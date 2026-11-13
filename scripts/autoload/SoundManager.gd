extends Node
## Autoload "SoundManager": prozeduraler Audio-Synthesizer ohne externe Dateien.
## Jeder Sound wird per Code aus Sinus-/Rechteck-/Saegezahn-Oszillatoren, gefiltertem Rauschen,
## Huellkurven und Echo berechnet und ueber AudioStreamGenerator-Stimmen abgespielt.
## Dynamik: Staerke-Varianten (z.B. Abschlag je nach Kraft), Tonhoehe und Lautstaerke pro Wiedergabe,
## dazu ein stufenloses Windrauschen (set_wind) fuer hohe Spruenge.

const RATE := 22050.0
const VOICE_COUNT := 10
const VOICE_BUFFER := 2.8          # Sekunden Puffer je Stimme
const WIND_LOOP_SECONDS := 2.0

## Alle Sounds: Name -> Anzahl Staerke-Varianten.
const SOUNDS := {
	"hit": 4, "bounce_wood": 3, "bounce_stone": 3, "bounce_metal": 3,
	"splash_water": 1, "splash_lava": 1, "holed": 1, "fanfare": 1, "bass": 1, "thunder": 1,
	"click": 1, "tab": 1, "chest_open": 1, "coin": 1, "gem": 1, "boost": 1, "teleport": 1,
	"laser": 1, "cannon": 1, "pop": 1, "error": 1, "beep": 1, "go": 1, "style": 1,
	"upgrade": 1, "whoosh": 1, "win": 1, "lose": 1, "card": 1, "firework": 1, "blackhole": 1,
}
## Grundlautstaerke je Sound (linear).
const GAINS := {
	"hit": 0.9, "bounce_wood": 0.7, "bounce_stone": 0.7, "bounce_metal": 0.6, "splash_water": 0.8,
	"splash_lava": 0.85, "holed": 0.8, "fanfare": 0.85, "bass": 1.0, "thunder": 0.95, "click": 0.5,
	"tab": 0.4, "chest_open": 0.8, "coin": 0.55, "gem": 0.55, "boost": 0.7, "teleport": 0.7,
	"laser": 0.6, "cannon": 0.95, "pop": 0.6, "error": 0.5, "beep": 0.5, "go": 0.6, "style": 0.6,
	"upgrade": 0.75, "whoosh": 0.5, "win": 0.8, "lose": 0.7, "card": 0.45, "firework": 0.8, "blackhole": 0.9,
}
const MIN_INTERVAL_MS := {"bounce_wood": 50, "bounce_stone": 50, "bounce_metal": 60, "click": 30, "coin": 40, "card": 40}

var volume: float = 0.8
var _players: Array[AudioStreamPlayer] = []
var _playbacks: Array = []
var _busy_until: PackedFloat64Array = PackedFloat64Array()
var _cache: Dictionary = {}
var _mutex := Mutex.new()
var _last_play: Dictionary = {}
var _task_id: int = -1
var _wind_player: AudioStreamPlayer
var _wind_playback: AudioStreamGeneratorPlayback
var _wind_loop: PackedVector2Array = PackedVector2Array()
var _wind_pos: int = 0
var _wind_level: float = 0.0
var _wind_target: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICE_COUNT:
		var p := AudioStreamPlayer.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = RATE
		gen.buffer_length = VOICE_BUFFER
		p.stream = gen
		p.bus = "Master"
		add_child(p)
		p.play()
		_players.append(p)
		_playbacks.append(p.get_stream_playback())
		_busy_until.append(0.0)
	_wind_player = AudioStreamPlayer.new()
	var wgen := AudioStreamGenerator.new()
	wgen.mix_rate = RATE
	wgen.buffer_length = 0.35
	_wind_player.stream = wgen
	_wind_player.volume_db = -80.0
	add_child(_wind_player)
	_wind_player.play()
	_wind_playback = _wind_player.get_stream_playback() as AudioStreamGeneratorPlayback
	_apply_settings()
	GameManager.settings_changed.connect(_apply_settings)
	# Alle Sounds im Hintergrund vorberechnen, damit beim ersten Abspielen nichts ruckelt.
	_task_id = WorkerThreadPool.add_task(_prewarm)

func _exit_tree() -> void:
	if _task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1

func _apply_settings() -> void:
	volume = clampf(float(GameManager.setting("sfx", 0.8)), 0.0, 1.0)

