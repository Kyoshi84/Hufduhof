class_name Hud
extends CanvasLayer
## HUD: zdrowie Ivo, wynik, licznik pokonanych, pasek bossa, przycisk pauzy, banery, sterowanie dotykowe.

var level
var canvas: Control
var score_label: Label
var kills_label: Label
var banner_label: Label
var banner_t: float = 0.0
var damage_flash: float = 0.0
var touch: TouchControls
var t: float = 0.0

func _ready() -> void:
	layer = 10
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.theme = UI.theme()
	add_child(canvas)
	canvas.draw.connect(_draw_hud)
	score_label = UI.make_label("", 30)
	score_label.position = Vector2(300, 18)
	canvas.add_child(score_label)
	kills_label = UI.make_label("", 24, Color(0.8, 0.75, 0.62))
	kills_label.position = Vector2(300, 56)
	canvas.add_child(kills_label)
	banner_label = UI.make_label("", 52, Color(0.9, 0.78, 0.45))
	banner_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_label.size = Vector2(1280, 80)
	banner_label.visible = false
	canvas.add_child(banner_label)
	var pause := Button.new()
	pause.text = "II"
	pause.custom_minimum_size = Vector2(72, 64)
	pause.process_mode = Node.PROCESS_MODE_ALWAYS
	pause.pressed.connect(func():
		Sfx.play("ui_click")
		level.toggle_pause())
	canvas.add_child(pause)
	pause.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause.position = Vector2(get_viewport().get_visible_rect().size.x - 96, 16)
	canvas.get_viewport().size_changed.connect(func():
		pause.position = Vector2(canvas.get_viewport_rect().size.x - 96, 16)
		banner_label.position.x = (canvas.get_viewport_rect().size.x - banner_label.size.x) * 0.5)
	banner_label.position.x = (get_viewport().get_visible_rect().size.x - banner_label.size.x) * 0.5
	banner_label.position.y = 200
	if SaveData.touch_controls_visible():
		touch = TouchControls.new()
		canvas.add_child(touch)

func show_banner(text: String, secs: float) -> void:
	banner_label.text = text
	banner_label.visible = true
	banner_t = secs

func flash_damage() -> void:
	damage_flash = 0.35

func _process(delta: float) -> void:
	t += delta
	score_label.text = "WYNIK  %d" % GameState.score
	kills_label.text = "Pokonani: %d" % GameState.kills
	if banner_t > 0.0:
		banner_t -= delta
		banner_label.modulate.a = clampf(banner_t / 0.5, 0.0, 1.0)
		if banner_t <= 0.0:
			banner_label.visible = false
	damage_flash = maxf(0.0, damage_flash - delta)
	canvas.queue_redraw()

func _draw_hud() -> void:
	var p = level.player
	if p == null:
		return
	var size_v: Vector2 = canvas.get_viewport_rect().size
	# pasek zdrowia Ivo
	var bx := 24.0
	var by := 22.0
	var bw := 250.0
	canvas.draw_rect(Rect2(bx - 3, by - 3, bw + 6, 34), Color(0.05, 0.03, 0.03, 0.85))
	canvas.draw_rect(Rect2(bx, by, bw * clampf(p.hp / p.max_hp, 0.0, 1.0), 28), Color(0.72, 0.1, 0.1))
	canvas.draw_rect(Rect2(bx - 3, by - 3, bw + 6, 34), Color(0.72, 0.58, 0.28), false, 2.0)
	canvas.draw_string(ThemeDB.fallback_font, Vector2(bx + 6, by + 22), "IVO", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.9))
	# pasek bossa
	var b = level.boss
	if b != null and is_instance_valid(b) and b.is_alive():
		var w := minf(size_v.x - 400.0, 760.0)
		var x := (size_v.x - w) * 0.5
		var y := 128.0
		canvas.draw_rect(Rect2(x - 4, y - 4, w + 8, 30), Color(0.05, 0.03, 0.03, 0.9))
		canvas.draw_rect(Rect2(x, y, w * clampf(b.hp / b.max_hp, 0.0, 1.0), 22), Color(0.55, 0.05, 0.12))
		for th in b.thresholds:
			var tx: float = x + w * float(th)
			canvas.draw_line(Vector2(tx, y - 4), Vector2(tx, y + 26), Color(0.9, 0.8, 0.5, 0.8), 2.0)
		canvas.draw_rect(Rect2(x - 4, y - 4, w + 8, 30), Color(0.72, 0.58, 0.28), false, 2.0)
		canvas.draw_string(ThemeDB.fallback_font, Vector2(x, y - 10), "CZEMPION CHAOSU  -  FAZA %d" % b.phase, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 0.8, 0.6))
	# strzałka "idź"
	if level.go_prompt and not level.locked:
		var a: float = 0.5 + 0.5 * sin(t * 6.0)
		var cx: float = size_v.x - 120.0
		var cy: float = 330.0
		var col := Color(0.95, 0.8, 0.3, 0.35 + 0.5 * a)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(cx, cy - 30), Vector2(cx + 50, cy), Vector2(cx, cy + 30), Vector2(cx, cy + 12), Vector2(cx - 40, cy + 12), Vector2(cx - 40, cy - 12), Vector2(cx, cy - 12)]), col)
	if GameState.debug_collision:
		canvas.draw_string(ThemeDB.fallback_font, Vector2(24, size_v.y - 20), "DIAGNOSTYKA KOLIZJI (F3): czerwony=aktywny hitbox, zielony=hurtbox stóp", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.9, 0.4))
	# błysk po otrzymaniu obrażeń
	if damage_flash > 0.0:
		canvas.draw_rect(Rect2(0, 0, size_v.x, size_v.y), Color(0.7, 0.0, 0.0, damage_flash * 0.5))
