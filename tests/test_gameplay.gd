extends GutTest
## Testy integracyjne na prawdziwej scenie: walka wręcz ze skavenem, mikstury, zadanie z wiadrami od początku
## do wyjścia z wioski, zapis i wczytanie stanu, śmierć z PP.

var lvl: Level
var requests: Array = []

func before_each():
	Save.save_path = "user://test_gameplay_zapis.json"
	Save.delete_save()
	Game.new_game("ivo")
	Game.level_id = "wioska"
	requests.clear()
	lvl = Level.new("wioska")
	lvl.request.connect(func(w): requests.append(w))
	add_child(lvl)
	await wait_frames(3)

func after_each():
	lvl.queue_free()
	await wait_frames(2)
	Controls.test_move = null
	Engine.time_scale = 1.0

func _clear_enemies():
	for e in lvl.enemies():
		e.queue_free()
	await wait_frames(2)

func test_level_builds_with_navigation_and_fog():
	assert_not_null(lvl.map.nav_region.navigation_polygon)
	assert_true(lvl.map.nav_region.navigation_polygon.get_polygon_count() > 10, "wypieczona nawigacja")
	assert_true(lvl.alive_enemies() >= 18, "grupy potworów na mapie")
	assert_eq(get_tree().get_nodes_in_group("tunnels").size(), 5, "tunele skavenów")
	assert_true(lvl.map.explored_ratio() > 0.0 and lvl.map.explored_ratio() < 0.2, "mgła wojny odkryta tylko przy starcie")

func test_hero_moves_in_iso_ground_metric():
	await _clear_enemies()
	var p0 := lvl.hero.position
	Controls.test_move = Vector2(1, 0)
	await wait_seconds(0.5)
	Controls.test_move = Vector2(0, 1)
	await wait_seconds(0.5)
	Controls.test_move = null
	var d := lvl.hero.position - p0
	assert_true(d.x > 20.0, "ruch w prawo")
	assert_true(d.y > 10.0, "ruch w dół (wolniejszy na ekranie - rzut izometryczny)")

func test_melee_kills_skaven_and_gives_xp():
	await _clear_enemies()
	var e := lvl.spawn_enemy("skaven_spear", lvl.hero.position + Vector2(50, 0), "", "test_1")
	e.stats.set_base("Zr", 0)
	lvl.hero.blessed = 100.0
	var xp0 := Game.hero.xp
	lvl.hero.mouse_atk = true
	var t := 0.0
	while not e.is_dead() and t < 20.0:
		await wait_frames(10)
		t += 10.0 / 60.0
	lvl.hero.mouse_atk = false
	assert_true(e.is_dead(), "skaven zabity")
	assert_eq(Game.hero.xp, xp0 + int(Data.enemy("skaven_spear")["xp"]))
	assert_true(Game.has_flag("zabici", "test_1"))
	gut.p("czas walki: %.1f s" % t)
	assert_true(t <= 3.0, "zwykły skaven pada szybko (kilka ciosów)")

func test_enemy_telegraphs_before_hitting():
	await _clear_enemies()
	var e := lvl.spawn_enemy("skaven_spear", lvl.hero.position + Vector2(55, 0), "", "")
	e.wake()
	var saw_windup := false
	var hp0 := lvl.hero.hp
	for i in 120:
		await wait_frames(1)
		if e.state == Actor.St.WINDUP:
			saw_windup = true
			assert_eq(lvl.hero.hp, hp0, "brak obrażeń w trakcie zamachu")
			break
	assert_true(saw_windup, "wróg zapowiada atak (zamach)")
	assert_not_null(e.marker, "znacznik zapowiedzi na ziemi")

func test_potion_heals():
	lvl.hero.hp = 20.0
	Game.hero.hp = 20.0
	assert_true(lvl.hero.use_belt("mikstura_zycia"))
	assert_true(lvl.hero.hp > 20.0)

func test_bucket_quest_full_flow_to_exit():
	await _clear_enemies()
	lvl.hero.blessed = 1000.0
	lvl.talk_to_npc("borubar")
	assert_true(get_tree().paused, "dialog pauzuje grę")
	lvl.close_overlay()
	Game.quest.start()
	var buckets := get_tree().get_nodes_in_group("interactable").filter(func(n): return n is Obj.Bucket)
	assert_eq(buckets.size(), 3)
	for b in buckets:
		lvl.hero.position = b.position + Vector2(20, 0)
		await wait_frames(2)
		b.interact(lvl.hero)
	assert_eq(Game.quest.found_count(), 3)
	lvl.hero.position = lvl.well.position + Vector2(60, 0)
	await wait_frames(2)
	lvl.well.interact(lvl.hero)
	assert_eq(Game.quest.carrying_full(), 3)
	assert_false(lvl.exit_zone.open, "wyjście zamknięte przed ugaszeniem")
	for part in lvl.barricade_parts:
		part.interact(lvl.hero)
		await wait_frames(1)
	assert_true(Game.quest.is_barricade_out())
	assert_true(lvl.exit_zone.open)
	for part in lvl.barricade_parts:
		assert_false(part.burning)
	lvl.hero.position = lvl.exit_zone.position
	await wait_frames(3)
	assert_has(requests, "poziom2", "przejście do Poziomu 2")

