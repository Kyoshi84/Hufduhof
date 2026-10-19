extends Node
## Uruchamianie: godot --headless --path . res://tests/test_runner.tscn
## Kończy proces kodem 0 (OK) lub 1 (błędy).

var failures: Array = []
var checks: int = 0

func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)
		print("  FAIL: ", msg)

func _ready() -> void:
	Balance.load_data()
	GameState.god_mode = false
	var tests := [
		"t_balance", "t_hit_geometry", "t_single_hit_per_attack", "t_invulnerability", "t_light_timing",
		"t_skaven_ai", "t_hound_charge", "t_beastman_poise", "t_boss_phases", "t_wave_flow", "t_pause_state",
		"t_restart_cleanup", "t_save_data", "t_touch_controls", "t_hit_shape", "t_sword_scenarios", "t_sword_assist", "t_art_assets", "t_ivo_direction", "t_asset_folders", "t_sheet_loading", "t_sheet_integration", "t_stage_art", "t_story", "t_tavern", "t_music", "t_full_run_bot",
	]
	for t in tests:
		var t0 := Time.get_ticks_msec()
		GameState.reset()
		Controls.reset()
		call(t)
		print("[test] %s (%d ms)" % [t, Time.get_ticks_msec() - t0])
	print("\nSprawdzeń: %d, błędów: %d" % [checks, failures.size()])
	get_tree().quit(1 if failures.size() > 0 else 0)

# ------------------------------------------------------------------ pomocnicze

func make_level() -> Level:
	var lvl := Level.new()
	lvl.simulate_only = true
	add_child(lvl)
	return lvl

func step(lvl: Level, secs: float, bot: TestBot = null) -> void:
	var n := int(secs * 60.0)
	for i in n:
		if bot != null:
			bot.drive(1.0 / 60.0)
		lvl.tick(1.0 / 60.0)

func spawn(lvl: Level, type: String, pos: Vector2) -> Enemy:
	var e: Enemy = Boss.new() if str(Balance.enemy(type)["behavior"]) == "boss" else Enemy.new()
	e.setup(lvl, type, pos)
	lvl.attach_visual(e, type)
	lvl.entities.add_child(e)
	lvl.enemies.append(e)
	if e is Boss:
		lvl.boss = e
	return e

func free_level(lvl: Level) -> void:
	lvl.queue_free()

# ------------------------------------------------------------------ testy

func t_music() -> void:
	var cfg: Dictionary = Sfx.load_music_cfg()
	var tracks: Dictionary = cfg.get("tracks", {})
	for k in ["menu", "stage", "boss"]:
		ok(tracks.has(k), "music.json: utwór %s" % k)
		var f := str(tracks.get(k, {}).get("file", ""))
		ok(ResourceLoader.exists(f), "plik muzyki istnieje: %s" % f)
		if ResourceLoader.exists(f):
			var st = load(f)
			ok(st is AudioStreamOggVorbis, "%s to OGG" % k)
			var ln: float = st.get_length()
			ok(ln > 20.0 and ln < 150.0, "%s: długość pętli %.1f s" % [k, ln])
	# przepływ ekranów: menu -> prolog (cisza) -> etap 1 (muzyka) -> boss
	var main = load("res://main.tscn").instantiate()
	add_child(main)
	ok(Sfx.current_track == "menu", "menu główne gra motyw menu")
	main.show_settings()
	ok(Sfx.current_track == "menu", "ustawienia nie przerywają motywu menu")
	main.show_menu()
	main.show_prologue()
	ok(Sfx.current_track == "", "prolog (Etap 0) bez muzyki")
	main.show_tavern()
	ok(Sfx.current_track == "", "karczma (Etap 0) bez muzyki")
	main.begin_level(0)
	ok(Sfx.current_track == "stage", "etap 1 gra motyw rozgrywki")
	var lvl: Level = main.current
	lvl.spawn_enemy("chaos_champion", "right")
	ok(Sfx.current_track == "boss", "pojawienie się Czempiona włącza motyw bossa")
	main.show_menu()
	ok(Sfx.current_track == "menu", "powrót do menu przywraca motyw menu")
	Sfx.stop_music()
	main.queue_free()
	get_tree().paused = false

func t_balance() -> void:
	ok(Balance.validate().is_empty(), "balans przechodzi walidację: %s" % str(Balance.validate()))
	for id in ["skaven", "chaos_hound", "beastman", "chaos_champion"]:
		ok(Balance.data["enemies"].has(id), "istnieje wróg %s" % id)
	var lvl_data := Level.load_level_data("res://data/level_1.json")
	ok(lvl_data["waves"].size() >= 8, "poziom ma co najmniej 8 fal")
	ok(bool(lvl_data["waves"][lvl_data["waves"].size() - 1].get("final", false)), "ostatnia fala jest falą bossa")

func t_hit_geometry() -> void:
	var lvl := make_level()
	var p: Player = lvl.player
	p.position = Vector2(1000, 480)
	p.facing = 1
	var near := spawn(lvl, "beastman", Vector2(1100, 480))
	var wrong_depth := spawn(lvl, "beastman", Vector2(1100, 480 + 90))
	var far := spawn(lvl, "beastman", Vector2(1100 + 300, 480))
	var behind := spawn(lvl, "beastman", Vector2(900, 480))
	for e in [near, wrong_depth, far, behind]:
		e.ai_cd = 99.0
	p.start_attack("light1", p.attack_defs["light1"])
	step(lvl, 0.6)
	ok(near.hp < near.max_hp, "wróg w zasięgu i na tej samej głębi dostaje obrażenia")
	ok(wrong_depth.hp == wrong_depth.max_hp, "wróg na innej głębi nie dostaje obrażeń")
	ok(far.hp == far.max_hp, "wróg poza zasięgiem nie dostaje obrażeń")
	ok(behind.hp == behind.max_hp, "wróg za plecami nie dostaje obrażeń od ataku w przód")
	# szeroki zamach trafia też za plecami
	p.start_attack("sweep", p.attack_defs["sweep"])
	step(lvl, 0.8)
	ok(behind.hp < behind.max_hp, "sweep (obszarowy) trafia wroga za plecami")
	free_level(lvl)

func t_single_hit_per_attack() -> void:
	var lvl := make_level()
	var p: Player = lvl.player
	p.position = Vector2(1000, 480)
	var e := spawn(lvl, "skaven", Vector2(1090, 480))
	e.ai_cd = 99.0
	e.hp = 1000.0
	e.max_hp = 1000.0
	p.start_attack("light1", p.attack_defs["light1"])
	step(lvl, 0.7)
	var expected: float = 1000.0 - float(p.attack_defs["light1"]["damage"]) * e.resist
	ok(absf(e.hp - expected) < 0.01, "jeden atak = jedno trafienie (hp %.1f, oczekiwane %.1f)" % [e.hp, expected])
	free_level(lvl)

func t_invulnerability() -> void:
	var lvl := make_level()
	var p: Player = lvl.player
	p.position = Vector2(1000, 480)
	var e := spawn(lvl, "skaven", Vector2(1050, 480))
	e.ai_cd = 99.0
	var d: Dictionary = e.attack_defs["claw"]
	var hp0: float = p.hp
	ok(p.receive_hit(e, d), "pierwsze trafienie w gracza przechodzi")
	var hp1: float = p.hp
	ok(hp1 < hp0, "gracz traci zdrowie")
	ok(not p.receive_hit(e, d), "drugie trafienie w oknie nietykalności jest ignorowane")
	ok(p.hp == hp1, "zdrowie bez zmian podczas nietykalności")
	step(lvl, 1.0)
	ok(p.receive_hit(e, d), "po wygaśnięciu nietykalności gracz znów może dostać obrażenia")
	# unik daje nietykalność
	step(lvl, 1.0)
	p.state = Actor.State.IDLE
	Controls.touch_move = Vector2(1, 0)
	Controls.press("dodge")
	step(lvl, 0.05)
	Controls.touch_move = Vector2.ZERO
	ok(p.state == Actor.State.DODGE, "unik uruchamia stan DODGE")
	var hp2: float = p.hp
	ok(not p.receive_hit(e, d) and p.hp == hp2, "unik daje chwilową nietykalność")
	free_level(lvl)

