extends Node
## Przełączanie ekranów: menu główne, ustawienia, informacje, poziom.

var current: Node = null
const PORTRAIT := "res://assets/ui/ivo_portrait.png"

func _ready() -> void:
	add_child(PaletteFilter.new())
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
	vb.add_child(UI.make_label("IVO EGGERT", 64, Color(0.85, 0.18, 0.14)))
	vb.add_child(UI.make_label("Obrona Hufduhofu", 36, Color(0.9, 0.78, 0.45)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	vb.add_child(gap)
	vb.add_child(UI.make_button("Nowa gra", func(): start_game(false)))
	var cont := UI.make_button("Kontynuuj", func(): start_game(true))
	cont.disabled = not SaveData.has_checkpoint()
	vb.add_child(cont)
	vb.add_child(UI.make_button("Ustawienia", show_settings))
	vb.add_child(UI.make_button("Informacje o grze", show_about))
	if SaveData.best_score > 0:
		vb.add_child(UI.make_label("Najlepszy wynik: %d" % SaveData.best_score, 24, Color(0.8, 0.75, 0.62)))
	_swap(root)

## Nowa gra zaczyna się prologiem (opis -> karczma z kuflami -> szczury -> opis); Kontynuuj i ponowna próba po porażce go pomijają.
func start_game(continue_save: bool, skip_prologue: bool = false) -> void:
	get_tree().paused = false
	GameState.reset()
	Controls.reset()
	var from_wave := 0
	var resumed: bool = continue_save and SaveData.has_checkpoint()
	if resumed:
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
	var text := "Ivo Eggert: Obrona Hufduhofu\n\nGwardzista Szkarłatnej Gwardii z Carroburga przedziera się\nprzez Hufduhof i okolice, by stawić czoła czempionowi Chaosu.\n\nSTEROWANIE (PC):  WASD / strzałki - ruch,  J - cięcie,\nK - mocny atak,  L / Spacja - unik,  Esc - pauza\nCombo: cięcie, cięcie, szeroki zamach obszarowy.\nTelefon: joystick po lewej, przyciski po prawej."
	var box := UI.make_overlay("INFORMACJE", text, [["Wróć", show_menu]])
	box.theme = UI.theme()
	_swap(box)
