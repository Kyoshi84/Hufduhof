class_name LevelMap
extends Node2D
## Buduje poziom z pliku data/levels/<poziom>.json:
##  - TileMapLayer z izometrycznym TileSetem (kafle z assets/levels/<poziom>/tiles/<nazwa>.png),
##  - rekwizyty (drzewa, płoty, budynki, ściany) w węźle z Y-sortem,
##  - kolizje (StaticBody2D, warstwa 1) i nawigację (NavigationRegion2D, wypiekaną w czasie wczytywania),
##  - mgłę wojny (osobny TileMapLayer) z odkrywaniem w promieniu wokół bohatera.

const BLOCKING := "T#-|bWx"
const TILE_FOR := {
	".": ["grass_0", "grass_1", "grass_2", "grass_3"], ",": ["grass_flowers"], ":": ["dirt_0", "dirt_1"],
	"=": ["cobble_0", "cobble_1"], "~": ["mud_0"], "T": ["grass_0", "grass_2"], "b": ["grass_1", "grass_3"],
	"#": ["forest_0"], "-": ["grass_0"], "|": ["grass_1"], "o": ["floor_0", "floor_1"], "r": ["rug_0"],
	"s": ["stone_0"], "W": ["floor_0"], "x": ["floor_0"],
}

var data: Dictionary
var size := Vector2i.ZERO
var rows: Array = []
var blocked: Dictionary = {}          # Vector2i -> true (statyczne przeszkody)
var ground_layer: TileMapLayer
var fog_layer: TileMapLayer
var world: Node2D                     # Y-sort: rekwizyty + postacie
var decals: Node2D                    # pod postaciami (kałuże, znaczniki zapowiedzi ataku)
var nav_region: NavigationRegion2D
var walls: StaticBody2D
var explored := PackedByteArray()
var tile_dir: String
var prop_dir: String
var _tile_ids: Dictionary = {}       # nazwa kafla -> source id
var _fog_ids: Array = []
var _tex_cache: Dictionary = {}
var fog_enabled: bool = true

signal explored_changed

func build(level_data: Dictionary, level_key: String) -> void:
	data = level_data
	rows = data.get("mapa", [])
	size = Vector2i(rows[0].length() if not rows.is_empty() else 0, rows.size())
	tile_dir = str(data.get("kafle", "res://assets/levels/level1/tiles/"))
	prop_dir = str(data.get("rekwizyty", "res://assets/levels/level1/props/"))
	explored.resize(size.x * size.y)
	explored.fill(0)
	var saved: String = str(Game.explored.get(level_key, ""))
	if saved != "":
		var raw := Marshalls.base64_to_raw(saved)
		if raw.size() == explored.size():
			explored = raw
	_build_ground()
	decals = Node2D.new()
	decals.name = "Decals"
	decals.z_index = -5
	add_child(decals)
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)
	for y in size.y:
		for x in size.x:
			if BLOCKING.contains(char_at(x, y)):
				blocked[Vector2i(x, y)] = true
	_spawn_cell_props()
	for o in data.get("obiekty", []):
		_spawn_static_object(o)
	_build_walls()
	_build_navigation()
	_build_fog()

func char_at(x: int, y: int) -> String:
	if y < 0 or y >= rows.size() or x < 0 or x >= str(rows[y]).length():
		return "#"
	return str(rows[y])[x]

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y

func is_walkable(c: Vector2i) -> bool:
	return in_bounds(c) and not blocked.has(c)

func tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[path] = t
	return t

# ---------------------------------------------------------------- podłoże
func _build_ground() -> void:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(Iso.TW, Iso.TH)
	var names: Dictionary = {}
	for k in TILE_FOR:
		for n in TILE_FOR[k]:
			names[n] = true
	for n in names:
		var t := tex(tile_dir + n + ".png")
		if t == null:
			t = tex("res://assets/levels/level1/tiles/" + n + ".png")
		if t == null:
			continue
		var src := TileSetAtlasSource.new()
		src.texture = t
		src.texture_region_size = Vector2i(Iso.TW, Iso.TH)
		src.create_tile(Vector2i.ZERO)
		_tile_ids[n] = ts.add_source(src)
	ground_layer = TileMapLayer.new()
	ground_layer.name = "Ground"
	ground_layer.tile_set = ts
	ground_layer.z_index = -10
	add_child(ground_layer)
	for y in size.y:
		for x in size.x:
			var opts: Array = TILE_FOR.get(char_at(x, y), TILE_FOR["."])
			var n: String = opts[_hash(x, y) % opts.size()]
			if _tile_ids.has(n):
				ground_layer.set_cell(Vector2i(x, y), _tile_ids[n], Vector2i.ZERO)

