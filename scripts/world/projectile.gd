class_name Projectile
extends Node2D
## Pocisk lecący po prostej: kamień procarza, strzała Modraszki, pociski ognia Ursy.
##
## Trafienie: w każdej klatce sprawdzany jest CAŁY odcinek ruchu (od poprzedniej do nowej pozycji), a nie tylko punkt
## końcowy - szybki pocisk nie "przeskoczy" wroga nawet przy niskim FPS. Hitbox = promien_trafienia pocisku + promień
## ciała celu, w mierze podłoża (niezależny od rozmiaru sprite'a).
##  skill (bohater)  - obrażenia liczy bohater (Hero.skill_hit): kontakt zawsze rani, nieudany rzut = draśnięcie.
##  bez skill (wróg) - rzut na US przy kontakcie; przy pudle kamień leci dalej.
##  przebicie N      - przelatuje przez N wrogów.  wybuch R - przy trafieniu/na końcu lotu rani wszystkich w promieniu R.
##  soft_aim         - pomoc w celowaniu: lekko skręca do wroga w stożku przed sobą (data/balance.json -> celowanie).

var shooter: Actor
var faction: int = 1
var dir := Vector2.RIGHT
var speed: float = 230.0
var max_dist: float = 400.0
var travelled: float = 0.0
var dmg: int = 3
var kind: String = "stone"
var opts: Dictionary = {}
var height: float = 30.0
var hit_r: float = 8.0
var level: Node
var spr: Sprite2D
var ignored: Array = []          # cele już trafione (przebicie) albo ominięte (pudło wroga)
var pierce_left: int = 1
var start_pos := Vector2.ZERO
var _done: bool = false

func setup(lvl: Node, k: String, from: Actor, pos: Vector2, d: Vector2, spd: float, dist: float, damage: int, options: Dictionary = {}) -> void:
	level = lvl
	kind = k
	shooter = from
	faction = from.faction
	position = pos
	start_pos = pos
	dir = d.normalized()
	speed = spd
	max_dist = dist
	dmg = damage
	opts = options
	if not opts.has("rzut"):
		opts["rzut"] = not opts.has("skill") and kind in ["stone", "arrow"]
	hit_r = float(opts.get("promien_trafienia", 8.0))
	pierce_left = maxi(1, int(opts.get("przebicie", 1)))
	height = 30.0 if kind == "stone" else 48.0
	spr = Sprite2D.new()
	var p := "res://assets/levels/common/fx/%s.png" % k
	if not ResourceLoader.exists(p):
		p = "res://assets/levels/common/fx/%s.png" % ("arrow" if "arrow" in k else "fireball")
	if ResourceLoader.exists(p):
		spr.texture = load(p)
	spr.position = Vector2(0, -height)
	spr.scale = Vector2.ONE * float(opts.get("skala", 1.0))
	add_child(spr)
	_orient()

func _orient() -> void:
	if kind != "stone":
		spr.rotation = dir.angle()

