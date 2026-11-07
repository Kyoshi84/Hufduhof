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
