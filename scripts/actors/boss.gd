class_name Boss
extends Enemy
## Czempion Chaosu. Fazy zależą od zdrowia (progi w balance.json). Każda faza ma własne wzorce ataków
## i krótsze przerwy. Ataki są wyraźnie telegrafowane (długi zamach + znacznik na ziemi).

var phase: int = 1
var phases: Array = []
var thresholds: Array = []
var dazed: bool = false
var roaring: bool = false     # ryk przy zmianie fazy (animacja "roar")

func setup(lvl, type: String, pos: Vector2) -> void:
	super.setup(lvl, type, pos)
	phases = cfg["phases"]
	thresholds = cfg["phase_thresholds"]
	body_height = 200.0
	apply_phase()
	ai_cd = 1.8

func phase_cfg() -> Dictionary:
	return phases[phase - 1]

func apply_phase() -> void:
	damage_mult = float(phase_cfg()["damage_mult"])

func phase_for_ratio(ratio: float) -> int:
	if ratio > float(thresholds[0]):
		return 1
	if ratio > float(thresholds[1]):
		return 2
	return 3

func receive_hit(attacker, defn: Dictionary) -> bool:
	var ok: bool = super.receive_hit(attacker, defn)
	if ok and is_alive():
		var np: int = phase_for_ratio(hp / max_hp)
		if np > phase:
			change_phase(np)
	return ok

func change_phase(np: int) -> void:
	phase = np
	apply_phase()
	attack_queue.clear()
	abort_attack()
	hurt_time = 1.2
	kb_vx = 0.0
	invuln = 1.2                       # ryk przy zmianie fazy: chwilowa nietykalność
	set_state(State.HURT)
	roaring = true
	ai_cd = float(phase_cfg()["pause"])
	Sfx.play("boss_roar")
	level.on_boss_phase(self, phase)

func should_stagger(defn: Dictionary, dmg: float) -> bool:
	# Boss nie reaguje na zwykłe trafienia; łamie się dopiero po przekroczeniu poise.
	poise -= dmg * (1.5 if bool(defn.get("breaks_poise", false)) else 1.0)
	if poise <= 0.0:
		poise = poise_max
		return true
	return false

func enter_hurt(dir: int, defn: Dictionary) -> void:
	super.enter_hurt(dir, defn)
	roaring = false
	hurt_time = float(cfg.get("stagger_time", 1.5))     # oszołomienie = okno kontrataku
	kb_vx = dir * 90.0
	dazed = true

func on_hurt_finished() -> void:
	dazed = false
	roaring = false
	ai_cd = float(phase_cfg()["pause"]) * 0.6

func think(delta: float) -> void:
	face_target()
	var pc: Dictionary = phase_cfg()
	var ad: float = dist_x()
	if ai_cd <= 0.0:
		var pattern: Dictionary = pick_pattern(ad)
		if not pattern.is_empty():
			var seq: Array = (pattern["seq"] as Array).duplicate()
			var first: String = seq.pop_front()
			attack_queue = seq
			facing = 1 if target.position.x >= position.x else -1
			start_attack(first, attack_defs[first])
			return
	# poza atakami: podchodzi do gracza, utrzymując bliski dystans
	var sm: float = float(pc["speed_mult"])
	var goal := Vector2(target.position.x - facing * 110.0, target.position.y)
	if ad > 140.0 or dist_y() > 30.0:
		move_toward_point(goal, delta, sm)
	else:
		set_state_if_changed(State.IDLE)

func pick_pattern(dist: float) -> Dictionary:
	var pool: Array = []
	var total: float = 0.0
	for p in phase_cfg()["patterns"]:
		if dist < float(p.get("min_dist", 0.0)) or dist > float(p.get("max_dist", 99999.0)):
			continue
		pool.append(p)
		total += float(p["w"])
	if pool.is_empty():
		return {}
	var r: float = randf() * total
	for p in pool:
		r -= float(p["w"])
		if r <= 0.0:
			return p
	return pool[0]

func on_attack_finished() -> void:
	ai_cd = float(phase_cfg()["pause"])
