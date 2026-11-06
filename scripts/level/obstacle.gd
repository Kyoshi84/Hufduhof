class_name Obstacle
extends Node2D
## Przeszkoda na całej szerokości pasa walki (wszystkie linie głębi), którą trzeba przeskoczyć (Spacja):
##   slow  - kałuża/bagno: brodzenie spowalnia (x0.42), skok przelatuje nad nią,
##   wall  - powalone drzewo, płonący budynek: nie da się przejść po ziemi (ogień dodatkowo parzy),
##   pit   - rzeka, przepaść: spadasz (obrażenia) i wracasz na brzeg, z którego startowałeś.
##   none  - nie blokuje (studnia, ugaszony wóz, rozbita barykada, gotowy most).
## Przeszkody-zadania (trzeba je rozwiązać, nie tylko przeskoczyć; interakcja = przycisk ataku obok przeszkody):
##   burning_cart - płonący wóz (160 wys., ponad skokiem ~131): 2 wiadra wody ze studni (well) gaszą go -> niski wrak, przejście,
##   barricade    - barykada (150): każdy MOCNY atak obniża ją o 40; <= 72 da się przeskoczyć, przy 0 znika,
##   river_bridge / chasm_bridge - szeroka rzeka/przepaść (330, za szeroka na skok): 5 cegieł buduje most,
##   well         - studnia: zawsze leży przy niej wiadro wody (gdy gracz go nie niesie).
## Nora szczurów (rat_hole) to osobny obiekt do zniszczenia: scripts/level/rat_hole.gd.
## Położenie x = środek przeszkody; wymiary w TYPES (w jednostkach świata). Wrogowie ignorują przeszkody.

const TYPES := {
	"puddle": { "kind": "slow", "w": 250.0, "h": 0.0 },
	"fire":   { "kind": "wall", "w": 96.0, "h": 92.0, "dmg": 10.0 },
	"log":    { "kind": "wall", "w": 70.0, "h": 72.0, "dmg": 0.0 },
	"river":  { "kind": "pit", "w": 150.0, "h": 0.0, "dmg": 18.0 },
	"chasm":  { "kind": "pit", "w": 150.0, "h": 0.0, "dmg": 22.0 },
	"burning_cart": { "kind": "wall", "w": 110.0, "h": 160.0, "dmg": 8.0, "jump_h": 0.0, "water": 2 },
	"barricade":    { "kind": "wall", "w": 80.0, "h": 150.0, "dmg": 0.0, "jump_h": 72.0, "chop": 40.0 },
	"river_bridge": { "kind": "pit", "w": 330.0, "h": 0.0, "dmg": 18.0, "bricks": 5 },
	"chasm_bridge": { "kind": "pit", "w": 330.0, "h": 0.0, "dmg": 22.0, "bricks": 5 },
	"well":         { "kind": "none", "w": 70.0, "h": 0.0 },
}
const USE_RANGE := 220.0            # z jakiej odległości od krawędzi przeszkody działa przycisk ataku (wiadro, cegły)
const BUCKET_RESPAWN := 0.6         # po ilu sekundach przy studni pojawia się nowe wiadro
const FEET_HALF := 14.0             # połowa szerokości stóp Ivo przy zderzeniu ze ścianą
const PIT_MARGIN := 8.0             # na krawędzi przepaści jest trochę "kopyta" (wybaczanie błędu)
const LAND_Z := 6.0                 # poniżej tej wysokości stopy dotykają dna/wody

var level
var type: String = "puddle"
var kind: String = "slow"
var half_w: float = 85.0
var h: float = 0.0
var dmg: float = 0.0
var t: float = 0.0
var ripple_t: float = 0.0
var hit_count: int = 0              # ile razy gracz się o nią potknął (testy/statystyki)
var jump_h: float = -1.0            # < 0: zwykła ściana (skok ponad h - 8); >= 0: da się przeskoczyć dopiero, gdy h <= jump_h
var state: String = ""              # "" = aktywna; "out" = ugaszona, "gone" = rozbita, "built" = most gotowy
var water_left: int = 0             # płonący wóz: ile wiader jeszcze potrzeba
var chop: float = 0.0               # barykada: o ile obniża ją jeden mocny atak
var bricks_needed: int = 0          # most: ile cegieł trzeba w sumie
var bricks_placed: int = 0
var bucket = null                   # studnia: wiadro leżące obok (Pickup) albo null
var bucket_t: float = 0.0
var flash_t: float = 0.0            # krótki błysk po uderzeniu/ugaszeniu (efekt)

