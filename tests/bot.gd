class_name TestBot
extends RefCounted
## Prosty bot grający w poziom: podchodzi do najbliższego wroga/beczki i go tnie (bohater dystansowy: strzela z dystansu),
## w przeciwnym razie idzie w prawo.

var level
var heavy_t: float = 0.0
var dodge_t: float = 0.0

func drive(delta: float) -> void:
	var p = level.player
	heavy_t -= delta
	dodge_t -= delta
	if not p.is_alive():
		return
	if p.is_airborne() and not level.wave_active:
		return                                          # w locie trzymaj kierunek z chwili skoku
	var best = null
	var best_d: float = 1.0e9
	for e in level.enemies:
		if e.is_alive():
			var d: float = absf(e.position.x - p.position.x) + absf(e.position.y - p.position.y) * 2.0
			if d < best_d:
				best_d = d
				best = e
	# nora szczurów w pobliżu (albo blokująca koniec etapu) to też cel
	for rh in level.rat_holes:
		var behind_blocking: bool = rh.position.x < p.position.x and level.stage_at(rh.position.x) == level.stage_idx
		if rh.is_alive() and (absf(rh.position.x - p.position.x) < 650.0 or behind_blocking):
			var dh: float = absf(rh.position.x - p.position.x) + absf(rh.position.y - p.position.y) * 2.0
			if best == null or (best_d > 400.0 and dh < 900.0):
				best = rh
				best_d = dh
	var mv := Vector2.ZERO
	if best == null and not level.wave_active and _puzzle(p):
		return
	if best == null:
		if level.wave_active:
			mv = Vector2(0.0, 0.0)
		else:
			mv = Vector2(1.0, 0.0)
			# zbij beczkę w pobliżu, jeśli blisko
			for b in level.barrels:
				if b.is_alive() and absf(b.position.x - p.position.x) < 150.0 and b.position.x > p.position.x - 20.0:
					best = b
					break
	if best != null and _ranged(p):
		# bohater dystansowy (Ursa): ustaw się na tej samej głębi, trzymaj dystans i strzelaj
		var rdx: float = best.position.x - p.position.x
		var rdy: float = best.position.y - p.position.y
		mv.x = 0.0 if absf(rdx) < 380.0 else signf(rdx)
		mv.y = 0.0 if absf(rdy) < 10.0 else signf(rdy)
		if absf(rdy) < 24.0 and absf(rdx) < 560.0:
			p.facing = 1 if rdx >= 0 else -1
			if heavy_t <= 0.0 and (best is Boss or level.alive_enemy_count() >= 3):
				Controls.press("heavy")
				heavy_t = 1.8
			else:
				Controls.press("light")
		best = null
		_jump_and_move(p, mv, true)
		return
	if best != null:
		var dx: float = best.position.x - p.position.x
		var dy: float = best.position.y - p.position.y
		mv.x = 0.0 if absf(dx) < 100.0 else signf(dx)
		mv.y = 0.0 if absf(dy) < 14.0 else signf(dy)
		if absf(dx) < 150.0 and absf(dy) < 30.0:
			if absf(dx) < 100.0:
				p.facing = 1 if dx >= 0 else -1
			if heavy_t <= 0.0 and best is Boss:
				Controls.press("heavy")
				heavy_t = 1.6
			else:
				Controls.press("light")
	_jump_and_move(p, mv, best == null)

## Atak lekki bohatera jest dystansowy (pocisk)?
func _ranged(p) -> bool:
	var first: String = str(p.chain[0])
	return p.attack_defs.has(first) and p.attack_defs[first].has("projectile")

func _jump_and_move(p, mv: Vector2, free: bool) -> void:
	var ob = level.next_obstacle_ahead(p.position.x, 260.0)
	if ob != null and ob.jumpable() and not p.is_airborne() and ob.x0() - p.position.x < 70.0 and ob.x0() > p.position.x - 5.0 and ob.type != "puddle":
		mv = Vector2(1.0, mv.y)
		Controls.press("jump")
	elif ob != null and ob.x0() - p.position.x < 260.0 and not level.wave_active and ob.x0() > p.position.x and free:
		mv = Vector2(1.0, mv.y)
	Controls.touch_move = mv

