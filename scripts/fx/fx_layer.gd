class_name FxLayer
extends Node2D
## Lekkie cząsteczki trafień (iskry/krew/drzazgi) rysowane jednym _draw().

var parts: Array = []

func burst(pos: Vector2, count: int, col: Color, force: float, dir: int) -> void:
	for i in count:
		var ang: float = randf_range(-PI * 0.8, PI * 0.2) if dir > 0 else randf_range(PI * 0.8, PI * 1.8)
		parts.append({
			"p": pos, "v": Vector2.from_angle(ang) * randf_range(force * 0.3, force),
			"life": randf_range(0.25, 0.5), "max": 0.5, "c": col, "r": randf_range(2.0, 4.5),
		})
	if parts.size() > 220:
		parts = parts.slice(parts.size() - 220)

func _process(delta: float) -> void:
	if parts.is_empty():
		return
	for p in parts:
		p["life"] = float(p["life"]) - delta
		p["v"] = (p["v"] as Vector2) + Vector2(0, 700.0 * delta)
		p["p"] = (p["p"] as Vector2) + (p["v"] as Vector2) * delta
	parts = parts.filter(func(p): return float(p["life"]) > 0.0)
	queue_redraw()

func _draw() -> void:
	for p in parts:
		var c: Color = p["c"]
		c.a = clampf(float(p["life"]) / float(p["max"]), 0.0, 1.0)
		draw_circle(p["p"], float(p["r"]), c)