func _prewarm() -> void:
	for sound_name in SOUNDS.keys():
		for variant in int(SOUNDS[sound_name]):
			_get_buffer(str(sound_name), variant)
	var loop := _synth_wind_loop()
	_mutex.lock()
	_wind_loop = loop
	_mutex.unlock()

# ================================================================ Wiedergabe

## Spielt einen Sound. strength 0..1 waehlt die Staerke-Variante (z.B. Schlagkraft) und skaliert die Lautstaerke.
func play(sound_name: String, strength: float = 1.0, pitch: float = 1.0, gain: float = 1.0) -> void:
	if volume <= 0.001 or not SOUNDS.has(sound_name):
		return
	var now_ms: int = Time.get_ticks_msec()
	if MIN_INTERVAL_MS.has(sound_name):
		if now_ms - int(_last_play.get(sound_name, -100000)) < int(MIN_INTERVAL_MS[sound_name]):
			return
	_last_play[sound_name] = now_ms
	var variants: int = int(SOUNDS[sound_name])
	var s: float = clampf(strength, 0.0, 1.0)
	var variant: int = clampi(int(floor(s * float(variants))), 0, variants - 1)
	var frames: PackedVector2Array = _get_buffer(sound_name, variant)
	if frames.is_empty():
		return
	var now: float = float(now_ms) / 1000.0
	var voice := -1
	var oldest := 0
	for i in VOICE_COUNT:
		if _busy_until[i] <= now:
			voice = i
			break
		if _busy_until[i] < _busy_until[oldest]:
			oldest = i
	if voice < 0:
		# Alle Stimmen belegt: aelteste Stimme neu starten (Puffer verwerfen).
		voice = oldest
		_players[voice].stop()
		_players[voice].play()
		_playbacks[voice] = _players[voice].get_stream_playback()
	var player: AudioStreamPlayer = _players[voice]
	var pb: AudioStreamGeneratorPlayback = _playbacks[voice] as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var level: float = volume * gain * float(GAINS.get(sound_name, 0.7)) * (0.55 + 0.45 * s if variants > 1 else 1.0)
	player.volume_db = linear_to_db(clampf(level, 0.0005, 1.5))
	player.pitch_scale = clampf(pitch, 0.4, 2.5)
	if pb.get_frames_available() < frames.size():
		return
	pb.push_buffer(frames)
	_busy_until[voice] = now + float(frames.size()) / RATE / player.pitch_scale + 0.03

## Bequemer Helfer fuer Ball-Abpraller: material = "wood" | "stone" | "metal".
func play_bounce(material: String, strength: float) -> void:
	var sound_name := "bounce_" + material
	if not SOUNDS.has(sound_name):
		sound_name = "bounce_stone"
	play(sound_name, strength, randf_range(0.92, 1.08))

## Windrauschen: level 0..1 (z.B. aus Fluggeschwindigkeit/-hoehe des Balls).
func set_wind(level: float) -> void:
	_wind_target = clampf(level, 0.0, 1.0)

func _process(delta: float) -> void:
	_wind_level = move_toward(_wind_level, _wind_target, delta * 2.5)
	if _wind_playback == null:
		return
	var audible: bool = _wind_level > 0.01 and volume > 0.001
	_wind_player.volume_db = linear_to_db(maxf(0.0001, _wind_level * _wind_level * volume * 0.55)) if audible else -80.0
	_wind_player.pitch_scale = 0.75 + 0.7 * _wind_level
	if not audible or _wind_loop.is_empty():
		return
	# Puffer der Wind-Stimme nachfuellen (ca. 0.15 s Vorlauf).
	var want: int = mini(_wind_playback.get_frames_available(), int(RATE * 0.15))
	while want > 0:
		var chunk: int = mini(want, _wind_loop.size() - _wind_pos)
		_wind_playback.push_buffer(_wind_loop.slice(_wind_pos, _wind_pos + chunk))
		_wind_pos = (_wind_pos + chunk) % _wind_loop.size()
		want -= chunk

# ================================================================ Synthese-Cache

func _get_buffer(sound_name: String, variant: int) -> PackedVector2Array:
	var key := "%s#%d" % [sound_name, variant]
	_mutex.lock()
	var cached: Variant = _cache.get(key)
	_mutex.unlock()
	if cached != null:
		return cached
	var frames := synth(sound_name, variant)
	_mutex.lock()
	_cache[key] = frames
	_mutex.unlock()
	return frames

