class_name TavernGame
extends Node2D
## Prolog (Etap 0): karczma w Hufduhofie. Gramy pijakiem Borubarem, który łapie kufle zrzucane z balkonu przez
## karczmarza (klasyczne "łapanie jajek" w scenerii Warhammer Fantasy). Po złapaniu GOAL (50) kufli drzwi wylatują
## z zawiasów, na scenę wskakują szczuroludzie, a Ivo (jeden z gości pod ścianą) rusza do walki => sygnał finished.
##
## Cała gra jest rysowana w stałych współrzędnych świata 1280x720 i skalowana do ekranu z czarnymi pasami.
## Logika (step) jest oddzielona od wyglądu, żeby dało się ją testować bez renderowania.
## Sterowanie: A/D, strzałki, joystick (Controls.get_move) albo dotyk/mysz - Borubar biegnie pod palec.

signal finished(skipped: bool)

const S := 4.0 / 3.0                    # jednostek świata na piksel grafiki
const WORLD := Vector2(1280, 720)
const ART := "res://assets/minigame/"
const GOAL := 50
const GOLD_VALUE := 3                   # złoty kufel Bugmana liczy się za 3
const FLOOR_Y := 660.0                  # stopy Borubara / podłoga, o którą rozbijają się kufle
const CATCH_Y := 482.0                  # linia piany w wielkim kuflu Borubara
const CATCH_HALF := 54.0
const BORU_MIN := 90.0
const BORU_MAX := 1190.0
const BORU_SPEED := 640.0
const BORU_ACCEL := 4200.0
const STUN_TIME := 0.75
const KEEPER_Y := 168.0                 # stopy karczmarza na balkonie
const MUG_START_Y := 196.0
const DOOR_POS := Vector2(640, 524)     # środek progu drzwi (świat)
const CUT_DOOR := 0.6                   # kiedy wylatują drzwi
const CUT_FADE := 3.6
const CUT_END := 4.4

enum Phase { PLAY, CUTSCENE, DONE }

var goal: int = GOAL
var phase: int = Phase.PLAY
var caught: int = 0
var missed: int = 0
var boru_x: float = 640.0
var boru_vx: float = 0.0
var stun: float = 0.0
var mugs: Array = []                    # { x, y, vy, gold, rot, spin }
var splashes: Array = []                # { x, t }
var pops: Array = []                    # { x, y, t, text, col }
var keeper_x: float = 640.0
var keeper_to: float = 900.0
var keeper_bounce: float = 0.0
var tank_pop: float = 0.0
var spawn_t: float = 1.4
var spawn_count: int = 0
var t: float = 0.0
var cut_t: float = 0.0
var door_open: bool = false
var shake: float = 0.0
var auto_step: bool = true
var input_override = null               # null albo float -1..1 (testy)
var pointer_x: float = -1.0
var rng := RandomNumberGenerator.new()

# elementy wizualne
var bg: Sprite2D
var door_spr: Sprite2D
var boru: Sprite2D
var tank: Sprite2D
var keeper: Sprite2D
var guests: Array = []                  # { spr, x, y, away }
var ivo: Sprite2D
var ivo_pos: Vector2 = Vector2(900, 562)
var ivo_tex: Dictionary = {}
var rats: Array = []                    # { actor, t0, from, to, dur, landed }
var shadows: DrawLayer
var fx: DrawLayer
var hud: CanvasLayer
var count_label: Label
var miss_label: Label
var hint_label: Label
var bar_fill: ColorRect
var bar_back: ColorRect
var fade: ColorRect
var origin: Vector2 = Vector2.ZERO
var zoom: float = 1.0
var tex: Dictionary = {}

class DrawLayer extends Node2D:
	var cb: Callable
	func _draw() -> void:
		if cb.is_valid():
			cb.call(self)

# ------------------------------------------------------------------ logika

func progress() -> float:
	return clampf(float(caught) / float(maxi(goal, 1)), 0.0, 1.0)

func fall_speed() -> float:
	return lerpf(300.0, 540.0, progress())

func spawn_interval() -> float:
	return lerpf(1.25, 0.55, progress())

func keeper_speed() -> float:
	return lerpf(190.0, 400.0, progress())

## Zrzuca kufel z zadanej pozycji (karczmarz robi to sam; testy też).
func drop_mug(x: float, gold: bool = false, speed: float = -1.0) -> void:
	mugs.append({
		"x": x, "y": MUG_START_Y, "vy": speed if speed > 0.0 else fall_speed(),
		"gold": gold, "rot": 0.0, "spin": rng.randf_range(-2.5, 2.5),
	})
	spawn_count += 1
	keeper_bounce = 1.0

