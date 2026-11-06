class_name Pickup
extends Node2D
## Łup leżący na ziemi: korony, mikstury, przedmioty. Podnoszony automatycznie po wejściu na niego.
## Przedmioty mają nad sobą nazwę (złota = magiczny).

var drop: Dictionary
var spr: Sprite2D
var bounce_t: float = 0.0
var from := Vector2.ZERO
var to := Vector2.ZERO
var label: Label

static func icon_for(d: Dictionary) -> String:
	match str(d.get("typ", "")):
		"korony":
			return "res://assets/ui/items/gold.png"
		"mikstura_zycia", "mikstura_many", "piwo":
			return "res://assets/ui/items/%s.png" % str(Data.belt_item(str(d["typ"])).get("ikona", "potion_red"))
		"przedmiot":
			return "res://assets/ui/items/%s.png" % str(Loot.item_def(d["item"]).get("ikona", "sword"))
	return ""

func setup(d: Dictionary, start: Vector2, dest: Vector2) -> void:
	drop = d
	from = start
	to = dest
	position = start
	spr = Sprite2D.new()
	var p := icon_for(d)
	if p != "" and ResourceLoader.exists(p):
		spr.texture = load(p)
	spr.offset = Vector2(0, -14)
	add_child(spr)
	if d.get("typ") == "przedmiot":
		label = Label.new()
		label.text = Loot.item_name(d["item"])
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35) if Loot.is_magic(d["item"]) else Color(0.92, 0.9, 0.85))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		label.add_theme_constant_override("outline_size", 4)
		label.size = Vector2(200, 20)
		label.position = Vector2(-100, -50)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)
	elif d.get("typ") == "korony":
		label = Label.new()
		label.text = "%d kor." % int(d.get("ilosc", 0))
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		label.add_theme_constant_override("outline_size", 4)
		label.size = Vector2(100, 20)
		label.position = Vector2(-50, -46)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)
	add_to_group("pickup")

func _process(delta: float) -> void:
	if bounce_t < 0.45:
		bounce_t += delta
		var k := clampf(bounce_t / 0.45, 0.0, 1.0)
		position = from.lerp(to, k)
		spr.position = Vector2(0, -sin(k * PI) * 40.0)

func can_pick() -> bool:
	return bounce_t >= 0.45

func pick(hero: Hero) -> void:
	var inv := hero.hs.inv
	match str(drop.get("typ", "")):
		"korony":
			inv.gold += int(drop.get("ilosc", 0))
			Audio.play("coin")
			Game.notify("+%d koron" % int(drop.get("ilosc", 0)), Color(1.0, 0.85, 0.35))
		"mikstura_zycia", "mikstura_many", "piwo":
			inv.belt_add(str(drop["typ"]))
			Audio.play("pickup")
			Game.notify(str(Data.belt_item(str(drop["typ"])).get("nazwa", "")), Color(0.8, 0.9, 1.0))
		"przedmiot":
			if not inv.add_item(drop["item"]):
				if not get_meta("warned", false):
					Game.notify("Plecak pełny!", Color(1, 0.5, 0.4))
					set_meta("warned", true)
				return
			Audio.play("pickup")
			Game.notify("Zdobyto: " + Loot.item_name(drop["item"]), Color(1.0, 0.85, 0.35) if Loot.is_magic(drop["item"]) else Color(0.9, 0.9, 0.9))
	Game.hero_changed.emit()
	queue_free()
