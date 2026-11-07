class_name Hero
extends Actor
## Bohater sterowany przez gracza. Ruch w 8 kierunkach (miara podłoża izometrycznego), ciężki atak
## z wyraźnym zamachem (fazy z Rules.attack_phases), umiejętność/czar, mikstury, interakcja.

signal action_hint_changed
signal mana_denied          # próba użycia umiejętności bez many (pasek miga)

var hs: HeroState
var hdef: Dictionary
var weapon_atk: Dictionary         # zwykły atak bronią (bez many) - zapas
var skills: Dictionary = {}        # id -> definicja umiejętności (heroes.json)
var bar: Array = []                # 10 slotów paska (id umiejętności / mikstura / "")
var cooldowns: Dictionary = {}     # id -> pozostały czas odnowienia
var cur: Dictionary = {}           # umiejętność (albo atak bronią) w trakcie użycia
var cur_id: String = ""
var phases: Array = [0.2, 0.05, 0.2]
var aim := Vector2.ZERO
var potion_cd: float = 0.0
var dmg_buff: float = 0.0          # wzmocnienie obrażeń (Okrzyk), np. 0.4 = +40%
var dmg_buff_t: float = 0.0
var mouse_atk: bool = false        # LPM przytrzymany: atak główny
var mouse_skill: bool = false      # PPM przytrzymany: slot 2
var mouse_world := Vector2.ZERO
var use_mouse_aim: bool = false
var near_interactable: Node = null
var walk_t: float = 0.0
var input_locked: bool = false     # dialogi, przerywniki
var ui_cooldown: float = 0.0       # chwila po zamknięciu okna: ten sam klawisz nie otwiera go ponownie
var can_fight: bool = true         # w karczmie gramy Borubarem, który nie walczy
var _deny_t: float = 0.0
var _reveal_t: float = 0.0
var last_shot_dir := Vector2.ZERO  # do testów i diagnostyki

func setup(hero_state: HeroState) -> void:
	hs = hero_state
	stats = hs.stats
	hdef = Data.hero(hs.id)
	weapon_atk = hdef.get("atak_bronia", {})
	skills = hdef.get("umiejetnosci", {})
	bar = hdef.get("pasek", [])
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
	for k in cooldowns.keys():
		cooldowns[k] = maxf(0.0, cooldowns[k] - delta)
	potion_cd = maxf(0.0, potion_cd - delta)
	ui_cooldown = maxf(0.0, ui_cooldown - delta)
	_deny_t = maxf(0.0, _deny_t - delta)
	dmg_buff_t = maxf(0.0, dmg_buff_t - delta)
	if dmg_buff_t <= 0.0:
		dmg_buff = 0.0
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
	# przytrzymanie = ciągłe używanie (ogranicza je tylko odnowienie i mana)
	if Input.is_action_pressed("atak") or mouse_atk:
		primary()
	elif Input.is_action_pressed("umiejetnosc") or mouse_skill:
		use_slot(1)
	else:
		for i in bar.size():
			var act := "slot_%d" % (i + 1)
			var entry := str(bar[i])
			if skills.has(entry) and Input.is_action_pressed(act):
				use_slot(i)
				break
	for i in bar.size():
		var entry := str(bar[i])
		if entry in Inventory.BELT and Input.is_action_just_pressed("slot_%d" % (i + 1)):
			use_belt(entry)
	if Input.is_action_just_pressed("mikstura_zycia"):
		use_belt("mikstura_zycia")
	if Input.is_action_just_pressed("mikstura_many"):
		use_belt("mikstura_many")

# ---------------------------------------------------------------- pasek i umiejętności
func slot_entry(i: int) -> String:
	return str(bar[i]) if i >= 0 and i < bar.size() else ""

func skill_ready(id: String) -> bool:
	return float(cooldowns.get(id, 0.0)) <= 0.0

func can_afford(id: String) -> bool:
	return hs.mana >= float(skills.get(id, {}).get("koszt_many", 0))

func busy() -> bool:
	return state in [St.WINDUP, St.STRIKE, St.RECOVER, St.DEAD]

