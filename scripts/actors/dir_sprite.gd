class_name DirSprite
extends Node2D
## Grafika postaci w 8 kierunkach z folderów: <baza>/<animacja>/<kierunek>/<n>.png  (n = 0, 1, 2, ...)
## Brakujące pliki są zastępowane w kolejności: lustrzany kierunek (odbicie) -> animacja "idle" -> dowolna klatka.
## Dzięki temu da się podmieniać grafikę po jednym pliku. Pivot (stopy) i fps: <baza>/sprite.json.
## Postać bez klatek ruchu (np. Ivo - same pozy) jest "ożywiana" w kodzie: kołysanie kroku, wypad przy ataku.

const ANIMS := ["idle", "walk", "attack", "cast", "hurt", "death"]
const MIRROR := {"west": "east", "south-west": "south-east", "north-west": "north-east",
	"east": "west", "south-east": "south-west", "north-east": "north-west"}
static var _cache: Dictionary = {}

var base_path: String
var frames: Dictionary = {}     # anim -> dir -> {"tex": Array, "flip": bool}
var pivot := Vector2(48, 126)
var fps: Dictionary = {"idle": 3.0, "walk": 8.0, "hurt": 1.0, "death": 6.0, "cast": 6.0}
var sprite: Sprite2D
var anim: String = "idle"
var dir: String = "south"
var t: float = 0.0
var progress: float = -1.0      # >= 0: klatka wg postępu (atak: zamach rozłożony na klatki)
var hold_last: bool = false
var bob: float = 0.0            # przesunięcie w pionie (kroki)
var lunge := Vector2.ZERO       # przesunięcie (wypad/odskok)
var has_walk: bool = false
var has_attack: bool = false

func setup(path: String) -> void:
	base_path = path
	sprite = Sprite2D.new()
	sprite.centered = false
	add_child(sprite)
	var meta := Data.load_json(path + "/sprite.json") if FileAccess.file_exists(path + "/sprite.json") else {}
	if meta.has("pivot"):
		pivot = Vector2(float(meta["pivot"][0]), float(meta["pivot"][1]))
	for k in meta.get("fps", {}):
		fps[k] = float(meta["fps"][k])
	if _cache.has(path):
		frames = _cache[path]
	else:
		frames = _load_all(path)
		_cache[path] = frames
	has_walk = _has_own("walk")
	has_attack = _has_own("attack")
	_apply()

func _has_own(a: String) -> bool:
	return frames.has(a) and not frames[a].is_empty()

static func _load_dir(path: String) -> Array:
	var out: Array = []
	for i in 32:
		var p := "%s/%d.png" % [path, i]
		if not ResourceLoader.exists(p):
			break
		out.append(load(p))
	return out

static func _load_all(path: String) -> Dictionary:
	var res: Dictionary = {}
	for a in ANIMS:
		var per: Dictionary = {}
		for d in Iso.DIRS:
			var list := _load_dir("%s/%s/%s" % [path, a, d])
			if not list.is_empty():
				per[d] = {"tex": list, "flip": false}
		for d in Iso.DIRS:
			if not per.has(d) and per.has(MIRROR.get(d, "")) and not per[MIRROR[d]]["flip"]:
				per[d] = {"tex": per[MIRROR[d]]["tex"], "flip": true}
		if not per.is_empty():
			res[a] = per
	return res

func _entry(a: String, d: String) -> Dictionary:
	for an in [a, "idle"]:
		if frames.has(an):
			var per: Dictionary = frames[an]
			if per.has(d):
				return per[d]
			if not per.is_empty():
				return per.values()[0]
	return {}

func play(a: String, d: String = "", restart: bool = false) -> void:
	if d != "":
		dir = d
	if a != anim or restart:
		anim = a
		t = 0.0
		progress = -1.0
		hold_last = a == "death"

func set_progress(a: String, p: float, d: String = "") -> void:
	if d != "":
		dir = d
	anim = a
	progress = clampf(p, 0.0, 1.0)

func _process(delta: float) -> void:
	t += delta
	_apply()

func _apply() -> void:
	var e := _entry(anim, dir)
	if e.is_empty():
		return
	var list: Array = e["tex"]
	var idx := 0
	if progress >= 0.0:
		idx = mini(int(progress * list.size()), list.size() - 1)
	else:
		var f: float = float(fps.get(anim, 6.0))
		idx = int(t * f)
		if hold_last:
			idx = mini(idx, list.size() - 1)
		else:
			idx = idx % list.size()
	var tx: Texture2D = list[idx]
	sprite.texture = tx
	sprite.flip_h = e["flip"]
	var px := pivot.x
	if e["flip"]:
		px = tx.get_width() - pivot.x
	sprite.position = Vector2(-px, -pivot.y + bob) + lunge

func current_texture() -> Texture2D:
	return sprite.texture if sprite else null
