extends Node
## Muzyka (data/music.json) i efekty dźwiękowe.
## Efekt: jeśli istnieje plik assets/audio/sfx/<nazwa>.ogg|wav|mp3 - gra go; w przeciwnym razie dźwięk
## tymczasowy syntezowany w kodzie (szum/ton). Podmiana pliku nie wymaga zmian w kodzie.

const RATE := 22050
const SFX := ["swing", "swing_heavy", "hit", "miss", "hurt", "skaven_die", "skaven_alert", "stone", "warp", "bolt",
	"lightning", "fire", "pickup", "coin", "potion", "chest", "splash", "fill", "shrine", "levelup", "ui_click",
	"door", "mug_catch", "mug_break", "death", "no_mana"]

var streams: Dictionary = {}
var _pool: Array = []
var _music: AudioStreamPlayer
var _last: Dictionary = {}
var current_track: String = ""
var _tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	for n in SFX:
		streams[n] = _load_override(n)
		if streams[n] == null:
			streams[n] = _synth(n)
	apply_volumes()

func apply_volumes() -> void:
	_set_bus("Music", Save.music_volume)
	_set_bus("SFX", Save.sfx_volume)

func _set_bus(bus: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))

func play(name_: String, pitch: float = 1.0) -> void:
	var s = streams.get(name_)
	if s == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(name_, -1000)) < 45:
		return
	_last[name_] = now
	for p in _pool:
		if not p.playing:
			p.stream = s
			p.pitch_scale = pitch * randf_range(0.94, 1.06)
			p.play()
			return

func play_track(id: String) -> void:
	if id == current_track and _music.playing:
		return
	var cfg: Dictionary = Data.music.get("tracks", {}).get(id, {})
	var path: String = str(cfg.get("file", ""))
	if path == "" or not ResourceLoader.exists(path):
		stop_music()
		return
	var st = load(path)
	if st is AudioStreamOggVorbis:
		st.loop = true
	elif st is AudioStreamMP3:
		st.loop = true
	current_track = id
	_music.stream = st
	var target: float = float(cfg.get("volume_db", 0.0))
	_music.volume_db = -30.0
	_music.play()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_music, "volume_db", target, float(Data.music.get("fade_in", 0.8)))

func stop_music(fade: float = 0.6) -> void:
	current_track = ""
	if _tween:
		_tween.kill()
	if not _music.playing:
		return
	_tween = create_tween()
	_tween.tween_property(_music, "volume_db", -40.0, fade)
	_tween.tween_callback(_music.stop)

func _load_override(n: String):
	for ext in ["ogg", "wav", "mp3"]:
		var p := "res://assets/audio/sfx/%s.%s" % [n, ext]
		if ResourceLoader.exists(p):
			return load(p)
	return null

# ---------------------------------------------------------------- synteza dźwięków tymczasowych
func _synth(n: String) -> AudioStreamWAV:
	var r := RandomNumberGenerator.new()
	r.seed = hash(n)
	var spec := {
		"swing": [0.22, "noise_sweep", 900.0, 200.0, 0.5],
		"swing_heavy": [0.32, "noise_sweep", 600.0, 120.0, 0.6],
		"hit": [0.14, "thud", 120.0, 60.0, 0.8],
		"miss": [0.12, "noise_sweep", 1600.0, 800.0, 0.25],
		"hurt": [0.2, "thud", 200.0, 90.0, 0.7],
		"skaven_die": [0.35, "squeak", 1400.0, 500.0, 0.5],
		"skaven_alert": [0.25, "squeak", 900.0, 1600.0, 0.35],
		"stone": [0.12, "thud", 300.0, 200.0, 0.4],
		"warp": [0.45, "tone", 220.0, 110.0, 0.35],
		"bolt": [0.25, "tone", 700.0, 1200.0, 0.3],
		"lightning": [0.5, "noise", 0.0, 0.0, 0.7],
		"fire": [0.4, "noise", 0.0, 0.0, 0.35],
		"pickup": [0.12, "tone", 660.0, 990.0, 0.3],
		"coin": [0.15, "tone", 1320.0, 1760.0, 0.25],
		"potion": [0.3, "tone", 300.0, 500.0, 0.3],
		"chest": [0.3, "thud", 160.0, 90.0, 0.6],
		"splash": [0.35, "noise_sweep", 2000.0, 300.0, 0.5],
		"fill": [0.4, "tone", 200.0, 600.0, 0.3],
		"shrine": [0.8, "tone", 523.0, 784.0, 0.35],
		"levelup": [0.7, "tone", 440.0, 880.0, 0.35],
		"ui_click": [0.05, "tone", 900.0, 900.0, 0.2],
		"door": [0.5, "thud", 90.0, 50.0, 0.9],
		"mug_catch": [0.12, "tone", 880.0, 1100.0, 0.3],
		"mug_break": [0.25, "noise_sweep", 3000.0, 1500.0, 0.4],
		"death": [0.9, "tone", 200.0, 60.0, 0.4],
		"no_mana": [0.12, "tone", 180.0, 140.0, 0.25],
	}
	var p: Array = spec.get(n, [0.1, "tone", 440.0, 440.0, 0.2])
	var dur: float = p[0]
	var kind: String = p[1]
	var f0: float = p[2]
	var f1: float = p[3]
	var vol: float = p[4]
	var count := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var lp := 0.0
	for i in count:
		var t := float(i) / count
		var env := (1.0 - t) * (1.0 - t) * minf(1.0, t * 40.0)
		var f := lerpf(f0, f1, t)
		var s := 0.0
		match kind:
			"tone":
				phase += f / RATE
				s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
				s *= 0.6
			"squeak":
				phase += (f + sin(t * 60.0) * 200.0) / RATE
				s = sin(phase * TAU)
			"thud":
				phase += f / RATE
				s = sin(phase * TAU) + r.randf_range(-0.3, 0.3)
			"noise":
				s = r.randf_range(-1.0, 1.0)
			"noise_sweep":
				var k := clampf(f / 4000.0, 0.02, 0.9)
				lp += (r.randf_range(-1.0, 1.0) - lp) * k
				s = lp * 2.0
		var v := int(clampf(s * env * vol, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w