## Odległość (w mierze podłoża) punktu c od odcinka a-b.
static func seg_dist(a: Vector2, b: Vector2, c: Vector2) -> float:
	var ga := Iso.ground(a)
	var gb := Iso.ground(b)
	var gc := Iso.ground(c)
	var ab := gb - ga
	var t := 0.0 if ab.length_squared() < 0.0001 else clampf((gc - ga).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (ga + ab * t).distance_to(gc)

func _physics_process(delta: float) -> void:
	step(delta)

func step(delta: float) -> void:
	if _done:
		return
	if bool(opts.get("soft_aim", false)):
		_steer(delta)
	var move := Iso.screen(Iso.ground(dir).normalized()) * speed * delta
	var remaining := max_dist - travelled
	var glen := Iso.ground(move).length()
	if glen > remaining and glen > 0.0:
		move *= remaining / glen
		glen = remaining
	var from := position
	var to := position + move
	# ściany: promień od poprzedniej do nowej pozycji
	var wall_t := 2.0
	if is_inside_tree():
		var q := PhysicsRayQueryParameters2D.create(from, to, 1)
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			wall_t = from.distance_to(hit["position"]) / maxf(0.001, from.distance_to(to))
			to = hit["position"]
	# cele na odcinku, od najbliższego
	var cands: Array = []
	for a in level.actors_of_faction(1 - faction):
		if a.is_dead() or a in ignored:
			continue
		if seg_dist(from, to, a.position) <= a.body_radius + hit_r:
			cands.append(a)
	cands.sort_custom(func(x, y): return Iso.dist(from, x.position) < Iso.dist(from, y.position))
	for a in cands:
		if _try_hit(a):
			pierce_left -= 1
			if pierce_left <= 0:
				position = a.position
				_impact()
				return
	position = to
	travelled += glen
	if kind == "stone":
		spr.rotation += delta * 8.0
	if wall_t <= 1.0 or travelled >= max_dist - 0.01:
		_impact()
		return
	queue_redraw()

## Pomoc w celowaniu w locie: skręt (ograniczony stopniami na sekundę) do najbliższego kątowo wroga w stożku.
func _steer(delta: float) -> void:
	var cone := deg_to_rad(float(Data.bal("celowanie/stozek_stopni", 30))) * 0.5
	var gd := Iso.ground(dir).normalized()
	var best_g := Vector2.ZERO
	var best_a := cone
	for a in level.actors_of_faction(1 - faction):
		if a.is_dead() or a in ignored:
			continue
		var g := Iso.ground(a.position - position)
		if g.length() < 1.0 or g.length() > max_dist - travelled + a.body_radius:
			continue
		var ang := absf(gd.angle_to(g))
		if ang <= best_a:
			best_a = ang
			best_g = g
	if best_g == Vector2.ZERO:
		return
	var turn := deg_to_rad(float(Data.bal("celowanie/skret_stopni_na_sekunde", 220))) * delta
	var want := gd.angle_to(best_g)
	gd = gd.rotated(clampf(want, -turn, turn))
	dir = Iso.screen(gd).normalized()
	_orient()

func _try_hit(a: Actor) -> bool:
	if opts.has("skill"):
		ignored.append(a)
		if float(opts.get("wybuch", 0.0)) > 0.0:
			return true   # obrażenia zada wybuch
		if shooter and is_instance_valid(shooter) and shooter.has_method("skill_hit"):
			var res: Dictionary = shooter.skill_hit(opts["skill"], a, true)
			a.receive_hit(res, shooter)
			_after_hit(a)
		return true
	if not opts["rzut"] or (shooter and is_instance_valid(shooter) and Rules.ranged_roll(shooter.stats, a.stats, a.rng)):
		var d: int = dmg
		if opts["rzut"] and shooter and is_instance_valid(shooter):
			d = Rules.projectile_damage(shooter.stats, dmg, a.stats)
		a.receive_hit({"hit": true, "damage": d, "kind": "fiz"}, shooter)
		return true
	ignored.append(a)
	a.receive_hit({"hit": false}, shooter)
	return false

func _after_hit(a: Actor) -> void:
	var sk: Dictionary = opts.get("skill", {})
	if a.has_method("knockback"):
		a.knockback(Iso.ground(dir).normalized() * float(Data.bal("walka_bohatera/odrzut_trafienia", 10)))
	if sk.has("podpalenie_na_sekunde"):
		a.add_dot(float(sk["podpalenie_na_sekunde"]), float(sk.get("podpalenie_czas", 3.0)), "ogien")
	if sk.has("spowolnienie") and a.has_method("apply_slow"):
		a.apply_slow(float(sk["spowolnienie"]), float(sk.get("spowolnienie_czas", 3.0)))

func _impact() -> void:
	_done = true
	var r := float(opts.get("wybuch", 0.0))
	var sk: Dictionary = opts.get("skill", {})
	if r > 0.0:
		var net := sk.has("spowolnienie")
		Audio.play("fire" if not net else "miss", 0.7)
		Fx.ring(level.decal_parent(), position, r, Color(1.0, 0.55, 0.15) if not net else Color(0.75, 0.7, 0.55), 0.45)
		Fx.ring(level.decal_parent(), position, r * 0.6, Color(1.0, 0.85, 0.3) if not net else Color(0.9, 0.85, 0.7), 0.3)
		if not net:
			level.shake(4.0)
		for a in level.actors_of_faction(1 - faction):
			if a.is_dead() or Iso.dist(a.position, position) > r + a.body_radius:
				continue
			if shooter and is_instance_valid(shooter) and shooter.has_method("skill_hit"):
				var res: Dictionary = shooter.skill_hit(sk, a, true)
				res["kind"] = "ogien" if not net else "fiz"
				a.receive_hit(res, shooter)
			_after_hit(a)
	elif kind in ["fireball", "fire_lance", "magic_bolt"]:
		Fx.ring(level.decal_parent(), position, 18.0, Color(1.0, 0.6, 0.2), 0.2)
	queue_free()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.35))
	if Game.debug_collision:
		draw_arc(Vector2.ZERO, hit_r, 0, TAU, 20, Color(1, 0.3, 1), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if Game.debug_collision:
		draw_line(start_pos - position, Vector2.ZERO, Color(1, 0.3, 1, 0.6), 1.0)
		draw_line(Vector2.ZERO, Iso.screen(Iso.ground(dir).normalized() * (max_dist - travelled)), Color(1, 0.3, 1, 0.25), 1.0)
