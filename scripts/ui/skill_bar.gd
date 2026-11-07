class_name SkillBar
extends Control
## Pasek umiejętności przy dolnej krawędzi (styl: ciemne drewno i żelazo), po bokach kule Życia i Many.
## 10 slotów: klawisze 1-9 i 0 (górny rząd i klawiatura numeryczna), kliknięcie albo dotyk aktywuje slot,
## przytrzymanie = ciągłe używanie. Zawartość slotów: heroes.json -> "pasek".
## Każdy slot: ikona, numer klawisza, koszt many, zegar odnowienia, liczba sztuk (mikstury, piwo),
## szary, gdy brak many / brak sztuk. Gdy pasek się nie mieści (telefon), puste sloty 7-0 chowają się pod "...".

const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
const WOOD := Color(0.22, 0.13, 0.08)
const WOOD_D := Color(0.13, 0.08, 0.05)
const IRON := Color(0.36, 0.36, 0.38)
const IRON_L := Color(0.58, 0.57, 0.55)

var level: Node
var slot_size: float = 54.0
var gap: float = 4.0
var orb_r: float = 40.0
var collapsed: bool = false     # puste sloty ukryte pod "..."
var expanded: bool = false      # rozwinięty drugi rząd
var slot_rects: Array = []      # [indeks slotu, Rect2]
var more_rect := Rect2()
var _press_mouse: int = -1
var _press_touch: Dictionary = {}   # indeks palca -> slot
var _icons: Dictionary = {}
var _mana_flash: float = 0.0
var _flash_slot: int = -1
var _h: float = 80.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(layout)
	if level and level.hero:
		level.hero.mana_denied.connect(_on_mana_denied)
	layout()

func _hero() -> Hero:
	return level.hero if level else null

func _entries() -> Array:
	var h := _hero()
	return h.bar if h else []

func _is_empty(i: int) -> bool:
	var e: Array = _entries()
	return i >= e.size() or str(e[i]) == ""

## Układ: rozmiar slotów i zwinięcie zależą od szerokości ekranu i od tego, czy jest sterowanie dotykowe.
func layout() -> void:
	var vw := get_viewport_rect().size.x
	var touch := Save.touch_enabled()
	slot_size = 58.0 if touch else 54.0
	orb_r = 40.0
	var reserve := 270.0 if touch else 20.0      # joystick po lewej, ATAK po prawej
	var avail := vw - 2.0 * reserve
	var full := _width(10)
	collapsed = full > avail
	if collapsed and _width(7) > avail:
		slot_size = maxf(40.0, (avail - 2.0 * (orb_r * 2.0 + 12.0) - 16.0 - 6.0 * gap) / 7.0)
	var n := 10 if not collapsed else 7
	var w := _width(n)
	var h := slot_size + 22.0
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	var extra_top := (slot_size + gap + 6.0) if (collapsed and expanded) else 0.0
	offset_left = -w / 2.0
	offset_right = w / 2.0
	offset_top = -h - 6.0 - extra_top
	offset_bottom = -6.0
	_h = h + extra_top
	_build_rects(n)
	queue_redraw()

func _width(n: int) -> float:
	return 2.0 * (orb_r * 2.0 + 12.0) + n * slot_size + (n - 1) * gap + 16.0

func _build_rects(_n: int) -> void:
	slot_rects.clear()
	var y := _h - slot_size - 10.0
	var x := orb_r * 2.0 + 12.0 + 8.0
	var visible_slots := range(10) if not collapsed else range(6)
	for i in visible_slots:
		slot_rects.append([i, Rect2(x, y, slot_size, slot_size)])
		x += slot_size + gap
	more_rect = Rect2()
	if collapsed:
		more_rect = Rect2(x, y, slot_size, slot_size)
		if expanded:
			var x2 := more_rect.position.x - 3.0 * (slot_size + gap)
			for i in range(6, 10):
				slot_rects.append([i, Rect2(x2, y - slot_size - gap - 6.0, slot_size, slot_size)])
				x2 += slot_size + gap

func _process(delta: float) -> void:
	_mana_flash = maxf(0.0, _mana_flash - delta)
	var h := _hero()
	visible = h != null and h.can_fight
	queue_redraw()

func _on_mana_denied() -> void:
	_mana_flash = 0.35

# ---------------------------------------------------------------- wejście
func slot_at(p: Vector2) -> int:
	for sr in slot_rects:
		if (sr[1] as Rect2).has_point(p):
			return sr[0]
	if more_rect.size.x > 0.0 and more_rect.has_point(p):
		return -2
	return -1

