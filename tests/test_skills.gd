extends GutTest
## Umiejętności i mana: każda postać ma 3 umiejętności w danych, szybkie ciągłe używanie slotu 1,
## pasek many pustoszeje w 8-12 s ciągłego strzału, brak many daje sygnał i nie blokuje ruchu,
## atak bronią zostaje jako zapas.

var lvl: Level

func before_each():
	Save.save_path = "user://test_skills_zapis.json"
	Game.new_game("ursa")
	Game.level_id = "wioska"
	lvl = Level.new("wioska")
	add_child(lvl)
	await wait_frames(3)
	for e in lvl.enemies():
		e.queue_free()
	await wait_frames(2)
	lvl.map.walls.free()
	lvl.hero.blessed = 1000.0
	lvl.hero.use_mouse_aim = false

func after_each():
	Input.action_release("slot_1")
	Controls.test_move = null
	lvl.queue_free()
	await wait_frames(2)

func test_every_hero_has_three_skills_with_full_data():
	for hid in Data.hero_ids():
		var d := Data.hero(hid)
		var skills: Dictionary = d["umiejetnosci"]
		assert_eq(skills.size(), 3, hid)
		var bar: Array = d["pasek"]
		assert_eq(bar.size(), 10, hid + ": 10 slotów")
		assert_eq(bar.slice(3, 6), ["mikstura_zycia", "mikstura_many", "piwo"])
		for i in 3:
			assert_true(skills.has(bar[i]), "%s slot %d" % [hid, i + 1])
		for sid in skills:
			var sk: Dictionary = skills[sid]
			for key in ["nazwa", "typ", "koszt_many", "odnowienie", "zasieg", "ikona"]:
				assert_true(sk.has(key), "%s.%s ma %s" % [hid, sid, key])
			if sk["typ"] in ["pocisk", "salwa"]:
				assert_true(sk.has("predkosc") and sk.has("promien_trafienia"), "%s.%s: prędkość i hitbox" % [hid, sid])
			assert_true(ResourceLoader.exists(str(sk["ikona"])), "ikona " + str(sk["ikona"]))

func test_basic_skill_cooldown_is_minimal():
	for hid in Data.hero_ids():
		var d := Data.hero(hid)
		var sk: Dictionary = d["umiejetnosci"][d["pasek"][0]]
		assert_between(float(sk["odnowienie"]), 0.15, 0.25, hid)

func test_mana_empties_in_8_to_12_seconds_of_continuous_fire():
	for hid in Data.hero_ids():
		var d := Data.hero(hid)
		var h := HeroState.create(hid)
		var sk: Dictionary = d["umiejetnosci"][d["pasek"][0]]
		var t := Rules.seconds_to_empty(sk, h.max_mana(), h.stats.val("SW"))
		gut.p("%s: %s - mana %d, %.1f użyć/s, pusto po %.1f s" % [hid, sk["nazwa"], h.max_mana(), Rules.skill_rate(sk), t])
		assert_between(t, 8.0, 12.0, hid)

func test_holding_key_fires_continuously_until_mana_runs_out():
	Game.hero.mana = Game.hero.max_mana()
	var denied := [0]
	lvl.hero.mana_denied.connect(func(): denied[0] += 1)
	Input.action_press("slot_1")
	await wait_seconds(3.0)
	var shots := lvl.hero.cooldowns.size()
	assert_true(Game.hero.mana < Game.hero.max_mana() - 15.0, "przytrzymanie = ciągłe strzelanie (zużyto %.0f many)" % (Game.hero.max_mana() - Game.hero.mana))
	Game.hero.mana = 0.0
	await wait_seconds(0.5)
	Input.action_release("slot_1")
	assert_true(denied[0] >= 1, "brak many daje sygnał")
	assert_true(shots >= 1)

func test_no_mana_does_not_block_movement():
	Game.hero.mana = 0.0
	assert_eq(lvl.hero.try_skill("ognisty_pocisk"), "mana")
	var p0 := lvl.hero.position
	Controls.test_move = Vector2(1, 0)
	await wait_seconds(0.4)
	assert_true(lvl.hero.position.x > p0.x + 20.0, "postać dalej się rusza")

func test_skill_rate_is_several_per_second():
	var t0 := Time.get_ticks_msec()
	var used := 0
	Game.hero.mana = 999.0
	while Time.get_ticks_msec() - t0 < 2000:
		if lvl.hero.try_skill("ognisty_pocisk") == "ok":
			used += 1
		await wait_frames(1)
	assert_between(used, 5, 9, "ok. 3-4 strzały na sekundę")