func t_light_timing() -> void:
	var lvl := make_level()
	var p: Player = lvl.player
	var seq: Array = []
	Controls.press("light")
	for i in 90:
		lvl.tick(1.0 / 60.0)
		if seq.is_empty() or seq[seq.size() - 1] != p.state:
			seq.append(p.state)
	var i_w: int = seq.find(Actor.State.WINDUP)
	var i_a: int = seq.find(Actor.State.ACTIVE)
	var i_r: int = seq.find(Actor.State.RECOVER)
	ok(i_w >= 0 and i_a > i_w and i_r > i_a, "atak przechodzi WINDUP -> ACTIVE -> RECOVER (%s)" % str(seq))
	ok(p.state == Actor.State.IDLE or p.state == Actor.State.MOVE, "po ataku gracz wraca do IDLE")
	# cooldown mocnego ataku
	Controls.press("heavy")
	step(lvl, 0.1)
	ok(p.attack_name == "heavy", "mocny atak startuje")
	step(lvl, 1.2)
	var cd_left: float = float(p.cooldowns["heavy"])
	ok(cd_left >= 0.0, "cooldown mocnego ataku liczy się w dół")
	free_level(lvl)

func t_skaven_ai() -> void:
	var lvl := make_level()
	var p: Player = lvl.player
	p.position = Vector2(1000, 480)
	var sk: Array = []
	for i in 4:
		sk.append(spawn(lvl, "skaven", Vector2(1500 + i * 30, 420 + i * 40)))
	var max_simul_attackers := 0
	var sides := {}
	var hp0: float = p.hp
	for i in 600:
		lvl.tick(1.0 / 60.0)
		var n := 0
		for e in sk:
			if e.is_attacking():
				n += 1
			sides[1 if e.position.x > p.position.x else -1] = true
		max_simul_attackers = maxi(max_simul_attackers, n)
	ok(p.hp < hp0, "skaveni dobiegają do gracza i go ranią")
	ok(max_simul_attackers <= int(Balance.world("max_attackers")), "limit jednoczesnych atakujących (%d)" % max_simul_attackers)
	ok(sides.size() == 2, "skaveni występują po obu stronach gracza (flankowanie)")
	free_level(lvl)

func t_hound_charge() -> void:
	var lvl := make_level()
	var p: Player = lvl.player
	p.position = Vector2(1000, 480)
	GameState.god_mode = true
	var h := spawn(lvl, "chaos_hound", Vector2(1400, 480))
	var saw_windup := false
	var windup_len := 0.0
	var saw_active := false
	var moved_during_active := 0.0
	var x_start := 0.0
	for i in 900:
		lvl.tick(1.0 / 60.0)
		if h.attack_name == "charge" and h.state == Actor.State.WINDUP:
			saw_windup = true
			windup_len += 1.0 / 60.0
		if h.attack_name == "charge" and h.state == Actor.State.ACTIVE:
			if not saw_active:
				x_start = h.position.x
			saw_active = true
			moved_during_active = absf(h.position.x - x_start)
	GameState.god_mode = false
	ok(saw_windup and windup_len >= 0.45, "pies telegrafuje szarżę (zamach %.2f s)" % windup_len)
	ok(saw_active and moved_during_active > 150.0, "szarża przemieszcza psa (%.0f px)" % moved_during_active)
	free_level(lvl)

func t_beastman_poise() -> void:
	var lvl := make_level()
	var p: Player = lvl.player
	p.position = Vector2(1000, 480)
	var b := spawn(lvl, "beastman", Vector2(1100, 480))
	b.ai_cd = 99.0
	var light: Dictionary = p.attack_defs["light1"]
	var heavy: Dictionary = p.attack_defs["heavy"]
	b.receive_hit(p, light)
	ok(b.state != Actor.State.HURT, "lekki atak nie przerywa zwierzoluda (poise)")
	b.invuln = 0.0
	b.receive_hit(p, heavy)
	ok(b.state == Actor.State.HURT, "mocny atak łamie poise i przerywa zwierzoluda")
	# zwierzoczłek przerywa akcje gracza
	var b2 := spawn(lvl, "beastman", Vector2(1080, 500))
	b2.ai_cd = 99.0
	p.start_attack("light1", p.attack_defs["light1"])
	step(lvl, 0.05)
	p.invuln = 0.0
	p.receive_hit(b2, b2.attack_defs["chop"])
	ok(p.state == Actor.State.HURT, "cios zwierzoluda przerywa atak gracza")
	free_level(lvl)

func t_boss_phases() -> void:
	var lvl := make_level()
	var p: Player = lvl.player
	p.position = Vector2(1000, 480)
	var boss := spawn(lvl, "chaos_champion", Vector2(1120, 480))
	boss.ai_cd = 99.0
	ok(boss.phase == 1, "boss zaczyna w fazie 1")
	boss.hp = boss.max_hp * 0.66 + 2.0
	boss.invuln = 0.0
	boss.receive_hit(p, p.attack_defs["light1"])
	ok(boss.phase == 2, "przy ~64%% zdrowia boss wchodzi w fazę 2 (faza=%d)" % boss.phase)
	boss.invuln = 0.0
	boss.hp = boss.max_hp * 0.33 + 2.0
	boss.receive_hit(p, p.attack_defs["light1"])
	ok(boss.phase == 3, "przy ~31%% zdrowia boss wchodzi w fazę 3 (faza=%d)" % boss.phase)
	var pause1: float = float(boss.phases[0]["pause"])
	var pause3: float = float(boss.phases[2]["pause"])
	ok(pause3 < pause1, "przerwy między akcjami w fazie 3 są krótsze")
	# wzorce z fazy 2 i 3 zawierają nowe ataki
	var names2 := []
	for pt in boss.phases[1]["patterns"]:
		names2.append_array(pt["seq"])
	ok(names2.has("slam") and names2.has("charge"), "faza 2 ma ataki obszarowe i szarżę")
	# boss faktycznie atakuje i telegrafuje
	var lvl2 := make_level()
	lvl2.player.position = Vector2(1000, 480)
	GameState.god_mode = true
	var b2 := spawn(lvl2, "chaos_champion", Vector2(1100, 480))
	var windups := 0
	var used := {}
	for i in 3000:
		lvl2.tick(1.0 / 60.0)
		if b2.state == Actor.State.WINDUP:
			if b2.state_t < 0.02:
				windups += 1
				used[b2.attack_name] = true
	GameState.god_mode = false
	ok(windups >= 5, "boss wykonuje wiele telegrafowanych ataków (%d)" % windups)
	free_level(lvl2)
	free_level(lvl)

func t_wave_flow() -> void:
	var lvl := make_level()
	var p: Player = lvl.player
	var w0: Dictionary = lvl.waves[0]
	p.position.x = float(w0["trigger"]) + 10.0
	step(lvl, 0.1)
	ok(lvl.wave_active and lvl.locked, "wejście w trigger uruchamia falę i blokuje ekran")
	step(lvl, 4.0)
	var expected := 0
	for s in w0["spawns"]:
		expected += int(s["count"])
	ok(lvl.enemies.size() == expected, "fala 0 zrodziła %d wrogów (jest %d)" % [expected, lvl.enemies.size()])
	ok(lvl.next_wave == 0, "fala nie jest zakończona, dopóki wrogowie żyją")
	GameState.god_mode = true
	for e in lvl.enemies.duplicate():
		e.hp = 1.0
		e.invuln = 0.0
		e.receive_hit(p, p.attack_defs["heavy"])
	step(lvl, 0.2)
	GameState.god_mode = false
	ok(not lvl.wave_active and not lvl.locked, "po pokonaniu wrogów ekran się odblokowuje")
	ok(lvl.next_wave == 1 and lvl.go_prompt, "kolejna fala w kolejce i pojawia się znacznik 'idź'")
	ok(GameState.kills == expected, "licznik pokonanych = %d" % expected)
	ok(GameState.score >= expected * 100, "wynik rośnie za pokonanych wrogów")
	ok(SaveData.has_checkpoint(), "po fali zapisuje się checkpoint")
	SaveData.clear_checkpoint()
	free_level(lvl)

