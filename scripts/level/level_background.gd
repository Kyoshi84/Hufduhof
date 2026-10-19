class_name LevelBackground
extends Node2D
## Proceduralne tło w stylu 256 kolorów: niebo i ziemia jako tekstury z ditheringiem Bayera,
## dwie warstwy paralaksy, rekwizyty zakotwiczone w świecie (wszystkie WYŁĄCZNIE dekoracyjne - nic nie
## blokuje ruchu i nic nie rysuje się przed postaciami) oraz animowane akcenty (ogień, dym, runy).
## Docelowo zastępowane teksturami: assets/backgrounds/<etap>/ (patrz README).

const HORIZON := 345.0
const TEX_W := 4                       # okres wzoru dithering'u (px)
const WPT := 4.0 / 3.0                 # jednostek świata na piksel obrazu wewnętrznego
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

var level
var t: float = 0.0
var sky_tex: Array = []
var ground_tex: Array = []
var sky_par: Array = []
var ground_par: Array = []
var art: Array = []                    # StageArt albo null na etap
var fore: LevelForeground
var sky_a: Sprite2D
var sky_b: Sprite2D
var gnd_a: Sprite2D
var gnd_b: Sprite2D

# ------------------------------------------------------------------ motywy etapów

func _themes() -> Array:
	return [
		{ "sky": [Pal.r("night", 1), Pal.r("night", 2), Pal.r("grey", 2), Pal.r("dusk", 5), Pal.r("dusk", 6)],
		  "ground": [Pal.r("mud", 4), Pal.r("mud", 3), Pal.r("mud", 2), Pal.r("mud", 1)],
		  "far1": Pal.r("night", 3), "far2": Pal.r("night", 2), "haze": Pal.r("grey", 4), "accent": Pal.r("moss", 4) },
		{ "sky": [Pal.r("night", 0), Pal.r("dusk", 1), Pal.r("dusk", 3), Pal.r("dusk", 6), Pal.r("fire", 4)],
		  "ground": [Pal.r("mud", 4), Pal.r("wood", 4), Pal.r("wood", 3), Pal.r("wood", 2)],
		  "far1": Pal.r("dusk", 2), "far2": Pal.r("dusk", 0), "haze": Pal.r("dusk", 6), "accent": Pal.r("fire", 5) },
		{ "sky": [Pal.r("fog", 0), Pal.r("fog", 1), Pal.r("fog", 2), Pal.r("fog", 3), Pal.r("moss", 5)],
		  "ground": [Pal.r("moss", 3), Pal.r("moss", 2), Pal.r("moss", 1), Pal.r("moss", 0)],
		  "far1": Pal.r("fog", 1), "far2": Pal.r("fog", 0), "haze": Pal.r("fog", 4), "accent": Pal.r("moss", 8) },
		{ "sky": [Pal.r("ink", 1), Pal.r("chaos", 0), Pal.r("chaos", 1), Pal.r("blood", 2), Pal.r("blood", 4)],
		  "ground": [Pal.r("chaos", 1), Pal.r("ink", 3), Pal.r("ink", 2), Pal.r("ink", 1)],
		  "far1": Pal.r("chaos", 1), "far2": Pal.r("ink", 1), "haze": Pal.r("blood", 3), "accent": Pal.r("chaos", 6) },
	]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var th := _themes()
	var stages: Array = level.data["stages"]
	for i in th.size():
		var sa: StageArt = StageArt.get_stage(str(stages[i].get("folder", ""))) if i < stages.size() else null
		art.append(sa)
		var sky: Dictionary = sa.layer("sky") if sa != null else {}
		var gnd: Dictionary = sa.layer("ground") if sa != null else {}
		sky_tex.append(sky["tex"] if not sky.is_empty() else _gradient_texture(th[i]["sky"], 460))
		sky_par.append(float(sky["parallax"]) if not sky.is_empty() else 0.0)
		ground_tex.append(gnd["tex"] if not gnd.is_empty() else _gradient_texture(th[i]["ground"], 420))
		ground_par.append(float(gnd["parallax"]) if not gnd.is_empty() else 1.0)
	sky_a = _layer(-12)
	sky_b = _layer(-12)
	gnd_a = _layer(-11)
	gnd_b = _layer(-11)
	fore = LevelForeground.new()
	fore.bg = self
	fore.z_index = 5
	add_child(fore)