const ART_DIR := "res://assets/stages/common/props"
const WPT := 4.0 / 3.0
static var _art: Dictionary = {}       # typ -> { tex, y, flames, frames, fps, glow } z obstacles.json (pusty = grafika z kodu)
static var _art_loaded: bool = false

## Grafika przeszkody z assets/stages/common/props/obstacles.json (tools/build_obstacles.py) albo {}.
static func art_for(p_type: String) -> Dictionary:
	if not _art_loaded:
		_art_loaded = true
		var path: String = ART_DIR + "/obstacles.json"
		if FileAccess.file_exists(path):
			var m = JSON.parse_string(FileAccess.get_file_as_string(path))
			if typeof(m) == TYPE_DICTIONARY:
				for k in m.get("obstacles", {}).keys():
					var spec: Dictionary = m["obstacles"][k]
					var tex := CharacterSheet.load_tex(ART_DIR + "/" + str(spec.get("file", "")))
					if tex == null:
						continue
					var a := { "tex": tex, "y": float(spec.get("y", 0.0)) }
					if spec.has("flames"):
						a["flames"] = CharacterSheet.load_tex(ART_DIR + "/" + str(spec["flames"]))
						a["frames"] = int(spec.get("frames", 1))
						a["fps"] = float(spec.get("fps", 10.0))
					if spec.has("glow"):
						a["glow"] = CharacterSheet.load_tex(ART_DIR + "/" + str(spec["glow"]))
					if spec.has("wreck"):
						a["wreck"] = CharacterSheet.load_tex(ART_DIR + "/" + str(spec["wreck"]))
					if spec.has("flames_y"):
						a["flames_y"] = float(spec["flames_y"])
					if spec.has("states"):
						var sts: Array = []
						for st in spec["states"]:
							sts.append({ "h": float(st["h"]), "tex": CharacterSheet.load_tex(ART_DIR + "/" + str(st["file"])) })
						a["states"] = sts
					_art[k] = a
	return _art.get(p_type, {})

## Rysuje teksturę przeszkody: x = środek przeszkody, y = wiersz pod horyzontem (px obrazu) górnej krawędzi.
func _draw_art_tex(tex: Texture2D, y_px: float, mod: Color = Color(1, 1, 1, 1)) -> Rect2:
	var w: float = tex.get_width() * WPT
	var h: float = tex.get_height() * WPT
	var r := Rect2(floorf(-w * 0.5), LevelBackground.HORIZON + y_px * WPT, w, h)
	draw_texture_rect(tex, r, false, mod)
	return r

static func is_known(name: String) -> bool:
	return TYPES.has(name)

func setup(lvl, p_type: String, x: float) -> void:
	level = lvl
	type = p_type
	var d: Dictionary = TYPES[p_type]
	kind = str(d["kind"])
	half_w = float(d["w"]) * 0.5
	h = float(d["h"])
	dmg = float(d.get("dmg", 0.0))
	jump_h = float(d.get("jump_h", -1.0))
	water_left = int(d.get("water", 0))
	chop = float(d.get("chop", 0.0))
	bricks_needed = int(d.get("bricks", 0))
	position = Vector2(x, 0.0)
	z_index = 0

func x0() -> float:
	return position.x - half_w

func x1() -> float:
	return position.x + half_w

## Czy gracz o danych współrzędnych przebywa nad przeszkodą (do podpowiedzi i testów).
func overlaps_x(px: float, pad: float = 0.0) -> bool:
	return px > x0() - pad and px < x1() + pad

# ------------------------------------------------------------------ zadania

## Przeszkoda wymaga rozwiązania (a nie tylko skoku) i jeszcze nie jest rozwiązana.
func is_puzzle() -> bool:
	return type in ["burning_cart", "barricade", "river_bridge", "chasm_bridge"] and kind != "none"

## Czy da się ją teraz przeskoczyć (barykada po obniżeniu; zwykłe przeszkody zawsze).
func jumpable() -> bool:
	if kind == "none":
		return false
	if kind == "pit":
		return bricks_needed == 0
	return jump_h < 0.0 or h <= jump_h

func blocks_passage() -> bool:
	return kind != "none"

## Gracz stoi dość blisko krawędzi przeszkody, żeby przycisk ataku zadziałał (z obu stron).
func in_use_range(px: float) -> bool:
	return (px > x0() - USE_RANGE and px <= x0() + 4.0) or (px < x1() + USE_RANGE and px >= x1() - 4.0)

