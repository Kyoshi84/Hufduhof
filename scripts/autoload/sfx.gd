extends Node
## Warstwa audio. Brak plików => tymczasowe dźwięki syntezowane w kodzie.
## Aby podmienić dźwięk, wrzuć plik assets/audio/sfx/<nazwa>.ogg|wav|mp3. Kod gry nie wymaga zmian.
## Muzyka: utwory i ich głośność opisuje data/music.json (menu, etapy 1-4, boss).
## Prolog (Etap 0) celowo gra bez muzyki.

const RATE := 22050
const SFX_NAMES := [
	"swing", "swing_heavy", "hit", "hit_heavy", "skaven_squeak", "hound_bark", "beast_roar",
	"boss_attack", "boss_roar", "slam", "player_hurt", "player_die", "enemy_die", "pickup",
	"barrel_break", "ui_click", "ui_back", "victory", "defeat",
]

var streams: Dictionary = {}
var _pool: Array = []
var _music: AudioStreamPlayer
var _last_play: Dictionary = {}
var music_cfg: Dictionary = {}
var current_track: String = ""
var _fade: Tween
const MUSIC_CFG := "res://data/music.json"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i in 14:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	music_cfg = load_music_cfg()
	for n in SFX_NAMES:
		streams[n] = _load_override("sfx", n)
		if streams[n] == null:
			streams[n] = _synth_sfx(n)
	apply_volumes()

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func apply_volumes() -> void:
	_set_bus("Music", SaveData.music_volume)
	_set_bus("SFX", SaveData.sfx_volume)

func _set_bus(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))

func play(sfx_name: String, pitch: float = 1.0) -> void:
	var s = streams.get(sfx_name)
	if s == null:
		return
	# ogranicznik: ten sam dźwięk nie częściej niż co 40 ms (ochrona przy dużej liczbie wrogów)
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(sfx_name, -1000)) < 40:
		return
	_last_play[sfx_name] = now
	for p in _pool:
		if not p.playing:
			p.stream = s
			p.pitch_scale = pitch * randf_range(0.95, 1.05)
			p.play()
			return

static func load_music_cfg() -> Dictionary:
	if not FileAccess.file_exists(MUSIC_CFG):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(MUSIC_CFG))
	return d if d is Dictionary else {}

## Zgodność wstecz: muzyka etapów.
func play_music() -> void:
	play_track("stage")

## Włącza utwór z data/music.json ("menu", "stage", "boss") z płynnym przejściem.
## Ten sam utwór, który już gra, nie jest restartowany.
func play_track(track: String) -> void:
	if current_track == track and _music.playing:
		return
	var tracks: Dictionary = music_cfg.get("tracks", {})
	var info: Dictionary = tracks.get(track, {})
	var m = null
	var f := str(info.get("file", ""))
	if f != "" and ResourceLoader.exists(f):
		m = load(f)
	if m == null:
		m = _load_override("music", "battle")
	if m == null:
		m = _synth_music()
	if m is AudioStreamOggVorbis:
		m.loop = true
	current_track = track
	var target_db := float(info.get("volume_db", 0.0))
	var fade_in := float(music_cfg.get("fade_in", 0.6))
	if _fade != null:
		_fade.kill()
	_music.stream = m
	_music.volume_db = -40.0 if fade_in > 0.0 else target_db
	_music.play()
	if fade_in > 0.0 and is_inside_tree():
		_fade = create_tween()
		_fade.tween_property(_music, "volume_db", target_db, fade_in)

func stop_music(fade_out: float = 0.0) -> void:
	current_track = ""
	if _fade != null:
		_fade.kill()
		_fade = null
	if fade_out > 0.0 and _music.playing and is_inside_tree():
		_fade = create_tween()
		_fade.tween_property(_music, "volume_db", -40.0, fade_out)
		_fade.tween_callback(_music.stop)
	else:
		_music.stop()

func is_music_playing() -> bool:
	return _music.playing and current_track != ""

func _load_override(folder: String, file: String):
	for ext in ["ogg", "wav", "mp3"]:
		var p := "res://assets/audio/%s/%s.%s" % [folder, file, ext]
		if ResourceLoader.exists(p):
			return load(p)
	return null

# ---------------------------------------------------------------- synteza

