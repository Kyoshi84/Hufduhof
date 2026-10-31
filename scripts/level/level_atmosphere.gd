class_name LevelAtmosphere
extends Node2D
## Nastrój etapów 3 i 4 rysowany NA WIERZCHU świata (pod HUD-em): w lesie (etap 3) korony drzew gęstnieją od góry ekranu,
## aż zakryją całe niebo, a robi się coraz ciemniej; w legowisku (etap 4) zostaje mrok z fioletową poświatą.
## Parametry: forest_k() = 0..1 postęp w lesie, darkness() = przezroczystość czerni.

const DARK_LAIR := 0.30
const DARK_FOREST_MAX := 0.44
const FADE_OUT := 700.0             # tyle jednostek świata na wygaszenie koron po wejściu w legowisko

var level
var t: float = 0.0

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _stage_start(i: int) -> float:
	var stages: Array = level.data["stages"]
	return float(stages[i]["start"]) if i < stages.size() else 1.0e9

## Postęp przez etap 3 (las): 0 na wejściu, 1 na jego końcu; po wejściu w legowisko wygasa do 0.
func forest_k_at(cx: float) -> float:
	var s2: float = _stage_start(2)
	var s3: float = _stage_start(3)
	if cx < s2:
		return clampf((cx - (s2 - 500.0)) / 500.0, 0.0, 1.0) * 0.06
	if cx < s3:
		return clampf((cx - s2) / maxf(s3 - s2, 1.0), 0.0, 1.0)
	return clampf(1.0 - (cx - s3) / FADE_OUT, 0.0, 1.0)

func darkness_at(cx: float) -> float:
	var s2: float = _stage_start(2)
	var s3: float = _stage_start(3)
	if cx < s2:
		return 0.0
	if cx < s3:
		var k: float = clampf((cx - s2) / maxf(s3 - s2, 1.0), 0.0, 1.0)
		return DARK_FOREST_MAX * pow(k, 1.15)
	var f: float = clampf((cx - s3) / FADE_OUT, 0.0, 1.0)
	return lerpf(DARK_FOREST_MAX, DARK_LAIR, f)

func _h(i: int, salt: int) -> float:
	var v: int = absi((i * 73856093) ^ (salt * 19349663)) % 1000
	return float(v) / 1000.0

func _blob(c: Vector2, r: float, col: Color, seed: int) -> void:
	var pts := PackedVector2Array()
	var n := 14
	for i in n:
		var a: float = TAU * i / float(n)
		var rr: float = r * (0.78 + 0.34 * _h(seed * 31 + i, 5))
		pts.append(c + Vector2(cos(a) * rr, sin(a) * rr * 0.78))
	draw_colored_polygon(pts, col)

func _draw() -> void:
	if level == null:
		return
	var vl: float = level.view_left
	var vw: float = level.view_w
	var cx: float = vl + vw * 0.5
	var k: float = forest_k_at(cx)
	var dark: float = darkness_at(cx)
	if k > 0.02:
		_draw_canopy(vl, vw, k)
		_draw_motes(vl, vw, k)
	if dark > 0.005:
		var tint: float = clampf((cx - _stage_start(3)) / FADE_OUT, 0.0, 1.0)
		var col := Color(0.01 + 0.05 * tint, 0.02, 0.04 + 0.05 * tint, dark)
		draw_rect(Rect2(vl - 4.0, -4.0, vw + 8.0, 728.0), col)
		for s in 6:                                                                              # winieta: ciemniejsze brzegi
			var a: float = dark * 0.5 * (1.0 - float(s) / 6.0)
			draw_rect(Rect2(vl - 4.0, -4.0, 40.0 + s * 34.0, 728.0), Color(0, 0, 0, a * 0.5))
			draw_rect(Rect2(vl + vw + 4.0 - (40.0 + s * 34.0), -4.0, 40.0 + s * 34.0, 728.0), Color(0, 0, 0, a * 0.5))

func _draw_canopy(vl: float, vw: float, k: float) -> void:
	var cover: float = smoothstep(0.08, 0.95, k)              # 0..1: jak głęboko korony zwisają od góry
	var layers := [
		{ "par": 0.55, "step": 74.0, "r": 62.0, "col": Color(0.10, 0.19, 0.11), "reach": 0.74 },
		{ "par": 0.85, "step": 62.0, "r": 70.0, "col": Color(0.07, 0.14, 0.08), "reach": 0.88 },
		{ "par": 1.20, "step": 52.0, "r": 78.0, "col": Color(0.03, 0.06, 0.04), "reach": 1.00 },
	]
	var depth: float = 290.0 * cover
	for li in layers.size():
		var L: Dictionary = layers[li]
		var par: float = float(L["par"])
		var step: float = float(L["step"])
		var lo: int = int(floor((vl * par - 120.0) / step))
		var hi: int = int(ceil((vl * par + vw + 120.0) / step))
		for i in range(lo, hi + 1):
			var jitter: float = _h(i, 11 + li)
			var thin: float = _h(i, 17 + li)
			if thin > 0.35 + cover * 0.75:
				continue                                           # na początku lasu korony są rzadkie
			var x: float = vl + (float(i) * step - vl * par) + (jitter - 0.5) * step * 0.6
			var reach: float = depth * float(L["reach"]) * (0.75 + 0.35 * jitter)
			var r: float = float(L["r"]) * (0.7 + 0.5 * _h(i, 23 + li))
			var y: float = reach - r * 0.5 - 30.0
			if reach < 24.0:
				continue
			var col: Color = L["col"]
			# gąszcz od sufitu do dolnej krawędzi: słup z kępek liści
			var yy: float = -r * 0.2
			var seed_i: int = i * 7 + li
			while yy < y:
				_blob(Vector2(x + sin(yy * 0.05 + i) * 6.0, yy), r * 0.95, col, seed_i + int(yy))
				yy += r * 0.7
			_blob(Vector2(x, y), r, col, seed_i)
			_blob(Vector2(x - r * 0.55, y - r * 0.2), r * 0.7, col.lightened(0.04), seed_i + 3)
			if li == 2 and _h(i, 41) < 0.45:                                                     # zwisające pnącza
				var vl_len: float = 30.0 + 60.0 * _h(i, 43)
				draw_line(Vector2(x + 10, y + r * 0.5), Vector2(x + 12 + sin(t + i) * 3.0, y + r * 0.5 + vl_len), Color(0.10, 0.20, 0.10), 3.0)

func _draw_motes(vl: float, vw: float, k: float) -> void:
	var n: int = int(14.0 * k) + 3
	for i in n:
		var u: float = fmod(t * (0.04 + 0.03 * _h(i, 3)) + _h(i, 5), 1.0)
		var x: float = vl + fmod(_h(i, 7) * vw * 1.4 + t * 8.0 * (_h(i, 9) - 0.5) * 3.0 + vw * 2.0, vw)
		var y: float = 140.0 + u * 480.0 + sin(t * 1.6 + i) * 14.0
		var a: float = 0.55 * sin(u * PI) * (0.6 + 0.4 * sin(t * 3.0 + i * 2.0))
		draw_circle(Vector2(x, y), 2.0, Color(0.85, 1.0, 0.55, a))