## Wiadro wody na płonący wóz. Zwraca true, gdy woda trafiła w ogień.
func douse() -> bool:
	if type != "burning_cart" or state != "":
		return false
	water_left -= 1
	flash_t = 0.5
	if level.fx != null:
		for i in 3:
			level.fx.burst(Vector2(position.x, level.lane_min() + 60.0 + i * 70.0), 10, Color(0.55, 0.72, 0.9), 220.0, -1)
			level.fx.burst(Vector2(position.x, level.lane_min() + 20.0 + i * 70.0), 8, Color(0.82, 0.84, 0.86), 160.0, 1)     # para
	Sfx.play("slam", 1.6)
	if water_left <= 0:
		state = "out"
		kind = "none"
		h = 0.0
		GameState.add_score(100)
	return true

## Cegły z ekwipunku gracza na most. Zwraca liczbę położonych cegieł.
func add_bricks(n: int) -> int:
	if bricks_needed <= 0 or state == "built" or n <= 0:
		return 0
	var k: int = mini(n, bricks_needed - bricks_placed)
	bricks_placed += k
	flash_t = 0.4
	Sfx.play("pickup", 0.7)
	if bricks_placed >= bricks_needed:
		state = "built"
		kind = "none"
		GameState.add_score(100)
		if level.fx != null:
			level.fx.burst(Vector2(position.x, (level.lane_min() + level.lane_max()) * 0.5), 14, Color(0.7, 0.35, 0.2), 200.0, 1)
	return k

## Cios w przeszkodę (atak wręcz w fazie ACTIVE albo wybuch kuli ognia). Barykada: tylko mocny atak ją obniża.
func strike(attack_name: String, r: Rect2) -> bool:
	if type != "barricade" or kind == "none":
		return false
	if r.end.x < x0() - 6.0 or r.position.x > x1() + 6.0:
		return false
	if level.fx != null:
		level.fx.burst(Vector2(position.x, r.get_center().y - 60.0), 6 if attack_name != "heavy" else 14, Color(0.62, 0.46, 0.26), 200.0, 1)
	if attack_name != "heavy":
		Sfx.play("barrel_break", 0.8)         # lekkie cięcie tylko odbija się od pali
		return false
	h = maxf(0.0, h - chop)
	flash_t = 0.35
	Sfx.play("barrel_break", 0.6)
	if level != null:
		level.shake = maxf(level.shake, 6.0)
	if h <= 0.0:
		state = "gone"
		kind = "none"
		GameState.add_score(50)
	return true

## Pocisk zatrzymuje się na barykadzie (ognisty pocisk gaśnie, kula ognia wybucha).
func stops_projectile(r: Rect2) -> bool:
	return type == "barricade" and kind != "none" and r.end.x > x0() and r.position.x < x1()

## Studnia pilnuje, żeby przy niej leżało wiadro, gdy gracz żadnego nie niesie.
func _tick_well(p: Player, delta: float) -> void:
	if bucket != null and (not is_instance_valid(bucket) or bucket.taken):
		bucket = null
	if bucket != null and level.burning_cart_near(position.x, 1500.0) == null:
		bucket.taken = true                          # ogień ugaszony: wiadro przy studni znika
		bucket = null
	if bucket != null or p.carry == "bucket" or level.burning_cart_near(position.x, 1500.0) == null:
		bucket_t = BUCKET_RESPAWN
		return
	bucket_t -= delta
	if bucket_t <= 0.0:
		bucket = level.drop_pickup(Vector2(position.x + 50.0, well_bucket_y()), "bucket")

func well_bucket_y() -> float:
	return level.lane_min() + 22.0