func move_axis() -> float:
	if input_override != null:
		return clampf(float(input_override), -1.0, 1.0)
	var ax: float = Controls.get_move().x
	if pointer_x >= 0.0:
		var d := pointer_x - boru_x
		ax = clampf(d / 36.0, -1.0, 1.0) if absf(d) > 6.0 else 0.0
	return clampf(ax, -1.0, 1.0)

func step(delta: float) -> void:
	t += delta
	if tank_pop > 0.0:
		tank_pop = maxf(0.0, tank_pop - delta * 4.0)
	keeper_bounce = maxf(0.0, keeper_bounce - delta * 5.0)
	shake = maxf(0.0, shake - delta * 1.4)
	for p in pops:
		p["t"] += delta
	pops = pops.filter(func(p): return p["t"] < 0.8)
	for s in splashes:
		s["t"] += delta
	splashes = splashes.filter(func(s): return s["t"] < 1.6)
	match phase:
		Phase.PLAY:
			_step_play(delta)
		Phase.CUTSCENE:
			_step_cut(delta)

func _step_play(delta: float) -> void:
	stun = maxf(0.0, stun - delta)
	var target_vx: float = move_axis() * BORU_SPEED if stun <= 0.0 else 0.0
	boru_vx = move_toward(boru_vx, target_vx, BORU_ACCEL * delta)
	boru_x = clampf(boru_x + boru_vx * delta, BORU_MIN, BORU_MAX)
	if absf(boru_x - BORU_MIN) < 0.01 or absf(boru_x - BORU_MAX) < 0.01:
		boru_vx = 0.0
	# karczmarz chodzi po balkonie i zrzuca kufle
	var dx := keeper_to - keeper_x
	var stp := keeper_speed() * delta
	if absf(dx) <= stp:
		keeper_x = keeper_to
		keeper_to = rng.randf_range(150.0, 1130.0)
	else:
		keeper_x += signf(dx) * stp
	spawn_t -= delta
	if spawn_t <= 0.0:
		var gold: bool = spawn_count > 0 and spawn_count % 9 == 8
		drop_mug(keeper_x, gold)
		spawn_t = spawn_interval() * rng.randf_range(0.85, 1.15)
	# kufle
	var keep: Array = []
	for m in mugs:
		var prev: float = m["y"]
		m["y"] += float(m["vy"]) * delta
		m["rot"] += float(m["spin"]) * delta
		if stun <= 0.0 and prev < CATCH_Y and m["y"] >= CATCH_Y and absf(float(m["x"]) - boru_x) <= CATCH_HALF:
			_on_catch(m)
			continue
		if m["y"] >= FLOOR_Y:
			_on_smash(m)
			continue
		keep.append(m)
	mugs = keep
	if phase == Phase.PLAY and caught >= goal:
		start_cutscene()

func _on_catch(m: Dictionary) -> void:
	var v: int = GOLD_VALUE if bool(m["gold"]) else 1
	caught += v
	tank_pop = 1.0
	pops.append({ "x": boru_x, "y": CATCH_Y - 40.0, "t": 0.0, "text": "+%d" % v, "col": Color(1.0, 0.85, 0.3) if v > 1 else Color(1, 1, 1) })
	Sfx.play("pickup", 1.0 + minf(0.4, progress() * 0.4))
	_update_hud()

func _on_smash(m: Dictionary) -> void:
	missed += 1
	splashes.append({ "x": m["x"], "t": 0.0 })
	if absf(float(m["x"]) - boru_x) < 90.0:
		stun = STUN_TIME                 # prysnął po nogach: Borubar się potyka
	Sfx.play("barrel_break", 1.2)
	_update_hud()

func start_cutscene() -> void:
	if phase != Phase.PLAY:
		return
	phase = Phase.CUTSCENE
	cut_t = 0.0
	mugs.clear()
	stun = 0.0
	boru_vx = 0.0
	_update_hud()
	_build_rats()

func skip() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	finished.emit(true)

