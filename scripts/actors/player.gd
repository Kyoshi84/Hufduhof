class_name Player
extends Actor
## Ivo Eggert. Kombinacja: light1 -> light2 -> sweep (szeroki zamach obszarowy). Heavy osobno.

const CHAIN := ["light1", "light2", "sweep"]

var cfg: Dictionary
var combo_idx: int = 0
var combo_timer: float = 0.0
var dodge_cd: float = 0.0
var dodge_dir: Vector2 = Vector2.ZERO
var dodge_invuln: float = 0.0
var aim_dir: String = "east"      # 8-kierunkowy widok (E/SE/S/SW/W/NW/N/NE)
var aim_hold: float = 0.0

func setup(lvl) -> void:
	level = lvl
	cfg = Balance.player()
	id = "ivo"
	team = 0
	max_hp = float(cfg["max_hp"])
	hp = max_hp
	speed = float(cfg["move_speed"])
	depth_speed = float(cfg["depth_speed"])
	body_half = float(cfg["body_half_width"])
	attack_defs = Balance.build_attacks(cfg["attacks"])

func hit_invuln() -> float:
	return float(cfg["invuln_after_hit"])

func hurt_scale() -> float:
	return float(cfg["hurt_time_scale"])

func tick(delta: float) -> void:
	tick_timers(delta)
	dodge_cd = maxf(0.0, dodge_cd - delta)
	dodge_invuln = maxf(0.0, dodge_invuln - delta)
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_idx = 0
	match state:
		State.IDLE, State.MOVE:
			tick_free(delta)
		State.WINDUP, State.ACTIVE, State.RECOVER:
			tick_attack(delta)
			try_cancel()
		State.HURT:
			tick_hurt(delta)
		State.DODGE:
			tick_dodge(delta)
		State.DEAD:
			tick_dead(delta)
		State.VICTORY:
			pass
	level.clamp_player(self)

func can_be_hit() -> bool:
	return state != State.DEAD and invuln <= 0.0 and dodge_invuln <= 0.0

func tick_free(delta: float) -> void:
	var mv: Vector2 = Controls.get_move()
	if mv.x != 0.0:
		facing = 1 if mv.x > 0.0 else -1
	position.x += mv.x * speed * delta
	position.y += mv.y * depth_speed * delta
	update_aim(mv, delta)
	set_state_if_changed(State.MOVE if mv.length() > 0.05 else State.IDLE)
	if Controls.consume("dodge"):
		if try_dodge(mv):
			return
	if Controls.consume("heavy"):
		if cooldown_ready("heavy"):
			assist_facing()
			start_attack("heavy", attack_defs["heavy"])
			return
	if Controls.consume("light"):
		start_light()

## Kierunek widoku: według wektora ruchu; po zatrzymaniu wraca do profilu zgodnego z kierunkiem ataku.
func update_aim(mv: Vector2, delta: float) -> void:
	var prof: String = "east" if facing >= 0 else "west"
	if mv.length() > 0.3:
		aim_dir = IvoView.dir_from_vector(mv, prof, aim_dir)
		aim_hold = 0.22
	else:
		aim_hold -= delta
		if aim_hold <= 0.0:
			aim_dir = prof

func set_state_if_changed(s: int) -> void:
	if state != s:
		set_state(s)

## Wspomaganie kierunku: bez wciśniętego kierunku Ivo obraca się ku najbliższemu celowi w pobliżu,
## więc wróg, który zbiegł mu za plecy, nie jest "poza zasięgiem miecza".
func assist_facing() -> void:
	var mv: Vector2 = Controls.get_move()
	if absf(mv.x) > 0.2:
		facing = 1 if mv.x > 0.0 else -1
		return
	var cfgA: Dictionary = cfg["facing_assist"]
	var best = null
	var best_score: float = 1.0e9
	for e in level.opponents_of(self):
		var dx: float = e.position.x - position.x
		var dy: float = absf(e.position.y - position.y)
		if absf(dx) <= float(cfgA["range"]) and dy <= float(cfgA["depth"]):
			var sc: float = absf(dx) + dy * 2.0
			if sc < best_score:
				best_score = sc
				best = e
	if best != null:
		facing = 1 if best.position.x >= position.x else -1

func start_light() -> void:
	assist_facing()
	var name: String = CHAIN[combo_idx % CHAIN.size()]
	start_attack(name, attack_defs[name])
	combo_idx += 1
	if combo_idx >= CHAIN.size():
		combo_idx = 0

## Anulowanie odnowienia ataku w kolejny element combo / unik / mocny atak.
func try_cancel() -> void:
	if state != State.RECOVER:
		return
	var frac: float = state_t / float(attack["recover"])
	if frac < float(cfg["chain_cancel_at"]):
		return
	if Controls.consume("dodge"):
		if try_dodge(Controls.get_move()):
			return
	if Controls.consume("heavy") and cooldown_ready("heavy"):
		start_attack("heavy", attack_defs["heavy"])
		return
	if attack_name != "sweep" and attack_name != "heavy" and Controls.consume("light"):
		start_light()

func on_attack_finished() -> void:
	combo_timer = float(cfg["combo_window"]) if attack_name != "sweep" and attack_name != "heavy" else 0.0
	if attack_name == "sweep" or attack_name == "heavy":
		combo_idx = 0

func try_dodge(mv: Vector2) -> bool:
	if dodge_cd > 0.0:
		return false
	var d: Dictionary = cfg["dodge"]
	dodge_dir = Vector2(mv.x, mv.y * 0.6)
	if dodge_dir.length() < 0.1:
		dodge_dir = Vector2(-facing, 0.0)      # bez kierunku: krok w tył
	dodge_dir = dodge_dir.normalized()
	dodge_invuln = float(d["invuln"])
	dodge_cd = float(d["cooldown"])
	abort_attack()
	set_state(State.DODGE)
	return true

func tick_dodge(delta: float) -> void:
	var d: Dictionary = cfg["dodge"]
	var k: float = 1.0 - state_t / float(d["duration"])
	position += dodge_dir * float(d["speed"]) * maxf(k, 0.2) * delta
	if state_t >= float(d["duration"]):
		set_state(State.IDLE)

func abort_attack() -> void:
	combo_timer = 0.0
	combo_idx = 0

func enter_hurt(dir: int, defn: Dictionary) -> void:
	super.enter_hurt(dir, defn)
	dodge_invuln = 0.0

func victory() -> void:
	if state != State.DEAD:
		set_state(State.VICTORY)

func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
