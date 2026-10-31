class_name Level
extends Node2D
## Jeden przewijany poziom: kamera, fale wrogów, blokada ekranu, tokeny ataku, efekty, zakończenie.

signal exit_to_menu
signal restart_requested

const VIEW_H := 720.0

var data: Dictionary = {}
var player: Player
var enemies: Array = []
var barrels: Array = []
var pickups: Array = []
var obstacles: Array = []           # Obstacle: kałuże, ogień, powalone drzewa, rzeki, przepaście (trzeba skoczyć)
var obstacle_layer: Node2D
var ambient: Ambient                # uciekający wieśniacy i zwierzęta (tylko dekoracja)
var atmosphere: LevelAtmosphere     # gęstniejący las i ściemnianie
var _jump_hint_shown: bool = false
var entities: Node2D
var camera: Camera2D
var world: Node                    # rodzic świata: SubViewport (gra) lub sam Level (testy)
var world_vp: SubViewport
var display_layer: CanvasLayer
var display_rect: TextureRect
var bg: LevelBackground
var fx: FxLayer
var debug_overlay: DebugOverlay
var hud: Hud
var overlay_layer: CanvasLayer
var overlay: Control

var level_w: float = 7600.0
var view_w: float = 1280.0
var view_h: float = 720.0
var view_left: float = 0.0
var locked: bool = false
var lock_left: float = 0.0
var freeze_time: float = 0.0
var shake: float = 0.0

var waves: Array = []
var next_wave: int = 0
var wave_active: bool = false
var wave_time: float = 0.0
var spawn_queue: Array = []
var tokens: Array = []
var stage_idx: int = -1
var go_prompt: bool = false
var story_active: bool = false       # ekran fabularny na wierzchu (gra wstrzymana)
var _story_checked: bool = false
var _stories_seen: Dictionary = {}

var outcome: String = ""
var outcome_t: float = 0.0
var boss: Boss = null
var start_wave_idx: int = 0
var simulate_only: bool = false     # tryb testowy: bez UI/dźwięków/kamery z viewportu

func _init(p_data: Dictionary = {}, p_from_wave: int = 0) -> void:
	data = p_data
	start_wave_idx = p_from_wave

func _ready() -> void:
	if data.is_empty():
		data = load_level_data("res://data/level_1.json")
	build()