## Rozwiązuje kontakt gracza z przeszkodą. prev_x = pozycja z początku klatki (skąd gracz przyszedł).
func resolve(p: Player, prev_x: float, delta: float) -> void:
	if p == null or not p.is_alive():
		return
	flash_t = maxf(0.0, flash_t - delta)
	if type == "well":
		_tick_well(p, delta)
	match kind:
		"slow":
			if p.z < LAND_Z and overlaps_x(p.position.x):
				p.speed_mult = minf(p.speed_mult, 0.42)
				ripple_t -= delta
				if ripple_t <= 0.0 and level.fx != null and p.state == Actor.State.MOVE:
					ripple_t = 0.16
					level.fx.burst(p.position + Vector2(0, -4), 3, Color(0.45, 0.55, 0.65), 90.0, p.facing)
		"wall":
			var reach: float = half_w + FEET_HALF
			var too_high: bool = jump_h >= 0.0 and h > jump_h        # np. płonący wóz, wysoka barykada: skok nie pomoże
			if (p.z < h - 8.0 or too_high) and absf(p.position.x - position.x) < reach:
				var from_left: bool = prev_x <= position.x
				p.position.x = position.x - reach if from_left else position.x + reach
				p.kb_vx = 0.0
				hit_count += 1
				if dmg > 0.0:
					p.take_hazard(dmg)
		"pit":
			if p.z < LAND_Z and p.position.x > x0() + PIT_MARGIN and p.position.x < x1() - PIT_MARGIN:
				var from_left2: bool = prev_x <= position.x
				hit_count += 1
				p.take_hazard(dmg)
				p.position.x = x0() - 90.0 if from_left2 else x1() + 90.0
				p.z = 0.0
				p.vz = 0.0
				p.kb_vx = 0.0
				if p.is_alive():
					p.set_state(Actor.State.IDLE)
				if level.fx != null:
					level.fx.burst(Vector2(position.x, p.position.y - 10.0), 14, Color(0.5, 0.65, 0.8) if type == "river" else Color(0.35, 0.2, 0.45), 200.0, 1)
				Sfx.play("slam", 0.8)

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

# ------------------------------------------------------------------ rysowanie

func _lane_top() -> float:
	return level.lane_min() - 34.0 if level != null else 350.0

func _lane_bot() -> float:
	return level.lane_max() + 58.0 if level != null else 660.0

func _draw() -> void:
	if level == null:
		return
	var vl: float = level.view_left
	if position.x + half_w + 260.0 < vl or position.x - half_w - 260.0 > vl + level.view_w:
		return
	match type:
		"puddle": _draw_puddle()
		"fire": _draw_fire()
		"log": _draw_log()
		"river": _draw_water(Color(0.15, 0.28, 0.40), Color(0.36, 0.55, 0.68), true)
		"chasm": _draw_chasm()
		"burning_cart": _draw_cart()
		"barricade": _draw_barricade()
		"well": _draw_well()
		"river_bridge":
			_draw_water(Color(0.15, 0.28, 0.40), Color(0.36, 0.55, 0.68), true)
			_draw_bridge()
		"chasm_bridge":
			_draw_chasm_wide()
			_draw_bridge()

# ------------------------------------------------------------------ rysowanie przeszkód-zadań

func _flash_mod() -> Color:
	return Color(1.6, 1.6, 1.6) if flash_t > 0.0 and int(flash_t * 20.0) % 2 == 0 else Color.WHITE

func _draw_cart() -> void:
	var art: Dictionary = art_for("burning_cart")
	if art.is_empty():
		_poly([Vector2(-half_w, _lane_top()), Vector2(half_w, _lane_top()), Vector2(half_w, _lane_bot()), Vector2(-half_w, _lane_bot())], Color(0.3, 0.18, 0.1))
		return
	if state == "out":
		var wr: Texture2D = art.get("wreck")
		if wr != null:
			_draw_art_tex(wr, art["y"])
		for i in 6:                                                     # dym znad wraku
			var u: float = fmod(t * 0.35 + i * 0.17, 1.0)
			var c := Color(0.42, 0.42, 0.44, 0.45 * (1.0 - u))
			draw_circle(Vector2(floorf((sin(i * 2.7) * 20.0 + u * 30.0) / WPT) * WPT, floorf((lerpf(_lane_top() + 40.0, _lane_bot() - 40.0, fmod(i * 0.41, 1.0)) - 30.0 - u * 140.0) / WPT) * WPT), 6.0 + u * 10.0, c)
		return
	_draw_art_tex(art["tex"], art["y"], _flash_mod())
	var fl: Texture2D = art.get("flames")
	if fl != null:
		var total: float = float(TYPES["burning_cart"]["water"])
		var k: float = clampf(float(water_left) / total, 0.25, 1.0)
		var n: int = maxi(1, int(art["frames"]))
		var fw: float = fl.get_width() / float(n)
		var f: int = int(t * float(art["fps"])) % n
		var full_h: float = fl.get_height() * WPT
		var top: float = LevelBackground.HORIZON + float(art.get("flames_y", art["y"])) * WPT
		var dst := Rect2(floorf(-fw * WPT * 0.5), top + full_h * (1.0 - k), fw * WPT, full_h * k)
		draw_texture_rect_region(fl, dst, Rect2(f * fw, 0, fw, fl.get_height()))

