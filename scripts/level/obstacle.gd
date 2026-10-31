class_name Obstacle
extends Node2D
## Przeszkoda na całej szerokości pasa walki (wszystkie linie głębi), którą trzeba przeskoczyć (Spacja):
##   slow  - kałuża/bagno: brodzenie spowalnia (x0.42), skok przelatuje nad nią,
##   wall  - powalone drzewo, płonący budynek: nie da się przejść po ziemi (ogień dodatkowo parzy),
##   pit   - rzeka, przepaść: spadasz (obrażenia) i wracasz na brzeg, z którego startowałeś.
## Położenie x = środek przeszkody; wymiary w TYPES (w jednostkach świata). Wrogowie ignorują przeszkody.

const TYPES := {
	"puddle": { "kind": "slow", "w": 250.0, "h": 0.0 },
	"fire":   { "kind": "wall", "w": 96.0, "h": 92.0, "dmg": 10.0 },
	"log":    { "kind": "wall", "w": 70.0, "h": 72.0, "dmg": 0.0 },
	"river":  { "kind": "pit", "w": 150.0, "h": 0.0, "dmg": 18.0 },
	"chasm":  { "kind": "pit", "w": 150.0, "h": 0.0, "dmg": 22.0 },
}
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
	position = Vector2(x, 0.0)
	z_index = 0

func x0() -> float:
	return position.x - half_w

func x1() -> float:
	return position.x + half_w

## Czy gracz o danych współrzędnych przebywa nad przeszkodą (do podpowiedzi i testów).
func overlaps_x(px: float, pad: float = 0.0) -> bool:
	return px > x0() - pad and px < x1() + pad

## Rozwiązuje kontakt gracza z przeszkodą. prev_x = pozycja z początku klatki (skąd gracz przyszedł).
func resolve(p: Player, prev_x: float, delta: float) -> void:
	if p == null or not p.is_alive():
		return
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
			if p.z < h - 8.0 and absf(p.position.x - position.x) < reach:
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