static func load_level_data(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Nie można wczytać poziomu %s" % path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func build() -> void:
	level_w = float(data["length"])
	waves = data["waves"]
	if not simulate_only:
		view_w = maxf(get_viewport_rect().size.x, 1280.0)
	world = self
	if not simulate_only:
		build_world_viewport()
	bg = LevelBackground.new()
	bg.level = self
	world.add_child(bg)
	obstacle_layer = Node2D.new()
	obstacle_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.add_child(obstacle_layer)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	world.add_child(entities)
	for od in data.get("obstacles", []):
		if Obstacle.is_known(str(od.get("type", ""))):
			var o := Obstacle.new()
			o.setup(self, str(od["type"]), float(od["x"]))
			obstacle_layer.add_child(o)
			obstacles.append(o)
	if not simulate_only:
		ambient = Ambient.new()
		ambient.level = self
		entities.add_child(ambient)
		atmosphere = LevelAtmosphere.new()
		atmosphere.level = self
		atmosphere.z_index = 8
		world.add_child(atmosphere)
	fx = FxLayer.new()
	fx.z_index = 50
	world.add_child(fx)
	debug_overlay = DebugOverlay.new()
	debug_overlay.level = self
	debug_overlay.visible = false
	world.add_child(debug_overlay)
	for bx in data.get("barrels", []):
		var b := Barrel.new()
		b.setup(self, Vector2(float(bx), randf_range(lane_min() + 20.0, lane_max() - 20.0)))
		entities.add_child(b)
		barrels.append(b)
	for px in data.get("potions", []):
		drop_pickup(Vector2(float(px), randf_range(lane_min() + 25.0, lane_max() - 25.0)))
	for sx in data.get("slimes", []):
		drop_pickup(Vector2(float(sx), randf_range(lane_min() + 25.0, lane_max() - 25.0)), "slime")
	player = Player.new()
	player.setup(self)
	player.position = Vector2(float(data["player_start"]), (lane_min() + lane_max()) * 0.5)
	attach_visual(player, "ivo")
	entities.add_child(player)
	camera = Camera2D.new()
	camera.position = Vector2(view_w * 0.5, VIEW_H * 0.5)
	world.add_child(camera)
	if not simulate_only:
		camera.make_current()
		hud = Hud.new()
		hud.level = self
		add_child(hud)
		overlay_layer = CanvasLayer.new()
		overlay_layer.layer = 30
		overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(overlay_layer)
		Controls.pause_pressed.connect(toggle_pause)
		Sfx.play_music()
	# checkpoint: kontynuacja od wskazanej fali
	if start_wave_idx > 0 and start_wave_idx < waves.size():
		next_wave = start_wave_idx
		var tx: float = float(waves[next_wave]["trigger"])
		player.position.x = maxf(float(data["player_start"]), tx - 520.0)
		view_left = clampf(player.position.x - view_w * 0.42, 0.0, level_w - view_w)
	update_stage_banner()

## Świat jest renderowany do SubViewport o mniejszej rozdzielczości (render_scale z balance.json,
## domyślnie 0.75 => 960x540) i skalowany do ekranu filtrem "nearest" => ostre, arcade'owe piksele.
## HUD i menu zostają w głównym viewport (pełna ostrość wejścia dotykowego).
func build_world_viewport() -> void:
	world_vp = SubViewport.new()
	world_vp.disable_3d = true
	world_vp.transparent_bg = false
	world_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(world_vp)
	world = world_vp
	display_layer = CanvasLayer.new()
	display_layer.layer = -1
	add_child(display_layer)
	display_rect = TextureRect.new()
	display_rect.texture = world_vp.get_texture()
	display_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display_rect.stretch_mode = TextureRect.STRETCH_SCALE
	display_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display_layer.add_child(display_rect)
	fit_world()
	get_viewport().size_changed.connect(fit_world)

func fit_world() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var ratio: float = float(Balance.world("render_scale"))
	view_w = maxf(vs.x, 1280.0)
	view_h = maxf(vs.y, 720.0)
	world_vp.size = Vector2i(maxi(1, roundi(vs.x * ratio)), maxi(1, roundi(vs.y * ratio)))
	world_vp.size_2d_override = Vector2i(roundi(vs.x), roundi(vs.y))
	world_vp.size_2d_override_stretch = true
	display_rect.position = Vector2.ZERO
	display_rect.size = vs

func attach_visual(a: Actor, kind: String) -> void:
	var v := ActorVisual.new()
	v.setup(a, kind)
	a.add_child(v)
	a.visual = v

# ------------------------------------------------------------------ granice sceny

func lane_min() -> float:
	return float(Balance.world("lane_min"))

func lane_max() -> float:
	return float(Balance.world("lane_max"))

func clamp_player(p: Actor) -> void:
	p.position.x = clampf(p.position.x, view_left + 36.0, view_left + view_w - 36.0)
	p.position.x = clampf(p.position.x, 20.0, level_w - 20.0)
	p.position.y = clampf(p.position.y, lane_min(), lane_max())

func clamp_enemy(e: Actor) -> void:
	e.position.x = clampf(e.position.x, -200.0, level_w + 200.0)
	e.position.y = clampf(e.position.y, lane_min(), lane_max())

func opponents_of(a: Actor) -> Array:
	if a.team == 0:
		var out: Array = []
		for e in enemies:
			if e.is_alive():
				out.append(e)
		for b in barrels:
			if b.is_alive():
				out.append(b)
		return out
	if player != null and player.is_alive():
		return [player]
	return []

# ------------------------------------------------------------------ tokeny ataku

func request_token(e) -> bool:
	if tokens.has(e):
		return true
	if tokens.size() >= int(Balance.world("max_attackers")):
		return false
	tokens.append(e)
	return true

func release_token(e) -> void:
	tokens.erase(e)

# ------------------------------------------------------------------ pętla

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 30.0)
	if freeze_time > 0.0:
		freeze_time -= delta
		update_camera(delta)
		return
	var prev_x: float = player.position.x
	player.tick(delta)
	player.speed_mult = 1.0
	for o in obstacles:
		o.resolve(player, prev_x, delta)
	update_jump_hint()
	for e in enemies.duplicate():
		e.tick(delta)
		if e.remove_me:
			remove_enemy(e)
	for b in barrels:
		b.tick(delta)
	for p in pickups.duplicate():
		p.tick(delta)
		if p.taken:
			pickups.erase(p)
			p.queue_free()
	if ambient != null:
		ambient.tick(delta)
	update_waves(delta)
	update_camera(delta)
	check_outcome(delta)

