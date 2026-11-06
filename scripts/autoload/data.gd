extends Node
## Dane gry wczytywane z plików JSON w res://data/ (balans poza kodem).
## Podmiana liczb nie wymaga zmian w skryptach.

var balance: Dictionary = {}
var heroes: Dictionary = {}
var enemies: Dictionary = {}
var items: Dictionary = {}
var loot: Dictionary = {}
var world: Dictionary = {}
var music: Dictionary = {}

func _ready() -> void:
	reload()

func reload() -> void:
	balance = load_json("res://data/balance.json")
	heroes = load_json("res://data/heroes.json")
	enemies = load_json("res://data/enemies.json")
	items = load_json("res://data/items.json")
	loot = load_json("res://data/loot.json")
	world = load_json("res://data/world.json")
	music = load_json("res://data/music.json")

func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Brak pliku danych: " + path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Błędny JSON: " + path)
		return {}
	return parsed

## Wartość z balance.json po ścieżce "a/b/c" z domyślną.
func bal(path: String, default = null):
	var cur = balance
	for part in path.split("/"):
		if cur is Dictionary and cur.has(part):
			cur = cur[part]
		else:
			return default
	return cur

func hero(id: String) -> Dictionary:
	return heroes.get("bohaterowie", {}).get(id, {})

func hero_ids() -> Array:
	return heroes.get("kolejnosc", [])

func enemy(id: String) -> Dictionary:
	return enemies.get("wrogowie", {}).get(id, {})

func item(id: String) -> Dictionary:
	return items.get("przedmioty", {}).get(id, {})

func belt_item(id: String) -> Dictionary:
	return items.get("pas", {}).get(id, {})

func shrine(kind: String) -> Dictionary:
	return world.get("kapliczki", {}).get(kind, {})

func dialog(id: String) -> Array:
	return world.get("dialogi", {}).get(id, [])

func shop(id: String) -> Dictionary:
	return world.get("handel", {}).get(id, {})
