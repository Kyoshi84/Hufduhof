class_name UI
extends RefCounted
## Wspólny motyw i konstruktory ekranów (wszystko tworzone w kodzie).

static var _theme: Theme = null

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 28
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		match state:
			"normal": sb.bg_color = Color(0.16, 0.10, 0.09, 0.95)
			"hover": sb.bg_color = Color(0.30, 0.12, 0.10, 0.98)
			"pressed": sb.bg_color = Color(0.50, 0.12, 0.10, 1.0)
			"focus": sb.bg_color = Color(0.22, 0.11, 0.09, 1.0)
			"disabled": sb.bg_color = Color(0.10, 0.08, 0.08, 0.7)
		sb.border_color = Color(0.72, 0.58, 0.28)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 24
		sb.content_margin_right = 24
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", Color(0.93, 0.88, 0.76))
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.42, 0.38))
	t.set_color("font_color", "Label", Color(0.93, 0.88, 0.76))
	_theme = t
	return t

static func make_button(text: String, cb: Callable, min_w: float = 420.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 64)
	b.pressed.connect(func():
		Sfx.play("ui_click")
		cb.call())
	return b

static func make_label(text: String, size: int, col: Color = Color(0.93, 0.88, 0.76)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

## Pełnoekranowy overlay z tytułem, opisem i listą przycisków [[tekst, callable], ...].
static func make_overlay(title: String, subtitle: String, buttons: Array) -> Control:
	var root := Control.new()
	root.theme = theme()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	center.add_child(vb)
	vb.add_child(make_label(title, 58, Color(0.85, 0.2, 0.15)))
	if subtitle != "":
		vb.add_child(make_label(subtitle, 30))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	vb.add_child(gap)
	for b in buttons:
		vb.add_child(make_button(b[0], b[1]))
	return root
