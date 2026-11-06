class_name Enemy
extends Actor
## Skaveny. AI z data/enemies.json:
##  wrecz     - podchodzi (NavigationAgent2D), zatrzymuje się, ZAMACH (czerwony pas na ziemi = zasięg pchnięcia), pchnięcie.
##  dystans   - trzyma dystans, przy zamachu rysuje linię celowania, rzuca kamień (widoczny, da się zejść z linii).
##  czarownik - trzyma dystans, ucieka przed bohaterem; czar: zielone koło na ziemi, po chwili spada kula spaczenia
##              i zostaje trująca kałuża (obrażenia w czasie, mniejsze przy wysokiej SW bohatera).
## Wrogowie z jednej grupy budzą się razem.

var eid: String
var edef: Dictionary
var uid: String = ""
var group: String = ""
var home := Vector2.ZERO
var aggro: bool = false
var agent: NavigationAgent2D
var target: Actor = null
var atk_cd: float = 0.0
var repath_t: float = 0.0
var wander_t: float = 0.0
var wander_to := Vector2.ZERO
var strike_dir := Vector2.RIGHT
var strike_pos := Vector2.ZERO
var marker: Fx = null
var knock := Vector2.ZERO
var corpse_t: float = 0.0
var stagger_t: float = 0.0

func setup(enemy_id: String, unique_id: String, group_id: String) -> void:
	eid = enemy_id
	uid = unique_id
	group = group_id
	edef = Data.enemy(eid)
	stats = Stats.from_profile(edef.get("profil", {}))
	hp = stats.max_hp()
	faction = 1
	setup_body(float(edef.get("promien_ciala", 13)), 4, 1 | 2 | 4)
	gfx = DirSprite.new()
	add_child(gfx)
	gfx.setup(str(edef.get("grafika", "")))
	agent = NavigationAgent2D.new()
	agent.path_desired_distance = 10.0
	agent.target_desired_distance = 12.0
	agent.radius = body_radius
	add_child(agent)
	home = position
	wander_to = position
	atk_cd = rng.randf_range(0.3, 1.2)
	add_to_group("enemies")

func armor() -> int:
	return int(edef.get("obrona", 0))

func weapon_dmg() -> int:
	return int(edef.get("bron_obrazenia", 3))

func gfx_height() -> float:
	return 84.0

func _physics_process(delta: float) -> void:
	tick_common(delta)
	if is_dead():
		_dead_tick(delta)
		return
	atk_cd = maxf(0.0, atk_cd - delta)
	if target == null or not is_instance_valid(target):
		target = level.hero if level else null
	match state:
		St.IDLE, St.MOVE:
			_think(delta)
		St.WINDUP:
			velocity = Vector2.ZERO
			_windup_tick()
		St.STRIKE:
			velocity = Vector2.ZERO
			if state_t > 0.12:
				set_state(St.RECOVER)
		St.RECOVER:
			velocity = Vector2.ZERO
			if state_t >= float(edef.get("odpoczynek", 1.0)):
				set_state(St.IDLE)
		St.HURT:
			velocity = Vector2.ZERO
			if state_t >= stagger_t:
				set_state(St.IDLE)
	if knock.length() > 1.0:
		velocity += Iso.screen(knock) * 8.0
		knock = knock.lerp(Vector2.ZERO, minf(1.0, delta * 10.0))
	move_and_slide()
	_animate()

