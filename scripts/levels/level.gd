class_name Level
extends Node2D
## Scena rozgrywki budowana z data/levels/<klucz>.json: mapa, bohater, kamera, obiekty, wrogowie, interfejs.
## Wspólna dla karczmy (podklasa Tavern) i wioski. Przejścia między ekranami zgłasza sygnałem request.

signal request(what: String)

var key: String = "wioska"
var data: Dictionary
var map: LevelMap
var hero: Hero
var cam: Camera2D
var ui: CanvasLayer
var hud: Hud
var touch: TouchControls
var fx_top: Node2D
var overlay: Control = null
var minimap: Minimap
var well: Node = null
var barricade_parts: Array = []
var exit_zone: Node = null
var tunnel_defs: Array = []
var _enemies: Array = []
var _shake: float = 0.0
var _zoom: float = 1.15
var _hitstop_on: bool = false
var _dying: bool = false
var rng := RandomNumberGenerator.new()

func _init(level_key: String = "wioska") -> void:
	key = level_key

func _ready() -> void:
	rng.randomize()
	Controls.reset()
	data = Data.load_json("res://data/levels/%s.json" % key)
	map = LevelMap.new()
	map.name = "Map"
	add_child(map)
	map.build(data, key)
	fx_top = Node2D.new()
	fx_top.name = "FxTop"
	fx_top.z_index = 45
	add_child(fx_top)
	_spawn_objects()
	_spawn_hero()
	_setup_camera()
	_setup_ui()
	map.reveal(hero.position, float(Data.bal("mgla/promien_komorek", 6.5)))
	var tint_key := "odcien" if LightFx.enabled() else "odcien_bez_swiatel"
	if data.has(tint_key):
		# zmierzch (grimdark): mnożnik koloru całego świata gry, bez interfejsu; źródła światła rozjaśniają go lokalnie
		var tint: Array = data[tint_key]
		var cm := CanvasModulate.new()
		cm.color = Color(float(tint[0]), float(tint[1]), float(tint[2]))
		add_child(cm)
	Audio.play_track(str(data.get("muzyka", "wioska")))
	Game.quest_changed.connect(_on_quest_changed)
	after_ready()

## Podklasy (karczma) dopisują tu własne rzeczy.
func after_ready() -> void:
	if Game.quest.is_barricade_out() and exit_zone:
		exit_zone.open = true
	autosave()

# ---------------------------------------------------------------- budowa
func cell_pos(o: Dictionary) -> Vector2:
	var c: Array = o.get("komorka", [0, 0])
	return Iso.cell_center(Vector2i(int(c[0]), int(c[1])))

func _spawn_objects() -> void:
	var barr_i := 0
	for o in data.get("obiekty", []):
		var t := str(o.get("typ", ""))
		var p := cell_pos(o)
		match t:
			"skrzynia":
				_add_obj(Obj.Chest.new(), p).setup(self, str(o.get("id", "")))
				map.blocked[Iso.to_cell(p)] = true
			"kapliczka":
				_add_obj(Obj.Shrine.new(), p).setup(self, str(o.get("id", "")), str(o.get("rodzaj", "ulryk")))
				map.blocked[Iso.to_cell(p)] = true
			"studnia":
				well = _add_obj(Obj.Well.new(), p)
				well.setup(self)
				map.blocked[Iso.to_cell(p)] = true
			"wiadro":
				_add_obj(Obj.Bucket.new(), p).setup(self, str(o.get("id", "")))
			"barykada":
				var part: Node = _add_obj(Obj.BarricadePart.new(), p)
				part.setup(self, str(o.get("id", "")), barr_i, Iso.to_cell(p))
				barricade_parts.append(part)
				barr_i += 1
			"wyjscie":
				exit_zone = _add_obj(Obj.ExitZone.new(), p)
				exit_zone.setup(self, float(o.get("promien", 2)))
			"tunel":
				tunnel_defs.append(o)
			"latarnia":
				map.add_prop(map.prop_tex("lantern_post"), Iso.to_cell(p))
				map.blocked[Iso.to_cell(p)] = true
				LightFx.make("latarnia", map.world, p)
			"swiatlo":
				LightFx.make(str(o.get("rodzaj", "latarnia")), map.world, p)
			"npc":
				_add_obj(Obj.Npc.new(), p).setup(self, str(o.get("id", "borubar")))
				map.blocked[Iso.to_cell(p)] = true
			_:
				spawn_custom_object(o, p)
	# kolizje i nawigacja muszą uwzględnić skrzynie/kapliczki/studnię dodane wyżej
	map.walls.queue_free()
	map._build_walls()
	var extra: Array = []
	for part in barricade_parts:
		if part.burning:
			extra.append(part.cell)
	map.rebake_navigation(extra)
	for o in tunnel_defs:
		var tn := Obj.Tunnel.new()
		tn.position = cell_pos(o)
		map.decals.add_child(tn)
		tn.setup(self, str(o.get("id", "")), o.get("wrogowie", []))
	for g in data.get("grupy", []):
		var c: Array = g.get("komorka", [0, 0])
		var center := Vector2i(int(c[0]), int(c[1]))
		var list: Array = g.get("wrogowie", [])
		for i in list.size():
			var uid := "%s_%s_%d" % [key, str(g.get("id", "g")), i]
			if Game.has_flag("zabici", uid):
				continue
			var cell := _free_cell_near(center, int(g.get("promien", 2)), i)
			spawn_enemy(str(list[i]), Iso.cell_center(cell) + Vector2(rng.randf_range(-12, 12), rng.randf_range(-6, 6)), str(g.get("id", "")), uid)