func test_save_and_load_restores_state():
	Game.hero.add_xp(200)
	Game.hero.raise_stat("WW")
	Game.quest.pick_bucket("wiadro_kuznia")
	Game.add_flag("skrzynie", "skrzynia_mlyn")
	lvl.hero.position = Iso.cell_center(Vector2i(30, 30))
	lvl.autosave()
	var ww := Game.hero.stats.base_val("WW")
	Game.new_game("ursa")
	assert_true(Save.load_game())
	assert_eq(Game.hero.id, "ivo")
	assert_eq(Game.hero.stats.base_val("WW"), ww)
	assert_eq(Game.quest.found_count(), 1)
	assert_true(Game.has_flag("skrzynie", "skrzynia_mlyn"))
	assert_eq(Game.level_id, "wioska")
	assert_almost_eq((Game.spawn_pos as Vector2).x, Iso.cell_center(Vector2i(30, 30)).x, 1.0)

func test_death_uses_fate_point_and_revives_half_hp():
	await _clear_enemies()
	var pp := Game.hero.stats.base_val("PP")
	lvl.hero.apply_damage(9999.0, "ogien")
	assert_true(lvl.hero.is_dead())
	await wait_seconds(1.8)
	assert_false(lvl.hero.is_dead(), "odrodzony")
	assert_eq(Game.hero.stats.base_val("PP"), pp - 1)
	assert_almost_eq(lvl.hero.hp, Game.hero.max_hp() * 0.5, 1.0)

func test_shrines():
	var shrines := get_tree().get_nodes_in_group("interactable").filter(func(n): return n is Obj.Shrine)
	assert_eq(shrines.size(), 4)
	var ul = shrines.filter(func(s): return s.kind == "ulryk")[0]
	ul.interact(lvl.hero)
	assert_true(lvl.hero.blessed > 7.0, "niezniszczalność ok. 8 s")
	var hp0 := lvl.hero.hp
	lvl.hero.apply_damage(30.0)
	assert_eq(lvl.hero.hp, hp0, "nietykalny")
	assert_false(ul.can_interact(lvl.hero), "jedno użycie")
	lvl.hero.blessed = 0.0
	lvl.hero.hp = 10.0
	var rh = shrines.filter(func(s): return s.kind == "rhya")[0]
	rh.interact(lvl.hero)
	assert_eq(lvl.hero.hp, float(Game.hero.max_hp()), "pełne leczenie")

func test_chest_drops_loot():
	var chests := get_tree().get_nodes_in_group("interactable").filter(func(n): return n is Obj.Chest)
	assert_eq(chests.size(), 6)
	var before := get_tree().get_nodes_in_group("pickup").size()
	for i in 5:
		var c = chests[i]
		c.interact(lvl.hero)
	await wait_frames(2)
	assert_true(get_tree().get_nodes_in_group("pickup").size() > before, "skrzynie dają łupy")

func _swap_hero(id: String) -> void:
	lvl.queue_free()
	await wait_frames(2)
	Game.new_game(id)
	Game.level_id = "wioska"
	lvl = Level.new("wioska")
	add_child(lvl)
	await wait_frames(3)
	await _clear_enemies()
	lvl.hero.blessed = 100.0

func test_modraszka_primary_shoots_and_knife_without_mana():
	await _swap_hero("modraszka")
	var e := lvl.spawn_enemy("skaven_spear", lvl.hero.position + Vector2(220, 0), "", "")
	lvl.hero.use_mouse_aim = false
	lvl.hero.primary()
	assert_eq(lvl.hero.cur_id, "strzala", "atak główny = strzała ze slotu 1")
	await wait_seconds(0.8)
	assert_true(e.hp < e.get_max_hp(), "strzała trafia")
	await wait_seconds(0.4)
	Game.hero.mana = 0.0
	lvl.hero.primary()
	assert_eq(lvl.hero.cur_id, "bron", "bez many - zwykły atak nożem")

