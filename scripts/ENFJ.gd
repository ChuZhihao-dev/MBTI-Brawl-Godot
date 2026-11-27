extends BaseFighter
class_name ENFJFighter

const LIGHT_STATES: Array[String] = ["light_1", "light_2", "light_3", "light_4", "light_5"]
const HEAVY_STATES: Array[String] = ["heavy_1", "heavy_2", "heavy_3"]
const HEAVY_CALLOUTS: Array[String] = ["耀光劈斩!", "破晓横扫!", "正气重击!"]

var aura_buff_timer: float = 0.0
var _aura_pulse: float = 0.0
var _last_heavy_idx: int = -1
var _combo_count: int = 0
var _combo_reset_timer: float = 0.0

# 延迟发射与重击挥砍帧同步队列
var _pending_waves: Array[Dictionary] = []
var _pending_heavy: Dictionary = {}
var _aura_sprite: Sprite2D

func _ready() -> void:
	fighter_id = "enfj"
	fighter_name = "ENFJ"
	theme_color = Color("#059669")
	super._ready()
	_setup_aura_sprite()

func _setup_aura_sprite() -> void:
	var aura_path := "res://assets/fighters/enfj/frames/reduced_v2/aura_loop_sheet.png"
	if not ResourceLoader.exists(aura_path):
		return
	var tex: Texture2D = load(aura_path) as Texture2D
	if tex == null:
		return
	_aura_sprite = Sprite2D.new()
	_aura_sprite.name = "AuraLoopSprite"
	_aura_sprite.texture = tex
	_aura_sprite.hframes = 2
	_aura_sprite.vframes = 2
	_aura_sprite.frame = 0
	_aura_sprite.z_index = 2
	var cell_h: float = tex.get_size().y * 0.5
	var sc: float = (target_sprite_height * 1.24) / maxf(1.0, cell_h)
	_aura_sprite.scale = Vector2(sc, sc)
	_aura_sprite.position = Vector2(0.0, -target_sprite_height * 0.52)
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_aura_sprite.material = add_mat
	_aura_sprite.modulate = Color(1.35, 1.38, 1.08, 0.86)
	_aura_sprite.visible = false
	add_child(_aura_sprite)

func _get_effective_move_speed() -> float:
	return move_speed * (1.10 if aura_buff_timer > 0.0 else 1.0)

func _get_attack_speed_mult() -> float:
	return 1.22 if aura_buff_timer > 0.0 else 1.0

func _get_melee_range_bonus() -> float:
	return 28.0 if aura_buff_timer > 0.0 else 0.0

func get_active_buff_status() -> String:
	var base_s: String = super.get_active_buff_status()
	if aura_buff_timer > 0.0:
		var aura_s: String = "气焰共鸣 %.1fs" % aura_buff_timer
		return (aura_s + " · " + base_s) if base_s != "" else aura_s
	return base_s

func reset_for_new_round(spawn_pos: Vector2, keep_ep_ratio: float = 0.3) -> void:
	aura_buff_timer = 0.0
	_combo_count = 0
	_combo_reset_timer = 0.0
	_pending_waves.clear()
	_pending_heavy.clear()
	if _aura_sprite:
		_aura_sprite.visible = false
	super.reset_for_new_round(spawn_pos, keep_ep_ratio)

