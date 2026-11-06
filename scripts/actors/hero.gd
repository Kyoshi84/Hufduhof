class_name Hero
extends Actor
## Bohater sterowany przez gracza. Ruch w 8 kierunkach (miara podłoża izometrycznego), ciężki atak
## z wyraźnym zamachem (fazy z Rules.attack_phases), umiejętność/czar, mikstury, interakcja.

signal action_hint_changed

var hs: HeroState
var hdef: Dictionary
var atk: Dictionary
var skill: Dictionary
var action: String = ""            # "atak" / "umiejetnosc"
var atk_mode: String = "wrecz"     # atak mieszany: "wrecz" (z bliska) albo "pocisk" (z dystansu)
var phases: Array = [0.5, 0.1, 0.6]
var hit_done: bool = false
var skill_cd: float = 0.0
var potion_cd: float = 0.0
var aim := Vector2.ZERO
var skill_target := Vector2.ZERO
var mouse_atk: bool = false
var mouse_skill: bool = false
var mouse_world := Vector2.ZERO
var use_mouse_aim: bool = false
var near_interactable: Node = null
var walk_t: float = 0.0
var input_locked: bool = false     # dialogi, przerywniki
var ui_cooldown: float = 0.0       # chwila po zamknięciu okna: ten sam klawisz nie otwiera go ponownie
var can_fight: bool = true         # w karczmie gramy Borubarem, który nie walczy
var mana_acc: float = 0.0
var _marker: Fx = null
var _reveal_t: float = 0.0

func setup(hero_state: HeroState) -> void:
	hs = hero_state
	stats = hs.stats
	hdef = Data.hero(hs.id)
	atk = hdef.get("atak", {})
	skill = hdef.get("umiejetnosc", {})
	faction = 0
	setup_body(13.0, 2, 1 | 4)
	gfx = DirSprite.new()
	add_child(gfx)
	gfx.setup(str(hdef.get("grafika", "res://assets/characters/ivo")))
	hp = hs.hp
	add_to_group("heroes")

## Podmiana grafiki (w karczmie gramy najpierw Borubarem).
func set_look(path: String) -> void:
	if gfx:
		gfx.queue_free()
	gfx = DirSprite.new()
	add_child(gfx)
	gfx.setup(path)

func get_max_hp() -> int:
	return hs.max_hp()

func armor() -> int:
	return hs.inv.armor_defense()

func weapon_dmg() -> int:
	return hs.inv.weapon_damage()

func gfx_height() -> float:
	return 118.0

func _physics_process(delta: float) -> void:
	tick_common(delta)
	hs.hp = hp
	if is_dead():
		gfx.play("death", Iso.dir_name(facing))
		return
	skill_cd = maxf(0.0, skill_cd - delta)
	potion_cd = maxf(0.0, potion_cd - delta)
	ui_cooldown = maxf(0.0, ui_cooldown - delta)
	if hs.max_mana() > 0:
		hs.mana = minf(hs.max_mana(), hs.mana + Rules.mana_regen(stats.val("SW")) * delta)
	if state in [St.WINDUP, St.STRIKE, St.RECOVER]:
		_process_action(delta)
	elif state == St.HURT:
		velocity = Vector2.ZERO
		if state_t > float(Data.bal("walka/zachwianie_czas", 0.3)):
			set_state(St.IDLE)
	else:
		_process_free(delta)
	move_and_slide()
	_animate(delta)
	_reveal_t -= delta
	if _reveal_t <= 0.0 and level:
		_reveal_t = 0.15
		level.reveal_around(position)
	_check_pickups()
	_update_interactable()

func _process_free(_delta: float) -> void:
	var mv: Vector2 = Vector2.ZERO if input_locked else Controls.move_vector()
	if mv.length() > 0.1:
		facing = Iso.screen(mv).normalized()
		velocity = Iso.screen(mv.limit_length(1.0)) * stats.move_speed()
		state = St.MOVE
	else:
		velocity = Vector2.ZERO
		state = St.IDLE
	if input_locked or ui_cooldown > 0.0:
		return
	if Input.is_action_just_pressed("interakcja"):
		interact()
	if not can_fight:
		return
	if Input.is_action_pressed("atak") or mouse_atk:
		start_attack()
	elif Input.is_action_just_pressed("umiejetnosc") or mouse_skill:
		mouse_skill = false
		start_skill()
	if Input.is_action_just_pressed("mikstura_zycia"):
		use_belt("mikstura_zycia")
	if Input.is_action_just_pressed("mikstura_many"):
		use_belt("mikstura_many")

