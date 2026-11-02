extends Node
## Zrzuty plansz po wsi i lesie (okno na portret) oraz HUD z limitem punktów etapu.
var out_dir := "/home/claude/shots"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	run.call_deferred()

func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, n])
	print("zapisano ", n)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func board(stage: int, page: int, name: String) -> void:
	var sc := StoryScreen.new()
	sc.setup(StoryScreen.entry_after_stage(stage))
	add_child(sc)
	await frames(2)
	sc.show_page(page)
	sc.advance()
	await frames(4)
	await shot(name)
	sc.queue_free()
	await frames(2)

func run() -> void:
	await board(1, 0, "b1_borubar")
	await board(2, 3, "b2_czempion")
	GameState.god_mode = true
	GameState.story_enabled = false
	var lvl := Level.new()
	add_child(lvl)
	await frames(10)
	lvl.waves = []
	lvl.stage_points[0] = 23
	lvl.player.position = Vector2(lvl.stage_end(0) - 300.0, 480)
	lvl.view_left = lvl.stage_end(0) - lvl.view_w
	await frames(200)
	await shot("b3_bramka_posilki")
	get_tree().quit()