## Berechnet einen Sound (Mono-Synthese -> Stereo-Frames). Oeffentlich fuer Tests.
func synth(sound_name: String, variant: int) -> PackedVector2Array:
	var q: float = float(variant)
	var b := PackedFloat32Array()
	match sound_name:
		"hit":
			var p: float = (q + 1.0) / 4.0
			b = _buf(0.28)
			_tone(b, 0.0, 0.26, 150.0 + 60.0 * p, 58.0, 0.9, 17.0)
			_tone(b, 0.0, 0.1, 650.0 + 550.0 * p, 380.0, 0.15 + 0.4 * p, 45.0)
			_noise(b, 0.0, 0.035, 0.35 + 0.5 * p, 110.0, 5000.0, 2200.0, true, 11 + variant)
			if variant >= 2:
				_tone(b, 0.0, 0.05, 2400.0, 1500.0, 0.2 * p, 90.0, 3)
		"bounce_wood":
			var a: float = 0.45 + 0.25 * q
			b = _buf(0.16)
			_tone(b, 0.0, 0.14, 380.0, 360.0, 0.5 * a, 38.0)
			_tone(b, 0.0, 0.1, 565.0, 550.0, 0.3 * a, 55.0)
			_tone(b, 0.0, 0.08, 910.0, 880.0, 0.16 * a, 70.0)
			_noise(b, 0.0, 0.02, 0.3 * a, 160.0, 2600.0, 1800.0, false, 21 + variant)
		"bounce_stone":
			var a2: float = 0.5 + 0.25 * q
			b = _buf(0.16)
			_noise(b, 0.0, 0.09, 0.8 * a2, 55.0, 1900.0, 480.0, false, 31 + variant)
			_tone(b, 0.0, 0.12, 140.0, 86.0, 0.55 * a2, 36.0)
			_noise(b, 0.0, 0.012, 0.4 * a2, 300.0, 6000.0, 4000.0, true, 35 + variant)
		"bounce_metal":
			var a3: float = 0.5 + 0.25 * q
			b = _buf(0.7)
			var freqs: Array[float] = [760.0, 1213.0, 1954.0, 2741.0, 3620.0]
			var decs: Array[float] = [8.0, 10.0, 13.0, 17.0, 23.0]
			var amps: Array[float] = [0.4, 0.3, 0.22, 0.15, 0.1]
			for i in freqs.size():
				_tone(b, 0.0, 0.68, freqs[i], freqs[i] * 0.995, amps[i] * a3, decs[i])
			_noise(b, 0.0, 0.015, 0.5 * a3, 250.0, 7000.0, 5000.0, true, 41 + variant)
		"splash_water":
			b = _buf(0.85)
			_noise(b, 0.0, 0.8, 0.85, 5.0, 2600.0, 450.0, false, 51, 0.012)
			_noise(b, 0.0, 0.25, 0.4, 14.0, 6000.0, 3000.0, true, 52)
			var blips: Array[float] = [0.12, 0.2, 0.27, 0.36, 0.44, 0.55, 0.63]
			for i in blips.size():
				var f: float = 480.0 + 130.0 * float((i * 5) % 7)
				_tone(b, blips[i], 0.06, f, f * 1.6, 0.2, 30.0)
		"splash_lava":
			b = _buf(1.1)
			_noise(b, 0.0, 0.95, 0.95, 4.0, 950.0, 180.0, false, 61, 0.02)
			_noise(b, 0.05, 1.0, 0.28, 3.2, 7000.0, 3500.0, true, 62, 0.05)
			_tone(b, 0.0, 0.7, 82.0, 38.0, 0.7, 5.5)
			var pops: Array[float] = [0.3, 0.48, 0.62, 0.8]
			for i in pops.size():
				_tone(b, pops[i], 0.07, 160.0 + 40.0 * float(i), 90.0, 0.3, 30.0)
		"holed":
			b = _buf(1.1)
			var knocks: Array[float] = [0.0, 0.07, 0.125, 0.165]
			var kf: Array[float] = [920.0, 720.0, 640.0, 590.0]
			for i in knocks.size():
				_tone(b, knocks[i], 0.05, kf[i], kf[i] * 0.8, 0.5 - 0.08 * float(i), 60.0)
				_noise(b, knocks[i], 0.012, 0.25, 300.0, 4000.0, 2500.0, true, 71 + i)
			var notes: Array[float] = [1046.5, 1318.5, 1568.0, 2093.0]
			for i in notes.size():
				_tone(b, 0.22 + 0.075 * float(i), 0.55, notes[i], notes[i], 0.26, 6.0, 3)
				_tone(b, 0.22 + 0.075 * float(i), 0.3, notes[i] * 2.0, notes[i] * 2.0, 0.07, 12.0)
			_echo(b, 0.17, 0.3)
		"fanfare":
			b = _buf(1.9)
			_tone(b, 0.0, 0.9, 112.0, 36.0, 1.0, 3.6)
			_noise(b, 0.0, 0.5, 0.55, 8.0, 1300.0, 180.0, false, 81)
			var arp: Array[float] = [392.0, 523.25, 659.25, 784.0]
			for i in arp.size():
				_brass(b, 0.02 + 0.115 * float(i), 0.2, arp[i], 0.26)
			var chord: Array[float] = [523.25, 659.25, 784.0, 1046.5]
			for i in chord.size():
				_brass(b, 0.5, 1.1, chord[i], 0.17)
			_noise(b, 0.5, 0.9, 0.12, 3.0, 9000.0, 6000.0, true, 82, 0.01)
			_echo(b, 0.19, 0.32)
		"bass":
			b = _buf(0.9)
			_tone(b, 0.0, 0.85, 92.0, 30.0, 1.0, 4.0)
			_tone(b, 0.0, 0.4, 46.0, 28.0, 0.5, 5.0)
			_noise(b, 0.0, 0.3, 0.5, 11.0, 320.0, 90.0, false, 91)
		"thunder":
			b = _buf(1.7)
			_noise(b, 0.0, 0.05, 1.0, 40.0, 9000.0, 3000.0, true, 101)
			_noise(b, 0.0, 1.6, 1.0, 2.4, 3200.0, 140.0, false, 102, 0.003)
			_tone(b, 0.0, 1.2, 64.0, 30.0, 0.8, 3.0)
			_noise(b, 0.25, 0.9, 0.5, 4.0, 700.0, 100.0, false, 103, 0.08)
		"click":
			b = _buf(0.06)
			_tone(b, 0.0, 0.05, 1350.0, 900.0, 0.7, 70.0)
			_noise(b, 0.0, 0.008, 0.3, 400.0, 6000.0, 4000.0, true, 111)
		"tab":
			b = _buf(0.05)
			_tone(b, 0.0, 0.04, 780.0, 700.0, 0.6, 80.0, 3)
		"chest_open":
			b = _buf(1.6)
			_tone(b, 0.0, 0.45, 85.0, 190.0, 0.22, 1.5, 2, 0.05)
			_noise(b, 0.0, 0.45, 0.2, 2.0, 500.0, 1400.0, false, 121, 0.05)
			_tone(b, 0.45, 0.06, 500.0, 250.0, 0.6, 50.0)
			_noise(b, 0.45, 0.03, 0.5, 120.0, 5000.0, 2000.0, true, 122)
			var up: Array[float] = [523.25, 659.25, 784.0, 1046.5, 1318.5]
			for i in up.size():
				_tone(b, 0.52 + 0.07 * float(i), 0.5, up[i], up[i], 0.2, 6.0, 3)
			var spark: Array[float] = [2349.0, 3136.0, 2637.0, 3520.0, 2093.0, 3951.0, 2794.0, 3136.0]
			for i in spark.size():
				_tone(b, 0.6 + 0.1 * float(i), 0.2, spark[i], spark[i], 0.12, 14.0)
			_echo(b, 0.21, 0.35)
		"coin":
			b = _buf(0.36)
			_tone(b, 0.0, 0.07, 1318.5, 1318.5, 0.5, 14.0, 3)
			_tone(b, 0.065, 0.28, 1975.5, 1975.5, 0.5, 10.0, 3)
			_tone(b, 0.065, 0.2, 3951.0, 3951.0, 0.1, 16.0)
		"gem":
			b = _buf(0.5)
			var gn: Array[float] = [2093.0, 2637.0, 3136.0]
			for i in gn.size():
				_tone(b, 0.055 * float(i), 0.35, gn[i], gn[i], 0.32, 9.0)
				_tone(b, 0.055 * float(i), 0.2, gn[i] * 1.5, gn[i] * 1.5, 0.08, 15.0)
			_echo(b, 0.11, 0.25)
		"boost":
			b = _buf(0.5)
			_noise(b, 0.0, 0.45, 0.6, 3.0, 380.0, 5200.0, false, 131, 0.09)
			_tone(b, 0.0, 0.4, 190.0, 950.0, 0.35, 4.0, 2, 0.05)
			_tone(b, 0.0, 0.4, 285.0, 1425.0, 0.15, 5.0)
		"teleport":
			b = _buf(0.65)
			_tone(b, 0.0, 0.38, 300.0, 1850.0, 0.3, 3.0, 0, 0.03)
			_tone(b, 0.0, 0.38, 452.0, 2760.0, 0.2, 3.5, 3, 0.03)
			_tone(b, 0.3, 0.25, 1850.0, 620.0, 0.25, 9.0)
			_noise(b, 0.0, 0.4, 0.15, 3.0, 2000.0, 8000.0, true, 141, 0.1)
			_echo(b, 0.09, 0.4)
		"laser":
			b = _buf(0.36)
			_tone(b, 0.0, 0.3, 1900.0, 190.0, 0.45, 7.0, 2)
			_tone(b, 0.0, 0.3, 2850.0, 285.0, 0.2, 9.0, 1)
			_noise(b, 0.0, 0.05, 0.4, 60.0, 8000.0, 4000.0, true, 151)
		"cannon":
			b = _buf(0.95)
			_noise(b, 0.0, 0.75, 1.0, 6.5, 850.0, 75.0, false, 161)
			_tone(b, 0.0, 0.7, 72.0, 33.0, 0.95, 5.0)
			_noise(b, 0.0, 0.03, 0.8, 100.0, 7000.0, 3000.0, true, 162)
			_echo(b, 0.14, 0.2)
		"pop":
			b = _buf(0.1)
			_tone(b, 0.0, 0.085, 480.0, 1150.0, 0.7, 24.0)
		"error":
			b = _buf(0.32)
			_tone(b, 0.0, 0.12, 185.0, 175.0, 0.4, 6.0, 1)
			_tone(b, 0.15, 0.14, 150.0, 140.0, 0.4, 6.0, 1)
		"beep":
			b = _buf(0.16)
			_tone(b, 0.0, 0.14, 880.0, 880.0, 0.55, 10.0, 3)
		"go":
			b = _buf(0.45)
			_tone(b, 0.0, 0.4, 1320.0, 1320.0, 0.5, 5.0, 3)
			_tone(b, 0.0, 0.4, 1760.0, 1760.0, 0.25, 6.0)
		"style":
			b = _buf(0.5)
			var sn: Array[float] = [880.0, 1108.7, 1318.5, 1760.0]
			for i in sn.size():
				_tone(b, 0.055 * float(i), 0.26, sn[i], sn[i], 0.3, 10.0, 3)
			_echo(b, 0.12, 0.25)
		"upgrade":
			b = _buf(0.95)
			var un: Array[float] = [523.25, 659.25, 784.0, 1046.5, 1318.5, 1568.0]
			for i in un.size():
				_tone(b, 0.06 * float(i), 0.42, un[i], un[i], 0.25, 7.0, 3)
			_noise(b, 0.3, 0.55, 0.1, 4.0, 9000.0, 5000.0, true, 171, 0.05)
			_tone(b, 0.0, 0.3, 130.0, 65.0, 0.4, 9.0)
			_echo(b, 0.16, 0.3)
		"whoosh":
			b = _buf(0.42)
			_noise(b, 0.0, 0.22, 0.5, 1.0, 300.0, 2400.0, false, 181, 0.12)
			_noise(b, 0.2, 0.2, 0.5, 9.0, 2400.0, 300.0, false, 182, 0.01)
		"win":
			b = _buf(1.7)
			var wn: Array[float] = [523.25, 659.25, 784.0, 1046.5, 784.0, 1046.5]
			var wt: Array[float] = [0.0, 0.12, 0.24, 0.36, 0.52, 0.66]
			for i in wn.size():
				_brass(b, wt[i], 0.9 if i == wn.size() - 1 else 0.16, wn[i], 0.26)
			_brass(b, 0.66, 0.9, 659.25, 0.16)
			_brass(b, 0.66, 0.9, 784.0, 0.16)
			_tone(b, 0.0, 0.5, 130.8, 130.8, 0.4, 4.0)
			_tone(b, 0.66, 0.9, 65.4, 65.4, 0.5, 3.0)
			_echo(b, 0.2, 0.3)
		"lose":
			b = _buf(1.2)
			var ln: Array[float] = [659.25, 523.25, 440.0, 349.2]
			for i in ln.size():
				_tone(b, 0.2 * float(i), 0.5 if i == ln.size() - 1 else 0.22, ln[i], ln[i] * 0.985, 0.35, 5.0, 3)
			_echo(b, 0.18, 0.25)
		"card":
			b = _buf(0.09)
			_noise(b, 0.0, 0.06, 0.6, 50.0, 3500.0, 1500.0, false, 191)
			_tone(b, 0.0, 0.04, 1500.0, 1100.0, 0.25, 60.0)
		"firework":
			b = _buf(1.3)
			_noise(b, 0.0, 0.35, 0.3, 2.0, 1500.0, 6000.0, true, 201, 0.15)
			_tone(b, 0.0, 0.35, 500.0, 2200.0, 0.12, 2.0, 0, 0.1)
			_noise(b, 0.36, 0.5, 1.0, 9.0, 2500.0, 200.0, false, 202)
			_tone(b, 0.36, 0.5, 95.0, 40.0, 0.8, 6.0)
			_noise(b, 0.45, 0.8, 0.3, 4.0, 9000.0, 4000.0, true, 203, 0.02)
			_echo(b, 0.15, 0.25)
		"blackhole":
			b = _buf(1.6)
			_tone(b, 0.0, 1.1, 320.0, 30.0, 0.6, 1.2, 2, 0.2)
			_tone(b, 0.0, 1.1, 644.0, 61.0, 0.25, 1.5, 0, 0.2)
			_noise(b, 0.0, 1.1, 0.4, 1.0, 4000.0, 150.0, false, 211, 0.25)
			_tone(b, 1.08, 0.5, 70.0, 28.0, 1.0, 6.0)
			_noise(b, 1.08, 0.3, 0.6, 12.0, 1200.0, 100.0, false, 212)
		_:
			return PackedVector2Array()
	return _finish(b)

