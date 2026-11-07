class_name CharacterSheet
extends RefCounted
## Ekran postaci: profil cech, doświadczenie, punkty rozwoju z przyciskami "+", wartości pochodne
## (życie, mana, szansa trafienia, obrażenia, tempo ataku, unik, odporność, ceny).

static func build(h: HeroState, on_close: Callable, on_change: Callable) -> Control:
	var root := UiKit.dim_root(0.82)
	var center := CenterContainer.new()
	UiKit.full_rect(center)
	root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var holder := VBoxContainer.new()
	vb.add_child(holder)
	var ctx := {}
	ctx["redraw"] = func():
		for c in holder.get_children():
			c.queue_free()
		_fill(holder, h, func():
			on_change.call()
			ctx["redraw"].call())
	ctx["redraw"].call()
	var close := UiKit.button("Zamknij", on_close, 240)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(close)
	close.call_deferred("grab_focus")
	return root

static func _fill(holder: VBoxContainer, h: HeroState, on_raise: Callable) -> void:
	var def := Data.hero(h.id)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	holder.add_child(top)
	top.add_child(UiKit.icon(str(def.get("portret", "")), 120))
	var info := VBoxContainer.new()
	top.add_child(info)
	info.add_child(UiKit.label(str(def.get("imie", h.id)), 32, UiKit.GOLD, false))
	info.add_child(UiKit.label(str(def.get("tytul", "")), 18, UiKit.DIM, false))
	var nxt := h.next_threshold()
	info.add_child(UiKit.label("Doświadczenie: %d%s" % [h.xp, (" / %d" % nxt) if nxt > 0 else ""], 20, UiKit.TEXT, false))
	var pa := h.points_available()
	var pl := UiKit.label("Punkty rozwoju: %d" % pa, 22, Color(1.0, 0.85, 0.3) if pa > 0 else UiKit.DIM, false)
	info.add_child(pl)
	if pa > 0:
		info.add_child(UiKit.label("Punkt = +5 do cechy głównej albo +1 do drugorzędnej (A, Żyw, Sz, Mag, PP)", 15, UiKit.DIM, false))
	holder.add_child(ProfileTable.build(h.stats, h, on_raise, 66))
	var s := h.stats
	var hint := Data.enemy("skaven_spear")
	var foe := Stats.from_profile(hint.get("profil", {}))
	var ph := Rules.attack_phases(s.val("A"), s.val("Zr"))
	var lines := [
		"Życie: %d / %d      Mana: %d / %d      Regeneracja many: %.1f/s" % [int(h.hp), h.max_hp(), int(h.mana), h.max_mana(), Rules.mana_regen(s.val("SW")) if h.max_mana() > 0 else 0.0],
		"Broń: %d obrażeń  (+S %d)      Obrona pancerza: %d      Unik: %d%%" % [h.inv.weapon_damage(), s.val("S"), h.inv.armor_defense(), Rules.dodge_chance(s.val("Zr"))],
		"Atak co %.2f s (zamach %.2f s)      Szansa trafienia skavena: %d%%      Obrażenia: %d" % [ph[0] + ph[1] + ph[2], ph[0],
			Rules.melee_hit_chance(s.val("WW"), foe.val("WW"), int(hint.get("obrona", 0))), Rules.damage(h.inv.weapon_damage(), s.val("S"), foe.val("Wt"))],
		"Odporność na truciznę: %d%%      Siła czarów: %d      Ceny u kupca: x%.2f" % [int(round((1.0 - Rules.poison_factor(s.val("SW"))) * 100)), Rules.spell_power(s.val("Int"), s.val("Mag")), Rules.buy_price(100, s.val("Ogd")) / 100.0],
	]
	var skills: Dictionary = def.get("umiejetnosci", {})
	var n := 1
	for id in def.get("pasek", []):
		if skills.has(id):
			var sk: Dictionary = skills[id]
			lines.append("[%d] %s (%.1f many): %s" % [n, sk.get("nazwa", id), float(sk.get("koszt_many", 0)), sk.get("opis", "")])
		n += 1
	for l in lines:
		var lb := UiKit.label(l, 16, UiKit.TEXT, false)
		holder.add_child(lb)
