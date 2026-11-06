class_name Iso
extends RefCounted
## Rzut izometryczny: komórka = romb 128x64 px (TileSet: ISOMETRIC, DIAMOND_DOWN).
## "Odległość podłoża": oś pionowa ekranu jest ściśnięta 2x, więc liczymy |(dx, 2*dy)|.
## Wszystkie zasięgi (ataki, wykrywanie) są w tej mierze - koło na podłodze = elipsa 2:1 na ekranie.

const TW := 128
const TH := 64
const Y_SCALE := 0.5
const DIRS := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]

static func cell_center(c: Vector2i) -> Vector2:
	return Vector2((c.x - c.y) * TW / 2.0 + TW / 2.0, (c.x + c.y) * TH / 2.0 + TH / 2.0)

static func cellf_center(x: float, y: float) -> Vector2:
	return Vector2((x - y) * TW / 2.0 + TW / 2.0, (x + y) * TH / 2.0 + TH / 2.0)

## Narożnik siatki (gx, gy liczby całkowite = narożniki komórek): narożnik północny komórki (x, y) to corner(x, y).
static func corner(gx: float, gy: float) -> Vector2:
	return Vector2((gx - gy) * TW / 2.0 + TW / 2.0, (gx + gy) * TH / 2.0)

static func to_cell(p: Vector2) -> Vector2i:
	var px := p.x - TW / 2.0
	var gx := (px / (TW / 2.0) + p.y / (TH / 2.0)) / 2.0
	var gy := (p.y / (TH / 2.0) - px / (TW / 2.0)) / 2.0
	return Vector2i(int(floor(gx)), int(floor(gy)))

static func ground(v: Vector2) -> Vector2:
	return Vector2(v.x, v.y / Y_SCALE)

static func screen(g: Vector2) -> Vector2:
	return Vector2(g.x, g.y * Y_SCALE)

static func dist(a: Vector2, b: Vector2) -> float:
	return ground(b - a).length()

## Kierunek ekranu -> nazwa jednego z 8 kierunków sprite'ów (liczone w mierze podłoża).
static func dir_name(v: Vector2) -> String:
	if v.length_squared() < 0.0001:
		return "south"
	var g := ground(v)
	var a := fposmod(g.angle(), TAU)
	var idx := int(round(a / (TAU / 8.0))) % 8
	return DIRS[idx]

static func dir_vector(name: String) -> Vector2:
	var idx := DIRS.find(name)
	if idx < 0:
		idx = 2
	return screen(Vector2.RIGHT.rotated(idx * TAU / 8.0)).normalized()

## Czy punkt p (ekran) leży w łuku podłoża: od origin, w kierunku dir, zasięg r, kąt łuku arc_deg.
static func in_arc(origin: Vector2, dir: Vector2, p: Vector2, r: float, arc_deg: float, extra: float = 0.0) -> bool:
	var g := ground(p - origin)
	if g.length() > r + extra:
		return false
	if g.length() < extra + 4.0:
		return true
	var gd := ground(dir).normalized()
	return absf(rad_to_deg(gd.angle_to(g))) <= arc_deg * 0.5
