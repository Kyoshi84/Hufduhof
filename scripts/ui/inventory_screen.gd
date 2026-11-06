class_name InventoryScreen
extends RefCounted
## Ekwipunek: sloty (broń, zbroja, hełm, amulet), siatka plecaka, pas z miksturami i korony.
## Kliknięcie przedmiotu pokazuje opis i przyciski Załóż / Zdejmij / Wyrzuć (albo Sprzedaj u handlarza).
## Z parametrem shop_id ekran działa jako handel (lewa kolumna: towary kupca).

static func build(h: HeroState, on_close: Callable, shop_id: String = "") -> Control:
	var root := UiKit.dim_root(0.82)
	var center := CenterContainer.new()
	UiKit.full_rect(center)
	root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	outer.add_child(body)
	var state := {"sel": -1, "slot": ""}
	var ctx := {}
	var rebuild := func(): ctx["rebuild"].call()
	ctx["rebuild"] = func():
		for c in body.get_children():
			c.queue_free()
		if shop_id != "":
			body.add_child(_shop_column(h, shop_id, rebuild))
		body.add_child(_hero_column(h, state, shop_id, rebuild))
	rebuild.call()
	var close := UiKit.button("Zamknij", func():
		h.refresh_bonuses()
		Game.hero_changed.emit()
		on_close.call(), 240)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer.add_child(close)
	close.call_deferred("grab_focus")
	return root

static func _slot_button(it, label: String, selected: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(64, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = label
	if it != null:
		var ic := Pickup.icon_for({"typ": "przedmiot", "item": it})
		if ic != "" and ResourceLoader.exists(ic):
			b.icon = load(ic)
			b.expand_icon = true
		if Loot.is_magic(it):
			b.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	if selected:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.45, 0.14, 0.08)
		sb.border_color = Color(1.0, 0.85, 0.35)
		sb.set_border_width_all(3)
		b.add_theme_stylebox_override("normal", sb)
	b.pressed.connect(func():
		Audio.play("ui_click")
		cb.call())
	return b

static func _hero_column(h: HeroState, st: Dictionary, shop_id: String, rebuild: Callable) -> Control:
	var inv := h.inv
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.add_child(UiKit.label("EKWIPUNEK - %s" % h.display_name(), 26, UiKit.GOLD, false))
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 10)
	vb.add_child(slots)
	for slot in Inventory.SLOTS:
		var col := VBoxContainer.new()
		col.add_child(UiKit.label(Inventory.SLOT_NAMES[slot], 15, UiKit.DIM))
		var it = inv.equipped.get(slot)
		col.add_child(_slot_button(it, Loot.item_name(it) if it != null else "(pusto)", st["slot"] == slot, func():
			st["slot"] = slot
			st["sel"] = -1
			rebuild.call()))
		slots.add_child(col)
	vb.add_child(UiKit.label("Plecak (%d wolnych miejsc)" % inv.free_slots(), 16, UiKit.DIM, false))
	var grid := GridContainer.new()
	grid.columns = inv.width
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	vb.add_child(grid)
	for i in inv.bag.size():
		var it = inv.bag[i]
		grid.add_child(_slot_button(it, Loot.item_name(it) if it != null else "", st["sel"] == i, func():
			st["sel"] = i if it != null else -1
			st["slot"] = ""
			rebuild.call()))
	var belt := inv.belt
	vb.add_child(UiKit.label("Korony: %d      Mikstury życia: %d   many: %d   Piwo: %d" % [inv.gold,
		int(belt.get("mikstura_zycia", 0)), int(belt.get("mikstura_many", 0)), int(belt.get("piwo", 0))], 18, Color(1.0, 0.85, 0.35), false))
	# opis zaznaczonego przedmiotu i akcje
	var sel_item = null
	if st["sel"] >= 0:
		sel_item = inv.bag[st["sel"]]
	elif st["slot"] != "":
		sel_item = inv.equipped.get(st["slot"])
	var desc := PanelContainer.new()
	desc.add_theme_stylebox_override("panel", UiKit.panel_style(0.6))
	desc.custom_minimum_size = Vector2(0, 110)
	vb.add_child(desc)
	var dv := VBoxContainer.new()
	desc.add_child(dv)
	if sel_item == null:
		dv.add_child(UiKit.label("Wybierz przedmiot, żeby zobaczyć opis.", 16, UiKit.DIM, false))
	else:
		dv.add_child(UiKit.label(Loot.item_name(sel_item), 20, Color(1, 0.85, 0.35) if Loot.is_magic(sel_item) else UiKit.TEXT, false))
		dv.add_child(UiKit.label("%s   %s" % [Inventory.SLOT_NAMES.get(Loot.item_slot(sel_item), ""), Loot.describe(sel_item).replace("\n", ",  ")], 16, UiKit.TEXT, false))
		var acts := HBoxContainer.new()
		acts.add_theme_constant_override("separation", 8)
		dv.add_child(acts)
		if st["sel"] >= 0:
			var idx: int = st["sel"]
			acts.add_child(UiKit.button("Załóż", func():
				inv.equip_from_bag(idx)
				h.refresh_bonuses()
				st["sel"] = -1
				rebuild.call(), 140, 44))
			if shop_id != "":
				var price := Rules.sell_price(Loot.item_price(sel_item), h.stats.val("Ogd"))
				acts.add_child(UiKit.button("Sprzedaj (%d kor.)" % price, func():
					inv.remove_at(idx)
					inv.gold += price
					Audio.play("coin")
					st["sel"] = -1
					rebuild.call(), 220, 44))
			else:
				acts.add_child(UiKit.button("Wyrzuć", func():
					inv.remove_at(idx)
					st["sel"] = -1
					rebuild.call(), 140, 44))
		else:
			var slot: String = st["slot"]
			acts.add_child(UiKit.button("Zdejmij", func():
				if not inv.unequip(slot):
					Game.notify("Plecak pełny!", Color(1, 0.5, 0.4))
				h.refresh_bonuses()
				st["slot"] = ""
				rebuild.call(), 140, 44))
	return vb

