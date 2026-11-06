class_name Projectile
extends Node2D
## Pocisk lecący po prostej: kamień procarza, strzała Modraszki, ognisty pocisk / kula ognia Ursy.
##  rzut = true  - przy zetknięciu rzut na trafienie (US strzelca przeciw Zr celu); przy pudle pocisk leci dalej.
##                 Obrażenia = obrażenia broni + S strzelca - Wt celu.
##  rzut = false - czar: trafia zawsze, obrażenia policzone wcześniej (albo czar_bazowe -> Rules.spell_damage).
##  wybuch > 0   - przy trafieniu / na końcu lotu wybucha i rani wszystkich w promieniu (+ podpalenie).
## Zatrzymuje się na ścianach.

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
var level: Node
var spr: Sprite2D
var missed: Array = []
var _done: bool = false

func setup(lvl: Node, k: String, from: Actor, pos: Vector2, d: Vector2, spd: float, dist: float, damage: int, options: Dictionary = {}) -> void:
	level = lvl
	kind = k
	shooter = from
	faction = from.faction
	position = pos
	dir = d.normalized()
	speed = spd
	max_dist = dist
	dmg = damage
	opts = options
	if not opts.has("rzut"):
		opts["rzut"] = kind in ["stone", "arrow"]
	height = 30.0 if kind == "stone" else 52.0
	spr = Sprite2D.new()
	var p := "res://assets/levels/common/fx/%s.png" % k
	if ResourceLoader.exists(p):
		spr.texture = load(p)
	spr.position = Vector2(0, -height)
	spr.scale = Vector2.ONE * float(opts.get("skala", 1.0))
	if kind == "arrow":
		spr.rotation = dir.angle()
	add_child(spr)

func _physics_process(delta: float) -> void:
	if _done:
		return
	var step := Iso.screen(Iso.ground(dir).normalized()) * speed * delta
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(position, position + step, 1)
	if not space.intersect_ray(q).is_empty():
		_impact(null)
		return
	position += step
	travelled += Iso.ground(step).length()
	if kind == "stone":
		spr.rotation += delta * 8.0
	for a in level.actors_of_faction(1 - faction):
		if a.is_dead() or a in missed:
			continue
		if Iso.dist(position, a.position) <= a.body_radius + 8.0:
			if not opts["rzut"] or (shooter and is_instance_valid(shooter) and Rules.ranged_roll(shooter.stats, a.stats, a.rng)):
				_hit(a)
				_impact(a)
				return
			missed.append(a)
			a.receive_hit({"hit": false}, shooter)
	if travelled >= max_dist:
		_impact(null)
	queue_redraw()

func _hit(a: Actor) -> void:
	if float(opts.get("wybuch", 0.0)) > 0.0:
		return   # obrażenia zada wybuch
	var d: int = dmg
	if opts["rzut"] and shooter and is_instance_valid(shooter):
		d = Rules.projectile_damage(shooter.stats, dmg, a.stats)
	a.receive_hit({"hit": true, "damage": d, "kind": "fiz" if opts["rzut"] else "ogien" if kind == "fireball" else "magia"}, shooter)

func _impact(_who) -> void:
	_done = true
	var r := float(opts.get("wybuch", 0.0))
	if r > 0.0:
		Audio.play("fire", 0.7)
		Fx.ring(level.decal_parent(), position, r, Color(1.0, 0.55, 0.15), 0.45)
		Fx.ring(level.decal_parent(), position, r * 0.6, Color(1.0, 0.85, 0.3), 0.3)
		level.shake(4.0)
		for a in level.actors_of_faction(1 - faction):
			if a.is_dead() or Iso.dist(a.position, position) > r + a.body_radius:
				continue
			var d: int = dmg
			if opts.has("czar_bazowe") and shooter and is_instance_valid(shooter):
				d = Rules.spell_damage(int(opts["czar_bazowe"]), shooter.stats, a.stats)
			a.receive_hit({"hit": true, "damage": d, "kind": "ogien"}, shooter)
			var burn: Array = opts.get("podpalenie", [])
			if burn.size() == 2:
				a.add_dot(float(burn[0]), float(burn[1]), "ogien")
	elif kind == "magic_bolt" or kind == "fireball":
		Fx.ring(level.decal_parent(), position, 18.0, Color(1.0, 0.6, 0.2) if kind == "fireball" else Color(0.6, 0.8, 1.0), 0.2)
	queue_free()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.35))
