extends Node
## Zrzuty nowości: menu z herbem, przeszkody, wieś z uciekinierami, las (gęstnienie), legowisko, spaczenie.
var out_dir := "/home/claude/shots"
var lvl: Level

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	add_child(PaletteFilter.new())
	run.call_deferred()

func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
	print("zapisano ", n)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func at(x: float, name: String, wait: int = 40) -> void:
	lvl.waves = []
	lvl.player.position = Vector2(x, 480)
	lvl.view_left = x - 300.0
	await frames(wait)
	await shot(name)

func run() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await frames(10)
	await shot("n01_menu")
	main.queue_free()
	await frames(2)
	GameState.god_mode = true
	GameState.story_enabled = false
	lvl = Level.new()
	add_child(lvl)
	await frames(10)
	await at(1500 - 220, "n02_puddle")
	await at(7800 - 220, "n03b_fire2")
	await at(6100 - 220, "n03_fire")
	await at(5000, "n04_village", 120)
	await at(10700 - 220, "n05_river")
	await at(9000, "n06_forest_start")
	await at(11800, "n07_forest_mid")
	await at(13000, "n08_forest_end")
	await at(14200 - 220, "n09_chasm")
	await at(15300, "n10_lair")
	await at(16100, "n11_lair2")
	get_tree().quit()