func spawn_custom_object(_o: Dictionary, _p: Vector2) -> void:
	pass

func _add_obj(n: Node2D, p: Vector2) -> Node2D:
	n.position = p
	map.world.add_child(n)
	return n

func _free_cell_near(c: Vector2i, r: int, salt: int) -> Vector2i:
	var cands: Array = []
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var cc := c + Vector2i(x, y)
			if map.is_walkable(cc):
				cands.append(cc)
	if cands.is_empty():
		return c
	return cands[(salt * 7 + c.x) % cands.size()]

func start_cell() -> Vector2:
	for o in data.get("obiekty", []):
		if str(o.get("typ", "")) == "start":
			return cell_pos(o)
	return Iso.cell_center(Vector2i(Vector2(map.size) * 0.5))

func _spawn_hero() -> void:
	hero = Hero.new()
	hero.level = self
	hero.position = Game.spawn_pos if Game.spawn_pos != null else start_cell()
	Game.spawn_pos = null
	map.world.add_child(hero)
	hero.setup(Game.hero)
	var hl := LightFx.make("bohater", hero, Vector2.ZERO)   # słaba poświata, żeby postać była czytelna w mroku
	if hl:
		hl.name = "HeroLight"

func spawn_enemy(eid: String, pos: Vector2, group: String, uid: String) -> Enemy:
	var e := Enemy.new()
	e.level = self
	e.position = pos
	map.world.add_child(e)
	e.setup(eid, uid, group)
	_enemies.append(e)
	return e

func _setup_camera() -> void:
	cam = Camera2D.new()
	_zoom = float(Data.bal("kamera/zoom", 1.15))
	cam.zoom = Vector2.ONE * _zoom
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = float(Data.bal("kamera/wygladzanie", 6.0))
	cam.position = hero.position
	var b := map.map_bounds()
	cam.limit_left = int(b.position.x) - 200
	cam.limit_right = int(b.end.x) + 200
	cam.limit_top = int(b.position.y) - 300
	cam.limit_bottom = int(b.end.y) + 200
	add_child(cam)
	cam.make_current()
	cam.reset_smoothing()

func _setup_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 10
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	hud = Hud.new()
	hud.level = self
	ui.add_child(hud)
	touch = TouchControls.new()
	touch.level = self
	touch.visible = Save.touch_enabled()
	ui.add_child(touch)
	var keys := OverlayKeys.new()
	keys.level = self
	ui.add_child(keys)
	minimap = Minimap.new()
	minimap.level = self
	minimap.visible = false
	ui.add_child(minimap)
	if Save.palette_filter:
		add_child(PaletteFilter.new())

# ---------------------------------------------------------------- pętla
func _physics_process(delta: float) -> void:
	if hero:
		cam.position = hero.position + Vector2(0, -40)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 18.0)
		cam.offset = Vector2(rng.randf_range(-_shake, _shake), rng.randf_range(-_shake, _shake))
	else:
		cam.offset = Vector2.ZERO
	if hero:
		hero.mouse_world = get_global_mouse_position()

