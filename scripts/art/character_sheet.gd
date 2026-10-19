class_name CharacterSheet
extends RefCounted
## Animacje postaci ładowane z folderu assets/characters/<id>/ (patrz README tam):
##   character.json            manifest: rozmiar płótna, pivot, lista animacji (fps, pętla, klatki kontaktu)
##   anim/<nazwa>/<nazwa>_00.png, _01.png, ...   klatki (zwrócone w PRAWO; w lewo gra odbija lustrzanie)
## Brak folderu/animacji nie jest błędem: gra używa wtedy grafiki zapasowej.
## Klatki ataków są dobierane NIE wg zegara, tylko wg fazy ataku (zamach/trafienie/powrót), więc klatka
## kontaktu pokrywa się z oknem aktywnego hitboxa.

static var root: String = "res://assets/characters"
static var _cache: Dictionary = {}

var id: String = ""
var pivot: Vector2 = Vector2.ZERO
var frame_size: Vector2 = Vector2.ZERO
var wpt: float = 4.0 / 3.0
var anims: Dictionary = {}     # nazwa -> { "tex": Array, "fps": float, "loop": bool, "contact": Array }

static func clear_cache() -> void:
	_cache.clear()

## Zwraca arkusz albo null (brak manifestu lub brak jakichkolwiek klatek).
static func get_sheet(char_id: String) -> CharacterSheet:
	var key: String = root + "/" + char_id
	if _cache.has(key):
		return _cache[key]
	var s := CharacterSheet.new()
	_cache[key] = s if s._load(char_id) else null
	return _cache[key]

static func load_tex(path: String) -> Texture2D:
	if path.begins_with("res://") and ResourceLoader.exists(path):
		return load(path) as Texture2D
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null:
			return ImageTexture.create_from_image(img)
	return null

func _load(char_id: String) -> bool:
	id = char_id
	var mpath: String = "%s/%s/character.json" % [root, id]
	if not FileAccess.file_exists(mpath):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(mpath))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	frame_size = Vector2(float(parsed["frame_size"][0]), float(parsed["frame_size"][1]))
	pivot = Vector2(float(parsed["pivot"][0]), float(parsed["pivot"][1]))
	wpt = float(parsed.get("world_per_texel", wpt))
	for name in parsed["animations"].keys():
		var spec: Dictionary = parsed["animations"][name]
		var frames: Array = []
		for i in 64:
			var t := load_tex("%s/%s/anim/%s/%s_%02d.png" % [root, id, name, name, i])
			if t == null:
				break
			frames.append(t)
		if frames.is_empty():
			continue
		var d := { "tex": frames, "fps": float(spec.get("fps", 8.0)), "loop": bool(spec.get("loop", false)) }
		if spec.has("contact"):
			d["contact"] = [int(spec["contact"][0]), int(spec["contact"][1])]
		anims[name] = d
	return not anims.is_empty()

func has_anim(name: String) -> bool:
	return anims.has(name)

## Indeks klatki dla aktora. Ataki: wg fazy (zamach -> kontakt -> powrót). Reszta: wg czasu/fps.
func frame_index(name: String, a, visual_time: float) -> int:
	var d: Dictionary = anims[name]
	var n: int = (d["tex"] as Array).size()
	if n <= 1:
		return 0
	var st: int = a.state
	var attacking: bool = st == Actor.State.WINDUP or st == Actor.State.ACTIVE or st == Actor.State.RECOVER
	if d.has("contact") and attacking and not a.attack.is_empty():
		var c0: int = clampi(int(d["contact"][0]), 0, n - 1)
		var c1: int = clampi(int(d["contact"][1]), c0, n - 1)
		match st:
			Actor.State.WINDUP:
				if c0 == 0:
					return 0
				var p: float = clampf(a.state_t / maxf(a.windup_time(), 0.001), 0.0, 1.0)
				return mini(int(p * c0), c0 - 1)
			Actor.State.ACTIVE:
				var p2: float = clampf(a.state_t / maxf(float(a.attack["active"]), 0.001), 0.0, 1.0)
				return c0 + mini(int(p2 * float(c1 - c0 + 1)), c1 - c0)
			_:
				if c1 >= n - 1:
					return n - 1
				var p3: float = clampf(a.state_t / maxf(float(a.attack["recover"]), 0.001), 0.0, 1.0)
				return c1 + 1 + mini(int(p3 * float(n - 1 - c1)), n - 2 - c1)
	var fps: float = maxf(float(d["fps"]), 1.0)
	if bool(d["loop"]):
		return int(visual_time * fps) % n
	var src: float = a.dead_t if name == "die" else a.state_t
	return mini(int(src * fps), n - 1)