## Użycie slotu paska (klawisz 1-0, kliknięcie, dotyk).
func use_slot(i: int) -> String:
	var e := slot_entry(i)
	if e == "":
		return "pusty"
	if e in Inventory.BELT:
		return "ok" if use_belt(e) else "brak"
	return try_skill(e)

## Atak główny (LPM / J / przycisk ATAK): umiejętność ze slotu 1, a bez many - zwykły atak bronią.
func primary() -> void:
	if busy():
		return
	if try_skill(slot_entry(0)) == "mana":
		weapon_attack()

## Zwraca: "ok", "zajety", "odnowienie", "mana", "brak".
func try_skill(id: String) -> String:
	if not skills.has(id):
		return "brak"
	if busy():
		return "zajety"
	if not skill_ready(id):
		return "odnowienie"
	var sk: Dictionary = skills[id]
	var cost := float(sk.get("koszt_many", 0))
	if hs.mana < cost:
		_deny()
		return "mana"
	hs.mana -= cost
	cooldowns[id] = float(sk.get("odnowienie", 0.2))
	_begin(sk, id, [float(sk.get("zamach", 0.15)), 0.05, float(sk.get("powrot", 0.15))])
	return "ok"

func _deny() -> void:
	if _deny_t > 0.0:
		return
	_deny_t = float(Data.bal("mana/brak_many_sygnal_co", 0.4))
	Audio.play("no_mana")
	mana_denied.emit()

## Zwykły atak bronią (bez many): tempo z cechy A (i Zr), mnożone przez walka_bohatera/tempo_ataku_bronia.
func weapon_attack() -> void:
	if busy() or weapon_atk.is_empty():
		return
	var ph := Rules.attack_phases(stats.val("A"), stats.val("Zr"))
	var k := float(Data.bal("walka_bohatera/tempo_ataku_bronia", 1.0))
	var sk := weapon_atk.duplicate()
	sk["typ"] = "ciecie"
	sk["skalowanie"] = "bron"
	_begin(sk, "bron", [ph[0] * k, ph[1] * k, ph[2] * k])

func _begin(sk: Dictionary, id: String, ph: Array) -> void:
	cur = sk
	cur_id = id
	phases = ph
	aim = _aim_dir(float(sk.get("zasieg", 90)), _is_projectile(sk))
	facing = aim
	velocity = Vector2.ZERO
	set_state(St.WINDUP)

static func _is_projectile(sk: Dictionary) -> bool:
	return str(sk.get("typ", "")) in ["pocisk", "salwa"]

# ---------------------------------------------------------------- celowanie
## Kierunek ataku liczony w chwili WYPUSZCZENIA (nie na początku zamachu), dokładnie w cel - nie zaokrąglany
## do 8 kierunków animacji. Mysz: wróg pod kursorem albo punkt na ziemi (korekta wysokości lotu pocisku).
## Joystick / klawiatura: kierunek ruchu z pomocą w celowaniu, bez ruchu - najbliższy wróg w zasięgu.
func _aim_dir(reach: float, projectile: bool) -> Vector2:
	var cone := float(Data.bal("celowanie/stozek_stopni", 30))
	if use_mouse_aim:
		var hovered := enemy_under_cursor()
		if hovered:
			return (hovered.position - position).normalized()
		var ground_pt := mouse_world
		if projectile:
			ground_pt += Vector2(0, float(Data.bal("celowanie/wysokosc_pocisku", 48)))
		var d := ground_pt - position
		if d.length() > 4.0:
			var soft := soft_target(d, reach, cone)
			return (soft.position - position).normalized() if soft else d.normalized()
	var mv := Controls.move_vector()
	if mv.length() > 0.1:
		var dir := Iso.screen(mv).normalized()
		var soft := soft_target(dir, reach + 40.0, cone * 1.5)
		return (soft.position - position).normalized() if soft else dir
	var target := nearest_enemy(reach + float(Data.bal("walka/auto_cel_zasieg", 60)))
	if target:
		return (target.position - position).normalized()
	var soft := soft_target(facing, reach + 60.0, cone * 2.0)
	return (soft.position - position).normalized() if soft else facing

