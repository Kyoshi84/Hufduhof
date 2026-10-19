class_name Actor
extends Node2D
## Bazowy aktor beat'em upa. Pozycja = punkt stóp (x = oś pozioma, y = głębia sceny).
## Atak ma trzy fazy: WINDUP (zamach) -> ACTIVE (okno trafienia) -> RECOVER (powrót).
## Trafienie jest liczone tylko w fazie ACTIVE, raz na cel na atak, według zasięgu i głębi.

enum State { IDLE, MOVE, WINDUP, ACTIVE, RECOVER, HURT, DODGE, DEAD, VICTORY }

var level                         # Level
var id: String = "actor"
var team: int = 0                 # 0 = gracz, 1 = wrogowie
var max_hp: float = 100.0
var hp: float = 100.0
var facing: int = 1
var state: int = State.IDLE
var state_t: float = 0.0
var body_half: float = 26.0
var body_height: float = 120.0
var speed: float = 200.0
var depth_speed: float = 140.0
var damage_mult: float = 1.0
var resist: float = 1.0           # mnożnik obrażeń otrzymywanych
var invuln: float = 0.0
var kb_vx: float = 0.0
var hurt_time: float = 0.0
var flash: float = 0.0
var dead_t: float = 0.0
var attack_name: String = ""
var attack: Dictionary = {}
var attack_defs: Dictionary = {}
var attack_queue: Array = []
var attack_scale: float = 1.0
var hit_ids: Array = []
var cooldowns: Dictionary = {}
var visual: ActorVisual

func set_state(s: int) -> void:
	state = s
	state_t = 0.0

func is_alive() -> bool:
	return state != State.DEAD

func can_be_hit() -> bool:
	return state != State.DEAD and invuln <= 0.0

func is_attacking() -> bool:
	return state == State.WINDUP or state == State.ACTIVE or state == State.RECOVER

func windup_time() -> float:
	return float(attack.get("windup", 0.2)) * attack_scale

# ------------------------------------------------------------------ ataki

func start_attack(attack_id: String, defn: Dictionary, wscale: float = 1.0) -> void:
	attack_name = attack_id
	attack = defn
	attack_scale = wscale
	hit_ids = []
	cooldowns[attack_id] = float(defn.get("cooldown", 0.0))
	set_state(State.WINDUP)
	on_attack_started()

func tick_attack(delta: float) -> void:
	match state:
		State.WINDUP:
			on_windup(delta)
			if state_t >= windup_time():
				set_state(State.ACTIVE)
				Sfx.play(str(attack.get("sfx", "swing")))
				on_active_started()
		State.ACTIVE:
			position.x += facing * float(attack.get("lunge", 0.0)) * delta
			check_hits()
			if state_t >= float(attack["active"]):
				set_state(State.RECOVER)
		State.RECOVER:
			on_recover(delta)
			if state_t >= float(attack["recover"]):
				finish_attack()

func finish_attack() -> void:
	if not attack_queue.is_empty():
		var nxt: String = attack_queue.pop_front()
		start_attack(nxt, attack_defs[nxt], 0.6)
		return
	set_state(State.IDLE)
	on_attack_finished()

## Hitbox bieżącego ataku na płaszczyźnie podłoża (patrz HitShape).
func hitbox_rect() -> Rect2:
	return HitShape.attack_rect(position, facing, attack)

## Zakres poziomy hitboxa (zgodność wsteczna: x = lewa, y = prawa krawędź).
func hitbox_x_range() -> Vector2:
	var r := hitbox_rect()
	return Vector2(r.position.x, r.end.x)

func hurtbox_rect() -> Rect2:
	return HitShape.hurt_rect(position, body_half, float(Balance.world("foot_half_depth")))

## Hitbox istnieje tylko w fazie ACTIVE ataku.
func hitbox_active() -> bool:
	return state == State.ACTIVE

var last_report: Array = []        # tylko w trybie diagnostycznym: [{target, result}]

func check_hits() -> void:
	if not hitbox_active():
		return
	var r := hitbox_rect()
	var dbg: bool = GameState.debug_collision
	if dbg:
		last_report = []
	for t in level.opponents_of(self):
		var tid: int = t.get_instance_id()
		var result: String
		if hit_ids.has(tid):
			result = "dup"
		else:
			result = HitShape.test(r, t.hurtbox_rect())
			if result == "hit" and not t.can_be_hit():
				result = "invuln"
		if dbg:
			last_report.append({ "target": t, "result": result })
		if result != "hit":
			continue
		hit_ids.append(tid)
		t.receive_hit(self, attack)

# ------------------------------------------------------------------ obrażenia

func hit_invuln() -> float:
	return 0.05

func should_stagger(_defn: Dictionary, _dmg: float) -> bool:
	return true

func receive_hit(attacker, defn: Dictionary) -> bool:
	if not can_be_hit():
		return false
	var dmg: float = float(defn["damage"]) * attacker.damage_mult * resist
	if team == 0 and GameState.god_mode:
		dmg = 0.0
	hp -= dmg
	var dir: int = 1 if position.x >= attacker.position.x else -1
	var stagger: bool = should_stagger(defn, dmg)
	level.on_hit(attacker, self, defn, dmg, stagger)
	if hp <= 0.0:
		hp = 0.0
		die(dir, defn)
		return true
	invuln = hit_invuln()
	flash = 0.12
	if stagger:
		enter_hurt(dir, defn)
	return true

func enter_hurt(dir: int, defn: Dictionary) -> void:
	abort_attack()
	hurt_time = float(defn.get("stun", 0.3)) * hurt_scale()
	kb_vx = dir * float(defn.get("knockback", 150.0))
	facing = -dir
	set_state(State.HURT)

func hurt_scale() -> float:
	return 1.0

func tick_hurt(delta: float) -> void:
	position.x += kb_vx * delta
	kb_vx = move_toward(kb_vx, 0.0, 1300.0 * delta)
	if state_t >= hurt_time:
		set_state(State.IDLE)
		on_hurt_finished()

func die(dir: int, defn: Dictionary) -> void:
	abort_attack()
	attack_queue.clear()
	kb_vx = dir * float(defn.get("knockback", 150.0)) * 0.8
	dead_t = 0.0
	set_state(State.DEAD)
	level.on_actor_died(self)

func tick_dead(delta: float) -> void:
	dead_t += delta
	position.x += kb_vx * delta
	kb_vx = move_toward(kb_vx, 0.0, 900.0 * delta)

# ------------------------------------------------------------------ haki

func on_attack_started() -> void: pass
func on_windup(_delta: float) -> void: pass
func on_active_started() -> void: pass
func on_recover(_delta: float) -> void: pass
func on_attack_finished() -> void: pass
func on_hurt_finished() -> void: pass
func abort_attack() -> void: pass

func tick_timers(delta: float) -> void:
	state_t += delta
	invuln = maxf(0.0, invuln - delta)
	flash = maxf(0.0, flash - delta)
	for k in cooldowns.keys():
		cooldowns[k] = maxf(0.0, float(cooldowns[k]) - delta)

func cooldown_ready(attack_id: String) -> bool:
	return float(cooldowns.get(attack_id, 0.0)) <= 0.0
