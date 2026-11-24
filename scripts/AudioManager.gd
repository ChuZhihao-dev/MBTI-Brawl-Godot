extends Node

const SETTINGS_PATH: String = "user://settings.cfg"
const SAMPLE_RATE: int = 22050
const POOL_SIZE: int = 12

var muted: bool = false
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player_idx: int = 0

signal mute_changed(is_muted: bool)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_audio_settings()
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_players.append(p)
	_build_all_sfx()

func set_muted(value: bool) -> void:
	muted = value
	_save_audio_settings()
	mute_changed.emit(muted)

func toggle_mute() -> bool:
	set_muted(not muted)
	return muted

func play_sfx(sfx_name: String, volume_db: float = -4.0, pitch_scale: float = 1.0) -> void:
	if muted or not _streams.has(sfx_name):
		return
	var p: AudioStreamPlayer = _players[_next_player_idx]
	_next_player_idx = (_next_player_idx + 1) % _players.size()
	p.stream = _streams[sfx_name] as AudioStream
	p.volume_db = volume_db
	p.pitch_scale = pitch_scale
	p.play()

func _load_audio_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		muted = bool(cfg.get_value("audio", "muted", false))

func _save_audio_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "muted", muted)
	cfg.save(SETTINGS_PATH)

func _build_all_sfx() -> void:
	_streams["swing_light"] = _gen_whoosh(0.11, 520.0, 220.0, 0.35)
	_streams["swing_heavy"] = _gen_whoosh(0.18, 360.0, 110.0, 0.55)
	_streams["hit_light"] = _gen_hit(0.12, 210.0, 65.0, 0.65)
	_streams["hit_heavy"] = _gen_hit(0.22, 160.0, 42.0, 0.92)
	_streams["block"] = _gen_metallic_block(0.16)
	_streams["dash"] = _gen_whoosh(0.14, 780.0, 260.0, 0.42)
	_streams["charge_1"] = _gen_chime(0.14, 523.25, 659.25, 0.35)
	_streams["charge_2"] = _gen_chime(0.18, 659.25, 880.0, 0.42)
	_streams["charge_3"] = _gen_chime(0.24, 880.0, 1318.5, 0.52)
	_streams["skill_wave"] = _gen_sword_wave(0.26)
	_streams["aura_buff"] = _gen_aura_chord(0.45)
	_streams["ult_cast"] = _gen_ultimate(0.65)
	_streams["ko"] = _gen_ko_gong(0.85)
	_streams["ui_click"] = _gen_chime(0.06, 620.0, 740.0, 0.25)
	_streams["ui_confirm"] = _gen_chime(0.12, 540.0, 810.0, 0.32)

func _pack_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v: int = clampi(int(round(clampf(samples[i], -1.0, 1.0) * 32767.0)), -32768, 32767)
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	wav.data = bytes
	return wav

func _gen_whoosh(duration: float, start_freq: float, end_freq: float, gain: float) -> AudioStreamWAV:
	var count: int = int(duration * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase: float = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(start_freq * 13.0)
	var lp: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var env: float = sin(t * PI) * pow(1.0 - t, 0.7)
		var freq: float = lerpf(start_freq, end_freq, t)
		phase += TAU * freq / SAMPLE_RATE
		var n: float = rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, n, 0.22)
		out[i] = (lp * 0.75 + sin(phase) * 0.25) * env * gain
	return _pack_wav(out)

