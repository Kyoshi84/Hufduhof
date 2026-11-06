class_name Stats
extends RefCounted
## Profil cech postaci (bohater albo wróg). Cechy główne 0-100, drugorzędne 0-10.
## S i Wt nie są przechowywane - wynikają z K i Odp (Rules), plus premie z ekwipunku.

const PRIMARY := ["WW", "US", "K", "Odp", "Zr", "Int", "SW", "Ogd"]
const SECONDARY := ["A", "Zyw", "S", "Wt", "Sz", "Mag", "PO", "PP"]
const LABELS := {
	"WW": "WW", "US": "US", "K": "K", "Odp": "Odp", "Zr": "Zr", "Int": "Int", "SW": "SW", "Ogd": "Ogd",
	"A": "A", "Zyw": "Żyw", "S": "S", "Wt": "Wt", "Sz": "Sz", "Mag": "Mag", "PO": "PO", "PP": "PP",
}
const NAMES := {
	"WW": "Walka wręcz", "US": "Umiejętności strzeleckie", "K": "Krzepa", "Odp": "Odporność",
	"Zr": "Zręczność", "Int": "Inteligencja", "SW": "Siła Woli", "Ogd": "Ogłada",
	"A": "Ataki", "Zyw": "Żywotność", "S": "Siła", "Wt": "Wytrzymałość", "Sz": "Szybkość",
	"Mag": "Magia", "PO": "Punkty Obłędu", "PP": "Punkty Przeznaczenia",
}
const DERIVED := ["S", "Wt"]

var base: Dictionary = {}    # wartości bazowe (bez S i Wt)
var bonus: Dictionary = {}   # premie z ekwipunku (mogą dotyczyć też S i Wt)

static func from_profile(profile: Dictionary) -> Stats:
	var s := Stats.new()
	for k in PRIMARY + SECONDARY:
		if k in DERIVED:
			continue
		s.base[k] = int(profile.get(k, 0))
	return s

func val(k: String) -> int:
	match k:
		"S":
			return Rules.strength_bonus(val("K")) + int(bonus.get("S", 0))
		"Wt":
			return Rules.toughness_bonus(val("Odp")) + int(bonus.get("Wt", 0))
	return maxi(0, int(base.get(k, 0)) + int(bonus.get(k, 0)))

func base_val(k: String) -> int:
	if k == "S":
		return Rules.strength_bonus(int(base.get("K", 0)))
	if k == "Wt":
		return Rules.toughness_bonus(int(base.get("Odp", 0)))
	return int(base.get(k, 0))

func set_base(k: String, v: int) -> void:
	base[k] = v

func to_dict() -> Dictionary:
	return base.duplicate()

func max_hp() -> int:
	return Rules.max_hp(val("Zyw"))

func max_mana() -> int:
	return Rules.max_mana(val("Int"), val("Mag"))

func move_speed() -> float:
	return Rules.move_speed(val("Sz"))