# ---------------------------------------------------------------- atak podstawowy
func _aim_dir(reach: float) -> Vector2:
	if use_mouse_aim:
		var d := mouse_world - position
		if d.length() > 4.0:
			return d.normalized()
	var mv := Controls.move_vector()
	var target := nearest_enemy(reach + float(Data.bal("walka/auto_cel_zasieg", 60)))
	if target and (mv.length() < 0.1 or Iso.in_arc(position, Iso.screen(mv), target.position, reach + 80.0, 100.0)):
		return (target.position - position).normalized()
	if mv.length() > 0.1:
		return Iso.screen(mv).normalized()
	return facing

func nearest_enemy(max_d: float) -> Actor:
	var best: Actor = null
	var bd := max_d
	if level == null:
		return null
	for e in level.enemies():
		if e.is_dead():
			continue
		var d: float = Iso.dist(position, e.position) - e.body_radius
		if d < bd:
			bd = d
			best = e
	return best

func start_attack() -> void:
	if state in [St.WINDUP, St.STRIKE, St.RECOVER, St.DEAD]:
		return
	action = "atak"
	atk_mode = str(atk.get("typ", "wrecz"))
	var reach := float(atk.get("zasieg", 80))
	if atk_mode == "mieszany":
		# z bliska broń wręcz (kostur / nóż), dalej pocisk (ognisty pocisk / strzała)
		var close: Dictionary = atk.get("wrecz", {})
		var near := nearest_enemy(float(close.get("zasieg", 60)) + 12.0)
		var shot: Dictionary = atk.get("pocisk", {})
		var cost := float(shot.get("koszt_many", 0))
		if near:
			atk_mode = "wrecz"
			reach = float(close.get("zasieg", 60))
		elif cost > 0.0 and hs.mana < cost:
			if Input.is_action_just_pressed("atak") or mouse_atk:
				Game.notify("Brak many na %s!" % str(shot.get("nazwa", "pocisk")).to_lower(), Color(0.5, 0.7, 1.0))
			mouse_atk = false
			return
		else:
			atk_mode = "pocisk"
			reach = float(shot.get("zasieg", 360))
			hs.mana -= cost
	phases = Rules.attack_phases(stats.val("A"), stats.val("Zr"))
	aim = _aim_dir(reach)
	facing = aim
	hit_done = false
	velocity = Vector2.ZERO
	set_state(St.WINDUP)

func start_skill() -> void:
	if state in [St.WINDUP, St.STRIKE, St.RECOVER, St.DEAD] or skill.is_empty():
		return
	if skill_cd > 0.0:
		Game.notify("%s: odnowienie %.0f s" % [skill.get("nazwa", ""), ceil(skill_cd)], Color(0.8, 0.8, 0.8))
		return
	var cost := float(skill.get("koszt_many", 0))
	if cost > 0.0 and hs.mana < cost:
		Game.notify("Brak many!", Color(0.5, 0.7, 1.0))
		return
	var typ := str(skill.get("typ", ""))
	if typ == "piorun":
		var t := nearest_enemy(float(skill.get("zasieg", 300)))
		if use_mouse_aim and (mouse_world - position).length() > 10.0:
			skill_target = mouse_world
		elif t:
			skill_target = t.position
		else:
			Game.notify("Brak celu w zasięgu", Color(0.8, 0.8, 0.8))
			return
		aim = (skill_target - position).normalized()
		if level:
			_marker = Fx.marker(level.decal_parent(), skill_target, "circle", Vector2.RIGHT, float(skill.get("promien", 70)), 0.0, Color(0.5, 0.75, 1.0))
	else:
		aim = _aim_dir(float(skill.get("zasieg", 90)))
	hs.mana -= cost
	action = "umiejetnosc"
	var wind := float(skill.get("zamach", 0.6))
	phases = [wind, 0.1, wind * 0.8]
	facing = aim
	hit_done = false
	velocity = Vector2.ZERO
	set_state(St.WINDUP)

func _process_action(_delta: float) -> void:
	velocity = Vector2.ZERO
	match state:
		St.WINDUP:
			if _marker:
				_marker.fill_progress = state_t / phases[0]
			if state_t >= phases[0]:
				set_state(St.STRIKE)
				_do_strike()
		St.STRIKE:
			if state_t >= phases[1]:
				set_state(St.RECOVER)
		St.RECOVER:
			# ruch może przerwać końcówkę powrotu (po połowie), atak przytrzymany = kolejny zamach
			var mv := Controls.move_vector()
			if state_t >= phases[2] or (state_t >= phases[2] * 0.5 and mv.length() > 0.3 and not input_locked):
				set_state(St.IDLE)
				action = ""

