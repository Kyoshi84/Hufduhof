extends GutTest
## Trafienia: pocisk wystrzelony w stojącego wroga w zasięgu trafia ZAWSZE (8 kierunków, skosy, różne FPS),
## cios wręcz Ivo trafia wroga w łuku, celowanie liczone przy wypuszczeniu, klik w korpus, pomoc w celowaniu.

var lvl: Level

func before_each():
	Save.save_path = "user://test_hits_zapis.json"
	Game.new_game("ursa")
	Game.level_id = "wioska"
	lvl = Level.new("wioska")
	add_child(lvl)
	await wait_frames(3)
	for e in lvl.enemies():
		e.queue_free()
	await wait_frames(2)
	_open_field()

## Testy sprawdzają mechanikę pocisku, nie układ mapy: usuwamy ściany, żeby cel nie stał za płotem.
func _open_field() -> void:
	lvl.map.walls.free()
	lvl.hero.blessed = 1000.0
	lvl.hero.use_mouse_aim = false

func after_each():
	lvl.queue_free()
	await wait_frames(2)
	Engine.time_scale = 1.0

func _swap(id: String) -> void:
	lvl.queue_free()
	await wait_frames(2)
	Game.new_game(id)
	lvl = Level.new("wioska")
	add_child(lvl)
	await wait_frames(3)
	for e in lvl.enemies():
		e.queue_free()
	await wait_frames(2)
	_open_field()

## Stojący, nieaktywny wróg (bez AI), dużo życia, żeby przeżył serię strzałów.
func _dummy(pos: Vector2) -> Enemy:
	var e := lvl.spawn_enemy("skaven_spear", pos, "", "")
	e.set_physics_process(false)
	e.hp = 99999.0
	e.stats.set_base("Zr", 100)   # nawet najlepszy unik nie zamienia trafienia w pudło
	return e

## Ręczne prowadzenie pocisku stałym krokiem czasu (symulacja danego FPS).
func _fly(dt: float) -> void:
	for n in lvl.map.world.get_children():
		if n is Projectile:
			n.set_physics_process(false)
	for i in 2000:
		var any := false
		for n in lvl.map.world.get_children():
			if n is Projectile and not n.is_queued_for_deletion() and not n._done:
				n.step(dt)
				any = true
		if not any:
			break

func _projectile_hit_matrix(skill_id: String) -> void:
	var sk: Dictionary = lvl.hero.skills[skill_id]
	var reach := float(sk["zasieg"])
	var hero_pos := lvl.hero.position
	var total := 0
	var hits := 0
	var angles: Array = []
	for i in 8:
		angles.append(i * 45.0)
	angles.append_array([12.0, 33.0, 67.0, 101.0, 158.0, 199.0, 247.0, 291.0, 333.0])
	for fps in [15.0, 30.0, 60.0, 144.0]:
		for ang in angles:
			for dist in [60.0, reach * 0.5, reach - 20.0]:
				var pos: Vector2 = hero_pos + Iso.screen(Vector2.RIGHT.rotated(deg_to_rad(ang)) * dist)
				var e := _dummy(pos)
				var hp0 := e.hp
				lvl.hero._shoot(sk, (pos - hero_pos).normalized(), true)
				_fly(1.0 / fps)
				total += 1
				if e.hp < hp0:
					hits += 1
				else:
					gut.p("PUDŁO: %s fps=%d kąt=%d dyst=%d" % [skill_id, fps, ang, dist])
				e.free()
	assert_eq(hits, total, "%s: trafienia %d/%d" % [skill_id, hits, total])

func test_ursa_fire_bolt_always_hits_standing_enemy():
	_projectile_hit_matrix("ognisty_pocisk")

func test_ursa_piercing_flame_hits_all_in_line():
	var sk: Dictionary = lvl.hero.skills["przebijajacy_plomien"]
	var dir := Iso.screen(Vector2(1, 0.6).normalized())
	var es: Array = []
	for d in [80.0, 160.0, 240.0, 320.0]:
		es.append(_dummy(lvl.hero.position + dir * d))
	lvl.hero._shoot(sk, dir.normalized(), true)
	_fly(1.0 / 30.0)
	for e in es:
		assert_true(e.hp < 99999.0, "płomień przebija wszystkich w linii")

