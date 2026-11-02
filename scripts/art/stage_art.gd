class_name StageArt
extends RefCounted
## Grafika etapu z folderu assets/stages/<folder>/ (patrz README tam):
##   stage.json                     manifest: warstwy (paralaksa, y_offset) i opisy rekwizytów
##   sky.png, far1.png, far2.png, ground.png, foreground.png   warstwy (powtarzane poziomo)
##   props/<nazwa>.png, <nazwa>_2.png ... <nazwa>_6.png          rekwizyty (pivot = środek dolnej krawędzi)
## Każdy brakujący plik = zapas (grafika proceduralna). Rekwizyty są tylko dekoracją.

static var root: String = "res://assets/stages"
static var _cache: Dictionary = {}

var folder: String = ""
var wpt: float = 4.0 / 3.0
var layers: Dictionary = {}          # nazwa -> { "tex", "parallax", "y_offset" }
var _props: Dictionary = {}          # nazwa -> Array[Texture2D] (puste = brak)
var decal_cfg: Dictionary = {}       # decals.json: nakładki terenu (rozdroża, skarpy, bruk...); puste = brak
var _decals: Dictionary = {}         # nazwa -> Array[[Texture2D, y_px]]

static func clear_cache() -> void:
	_cache.clear()

static func get_stage(folder_name: String) -> StageArt:
	if folder_name == "":
		return null
	var key: String = root + "/" + folder_name
	if _cache.has(key):
		return _cache[key]
	var s := StageArt.new()
	_cache[key] = s if s._load(folder_name) else null
	return _cache[key]

func _load(folder_name: String) -> bool:
	folder = folder_name
	var base: String = "%s/%s" % [root, folder]
	var mpath: String = base + "/stage.json"
	if not FileAccess.file_exists(mpath):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(mpath))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	wpt = float(parsed.get("world_per_texel", wpt))
	for lname in parsed.get("layers", {}).keys():
		var spec: Dictionary = parsed["layers"][lname]
		var tex := CharacterSheet.load_tex("%s/%s" % [base, str(spec["file"])])
		if tex != null:
			layers[lname] = { "tex": tex, "parallax": float(spec.get("parallax", 0.0)), "y_offset": float(spec.get("y_offset", 0.0)) }
	var dpath: String = base + "/decals.json"
	if FileAccess.file_exists(dpath):
		var dc = JSON.parse_string(FileAccess.get_file_as_string(dpath))
		if typeof(dc) == TYPE_DICTIONARY:
			decal_cfg = dc
	return true

## Warianty nakładki terenu: [[tekstura, y w px pod horyzontem], ...] z decals/<plik> (leniwie, zapamiętywane).
func decal_variants(dname: String) -> Array:
	if _decals.has(dname):
		return _decals[dname]
	var out: Array = []
	for spec in decal_cfg.get("decals", {}).get(dname, []):
		var t := CharacterSheet.load_tex("%s/%s/decals/%s" % [root, folder, str(spec["file"])])
		if t != null:
			out.append([t, float(spec.get("y", 0))])
	_decals[dname] = out
	return out

func layer(lname: String) -> Dictionary:
	return layers.get(lname, {})

## Warianty rekwizytu: props/<nazwa>.png, <nazwa>_2.png ... (wczytywane leniwie i zapamiętywane).
func prop_variants(pname: String) -> Array:
	if _props.has(pname):
		return _props[pname]
	var out: Array = []
	var base: String = "%s/%s/props/" % [root, folder]
	var first := CharacterSheet.load_tex(base + pname + ".png")
	if first != null:
		out.append(first)
	for i in range(2, 7):
		var t := CharacterSheet.load_tex(base + "%s_%d.png" % [pname, i])
		if t != null:
			out.append(t)
	_props[pname] = out
	return out

## Pierwsza tekstura wspólnego rekwizytu (beczka, mikstura) z assets/stages/common/props/ albo null.
static func common_prop(pname: String) -> Texture2D:
	var s := get_stage("common")
	if s == null:
		return null
	var v: Array = s.prop_variants(pname)
	return v[0] if not v.is_empty() else null
