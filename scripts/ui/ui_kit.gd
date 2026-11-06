class_name UiKit
extends RefCounted
## Wspólny wygląd interfejsu (ten sam klimat co menu poprzedniej wersji: ciemna czerwień, złote obramowania).

const RED := Color(0.85, 0.18, 0.14)
const GOLD := Color(0.9, 0.78, 0.45)
const TEXT := Color(0.93, 0.88, 0.76)
const DIM := Color(0.62, 0.58, 0.5)
const BG := Color(0.07, 0.04, 0.04)
static var _theme: Theme = null

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 24
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		match state:
			"normal": sb.bg_color = Color(0.16, 0.10, 0.09, 0.95)
			"hover": sb.bg_color = Color(0.30, 0.12, 0.10, 0.98)
			"pressed": sb.bg_color = Color(0.50, 0.12, 0.10, 1.0)
			"focus": sb.bg_color = Color(0.22, 0.11, 0.09, 1.0)
			"disabled": sb.bg_color = Color(0.10, 0.08, 0.08, 0.7)
		sb.border_color = Color(0.72, 0.58, 0.28) if state != "disabled" else Color(0.35, 0.3, 0.25)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.42, 0.38))
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", panel_style())
	_theme = t
	return t

static func panel_style(alpha: float = 0.94) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.06, 0.05, alpha)
	sb.border_color = Color(0.62, 0.48, 0.22)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(14)
	return sb

static func button(text: String, cb: Callable, min_w: float = 320.0, h: float = 56.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, h)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func():
		Audio.play("ui_click")
		cb.call())
	return b

static func label(text: String, size: int = 24, col: Color = TEXT, center: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func outlined(l: Label, w: int = 4) -> Label:
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.01))
	l.add_theme_constant_override("outline_size", w)
	return l

static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c

static func dim_root(alpha: float = 0.75) -> Control:
	var root := Control.new()
	root.theme = theme()
	full_rect(root)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, alpha)
	full_rect(dim)
	root.add_child(dim)
	return root

## Pełnoekranowa nakładka z tytułem, opisem i przyciskami [[tekst, callable], ...].
static func overlay(title: String, subtitle: String, buttons: Array) -> Control:
	var root := dim_root()
	var center := CenterContainer.new()
	full_rect(center)
	root.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	center.add_child(vb)
	vb.add_child(label(title, 52, RED))
	if subtitle != "":
		var s := label(subtitle, 24)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.custom_minimum_size = Vector2(620, 0)
		vb.add_child(s)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	vb.add_child(gap)
	var first: Button = null
	for b in buttons:
		var btn := button(b[0], b[1])
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(btn)
		if first == null:
			first = btn
	if first:
		first.call_deferred("grab_focus")
	return root

static func icon(path: String, size: float = 40.0) -> TextureRect:
	var trect := TextureRect.new()
	if path != "" and ResourceLoader.exists(path):
		trect.texture = load(path)
	trect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	trect.custom_minimum_size = Vector2(size, size)
	trect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return trect
