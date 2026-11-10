class_name LightFx
extends PointLight2D
## Źródło światła w świecie gry (latarnia, ogień barykady, palenisko, świeca, okno, spaczenie, pocisk ognia).
## Świat jest przyciemniony (CanvasModulate z "odcien" poziomu), a światła dodają ciepłe plamy na ziemi i postaciach.
## Tekstura światła ma kilka schodkowych pierścieni (bez gładkiego gradientu - pasuje do palety 256 kolorów).
## Parametry rodzajów: data/balance.json -> swiatlo/rodzaje. Wyłączenie: Ustawienia -> Oświetlenie.

static var _tex: ImageTexture = null
var kind: String = "latarnia"
var base_energy: float = 0.8
var flicker: float = 0.0
var _t: float = 0.0
var _seed: float = 0.0

static func light_texture() -> ImageTexture:
	if _tex != null:
		return _tex
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var steps := [[0.30, 1.0], [0.48, 0.78], [0.64, 0.55], [0.80, 0.33], [0.92, 0.16], [1.0, 0.06]]
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() / (n / 2.0)
			var v := 0.0
			for s in steps:
				if d <= s[0]:
					v = s[1]
					# przejście między pierścieniami w szachownicę (dithering zamiast gradientu)
					if d > s[0] - 0.035 and (x + y) % 2 == 0:
						v *= 0.75
					break
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	_tex = ImageTexture.create_from_image(img)
	return _tex

static func enabled() -> bool:
	return Save.lights and bool(Data.bal("swiatlo/wlaczone", true))

## Tworzy światło danego rodzaju albo null, gdy oświetlenie jest wyłączone.
static func make(light_kind: String, parent: Node, pos: Vector2) -> LightFx:
	if not enabled():
		return null
	var cfg: Dictionary = Data.bal("swiatlo/rodzaje", {}).get(light_kind, {})
	if cfg.is_empty():
		return null
	var l := LightFx.new()
	l.kind = light_kind
	l.texture = light_texture()
	var r := float(cfg.get("promien", 200))
	l.texture_scale = r / 64.0
	l.scale = Vector2(1.0, float(Data.bal("swiatlo/splaszczenie", 0.72)))    # plama światła na ziemi jest elipsą
	var c: Array = cfg.get("kolor", [1.0, 0.75, 0.45])
	l.color = Color(float(c[0]), float(c[1]), float(c[2]))
	l.base_energy = float(cfg.get("energia", 0.8))
	l.energy = l.base_energy
	l.flicker = float(cfg.get("migotanie", 0.0))
	l.blend_mode = Light2D.BLEND_MODE_ADD
	l.position = pos + Vector2(0, -float(cfg.get("wysokosc", 30)))
	l._seed = randf() * 100.0
	parent.add_child(l)
	return l

func _process(delta: float) -> void:
	if flicker <= 0.0:
		return
	_t += delta
	# migotanie skokowe (ok. 12 razy na sekundę), jak w starych grach
	var step: float = floor(_t * 12.0)
	var n := sin(step * 12.9898 + _seed) * 43758.5453
	n = n - floor(n)
	energy = base_energy * (1.0 - flicker + flicker * n)