func _draw_barricade() -> void:
	var art: Dictionary = art_for("barricade")
	if kind == "none":
		return
	if art.is_empty() or not art.has("states"):
		var top: float = _lane_top()
		_poly([Vector2(-half_w, top), Vector2(half_w, top), Vector2(half_w, _lane_bot()), Vector2(-half_w, _lane_bot())], Color(0.36, 0.24, 0.13))
		return
	var best: Dictionary = {}
	for st in art["states"]:
		if best.is_empty() or absf(float(st["h"]) - h) < absf(float(best["h"]) - h):
			best = st
	if best.get("tex") != null:
		_draw_art_tex(best["tex"], art["y"], _flash_mod())

func _draw_well() -> void:
	var art: Dictionary = art_for("well")
	var base_y: float = level.lane_min() - 6.0
	if art.is_empty():
		_ellipse(Vector2(0, base_y), 30.0, 12.0, Color(0.4, 0.38, 0.36))
		return
	var tex: Texture2D = art["tex"]
	var w: float = tex.get_width() * WPT
	var hh: float = tex.get_height() * WPT
	draw_texture_rect(tex, Rect2(floorf(-w * 0.5), floorf(base_y - hh), w, hh), false)

func _draw_chasm_wide() -> void:
	var art: Dictionary = art_for("chasm_bridge")
	if art.is_empty():
		_draw_chasm()
		return
	_draw_art_tex(art["tex"], art["y"])
	var gl: Texture2D = art.get("glow")
	if gl != null:
		_draw_art_tex(gl, art["y"], Color(1, 1, 1, 0.35 + 0.3 * sin(t * 1.8)))

## Most z cegieł: odsłaniany od lewego brzegu, każda cegła = 1/5 długości; nad brzegiem licznik cegieł.
func _draw_bridge() -> void:
	var frac: float = clampf(float(bricks_placed) / float(maxi(1, bricks_needed)), 0.0, 1.0)
	var art: Dictionary = art_for("bridge")
	var y0: float = _lane_top()
	var y1: float = _lane_bot()
	var w: float = half_w * 2.0 + 16.0
	if frac > 0.0:
		if not art.is_empty():
			var tex: Texture2D = art["tex"]
			var tw: float = tex.get_width()
			var src := Rect2(0, 0, tw * frac, tex.get_height())
			var dst := Rect2(-w * 0.5, LevelBackground.HORIZON + float(art["y"]) * WPT, w * frac, tex.get_height() * WPT)
			draw_texture_rect_region(tex, dst, src, _flash_mod())
		else:
			_poly([Vector2(-w * 0.5, y0), Vector2(-w * 0.5 + w * frac, y0), Vector2(-w * 0.5 + w * frac, y1), Vector2(-w * 0.5, y1)], Color(0.55, 0.25, 0.15))
	if state != "built":
		# plan mostu: przerywane krawędzie, żeby było widać, że coś tu trzeba zbudować
		for i in 12:
			var xx: float = -w * 0.5 + w * (float(i) + 0.5) / 12.0
			if xx > -w * 0.5 + w * frac:
				draw_rect(Rect2(floorf(xx / WPT) * WPT, y0 + 2.0, 12.0, 4.0), Color(0.85, 0.6, 0.3, 0.75))
				draw_rect(Rect2(floorf(xx / WPT) * WPT, y1 - 6.0, 12.0, 4.0), Color(0.85, 0.6, 0.3, 0.75))
		var font := ThemeDB.fallback_font
		var label := "MOST: %d / %d CEGIEŁ" % [bricks_placed, bricks_needed]
		draw_string_outline(font, Vector2(-half_w - 150.0, y0 - 14.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(0, 0, 0))
		draw_string(font, Vector2(-half_w - 150.0, y0 - 14.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.95, 0.75, 0.4))

func _poly(pts: Array, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pts), col)

func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		pts.append(c + Vector2(cos(TAU * i / 24.0) * rx, sin(TAU * i / 24.0) * ry))
	draw_colored_polygon(pts, col)

