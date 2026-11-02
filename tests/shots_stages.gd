extends Node
## Zrzuty etapów 2-4 i przeszkód (xvfb-run godot --path . res://tests/shots_stages.tscn).
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
	var only: String = OS.get_environment("SHOTS_ONLY")
	var list := [
		[5000.0, "s2_wies_a"], [6100.0 - 220.0, "s2_ogien"], [7400.0, "s2_wies_b"],
		[9300.0, "s3_pola"], [9900.0 - 220.0, "s3_pien"], [11800.0, "s3_las"],
		[14200.0 - 220.0, "s4_przepasc"],
	]
	for it in list:
		if only == "" or str(it[1]).begins_with(only):
			await at(float(it[0]), str(it[1]))
	get_tree().quit()