func _make_wav(samples: PackedFloat32Array, rate: int, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w

func _synth_sfx(n: String) -> AudioStreamWAV:
	var dur := 0.25
	match n:
		"swing": dur = 0.18
		"swing_heavy": dur = 0.30
		"hit": dur = 0.14
		"hit_heavy": dur = 0.26
		"skaven_squeak": dur = 0.16
		"hound_bark": dur = 0.22
		"beast_roar": dur = 0.45
		"boss_attack": dur = 0.50
		"boss_roar": dur = 0.90
		"slam": dur = 0.55
		"player_hurt": dur = 0.22
		"player_die": dur = 0.70
		"enemy_die": dur = 0.30
		"pickup": dur = 0.22
		"barrel_break": dur = 0.30
		"ui_click": dur = 0.07
		"ui_back": dur = 0.09
		"victory": dur = 1.4
		"defeat": dur = 1.2
	var count := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		var k := t / dur                 # 0..1
		var env := pow(1.0 - k, 2.0)
		var s := 0.0
		var noise := randf_range(-1.0, 1.0)
		match n:
			"swing", "swing_heavy":
				var band := 0.5 + 0.5 * sin(k * PI)
				s = noise * band * (1.0 - k) * (0.5 if n == "swing" else 0.8)
			"hit", "hit_heavy":
				var f := (140.0 if n == "hit" else 80.0) * (1.0 - 0.6 * k)
				phase += TAU * f / RATE
				s = (sin(phase) * 0.8 + noise * 0.5) * env
			"skaven_squeak":
				var f := 1500.0 + 900.0 * sin(k * 18.0)
				phase += TAU * f / RATE
				s = sin(phase) * env * 0.5
			"hound_bark":
				var f := 260.0 - 140.0 * k
				phase += TAU * f / RATE
				s = (signf(sin(phase)) * 0.35 + noise * 0.2) * env
			"beast_roar":
				var f := 95.0 + 25.0 * sin(k * 30.0)
				phase += TAU * f / RATE
				s = (fposmod(phase, TAU) / PI - 1.0) * 0.5 * (1.0 - k * k) + noise * 0.15
			"boss_attack":
				var f := 60.0 + 80.0 * k
				phase += TAU * f / RATE
				s = (sin(phase) * 0.7 + noise * 0.25 * (1.0 - k)) * (1.0 - k)
			"boss_roar":
				var f := 55.0 + 18.0 * sin(k * 40.0)
				phase += TAU * f / RATE
				s = (signf(sin(phase)) * 0.4 + noise * 0.25) * sin(k * PI)
			"slam":
				var f := 45.0 * (1.0 - 0.5 * k)
				phase += TAU * f / RATE
				s = (sin(phase) * 0.9 + noise * 0.4 * env) * env
			"player_hurt":
				var f := 330.0 - 150.0 * k
				phase += TAU * f / RATE
				s = (sin(phase) * 0.5 + noise * 0.2) * env
			"player_die":
				var f := 220.0 * (1.0 - 0.7 * k)
				phase += TAU * f / RATE
				s = (signf(sin(phase)) * 0.3 + noise * 0.1) * (1.0 - k)
			"enemy_die":
				var f := 500.0 * (1.0 - 0.8 * k)
				phase += TAU * f / RATE
				s = (sin(phase) * 0.5 + noise * 0.25) * env
			"pickup":
				var f := 660.0 + 660.0 * k
				phase += TAU * f / RATE
				s = sin(phase) * env * 0.5
			"barrel_break":
				s = noise * env * 0.8
			"ui_click":
				phase += TAU * 880.0 / RATE
				s = sin(phase) * env * 0.4
			"ui_back":
				phase += TAU * 440.0 / RATE
				s = sin(phase) * env * 0.4
			"victory":
				var notes := [220.0, 261.6, 329.6, 440.0]
				var f2: float = notes[mini(int(k * 4.0), 3)]
				phase += TAU * f2 / RATE
				s = (sin(phase) + 0.3 * sin(phase * 2.0)) * 0.35 * (1.0 - k * 0.6)
			"defeat":
				var notes2 := [220.0, 207.7, 196.0, 164.8]
				var f3: float = notes2[mini(int(k * 4.0), 3)]
				phase += TAU * f3 / RATE
				s = signf(sin(phase)) * 0.2 * (1.0 - k * 0.6)
		out[i] = s
	return _make_wav(out, RATE)

## Ponura pętla ~8 s: burdon + powolny motyw w molowej skali + uderzenia.
func _synth_music() -> AudioStreamWAV:
	var rate := 11025
	var dur := 8.0
	var count := int(dur * rate)
	var out := PackedFloat32Array()
	out.resize(count)
	var melody := [110.0, 0.0, 130.8, 0.0, 123.5, 110.0, 0.0, 98.0]   # A moll
	var ph1 := 0.0
	var ph2 := 0.0
	var ph3 := 0.0
	for i in count:
		var t := float(i) / rate
		var beat := fmod(t, 1.0)
		var drone := sin(ph1) * 0.18 + sin(ph2) * 0.10
		ph1 += TAU * 55.0 / rate
		ph2 += TAU * 82.4 * (1.0 + 0.004 * sin(t * 0.8)) / rate
		var hit := sin(TAU * 48.0 * beat) * exp(-beat * 9.0) * 0.5 if fmod(t, 2.0) < 1.0 else 0.0
		var mf: float = melody[int(t) % melody.size()]
		var m := 0.0
		if mf > 0.0:
			ph3 += TAU * mf * 2.0 / rate
			m = signf(sin(ph3)) * 0.06 * exp(-beat * 2.5)
		out[i] = (drone + hit + m) * 0.9
	return _make_wav(out, rate, true)
