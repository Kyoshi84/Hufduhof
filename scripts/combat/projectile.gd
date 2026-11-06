class_name Projectile
extends Node2D
## Pocisk bohatera (Ursa): leci poziomo wzdłuż pasa walki na głębi strzelca.
##   bolt     - ognisty pocisk: przebija i rani KAŻDEGO wroga na swojej linii (raz na wroga), znika po zasięgu,
##   fireball - kula ognia: wybucha na pierwszym trafionym wrogu (albo na końcu zasięgu) i rani wszystkich w promieniu.
## Pozycja = punkt na ziemi (x, głębia); kula jest rysowana na wysokości "height" nad nim, z poświatą na ziemi.
## Parametry: pole "projectile" ataku w data/balance.json (heroes.<id>.attacks). Obrażenia/odrzut/ogłuszenie - z ataku.

var level
var shooter                        # Player (atakujący w receive_hit: kierunek odrzutu, mnożnik obrażeń)
var attack_name: String = ""       # nazwa ataku strzelca ("heavy" = kula ognia rąbie barykadę)
var defn: Dictionary = {}          # definicja ataku (damage, knockback, stun, breaks_poise, hit_sfx...)
var spec: Dictionary = {}          # defn["projectile"]
var kind: String = "bolt"
var dir: int = 1
var speed: float = 900.0
var max_range: float = 600.0
var depth: float = 30.0
var half_len: float = 24.0
var pierce: bool = true
var explode_radius: float = 0.0
var explode_depth: float = 60.0
var height: float = 80.0
var travelled: float = 0.0
var tail_x: float = 0.0            # skąd pocisk przyleciał w tej klatce (test kolizji po całym odcinku, także z bliska)
var hit_ids: Array = []
var hits: int = 0                  # ilu wrogów trafił (testy)
var boom_t: float = -1.0           # >= 0: trwa wybuch (tylko efekt)
var done: bool = false
var t: float = 0.0

const BOOM_TIME := 0.32

func setup(lvl, p_shooter, p_defn: Dictionary) -> void:
	level = lvl
	shooter = p_shooter
	defn = p_defn
	var an = p_shooter.get("attack_name")
	attack_name = str(an) if an != null else ""
	spec = p_defn.get("projectile", {})
	kind = str(spec.get("kind", "bolt"))
	dir = 1 if int(p_shooter.facing) >= 0 else -1
	speed = float(spec.get("speed", speed))
	max_range = float(spec.get("range", max_range))
	depth = float(spec.get("depth", depth))
	half_len = float(spec.get("half_len", half_len))
	pierce = bool(spec.get("pierce", pierce))
	explode_radius = float(spec.get("explode_radius", 0.0))
	explode_depth = float(spec.get("explode_depth", explode_depth))
	height = float(spec.get("height", height))
	var zz = p_shooter.get("z")
	if zz != null:
		height += float(zz)
	position = p_shooter.position + Vector2(dir * float(spec.get("spawn_dx", 40.0)), 0.0)
	tail_x = p_shooter.position.x                      # pierwszy test obejmuje też wroga tuż przy rzucającym
	z_index = 40
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## Prostokąt pocisku na płaszczyźnie podłoża (jak hitbox ataku wręcz).
func hit_rect() -> Rect2:
	return Rect2(position.x - half_len, position.y - depth, half_len * 2.0, depth * 2.0)

func explode_rect() -> Rect2:
	return Rect2(position.x - explode_radius, position.y - explode_depth, explode_radius * 2.0, explode_depth * 2.0)

func is_exploding() -> bool:
	return boom_t >= 0.0

