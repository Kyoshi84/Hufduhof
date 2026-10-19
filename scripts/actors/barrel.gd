class_name Barrel
extends Node2D
## Zniszczalna beczka: element otoczenia. Może zawierać mikstury leczącej.

var level
var hp: float = 24.0
var body_half: float = 22.0
var team: int = 2
var alive: bool = true
var wobble: float = 0.0

func setup(lvl, pos: Vector2) -> void:
	level = lvl
	position = pos
	hp = float(Balance.world("barrel_hp"))

func is_alive() -> bool:
	return alive

func can_be_hit() -> bool:
	return alive

func hurtbox_rect() -> Rect2:
	return HitShape.hurt_rect(position, body_half, float(Balance.world("foot_half_depth")))

func tick(delta: float) -> void:
	wobble = maxf(0.0, wobble - delta * 4.0)
	queue_redraw()

func receive_hit(attacker, defn: Dictionary) -> bool:
	if not alive:
		return false
	hp -= float(defn["damage"]) * attacker.damage_mult
	wobble = 1.0
	Sfx.play("barrel_break", 1.4)
	if hp <= 0.0:
		alive = false
		level.on_barrel_broken(self)
	return true

func _draw() -> void:
	var sway: float = sin(wobble * 18.0) * wobble * 4.0
	draw_set_transform(Vector2(sway, 0), 0.0, Vector2.ONE)
	var bt: Texture2D = StageArt.common_prop("barrel")
	if bt != null:
		var k: float = 4.0 / 3.0
		draw_texture_rect(bt, Rect2(-bt.get_width() * k * 0.5, -bt.get_height() * k, bt.get_width() * k, bt.get_height() * k), false)
		return
	var c := Color(0.36, 0.22, 0.12)
	var pts := PackedVector2Array([Vector2(-18, 0), Vector2(18, 0), Vector2(22, -28), Vector2(18, -56), Vector2(-18, -56), Vector2(-22, -28)])
	draw_colored_polygon(pts, c)
	draw_line(Vector2(-21, -14), Vector2(21, -14), Color(0.17, 0.15, 0.14), 4.0)
	draw_line(Vector2(-21, -42), Vector2(21, -42), Color(0.17, 0.15, 0.14), 4.0)
	draw_line(Vector2(-6, -56), Vector2(-5, 0), c.darkened(0.3), 2.0)
	draw_line(Vector2(7, -56), Vector2(8, 0), c.darkened(0.3), 2.0)