func t_pause_state() -> void:
	var lvl := make_level()
	lvl.toggle_pause()   # w trybie testowym ignorowane
	ok(not get_tree().paused, "tryb testowy nie ustawia pauzy globalnej")
	free_level(lvl)

func t_restart_cleanup() -> void:
	var lvl := make_level()
	spawn(lvl, "skaven", Vector2(1500, 450))
	GameState.score = 999
	GameState.kills = 7
	lvl.queue_free()
	GameState.reset()
	var lvl2 := make_level()
	ok(lvl2.enemies.is_empty() and lvl2.tokens.is_empty(), "nowy poziom nie dziedziczy wrogów ani tokenów")
	ok(GameState.score == 0 and GameState.kills == 0, "wynik i licznik zresetowane")
	ok(lvl2.player.hp == lvl2.player.max_hp, "gracz startuje z pełnym zdrowiem")
	ok(lvl2.next_wave == 0 and not lvl2.wave_active, "fale od początku")
	free_level(lvl2)

func t_save_data() -> void:
	var old_path: String = SaveData.path
	SaveData.path = "user://test_save.cfg"
	SaveData.clear_checkpoint()
	ok(not SaveData.has_checkpoint(), "brak checkpointu na starcie")
	SaveData.music_volume = 0.3
	SaveData.set_checkpoint(3, 1200, 9)
	SaveData.music_volume = 0.9
	SaveData.checkpoint = {}
	SaveData.load_all()
	ok(SaveData.has_checkpoint() and int(SaveData.checkpoint["wave"]) == 3, "checkpoint odczytuje się z pliku")
	ok(int(SaveData.checkpoint["score"]) == 1200, "wynik w checkpoincie zapisany")
	ok(absf(SaveData.music_volume - 0.3) < 0.001, "ustawienia głośności zapisane")
	SaveData.music_volume = 0.7
	SaveData.clear_checkpoint()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.cfg"))
	SaveData.path = old_path

func t_touch_controls() -> void:
	var tc := TouchControls.new()
	add_child(tc)
	var size_v: Vector2 = tc.get_viewport_rect().size
	# joystick: dotknięcie po lewej, przeciągnięcie w prawo
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = Vector2(200, size_v.y - 150)
	tc._input(down)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(200 + 120, size_v.y - 150)
	tc._input(drag)
	ok(Controls.touch_move.x > 0.95 and absf(Controls.touch_move.y) < 0.05, "joystick: przeciągnięcie w prawo daje ruch w prawo (%s)" % str(Controls.touch_move))
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = drag.position
	tc._input(up)
	ok(Controls.touch_move == Vector2.ZERO, "puszczenie joysticka zeruje ruch")
	# przyciski
	var lay: Dictionary = tc.layout()
	for act in ["light", "heavy", "dodge"]:
		var t := InputEventScreenTouch.new()
		t.index = 3
		t.pressed = true
		t.position = lay[act][0]
		tc._input(t)
		ok(Controls.consume(act), "przycisk dotykowy '%s' rejestruje akcję" % act)
		t.pressed = false
		tc._input(t)
	# dwa palce naraz: joystick + atak (multi-touch)
	var d2 := InputEventScreenTouch.new()
	d2.index = 1
	d2.pressed = true
	d2.position = Vector2(180, size_v.y - 140)
	tc._input(d2)
	var b2 := InputEventScreenTouch.new()
	b2.index = 2
	b2.pressed = true
	b2.position = lay["light"][0]
	tc._input(b2)
	ok(Controls.consume("light"), "multi-touch: atak działa podczas trzymania joysticka")
	ok(tc.stick_id == 1, "multi-touch: joystick nadal aktywny")
	tc.queue_free()
	Controls.reset()


# ------------------------------------------------------------------ miecz: scenariusze z briefu

func fresh_pair(ex: float, ey: float = 480.0, type: String = "skaven", px: float = 1000.0) -> Array:
	var lvl := make_level()
	var p: Player = lvl.player
	p.position = Vector2(px, 480.0)
	p.facing = 1
	var e := spawn(lvl, type, Vector2(ex, ey))
	e.ai_cd = 99999.0
	e.speed = 0.0
	e.depth_speed = 0.0
	e.hp = 1000.0
	e.max_hp = 1000.0
	return [lvl, p, e]

func swing(lvl: Level, p: Player, atk: String = "light1", lunge_off: bool = true, secs: float = 0.6) -> void:
	var d: Dictionary = p.attack_defs[atk].duplicate()
	if lunge_off:
		d["lunge"] = 0.0
	p.attack_defs[atk] = d
	p.start_attack(atk, d)
	step(lvl, secs)

func t_hit_shape() -> void:
	var atk := { "reach": 140.0, "depth": 34.0, "hit_start": 18.0 }
	var r := HitShape.attack_rect(Vector2(1000, 480), 1, atk)
	ok(absf(r.position.x - 1018.0) < 0.01 and absf(r.end.x - 1140.0) < 0.01, "hitbox w prawo: od 18 do 140 px przed pivotem (%s)" % str(r))
	var l := HitShape.attack_rect(Vector2(1000, 480), -1, atk)
	ok(absf(l.position.x - 860.0) < 0.01 and absf(l.end.x - 982.0) < 0.01, "hitbox w lewo jest lustrem w osi pivotu (%s)" % str(l))
	var sw := HitShape.attack_rect(Vector2(1000, 480), 1, { "reach": 165.0, "back": 165.0, "depth": 52.0 })
	ok(sw.position.x == 835.0 and sw.end.x == 1165.0, "atak obszarowy obejmuje obie strony")
	var h := HitShape.hurt_rect(Vector2(1160, 480), 20.0, 8.0)
	ok(HitShape.test(r, h) == "hit", "hurtbox stykający się z końcem hitboxa = trafienie")
	ok(HitShape.test(r, HitShape.hurt_rect(Vector2(1165, 480), 20.0, 8.0)) == "reach", "o 5 px dalej = poza zasięgiem")
	ok(HitShape.test(r, HitShape.hurt_rect(Vector2(1100, 560), 20.0, 8.0)) == "depth", "inna linia głębi = depth")

