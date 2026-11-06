extends Node
## Przełączanie ekranów: menu główne -> wybór postaci -> karczma (minigra) -> wioska (Poziom 1)
## -> Poziom 2 (zaślepka "Ciąg dalszy nastąpi" z zapisem gry).

const AUTHORS := "Janek M. i Franek W."
const MENU_PORTRAIT := "res://assets/ui/ivo_portrait.png"

var current: Node = null

func _ready() -> void:
	show_menu()

func _swap(n: Node) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if current != null:
		current.queue_free()
	current = n
	add_child(n)

func _screen_root() -> Control:
	var root := Control.new()
	root.theme = UiKit.theme()
	UiKit.full_rect(root)
	var bg := ColorRect.new()
	bg.color = UiKit.BG
	UiKit.full_rect(bg)
	root.add_child(bg)
	return root

# ---------------------------------------------------------------- menu główne (wygląd jak w poprzedniej wersji)
func show_menu() -> void:
	Controls.reset()
	Audio.play_track("menu")
	var root := _screen_root()
	root.name = "MainMenu"
	var hb := HBoxContainer.new()
	UiKit.full_rect(hb)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 40)
	root.add_child(hb)
	if ResourceLoader.exists(MENU_PORTRAIT):
		var tr := TextureRect.new()
		tr.texture = load(MENU_PORTRAIT)
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
	vb.add_child(UiKit.label("HUFDUHOF", 64, UiKit.RED))
	vb.add_child(UiKit.label("Szczury w wiosce", 34, UiKit.GOLD))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	vb.add_child(gap)
	var ng := UiKit.button("Nowa gra", show_character_select, 420, 62)
	vb.add_child(ng)
	var cont := UiKit.button("Kontynuuj", continue_game, 420, 62)
	cont.disabled = not Save.has_save()
	vb.add_child(cont)
	vb.add_child(UiKit.button("Ustawienia", func(): _swap(_wrap(SettingsScreen.build(show_menu))), 420, 62))
	vb.add_child(UiKit.button("Informacje o grze", show_about, 420, 62))
	var credits := UiKit.outlined(UiKit.label("Autorzy: " + AUTHORS, 22, Color(0.8, 0.72, 0.55)))
	credits.name = "Credits"
	credits.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	credits.offset_top = -48
	credits.offset_bottom = -12
	credits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(credits)
	_swap(root)
	(cont if not cont.disabled else ng).call_deferred("grab_focus")

func _wrap(c: Control) -> Control:
	var root := _screen_root()
	root.add_child(c)
	return root

func show_about() -> void:
	var text := "Izometryczny hack and slash w klimacie Warhammer Fantasy.\nSzczuroludzie napadli Hufduhof - ugaś barykadę i wyprowadź się z wioski.\n\nPC: WASD - ruch, lewy przycisk myszy / J - atak, prawy / K - umiejętność,\nQ - mikstura życia, R - mikstura many, E - interakcja, M - mapa, C - postać, I - plecak, Esc - pauza.\nTelefon: joystick po lewej, przyciski po prawej.\n\nAutorzy: " + AUTHORS
	_swap(_wrap(UiKit.overlay("INFORMACJE", text, [["Wróć", show_menu]])))

# ---------------------------------------------------------------- wybór postaci
func show_character_select() -> void:
	var root := _screen_root()
	root.name = "CharacterSelect"
	var center := CenterContainer.new()
	UiKit.full_rect(center)
	root.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	center.add_child(vb)
	vb.add_child(UiKit.label("WYBIERZ BOHATERA", 42, UiKit.RED))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)
	var focus: Button = null
	for id in Data.hero_ids():
		var card := _hero_card(str(id))
		row.add_child(card)
		if str(id) == Save.last_hero:
			focus = card.get_meta("button")
	var back := UiKit.button("Wróć", show_menu, 240, 50)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(back)
	_swap(root)
	if focus:
		focus.call_deferred("grab_focus")

func _hero_card(id: String) -> Control:
	var d := Data.hero(id)
	var panel := PanelContainer.new()
	panel.name = "Hero_" + id
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	col.add_child(UiKit.icon(str(d.get("portret", "")), 210))
	col.add_child(UiKit.label(str(d.get("imie", id)), 28, UiKit.GOLD))
	col.add_child(UiKit.label(str(d.get("tytul", "")), 16, UiKit.DIM))
	var desc := UiKit.label(str(d.get("opis", "")), 14, UiKit.TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(330, 62)
	col.add_child(desc)
	col.add_child(ProfileTable.build(Stats.from_profile(d.get("profil", {})), null, Callable(), 40))
	var btn := UiKit.button("Wybierz", func(): choose_hero(id), 330, 50)
	col.add_child(btn)
	panel.set_meta("button", btn)
	return panel

func choose_hero(id: String) -> void:
	Save.last_hero = id
	Save.save_settings()
	Game.new_game(id)
	show_tavern_intro()

func show_tavern_intro() -> void:
	var root := _screen_root()
	var card := TextureRect.new()
	card.texture = load("res://assets/levels/tavern/tavern_card.png")
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	UiKit.full_rect(card)
	card.modulate = Color(0.55, 0.5, 0.5)
	root.add_child(card)
	var text := "Hufduhof, wieczór po żniwach.\n\nW karczmie \"Pod Złotym Kuflem\" trwa zabawa: karczmarz ciska kuflami z lady, a Borubar śpiewa\no Sigmarze tak głośno, że nikt nie słyszy drapania pod podłogą...\n\n%s wznosi kufel. Jeszcze nie wie, że to ostatni spokojny wieczór w Hufduhofie." % Game.hero.display_name()
	var ov := UiKit.overlay("KARCZMA", text, [["Dalej", func(): start_level("karczma")], ["Pomiń minigrę", func():
		Game.level_id = "wioska"
		Game.give_xp(int(Data.bal("xp_zadania/karczma_obroniona", 20)))
		start_level("wioska")]])
	root.add_child(ov)
	_swap(root)

# ---------------------------------------------------------------- poziomy
func start_level(key: String) -> void:
	Controls.reset()
	Game.level_id = key
	var lvl: Level = Tavern.new() if key == "karczma" else Level.new(key)
	lvl.name = "Level_" + key
	lvl.request.connect(_on_level_request)
	_swap(lvl)

func _on_level_request(what: String) -> void:
	match what:
		"menu":
			show_menu()
		"wioska":
			start_level("wioska")
		"poziom2":
			show_level2()
		"wczytaj":
			continue_game()
		"karczma_od_nowa":
			Game.new_game(Game.hero.id if Game.hero else Save.last_hero)
			start_level("karczma")

func continue_game() -> void:
	if not Save.load_game():
		show_menu()
		return
	if Game.level_id == "poziom2":
		show_level2()
	else:
		start_level(Game.level_id)

func show_level2() -> void:
	Game.level_id = "poziom2"
	Save.save_game(Vector2.ZERO)
	Audio.play_track("menu")
	var root := _screen_root()
	root.name = "Level2"
	var h: HeroState = Game.hero
	var txt := "Brama Hufduhofu za tobą. Droga prowadzi przez spalone pola w stronę lasu...\n\n%s  -  doświadczenie: %d, korony: %d\n\nGra została zapisana. Poziom 2 powstaje." % [h.display_name(), h.xp, h.inv.gold]
	root.add_child(UiKit.overlay("CIĄG DALSZY NASTĄPI", txt, [["Menu główne", show_menu]]))
	_swap(root)