# ---------------------------------------------------------------- myślenie
func _think(delta: float) -> void:
	if target == null or target.is_dead():
		aggro = false
		_wander(delta)
		return
	var d := Iso.dist(position, target.position)
	if not aggro:
		if d <= float(edef.get("zasieg_wykrycia", 300)):
			wake()
		else:
			_wander(delta)
			return
	if Iso.dist(home, target.position) > float(edef.get("smycz", 800)):
		aggro = false
		_nav_to(home, 0.8)
		return
	match str(edef.get("ai", "wrecz")):
		"wrecz":
			var reach := float(edef.get("zasieg_ataku", 60)) + target.body_radius
			if d <= reach * 0.85 and atk_cd <= 0.0:
				_begin_windup()
			elif d <= reach * 0.7:
				velocity = Vector2.ZERO
				facing = (target.position - position).normalized()
				state = St.IDLE
			else:
				_nav_to(target.position, 1.0)
		"dystans", "czarownik":
			var dmin := float(edef.get("dystans_min", 170))
			var dmax := float(edef.get("dystans_max", 290))
			var flee := float(edef.get("ucieczka_dystans", 0))
			if flee > 0.0 and d < flee:
				_flee_from(target.position, 1.25)
			elif d < dmin * 0.8 and flee <= 0.0:
				_flee_from(target.position, 0.9)
			elif d > dmax:
				_nav_to(target.position, 1.0)
			elif atk_cd <= 0.0 and d <= float(edef.get("zasieg_ataku", 320)):
				_begin_windup()
			else:
				velocity = Vector2.ZERO
				facing = (target.position - position).normalized()
				state = St.IDLE

func wake() -> void:
	if aggro or is_dead():
		return
	aggro = true
	Audio.play("skaven_alert", rng.randf_range(0.9, 1.2))
	if level:
		level.alert_group(group)

func _wander(delta: float) -> void:
	wander_t -= delta
	if wander_t <= 0.0:
		wander_t = rng.randf_range(2.0, 5.0)
		wander_to = home + Iso.screen(Vector2(rng.randf_range(-60, 60), rng.randf_range(-60, 60)))
	if Iso.dist(position, wander_to) > 10.0:
		_nav_to(wander_to, 0.35)
	else:
		velocity = Vector2.ZERO
		state = St.IDLE

func _nav_to(p: Vector2, speed_k: float) -> void:
	if NavigationServer2D.map_get_iteration_id(agent.get_navigation_map()) == 0:
		return
	repath_t -= get_physics_process_delta_time()
	if repath_t <= 0.0 or agent.target_position.distance_to(p) > 40.0:
		agent.target_position = p
		repath_t = 0.3
	var next := agent.get_next_path_position()
	var dvec := next - position
	if agent.is_navigation_finished() or dvec.length() < 1.0:
		dvec = p - position
	if dvec.length() < 2.0:
		velocity = Vector2.ZERO
		state = St.IDLE
		return
	var g := Iso.ground(dvec).normalized()
	velocity = Iso.screen(g) * stats.move_speed() * speed_k
	facing = velocity.normalized()
	state = St.MOVE

func _flee_from(p: Vector2, speed_k: float) -> void:
	var away := Iso.ground(position - p).normalized()
	var goal := position + Iso.screen(away * 140.0)
	var map_rid := agent.get_navigation_map()
	if map_rid.is_valid():
		goal = NavigationServer2D.map_get_closest_point(map_rid, goal)
	_nav_to(goal, speed_k)
	facing = Iso.screen(away)

# ---------------------------------------------------------------- atak z zapowiedzią
func _begin_windup() -> void:
	set_state(St.WINDUP)
	velocity = Vector2.ZERO
	strike_dir = (target.position - position).normalized()
	facing = strike_dir
	strike_pos = target.position
	var parent: Node = level.decal_parent() if level else self
	match str(edef.get("ai", "wrecz")):
		"wrecz":
			marker = Fx.marker(parent, position, "line", strike_dir, float(edef.get("zasieg_ataku", 60)) + 10.0,
				float(edef.get("szerokosc_pchniecia", 22)) * 2.0, Color(0.95, 0.2, 0.15))
		"dystans":
			marker = Fx.marker(parent, position, "line", strike_dir, Iso.dist(position, target.position) + 40.0, 10.0, Color(0.95, 0.75, 0.3))
			Audio.play("swing", 1.6)
		"czarownik":
			var sp: Dictionary = edef.get("spaczenie", {})
			marker = Fx.marker(parent, strike_pos, "circle", Vector2.RIGHT, float(sp.get("kaluza_promien", 46)), 0.0, Color(0.4, 1.0, 0.25))
			Audio.play("warp", 1.3)

