class_name Actor
extends CharacterBody2D
## Wspólna baza bohatera i wrogów: cechy, życie, obrażenia, efekty w czasie (trucizna, ogień),
## nietykalność, cień i tryb diagnostyki kolizji (F3). Hurtbox (promień ciała) jest niezależny od sprite'a.

signal died(actor: Actor)

enum St { IDLE, MOVE, WINDUP, STRIKE, RECOVER, HURT, DEAD }

var level: Node = null               # Level (spawn efektów, lista aktorów)
var stats: Stats
var hp: float = 10.0
var faction: int = 0                 # 0 = bohater, 1 = wrogowie
var body_radius: float = 14.0        # hurtbox w pikselach podłoża
var facing := Vector2(0, 1)
var gfx: DirSprite
var state: int = St.IDLE
var state_t: float = 0.0
var invuln: float = 0.0
var dots: Array = []                 # {dps, t, kind}
var _dot_tick: float = 0.0
var flash: float = 0.0
var glow := Color(0, 0, 0, 0)        # poświata (np. niezniszczalność Ulryka)
var blessed: float = 0.0             # niezniszczalność (kapliczka Ulryka) - sekundy
var rng := RandomNumberGenerator.new()
var _glancing: bool = false         # bieżące trafienie to draśnięcie (mniejsza, szara liczba)

func _init() -> void:
	rng.randomize()

func setup_body(radius: float, layer: int, mask: int) -> void:
	body_radius = radius
	collision_layer = layer
	collision_mask = mask
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = radius * 0.5
	cap.height = radius * 2.0
	cs.shape = cap
	cs.rotation = PI / 2.0      # pozioma kapsuła = elipsa 2:1 na podłodze
	add_child(cs)

func get_max_hp() -> int:
	return stats.max_hp()

func armor() -> int:
	return 0

func weapon_dmg() -> int:
	return 2

func is_dead() -> bool:
	return state == St.DEAD

func set_state(s: int) -> void:
	state = s
	state_t = 0.0

## Zadaje obrażenia (już po rzucie na trafienie). kind: fiz / trucizna / ogien / magia
func apply_damage(amount: float, kind: String = "fiz", _source: Node = null) -> void:
	if is_dead() or amount <= 0.0:
		return
	if invuln > 0.0 and kind == "fiz":
		return
	if blessed > 0.0:
		_float("Ochrona!", Color(1, 0.9, 0.5))
		return
	hp -= amount
	flash = 0.12
	var c := Color(1, 0.35, 0.3) if faction == 0 else Color(1, 0.95, 0.8)
	if kind == "trucizna":
		c = Color(0.55, 1.0, 0.35)
	elif kind == "ogien":
		c = Color(1.0, 0.6, 0.2)
	if _glancing:
		c = Color(0.75, 0.72, 0.66)
	_float(str(int(round(amount))), c, amount >= 10.0 and not _glancing)
	on_damaged(amount, kind)
	if hp <= 0.0:
		hp = 0.0
		die()

func on_damaged(_amount: float, _kind: String) -> void:
	pass

func die() -> void:
	set_state(St.DEAD)
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	died.emit(self)

## Efekt w czasie. Trucizna/spaczenie osłabiana przez SW (Rules.poison_factor).
func add_dot(dps: float, duration: float, kind: String) -> void:
	if is_dead():
		return
	if kind == "trucizna":
		dps *= Rules.poison_factor(stats.val("SW"))
	for d in dots:
		if d["kind"] == kind:
			d["t"] = maxf(d["t"], duration)
			d["dps"] = maxf(d["dps"], dps)
			return
	dots.append({"dps": dps, "t": duration, "kind": kind})

func receive_hit(res: Dictionary, attacker: Actor = null) -> void:
	if is_dead():
		return
	if res.get("hit", false):
		_glancing = bool(res.get("glancing", false))
		apply_damage(float(res["damage"]), str(res.get("kind", "fiz")), attacker)
		_glancing = false
		Audio.play("hit", 0.8 if res.get("glancing", false) else 1.0)
	elif res.get("dodged", false):
		_float("Unik", Color(0.8, 0.9, 1.0))
		Audio.play("miss")
	else:
		_float("Pudło", Color(0.75, 0.72, 0.65))
		Audio.play("miss")

func _float(t: String, c: Color, big: bool = false) -> void:
	if level and level.has_method("fx_parent"):
		Fx.float_text(level.fx_parent(), position + Vector2(0, -gfx_height() - 6), t, c, big)

func gfx_height() -> float:
	return 90.0

func tick_common(delta: float) -> void:
	state_t += delta
	invuln = maxf(0.0, invuln - delta)
	blessed = maxf(0.0, blessed - delta)
	glow = Color(1.0, 0.85, 0.35, 1.0) if blessed > 0.0 else Color(0, 0, 0, 0)
	flash = maxf(0.0, flash - delta)
	if not dots.is_empty() and not is_dead():
		_dot_tick += delta
		if _dot_tick >= 0.5:
			_dot_tick -= 0.5
			for d in dots:
				apply_damage(d["dps"] * 0.5, d["kind"])
				if is_dead():
					break
		for d in dots:
			d["t"] -= delta
		dots = dots.filter(func(d): return d["t"] > 0.0)
	if gfx:
		var m := Color(1, 1, 1)
		if flash > 0.0:
			m = Color(2.2, 2.0, 1.9)
		elif get("slow_t") != null and float(get("slow_t")) > 0.0:
			m = Color(0.75, 0.85, 1.25)
		elif not dots.is_empty():
			m = Color(0.75, 1.15, 0.7) if dots[0]["kind"] == "trucizna" else Color(1.3, 0.9, 0.7)
		if glow.a > 0.0:
			m = m.lerp(Color(glow.r * 1.6, glow.g * 1.6, glow.b * 1.4), 0.45 + 0.15 * sin(Time.get_ticks_msec() / 90.0))
		gfx.modulate = m
	queue_redraw()

func _draw() -> void:
	# cień pod stopami (elipsa)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, body_radius + 6.0, Color(0, 0, 0, 0.35 if not is_dead() else 0.2))
	if glow.a > 0.0:
		draw_arc(Vector2.ZERO, body_radius + 14.0, 0, TAU, 28, Color(glow, 0.9), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if Game.debug_collision:
		draw_debug()

func draw_debug() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_arc(Vector2.ZERO, body_radius, 0, TAU, 24, Color(0.2, 1.0, 0.3), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_line(Vector2.ZERO, Iso.screen(Iso.ground(facing).normalized() * 30.0), Color(1, 1, 0), 1.5)
	draw_circle(Vector2.ZERO, 2.0, Color(1, 0, 1))
