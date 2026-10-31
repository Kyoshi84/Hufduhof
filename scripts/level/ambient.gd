class_name Ambient
extends Node2D
## Uciekający wieśniacy (etap 2: wieś) i leśne zwierzęta (etap 3: sarny, zające, nietoperze w stylu rysunków z marginesów
## średniowiecznych rękopisów). Wyłącznie dekoracja: nie wchodzą w interakcję z walką ani z przeszkodami.
## Grafiki: assets/minigame/guest_N.png (wieśniacy) i assets/stages/stage3_fields_forest/critters/<nazwa>_1/2.png.

const WPT := 4.0 / 3.0
const MAX_VILLAGERS := 5
const MAX_ANIMALS := 8
const VILLAGER_FILES := ["guest_1", "guest_2", "guest_3", "guest_5", "guest_6", "guest_4"]
const ANIMAL_DIR := "res://assets/stages/stage3_fields_forest/critters/"

class Critter extends Node2D:
	var kind: String = "hare"
	var frames: Array = []
	var vx: float = -200.0
	var rate: float = 8.0
	var t: float = 0.0
	var alt: float = 0.0               # nietoperze: wysokość lotu
	var scl: float = WPT
	var phase: float = 0.0

	func _process(delta: float) -> void:
		t += delta
		position.x += vx * delta
		queue_redraw()

	func lift() -> float:
		match kind:
			"hare": return absf(sin(t * 8.0 + phase)) * 24.0
			"deer": return absf(sin(t * 5.5 + phase)) * 30.0
			"bat": return alt + sin(t * 2.6 + phase) * 18.0
			_: return absf(sin(t * 13.0 + phase)) * 9.0

	func _draw() -> void:
		if frames.is_empty():
			return
		var fr: Texture2D = frames[int(t * rate) % frames.size()]
		var w: float = fr.get_width() * scl
		var h: float = fr.get_height() * scl
		var up: float = lift()
		if kind != "bat":
			var sh := PackedVector2Array()
			for i in 16:
				var a: float = TAU * i / 16.0
				sh.append(Vector2(cos(a) * w * 0.36, sin(a) * 6.0))
			draw_colored_polygon(sh, Color(0, 0, 0, 0.30 - minf(up, 30.0) * 0.004))
		var flip: bool = vx > 0.0 and kind != "villager"        # zwierzęta narysowane zwrócone w lewo
		var tilt: float = 0.14 * signf(vx) * sin(t * 13.0 + phase) if kind == "villager" else 0.0
		draw_set_transform(Vector2(0, -up), tilt, Vector2(-1.0 if flip else 1.0, 1.0))
		draw_texture_rect(fr, Rect2(-w * 0.5, -h, w, h), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

var level
var spawn_t: float = 0.6
var critters: Array = []
var _tex: Dictionary = {}

func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]

func count_kind(villagers: bool) -> int:
	var n := 0
	for c in critters:
		if is_instance_valid(c) and (c.kind == "villager") == villagers:
			n += 1
	return n

## Tworzy jedną postać; side: "right" = wbiega z prawej i ucieka w lewo (domyślnie), "left" = odwrotnie.
func spawn(kind: String, side: String = "right") -> Critter:
	var c := Critter.new()
	c.kind = kind
	c.phase = randf() * TAU
	var lane_lo: float = level.lane_min() + 8.0
	var lane_hi: float = level.lane_max() - 8.0
	var dir: float = -1.0 if side == "right" else 1.0
	match kind:
		"villager":
			var f: String = VILLAGER_FILES[randi() % VILLAGER_FILES.size()]
			c.frames = [tex("res://assets/minigame/%s.png" % f)]
			c.scl = WPT * randf_range(0.85, 1.0)
			c.vx = dir * randf_range(210.0, 300.0)
			c.rate = 1.0
		"hare":
			c.frames = [tex(ANIMAL_DIR + "hare_1.png"), tex(ANIMAL_DIR + "hare_2.png")]
			c.vx = dir * randf_range(250.0, 360.0)
			c.rate = 7.0
		"deer":
			c.frames = [tex(ANIMAL_DIR + "deer_1.png"), tex(ANIMAL_DIR + "deer_2.png")]
			c.vx = dir * randf_range(300.0, 420.0)
			c.rate = 5.5
		"bat":
			c.frames = [tex(ANIMAL_DIR + "bat_1.png"), tex(ANIMAL_DIR + "bat_2.png")]
			c.vx = dir * randf_range(150.0, 250.0)
			c.rate = 9.0
			c.alt = randf_range(150.0, 300.0)
	c.frames = c.frames.filter(func(x): return x != null)
	if c.frames.is_empty():
		c.queue_free()
		return null
	var margin: float = 130.0
	c.position = Vector2(level.view_left + (level.view_w + margin if side == "right" else -margin), randf_range(lane_lo, lane_hi))
	add_child(c)
	critters.append(c)
	return c

func tick(delta: float) -> void:
	var st: int = level.stage_idx
	# sprzątanie postaci, które wyszły poza ekran
	var vl: float = level.view_left
	for c in critters.duplicate():
		if not is_instance_valid(c) or c.position.x < vl - 420.0 or c.position.x > vl + level.view_w + 420.0:
			critters.erase(c)
			if is_instance_valid(c):
				c.queue_free()
	if st != 1 and st != 2:
		return
	spawn_t -= delta
	if spawn_t > 0.0:
		return
	var side: String = "right" if randf() < 0.75 else "left"
	if st == 1:
		spawn_t = randf_range(1.2, 2.8)
		if count_kind(true) < MAX_VILLAGERS:
			spawn("villager", side)
	else:
		spawn_t = randf_range(0.9, 2.2)
		if count_kind(false) < MAX_ANIMALS:
			var r: float = randf()
			spawn("hare" if r < 0.38 else ("deer" if r < 0.62 else "bat"), side)
