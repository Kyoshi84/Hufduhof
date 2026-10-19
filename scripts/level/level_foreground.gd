class_name LevelForeground
extends Node2D
## Opcjonalny pierwszy plan (foreground.png w folderze etapu) przy dolnej krawędzi ekranu.
## Rysowany przed postaciami, więc plik NIE powinien wchodzić w pas walki (max ~67 px wysokości).

var bg   # LevelBackground

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	if bg == null or bg.level == null:
		return
	var lv = bg.level
	var vl: float = lv.view_left
	var stage: int = bg._stage_index_at(vl + lv.view_w * 0.5)
	var sa: StageArt = bg.art[stage] if stage < bg.art.size() else null
	if sa == null:
		return
	var ly: Dictionary = sa.layer("foreground")
	if ly.is_empty():
		return
	bg.draw_tiled(self, ly, vl, lv.view_w, 360.0 + lv.view_h * 0.5)
