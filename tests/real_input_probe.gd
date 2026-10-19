extends Node
## Sonda diagnostyczna: prawdziwa ścieżka wejścia (zdarzenia klawiatury) i pętla fizyki, bez trybu symulacji.
var lvl: Level

func key(code: int, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	GameState.story_enabled = false
	lvl = Level.new()
	add_child(lvl)
	await frames(5)
	var p: Player = lvl.player
	p.position = Vector2(1000, 480)
	p.facing = 1
	var results := []
	for dist in [100, 130, 150, 160, 165, 170, 175, 185]:
		var e := Enemy.new()
		e.setup(lvl, "skaven", Vector2(p.position.x + dist, 480))
		lvl.attach_visual(e, "skaven")
		lvl.entities.add_child(e)
		lvl.enemies.append(e)
		e.ai_cd = 999.0
		e.speed = 0.0
		e.depth_speed = 0.0
		p.combo_idx = 0
		e.hp = 1000.0
		e.max_hp = 1000.0
		await frames(2)
		var hp0: float = e.hp
		key(KEY_J, true)
		await frames(2)
		key(KEY_J, false)
		await frames(50)
		results.append("dist %d (krawędź ciała %d): %s" % [dist, dist - 20, "TRAFIENIE" if e.hp < hp0 else "pudło"])
		lvl.remove_enemy(e)
		await frames(40)
		p.position.x = 1000.0
		p.set_state(Actor.State.IDLE)
	for r in results:
		print(r)
	# zasięg wizualny miecza (wzory z ActorVisual._draw_biped) vs hitbox
	var sc: float = ActorVisual.STYLES["ivo"]["scale"]
	var wl: float = ActorVisual.STYLES["ivo"]["wlen"]
	var best := 0.0
	for i in 101:
		var ang: float = lerpf(-2.6, 1.0, i / 100.0)
		var tip_x: float = sc * (0.22 * 46.0 + 6.0 + 14.0 * cos(ang) + wl * cos(ang))
		best = maxf(best, tip_x)
	print("max zasięg narysowanego czubka miecza (light): %.0f; hitbox light1: reach %.0f" % [best, float(p.attack_defs["light1"]["reach"])])
	get_tree().quit()
