extends BaseFighter
class_name ENFJFighter

const LIGHT_STATES: Array[String] = ["light_1", "light_2", "light_3", "light_4", "light_5"]
const HEAVY_STATES: Array[String] = ["heavy_1", "heavy_2", "heavy_3"]
const HEAVY_CALLOUTS: Array[String] = ["耀光劈斩!", "破晓横扫!", "正气重击!"]

var aura_buff_timer: float = 0.0
var _aura_pulse: float = 0.0
var _last_light_idx: int = -1
var _last_heavy_idx: int = -1
var _combo_count: int = 0
var _combo_reset_timer: float = 0.0

# 延迟发射队列（三连剑气第 11/14/17 帧 & 大招第 8 帧）
var _pending_waves: Array[Dictionary] = []

func _ready() -> void:
	fighter_id = "enfj"
	fighter_name = "ENFJ"
	theme_color = Color("#059669")
	super._ready()

func _get_effective_move_speed() -> float:
	return move_speed * (1.10 if aura_buff_timer > 0.0 else 1.0)

func _get_attack_speed_mult() -> float:
	return 1.22 if aura_buff_timer > 0.0 else 1.0

func _get_melee_range_bonus() -> float:
	return 28.0 if aura_buff_timer > 0.0 else 0.0

func get_active_buff_status() -> String:
	if aura_buff_timer > 0.0:
		return "气焰共鸣 %.1fs" % aura_buff_timer
	return ""

func _physics_process(delta: float) -> void:
	if aura_buff_timer > 0.0:
		aura_buff_timer = maxf(0.0, aura_buff_timer - delta)
		_aura_pulse += delta * 6.5
		if int(floor(_aura_pulse)) != int(floor(_aura_pulse - delta * 6.5)):
			var vfx := BattleVFX.get_current(get_tree())
			if vfx:
				vfx.spawn_ember_burst(global_position + Vector2(randf_range(-24.0, 24.0), -28.0), Color("#4ade80"), 3)
	if sprite and sprite.material is ShaderMaterial:
		(sprite.material as ShaderMaterial).set_shader_parameter("aura_glow", 1.0 if aura_buff_timer > 0.0 else 0.0)
		(sprite.material as ShaderMaterial).set_shader_parameter("aura_color", Color("#4ade80"))
	if _combo_reset_timer > 0.0:
		_combo_reset_timer = maxf(0.0, _combo_reset_timer - delta)
		if _combo_reset_timer <= 0.0:
			_combo_count = 0

	# 处理延迟发射的剑气 / 大招斩波
	if not _pending_waves.is_empty() and not is_ko and not battle_locked:
		var remain: Array[Dictionary] = []
		for item: Dictionary in _pending_waves:
			item["delay"] = float(item["delay"]) - delta
			if float(item["delay"]) <= 0.0:
				_spawn_sword_wave(item)
			else:
				remain.append(item)
		_pending_waves = remain

	super._physics_process(delta)

func _pick_non_repeating_idx(total: int, last_idx: int) -> int:
	if total <= 1:
		return 0
	var idx: int = randi() % total
	if idx == last_idx:
		idx = (idx + 1 + (randi() % (total - 1))) % total
	return idx

func _perform_light_attack() -> void:
	var idx: int = _pick_non_repeating_idx(LIGHT_STATES.size(), _last_light_idx)
	_last_light_idx = idx
	_combo_count = mini(5, _combo_count + 1)
	_combo_reset_timer = 0.9

	var state_name: String = LIGHT_STATES[idx]
	var spd: float = _get_attack_speed_mult()
	basic_cd = 0.24 / spd
	action_anim_state = state_name
	action_anim_timer = 0.28 / spd
	_play_anim(state_name, true)
	trigger_squash(1.14, 0.90)
	spawn_slash_arc(-75.0 if idx % 2 == 0 else 65.0, 52.0 if idx % 2 == 0 else -75.0, 96.0, Color("#6ee7b7"), 0.14, 24.0)
	velocity.x = facing * 135.0
	AudioManager.play_sfx("swing_light", -5.5, 0.96 + float(_combo_count) * 0.04)

	var dmg: int = 7 + (2 if _combo_count >= 4 else 0) + (1 if aura_buff_timer > 0.0 else 0)
	var kb := Vector2(facing * (220.0 + _combo_count * 24.0), -110.0 - _combo_count * 12.0)
	var hit: bool = _perform_melee(dmg, kb, false, 102.0)
	if hit and _combo_count >= 3:
		var vfx := BattleVFX.get_current(get_tree())
		if vfx:
			vfx.spawn_floating_text(global_position + Vector2(facing * 36.0, -104.0), "%d HIT!" % _combo_count, Color("#6ee7b7"), 0.92)

