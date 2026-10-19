class_name ActorVisual
extends Node2D
## Warstwa wizualna aktora, całkowicie oddzielona od mechaniki. Kolejność wyboru grafiki:
##  1. animacje z assets/characters/<id>/ (CharacterSheet) - patrz README w tym folderze,
##  2. Ivo: 8 póz kierunkowych (IvoView), wrogowie: tymczasowa grafika proceduralna (MonsterArt).
## Brakująca animacja = zapas, więc podmieniasz grafikę po jednej animacji.

const STYLES := {
	"ivo":            { "scale": 1.2,  "cloth": Color(0.74, 0.08, 0.10), "cloth2": Color(0.09, 0.08, 0.08), "skin": Color(0.80, 0.60, 0.46), "blade": Color(0.72, 0.74, 0.78), "wlen": 118.0 },
	"skaven":         { "scale": 1.0, "cloth": Color(0.36, 0.30, 0.24), "cloth2": Color(0.22, 0.18, 0.14), "skin": Color(0.45, 0.38, 0.32), "blade": Color(0.50, 0.42, 0.30), "wlen": 40.0 },
	"chaos_hound":    { "scale": 1.1, "cloth": Color(0.20, 0.16, 0.18), "cloth2": Color(0.42, 0.10, 0.16), "skin": Color(0.26, 0.20, 0.20), "blade": Color(0.8, 0.8, 0.8),   "wlen": 0.0 },
	"beastman":       { "scale": 1.4, "cloth": Color(0.38, 0.28, 0.20), "cloth2": Color(0.24, 0.18, 0.12), "skin": Color(0.44, 0.33, 0.24), "blade": Color(0.55, 0.57, 0.60), "wlen": 78.0 },
	"chaos_champion": { "scale": 2.1, "cloth": Color(0.13, 0.12, 0.14), "cloth2": Color(0.55, 0.06, 0.08), "skin": Color(0.30, 0.26, 0.28), "blade": Color(0.40, 0.42, 0.48), "wlen": 105.0 },
}

var actor
var kind: String = "ivo"
var sheet_view: SheetView = null
var ivo_view: IvoView = null
var t_anim: float = 0.0

func setup(a, k: String) -> void:
	actor = a
	kind = k
	if k == "ivo" and IvoView.available():
		ivo_view = IvoView.new()
		ivo_view.setup(a)
		add_child(ivo_view)
		return
	var sh := CharacterSheet.get_sheet(k)
	if sh != null:
		sheet_view = SheetView.new()
		sheet_view.setup(a, sh)
		add_child(sheet_view)

func _process(delta: float) -> void:
	t_anim += delta
	if actor == null:
		return
	if ivo_view != null:
		queue_redraw()
		if actor.state == Actor.State.DEAD and actor.team == 1:
			modulate.a = clampf(1.0 - (actor.dead_t - 0.5) / 0.6, 0.0, 1.0)
		return
	queue_redraw()
	# zanikanie po śmierci wroga
	if actor.state == Actor.State.DEAD and actor.team == 1:
		modulate.a = clampf(1.0 - (actor.dead_t - 0.5) / 0.6, 0.0, 1.0)

# ------------------------------------------------------------------ rysowanie

func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var ang := TAU * i / 20.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	draw_colored_polygon(pts, col)

func _tint(c: Color) -> Color:
	if actor.flash > 0.0:
		return c.lerp(Color(1, 1, 1), 0.55)
	return c