func _unhandled_input(event: InputEvent) -> void:
	if overlay != null:
		return
	if event is InputEventMouseMotion and not Save.touch_enabled() and hero:
		hero.use_mouse_aim = true
	if event is InputEventMouseButton and not Save.touch_enabled():
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			hero.mouse_atk = mb.pressed
			hero.use_mouse_aim = true
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			hero.mouse_skill = mb.pressed
			hero.use_mouse_aim = true
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			set_zoom(_zoom + 0.08)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			set_zoom(_zoom - 0.08)
	elif event is InputEventKey and event.pressed and not event.echo:
		if hero and event.is_action("atak"):
			hero.use_mouse_aim = false
	if event.is_action_pressed("pauza"):
		open_pause()
	elif event.is_action_pressed("mapa"):
		toggle_map()
	elif event.is_action_pressed("postac"):
		open_character()
	elif event.is_action_pressed("plecak"):
		open_inventory()
	elif event.is_action_pressed("debug") and OS.is_debug_build():
		Game.debug_collision = not Game.debug_collision
		Game.notify("Diagnostyka kolizji: " + ("WŁ" if Game.debug_collision else "wył"))

func set_zoom(z: float) -> void:
	_zoom = clampf(z, float(Data.bal("kamera/zoom_min", 0.85)), float(Data.bal("kamera/zoom_max", 1.6)))
	cam.zoom = Vector2.ONE * _zoom

# ---------------------------------------------------------------- usługi dla obiektów
func fx_parent() -> Node:
	return fx_top

func decal_parent() -> Node:
	return map.decals

func enemies() -> Array:
	_enemies = _enemies.filter(func(e): return is_instance_valid(e))
	return _enemies

func alive_enemies() -> int:
	var n := 0
	for e in enemies():
		if not e.is_dead():
			n += 1
	return n

func actors_of_faction(f: int) -> Array:
	if f == 0:
		return [hero] if hero else []
	return enemies()

func reveal_around(p: Vector2) -> void:
	if map.reveal(p, float(Data.bal("mgla/promien_komorek", 6.5))):
		Game.explored[key] = map.explored_b64()

func spawn_projectile(kind: String, from: Actor, pos: Vector2, d: Vector2, spd: float, dist: float, dmg: int, opts: Dictionary = {}) -> void:
	var pr := Projectile.new()
	map.world.add_child(pr)
	pr.setup(self, kind, from, pos, d, spd, dist, dmg, opts)

func spawn_warp_orb(from: Actor, a: Vector2, b: Vector2, edef: Dictionary) -> void:
	var o := WarpOrb.new()
	map.world.add_child(o)
	o.setup(self, from, a, b, edef)

func drop_loot(pos: Vector2, drops: Array) -> void:
	for d in drops:
		var ang := rng.randf() * TAU
		var dest := pos + Iso.screen(Vector2.RIGHT.rotated(ang) * rng.randf_range(30, 60))
		if not map.is_walkable(Iso.to_cell(dest)):
			dest = pos
		var pk := Pickup.new()
		map.world.add_child(pk)
		pk.setup(d, pos, dest)

func alert_group(group: String) -> void:
	if group == "":
		return
	for e in enemies():
		if e.group == group and not e.is_dead():
			e.wake()

func on_enemy_died(e: Enemy) -> void:
	if e.uid != "":
		Game.add_flag("zabici", e.uid)
	Game.give_xp(int(e.edef.get("xp", 0)))
	drop_loot(e.position, Loot.roll_table(str(e.edef.get("lup", "")), Game.rng))
	enemy_killed(e)

func enemy_killed(_e: Enemy) -> void:
	pass

