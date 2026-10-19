extends Node
## Robi zrzuty ekranu kluczowych momentów (wymaga prawdziwego renderowania, np. xvfb).

var out_dir := "/home/claude/shots"
var lvl: Level

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	add_child(PaletteFilter.new())
	run.call_deferred()

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])
	print("zapisano ", name)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func put(type: String, dx: float, dy: float, facing: int = -1) -> Enemy:
	var e: Enemy = Boss.new() if type == "chaos_champion" else Enemy.new()
	e.setup(lvl, type, Vector2(lvl.player.position.x + dx, dy))
	lvl.attach_visual(e, type)
	lvl.entities.add_child(e)
	lvl.enemies.append(e)
	if e is Boss:
		lvl.boss = e
	e.facing = facing
	return e

func run() -> void:
	# menu
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await frames(10)
	await shot("01_menu")
	main.queue_free()
	await frames(2)
	# poziom
	GameState.god_mode = true
	GameState.story_enabled = false
	lvl = Level.new()
	add_child(lvl)
	await frames(30)
	await shot("02_start")
	# etap 1: skaveni
	lvl.player.position.x = 920
	lvl.view_left = 600.0
	await frames(100)
	await shot("03_skaveni")
	# wieś, psy i skaveni
	for e in lvl.enemies.duplicate():
		e.hp = 0.0
		e.die(1, { "knockback": 10.0 })
	lvl.wave_active = false
	lvl.locked = false
	lvl.player.position.x = 2500
	lvl.view_left = 2100.0
	lvl.next_wave = 99
	await frames(30)
	put("skaven", 260, 440)
	put("skaven", -230, 520, 1)
	put("chaos_hound", 380, 560)
	lvl.player.start_attack("sweep", lvl.player.attack_defs["sweep"])
	await frames(32)
	await shot("04_wies_sweep")
	# pola: zwierzoludzie, atak ciężki
	for e in lvl.enemies.duplicate():
		e.ai_cd = 99.0
		e.hp = 0.0
		e.die(1, { "knockback": 10.0 })
	await frames(80)
	lvl.player.position.x = 4600
	lvl.view_left = 4200.0
	await frames(20)
	var b := put("beastman", 150, 500)
	b.ai_cd = 0.0
	put("beastman", 330, 430)
	await frames(50)
	lvl.player.start_attack("heavy", lvl.player.attack_defs["heavy"])
	await frames(40)
	await shot("05_pola_beastman")
	# legowisko + boss
	for e in lvl.enemies.duplicate():
		e.hp = 0.0
		e.die(1, { "knockback": 10.0 })
	await frames(80)
	lvl.player.position = Vector2(6500, 500)
	lvl.view_left = 6320.0
	lvl.locked = true
	lvl.lock_left = 6320.0
	await frames(20)
	var boss := put("chaos_champion", 260, 480)
	boss.ai_cd = 99.0
	lvl.hud.show_banner("CZEMPION CHAOSU", 5.0)
	await frames(60)
	boss.facing = -1
	boss.start_attack("slam", boss.attack_defs["slam"])
	await frames(45)
	await shot("06_boss_telegraf")
	boss.hp = boss.max_hp * 0.5
	boss.invuln = 0.0
	boss.receive_hit(lvl.player, lvl.player.attack_defs["light1"])
	await frames(150)
	await shot("07_boss_faza2")
	lvl.toggle_pause()
	await frames(5)
	await shot("08_pauza")
	lvl.resume()
	lvl.player.hp = 0.0
	lvl.player.die(1, { "knockback": 100.0 })
	await frames(130)
	await shot("09_porazka")
	print("KONIEC")
	get_tree().quit()
