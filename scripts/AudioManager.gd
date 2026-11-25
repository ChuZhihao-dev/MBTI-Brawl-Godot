extends Node

const SETTINGS_PATH: String = "user://settings.cfg"
const SAMPLE_RATE: int = 22050
const POOL_SIZE: int = 12

var muted: bool = false
var bgm_muted: bool = false
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player_idx: int = 0
var _bgm_player: AudioStreamPlayer
var _bgm_stream: AudioStreamWAV

signal mute_changed(is_muted: bool)
signal bgm_mute_changed(is_bgm_muted: bool)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_audio_settings()
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_players.append(p)
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_bgm_player.volume_db = -14.5
	add_child(_bgm_player)
	_build_all_sfx()
	_bgm_stream = _gen_battle_bgm()

func set_muted(value: bool) -> void:
	muted = value
	_save_audio_settings()
	mute_changed.emit(muted)

func toggle_mute() -> bool:
	set_muted(not muted)
	return muted

func set_bgm_muted(value: bool) -> void:
	bgm_muted = value
	if _bgm_player:
		if bgm_muted:
			_bgm_player.stop()
		elif _bgm_stream != null and _bgm_player.stream == _bgm_stream:
			_bgm_player.play()
	_save_audio_settings()
	bgm_mute_changed.emit(bgm_muted)

func toggle_bgm() -> bool:
	set_bgm_muted(not bgm_muted)
	return bgm_muted

func start_battle_bgm() -> void:
	if _bgm_player == null or _bgm_stream == null:
		return
	_bgm_player.stream = _bgm_stream
	_bgm_player.volume_db = -14.5
	if not bgm_muted and not _bgm_player.playing:
		_bgm_player.play()

func stop_bgm() -> void:
	if _bgm_player and _bgm_player.playing:
		_bgm_player.stop()

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
		bgm_muted = bool(cfg.get_value("audio", "bgm_muted", false))

func _save_audio_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("audio", "bgm_muted", bgm_muted)
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
	_streams["parry"] = _gen_chime(0.28, 1046.5, 1568.0, 0.65)
	_streams["jump_double"] = _gen_whoosh(0.12, 340.0, 880.0, 0.38)
	_streams["wind_boost"] = _gen_whoosh(0.32, 240.0, 960.0, 0.55)
	_streams["item_pickup"] = _gen_chime(0.24, 587.3, 1174.6, 0.52)
	_streams["bomb_explode"] = _gen_hit(0.42, 135.0, 32.0, 0.96)
	_streams["round_ready"] = _gen_chime(0.22, 440.0, 554.37, 0.45)
	_streams["round_fight"] = _gen_ultimate(0.38)
	_streams["shield_break"] = _gen_shield_break(0.46)
	_streams["wall_bounce"] = _gen_hit(0.24, 240.0, 58.0, 0.85)
	_streams["tech_roll"] = _gen_chime(0.16, 740.0, 1180.0, 0.45)
	_streams["air_slam"] = _gen_whoosh(0.22, 620.0, 140.0, 0.62)

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

func _gen_shield_break(duration: float) -> AudioStreamWAV:
	var count: int = int(duration * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7731
	var freqs: Array[float] = [1480.0, 2110.0, 2940.0, 3820.0]
	for i in range(count):
		var t: float = float(i) / float(count)
		var sec: float = float(i) / float(SAMPLE_RATE)
		var shatter: float = 0.0
		for k in range(freqs.size()):
			shatter += sin(TAU * (freqs[k] * (1.0 - 0.18 * t)) * sec) * 0.22
		var crunch: float = rng.randf_range(-1.0, 1.0) * exp(-t * 8.5) * 0.65
		var sub: float = sin(TAU * lerpf(160.0, 48.0, t) * sec) * exp(-t * 5.0) * 0.55
		var env: float = exp(-t * 4.2)
		out[i] = tanh((shatter * exp(-t * 5.5) + crunch + sub) * 1.4) * env * 0.82
	return _pack_wav(out)

func _gen_battle_bgm() -> AudioStreamWAV:
	# 136 BPM 4小节循环街机对战 BGM（16步贝斯 + 跳跃琶音 + 轻快底鼓/军鼓）
	var bpm: float = 136.0
	var step_sec: float = (60.0 / bpm) * 0.25 # 十六分音符
	var total_steps: int = 64
	var total_dur: float = step_sec * float(total_steps)
	var count: int = int(round(total_dur * SAMPLE_RATE))
	var out := PackedFloat32Array()
	out.resize(count)

	# D 小调街机推进：Dm - Bb - C - A
	var bass_roots: Array[float] = [146.83, 116.54, 130.81, 110.00]
	var arp_patterns: Array = [
		[293.66, 349.23, 440.00, 587.33],
		[233.08, 293.66, 349.23, 466.16],
		[261.63, 329.63, 392.00, 523.25],
		[220.00, 277.18, 329.63, 440.00]
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026

	for i in range(count):
		var sec: float = float(i) / float(SAMPLE_RATE)
		var step_f: float = sec / step_sec
		var step: int = int(floor(step_f)) % total_steps
		var step_t: float = fmod(step_f, 1.0)
		var bar: int = (step / 16) % 4
		var beat_in_bar: int = step % 16

		# 1. 律动贝斯（八分音符脉冲）
		var root: float = bass_roots[bar]
		var bass_freq: float = root * (1.5 if (beat_in_bar % 4 == 2) else 1.0)
		var bass_env: float = exp(-step_t * 4.5) if (beat_in_bar % 2 == 0) else exp(-step_t * 7.5) * 0.65
		var bass: float = (sin(TAU * bass_freq * sec) * 0.72 + sin(TAU * bass_freq * 2.0 * sec) * 0.22) * bass_env * 0.34

		# 2. 明亮低多边形风格琶音（十六分音符）
		var arp_arr: Array = arp_patterns[bar] as Array
		var arp_freq: float = float(arp_arr[step % 4])
		var arp_env: float = minf(1.0, step_t * 24.0) * exp(-step_t * 6.5)
		var arp: float = (sin(TAU * arp_freq * sec) * 0.65 + sin(TAU * arp_freq * 2.0 * sec) * 0.20) * arp_env * 0.16

		# 3. 轻快底鼓（0, 4, 8, 12 拍）与踩镲（2, 6, 10, 14 拍）
		var drum: float = 0.0
		if beat_in_bar % 4 == 0:
			var kick_f: float = lerpf(118.0, 46.0, minf(1.0, step_t * 3.0))
			drum += sin(TAU * kick_f * (step_t * step_sec)) * exp(-step_t * 9.0) * 0.36
		elif beat_in_bar % 4 == 2:
			drum += rng.randf_range(-1.0, 1.0) * exp(-step_t * 22.0) * 0.10

		out[i] = tanh((bass + arp + drum) * 1.15) * 0.72

	var wav := _pack_wav(out)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = count
	return wav
