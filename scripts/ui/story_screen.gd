class_name StoryScreen
extends Control
## Ekran fabularny między etapami: ilustracja, tytuł, tekst "maszynopisowy" i przyciski Dalej / Pomiń.
## Dane z data/story.json (wpis: kicker, title, image, pages = [[akapity], ...]). Akapity zaczynające się od "—" to dialogi.
## Sterowanie: dotyk/klik w dowolnym miejscu, Enter, Spacja = dalej (pierwsze naciśnięcie kończy pisanie strony); Esc = pomiń.

signal finished

const CHARS_PER_SEC := 60.0
const DIALOG_COLOR := "#e6c46e"

var entry: Dictionary = {}
var pages: Array = []
var page: int = 0
var typing: bool = false
var rich: RichTextLabel
var next_btn: Button
var page_label: Label
var _tween: Tween
var _done: bool = false

## Wczytuje data/story.json -> tablica wpisów (pusta, gdy brak pliku lub błąd).
static func load_entries(path: String = "res://data/story.json") -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var arr = parsed.get("stories", [])
	return arr if typeof(arr) == TYPE_ARRAY else []

## Wpis fabularny pokazywany przed etapem o danym numerze (albo pusty słownik).
static func entry_for_stage(stage: int, entries: Array = []) -> Dictionary:
	if entries.is_empty():
		entries = load_entries()
	for e in entries:
		if int(e.get("before_stage", -1)) == stage:
			return e
	return {}

## Zamienia akapity strony na BBCode (dialogi złote, tekst z escapowanymi nawiasami).
static func page_to_bbcode(paragraphs: Array) -> String:
	var out: PackedStringArray = []
	for p in paragraphs:
		var s := str(p).replace("[", "[lb]")
		if s.begins_with("—"):
			out.append("[color=%s][i]%s[/i][/color]" % [DIALOG_COLOR, s])
		else:
			out.append(s)
	return "\n\n".join(out)

func setup(p_entry: Dictionary) -> void:
	entry = p_entry
	pages = entry.get("pages", [])

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_ALL
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.03)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var img_path: String = str(entry.get("image", ""))
	if img_path != "" and ResourceLoader.exists(img_path):
		var tr := TextureRect.new()
		tr.texture = load(img_path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)
	# przyciemnienie dołu ekranu pod tekstem (gradient)
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.0))
	grad.set_color(1, Color(0.02, 0.01, 0.02, 0.92))
	grad.set_offset(0, 0.35)
	grad.set_offset(1, 0.78)
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	var shade := TextureRect.new()
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	# nagłówek
	var head := VBoxContainer.new()
	head.set_anchors_preset(Control.PRESET_TOP_LEFT)
	head.position = Vector2(56, 34)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(head)
	var kicker := UI.make_label(str(entry.get("kicker", "")), 24, Color(0.82, 0.68, 0.38))
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	kicker.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	kicker.add_theme_constant_override("outline_size", 6)
	head.add_child(kicker)
	var title := UI.make_label(str(entry.get("title", "")).to_upper(), 64, Color(0.88, 0.2, 0.15))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	title.add_theme_constant_override("outline_size", 10)
	head.add_child(title)
	# panel z tekstem u dołu
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.anchor_top = 1.0
	panel.offset_left = 48
	panel.offset_right = -48
	panel.offset_top = -312
	panel.offset_bottom = -28
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.04, 0.04, 0.84)
	sb.border_color = Color(0.72, 0.58, 0.28)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 18
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vb)
	rich = RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.scroll_active = false
	rich.fit_content = false
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rich.custom_minimum_size = Vector2(0, 170)
	rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich.add_theme_font_size_override("normal_font_size", 28)
	rich.add_theme_font_size_override("italics_font_size", 28)
	rich.add_theme_color_override("default_color", Color(0.93, 0.88, 0.76))
	vb.add_child(rich)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(row)
	page_label = UI.make_label("", 22, Color(0.62, 0.56, 0.46))
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(page_label)
	var skip := UI.make_button("Pomiń", skip_all, 180.0)
	skip.process_mode = Node.PROCESS_MODE_ALWAYS
	row.add_child(skip)
	next_btn = UI.make_button("Dalej", advance, 240.0)
	next_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	row.add_child(next_btn)
	grab_focus()
	show_page(0)

func show_page(i: int) -> void:
	page = i
	var last: bool = page >= pages.size() - 1
	rich.text = page_to_bbcode(pages[page]) if page < pages.size() else ""
	page_label.text = "%d / %d" % [page + 1, maxi(1, pages.size())]
	if next_btn != null:
		next_btn.text = "Do boju!" if last else "Dalej"
	if _tween != null and _tween.is_valid():
		_tween.kill()
	rich.visible_ratio = 0.0
	typing = true
	var total: int = maxi(1, rich.get_total_character_count())
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(rich, "visible_ratio", 1.0, total / CHARS_PER_SEC)
	_tween.finished.connect(func(): typing = false)

## Pierwsze wywołanie kończy pisanie bieżącej strony, kolejne przechodzi dalej (po ostatniej stronie: koniec).
func advance() -> void:
	if _done:
		return
	if typing:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		rich.visible_ratio = 1.0
		typing = false
		return
	if page >= pages.size() - 1:
		_finish()
	else:
		show_page(page + 1)

func skip_all() -> void:
	_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	finished.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		advance()

func _input(event: InputEvent) -> void:
	if _done or not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				get_viewport().set_input_as_handled()
				advance()
			KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				skip_all()
