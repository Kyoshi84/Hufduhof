class_name Rules
extends RefCounted
## JEDYNE miejsce ze wzorami gry (uproszczony system cech Warhammera -> gra akcji).
## Liczby (stałe) są w data/balance.json; tutaj tylko przełożenie cech na mechanikę.
##
##  WW  - szansa trafienia wręcz:   bazowe + WW - (WW_celu / dzielnik) - obrona_pancerza, w granicach [min, max] %
##  US  - szansa trafienia z dystansu: bazowe + US - Zr_celu / dzielnik, w granicach [min, max] %
##  K   - S  = K / 10   (dziesiątki, w dół)
##  Odp - Wt = Odp / 10
##  Zr  - szansa uniku = Zr / dzielnik (max %), przyspieszenie ataku = Zr * zr_przyspieszenie (max)
##  Int - maks. mana = Int * mnożnik + Mag * na_poziom_mag + premia postaci, siła czarów = Int / dzielnik + Mag * mnożnik
##  SW  - regeneracja many = SW * mnożnik / s,  odporność na truciznę/spaczenie = SW / dzielnik % (max)
##  Ogd - cena kupna  = cena * (bazowe - Ogd * na_ogd), min;  cena sprzedaży = cena * (bazowe + Ogd * na_ogd), max
##  A   - ataki na 10 sekund: odstęp między atakami = 10 / A (skrócony przez Zr)
##  Żyw - punkty życia = Żyw * mnożnik (domyślnie x10)
##  Obrażenia = obrażenia broni + S - Wt celu (minimum 1)
##  Sz  - prędkość ruchu = bazowa + Sz * na_punkt (px/s podłoża)
##  Mag - 0 = brak czarów; poziom wzmacnia czary
##  PP  - przy śmierci: -1 PP i odrodzenie z połową życia; bez PP powrót do zapisu
##  PO  - tylko wyświetlane

static func _b(path: String, default):
	return Data.bal(path, default)

static func strength_bonus(k: int) -> int:
	return int(floor(k / 10.0))

static func toughness_bonus(odp: int) -> int:
	return int(floor(odp / 10.0))

static func melee_hit_chance(att_ww: int, def_ww: int, def_armor: int) -> int:
	var base: int = int(_b("trafienie_wrecz/bazowe", 40))
	var div: float = float(_b("trafienie_wrecz/obrona_dzielnik_ww", 4))
	var c: int = base + att_ww - int(floor(def_ww / div)) - def_armor
	return clampi(c, int(_b("trafienie_wrecz/min", 10)), int(_b("trafienie_wrecz/max", 95)))

static func ranged_hit_chance(att_us: int, def_zr: int) -> int:
	var base: int = int(_b("trafienie_dystans/bazowe", 40))
	var div: float = float(_b("trafienie_dystans/unik_dzielnik_zr", 4))
	var c: int = base + att_us - int(floor(def_zr / div))
	return clampi(c, int(_b("trafienie_dystans/min", 10)), int(_b("trafienie_dystans/max", 95)))

static func dodge_chance(zr: int) -> int:
	return clampi(int(floor(zr / float(_b("unik/dzielnik_zr", 5)))), 0, int(_b("unik/max", 30)))

static func damage(weapon_dmg: int, s: int, target_wt: int) -> int:
	return maxi(1, weapon_dmg + s - target_wt)

## Odstęp między atakami w sekundach: 10 / A, skrócony o Zr.
static func attack_interval(a: int, zr: int) -> float:
	var window: float = float(_b("atak/okno_sekund", 10.0))
	var base: float = window / float(maxi(1, a))
	var speedup: float = minf(zr * float(_b("atak/zr_przyspieszenie", 0.0025)), float(_b("atak/zr_przyspieszenie_max", 0.25)))
	return maxf(float(_b("atak/min_odstep", 0.6)), base * (1.0 - speedup))

## Podział ataku na fazy: [zamach (zapowiedź), uderzenie, powrót] w sekundach.
static func attack_phases(a: int, zr: int) -> Array:
	var t := attack_interval(a, zr)
	var wind: float = t * float(_b("atak/zamach_udzial", 0.42))
	var hit: float = t * float(_b("atak/uderzenie_udzial", 0.08))
	return [wind, hit, t - wind - hit]

static func max_hp(zyw: int) -> int:
	return maxi(1, zyw * int(_b("zycie_mnoznik", 10)))

## Mana = Int * mnożnik + Mag * na_poziom_mag + premia postaci (heroes.json -> mana_premia).
## Mana zasila wszystkie umiejętności (także Ivo i Modraszki); Mag wzmacnia czary.
static func max_mana(intel: int, mag: int, premia: int = 0) -> int:
	return maxi(0, int(round(intel * float(_b("mana/int_mnoznik", 1.0)))) + mag * int(_b("mana/na_poziom_mag", 10)) + premia)

static func mana_regen(sw: int) -> float:
	return sw * float(_b("mana/regen_sw_mnoznik", 0.02))

## Ułamek obrażeń od trucizny/spaczenia, który przechodzi przez odporność (1.0 = całość).
static func poison_factor(sw: int) -> float:
	var res: float = minf(sw / float(_b("trucizna/odpornosc_sw_dzielnik", 2)), float(_b("trucizna/odpornosc_max", 75)))
	return 1.0 - res / 100.0

static func spell_power(intel: int, mag: int) -> int:
	return int(floor(intel / float(_b("czary/int_dzielnik", 10)))) + mag * int(_b("czary/mag_mnoznik", 3))

