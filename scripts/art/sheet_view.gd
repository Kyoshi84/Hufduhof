class_name SheetView
extends Node2D
## Pokazuje animację z CharacterSheet dla danego aktora (wróg). Stan gry -> nazwa animacji:
##   IDLE idle | MOVE run | atak <nazwa ataku z balance.json> | HURT hurt (boss: roar przy zmianie fazy) | DEAD die
## Gdy brakuje animacji: używana jest "idle". Gdy brakuje i jej, `active` = false i aktor rysuje grafikę zapasową.

var sheet: CharacterSheet
var actor
var sprite: Sprite2D
var active: bool = false
var t: float = 0.0

func setup(a, s: CharacterSheet) -> void:
	actor = a
	sheet = s
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(s.wpt, s.wpt)
	add_child(sprite)

static func anim_name_for(a) -> String:
	match a.state:
		Actor.State.MOVE: return "run"
		Actor.State.WINDUP, Actor.State.ACTIVE, Actor.State.RECOVER: return a.attack_name
		Actor.State.HURT: return "roar" if a.get("roaring") == true else "hurt"
		Actor.State.DODGE: return "dodge"
		Actor.State.DEAD: return "die"
		Actor.State.VICTORY: return "victory"
	return "idle"

func _process(delta: float) -> void:
	if actor == null or sheet == null:
		return
	t += delta
	var name: String = anim_name_for(actor)
	if not sheet.has_anim(name):
		name = "idle"
	active = sheet.has_anim(name)
	sprite.visible = active
	if not active:
		return
	show_frame(sprite, sheet, name, actor, t)

## Ustawia klatkę, pivot i odbicie; wspólne dla wrogów i Ivo.
static func show_frame(spr: Sprite2D, sh: CharacterSheet, name: String, a, vt: float) -> void:
	var idx: int = sh.frame_index(name, a, vt)
	var tex: Texture2D = sh.anims[name]["tex"][idx]
	spr.texture = tex
	var flip: bool = a.facing < 0
	spr.flip_h = flip
	var w: float = float(tex.get_width())
	spr.offset = Vector2(-floorf(w - sh.pivot.x) if flip else -floorf(sh.pivot.x), -floorf(sh.pivot.y))
	spr.self_modulate = Color(1.9, 1.9, 1.9) if a.flash > 0.0 else Color.WHITE