func _draw_puddle() -> void:
	var y0: float = _lane_top() + 20.0
	var y1: float = _lane_bot() - 30.0
	var cy: float = (y0 + y1) * 0.5
	var ry: float = (y1 - y0) * 0.42
	# grafika z pliku (assets/stages/common/props/obstacle_puddle.png, tools/build_road.py) + pikselowe kręgi na wodzie
	var tex: Texture2D = StageArt.common_prop("obstacle_puddle")
	if tex != null:
		var k: float = 4.0 / 3.0
		var tw: float = tex.get_width() * k
		var th: float = tex.get_height() * k
		draw_texture_rect(tex, Rect2(floorf(-tw * 0.5), floorf(cy - th * 0.5), tw, th), false)
		for i in 4:
			var ph: float = fmod(t * 0.6 + i * 0.29, 1.0)
			var c := Vector2(sin(i * 2.3) * half_w * 0.45, cy + 12.0 + cos(i * 1.7) * ry * 0.4)
			var rx: float = 6.0 + ph * 34.0
			var pts := PackedVector2Array()
			for a in 17:
				pts.append(c + Vector2(cos(TAU * a / 16.0) * rx, sin(TAU * a / 16.0) * rx * 0.35))
			draw_polyline(pts, Color(0.59, 0.64, 0.67, 0.75 * (1.0 - ph)), k)
		return
	_ellipse(Vector2(0, cy + 6), half_w + 10.0, ry + 4.0, Color(0.12, 0.09, 0.07))             # mokry brzeg
	_ellipse(Vector2(0, cy), half_w, ry, Color(0.20, 0.25, 0.32))
	_ellipse(Vector2(-6, cy - 4), half_w * 0.82, ry * 0.8, Color(0.30, 0.39, 0.48))
	_ellipse(Vector2(-14, cy - 10), half_w * 0.45, ry * 0.4, Color(0.52, 0.62, 0.70, 0.7))    # odbicie nieba
	for i in 5:
		var ph: float = fmod(t * 0.7 + i * 0.37, 1.0)
		var rr: float = 10.0 + ph * 50.0
		draw_arc(Vector2(sin(i * 2.3) * half_w * 0.5, cy + cos(i * 1.7) * ry * 0.5), rr, 0, TAU, 20, Color(0.75, 0.85, 0.92, 0.6 * (1.0 - ph)), 2.0)
	for k in 7:                                                                                 # kamyki i trawa na brzegu
		var a: float = float(k) / 7.0 * TAU + 0.4
		_ellipse(Vector2(cos(a) * (half_w + 8.0), cy + sin(a) * (ry + 6.0)), 6.0, 4.0, Color(0.30, 0.28, 0.27))

func _draw_water(deep: Color, light: Color, bank: bool) -> void:
	var y0: float = _lane_top()
	var y1: float = _lane_bot()
	var w: float = half_w
	_poly([Vector2(-w - 16, y0), Vector2(w + 16, y0), Vector2(w + 24, y1), Vector2(-w - 24, y1)], Color(0.16, 0.12, 0.09))      # błotnisty brzeg
	_poly([Vector2(-w + 4, y0), Vector2(w - 4, y0), Vector2(w + 4, y1), Vector2(-w - 4, y1)], deep)
	for i in 14:                                                                                 # fale płynące w dół ekranu
		var u: float = fmod(t * 0.45 + i * 0.173, 1.0)
		var yy: float = lerpf(y0 + 10.0, y1 - 10.0, u)
		var xx: float = -w + 14.0 + fmod(i * 37.0, w * 2.0 - 28.0)
		draw_line(Vector2(xx, yy), Vector2(xx + 26.0 + (i % 3) * 8.0, yy + 2.0), Color(light.r, light.g, light.b, 0.75), 2.0)
	for i in 4:
		draw_line(Vector2(-w + 6.0, y0 + 8.0), Vector2(-w + 3.0 - i, y1), Color(0.72, 0.82, 0.88, 0.5), 2.0)
	if bank:
		for k in 9:                                                                              # kamienie na brzegach
			var yb: float = lerpf(y0 + 10.0, y1 - 8.0, float(k) / 8.0)
			_ellipse(Vector2(-w - 14.0 + (k % 2) * 3.0, yb), 8.0, 5.0, Color(0.26, 0.25, 0.27))
			_ellipse(Vector2(w + 14.0 - (k % 3) * 2.0, yb + 5.0), 7.0, 5.0, Color(0.30, 0.28, 0.28))

