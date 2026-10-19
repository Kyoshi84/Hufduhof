class_name Enemy
extends Actor
## Wróg sterowany AI zależnym od pola "behavior" w balance.json:
##  swarm   - skaveni: szybkie podbieganie, flankowanie/otaczanie, krótkie ataki
##  charger - psy Chaosu: okrążanie, telegrafowana szarża, długie odnowienie po szarży
##  brute   - zwierzoludzie: wolni, mocni, poise (nie dają się przerwać lekkim atakom)
##  boss    - patrz Boss

var type_id: String = "skaven"
var cfg: Dictionary
var behavior: String = "swarm"
var ai_cd: float = 1.0
var has_token: bool = false
var uses_token: bool = true
var flank_side: int = 1
var flank_t: float = 3.0
var strafe_dir: int = 1
var strafe_t: float = 1.0
var score_value: int = 100
var poise: float = 0.0
var poise_max: float = 0.0
var poise_regen: float = 8.0
var target
var remove_me: bool = false

func setup(lvl, type: String, pos: Vector2) -> void:
	level = lvl
	type_id = type
	id = type
	cfg = Balance.enemy(type)
	behavior = str(cfg["behavior"])
	team = 1
	position = pos
	max_hp = float(cfg["max_hp"])
	hp = max_hp
	speed = float(cfg["speed"])
	depth_speed = float(cfg["depth_speed"])
	body_half = float(cfg["body_half_width"])
	resist = float(cfg.get("resist", 1.0))
	score_value = int(cfg.get("score", 100))
	uses_token = bool(cfg.get("uses_token", true))
	poise_max = float(cfg.get("poise", 0.0))
	poise = poise_max
	poise_regen = float(cfg.get("poise_regen", 8.0))
	attack_defs = Balance.build_attacks(cfg["attacks"])
	flank_side = 1 if randf() < 0.5 else -1
	strafe_dir = 1 if randf() < 0.5 else -1
	ai_cd = randf_range(0.4, 1.2)
	body_height = 120.0

func tick(delta: float) -> void:
	tick_timers(delta)
	poise = minf(poise_max, poise + poise_regen * delta)
	target = level.player
	match state:
		State.IDLE, State.MOVE:
			ai_cd -= delta
			if target != null and target.is_alive():
				think(delta)
			else:
				set_state_if_changed(State.IDLE)
		State.WINDUP, State.ACTIVE, State.RECOVER:
			tick_attack(delta)
		State.HURT:
			tick_hurt(delta)
		State.DEAD:
			tick_dead(delta)
			if dead_t > 1.1:
				remove_me = true
	level.clamp_enemy(self)

func set_state_if_changed(s: int) -> void:
	if state != s:
		set_state(s)

# ------------------------------------------------------------------ ruch

func face_target() -> void:
	facing = 1 if target.position.x >= position.x else -1

func move_toward_point(p: Vector2, delta: float, speed_mult: float = 1.0) -> bool:
	var dx: float = p.x - position.x
	var dy: float = p.y - position.y
	var sx: float = speed * speed_mult * delta
	var sy: float = depth_speed * speed_mult * delta
	position.x += signf(dx) * minf(absf(dx), sx)
	position.y += signf(dy) * minf(absf(dy), sy)
	var moved: bool = absf(dx) > 2.0 or absf(dy) > 2.0
	set_state_if_changed(State.MOVE if moved else State.IDLE)
	return moved

func dist_x() -> float:
	return absf(target.position.x - position.x)

func dist_y() -> float:
	return absf(target.position.y - position.y)

## Odpycha od siebie nakładających się wrogów (prosta separacja w osi głębi).
func separation_offset() -> float:
	var push: float = 0.0
	for o in level.enemies:
		if o == self or not o.is_alive():
			continue
		var dx: float = position.x - o.position.x
		var dy: float = position.y - o.position.y
		if absf(dx) < 40.0 and absf(dy) < 24.0:
			push += signf(dy if dy != 0.0 else randf() - 0.5) * 22.0
	return push

func try_start(attack_id: String, wscale: float = 1.0) -> bool:
	if not cooldown_ready(attack_id):
		return false
	if uses_token and not level.request_token(self):
		return false
	has_token = uses_token
	facing = 1 if target.position.x >= position.x else -1
	start_attack(attack_id, attack_defs[attack_id], wscale)
	return true