func update_camera(delta: float) -> void:
	var target: float
	if locked:
		target = lock_left
	else:
		target = clampf(player.position.x - view_w * 0.42, 0.0, level_w - view_w)
	view_left = lerpf(view_left, target, 1.0 - exp(-6.0 * delta))
	var off := Vector2.ZERO
	if shake > 0.0:
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	camera.position = Vector2(view_left + view_w * 0.5, VIEW_H * 0.5) + off

# ------------------------------------------------------------------ fale

func update_waves(delta: float) -> void:
	if outcome != "":
		return
	if not wave_active:
		update_stage_banner()
		if next_wave < waves.size() and player.position.x >= float(waves[next_wave]["trigger"]):
			start_wave(next_wave)
		return
	wave_time += delta
	while not spawn_queue.is_empty() and float(spawn_queue[0]["t"]) <= wave_time:
		var s: Dictionary = spawn_queue.pop_front()
		spawn_enemy(str(s["type"]), str(s["side"]))
	if spawn_queue.is_empty() and alive_enemy_count() == 0:
		end_wave()

func start_wave(i: int) -> void:
	var w: Dictionary = waves[i]
	wave_active = true
	wave_time = 0.0
	go_prompt = false
	locked = true
	lock_left = clampf(player.position.x - view_w * 0.42, 0.0, level_w - view_w)
	spawn_queue.clear()
	for s in w["spawns"]:
		var t0: float = float(s.get("delay", 0.0))
		var interval: float = float(s.get("interval", 0.9))
		for k in int(s.get("count", 1)):
			var side: String = str(s.get("side", "right"))
			if side == "both":
				side = "left" if k % 2 == 0 else "right"
			spawn_queue.append({ "t": t0 + k * interval, "type": s["type"], "side": side })
	spawn_queue.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	if bool(w.get("final", false)) and hud != null:
		hud.show_banner("CZEMPION CHAOSU", 2.5)

func end_wave() -> void:
	var w: Dictionary = waves[next_wave]
	wave_active = false
	locked = false
	next_wave += 1
	if bool(w.get("final", false)):
		return
	go_prompt = true
	SaveData.set_checkpoint(next_wave, GameState.score, GameState.kills)

func alive_enemy_count() -> int:
	var n := 0
	for e in enemies:
		if e.is_alive():
			n += 1
	return n

func spawn_enemy(type: String, side: String) -> Enemy:
	var left: float = lock_left if locked else view_left
	var x: float
	if side == "left" and left > 120.0:
		x = left - 70.0
	else:
		x = left + view_w + 70.0
	var pos := Vector2(x, randf_range(lane_min(), lane_max()))
	var e: Enemy = Boss.new() if str(Balance.enemy(type)["behavior"]) == "boss" else Enemy.new()
	e.setup(self, type, pos)
	attach_visual(e, type)
	entities.add_child(e)
	enemies.append(e)
	if e is Boss:
		boss = e
		Sfx.play("boss_roar")
		if not simulate_only:
			Sfx.play_track("boss")
	return e

func remove_enemy(e: Enemy) -> void:
	enemies.erase(e)
	tokens.erase(e)
	e.queue_free()

func update_stage_banner() -> void:
	var stages: Array = data["stages"]
	var idx := 0
	for i in stages.size():
		if player.position.x >= float(stages[i]["start"]):
			idx = i
	if idx != stage_idx:
		stage_idx = idx
		if hud != null:
			var banner: String = str(stages[idx]["name"])
			var entry: Dictionary = _story_to_show(idx)
			if entry.is_empty():
				hud.show_banner(banner, 2.4)
			else:
				show_story(entry, banner)