func _layer(z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.z_index = z
	s.region_enabled = true
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(WPT, WPT)
	add_child(s)
	return s

## Gradient przez kolejne kolory palety z ditheringiem Bayera 4x4 (bez rozmytych przejść).
func _gradient_texture(seq: Array, h: int) -> ImageTexture:
	var img := Image.create(TEX_W, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var u: float = float(y) / float(h - 1) * float(seq.size() - 1)
		var i: int = mini(int(u), seq.size() - 2)
		var f: float = u - i
		for x in TEX_W:
			var th: float = (float(BAYER[y % 4][x]) + 0.5) / 16.0
			img.set_pixel(x, y, seq[i + 1] if f > th else seq[i])
	return ImageTexture.create_from_image(img)

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _stage_index_at(x: float) -> int:
	var idx := 0
	var stages: Array = level.data["stages"]
	for i in stages.size():
		if x >= float(stages[i]["start"]):
			idx = i
	return idx

func _update_layers(vl: float, vw: float) -> void:
	var cx: float = vl + vw * 0.5
	var stages: Array = level.data["stages"]
	var i: int = _stage_index_at(cx)
	var j: int = mini(i + 1, stages.size() - 1)
	var k: float = 0.0
	if j != i:
		k = clampf((cx - (float(stages[j]["start"]) - 500.0)) / 500.0, 0.0, 1.0)
	_place(sky_a, sky_tex[i], sky_par[i], vl, vw, true)
	_place(sky_b, sky_tex[j], sky_par[j], vl, vw, true)
	_place(gnd_a, ground_tex[i], ground_par[i], vl, vw, false)
	_place(gnd_b, ground_tex[j], ground_par[j], vl, vw, false)
	sky_b.modulate.a = k
	gnd_b.modulate.a = k

## Układa warstwę powtarzaną poziomo (tekstura z pliku albo wygenerowana): piksel-w-piksel, z paralaksą.
func _place(spr: Sprite2D, tex: Texture2D, par: float, vl: float, vw: float, is_sky: bool) -> void:
	var tw: int = tex.get_width()
	var th: int = tex.get_height()
	spr.texture = tex
	var wpx: int = int(ceil((vw + 8.0) / WPT)) + 2
	var off: int = int(fposmod(floorf(vl * par / WPT), float(tw)))
	spr.region_rect = Rect2(off, 0, wpx, th)
	spr.position = Vector2(floorf(vl / WPT) * WPT, (HORIZON - th * WPT) if is_sky else HORIZON)

## Rysuje teksturę powtarzaną poziomo z paralaksą; dolna krawędź na y_bottom (+ y_offset z manifestu, w px).
func draw_tiled(ci: CanvasItem, ly: Dictionary, vl: float, vw: float, y_bottom: float) -> void:
	var tex: Texture2D = ly["tex"]
	var w: float = tex.get_width() * WPT
	var h: float = tex.get_height() * WPT
	var off: float = vl * float(ly["parallax"])
	var y: float = y_bottom - h + float(ly["y_offset"]) * WPT
	for kk in range(int(floor(off / w)), int(ceil((off + vw) / w)) + 1):
		ci.draw_texture_rect(tex, Rect2(floorf(kk * w - off + vl), y, w + 1.0, h), false)

func _hash(i: int, salt: int = 0) -> float:
	var h: int = absi((i * 73856093) ^ (salt * 19349663)) % 1000
	return float(h) / 1000.0

# ------------------------------------------------------------------ rysowanie

func _p(pts: Array, fill: Color) -> void:
	MonsterArt.poly(self, pts, fill, 1.8)

func _l(a: Vector2, b: Vector2, col: Color, w: float = 3.0) -> void:
	MonsterArt.line(self, a, b, col, w, 1.0)

func _draw() -> void:
	if level == null:
		return
	var vl: float = level.view_left
	var vw: float = level.view_w
	_update_layers(vl, vw)
	var stage: int = _stage_index_at(vl + vw * 0.5)
	var th: Dictionary = _themes()[stage]
	var sa: StageArt = art[stage] if stage < art.size() else null
	var f1: Dictionary = sa.layer("far1") if sa != null else {}
	var f2: Dictionary = sa.layer("far2") if sa != null else {}
	if f1.is_empty():
		_draw_far(vl, vw, th, 0.15, th["far1"], 70.0, 130.0, 1)
	else:
		draw_tiled(self, f1, vl, vw, HORIZON)
	if f2.is_empty():
		_draw_far(vl, vw, th, 0.32, th["far2"], 50.0, 105.0, 2)
	else:
		draw_tiled(self, f2, vl, vw, HORIZON)
	_draw_haze(vl, vw, th)
	var step := 150.0
	var first: int = int(floor((vl - 300.0) / step))
	var last: int = int(ceil((vl + vw + 300.0) / step))
	for i in range(first, last + 1):
		_draw_ground_detail(i, i * step, vl, vw)
		_draw_ground_detail(i + 5000, i * step + 70.0, vl, vw)          # drugi przebieg: gęstsze detale podłoża
	for i in range(first, last + 1):
		_draw_prop(i, i * step)

func _draw_far(vl: float, vw: float, th: Dictionary, par: float, col: Color, h0: float, h1: float, salt: int) -> void:
	var stage: int = _stage_index_at(vl + vw * 0.5)
	var off: float = vl * par
	var step := 90.0 if stage == 2 else 150.0
	var first: int = int(floor((off - 200.0) / step))
	var last: int = int(ceil((off + vw + 200.0) / step))
	for i in range(first, last + 1):
		var x: float = i * step - off + vl
		var h: float = h0 + _hash(i, salt) * (h1 - h0)
		match stage:
			0:   # wzgórza
				draw_colored_polygon(PackedVector2Array([Vector2(x - 110, HORIZON), Vector2(x - 40, HORIZON - h * 0.8), Vector2(x + 30, HORIZON - h), Vector2(x + 120, HORIZON)]), col)
			1:   # sylwetki dachów i dymy w oddali
				var w := 60.0 + _hash(i, 9) * 50.0
				draw_colored_polygon(PackedVector2Array([Vector2(x - w, HORIZON), Vector2(x - w, HORIZON - h * 0.45), Vector2(x, HORIZON - h * 0.85), Vector2(x + w, HORIZON - h * 0.45), Vector2(x + w, HORIZON)]), col)
				if par < 0.2 and _hash(i, 4) < 0.35:
					for k in 5:
						var u: float = fmod(t * 0.35 + k * 0.2 + _hash(i, 5), 1.0)
						draw_rect(Rect2(x + sin(u * 5.0 + k) * 6.0, HORIZON - h * 0.85 - u * 70.0, 6, 6), Pal.r("dusk", 2 + k % 2))
			2:   # las świerkowy
				draw_colored_polygon(PackedVector2Array([Vector2(x - 34, HORIZON), Vector2(x - 20, HORIZON - h * 0.45), Vector2(x - 28, HORIZON - h * 0.45), Vector2(x - 12, HORIZON - h * 0.8), Vector2(x - 18, HORIZON - h * 0.8), Vector2(x, HORIZON - h * 1.15), Vector2(x + 18, HORIZON - h * 0.8), Vector2(x + 12, HORIZON - h * 0.8), Vector2(x + 28, HORIZON - h * 0.45), Vector2(x + 20, HORIZON - h * 0.45), Vector2(x + 34, HORIZON)]), col)
			_:   # poszarpane skały i iglice Chaosu
				draw_colored_polygon(PackedVector2Array([Vector2(x - 60, HORIZON), Vector2(x - 30, HORIZON - h * 0.6), Vector2(x - 14, HORIZON - h * 0.5), Vector2(x, HORIZON - h * 1.3), Vector2(x + 14, HORIZON - h * 0.55), Vector2(x + 44, HORIZON - h * 0.8), Vector2(x + 70, HORIZON)]), col)
				if par > 0.3 and _hash(i, 6) < 0.3:
					draw_circle(Vector2(x, HORIZON - h * 1.3), 4.0, Pal.r("chaos", 6 if int(t * 3.0 + i) % 2 == 0 else 5))

func _draw_haze(vl: float, vw: float, th: Dictionary) -> void:
	var c: Color = th["haze"]
	for i in 4:
		var drift: float = fmod(t * (6.0 + i * 3.0), 96.0)
		for k in int(vw / 96.0) + 3:
			var x: float = vl - 96.0 + k * 96.0 + drift - fmod(vl, 96.0)
			draw_rect(Rect2(x, HORIZON - 26.0 + i * 8.0, 60.0, 4.0), Color(c.r, c.g, c.b, 0.30 - i * 0.05))

func _draw_ground_detail(i: int, x: float, vl: float, vw: float) -> void:
	var stage: int = _stage_index_at(x)
	var lane0: float = level.lane_min()
	var lane1: float = level.lane_max()
	var r1: float = _hash(i, 11)
	var r2: float = _hash(i, 12)
	var gy: float = lane0 - 10.0 + r2 * (lane1 - lane0 + 90.0)
	var gx: float = x + r1 * 120.0
	# koleiny wozów (równoległe pary linii)
	if r1 < 0.55:
		var ry: float = lane0 + 30.0 + _hash(i, 13) * 130.0
		var dark: Color = Pal.r("mud", 0) if stage != 3 else Pal.r("ink", 0)
		draw_line(Vector2(gx, ry), Vector2(gx + 140.0, ry + 3.0), dark, 3.0)
		draw_line(Vector2(gx, ry + 8.0), Vector2(gx + 140.0, ry + 11.0), dark, 3.0)
		draw_line(Vector2(gx + 6, ry + 3.5), Vector2(gx + 130.0, ry + 6.0), Pal.r("mud", 3) if stage < 2 else Pal.r("moss", 2), 1.5)
	# kałuże z odbiciem nieba
	if r2 < 0.22:
		var pw: float = 36.0 + r1 * 40.0
		var sky: Color = Pal.r("night", 4) if stage < 3 else Pal.r("blood", 3)
		_ell(Vector2(gx, gy), pw, 8.0, sky.darkened(0.2))
		_ell(Vector2(gx - 4, gy - 1), pw * 0.7, 5.0, sky)
		draw_line(Vector2(gx - pw * 0.4, gy - 2), Vector2(gx - pw * 0.1, gy - 2), Pal.r("white", 0), 1.5)
	# kępy trawy / chwasty
	elif r2 < 0.55 and stage < 3:
		var gc: Color = Pal.r("moss", 4) if stage != 1 else Pal.r("straw", 3)
		for k in 4:
			var bx: float = gx + k * 4.0
			draw_line(Vector2(bx, gy), Vector2(bx + (k - 1.5) * 3.0, gy - 9.0 - (k % 2) * 4.0), gc, 1.8)
	# kamienie
	elif r2 < 0.70:
		_p([Vector2(gx - 9, gy + 3), Vector2(gx - 6, gy - 5), Vector2(gx + 5, gy - 6), Vector2(gx + 10, gy + 3)], Pal.r("grey", 3 if stage != 3 else 1))
	# ślady walki i skażenia
	elif r2 < 0.80 and stage >= 1:
		match stage:
			1:    # osmalone plamy po pożarze, połamana broń
				_ell(Vector2(gx, gy), 26.0, 7.0, Pal.r("ink", 1))
				draw_line(Vector2(gx - 14, gy - 4), Vector2(gx + 14, gy - 9), Pal.r("wood", 2), 3.0)
			2:    # strzały wbite w ziemię
				for k in 3:
					var ax: float = gx + k * 7.0
					_l(Vector2(ax, gy), Vector2(ax + 3.0, gy - 22.0), Pal.r("wood", 5), 1.8)
					_p([Vector2(ax + 3, gy - 22), Vector2(ax, gy - 28), Vector2(ax + 6, gy - 28)], Pal.r("grey", 1))
			3:    # świecące runy na ziemi
				var gl: int = 5 + int(2.0 * (0.5 + 0.5 * sin(t * 3.0 + i)))
				draw_arc(Vector2(gx, gy), 24.0, 0, TAU, 18, Pal.r("chaos", gl), 2.0)
				draw_line(Vector2(gx - 12, gy - 4), Vector2(gx + 12, gy + 4), Pal.r("chaos", gl), 2.0)

func _ell(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		pts.append(c + Vector2(cos(TAU * i / 14.0) * rx, sin(TAU * i / 14.0) * ry))
	draw_colored_polygon(pts, col)

## Wybiera rekwizyt dla slotu: [nazwa, przesunięcie_y, parametry...]. Nazwy = pliki props/<nazwa>.png w folderze etapu.
func _pick_prop(stage: int, r: float, v: float, _i: int) -> Array:
	match stage:
		0:   # droga
			if r < 0.30: return ["fence_broken" if v < 0.3 else "fence", 8.0, 4, v < 0.3]
			elif r < 0.52: return ["tree_dead" if v < 0.2 else "tree_oak", 0.0, 0.8 + v * 0.5, v < 0.2, false]
			elif r < 0.62: return ["signpost", 12.0]
			elif r < 0.74: return ["bush", 10.0]
			elif r < 0.80: return ["milestone", 12.0]
			elif r < 0.86: return ["stump_axe", 14.0]
		1:   # wieś
			if r < 0.30: return ["house_thatch" if v < 0.5 else "house_shingle", 0.0, 0.95 + v * 0.35, 0 if v < 0.5 else 1]
			elif r < 0.40: return ["house_burnt", 0.0, 1.0, 2]
			elif r < 0.48: return ["barn", 0.0]
			elif r < 0.60: return ["fence_broken" if v < 0.4 else "fence", 8.0, 5, v < 0.4]
			elif r < 0.66: return ["gate", 8.0]
			elif r < 0.74: return ["cart", 24.0, v < 0.5]
			elif r < 0.80: return ["well", 18.0]
			elif r < 0.86: return ["crates", 20.0]
			elif r < 0.91: return ["scarecrow", 18.0]
		2:   # pola i las
			if r < 0.50:
				var dead: bool = v < 0.35
				var pine: bool = v > 0.6
				return ["tree_dead" if dead else ("tree_pine" if pine else "tree_oak"), 0.0, 1.0 + v * 0.8, dead, pine]
			elif r < 0.60: return ["bush", 10.0]
			elif r < 0.68: return ["stone_big", 14.0]
			elif r < 0.76: return ["fence_broken", 8.0, 3, true]
			elif r < 0.82: return ["tent", 16.0]
			elif r < 0.86: return ["banner_torn", 16.0]
		3:   # legowisko
			if r < 0.28: return ["obelisk", 14.0]
			elif r < 0.46: return ["brazier", 20.0]
			elif r < 0.62: return ["tree_twisted", 0.0, 1.2, true, false, true]
			elif r < 0.74: return ["bones", 30.0]
			elif r < 0.82: return ["crystals", 18.0]
	return []

func _draw_prop(i: int, x: float) -> void:
	var stage: int = _stage_index_at(x)
	var p: Array = _pick_prop(stage, _hash(i, 7), _hash(i, 8), i)
	if p.is_empty():
		return
	var y: float = HORIZON + 10.0 + float(p[1])
	var sa: StageArt = art[stage] if stage < art.size() else null
	if sa != null:
		var vars: Array = sa.prop_variants(str(p[0]))
		if not vars.is_empty():
			var tex: Texture2D = vars[int(_hash(i, 21) * vars.size()) % vars.size()]
			var w: float = tex.get_width() * WPT
			var h: float = tex.get_height() * WPT
			if _hash(i, 22) < 0.5:
				draw_texture_rect(tex, Rect2(x + w * 0.5, y - h, -w, h), false)      # lustrzane odbicie dla różnorodności
			else:
				draw_texture_rect(tex, Rect2(x - w * 0.5, y - h, w, h), false)
			return
	_proc_prop(str(p[0]), x, y, p, i)

func _proc_prop(name: String, x: float, y: float, p: Array, i: int) -> void:
	match name:
		"fence", "fence_broken": _fence(x, y, int(p[2]), bool(p[3]))
		"tree_oak", "tree_dead", "tree_pine", "tree_twisted": _tree(x, y, float(p[2]), bool(p[3]), bool(p[4]), p.size() > 5 and bool(p[5]))
		"signpost": _signpost(x, y)
		"bush": _bush(x, y)
		"milestone": _milestone(x, y)
		"stump_axe": _stump_axe(x, y)
		"house_thatch", "house_shingle", "house_burnt": _house(x, y, float(p[2]), int(p[3]), i)
		"barn": _barn(x, y, i)
		"gate": _gate(x, y)
		"cart": _cart(x, y, bool(p[2]))
		"well": _well(x, y)
		"crates": _crates(x, y)
		"scarecrow": _scarecrow(x, y)
		"stone_big": _stone_big(x, y)
		"tent": _tent(x, y)
		"banner_torn": _banner_torn(x, y)
		"obelisk": _obelisk(x, y, i)
		"brazier": _brazier(x, y)
		"bones": _bones(x, y)
		"crystals": _crystals(x, y, i)

# ---- rekwizyty -----------------------------------------------------------

func _fence(x: float, y: float, n: int, broken: bool) -> void:
	var c: Color = Pal.r("wood", 4)
	var d: Color = Pal.r("wood", 2)
	for k in n:
		var px: float = x + k * 24.0
		var lean: float = 8.0 if (broken and k == 2) else 0.0
		_p([Vector2(px - 3, y), Vector2(px - 3 + lean * 0.2, y - 30), Vector2(px + lean, y - 34), Vector2(px + 4 + lean * 0.2, y - 30), Vector2(px + 4, y)], c)
	if not broken:
		_l(Vector2(x, y - 24), Vector2(x + n * 24.0, y - 24), d, 4.0)
		_l(Vector2(x, y - 11), Vector2(x + n * 24.0, y - 11), d, 4.0)
	else:
		_l(Vector2(x, y - 24), Vector2(x + 2.2 * 24.0, y - 22), d, 4.0)
		_l(Vector2(x + 2.0 * 24.0, y - 6), Vector2(x + n * 24.0, y - 14), d, 4.0)
		_l(Vector2(x, y - 11), Vector2(x + 24.0, y - 11), d, 4.0)

func _gate(x: float, y: float) -> void:
	var c: Color = Pal.r("wood", 3)
	_p([Vector2(x - 4, y), Vector2(x - 4, y - 56), Vector2(x + 5, y - 56), Vector2(x + 5, y)], Pal.r("wood", 2))
	_p([Vector2(x + 60, y), Vector2(x + 60, y - 56), Vector2(x + 69, y - 56), Vector2(x + 69, y)], Pal.r("wood", 2))
	_p([Vector2(x + 4, y - 4), Vector2(x + 58, y - 2), Vector2(x + 58, y - 36), Vector2(x + 4, y - 40)], c)
	_l(Vector2(x + 5, y - 6), Vector2(x + 57, y - 36), Pal.r("wood", 1), 3.0)
	_l(Vector2(x + 5, y - 36), Vector2(x + 57, y - 6), Pal.r("wood", 1), 3.0)

func _tree(x: float, y: float, s: float, dead: bool, pine: bool, twisted: bool = false) -> void:
	var trunk: Color = Pal.r("wood", 1)
	_p([Vector2(x - 11 * s, y + 10), Vector2(x - 5 * s, y - 70 * s), Vector2(x + 5 * s, y - 70 * s), Vector2(x + 11 * s, y + 10)], trunk)
	ci_lines(x, y, s, trunk, 3)
	if dead or twisted:
		var br: Color = Pal.r("wood", 1) if not twisted else Pal.r("chaos", 1)
		_l(Vector2(x, y - 55 * s), Vector2(x - 42 * s, y - 100 * s), br, 5.0)
		_l(Vector2(x - 42 * s, y - 100 * s), Vector2(x - 52 * s, y - 128 * s), br, 3.0)
		_l(Vector2(x, y - 72 * s), Vector2(x + 40 * s, y - 118 * s), br, 5.0)
		_l(Vector2(x + 40 * s, y - 118 * s), Vector2(x + 62 * s, y - 130 * s), br, 3.0)
		_l(Vector2(x, y - 70 * s), Vector2(x - 6 * s, y - 140 * s), br, 4.0)
		if twisted:
			var gl: int = 5 + int(2.0 * (0.5 + 0.5 * sin(t * 3.0 + x)))
			draw_circle(Vector2(x - 52 * s, y - 128 * s), 4.0, Pal.r("chaos", gl))
			draw_circle(Vector2(x + 62 * s, y - 130 * s), 4.0, Pal.r("glow", 2))
	elif pine:
		for k in 4:
			var yy: float = y - 40 * s - k * 32 * s
			var hw: float = (54 - k * 11) * s
			_p([Vector2(x - hw, yy), Vector2(x, yy - 46 * s), Vector2(x + hw, yy)], Pal.r("moss", 1 + (k % 2)))
	else:
		var leaf: Color = Pal.r("moss", 2)
		_circ(Vector2(x - 28 * s, y - 92 * s), 30 * s, Pal.r("moss", 1))
		_circ(Vector2(x + 28 * s, y - 96 * s), 32 * s, leaf)
		_circ(Vector2(x, y - 118 * s), 40 * s, leaf)
		_circ(Vector2(x - 10 * s, y - 124 * s), 22 * s, Pal.r("moss", 4))

func ci_lines(x: float, y: float, s: float, c: Color, n: int) -> void:
	for k in n:
		draw_line(Vector2(x - 6 * s + k * 5 * s, y + 4), Vector2(x - 3 * s + k * 4 * s, y - 60 * s), c.darkened(0.3), 1.5)

func _circ(c: Vector2, r: float, col: Color) -> void:
	_ell(c, r, r * 0.92, col)
	draw_arc(c, r, 0, TAU, 20, MonsterArt.INK, 1.8)

func _bush(x: float, y: float) -> void:
	_circ(Vector2(x - 14, y - 12), 14.0, Pal.r("moss", 2))
	_circ(Vector2(x + 10, y - 14), 17.0, Pal.r("moss", 3))
	_circ(Vector2(x, y - 22), 12.0, Pal.r("moss", 4))

func _signpost(x: float, y: float) -> void:
	_p([Vector2(x - 3, y), Vector2(x - 3, y - 70), Vector2(x + 3, y - 70), Vector2(x + 3, y)], Pal.r("wood", 2))
	_p([Vector2(x - 4, y - 66), Vector2(x + 34, y - 66), Vector2(x + 44, y - 58), Vector2(x + 34, y - 50), Vector2(x - 4, y - 50)], Pal.r("wood", 4))
	_p([Vector2(x + 4, y - 44), Vector2(x - 28, y - 44), Vector2(x - 38, y - 37), Vector2(x - 28, y - 30), Vector2(x + 4, y - 30)], Pal.r("wood", 3))
	draw_line(Vector2(x + 2, y - 60), Vector2(x + 30, y - 60), Pal.r("wood", 1), 1.5)

func _milestone(x: float, y: float) -> void:
	_p([Vector2(x - 12, y), Vector2(x - 10, y - 32), Vector2(x, y - 38), Vector2(x + 10, y - 32), Vector2(x + 12, y)], Pal.r("grey", 3))
	draw_line(Vector2(x - 4, y - 24), Vector2(x + 4, y - 24), Pal.r("grey", 1), 2.0)
	draw_line(Vector2(x, y - 28), Vector2(x, y - 14), Pal.r("grey", 1), 2.0)

func _stump_axe(x: float, y: float) -> void:
	_p([Vector2(x - 14, y), Vector2(x - 12, y - 22), Vector2(x + 12, y - 22), Vector2(x + 14, y)], Pal.r("wood", 3))
	_ell(Vector2(x, y - 22), 12.0, 4.0, Pal.r("wood", 6))
	_l(Vector2(x + 4, y - 26), Vector2(x + 24, y - 52), Pal.r("wood", 2), 3.0)
	_p([Vector2(x + 18, y - 44), Vector2(x + 30, y - 52), Vector2(x + 28, y - 38)], Pal.r("steel", 4))

func _house(x: float, y: float, s: float, kind: int, seed: int) -> void:
	var w: float = 118.0 * s
	var h: float = 74.0 * s
	var burnt: bool = kind == 2
	var wall: Color = Pal.r("wood", 4) if not burnt else Pal.r("ink", 1)
	var wall_d: Color = Pal.r("wood", 2) if not burnt else Pal.r("ink", 0)
	_p([Vector2(x - w * 0.5, y + 8), Vector2(x - w * 0.5, y - h), Vector2(x + w * 0.5, y - h), Vector2(x + w * 0.5, y + 8)], wall)
	for k in int(w / 12.0):                                                                        # deski
		var px: float = x - w * 0.5 + 6.0 + k * 12.0
		draw_line(Vector2(px, y + 6), Vector2(px, y - h + 2), wall_d, 1.5)
	for k in 3:                                                                                    # kamienna podmurówka
		_p([Vector2(x - w * 0.5 + k * w / 3.0, y + 8), Vector2(x - w * 0.5 + k * w / 3.0 + 2, y - 4), Vector2(x - w * 0.5 + (k + 1) * w / 3.0, y - 4), Vector2(x - w * 0.5 + (k + 1) * w / 3.0, y + 8)], Pal.r("grey", 2 if not burnt else 0))
	if not burnt:
		var roof: Color = Pal.r("straw", 3) if kind == 0 else Pal.r("wood", 1)
		_p([Vector2(x - w * 0.5 - 14, y - h + 4), Vector2(x - w * 0.12, y - h - 54 * s), Vector2(x + w * 0.12, y - h - 54 * s), Vector2(x + w * 0.5 + 14, y - h + 4)], roof)
		for k in 5:                                                                                # strzecha / gont
			var ry: float = y - h - 6.0 - k * 10.0 * s
			var inset: float = k * 14.0 * s
			for q in int((w - inset * 1.3) / 14.0):
				var qx: float = x - w * 0.5 + inset * 0.6 + q * 14.0 + (7.0 if k % 2 == 0 else 0.0)
				if kind == 0:
					draw_line(Vector2(qx, ry), Vector2(qx + 4.0, ry - 8.0), Pal.r("straw", 1), 1.5)
				else:
					draw_arc(Vector2(qx, ry), 6.0, 0.2, PI - 0.2, 6, Pal.r("wood", 0), 1.8)
		if kind == 0:
			_l(Vector2(x - w * 0.12, y - h - 54 * s), Vector2(x + w * 0.12, y - h - 54 * s), Pal.r("wood", 2), 4.0)
		_p([Vector2(x + w * 0.22, y - h - 20 * s), Vector2(x + w * 0.22, y - h - 56 * s), Vector2(x + w * 0.34, y - h - 56 * s), Vector2(x + w * 0.34, y - h - 14 * s)], Pal.r("grey", 2))   # komin
		for k in 4:
			var u: float = fmod(t * 0.4 + k * 0.25 + _hash(seed, 3), 1.0)
			draw_rect(Rect2(x + w * 0.27 + sin(u * 6.0) * 5.0, y - h - 60 * s - u * 60.0, 6, 6), Pal.r("grey", 3 + k % 2))
		var lit: Color = Pal.r("fire", 5) if _hash(seed, 2) < 0.6 else Pal.r("fire", 2)
		_p([Vector2(x + 12, y - h * 0.7), Vector2(x + 12, y - h * 0.35), Vector2(x + 36, y - h * 0.35), Vector2(x + 36, y - h * 0.7)], lit)
		draw_line(Vector2(x + 24, y - h * 0.7), Vector2(x + 24, y - h * 0.35), Pal.r("wood", 1), 1.8)
		draw_line(Vector2(x + 12, y - h * 0.52), Vector2(x + 36, y - h * 0.52), Pal.r("wood", 1), 1.8)
		_p([Vector2(x - 34, y + 8), Vector2(x - 34, y - 44 * s), Vector2(x - 12, y - 44 * s), Vector2(x - 12, y + 8)], Pal.r("wood", 1))
		draw_circle(Vector2(x - 17, y - 16 * s), 1.8, Pal.r("gold", 3))
	else:
		_l(Vector2(x - w * 0.5 - 6, y - h), Vector2(x - 16, y - h - 56 * s), Pal.r("ink", 2), 6.0)
		_l(Vector2(x + w * 0.5 + 6, y - h), Vector2(x + 26, y - h - 38 * s), Pal.r("ink", 2), 6.0)
		_l(Vector2(x - 16, y - h - 56 * s), Vector2(x + 26, y - h - 38 * s), Pal.r("ink", 2), 4.0)
		for k in 3:
			var fx: float = x - 30.0 + k * 28.0
			var fh: float = 20.0 + 8.0 * sin(t * 9.0 + k * 2.0 + seed)
			_p([Vector2(fx - 9, y - h + 2), Vector2(fx - 3, y - h - fh * 0.6), Vector2(fx, y - h - fh), Vector2(fx + 5, y - h - fh * 0.5), Vector2(fx + 10, y - h + 2)], Pal.r("fire", 4))
			_p([Vector2(fx - 4, y - h + 2), Vector2(fx, y - h - fh * 0.6), Vector2(fx + 5, y - h + 2)], Pal.r("fire", 6))
		for k in 5:
			var u: float = fmod(t * 0.5 + k * 0.2 + _hash(seed, 3), 1.0)
			draw_rect(Rect2(x - 30 + k * 16 + sin(u * 8.0) * 8.0, y - h - 40 - u * 90.0, 5, 5), Pal.r("ink", 3) if k % 2 == 0 else Pal.r("ember", 2))
		_p([Vector2(x - 14, y + 8), Vector2(x - 14, y - 44 * s), Vector2(x + 8, y - 44 * s), Vector2(x + 8, y + 8)], Pal.r("ink", 0))

func _barn(x: float, y: float, seed: int) -> void:
	var w := 168.0
	var h := 84.0
	_p([Vector2(x - w * 0.5, y + 8), Vector2(x - w * 0.5, y - h), Vector2(x + w * 0.5, y - h), Vector2(x + w * 0.5, y + 8)], Pal.r("wood", 3))
	for k in int(w / 14.0):
		var px: float = x - w * 0.5 + 7.0 + k * 14.0
		draw_line(Vector2(px, y + 6), Vector2(px, y - h + 2), Pal.r("wood", 1), 1.5)
	_p([Vector2(x - w * 0.5 - 10, y - h + 4), Vector2(x, y - h - 60), Vector2(x + w * 0.5 + 10, y - h + 4)], Pal.r("wood", 1))
	_p([Vector2(x - 34, y + 8), Vector2(x - 34, y - 52), Vector2(x + 34, y - 52), Vector2(x + 34, y + 8)], Pal.r("wood", 2))
	draw_line(Vector2(x, y - 52), Vector2(x, y + 8), MonsterArt.INK, 2.0)
	_l(Vector2(x - 32, y + 6), Vector2(x - 2, y - 50), Pal.r("wood", 4), 3.0)
	_l(Vector2(x + 32, y + 6), Vector2(x + 2, y - 50), Pal.r("wood", 4), 3.0)
	_p([Vector2(x - 14, y - h + 14), Vector2(x - 14, y - h + 40), Vector2(x + 14, y - h + 40), Vector2(x + 14, y - h + 14)], Pal.r("straw", 2))

func _cart(x: float, y: float, broken: bool) -> void:
	var c: Color = Pal.r("wood", 3)
	_p([Vector2(x - 34, y - 18), Vector2(x + 34, y - 18), Vector2(x + 28, y - 34), Vector2(x - 28, y - 34)], c)
	_l(Vector2(x + 34, y - 22), Vector2(x + 72, y - 6), Pal.r("wood", 2), 4.0)
	var wc := Vector2(x - 14, y - 12)
	if broken:
		wc = Vector2(x - 22, y - 6)
	draw_circle(wc, 15.0, Pal.r("wood", 2))
	draw_arc(wc, 15.0, 0, TAU, 18, MonsterArt.INK, 1.8)
	for k in 4:
		draw_line(wc, wc + Vector2.from_angle(k * PI / 4.0) * 15.0, Pal.r("wood", 4), 1.5)
		draw_line(wc, wc - Vector2.from_angle(k * PI / 4.0) * 15.0, Pal.r("wood", 4), 1.5)
	_p([Vector2(x - 18, y - 34), Vector2(x - 6, y - 50), Vector2(x + 10, y - 48), Vector2(x + 16, y - 34)], Pal.r("straw", 3))

func _well(x: float, y: float) -> void:
	_p([Vector2(x - 24, y), Vector2(x - 24, y - 24), Vector2(x + 24, y - 24), Vector2(x + 24, y)], Pal.r("grey", 3))
	for k in 3:
		draw_line(Vector2(x - 22, y - 6 - k * 8), Vector2(x + 22, y - 6 - k * 8), Pal.r("grey", 1), 1.5)
	_l(Vector2(x - 22, y - 24), Vector2(x - 22, y - 70), Pal.r("wood", 2), 4.0)
	_l(Vector2(x + 22, y - 24), Vector2(x + 22, y - 70), Pal.r("wood", 2), 4.0)
	_p([Vector2(x - 32, y - 68), Vector2(x, y - 90), Vector2(x + 32, y - 68)], Pal.r("wood", 1))
	draw_line(Vector2(x, y - 68), Vector2(x, y - 40), Pal.r("wood", 5), 1.8)

func _crates(x: float, y: float) -> void:
	for k in 2:
		var cx: float = x + k * 30.0
		_p([Vector2(cx - 14, y), Vector2(cx - 14, y - 28), Vector2(cx + 14, y - 28), Vector2(cx + 14, y)], Pal.r("wood", 4))
		draw_line(Vector2(cx - 12, y - 2), Vector2(cx + 12, y - 26), Pal.r("wood", 2), 2.0)
		draw_line(Vector2(cx - 12, y - 26), Vector2(cx + 12, y - 2), Pal.r("wood", 2), 2.0)
	_p([Vector2(x + 2, y - 28), Vector2(x + 2, y - 54), Vector2(x + 28, y - 54), Vector2(x + 28, y - 28)], Pal.r("wood", 3))
	_p([Vector2(x + 46, y), Vector2(x + 50, y - 22), Vector2(x + 66, y - 22), Vector2(x + 70, y)], Pal.r("wood", 5))      # worek

func _scarecrow(x: float, y: float) -> void:
	_l(Vector2(x, y), Vector2(x, y - 78), Pal.r("wood", 2), 4.0)
	_l(Vector2(x - 28, y - 58), Vector2(x + 28, y - 58), Pal.r("wood", 2), 4.0)
	_p([Vector2(x - 12, y - 62), Vector2(x - 16, y - 34), Vector2(x + 16, y - 34), Vector2(x + 12, y - 62)], Pal.r("mud", 3))
	draw_circle(Vector2(x, y - 82), 9.0, Pal.r("straw", 4))
	draw_arc(Vector2(x, y - 82), 9.0, 0, TAU, 12, MonsterArt.INK, 1.8)
	_p([Vector2(x - 12, y - 86), Vector2(x, y - 102), Vector2(x + 12, y - 86)], Pal.r("wood", 1))

func _stone_big(x: float, y: float) -> void:
	_p([Vector2(x - 26, y), Vector2(x - 22, y - 30), Vector2(x - 4, y - 44), Vector2(x + 20, y - 34), Vector2(x + 28, y)], Pal.r("grey", 3))
	_p([Vector2(x - 4, y - 44), Vector2(x + 20, y - 34), Vector2(x + 28, y), Vector2(x + 4, y)], Pal.r("grey", 2))
	draw_line(Vector2(x - 12, y - 26), Vector2(x - 2, y - 14), Pal.r("moss", 4), 3.0)

func _tent(x: float, y: float) -> void:
	_p([Vector2(x - 44, y), Vector2(x, y - 58), Vector2(x + 44, y)], Pal.r("grey", 3))
	_p([Vector2(x, y - 58), Vector2(x + 44, y), Vector2(x + 8, y)], Pal.r("grey", 2))
	_p([Vector2(x - 8, y), Vector2(x, y - 26), Vector2(x + 8, y)], Pal.r("ink", 1))
	var f: float = 5.0 * sin(t * 10.0)                                   # zgasłe ognisko
	_ell(Vector2(x + 70, y + 2), 12.0, 4.0, Pal.r("ink", 1))
	if int(t * 4.0) % 5 != 0:
		_p([Vector2(x + 64, y), Vector2(x + 70, y - 12 - f), Vector2(x + 76, y)], Pal.r("fire", 3))

func _banner_torn(x: float, y: float) -> void:
	_l(Vector2(x, y), Vector2(x, y - 92), Pal.r("wood", 2), 4.0)
	_p([Vector2(x + 2, y - 90), Vector2(x + 40, y - 86 + sin(t * 2.0) * 3.0), Vector2(x + 28, y - 70), Vector2(x + 42, y - 52), Vector2(x + 2, y - 54)], Pal.r("blood", 3))
	draw_line(Vector2(x + 12, y - 80), Vector2(x + 26, y - 64), Pal.r("gold", 3), 2.0)

func _obelisk(x: float, y: float, seed: int) -> void:
	_p([Vector2(x - 20, y), Vector2(x - 14, y - 90), Vector2(x - 2, y - 118), Vector2(x + 14, y - 90), Vector2(x + 22, y)], Pal.r("ink", 2))
	_p([Vector2(x - 2, y - 118), Vector2(x + 14, y - 90), Vector2(x + 22, y), Vector2(x + 2, y)], Pal.r("chaos", 0))
	var gl: int = 5 + int(2.0 * (0.5 + 0.5 * sin(t * 2.5 + seed)))
	var c: Color = Pal.r("chaos", gl)
	draw_line(Vector2(x - 8, y - 78), Vector2(x + 8, y - 44), c, 2.5)
	draw_line(Vector2(x + 8, y - 78), Vector2(x - 8, y - 44), c, 2.5)
	draw_arc(Vector2(x, y - 62), 24.0, 0, TAU, 20, c, 2.0)

func _brazier(x: float, y: float) -> void:
	_l(Vector2(x, y), Vector2(x, y - 52), Pal.r("ink", 2), 5.0)
	_p([Vector2(x - 18, y - 52), Vector2(x + 18, y - 52), Vector2(x + 12, y - 38), Vector2(x - 12, y - 38)], Pal.r("steel", 1))
	var f: float = 10.0 * sin(t * 8.0 + x)
	_p([Vector2(x - 12, y - 52), Vector2(x - 4, y - 70 - f), Vector2(x, y - 82 - f), Vector2(x + 6, y - 66 - f), Vector2(x + 14, y - 52)], Pal.r("chaos", 5))
	_p([Vector2(x - 6, y - 52), Vector2(x, y - 70 - f * 0.5), Vector2(x + 8, y - 52)], Pal.r("glow", 3))

func _bones(x: float, y: float) -> void:
	var c: Color = Pal.r("bone", 3)
	_l(Vector2(x - 28, y - 4), Vector2(x + 28, y - 8), c, 4.0)
	_l(Vector2(x - 16, y - 18), Vector2(x + 22, y), c, 3.0)
	draw_circle(Vector2(x, y - 14), 10.0, Pal.r("bone", 4))
	draw_arc(Vector2(x, y - 14), 10.0, 0, TAU, 12, MonsterArt.INK, 1.8)
	draw_rect(Rect2(x - 5, y - 17, 3, 4), MonsterArt.INK)
	draw_rect(Rect2(x + 2, y - 17, 3, 4), MonsterArt.INK)
	_l(Vector2(x + 44, y + 6), Vector2(x + 44, y - 70), Pal.r("wood", 1), 4.0)                    # pal z czaszką
	draw_circle(Vector2(x + 44, y - 78), 8.0, Pal.r("bone", 4))

func _crystals(x: float, y: float, seed: int) -> void:
	var gl: int = 4 + int(3.0 * (0.5 + 0.5 * sin(t * 2.0 + seed)))
	for k in 3:
		var cx: float = x - 14.0 + k * 14.0
		var ch: float = 34.0 + k * 10.0 * (1 if k != 1 else 2)
		_p([Vector2(cx - 7, y), Vector2(cx - 5, y - ch * 0.7), Vector2(cx, y - ch), Vector2(cx + 6, y - ch * 0.7), Vector2(cx + 8, y)], Pal.r("chaos", gl))
