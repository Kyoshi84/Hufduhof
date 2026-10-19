extends Node
## Dowód działania folderów grafik: syntetyczne (celowo brzydkie) klatki i warstwy w user://,
## wczytywane przez CharacterSheet/StageArt. Pokazuje pivot, odbicie, klatkę kontaktu = koniec hitboxa.
const TMP := "user://asset_demo"
var lvl: Level

func rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)

func save(path: String, img: Image) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	img.save_png(path)

func blank(w: int, h: int) -> Image:
	var i := Image.create(w, h, false, Image.FORMAT_RGBA8)
	i.fill(Color(0, 0, 0, 0))
	return i

func make_ivo() -> void:
	var fw := 320; var fh := 192; var px := 160; var py := 190
	var cols := [Color(0.2, 0.4, 0.9), Color(0.3, 0.6, 0.9), Color(0.95, 0.15, 0.15), Color(0.3, 0.8, 0.3), Color(0.5, 0.9, 0.5)]
	var man := { "id": "ivo", "frame_size": [fw, fh], "pivot": [px, py], "world_per_texel": 1.3333, "animations": {
		"light1": { "frames": 5, "fps": 0, "loop": false, "contact": [2, 2] } } }
	for i in 5:
		var im := blank(fw, fh)
		rect(im, px - 14, py - 120, 28, 120, cols[i])                       # ciało
		rect(im, px - 8, py - 140, 16, 20, Color(0.9, 0.7, 0.5))             # głowa
		var reach_px: int = [20, 10, 105, 60, 30][i]                          # miecz: kontakt = 105 px sprite'a = 140 jedn. świata
		rect(im, px + 10, py - 80, reach_px, 8, Color(0.85, 0.85, 0.9))
		rect(im, px - 3, py - 3, 6, 6, Color(1, 1, 0))                        # znacznik pivotu
		save("%s/characters/ivo/anim/light1/light1_%02d.png" % [TMP, i], im)
	save_json("%s/characters/ivo/character.json" % TMP, man)

func make_skaven() -> void:
	var man := { "id": "skaven", "frame_size": [160, 112], "pivot": [80, 110], "world_per_texel": 1.3333, "animations": {
		"idle": { "frames": 2, "fps": 4, "loop": true }, "claw": { "frames": 5, "fps": 0, "loop": false, "contact": [2, 2] } } }
	for i in 2:
		var im := blank(160, 112)
		rect(im, 66, 40, 28, 70, Color(0.55, 0.4, 0.25))
		rect(im, 70, 28, 22, 16, Color(0.7, 0.5, 0.35))
		rect(im, 90, 34, 12, 6, Color(1, 0.4, 0.5))                           # pysk wskazuje kierunek (prawo)
		rect(im, 77, 107, 6, 6, Color(1, 1, 0))
		save("%s/characters/skaven/anim/idle/idle_%02d.png" % [TMP, i], im)
	var ccols := [Color(0.3, 0.3, 0.9), Color(0.3, 0.6, 0.9), Color(0.95, 0.2, 0.2), Color(0.4, 0.8, 0.4), Color(0.6, 0.9, 0.6)]
	for i in 5:
		var im2 := blank(160, 112)
		rect(im2, 66, 40, 28, 70, ccols[i])
		rect(im2, 70, 28, 22, 16, Color(0.7, 0.5, 0.35))
		rect(im2, 90, 34, 12, 6, Color(1, 0.4, 0.5))
		rect(im2, 94, 60, [4, 10, 40, 20, 8][i], 6, Color(0.9, 0.9, 0.9))   # pazur: kontakt = 40 px
		rect(im2, 77, 107, 6, 6, Color(1, 1, 0))
		save("%s/characters/skaven/anim/claw/claw_%02d.png" % [TMP, i], im2)
	save_json("%s/characters/skaven/character.json" % TMP, man)

func save_json(path: String, d: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))

