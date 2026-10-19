class_name MonsterArt
extends RefCounted
## Tymczasowa, proceduralna grafika potworów w stylu sprite'owym: kolory wyłącznie z palety (Pal),
## 1-2 px obrysy "ink", cieniowanie blokowe (2-3 odcienie rampy), bez gradientów.
## Rysowane w lokalnych jednostkach aktora (stopy w (0,0), twarzą w +x, y w górę ujemne).
## Docelowo zastępowane sprite'ami z assets/sprites/<id>/frames.tres (patrz README).

static var INK: Color = Pal.r("ink", 0)

# ------------------------------------------------------------------ prymitywy

static func poly(ci: CanvasItem, pts: Array, fill: Color, ow: float, outline: bool = true) -> void:
	var pa := PackedVector2Array(pts)
	ci.draw_colored_polygon(pa, fill)
	if outline:
		var c := pa.duplicate()
		c.append(pa[0])
		ci.draw_polyline(c, INK, ow)

static func line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float, ow: float) -> void:
	ci.draw_line(a, b, INK, w + ow * 2.0)
	ci.draw_line(a, b, col, w)

static func disc(ci: CanvasItem, c: Vector2, rx: float, ry: float, fill: Color, ow: float) -> void:
	var pts: Array = []
	for i in 14:
		var a := TAU * i / 14.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	poly(ci, pts, fill, ow)

## Kończyna dwuczłonowa (udo-goleń lub ramię-przedramię).
static func limb(ci: CanvasItem, a: Vector2, k: Vector2, b: Vector2, col: Color, w: float, ow: float) -> void:
	line(ci, a, k, col, w, ow)
	line(ci, k, b, col, w * 0.85, ow)

static func tint(c: Color, flash: float) -> Color:
	return c.lerp(Pal.r("white", 2), 0.6) if flash > 0.0 else c

static func fur_edge(ci: CanvasItem, pts: Array, col: Color, ow: float) -> void:
	# ząbkowana linia futra wzdłuż grzbietu
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var m: Vector2 = (a + b) * 0.5 + Vector2(0, -4)
		poly(ci, [a, m + Vector2(-2, -3), b], col, ow, false)

# ------------------------------------------------------------------ SKAVEN