func _step_cut(delta: float) -> void:
	cut_t += delta
	if not door_open and cut_t >= CUT_DOOR:
		door_open = true
		shake = 1.0
		Sfx.play("slam")
		if door_spr != null:
			door_spr.visible = true
	# szczury
	for r in rats:
		var a: Actor = r["actor"]
		var u: float = (cut_t - float(r["t0"])) / float(r["dur"])
		if u < 0.0:
			a.visible = false
			continue
		a.visible = true
		if u < 1.0:
			var from: Vector2 = r["from"]
			var to: Vector2 = r["to"]
			var arc: float = 150.0 * 4.0 * u * (1.0 - u)
			a.position = from.lerp(to, u) - Vector2(0, arc)
			a.facing = 1 if to.x >= from.x else -1
			a.state = Actor.State.MOVE
		else:
			if not bool(r["landed"]):
				r["landed"] = true
				Sfx.play("skaven_squeak", randf_range(0.9, 1.2))
			a.state = Actor.State.MOVE
			var dir: float = signf(ivo_pos.x - a.position.x)
			if absf(ivo_pos.x - a.position.x) > 150.0:
				a.position.x += dir * 90.0 * delta
				a.facing = int(dir) if dir != 0.0 else a.facing
			else:
				a.state = Actor.State.IDLE
	# goście cofają się pod ściany
	if door_open:
		var k: float = clampf((cut_t - CUT_DOOR) / 0.7, 0.0, 1.0)
		for g in guests:
			g["away"] = k * (22.0 if float(g["x"]) > DOOR_POS.x else -22.0)
	# Ivo rusza do walki
	if cut_t > 1.3:
		var goal_p := Vector2(790, 600)
		ivo_pos = ivo_pos.move_toward(goal_p, 210.0 * delta)
	if cut_t >= CUT_END and phase == Phase.CUTSCENE:
		phase = Phase.DONE
		finished.emit(false)

func _build_rats() -> void:
	var spots: Array = [Vector2(250, 610), Vector2(380, 640), Vector2(470, 600), Vector2(560, 645), Vector2(700, 650),
		Vector2(830, 620), Vector2(960, 648), Vector2(1080, 612), Vector2(330, 585), Vector2(1000, 585)]
	for i in spots.size():
		var a := Actor.new()
		a.id = "skaven"
		a.team = 1
		a.position = DOOR_POS
		a.visible = false
		var v := ActorVisual.new()
		v.setup(a, "skaven")
		a.add_child(v)
		a.visual = v
		a.scale = Vector2(1.1, 1.1)
		a.z_index = 1
		add_child(a)
		var from := DOOR_POS + Vector2(rng.randf_range(-30, 30), 0)
		rats.append({ "actor": a, "t0": CUT_DOOR + 0.25 + i * 0.16, "from": from, "to": spots[i], "dur": rng.randf_range(0.55, 0.85), "landed": false })

# ------------------------------------------------------------------ budowa sceny

func tx(name: String) -> Texture2D:
	if not tex.has(name):
		tex[name] = load(ART + name + ".png")
	return tex[name]

func _sprite(name: String, pos: Vector2, flip: bool = false) -> Sprite2D:
	var t2: Texture2D = tx(name)
	var s := Sprite2D.new()
	s.texture = t2
	s.centered = false
	s.offset = Vector2(-floorf(t2.get_width() / 2.0), -t2.get_height())
	s.scale = Vector2(-S if flip else S, S)
	s.position = pos
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(s)
	return s

func _ready() -> void:
	rng.randomize()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	keeper_x = 520.0
	keeper_to = 900.0
	_build_scene()
	_build_hud()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_update_hud()

