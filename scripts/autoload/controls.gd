extends Node
## Sterowanie: akcje wejścia (klawiatura, mysz) rejestrowane w kodzie + wirtualny joystick dotykowy.
## PC: WASD/strzałki ruch, LPM/J/Spacja atak główny (slot 1, bez many - atak bronią), PPM/K slot 2,
##     1-9 i 0 (górny rząd i klawiatura numeryczna) - sloty paska, Q mikstura życia, R mikstura many,
##     E/F interakcja, M/Tab mapa, C postać, I plecak, Esc pauza, F3 diagnostyka kolizji, kółko myszy - zoom.

const ACTIONS := {
	"ruch_gora": [KEY_W, KEY_UP], "ruch_dol": [KEY_S, KEY_DOWN],
	"ruch_lewo": [KEY_A, KEY_LEFT], "ruch_prawo": [KEY_D, KEY_RIGHT],
	"atak": [KEY_J, KEY_SPACE], "umiejetnosc": [KEY_K],
	"mikstura_zycia": [KEY_Q], "mikstura_many": [KEY_R],
	"interakcja": [KEY_E, KEY_F], "mapa": [KEY_M, KEY_TAB], "postac": [KEY_C], "plecak": [KEY_I],
	"pauza": [KEY_ESCAPE, KEY_P], "debug": [KEY_F3],
}
## Mysz NIE jest przypięta do akcji: klik w przycisk interfejsu (np. slot paska) nie może odpalać ataku.
## Przyciski myszy nad światem gry obsługuje Level._unhandled_input.

var joy: Vector2 = Vector2.ZERO       # wektor z wirtualnego joysticka (-1..1)
var aim_mouse: bool = false           # ostatni atak był myszą -> celuj w kursor
var test_move = null                  # testy: wymuszony kierunek ruchu

func _ready() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	# sloty paska umiejętności: 1-9, 0 w górnym rzędzie i na klawiaturze numerycznej
	var top := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
	var kp := [KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9, KEY_KP_0]
	for i in 10:
		var action := "slot_%d" % (i + 1)
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key in [top[i], kp[i]]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
			var ev2 := InputEventKey.new()
			ev2.keycode = key
			InputMap.action_add_event(action, ev2)

func move_vector() -> Vector2:
	if test_move != null:
		return test_move
	if joy.length() > 0.15:
		return joy.limit_length(1.0)
	return Input.get_vector("ruch_lewo", "ruch_prawo", "ruch_gora", "ruch_dol")

func reset() -> void:
	joy = Vector2.ZERO
	for a in ACTIONS:
		Input.action_release(a)
	for i in 10:
		Input.action_release("slot_%d" % (i + 1))
