extends Node
## Wynik, licznik pokonanych wrogów i flagi debugowe bieżącej rozgrywki.

var score: int = 0
var kills: int = 0
var god_mode: bool = false   # tylko do testów automatycznych

func reset() -> void:
	score = 0
	kills = 0

func add_kill(points: int) -> void:
	kills += 1
	score += points

func add_score(points: int) -> void:
	score += points

## Tryb diagnostyczny kolizji (domyślnie wyłączony; dostępny tylko w buildach debug).
var debug_collision: bool = false
