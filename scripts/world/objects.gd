class_name Obj
extends RefCounted
## Obiekty interaktywne poziomów (podklasy Interactable): skrzynia, kapliczka, studnia, wiadro,
## część barykady, NPC, strefa wyjścia, drzwi karczmy. Tworzenie: Obj.Chest.new() itd.


class Chest extends Interactable:
	var opened: bool = false
	func setup(lvl: Node, id: String) -> void:
		level = lvl
		uid = id
		opened = Game.has_flag("skrzynie", uid)
		set_sprite(level.map.prop_tex("chest_open" if opened else "chest_closed"))
	func can_interact(_h: Hero) -> bool:
		return not opened
	func interact_label(_h: Hero) -> String:
		return "Otwórz skrzynię"
	func interact(_h: Hero) -> void:
		opened = true
		Game.add_flag("skrzynie", uid)
		set_sprite(level.map.prop_tex("chest_open"))
		Audio.play("chest")
		level.drop_loot(position, Loot.roll_table("skrzynia", Game.rng))


class Shrine extends Interactable:
	var kind: String = "ulryk"
	var used: bool = false
	var t: float = 0.0
	func setup(lvl: Node, id: String, k: String) -> void:
		level = lvl
		uid = id
		kind = k
		used = Game.has_flag("kapliczki", uid)
		interact_radius = 80.0
		_refresh()
	func _refresh() -> void:
		set_sprite(level.map.prop_tex("shrine_%s%s" % [kind, "_used" if used else ""]))
	func can_interact(_h: Hero) -> bool:
		return not used
	func interact_label(_h: Hero) -> String:
		return "Pomódl się: " + str(Data.shrine(kind).get("nazwa", "kapliczka"))
	func interact(h: Hero) -> void:
		var d := Data.shrine(kind)
		match str(d.get("efekt", "")):
			"niezniszczalnosc":
				h.blessed = float(d.get("czas", 8.0))
			"leczenie":
				h.heal(h.get_max_hp() * float(d.get("procent", 100)) / 100.0)
				h.dots.clear()
		Game.notify(str(d.get("komunikat", "")), Color(1.0, 0.9, 0.55))
		Audio.play("shrine")
		Fx.ring(level.decal_parent(), position, 60.0, Color(1.0, 0.9, 0.5), 0.6)
		var uses := int(d.get("uzycia", 1))
		var n := int(Game.flags.get("kapliczki_uzycia", {}).get(uid, 0)) + 1
		if not Game.flags.has("kapliczki_uzycia"):
			Game.flags["kapliczki_uzycia"] = {}
		Game.flags["kapliczki_uzycia"][uid] = n
		if n >= uses:
			used = true
			Game.add_flag("kapliczki", uid)
			_refresh()
	func _process(delta: float) -> void:
		t += delta
		if spr and not used:
			spr.modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.25, 1.15, 0.85), 0.5 + 0.5 * sin(t * 3.0))


class Well extends Interactable:
	func setup(lvl: Node) -> void:
		level = lvl
		interact_radius = 95.0
		set_sprite(level.map.prop_tex("well"))
	func can_interact(_h: Hero) -> bool:
		return true
	func interact_label(_h: Hero) -> String:
		if Game.quest.carrying_empty() > 0:
			return "Napełnij wiadra (%d)" % Game.quest.carrying_empty()
		return "Studnia"
	func interact(_h: Hero) -> void:
		var n := Game.quest.fill_at_well()
		if n > 0:
			Audio.play("fill")
			Game.notify("Napełniono wiadra: %d" % n, Color(0.6, 0.8, 1.0))
			Game.quest_changed.emit()
			level.autosave()
		elif Game.quest.found_count() == 0:
			Game.notify("Potrzebujesz wiadra, żeby nabrać wody.", Color(0.85, 0.85, 0.85))
		else:
			Game.notify("Nie masz pustych wiader.", Color(0.85, 0.85, 0.85))


class Bucket extends Interactable:
	var bob: float = 0.0
	func setup(lvl: Node, id: String) -> void:
		level = lvl
		uid = id
		interact_radius = 60.0
		set_sprite(level.map.prop_tex("bucket_empty"), 4.0)
		if uid in Game.quest.found:
			queue_free()
	func interact_label(_h: Hero) -> String:
		return "Podnieś wiadro"
	func interact(_h: Hero) -> void:
		if Game.quest.pick_bucket(uid):
			Audio.play("pickup")
			Game.notify("Znaleziono wiadro! (%d/%d)" % [Game.quest.found_count(), Game.quest.total], Color(0.6, 0.85, 1.0))
			Game.quest_xp("wiadro_znalezione")
			Game.quest_changed.emit()
			level.autosave()
			queue_free()
	func _process(delta: float) -> void:
		bob += delta
		if spr:
			spr.position.y = -absf(sin(bob * 2.0)) * 4.0


