class_name IvoView
extends Node2D
## Widok Ivo oparty na dostarczonych sprite'ach (8 kierunków, statyczne pozy). Wybór kierunku:
##  - ruch (także w głąb sceny): kierunek wektora ruchu (E, SE, S, SW, W, NW, N, NE),
##  - atak / trafienie / unik: profil zgodny z kierunkiem ataku (E lub W) - hitbox jest zawsze poziomy,
##  - zwycięstwo: S (twarzą do kamery), śmierć: profil, obrócony o dokładnie 90 stopni.
## Brak klatek chodu i ataku -> animacje tymczasowe: wahnięcie w pionie i wypad/odskok sprite'a + SwingFx.

const DIR_ORDER := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
const MANIFEST := "res://assets/characters/ivo/poses/manifest.json"

var actor
var sprite: Sprite2D
var swing: SwingFx
var sheet: CharacterSheet = null
var sheet_sprite: Sprite2D
var tex := {}
var wpt: float = 1.3333
var cur_dir: String = "east"
var t: float = 0.0

static func available() -> bool:
	return ResourceLoader.exists(MANIFEST) or FileAccess.file_exists(MANIFEST)

func setup(a) -> void:
	actor = a
	var f := FileAccess.open(MANIFEST, FileAccess.READ)
	var m: Dictionary = JSON.parse_string(f.get_as_text())
	wpt = float(m["world_per_texel"])
	for d in m["dirs"]:
		tex[d] = load("res://assets/characters/ivo/poses/ivo_%s.png" % d)
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.offset = -Vector2(floorf(float(m["pivot"][0])), floorf(float(m["pivot"][1])))
	sprite.scale = Vector2(wpt, wpt)
	add_child(sprite)
	sheet = CharacterSheet.get_sheet("ivo")
	sheet_sprite = Sprite2D.new()
	sheet_sprite.centered = false
	sheet_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sheet_sprite.visible = false
	if sheet != null:
		sheet_sprite.scale = Vector2(sheet.wpt, sheet.wpt)
	add_child(sheet_sprite)
	swing = SwingFx.new()
	swing.actor = a
	add_child(swing)

## Kierunek wizualny (8 stron) dla aktualnego stanu gracza.
func pick_dir() -> String:
	var a = actor
	var prof: String = "east" if a.facing >= 0 else "west"
	match a.state:
		Actor.State.WINDUP, Actor.State.ACTIVE, Actor.State.RECOVER, Actor.State.HURT, Actor.State.DEAD:
			return prof
		Actor.State.DODGE:
			return dir_from_vector(a.dodge_dir, prof)
		Actor.State.VICTORY:
			return "south"
	return a.aim_dir

static func dir_from_vector(v: Vector2, fallback: String, current: String = "") -> String:
	if v.length() < 0.3:
		return fallback
	var ang: float = rad_to_deg(atan2(v.y, v.x))          # 0 = E, 90 = S (w dół ekranu, ku kamerze)
	var best: int = int(round(ang / 45.0))
	best = posmod(best, 8)
	if current != "":
		var ci: int = DIR_ORDER.find(current)
		if ci >= 0:
			var diff: float = absf(wrapf(ang - ci * 45.0, -180.0, 180.0))
			if diff < 29.0:                                   # histereza: nie przeskakuj przy drganiu drążka
				return current
	return DIR_ORDER[best]

## Nazwa animacji z arkusza dla bieżącego stanu ("" = użyj póz 8-kierunkowych).
func sheet_anim() -> String:
	if sheet == null:
		return ""
	var a = actor
	var name := ""
	match a.state:
		Actor.State.IDLE:
			name = "idle" if a.aim_dir == "east" or a.aim_dir == "west" else ""
		Actor.State.MOVE:
			name = "run" if a.aim_dir != "north" and a.aim_dir != "south" else ""
		Actor.State.WINDUP, Actor.State.ACTIVE, Actor.State.RECOVER:
			name = a.attack_name
		Actor.State.HURT: name = "hurt"
		Actor.State.DODGE: name = "dodge"
		Actor.State.DEAD: name = "die"
		Actor.State.VICTORY: name = "victory"
	return name if sheet.has_anim(name) else ""

func _process(delta: float) -> void:
	if actor == null:
		return
	t += delta
	var a = actor
	var anim: String = sheet_anim()
	if anim != "":
		sprite.visible = false
		sheet_sprite.visible = true
		swing.visible = false                      # animacja z arkusza zawiera własny efekt ciosu
		sheet_sprite.modulate.a = 0.6 if a.state == Actor.State.DODGE else 1.0
		SheetView.show_frame(sheet_sprite, sheet, anim, a, t)
		return
	sprite.visible = true
	sheet_sprite.visible = false
	swing.visible = true
	cur_dir = pick_dir()
	sprite.texture = tex[cur_dir]
	var off := Vector2.ZERO
	match a.state:
		Actor.State.MOVE:
			off.y = -wpt * (1.0 if int(t * 9.0) % 2 == 0 else 0.0)        # tymczasowe wahnięcie kroku (1 piksel)
		Actor.State.WINDUP:
			var p: float = clampf(a.state_t / maxf(a.windup_time(), 0.01), 0.0, 1.0)
			off.x = -a.facing * 5.0 * p
		Actor.State.ACTIVE:
			off.x = a.facing * 4.0
	sprite.position = Vector2(roundf(off.x / wpt) * wpt, roundf(off.y / wpt) * wpt)
	sprite.rotation = 0.0
	sprite.modulate = Color.WHITE
	sprite.self_modulate = Color(1.9, 1.9, 1.9) if a.flash > 0.0 else Color.WHITE
	if a.state == Actor.State.DODGE:
		sprite.modulate.a = 0.6
	if a.state == Actor.State.DEAD:
		var k: float = clampf(a.dead_t / 0.25, 0.0, 1.0)
		sprite.rotation = -PI * 0.5 * k * float(a.facing)       # dokładnie 90 stopni: siatka pikseli zachowana
		sprite.modulate.a = 1.0 if int(a.dead_t * 10.0) % 2 == 0 or a.dead_t < 0.8 else 0.0