func _synth_wind_loop() -> PackedVector2Array:
	var n: int = int(WIND_LOOP_SECONDS * RATE)
	var mono := PackedFloat32Array()
	mono.resize(n)
	var seed_value: int = 777
	var y1 := 0.0
	var y2 := 0.0
	for i in n:
		seed_value = (seed_value * 1103515245 + 12345) & 0x7fffffff
		var x: float = float(seed_value) / 1073741824.0 - 1.0
		y1 += 0.16 * (x - y1)
		y2 += 0.05 * (y1 - y2)
		# langsame Schwebung, damit die Schleife "atmet" (ganzzahlige Perioden -> nahtlos)
		var wobble: float = 0.75 + 0.25 * sin(TAU * 3.0 * float(i) / float(n))
		mono[i] = (y1 * 0.6 + y2 * 1.6) * wobble
	# Nahtstelle ueberblenden
	var fade: int = 600
	for i in fade:
		var t: float = float(i) / float(fade)
		mono[i] = mono[i] * t + mono[n - fade + i] * (1.0 - t)
	var out := PackedVector2Array()
	out.resize(n - fade)
	for i in n - fade:
		var v: float = clampf(mono[i] * 1.6, -1.0, 1.0)
		out[i] = Vector2(v, v)
	return out

# ================================================================ Synthese-Bausteine