func _draw() -> void:
	if actor == null:
		return
	if ivo_view != null:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_ellipse(Vector2(0, 2), 38.0, 9.0, Pal.r("ink", 1))
		return
	var a = actor
	var st: Dictionary = STYLES[kind]
	var sc: float = st["scale"]
	var f: int = a.facing
	# cień
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_ellipse(Vector2(0, 2), 34.0 * sc, 9.0 * sc, Color(0, 0, 0, 0.35))
	# znacznik telegrafu ataku wroga (obszar trafienia na ziemi)
	if a.team == 1 and a.state == Actor.State.WINDUP:
		_draw_telegraph(a, sc)
	if sheet_view != null and sheet_view.active:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_hp_bar(a, sc)
		return
	var ghost: bool = a.state == Actor.State.DODGE
	if ghost:
		modulate.a = 0.55
	elif a.state != Actor.State.DEAD:
		modulate.a = 1.0
	var rot := 0.0
	var off := Vector2.ZERO
	if a.state == Actor.State.DEAD:
		rot = (PI * 0.5) * clampf(a.dead_t / 0.25, 0.0, 1.0) * -float(f)
		off = Vector2(-f * 20.0 * clampf(a.dead_t / 0.25, 0.0, 1.0), 0)
	draw_set_transform(off, rot, Vector2(f * sc, sc))
	match kind:
		"chaos_hound":
			MonsterArt.hound(self, a, t_anim, {})
		"skaven":
			MonsterArt.skaven(self, a, t_anim, _poses(a, st))
		"beastman":
			MonsterArt.beastman(self, a, t_anim, _poses(a, st))
		"chaos_champion":
			MonsterArt.champion(self, a, t_anim, _poses(a, st))
		_:
			_draw_biped(a, st)          # awaryjnie: Ivo bez sprite'ów
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_hp_bar(a, sc)

func _draw_telegraph(a, sc: float) -> void:
	var windup: float = a.windup_time()
	if windup < 0.25:
		return
	var p: float = clampf(a.state_t / windup, 0.0, 1.0)
	var r: Vector2 = a.hitbox_x_range()
	var depth: float = float(a.attack.get("depth", 36.0)) * 0.42
	var x0: float = r.x - a.position.x
	var x1: float = r.y - a.position.x
	if bool(a.attack.get("track", false)):
		x1 = x0 + (x1 - x0) + a.facing * float(a.attack.get("lunge", 0.0)) * float(a.attack["active"])
		if a.facing < 0:
			var t0: float = x0
			x0 = x1
			x1 = t0
		x0 = minf(x0, a.facing * -4.0)
	var col := Color(0.9, 0.12, 0.08, 0.10 + 0.30 * p)
	var pts := PackedVector2Array([Vector2(x0, -depth), Vector2(x1, -depth), Vector2(x1, depth), Vector2(x0, depth)])
	draw_colored_polygon(pts, col)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(1, 0.3, 0.2, 0.6), 2.0)
	# wykrzyknik nad głową
	if int(a.state_t * 14.0) % 2 == 0 or p > 0.7:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-10, -135.0 * sc - 10.0), "!", HORIZONTAL_ALIGNMENT_CENTER, 30, int(30 * maxf(sc, 1.0)), Color(1, 0.25, 0.15))

func _draw_hp_bar(a, sc: float) -> void:
	if a.team != 1 or a is Boss or a.state == Actor.State.DEAD or a.hp >= a.max_hp:
		return
	var w: float = 54.0
	var y: float = -125.0 * sc - 12.0
	draw_rect(Rect2(-w * 0.5, y, w, 6), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-w * 0.5 + 1, y + 1, (w - 2) * a.hp / a.max_hp, 4), Color(0.75, 0.1, 0.1))

