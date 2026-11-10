extends GutTest
## Wioska: barykada i palisada szczelnie zamykają wyjście, granica mapy, tunele skavenów, płynny ruch,
## animacje Modraszki, brak podwójnych obrażeń.

var lvl: Level
var requests: Array = []

func before_each():
	Save.save_path = "user://test_village_zapis.json"
	Save.delete_save()
	Game.new_game("modraszka")
	Game.level_id = "wioska"
	requests.clear()
	lvl = Level.new("wioska")
	lvl.request.connect(func(w): requests.append(w))
	add_child(lvl)
	await wait_frames(3)

func after_each():
	Controls.test_move = null
	lvl.queue_free()
	await wait_frames(2)

func _clear():
	for e in lvl.enemies():
		e.queue_free()
	for t in get_tree().get_nodes_in_group("tunnels"):
		t.set_physics_process(false)
	await wait_frames(2)
	lvl.hero.blessed = 1000.0

func _flood(extra_blocked: Dictionary) -> Dictionary:
	var start := Iso.to_cell(lvl.start_cell())
	var seen := {start: true}
	var stack := [start]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if lvl.map.is_walkable(n) and not extra_blocked.has(n) and not seen.has(n):
				seen[n] = true
				stack.append(n)
	return seen

func test_exit_is_sealed_until_barricade_is_out():
	var bar := {}
	for p in lvl.barricade_parts:
		bar[p.cell] = true
	var exit_cell := Iso.to_cell(lvl.exit_zone.position)
	assert_false(_flood(bar).has(exit_cell), "z płonącą barykadą nie ma żadnej drogi do wyjścia (palisada od lasu do lasu)")
	assert_true(_flood({}).has(exit_cell), "po ugaszeniu brama jest przejezdna")

