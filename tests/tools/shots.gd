extends SceneTree
## Zrzuty ekranu z prawdziwym renderowaniem (xvfb-run godot --path . -s res://tests/tools/shots.gd -- <katalog>).
## Przechodzi: menu, wybór postaci, karczma, wioska (z bohaterem w kilku miejscach), ekran postaci, plecak, mapa.
var main: Node
var out := "user://shots"
var step := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.get_node("Save").save_path = "user://test_zapis.json"
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	_run()

func _wait(n: int) -> void:
	for i in n:
		await process_frame

func _shot(name: String) -> void:
	await _wait(3)
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out + "/" + name + ".png")
	print("zrzut: ", name)

func _run() -> void:
	await _wait(10)
	await _shot("01_menu")
	main.show_character_select()
	await _shot("02_wybor_postaci")
	var hero_id := "ivo"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("hero="):
			hero_id = a.substr(5)
	main.choose_hero(hero_id)
	await _shot("03_karczma_intro")
	main.start_level("karczma")
	await _wait(120)
	await _shot("04_karczma")
	var lvl: Level = main.current
	lvl._break_in()
	await _wait(100)
	await _shot("05_karczma_skaveny")
	await _wait(120)
	await _shot("06_karczma_walka")
	main.start_level("wioska")
	await _wait(60)
	await _shot("07_wioska_start")
	lvl = main.current
	lvl.hero.position = Iso.cell_center(Vector2i(34, 34))
	lvl.cam.reset_smoothing()
	await _wait(40)
	await _shot("08_wioska_plac")
	lvl.hero.position = Iso.cell_center(Vector2i(48, 9))
	await _wait(40)
	await _shot("09_wioska_barykada")
	lvl.hero.position = Iso.cell_center(Vector2i(20, 39))
	await _wait(60)
	await _shot("10_wioska_kuznia")
	lvl.toggle_map()
	await _shot("11_mapa")
	lvl.toggle_map()
	root.get_node("Game").hero.add_xp(200)
	lvl.open_character()
	await _shot("12_postac")
	lvl.close_overlay()
	root.get_node("Game").hero.inv.add_item(Loot.make_item("kolczuga", null, 1))
	root.get_node("Game").hero.inv.add_item(Loot.make_item("topor", null, -1))
	lvl.open_inventory("borubar")
	await _shot("13_handel")
	lvl.close_overlay()
	main.show_level2()
	await _shot("14_poziom2")
	quit(0)
