extends Node
## Zrzuty przeszkód-zadań (etap 1 zadań): barykada, płonący wóz ze studnią, wrak, nora szczurów, most z cegieł.
## Uruchom z prawdziwym renderowaniem: xvfb-run godot --path . res://tests/shots_puzzles.tscn (katalog: SHOTS_DIR).
var out_dir := "/home/claude/shots"
var lvl: Level

func _ready() -> void:
	if OS.get_environment("SHOTS_DIR") != "":
		out_dir = OS.get_environment("SHOTS_DIR")
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

func ob(type: String) -> Obstacle:
	for o in lvl.obstacles:
		if o.type == type:
			return o
	return null

func at(x: float, y: float, name: String, wait: int = 40) -> void:
	lvl.player.position = Vector2(x, y)
	lvl.view_left = x - 420.0
	await frames(wait)
	await shot(name)

func run() -> void:
	GameState.god_mode = true
	GameState.story_enabled = false
	lvl = Level.new()
	add_child(lvl)
	await frames(10)
	lvl.waves = []
	var bar := ob("barricade")
	await at(bar.x0() - 160.0, 470.0, "p01_barykada")
	bar.h = 70.0
	await at(bar.x0() - 160.0, 470.0, "p02_barykada_porabana")
	var cart := ob("burning_cart")
	lvl.player.carry = "bucket"
	await at(cart.x0() - 260.0, 520.0, "p03_plonacy_woz_wiadro")
	lvl.player.carry = ""
	await at(ob("well").position.x - 120.0, 440.0, "p04_studnia")
	cart.water_left = 1
	await at(cart.x0() - 260.0, 520.0, "p05_woz_po_pierwszym_wiadrze")
	cart.water_left = 0
	cart.state = "out"
	cart.kind = "none"
	await at(cart.x0() - 260.0, 520.0, "p06_wrak")
	var hole: RatHole = lvl.rat_holes[0]
	await at(hole.position.x - 300.0, 500.0, "p07_nora_szczurow", 360)
	hole.hits = 3
	hole.alive = false
	for e in lvl.enemies:
		e.hp = 0.0
		e.die(1, {})
	await at(hole.position.x - 300.0, 500.0, "p08_nora_zniszczona", 90)
	var riv := ob("river_bridge")
	lvl.player.bricks = 2
	riv.bricks_placed = 3
	await at(riv.x0() - 200.0, 480.0, "p09_most_3z5")
	riv.bricks_placed = 5
	riv.state = "built"
	riv.kind = "none"
	await at(riv.x0() - 120.0, 480.0, "p10_most_gotowy")
	var ch := ob("chasm_bridge")
	await at(ch.x0() - 200.0, 480.0, "p11_szeroka_przepasc")
	get_tree().quit()