func test_modraszka_arrow_always_hits_standing_enemy():
	await _swap("modraszka")
	_projectile_hit_matrix("strzala")

func test_ivo_cut_hits_in_all_directions():
	await _swap("ivo")
	var sk: Dictionary = lvl.hero.skills["potezne_ciecie"]
	for i in 8:
		var dir := Iso.screen(Vector2.RIGHT.rotated(deg_to_rad(i * 45.0)))
		var e := _dummy(lvl.hero.position + dir * (float(sk["zasieg"]) - 5.0))
		lvl.hero.aim = dir.normalized()
		var hits: Array = lvl.hero._melee(sk)
		assert_has(hits, e, "cięcie w kierunku %d°" % (i * 45))
		e.free()
		await wait_frames(1)

func test_aim_is_taken_at_release_not_at_windup_start():
	var e := _dummy(lvl.hero.position + Vector2(220, 0))
	assert_eq(lvl.hero.try_skill("ognisty_pocisk"), "ok")
	e.position = lvl.hero.position + Iso.screen(Vector2(0, 200))   # wróg przesunął się w trakcie zamachu
	await wait_seconds(0.3)
	var want := (e.position - lvl.hero.position).normalized()
	assert_almost_eq(lvl.hero.last_shot_dir.angle_to(want), 0.0, 0.05, "strzał leci w aktualną pozycję wroga")

func test_mouse_on_enemy_torso_aims_at_its_feet():
	var e := _dummy(lvl.hero.position + Vector2(260, -40))
	lvl.hero.use_mouse_aim = true
	lvl.hero.mouse_world = e.position + Vector2(0, -60)   # kursor na korpusie
	var d: Vector2 = lvl.hero._aim_dir(460.0, true)
	assert_almost_eq(d.angle_to((e.position - lvl.hero.position).normalized()), 0.0, 0.01)

func test_mouse_ground_aim_has_height_correction():
	lvl.hero.use_mouse_aim = true
	lvl.hero.mouse_world = lvl.hero.position + Vector2(300, 0)
	var d: Vector2 = lvl.hero._aim_dir(460.0, true)
	var want := (Vector2(300, float(Data.bal("celowanie/wysokosc_pocisku", 48)))).normalized()
	assert_almost_eq(d.angle_to(want), 0.0, 0.01, "pocisk leci tak, by jego obrazek przeleciał przez kursor")

func test_soft_aim_corrects_small_error_but_not_large():
	var sk: Dictionary = lvl.hero.skills["ognisty_pocisk"]
	var to_e := Iso.screen(Vector2(1, 0))
	var e := _dummy(lvl.hero.position + to_e * 300.0)
	var off12 := Iso.screen(Iso.ground(to_e).rotated(deg_to_rad(12.0))).normalized()
	lvl.hero._shoot(sk, off12, true)
	_fly(1.0 / 60.0)
	assert_true(e.hp < 99999.0, "błąd 12° korygowany (stożek 30°)")
	e.hp = 99999.0
	var off45 := Iso.screen(Iso.ground(to_e).rotated(deg_to_rad(45.0))).normalized()
	lvl.hero._shoot(sk, off45, true)
	_fly(1.0 / 60.0)
	assert_eq(e.hp, 99999.0, "strzał 45° obok nie skręca do wroga")

func test_contact_never_reports_miss():
	var rng := RandomNumberGenerator.new()
	var att := Stats.from_profile(Data.hero("ursa")["profil"])
	var def := Stats.from_profile(Data.enemy("skaven_slinger")["profil"])
	def.set_base("Zr", 100)
	for i in 300:
		var r := Rules.hero_hit(att, def, 5, i % 2 == 0, 10, rng)
		assert_true(r["hit"])
		assert_true(int(r["damage"]) >= 5)
