class_name Heroes
extends RefCounted
## Lista bohaterów do wyboru (data/heroes.json): imię, tytuł, opis, portret, czy można wybrać.
## Statystyki i ataki są w data/balance.json (Balance.hero). Grafika w grze: assets/characters/<id>/poses/.

const PATH := "res://data/heroes.json"
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = parsed if typeof(parsed) == TYPE_DICTIONARY else { "default": "ivo", "heroes": [] }
	return _data

static func all() -> Array:
	return data().get("heroes", [])

static func get_hero(hero_id: String) -> Dictionary:
	for h in all():
		if str(h.get("id", "")) == hero_id:
			return h
	return {}

static func is_selectable(hero_id: String) -> bool:
	return bool(get_hero(hero_id).get("selectable", false))

static func default_id() -> String:
	return str(data().get("default", "ivo"))

## Bohater do zaznaczenia na starcie ekranu wyboru: ostatnio wybrany, jeśli nadal dostępny.
static func preferred(last: String) -> String:
	return last if is_selectable(last) else default_id()

static func display_name(hero_id: String) -> String:
	var h := get_hero(hero_id)
	return str(h.get("name", hero_id.capitalize()))

## Krótkie imię na pasek zdrowia (pierwsze słowo, wielkie litery): "IVO", "URSA".
static func hud_name(hero_id: String) -> String:
	return display_name(hero_id).split(" ")[0].to_upper()