func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	b.fill(0.0)
	return b

## Oszillator mit exponentiellem Frequenz-Glide (f0 -> f1) und exponentiellem Abklingen.
## wave: 0 Sinus, 1 Rechteck, 2 Saegezahn, 3 Dreieck.
func _tone(b: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, amp: float, decay: float, wave: int = 0, attack: float = 0.003) -> void:
	var i0: int = int(start * RATE)
	var n: int = mini(int(dur * RATE), b.size() - i0)
	if n <= 0 or i0 < 0:
		return
	var ratio: float = 1.0
	if absf(f1 - f0) > 0.001 and f0 > 0.0 and f1 > 0.0:
		ratio = pow(f1 / f0, 1.0 / float(n))
	var f: float = f0
	var phase: float = 0.0
	var env: float = amp
	var env_mul: float = exp(-decay / RATE)
	var att: float = maxf(1.0, attack * RATE)
	var rel: float = minf(90.0, float(n) * 0.25)
	for i in n:
		phase += f / RATE
		f *= ratio
		var p: float = phase - floor(phase)
		var s: float
		if wave == 0:
			s = sin(TAU * p)
		elif wave == 1:
			s = 0.6 if p < 0.5 else -0.6
		elif wave == 2:
			s = (2.0 * p - 1.0) * 0.7
		else:
			s = 4.0 * absf(p - 0.5) - 1.0
		var a: float = env
		if float(i) < att:
			a *= float(i) / att
		var left: float = float(n - i)
		if left < rel:
			a *= left / rel
		b[i0 + i] += s * a
		env *= env_mul

