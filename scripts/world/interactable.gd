class_name Interactable
extends Node2D
## Baza obiektów, z którymi bohater wchodzi w interakcję przyciskiem "Interakcja" (PC: E/F).
## Podklasy w scripts/world/objects.gd: skrzynia, kapliczka, studnia, wiadro, część barykady, NPC, wyjście, drzwi karczmy.

var level: Node
var uid: String = ""
var interact_radius: float = 70.0
var spr: Sprite2D

func _ready() -> void:
	add_to_group("interactable")

func can_interact(_hero: Hero) -> bool:
	return true

func interact(_hero: Hero) -> void:
	pass

func interact_label(_hero: Hero) -> String:
	return "Użyj"

func set_sprite(tex: Texture2D, lift: float = 0.0) -> void:
	if spr == null:
		spr = Sprite2D.new()
		spr.centered = false
		add_child(spr)
	spr.texture = tex
	if tex:
		spr.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height() - lift)