func _press(i: int) -> void:
	if i == -2:
		expanded = not expanded
		Audio.play("ui_click")
		layout()
		return
	if i < 0:
		return
	var h := _hero()
	if h:
		h.use_mouse_aim = false     # aktywacja z paska: celuje pomoc w celowaniu, nie kursor na pasku
	Input.action_press("slot_%d" % (i + 1))
	_flash_slot = i

func _release(i: int) -> void:
	if i >= 0:
		Input.action_release("slot_%d" % (i + 1))

func _gui_input(event: InputEvent) -> void:
	if Save.touch_enabled():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_mouse = slot_at(event.position)
			_press(_press_mouse)
		else:
			_release(_press_mouse)
			_press_mouse = -1
		accept_event()

func _input(event: InputEvent) -> void:
	if not visible or not Save.touch_enabled():
		return
	if event is InputEventScreenTouch:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed:
			if not Rect2(Vector2.ZERO, size).has_point(local):
				return
			var i := slot_at(local)
			_press_touch[event.index] = i
			_press(i)
			get_viewport().set_input_as_handled()
		elif _press_touch.has(event.index):
			_release(int(_press_touch[event.index]))
			_press_touch.erase(event.index)
			get_viewport().set_input_as_handled()

## Czy punkt ekranu leży na pasku (TouchControls nie startuje tam joysticka).
func covers(screen_pos: Vector2) -> bool:
	return visible and get_global_rect().has_point(screen_pos)

# ---------------------------------------------------------------- rysowanie
func _icon_for(entry: String) -> Texture2D:
	if _icons.has(entry):
		return _icons[entry]
	var path := ""
	var h := _hero()
	if h and h.skills.has(entry):
		path = str(h.skills[entry].get("ikona", ""))
	elif entry in Inventory.BELT:
		path = "res://assets/ui/items/%s.png" % str(Data.belt_item(entry).get("ikona", ""))
	var t: Texture2D = load(path) if path != "" and ResourceLoader.exists(path) else null
	_icons[entry] = t
	return t