func _physics_process(delta: float) -> void:
	if aura_buff_timer > 0.0:
		aura_buff_timer = maxf(0.0, aura_buff_timer - delta)
		_aura_pulse += delta * 6.5
		if int(floor(_aura_pulse)) != int(floor(_aura_pulse - delta * 6.5)):
			var vfx := BattleVFX.get_current(get_tree())
			if vfx:
				vfx.spawn_ember_burst(global_position + Vector2(randf_range(-24.0, 24.0), -28.0), Color("#4ade80"), 3)
	if _aura_sprite:
		_aura_sprite.visible = aura_buff_timer > 0.0 and not is_ko
		if _aura_sprite.visible:
			_aura_sprite.frame = int(floor(_aura_pulse * 1.5)) % 4
			_aura_sprite.modulate.a = clampf(aura_buff_timer * 1.5, 0.0, 0.88)
	if sprite and sprite.material is ShaderMaterial:
		(sprite.material as ShaderMaterial).set_shader_parameter("aura_glow", 1.0 if aura_buff_timer > 0.0 else 0.0)
		(sprite.material as ShaderMaterial).set_shader_parameter("aura_color", Color("#4ade80"))
	if _combo_reset_timer > 0.0:
		_combo_reset_timer = maxf(0.0, _combo_reset_timer - delta)
		if _combo_reset_timer <= 0.0:
			_combo_count = 0

	# 受击或战败时取消未挥出的重击前摇与待发剑气
	if hitstun_timer > 0.0 or is_ko or battle_locked:
		_pending_heavy.clear()
		if hitstun_timer > 0.0 or is_ko:
			_pending_waves.clear()
	elif not _pending_heavy.is_empty():
		_pending_heavy["delay"] = float(_pending_heavy["delay"]) - delta
		if float(_pending_heavy["delay"]) <= 0.0:
			_execute_heavy_strike(_pending_heavy)
			_pending_heavy.clear()

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
	# 顺序 5 段递进轻连招（第 1~4 段快斩压制，第 5 段小幅挑飞收尾）
	var idx: int = _combo_count % LIGHT_STATES.size()
	_combo_count = (_combo_count + 1) % LIGHT_STATES.size()
	var step_num: int = idx + 1
	_combo_reset_timer = 0.92

	var state_name: String = LIGHT_STATES[idx]
	var spd: float = _get_attack_speed_mult()
	basic_cd = (0.22 if step_num < 5 else 0.34) / spd
	action_anim_state = state_name
	action_anim_timer = (0.26 if step_num < 5 else 0.34) / spd
	_play_anim(state_name, true)
	trigger_squash(1.14, 0.90)
	spawn_slash_arc(-75.0 if idx % 2 == 0 else 65.0, 52.0 if idx % 2 == 0 else -75.0, 96.0 + idx * 4.0, Color("#fde047") if step_num == 5 else Color("#6ee7b7"), 0.14, 24.0)

	# 空中保留水平惯性并微幅滞空托举；地面小幅踏步前压
	if is_on_floor():
		velocity.x = facing * (125.0 if step_num < 5 else 185.0)
	else:
		velocity.x = lerpf(velocity.x, facing * move_speed * 0.75, 0.25)
		velocity.y = minf(velocity.y, -95.0)

	AudioManager.play_sfx("swing_light", -5.5, 0.96 + float(step_num) * 0.04)

	var dmg: int = 7 + (2 if step_num >= 4 else 0) + (1 if aura_buff_timer > 0.0 else 0)
	var kb_y: float = -210.0 if step_num == 5 else (-110.0 - step_num * 10.0)
	var kb := Vector2(facing * (210.0 + step_num * 28.0), kb_y)
	var hit: bool = _perform_melee(dmg, kb, false, 102.0 + float(idx) * 3.0)
	if hit:
		can_hit_cancel = true
		if step_num >= 3:
			var vfx := BattleVFX.get_current(get_tree())
			if vfx:
				vfx.spawn_floating_text(global_position + Vector2(facing * 36.0, -104.0), "%d HIT!" % step_num, Color("#fde047") if step_num == 5 else Color("#6ee7b7"), 0.96)

func _perform_heavy_attack() -> void:
	var idx: int = _pick_non_repeating_idx(HEAVY_STATES.size(), _last_heavy_idx)
	_last_heavy_idx = idx
	_combo_count = 0
	_combo_reset_timer = 0.0
	can_hit_cancel = false

	var state_name: String = HEAVY_STATES[idx]
	var spd: float = _get_attack_speed_mult()
	basic_cd = 0.46 / spd
	action_anim_state = state_name
	action_anim_timer = 0.44 / spd
	_play_anim(state_name, true)
	trigger_squash(0.88, 1.14)
	if is_on_floor():
		velocity.x = facing * 195.0
	else:
		velocity.x = lerpf(velocity.x, facing * move_speed * 0.8, 0.3)
		velocity.y = minf(velocity.y, -110.0)
	AudioManager.play_sfx("swing_heavy", -3.5, randf_range(0.92, 1.04))

	# 延迟 0.11s 在重击真正挥砍落刀瞬间触发刀光与判定，对齐 5 帧动作节奏
	_pending_heavy = {
		"delay": 0.11 / spd,
		"idx": idx,
		"dmg": 13 + idx + (2 if aura_buff_timer > 0.0 else 0),
		"kb": Vector2(facing * (360.0 + idx * 40.0), -220.0 - idx * 20.0)
	}

