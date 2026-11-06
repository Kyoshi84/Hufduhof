class_name OverlayKeys
extends Node
## Klawisze w otwartych oknach (dialog, pauza, postać, plecak, handel). Działa także podczas pauzy gry.
##  Esc / P   - zamknij okno (w dialogu = "Do widzenia"; ekranu śmierci nie da się tak zamknąć),
##  E / F     - naciśnij podświetlony przycisk (np. "Dalej" w rozmowie); Enter i Spacja działają tak samo.

var level: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if level == null or level.overlay == null or not is_instance_valid(level.overlay):
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var ov: Control = level.overlay
	if event.is_action("pauza"):
		get_viewport().set_input_as_handled()
		if not bool(ov.get_meta("closable", true)):
			return
		if ov.has_meta("on_cancel"):
			(ov.get_meta("on_cancel") as Callable).call()
		else:
			level.close_overlay()
	elif event.is_action("interakcja") or event.is_action("postac") or event.is_action("plecak"):
		get_viewport().set_input_as_handled()
		if event.is_action("interakcja"):
			var f := get_viewport().gui_get_focus_owner()
			if f is Button and not f.disabled and ov.is_ancestor_of(f):
				(f as Button).pressed.emit()
		elif bool(ov.get_meta("closable", true)) and not ov.has_meta("on_cancel"):
			level.close_overlay()
