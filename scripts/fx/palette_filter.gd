class_name PaletteFilter
extends CanvasLayer
## Nakładka na cały ekran, która sprowadza ostateczny obraz do wspólnej palety 256 kolorów
## (tablica LUT). Obejmuje świat, HUD i menu. Wyłączenie: argument uruchomienia --no-palette.

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--no-palette" in OS.get_cmdline_user_args():
		return
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/palette.gdshader")
	mat.set_shader_parameter("lut", load("res://assets/palette/palette_lut.png"))
	rect.material = mat
	add_child(rect)
