extends Node
## Zapis gry (jeden slot) i ustawień w katalogu użytkownika (user://).

const SAVE_PATH := "user://zapis.json"
const SETTINGS_PATH := "user://ustawienia.json"

var music_volume: float = 0.8
var sfx_volume: float = 0.9
var touch_mode: int = 0          # 0 = auto, 1 = zawsze, 2 = nigdy
var palette_filter: bool = true
var last_hero: String = "ivo"
var save_path: String = SAVE_PATH   # testy podmieniają ścieżkę

func _ready() -> void:
	load_settings()

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

func save_game(pos: Vector2) -> bool:
	if Game.hero == null:
		return false
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_error("Nie można zapisać gry: " + save_path)
		return false
	f.store_string(JSON.stringify(Game.to_save_dict(pos), " "))
	f.close()
	return true

func load_game() -> bool:
	if not has_save():
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not d is Dictionary:
		return false
	return Game.load_from_dict(d)

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if not d is Dictionary:
		return
	music_volume = float(d.get("music", music_volume))
	sfx_volume = float(d.get("sfx", sfx_volume))
	touch_mode = int(d.get("touch", touch_mode))
	palette_filter = bool(d.get("palette", palette_filter))
	last_hero = str(d.get("last_hero", last_hero))

func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"music": music_volume, "sfx": sfx_volume, "touch": touch_mode,
		"palette": palette_filter, "last_hero": last_hero}))
	f.close()

func touch_enabled() -> bool:
	if touch_mode == 1:
		return true
	if touch_mode == 2:
		return false
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
