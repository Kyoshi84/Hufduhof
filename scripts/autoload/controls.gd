extends Node
## Sterowanie: akcje wejścia (klawiatura, mysz) rejestrowane w kodzie + wirtualny joystick dotykowy.
## PC: WASD/strzałki ruch, LPM/J atak (w stronę kursora), PPM/K umiejętność, Q/1 mikstura życia, R/2 mikstura many,
##     E/F interakcja, M/Tab mapa, C postać, I plecak, Esc pauza, F3 diagnostyka kolizji, kółko myszy - zoom.

const ACTIONS := {
	"ruch_gora": [KEY_W, KEY_UP], "ruch_dol": [KEY_S, KEY_DOWN],
	"ruch_lewo": [KEY_A, KEY_LEFT], "ruch_prawo": [KEY_D, KEY_RIGHT],
	"atak": [KEY_J, KEY_SPACE], "umiejetnosc": [KEY_K],
	"mikstura_zycia": [KEY_Q, KEY_1], "mikstura_many": [KEY_R, KEY_2],
	"interakcja": [KEY_E, KEY_F], "mapa": [KEY_M, KEY_TAB], "postac": [KEY_C], "plecak": [KEY_I],
	"pauza": [KEY_ESCAPE, KEY_P], "debug": [KEY_F3],
}
const MOUSE := {"atak": MOUSE_BUTTON_LEFT, "umiejetnosc": MOUSE_BUTTON_RIGHT}

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
	for action in MOUSE:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE[action]
		InputMap.action_add_event(action, mb)

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
