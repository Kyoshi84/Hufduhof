class_name RatHole
extends Node2D
## Nora szczuroludzi: co kilka sekund wypuszcza szczura, dopóki gracz jej nie zniszczy (3 trafienia dowolnym atakiem,
## także pociskiem). Dopóki nora w etapie istnieje, etap się nie kończy (bramka zamknięta, licznik pokazuje "NORA!").
## Szczury z nory nie nabijają licznika punktów etapu. Nora "śpi" w czasie fal i gdy gracz jest daleko.

const HITS := 3
const INTERVAL := 3.5               # s między szczurami
const RANGE := 650.0                # nora budzi się, gdy gracz jest bliżej niż tyle (w poziomie)
const MAX_ALIVE := 3                # najwyżej tylu szczurów z tej nory naraz
const WPT := 4.0 / 3.0

var level
var hits: int = 0
var alive: bool = true
var team: int = 2
var body_half: float = 34.0
var damage_mult: float = 1.0
var spawn_t: float = 1.2
var spawned: Array = []
var spawn_count: int = 0
var invuln: float = 0.0
var wobble: float = 0.0
var t: float = 0.0

func setup(lvl, pos: Vector2) -> void:
	level = lvl
	position = pos

func is_alive() -> bool:
	return alive

func can_be_hit() -> bool:
	return alive and invuln <= 0.0

func hurtbox_rect() -> Rect2:
	return HitShape.hurt_rect(position, body_half, 22.0)

## Każde trafienie (niezależnie od obrażeń) to jeden "cios" w norę.
func receive_hit(_attacker, _defn: Dictionary) -> bool:
	if not can_be_hit():
		return false
	hits += 1
	invuln = 0.22
	wobble = 1.0
	Sfx.play("barrel_break", 0.7)
	if level.fx != null:
		level.fx.burst(position + Vector2(0, -16), 10, Color(0.42, 0.32, 0.2), 200.0, 1)
	if hits >= HITS:
		alive = false
		level.on_rat_hole_destroyed(self)
	return true

func alive_spawned() -> int:
	var n := 0
	for e in spawned:
		if is_instance_valid(e) and e.is_alive():
			n += 1
	return n

func tick(delta: float) -> void:
	t += delta
	invuln = maxf(0.0, invuln - delta)
	wobble = maxf(0.0, wobble - delta * 4.0)
	queue_redraw()
	if not alive or level.outcome != "" or level.wave_active:
		return
	var p = level.player
	if p == null or not p.is_alive() or absf(p.position.x - position.x) > RANGE:
		return
	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = INTERVAL
		if alive_spawned() < MAX_ALIVE:
			var e: Enemy = level.spawn_enemy_at("skaven", position + Vector2(randf_range(-16.0, 16.0), 10.0))
			e.no_stage_points = true
			spawned.append(e)
			spawn_count += 1
			if level.fx != null:
				level.fx.burst(position + Vector2(0, -6), 8, Color(0.3, 0.22, 0.14), 160.0, 1)

func _draw() -> void:
	var tex: Texture2D = StageArt.common_prop("rat_hole" if alive else "rat_hole_broken")
	var sway: float = sin(wobble * 20.0) * wobble * 3.0
	if tex != null:
		var w: float = tex.get_width() * WPT
		var h: float = tex.get_height() * WPT
		var mod := Color(1.7, 1.7, 1.7) if invuln > 0.1 else Color.WHITE
		draw_texture_rect(tex, Rect2(floorf(-w * 0.5 + sway), floorf(-h + 16.0), w, h), false, mod)
	else:
		draw_circle(Vector2(0, -6), 30.0, Color(0.3, 0.22, 0.14))
		if alive:
			draw_circle(Vector2(0, -8), 14.0, Color(0.02, 0.02, 0.02))
	if alive:
		# pęknięcia za każde trafienie: małe znaczniki nad norą (ile jeszcze ciosów)
		for i in HITS:
			var c := Color(0.9, 0.2, 0.15) if i >= hits else Color(0.3, 0.3, 0.3)
			draw_rect(Rect2(-18.0 + i * 14.0, -58.0, 10.0, 6.0), c)