func _perform_heavy_attack() -> void:
	var idx: int = _pick_non_repeating_idx(HEAVY_STATES.size(), _last_heavy_idx)
	_last_heavy_idx = idx
	_combo_count = 0
	_combo_reset_timer = 0.0

	var state_name: String = HEAVY_STATES[idx]
	var spd: float = _get_attack_speed_mult()
	basic_cd = 0.46 / spd
	action_anim_state = state_name
	action_anim_timer = 0.44 / spd
	_play_anim(state_name, true)
	trigger_squash(1.22, 0.84)
	spawn_slash_arc(-135.0 if idx != 2 else 82.0, 58.0 if idx != 2 else -105.0, 128.0, Color("#fde047"), 0.22, 38.0)
	velocity.x = facing * 190.0
	AudioManager.play_sfx("swing_heavy", -3.5, randf_range(0.92, 1.04))

	var dmg: int = 13 + idx + (2 if aura_buff_timer > 0.0 else 0)
	var kb := Vector2(facing * (360.0 + idx * 40.0), -220.0 - idx * 20.0)
	var hit: bool = _perform_melee(dmg, kb, true, 128.0)
	if hit:
		var vfx := BattleVFX.get_current(get_tree())
		if vfx:
			vfx.spawn_floating_text(global_position + Vector2(facing * 42.0, -116.0), HEAVY_CALLOUTS[idx], Color("#fde047"), 1.05)

func on_charge_skill_release(slot: String, level: int, dir: String) -> void:
	var vfx := BattleVFX.get_current(get_tree())
	if slot == "skill1":
		# 三连剑气（U/4）：三档蓄力 + ↑↓←→ 方向派生，按第 11/14/17 帧节奏连发三道圆弧剑气
		skill1_cd = 2.6 if aura_buff_timer <= 0.0 else 2.0
		action_anim_state = "triple_wave"
		action_anim_timer = 0.62
		_play_anim("triple_wave", true)
		AudioManager.play_sfx("skill_wave", -2.5, 0.95 + level * 0.06)

		var callout: String = "三连剑气!"
		if dir == "back":
			callout = "后撤三连斩!"
			if vfx:
				if rig != null and rig.visible:
					rig.spawn_ghost_into(vfx, Color("#34d399"), 0.28)
				else:
					vfx.spawn_ghost(sprite, Color("#34d399"), 0.28)
			global_position.x = clampf(global_position.x - facing * 105.0, 220.0, 1580.0)
			invincible_timer = maxf(invincible_timer, 0.16)
		elif dir == "forward":
			callout = "疾风三连斩!"
			velocity.x = facing * 260.0
		elif dir == "up":
			callout = "升空三连斩!"
		elif dir == "down":
			callout = "裂地三连斩!"
		if level >= 3:
			callout = "MAX·" + callout

		if vfx:
			vfx.spawn_floating_text(global_position + Vector2(0.0, -114.0), callout, Color("#fde047") if level >= 3 else Color("#6ee7b7"), 1.12 if level >= 3 else 1.0)

		var base_speed: float = (680.0 + level * 110.0) * (1.15 if dir == "forward" else 1.0)
		var base_dmg: int = 5 + level * 2 + (1 if aura_buff_timer > 0.0 else 0)
		var wave_sc: float = 0.85 + level * 0.22
		var delays: Array[float] = [0.12, 0.20, 0.28]

		for i in range(3):
			var vel := Vector2(facing * base_speed, 0.0)
			var y_off: float = -54.0 + float(i - 1) * 14.0
			if dir == "up":
				var ang: float = deg_to_rad(-22.0 - float(i) * 13.0)
				vel = Vector2(facing * cos(ang) * base_speed, sin(ang) * base_speed)
			elif dir == "down":
				var ang2: float = deg_to_rad(14.0 + float(i) * 9.0)
				vel = Vector2(facing * cos(ang2) * base_speed, sin(ang2) * base_speed)
				y_off = -34.0
			_pending_waves.append({
				"delay": delays[i],
				"velocity": vel,
				"damage": base_dmg,
				"knockback": Vector2(facing * (210.0 + level * 55.0), -140.0 if dir != "up" else -260.0),
				"scale": wave_sc,
				"radius": 38.0 + level * 8.0,
				"lifetime": 0.72 + level * 0.14,
				"offset": Vector2(facing * 42.0, y_off),
				"is_ultimate": false,
				"tint": Color("#facc15") if level >= 3 else Color("#34d399")
			})
	else:
		# 气焰共鸣（I/5）：蓄力震荡冲击波 + 回血回能 + 10 秒攻速/范围强化气焰 Buff
		skill2_cd = 6.5
		action_anim_state = "aura_buff"
		action_anim_timer = 0.56
		_play_anim("aura_buff", true)
		AudioManager.play_sfx("aura_buff", -2.0, 0.96 + level * 0.05)

		aura_buff_timer = 10.0
		var heal_hp: int = 6 + (level - 1) * 4 + (1 if level == 3 else 0)
		var gain_ep: float = 12.0 + (level - 1) * 9.0
		hp = mini(max_hp, hp + heal_hp)
		ep = minf(100.0, ep + gain_ep)

		var radius: float = 155.0 + level * 42.0
		var shock_dmg: int = 6 + level * 3
		if vfx:
			vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -48.0), Color("#34d399"), 18.0, radius, 0.36, 7.0)
			vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -48.0), Color("#fde047"), 10.0, radius * 0.78, 0.28, 5.0)
			vfx.spawn_hit_particles(global_position + Vector2(0.0, -48.0), Color("#6ee7b7"), 18, 280.0)
			vfx.spawn_floating_text(global_position + Vector2(0.0, -124.0), "气焰共鸣! +%dHP" % heal_hp, Color("#4ade80"), 1.1)

		for node in get_tree().get_nodes_in_group("fighters"):
			if node == self or not (node is BaseFighter):
				continue
			var target := node as BaseFighter
			if target.is_ko:
				continue
			var dist: float = target.global_position.distance_to(global_position)
			if dist <= radius:
				var push_dir: float = signf(target.global_position.x - global_position.x)
				if push_dir == 0.0:
					push_dir = float(facing)
				target.take_damage(shock_dmg, Vector2(push_dir * (310.0 + level * 60.0), -230.0), self, false)

