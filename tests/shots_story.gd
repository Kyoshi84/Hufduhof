extends Node
## Zrzuty ekranów fabularnych (wymaga prawdziwego renderowania, np. xvfb): prolog w poziomie + strony z lasu i czempiona.
var out_dir := "/home/claude/shots"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out_dir)
	add_child(PaletteFilter.new())
	run.call_deferred()

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("zapisano ", name)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func run() -> void:
	GameState.story_enabled = true
	var lvl := Level.new()
	add_child(lvl)
	await frames(10)
	print("gra wstrzymana na starcie: ", get_tree().paused, ", ekran: ", lvl.overlay is StoryScreen)
	var sc: StoryScreen = lvl.overlay
	await frames(20)
	await shot("40_story_pisanie")
	sc.advance()
	await frames(2)
	await shot("41_story_prolog_s1")
	sc.advance(); sc.advance(); sc.advance()
	await frames(2)
	await shot("42_story_prolog_s2_dialog")
	sc.skip_all()
	await frames(20)
	print("po zakończeniu: paused=", get_tree().paused, " story_active=", lvl.story_active)
	await shot("43_poziom_po_prologu")
	lvl.queue_free()
	await frames(2)
	for pair in [[1, 1, "44_story_las_s2"], [2, 0, "45_story_czempion_s1"], [2, 2, "46_story_czempion_s3"]]:
		var e: Dictionary = StoryScreen.load_entries()[pair[0]]
		var s2 := StoryScreen.new()
		s2.setup(e)
		var cl := CanvasLayer.new()
		add_child(cl)
		cl.add_child(s2)
		await frames(3)
		for i in int(pair[1]):
			s2.advance(); s2.advance()
		s2.advance()
		await frames(2)
		await shot(pair[2])
		cl.queue_free()
		await frames(2)
	print("KONIEC")
	get_tree().quit()