func _do_strike() -> void:
	if action == "umiejetnosc":
		skill_cd = float(skill.get("odnowienie", 3.0))
		_do_skill()
		return
	if str(atk.get("typ", "")) == "mieszany":
		if atk_mode == "wrecz":
			var close: Dictionary = atk.get("wrecz", {})
			Audio.play(str(close.get("dzwiek", "swing")))
			if level:
				Fx.slash(level.fx_parent(), position + Vector2(0, -34), aim, float(close.get("zasieg", 60)), float(close.get("luk_stopni", 90)), Color(0.85, 0.85, 0.9))
			var dmg_override := int(close.get("obrazenia", -1))
			_melee_hits(float(close.get("zasieg", 60)), float(close.get("luk_stopni", 90)), int(close.get("max_celow", 1)), 1.0, 0, "fiz", dmg_override)
		else:
			_shoot(atk.get("pocisk", {}), aim)
		return
	match str(atk.get("typ", "wrecz")):
		"wrecz":
			var reach := float(atk.get("zasieg", 80))
			var arc := float(atk.get("luk_stopni", 110))
			Audio.play(str(atk.get("dzwiek", "swing")))
			if level:
				Fx.slash(level.fx_parent(), position + Vector2(0, -34), aim, reach, arc, Color(0.85, 0.85, 0.9))
			_melee_hits(reach, arc, int(atk.get("max_celow", 1)), 1.0, 0, "fiz")
		"pocisk":
			Audio.play(str(atk.get("dzwiek", "bolt")))
			if level:
				var dmg := weapon_dmg() + int(atk.get("obrazenia_bazowe", 0)) + int(floor(Rules.spell_power(stats.val("Int"), stats.val("Mag")) / 2.0))
				level.spawn_projectile(str(atk.get("pocisk", "magic_bolt")), self, position, aim, float(atk.get("predkosc", 340)), float(atk.get("zasieg", 360)), dmg)

## Pocisk bohatera: strzała (rzut na US przy trafieniu, obrażenia łuku + S - Wt) albo ognisty pocisk (czar, zawsze trafia).
func _shoot(shot: Dictionary, dir: Vector2, extra: Dictionary = {}) -> void:
	if level == null:
		return
	Audio.play(str(shot.get("dzwiek", "bolt")))
	var kind := str(shot.get("rodzaj", "arrow"))
	var opts := {"rzut": bool(shot.get("rzut", kind == "arrow"))}
	var dmg := weapon_dmg()
	if not opts["rzut"]:
		dmg = int(shot.get("obrazenia_bazowe", 0)) + int(floor(Rules.spell_power(stats.val("Int"), stats.val("Mag")) / 2.0)) + int(floor(weapon_dmg() / 2.0))
	opts.merge(extra, true)
	level.spawn_projectile(kind, self, position, dir, float(shot.get("predkosc", 340)), float(shot.get("zasieg", 360)), dmg, opts)

func _melee_hits(reach: float, arc: float, max_targets: int, mult: float, bonus: int, kind: String, dmg_override: int = -1) -> Array:
	var hits: Array = []
	if level == null:
		return hits
	var cands: Array = []
	for e in level.enemies():
		if not e.is_dead() and Iso.in_arc(position, aim, e.position, reach, arc, e.body_radius):
			cands.append(e)
	cands.sort_custom(func(a, b): return Iso.dist(position, a.position) < Iso.dist(position, b.position))
	for e in cands.slice(0, max_targets):
		var res := Rules.resolve_melee(stats, weapon_dmg() if dmg_override < 0 else dmg_override, e.stats, e.armor(), rng, mult, bonus)
		res["kind"] = kind
		e.receive_hit(res, self)
		if res["hit"]:
			hits.append(e)
	if not hits.is_empty() and level:
		level.hitstop(float(Data.bal("walka/zatrzymanie_trafienia", 0.05)))
		level.shake(2.5)
	return hits