func _hash(x: int, y: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663)) % 9973

# ---------------------------------------------------------------- rekwizyty
## Dodaje sprite rekwizytu. footprint = rozmiar podstawy w komórkach; anchor "south" (budynki) albo "center".
func add_prop(texture: Texture2D, cell: Vector2i, footprint: Vector2i = Vector2i.ONE, anchor: String = "center", parent: Node = null) -> Sprite2D:
	if texture == null:
		return null
	var s := Sprite2D.new()
	s.texture = texture
	s.centered = false
	var center := Iso.cellf_center(cell.x + (footprint.x - 1) / 2.0, cell.y + (footprint.y - 1) / 2.0)
	var a := Vector2.ZERO
	if anchor == "south":
		a = Vector2((footprint.x - footprint.y) * Iso.TW / 4.0, (footprint.x + footprint.y) * Iso.TH / 4.0)
	s.position = center
	s.offset = a - Vector2(texture.get_width() / 2.0, texture.get_height())
	(parent if parent else world).add_child(s)
	return s

func prop_tex(name: String, set_dir: String = "") -> Texture2D:
	var dirs := [set_dir] if set_dir != "" else []
	dirs.append_array([prop_dir, "res://assets/levels/level1/props/", "res://assets/levels/common/props/", "res://assets/levels/tavern/props/"])
	for d in dirs:
		var t := tex(d + name + ".png")
		if t:
			return t
	return null

func _spawn_cell_props() -> void:
	for y in size.y:
		for x in size.x:
			var c := char_at(x, y)
			var cell := Vector2i(x, y)
			match c:
				"T":
					add_prop(prop_tex("tree_%d" % (_hash(x, y) % 3)), cell)
				"b":
					add_prop(prop_tex("bush_%d" % (_hash(x, y) % 2)), cell)
				"-":
					add_prop(prop_tex("fence_x_broken" if _hash(x, y) % 7 == 0 else "fence_x"), cell)
				"|":
					add_prop(prop_tex("fence_y"), cell)
				"#":
					# drzewa tylko na wewnętrznym skraju lasu (reszta to ciemne podłoże)
					var edge := false
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var n := char_at(x + d.x, y + d.y)
						if n != "#" and in_bounds(cell + d):
							edge = true
					if edge or _hash(x, y) % 4 == 0:
						var sp := add_prop(prop_tex("tree_%d" % (_hash(x, y) % 3)), cell)
						if sp and not edge:
							sp.modulate = Color(0.6, 0.65, 0.6)
				"W":
					if y == 0:
						add_prop(prop_tex("wall_x_window" if x % 4 == 2 else "wall_x"), cell)
					if x == 0:
						add_prop(prop_tex("wall_y_window" if y % 4 == 2 else "wall_y"), cell)

func _spawn_static_object(o: Dictionary) -> void:
	var t := str(o.get("typ", ""))
	var c: Array = o.get("komorka", [0, 0])
	var cell := Vector2i(int(c[0]), int(c[1]))
	match t:
		"budynek":
			var sz: Array = o.get("rozmiar", [1, 1])
			var fp := Vector2i(int(sz[0]), int(sz[1]))
			add_prop(prop_tex(str(o.get("grafika", ""))), cell, fp, "south")
			for yy in fp.y:
				for xx in fp.x:
					blocked[cell + Vector2i(xx, yy)] = true
		"dekoracja":
			var set_dir := ""
			if o.has("zestaw"):
				set_dir = "res://assets/levels/%s/props/" % str(o["zestaw"])
			var sp := add_prop(prop_tex(str(o.get("grafika", "")), set_dir), cell)
			if str(o.get("grafika", "")) == "rat_hole" and sp:
				sp.z_index = -4
				sp.reparent(decals)
			if bool(o.get("blokuje", false)):
				blocked[cell] = true

# ---------------------------------------------------------------- kolizje
## Łączy sąsiednie zablokowane komórki w rzędy i tworzy z nich wielokąty kolizji.
func blocked_runs() -> Array:
	var runs: Array = []
	for y in size.y:
		var x := 0
		while x < size.x:
			if blocked.has(Vector2i(x, y)):
				var x0 := x
				while x < size.x and blocked.has(Vector2i(x, y)):
					x += 1
				runs.append([x0, x - 1, y])
			else:
				x += 1
	return runs

