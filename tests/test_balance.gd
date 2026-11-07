extends GutTest
## Balans siły bohaterów: ile podstawowych ataków (slot 1, pełne trafienia) potrzeba na każdego wroga.
## Cel: skaven z dzidą 2-3, procarz 2, czarownik 3-4. Stroi się jednym mnożnikiem hero_damage_multiplier (balance.json).

const TARGET := {"skaven_spear": [2, 3], "skaven_slinger": [2, 2], "skaven_warlock": [3, 4]}

func _hits(hid: String, eid: String) -> int:
	var h := HeroState.create(hid)
	var d := Data.hero(hid)
	var sk: Dictionary = d["umiejetnosci"][d["pasek"][0]]
	var foe := Stats.from_profile(Data.enemy(eid)["profil"])
	var dmg := Rules.skill_damage(sk, h.stats, foe, int(sk.get("obrazenia", h.inv.weapon_damage())))
	return int(ceil(foe.max_hp() / float(dmg)))

func test_basic_attack_hits_to_kill():
	gut.p("hero_damage_multiplier = %s" % str(Data.bal("hero_damage_multiplier", 1.0)))
	for hid in Data.hero_ids():
		for eid in TARGET:
			var n := _hits(hid, eid)
			gut.p("%s -> %s: %d ataków" % [hid, eid, n])
			assert_between(n, int(TARGET[eid][0]), int(TARGET[eid][1]), "%s na %s" % [hid, eid])

func test_weapon_attack_is_quick_but_readable():
	for hid in Data.hero_ids():
		var s := Stats.from_profile(Data.hero(hid)["profil"])
		var ph := Rules.attack_phases(s.val("A"), s.val("Zr"))
		var k := float(Data.bal("walka_bohatera/tempo_ataku_bronia", 1.0))
		gut.p("%s: zamach %.2f s, cały atak %.2f s" % [hid, ph[0] * k, (ph[0] + ph[1] + ph[2]) * k])
		assert_between(ph[0] * k, 0.15, 0.4, hid + ": krótki, ale widoczny zamach")

func test_enemy_tempo_unchanged():
	assert_almost_eq(float(Data.enemy("skaven_spear")["zamach"]), 0.75, 0.001, "zapowiedź ataku wroga bez zmian")
	assert_eq(int(Data.enemy("skaven_spear")["profil"]["Sz"]), 4)

func test_hero_hit_does_not_cancel_enemy_telegraph():
	Game.new_game("ursa")
	var lvl := Level.new("wioska")
	add_child(lvl)
	await wait_frames(3)
	for e in lvl.enemies():
		e.queue_free()
	await wait_frames(2)
	lvl.hero.blessed = 100.0
	var e := lvl.spawn_enemy("skaven_spear", lvl.hero.position + Vector2(55, 0), "", "")
	e.hp = 999.0
	e.wake()
	for i in 120:
		await wait_frames(1)
		if e.state == Actor.St.WINDUP:
			break
	assert_eq(e.state, Actor.St.WINDUP)
	e.receive_hit({"hit": true, "damage": 10, "kind": "fiz"}, lvl.hero)
	assert_eq(e.state, Actor.St.WINDUP, "zapowiedź ataku trwa dalej")
	lvl.queue_free()
	await wait_frames(2)
