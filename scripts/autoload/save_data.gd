extends Node
## Ustawienia i checkpoint zapisywane w user://savegame.cfg.

var path: String = "user://savegame.cfg"
var music_volume: float = 0.7
var sfx_volume: float = 0.9
var touch_mode: int = 0          # 0 = auto, 1 = włączone, 2 = wyłączone
var best_score: int = 0
var checkpoint: Dictionary = {}  # { wave, score, kills }

func _ready() -> void:
	load_all()

func load_all() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	music_volume = float(cfg.get_value("settings", "music_volume", music_volume))
	sfx_volume = float(cfg.get_value("settings", "sfx_volume", sfx_volume))
	touch_mode = int(cfg.get_value("settings", "touch_mode", touch_mode))
	best_score = int(cfg.get_value("progress", "best_score", 0))
	var cp = cfg.get_value("progress", "checkpoint", {})
	checkpoint = cp if typeof(cp) == TYPE_DICTIONARY else {}

func save_all() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("settings", "touch_mode", touch_mode)
	cfg.set_value("progress", "best_score", best_score)
	cfg.set_value("progress", "checkpoint", checkpoint)
	cfg.save(path)

func has_checkpoint() -> bool:
	return checkpoint.has("wave") and int(checkpoint["wave"]) > 0

func set_checkpoint(wave: int, score: int, kills: int) -> void:
	checkpoint = { "wave": wave, "score": score, "kills": kills }
	save_all()

func clear_checkpoint() -> void:
	checkpoint = {}
	save_all()

func submit_score(score: int) -> void:
	if score > best_score:
		best_score = score
		save_all()

func touch_controls_visible() -> bool:
	if touch_mode == 1:
		return true
	if touch_mode == 2:
		return false
	return DisplayServer.is_touchscreen_available()
