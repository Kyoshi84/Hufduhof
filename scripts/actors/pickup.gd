class_name Pickup
extends Node2D
## Mikstura lecząca.

var level
var heal_amount: float = 35.0       # dla kind = "slime": obrażenia
var kind: String = "potion"         # "potion" leczy, "slime" (spaczenie, seledynowy glut) rani
var taken: bool = false
var t: float = 0.0

func setup(lvl, pos: Vector2, amount: float, p_kind: String = "potion") -> void:
	level = lvl
	position = pos
	heal_amount = amount
	kind = p_kind

func tick(delta: float) -> void:
	t += delta
	queue_redraw()
	var p = level.player
	if p != null and p.is_alive() and not taken:
		if absf(p.position.x - position.x) < 44.0 and absf(p.position.y - position.y) < 36.0:
			if kind == "slime":
				if p.z > 40.0:
					return                                # skok nad glutem: omijasz go
				taken = true
				p.take_hazard(heal_amount)
				if level.fx != null:
					level.fx.burst(position + Vector2(0, -16), 10, Color(0.67, 0.88, 0.69), 170.0, 1)
				Sfx.play("hit", 0.7)
				return
			taken = true
			p.heal(heal_amount)
			Sfx.play("pickup")

func _draw_slime() -> void:
	var sq: float = 1.0 + 0.12 * sin(t * 6.0)
	var rx: float = 15.0 * sq
	var ry: float = 11.0 / sq
	draw_circle(Vector2(0, 2), 15.0, Color(0, 0, 0, 0.25))
	var glow: float = 0.30 + 0.15 * sin(t * 4.0)
	draw_circle(Vector2(0, -10), 26.0, Color(0.55, 0.95, 0.65, glow * 0.45))          # poświata ostrzega: to nie lek
	var pts := PackedVector2Array()
	for i in 20:
		var a: float = TAU * i / 20.0
		var wob: float = 1.0 + 0.08 * sin(a * 3.0 + t * 5.0)
		pts.append(Vector2(cos(a) * rx * wob, -10.0 + sin(a) * ry * wob * (1.0 if sin(a) < 0.0 else 0.55)))
	draw_colored_polygon(pts, Color(0.46, 0.72, 0.52))
	var pts2 := PackedVector2Array()
	for i in 20:
		var a2: float = TAU * i / 20.0
		pts2.append(Vector2(cos(a2) * rx * 0.78, -11.0 + sin(a2) * ry * 0.72 * (1.0 if sin(a2) < 0.0 else 0.5)))
	draw_colored_polygon(pts2, Color(0.67, 0.88, 0.69))
	draw_circle(Vector2(-5, -17), 3.2, Color(0.92, 1.0, 0.92))
	draw_circle(Vector2(-4, -9), 2.3, Color(0.12, 0.2, 0.14))                         # oczka spaczenia
	draw_circle(Vector2(4, -9), 2.3, Color(0.12, 0.2, 0.14))
	for k in 3:
		var u: float = fmod(t * 0.8 + k * 0.33, 1.0)
		draw_circle(Vector2(sin(k * 2.0 + t) * 8.0, -22.0 - u * 18.0), 2.0 * (1.0 - u), Color(0.75, 1.0, 0.8, 0.8 * (1.0 - u)))

func _draw() -> void:
	if kind == "slime":
		_draw_slime()
		return
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
