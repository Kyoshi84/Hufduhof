class_name TouchControls
extends Control
## Sterowanie dotykowe (Android): wirtualny joystick po lewej, po prawej przyciski Atak, Umiejętność/Czar,
## Mikstura życia, Mikstura many i Interakcja. Obsługa wielu palców naraz (ruch + atak).
## Przyciski wywołują te same akcje wejścia co klawiatura (Input.action_press), więc bohater nie odróżnia źródła.

var level: Node
var joy_center := Vector2.ZERO
var joy_touch: int = -1
var joy_knob := Vector2.ZERO
var joy_radius: float = 78.0
var buttons: Array = []          # {action, pos, r, label, touch}
var interact_label: String = ""

func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout()
	get_viewport().size_changed.connect(_layout)

func _layout() -> void:
	var s := get_viewport_rect().size
	joy_center = Vector2(150, s.y - 150)
	var br := Vector2(s.x - 120, s.y - 120)
	buttons = [
		{"action": "atak", "pos": br, "r": 66.0, "label": "ATAK", "touch": -1},
		{"action": "umiejetnosc", "pos": br + Vector2(-150, 18), "r": 48.0, "label": "UMIEJ.", "touch": -1},
		{"action": "interakcja", "pos": br + Vector2(-20, -150), "r": 46.0, "label": "UŻYJ", "touch": -1},
		{"action": "mikstura_zycia", "pos": br + Vector2(-140, -110), "r": 36.0, "label": "ŻYCIE", "touch": -1},
		{"action": "mikstura_many", "pos": br + Vector2(-250, -40), "r": 36.0, "label": "MANA", "touch": -1},
	]
	queue_redraw()

func set_interact_label(t: String) -> void:
	interact_label = t
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			for b in buttons:
				if b["touch"] == -1 and e.position.distance_to(b["pos"]) <= b["r"] + 12.0:
					b["touch"] = e.index
					Input.action_press(b["action"])
					if level and level.hero:
						level.hero.use_mouse_aim = false
					get_viewport().set_input_as_handled()
					queue_redraw()
					return
			if joy_touch == -1 and e.position.x < get_viewport_rect().size.x * 0.45 and e.position.y > 140:
				joy_touch = e.index
				joy_center = e.position
				joy_knob = Vector2.ZERO
				get_viewport().set_input_as_handled()
				queue_redraw()
		else:
			for b in buttons:
				if b["touch"] == e.index:
					b["touch"] = -1
					Input.action_release(b["action"])
					queue_redraw()
			if e.index == joy_touch:
				joy_touch = -1
				joy_knob = Vector2.ZERO
				Controls.joy = Vector2.ZERO
				var s := get_viewport_rect().size
				joy_center = Vector2(150, s.y - 150)
				queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == joy_touch:
			joy_knob = (d.position - joy_center).limit_length(joy_radius)
			Controls.joy = joy_knob / joy_radius
			get_viewport().set_input_as_handled()
			queue_redraw()

func _draw() -> void:
	draw_circle(joy_center, joy_radius, Color(0.1, 0.06, 0.05, 0.35))
	draw_arc(joy_center, joy_radius, 0, TAU, 40, Color(0.72, 0.58, 0.28, 0.6), 2.0)
	draw_circle(joy_center + joy_knob, 34.0, Color(0.5, 0.15, 0.1, 0.65))
	draw_arc(joy_center + joy_knob, 34.0, 0, TAU, 30, Color(0.9, 0.78, 0.45, 0.8), 2.0)
	var f := get_theme_default_font()
	for b in buttons:
		var pressed: bool = b["touch"] != -1
		var dim: bool = b["action"] == "interakcja" and interact_label == ""
		var col := Color(0.55, 0.12, 0.09, 0.75) if pressed else Color(0.16, 0.09, 0.08, 0.6)
		if dim:
			col.a = 0.25
		draw_circle(b["pos"], b["r"], col)
		draw_arc(b["pos"], b["r"], 0, TAU, 36, Color(0.9, 0.78, 0.45, 0.35 if dim else 0.85), 2.5)
		var txt: String = b["label"]
		var fs := 16 if b["r"] > 40 else 13
		if b["action"] == "mikstura_zycia" or b["action"] == "mikstura_many":
			var h: HeroState = Game.hero
			if h:
				txt += "\n%d" % int(h.inv.belt.get(b["action"], 0))
		var lines := txt.split("\n")
		for i in lines.size():
			var w := f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			draw_string_outline(f, b["pos"] + Vector2(-w / 2.0, 6 + (i - (lines.size() - 1) / 2.0) * 18), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0))
			draw_string(f, b["pos"] + Vector2(-w / 2.0, 6 + (i - (lines.size() - 1) / 2.0) * 18), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.95, 0.85, 0.4 if dim else 1.0))
	if interact_label != "":
		var b: Dictionary = buttons[2]
		var w := f.get_string_size(interact_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string_outline(f, b["pos"] + Vector2(-w / 2.0, -b["r"] - 10), interact_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 3, Color(0, 0, 0))
		draw_string(f, b["pos"] + Vector2(-w / 2.0, -b["r"] - 10), interact_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.95, 0.7))

func _process(_d: float) -> void:
	if visible:
		queue_redraw()