func on_ultimate_cast() -> void:
	# 耀光破阵斩（O/6）：全屏特写 + 蓄力 8 帧后释放超大耀金圆弧斩波
	AudioManager.play_sfx("ult_cast", -1.0)
	invincible_timer = 0.85
	action_anim_state = "ultimate"
	action_anim_timer = 0.78
	_play_anim("ultimate", true)

	var vfx := BattleVFX.get_current(get_tree())
	if vfx:
		vfx.play_ult_cutin("ENFJ", "耀光破阵斩!!", GameManager.get_portrait_texture("enfj"), Color("#059669"), facing)
		vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -52.0), Color("#fde047"), 22.0, 210.0, 0.4, 8.0)
		if rig != null and rig.visible:
			rig.spawn_ghost_into(vfx, Color("#fde047"), 0.35)
		else:
			vfx.spawn_ghost(sprite, Color("#fde047"), 0.35)
	GameManager.trigger_hitstop(0.22)
	GameManager.trigger_shake(10.0, 0.25, Vector2(facing, 0.0))

	_pending_waves.append({
		"delay": 0.34,
		"velocity": Vector2(facing * 980.0, 0.0),
		"damage": 34,
		"knockback": Vector2(facing * 560.0, -340.0),
		"scale": 2.35,
		"radius": 96.0,
		"lifetime": 1.35,
		"offset": Vector2(facing * 56.0, -64.0),
		"is_ultimate": true,
		"tint": Color("#fde047")
	})

func _spawn_sword_wave(cfg: Dictionary) -> void:
	var wave := SwordWaveProjectile.new()
	wave.owner_fighter = self
	wave.global_position = global_position + (cfg["offset"] as Vector2)
	wave.velocity = cfg["velocity"] as Vector2
	wave.damage = int(cfg["damage"])
	wave.knockback = cfg["knockback"] as Vector2
	wave.wave_scale = float(cfg["scale"])
	wave.hit_radius = float(cfg["radius"])
	wave.max_lifetime = float(cfg["lifetime"])
	wave.is_ultimate = bool(cfg["is_ultimate"])
	wave.tint_color = cfg["tint"] as Color
	get_parent().add_child(wave)
	AudioManager.play_sfx("skill_wave", -1.5 if wave.is_ultimate else -5.0, 0.78 if wave.is_ultimate else randf_range(1.0, 1.16))
	if wave.is_ultimate:
		GameManager.trigger_shake(12.0, 0.22, Vector2(facing, 0.0))

func _draw() -> void:
	# 气焰共鸣外围动态气焰（不遮挡或重叠人物主体）
	if aura_buff_timer > 0.0 and not is_ko:
		var pulse: float = 0.5 + 0.5 * sin(_aura_pulse)
		var base_r: float = 52.0 + pulse * 8.0
		draw_arc(Vector2(0.0, -52.0), base_r, 0.0, TAU, 32, Color(0.2, 0.88, 0.58, 0.42 + pulse * 0.22), 5.0, true)
		draw_arc(Vector2(0.0, -52.0), base_r + 10.0, _aura_pulse * 0.4, _aura_pulse * 0.4 + PI * 1.4, 24, Color(0.99, 0.88, 0.28, 0.55), 3.0, true)
		for i in range(6):
			var ang: float = _aura_pulse * 0.7 + float(i) * (TAU / 6.0)
			var flame_pos := Vector2(cos(ang) * (base_r + 4.0), -52.0 + sin(ang) * 34.0 - pulse * 10.0)
			draw_circle(flame_pos, 4.5, Color(0.99, 0.92, 0.45, 0.72))
	super._draw()