func _execute_heavy_strike(cfg: Dictionary) -> void:
	var idx: int = int(cfg["idx"])
	trigger_squash(1.24, 0.82)
	spawn_slash_arc(-135.0 if idx != 2 else 82.0, 58.0 if idx != 2 else -105.0, 132.0, Color("#fde047"), 0.22, 38.0)
	var hit: bool = _perform_melee(int(cfg["dmg"]), cfg["kb"] as Vector2, true, 130.0)
	if hit:
		var vfx := BattleVFX.get_current(get_tree())
		if vfx:
			vfx.spawn_floating_text(global_position + Vector2(facing * 42.0, -116.0), HEAVY_CALLOUTS[idx], Color("#fde047"), 1.05)

func on_charge_skill_release(slot: String, level: int, dir: String) -> void:
	var vfx := BattleVFX.get_current(get_tree())
	can_hit_cancel = false
	_pending_heavy.clear()
	if slot == "skill1":
		# 三连剑气（U/4）：三档蓄力 + ↑↓←→ 方向派生，按第 11/14/17 帧节奏连发三道圆弧剑气
		skill1_cd = 2.6 if aura_buff_timer <= 0.0 else 2.0
		action_anim_state = "triple_wave"
		action_anim_timer = 0.62
		_play_anim("triple_wave", true)
		AudioManager.play_sfx("skill_wave", -2.5, 0.95 + level * 0.06)
		if not is_on_floor():
			velocity.y = minf(velocity.y, -150.0)
		if level >= 2:
			GameManager.trigger_shake(6.5 if level >= 3 else 3.5, 0.14, Vector2(facing, 0.0))

		var grounded_down: bool = dir == "down" and is_on_floor()
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
		elif grounded_down:
			callout = "裂地疾走波!"
		elif dir == "down":
			callout = "俯冲三连斩!"
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
			var kb := Vector2(facing * (210.0 + level * 55.0), -140.0)
			var arc_start: float = -85.0 if i % 2 == 0 else 72.0
			var arc_end: float = 55.0 if i % 2 == 0 else -78.0
			if dir == "up":
				var ang: float = deg_to_rad(-22.0 - float(i) * 13.0)
				vel = Vector2(facing * cos(ang) * base_speed, sin(ang) * base_speed)
				kb.y = -260.0
				arc_start = 48.0
				arc_end = -95.0
			elif grounded_down:
				vel = Vector2(facing * base_speed * 1.12, 0.0)
				y_off = -26.0
				kb = Vector2(facing * (180.0 + level * 40.0), -285.0)
			elif dir == "down":
				var ang2: float = deg_to_rad(18.0 + float(i) * 9.0)
				vel = Vector2(facing * cos(ang2) * base_speed, sin(ang2) * base_speed)
				y_off = -34.0
			_pending_waves.append({
				"delay": delays[i],
				"velocity": vel,
				"damage": base_dmg,
				"knockback": kb,
				"scale": wave_sc,
				"radius": 38.0 + level * 8.0,
				"lifetime": 0.72 + level * 0.14,
				"offset": Vector2(facing * 42.0, y_off),
				"is_ultimate": false,
				"charge_level": level,
				"tint": Color("#facc15") if level >= 3 else Color("#34d399"),
				"arc_start": arc_start,
				"arc_end": arc_end
			})
	else:
		# 气焰共鸣（I/5）：蓄力震荡冲击波 + 施放动作霸体 + 回血回能 + 10 秒强化 Buff
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
				target.take_damage(shock_dmg, Vector2(push_dir * (310.0 + level * 60.0), -230.0), self, false, AttackPriority.SKILL)