## Wróg, którego sprite jest pod kursorem myszy (klik w korpus = cel w stopy tego wroga).
func enemy_under_cursor() -> Actor:
	if level == null:
		return null
	var px := float(Data.bal("celowanie/kursor_na_wrogu_px", 30))
	var best: Actor = null
	var bd := INF
	for e in level.enemies():
		if e.is_dead():
			continue
		var dx := absf(mouse_world.x - e.position.x)
		var top: float = e.position.y - e.gfx_height()
		if dx <= px and mouse_world.y >= top and mouse_world.y <= e.position.y + 12.0:
			var d := mouse_world.distance_to(e.position + Vector2(0, -e.gfx_height() * 0.5))
			if d < bd:
				bd = d
				best = e
	return best

## Pomoc w celowaniu: najbliższy kątowo wróg w stożku (stopnie, całość) przed kierunkiem, w zasięgu.
func soft_target(dir: Vector2, reach: float, cone_deg: float) -> Actor:
	if level == null or dir.length() < 0.01:
		return null
	var gd := Iso.ground(dir).normalized()
	var best: Actor = null
	var best_a := deg_to_rad(cone_deg) * 0.5
	for e in level.enemies():
		if e.is_dead():
			continue
		var g := Iso.ground(e.position - position)
		if g.length() > reach + e.body_radius or g.length() < 1.0:
			continue
		var a := absf(gd.angle_to(g))
		if a <= best_a:
			best_a = a
			best = e
	return best

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

# ---------------------------------------------------------------- wykonanie
func _process_action(_delta: float) -> void:
	velocity = Vector2.ZERO
	match state:
		St.WINDUP:
			if state_t >= phases[0]:
				set_state(St.STRIKE)
				_release()
		St.STRIKE:
			if state_t >= phases[1]:
				set_state(St.RECOVER)
		St.RECOVER:
			var mv := Controls.move_vector()
			if state_t >= phases[2] or (state_t >= phases[2] * 0.5 and mv.length() > 0.3 and not input_locked):
				set_state(St.IDLE)
				cur = {}
				cur_id = ""

func _release() -> void:
	var sk := cur
	aim = _aim_dir(float(sk.get("zasieg", 90)), _is_projectile(sk))
	facing = aim
	match str(sk.get("typ", "")):
		"ciecie":
			var reach := float(sk.get("zasieg", 90))
			var arc := float(sk.get("luk_stopni", 120))
			Audio.play(str(sk.get("dzwiek", "swing")))
			if level:
				Fx.slash(level.fx_parent(), position + Vector2(0, -34), aim, reach, minf(arc, 359.0), Color(1.0, 0.85, 0.6) if arc >= 300.0 else Color(0.85, 0.85, 0.9), 0.14)
			_melee(sk)
		"pocisk":
			_shoot(sk, aim)
		"salwa":
			var n := int(sk.get("strzaly", 5))
			var spread := deg_to_rad(float(sk.get("rozrzut_stopni", 40)))
			var g := Iso.ground(aim).normalized()
			for i in n:
				var a := -spread / 2.0 + spread * i / maxf(1.0, n - 1)
				_shoot(sk, Iso.screen(g.rotated(a)).normalized(), i > 0)
		"okrzyk":
			Audio.play("shrine", 0.7)
			dmg_buff = float(sk.get("wzmocnienie", 0.4))
			dmg_buff_t = float(sk.get("czas", 6.0))
			if level:
				Fx.ring(level.decal_parent(), position, float(sk.get("promien", 140)), Color(1.0, 0.3, 0.2), 0.5)
				Fx.float_text(level.fx_parent(), position + Vector2(0, -130), "Za Carroburg!", Color(1.0, 0.4, 0.3), true)
				level.shake(5.0)
				for e in level.enemies():
					if not e.is_dead() and Iso.dist(position, e.position) <= float(sk.get("promien", 140)) + e.body_radius:
						e.knockback(Iso.ground(e.position - position).normalized() * float(sk.get("odrzut", 60)))
						e.stagger(0.4)