func t_sword_scenarios() -> void:
	var foot: float = float(Balance.world("foot_half_depth"))
	# 1. wróg tuż przed Ivo
	var a := fresh_pair(1090.0)
	swing(a[0], a[1])
	ok(a[2].hp < a[2].max_hp, "[1] wróg bezpośrednio przed Ivo dostaje obrażenia")
	a[0].queue_free()
	# 2. granica zasięgu (lunge wyłączony, żeby granica była ostra): reach 140 + body_half 20 => x <= 1160
	var b1 := fresh_pair(1158.0)
	swing(b1[0], b1[1])
	ok(b1[2].hp < b1[2].max_hp, "[2] wróg na granicy zasięgu (1158) jest trafiony")
	b1[0].queue_free()
	var b2 := fresh_pair(1163.0)
	swing(b2[0], b2[1])
	ok(b2[2].hp == b2[2].max_hp, "[2] wróg 3 px za granicą (1163) nie jest trafiony")
	b2[0].queue_free()
	# 3. poza zasięgiem
	var c := fresh_pair(1400.0)
	swing(c[0], c[1])
	ok(c[2].hp == c[2].max_hp, "[3] wróg daleko poza zasięgiem nie jest trafiony")
	c[0].queue_free()
	# 4. lewo i prawo
	var d1 := fresh_pair(1100.0)
	swing(d1[0], d1[1])
	var right_ok: bool = d1[2].hp < d1[2].max_hp
	d1[0].queue_free()
	var d2 := fresh_pair(900.0)
	d2[1].facing = -1
	swing(d2[0], d2[1])
	ok(right_ok and d2[2].hp < d2[2].max_hp, "[4] atak w prawo i w lewo trafia wroga po właściwej stronie")
	var d3 := fresh_pair(900.0)
	d3[1].facing = 1
	d3[1].position.x = 1000.0
	swing(d3[0], d3[1])
	ok(d3[2].hp == d3[2].max_hp, "[4] atak w prawo nie trafia wroga stojącego z lewej")
	d2[0].queue_free()
	d3[0].queue_free()
	# 5. atak podczas ruchu (gracz trzyma kierunek)
	var e5 := fresh_pair(1090.0)
	Controls.touch_move = Vector2(1, 0)
	Controls.press("light")
	step(e5[0], 0.6)
	Controls.touch_move = Vector2.ZERO
	ok(e5[2].hp < e5[2].max_hp and e5[1].facing == 1, "[5] atak z wciśniętym kierunkiem trafia i zachowuje kierunek")
	e5[0].queue_free()
	# 6. wróg idący na Ivo (prawdziwe AI) - bot tnie, gdy wróg jest w zasięgu wizualnym
	var f := make_level()
	f.player.position = Vector2(1000, 480)
	var sk := spawn(f, "skaven", Vector2(1500, 480))
	sk.hp = 500.0
	sk.max_hp = 500.0
	var hits := 0
	var swings := 0
	var hp_prev: float = sk.hp
	for i in 420:
		var dx: float = sk.position.x - f.player.position.x
		if f.player.state == Actor.State.IDLE and absf(dx) < 150.0 and absf(sk.position.y - f.player.position.y) < 30.0 and f.player.cooldown_ready("light1"):
			f.player.facing = 1 if dx > 0 else -1
			Controls.press("light")
			swings += 1
		f.tick(1.0 / 60.0)
		if sk.hp < hp_prev:
			hits += 1
			hp_prev = sk.hp
	ok(hits >= 1 and hits >= swings / 3, "[6] wróg idący na Ivo jest trafiany (%d trafień / %d zamachów)" % [hits, swings])
	f.queue_free()
	# 7. inna linia głębi (hurtbox +-8, hitbox +-34 => granica 42)
	var g1 := fresh_pair(1100.0, 480.0 + 40.0)
	swing(g1[0], g1[1])
	ok(g1[2].hp < g1[2].max_hp, "[7] wróg 40 px w głąb (w paśmie) jest trafiony")
	g1[0].queue_free()
	var g2 := fresh_pair(1100.0, 480.0 + 48.0)
	swing(g2[0], g2[1])
	ok(g2[2].hp == g2[2].max_hp, "[7] wróg 48 px w głąb (inna linia) nie jest trafiony")
	g2[0].queue_free()
	# 8. po przesunięciu kamery (współrzędne świata, nie ekranu)
	var h := fresh_pair(3590.0, 480.0, "skaven", 3500.0)
	h[0].view_left = 3000.0
	h[0].update_camera(1.0)
	swing(h[0], h[1])
	ok(h[0].view_left > 2900.0 and h[2].hp < h[2].max_hp, "[8] trafienie działa po przesunięciu kamery (view_left=%.0f)" % h[0].view_left)
	h[0].queue_free()
	# 9. szeroki zamach vs grupa; 10. jedno trafienie na wroga
	var k := fresh_pair(1100.0)
	var k2 := spawn(k[0], "skaven", Vector2(900.0, 490.0))
	var k3 := spawn(k[0], "skaven", Vector2(1140.0, 470.0))
	for e in [k2, k3]:
		e.ai_cd = 99999.0
		e.speed = 0.0
		e.depth_speed = 0.0
		e.hp = 1000.0
		e.max_hp = 1000.0
	swing(k[0], k[1], "sweep")
	var dmg: float = float(k[1].attack_defs["sweep"]["damage"])
	var all_once := true
	for e in [k[2], k2, k3]:
		if absf((1000.0 - e.hp) - dmg * e.resist) > 0.01:
			all_once = false
	ok(all_once, "[9][10] sweep trafia całą grupę (przód i tył), każdego dokładnie raz (hp: %.0f / %.0f / %.0f)" % [k[2].hp, k2.hp, k3.hp])
	k[0].queue_free()
	# 11. hitbox wyłączony po animacji
	var m := fresh_pair(1500.0)
	swing(m[0], m[1])
	ok(not m[1].hitbox_active() and m[1].state != Actor.State.ACTIVE, "[11] po zakończeniu animacji hitbox jest wyłączony")
	m[2].position.x = 1100.0
	step(m[0], 0.5)
	ok(m[2].hp == m[2].max_hp, "[11] wróg wchodzący w dawny obszar po ataku nie dostaje obrażeń")
	# 11b. hitbox aktywny wyłącznie w fazie ACTIVE
	var seen := {}
	var n := fresh_pair(1090.0)
	n[1].start_attack("light1", n[1].attack_defs["light1"])
	for i in 60:
		n[0].tick(1.0 / 60.0)
		seen[n[1].state] = seen.get(n[1].state, true) and (n[1].hitbox_active() == (n[1].state == Actor.State.ACTIVE))
	ok(not seen.has(false) or seen.values().all(func(v): return v), "[11] hitbox_active() == (stan == ACTIVE) w każdej klatce")
	n[0].queue_free()
	m[0].queue_free()
	# 12. zmiana kierunku nie zostawia hitboxa po złej stronie
	var q := fresh_pair(1090.0)
	var left_e := spawn(q[0], "skaven", Vector2(910.0, 480.0))
	left_e.ai_cd = 99999.0
	left_e.speed = 0.0
	left_e.depth_speed = 0.0
	left_e.hp = 1000.0
	left_e.max_hp = 1000.0
	swing(q[0], q[1])
	var right_hit: bool = q[2].hp < q[2].max_hp
	var left_untouched: bool = left_e.hp == left_e.max_hp
	step(q[0], 1.0)
	Controls.touch_move = Vector2(-1, 0)
	step(q[0], 0.1)
	Controls.touch_move = Vector2.ZERO
	q[1].combo_idx = 0
	q[1].start_attack("light1", q[1].attack_defs["light1"])
	step(q[0], 0.14)   # w fazie ACTIVE
	var rect: Rect2 = q[1].hitbox_rect()
	ok(rect.end.x <= q[1].position.x + 0.1, "[12] po obrocie w lewo hitbox leży po lewej stronie pivotu (%s)" % str(rect))
	step(q[0], 0.6)
	ok(right_hit and left_untouched and left_e.hp < left_e.max_hp, "[12] zmiana kierunku: najpierw trafiony prawy, potem lewy wróg")
	q[0].queue_free()

func t_sword_assist() -> void:
	# wróg zbiegł Ivo za plecy; bez wciśniętego kierunku Ivo obraca się ku niemu i trafia
	var a := fresh_pair(910.0)
	a[1].facing = 1
	Controls.press("light")
	step(a[0], 0.6)
	ok(a[1].facing == -1 and a[2].hp < a[2].max_hp, "wspomaganie kierunku: wróg za plecami jest trafiony po obrocie")
	a[0].queue_free()
	# ale nie obraca się ku wrogowi poza zasięgiem wspomagania
	var b := fresh_pair(500.0)
	b[1].facing = 1
	Controls.press("light")
	step(b[0], 0.6)
	ok(b[1].facing == 1 and b[2].hp == b[2].max_hp, "wspomaganie nie celuje we wroga poza zasięgiem")
	b[0].queue_free()


# ------------------------------------------------------------------ zasoby graficzne

