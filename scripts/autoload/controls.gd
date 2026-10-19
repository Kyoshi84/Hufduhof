extends Node
## Zunifikowane sterowanie: klawiatura (testy na PC) + wirtualny joystick i przyciski dotykowe.

signal pause_pressed
signal debug_pressed

var touch_move := Vector2.ZERO
var _stamp := { "light": -100000, "heavy": -100000, "dodge": -100000 }

func reset() -> void:
	touch_move = Vector2.ZERO
	for k in _stamp.keys():
		_stamp[k] = -100000

func press(action: String) -> void:
	_stamp[action] = Time.get_ticks_msec()

## Zwraca true, jeśli akcja została wciśnięta w ostatnich `window_ms` ms (bufor wejścia).
func consume(action: String, window_ms: int = 150) -> bool:
	if Time.get_ticks_msec() - int(_stamp[action]) <= window_ms:
		_stamp[action] = -100000
		return true
	return false

func get_move() -> Vector2:
	var v := touch_move
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1.0
	if v.length() > 1.0:
		v = v.normalized()
	return v

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_J, KEY_Z: press("light")
			KEY_K, KEY_X: press("heavy")
			KEY_L, KEY_C, KEY_SPACE: press("dodge")
			KEY_ESCAPE, KEY_P: pause_pressed.emit()
			KEY_F3:
				if OS.is_debug_build():
					GameState.debug_collision = not GameState.debug_collision
					debug_pressed.emit()