func _poses(a, st: Dictionary) -> Dictionary:
	var rest: float = -2.15
	var ang: float = rest
	var lean: float = 0.0
	var crouch: float = 0.0
	var swoosh_from: float = 0.0
	var swoosh_to: float = 0.0
	var swoosh: bool = false
	var arms_up: bool = false
	match a.state:
		Actor.State.WINDUP:
			var p: float = clampf(a.state_t / maxf(a.windup_time(), 0.01), 0.0, 1.0)
			var wind: float = -3.1 if a.attack_name in ["heavy", "overhead", "slam", "chop"] else -2.6
			ang = lerpf(rest, wind, p)
			lean = -0.18 * p
			crouch = 4.0 * p
		Actor.State.ACTIVE:
			var p2: float = clampf(a.state_t / maxf(float(a.attack["active"]), 0.01), 0.0, 1.0)
			var wind2: float = -3.1 if a.attack_name in ["heavy", "overhead", "slam", "chop"] else -2.6
			var end: float = 1.0 if a.attack_name != "backhand" else 0.2
			if a.attack_name in ["sweep", "wide"]:
				ang = rest + TAU * p2
				swoosh_from = rest
			else:
				ang = lerpf(wind2, end, p2)
				swoosh_from = wind2
			swoosh_to = ang
			swoosh = true
			lean = 0.22
		Actor.State.RECOVER:
			var p3: float = clampf(a.state_t / maxf(float(a.attack["recover"]), 0.01), 0.0, 1.0)
			ang = lerpf(0.9, rest, p3)
			lean = 0.15 * (1.0 - p3)
		Actor.State.HURT:
			lean = -0.4
			ang = -1.2
		Actor.State.DODGE:
			lean = 0.5
			ang = -0.4
		Actor.State.VICTORY:
			arms_up = true
			ang = -1.57 + sin(t_anim * 3.0) * 0.12
		Actor.State.DEAD:
			ang = 0.4
	return { "ang": ang, "lean": lean, "crouch": crouch, "swoosh": swoosh, "sf": swoosh_from, "st": swoosh_to, "arms_up": arms_up }

func _draw_biped(a, st: Dictionary) -> void:
	var moving: bool = a.state == Actor.State.MOVE
	var walk: float = sin(t_anim * 11.0) if moving else 0.0
	var bob: float = absf(sin(t_anim * 11.0)) * 3.0 if moving else sin(t_anim * 2.4) * 1.4
	var po: Dictionary = _poses(a, st)
	var lean: float = po["lean"]
	if kind == "skaven":
		lean += 0.28
	var cloth: Color = _tint(st["cloth"])
	var cloth2: Color = _tint(st["cloth2"])
	var skin: Color = _tint(st["skin"])
	var hip := Vector2(0, -46 + bob * 0.4 + float(po["crouch"]))
	var sh := hip + Vector2(lean * 46.0, -48)
	var head := sh + Vector2(lean * 10.0 + 3, -17)
	# nogi
	var boot := cloth2.darkened(0.2) if kind == "ivo" else cloth2
	var ph := 15.0 * walk
	draw_line(hip + Vector2(-5, 0), Vector2(-9 - ph, 0), boot, 9.0)
	draw_line(hip + Vector2(5, 0), Vector2(9 + ph, 0), boot, 9.0)
	if kind == "ivo":
		# pludry
		_ellipse(hip + Vector2(-6, 10), 12, 14, cloth)
		_ellipse(hip + Vector2(8, 10), 12, 14, cloth)
	# ogon skavena
	if kind == "skaven":
		draw_arc(hip + Vector2(-8, -4), 22, PI * 0.2, PI * 1.1, 10, skin.darkened(0.2), 4.0)
	# tors
	var tors := PackedVector2Array([hip + Vector2(-14, 0), hip + Vector2(14, 0), sh + Vector2(17, 0), sh + Vector2(-17, 0)])
	draw_colored_polygon(tors, cloth)
	if kind == "ivo":
		draw_line(sh + Vector2(-14, 4), hip + Vector2(10, -4), cloth2, 5.0)             # pas na ukos
		draw_line(hip + Vector2(-14, -2), hip + Vector2(14, -2), Color(0.35, 0.22, 0.12), 5.0)
		draw_rect(Rect2(hip.x + 4, hip.y + 2, 10, 14), Color(0.8, 0.1, 0.1))               # tarcza z orłem
		draw_rect(Rect2(hip.x + 4, hip.y + 2, 10, 14), Color(0.8, 0.65, 0.2), false, 1.5)
	elif kind == "beastman":
		draw_line(sh + Vector2(-16, 2), sh + Vector2(16, 2), cloth2, 8.0)
	elif kind == "chaos_champion":
		_ellipse(sh + Vector2(-17, 2), 11, 8, cloth2)        # naramienniki
		_ellipse(sh + Vector2(17, 2), 11, 8, cloth2)
		draw_colored_polygon(PackedVector2Array([sh + Vector2(-12, 0), sh + Vector2(-26, 40), sh + Vector2(-8, 36)]), cloth2.darkened(0.3))  # peleryna
	# głowa
	_draw_head(head, st, skin, cloth, cloth2)
	# ramię i broń
	var ang: float = po["ang"]
	var hand := sh + Vector2(6, 8) + Vector2.from_angle(ang) * 14.0
	if bool(po["arms_up"]):
		hand = sh + Vector2(4, -22)
	draw_line(sh + Vector2(8, 2), hand, cloth if kind != "skaven" else skin, 9.0)
	var wlen: float = st["wlen"]
	var dir := Vector2.from_angle(ang)
	var wbase := hand - dir * 16.0
	var wtip := hand + dir * wlen
	var blade: Color = _tint(st["blade"])
	if kind == "ivo" or kind == "chaos_champion":
		draw_line(wbase, hand + dir * 10.0, Color(0.45, 0.30, 0.15), 6.0)                       # rękojeść
		var perp := Vector2(-dir.y, dir.x)
		draw_line(hand + dir * 10.0 - perp * 12.0, hand + dir * 10.0 + perp * 12.0, Color(0.8, 0.65, 0.2) if kind == "ivo" else Color(0.5, 0.1, 0.1), 5.0)
		draw_line(hand + dir * 12.0, wtip, blade, 7.0)
	elif kind == "beastman":
		draw_line(wbase, wtip, Color(0.35, 0.24, 0.14), 6.0)
		var perp2 := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([wtip, wtip - dir * 26.0 + perp2 * 24.0, wtip - dir * 26.0 - perp2 * 2.0]), blade)
	else:
		draw_line(wbase, wtip, blade, 5.0)
	# smuga cięcia
	if bool(po["swoosh"]):
		var c := sh + Vector2(6, 8)
		var from_a: float = po["sf"]
		var to_a: float = po["st"]
		if absf(to_a - from_a) > 0.05:
			draw_arc(c, wlen * 0.9 + 10.0, from_a, to_a, 28, Color(1, 1, 1, 0.55), 9.0)
			draw_arc(c, wlen * 0.75 + 10.0, from_a, to_a, 28, Color(0.9, 0.2, 0.15, 0.35), 6.0)
	# ręka wolna
	draw_line(sh + Vector2(-9, 2), sh + Vector2(-12 + walk * -6.0, 30), cloth if kind != "skaven" else skin, 8.0)