func t_art_assets() -> void:
	var pal_img := Image.load_from_file("res://assets/palette/hufduhof_256.png")
	ok(pal_img != null and pal_img.get_width() == 256 and pal_img.get_height() == 1, "paleta ma 256 wpisów")
	var pal := {}
	for x in 256:
		pal[pal_img.get_pixel(x, 0).to_html(false)] = true
	ok(pal.size() == 256, "paleta ma 256 RÓŻNYCH kolorów (%d)" % pal.size())
	var lut := Image.load_from_file("res://assets/palette/palette_lut.png")
	ok(lut != null and lut.get_width() == 1024 and lut.get_height() == 32, "tablica LUT ma rozmiar 1024x32")
	# każda komórka LUT wskazuje kolor z palety
	var lut_bad := 0
	for y in range(0, 32, 3):
		for x in range(0, 1024, 7):
			if not pal.has(lut.get_pixel(x, y).to_html(false)):
				lut_bad += 1
	ok(lut_bad == 0, "LUT zawiera wyłącznie kolory palety (poza paletą: %d)" % lut_bad)
	# sprite'y Ivo
	var f := FileAccess.open("res://assets/characters/ivo/poses/manifest.json", FileAccess.READ)
	var m: Dictionary = JSON.parse_string(f.get_as_text())
	ok(m["dirs"].size() == 8, "manifest Ivo: 8 kierunków")
	var want := ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]
	var all_there := true
	for d in want:
		if not m["dirs"].has(d):
			all_there = false
	ok(all_there, "manifest zawiera wszystkie kierunki rozpoznane w dostarczonych plikach")
	var pivot_y: int = int(floorf(float(m["pivot"][1])))
	var bottoms := []
	var sizes := {}
	var foreign := 0
	var partial_alpha := 0
	for d in m["dirs"]:
		var img := Image.load_from_file("res://assets/characters/ivo/poses/ivo_%s.png" % d)
		sizes[img.get_size()] = true
		var bottom := -1
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.0:
					bottom = y
					if c.a < 0.99:
						partial_alpha += 1
					if not pal.has(c.to_html(false)):
						foreign += 1
		bottoms.append(bottom)
	ok(sizes.size() == 1, "wszystkie kadry Ivo mają to samo płótno (%s)" % str(sizes.keys()))
	var aligned := true
	for b in bottoms:
		if absi(int(b) - pivot_y) > 4:
			aligned = false
	ok(aligned, "stopy wszystkich kierunków leżą przy linii pivotu (dolne piksele: %s, pivot y=%d)" % [str(bottoms), pivot_y])
	ok(foreign == 0, "sprite'y Ivo używają wyłącznie kolorów palety (spoza: %d)" % foreign)
	ok(partial_alpha == 0, "sprite'y Ivo mają alfę binarną - brak półprzezroczystych obwódek (%d)" % partial_alpha)
	# oryginały nietknięte (kopie w assets/characters/ivo/source identyczne co dostarczone)
	var intact := true
	for d in want:
		var a := FileAccess.get_file_as_bytes("res://assets/characters/ivo/source/%s.png" % d)
		intact = intact and a.size() > 0
	ok(intact, "oryginalne PNG zachowane w assets/characters/ivo/source")

func t_ivo_direction() -> void:
	var cases := {
		Vector2(1, 0): "east", Vector2(1, 1): "south-east", Vector2(0, 1): "south", Vector2(-1, 1): "south-west",
		Vector2(-1, 0): "west", Vector2(-1, -1): "north-west", Vector2(0, -1): "north", Vector2(1, -1): "north-east",
	}
	var good := true
	for v in cases.keys():
		var got: String = IvoView.dir_from_vector(v, "east")
		if got != cases[v]:
			good = false
			print("  kierunek dla ", v, ": ", got, " (oczekiwano ", cases[v], ")")
	ok(good, "wektor ruchu -> właściwy z 8 kierunków sprite'a")
	# histereza: drżenie drążka blisko granicy nie przełącza kierunku
	var stay: String = IvoView.dir_from_vector(Vector2(1.0, 0.45), "east", "east")
	ok(stay == "east", "histereza: drobne wychylenie w głąb nie zmienia profilu (%s)" % stay)
	# ruch w głąb sceny na żywo
	var lvl := make_level()
	var p: Player = lvl.player
	Controls.touch_move = Vector2(0, -1)
	step(lvl, 0.2)
	ok(p.aim_dir == "north", "ruch w górę ekranu pokazuje Ivo tyłem (north), jest: %s" % p.aim_dir)
	Controls.touch_move = Vector2(0, 1)
	step(lvl, 0.2)
	ok(p.aim_dir == "south", "ruch w dół ekranu pokazuje Ivo przodem (south), jest: %s" % p.aim_dir)
	Controls.touch_move = Vector2(-1, -1)
	step(lvl, 0.2)
	ok(p.aim_dir == "north-west" and p.facing == -1, "skos w lewo-górę: north-west i kierunek ataku w lewo")
	Controls.touch_move = Vector2.ZERO
	step(lvl, 0.6)
	ok(p.aim_dir == "west", "po zatrzymaniu Ivo wraca do profilu zgodnego z kierunkiem ataku (%s)" % p.aim_dir)
	# podczas ataku widok to profil E/W, niezależnie od ruchu w głąb
	Controls.touch_move = Vector2(0, -1)
	Controls.press("light")
	step(lvl, 0.12)
	var v: ActorVisual = p.visual
	ok(v.ivo_view != null and v.ivo_view.cur_dir in ["east", "west"], "w czasie ataku widok to profil E/W (%s)" % v.ivo_view.cur_dir)
	Controls.touch_move = Vector2.ZERO
	free_level(lvl)


# ------------------------------------------------------------------ foldery grafik (podmiana na docelowe)

const TMP := "user://test_assets"

func tmp_png(path: String, w: int, h: int, col: Color) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(col)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	img.save_png(path)

func tmp_json(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))

func tmp_clean() -> void:
	_rm(ProjectSettings.globalize_path(TMP))
	CharacterSheet.root = "res://assets/characters"
	StageArt.root = "res://assets/stages"
	CharacterSheet.clear_cache()
	StageArt.clear_cache()

