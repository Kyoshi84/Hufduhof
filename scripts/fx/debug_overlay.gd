class_name DebugOverlay
extends Node2D
## Nakładka diagnostyczna kolizji (F3 w buildach debug). Rysuje te same prostokąty, których używa
## logika walki: hitbox ataku (aktywny = czerwony wypełniony, zamach = żółty obrys), hurtboxy stóp (zielone),
## słupy ciała, pivot, kierunek ataku oraz wynik ostatniego sprawdzenia kolizji dla każdego celu.

var level
var _font: Font = ThemeDB.fallback_font

func _ready() -> void:
	z_index = 200

func _process(_d: float) -> void:
	if visible != GameState.debug_collision:
		visible = GameState.debug_collision
	if visible:
		queue_redraw()

func _draw() -> void:
	if level == null or not GameState.debug_collision:
		return
	var actors: Array = [level.player]
	actors.append_array(level.enemies)
	for a in actors:
		if a == null or not is_instance_valid(a):
			continue
		_draw_actor(a)
	for b in level.barrels:
		if is_instance_valid(b):
			_draw_rect_outline(b.hurtbox_rect(), Color(0.2, 1.0, 0.3, 0.9))

func _draw_rect_outline(r: Rect2, c: Color, w: float = 2.0) -> void:
	draw_rect(r, c, false, w)

func _draw_actor(a) -> void:
	var hurt: Rect2 = a.hurtbox_rect()
	var col := Color(0.2, 1.0, 0.3, 0.95) if a.can_be_hit() else Color(0.6, 0.6, 0.6, 0.9)
	_draw_rect_outline(hurt, col)
	# słup ciała (zasięg poziomy hurtboxa w górę) i pivot stóp
	draw_rect(Rect2(hurt.position.x, a.position.y - 110.0, hurt.size.x, 110.0), Color(0.2, 0.8, 1.0, 0.25), false, 1.0)
	draw_line(a.position + Vector2(-8, 0), a.position + Vector2(8, 0), Color(1, 1, 0), 2.0)
	draw_line(a.position + Vector2(0, -8), a.position + Vector2(0, 8), Color(1, 1, 0), 2.0)
	if not a.is_attacking():
		return
	var r: Rect2 = a.hitbox_rect()
	if a.state == Actor.State.ACTIVE:
		draw_rect(r, Color(1.0, 0.1, 0.1, 0.28))
		_draw_rect_outline(r, Color(1.0, 0.2, 0.2), 3.0)
	elif a.state == Actor.State.WINDUP:
		_draw_rect_outline(r, Color(1.0, 0.9, 0.2, 0.8), 1.0)
	# strzałka kierunku ataku
	var y: float = a.position.y
	var tip := Vector2(a.position.x + a.facing * 70.0, y)
	draw_line(Vector2(a.position.x, y), tip, Color(1, 0.6, 0.1), 3.0)
	draw_line(tip, tip + Vector2(-a.facing * 12.0, -8), Color(1, 0.6, 0.1), 3.0)
	draw_line(tip, tip + Vector2(-a.facing * 12.0, 8), Color(1, 0.6, 0.1), 3.0)
	var label := "%s [%s] hitbox:%s" % [a.attack_name, ["IDLE", "MOVE", "ZAMACH", "AKTYWNY", "POWRÓT", "HURT", "UNIK", "DEAD", "VICTORY"][a.state], "WŁ" if a.hitbox_active() else "wył"]
	draw_string(_font, Vector2(r.position.x, r.position.y - 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.9, 0.5))
	# wynik ostatniego sprawdzenia kolizji dla każdego celu
	var i := 0
	for rep in a.last_report:
		var t = rep["target"]
		if not is_instance_valid(t):
			continue
		var c := Color(0.3, 1, 0.3) if rep["result"] == "hit" else Color(1, 0.5, 0.3)
		draw_string(_font, t.position + Vector2(-24, 16.0 + i * 0.0), str(rep["result"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, c)
		i += 1