static func buy_price(base_price: int, ogd: int) -> int:
	var k: float = maxf(float(_b("ceny/kupno_min", 0.8)), float(_b("ceny/kupno_bazowe", 1.5)) - ogd * float(_b("ceny/kupno_na_ogd", 0.01)))
	return maxi(1, int(ceil(base_price * k)))

static func sell_price(base_price: int, ogd: int) -> int:
	var k: float = minf(float(_b("ceny/sprzedaz_max", 0.6)), float(_b("ceny/sprzedaz_bazowe", 0.15)) + ogd * float(_b("ceny/sprzedaz_na_ogd", 0.005)))
	return maxi(1, int(floor(base_price * k)))

static func move_speed(sz: int) -> float:
	return float(_b("ruch/bazowa", 40.0)) + sz * float(_b("ruch/na_punkt_sz", 18.0))

## --- rozstrzyganie ataków (losowanie z podanego RNG, by testy były powtarzalne) ---

## Wynik: {hit, dodged, damage, chance}
static func resolve_melee(att: Stats, weapon_dmg: int, def: Stats, def_armor: int, rng: RandomNumberGenerator, mult: float = 1.0, bonus_dmg: int = 0) -> Dictionary:
	var chance := melee_hit_chance(att.val("WW"), def.val("WW"), def_armor)
	var res := {"hit": false, "dodged": false, "damage": 0, "chance": chance}
	if rng.randi_range(1, 100) > chance:
		return res
	if rng.randi_range(1, 100) <= dodge_chance(def.val("Zr")):
		res["dodged"] = true
		return res
	res["hit"] = true
	res["damage"] = maxi(1, int(round((damage(weapon_dmg, att.val("S"), def.val("Wt")) + bonus_dmg) * mult)))
	return res

## Rzut na trafienie pociskiem przy wypuszczeniu: przy pudle pocisk leci obok celu (widać, że chybił).
static func ranged_roll(att: Stats, def: Stats, rng: RandomNumberGenerator) -> bool:
	return rng.randi_range(1, 100) <= ranged_hit_chance(att.val("US"), def.val("Zr"))

static func projectile_damage(att: Stats, weapon_dmg: int, def: Stats) -> int:
	return damage(weapon_dmg, att.val("S"), def.val("Wt"))

## Obrażenia czaru: bazowe + siła czarów (Int, Mag); Wt celu odejmuje się o połowę.
static func spell_damage(base: int, att: Stats, def: Stats) -> int:
	return maxi(1, base + spell_power(att.val("Int"), att.val("Mag")) - int(floor(def.val("Wt") / 2.0)))

## --- umiejętności bohatera ---
## Obrażenia umiejętności (przed rzutem na trafienie):
##   skalowanie "bron": (obrażenia broni + obrazenia_bazowe) + S - Wt celu
##   skalowanie "czar": obrazenia_bazowe + siła czarów (Int/10 + Mag*3) - Wt/2
## potem x mnoznik umiejętności x hero_damage_multiplier (balance.json) x (1 + wzmocnienie, np. Okrzyk).
static func skill_damage(skill: Dictionary, att: Stats, def: Stats, weapon_dmg: int, buff: float = 0.0) -> int:
	var base := 0
	if str(skill.get("skalowanie", "bron")) == "czar":
		base = spell_damage(int(skill.get("obrazenia_bazowe", 0)), att, def)
	else:
		base = damage(weapon_dmg + int(skill.get("obrazenia_bazowe", 0)), att.val("S"), def.val("Wt"))
	var dmg := base * float(skill.get("mnoznik", 1.0)) * float(_b("hero_damage_multiplier", 1.0)) * (1.0 + buff)
	return maxi(1, int(round(dmg)))

## Rzut bohatera po kontakcie hitboxu: trafienie pełne albo draśnięcie (nieudany rzut na WW/US lub unik wroga).
## Kontakt zawsze rani - dzięki temu cios/pocisk, który wizualnie trafił, nigdy nie daje "Pudła".
static func hero_hit(att: Stats, def: Stats, def_armor: int, ranged: bool, base_dmg: int, rng: RandomNumberGenerator) -> Dictionary:
	var chance := ranged_hit_chance(att.val("US"), def.val("Zr")) if ranged else melee_hit_chance(att.val("WW"), def.val("WW"), def_armor)
	var full := rng.randi_range(1, 100) <= chance
	if full and not ranged and rng.randi_range(1, 100) <= dodge_chance(def.val("Zr")):
		full = false
	var dmg := base_dmg
	if not full:
		dmg = maxi(1, int(round(base_dmg * float(_b("walka_bohatera/drasniecie_mnoznik", 0.5)))))
	return {"hit": true, "glancing": not full, "damage": dmg, "chance": chance}

## Ile razy na sekundę można użyć umiejętności przy przytrzymaniu przycisku.
static func skill_rate(skill: Dictionary) -> float:
	var cycle := maxf(float(skill.get("zamach", 0.2)) + float(skill.get("powrot", 0.2)), float(skill.get("odnowienie", 0.2)))
	return 1.0 / maxf(0.05, cycle)

## Po ilu sekundach ciągłego używania umiejętności skończy się mana (z regeneracją z SW).
static func seconds_to_empty(skill: Dictionary, max_mana_v: float, sw: int) -> float:
	var drain := float(skill.get("koszt_many", 0)) * skill_rate(skill) - mana_regen(sw)
	return INF if drain <= 0.0 else max_mana_v / drain