static func skaven(ci: CanvasItem, a, t: float, po: Dictionary) -> void:
	var fl: float = a.flash
	var ow := 1.7
	var fur := tint(Pal.r("fur", 3), fl)
	var fur_d := tint(Pal.r("fur", 1), fl)
	var fur_l := tint(Pal.r("fur", 5), fl)
	var rag := tint(Pal.r("mud", 3), fl)
	var rag_d := tint(Pal.r("mud", 1), fl)
	var moving: bool = a.state == Actor.State.MOVE
	var w: float = sin(t * 14.0) if moving else 0.0
	var bob: float = absf(sin(t * 14.0)) * 3.0 if moving else sin(t * 3.0) * 1.2
	var lean: float = float(po["lean"]) + 0.30
	var hip := Vector2(0, -40 + bob * 0.4 + float(po["crouch"]))
	var sh := hip + Vector2(lean * 38.0 + 6, -32)
	var head := sh + Vector2(15, -7)
	# ogon: łuk z jaśniejszą końcówką
	var tail: Array = []
	for i in 8:
		var u := float(i) / 7.0
		tail.append(hip + Vector2(-8 - u * 30.0, 6 - sin(u * 3.0 + t * 4.0) * 7.0 + u * 8.0))
	for i in range(7):
		line(ci, tail[i], tail[i + 1], fur_d if i < 5 else fur_l, 4.0 - i * 0.35, ow)
	# nogi cyfrochodne
	for s in [-1, 1]:
		var ph: float = w * s
		var knee: Vector2 = hip + Vector2(s * 5 + 10 * ph, 15)
		var ank: Vector2 = Vector2(s * 5 - 4 + 14 * ph, -7 + maxf(0.0, -ph) * -5)
		limb(ci, hip + Vector2(s * 3, 0), knee, ank, fur_d if s < 0 else fur, 6.0, ow)
		poly(ci, [ank + Vector2(-2, -2), ank + Vector2(13, 3), ank + Vector2(-2, 5)], fur_d, ow)
	# tors zgarbiony + łachmany
	poly(ci, [hip + Vector2(-10, 4), hip + Vector2(10, 0), sh + Vector2(14, 2), sh + Vector2(-8, -4)], rag, ow)
	poly(ci, [hip + Vector2(-10, 4), hip + Vector2(10, 0), hip + Vector2(14, 16), hip + Vector2(4, 12), hip + Vector2(-2, 20), hip + Vector2(-8, 11), hip + Vector2(-14, 18)], rag_d, ow)
	line(ci, hip + Vector2(-10, 0), hip + Vector2(12, -3), Pal.r("wood", 4), 3.0, ow)               # sznur-pas
	poly(ci, [sh + Vector2(-4, 0), sh + Vector2(6, 6), sh + Vector2(2, 14)], fur_l, ow, false)       # łata futra
	fur_edge(ci, [sh + Vector2(-9, -3), hip + Vector2(-9, -12), hip + Vector2(-12, 0)], fur_d, ow)
	# warpstone na rzemieniu
	var gl: float = 0.5 + 0.5 * sin(t * 5.0)
	line(ci, sh + Vector2(-2, 3), sh + Vector2(6, 15), Pal.r("wood", 3), 2.0, ow * 0.6)
	disc(ci, sh + Vector2(6, 17), 3.2, 3.8, Pal.r("moss", 7 + int(gl * 2.0)), ow * 0.8)
	# głowa: pysk, uszy, wąsy, kły
	poly(ci, [head + Vector2(-8, -7), head + Vector2(6, -9), head + Vector2(26, 0), head + Vector2(8, 8), head + Vector2(-8, 7)], fur, ow)
	poly(ci, [head + Vector2(8, 3), head + Vector2(24, 2), head + Vector2(8, 8)], fur_l, ow, false)
	poly(ci, [head + Vector2(-5, -8), head + Vector2(-9, -26), head + Vector2(3, -12)], fur_d, ow)
	poly(ci, [head + Vector2(-4, -11), head + Vector2(-7, -22), head + Vector2(1, -12)], tint(Pal.r("skin", 6), fl), ow, false)
	disc(ci, head + Vector2(25, 0), 2.6, 2.4, tint(Pal.r("glow", 2), fl), ow * 0.8)                    # nos
	disc(ci, head + Vector2(7, -3), 2.4, 2.2, Pal.r("fire", 6), ow * 0.7)                              # oko
	ci.draw_line(head + Vector2(23, 2), head + Vector2(32, 6), Pal.r("bone", 3), 1.0)                  # wąsy
	ci.draw_line(head + Vector2(23, 3), head + Vector2(31, 11), Pal.r("bone", 3), 1.0)
	var open: float = 4.0 if a.state == Actor.State.WINDUP or a.state == Actor.State.ACTIVE else 0.0
	poly(ci, [head + Vector2(16, 7), head + Vector2(20, 11 + open), head + Vector2(22, 6)], Pal.r("bone", 4), ow * 0.6, false)
	# ręka z bronią (zardzewiały tasak z karbami)
	var ang: float = po["ang"]
	var hand := sh + Vector2(8, 6) + Vector2.from_angle(ang) * 12.0
	var dirv := Vector2.from_angle(ang)
	var perp := Vector2(-dirv.y, dirv.x)
	limb(ci, sh + Vector2(4, 0), (sh + hand) * 0.5 + Vector2(0, 5), hand, fur, 4.0, ow)
	line(ci, hand - dirv * 8.0, hand + dirv * 10.0, Pal.r("wood", 4), 3.0, ow)
	var tip := hand + dirv * 40.0
	poly(ci, [hand + dirv * 10.0 + perp * 2.0, hand + dirv * 22.0 + perp * 7.0, hand + dirv * 31.0 + perp * 6.0, tip, hand + dirv * 30.0 - perp * 3.0, hand + dirv * 10.0 - perp * 2.0], tint(Pal.r("ember", 0).lerp(Pal.r("steel", 3), 0.5), fl), ow * 0.9)
	for i in 3:                                                                                         # karby ostrza
		var q := hand + dirv * (18.0 + i * 7.0)
		ci.draw_line(q + perp * 5.0, q + perp * 9.0 + dirv * 3.0, INK, 1.2)
	line(ci, sh + Vector2(-4, 2), sh + Vector2(-8 - w * 4.0, 22), fur_d, 3.5, ow)                      # druga ręka