func _weapon_for(sk: Dictionary) -> int:
	return int(sk.get("obrazenia", weapon_dmg()))

## Wynik trafienia umiejętnością w wroga (wywołuje też Projectile).
func skill_hit(sk: Dictionary, e: Actor, ranged: bool) -> Dictionary:
	var dmg := Rules.skill_damage(sk, stats, e.stats, _weapon_for(sk), dmg_buff)
	var res := Rules.hero_hit(stats, e.stats, e.armor(), ranged, dmg, rng)
	var kind := "fiz"
	if str(sk.get("rodzaj", "")) in ["fireball", "fire_lance"]:
		kind = "ogien"
	res["kind"] = kind
	return res

func _melee(sk: Dictionary) -> Array:
	var hits: Array = []
	if level == null:
		return hits
	var reach := float(sk.get("zasieg", 90))
	var arc := float(sk.get("luk_stopni", 120))
	var cands: Array = []
	for e in level.enemies():
		if not e.is_dead() and (arc >= 359.0 and Iso.dist(position, e.position) <= reach + e.body_radius or Iso.in_arc(position, aim, e.position, reach, arc, e.body_radius)):
			cands.append(e)
	cands.sort_custom(func(a, b): return Iso.dist(position, a.position) < Iso.dist(position, b.position))
	for e in cands.slice(0, int(sk.get("max_celow", 1))):
		e.receive_hit(skill_hit(sk, e, false), self)
		var push := float(Data.bal("walka_bohatera/odrzut_trafienia", 10)) + float(sk.get("odrzut", 0))
		e.knockback(Iso.ground(e.position - position).normalized() * push)
		hits.append(e)
	if not hits.is_empty():
		level.hitstop(float(Data.bal("walka/zatrzymanie_trafienia", 0.05)))
		level.shake(2.5 if arc < 300.0 else 4.0)
	return hits

## Pocisk umiejętności: obrażenia liczone przy trafieniu (skill_hit), hitbox = promien_trafienia + promień ciała wroga.
func _shoot(sk: Dictionary, dir: Vector2, silent: bool = false) -> void:
	if level == null:
		return
	if not silent:
		Audio.play(str(sk.get("dzwiek", "bolt")))
	last_shot_dir = dir
	var opts := {"skill": sk, "soft_aim": true, "promien_trafienia": float(sk.get("promien_trafienia", 14)),
		"przebicie": int(sk.get("przebicie", 1)), "wybuch": float(sk.get("wybuch", 0.0)), "skala": float(sk.get("skala", 1.0))}
	level.spawn_projectile(str(sk.get("rodzaj", "arrow")), self, position, dir, float(sk.get("predkosc", 400)), float(sk.get("zasieg", 400)), 0, opts)

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
	# zasięg umiejętności ze slotu 1 (elipsa na ziemi) i łuk zwykłego ataku bronią
	var sk: Dictionary = skills.get(slot_entry(0), {})
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_arc(Vector2.ZERO, float(sk.get("zasieg", 0)), 0, TAU, 64, Color(0.4, 0.8, 1.0, 0.5), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var shown: Dictionary = cur if not cur.is_empty() else weapon_atk
	var reach := float(shown.get("zasieg", 80))
	var arc := minf(float(shown.get("luk_stopni", 110)), 360.0)
	var g := Iso.ground(aim if aim.length() > 0.1 else facing).normalized()
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 25:
		var a := g.angle() - deg_to_rad(arc) / 2.0 + deg_to_rad(arc) * i / 24.0
		pts.append(Iso.screen(Vector2.RIGHT.rotated(a) * reach))
	pts.append(Vector2.ZERO)
	draw_polyline(pts, Color(1, 0.2, 0.2) if state == St.STRIKE else Color(1, 0.9, 0.2, 0.8), 1.5)
	if state in [St.WINDUP, St.STRIKE]:
		draw_line(Vector2.ZERO, Iso.screen(g * 500.0), Color(1, 1, 1, 0.4), 1.0)
