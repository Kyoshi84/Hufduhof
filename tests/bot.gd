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
	var best = null
	var best_d: float = 1.0e9
	for e in level.enemies:
		if e.is_alive():
			var d: float = absf(e.position.x - p.position.x) + absf(e.position.y - p.position.y) * 2.0
			if d < best_d:
				best_d = d
				best = e
	var mv := Vector2.ZERO
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
	if ob != null and not p.is_airborne() and ob.x0() - p.position.x < 70.0 and ob.x0() > p.position.x - 5.0 and ob.type != "puddle":
		mv = Vector2(1.0, mv.y)
		Controls.press("jump")
	elif ob != null and ob.x0() - p.position.x < 260.0 and not level.wave_active and ob.x0() > p.position.x and free:
		mv = Vector2(1.0, mv.y)
	Controls.touch_move = mv