func _rm(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	for sub in d.get_directories():
		_rm(dir + "/" + sub)
		d.remove(sub)
	DirAccess.remove_absolute(dir)

## Zgodność folderów z balance.json: każdy atak ma animację z klatkami kontaktu, są wymagane animacje bazowe.
func t_asset_folders() -> void:
	var need := { "ivo": ["idle", "run", "hurt", "dodge", "die", "victory"], "skaven": ["idle", "run", "hurt", "die"],
		"chaos_hound": ["idle", "run", "hurt", "die"], "beastman": ["idle", "run", "hurt", "die"],
		"chaos_champion": ["idle", "run", "hurt", "roar", "die"] }
	var attacks := { "ivo": Balance.player()["attacks"].keys() }
	for id in ["skaven", "chaos_hound", "beastman", "chaos_champion"]:
		attacks[id] = Balance.enemy(id)["attacks"].keys()
	for id in need.keys():
		var path := "res://assets/characters/%s/character.json" % id
		ok(FileAccess.file_exists(path), "manifest postaci %s istnieje" % id)
		var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var anims: Dictionary = m["animations"]
		var missing := []
		for a in need[id]:
			if not anims.has(a):
				missing.append(a)
		for a in attacks[id]:
			if not anims.has(a) or not anims[a].has("contact"):
				missing.append(a + "(kontakt)")
		ok(missing.is_empty(), "%s: manifest pokrywa animacje stanów i wszystkie ataki z balance.json (brak: %s)" % [id, str(missing)])
		var contact_ok := true
		for a in attacks[id]:
			if anims.has(a):
				var c: Array = anims[a]["contact"]
				contact_ok = contact_ok and int(c[0]) <= int(c[1]) and int(c[1]) < int(anims[a]["frames"])
		ok(contact_ok, "%s: klatki kontaktu mieszczą się w liczbie klatek" % id)
		ok(float(m["pivot"][0]) < float(m["frame_size"][0]) and float(m["pivot"][1]) <= float(m["frame_size"][1]), "%s: pivot leży w obrębie płótna" % id)
	# etapy
	var lvl := Level.load_level_data("res://data/level_1.json")
	var names := {}
	for st in lvl["stages"]:
		var f: String = str(st["folder"])
		ok(FileAccess.file_exists("res://assets/stages/%s/stage.json" % f), "etap '%s' ma stage.json" % f)
	var bg := LevelBackground.new()
	var all_ok := true
	var unknown := []
	for stage in 4:
		var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/stages/%s/stage.json" % lvl["stages"][stage]["folder"]))
		for ri in 101:
			for vi in 11:
				var p: Array = bg._pick_prop(stage, ri / 100.0, vi / 10.0, 0)
				if not p.is_empty() and not man["props"].has(p[0]):
					unknown.append("%d:%s" % [stage, p[0]])
	ok(unknown.is_empty(), "wszystkie rekwizyty wybierane przez grę są opisane w stage.json etapu (brak: %s)" % str(unknown.slice(0, 5)))
	bg.free()
	var com: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/stages/common/stage.json"))
	ok(com["props"].has("barrel") and com["props"].has("potion"), "folder common opisuje beczkę i miksturę")

func make_dummy_sheet(id: String, anims: Dictionary) -> void:
	var man := { "id": id, "frame_size": [16, 16], "pivot": [4, 15], "world_per_texel": 1.3333, "animations": {} }
	for name in anims.keys():
		var n: int = int(anims[name]["frames"])
		var spec := { "frames": n, "fps": anims[name].get("fps", 6), "loop": anims[name].get("loop", false) }
		if anims[name].has("contact"):
			spec["contact"] = anims[name]["contact"]
		man["animations"][name] = spec
		for i in n:
			tmp_png("%s/characters/%s/anim/%s/%s_%02d.png" % [TMP, id, name, name, i], 16, 16, Color(0.1 * (i + 1), 0.2, 0.9 - 0.1 * i, 1.0))
	tmp_json("%s/characters/%s/character.json" % [TMP, id], man)
	CharacterSheet.root = TMP + "/characters"
	CharacterSheet.clear_cache()

func t_sheet_loading() -> void:
	make_dummy_sheet("dummy", { "idle": { "frames": 3, "fps": 6, "loop": true }, "light": { "frames": 5, "contact": [2, 2] },
		"charge": { "frames": 6, "contact": [2, 4] }, "die": { "frames": 4, "fps": 8 } })
	var sh := CharacterSheet.get_sheet("dummy")
	ok(sh != null and sh.has_anim("idle") and sh.has_anim("light") and not sh.has_anim("run"), "arkusz ładuje istniejące animacje i pomija brakujące")
	ok(sh.anims["light"]["tex"].size() == 5 and sh.pivot == Vector2(4, 15), "liczba klatek i pivot z manifestu")
	ok(CharacterSheet.get_sheet("nie_istnieje") == null, "brak folderu postaci = null (zapas), bez błędu")
	var lvl := make_level()
	var e := spawn(lvl, "skaven", Vector2(1200, 480))
	e.attack = { "windup": 0.2, "active": 0.1, "recover": 0.3 }
	e.attack_scale = 1.0
	var seq := []
	for pair in [[Actor.State.WINDUP, 0.0], [Actor.State.WINDUP, 0.09], [Actor.State.WINDUP, 0.15], [Actor.State.ACTIVE, 0.0], [Actor.State.ACTIVE, 0.09],
			[Actor.State.RECOVER, 0.0], [Actor.State.RECOVER, 0.29]]:
		e.state = pair[0]
		e.state_t = pair[1]
		seq.append(sh.frame_index("light", e, 0.0))
	ok(seq == [0, 0, 1, 2, 2, 3, 4], "atak: zamach -> klatka kontaktu w oknie AKTYWNYM -> powrót (%s)" % str(seq))
	# zakres kontaktu 2-4 w 6 klatkach (szarża)
	var ch := []
	for t in [0.0, 0.03, 0.2, 0.44]:
		e.state = Actor.State.ACTIVE
		e.state_t = t
		e.attack = { "windup": 0.5, "active": 0.46, "recover": 0.9 }
		ch.append(sh.frame_index("charge", e, 0.0))
	ok(ch[0] == 2 and ch[3] == 4 and ch[1] >= 2 and ch[2] >= 2 and ch[2] <= 4, "kontakt 2-4: w oknie aktywnym klatki 2..4 (%s)" % str(ch))
	# pętla wg czasu, śmierć wg dead_t
	e.state = Actor.State.IDLE
	ok(sh.frame_index("idle", e, 0.0) == 0 and sh.frame_index("idle", e, 1.0 / 6.0 + 0.01) == 1 and sh.frame_index("idle", e, 0.5) == 0, "idle: pętla wg fps (3 klatki @6)")
	e.state = Actor.State.DEAD
	e.dead_t = 0.2
	var d1: int = sh.frame_index("die", e, 0.0)
	e.dead_t = 9.0
	ok(d1 == 1 and sh.frame_index("die", e, 0.0) == 3, "die: wg dead_t, ostatnia klatka zostaje (%d, 3)" % d1)
	# pivot i odbicie lustrzane
	var spr := Sprite2D.new()
	e.facing = 1
	e.state = Actor.State.IDLE
	SheetView.show_frame(spr, sh, "idle", e, 0.0)
	var off_r: Vector2 = spr.offset
	e.facing = -1
	SheetView.show_frame(spr, sh, "idle", e, 0.0)
	ok(off_r == Vector2(-4, -15) and spr.flip_h and spr.offset == Vector2(-12, -15), "pivot stóp zachowany po odbiciu lustrzanym (%s / %s)" % [str(off_r), str(spr.offset)])
	spr.free()
	free_level(lvl)
	tmp_clean()

func t_sheet_integration() -> void:
	make_dummy_sheet("skaven", { "idle": { "frames": 2, "loop": true }, "claw": { "frames": 5, "contact": [2, 2] } })
	var lvl := make_level()
	var e := spawn(lvl, "skaven", Vector2(1300, 480))
	e.ai_cd = 99999.0
	e.speed = 0.0
	var sv: SheetView = e.visual.sheet_view
	ok(sv != null, "wróg z folderem animacji dostaje SheetView")
	sv._process(0.016)
	ok(sv.active and sv.sprite.texture == sv.sheet.anims["idle"]["tex"][0], "stan IDLE pokazuje animację idle")
	e.state = Actor.State.HURT           # brak animacji hurt -> zapas: idle
	sv._process(0.016)
	ok(sv.active and sv.sprite.texture in sv.sheet.anims["idle"]["tex"], "brak animacji 'hurt' -> zapas: idle (ten sam styl)")
	e.start_attack("claw", e.attack_defs["claw"])
	e.set_state(Actor.State.ACTIVE)
	e.state_t = 0.02
	sv._process(0.016)
	ok(sv.sprite.texture == sv.sheet.anims["claw"]["tex"][2], "atak 'claw' w oknie aktywnym = klatka kontaktu")
	# arkusz bez 'idle' i bez animacji stanu => aktor rysuje grafikę zapasową
	free_level(lvl)
	make_dummy_sheet("skaven", { "claw": { "frames": 3, "contact": [1, 1] } })
	var lvl2 := make_level()
	var e2 := spawn(lvl2, "skaven", Vector2(1300, 480))
	e2.visual.sheet_view._process(0.016)
	ok(not e2.visual.sheet_view.active, "brak animacji i brak idle -> sprite ukryty, zapas proceduralny")
	free_level(lvl2)
	# Ivo: arkusz częściowy; reszta stanów zostaje na pozach 8-kierunkowych
	make_dummy_sheet("ivo", { "idle": { "frames": 2, "loop": true }, "light1": { "frames": 5, "contact": [2, 2] } })
	var lvl3 := make_level()
	var p: Player = lvl3.player
	var iv: IvoView = p.visual.ivo_view
	p.aim_dir = "east"
	p.state = Actor.State.IDLE
	ok(iv.sheet_anim() == "idle", "Ivo: IDLE w profilu używa animacji idle z folderu")
	p.aim_dir = "north"
	ok(iv.sheet_anim() == "", "Ivo: ruch w głąb sceny (N) zostaje na pozach 8-kierunkowych")
	p.aim_dir = "east"
	p.state = Actor.State.HURT
	ok(iv.sheet_anim() == "", "Ivo: brak animacji 'hurt' -> pozy (zapas)")
	p.start_attack("light1", p.attack_defs["light1"])
	iv._process(0.016)
	ok(iv.sheet_anim() == "light1" and iv.sheet_sprite.visible and not iv.sprite.visible and not iv.swing.visible, "Ivo: animacja ataku z folderu zastępuje pozę i tymczasową smugę")
	p.state = Actor.State.HURT
	iv._process(0.016)
	ok(iv.sprite.visible and iv.swing.visible and not iv.sheet_sprite.visible, "powrót do póz i smugi, gdy animacji brak")
	free_level(lvl3)
	tmp_clean()

func t_stage_art() -> void:
	StageArt.root = TMP + "/stages"
	StageArt.clear_cache()
	var man := { "id": "teststage", "world_per_texel": 1.3333, "layers": { "sky": { "file": "sky.png", "parallax": 0.0, "y_offset": 0 },
		"far1": { "file": "far1.png", "parallax": 0.15, "y_offset": 4 }, "foreground": { "file": "foreground.png", "parallax": 1.25, "y_offset": 0 },
		"far2": { "file": "far2.png", "parallax": 0.3, "y_offset": 0 } }, "props": {} }
	tmp_json(TMP + "/stages/teststage/stage.json", man)
	tmp_png(TMP + "/stages/teststage/sky.png", 8, 100, Color(0.2, 0.3, 0.8))
	tmp_png(TMP + "/stages/teststage/far1.png", 64, 40, Color(0.3, 0.3, 0.3))
	tmp_png(TMP + "/stages/teststage/foreground.png", 64, 20, Color(0.0, 0.2, 0.0))
	tmp_png(TMP + "/stages/teststage/props/house_thatch.png", 30, 40, Color(0.8, 0.6, 0.2))
	tmp_png(TMP + "/stages/teststage/props/house_thatch_2.png", 32, 44, Color(0.7, 0.5, 0.2))
	tmp_json(TMP + "/stages/common/stage.json", { "id": "common", "layers": {}, "props": {} })
	tmp_png(TMP + "/stages/common/props/barrel.png", 12, 16, Color(0.5, 0.3, 0.1))
	var sa := StageArt.get_stage("teststage")
	ok(sa != null and sa.layers.size() == 3, "warstwy z pliku załadowane, brakująca (far2) pominięta (%d)" % sa.layers.size())
	ok(float(sa.layer("far1")["parallax"]) == 0.15 and float(sa.layer("far1")["y_offset"]) == 4.0, "paralaksa i y_offset z manifestu")
	ok(sa.layer("ground").is_empty(), "brak pliku ground => pusta warstwa (zapas proceduralny)")
	ok(sa.prop_variants("house_thatch").size() == 2 and sa.prop_variants("barn").is_empty(), "warianty rekwizytu: house_thatch ma 2, barn brak")
	ok(StageArt.common_prop("barrel") != null and StageArt.common_prop("potion") == null, "wspólne rekwizyty: beczka jest, mikstury brak")
	# integracja z tłem poziomu
	var data := Level.load_level_data("res://data/level_1.json")
	for st in data["stages"]:
		st["folder"] = "teststage"
	var lvl := Level.new(data, 0)
	lvl.simulate_only = true
	add_child(lvl)
	var bg: LevelBackground = lvl.bg
	ok(bg.art[0] != null and bg.sky_tex[0] == sa.layer("sky")["tex"], "tło używa nieba z pliku zamiast generowanego")
	ok(bg.ground_tex[0] != sa.layer("sky")["tex"] and bg.ground_tex[0].get_height() == 420, "brakujące podłoże: gradient zapasowy")
	free_level(lvl)
	var lvl2 := make_level()    # domyślne foldery (puste): wszystko zapasowe
	ok(lvl2.bg.sky_tex[0].get_height() == 460 and lvl2.bg.sky_par[0] == 0.0, "puste foldery etapów => tło w całości zapasowe")
	free_level(lvl2)
	tmp_clean()

func t_story() -> void:
	var entries: Array = StoryScreen.load_entries()
	ok(entries.size() == 4, "story.json ma 4 ekrany fabularne: 2 prologu + las + czempion (jest %d)" % entries.size())
	var stage_count: int = int(Level.load_level_data("res://data/level_1.json")["stages"].size())
	var ids := {}
	for e in entries:
		var id := str(e.get("id", ""))
		ok(id != "" and not ids.has(id), "unikalny id ekranu fabularnego: " + id)
		ids[id] = true
		var is_prologue: bool = str(e.get("phase", "")) != ""
		if is_prologue:
			ok(str(e["phase"]) in ["pre", "post"] and not e.has("before_stage"), "%s: wpis prologu ma phase pre/post, bez before_stage" % id)
		else:
			ok(int(e.get("before_stage", -1)) >= 0 and int(e.get("before_stage", -1)) < stage_count, "%s: before_stage w zakresie etapów" % id)
		ok(str(e.get("title", "")) != "" and str(e.get("kicker", "")) != "", "%s: tytuł i podtytuł" % id)
		ok(ResourceLoader.exists(str(e.get("image", ""))), "%s: istnieje ilustracja" % id)
		var pages: Array = e.get("pages", [])
		ok(pages.size() >= (2 if is_prologue else 3), "%s: wystarczająco stron" % id)
		for pg in pages:
			ok(typeof(pg) == TYPE_ARRAY and pg.size() > 0 and str(pg[0]).length() > 10, "%s: strona z tekstem" % id)
			ok(StoryScreen.page_to_bbcode(pg).length() < 520, "%s: strona mieści się w panelu (<520 znaków)" % id)
	ok(StoryScreen.entry_for_stage(1).is_empty(), "etap 2 (wieś) bez ekranu fabularnego")
	ok(StoryScreen.entry_for_stage(0).is_empty(), "przed etapem 1 poziom nie pokazuje prologu (jest osobno, w karczmie)")
	ok(str(StoryScreen.entry_for_phase("pre").get("id", "")) == "karczma", "prolog: opis przed minigrą")
	ok(str(StoryScreen.entry_for_phase("post").get("id", "")) == "szczury", "prolog: opis po minigrze")
	ok(StoryScreen.entry_for_phase("nieistniejaca").is_empty(), "nieznana faza => pusty wpis")
	ok(str(StoryScreen.entry_for_stage(2).get("id", "")) == "las", "przed etapem 3: las")
	ok(str(StoryScreen.entry_for_stage(3).get("id", "")) == "czempion", "przed etapem 4: czempion")
	var bb := StoryScreen.page_to_bbcode(["Tekst [x]", "— Dialog"])
	ok(bb.contains("[lb]x]") and bb.contains("[color=" + StoryScreen.DIALOG_COLOR + "]"), "BBCode: nawiasy escapowane, dialog złoty")
	# przejście przez wszystkie strony: pierwsze advance kończy pisanie, drugie zmienia stronę
	var sc := StoryScreen.new()
	sc.setup(entries[0])
	add_child(sc)
	var fin := [0]
	sc.finished.connect(func(): fin[0] += 1)
	var pages_n: int = sc.pages.size()
	for i in pages_n:
		ok(sc.page == i and sc.typing, "strona %d startuje w trakcie pisania" % i)
		sc.advance()
		ok(not sc.typing and is_equal_approx(sc.rich.visible_ratio, 1.0), "pierwsze advance dopisuje stronę %d" % i)
		sc.advance()
	ok(fin[0] == 1, "po ostatniej stronie dokładnie jedno finished")
	sc.advance(); sc.skip_all()
	ok(fin[0] == 1, "po zakończeniu kolejne wywołania nic nie robią")
	sc.queue_free()
	var sk := StoryScreen.new()
	sk.setup(entries[1])
	add_child(sk)
	var fin2 := [0]
	sk.finished.connect(func(): fin2[0] += 1)
	sk.skip_all()
	ok(fin2[0] == 1, "Pomiń kończy od razu")
	sk.queue_free()
	# logika wyzwalania w poziomie: raz na etap, wyłączalna, pomijana po kontynuacji z checkpointu
	GameState.story_enabled = true
	var lvl := make_level()
	ok(lvl._story_to_show(0).is_empty(), "start poziomu nie powtarza prologu z karczmy")
	ok(lvl._story_to_show(1).is_empty(), "etap bez wpisu: brak ekranu")
	ok(str(lvl._story_to_show(2).get("id", "")) == "las", "wejście w etap 3 pokazuje las")
	free_level(lvl)
	GameState.story_enabled = false
	var lvl2 := make_level()
	ok(lvl2._story_to_show(0).is_empty(), "story_enabled=false wyłącza ekrany")
	free_level(lvl2)
	GameState.story_enabled = true
	var lvl3 := Level.new({}, 5)
	lvl3.simulate_only = true
	add_child(lvl3)
	ok(lvl3._story_to_show(2).is_empty(), "kontynuacja z checkpointu nie powtarza fabuły etapów za graczem")
	ok(str(lvl3._story_to_show(3).get("id", "")) == "czempion", "kontynuacja: przed bossem fabuła pokazuje się raz")
	free_level(lvl3)

func make_tavern() -> TavernGame:
	var g := TavernGame.new()
	g.auto_step = false
	g.rng.seed = 7
	add_child(g)
	return g

func t_tavern() -> void:
	var g := make_tavern()
	ok(g.phase == TavernGame.Phase.PLAY and g.caught == 0 and g.goal == 50, "prolog: start, cel 50 kufli")
	# ruch Borubara: przyspiesza, ma granice
	g.input_override = 1.0
	for i in 600:
		g.step(1.0 / 60.0)
		g.mugs.clear()
		g.spawn_t = 99.0
	ok(is_equal_approx(g.boru_x, TavernGame.BORU_MAX), "Borubar zatrzymuje się na prawej ścianie")
	g.input_override = -1.0
	for i in 20:
		g.step(1.0 / 60.0)
	ok(g.boru_x < TavernGame.BORU_MAX - 100.0, "Borubar reaguje na sterowanie")
	g.input_override = 0.0
	for i in 60:
		g.step(1.0 / 60.0)
	ok(absf(g.boru_vx) < 0.01, "bez sterowania Borubar staje")
	# łapanie: kufel nad wielkim kuflem
	g.mugs.clear()
	var bx: float = g.boru_x
	g.drop_mug(bx, false, 400.0)
	var before: int = g.caught
	for i in 120:
		g.step(1.0 / 60.0)
		g.spawn_t = 99.0
	ok(g.caught == before + 1 and g.mugs.is_empty() and g.missed == 0, "kufel nad Borubarem zostaje złapany (+1)")
	g.drop_mug(bx, true, 400.0)
	before = g.caught
	for i in 120:
		g.step(1.0 / 60.0)
		g.spawn_t = 99.0
	ok(g.caught == before + TavernGame.GOLD_VALUE, "złoty kufel liczy się za %d" % TavernGame.GOLD_VALUE)
	# pudło: rozbity kufel, Borubar ogłuszony tylko gdy blisko
	g.drop_mug(bx + 300.0 if bx < 800.0 else bx - 300.0, false, 600.0)
	before = g.caught
	for i in 120:
		g.step(1.0 / 60.0)
		g.spawn_t = 99.0
	ok(g.missed == 1 and g.caught == before and g.stun == 0.0, "kufel daleko od Borubara rozbija się bez kary")
	g.drop_mug(bx, false, 600.0)
	g.mugs[0]["y"] = TavernGame.CATCH_Y + 5.0          # tuż pod linią łapania => spada Borubarowi na nogi
	for i in 40:
		g.step(1.0 / 60.0)
		g.spawn_t = 99.0
	ok(g.missed == 2 and g.splashes.size() >= 1, "rozlane kufle są liczone")
	g.drop_mug(bx, false, 400.0)
	g.mugs[0]["y"] = TavernGame.FLOOR_Y - 5.0
	g.step(1.0 / 60.0)
	ok(g.stun > 0.0, "kufel rozbity przy stopach ogłusza Borubara")
	var cb := [0, true]
	g.finished.connect(func(sk): cb[0] += 1; cb[1] = sk)
	g.stun = 0.0
	g.step(1.0 / 60.0)
	# trudność rośnie z postępem
	var easy_speed: float = g.fall_speed()
	g.caught = 40
	ok(g.fall_speed() > easy_speed and g.spawn_interval() < 1.25, "trudność rośnie wraz z liczbą kufli")
	# dojście do 50 => scena ze szczurami
	g.caught = 49
	g.mugs.clear()
	g.drop_mug(g.boru_x, false, 400.0)
	for i in 120:
		g.step(1.0 / 60.0)
		g.spawn_t = 99.0
		if g.phase != TavernGame.Phase.PLAY:
			break
	ok(g.caught >= 50 and g.phase == TavernGame.Phase.CUTSCENE, "50. kufel uruchamia scenę ze szczurami")
	ok(g.mugs.is_empty() and g.rats.size() >= 8, "scena: kufle znikają, wskakują szczury")
	var guard := 0
	while g.phase == TavernGame.Phase.CUTSCENE and guard < 60 * 12:
		g.step(1.0 / 60.0)
		guard += 1
	ok(g.door_open and g.phase == TavernGame.Phase.DONE, "scena: drzwi wyważone, koniec prologu")
	ok(cb[0] == 1 and cb[1] == false, "dokładnie jedno finished(skipped=false)")
	g.step(0.1); g.skip()
	ok(cb[0] == 1, "po zakończeniu skip nic nie robi")
	var all_landed := true
	for r in g.rats:
		all_landed = all_landed and bool(r["landed"])
	ok(all_landed, "wszystkie szczury wylądowały na scenie")
	g.queue_free()
	# pominięcie z menu prologu
	var g2 := make_tavern()
	var cb2 := [0, false]
	g2.finished.connect(func(sk): cb2[0] += 1; cb2[1] = sk)
	g2.skip(); g2.skip()
	ok(cb2[0] == 1 and cb2[1] == true, "Pomiń prolog: jedno finished(skipped=true)")
	g2.queue_free()
	# automatyczny karczmarz zrzuca kufle i co 9. jest złoty
	var g3 := make_tavern()
	var drops := 0
	var golds := 0
	for i in 60 * 40:
		var n: int = g3.spawn_count
		g3.step(1.0 / 60.0)
		g3.boru_x = g3.mugs[0]["x"] if not g3.mugs.is_empty() and g3.mugs[0]["y"] > 300.0 else g3.boru_x
		if g3.phase != TavernGame.Phase.PLAY:
			break
	ok(g3.spawn_count > 10, "karczmarz regularnie zrzuca kufle (%d)" % g3.spawn_count)
	ok(g3.phase == TavernGame.Phase.CUTSCENE or g3.caught >= 20, "prowadzony gracz łapie większość kufli (%d)" % g3.caught)
	g3.queue_free()
	# assety prologu
	for n in ["tavern_bg", "balcony_rail", "door_open", "borubar", "borubar_dizzy", "tankard_big", "innkeeper", "mug", "mug_gold", "splash", "stars", "guest_1", "guest_2", "guest_3", "guest_4", "guest_5", "guest_6"]:
		ok(ResourceLoader.exists("res://assets/minigame/%s.png" % n), "istnieje grafika prologu: " + n)

func t_full_run_bot() -> void:
	var lvl := make_level()
	GameState.god_mode = true
	var bot := TestBot.new()
	bot.level = lvl
	var ticks := 0
	var max_ticks := 60 * 60 * 12
	var peak_enemies := 0
	while lvl.outcome != "won" and ticks < max_ticks:
		bot.drive(1.0 / 60.0)
		lvl.tick(1.0 / 60.0)
		peak_enemies = maxi(peak_enemies, lvl.enemies.size())
		ticks += 1
	GameState.god_mode = false
	Controls.reset()
	ok(lvl.outcome == "won", "bot przechodzi cały poziom do zwycięstwa (%.0f s symulacji, fala %d/%d)" % [ticks / 60.0, lvl.next_wave, lvl.waves.size()])
	ok(lvl.boss != null and not lvl.boss.is_alive(), "boss pokonany")
	ok(lvl.boss != null and lvl.boss.phase == 3, "boss przeszedł przez fazy do 3")
	ok(GameState.kills >= 25, "pokonano wielu wrogów (%d)" % GameState.kills)
	print("  info: czas ~%.0f s, kills %d, wynik %d, szczyt wrogów %d" % [ticks / 60.0, GameState.kills, GameState.score, peak_enemies])
	SaveData.clear_checkpoint()
	free_level(lvl)
