class_name Pickup
extends Node2D
## Mikstura lecząca.

var level
var heal_amount: float = 35.0
var taken: bool = false
var t: float = 0.0

func setup(lvl, pos: Vector2, amount: float) -> void:
	level = lvl
	position = pos
	heal_amount = amount

func tick(delta: float) -> void:
	t += delta
	queue_redraw()
	var p = level.player
	if p != null and p.is_alive() and not taken:
		if absf(p.position.x - position.x) < 44.0 and absf(p.position.y - position.y) < 36.0:
			taken = true
			p.heal(heal_amount)
			Sfx.play("pickup")

func _draw() -> void:
	var bob: float = sin(t * 4.0) * 4.0 - 22.0
	var pt: Texture2D = StageArt.common_prop("potion")
	if pt != null:
		var k: float = 4.0 / 3.0
		draw_texture_rect(pt, Rect2(-pt.get_width() * k * 0.5, bob - pt.get_height() * k * 0.5 - 4.0, pt.get_width() * k, pt.get_height() * k), false)
		return
	draw_circle(Vector2(0, bob), 11, Color(0.75, 0.08, 0.1))
	draw_rect(Rect2(-4, bob - 20, 8, 10), Color(0.8, 0.75, 0.6))
	draw_circle(Vector2(-3, bob - 3), 3, Color(1, 0.6, 0.6, 0.7))
	draw_circle(Vector2(0, 0), 10, Color(0, 0, 0, 0.25))