func _do_skill() -> void:
	var typ := str(skill.get("typ", ""))
	match typ:
		"kula_ognia":
			_shoot({"rodzaj": "fireball", "predkosc": skill.get("predkosc", 300), "zasieg": skill.get("zasieg", 380), "rzut": false,
				"dzwiek": "fire", "obrazenia_bazowe": 0}, aim,
				{"czar_bazowe": int(skill.get("obrazenia_bazowe", 10)), "wybuch": float(skill.get("promien", 72)),
				 "podpalenie": [float(skill.get("podpalenie_na_sekunde", 3)), float(skill.get("podpalenie_czas", 3.0))], "skala": 1.8})
		"salwa":
			var n := int(skill.get("strzaly", 5))
			var spread := deg_to_rad(float(skill.get("rozrzut_stopni", 44)))
			var g := Iso.ground(aim).normalized()
			for i in n:
				var a := -spread / 2.0 + spread * i / maxf(1.0, n - 1)
				_shoot({"rodzaj": "arrow", "predkosc": skill.get("predkosc", 430), "zasieg": skill.get("zasieg", 420), "rzut": true, "dzwiek": "bolt"},
					Iso.screen(g.rotated(a)).normalized())
		"zamach":
			Audio.play("swing_heavy", 0.8)
			if level:
				Fx.slash(level.fx_parent(), position + Vector2(0, -30), aim, float(skill.get("zasieg", 95)), float(skill.get("luk_stopni", 220)), Color(1.0, 0.8, 0.5), 0.24)
			var hits := _melee_hits(float(skill.get("zasieg", 95)), float(skill.get("luk_stopni", 220)), int(skill.get("max_celow", 6)), float(skill.get("mnoznik_obrazen", 1.8)), 0, "fiz")
			for e in hits:
				e.knockback(Iso.ground(e.position - position).normalized() * float(skill.get("odrzut", 40)))
			if level:
				level.shake(5.0)
		"ogien":
			Audio.play("fire")
			if level:
				Fx.slash(level.fx_parent(), position + Vector2(0, -34), aim, float(skill.get("zasieg", 90)), float(skill.get("luk_stopni", 150)), Color(1.0, 0.5, 0.15), 0.22)
			var bonus := int(skill.get("obrazenia_bazowe", 6)) + Rules.spell_power(stats.val("Int"), stats.val("Mag"))
			var hits := _melee_hits(float(skill.get("zasieg", 90)), float(skill.get("luk_stopni", 150)), int(skill.get("max_celow", 4)), 1.0, bonus, "ogien")
			for e in hits:
				e.add_dot(float(skill.get("podpalenie_na_sekunde", 3)), float(skill.get("podpalenie_czas", 3.0)), "ogien")
		"piorun":
			Audio.play("lightning")
			if _marker:
				_marker.queue_free()
				_marker = null
			if level:
				Fx.bolt(level.fx_parent(), skill_target, Color(0.55, 0.75, 1.0))
				Fx.ring(level.decal_parent(), skill_target, float(skill.get("promien", 70)), Color(0.6, 0.8, 1.0))
				level.shake(4.0)
				for e in level.enemies():
					if not e.is_dead() and Iso.dist(e.position, skill_target) <= float(skill.get("promien", 70)) + e.body_radius:
						var dmg := Rules.spell_damage(int(skill.get("obrazenia_bazowe", 10)), stats, e.stats)
						e.receive_hit({"hit": true, "damage": dmg, "kind": "magia"}, self)

# ---------------------------------------------------------------- obrażenia i śmierć
func receive_hit(res: Dictionary, attacker: Actor = null) -> void:
	super(res, attacker)
	if res.get("hit", false):
		Audio.play("hurt")
		if level:
			level.shake(3.0)

func on_damaged(amount: float, kind: String) -> void:
	hs.hp = hp
	if kind == "fiz":
		invuln = float(Data.bal("walka/niezniszczalnosc_po_trafieniu", 0.25))
	if kind == "fiz" and amount >= get_max_hp() * float(Data.bal("walka/zachwianie_prog", 0.12)) and state in [St.IDLE, St.MOVE]:
		set_state(St.HURT)

func die() -> void:
	super()
	Audio.play("death")
	if _marker:
		_marker.queue_free()
		_marker = null
	if level:
		level.on_hero_died()

func revive(fraction: float) -> void:
	hp = maxf(1.0, get_max_hp() * fraction)
	hs.hp = hp
	set_state(St.IDLE)
	setup_collision_again()
	invuln = float(Data.bal("pp/niezniszczalnosc_po_odrodzeniu", 2.5))
	blessed = invuln
	dots.clear()

func setup_collision_again() -> void:
	collision_layer = 2
	collision_mask = 1 | 4

func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	hp = minf(get_max_hp(), hp + amount)
	hs.hp = hp
	if level:
		Fx.float_text(level.fx_parent(), position + Vector2(0, -126), "+%d" % int(amount), Color(0.4, 1.0, 0.4))

func restore_mana(amount: float) -> void:
	if hs.max_mana() <= 0 or amount <= 0.0:
		return
	hs.mana = minf(hs.max_mana(), hs.mana + amount)

