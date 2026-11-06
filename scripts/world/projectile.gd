class_name Projectile
extends Node2D
## Pocisk lecący po prostej (kamień procarza, niebieski pocisk Modraszki). Rzut na trafienie (US strzelca
## przeciw Zr celu) przy zetknięciu - przy pudle pocisk leci dalej. Zatrzymuje się na ścianach.

var shooter: Actor
var faction: int = 1
var dir := Vector2.RIGHT
var speed: float = 230.0
var max_dist: float = 400.0
var travelled: float = 0.0
var dmg: int = 3
var kind: String = "stone"
var height: float = 30.0
var level: Node
var spr: Sprite2D
var missed: Array = []

func setup(lvl: Node, k: String, from: Actor, pos: Vector2, d: Vector2, spd: float, dist: float, damage: int) -> void:
	level = lvl
	kind = k
	shooter = from
	faction = from.faction
	position = pos
	dir = d.normalized()
	speed = spd
	max_dist = dist
	dmg = damage
	spr = Sprite2D.new()
	var p := "res://assets/levels/common/fx/%s.png" % k
	if ResourceLoader.exists(p):
		spr.texture = load(p)
	spr.position = Vector2(0, -height)
	add_child(spr)

func _physics_process(delta: float) -> void:
	var step := Iso.screen(Iso.ground(dir).normalized()) * speed * delta
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(position, position + step, 1)
	if not space.intersect_ray(q).is_empty():
		_impact(null)
		return
	position += step
	travelled += step.length() if absf(step.y) < 0.001 else Iso.ground(step).length()
	spr.rotation += delta * 8.0 if kind == "stone" else 0.0
	for a in level.actors_of_faction(1 - faction):
		if a.is_dead() or a in missed:
			continue
		if Iso.dist(position, a.position) <= a.body_radius + 8.0:
			if shooter and is_instance_valid(shooter) and Rules.ranged_roll(shooter.stats, a.stats, a.rng):
				var d: int = Rules.projectile_damage(shooter.stats, dmg, a.stats) if kind == "stone" else dmg
				a.receive_hit({"hit": true, "damage": d, "kind": "fiz" if kind == "stone" else "magia"}, shooter)
				_impact(a)
				return
			missed.append(a)
			a.receive_hit({"hit": false}, shooter)
	if travelled >= max_dist:
		_impact(null)
	queue_redraw()

func _impact(_who) -> void:
	if kind == "magic_bolt":
		Fx.ring(level.decal_parent(), position, 18.0, Color(0.6, 0.8, 1.0), 0.2)
	queue_free()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.35))
