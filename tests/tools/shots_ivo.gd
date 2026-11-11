extends SceneTree
## Zrzuty animacji Ivo w wiosce (xvfb-run -a godot --path . -s res://tests/tools/shots_ivo.gd -- <katalog>).
## Ustawia klatki ręcznie: chód, cios, Potężne cięcie, Wirujący miecz, okrzyk, trafienie, śmierć (east i west) oraz pozę south.
var main: Node
var out := "user://shots"

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

func _run() -> void:
	await _wait(10)
	main.choose_hero("ivo")
	main.start_level("wioska")
	await _wait(60)
	var lvl: Level = main.current
	for e in lvl.enemies():
		e.queue_free()
	lvl.hero.position = Iso.cell_center(Vector2i(34, 34))
	lvl.cam.reset_smoothing()
	await _wait(60)                      # mgła odsłonięta, kamera na miejscu - dopiero teraz zatrzymujemy bohatera
	lvl.hero.set_process(false)
	lvl.hero.set_physics_process(false)
	var g: DirSprite = lvl.hero.gfx
	g.set_process(false)
	var poses := [["idle", "south", 0], ["idle", "east", 0], ["walk", "east", 0], ["walk", "west", 2], ["attack", "east", 3],
		["heavy", "east", 3], ["heavy", "west", 1], ["whirl", "east", 3], ["shout", "east", 2], ["hurt", "east", 0],
		["death", "east", 5], ["death", "south-west", 5]]
	for p in poses:
		var n := g.frame_count(p[0], p[1])
		g.set_progress(p[0], (float(p[2]) + 0.5) / maxf(1.0, n), p[1])
		g._apply()
		await _wait(4)
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("%s/ivo_%s_%s_%d.png" % [out, p[0], p[1], p[2]])
		print("zrzut: ", p)
	quit()
