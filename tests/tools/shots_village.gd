extends SceneTree
## Zrzuty wioski w kilku miejscach (xvfb-run godot --path . -s res://tests/tools/shots_village.gd -- <katalog> [bohater]).
var out := "user://shots"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	_run(args[1] if args.size() > 1 else "modraszka")

func _wait(n: int) -> void:
	for i in n:
		await process_frame

func _run(hid: String) -> void:
	await _wait(5)
	var game = root.get_node("Game")
	root.get_node("Save").save_path = "user://test_shots_village.json"
	game.new_game(hid)
	game.level_id = "wioska"
	var lvl = load("res://scripts/levels/level.gd").new("wioska")
	root.add_child(lvl)
	await _wait(20)
	lvl.hero.blessed = 1000.0
	lvl.map.fog_layer.visible = false
	var spots := {"brama": Vector2i(48, 6), "ruina_tunel": Vector2i(34, 44), "plac": Vector2i(34, 34), "cmentarz": Vector2i(32, 13),
		"start": Vector2i(9, 50), "dom_deski": Vector2i(38, 27), "tunel_wschod": Vector2i(46, 33)}
	for name in spots:
		lvl.hero.position = Iso.cell_center(spots[name])
		lvl.cam.reset_smoothing()
		await _wait(50 if name.contains("tunel") else 25)
		root.get_viewport().get_texture().get_image().save_png("%s/wies_%s.png" % [out, name])
		print("zrzut: ", name)
	quit(0)