func test_modraszka_volley_fires_five_arrows():
	await _swap_hero("modraszka")
	var e := lvl.spawn_enemy("skaven_spear", lvl.hero.position + Vector2(200, 0), "", "")
	lvl.hero.use_mouse_aim = false
	assert_eq(lvl.hero.try_skill("grad_strzal"), "ok")
	await wait_seconds(0.3)
	var arrows := lvl.map.world.get_children().filter(func(n): return n is Projectile and n.kind == "arrow")
	assert_eq(arrows.size(), 5)
	assert_not_null(e)

func test_ursa_fire_bolt_uses_mana_and_fireball_explodes():
	await _swap_hero("ursa")
	var e1 := lvl.spawn_enemy("skaven_spear", lvl.hero.position + Vector2(200, 0), "", "")
	var e2 := lvl.spawn_enemy("skaven_spear", lvl.hero.position + Vector2(215, 12), "", "")
	var mana0 := Game.hero.mana
	lvl.hero.use_mouse_aim = false
	assert_eq(lvl.hero.try_skill("ognisty_pocisk"), "ok")
	assert_almost_eq(Game.hero.mana, mana0 - 2.1, 0.05)
	await wait_seconds(0.6)
	mana0 = Game.hero.mana
	assert_eq(lvl.hero.try_skill("kula_ognia"), "ok")
	assert_almost_eq(Game.hero.mana, mana0 - 12.0, 0.1, "kula ognia: 12 many")
	await wait_seconds(1.2)
	assert_true(e1.hp < e1.get_max_hp() and e2.hp < e2.get_max_hp(), "wybuch rani obu skavenów")

func test_mana_potion_works_for_everyone():
	Game.hero.mana = 0.0
	Game.hero.inv.belt["mikstura_many"] = 1
	assert_true(lvl.hero.use_belt("mikstura_many"))
	assert_true(Game.hero.mana > 0.0, "Ivo też ma manę (zasila jego umiejętności)")

func test_dialog_advances_and_closes_with_e_key():
	await _clear_enemies()
	lvl.talk_to_npc("borubar")
	var keys: OverlayKeys = null
	for c in lvl.ui.get_children():
		if c is OverlayKeys:
			keys = c
	assert_not_null(keys)
	var steps := 0
	while lvl.overlay != null and steps < 20:
		var btn: Button = null
		for b in lvl.overlay.find_children("*", "Button", true, false):
			if not b.is_queued_for_deletion() and (b.text == "Dalej" or b.text == "Do widzenia"):
				btn = b
		assert_not_null(btn, "jest przycisk Dalej / Do widzenia")
		if btn == null:
			break
		btn.grab_focus()
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E
		ev.pressed = true
		keys._input(ev)
		steps += 1
	assert_null(lvl.overlay, "dialog zamknięty klawiszem E")
	assert_false(get_tree().paused)
	assert_eq(Game.quest.state, BucketQuest.State.ACTIVE, "rozmowa rozpoczęła zadanie")
	assert_eq(steps, Data.dialog("borubar_start").size(), "każde E = jedna kwestia")

func test_dialog_closes_with_escape():
	lvl.talk_to_npc("borubar")
	var keys: OverlayKeys = lvl.ui.get_children().filter(func(c): return c is OverlayKeys)[0]
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	keys._input(ev)
	assert_null(lvl.overlay)
	assert_false(get_tree().paused)

func test_borubar_waits_in_front_of_tavern():
	var npc = get_tree().get_nodes_in_group("interactable").filter(func(n): return n is Obj.Npc)[0]
	assert_true(Iso.dist(npc.position, lvl.start_cell()) < 260.0, "Borubar stoi przed karczmą, blisko startu")

func test_tavern_play_borubar_then_hero():
	lvl.queue_free()
	await wait_frames(2)
	Game.new_game("ivo")
	var tv := Tavern.new()
	add_child(tv)
	await wait_frames(3)
	assert_eq(tv.controlled_name(), "Borubar", "w imprezie gramy Borubarem")
	assert_false(tv.hero.can_fight, "Borubar nie walczy")
	assert_true(tv.hero.gfx.base_path.ends_with("borubar"))
	assert_not_null(tv.guest, "bohater siedzi wśród gości")
	tv.caught = int(tv.cfg.get("kufle_cel", 6))
	tv._break_in()
	await wait_seconds(1.6)
	assert_eq(tv.controlled_name(), "Ivo Eggert", "po wtargnięciu szczurów sterujemy bohaterem")
	assert_true(tv.hero.can_fight)
	assert_true(tv.hero.gfx.base_path.ends_with("ivo"))
	assert_almost_eq(tv.hero.position.x, tv.guest_pos.x, 1.0, "bohater wstaje z miejsca gościa")
	await wait_seconds(2.0)
	assert_true(tv.alive_enemies() >= 2, "wpadły skaveny")
	tv.queue_free()
	lvl = Level.new("wioska")
	add_child(lvl)
	await wait_frames(2)
