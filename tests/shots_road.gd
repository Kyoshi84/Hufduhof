extends Node
## Zrzuty drogi etapu 1: rozdroża, skarpy, bruk, kałuże (xvfb-run godot --path . res://tests/shots_road.tscn).
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
	GameState.god_mode = true
	GameState.story_enabled = false
	lvl = Level.new()
	add_child(lvl)
	await frames(10)
	await at(900, "r01_skarpa")
	await at(1600, "r02_uskok_kaluza")
	await at(2150, "r03_rozdroze_bruk")
	await at(3200, "r04_murek_rozdroze")
	get_tree().quit()