## Wpis fabularny do pokazania przed etapem idx (pusty, gdy brak, wyłączony albo już widziany).
## Przy kontynuacji z checkpointu pomijamy fabułę etapów, które gracz ma już za sobą.
func _story_to_show(idx: int) -> Dictionary:
	if not GameState.story_enabled:
		return {}
	var first_check := not _story_checked
	_story_checked = true
	if first_check and start_wave_idx > 0:
		for e in StoryScreen.load_entries():
			if int(e.get("before_stage", -1)) <= idx:
				_stories_seen[str(e.get("id", ""))] = true
	var entry: Dictionary = StoryScreen.entry_for_stage(idx)
	if entry.is_empty() or _stories_seen.has(str(entry.get("id", ""))):
		return {}
	_stories_seen[str(entry.get("id", ""))] = true
	return entry

func show_story(entry: Dictionary, banner: String = "") -> void:
	if overlay_layer == null:
		return
	story_active = true
	get_tree().paused = true
	Controls.reset()
	var sc := StoryScreen.new()
	sc.setup(entry)
	sc.finished.connect(func():
		story_active = false
		clear_overlay()
		get_tree().paused = false
		Controls.reset()
		if banner != "" and hud != null:
			hud.show_banner(banner, 2.4))
	set_overlay(sc)

# ------------------------------------------------------------------ zdarzenia walki

func on_hit(attacker: Actor, target, defn: Dictionary, dmg: float, stagger: bool) -> void:
	var heavy: bool = float(defn["damage"]) >= 30.0
	var pos: Vector2 = target.position + Vector2(0, -60)
	if fx != null:
		fx.burst(pos, 7 if not heavy else 12, Color(0.75, 0.10, 0.08) if target is Actor else Color(0.7, 0.5, 0.3), 160.0 if not heavy else 260.0, attacker.facing)
	Sfx.play(str(defn.get("hit_sfx", "hit")))
	if attacker.team == 0:
		freeze_time = maxf(freeze_time, float(Balance.world("hitstop_player_hit")) * (1.8 if heavy else 1.0))
		shake = maxf(shake, 4.0 if not heavy else 9.0)
	else:
		freeze_time = maxf(freeze_time, float(Balance.world("hitstop_enemy_hit")))
		shake = maxf(shake, 8.0)
		Sfx.play("player_hurt")
		if hud != null:
			hud.flash_damage()

func on_actor_died(a: Actor) -> void:
	if a.team == 1:
		GameState.add_kill((a as Enemy).score_value)
		Sfx.play("enemy_die")
		if a is Boss:
			on_boss_defeated(a)
		elif randf() < float(Balance.world("potion_drop_chance")):
			drop_pickup(a.position, "slime" if stage_idx >= 3 and randf() < 0.3 else "potion")
		if fx != null:
			fx.burst(a.position + Vector2(0, -50), 16, Color(0.5, 0.05, 0.05), 220.0, a.facing)
	else:
		Sfx.play("player_die")
		Sfx.stop_music()
		outcome = "lost"
		outcome_t = 0.0

func on_boss_phase(b: Boss, phase: int) -> void:
	shake = 14.0
	if hud != null:
		hud.show_banner("FAZA %d" % phase, 1.8)

func on_boss_defeated(b: Boss) -> void:
	for e in enemies:
		if e != b and e.is_alive():
			e.hp = 0.0
			e.die(1, { "knockback": 120.0 })
	spawn_queue.clear()
	shake = 18.0
	freeze_time = 0.25
	Sfx.stop_music(1.2)

## Obrażenia od przeszkód (ogień, upadek): krótki efekt i dźwięk, bez przerywania akcji.
func on_hazard_hit(target: Actor, dmg: float) -> void:
	if fx != null:
		fx.burst(target.position + Vector2(0, -50), 8, Color(0.85, 0.35, 0.1), 180.0, 1)
	Sfx.play("player_hurt")
	shake = maxf(shake, 7.0)
	if hud != null:
		hud.flash_damage()

