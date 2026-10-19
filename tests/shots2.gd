extends Node
## Zrzuty kontrolne grafiki: bestiariusz, 8 kierunków Ivo, faza aktywna ciosu + diagnostyka, etapy.
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

func put(type: String, x: float, y: float, facing: int = -1) -> Enemy:
	var e: Enemy = Boss.new() if type == "chaos_champion" else Enemy.new()
	e.setup(lvl, type, Vector2(x, y))
	lvl.attach_visual(e, type)
	lvl.entities.add_child(e)
	lvl.enemies.append(e)
	e.ai_cd = 99999.0
	e.speed = 0.0
	e.depth_speed = 0.0
	e.facing = facing
	if e is Boss:
		lvl.boss = e
	return e

func go_to(x: float) -> void:
	lvl.player.position.x = x
	lvl.view_left = x - 540.0
	lvl.next_wave = 99
	await frames(8)

func run() -> void:
	GameState.god_mode = true
	lvl = Level.new()
	add_child(lvl)
	await frames(10)
	lvl.hud.banner_t = 0.0
	lvl.hud.banner_label.visible = false
	# --- bestiariusz (wieś)
	await go_to(2600.0)
	lvl.player.position = Vector2(2330, 520)
	var sk1 := put("skaven", 2480, 470)
	var sk2 := put("skaven", 2560, 540)
	sk2.start_attack("claw", sk2.attack_defs["claw"])
	sk2.state_t = 0.14
	var hd1 := put("chaos_hound", 2700, 440)
	var hd2 := put("chaos_hound", 2820, 520)
	hd2.start_attack("charge", hd2.attack_defs["charge"])
	hd2.state_t = 0.4
	var bm := put("beastman", 2960, 500)
	bm.start_attack("chop", bm.attack_defs["chop"])
	bm.state_t = 0.4
	await frames(2)
	await shot("20_bestiariusz_wies")
	# --- boss
	for e in lvl.enemies.duplicate():
		lvl.remove_enemy(e)
	await frames(2)
	await go_to(6500.0)
	lvl.player.position = Vector2(6300, 520)
	var boss := put("chaos_champion", 6620, 500)
	await frames(30)
	await shot("21_boss_idle")
	boss.facing = -1
	boss.start_attack("overhead", boss.attack_defs["overhead"])
	boss.state_t = 0.6
	await frames(1)
	await shot("22_boss_telegraf")
	lvl.remove_enemy(boss)
	# --- Ivo 8 kierunków
	await go_to(2600.0)
	lvl.player.position = Vector2(0, 0)
	lvl.player.visible = false
	var names := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	var pls: Array = []
	for i in 8:
		var pl := Player.new()
		pl.setup(lvl)
		pl.position = Vector2(2160 + i * 100, 500)
		lvl.attach_visual(pl, "ivo")
		lvl.entities.add_child(pl)
		pl.aim_dir = names[i]
		pls.append(pl)
	await frames(4)
	await shot("23_ivo_8_kierunkow")
	for pl in pls:
		pl.queue_free()
	lvl.player.visible = true
	# --- cios z diagnostyką
	await go_to(2600.0)
	lvl.player.position = Vector2(2500, 500)
	lvl.player.facing = 1
	var t1 := put("skaven", 2630, 505, -1)
	var t2 := put("beastman", 2760, 500, -1)
	var t3 := put("skaven", 2600, 560, -1)
	t1.hp = 999; t2.hp = 999; t3.hp = 999
	t1.max_hp = 999; t2.max_hp = 999; t3.max_hp = 999
	lvl.player.start_attack("light1", lvl.player.attack_defs["light1"])
	lvl.player.set_state(Actor.State.ACTIVE)
	lvl.player.state_t = 0.05
	GameState.debug_collision = true
	await frames(1)
	await shot("24_cios_diagnostyka")
	GameState.debug_collision = false
	for e in lvl.enemies.duplicate():
		lvl.remove_enemy(e)
	lvl.player.start_attack("sweep", lvl.player.attack_defs["sweep"])
	lvl.player.set_state(Actor.State.ACTIVE)
	lvl.player.state_t = 0.06
	await frames(1)
	await shot("25_sweep")
	# --- etapy
	lvl.player.set_state(Actor.State.IDLE)
	for st in [[600.0, "30_etap1"], [2200.0, "31_etap2"], [4400.0, "32_etap3"], [6500.0, "33_etap4"]]:
		await go_to(st[0])
		lvl.player.position.y = 500
		await frames(20)
		await shot(st[1])
	print("KONIEC")
	get_tree().quit()
