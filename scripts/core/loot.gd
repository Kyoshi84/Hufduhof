class_name Loot
extends RefCounted
## Losowanie łupów z tabel w data/loot.json i tworzenie przedmiotów (z afiksami).
## Przedmiot to słownik: {"id": "miecz", "afiks": -1 albo indeks w items.json/afiksy}.

## Losuje łup z tabeli. Zwraca listę: {"typ": "korony", "ilosc": n} / {"typ": "mikstura_zycia"} / {"typ": "przedmiot", "item": {...}}
static func roll_table(table_id: String, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var table: Dictionary = Data.loot.get("tabele", {}).get(table_id, {})
	if table.is_empty():
		return out
	for i in int(table.get("losowania", 1)):
		var entry := pick_weighted(table.get("pozycje", []), rng)
		if entry.is_empty():
			continue
		var typ: String = str(entry.get("typ", "nic"))
		match typ:
			"nic":
				pass
			"korony":
				out.append({"typ": "korony", "ilosc": rng.randi_range(int(entry.get("min", 1)), int(entry.get("max", 1)))})
			"przedmiot":
				var pool: Array = Data.loot.get("pule", {}).get(str(entry.get("pula", "")), [])
				if not pool.is_empty():
					var base_id: String = str(pool[rng.randi_range(0, pool.size() - 1)])
					out.append({"typ": "przedmiot", "item": make_item(base_id, rng)})
			_:
				out.append({"typ": typ})
	return out

static func pick_weighted(entries: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for e in entries:
		total += float(e.get("waga", 0))
	if total <= 0.0:
		return {}
	var r := rng.randf() * total
	for e in entries:
		r -= float(e.get("waga", 0))
		if r < 0.0:
			return e
	return entries[entries.size() - 1]

## Tworzy przedmiot; z szansą magiczny_szansa dostaje losowy afiks.
static func make_item(base_id: String, rng: RandomNumberGenerator = null, force_affix: int = -2) -> Dictionary:
	var it := {"id": base_id, "afiks": -1}
	var affixes: Array = Data.items.get("afiksy", [])
	if force_affix >= -1:
		it["afiks"] = force_affix
	elif rng != null and not affixes.is_empty() and rng.randi_range(1, 100) <= int(Data.loot.get("magiczny_szansa", 0)):
		it["afiks"] = rng.randi_range(0, affixes.size() - 1)
	return it

static func item_def(it: Dictionary) -> Dictionary:
	return Data.item(str(it.get("id", "")))

static func item_name(it: Dictionary) -> String:
	var d := item_def(it)
	var n: String = str(d.get("nazwa", it.get("id", "?")))
	var a := _affix(it)
	if not a.is_empty():
		n += " " + str(a.get("nazwa", ""))
	return n

static func _affix(it: Dictionary) -> Dictionary:
	var idx: int = int(it.get("afiks", -1))
	var affixes: Array = Data.items.get("afiksy", [])
	if idx >= 0 and idx < affixes.size():
		return affixes[idx]
	return {}

## Suma premii do cech: bazowe przedmiotu + afiks.
static func item_bonus(it: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for src in [item_def(it).get("bonus", {}), _affix(it).get("bonus", {})]:
		for k in src:
			out[k] = int(out.get(k, 0)) + int(src[k])
	return out

static func item_price(it: Dictionary) -> int:
	var p: float = float(item_def(it).get("cena", 1))
	if not _affix(it).is_empty():
		p *= float(Data.items.get("afiks_mnoznik_ceny", 1.5))
	return int(round(p))

static func is_magic(it: Dictionary) -> bool:
	return not _affix(it).is_empty()

static func item_slot(it: Dictionary) -> String:
	return str(item_def(it).get("slot", ""))

static func describe(it: Dictionary) -> String:
	var d := item_def(it)
	var lines: Array = []
	if d.has("obrazenia"):
		lines.append("Obrażenia: %d" % int(d["obrazenia"]))
	if d.has("obrona") and int(d["obrona"]) != 0:
		lines.append("Obrona: %d" % int(d["obrona"]))
	var b := item_bonus(it)
	for k in b:
		lines.append("%s %+d" % [Stats.LABELS.get(k, k), int(b[k])])
	return "\n".join(lines)
