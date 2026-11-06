extends GutTest
## Formuły walki i cech (scripts/core/rules.gd).

func _stats(p: Dictionary) -> Stats:
	var base := {"WW": 30, "US": 30, "K": 30, "Odp": 30, "Zr": 30, "Int": 30, "SW": 30, "Ogd": 30,
		"A": 5, "Zyw": 5, "Sz": 4, "Mag": 0, "PO": 0, "PP": 0}
	base.merge(p, true)
	return Stats.from_profile(base)

func test_s_and_wt_are_tens_of_k_and_odp():
	var s := _stats({"K": 38, "Odp": 41})
	assert_eq(s.val("S"), 3)
	assert_eq(s.val("Wt"), 4)
	assert_eq(Rules.strength_bonus(9), 0)
	assert_eq(Rules.strength_bonus(100), 10)

func test_item_bonus_to_wt_adds_on_top():
	var s := _stats({"Odp": 36})
	s.bonus = {"Wt": 1}
	assert_eq(s.val("Wt"), 4)

func test_damage_formula_weapon_plus_s_minus_wt_min_1():
	assert_eq(Rules.damage(8, 3, 3), 8)
	assert_eq(Rules.damage(5, 3, 4), 4)
	assert_eq(Rules.damage(1, 0, 9), 1, "minimum 1")

func test_melee_hit_chance_clamped():
	# bazowe 40 + WW 41 - (30/4=7) - pancerz 2
	assert_eq(Rules.melee_hit_chance(41, 30, 2), 72)
	assert_eq(Rules.melee_hit_chance(0, 100, 50), 10, "minimum 10%")
	assert_eq(Rules.melee_hit_chance(100, 0, 0), 95, "maksimum 95%")

func test_ranged_hit_chance_uses_us_and_target_zr():
	assert_eq(Rules.ranged_hit_chance(35, 32), 40 + 35 - 8)
	assert_eq(Rules.ranged_hit_chance(0, 100), 15)
	assert_eq(Rules.ranged_hit_chance(0, 400), 10, "minimum 10%")

func test_dodge_from_zr_capped():
	assert_eq(Rules.dodge_chance(35), 7)
	assert_eq(Rules.dodge_chance(100), 20)
	assert_true(Rules.dodge_chance(1000) <= 30)

func test_attack_interval_from_a_and_zr():
	var slow := Rules.attack_interval(5, 0)
	assert_almost_eq(slow, 2.0, 0.001, "A=5 -> 5 ataków na 10 s")
	assert_true(Rules.attack_interval(5, 40) < slow, "Zr przyspiesza atak")
	assert_true(Rules.attack_interval(10, 100) >= 0.6, "minimalny odstęp")
	var ph := Rules.attack_phases(6, 31)
	assert_almost_eq(ph[0] + ph[1] + ph[2], Rules.attack_interval(6, 31), 0.0001)
	assert_true(ph[0] > 0.4, "wyczuwalny zamach")

func test_hp_is_zyw_times_multiplier():
	assert_eq(Rules.max_hp(9), 90)
	assert_eq(_stats({"Zyw": 6}).max_hp(), 60)

func test_mana_only_with_magic():
	assert_eq(Rules.max_mana(46, 0), 0)
	assert_eq(Rules.max_mana(46, 2), 66, "Int + Mag x 10")

func test_sw_regen_and_poison_resistance():
	assert_almost_eq(Rules.mana_regen(40), 0.8, 0.0001)
	assert_almost_eq(Rules.poison_factor(40), 0.8, 0.0001)
	assert_almost_eq(Rules.poison_factor(1000), 0.25, 0.0001, "odporność max 75%")

func test_ogd_prices():
	assert_true(Rules.buy_price(100, 50) < Rules.buy_price(100, 20), "lepsza Ogłada = taniej")
	assert_true(Rules.sell_price(100, 50) > Rules.sell_price(100, 20), "lepsza Ogłada = drożej sprzedane")
	assert_true(Rules.sell_price(100, 100) <= 60)
	assert_true(Rules.buy_price(100, 100) >= 80)

func test_move_speed_from_sz():
	assert_true(Rules.move_speed(5) > Rules.move_speed(4))

func test_resolve_melee_deterministic_and_bounded():
	var att := _stats({"WW": 60, "K": 40})
	var def := _stats({"WW": 20, "Odp": 30, "Zr": 0})
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var hits := 0
	for i in 400:
		var r := Rules.resolve_melee(att, 8, def, 0, rng)
		if r["hit"]:
			hits += 1
			assert_eq(r["damage"], 8 + 4 - 3)
	# szansa = 40 + 60 - 5 = 95%
	assert_between(hits, 360, 400)

func test_spell_damage_scales_with_int_and_mag():
	var weak := _stats({"Int": 30, "Mag": 1})
	var strong := _stats({"Int": 50, "Mag": 3})
	var tgt := _stats({})
	assert_true(Rules.spell_damage(10, strong, tgt) > Rules.spell_damage(10, weak, tgt))