func _draw() -> void:
	var h := _hero()
	if h == null:
		return
	var hs: HeroState = h.hs
	var w := size.x
	var bh := _h
	var top := bh - slot_size - 22.0
	# deska + żelazne okucia
	draw_rect(Rect2(orb_r, top, w - 2.0 * orb_r, slot_size + 22.0), WOOD_D)
	draw_rect(Rect2(orb_r + 3, top + 3, w - 2.0 * orb_r - 6, slot_size + 16.0), WOOD)
	for yy in range(int(top) + 9, int(bh) - 4, 9):
		draw_line(Vector2(orb_r + 4, yy), Vector2(w - orb_r - 4, yy), WOOD_D, 1.0)
	draw_rect(Rect2(orb_r, top, w - 2.0 * orb_r, 4), IRON)
	draw_rect(Rect2(orb_r, bh - 4, w - 2.0 * orb_r, 4), IRON)
	for xx in range(int(orb_r) + 10, int(w - orb_r), 46):
		draw_rect(Rect2(xx, top + 1, 2, 2), IRON_L)
	# doświadczenie: cienki pasek na górnej krawędzi
	var prev := hs.prev_threshold()
	var nxt := hs.next_threshold()
	var xk := 1.0 if nxt < 0 else float(hs.xp - prev) / maxf(1.0, nxt - prev)
	draw_rect(Rect2(orb_r * 2.0 + 14, top - 4, (w - orb_r * 4.0 - 28) * clampf(xk, 0, 1), 3), Color(0.82, 0.66, 0.22))
	# kule życia i many
	_orb(Vector2(orb_r + 2, bh - orb_r - 4), hs.hp / maxf(1.0, hs.max_hp()), Color(0.62, 0.06, 0.05), Color(0.85, 0.2, 0.15), "%d" % int(ceil(hs.hp)), false)
	_orb(Vector2(w - orb_r - 2, bh - orb_r - 4), hs.mana / maxf(1.0, hs.max_mana()), Color(0.1, 0.2, 0.62), Color(0.3, 0.45, 0.95), "%d" % int(hs.mana), _mana_flash > 0.0)
	# sloty
	var f := get_theme_default_font()
	var entries: Array = h.bar
	for sr in slot_rects:
		var i: int = sr[0]
		var r: Rect2 = sr[1]
		var entry := str(entries[i]) if i < entries.size() else ""
		draw_rect(r.grow(2), Color(0.05, 0.03, 0.02))
		draw_rect(r, Color(0.09, 0.06, 0.04))
		draw_rect(r, IRON, false, 2.0)
		var usable := true
		if entry != "":
			var t := _icon_for(entry)
			if t:
				draw_texture_rect(t, r.grow(-4), false)
			if h.skills.has(entry):
				var sk: Dictionary = h.skills[entry]
				usable = h.can_afford(entry)
				var cd := float(h.cooldowns.get(entry, 0.0))
				var total := float(sk.get("odnowienie", 1.0))
				if cd > 0.0 and total > 0.0:
					_clock(r, cd / total)
				var cost := "%s" % str(snappedf(float(sk.get("koszt_many", 0)), 0.1)).trim_suffix(".0")
				_text(f, r.position + Vector2(3, r.size.y - 4), cost, 12, Color(0.55, 0.7, 1.0))
			elif entry in Inventory.BELT:
				var n := int(hs.inv.belt.get(entry, 0))
				usable = n > 0
				var pc := h.potion_cd
				if pc > 0.0:
					_clock(r, pc / float(Data.bal("mikstury/odstep_sekund", 1.0)))
				_text(f, r.position + Vector2(r.size.x - 4 - f.get_string_size(str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x, r.size.y - 4), str(n), 14, Color(1, 0.95, 0.8))
			if not usable:
				draw_rect(r.grow(-2), Color(0.12, 0.12, 0.12, 0.62))
		_text(f, r.position + Vector2(4, 13), KEYS[i], 12, Color(0.95, 0.85, 0.55))
		if _flash_slot == i and Input.is_action_pressed("slot_%d" % (i + 1)):
			draw_rect(r, Color(1, 0.9, 0.6), false, 2.0)
	if more_rect.size.x > 0.0:
		draw_rect(more_rect, Color(0.09, 0.06, 0.04))
		draw_rect(more_rect, IRON, false, 2.0)
		_text(f, more_rect.get_center() + Vector2(-10, 6), "...", 18, Color(0.95, 0.85, 0.55))

## Zegar odnowienia: zaciemniony wycinek od góry zgodnie z ruchem wskazówek, proporcjonalny do pozostałego czasu.
func _clock(r: Rect2, frac: float) -> void:
	frac = clampf(frac, 0.0, 1.0)
	if frac <= 0.001:
		return
	var c := r.get_center()
	var rad := r.size.x * 0.5 - 3.0
	var pts := PackedVector2Array([c])
	var steps := maxi(3, int(28 * frac))
	var a0 := -PI / 2.0 + TAU * (1.0 - frac)
	for k in steps + 1:
		var a := a0 + TAU * frac * k / steps
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	draw_colored_polygon(pts, Color(0, 0, 0, 0.62))
	draw_arc(c, rad, a0, a0 + TAU * frac, steps, Color(0.95, 0.85, 0.55, 0.8), 1.5)

func _orb(c: Vector2, k: float, col: Color, light: Color, label: String, flash: bool) -> void:
	draw_circle(c, orb_r + 3, Color(0.05, 0.03, 0.02))
	draw_circle(c, orb_r, Color(0.08, 0.06, 0.06))
	k = clampf(k, 0.0, 1.0)
	var top := c.y + orb_r - 2.0 * orb_r * k
	for y in range(int(ceil(top)), int(c.y + orb_r)):
		var dy := y + 0.5 - c.y
		var half := sqrt(maxf(0.0, orb_r * orb_r - dy * dy))
		var lc := light if (y - int(top)) < 3 else col
		draw_line(Vector2(c.x - half, y + 0.5), Vector2(c.x + half, y + 0.5), lc, 1.0)
	draw_arc(c, orb_r, 0, TAU, 40, Color(1, 1, 1, 0.9) if flash else IRON, 3.0 if flash else 2.0)
	draw_circle(c + Vector2(-orb_r * 0.35, -orb_r * 0.4), orb_r * 0.12, Color(1, 1, 1, 0.35))
	var f := get_theme_default_font()
	var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_text(f, c + Vector2(-w / 2.0, 6), label, 15, Color(1, 1, 1))

func _text(f: Font, p: Vector2, t: String, fs: int, col: Color) -> void:
	draw_string_outline(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0))
	draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