func think(delta: float) -> void:
	match behavior:
		"swarm": think_swarm(delta)
		"charger": think_charger(delta)
		"brute": think_brute(delta)

func think_swarm(delta: float) -> void:
	face_target()
	var claw: Dictionary = attack_defs["claw"]
	flank_t -= delta
	if flank_t <= 0.0:
		var r: Array = cfg["flank_interval"]
		flank_t = randf_range(float(r[0]), float(r[1]))
		if randf() < float(cfg["flank_chance"]):
			flank_side = -flank_side           # przebiega na drugą stronę gracza (otoczenie)
	var reach: float = float(claw["reach"])
	var goal := Vector2(target.position.x + flank_side * (reach - 14.0), target.position.y + separation_offset())
	var in_range: bool = absf(goal.x - position.x) < 14.0 and absf(target.position.y - position.y) < float(claw["depth"]) * 0.7
	if in_range and dist_x() <= reach - 6.0:
		set_state_if_changed(State.IDLE)
		if ai_cd <= 0.0 and try_start("claw"):
			return
	else:
		move_toward_point(goal, delta)

func think_charger(delta: float) -> void:
	face_target()
	var ad: float = dist_x()
	var bite: Dictionary = attack_defs["bite"]
	if ad <= float(bite["reach"]) - 8.0 and dist_y() < 24.0 and ai_cd <= 0.0:
		if try_start("bite"):
			return
	var cmin: float = float(cfg["charge_min"])
	var cmax: float = float(cfg["charge_max"])
	var pref: float = (cmin + cmax) * 0.5
	strafe_t -= delta
	if strafe_t <= 0.0:
		strafe_t = randf_range(0.7, 1.6)
		strafe_dir = -strafe_dir
	if position.y <= level.lane_min() + 6.0:
		strafe_dir = 1
	elif position.y >= level.lane_max() - 6.0:
		strafe_dir = -1
	# trzyma dystans do szarży i okrąża gracza
	var tx: float = target.position.x - facing * pref
	var goal := Vector2(tx, position.y + strafe_dir * 60.0)
	if ad > cmax + 80.0:
		goal = Vector2(target.position.x, target.position.y)
	move_toward_point(goal, delta)
	if ai_cd <= 0.0 and ad >= cmin and ad <= cmax and dist_y() < 120.0:
		try_start("charge")

func on_windup(delta: float) -> void:
	# szarża: w trakcie zamachu wyrównuje głębię do celu i patrzy na niego (ostatnie 0.12 s zamrożone)
	if bool(attack.get("track", false)) and target != null:
		if state_t < windup_time() - 0.12:
			facing = 1 if target.position.x >= position.x else -1
			var dy: float = target.position.y - position.y
			position.y += signf(dy) * minf(absf(dy), depth_speed * 2.4 * delta)

func think_brute(delta: float) -> void:
	face_target()
	var chop: Dictionary = attack_defs["chop"]
	var wide: Dictionary = attack_defs["wide"]
	var goal := Vector2(target.position.x - facing * (float(chop["reach"]) - 26.0), target.position.y)
	var ad: float = dist_x()
	var aligned: bool = dist_y() < float(chop["depth"]) * 0.8
	if aligned and ad <= float(wide["reach"]) - 10.0 and ai_cd <= 0.0:
		var pick: String = "chop"
		if ad > float(chop["reach"]) - 8.0 or randf() < 0.3:
			pick = "wide"
		if try_start(pick):
			return
	move_toward_point(goal, delta)

# ------------------------------------------------------------------ reakcje

func should_stagger(defn: Dictionary, dmg: float) -> bool:
	if poise_max <= 0.0:
		return true
	if state == State.RECOVER:          # kara za pudło: okno kontrataku
		return true
	poise -= dmg
	if bool(defn.get("breaks_poise", false)) or poise <= 0.0:
		poise = poise_max
		return true
	return false

func abort_attack() -> void:
	release_token()

func on_attack_finished() -> void:
	release_token()
	var r: Array = cfg.get("attack_cooldown", [1.0, 1.5])
	ai_cd = randf_range(float(r[0]), float(r[1]))

func on_hurt_finished() -> void:
	var r: Array = cfg.get("attack_cooldown", [1.0, 1.5])
	ai_cd = maxf(ai_cd, randf_range(float(r[0]) * 0.5, float(r[1]) * 0.7))

func release_token() -> void:
	if has_token:
		level.release_token(self)
		has_token = false
