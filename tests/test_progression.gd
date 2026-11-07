extends GutTest
## Rozwój postaci: punkty za XP, +5 do cechy głównej / +1 do drugorzędnej, limity.

func test_points_from_thresholds():
	var t: Array = HeroState.thresholds()
	assert_eq(HeroState.points_for_xp(0), 0)
	assert_eq(HeroState.points_for_xp(int(t[0])), 1)
	assert_eq(HeroState.points_for_xp(int(t[4])), 5)

func test_raise_primary_plus5_and_secondary_plus1():
	var h := HeroState.create("ivo")
	h.add_xp(int(HeroState.thresholds()[1]))
	assert_eq(h.points_available(), 2)
	var ww := h.stats.base_val("WW")
	assert_true(h.raise_stat("WW"))
	assert_eq(h.stats.base_val("WW"), ww + 5)
	var zyw := h.stats.base_val("Zyw")
	var hp_before := h.max_hp()
	assert_true(h.raise_stat("Zyw"))
	assert_eq(h.stats.base_val("Zyw"), zyw + 1)
	assert_eq(h.max_hp(), hp_before + 10, "Żyw +1 = +10 życia")
	assert_eq(h.points_available(), 0)
	assert_false(h.raise_stat("K"), "brak punktów")

func test_k_raise_changes_s():
	var h := HeroState.create("ivo")
	h.stats.set_base("K", 38)
	h.add_xp(100000)
	assert_eq(h.stats.val("S"), 3)
	h.raise_stat("K")
	assert_eq(h.stats.val("S"), 4, "K 43 -> S 4")

func test_limits_respected():
	var h := HeroState.create("ivo")
	h.add_xp(100000)
	h.stats.set_base("WW", int(Data.bal("rozwoj/limit_glowne", 70)) - 2)
	assert_false(h.can_raise("WW"), "przekroczyłoby limit")
	h.stats.set_base("A", 10)
	assert_false(h.can_raise("A"))
	assert_false(h.can_raise("S"), "S wynika z K - nie rozwija się bezpośrednio")
	assert_false(h.can_raise("PO"))

func test_level1_gives_about_5_points():
	# suma XP możliwa w karczmie + Poziomie 1 (wrogowie z danych poziomów + zadania)
	var total := 0
	for lvl in ["karczma", "wioska"]:
		var d := Data.load_json("res://data/levels/%s.json" % lvl)
		for g in d.get("grupy", []):
			for e in g.get("wrogowie", []):
				total += int(Data.enemy(str(e)).get("xp", 0))
		for w in d.get("fale", []):
			for e in w.get("wrogowie", []):
				total += int(Data.enemy(str(e)).get("xp", 0))
	var qx: Dictionary = Data.bal("xp_zadania", {})
	total += int(qx["karczma_obroniona"]) + int(qx["rozmowa_borubar"]) + 3 * int(qx["wiadro_znalezione"])
	total += 3 * int(qx["barykada_czesc"]) + int(qx["barykada_ugaszona"]) + int(qx["nagroda_borubara"])
	var pts := HeroState.points_for_xp(total)
	gut.p("XP do zdobycia w karczmie i Poziomie 1: %d -> %d punktów" % [total, pts])
	assert_between(pts, 5, 6, "ok. 5 punktów rozwoju w Poziomie 1")

func test_starting_profiles_valid():
	for id in Data.hero_ids():
		var h := HeroState.create(id)
		for k in Stats.PRIMARY:
			assert_between(h.stats.base_val(k), 0, 100, id + " " + k)
		for k in Stats.SECONDARY:
			assert_between(h.stats.base_val(k), 0, 10, id + " " + k)
		assert_true(h.max_hp() > 0)
	assert_true(HeroState.create("ivo").max_mana() > 0, "mana zasila umiejętności wszystkich postaci")
	var ursa := HeroState.create("ursa")
	assert_true(ursa.max_mana() >= 60, "Ursa: dużo many")
	assert_true(ursa.max_hp() < HeroState.create("ivo").max_hp(), "Ursa: mniej zdrowia niż Ivo")

func test_heroes_faster_than_all_rats():
	for hid in Data.hero_ids():
		var hs := Stats.from_profile(Data.hero(hid)["profil"])
		for eid in Data.enemies["wrogowie"]:
			var es := Stats.from_profile(Data.enemy(eid)["profil"])
			assert_true(hs.move_speed() > es.move_speed(), "%s szybszy niż %s" % [hid, eid])
	for eid in Data.enemies["wrogowie"]:
		var s := Stats.from_profile(Data.enemy(eid)["profil"])
		assert_true(s.max_hp() > 0, eid)

func test_save_roundtrip_keeps_progress():
	var h := HeroState.create("ursa")
	h.add_xp(200)
	h.raise_stat("Zr")
	h.inv.add_item(Loot.make_item("kolczuga", null, 2))
	var h2 := HeroState.from_dict(JSON.parse_string(JSON.stringify(h.to_dict())))
	assert_eq(h2.id, "ursa")
	assert_eq(h2.xp, 200)
	assert_eq(h2.stats.base_val("Zr"), h.stats.base_val("Zr"))
	assert_eq(h2.points_available(), h.points_available())
	assert_eq(Loot.item_name(h2.inv.bag[0]), Loot.item_name(h.inv.bag[0]))
