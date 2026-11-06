class_name Tavern
extends Level
## Minigra wstępna: impreza w karczmie "Pod Złotym Kuflem".
##  1. Impreza - karczmarz rzuca kufle; na podłodze widać cień (koło), gdzie kufel spadnie. Stań w nim na czas.
##     To nauka ruchu i czytania zapowiedzi (te same koła/pasy zapowiadają potem ataki wrogów).
##  2. Skaveny wyważają drzwi - dwie fale wrogów (nauka ataku, umiejętności, mikstur).
##  3. Po walce wyjście drzwiami do wioski (Interakcja).
## Liczby: data/levels/karczma.json -> "impreza", "fale".

enum Ph { PARTY, BREAKIN, FIGHT, CLEAR }

var ph: int = Ph.PARTY
var cfg: Dictionary = {}
var caught: int = 0
var missed: int = 0
var mug_t: float = 1.5
var mugs: Array = []
var wave: int = -1
var wave_t: float = 0.0
var door: Node = null
var door_cell := Vector2i(7, 0)
var keeper: Sprite2D
var keeper_pos := Vector2.ZERO
var t: float = 0.0
var mug_tex: Texture2D
var splash_tex: Texture2D

func _init() -> void:
	super("karczma")

func spawn_custom_object(o: Dictionary, p: Vector2) -> void:
	match str(o.get("typ", "")):
		"drzwi":
			var c: Array = o.get("komorka", [7, 0])
			door_cell = Vector2i(int(c[0]), int(c[1]))
			door = _add_obj(Obj.TavernDoor.new(), p)
			door.setup(self)
		"goscie":
			var i := 1
			for c in o.get("komorki", []):
				var sp := map.add_prop(map.prop_tex("guest_%d" % i), Vector2i(int(c[0]), int(c[1])))
				if sp:
					sp.flip_h = i % 2 == 0
				map.blocked[Vector2i(int(c[0]), int(c[1]))] = true
				i += 1
		"karczmarz":
			keeper_pos = p
			keeper = map.add_prop(map.prop_tex("innkeeper"), Iso.to_cell(p))
			map.blocked[Iso.to_cell(p)] = true

func after_ready() -> void:
	cfg = data.get("impreza", {})
	mug_tex = map.prop_tex("mug")
	splash_tex = map.prop_tex("splash")
	for y in map.size.y:
		for x in map.size.x:
			map.reveal(Iso.cell_center(Vector2i(x, y)), 0.5)
	var ctrl := "Ruch: joystick po lewej" if Save.touch_enabled() else "Ruch: WASD"
	hud.show_banner("Impreza w karczmie!\n%s. Karczmarz rzuca kufle - stań w cieniu, zanim kufel spadnie." % ctrl, 7.0)
	hud.refresh_quest()

func quest_lines() -> Array:
	match ph:
		Ph.PARTY:
			return ["Impreza w karczmie", "Złap kufle: %d/%d" % [caught, int(cfg.get("kufle_cel", 6))]]
		Ph.BREAKIN, Ph.FIGHT:
			return ["Obroń karczmę!", "Fala %d/%d   wrogowie: %d" % [wave + 1, data.get("fale", []).size(), alive_enemies()]]
	return ["Karczma obroniona", "Wyjdź drzwiami do wioski"]

func _physics_process(delta: float) -> void:
	super(delta)
	t += delta
	match ph:
		Ph.PARTY:
			_party(delta)
		Ph.BREAKIN:
			wave_t -= delta
			if wave_t <= 0.0:
				_start_wave(0)
		Ph.FIGHT:
			if alive_enemies() == 0:
				wave_t -= delta
				if wave_t <= 0.0:
					if wave + 1 < data.get("fale", []).size():
						_start_wave(wave + 1)
					else:
						_clear()
			else:
				wave_t = 1.5
	_update_mugs(delta)
	if keeper:
		keeper.position.y = keeper_pos.y + (sin(t * 6.0) * 2.0 if ph == Ph.PARTY else 0.0)

func _party(delta: float) -> void:
	mug_t -= delta
	if mug_t <= 0.0 and caught < int(cfg.get("kufle_cel", 6)):
		mug_t = float(cfg.get("odstep", 1.9))
		_throw_mug()