# ------------------------------------------------------------------ PIES CHAOSU

static func hound(ci: CanvasItem, a, t: float, _po: Dictionary) -> void:
	var fl: float = a.flash
	var ow := 1.6
	var skin := tint(Pal.r("fur", 1).lerp(Pal.r("chaos", 1), 0.35), fl)
	var skin_l := tint(Pal.r("fur", 3).lerp(Pal.r("chaos", 2), 0.3), fl)
	var vein := Pal.r("chaos", 6 if int(t * 6.0) % 2 == 0 else 5)
	var spike := tint(Pal.r("bone", 3), fl)
	var run: bool = a.state == Actor.State.MOVE or a.state == Actor.State.ACTIVE
	var gait: float = sin(t * (18.0 if a.state == Actor.State.ACTIVE else 13.0)) if run else 0.0
	var crouch := 0.0
	var stretch := 0.0
	var jaw := 0.0
	match a.state:
		Actor.State.WINDUP:
			crouch = 11.0 * clampf(a.state_t / maxf(a.windup_time(), 0.01), 0.0, 1.0)
			jaw = 5.0
		Actor.State.ACTIVE:
			stretch = 14.0
			jaw = 8.0
		Actor.State.RECOVER:
			crouch = 4.0
		Actor.State.HURT:
			crouch = 7.0
	var body := Vector2(0, -34 + crouch)
	# tylne i przednie łapy (dwa człony, zad uniesiony)
	for i in 4:
		var front: bool = i >= 2
		var s: float = 1.0 if i % 2 == 0 else -1.0
		var root := body + Vector2((20 + stretch * 0.6) if front else -22, 8)
		var ph: float = gait * s * (1.0 if front else -1.0)
		var knee := root + Vector2(ph * 13.0 + (6.0 if front else -9.0), 12)
		var foot := Vector2(root.x + ph * 18.0 + (4.0 if front else -4.0), 0)
		limb(ci, root, knee, foot, skin if s > 0 else skin.darkened(0.25), 8.0 if not front else 7.0, ow)
		poly(ci, [foot + Vector2(-3, -3), foot + Vector2(11, 0), foot + Vector2(-3, 2)], skin.darkened(0.3), ow * 0.8)
	# ogon z kolcami
	var tp: Array = []
	for i in 6:
		var u := float(i) / 5.0
		tp.append(body + Vector2(-30 - u * 22.0 - stretch * 0.3, -2 - u * 9.0 + sin(t * 8.0 + u * 3.0) * 3.0))
	for i in range(5):
		line(ci, tp[i], tp[i + 1], skin, 5.0 - i * 0.7, ow)
	poly(ci, [tp[5] + Vector2(0, -5), tp[5] + Vector2(-10, 0), tp[5] + Vector2(0, 4)], spike, ow * 0.7)
	# korpus: żebra i żyły skażenia
	poly(ci, [body + Vector2(-32, -2), body + Vector2(-20, -16), body + Vector2(10, -15), body + Vector2(30 + stretch, -9), body + Vector2(30 + stretch, 6), body + Vector2(0, 14), body + Vector2(-30, 10)], skin, ow)
	poly(ci, [body + Vector2(-26, 6), body + Vector2(0, 11), body + Vector2(28 + stretch, 4), body + Vector2(0, 14), body + Vector2(-30, 10)], skin_l, ow, false)
	for i in 3:
		var rx: float = -6.0 + i * 9.0
		ci.draw_line(body + Vector2(rx, -2), body + Vector2(rx + 3, 8), skin.darkened(0.35), 1.2)
	ci.draw_polyline(PackedVector2Array([body + Vector2(-22, -8), body + Vector2(-8, -4), body + Vector2(4, -10), body + Vector2(18, -5)]), vein, 1.6)
	# kolce wzdłuż grzbietu
	for i in 6:
		var sx: float = -24.0 + i * 10.0
		poly(ci, [body + Vector2(sx - 4, -14), body + Vector2(sx + 1, -26 - (i % 2) * 5), body + Vector2(sx + 5, -14)], spike if i % 2 == 0 else tint(Pal.r("blood", 5), fl), ow * 0.8)
	# głowa: kufa, szczęka z kłami, uszy, oczy
	var hd := body + Vector2(34 + stretch, -9)
	poly(ci, [hd + Vector2(-10, -9), hd + Vector2(6, -12), hd + Vector2(30, -3), hd + Vector2(8, 0), hd + Vector2(-10, 8)], skin, ow)
	poly(ci, [hd + Vector2(8, 0), hd + Vector2(28, 0 + jaw * 0.4), hd + Vector2(26, 6 + jaw), hd + Vector2(2, 9 + jaw * 0.6), hd + Vector2(-8, 8)], skin.darkened(0.2), ow)
	poly(ci, [hd + Vector2(14, 1), hd + Vector2(17, 7 + jaw * 0.6), hd + Vector2(19, 1)], Pal.r("bone", 5), ow * 0.5, false)
	poly(ci, [hd + Vector2(24, 1), hd + Vector2(26, 7 + jaw * 0.8), hd + Vector2(28, 1)], Pal.r("bone", 5), ow * 0.5, false)
	poly(ci, [hd + Vector2(-6, -9), hd + Vector2(-9, -24), hd + Vector2(2, -12)], skin.darkened(0.2), ow)
	disc(ci, hd + Vector2(6, -6), 3.0, 2.6, Pal.r("glow", 3), ow * 0.6)
	if jaw > 0.0:
		ci.draw_rect(Rect2(hd.x + 6, hd.y + 1, 18, 2 + jaw * 0.5), Pal.r("blood", 3))