## Mikstury z pasa (piwo leczy życie i manę naraz).
func use_belt(id: String) -> bool:
	if potion_cd > 0.0 or is_dead():
		return false
	var inv := hs.inv
	var pick := id
	if int(inv.belt.get(id, 0)) <= 0:
		# brak mikstury -> użyj piwa (odnawia jedno i drugie)
		if int(inv.belt.get("piwo", 0)) > 0:
			pick = "piwo"
		else:
			Game.notify("Brak: " + str(Data.belt_item(id).get("nazwa", id)), Color(0.8, 0.7, 0.6))
			return false
	if pick == "mikstura_many" and hs.max_mana() <= 0:
		Game.notify("Ta postać nie używa many", Color(0.8, 0.7, 0.6))
		return false
	inv.belt_use(pick)
	var eff: Dictionary = Data.bal("mikstury/" + pick, {})
	heal(float(eff.get("zycie", 0)))
	restore_mana(float(eff.get("mana", 0)))
	potion_cd = float(Data.bal("mikstury/odstep_sekund", 1.0))
	Audio.play("potion")
	Game.hero_changed.emit()
	return true

# ---------------------------------------------------------------- podnoszenie i interakcja
func _check_pickups() -> void:
	if level == null:
		return
	var r := float(Data.bal("walka/podnoszenie_zasieg", 30))
	for p in get_tree().get_nodes_in_group("pickup"):
		if p.is_inside_tree() and Iso.dist(position, p.position) <= r and p.can_pick():
			p.pick(self)

func _update_interactable() -> void:
	var best: Node = null
	var bd := 1e9
	if not input_locked:
		for n in get_tree().get_nodes_in_group("interactable"):
			if not n.can_interact(self):
				continue
			var d := Iso.dist(position, n.position)
			if d <= n.interact_radius and d < bd:
				bd = d
				best = n
	if best != near_interactable:
		near_interactable = best
		action_hint_changed.emit()

func interact() -> void:
	if near_interactable and is_instance_valid(near_interactable) and near_interactable.can_interact(self):
		near_interactable.interact(self)
		action_hint_changed.emit()

# ---------------------------------------------------------------- wygląd
func _animate(delta: float) -> void:
	var d := Iso.dir_name(facing)
	gfx.lunge = Vector2.ZERO
	gfx.bob = 0.0
	match state:
		St.MOVE:
			walk_t += delta * stats.move_speed() / 18.0
			if gfx.has_walk:
				gfx.play("walk", d)
			else:
				gfx.play("idle", d)
				gfx.bob = -absf(sin(walk_t)) * 3.0
				gfx.lunge = Vector2(0, 0)
		St.WINDUP:
			var p: float = state_t / maxf(0.01, phases[0])
			if gfx.has_attack:
				gfx.set_progress("attack", p * 0.75, d)
			else:
				gfx.play("idle", d)
				# odchylenie do tyłu = zamach (zapowiedź ciosu)
				gfx.lunge = -Iso.screen(Iso.ground(aim).normalized()) * 6.0 * p
				gfx.bob = -2.0 * p
		St.STRIKE, St.RECOVER:
			if gfx.has_attack:
				gfx.set_progress("attack", 0.8 + 0.2 * clampf(state_t / maxf(0.01, phases[2]), 0, 1), d)
			else:
				gfx.play("idle", d)
				var k := 1.0 - clampf(state_t / maxf(0.01, phases[2]), 0.0, 1.0)
				gfx.lunge = Iso.screen(Iso.ground(aim).normalized()) * 10.0 * k
		St.HURT:
			gfx.play("hurt", d)
			gfx.lunge = -Iso.screen(Iso.ground(facing).normalized()) * 4.0
		_:
			gfx.play("idle", d)

func draw_debug() -> void:
	super()
	if state == St.WINDUP or state == St.STRIKE:
		var reach := float(atk.get("zasieg", 80)) if action == "atak" else float(skill.get("zasieg", 90))
		var arc := float(atk.get("luk_stopni", 110)) if action == "atak" else float(skill.get("luk_stopni", 180))
		var g := Iso.ground(aim).normalized()
		var pts := PackedVector2Array([Vector2.ZERO])
		for i in 13:
			var a := g.angle() - deg_to_rad(arc) / 2.0 + deg_to_rad(arc) * i / 12.0
			pts.append(Iso.screen(Vector2.RIGHT.rotated(a) * reach))
		pts.append(Vector2.ZERO)
		draw_polyline(pts, Color(1, 0.2, 0.2) if state == St.STRIKE else Color(1, 0.9, 0.2), 1.5)
