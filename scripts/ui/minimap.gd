class_name Minimap
extends Control
## Minimapa (przycisk "Mapa" / klawisz M): pokazuje tylko odkryte komórki (mgła wojny), bohatera,
## Borubara, studnię, barykadę, znalezione wiadra, kapliczki i skrzynie.

var level: Node
var _t: float = 0.0
const CELL := 7.0

func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_t += delta
	if visible and _t > 0.25:
		_t = 0.0
		queue_redraw()

func _to_map(c: Vector2, origin: Vector2) -> Vector2:
	return origin + Vector2((c.x - c.y) * CELL, (c.x + c.y) * CELL * 0.5)

func _draw() -> void:
	if level == null or level.map == null:
		return
	var m: LevelMap = level.map
	var w := (m.size.x + m.size.y) * CELL
	var hgt := (m.size.x + m.size.y) * CELL * 0.5
	var origin := Vector2(size.x / 2.0, size.y / 2.0 - hgt / 2.0)
	draw_rect(Rect2(origin + Vector2(-w / 2.0 - 12, -12), Vector2(w + 24, hgt + 40)), Color(0.05, 0.03, 0.03, 0.82))
	draw_rect(Rect2(origin + Vector2(-w / 2.0 - 12, -12), Vector2(w + 24, hgt + 40)), Color(0.62, 0.48, 0.22), false, 2.0)
	for y in m.size.y:
		for x in m.size.x:
			var c := Vector2i(x, y)
			if not m.is_explored(c):
				continue
			var ch := m.char_at(x, y)
			var col := Color(0.2, 0.3, 0.14)
			match ch:
				":": col = Color(0.4, 0.3, 0.18)
				"=": col = Color(0.45, 0.44, 0.42)
				"~": col = Color(0.25, 0.18, 0.1)
				"T", "#", "b": col = Color(0.09, 0.16, 0.07)
				"-", "|": col = Color(0.5, 0.36, 0.2)
				"o", "r", "s": col = Color(0.4, 0.28, 0.16)
				"W", "x": col = Color(0.15, 0.1, 0.08)
			if m.blocked.has(c) and not ch in "T#b-|Wx":
				col = Color(0.42, 0.14, 0.1)
			var p := _to_map(Vector2(x, y), origin)
			draw_colored_polygon(PackedVector2Array([p, p + Vector2(CELL, CELL * 0.5), p + Vector2(0, CELL), p + Vector2(-CELL, CELL * 0.5)]), col)
	var marks: Array = []
	for n in get_tree().get_nodes_in_group("interactable"):
		var cell := Iso.to_cell(n.position)
		if not m.is_explored(cell):
			continue
		var col := Color(0, 0, 0, 0)
		if n is Obj.Npc: col = Color(1.0, 0.85, 0.2)
		elif n is Obj.Well: col = Color(0.4, 0.6, 1.0)
		elif n is Obj.BarricadePart: col = Color(1.0, 0.45, 0.1) if n.burning else Color(0.4, 0.4, 0.4)
		elif n is Obj.Bucket: col = Color(0.6, 0.85, 1.0)
		elif n is Obj.Shrine: col = Color(0.95, 0.95, 0.7) if not n.used else Color(0.4, 0.4, 0.35)
		elif n is Obj.Chest and not n.opened: col = Color(0.75, 0.5, 0.2)
		if col.a > 0.0:
			marks.append([cell, col])
	for mk in marks:
		var p := _to_map(Vector2(mk[0]) + Vector2(0.5, 0.5), origin)
		draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), mk[1])
	if level.hero:
		var hc := Iso.to_cell(level.hero.position)
		var p := _to_map(Vector2(hc) + Vector2(0.5, 0.5), origin)
		draw_circle(p, 5.0, Color(1, 1, 1))
		draw_circle(p, 3.0, Color(0.85, 0.15, 0.12))
	var f := get_theme_default_font()
	var title := "%s  -  odkryto %d%%" % [str(level.data.get("nazwa", "")), int(m.explored_ratio() * 100)]
	draw_string(f, origin + Vector2(-w / 2.0, hgt + 20), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.78, 0.45))