func _draw_head(h: Vector2, st: Dictionary, skin: Color, cloth: Color, cloth2: Color) -> void:
	match kind:
		"ivo":
			draw_colored_polygon(PackedVector2Array([h + Vector2(-9, 2), h + Vector2(-14, 24), h + Vector2(-6, 22)]), Color(0.50, 0.33, 0.18))   # włosy
			_ellipse(h, 11, 12, skin)
			draw_colored_polygon(PackedVector2Array([h + Vector2(2, 6), h + Vector2(10, 6), h + Vector2(7, 16)]), Color(0.38, 0.26, 0.16))       # broda
			_ellipse(h + Vector2(0, -10), 15, 7, cloth)                                                                                          # beret
			draw_colored_polygon(PackedVector2Array([h + Vector2(-14, -9), h + Vector2(0, -14), h + Vector2(14, -9), h + Vector2(0, -6)]), cloth2)
			draw_circle(h + Vector2(5, -1), 1.6, Color(0.1, 0.1, 0.1))
		"skaven":
			_ellipse(h, 9, 8, skin)
			draw_colored_polygon(PackedVector2Array([h + Vector2(5, -3), h + Vector2(22, 3), h + Vector2(5, 6)]), skin.lightened(0.1))           # pysk
			draw_colored_polygon(PackedVector2Array([h + Vector2(-4, -6), h + Vector2(-6, -18), h + Vector2(2, -8)]), skin.darkened(0.1))        # ucho
			draw_circle(h + Vector2(5, -2), 1.8, Color(0.9, 0.15, 0.1))
		"beastman":
			_ellipse(h, 12, 12, skin)
			draw_colored_polygon(PackedVector2Array([h + Vector2(4, 0), h + Vector2(20, 6), h + Vector2(4, 10)]), skin.darkened(0.1))
			draw_arc(h + Vector2(-6, -8), 12, PI, PI * 1.9, 10, Color(0.85, 0.8, 0.65), 4.0)                                                       # rogi
			draw_arc(h + Vector2(8, -8), 12, PI * 1.1, PI * 2.0, 10, Color(0.85, 0.8, 0.65), 4.0)
			draw_circle(h + Vector2(6, -2), 2.0, Color(0.95, 0.5, 0.1))
		"chaos_champion":
			_ellipse(h, 13, 14, cloth2.darkened(0.5))
			draw_arc(h + Vector2(-8, -10), 16, PI * 0.95, PI * 1.85, 10, Color(0.75, 0.7, 0.6), 5.0)
			draw_arc(h + Vector2(8, -10), 16, PI * 1.15, PI * 2.05, 10, Color(0.75, 0.7, 0.6), 5.0)
			draw_rect(Rect2(h.x + 1, h.y - 3, 10, 3), Color(1.0, 0.25, 0.1))                                                                       # żarzące oczy

