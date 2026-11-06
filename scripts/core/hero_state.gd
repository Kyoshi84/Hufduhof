class_name HeroState
extends RefCounted
## Trwały stan bohatera: profil cech, doświadczenie, rozdane punkty, ekwipunek, życie i mana.
## Logika rozwoju (punkty za XP, limity) jest tu, by dało się ją testować bez sceny.

var id: String = "ivo"
var stats: Stats
var inv: Inventory
var xp: int = 0
var points_spent: int = 0
var raised: Dictionary = {}      # ile razy podniesiono daną cechę (do wyświetlania)
var hp: float = 1.0
var mana: float = 0.0

static func create(hero_id: String) -> HeroState:
	var h := HeroState.new()
	h.id = hero_id
	var def := Data.hero(hero_id)
	h.stats = Stats.from_profile(def.get("profil", {}))
	h.inv = Inventory.new(int(Data.bal("plecak/szerokosc", 8)), int(Data.bal("plecak/wysokosc", 4)))
	var eq: Dictionary = def.get("ekwipunek", {})
	for slot in eq:
		h.inv.equipped[slot] = Loot.make_item(str(eq[slot]), null, -1)
	var belt: Dictionary = def.get("pas", {})
	for k in belt:
		h.inv.belt[k] = int(belt[k])
	h.inv.gold = int(def.get("korony", 0))
	h.refresh_bonuses()
	h.hp = h.max_hp()
	h.mana = h.max_mana()
	return h

func refresh_bonuses() -> void:
	stats.bonus = inv.bonus_totals()
	hp = minf(hp, max_hp())
	mana = minf(mana, max_mana())

func max_hp() -> int:
	return stats.max_hp()

func max_mana() -> int:
	return stats.max_mana()

func display_name() -> String:
	return str(Data.hero(id).get("imie", id))

# ---------------------------------------------------------------- rozwój

static func thresholds() -> Array:
	return Data.bal("rozwoj/progi_xp", [])

## Ile punktów rozwoju daje dana liczba XP (liczba przekroczonych progów).
static func points_for_xp(x: int) -> int:
	var n := 0
	for t in thresholds():
		if x >= int(t):
			n += 1
	return n

func points_total() -> int:
	return points_for_xp(xp)

func points_available() -> int:
	return points_total() - points_spent

func next_threshold() -> int:
	for t in thresholds():
		if xp < int(t):
			return int(t)
	return -1

func prev_threshold() -> int:
	var p := 0
	for t in thresholds():
		if xp >= int(t):
			p = int(t)
	return p

## Dodaje XP; zwraca liczbę nowych punktów rozwoju.
func add_xp(amount: int) -> int:
	var before := points_total()
	xp += maxi(0, amount)
	return points_total() - before

func stat_limit(k: String) -> int:
	if k in Stats.PRIMARY:
		return int(Data.bal("rozwoj/limit_glowne", 70))
	return int(Data.bal("rozwoj/limity_drugorzedne", {}).get(k, 10))

func can_raise(k: String) -> bool:
	if points_available() <= 0:
		return false
	if k in Stats.PRIMARY:
		return stats.base_val(k) + int(Data.bal("rozwoj/plus_glowna", 5)) <= stat_limit(k)
	if not k in Data.bal("rozwoj/drugorzedne_do_rozwoju", []):
		return false
	return stats.base_val(k) + int(Data.bal("rozwoj/plus_drugorzedna", 1)) <= stat_limit(k)

func raise_stat(k: String) -> bool:
	if not can_raise(k):
		return false
	var plus: int = int(Data.bal("rozwoj/plus_glowna", 5)) if k in Stats.PRIMARY else int(Data.bal("rozwoj/plus_drugorzedna", 1))
	var old_max_hp := max_hp()
	var old_max_mana := max_mana()
	stats.set_base(k, stats.base_val(k) + plus)
	points_spent += 1
	raised[k] = int(raised.get(k, 0)) + 1
	# wzrost maksimum od razu dodaje różnicę do bieżących wartości
	hp += max_hp() - old_max_hp
	mana += max_mana() - old_max_mana
	return true

# ---------------------------------------------------------------- zapis

func to_dict() -> Dictionary:
	return {"id": id, "stats": stats.to_dict(), "inv": inv.to_dict(), "xp": xp, "points_spent": points_spent,
			"raised": raised.duplicate(), "hp": hp, "mana": mana}

static func from_dict(d: Dictionary) -> HeroState:
	var h := HeroState.new()
	h.id = str(d.get("id", "ivo"))
	h.stats = Stats.from_profile(d.get("stats", Data.hero(h.id).get("profil", {})))
	h.inv = Inventory.from_dict(d.get("inv", {}))
	h.xp = int(d.get("xp", 0))
	h.points_spent = int(d.get("points_spent", 0))
	h.raised = d.get("raised", {})
	h.refresh_bonuses()
	h.hp = clampf(float(d.get("hp", h.max_hp())), 1.0, h.max_hp())
	h.mana = clampf(float(d.get("mana", h.max_mana())), 0.0, h.max_mana())
	return h