static func _shop_column(h: HeroState, shop_id: String, rebuild: Callable) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.custom_minimum_size = Vector2(330, 0)
	vb.add_child(UiKit.label("HANDEL - BORUBAR", 26, UiKit.GOLD, false))
	vb.add_child(UiKit.icon("res://assets/characters/borubar/portrait.png", 110))
	vb.add_child(UiKit.label("Ceny zależą od Ogłady (Ogd %d)" % h.stats.val("Ogd"), 15, UiKit.DIM, false))
	var shop := Data.shop(shop_id)
	if not Game.flags.has("zapasy_" + shop_id):
		var z := {}
		for e in shop.get("sprzedaje", []):
			z[str(e["id"])] = int(e.get("zapas", -1))
		Game.flags["zapasy_" + shop_id] = z
	var stock: Dictionary = Game.flags["zapasy_" + shop_id]
	for e in shop.get("sprzedaje", []):
		var id := str(e["id"])
		var bi := Data.belt_item(id)
		var price := Rules.buy_price(int(bi.get("cena", 10)), h.stats.val("Ogd"))
		var left := int(stock.get(id, -1))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(UiKit.icon("res://assets/ui/items/%s.png" % str(bi.get("ikona", "")), 36))
		var name_txt := str(bi.get("nazwa", id)) + ("" if left < 0 else " (%d)" % left)
		var b := UiKit.button("%s - %d kor." % [name_txt, price], func():
			if h.inv.gold < price:
				Game.notify("Za mało koron!", Color(1, 0.5, 0.4))
				return
			if left == 0:
				return
			h.inv.gold -= price
			h.inv.belt_add(id)
			if left > 0:
				stock[id] = left - 1
			Audio.play("coin")
			rebuild.call(), 270, 46)
		b.disabled = left == 0 or h.inv.gold < price
		b.add_theme_font_size_override("font_size", 17)
		row.add_child(b)
		vb.add_child(row)
	vb.add_child(UiKit.label("Piwo leczy życie i manę naraz.", 15, UiKit.DIM, false))
	vb.add_child(UiKit.label("Sprzedaż: wybierz przedmiot z plecaka.", 15, UiKit.DIM, false))
	return vb
