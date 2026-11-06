class_name PaletteFilter
extends CanvasLayer
## Końcowy filtr obrazu: cały ekran (świat + interfejs) sprowadzany do palety 256 kolorów
## (shader assets/palette/palette.gdshader + tablica LUT 32^3). Wyłączalny w Ustawieniach.

func _ready() -> void:
	layer = 100
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/palette/palette.gdshader")
	mat.set_shader_parameter("lut", load("res://assets/palette/palette_lut.png"))
	r.material = mat
	add_child(r)
