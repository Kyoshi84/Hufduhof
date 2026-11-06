extends Node
## Stan bieżącej rozgrywki: bohater, poziom, zadanie, flagi świata (otwarte skrzynie, użyte kapliczki,
## zabici wrogowie, podniesione wiadra) i odkryta mgła wojny. Zapis/odczyt: autoload Save.

signal hero_changed
signal message(text: String, color: Color)
signal quest_changed

var hero: HeroState = null
var level_id: String = ""
var quest: BucketQuest = BucketQuest.new()
var flags: Dictionary = {}
var explored: Dictionary = {}
var spawn_pos = null
var debug_collision: bool = false
var borubar_rewarded: bool = false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func new_game(hero_id: String) -> void:
	hero = HeroState.create(hero_id)
	level_id = "karczma"
	quest = BucketQuest.new()
	flags = {}
	explored = {}
	spawn_pos = null
	borubar_rewarded = false

func has_flag(list: String, id: String) -> bool:
	return id in flags.get(list, [])

func add_flag(list: String, id: String) -> void:
	if not flags.has(list):
		flags[list] = []
	if not id in flags[list]:
		flags[list].append(id)

func notify(text: String, col: Color = Color(0.95, 0.88, 0.7)) -> void:
	message.emit(text, col)

## XP za zabicie / zadanie, z komunikatem o nowym punkcie rozwoju.
func give_xp(amount: int, reason: String = "") -> void:
	if hero == null or amount <= 0:
		return
	var gained := hero.add_xp(amount)
	if gained > 0:
		notify("Nowy punkt rozwoju! (ekran Postać)", Color(1.0, 0.85, 0.3))
		Audio.play("levelup")
	hero_changed.emit()

func quest_xp(key: String) -> void:
	give_xp(int(Data.bal("xp_zadania/" + key, 0)), key)

func to_save_dict(pos: Vector2) -> Dictionary:
	return {
		"version": 1,
		"hero": hero.to_dict(),
		"level": level_id,
		"pos": [pos.x, pos.y],
		"quest": quest.to_dict(),
		"flags": flags.duplicate(true),
		"explored": explored.duplicate(),
		"borubar_rewarded": borubar_rewarded,
	}

func load_from_dict(d: Dictionary) -> bool:
	if not d.has("hero"):
		return false
	hero = HeroState.from_dict(d["hero"])
	level_id = str(d.get("level", "wioska"))
	quest = BucketQuest.from_dict(d.get("quest", {}))
	flags = d.get("flags", {})
	explored = d.get("explored", {})
	borubar_rewarded = bool(d.get("borubar_rewarded", false))
	var p: Array = d.get("pos", [])
	spawn_pos = Vector2(float(p[0]), float(p[1])) if p.size() == 2 else null
	return true
