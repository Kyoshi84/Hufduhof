extends Node
## Przełączanie ekranów: menu główne, ustawienia, informacje, poziom.

var current: Node = null
const PORTRAIT := "res://assets/ui/ivo_portrait.png"
const AUTHORS := "Janek M. i Franek W."   # autorzy gry (menu główne i "Informacje o grze")

func _ready() -> void:
	add_child(PaletteFilter.new())
	GameState.hero_id = Heroes.preferred(SaveData.last_hero)
	var errs := Balance.validate()
	if not errs.is_empty():
		push_error("Błędy balansu: %s" % str(errs))
	show_menu()

func _swap(n: Node) -> void:
	if current != null:
		current.queue_free()
	current = n
	add_child(n)

func show_menu() -> void:
	get_tree().paused = false
	Controls.reset()
	Sfx.play_track("menu")
	var root := Control.new()
	root.theme = UI.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bgc := ColorRect.new()
	bgc.color = Color(0.07, 0.04, 0.04)
	bgc.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bgc)
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 40)
	root.add_child(hb)
	if ResourceLoader.exists(PORTRAIT):
		var tr := TextureRect.new()
		tr.texture = load(PORTRAIT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(420, 560)
		hb.add_child(tr)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 12)
	hb.add_child(vb)
	if ResourceLoader.exists("res://assets/ui/crest/crest_menu.png"):
		var crest := TextureRect.new()
		crest.texture = load("res://assets/ui/crest/crest_menu.png")
		crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		crest.custom_minimum_size = Vector2(0, 120)
		vb.add_child(crest)
	vb.add_child(UI.make_label("IVO EGGERT", 64, Color(0.85, 0.18, 0.14)))
	vb.add_child(UI.make_label("Obrona Hufduhofu", 36, Color(0.9, 0.78, 0.45)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	vb.add_child(gap)
	vb.add_child(UI.make_button("Nowa gra", show_hero_select))
	var cont := UI.make_button("Kontynuuj", func(): start_game(true))
	cont.disabled = not SaveData.has_checkpoint()
	vb.add_child(cont)
	vb.add_child(UI.make_button("Ustawienia", show_settings))
	vb.add_child(UI.make_button("Informacje o grze", show_about))
	if SaveData.best_score > 0:
		vb.add_child(UI.make_label("Najlepszy wynik: %d" % SaveData.best_score, 24, Color(0.8, 0.75, 0.62)))
	root.add_child(_credits_label())
	_swap(root)

## Autorzy gry na dole menu głównego.
func _credits_label() -> Label:
	var l := UI.make_label("Autorzy: " + AUTHORS, 22, Color(0.8, 0.72, 0.55))
	l.name = "Credits"
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	l.offset_top = -48.0
	l.offset_bottom = -12.0
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	return l

## Ekran wyboru bohatera (po "Nowa gra"): karty z data/heroes.json; zablokowane karty mają "Wkrótce".
func show_hero_select() -> void:
	Controls.reset()
	var root := Control.new()
	root.name = "HeroSelect"
	root.theme = UI.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bgc := ColorRect.new()
	bgc.color = Color(0.07, 0.04, 0.04)
	bgc.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bgc)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	center.add_child(vb)
	vb.add_child(UI.make_label("WYBIERZ BOHATERA", 48, Color(0.85, 0.18, 0.14)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	vb.add_child(row)
	var focus_btn: Button = null
	var want: String = Heroes.preferred(SaveData.last_hero)
	for h in Heroes.all():
		var card := _hero_card(h)
		row.add_child(card)
		var btn: Button = card.get_meta("button")
		if str(h.get("id", "")) == want:
			focus_btn = btn
	var back := UI.make_button("Wróć", show_menu, 260.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(back)
	_swap(root)
	if focus_btn != null:
		focus_btn.grab_focus()

func _hero_card(h: Dictionary) -> Control:
	var hid: String = str(h.get("id", ""))
	var open: bool = bool(h.get("selectable", false))
	var panel := PanelContainer.new()
	panel.name = "Hero_" + hid
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.08, 0.07, 0.95) if open else Color(0.08, 0.06, 0.06, 0.95)
	sb.border_color = Color(0.72, 0.58, 0.28) if open else Color(0.32, 0.27, 0.22)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var pic_size := Vector2(290, 290)
	var path: String = str(h.get("portrait", ""))
	if open and path != "" and ResourceLoader.exists(path):
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.custom_minimum_size = pic_size
		col.add_child(tr)
	else:
		var box := ColorRect.new()
		box.color = Color(0.04, 0.03, 0.03)
		box.custom_minimum_size = pic_size
		var q := UI.make_label("?", 140, Color(0.30, 0.26, 0.22))
		q.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(q)
		col.add_child(box)
	col.add_child(UI.make_label(str(h.get("name", hid)), 34, Color(0.9, 0.78, 0.45) if open else Color(0.5, 0.45, 0.4)))
	col.add_child(UI.make_label(str(h.get("title", "")), 20, Color(0.8, 0.72, 0.6)))
	var desc := UI.make_label(str(h.get("description", "")), 17, Color(0.78, 0.74, 0.66))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(pic_size.x, 48)
	col.add_child(desc)
	var btn := UI.make_button("Wybierz" if open else "Wkrótce", func(): choose_hero(hid), pic_size.x)
	btn.disabled = not open
	col.add_child(btn)
	panel.set_meta("button", btn)
	return panel

## Wybór bohatera: zapamiętany (SaveData.last_hero) i od razu nowa gra.
func choose_hero(hero_id: String) -> void:
	if not Heroes.is_selectable(hero_id):
		return
	GameState.hero_id = hero_id
	SaveData.last_hero = hero_id
	SaveData.save_all()
	start_game(false)

## Nowa gra zaczyna się prologiem (opis -> karczma z kuflami -> szczury -> opis); Kontynuuj i ponowna próba po porażce go pomijają.
func start_game(continue_save: bool, skip_prologue: bool = false) -> void:
	get_tree().paused = false
	GameState.reset()
	Controls.reset()
	var from_wave := 0
	var resumed: bool = continue_save and SaveData.has_checkpoint()
	if resumed:
		var cp_hero: String = str(SaveData.checkpoint.get("hero", GameState.hero_id))
		if Heroes.is_selectable(cp_hero):
			GameState.hero_id = cp_hero
		from_wave = int(SaveData.checkpoint["wave"])
		GameState.score = int(SaveData.checkpoint.get("score", 0))
		GameState.kills = int(SaveData.checkpoint.get("kills", 0))
	else:
		SaveData.clear_checkpoint()
	if not resumed and not skip_prologue and GameState.story_enabled:
		show_prologue()
		return
	begin_level(from_wave)

func begin_level(from_wave: int) -> void:
	get_tree().paused = false
	Controls.reset()
	var lvl := Level.new({}, from_wave)
	lvl.exit_to_menu.connect(show_menu)
	lvl.restart_requested.connect(func(): start_game(false, true))
	_swap(lvl)

## Prolog (Etap 0) jest bez muzyki - motyw wchodzi dopiero w etapie 1.
func show_prologue() -> void:
	Sfx.stop_music(0.8)
	var pre: Dictionary = StoryScreen.entry_for_phase("pre")
	if pre.is_empty():
		show_tavern()
	else:
		show_story(pre, show_tavern)

func show_story(entry: Dictionary, done: Callable) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sc := StoryScreen.new()
	sc.setup(entry)
	sc.finished.connect(done)
	root.add_child(sc)
	_swap(root)

func show_tavern() -> void:
	var g := TavernGame.new()
	g.finished.connect(func(skipped: bool):
		if skipped:
			begin_level(0)
			return
		var post: Dictionary = StoryScreen.entry_for_phase("post")
		if post.is_empty():
			begin_level(0)
		else:
			show_story(post, func(): begin_level(0)))
	_swap(g)

func show_settings() -> void:
	var root := Control.new()
	root.theme = UI.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bgc := ColorRect.new()
	bgc.color = Color(0.07, 0.04, 0.04)
	bgc.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bgc)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	center.add_child(vb)
	vb.add_child(UI.make_label("USTAWIENIA", 54, Color(0.85, 0.18, 0.14)))
	vb.add_child(_slider_row("Muzyka", SaveData.music_volume, func(v):
		SaveData.music_volume = v
		Sfx.apply_volumes()))
	vb.add_child(_slider_row("Efekty", SaveData.sfx_volume, func(v):
		SaveData.sfx_volume = v
		Sfx.apply_volumes()))
	var touch_btn := UI.make_button("", func(): pass)
	var names := ["Sterowanie dotykowe: auto", "Sterowanie dotykowe: włączone", "Sterowanie dotykowe: wyłączone"]
	touch_btn.text = names[SaveData.touch_mode]
	touch_btn.pressed.connect(func():
		SaveData.touch_mode = (SaveData.touch_mode + 1) % 3
		touch_btn.text = names[SaveData.touch_mode])
	vb.add_child(touch_btn)
	if OS.is_debug_build():
		var dbg_btn := UI.make_button("", func(): pass)
		dbg_btn.text = "Diagnostyka kolizji: " + ("WŁ" if GameState.debug_collision else "wył")
		dbg_btn.pressed.connect(func():
			GameState.debug_collision = not GameState.debug_collision
			dbg_btn.text = "Diagnostyka kolizji: " + ("WŁ" if GameState.debug_collision else "wył"))
		vb.add_child(dbg_btn)
	vb.add_child(UI.make_button("Wróć", func():
		SaveData.save_all()
		show_menu()))
	_swap(root)

func _slider_row(title: String, value: float, cb: Callable) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	var l := UI.make_label(title, 30)
	l.custom_minimum_size = Vector2(160, 0)
	hb.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(420, 48)
	s.value_changed.connect(func(v):
		cb.call(v)
		Sfx.play("ui_click"))
	hb.add_child(s)
	return hb

func show_about() -> void:
	var text := "Ivo Eggert: Obrona Hufduhofu\n\nGwardzista Szkarłatnej Gwardii z Carroburga przedziera się\nprzez Hufduhof i okolice, by stawić czoła czempionowi Chaosu.\n\nSTEROWANIE (PC):  WASD / strzałki - ruch,  J - cięcie,\nK - mocny atak,  Spacja - skok,  L / C - unik,  Esc - pauza\nCombo: cięcie, cięcie, szeroki zamach obszarowy.\nTelefon: joystick po lewej, przyciski po prawej.\n\nAUTORZY: " + AUTHORS
	var box := UI.make_overlay("INFORMACJE", text, [["Wróć", show_menu]])
	box.theme = UI.theme()
	_swap(box)
