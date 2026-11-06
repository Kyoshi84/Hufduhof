class_name Fx
extends Node2D
## Efekty wizualne rysowane w kodzie (płaskie kolory z palety, bez gradientów):
##  slash   - łuk cięcia broni (pokazuje faktyczny zasięg i kąt trafienia),
##  marker  - zapowiedź ataku wroga na ziemi (stożek/linia/koło), wypełnia się aż do uderzenia,
##  ring    - pierścień (wybuch, piorun, kapliczka), float - liczba obrażeń / napis.

var kind: String = "slash"
var life: float = 0.2
var age: float = 0.0
var dir := Vector2.RIGHT
var radius: float = 80.0
var arc: float = 120.0
var width: float = 20.0
var col := Color(1, 1, 1)
var fill_progress: float = -1.0     # marker: 0..1 sterowane z zewnątrz
var text: String = ""
var follow: Node2D = null
var vel := Vector2(0, -38)
var _label: Label

static func slash(parent: Node, pos: Vector2, d: Vector2, r: float, arc_deg: float, c: Color, dur: float = 0.16) -> Fx:
	var f := Fx.new()
	f.kind = "slash"
	f.position = pos
	f.dir = d.normalized()
	f.radius = r
	f.arc = arc_deg
	f.col = c
	f.life = dur
	f.z_index = 5
	parent.add_child(f)
	return f

static func marker(parent: Node, pos: Vector2, shape: String, d: Vector2, r: float, a_or_w: float, c: Color) -> Fx:
	var f := Fx.new()
	f.kind = "marker_" + shape
	f.position = pos
	f.dir = d.normalized() if d.length() > 0.01 else Vector2.RIGHT
	f.radius = r
	f.arc = a_or_w
	f.width = a_or_w
	f.col = c
	f.life = 999.0
	f.fill_progress = 0.0
	parent.add_child(f)
	return f

static func ring(parent: Node, pos: Vector2, r: float, c: Color, dur: float = 0.35) -> Fx:
	var f := Fx.new()
	f.kind = "ring"
	f.position = pos
	f.radius = r
	f.col = c
	f.life = dur
	parent.add_child(f)
	return f

static func bolt(parent: Node, pos: Vector2, c: Color, dur: float = 0.3) -> Fx:
	var f := Fx.new()
	f.kind = "lightning"
	f.position = pos
	f.col = c
	f.life = dur
	f.z_index = 30
	parent.add_child(f)
	return f

static func float_text(parent: Node, pos: Vector2, t: String, c: Color, big: bool = false) -> Fx:
	var f := Fx.new()
	f.kind = "float"
	f.position = pos + Vector2(randf_range(-8, 8), 0)
	f.text = t
	f.col = c
	f.life = 0.9
	f.z_index = 60
	f._label = Label.new()
	f._label.text = t
	f._label.add_theme_font_size_override("font_size", 22 if big else 17)
	f._label.add_theme_color_override("font_color", c)
	f._label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.03))
	f._label.add_theme_constant_override("outline_size", 5)
	f._label.position = Vector2(-40, -14)
	f._label.size = Vector2(80, 28)
	f._label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.add_child(f._label)
	parent.add_child(f)
	return f

func _process(delta: float) -> void:
	age += delta
	if follow and is_instance_valid(follow):
		position = follow.position
	if kind == "float":
		position += vel * delta
		vel.y += 30.0 * delta
		modulate.a = 1.0 if age < life * 0.6 else 1.0 - (age - life * 0.6) / (life * 0.4)
	if age >= life:
		queue_free()
		return
	queue_redraw()

func _arc_points(r: float, a0: float, a1: float, n: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var full := absf(a1 - a0) >= TAU - 0.001
	for i in (n if full else n + 1):
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(Iso.screen(Vector2.RIGHT.rotated(a) * r))
	return pts

func _draw() -> void:
	var g := Iso.ground(dir).normalized()
	var base := g.angle()
	match kind:
		"slash":
			var t := age / life
			var half := deg_to_rad(arc) * 0.5
			# półksiężyc: przesuwa się od jednego końca łuku do drugiego
			var a0 := base - half + (2.0 * half) * maxf(0.0, t - 0.35)
			var a1 := base - half + (2.0 * half) * minf(1.0, t * 1.6 + 0.1)
			if a1 <= a0:
				return
			var outer := _arc_points(radius, a0, a1)
			var inner := _arc_points(radius * 0.62, a1, a0)
			var poly := outer.duplicate()
			poly.append_array(inner)
			draw_colored_polygon(poly, Color(col, 0.85))
			draw_polyline(outer, Color(1, 1, 0.95, 0.95), 2.0)
		"marker_cone":
			var half := deg_to_rad(arc) * 0.5
			var pts := PackedVector2Array([Vector2.ZERO])
			pts.append_array(_arc_points(radius, base - half, base + half))
			draw_colored_polygon(pts, Color(col, 0.18))
			var pts2 := PackedVector2Array([Vector2.ZERO])
			pts2.append_array(_arc_points(radius * fill_progress, base - half, base + half))
			if fill_progress > 0.02:
				draw_colored_polygon(pts2, Color(col, 0.38))
			draw_polyline(pts, Color(col, 0.8), 1.5)
		"marker_line":
			var side := g.orthogonal() * width * 0.5
			var poly := PackedVector2Array([Iso.screen(side), Iso.screen(side + g * radius), Iso.screen(-side + g * radius), Iso.screen(-side)])
			draw_colored_polygon(poly, Color(col, 0.16))
			var p2 := PackedVector2Array([Iso.screen(side), Iso.screen(side + g * radius * fill_progress), Iso.screen(-side + g * radius * fill_progress), Iso.screen(-side)])
			if fill_progress > 0.02:
				draw_colored_polygon(p2, Color(col, 0.36))
			var closed := poly.duplicate()
			closed.append(poly[0])
			draw_polyline(closed, Color(col, 0.75), 1.5)
		"marker_circle":
			var full := _arc_points(radius, 0, TAU, 28)
			draw_colored_polygon(full, Color(col, 0.16))
			if fill_progress > 0.02:
				draw_colored_polygon(_arc_points(radius * fill_progress, 0, TAU, 28), Color(col, 0.34))
			var closed := full.duplicate()
			closed.append(full[0])
			draw_polyline(closed, Color(col, 0.85), 2.0)
		"ring":
			var t := age / life
			var rp := _arc_points(radius * (0.3 + 0.7 * t), 0, TAU, 30)
			rp.append(rp[0])
			draw_polyline(rp, Color(col, 1.0 - t), 3.0)
		"lightning":
			var y := -420.0
			var x := 0.0
			var pts := PackedVector2Array([Vector2(x, y)])
			var r := RandomNumberGenerator.new()
			r.seed = int(age * 30.0)
			while y < -4.0:
				y = minf(-4.0, y + r.randf_range(30, 60))
				x = clampf(x + r.randf_range(-22, 22), -40, 40)
				pts.append(Vector2(x, y))
			pts.append(Vector2.ZERO)
			draw_polyline(pts, Color(col, 0.9), 5.0)
			draw_polyline(pts, Color(1, 1, 1), 2.0)