## "Blech"-Ton: Saegezahn + Oktave + leichte Schwebung, weicher Einsatz.
func _brass(b: PackedFloat32Array, start: float, dur: float, freq: float, amp: float) -> void:
	_tone(b, start, dur, freq, freq, amp * 0.55, 2.2, 2, 0.02)
	_tone(b, start, dur, freq * 1.004, freq * 1.004, amp * 0.45, 2.6, 3, 0.02)
	_tone(b, start, dur, freq * 2.0, freq * 2.0, amp * 0.18, 4.0, 0, 0.02)

## Gefiltertes Rauschen: Tiefpass mit gleitender Grenzfrequenz (c0 -> c1); highpass = Rest ueber dem Filter.
func _noise(b: PackedFloat32Array, start: float, dur: float, amp: float, decay: float, c0: float, c1: float, highpass: bool, seed_value: int, attack: float = 0.002) -> void:
	var i0: int = int(start * RATE)
	var n: int = mini(int(dur * RATE), b.size() - i0)
	if n <= 0 or i0 < 0:
		return
	var ratio: float = pow(maxf(c1, 1.0) / maxf(c0, 1.0), 1.0 / float(n))
	var c: float = c0
	var y: float = 0.0
	var env: float = amp
	var env_mul: float = exp(-decay / RATE)
	var att: float = maxf(1.0, attack * RATE)
	var rel: float = minf(120.0, float(n) * 0.25)
	var st: int = (seed_value * 7919 + 104729) & 0x7fffffff
	for i in n:
		st = (st * 1103515245 + 12345) & 0x7fffffff
		var x: float = float(st) / 1073741824.0 - 1.0
		var k: float = minf(0.99, TAU * c / RATE)
		c *= ratio
		y += k * (x - y)
		var s: float = (x - y) if highpass else y * 1.8
		var a: float = env
		if float(i) < att:
			a *= float(i) / att
		var left: float = float(n - i)
		if left < rel:
			a *= left / rel
		b[i0 + i] += s * a
		env *= env_mul