func _draw_chasm() -> void:
	var y0: float = _lane_top()
	var y1: float = _lane_bot()
	var w: float = half_w
	var art: Dictionary = art_for("chasm")
	if not art.is_empty():
		_draw_art_tex(art["tex"], art["y"])
		var gl: Texture2D = art.get("glow")
		if gl != null:
			_draw_art_tex(gl, art["y"], Color(1, 1, 1, 0.35 + 0.3 * sin(t * 1.8)))
		for i in 6:                                                                              # kamyki spadające w głąb
			var u: float = fmod(t * 0.55 + i * 0.167, 1.0)
			var px: float = floorf((sin(i * 3.7) * w * 0.35 + u * 6.0) / WPT) * WPT
			var py: float = floorf((lerpf(y0 + 30.0, y1 - 20.0, fmod(i * 0.37, 1.0)) + u * 40.0) / WPT) * WPT
			draw_rect(Rect2(px, py, WPT, WPT), Color(0.42, 0.40, 0.38, 1.0 - u))
		return
	_poly([Vector2(-w - 18, y0), Vector2(w + 18, y0), Vector2(w + 26, y1), Vector2(-w - 26, y1)], Color(0.10, 0.07, 0.09))
	var rim := PackedVector2Array()
	var rim2 := PackedVector2Array()
	for i in 13:
		var yy: float = lerpf(y0, y1, float(i) / 12.0)
		rim.append(Vector2(-w + 6.0 + sin(i * 2.1) * 7.0, yy))
		rim2.append(Vector2(w - 6.0 + cos(i * 1.7) * 7.0, yy))
	var pts := PackedVector2Array()
	for p in rim:
		pts.append(p)
	for i in range(rim2.size() - 1, -1, -1):
		pts.append(rim2[i])
	draw_colored_polygon(pts, Color(0.02, 0.01, 0.03))
	for i in 5:                                                                                  # poświata spaczenia z dna
		var gl: float = 0.18 + 0.12 * sin(t * 2.0 + i)
		_ellipse(Vector2((i - 2) * w * 0.4, lerpf(y0 + 40.0, y1 - 40.0, float(i) / 4.0)), 34.0, 14.0, Color(0.5, 0.18, 0.7, gl))
	for k in 10:
		var yb: float = lerpf(y0 + 6.0, y1 - 6.0, float(k) / 9.0)
		_poly([Vector2(-w - 6, yb), Vector2(-w + 8, yb - 8), Vector2(-w + 14, yb + 6)], Color(0.20, 0.17, 0.20))
		_poly([Vector2(w + 6, yb), Vector2(w - 8, yb - 8), Vector2(w - 14, yb + 6)], Color(0.22, 0.18, 0.21))

func _draw_log() -> void:
	var y0: float = _lane_top() + 6.0
	var y1: float = _lane_bot() - 16.0
	var w: float = half_w
	var art: Dictionary = art_for("log")
	if not art.is_empty():
		_draw_art_tex(art["tex"], art["y"])
		return
	_ellipse(Vector2(0, y1 + 6), w + 8.0, 12.0, Color(0, 0, 0, 0.35))
	# pień leżący w poprzek ścieżki (wzdłuż głębi): kora w pionowe pasy
	var base_cols := [Color(0.20, 0.13, 0.08), Color(0.28, 0.18, 0.10), Color(0.36, 0.24, 0.13), Color(0.25, 0.16, 0.09)]
	for s in 4:
		var x_a: float = -w + s * (w * 2.0 / 4.0)
		var x_b: float = x_a + w * 2.0 / 4.0
		_poly([Vector2(x_a * 0.92, y0), Vector2(x_b * 0.92, y0), Vector2(x_b, y1), Vector2(x_a, y1)], base_cols[s])
	for i in 18:
		var yy: float = lerpf(y0 + 8.0, y1 - 6.0, float(i) / 17.0)
		var xx: float = -w + 8.0 + fmod(i * 23.0, w * 2.0 - 16.0)
		draw_line(Vector2(xx, yy), Vector2(xx + 2, yy + 14), Color(0.12, 0.08, 0.05), 2.0)
	for i in 6:                                                                                  # kępy mchu
		_ellipse(Vector2(-w + 10.0 + fmod(i * 29.0, w * 2.0 - 20.0), lerpf(y0 + 20.0, y1 - 20.0, float(i) / 5.0)), 9.0, 5.0, Color(0.22, 0.33, 0.16))
	_ellipse(Vector2(0, y1), w * 0.96, 15.0, Color(0.60, 0.46, 0.28))                          # przekrój pnia
	_ellipse(Vector2(0, y1), w * 0.72, 11.0, Color(0.50, 0.37, 0.22))
	_ellipse(Vector2(0, y1), w * 0.44, 6.5, Color(0.58, 0.44, 0.27))
	_ellipse(Vector2(0, y1), w * 0.16, 2.5, Color(0.40, 0.29, 0.17))
	for sgn in [-1, 1]:                                                                          # konary i korzenie
		_poly([Vector2(sgn * w * 0.9, y0 + 6), Vector2(sgn * (w + 34), y0 - 14), Vector2(sgn * (w + 30), y0 - 2), Vector2(sgn * w * 0.6, y0 + 22)], Color(0.24, 0.16, 0.09))
		_poly([Vector2(sgn * (w + 34), y0 - 14), Vector2(sgn * (w + 54), y0 - 30), Vector2(sgn * (w + 46), y0 - 8)], Color(0.18, 0.12, 0.07))

