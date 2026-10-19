extends Node
## Zrzuty prologu w karczmie (wymaga prawdziwego renderowania, np. xvfb): gra, ogłuszenie, scena ze szczurami.
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

func until(g: TavernGame, cut_time: float) -> void:
	var guard := 0
	while g.cut_t < cut_time and guard < 600:
		await get_tree().process_frame
		guard += 1

func run() -> void:
	var g := TavernGame.new()
	add_child(g)
	g.input_override = 0.0
	await frames(5)
	# Borubar łapie: ustawiamy się pod kuflem
	g.drop_mug(g.boru_x + 160.0, false, 260.0)
	g.drop_mug(g.boru_x - 40.0, true, 200.0)
	g.caught = 17
	await frames(50)
	await shot("50_karczma_gra")
	g.stun = 0.6
	await frames(3)
	await shot("51_karczma_ogluszony")
	g.stun = 0.0
	g.caught = 49
	g.drop_mug(g.boru_x, false, 600.0)
	await frames(30)
	await shot("52_karczma_50")
	var steps := 0
	while g.phase != TavernGame.Phase.CUTSCENE and steps < 300:
		await frames(1); steps += 1
	await until(g, 1.0)
	await shot("53_scena_drzwi")
	await until(g, 2.4)
	await shot("54_scena_szczury")
	await until(g, 3.3)
	await shot("55_scena_ivo")
	g.queue_free()
	await frames(2)
	get_tree().quit()