## Einfaches Feedback-Echo (Raumgefuehl).
func _echo(b: PackedFloat32Array, delay: float, feedback: float) -> void:
	var d: int = int(delay * RATE)
	if d <= 0:
		return
	for i in range(d, b.size()):
		b[i] += b[i - d] * feedback

## Soft-Clipping + Wandlung in Stereo-Frames.
func _finish(b: PackedFloat32Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n: int = b.size()
	out.resize(n)
	for i in n:
		var x: float = b[i]
		var v: float = clampf(x / (1.0 + absf(x) * 0.6), -1.0, 1.0)
		out[i] = Vector2(v, v)
	return out

## Fuer Tests: synthetisiert jeden Sound einmal und liefert die Anzahl fehlerhafter Puffer.
func self_test() -> int:
	var bad := 0
	for sound_name in SOUNDS.keys():
		for variant in int(SOUNDS[sound_name]):
			var frames := synth(str(sound_name), variant)
			if frames.is_empty():
				bad += 1
				continue
			var peak := 0.0
			for i in range(0, frames.size(), 7):
				var v: float = absf(frames[i].x)
				if is_nan(v):
					peak = 99.0
					break
				peak = maxf(peak, v)
			if peak < 0.02 or peak > 1.001:
				bad += 1
				push_warning("Sound %s#%d Pegel ungewoehnlich: %f" % [sound_name, variant, peak])
	return bad