## Pierwsza przeszkoda przed graczem w zasięgu max_dist (albo null) - dla podpowiedzi i bota testowego.
func next_obstacle_ahead(x: float, max_dist: float) -> Obstacle:
	var best: Obstacle = null
	for o in obstacles:
		if o.x1() > x - 10.0 and o.x0() - x < max_dist:
			if best == null or o.x0() < best.x0():
				best = o
	return best

func update_jump_hint() -> void:
	if _jump_hint_shown or hud == null or story_active:
		return
	var o := next_obstacle_ahead(player.position.x, 520.0)
	if o != null and o.x0() > player.position.x:
		_jump_hint_shown = true
		hud.show_banner("SPACJA - SKOK (przeszkody!)", 2.6)

func on_barrel_broken(b: Barrel) -> void:
	GameState.add_score(int(data.get("barrel_score", Balance.data.get("score", {}).get("barrel", 20))))
	if fx != null:
		fx.burst(b.position + Vector2(0, -30), 12, Color(0.45, 0.3, 0.15), 200.0, 1)
	if stage_idx >= 3 and randf() < 0.38:
		drop_pickup(b.position, "slime")             # w legowisku z beczek wylewa się spaczenie
	elif randf() < float(Balance.world("barrel_potion_chance")):
		drop_pickup(b.position)
	barrels.erase(b)
	b.queue_free()

func drop_pickup(pos: Vector2, kind: String = "potion") -> void:
	var p := Pickup.new()
	var amount: float = float(Balance.world("potion_heal")) if kind == "potion" else float(Balance.world("slime_damage"))
	p.setup(self, Vector2(pos.x, clampf(pos.y, lane_min(), lane_max())), amount, kind)
	entities.add_child(p)
	pickups.append(p)

# ------------------------------------------------------------------ zakończenie

func check_outcome(delta: float) -> void:
	if outcome == "":
		if boss != null and not boss.is_alive() and alive_enemy_count() == 0:
			outcome = "won"
			outcome_t = 0.0
			player.victory()
			Sfx.play("victory")
		return
	outcome_t += delta
	if outcome == "lost" and outcome_t > 1.6 and overlay == null and not simulate_only:
		Sfx.play("defeat")
		SaveData.submit_score(GameState.score)
		show_defeat()
	elif outcome == "won" and outcome_t > 3.0 and overlay == null and not simulate_only:
		SaveData.submit_score(GameState.score)
		SaveData.clear_checkpoint()
		show_victory()

func show_defeat() -> void:
	var box := UI.make_overlay("PORAŻKA", "Wynik: %d\nPokonani wrogowie: %d" % [GameState.score, GameState.kills], [
		["Ponów próbę", func(): restart_requested.emit()],
		["Powrót do menu", func(): exit_to_menu.emit()],
	])
	set_overlay(box)

func show_victory() -> void:
	var box := UI.make_overlay("ZWYCIĘSTWO!", "Hufduhof ocalony.\nWynik: %d\nPokonani wrogowie: %d\nNajlepszy wynik: %d" % [GameState.score, GameState.kills, SaveData.best_score], [
		["Zagraj ponownie", func(): restart_requested.emit()],
		["Powrót do menu", func(): exit_to_menu.emit()],
	])
	set_overlay(box)

func set_overlay(box: Control) -> void:
	clear_overlay()
	overlay = box
	overlay_layer.add_child(box)

func clear_overlay() -> void:
	if overlay != null:
		overlay.queue_free()
		overlay = null

func toggle_pause() -> void:
	if outcome != "" or simulate_only or story_active:
		return
	if get_tree().paused:
		resume()
	else:
		get_tree().paused = true
		Controls.reset()
		var box := UI.make_overlay("PAUZA", "", [
			["Wznów", func(): resume()],
			["Uruchom poziom ponownie", func(): restart_requested.emit()],
			["Wróć do menu", func(): exit_to_menu.emit()],
		])
		set_overlay(box)

func resume() -> void:
	get_tree().paused = false
	clear_overlay()
	Controls.reset()

func _exit_tree() -> void:
	if world_vp != null and get_viewport().size_changed.is_connected(fit_world):
		get_viewport().size_changed.disconnect(fit_world)
	get_tree().paused = false
	if Controls.pause_pressed.is_connected(toggle_pause):
		Controls.pause_pressed.disconnect(toggle_pause)