# ------------------------------------------------------------------ ZWIERZOCZŁEK

static func beastman(ci: CanvasItem, a, t: float, po: Dictionary) -> void:
	var fl: float = a.flash
	var ow := 1.4
	var fur := tint(Pal.r("fur", 2), fl)
	var fur_d := tint(Pal.r("fur", 0), fl)
	var fur_l := tint(Pal.r("fur", 4), fl)
	var leather := tint(Pal.r("wood", 3), fl)
	var iron := tint(Pal.r("steel", 3), fl)
	var moving: bool = a.state == Actor.State.MOVE
	var w: float = sin(t * 8.0) if moving else 0.0
	var bob: float = absf(sin(t * 8.0)) * 2.0 if moving else sin(t * 2.0) * 1.0
	var lean: float = float(po["lean"]) + 0.08
	var hip := Vector2(0, -44 + bob * 0.5 + float(po["crouch"]))
	var sh := hip + Vector2(lean * 44.0, -46)
	var head := sh + Vector2(8, -17)
	# nogi z kopytami
	for s in [-1, 1]:
		var ph: float = w * s
		var knee: Vector2 = hip + Vector2(s * 7 + 9 * ph, 16)
		var foot := Vector2(s * 8 + 14 * ph, 0)
		limb(ci, hip + Vector2(s * 5, 2), knee, foot, fur_d if s < 0 else fur, 11.0, ow)
		poly(ci, [foot + Vector2(-5, -5), foot + Vector2(8, -2), foot + Vector2(6, 3), foot + Vector2(-5, 3)], Pal.r("ink", 2), ow, true)
	# przepaska i tors owłosiony
	poly(ci, [hip + Vector2(-15, 0), hip + Vector2(15, 0), hip + Vector2(11, 20), hip + Vector2(0, 14), hip + Vector2(-11, 21)], leather, ow)
	poly(ci, [hip + Vector2(-16, 2), hip + Vector2(16, 2), sh + Vector2(21, 2), sh + Vector2(-21, 2)], fur, ow)
	poly(ci, [hip + Vector2(-6, 2), hip + Vector2(16, 2), sh + Vector2(21, 2), sh + Vector2(4, 2)], fur_l, ow, false)
	fur_edge(ci, [hip + Vector2(-16, 2), hip + Vector2(-19, -14), hip + Vector2(-18, -30), sh + Vector2(-21, 2)], fur_d, ow)
	line(ci, sh + Vector2(-18, 4), hip + Vector2(14, -4), leather, 5.0, ow)                            # bandolier
	line(ci, sh + Vector2(18, 4), hip + Vector2(-14, -4), leather, 5.0, ow)
	disc(ci, (sh + hip) * 0.5 + Vector2(0, -2), 4.0, 4.0, tint(Pal.r("gold", 3), fl), ow * 0.7)       # sprzączka
	line(ci, hip + Vector2(-15, -2), hip + Vector2(15, -2), Pal.r("wood", 1), 5.0, ow)
	# kolczasty naramiennik
	poly(ci, [sh + Vector2(10, 4), sh + Vector2(32, 0), sh + Vector2(34, 12), sh + Vector2(14, 16)], iron, ow)
	poly(ci, [sh + Vector2(20, 0), sh + Vector2(26, -14), sh + Vector2(30, 0)], tint(Pal.r("steel", 5), fl), ow * 0.8)
	# głowa kozła/byka: pysk, rogi, kieł, oko
	poly(ci, [head + Vector2(-11, -9), head + Vector2(8, -13), head + Vector2(26, -2), head + Vector2(26, 8), head + Vector2(6, 12), head + Vector2(-10, 9)], fur, ow)
	poly(ci, [head + Vector2(10, 4), head + Vector2(26, 4), head + Vector2(24, 11), head + Vector2(8, 12)], fur_l, ow, false)
	disc(ci, head + Vector2(25, 3), 3.4, 3.0, Pal.r("ink", 2), ow * 0.6)
	poly(ci, [head + Vector2(17, 9), head + Vector2(21, 19), head + Vector2(22, 9)], Pal.r("bone", 5), ow * 0.6, false)   # kieł
	disc(ci, head + Vector2(10, -4), 3.0, 2.6, Pal.r("fire", 5), ow * 0.6)
	for sgn in [-1, 1]:                                                                                  # dwa rogi z żebrowaniem
		var base := head + Vector2(-2 + sgn * 6, -11)
		var prev := base
		for i in 5:
			var u := float(i + 1) / 5.0
			var pt := base + Vector2(sgn * 10.0 * sin(u * 2.4) - 2.0, -26.0 * u + 12.0 * u * u)
			line(ci, prev, pt, Pal.r("bone", 3 + (i % 2)), 5.0 - u * 3.0, ow * 0.8)
			prev = pt
	# topór (nieforemne ostrze, owinięty trzonek)
	var ang: float = po["ang"]
	var hand := sh + Vector2(10, 12) + Vector2.from_angle(ang) * 14.0
	var dirv := Vector2.from_angle(ang)
	var perp := Vector2(-dirv.y, dirv.x)
	limb(ci, sh + Vector2(12, 4), (sh + hand) * 0.5 + Vector2(0, 6), hand, fur, 9.0, ow)
	line(ci, hand - dirv * 18.0, hand + dirv * 74.0, Pal.r("wood", 5), 5.0, ow)
	for i in 3:
		var q := hand + dirv * (4.0 + i * 8.0)
		ci.draw_line(q - perp * 3.0, q + perp * 3.0, Pal.r("grey", 2), 1.5)                              # owinięcie
	var tip := hand + dirv * 74.0
	poly(ci, [tip - dirv * 4.0, tip - dirv * 8.0 + perp * 22.0, tip + dirv * 12.0 + perp * 18.0, tip + dirv * 6.0 + perp * 3.0, tip + dirv * 12.0 - perp * 10.0, tip - dirv * 10.0 - perp * 8.0], iron, ow)
	ci.draw_line(tip - dirv * 6.0 + perp * 18.0, tip + dirv * 10.0 + perp * 15.0, tint(Pal.r("steel", 6), fl), 1.6)
	limb(ci, sh + Vector2(-16, 6), sh + Vector2(-20, 24), sh + Vector2(-16 - w * 5.0, 38), fur_d, 8.0, ow)

