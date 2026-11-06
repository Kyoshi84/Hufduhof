extends GutTest
## Łupy (tabele szans z data/loot.json) i ekwipunek.

func test_tables_reference_existing_items():
	for pool in Data.loot["pule"]:
		for id in Data.loot["pule"][pool]:
			assert_false(Data.item(id).is_empty(), "%s w puli %s" % [id, pool])
	for eid in Data.enemies["wrogowie"]:
		var t := str(Data.enemy(eid).get("lup", ""))
		assert_true(Data.loot["tabele"].has(t), "tabela łupu dla " + eid)

func test_roll_distribution_follows_weights():
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var counts := {}
	var n := 4000
	for i in n:
		var drops := Loot.roll_table("skaven_spear", rng)
		var key := "nic" if drops.is_empty() else str(drops[0]["typ"])
		counts[key] = int(counts.get(key, 0)) + 1
	var entries: Array = Data.loot["tabele"]["skaven_spear"]["pozycje"]
	var total := 0.0
	for e in entries:
		total += float(e["waga"])
	for e in entries:
		var expected := float(e["waga"]) / total
		var got := float(counts.get(str(e["typ"]), 0)) / n
		assert_almost_eq(got, expected, 0.03, "szansa na " + str(e["typ"]))

func test_gold_amount_in_range():
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 500:
		for d in Loot.roll_table("skrzynia", rng):
			if d["typ"] == "korony":
				assert_between(int(d["ilosc"]), 10, 30)

func test_chest_gives_three_rolls():
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 50:
		assert_true(Loot.roll_table("skrzynia", rng).size() <= 3)

func test_affix_bonus_and_name():
	var it := Loot.make_item("miecz", null, 0)   # afiks "Siły"
	assert_eq(Loot.item_name(it), "Miecz Siły")
	assert_eq(int(Loot.item_bonus(it).get("K", 0)), 5)
	assert_true(Loot.item_price(it) > Loot.item_price(Loot.make_item("miecz", null, -1)))

func test_equip_applies_bonuses():
	var h := HeroState.create("ivo")
	var zr := h.stats.val("Zr")
	h.inv.add_item(Loot.make_item("zab_szczura", null, -1))
	assert_true(h.inv.equip_from_bag(0))
	h.refresh_bonuses()
	assert_eq(h.stats.val("Zr"), zr + 5)
	assert_true(h.inv.unequip("amulet"))
	h.refresh_bonuses()
	assert_eq(h.stats.val("Zr"), zr)

func test_equip_swaps_with_previous():
	var h := HeroState.create("ivo")
	h.inv.add_item(Loot.make_item("topor", null, -1))
	assert_true(h.inv.equip_from_bag(0))
	assert_eq(str(h.inv.equipped["bron"]["id"]), "topor")
	assert_eq(str(h.inv.bag[0]["id"]), "miecz_dwureczny", "stara broń wraca do plecaka")
	assert_eq(h.inv.weapon_damage(), 7)

func test_bag_capacity():
	var inv := Inventory.new(2, 2)
	for i in 4:
		assert_true(inv.add_item(Loot.make_item("kaptur", null, -1)))
	assert_false(inv.add_item(Loot.make_item("kaptur", null, -1)), "pełny plecak")
	assert_eq(inv.free_slots(), 0)

func test_belt():
	var inv := Inventory.new()
	assert_false(inv.belt_use("piwo"))
	inv.belt_add("piwo", 2)
	assert_true(inv.belt_use("piwo"))
	assert_eq(int(inv.belt["piwo"]), 1)