class BarricadePart extends Interactable:
	## Jedna część płonącej barykady: blokuje przejście (kolizja), parzy przy dotyku, gaśnie od pełnego wiadra.
	var index: int = 0
	var burning: bool = true
	var cell := Vector2i.ZERO
	var body: StaticBody2D
	var fire: Sprite2D
	var fire_frames: Array = []
	var t: float = 0.0
	var burn_tick: float = 0.0
	func setup(lvl: Node, id: String, idx: int, c: Vector2i) -> void:
		level = lvl
		uid = id
		index = idx
		cell = c
		interact_radius = 95.0
		burning = idx >= Game.quest.poured
		for i in 4:
			var p := "res://assets/levels/common/fx/fire_%d.png" % i
			if ResourceLoader.exists(p):
				fire_frames.append(load(p))
		fire = Sprite2D.new()
		fire.centered = false
		add_child(fire)
		body = StaticBody2D.new()
		body.collision_layer = 1
		var cp := CollisionPolygon2D.new()
		var poly := LevelMap.run_polygon(c.x, c.x, c.y, 0.04)
		var local := PackedVector2Array()
		for p in poly:
			local.append(p - position)
		cp.polygon = local
		body.add_child(cp)
		add_child(body)
		_refresh()
	func _refresh() -> void:
		set_sprite(level.map.prop_tex("barricade" if burning else "barricade_burnt"))
		fire.visible = burning
		body.process_mode = Node.PROCESS_MODE_INHERIT if burning else Node.PROCESS_MODE_DISABLED
		body.collision_layer = 1 if burning else 0
	func can_interact(_h: Hero) -> bool:
		return burning and index == Game.quest.poured
	func interact_label(_h: Hero) -> String:
		if Game.quest.carrying_full() > 0:
			return "Wylej wodę na ogień"
		return "Płonąca barykada"
	func interact(_h: Hero) -> void:
		if Game.quest.carrying_full() <= 0:
			if Game.quest.carrying_empty() > 0:
				Game.notify("Wiadra są puste - napełnij je przy studni na placu.", Color(0.85, 0.85, 0.85))
			else:
				Game.notify("Potrzebujesz wody. Szukaj wiader we wsi.", Color(0.85, 0.85, 0.85))
			return
		if Game.quest.pour_on_barricade():
			Audio.play("splash")
			Fx.ring(level.decal_parent(), position, 50.0, Color(0.6, 0.8, 1.0), 0.5)
			Game.quest_xp("barykada_czesc")
			level.on_barricade_part_out()
			Game.quest_changed.emit()
	func extinguish_visual() -> void:
		burning = false
		_refresh()
	func _process(delta: float) -> void:
		t += delta
		if burning and not fire_frames.is_empty():
			var f: Texture2D = fire_frames[int(t * 8.0) % fire_frames.size()]
			fire.texture = f
			fire.offset = Vector2(-f.get_width() / 2.0, -f.get_height() + 6.0)
		if burning and level.hero and not level.hero.is_dead():
			if Iso.dist(level.hero.position, position) <= 64.0 + float(Data.bal("barykada/zasieg_dotyku", 18)):
				burn_tick -= delta
				if burn_tick <= 0.0:
					burn_tick = float(Data.bal("barykada/co_ile_sekund", 0.6))
					level.hero.apply_damage(float(Data.bal("barykada/obrazenia", 6)), "ogien")
			else:
				burn_tick = 0.0


class Npc extends Interactable:
	var npc_id: String = "borubar"
	var gfx: DirSprite
	var t: float = 0.0
	func setup(lvl: Node, id: String) -> void:
		level = lvl
		npc_id = id
		interact_radius = 90.0
		gfx = DirSprite.new()
		add_child(gfx)
		gfx.setup("res://assets/characters/borubar")
		var lbl := Label.new()
		lbl.text = "Borubar"
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.size = Vector2(120, 20)
		lbl.position = Vector2(-60, -160)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(lbl)
	func interact_label(_h: Hero) -> String:
		return "Rozmawiaj z Borubarem"
	func interact(_h: Hero) -> void:
		level.talk_to_npc(npc_id)
	func _process(delta: float) -> void:
		t += delta
		if gfx:
			gfx.bob = -absf(sin(t * 5.0)) * 2.0   # trzęsie się ze strachu
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.35))


class ExitZone extends Interactable:
	var radius_cells: float = 2.0
	var open: bool = false
	func setup(lvl: Node, r: float) -> void:
		level = lvl
		radius_cells = r
		interact_radius = 0.0
	func can_interact(_h: Hero) -> bool:
		return false
	func _physics_process(_d: float) -> void:
		if open and level.hero and not level.hero.is_dead():
			if Iso.dist(level.hero.position, position) <= radius_cells * 64.0:
				open = false
				level.on_exit_reached()


class TavernDoor extends Interactable:
	var broken: bool = false
	var can_leave: bool = false
	func setup(lvl: Node) -> void:
		level = lvl
		interact_radius = 100.0
		set_sprite(level.map.prop_tex("door_closed"))
	func burst() -> void:
		broken = true
		set_sprite(level.map.prop_tex("door_broken"))
	func can_interact(_h: Hero) -> bool:
		return can_leave
	func interact_label(_h: Hero) -> String:
		return "Wyjdź do wioski"
	func interact(_h: Hero) -> void:
		level.leave_tavern()
