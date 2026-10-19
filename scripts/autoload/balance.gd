extends Node
## Wczytuje data/balance.json. Wszystkie parametry balansu żyją w JSON-ie, nie w kodzie.

const PATH := "res://data/balance.json"
const ATTACK_DEFAULTS := {
	"windup": 0.2, "active": 0.1, "recover": 0.3, "damage": 10.0, "reach": 80.0, "back": 0.0,
	"depth": 36.0, "knockback": 150.0, "stun": 0.3, "lunge": 0.0, "cooldown": 0.0,
	"interrupts": false, "breaks_poise": false, "track": false, "sfx": "swing", "hit_sfx": "hit",
}

var data: Dictionary = {}

func _ready() -> void:
	load_data()

func load_data(path: String = PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Balance: nie można otworzyć %s" % path)
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Balance: niepoprawny JSON w %s" % path)
		return false
	data = parsed
	return true

func world(key: String):
	return data["world"][key]

func player() -> Dictionary:
	return data["player"]

func enemy(type_id: String) -> Dictionary:
	return data["enemies"][type_id]

## Zwraca słownik definicji ataków uzupełniony wartościami domyślnymi.
func build_attacks(raw: Dictionary) -> Dictionary:
	var out := {}
	for name in raw.keys():
		var d: Dictionary = ATTACK_DEFAULTS.duplicate()
		d["depth"] = float(world("depth_tolerance"))
		for k in raw[name].keys():
			d[k] = raw[name][k]
		out[name] = d
	return out

func validate() -> Array:
	var errors: Array = []
	for key in ["world", "player", "enemies"]:
		if not data.has(key):
			errors.append("brak sekcji '%s'" % key)
	if errors.is_empty():
		for id in data["enemies"].keys():
			var e: Dictionary = data["enemies"][id]
			for req in ["max_hp", "speed", "attacks", "behavior"]:
				if not e.has(req):
					errors.append("%s: brak pola '%s'" % [id, req])
	return errors