func make_stage() -> void:
	var man := { "id": "stage2_village", "world_per_texel": 1.3333, "layers": {
		"sky": { "file": "sky.png", "parallax": 0.0, "y_offset": 0 }, "far1": { "file": "far1.png", "parallax": 0.15, "y_offset": 0 },
		"ground": { "file": "ground.png", "parallax": 1.0, "y_offset": 0 }, "foreground": { "file": "foreground.png", "parallax": 1.25, "y_offset": 0 } }, "props": {} }
	save_json("%s/stages/stage2_village/stage.json" % TMP, man)
	var sky := blank(64, 260)
	for y in 260:
		rect(sky, 0, y, 64, 1, Color(0.15 + y / 600.0, 0.2 + y / 500.0, 0.5, 1))
	for c in 5:
		rect(sky, 8 + c * 11, 60 + (c % 2) * 20, 9, 5, Color(0.9, 0.9, 1))      # chmurki (widoczny szew powtarzania)
	save("%s/stages/stage2_village/sky.png" % TMP, sky)
	var far := blank(320, 100)
	for k in 8:
		for y in 60:
			rect(far, k * 40 + 20 - y / 3, 100 - y, 2 * (y / 3) + 1, 1, Color(0.25, 0.3, 0.45))
	save("%s/stages/stage2_village/far1.png" % TMP, far)
	var gr := blank(32, 280)
	for y in 280:
		for x in 32:
			gr.set_pixel(x, y, Color(0.35, 0.28, 0.15) if (x / 8 + y / 8) % 2 == 0 else Color(0.3, 0.24, 0.12))
	save("%s/stages/stage2_village/ground.png" % TMP, gr)
	var fg := blank(160, 40)
	for k in 10:
		rect(fg, k * 16, 10, 6, 30, Color(0.05, 0.12, 0.05))
	save("%s/stages/stage2_village/foreground.png" % TMP, fg)
	var h := blank(110, 130)
	rect(h, 10, 50, 90, 80, Color(0.55, 0.35, 0.2))
	for r in 40:
		rect(h, 5 + r, 50 - r, 100 - 2 * r, 1, Color(0.8, 0.7, 0.3))
	rect(h, 45, 90, 20, 40, Color(0.2, 0.12, 0.08))
	save("%s/stages/stage2_village/props/house_thatch.png" % TMP, h)
	var bar := blank(36, 44)
	rect(bar, 2, 2, 32, 40, Color(0.9, 0.2, 0.9))
	save("%s/stages/common/props/barrel.png" % TMP, bar)
	save_json("%s/stages/common/stage.json" % TMP, { "id": "common", "layers": {}, "props": {} })

func _ready() -> void:
	add_child(PaletteFilter.new())
	run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/claude/shots/%s.png" % n)
	print("zapisano ", n)

func put(type: String, x: float, y: float, facing: int) -> Enemy:
	var e := Enemy.new()
	e.setup(lvl, type, Vector2(x, y))
	lvl.attach_visual(e, type)
	lvl.entities.add_child(e)
	lvl.enemies.append(e)
	e.ai_cd = 99999.0
	e.speed = 0.0
	e.depth_speed = 0.0
	e.facing = facing
	e.hp = 999.0
	e.max_hp = 999.0
	return e

func run() -> void:
	make_ivo(); make_skaven(); make_stage()
	CharacterSheet.root = TMP + "/characters"
	StageArt.root = TMP + "/stages"
	CharacterSheet.clear_cache()
	StageArt.clear_cache()
	GameState.god_mode = true
	GameState.story_enabled = false
	lvl = Level.new()
	add_child(lvl)
	await frames(10)
	lvl.next_wave = 99
	lvl.player.position = Vector2(2500, 500)
	lvl.player.facing = 1
	lvl.view_left = 2500.0 - 540.0
	var sk_l := put("skaven", 2700, 505, -1)
	var sk_r := put("skaven", 2400, 520, 1)
	var sk_a := put("skaven", 2330, 470, 1)
	sk_a.start_attack("claw", sk_a.attack_defs["claw"])
	sk_a.set_state(Actor.State.ACTIVE)
	sk_a.state_t = 0.02
	var bar := Barrel.new()
	bar.setup(lvl, Vector2(2620, 430))
	lvl.entities.add_child(bar)
	lvl.barrels.append(bar)
	await frames(30)
	lvl.hud.banner_label.visible = false
	var p := lvl.player
	GameState.debug_collision = true
	lvl.set_physics_process(false)         # zamrożenie symulacji: stan zostaje taki, jaki ustawimy
	p.start_attack("light1", p.attack_defs["light1"])
	p.state_t = 0.05                       # zamach
	await frames(3)
	await shot("40_ivo_zamach")
	p.set_state(Actor.State.ACTIVE)
	p.state_t = 0.03                       # okno aktywne = klatka kontaktu
	await frames(3)
	await shot("41_ivo_kontakt")
	p.set_state(Actor.State.RECOVER)
	p.state_t = 0.18                       # powrót
	await frames(3)
	await shot("42_ivo_powrot")
	print("KONIEC")
	get_tree().quit()
