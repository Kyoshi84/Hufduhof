class_name ProfileTable
extends RefCounted
## Tabela profilu cech w stylu karty postaci Warhammera:
##  | WW | US | K | Odp | Zr | Int | SW | Ogd |   (cechy główne 0-100)
##  | A | Żyw | S | Wt | Sz | Mag | PO | PP |     (cechy drugorzędne 0-10)
## Z bohaterem (HeroState) i callbackiem pokazuje przyciski "+" do rozdawania punktów rozwoju.

static func build(stats: Stats, hero: HeroState = null, on_raise: Callable = Callable(), cell_w: float = 62.0) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	for keys in [Stats.PRIMARY, Stats.SECONDARY]:
		var grid := GridContainer.new()
		grid.columns = keys.size()
		grid.add_theme_constant_override("h_separation", 2)
		grid.add_theme_constant_override("v_separation", 2)
		vb.add_child(grid)
		for k in keys:
			grid.add_child(_cell(Stats.LABELS[k], cell_w, true, Stats.NAMES.get(k, k)))
		for k in keys:
			var v := stats.val(k)
			var bonus := v - stats.base_val(k)
			var t := str(v)
			var c := _cell(t, cell_w, false, Stats.NAMES.get(k, k))
			if bonus != 0:
				(c.get_child(0) as Label).add_theme_color_override("font_color", Color(0.5, 0.9, 0.5) if bonus > 0 else Color(1.0, 0.5, 0.4))
			grid.add_child(c)
		if hero != null and on_raise.is_valid() and hero.points_available() > 0:
			for k in keys:
				if hero.can_raise(k):
					var b := UiKit.button("+", func():
						if hero.raise_stat(k):
							Audio.play("levelup")
							on_raise.call(), cell_w, 36)
					b.add_theme_font_size_override("font_size", 20)
					b.tooltip_text = "%s +%d" % [Stats.NAMES.get(k, k), int(Data.bal("rozwoj/plus_glowna", 5)) if k in Stats.PRIMARY else 1]
					grid.add_child(b)
				else:
					var sp := Control.new()
					sp.custom_minimum_size = Vector2(cell_w, 36)
					grid.add_child(sp)
	return vb

static func _cell(text: String, w: float, header: bool, tip: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.35, 0.08, 0.06, 0.95) if header else Color(0.12, 0.08, 0.07, 0.95)
	sb.border_color = Color(0.55, 0.42, 0.2)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(3)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(w, 0)
	p.tooltip_text = tip
	var l := UiKit.label(text, 17 if header else 20, UiKit.GOLD if header else UiKit.TEXT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p