func _gen_hit(duration: float, start_freq: float, end_freq: float, gain: float) -> AudioStreamWAV:
	var count: int = int(duration * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase: float = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(start_freq * 29.0)
	for i in range(count):
		var t: float = float(i) / float(count)
		var freq: float = lerpf(start_freq, end_freq, pow(t, 0.45))
		phase += TAU * freq / SAMPLE_RATE
		var punch: float = sin(phase) * pow(1.0 - t, 1.5)
		var crack: float = rng.randf_range(-1.0, 1.0) * pow(1.0 - t, 4.5) * 0.65
		out[i] = tanh((punch + crack) * 1.8) * gain
	return _pack_wav(out)

func _gen_metallic_block(duration: float) -> AudioStreamWAV:
	var count: int = int(duration * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var freqs: Array[float] = [940.0, 1485.0, 2230.0, 3190.0]
	for i in range(count):
		var t: float = float(i) / float(count)
		var sec: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 9.5)
		var s: float = 0.0
		for f in freqs:
			s += sin(TAU * f * sec) * 0.25
		out[i] = tanh(s * 1.4) * env * 0.7
	return _pack_wav(out)

func _gen_chime(duration: float, f0: float, f1: float, gain: float) -> AudioStreamWAV:
	var count: int = int(duration * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var freq: float = lerpf(f0, f1, t)
		phase += TAU * freq / SAMPLE_RATE
		var env: float = minf(1.0, t * 14.0) * exp(-t * 4.5)
		out[i] = (sin(phase) * 0.7 + sin(phase * 2.0) * 0.3) * env * gain
	return _pack_wav(out)

func _gen_sword_wave(duration: float) -> AudioStreamWAV:
	var count: int = int(duration * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase: float = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 4077
	var lp: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var freq: float = lerpf(920.0, 260.0, pow(t, 0.6))
		phase += TAU * freq / SAMPLE_RATE
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.3)
		var env: float = minf(1.0, t * 22.0) * pow(1.0 - t, 1.35)
		out[i] = (sin(phase) * 0.55 + sin(phase * 1.5) * 0.2 + lp * 0.35) * env * 0.68
	return _pack_wav(out)

func _gen_aura_chord(duration: float) -> AudioStreamWAV:
	var count: int = int(duration * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var notes: Array[float] = [261.63, 329.63, 392.0, 523.25, 659.25]
	for i in range(count):
		var t: float = float(i) / float(count)
		var sec: float = float(i) / float(SAMPLE_RATE)
		var env: float = sin(minf(1.0, t * 3.0) * PI * 0.5) * pow(1.0 - t, 1.2)
		var s: float = 0.0
		for n in notes:
			s += sin(TAU * (n * (1.0 + 0.08 * t)) * sec) * 0.2
		out[i] = s * env * 0.6
	return _pack_wav(out)

func _gen_ultimate(duration: float) -> AudioStreamWAV:
	var count: int = int(duration * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var sub_phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(count)
		var sec: float = float(i) / float(SAMPLE_RATE)
		var sub_f: float = lerpf(130.0, 38.0, pow(t, 0.55))
		sub_phase += TAU * sub_f / SAMPLE_RATE
		var shimmer: float = (sin(TAU * 523.25 * sec) + sin(TAU * 783.99 * sec) + sin(TAU * 1046.5 * sec)) * 0.22
		var env: float = minf(1.0, t * 18.0) * pow(1.0 - t, 0.9)
		out[i] = tanh((sin(sub_phase) * 0.8 + shimmer * (1.0 - t * 0.4)) * 1.4) * env * 0.78
	return _pack_wav(out)

func _gen_ko_gong(duration: float) -> AudioStreamWAV:
	var count: int = int(duration * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase: float = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001
	for i in range(count):
		var t: float = float(i) / float(count)
		var sec: float = float(i) / float(SAMPLE_RATE)
		var freq: float = lerpf(150.0, 44.0, pow(t, 0.4))
		phase += TAU * freq / SAMPLE_RATE
		var gong: float = sin(phase) * 0.7 + sin(TAU * 280.0 * sec) * 0.25 + sin(TAU * 417.0 * sec) * 0.18
		var burst: float = rng.randf_range(-1.0, 1.0) * exp(-t * 16.0) * 0.55
		var env: float = exp(-t * 2.8)
		out[i] = tanh((gong + burst) * 1.5) * env * 0.82
	return _pack_wav(out)
