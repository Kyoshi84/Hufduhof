class_name PoisonPool
extends Node2D
## Trująca kałuża spaczenia: bohater stojący w niej dostaje truciznę (obrażenia w czasie).

var level: Node
var radius: float = 46.0
var life: float = 5.0
var dps: float = 4.0
var age: float = 0.0
var spr: Sprite2D
var frames: Array = []

func setup(lvl: Node, pos: Vector2, r: float, duration: float, per_second: float) -> void:
	level = lvl
	position = pos
	radius = r
	life = duration
	dps = per_second
	for i in 2:
		var p := "res://assets/levels/common/fx/poison_pool_%d.png" % i
		if ResourceLoader.exists(p):
			frames.append(load(p))
	spr = Sprite2D.new()
	if not frames.is_empty():
		spr.texture = frames[0]
		spr.scale = Vector2.ONE * (r * 2.0 / spr.texture.get_width())
	add_child(spr)
	LightFx.make("spaczenie", self, Vector2.ZERO)

func _physics_process(delta: float) -> void:
	age += delta
	if not frames.is_empty():
		spr.texture = frames[int(age * 3.0) % frames.size()]
	spr.modulate.a = 1.0 if age < life - 1.0 else maxf(0.0, life - age)
	for a in level.actors_of_faction(0):
		if not a.is_dead() and Iso.dist(a.position, position) <= radius + a.body_radius * 0.5:
			a.add_dot(dps, 1.2, "trucizna")
	if age >= life:
		queue_free()
