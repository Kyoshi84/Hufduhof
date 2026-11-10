class_name WarpOrb
extends Node2D
## Kula spaczenia czarownika: leci łukiem w zaznaczone wcześniej miejsce (zielone koło), przy upadku rani
## stojących w promieniu i zostawia trującą kałużę (obrażenia w czasie; odporność z SW).

var level: Node
var caster: Actor
var from := Vector2.ZERO
var to := Vector2.ZERO
var t: float = 0.0
var dur: float = 0.8
var cfg: Dictionary = {}
var spr: Sprite2D

func setup(lvl: Node, c: Actor, a: Vector2, b: Vector2, enemy_def: Dictionary) -> void:
	level = lvl
	caster = c
	from = a
	to = b
	dur = float(enemy_def.get("czas_lotu", 0.8))
	cfg = enemy_def.get("spaczenie", {})
	position = a
	spr = Sprite2D.new()
	var p := "res://assets/levels/common/fx/warp_orb.png"
	if ResourceLoader.exists(p):
		spr.texture = load(p)
	add_child(spr)
	LightFx.make("spaczenie", spr, Vector2(0, 20))

func _physics_process(delta: float) -> void:
	t += delta
	var k := clampf(t / dur, 0.0, 1.0)
	position = from.lerp(to, k)
	spr.position = Vector2(0, -40.0 - sin(k * PI) * 90.0)
	queue_redraw()
	if k >= 1.0:
		_land()

func _land() -> void:
	Audio.play("warp", 0.8)
	var r := float(cfg.get("kaluza_promien", 46))
	Fx.ring(level.decal_parent(), to, r, Color(0.45, 1.0, 0.3), 0.4)
	for a in level.actors_of_faction(0):
		if not a.is_dead() and Iso.dist(a.position, to) <= r + a.body_radius:
			var dmg := float(cfg.get("obrazenia_trafienia", 6)) * Rules.poison_factor(a.stats.val("SW"))
			a.receive_hit({"hit": true, "damage": maxf(1.0, round(dmg)), "kind": "trucizna"}, caster)
	var pool := PoisonPool.new()
	pool.setup(level, to, r, float(cfg.get("kaluza_czas", 5.0)), float(cfg.get("kaluza_na_sekunde", 4)))
	level.decal_parent().add_child(pool)
	queue_free()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.3))
