class_name DialogBox
extends RefCounted
## Okno rozmowy: portret, imię, kolejne kwestie (dotknięcie / Dalej), na końcu przyciski wyboru.

static func build(speaker: String, portrait: String, lines: Array, choices: Array) -> Control:
	var root := UiKit.dim_root(0.35)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 60
	panel.offset_right = -60
	panel.offset_top = -250
	panel.offset_bottom = -24
	root.add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	panel.add_child(hb)
	hb.add_child(UiKit.icon(portrait, 180))
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	hb.add_child(vb)
	vb.add_child(UiKit.label(speaker, 26, UiKit.GOLD, false))
	var text := UiKit.label("", 21, UiKit.TEXT, false)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.custom_minimum_size = Vector2(700, 90)
	vb.add_child(text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	var idx := {"i": 0}
	var show := func(): pass
	show = func():
		for c in row.get_children():
			c.queue_free()
		text.text = str(lines[idx["i"]]) if not lines.is_empty() else ""
		if idx["i"] < lines.size() - 1:
			var nb := UiKit.button("Dalej", func():
				idx["i"] += 1
				show.call(), 180, 48)
			row.add_child(nb)
			nb.call_deferred("grab_focus")
		else:
			var first := true
			for ch in choices:
				var b := UiKit.button(ch[0], ch[1], 200, 48)
				row.add_child(b)
				if first:
					b.call_deferred("grab_focus")
					first = false
	show.call()
	return root