func _windup_tick() -> void:
	var wind := float(edef.get("zamach", 0.8))
	if marker and is_instance_valid(marker):
		marker.fill_progress = clampf(state_t / wind, 0.0, 1.0)
		if str(edef.get("ai", "")) == "dystans" and target:
			# procarz celuje za bohaterem aż do wypuszczenia kamienia
			strike_dir = strike_dir.lerp((target.position - position).normalized(), 0.08).normalized()
			marker.dir = strike_dir
			facing = strike_dir
	if state_t >= wind:
		_strike()

func _clear_marker() -> void:
	if marker and is_instance_valid(marker):
		marker.queue_free()
	marker = null

func _strike() -> void:
	_clear_marker()
	set_state(St.STRIKE)
	atk_cd = Rules.attack_interval(stats.val("A"), stats.val("Zr"))
	match str(edef.get("ai", "wrecz")):
		"wrecz":
			Audio.play("swing", 1.3)
			if target and not target.is_dead() and _in_thrust(target):
				var res := Rules.resolve_melee(stats, weapon_dmg(), target.stats, target.armor(), rng)
				target.receive_hit(res, self)
		"dystans":
			Audio.play("stone")
			if level:
				level.spawn_projectile(str(edef.get("pocisk", "stone")), self, position, strike_dir,
					float(edef.get("predkosc_pocisku", 230)), float(edef.get("zasieg_ataku", 330)) + 120.0, weapon_dmg())
		"czarownik":
			if level:
				level.spawn_warp_orb(self, position, strike_pos, edef)

func _in_thrust(t: Actor) -> bool:
	var g := Iso.ground(t.position - position)
	var dirg := Iso.ground(strike_dir).normalized()
	var along := g.dot(dirg)
	var side := absf(g.dot(dirg.orthogonal()))
	var reach := float(edef.get("zasieg_ataku", 60)) + 10.0 + t.body_radius
	return along >= -t.body_radius and along <= reach and side <= float(edef.get("szerokosc_pchniecia", 22)) + t.body_radius

func receive_hit(res: Dictionary, attacker: Actor = null) -> void:
	if not aggro:
		wake()
	super(res, attacker)

func on_damaged(amount: float, _kind: String) -> void:
	if amount >= get_max_hp() * float(Data.bal("walka/zachwianie_prog", 0.12)) and state != St.DEAD:
		# trafienie przerywa zamach (zachwianie)
		_clear_marker()
		stagger_t = float(Data.bal("walka/zachwianie_czas", 0.3))
		set_state(St.HURT)

func knockback(g: Vector2) -> void:
	knock = g

func die() -> void:
	_clear_marker()
	super()
	Audio.play("skaven_die", rng.randf_range(0.85, 1.15))
	z_index = -1
	if level:
		level.on_enemy_died(self)

func _dead_tick(delta: float) -> void:
	corpse_t += delta
	gfx.play("death", Iso.dir_name(facing))
	if corpse_t > 8.0:
		modulate.a = maxf(0.0, 1.0 - (corpse_t - 8.0))
		if corpse_t > 9.0:
			queue_free()

func _animate() -> void:
	var d := Iso.dir_name(facing)
	gfx.lunge = Vector2.ZERO
	match state:
		St.MOVE:
			gfx.play("walk", d)
		St.WINDUP:
			var wind := float(edef.get("zamach", 0.8))
			gfx.set_progress("attack", clampf(state_t / wind, 0.0, 1.0) * 0.66, d)
			gfx.lunge = -Iso.screen(Iso.ground(strike_dir).normalized()) * 3.0 * clampf(state_t / wind, 0, 1)
		St.STRIKE:
			gfx.set_progress("attack", 1.0, d)
			gfx.lunge = Iso.screen(Iso.ground(strike_dir).normalized()) * 6.0
		St.RECOVER:
			gfx.set_progress("attack", 1.0, d)
		St.HURT:
			gfx.play("hurt", d)
		_:
			gfx.play("idle", d)

func draw_debug() -> void:
	super()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_arc(Vector2.ZERO, float(edef.get("zasieg_wykrycia", 300)), 0, TAU, 40, Color(1, 1, 1, 0.15), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if agent and aggro:
		var path := agent.get_current_navigation_path()
		for i in range(1, path.size()):
			draw_line(path[i - 1] - position, path[i] - position, Color(0.3, 0.7, 1.0, 0.6), 1.0)