func _throw_mug() -> void:
	var spread := float(cfg.get("rozrzut", 150))
	var target := hero.position + Iso.screen(Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread)))
	var c := Iso.to_cell(target)
	if not map.is_walkable(c):
		target = hero.position + Iso.screen(Vector2(rng.randf_range(-60, 60), rng.randf_range(-60, 60)))
		if not map.is_walkable(Iso.to_cell(target)):
			target = hero.position
	var spr := Sprite2D.new()
	spr.texture = mug_tex
	map.world.add_child(spr)
	var shadow := Fx.marker(decal_parent(), target, "circle", Vector2.RIGHT, float(cfg.get("promien_zlapania", 30)), 0.0, Color(1.0, 0.85, 0.35))
	mugs.append({"spr": spr, "from": keeper_pos + Vector2(0, -60), "to": target, "t": 0.0, "dur": float(cfg.get("czas_lotu", 1.35)), "shadow": shadow})
	Audio.play("swing", 1.8)

func _update_mugs(delta: float) -> void:
	for m in mugs.duplicate():
		m["t"] += delta
		var k: float = clampf(m["t"] / m["dur"], 0.0, 1.0)
		var spr: Sprite2D = m["spr"]
		spr.position = (m["from"] as Vector2).lerp(m["to"], k) + Vector2(0, -sin(k * PI) * 160.0 - 20.0 * (1.0 - k))
		spr.rotation = k * TAU * 1.5
		(m["shadow"] as Fx).fill_progress = k
		if k >= 1.0:
			mugs.erase(m)
			m["shadow"].queue_free()
			if ph == Ph.PARTY and Iso.dist(hero.position, m["to"]) <= float(cfg.get("promien_zlapania", 30)) + hero.body_radius:
				caught += 1
				Audio.play("mug_catch")
				Fx.float_text(fx_top, hero.position + Vector2(0, -130), "+1 kufel", Color(1.0, 0.85, 0.35), true)
				spr.queue_free()
				hud.refresh_quest()
				if caught >= int(cfg.get("kufle_cel", 6)):
					_break_in()
			else:
				missed += 1
				Audio.play("mug_break")
				spr.texture = splash_tex
				spr.rotation = 0
				spr.position = m["to"]
				var tw := spr.create_tween()
				tw.tween_interval(0.8)
				tw.tween_callback(spr.queue_free)

func _break_in() -> void:
	ph = Ph.BREAKIN
	wave_t = 1.6
	hud.show_banner("Borubar: \"Na Sigmara! Coś drapie w drzwi...\"", 3.0)
	await get_tree().create_timer(1.2).timeout
	if door:
		door.burst()
	Audio.play("door")
	shake(9.0)
	Audio.play_track("walka")
	hud.refresh_quest()

func _start_wave(i: int) -> void:
	wave = i
	ph = Ph.FIGHT
	wave_t = 1.5
	var w: Dictionary = data["fale"][i]
	hud.show_banner(str(w.get("podpowiedz", "")), 7.0)
	var list: Array = w.get("wrogowie", [])
	for j in list.size():
		var cell := door_cell + Vector2i(j - list.size() / 2, 1)
		if not map.is_walkable(cell):
			cell = door_cell + Vector2i(0, 1)
		var e := spawn_enemy(str(list[j]), Iso.cell_center(cell) + Vector2(rng.randf_range(-10, 10), 0), "fala_%d" % i, "")
		e.home = hero.position
		e.edef = e.edef.duplicate()
		e.edef["zasieg_wykrycia"] = 2000
		e.wake()
	hud.refresh_quest()

func enemy_killed(_e: Enemy) -> void:
	hud.refresh_quest()
	if wave == 0 and alive_enemies() == 0:
		hud.show_banner("Ranny? Mikstura życia: przycisk ŻYCIE (PC: Q). Piwo leczy życie i manę.", 5.0)

func _clear() -> void:
	ph = Ph.CLEAR
	Game.quest_xp("karczma_obroniona")
	if door:
		door.can_leave = true
	Audio.play_track("karczma")
	hud.show_banner("Karczma obroniona! Ale z wioski dobiegają krzyki...\nPodejdź do wyważonych drzwi i użyj INTERAKCJI (PC: E).", 8.0)
	hud.refresh_quest()

func talk_to_npc(_id: String) -> void:
	var lines: Array = Data.dialog("borubar_karczma")
	if ph == Ph.CLEAR:
		lines = Data.dialog("borubar_karczma_po")
	open_overlay(DialogBox.build("Borubar", "res://assets/characters/borubar/portrait.png", lines, [["Do widzenia", close_overlay]]))

func leave_tavern() -> void:
	Game.level_id = "wioska"
	Game.spawn_pos = null
	request.emit("wioska")