func _go(p, target: Vector2, tol_x: float = 20.0) -> void:
	var dx: float = target.x - p.position.x
	var dy: float = target.y - p.position.y
	var mv := Vector2(0.0 if absf(dx) < tol_x else signf(dx), 0.0 if absf(dy) < 10.0 else signf(dy))
	Controls.touch_move = mv
	# przeskakuj zwykłe przeszkody także w drodze powrotnej (np. po cegłę za kłodą)
	if mv.x != 0.0 and not p.is_airborne():
		for o in level.obstacles:
			if not o.blocks_passage() or not o.jumpable() or o.type == "puddle":
				continue
			var gap: float = (o.x0() - p.position.x) if mv.x > 0.0 else (p.position.x - o.x1())
			if gap > -5.0 and gap < 70.0:
				Controls.press("jump")
				break

## Przeszkody-zadania (gdy nie ma wrogów): cegły, wiadro i ogień, barykada, most. true = bot ma już ruch na tę klatkę.
func _puzzle(p) -> bool:
	var px: float = p.position.x
	var ob = null
	for o in level.obstacles:
		if o.is_puzzle() and o.x1() > px - 10.0 and o.x0() - px < 900.0 and (ob == null or o.x0() < ob.x0()):
			ob = o
	# cegły leżące blisko (po drodze albo tuż za plecami)
	var brick_limit: float = ob.x0() if ob != null and ob.bricks_needed > 0 else px + 450.0
	var near_brick = null
	for pk in level.pickups:
		if pk.kind == "brick" and not pk.taken and pk.position.x > px - 200.0 and pk.position.x < minf(px + 450.0, brick_limit) and not _blocked_between(px, pk.position.x):
			if near_brick == null or absf(pk.position.x - px) < absf(near_brick.position.x - px):
				near_brick = pk
	if near_brick != null:
		_go(p, near_brick.position, 10.0)
		return true
	if ob == null:
		return false
	match ob.type:
		"burning_cart":
			if p.carry == "bucket":
				if ob.in_use_range(px) and px < ob.x0():
					Controls.touch_move = Vector2.ZERO
					Controls.press("light")
				else:
					_go(p, Vector2(ob.x0() - 120.0, p.position.y), 40.0)
				return true
			for pk in level.pickups:
				if pk.kind == "bucket" and not pk.taken:
					_go(p, pk.position, 10.0)
					return true
			Controls.touch_move = Vector2.ZERO          # czekaj, aż przy studni pojawi się wiadro
			return true
		"barricade":
			if ob.jumpable():
				return false
			var reach: float = 420.0 if _ranged(p) else 50.0
			if px < ob.x0() - reach:
				Controls.touch_move = Vector2(1.0, 0.0)
			else:
				Controls.touch_move = Vector2.ZERO
				p.facing = 1
				if p.cooldown_ready("heavy") and not p.is_attacking():
					Controls.press("heavy")
			return true
		"river_bridge", "chasm_bridge":
			if p.bricks > 0 and p.bricks + ob.bricks_placed >= ob.bricks_needed:
				if ob.in_use_range(px) and px < ob.x0():
					Controls.touch_move = Vector2.ZERO
					Controls.press("light")
				else:
					_go(p, Vector2(ob.x0() - 100.0, p.position.y), 40.0)
				return true
			# za mało cegieł: najbliższa cegła albo beczka z cegłą przed mostem
			var tgt = null
			for pk in level.pickups:
				if pk.kind == "brick" and not pk.taken and pk.position.x < ob.x0() and (tgt == null or absf(pk.position.x - px) < absf(tgt.position.x - px)):
					tgt = pk
			if tgt != null:
				_go(p, tgt.position, 10.0)
				return true
			var bb = null
			for b in level.barrels:
				if b.is_alive() and b.contains == "brick" and b.position.x < ob.x0() and (bb == null or absf(b.position.x - px) < absf(bb.position.x - px)):
					bb = b
			if bb != null:
				_go(p, bb.position + Vector2(-70.0, 0.0), 12.0)
				if absf(bb.position.x - 70.0 - px) < 40.0 and absf(bb.position.y - p.position.y) < 20.0:
					p.facing = 1
					Controls.press("light")
				return true
			return false
	return false

## Czy między x_a a x_b stoi przeszkoda blokująca drogę (poza kałużą)?
func _blocked_between(x_a: float, x_b: float) -> bool:
	var lo: float = minf(x_a, x_b)
	var hi: float = maxf(x_a, x_b)
	for o in level.obstacles:
		if o.blocks_passage() and o.type != "puddle" and o.x1() > lo and o.x0() < hi:
			return true
	return false
