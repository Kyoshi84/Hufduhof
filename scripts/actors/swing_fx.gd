class_name SwingFx
extends Node2D
## Smuga cięcia Ivo. Rysowana z TYCH SAMYCH danych co hitbox (HitShape), więc widoczny zasięg zamachu
## zawsze odpowiada zasięgowi mechanicznemu. To rozwiązanie tymczasowe do czasu dostarczenia klatek ataku.

var actor

func _process(_d: float) -> void:
	queue_redraw()

func _pt(f: int, hit_start: float, rx: float, ry: float, ang: float, cy: float) -> Vector2:
	return Vector2(f * (hit_start + rx + cos(ang) * rx), cy + sin(ang) * ry)

func _draw() -> void:
	var a = actor
	if a == null or a.attack.is_empty():
		return
	var st: int = a.state
	var atk: Dictionary = a.attack
	var area: bool = float(atk.get("back", 0.0)) > 0.0
	var heavy: bool = a.attack_name == "heavy"
	var p: float = -1.0
	if st == Actor.State.ACTIVE:
		p = clampf(a.state_t / maxf(float(atk["active"]), 0.01), 0.0, 1.0)
	elif st == Actor.State.RECOVER and a.state_t < 0.07:
		p = 1.0
	if p < 0.0:
		return
	var f: int = a.facing
	var reach: float = float(atk["reach"])
	var start: float = float(atk.get("hit_start", HitShape.DEFAULT_START))
	var col_hi: Color = Pal.r("white", 2)
	var col_mid: Color = Pal.r("steel", 6) if not heavy else Pal.r("fire", 6)
	var col_lo: Color = Pal.r("blood", 7) if not heavy else Pal.r("ember", 2)
	if area:
		# pełny obrót wokół Ivo: elipsa o promieniu = zasięg hitboxa
		var rx: float = reach
		var ry: float = float(atk.get("depth", 40.0)) * 0.9
		var head: float = TAU * p - PI * 0.5
		var trail: float = TAU * 0.42
		_trail(0.0, rx, ry, head, trail, -46.0, 0, col_hi, col_mid, col_lo, true)
	else:
		var rx2: float = (reach - start) * 0.5
		var ry2: float = 62.0 if heavy else 54.0
		var head2: float = lerpf(-2.1, 0.75, p)
		_trail(start, rx2, ry2, head2, 1.5 if heavy else 1.15, -68.0, f, col_hi, col_mid, col_lo, false)

func _trail(start: float, rx: float, ry: float, head: float, trail: float, cy: float, f: int, hi: Color, mid: Color, lo: Color, full: bool) -> void:
	var n := 14
	var prev := Vector2.ZERO
	for i in range(n + 1):
		var t: float = float(i) / n
		var ang: float = head - trail * (1.0 - t)
		var pt: Vector2
		if full:
			pt = Vector2(cos(ang) * rx, cy + sin(ang) * ry)
		else:
			pt = _pt(f, start, rx, ry, ang, cy)
		if i > 0:
			var c: Color = lo if t < 0.34 else (mid if t < 0.78 else hi)
			draw_line(prev, pt, c, 3.0 + 5.0 * t)
		prev = pt
