class_name TouchControls
extends Control
## Wirtualny joystick (lewa strona, pojawia się pod palcem) i trzy przyciski (prawa strona).
## Półprzezroczyste i przy dolnych krawędziach, żeby nie zasłaniać akcji.

const STICK_R := 90.0

var stick_id: int = -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var held: Dictionary = {}      # index palca -> akcja

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func layout() -> Dictionary:
	var s := get_viewport_rect().size
	return {
		"light": [Vector2(s.x - 130.0, s.y - 120.0), 68.0, "CIĘCIE"],
		"heavy": [Vector2(s.x - 290.0, s.y - 82.0), 54.0, "MOCNY"],
		"dodge": [Vector2(s.x - 100.0, s.y - 265.0), 48.0, "UNIK"],
		"jump": [Vector2(s.x - 262.0, s.y - 214.0), 52.0, "SKOK"],
	}

func _button_at(pos: Vector2) -> String:
	var lay := layout()
	for k in lay.keys():
		if pos.distance_to(lay[k][0]) <= float(lay[k][1]) + 14.0:
			return k
	return ""

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			var act := _button_at(e.position)
			if act != "":
				Controls.press(act)
				held[e.index] = act
			elif e.position.x < get_viewport_rect().size.x * 0.45 and stick_id == -1 and e.position.y > 110.0:
				stick_id = e.index
				stick_origin = e.position
				stick_pos = e.position
		else:
			if e.index == stick_id:
				stick_id = -1
				Controls.touch_move = Vector2.ZERO
			held.erase(e.index)
		queue_redraw()
	elif e is InputEventScreenDrag and e.index == stick_id:
		stick_pos = e.position
		var d := stick_pos - stick_origin
		if d.length() > STICK_R:
			d = d.normalized() * STICK_R
			stick_pos = stick_origin + d
		var v := d / STICK_R
		Controls.touch_move = Vector2.ZERO if v.length() < 0.18 else v
		queue_redraw()

func _draw() -> void:
	var lay := layout()
	for k in lay.keys():
		var c: Vector2 = lay[k][0]
		var r: float = lay[k][1]
		var down: bool = held.values().has(k)
		draw_circle(c, r, Color(0.1, 0.05, 0.05, 0.55 if down else 0.32))
		draw_arc(c, r, 0, TAU, 32, Color(0.85, 0.7, 0.35, 0.7), 3.0)
		draw_string(ThemeDB.fallback_font, c + Vector2(-r, 8), lay[k][2], HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 18, Color(1, 1, 1, 0.8))
	var origin := stick_origin if stick_id != -1 else Vector2(150, get_viewport_rect().size.y - 130.0)
	draw_circle(origin, STICK_R, Color(0.1, 0.05, 0.05, 0.28))
	draw_arc(origin, STICK_R, 0, TAU, 40, Color(0.85, 0.7, 0.35, 0.5), 3.0)
	var knob := stick_pos if stick_id != -1 else origin
	draw_circle(knob, 36.0, Color(0.85, 0.7, 0.35, 0.55))