# ------------------------------------------------------------------ CZEMPION CHAOSU

static func champion(ci: CanvasItem, a, t: float, po: Dictionary) -> void:
	var fl: float = a.flash
	var ow := 0.9
	var plate := tint(Pal.r("steel", 0), fl)
	var plate_l := tint(Pal.r("steel", 2), fl)
	var plate_d := tint(Pal.r("ink", 1), fl)
	var trim := tint(Pal.r("blood", 4), fl)
	var pulse: int = 5 + int(2.0 * (0.5 + 0.5 * sin(t * 4.0)))
	var rune := Pal.r("chaos", pulse)
	var moving: bool = a.state == Actor.State.MOVE
	var w: float = sin(t * 6.0) if moving else 0.0
	var bob: float = absf(sin(t * 6.0)) * 1.5 if moving else sin(t * 1.6) * 0.8
	var lean: float = float(po["lean"])
	var hip := Vector2(0, -44 + bob + float(po["crouch"]) * 0.5)
	var sh := hip + Vector2(lean * 46.0, -50)
	var head := sh + Vector2(2, -20)
	# strzępy peleryny z tyłu
	poly(ci, [sh + Vector2(-14, 0), sh + Vector2(-34 - w * 3.0, 38), sh + Vector2(-24, 56), sh + Vector2(-14, 46), sh + Vector2(-6, 60), sh + Vector2(4, 30)], trim, ow)
	poly(ci, [sh + Vector2(-14, 0), sh + Vector2(-22, 30), sh + Vector2(-8, 24)], Pal.r("blood", 2), ow, false)
	# nogi w ciężkich nagolennikach
	for s in [-1, 1]:
		var ph: float = w * s
		var knee: Vector2 = hip + Vector2(s * 8 + 6 * ph, 17)
		var foot := Vector2(s * 9 + 10 * ph, 0)
		limb(ci, hip + Vector2(s * 6, 0), knee, foot, plate if s < 0 else plate_l, 12.0, ow)
		poly(ci, [knee + Vector2(-8, -6), knee + Vector2(9, -5), knee + Vector2(7, 6), knee + Vector2(-7, 6)], plate_l, ow)          # kolano
		poly(ci, [foot + Vector2(-7, -5), foot + Vector2(14, -1), foot + Vector2(14, 3), foot + Vector2(-7, 3)], plate_d, ow)
	# spódnica pancerna i tors
	poly(ci, [hip + Vector2(-18, -2), hip + Vector2(18, -2), hip + Vector2(22, 20), hip + Vector2(8, 16), hip + Vector2(0, 24), hip + Vector2(-9, 16), hip + Vector2(-22, 20)], plate_d, ow)
	poly(ci, [hip + Vector2(-17, 0), hip + Vector2(17, 0), sh + Vector2(24, 2), sh + Vector2(-24, 2)], plate, ow)
	poly(ci, [hip + Vector2(-4, 0), hip + Vector2(17, 0), sh + Vector2(24, 2), sh + Vector2(4, 2)], plate_l, ow, false)
	ci.draw_line(sh + Vector2(-2, 6), hip + Vector2(0, -2), rune, 2.0)                                # runy na napiersiu
	ci.draw_line(sh + Vector2(-9, 12), sh + Vector2(7, 12), rune, 1.6)
	ci.draw_line(sh + Vector2(-6, 20), sh + Vector2(10, 20), rune, 1.6)
	for i in 3:                                                                                          # czaszki przy pasie
		var cx: float = -12.0 + i * 12.0
		disc(ci, hip + Vector2(cx, 4), 3.0, 3.2, Pal.r("bone", 4), ow * 0.8)
	line(ci, hip + Vector2(-18, -1), hip + Vector2(18, -1), trim, 4.0, ow)
	# potężne naramienniki z kolcami
	for s in [-1, 1]:
		var c := sh + Vector2(s * 24, 2)
		poly(ci, [c + Vector2(-12, 6), c + Vector2(-8, -12), c + Vector2(10, -12), c + Vector2(14, 6), c + Vector2(4, 12)], plate_l if s > 0 else plate, ow)
		poly(ci, [c + Vector2(-3, -12), c + Vector2(s * 3, -30), c + Vector2(7, -12)], tint(Pal.r("bone", 3), fl), ow)
	# hełm z rogami i żarzącymi oczami
	poly(ci, [head + Vector2(-13, 8), head + Vector2(-14, -8), head + Vector2(-4, -16), head + Vector2(10, -14), head + Vector2(15, -2), head + Vector2(13, 10), head + Vector2(0, 14)], plate, ow)
	poly(ci, [head + Vector2(2, -12), head + Vector2(15, -2), head + Vector2(13, 10), head + Vector2(2, 14)], plate_l, ow, false)
	ci.draw_rect(Rect2(head.x + 1, head.y - 4, 13, 4), Pal.r("fire", 4 + int(2.0 * (0.5 + 0.5 * sin(t * 7.0)))))
	for sgn in [-1, 1]:
		var base := head + Vector2(sgn * 10 - 2, -12)
		var prev := base
		for i in 5:
			var u := float(i + 1) / 5.0
			var pt := base + Vector2(sgn * 16.0 * sin(u * 2.2), -30.0 * u + 14.0 * u * u)
			line(ci, prev, pt, Pal.r("bone", 2 + (i % 2)), 6.0 - u * 4.0, ow)
			prev = pt
	# ogromny miecz Chaosu: ząbkowane ostrze z pulsującą runą
	var ang: float = po["ang"]
	var hand := sh + Vector2(14, 12) + Vector2.from_angle(ang) * 16.0
	var dirv := Vector2.from_angle(ang)
	var perp := Vector2(-dirv.y, dirv.x)
	limb(ci, sh + Vector2(16, 2), (sh + hand) * 0.5 + Vector2(0, 8), hand, plate_l, 12.0, ow)
	line(ci, hand - dirv * 14.0, hand + dirv * 12.0, Pal.r("wood", 2), 6.0, ow)
	line(ci, hand + dirv * 12.0 - perp * 16.0, hand + dirv * 12.0 + perp * 16.0, tint(Pal.r("ember", 1), fl), 6.0, ow)
	var tip := hand + dirv * 118.0
	var bl: Array = [hand + dirv * 14.0 + perp * 7.0]
	for i in 5:
		var u := 0.25 + i * 0.16
		bl.append(hand + dirv * (14.0 + 104.0 * u) + perp * (9.0 - u * 3.0 + (4.0 if i % 2 == 0 else 0.0)))
	bl.append(tip)
	bl.append(hand + dirv * 14.0 - perp * 7.0)
	poly(ci, bl, tint(Pal.r("steel", 4), fl), ow)
	ci.draw_line(hand + dirv * 20.0, tip - dirv * 8.0, rune, 2.0)
	limb(ci, sh + Vector2(-22, 4), sh + Vector2(-26, 26), sh + Vector2(-20 - w * 6.0, 44), plate, 12.0, ow)
	# unoszące się iskry skażenia
	for i in 4:
		var u: float = fmod(t * 0.7 + i * 0.25, 1.0)
		ci.draw_rect(Rect2(sh.x - 40 + i * 24, sh.y - 20 - u * 60.0, 3, 3), Pal.r("chaos", 6) if i % 2 == 0 else Pal.r("glow", 2))