func _key(code: int, pressed: bool, physical: bool = true) -> InputEventKey:
	var ev := InputEventKey.new()
	if physical:
		ev.physical_keycode = code
	else:
		ev.keycode = code
	ev.pressed = pressed
	return ev

func test_number_row_and_numpad_map_to_slots():
	var top := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
	var kp := [KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9, KEY_KP_0]
	for i in 10:
		var act := "slot_%d" % (i + 1)
		assert_true(_key(top[i], true).is_action(act), "klawisz %d -> %s" % [i, act])
		assert_true(_key(kp[i], true).is_action(act), "numeryczna %d -> %s" % [i, act])
		assert_true(_key(kp[i], true, false).is_action(act), "numeryczna (keycode) %d -> %s" % [i, act])

func test_slot_keys_use_potions_and_skills():
	Game.hero.hp = 10.0
	lvl.hero.hp = 10.0
	Input.action_press("slot_4")
	await wait_frames(3)
	Input.action_release("slot_4")
	assert_true(lvl.hero.hp > 10.0, "slot 4 = mikstura zdrowia")
	await wait_seconds(1.1)
	Game.hero.mana = 5.0
	var mana0 := Game.hero.mana
	Input.action_press("slot_6")
	await wait_frames(3)
	Input.action_release("slot_6")
	assert_true(Game.hero.mana > mana0, "slot 6 = piwo (mana też)")
	Game.hero.mana = 50.0
	lvl.spawn_enemy("skaven_spear", lvl.hero.position + Vector2(250, 0), "", "")
	Input.action_press("slot_3")
	await wait_frames(4)
	Input.action_release("slot_3")
	assert_eq(lvl.hero.cur_id, "przebijajacy_plomien", "slot 3 = trzecia umiejętność")

func test_clicking_bar_slot_activates_it():
	var bar: SkillBar = lvl.hud.skill_bar
	await wait_frames(2)
	var r: Rect2 = bar.slot_rects[0][1]
	Game.hero.mana = 50.0
	bar._press(bar.slot_at(r.get_center()))
	assert_true(Input.is_action_pressed("slot_1"))
	await wait_frames(3)
	bar._release(0)
	assert_eq(lvl.hero.cur_id, "ognisty_pocisk")

func test_touch_layout_collapses_and_avoids_joystick():
	Save.touch_mode = 1
	var bar: SkillBar = lvl.hud.skill_bar
	bar.layout()
	await wait_frames(2)
	var rect := bar.get_global_rect()
	var vw := bar.get_viewport_rect().size.x
	gut.p("pasek dotykowy: %s (ekran %d)" % [rect, vw])
	assert_true(rect.position.x > 230.0, "pasek nie nachodzi na joystick")
	assert_true(rect.end.x < vw - 190.0, "pasek nie nachodzi na przycisk ATAK")
	assert_eq(bar.collapsed, true, "na telefonie puste sloty pod '...'")
	assert_eq(bar.slot_rects.size(), 6)
	Save.touch_mode = 2
	bar.layout()
	await wait_frames(2)
	assert_eq(bar.slot_rects.size(), 10, "na PC wszystkie 10 slotów")
	Save.touch_mode = 0

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
	lvl.map.walls.free()
	lvl.hero.blessed = 1000.0
	lvl.hero.use_mouse_aim = false

func _dummy(off: Vector2) -> Enemy:
	var e := lvl.spawn_enemy("skaven_spear", lvl.hero.position + off, "", "")
	e.set_physics_process(false)
	e.hp = 9999.0
	return e

func test_ivo_whirl_hits_all_around():
	await _swap("ivo")
	var es := [_dummy(Vector2(70, 0)), _dummy(Vector2(-70, 0)), _dummy(Vector2(0, 40)), _dummy(Vector2(0, -40))]
	lvl.hero.aim = Vector2.RIGHT
	var hits: Array = lvl.hero._melee(lvl.hero.skills["wirujacy_miecz"])
	assert_eq(hits.size(), 4, "wirujący miecz trafia przód, tył i boki")
	for e in es:
		assert_true(e.hp < 9999.0)

func test_ivo_war_cry_buffs_damage_and_pushes():
	await _swap("ivo")
	var e := _dummy(Vector2(80, 0))
	e.set_physics_process(true)
	var sk: Dictionary = lvl.hero.skills["potezne_ciecie"]
	var before := Rules.skill_damage(sk, lvl.hero.stats, e.stats, lvl.hero.weapon_dmg(), lvl.hero.dmg_buff)
	assert_eq(lvl.hero.try_skill("okrzyk_gwardii"), "ok")
	await wait_seconds(0.5)
	assert_almost_eq(lvl.hero.dmg_buff, 0.4, 0.001)
	var after := Rules.skill_damage(sk, lvl.hero.stats, e.stats, lvl.hero.weapon_dmg(), lvl.hero.dmg_buff)
	assert_true(after > before, "okrzyk zwiększa obrażenia (%d -> %d)" % [before, after])
	assert_true(Iso.dist(lvl.hero.position, e.position) > 80.0, "okrzyk odrzuca wroga")