func on_ultimate_cast() -> void:
	# 耀光破阵斩（O/6）：全屏特写 + 蓄力后释放超大耀金圆弧斩波 + 贴身破阵重劈（补齐近身盲区）
	AudioManager.play_sfx("ult_cast", -1.0)
	invincible_timer = 0.85
	can_hit_cancel = false
	_pending_heavy.clear()
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
		"tint": Color("#fde047"),
		"arc_start": -150.0,
		"arc_end": 65.0
	})

func _spawn_sword_wave(cfg: Dictionary) -> void:
	var is_ult: bool = bool(cfg["is_ultimate"])
	var wave := SwordWaveProjectile.new()
	wave.owner_fighter = self
	wave.global_position = global_position + (cfg["offset"] as Vector2)
	wave.velocity = cfg["velocity"] as Vector2
	wave.damage = int(cfg["damage"])
	wave.knockback = cfg["knockback"] as Vector2
	wave.wave_scale = float(cfg["scale"])
	wave.hit_radius = float(cfg["radius"])
	wave.max_lifetime = float(cfg["lifetime"])
	wave.is_ultimate = is_ult
	wave.charge_level = int(cfg.get("charge_level", 1))
	wave.tint_color = cfg["tint"] as Color

	if cfg.has("arc_start"):
		spawn_slash_arc(float(cfg["arc_start"]), float(cfg["arc_end"]), 165.0 if is_ult else 104.0, wave.tint_color, 0.26 if is_ult else 0.14)

	# 大招爆发瞬间同步执行贴身破阵劈砍，并将命中目标写入 wave._hit_ids 防止同一帧重复扣血
	if is_ult:
		for node in get_tree().get_nodes_in_group("fighters"):
			if node == self or not (node is BaseFighter):
				continue
			var target := node as BaseFighter
			if target.is_ko:
				continue
			var diff: Vector2 = target.global_position - global_position
			if (int(signf(diff.x)) == facing or absf(diff.x) < 42.0) and absf(diff.x) < 145.0 and absf(diff.y) < 115.0:
				wave._hit_ids[target.get_instance_id()] = true
				target.take_damage(wave.damage, wave.knockback, self, true)

	get_parent().add_child(wave)
	AudioManager.play_sfx("skill_wave", -1.5 if wave.is_ultimate else -5.0, 0.78 if wave.is_ultimate else randf_range(1.0, 1.16))
	if wave.is_ultimate:
		GameManager.trigger_shake(12.0, 0.22, Vector2(facing, 0.0))

func _draw() -> void:
	# 气焰共鸣期间若无独立外围贴图则回退到 HDR 菱形能量环
	if aura_buff_timer > 0.0 and not is_ko and _aura_sprite == null:
		var pulse: float = 0.5 + 0.5 * sin(_aura_pulse)
		var base_r: float = 52.0 + pulse * 8.0
		draw_arc(Vector2(0.0, -52.0), base_r, 0.0, TAU, 32, Color(0.28, 1.35, 0.75, 0.46 + pulse * 0.22), 4.5, true)
		draw_arc(Vector2(0.0, -52.0), base_r + 10.0, _aura_pulse * 0.45, _aura_pulse * 0.45 + PI * 1.45, 24, Color(1.45, 1.32, 0.42, 0.62), 3.0, true)
		for i in range(6):
			var ang: float = _aura_pulse * 0.75 + float(i) * (TAU / 6.0)
			var p := Vector2(cos(ang) * (base_r + 6.0), -52.0 + sin(ang) * 34.0 - pulse * 10.0)
			var diamond := PackedVector2Array([
				p + Vector2(0.0, -7.5),
				p + Vector2(4.5, 0.0),
				p + Vector2(0.0, 7.5),
				p + Vector2(-4.5, 0.0)
			])
			draw_colored_polygon(diamond, Color(1.45, 1.38, 0.55, 0.82))
	super._draw()