func test_cannot_walk_around_barricade_from_any_side():
	await _clear()
	var gate_y: int = lvl.barricade_parts[0].cell.y
	# podejście od lewej krawędzi, od prawej i na wprost: bohater pcha się na północ przez 2,5 s
	for x in [44, 46, 48, 50, 52]:
		lvl.hero.position = Iso.cell_center(Vector2i(x, gate_y + 2))
		lvl.hero.velocity = Vector2.ZERO
		await wait_frames(2)
		for dir in [Vector2(1, -1), Vector2(-1, -1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]:
			Controls.test_move = dir.normalized()
			await wait_seconds(0.5)
		Controls.test_move = null
		assert_true(Iso.to_cell(lvl.hero.position).y > gate_y, "start x=%d: bohater został po stronie wioski (%s)" % [x, Iso.to_cell(lvl.hero.position)])
	assert_does_not_have(requests, "poziom2")
	assert_false(lvl.exit_zone.open)

func test_exit_works_after_quest_and_map_edge_is_closed():
	await _clear()
	for id in ["a", "b", "c"]:
		Game.quest.pick_bucket(id)
	Game.quest.fill_at_well()
	for part in lvl.barricade_parts:
		part.interact(lvl.hero)
		await wait_frames(1)
	assert_true(lvl.exit_zone.open)
	lvl.exit_zone.open = false          # sprawdzamy samą granicę mapy: nawet przez otwartą bramę nie wyjdzie się poza mapę
	lvl.hero.position = Iso.cell_center(Vector2i(48, 2))
	Controls.test_move = Vector2(1, -1).normalized()
	await wait_seconds(1.5)
	Controls.test_move = null
	assert_true(lvl.map.in_bounds(Iso.to_cell(lvl.hero.position)), "granica mapy zatrzymuje bohatera")
	lvl.exit_zone.open = true
	lvl.hero.position = Iso.cell_center(Vector2i(48, 2))
	await wait_frames(4)
	assert_has(requests, "poziom2", "wyjście działa po ugaszeniu barykady")

func test_skaven_emerge_from_tunnel_when_hero_approaches():
	for e in lvl.enemies():
		e.queue_free()
	await wait_frames(2)
	lvl.hero.blessed = 1000.0
	var tunnels := get_tree().get_nodes_in_group("tunnels")
	var tn = tunnels.filter(func(t): return t.uid == "plac_wschod")[0]
	assert_false(tn.triggered)
	assert_eq(lvl.alive_enemies(), 0, "przed podejściem z nory nikt nie wychodzi")
	lvl.hero.position = tn.position + Vector2(200, 0)
	await wait_seconds(0.5)
	assert_true(tn.triggered)
	var first: Enemy = lvl.enemies()[0]
	assert_true(first.emerge_t > 0.0, "skaven wynurza się z nory")
	assert_true(Iso.dist(first.position, lvl.hero.position) >= 70.0, "nie pojawia się na bohaterze")
	assert_true(lvl.map.is_walkable(Iso.to_cell(first.position)), "nie pojawia się w przeszkodzie")
	await wait_seconds(3.5)
	assert_eq(lvl.enemies().size(), tn.list.size(), "wyszła cała fala")
	assert_true(Game.has_flag("tunele", "plac_wschod"))
	for e in lvl.enemies():
		assert_true(e.emerge_t <= 0.0 and e.aggro, "po wyjściu ruszają do walki")

func test_tunnel_waits_while_hero_stands_on_it():
	for e in lvl.enemies():
		e.queue_free()
	await wait_frames(2)
	lvl.hero.blessed = 1000.0
	var tn = get_tree().get_nodes_in_group("tunnels").filter(func(t): return t.uid == "polnoc")[0]
	lvl.hero.position = tn.position
	await wait_seconds(1.2)
	assert_true(tn.triggered)
	assert_eq(lvl.enemies().size(), 0, "nic nie wychodzi prosto w bohatera")

func test_movement_accelerates_and_decelerates_smoothly():
	await _clear()
	lvl.hero.position = Iso.cell_center(Vector2i(34, 34))
	await wait_frames(2)
	var full: float = lvl.hero.stats.move_speed()
	Controls.test_move = Vector2(1, 0)
	await wait_frames(2)
	var early: float = lvl.hero.velocity.length()
	assert_true(early > 0.0 and early < full * 0.7, "łagodny start (%.0f z %.0f)" % [early, full])
	await wait_seconds(0.4)
	assert_almost_eq(lvl.hero.velocity.length(), full, 1.0, "pełna prędkość po rozpędzie")
	Controls.test_move = null
	await wait_frames(2)
	var late: float = lvl.hero.velocity.length()
	assert_true(late > 0.0 and late < full, "łagodne hamowanie")
	await wait_seconds(0.3)
	assert_eq(lvl.hero.velocity.length(), 0.0)

func test_diagonal_is_not_faster():
	await _clear()
	lvl.hero.position = Iso.cell_center(Vector2i(34, 34))
	Controls.test_move = Vector2(1, 0)
	await wait_seconds(0.5)
	var straight: float = Iso.ground(lvl.hero.velocity).length()
	Controls.test_move = Vector2(1, 1)          # nieznormalizowany skos (np. dwa klawisze naraz)
	await wait_seconds(0.5)
	var diag: float = Iso.ground(lvl.hero.velocity).length()
	assert_almost_eq(diag, straight, 1.0, "skos nie daje przewagi prędkości")

func test_modraszka_has_all_animations_from_author_art():
	assert_true(FileAccess.file_exists("res://assets/characters/modraszka/source/modraszka_source.webp"), "oryginał zachowany")
	var g: DirSprite = lvl.hero.gfx
	for anim in ["idle", "walk", "attack", "hurt", "death"]:
		assert_true(g.frames.has(anim), "animacja " + anim)
		for d in Iso.DIRS:
			assert_true(g.frames[anim].has(d), "%s/%s" % [anim, d])
	assert_true(g.has_walk and g.has_attack)
	assert_eq(g.frames["walk"]["east"]["tex"].size(), 4)
	assert_almost_eq(lvl.hero.body_radius, 13.0, 0.01, "hitbox niezależny od rozmiaru grafiki (płótno 320 px)")

func test_single_attack_never_damages_twice():
	await _clear()
	lvl.map.walls.free()
	var e := lvl.spawn_enemy("skaven_warlock", lvl.hero.position + Vector2(200, 0), "", "")
	e.set_physics_process(false)
	e.hp = 9999.0
	var counts := [0]
	var orig_hp := e.hp
	var sk: Dictionary = lvl.hero.skills["strzala"]
	lvl.hero._shoot(sk, Vector2.RIGHT, true)
	var pr: Projectile = lvl.map.world.get_children().filter(func(n): return n is Projectile)[0]
	pr.set_physics_process(false)
	for i in 400:
		if pr._done:
			break
		var before := e.hp
		pr.step(1.0 / 240.0)      # bardzo drobne kroki: pocisk długo "siedzi" w hitboxie
		if e.hp < before:
			counts[0] += 1
	assert_eq(counts[0], 1, "jedna strzała = jedno trafienie")
	assert_true(e.hp < orig_hp)