static func run_polygon(x0: int, x1: int, y: int, shrink: float = 0.0) -> PackedVector2Array:
	return PackedVector2Array([
		Iso.corner(x0 + shrink, y + shrink), Iso.corner(x1 + 1 - shrink, y + shrink),
		Iso.corner(x1 + 1 - shrink, y + 1 - shrink), Iso.corner(x0 + shrink, y + 1 - shrink)])

func _build_walls() -> void:
	walls = StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	walls.collision_mask = 0
	add_child(walls)
	for r in blocked_runs():
		var cp := CollisionPolygon2D.new()
		cp.polygon = run_polygon(r[0], r[1], r[2], 0.08)
		walls.add_child(cp)

# ---------------------------------------------------------------- nawigacja
func _build_navigation() -> void:
	nav_region = NavigationRegion2D.new()
	nav_region.name = "Nav"
	add_child(nav_region)
	rebake_navigation()

func rebake_navigation(extra_blocked: Array = []) -> void:
	var np := NavigationPolygon.new()
	np.agent_radius = 10.0
	var src := NavigationMeshSourceGeometryData2D.new()
	src.add_traversable_outline(PackedVector2Array([Iso.corner(0, 0), Iso.corner(size.x, 0), Iso.corner(size.x, size.y), Iso.corner(0, size.y)]))
	for r in blocked_runs():
		src.add_obstruction_outline(run_polygon(r[0], r[1], r[2]))
	for c in extra_blocked:
		src.add_obstruction_outline(run_polygon(c.x, c.x, c.y))
	NavigationServer2D.bake_from_source_geometry_data(np, src)
	nav_region.navigation_polygon = np

# ---------------------------------------------------------------- mgła wojny
func _build_fog() -> void:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(Iso.TW, Iso.TH)
	for n in ["fog_full", "fog_soft"]:
		var src := TileSetAtlasSource.new()
		src.texture = tex("res://assets/levels/common/tiles/%s.png" % n)
		src.texture_region_size = Vector2i(Iso.TW, Iso.TH)
		src.create_tile(Vector2i.ZERO)
		_fog_ids.append(ts.add_source(src))
	fog_layer = TileMapLayer.new()
	fog_layer.name = "Fog"
	fog_layer.tile_set = ts
	fog_layer.z_index = 40
	add_child(fog_layer)
	# ramka mgły także poza mapą, żeby nie było widać krawędzi
	for y in range(-6, size.y + 6):
		for x in range(-6, size.x + 6):
			var c := Vector2i(x, y)
			if not in_bounds(c) or explored[y * size.x + x] == 0:
				fog_layer.set_cell(c, _fog_ids[0], Vector2i.ZERO)
	for y in size.y:
		for x in size.x:
			if explored[y * size.x + x] != 0:
				_refresh_fog_cell(Vector2i(x, y))

func is_explored(c: Vector2i) -> bool:
	return in_bounds(c) and explored[c.y * size.x + c.x] != 0

## Odkrywa komórki w promieniu (w komórkach) od pozycji; zwraca true, jeśli coś się zmieniło.
func reveal(p: Vector2, radius: float) -> bool:
	if not fog_enabled:
		return false
	var center := Iso.to_cell(p)
	var r := int(ceil(radius))
	var changed := false
	var cf := Vector2(center)
	for y in range(center.y - r - 1, center.y + r + 2):
		for x in range(center.x - r - 1, center.x + r + 2):
			var c := Vector2i(x, y)
			if not in_bounds(c):
				continue
			if Vector2(c).distance_to(cf) <= radius and explored[y * size.x + x] == 0:
				explored[y * size.x + x] = 1
				changed = true
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						_refresh_fog_cell(c + Vector2i(dx, dy))
	if changed:
		explored_changed.emit()
	return changed

func _refresh_fog_cell(c: Vector2i) -> void:
	if not in_bounds(c):
		return
	if is_explored(c):
		var edge := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if in_bounds(c + d) and not is_explored(c + d):
				edge = true
		if edge:
			fog_layer.set_cell(c, _fog_ids[1], Vector2i.ZERO)
		else:
			fog_layer.erase_cell(c)
	else:
		fog_layer.set_cell(c, _fog_ids[0], Vector2i.ZERO)

func explored_b64() -> String:
	return Marshalls.raw_to_base64(explored)

func explored_ratio() -> float:
	var n := 0
	for b in explored:
		if b != 0:
			n += 1
	return float(n) / maxf(1.0, explored.size())

func map_bounds() -> Rect2:
	var pts := [Iso.corner(0, 0), Iso.corner(size.x, 0), Iso.corner(size.x, size.y), Iso.corner(0, size.y)]
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r