func test_modraszka_net_slows_group():
	await _swap("modraszka")
	var es := [_dummy(Vector2(220, 0)), _dummy(Vector2(240, 20)), _dummy(Vector2(200, -15))]
	assert_eq(lvl.hero.try_skill("strzala_z_siecia"), "ok")
	await wait_seconds(1.0)
	for e in es:
		assert_true(e.slow_k < 1.0 and e.slow_t > 0.0, "sieć spowalnia grupę")

func test_ursa_fireball_explosion_damages_group():
	var es := [_dummy(Vector2(220, 0)), _dummy(Vector2(250, 20)), _dummy(Vector2(240, -20))]
	assert_eq(lvl.hero.try_skill("kula_ognia"), "ok")
	await wait_seconds(1.2)
	for e in es:
		assert_true(e.hp < 9999.0, "wybuch rani całą grupę")

# ---------------------------------------------------------------- animacje Ivo z profilu (east/west)
func test_ivo_profile_animations_exist_east_and_mirrored_west():
	await _swap("ivo")
	var g: DirSprite = lvl.hero.gfx
	assert_eq(g.pivot, Vector2(160, 190), "pivot z sprite.json (płótno 320x192)")
	var want := {"walk": 6, "attack": 4, "heavy": 4, "whirl": 4, "shout": 3, "hurt": 2, "death": 6}
	for an in want:
		assert_true(g.has_anim(an, "east"), an + "/east")
		assert_eq(g.frame_count(an, "east"), want[an], an + ": liczba klatek")
		assert_true(g.has_anim(an, "west"), an + "/west (odbicie)")
		assert_true(g.frames[an]["west"]["flip"], an + "/west jest lustrzanym odbiciem east")
		var tx: Texture2D = g.frames[an]["east"]["tex"][0]
		assert_eq(Vector2(tx.get_width(), tx.get_height()), Vector2(320, 192), an + ": wspólne płótno")
	for d in Iso.DIRS:
		assert_true(g.has_anim("idle", d), "idle/" + d)

func test_ivo_other_directions_keep_their_pose():
	await _swap("ivo")
	var g: DirSprite = lvl.hero.gfx
	for d in ["south", "north", "south-east", "north-east", "south-west", "north-west"]:
		assert_false(g.has_anim("walk", d), "brak klatek chodu w kierunku " + d)
		g.play("walk", d)
		g._apply()
		assert_eq(g.current_texture(), g.frames["idle"][d]["tex"][0], "chód w kierunku %s pokazuje pozę tego kierunku" % d)
		assert_eq(lvl.hero._attack_anim(d), "", "atak w kierunku %s ożywiany w kodzie" % d)
	g.play("death", "south-west")
	g._apply()
	assert_true(g.frames["death"]["west"]["tex"].has(g.current_texture()), "śmierć zawsze ma klatki (z profilu)")
	assert_true(g.sprite.flip_h, "upadek w stronę zachodnią jest odbity")

func test_ivo_skills_pick_their_own_animation():
	await _swap("ivo")
	var h := lvl.hero
	h.cur = h.skills["potezne_ciecie"]
	assert_eq(h._attack_anim("east"), "heavy")
	h.cur = h.skills["wirujacy_miecz"]
	assert_eq(h._attack_anim("west"), "whirl")
	h.cur = h.skills["okrzyk_gwardii"]
	assert_eq(h._attack_anim("east"), "shout")
	h.cur = h.weapon_atk
	assert_eq(h._attack_anim("east"), "attack", "zwykły cios bronią")
	h.cur = {}

func test_ivo_attack_shows_hit_frame_on_strike():
	await _swap("ivo")
	var h := lvl.hero
	var g: DirSprite = h.gfx
	_dummy(Vector2(70, 0))
	assert_eq(h.try_skill("potezne_ciecie"), "ok")
	await wait_seconds(0.2)        # zamach 0,14 s minął: trafienie albo powrót
	assert_eq(g.anim, "heavy")
	assert_eq(g.current_texture(), g.frames["heavy"][g.dir]["tex"][3], "po zamachu widać klatkę trafienia")