func _draw_fire() -> void:
	var y0: float = _lane_top() + 14.0
	var y1: float = _lane_bot() - 20.0
	var w: float = half_w
	# dom w głębi (spalona chata ze sztandarowych rekwizytów etapu) + żar na drodze
	var sa: StageArt = StageArt.get_stage("stage2_village")
	if sa != null:
		var vars: Array = sa.prop_variants("house_burnt")
		if not vars.is_empty():
			var tex: Texture2D = vars[0]
			var k: float = 4.0 / 3.0 * 1.5
			draw_texture_rect(tex, Rect2(-tex.get_width() * k * 0.5, y0 - tex.get_height() * k + 54.0, tex.get_width() * k, tex.get_height() * k), false)
	var art: Dictionary = art_for("fire")
	if not art.is_empty():
		_draw_art_tex(art["tex"], art["y"])
		var fl: Texture2D = art.get("flames")
		if fl != null:
			var n: int = maxi(1, int(art["frames"]))
			var fw: float = fl.get_width() / float(n)
			var f: int = int(t * float(art["fps"])) % n
			var dst := Rect2(floorf(-fw * WPT * 0.5), LevelBackground.HORIZON + float(art["y"]) * WPT, fw * WPT, fl.get_height() * WPT)
			draw_texture_rect_region(fl, dst, Rect2(f * fw, 0, fw, fl.get_height()))
		for i in 10:                                                                             # iskry (piksele)
			var u: float = fmod(t * 0.8 + i * 0.113, 1.0)
			var sx: float = floorf((sin(i * 5.3) * w * 0.6 + sin(t * 3.0 + i) * 8.0) / WPT) * WPT
			draw_rect(Rect2(sx, floorf(((y0 + y1) * 0.5 - 40.0 - u * 190.0) / WPT) * WPT, WPT, WPT), Color(1.0, 0.72 - u * 0.3, 0.25, 1.0 - u))
		return
	_ellipse(Vector2(0, (y0 + y1) * 0.5), w + 12.0, (y1 - y0) * 0.5, Color(0.10, 0.04, 0.03))
	_ellipse(Vector2(0, (y0 + y1) * 0.5), w * 0.8, (y1 - y0) * 0.42, Color(0.55, 0.16, 0.05, 0.55 + 0.15 * sin(t * 9.0)))
	var n: int = 6
	for i in n:                                                                                  # słupy ognia wzdłuż całej głębi
		var yy: float = lerpf(y0 + 10.0, y1 - 6.0, float(i) / float(n - 1))
		var xx: float = sin(i * 1.9) * w * 0.35
		_poly([Vector2(xx - 8, yy), Vector2(xx - 6, yy - 52), Vector2(xx + 6, yy - 56), Vector2(xx + 8, yy)], Color(0.10, 0.07, 0.06))      # zwęglona belka
		for f in 3:
			var ph: float = t * (7.0 + f) + i * 1.3
			var fh: float = h * (0.75 - f * 0.18) * (0.9 + 0.2 * sin(ph))
			var fw: float = (24.0 - f * 6.0) * (0.9 + 0.15 * sin(ph * 1.3))
			var col: Color = [Color(0.78, 0.20, 0.06, 0.92), Color(0.98, 0.58, 0.12, 0.95), Color(1.0, 0.92, 0.55, 0.95)][f]
			_poly([Vector2(xx - fw, yy), Vector2(xx - fw * 0.5, yy - fh * 0.55), Vector2(xx + sin(ph) * 5.0, yy - fh), Vector2(xx + fw * 0.5, yy - fh * 0.5), Vector2(xx + fw, yy)], col)
	for i in 8:                                                                                  # iskry
		var u: float = fmod(t * 0.9 + i * 0.131, 1.0)
		draw_rect(Rect2(sin(i * 5.3) * w * 0.5 + sin(t * 3.0 + i) * 6.0, (y0 + y1) * 0.5 - u * 150.0, 3, 3), Color(1.0, 0.75, 0.3, 1.0 - u))