func _build_scene() -> void:
	bg = Sprite2D.new()
	bg.texture = tx("tavern_bg")
	bg.centered = false
	bg.scale = Vector2(S, S)
	add_child(bg)
	door_spr = _sprite("door_open", Vector2(DOOR_POS.x, DOOR_POS.y + 2.0))
	door_spr.visible = false
	shadows = DrawLayer.new()
	shadows.cb = _draw_shadows
	add_child(shadows)
	# goście pod ścianami (lewa strona, okolice drzwi, prawa strona) + Ivo wśród nich
	var placing: Array = [
		[90, 560, 1], [185, 552, 3], [285, 564, 2], [385, 552, 6],
		[830, 552, 4], [985, 550, 5], [1080, 562, 3], [1175, 552, 2],
	]
	var i := 0
	for p in placing:
		var spr := _sprite("guest_%d" % int(p[2]), Vector2(p[0], p[1]), i % 2 == 1)
		guests.append({ "spr": spr, "x": float(p[0]), "y": float(p[1]), "away": 0.0, "ph": float(i) * 1.7 })
		i += 1
	for d in ["south", "west", "south-west"]:
		ivo_tex[d] = load("res://assets/characters/ivo/poses/ivo_%s.png" % d)
	ivo = Sprite2D.new()
	ivo.texture = ivo_tex["south"]
	ivo.centered = false
	ivo.offset = -Vector2(48, 126)
	ivo.scale = Vector2(S, S)
	ivo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ivo.position = ivo_pos
	add_child(ivo)
	keeper = _sprite("innkeeper", Vector2(keeper_x, KEEPER_Y))
	var rail := Sprite2D.new()
	rail.texture = tx("balcony_rail")
	rail.centered = false
	rail.scale = Vector2(S, S)
	rail.position = Vector2(0, 152)
	add_child(rail)
	boru = _sprite("borubar", Vector2(boru_x, FLOOR_Y))
	tank = Sprite2D.new()
	tank.texture = tx("tankard_big")
	tank.centered = false
	tank.offset = Vector2(-29, -56)
	tank.position = Vector2(0, -90)
	tank.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boru.add_child(tank)
	fx = DrawLayer.new()
	fx.cb = _draw_fx
	fx.z_index = 2
	add_child(fx)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	var back := ColorRect.new()
	back.color = Color(0, 0, 0)
	back.z_index = -1
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var under := CanvasLayer.new()
	under.layer = -5
	add_child(under)
	under.add_child(back)
	count_label = UI.make_label("", 40, Color(1.0, 0.9, 0.55))
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	count_label.position = Vector2(24, 14)
	count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	count_label.add_theme_constant_override("outline_size", 8)
	hud.add_child(count_label)
	miss_label = UI.make_label("", 24, Color(0.85, 0.6, 0.45))
	miss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	miss_label.position = Vector2(26, 62)
	miss_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	miss_label.add_theme_constant_override("outline_size", 6)
	hud.add_child(miss_label)
	bar_back = ColorRect.new()
	bar_back.color = Color(0, 0, 0, 0.6)
	bar_back.position = Vector2(26, 100)
	bar_back.size = Vector2(300, 14)
	bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bar_back)
	bar_fill = ColorRect.new()
	bar_fill.color = Color(0.93, 0.62, 0.16)
	bar_fill.position = Vector2(28, 102)
	bar_fill.size = Vector2(0, 10)
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bar_fill)
	hint_label = UI.make_label("Łap kufle Borubarem!  A / D, strzałki albo przeciągnij palcem", 28, Color(0.95, 0.9, 0.75))
	hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	hint_label.add_theme_constant_override("outline_size", 8)
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.position.y -= 26
	hud.add_child(hint_label)
	var skip_btn := UI.make_button("Pomiń prolog", skip, 220.0)
	skip_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip_btn.position.x -= 244
	skip_btn.position.y += 14
	hud.add_child(skip_btn)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fade)

func _update_hud() -> void:
	if count_label == null:
		return
	count_label.text = "Kufle: %d / %d" % [mini(caught, goal), goal]
	miss_label.text = "Rozlane: %d" % missed
	bar_fill.size.x = 296.0 * progress()

func _layout() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	zoom = minf(vs.x / WORLD.x, vs.y / WORLD.y)
	origin = (vs - WORLD * zoom) * 0.5
	scale = Vector2(zoom, zoom)
	position = origin

# ------------------------------------------------------------------ pętla i wejście

func _process(delta: float) -> void:
	if auto_step:
		step(minf(delta, 0.05))
	_sync_visuals()
	if hint_label != null:
		hint_label.modulate.a = clampf(1.0 - (t - 6.0) / 1.5, 0.0, 1.0) if phase == Phase.PLAY else 0.0
	if fade != null and phase != Phase.PLAY:
		fade.color.a = clampf((cut_t - CUT_FADE) / (CUT_END - CUT_FADE), 0.0, 1.0)
	position = origin + Vector2(sin(t * 61.0), cos(t * 47.0)) * 7.0 * shake * zoom

func _sync_visuals() -> void:
	if boru == null:
		return
	var swayv: float = sin(t * 2.3) * 0.035 + clampf(boru_vx / BORU_SPEED, -1.0, 1.0) * 0.07
	if stun > 0.0:
		swayv = sin(t * 14.0) * 0.12
	boru.position = Vector2(boru_x, FLOOR_Y)
	boru.rotation = swayv
	var sq: float = 1.0 + sin(t * 4.6) * 0.012
	boru.scale = Vector2(S * (1.0 / sq), S * sq)
	boru.texture = tx("borubar_dizzy") if stun > 0.0 or phase == Phase.CUTSCENE else tx("borubar")
	var pop: float = 1.0 + tank_pop * 0.16
	tank.scale = Vector2(pop, 1.0 / pop if tank_pop > 0.0 else 1.0)
	tank.position.y = -90.0 + tank_pop * 4.0
	keeper.position = Vector2(keeper_x, KEEPER_Y)
	keeper.scale = Vector2(-S if keeper_to < keeper_x else S, S * (1.0 + keeper_bounce * 0.06))
	for g in guests:
		var spr: Sprite2D = g["spr"]
		var bob: float = sin(t * 2.0 + float(g["ph"])) * 0.012
		spr.position = Vector2(float(g["x"]) + float(g["away"]), float(g["y"]))
		var sgn: float = signf(spr.scale.x)
		spr.scale = Vector2(S * sgn, S * (1.0 + bob))
	ivo.position = ivo_pos
	if phase == Phase.CUTSCENE and cut_t > 1.3:
		ivo.texture = ivo_tex["west"]
	elif phase == Phase.CUTSCENE and cut_t > 0.6:
		ivo.texture = ivo_tex["south-west"]
	else:
		ivo.texture = ivo_tex["south"]
	if shadows != null:
		shadows.queue_redraw()
	if fx != null:
		fx.queue_redraw()