func _draw_hound(a, st: Dictionary) -> void:
	var moving: bool = a.state == Actor.State.MOVE
	var gait: float = sin(t_anim * 16.0) if (moving or a.state == Actor.State.ACTIVE) else 0.0
	var crouch: float = 0.0
	var stretch: float = 0.0
	match a.state:
		Actor.State.WINDUP:
			crouch = 10.0 * clampf(a.state_t / maxf(a.windup_time(), 0.01), 0, 1)
		Actor.State.ACTIVE:
			stretch = 10.0
		Actor.State.HURT:
			crouch = 6.0
	var body := Vector2(0, -34 + crouch)
	var skin: Color = _tint(st["skin"])
	var acc: Color = _tint(st["cloth2"])
	for i in 2:
		draw_line(body + Vector2(-20 + i * 6, 0), Vector2(-24 + i * 6 - gait * 10.0, 0), skin.darkened(0.2), 7.0)
		draw_line(body + Vector2(18 + i * 6, 0), Vector2(18 + i * 6 + gait * 10.0, 0), skin.darkened(0.2), 7.0)
	_ellipse(body + Vector2(stretch * 0.3, 0), 30 + stretch, 16, skin)
	for i in 5:   # kolce wzdłuż grzbietu
		var sx: float = -18.0 + i * 9.0
		draw_colored_polygon(PackedVector2Array([body + Vector2(sx - 3, -12), body + Vector2(sx, -24 - (i % 2) * 5), body + Vector2(sx + 3, -12)]), acc)
	var head := body + Vector2(32 + stretch, -6)
	_ellipse(head, 14, 11, skin)
	var jaw: float = 0.0
	if a.state == Actor.State.ACTIVE or a.state == Actor.State.WINDUP:
		jaw = 6.0
	draw_colored_polygon(PackedVector2Array([head + Vector2(8, -4), head + Vector2(28, 0 - jaw * 0.3), head + Vector2(8, 3)]), skin.lightened(0.05))
	draw_colored_polygon(PackedVector2Array([head + Vector2(8, 3), head + Vector2(26, 4 + jaw), head + Vector2(8, 9)]), skin.darkened(0.1))
	draw_circle(head + Vector2(4, -4), 2.2, Color(0.9, 0.2, 0.9))
	draw_colored_polygon(PackedVector2Array([head + Vector2(-4, -8), head + Vector2(-2, -22), head + Vector2(4, -9)]), skin.darkened(0.2))
	draw_line(body + Vector2(-28, -2), body + Vector2(-44, -14 + gait * 4.0), skin, 4.0)