func tick(delta: float) -> void:
	t += delta
	queue_redraw()
	if done:
		return
	if is_exploding():
		boom_t += delta
		if boom_t >= BOOM_TIME:
			done = true
		return
	var stepx: float = minf(speed * delta, max_range - travelled)
	position.x += dir * stepx
	travelled += stepx
	var r := hit_rect()
	r = r.merge(Rect2(minf(tail_x, position.x) - half_len, r.position.y, absf(position.x - tail_x) + half_len * 2.0, r.size.y))
	tail_x = position.x
	if level.projectile_blocker(r) != null:              # barykada zatrzymuje pocisk
		if explode_radius > 0.0:
			explode()
		else:
			done = true
			if level.fx != null:
				level.fx.burst(position + Vector2(0, -height), 8, Pal.r("ember", 1), 160.0, -dir)
		return
	for target in level.opponents_of(shooter):
		var tid: int = target.get_instance_id()
		if hit_ids.has(tid) or not target.can_be_hit():
			continue
		if not r.intersects(target.hurtbox_rect()):
			continue
		if not pierce:
			explode()
			return
		hit_ids.append(tid)
		hits += 1
		target.receive_hit(shooter, defn)
	if travelled >= max_range - 0.01 or position.x < -100.0 or position.x > level.level_w + 100.0:
		if explode_radius > 0.0:
			explode()
		else:
			done = true

## Wybuch kuli ognia: obrażenia dla wszystkich w promieniu (raz na cel), efekt i wstrząs.
func explode() -> void:
	boom_t = 0.0
	var r := explode_rect()
	level.strike_obstacles(attack_name, r)
	for target in level.opponents_of(shooter):
		var tid: int = target.get_instance_id()
		if hit_ids.has(tid) or not target.can_be_hit():
			continue
		if r.intersects(target.hurtbox_rect()):
			hit_ids.append(tid)
			hits += 1
			target.receive_hit(shooter, defn)
	if level.fx != null:
		level.fx.burst(position + Vector2(0, -height * 0.6), 18, Pal.r("fire", 5), 320.0, dir)
		level.fx.burst(position + Vector2(0, -height * 0.6), 10, Pal.r("ember", 1), 200.0, -dir)
	level.shake = maxf(level.shake, 8.0)
	Sfx.play("hit_heavy")

# ------------------------------------------------------------------ wygląd (tymczasowy, z palety; do podmiany na klatki)

func _px(v: Vector2) -> Vector2:
	return Vector2(roundf(v.x / 2.0) * 2.0, roundf(v.y / 2.0) * 2.0)

func _draw() -> void:
	if done:
		return
	if is_exploding():
		var k: float = clampf(boom_t / BOOM_TIME, 0.0, 1.0)
		var rad: float = explode_radius * (0.35 + 0.65 * k)
		var c0 := Pal.r("fire", 6)
		c0.a = 1.0 - k
		_ellipse(Vector2(0, 0), rad, explode_depth * (0.35 + 0.65 * k), Color(c0.r, c0.g, c0.b, 0.35 * (1.0 - k)))
		for i in 3:
			var c := Pal.rt("fire", 1.0 - float(i) / 3.0)
			c.a = 1.0 - k
			draw_circle(_px(Vector2(0, -height * 0.6)), rad * (0.55 - i * 0.15), c)
		return
	# poświata na ziemi: pokazuje, na której głębi leci pocisk
	_ellipse(Vector2.ZERO, half_len * 1.3, depth * 0.35, Color(Pal.r("fire", 4).r, Pal.r("fire", 4).g, Pal.r("fire", 4).b, 0.28))
	var head := Vector2(0, -height)
	var big: bool = kind == "fireball"
	var r0: float = 15.0 if big else 9.0
	# ogon płomienia
	var n: int = 7 if big else 6
	for i in range(n, 0, -1):
		var f: float = float(i) / float(n)
		var wob: float = sin(t * 30.0 + i * 1.7) * 2.0
		var p := head + Vector2(-dir * f * (54.0 if big else 46.0), wob)
		draw_circle(_px(p), r0 * (1.0 - f * 0.7), Pal.rt("ember", 0.2 + 0.6 * (1.0 - f)))
	draw_circle(_px(head), r0, Pal.r("fire", 4))
	draw_circle(_px(head + Vector2(dir * 2.0, 0)), r0 * 0.68, Pal.r("fire", 7))
	draw_circle(_px(head + Vector2(dir * 3.0, -1.0)), r0 * 0.36, Pal.r("white", 2))

func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var ang := TAU * i / 20.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	draw_colored_polygon(pts, col)
