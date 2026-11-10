class_name SettingsScreen
extends RefCounted
## Ustawienia: głośność muzyki i efektów, sterowanie dotykowe, filtr palety 256 kolorów, diagnostyka kolizji (debug).

static func build(on_back: Callable) -> Control:
	var root := UiKit.dim_root(0.9)
	var center := CenterContainer.new()
	UiKit.full_rect(center)
	root.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	center.add_child(vb)
	vb.add_child(UiKit.label("USTAWIENIA", 50, UiKit.RED))
	vb.add_child(_slider("Muzyka", Save.music_volume, func(v):
		Save.music_volume = v
		Audio.apply_volumes()))
	vb.add_child(_slider("Efekty", Save.sfx_volume, func(v):
		Save.sfx_volume = v
		Audio.apply_volumes()))
	var names := ["Sterowanie dotykowe: auto", "Sterowanie dotykowe: zawsze", "Sterowanie dotykowe: wyłączone"]
	var tb := UiKit.button(names[Save.touch_mode], func(): pass, 460)
	tb.pressed.connect(func():
		Save.touch_mode = (Save.touch_mode + 1) % 3
		tb.text = names[Save.touch_mode])
	vb.add_child(tb)
	var pb := UiKit.button("", func(): pass, 460)
	pb.text = "Filtr palety 256 kolorów: " + ("WŁ" if Save.palette_filter else "wył")
	pb.pressed.connect(func():
		Save.palette_filter = not Save.palette_filter
		pb.text = "Filtr palety 256 kolorów: " + ("WŁ" if Save.palette_filter else "wył") + " (od nowego poziomu)")
	vb.add_child(pb)
	var lb := UiKit.button("", func(): pass, 460)
	lb.text = "Oświetlenie i cienie: " + ("WŁ" if Save.lights else "wył")
	lb.pressed.connect(func():
		Save.lights = not Save.lights
		lb.text = "Oświetlenie i cienie: " + ("WŁ" if Save.lights else "wył") + " (od nowego poziomu)")
	vb.add_child(lb)
	if OS.is_debug_build():
		var db := UiKit.button("", func(): pass, 460)
		db.text = "Diagnostyka kolizji (F3): " + ("WŁ" if Game.debug_collision else "wył")
		db.pressed.connect(func():
			Game.debug_collision = not Game.debug_collision
			db.text = "Diagnostyka kolizji (F3): " + ("WŁ" if Game.debug_collision else "wył"))
		vb.add_child(db)
	var back := UiKit.button("Wróć", func():
		Save.save_settings()
		on_back.call(), 460)
	vb.add_child(back)
	back.call_deferred("grab_focus")
	return root

static func _slider(title: String, value: float, cb: Callable) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	var l := UiKit.label(title, 26, UiKit.TEXT, false)
	l.custom_minimum_size = Vector2(140, 0)
	hb.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(320, 44)
	s.value_changed.connect(func(v):
		cb.call(v)
		Audio.play("ui_click"))
	hb.add_child(s)
	return hb