func _draw_shadows(c: Node2D) -> void:
	for g in guests:
		_shadow(c, Vector2(float(g["x"]) + float(g["away"]), float(g["y"])), 26.0)
	_shadow(c, ivo_pos, 30.0)
	_shadow(c, Vector2(boru_x, FLOOR_Y), 44.0)

func _shadow(c: Node2D, p: Vector2, rx: float) -> void:
	var pts := PackedVector2Array()
	for i in 18:
		var ang := TAU * i / 18.0
		pts.append(p + Vector2(cos(ang) * rx, sin(ang) * rx * 0.28))
	c.draw_colored_polygon(pts, Color(0, 0, 0, 0.35))

func _draw_fx(c: Node2D) -> void:
	for s in splashes:
		var st: Texture2D = tx("splash")
		var a: float = clampf(1.0 - (float(s["t"]) - 0.9) / 0.7, 0.0, 1.0)
		c.draw_set_transform(Vector2(float(s["x"]), FLOOR_Y + 8.0), 0.0, Vector2(S * (0.6 + minf(1.0, float(s["t"]) * 6.0) * 0.5), S))
		c.draw_texture(st, Vector2(-st.get_width() / 2.0, -st.get_height()), Color(1, 1, 1, a))
	for m in mugs:
		var mt: Texture2D = tx("mug_gold" if bool(m["gold"]) else "mug")
		c.draw_set_transform(Vector2(float(m["x"]), float(m["y"])), float(m["rot"]), Vector2(S, S))
		c.draw_texture(mt, -Vector2(mt.get_width(), mt.get_height()) * 0.5)
	if stun > 0.0:
		var stt: Texture2D = tx("stars")
		c.draw_set_transform(Vector2(boru_x, FLOOR_Y - 190.0), sin(t * 8.0) * 0.12, Vector2(S, S))
		c.draw_texture(stt, -Vector2(stt.get_width(), stt.get_height()) * 0.5)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var font := ThemeDB.fallback_font
	for p in pops:
		var k: float = float(p["t"]) / 0.8
		var col: Color = p["col"]
		col.a = 1.0 - k
		c.draw_string_outline(font, Vector2(float(p["x"]) - 24.0, float(p["y"]) - k * 60.0), str(p["text"]), HORIZONTAL_ALIGNMENT_CENTER, 48, 40, 8, Color(0, 0, 0, col.a))
		c.draw_string(font, Vector2(float(p["x"]) - 24.0, float(p["y"]) - k * 60.0), str(p["text"]), HORIZONTAL_ALIGNMENT_CENTER, 48, 40, col)
	if phase == Phase.CUTSCENE and cut_t >= CUT_DOOR and cut_t < CUT_DOOR + 1.2:
		var k2: float = (cut_t - CUT_DOOR) / 1.2
		var cc := Color(1.0, 0.3, 0.15, 1.0 - k2)
		c.draw_string_outline(font, Vector2(420, 330 - k2 * 40.0), "BUM!", HORIZONTAL_ALIGNMENT_CENTER, 440, 120, 14, Color(0, 0, 0, cc.a))
		c.draw_string(font, Vector2(420, 330 - k2 * 40.0), "BUM!", HORIZONTAL_ALIGNMENT_CENTER, 440, 120, cc)

func _to_world_x(p: Vector2) -> float:
	return (p.x - origin.x) / maxf(zoom, 0.001)

func _input(event: InputEvent) -> void:
	if phase != Phase.PLAY:
		return
	if event is InputEventScreenTouch:
		pointer_x = _to_world_x(event.position) if event.pressed else -1.0
	elif event is InputEventScreenDrag:
		pointer_x = _to_world_x(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer_x = _to_world_x(event.position) if event.pressed else -1.0
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		pointer_x = _to_world_x(event.position)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		skip()
