class_name Inventory
extends RefCounted
## Ekwipunek: siatka plecaka (każdy przedmiot zajmuje 1 pole), sloty broni/zbroi/hełmu/amuletu,
## pas z miksturami (liczniki) i korony.

const SLOTS := ["bron", "zbroja", "helm", "amulet"]
const SLOT_NAMES := {"bron": "Broń", "zbroja": "Zbroja", "helm": "Hełm", "amulet": "Amulet"}
const BELT := ["mikstura_zycia", "mikstura_many", "piwo"]

var width: int = 8
var height: int = 4
var bag: Array = []                 # null albo słownik przedmiotu
var equipped: Dictionary = {}       # slot -> przedmiot
var belt: Dictionary = {"mikstura_zycia": 0, "mikstura_many": 0, "piwo": 0}
var gold: int = 0

func _init(w: int = 8, h: int = 4) -> void:
	width = w
	height = h
	bag.resize(w * h)
	bag.fill(null)

func capacity() -> int:
	return width * height

func free_slots() -> int:
	var n := 0
	for it in bag:
		if it == null:
			n += 1
	return n

func add_item(it: Dictionary) -> bool:
	for i in bag.size():
		if bag[i] == null:
			bag[i] = it
			return true
	return false

func remove_at(i: int) -> Dictionary:
	if i < 0 or i >= bag.size() or bag[i] == null:
		return {}
	var it: Dictionary = bag[i]
	bag[i] = null
	return it

## Zakłada przedmiot z plecaka; poprzedni z tego slotu wraca na jego miejsce.
func equip_from_bag(i: int) -> bool:
	if i < 0 or i >= bag.size() or bag[i] == null:
		return false
	var it: Dictionary = bag[i]
	var slot := Loot.item_slot(it)
	if not slot in SLOTS:
		return false
	var old = equipped.get(slot)
	equipped[slot] = it
	bag[i] = old
	return true

func unequip(slot: String) -> bool:
	if not equipped.has(slot) or equipped[slot] == null:
		return false
	if not add_item(equipped[slot]):
		return false
	equipped.erase(slot)
	return true

func bonus_totals() -> Dictionary:
	var out: Dictionary = {}
	for slot in SLOTS:
		var it = equipped.get(slot)
		if it == null:
			continue
		var b := Loot.item_bonus(it)
		for k in b:
			out[k] = int(out.get(k, 0)) + int(b[k])
	return out

func armor_defense() -> int:
	var d := 0
	for slot in SLOTS:
		var it = equipped.get(slot)
		if it != null:
			d += int(Loot.item_def(it).get("obrona", 0))
	return d

func weapon_damage() -> int:
	var it = equipped.get("bron")
	if it == null:
		return 2   # pięści
	return int(Loot.item_def(it).get("obrazenia", 2))

func belt_add(id: String, n: int = 1) -> void:
	belt[id] = int(belt.get(id, 0)) + n

func belt_use(id: String) -> bool:
	if int(belt.get(id, 0)) <= 0:
		return false
	belt[id] = int(belt[id]) - 1
	return true

func to_dict() -> Dictionary:
	return {"w": width, "h": height, "bag": bag.duplicate(true), "equipped": equipped.duplicate(true),
			"belt": belt.duplicate(), "gold": gold}

static func from_dict(d: Dictionary) -> Inventory:
	var inv := Inventory.new(int(d.get("w", 8)), int(d.get("h", 4)))
	var b: Array = d.get("bag", [])
	for i in mini(b.size(), inv.bag.size()):
		inv.bag[i] = b[i] if b[i] is Dictionary else null
	var eq: Dictionary = d.get("equipped", {})
	for slot in eq:
		if eq[slot] is Dictionary:
			inv.equipped[slot] = eq[slot]
	var belt_d: Dictionary = d.get("belt", {})
	for k in BELT:
		inv.belt[k] = int(belt_d.get(k, 0))
	inv.gold = int(d.get("gold", 0))
	return inv
