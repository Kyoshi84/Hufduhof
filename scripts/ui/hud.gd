class_name Hud
extends Control
## Interfejs w trakcie gry: paski życia/many/doświadczenia, korony, pas z miksturami, dziennik zadań,
## komunikaty, podpowiedź interakcji i przyciski Mapa / Postać / Plecak / Pauza.

var level: Node
var _msgs: VBoxContainer
var _quest_box: VBoxContainer
var _quest_panel: PanelContainer
var _gold: Label
var skill_bar: SkillBar
var _name: Label
var _points: Button
var _hint: Label
var _banner: Label
var _banner_t: float = 0.0
var _t: float = 0.0

func _ready() -> void:
	theme = UiKit.theme()
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# lewy górny róg: imię, paski, korony, pas
	var tl := VBoxContainer.new()
	tl.position = Vector2(16, 12)
	tl.add_theme_constant_override("separation", 2)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tl)
	_name = UiKit.outlined(UiKit.label("", 18, UiKit.GOLD, false))
	tl.add_child(_name)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_child(row)
	_gold = UiKit.outlined(UiKit.label("", 17, Color(1.0, 0.85, 0.35), false))
	row.add_child(_gold)
	_points = UiKit.button("", func(): level.open_character(), 230, 34)
	_points.add_theme_font_size_override("font_size", 16)
	_points.visible = false
	tl.add_child(_points)
	# prawy górny róg: przyciski i dziennik zadań
	var trect := VBoxContainer.new()
	_anchor(trect, 1.0, 0.0, Vector2(-16, 10), Vector2(-16, 10))
	trect.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	trect.add_theme_constant_override("separation", 6)
	trect.alignment = BoxContainer.ALIGNMENT_END
	add_child(trect)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	btns.alignment = BoxContainer.ALIGNMENT_END
	trect.add_child(btns)
	for b in [["Mapa", func(): level.toggle_map()], ["Postać", func(): level.open_character()],
			["Plecak", func(): level.open_inventory()], ["II", func(): level.open_pause()]]:
		var btn := UiKit.button(b[0], b[1], 0, 46)
		btn.add_theme_font_size_override("font_size", 18)
		btn.focus_mode = Control.FOCUS_NONE
		btns.add_child(btn)
	_quest_panel = PanelContainer.new()
	_quest_panel.add_theme_stylebox_override("panel", UiKit.panel_style(0.72))
	_quest_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_quest_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trect.add_child(_quest_panel)
	_quest_box = VBoxContainer.new()
	_quest_box.add_theme_constant_override("separation", 0)
	_quest_panel.add_child(_quest_box)
	# komunikaty (środek u góry), baner (środek), podpowiedź interakcji (dół)
	_msgs = VBoxContainer.new()
	_anchor(_msgs, 0.5, 0.0, Vector2(-330, 96), Vector2(330, 96))
	_msgs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_msgs)
	_banner = UiKit.outlined(UiKit.label("", 26, UiKit.GOLD), 6)
	_anchor(_banner, 0.5, 0.5, Vector2(-420, -190), Vector2(420, -190))
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	_hint = UiKit.outlined(UiKit.label("", 20, Color(1.0, 0.95, 0.7)), 5)
	_anchor(_hint, 0.5, 1.0, Vector2(-300, -170), Vector2(300, -170))
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	# pasek umiejętności z kulami Życia i Many (dół ekranu)
	skill_bar = SkillBar.new()
	skill_bar.level = level
	add_child(skill_bar)
	Game.message.connect(show_message)
	Game.hero_changed.connect(refresh)
	if level and level.hero:
		level.hero.action_hint_changed.connect(_refresh_hint)
	refresh()
	refresh_quest()

func _anchor(c: Control, ax: float, ay: float, tl: Vector2, br: Vector2) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = tl.x
	c.offset_top = tl.y
	c.offset_right = br.x
	c.offset_bottom = br.y

func _process(delta: float) -> void:
	_t += delta
	if _banner_t > 0.0:
		_banner_t -= delta
		_banner.modulate.a = clampf(_banner_t, 0.0, 1.0)

func refresh() -> void:
	var h: HeroState = Game.hero
	if h == null:
		return
	_name.text = "%s   PP: %d" % [level.controlled_name() if level else h.display_name(), h.stats.val("PP")]
	_gold.text = "Korony: %d" % h.inv.gold
	var pa := h.points_available()
	_points.visible = pa > 0
	_points.text = "+ Punkty rozwoju: %d" % pa

func refresh_quest() -> void:
	for c in _quest_box.get_children():
		c.queue_free()
	var lines: Array = level.quest_lines() if level and level.has_method("quest_lines") else Game.quest.log_lines()
	_quest_panel.visible = not lines.is_empty()
	var first := true
	for l in lines:
		var lb := UiKit.label(str(l), 17 if first else 16, UiKit.GOLD if first else UiKit.TEXT, false)
		_quest_box.add_child(lb)
		first = false

func _refresh_hint() -> void:
	var h: Hero = level.hero
	if h.near_interactable and is_instance_valid(h.near_interactable):
		var key := "" if Save.touch_enabled() else "[E] "
		_hint.text = key + h.near_interactable.interact_label(h)
	else:
		_hint.text = ""
	if level.touch:
		level.touch.set_interact_label(_hint.text.trim_prefix("[E] "))

func show_message(text: String, col: Color) -> void:
	var l := UiKit.outlined(UiKit.label(text, 20, col), 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msgs.add_child(l)
	while _msgs.get_child_count() > 4:
		_msgs.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)

func show_banner(text: String, dur: float = 5.0) -> void:
	_banner.text = text
	_banner_t = dur
	_banner.modulate.a = 1.0
