class_name TestBot
extends RefCounted
## Prosty bot grający w poziom: podchodzi do najbliższego wroga/beczki i go tnie, w przeciwnym razie idzie w prawo.

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
	Controls.touch_move = mv
