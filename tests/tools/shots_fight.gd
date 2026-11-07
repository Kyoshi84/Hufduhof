extends SceneTree
## Zrzut walki: Ursa strzela do grupy skavenów (pasek, liczby obrażeń, pociski). Tryb diagnostyki F3 na drugim zrzucie.
var out := "user://shots"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	_run()

func _wait(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	await _wait(5)   # autoloady (Data) wczytują dane w pierwszej klatce
	var game = root.get_node("Game")
	root.get_node("Save").save_path = "user://test_fight.json"
	game.new_game("ursa")
	game.level_id = "wioska"
	var lvl = load("res://scripts/levels/level.gd").new("wioska")
	root.add_child(lvl)
	await _wait(20)
	lvl.hero.position = Iso.cell_center(Vector2i(42, 33))
	lvl.hero.blessed = 100.0
	lvl.cam.reset_smoothing()
	await _wait(30)
	for k in 2:
		Input.action_press("slot_1")
		await _wait(14 + k * 4)
		Input.action_release("slot_1")
		root.get_viewport().get_texture().get_image().save_png(out + "/walka_%d.png" % k)
		game.debug_collision = true
	quit(0)
