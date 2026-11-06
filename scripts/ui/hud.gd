class_name Hud
extends Control
## Interfejs w trakcie gry: paski życia/many/doświadczenia, korony, pas z miksturami, dziennik zadań,
## komunikaty, podpowiedź interakcji i przyciski Mapa / Postać / Plecak / Pauza.

var level: Node
var _msgs: VBoxContainer
var _quest_box: VBoxContainer
var _quest_panel: PanelContainer
var _gold: Label
var _belt: Label
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
	var bars := Control.new()
	bars.custom_minimum_size = Vector2(300, 46)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.draw.connect(_draw_bars.bind(bars))
	bars.name = "Bars"
	tl.add_child(bars)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_child(row)
	_gold = UiKit.outlined(UiKit.label("", 17, Color(1.0, 0.85, 0.35), false))
	row.add_child(_gold)
	_belt = UiKit.outlined(UiKit.label("", 17, UiKit.TEXT, false))
	row.add_child(_belt)
	_points = UiKit.button("", func(): level.open_character(), 230, 34)
	_points.add_theme_font_size_override("font_size", 16)
	_points.visible = false
	tl.add_child(_points)
	# prawy górny róg: przyciski i dziennik zadań
	var tr := VBoxContainer.new()
	_anchor(tr, 1.0, 0.0, Vector2(-16, 10), Vector2(-16, 10))
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr.add_theme_constant_override("separation", 6)
	tr.alignment = BoxContainer.ALIGNMENT_END
	add_child(tr)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	btns.alignment = BoxContainer.ALIGNMENT_END
	tr.add_child(btns)
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
	tr.add_child(_quest_panel)
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
	_anchor(_hint, 0.5, 1.0, Vector2(-300, -64), Vector2(300, -64))
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
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
	var bars := find_child("Bars", true, false)
	if bars:
		bars.queue_redraw()
	if _banner_t > 0.0:
		_banner_t -= delta
		_banner.modulate.a = clampf(_banner_t, 0.0, 1.0)
	_refresh_belt()

func _draw_bars(c: Control) -> void:
	var h: HeroState = Game.hero
	if h == null:
		return
	var w := 300.0
	_bar(c, Rect2(0, 0, w, 18), h.hp / maxf(1.0, h.max_hp()), Color(0.62, 0.08, 0.06), "%d / %d" % [int(ceil(h.hp)), h.max_hp()])
	if h.max_mana() > 0:
		_bar(c, Rect2(0, 21, w, 14), h.mana / maxf(1.0, h.max_mana()), Color(0.16, 0.3, 0.7), "%d / %d" % [int(h.mana), h.max_mana()])
	var prev := h.prev_threshold()
	var nxt := h.next_threshold()
	var k := 1.0 if nxt < 0 else float(h.xp - prev) / maxf(1.0, nxt - prev)
	_bar(c, Rect2(0, 38, w, 6), k, Color(0.75, 0.6, 0.2), "")
	if level and level.hero and level.hero.skill_cd > 0.0:
		var sk: Dictionary = level.hero.skill
		var kk: float = level.hero.skill_cd / maxf(0.1, float(sk.get("odnowienie", 1.0)))
		c.draw_rect(Rect2(w + 8, 0, 6, 35), Color(0.1, 0.08, 0.07))
		c.draw_rect(Rect2(w + 8, 35 * kk, 6, 35 * (1.0 - kk)), Color(0.8, 0.7, 0.4))

func _bar(c: Control, r: Rect2, k: float, col: Color, text: String) -> void:
	c.draw_rect(r.grow(2), Color(0.03, 0.02, 0.02))
	c.draw_rect(r, Color(0.14, 0.1, 0.09))
	c.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(k, 0, 1), r.size.y)), col)
	c.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(k, 0, 1), 2)), col.lightened(0.3))
	if text != "" and r.size.y >= 12:
		var f := get_theme_default_font()
		c.draw_string_outline(f, r.position + Vector2(6, r.size.y - 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color(0, 0, 0))
		c.draw_string(f, r.position + Vector2(6, r.size.y - 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1))

func refresh() -> void:
	var h: HeroState = Game.hero
	if h == null:
		return
	_name.text = "%s   PP: %d" % [h.display_name(), h.stats.val("PP")]
	_gold.text = "Korony: %d" % h.inv.gold
	var pa := h.points_available()
	_points.visible = pa > 0
	_points.text = "+ Punkty rozwoju: %d" % pa
	_refresh_belt()

func _refresh_belt() -> void:
	var h: HeroState = Game.hero
	if h == null:
		return
	var b: Dictionary = h.inv.belt
	var t := "Życie: %d  Piwo: %d" % [int(b.get("mikstura_zycia", 0)), int(b.get("piwo", 0))]
	if h.max_mana() > 0:
		t = "Życie: %d  Mana: %d  Piwo: %d" % [int(b.get("mikstura_zycia", 0)), int(b.get("mikstura_many", 0)), int(b.get("piwo", 0))]
	if _belt.text != t:
		_belt.text = t

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