func hitstop(d: float) -> void:
	if _hitstop_on or d <= 0.0:
		return
	_hitstop_on = true
	Engine.time_scale = 0.1
	await get_tree().create_timer(d, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_on = false

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func autosave() -> void:
	if hero == null or key == "karczma":
		return
	Game.level_id = key
	Game.explored[key] = map.explored_b64()
	Save.save_game(hero.position)

# ---------------------------------------------------------------- śmierć bohatera (PP)
func on_hero_died() -> void:
	if _dying:
		return
	_dying = true
	await get_tree().create_timer(1.4).timeout
	var pp := Game.hero.stats.base_val("PP")
	if pp > 0:
		Game.hero.stats.set_base("PP", pp - 1)
		hero.revive(float(Data.bal("pp/odrodzenie_zycie", 0.5)))
		Fx.ring(decal_parent(), hero.position, 80.0, Color(1.0, 0.9, 0.5), 0.8)
		Audio.play("shrine")
		Game.notify("Przeznaczenie cię ocaliło! (zużyto 1 PP, zostało: %d)" % (pp - 1), Color(1.0, 0.85, 0.4))
		Game.hero_changed.emit()
		_dying = false
		return
	var btns: Array = []
	if Save.has_save() and key != "karczma":
		btns.append(["Wczytaj ostatni zapis", func(): request.emit("wczytaj")])
	else:
		btns.append(["Spróbuj ponownie", func(): request.emit("karczma_od_nowa")])
	btns.append(["Menu główne", func(): request.emit("menu")])
	open_overlay(UiKit.overlay("ŚMIERĆ", "Nie masz już Punktów Przeznaczenia.", btns), true, false)
	_dying = false

# ---------------------------------------------------------------- nakładki (pauza, postać, plecak, handel, dialog)
func open_overlay(c: Control, pause: bool = true, closable: bool = true) -> void:
	close_overlay()
	overlay = c
	c.set_meta("closable", closable)
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	ui.add_child(c)
	get_tree().paused = pause
	Controls.reset()
	if hero:
		hero.mouse_atk = false
	touch.visible = false

func close_overlay() -> void:
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	get_tree().paused = false
	if hero:
		hero.ui_cooldown = 0.3
	touch.visible = Save.touch_enabled()
	Controls.reset()

func open_pause() -> void:
	var btns := [
		["Wznów", close_overlay],
		["Zapisz grę", func():
			if key == "karczma":
				Game.notify("W karczmie nie można zapisywać - zapis nastąpi w wiosce.")
			else:
				autosave()
				Game.notify("Zapisano grę.")
			close_overlay()],
		["Postać", open_character],
		["Plecak", open_inventory],
		["Ustawienia", func(): open_overlay(SettingsScreen.build(func(): open_pause()))],
		["Menu główne", func():
			close_overlay()
			request.emit("menu")],
	]
	open_overlay(UiKit.overlay("PAUZA", "", btns))

func open_character() -> void:
	open_overlay(CharacterSheet.build(Game.hero, close_overlay, func(): Game.hero_changed.emit()))

func open_inventory(shop_id: String = "") -> void:
	open_overlay(InventoryScreen.build(Game.hero, close_overlay, shop_id))

func toggle_map() -> void:
	minimap.visible = not minimap.visible
	if minimap.visible:
		minimap.queue_redraw()

# ---------------------------------------------------------------- zadanie i NPC
func talk_to_npc(id: String) -> void:
	if id != "borubar":
		return
	var q := Game.quest
	var lines: Array
	var after := func(): pass
	if q.state == BucketQuest.State.NOT_STARTED:
		lines = Data.dialog("borubar_start")
		after = func():
			q.start()
			Game.quest_xp("rozmowa_borubar")
			Game.quest_changed.emit()
			autosave()
	elif q.state == BucketQuest.State.EXTINGUISHED and not Game.borubar_rewarded:
		lines = Data.dialog("borubar_koniec")
		after = func():
			Game.borubar_rewarded = true
			q.complete()
			Game.hero.inv.gold += int(Data.bal("nagroda_borubara_korony", 50))
			Game.hero.inv.belt_add("piwo", 2)
			Game.quest_xp("nagroda_borubara")
			Game.notify("Nagroda: %d koron i 2 piwa" % int(Data.bal("nagroda_borubara_korony", 50)), Color(1.0, 0.85, 0.35))
			Game.quest_changed.emit()
			autosave()
	elif q.state >= BucketQuest.State.EXTINGUISHED:
		lines = Data.dialog("borubar_potem")
	else:
		lines = Data.dialog("borubar_w_trakcie")
	var bye := func():
		after.call()
		close_overlay()
	var dlg := DialogBox.build("Borubar", "res://assets/characters/borubar/portrait.png", lines,
		[["Handel", func():
			after.call()
			open_inventory("borubar")], ["Do widzenia", bye]])
	dlg.set_meta("on_cancel", bye)
	open_overlay(dlg)

func on_barricade_part_out() -> void:
	var idx := Game.quest.poured - 1
	if idx >= 0 and idx < barricade_parts.size():
		barricade_parts[idx].extinguish_visual()
	var extra: Array = []
	for part in barricade_parts:
		if part.burning:
			extra.append(part.cell)
	map.rebake_navigation(extra)
	if Game.quest.is_barricade_out():
		Game.quest_xp("barykada_ugaszona")
		Game.notify("Barykada ugaszona! Droga przez bramę wolna.", Color(1.0, 0.85, 0.4))
		if exit_zone:
			exit_zone.open = true
	else:
		Game.notify("Ugaszono część barykady (%d/%d)" % [Game.quest.poured, Game.quest.total], Color(0.6, 0.8, 1.0))
	autosave()

func on_exit_reached() -> void:
	Game.level_id = "poziom2"
	Game.explored[key] = map.explored_b64()
	request.emit("poziom2")

func controlled_name() -> String:
	return Game.hero.display_name()

func quest_lines() -> Array:
	return Game.quest.log_lines()

func leave_tavern() -> void:
	pass

func _on_quest_changed() -> void:
	if hud:
		hud.refresh_quest()

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
