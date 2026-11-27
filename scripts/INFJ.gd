extends BaseFighter
class_name INFJFighter

# 方案 A：「表里双姿态 · 变色龙切换」（跳出刻板印象的多变战术大师）
enum Stance { SURFACE, SHADOW }

const SURFACE_COLOR: Color = Color("#10b981") # 表 · 共鸣态（暖绿金）
const SHADOW_COLOR: Color = Color("#8b5cf6")  # 里 · 洞察态（深翠幽紫）

var stance: Stance = Stance.SURFACE
var dual_persona_timer: float = 0.0
var _combo_count: int = 0
var _combo_reset_timer: float = 0.0
var _emblem_phase: float = 0.0
var _blink_warped: bool = false
var _blink_origin: Vector2 = Vector2.ZERO
var _blink_trail_timer: float = 0.0

func _ready() -> void:
	fighter_id = "infj"
	fighter_name = "INFJ"
	theme_color = SURFACE_COLOR
	super._ready()

func _get_stance_color() -> Color:
	return SURFACE_COLOR if stance == Stance.SURFACE else SHADOW_COLOR

func _get_effective_move_speed() -> float:
	var mult: float = 1.06 if stance == Stance.SURFACE else 1.0
	if dual_persona_timer > 0.0:
		mult += 0.10
	return move_speed * mult

func _get_attack_speed_mult() -> float:
	var mult: float = 1.12 if stance == Stance.SHADOW else 1.0
	if dual_persona_timer > 0.0:
		mult += 0.12
	return mult

func _get_dash_duration() -> float:
	return 0.28

func _use_blink_dash() -> bool:
	return true

func _process_blink_dash(delta: float) -> void:
	# 大乱斗级丝滑三段式「消失帧瞬移」：
	# 0.00~0.065s 极速原地收束 -> 0.065~0.135s 彻底隐身瞬移（支持按住上键斜上闪上浮台！） -> 0.135~0.28s 开门丝滑踏出
	var elapsed: float = _get_dash_duration() - dash_timer
	if elapsed < 0.065:
		_blink_warped = false
		velocity.x = move_toward(velocity.x, 0.0, 2600.0 * delta)
		velocity.y = minf(velocity.y, 0.0)
		if sprite:
			sprite.visible = true
	elif elapsed < 0.135:
		if not _blink_warped:
			_blink_warped = true
			_blink_origin = global_position
			_blink_trail_timer = 0.18
			var inp: Dictionary = _read_inputs()
			var up_blink: bool = bool(inp.get("up_held", false))
			var dx: float = float(dash_dir) * (155.0 if up_blink else 210.0)
			var dy: float = -115.0 if up_blink else 0.0
			global_position.x = clampf(global_position.x + dx, 220.0, 1580.0)
			global_position.y = maxf(185.0, global_position.y + dy)
			velocity = Vector2(float(dash_dir) * 230.0, -90.0 if up_blink else 0.0)
			var vfx := BattleVFX.get_current(get_tree())
			if vfx:
				vfx.spawn_shockwave_ring(_blink_origin + Vector2(0.0, -52.0), theme_color, 8.0, 62.0, 0.18, 3.5)
				vfx.spawn_ember_burst(_blink_origin + Vector2(0.0, -52.0), Color("#fde047"), 8)
				vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -52.0), Color("#fde047"), 10.0, 74.0, 0.20, 4.0)
				vfx.spawn_ember_burst(global_position + Vector2(0.0, -52.0), theme_color.lightened(0.25), 10)
		if sprite:
			sprite.visible = false
	else:
		# 终点现身附带顺滑前踏惯性，自然减速不硬刹！
		velocity.x = move_toward(velocity.x, 0.0, 1450.0 * delta)
		if sprite:
			sprite.visible = true
		# 现身阶段支持极早取消衔接轻/重击，连招超顺手
		if elapsed > 0.18 and basic_cd <= 0.0 and attack_buffer_timer > 0.0:
			dash_timer = 0.0
			attack_buffer_timer = 0.0
			if attack_buffer_type == "light":
				_perform_light_attack()
			else:
				_perform_heavy_attack()

func get_active_buff_status() -> String:
	var parts: Array[String] = []
	parts.append("【表·共鸣】" if stance == Stance.SURFACE else "【里·洞察】")
	if dual_persona_timer > 0.0:
		parts.append("表里双生 %.1fs" % dual_persona_timer)
	var base_s: String = super.get_active_buff_status()
	if base_s != "":
		parts.append(base_s)
	return " · ".join(parts)

func reset_for_new_round(spawn_pos: Vector2, keep_ep_ratio: float = 0.3) -> void:
	stance = Stance.SURFACE
	theme_color = SURFACE_COLOR
	dual_persona_timer = 0.0
	_combo_count = 0
	_combo_reset_timer = 0.0
	super.reset_for_new_round(spawn_pos, keep_ep_ratio)

func _physics_process(delta: float) -> void:
	_emblem_phase += delta * 4.2
	_blink_trail_timer = maxf(0.0, _blink_trail_timer - delta)
	if dual_persona_timer > 0.0:
		dual_persona_timer = maxf(0.0, dual_persona_timer - delta)
		if int(floor(_emblem_phase)) != int(floor(_emblem_phase - delta * 4.2)):
			var vfx := BattleVFX.get_current(get_tree())
			if vfx:
				var c: Color = SURFACE_COLOR if (int(floor(_emblem_phase)) % 2 == 0) else SHADOW_COLOR
				vfx.spawn_ember_burst(global_position + Vector2(randf_range(-24.0, 24.0), -38.0), c, 2)

	if sprite and sprite.material is ShaderMaterial:
		var mat := sprite.material as ShaderMaterial
		if dual_persona_timer > 0.0:
			mat.set_shader_parameter("aura_glow", 1.0)
			mat.set_shader_parameter("aura_color", Color("#fde047"))
		elif stance == Stance.SHADOW:
			mat.set_shader_parameter("aura_glow", 0.55)
			mat.set_shader_parameter("aura_color", SHADOW_COLOR)
		else:
			mat.set_shader_parameter("aura_glow", 0.0)

	if _combo_reset_timer > 0.0:
		_combo_reset_timer = maxf(0.0, _combo_reset_timer - delta)
		if _combo_reset_timer <= 0.0:
			_combo_count = 0

	super._physics_process(delta)

	# 60fps 极柔和呼吸微动（与 16 帧待机叠合，消除帧切生硬感）；晶格瞬移时精确锁定三段帧、弹性缩放与显隐
	if sprite and dash_timer > 0.0:
		sprite.rotation = 0.0
		var b_el: float = _get_dash_duration() - dash_timer
		if b_el < 0.065:
			sprite.visible = true
			var p1: float = clampf(b_el / 0.065, 0.0, 1.0)
			sprite.frame = clampi(int(floor(p1 * 4.0)), 0, 3)
			var sx1: float = lerpf(1.0, 0.58, p1)
			var sy1: float = lerpf(1.0, 1.12, p1)
			sprite.scale = Vector2(_base_sprite_scale.x * sx1, _base_sprite_scale.y * sy1)
		elif b_el < 0.135:
			sprite.visible = false
		else:
			sprite.visible = true
			var p2: float = clampf((b_el - 0.135) / 0.145, 0.0, 1.0)
			sprite.frame = 8 + clampi(int(floor(p2 * 3.99)), 0, 3)
			var sx2: float = lerpf(0.62, 1.0, minf(1.0, p2 * 1.45))
			var sy2: float = lerpf(1.10, 1.0, minf(1.0, p2 * 1.45))
			sprite.scale = Vector2(_base_sprite_scale.x * sx2, _base_sprite_scale.y * sy2)
	else:
		_blink_warped = false
		if sprite and not sprite.visible and (rig == null or not rig.visible):
			sprite.visible = true
		if sprite and sprite.visible and _current_anim == "idle" and not is_ko:
			var b_sy: float = 1.0 + sin(_breath_time * 2.9) * 0.018
			var b_sx: float = 1.0 - sin(_breath_time * 2.9) * 0.010
			sprite.scale = Vector2(sprite.scale.x * b_sx, sprite.scale.y * b_sy)
			sprite.position.y = -target_sprite_height * 0.5 * b_sy + 4.0

func _perform_light_attack() -> void:
	_combo_count = (_combo_count % 3) + 1
	_combo_reset_timer = 0.95
	var spd: float = _get_attack_speed_mult()

	if stance == Stance.SURFACE:
		# 【表 · 共鸣态】灵动 3 段近中程弧光连击（1~2 段斜挥斩、第 3 段前踏共鸣点刺）
		basic_cd = (0.24 if _combo_count < 3 else 0.34) / spd
		var st_name: String = "light_surface_1" if _combo_count < 3 else "light_surface_3"
		action_anim_state = st_name
		action_anim_timer = (0.24 if _combo_count < 3 else 0.30) / spd
		_play_anim(st_name, true)
		trigger_squash(1.12, 0.90)
		AudioManager.play_sfx("swing_light", -5.0, 1.04 + float(_combo_count) * 0.07)
		if is_on_floor():
			velocity.x = facing * (135.0 if _combo_count < 3 else 180.0)
		var arc_col: Color = Color("#fde047") if _combo_count == 3 else SURFACE_COLOR.lightened(0.25)
		spawn_slash_arc(-75.0 if _combo_count != 2 else 65.0, 55.0 if _combo_count != 2 else -70.0, 96.0 + float(_combo_count) * 10.0, arc_col, 0.16)
		var kb: Vector2 = Vector2(facing * (190.0 if _combo_count < 3 else 330.0), -110.0 if _combo_count < 3 else -180.0)
		var hit: bool = _perform_melee(7 + _combo_count, kb, _combo_count == 3, 114.0 + float(_combo_count) * 8.0)
		if hit and _combo_count < 3:
			can_hit_cancel = true
		if dual_persona_timer > 0.0 and _combo_count == 3:
			_spawn_behind_rift(6)
	else:
		# 【里 · 洞察态】高速 3 段空间切裂斩，第 3 段在对手身后补出延迟「空间裂隙」！
		basic_cd = (0.21 if _combo_count < 3 else 0.36) / spd
		var sh_name: String = "light_shadow_1" if _combo_count < 3 else "light_shadow_3"
		action_anim_state = sh_name
		action_anim_timer = (0.22 if _combo_count < 3 else 0.30) / spd
		_play_anim(sh_name, true)
		trigger_squash(1.16, 0.88)
		AudioManager.play_sfx("swing_light", -4.5, 1.22 + float(_combo_count) * 0.08)
		spawn_slash_arc(-105.0, 50.0, 108.0 + float(_combo_count) * 8.0, SHADOW_COLOR.lightened(0.22), 0.15)
		var kb2: Vector2 = Vector2(facing * (170.0 if _combo_count < 3 else 250.0), -130.0 if _combo_count < 3 else -220.0)
		var hit2: bool = _perform_melee(8 + _combo_count, kb2, _combo_count == 3, 122.0)
		if hit2 and _combo_count < 3:
			can_hit_cancel = true
		if _combo_count == 3:
			_spawn_behind_rift(9)

func _perform_heavy_attack() -> void:
	_combo_count = 0
	var spd: float = _get_attack_speed_mult()
	basic_cd = 0.48 / spd
	action_anim_state = "heavy"
	action_anim_timer = 0.36 / spd
	_play_anim("heavy", true)
	trigger_squash(1.20, 0.84)
	var vfx := BattleVFX.get_current(get_tree())

	if stance == Stance.SURFACE:
		# 【表 · 共鸣态重击】棱镜折射：近身震飞 + 原路反弹一切敌方飞行道具！
		action_anim_state = "heavy_surface"
		_play_anim("heavy_surface", true)
		AudioManager.play_sfx("swing_heavy", -3.0, 1.18)
		var shield_pos: Vector2 = global_position + Vector2(facing * 64.0, -52.0)
		if vfx:
			vfx.spawn_shockwave_ring(shield_pos, Color("#fde047"), 14.0, 112.0, 0.24, 6.0)
			vfx.spawn_shockwave_ring(shield_pos, SURFACE_COLOR, 10.0, 88.0, 0.20, 4.0)
		var reflected_any: bool = _reflect_nearby_projectiles(shield_pos, 145.0)
		if reflected_any:
			ep = minf(100.0, ep + 14.0)
			AudioManager.play_sfx("parry", -1.5, 1.12)
			GameManager.trigger_hitstop(0.08)
			if vfx:
				vfx.spawn_floating_text(global_position + Vector2(0.0, -116.0), "棱镜折射! +14 EP", Color("#fde047"), 1.16)
		_perform_melee(12, Vector2(facing * 360.0, -220.0), true, 134.0)
		if dual_persona_timer > 0.0:
			_spawn_gravity_prism()
	else:
		# 【里 · 洞察态重击】维度坍缩：前方投射几何棱锥，短延迟向心拉扯并挑飞！
		action_anim_state = "heavy_shadow"
		_play_anim("heavy_shadow", true)
		AudioManager.play_sfx("skill_wave", -3.0, 0.92)
		_spawn_gravity_prism()
		if dual_persona_timer > 0.0:
			_reflect_nearby_projectiles(global_position + Vector2(facing * 56.0, -52.0), 120.0)

func _reflect_nearby_projectiles(center: Vector2, rad: float) -> bool:
	var reflected: bool = false
	for proj in get_tree().get_nodes_in_group("projectiles"):
		if not is_instance_valid(proj) or not (proj is Node2D):
			continue
		if proj.get("owner_fighter") == self:
			continue
		if (proj as Node2D).global_position.distance_to(center) <= rad and proj.has_method("reflect"):
			proj.reflect(self)
			reflected = true
	return reflected

func _spawn_behind_rift(dmg: int) -> void:
	var target_pos: Vector2 = global_position + Vector2(facing * 140.0, -52.0)
	var slash_dir: int = -facing
	for node in get_tree().get_nodes_in_group("fighters"):
		if node != self and node is BaseFighter and not (node as BaseFighter).is_ko:
			var enemy := node as BaseFighter
			var behind_sign: float = signf(enemy.global_position.x - global_position.x)
			if behind_sign == 0.0:
				behind_sign = float(facing)
			target_pos = enemy.global_position + Vector2(behind_sign * 52.0, -52.0)
			slash_dir = -int(behind_sign)
			break
	var rift := INFJPrismConstruct.new()
	rift.kind = INFJPrismConstruct.Kind.RIFT_SLASH
	rift.owner_fighter = self
	rift.global_position = target_pos
	rift.damage = dmg
	rift.knockback = Vector2(float(slash_dir) * 260.0, -250.0)
	rift.facing_dir = slash_dir
	rift.tint_color = SURFACE_COLOR
	rift.secondary_color = SHADOW_COLOR
	get_parent().add_child(rift)

func _spawn_gravity_prism() -> void:
	var prism := INFJPrismConstruct.new()
	prism.kind = INFJPrismConstruct.Kind.GRAVITY_PRISM
	prism.owner_fighter = self
	prism.global_position = global_position + Vector2(facing * 56.0, -54.0)
	prism.velocity = Vector2(facing * 430.0, 0.0)
	prism.damage = 13
	prism.facing_dir = facing
	prism.tint_color = SURFACE_COLOR
	prism.secondary_color = SHADOW_COLOR
	get_parent().add_child(prism)

func on_charge_skill_release(slot: String, level: int, dir: String) -> void:
	var vfx := BattleVFX.get_current(get_tree())
	if slot == "skill1":
		# 技能 1（U/4）：千面幻象（四向彻底不同机制）
		skill1_cd = 2.5
		action_anim_state = "skill"
		action_anim_timer = 0.36
		_play_anim("skill", true)
		trigger_squash(1.14, 0.88)

		if dir == "up":
			# 向上派生：虚实换位（瞬间上移 + 原地留下反击替身幻象！）
			var old_pos := global_position
			var decoy := INFJPrismConstruct.new()
			decoy.kind = INFJPrismConstruct.Kind.DECOY_ILLUSION
			decoy.owner_fighter = self
			decoy.global_position = old_pos
			decoy.damage = 9 + level * 2
			decoy.facing_dir = facing
			decoy.tint_color = _get_stance_color()
			decoy.max_lifetime = 2.2 + float(level) * 0.4
			get_parent().add_child(decoy)

			global_position.y = maxf(190.0, global_position.y - 135.0)
			velocity = Vector2(facing * 120.0, -180.0)
			invincible_timer = maxf(invincible_timer, 0.18)
			AudioManager.play_sfx("dash", -3.0, 1.22)
			if vfx:
				vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -48.0), _get_stance_color(), 10.0, 72.0, 0.22, 4.0)
				vfx.spawn_floating_text(global_position + Vector2(0.0, -110.0), "虚实换位!", _get_stance_color().lightened(0.25), 1.05)

		elif dir == "down":
			# 向下派生：折光地雷阵
			var trap := INFJPrismConstruct.new()
			trap.kind = INFJPrismConstruct.Kind.PRISM_TRAP
			trap.owner_fighter = self
			trap.global_position = Vector2(clampf(global_position.x + facing * (64.0 + level * 24.0), 240.0, 1560.0), global_position.y)
			trap.damage = 8 + level * 3
			trap.tint_color = _get_stance_color()
			trap.max_lifetime = 4.5 + float(level) * 0.6
			get_parent().add_child(trap)
			AudioManager.play_sfx("charge_2", -4.0, 1.05)
			if vfx:
				vfx.spawn_floating_text(global_position + Vector2(0.0, -108.0), "折光陷阱!", Color("#fde047"), 1.0)

		elif dir == "back":
			# 向后派生：残影撤步（原地留下会模仿发射光刃的残影！）
			var old_pos2 := global_position
			var decoy2 := INFJPrismConstruct.new()
			decoy2.kind = INFJPrismConstruct.Kind.DECOY_ILLUSION
			decoy2.owner_fighter = self
			decoy2.global_position = old_pos2
			decoy2.damage = 8 + level * 2
			decoy2.facing_dir = facing
			decoy2.tint_color = _get_stance_color()
			decoy2.mimic_on_spawn = true
			decoy2.max_lifetime = 1.8
			get_parent().add_child(decoy2)

			global_position.x = clampf(global_position.x - facing * 125.0, 220.0, 1580.0)
			invincible_timer = maxf(invincible_timer, 0.18)
			AudioManager.play_sfx("dash", -3.5, 1.15)
			if vfx:
				vfx.spawn_ghost(sprite, _get_stance_color(), 0.26)
				vfx.spawn_floating_text(global_position + Vector2(0.0, -110.0), "残影撤步!", _get_stance_color().lightened(0.25), 1.02)

		else:
			# 平射 / 前向：千面折射光刃（撞地/撞墙折角反弹并自动微调追击！）
			var blade := INFJPrismConstruct.new()
			blade.kind = INFJPrismConstruct.Kind.BOUNCE_BLADE
			blade.owner_fighter = self
			blade.global_position = global_position + Vector2(facing * 38.0, -56.0)
			var spd: float = (620.0 + level * 65.0) * (1.15 if dir == "forward" else 1.0)
			# 里态默认斜向下发射制造地面折射奇袭；表态平直高速切入
			var vy: float = 280.0 if stance == Stance.SHADOW else (0.0 if dir != "forward" else -90.0)
			blade.velocity = Vector2(facing * spd, vy).normalized() * spd
			blade.damage = 7 + level * 3
			blade.knockback = Vector2(facing * (250.0 + level * 55.0), -170.0)
			blade.bounces_left = level
			blade.max_lifetime = 1.25 + float(level) * 0.35
			blade.tint_color = Color("#fde047") if level >= 3 else _get_stance_color()
			get_parent().add_child(blade)
			AudioManager.play_sfx("skill_wave", -3.0, 1.18 + level * 0.06)
			if vfx:
				vfx.spawn_floating_text(global_position + Vector2(0.0, -110.0), "折射光刃·%d弹!" % level, blade.tint_color.lightened(0.2), 1.02)

	else:
		# 技能 2（I/5）：面具切换 · 表里反转（轻按秒切连段取消，满蓄开启表里双生！）
		stance = Stance.SHADOW if stance == Stance.SURFACE else Stance.SURFACE
		theme_color = _get_stance_color()
		invincible_timer = maxf(invincible_timer, 0.16)
		basic_cd = 0.0
		action_anim_timer = 0.0
		action_anim_state = ""
		can_hit_cancel = true
		skill2_cd = 0.85 if level == 1 else (3.6 if level == 2 else 6.8)
		trigger_squash(0.86, 1.18)
		AudioManager.play_sfx("aura_buff" if level >= 2 else "tech_roll", -2.5, 1.15 if stance == Stance.SHADOW else 0.96)

		var stance_label: String = "里态 · 洞察!" if stance == Stance.SHADOW else "表态 · 共鸣!"
		if vfx:
			vfx.spawn_ghost(sprite, theme_color, 0.26)
			vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -48.0), theme_color, 14.0, 86.0 + float(level) * 28.0, 0.26, 5.0)
			vfx.spawn_floating_text(global_position + Vector2(0.0, -114.0), "表里双生!!" if level >= 3 else stance_label, Color("#fde047") if level >= 3 else theme_color.lightened(0.22), 1.16 if level >= 3 else 1.04)

		if level >= 2:
			ep = minf(100.0, ep + (12.0 if level == 2 else 18.0))
			for node in get_tree().get_nodes_in_group("fighters"):
				if node == self or not (node is BaseFighter):
					continue
				var target := node as BaseFighter
				if target.is_ko:
					continue
				if target.global_position.distance_to(global_position) <= 135.0 + float(level) * 20.0:
					var push_d: float = signf(target.global_position.x - global_position.x)
					if push_d == 0.0:
						push_d = float(facing)
					target.take_damage(6 + level * 2, Vector2(push_d * 310.0, -210.0), self, false)

		if level >= 3:
			dual_persona_timer = 5.5

func on_ultimate_cast() -> void:
	# 万花筒心域 · Kaleidoscope：多面体镜界展开 + 表里幻影四向交错穿刺 + 镜界坍缩终结
	AudioManager.play_sfx("ult_cast", -1.0)
	invincible_timer = 0.95
	action_anim_state = "skill"
	action_anim_timer = 0.72
	_play_anim("skill", true)
	trigger_squash(0.88, 1.18)

	var vfx := BattleVFX.get_current(get_tree())
	if vfx:
		vfx.play_ult_cutin("INFJ", "KALEIDOSCOPE · 万花筒心域!!", GameManager.get_portrait_texture("infj"), SHADOW_COLOR, facing)
	GameManager.trigger_hitstop(0.20)

	var target_pos: Vector2 = global_position + Vector2(facing * 240.0, -52.0)
	for node in get_tree().get_nodes_in_group("fighters"):
		if node != self and node is BaseFighter and not (node as BaseFighter).is_ko:
			target_pos = (node as BaseFighter).global_position + Vector2(0.0, -52.0)
			break

	var ult := INFJPrismConstruct.new()
	ult.kind = INFJPrismConstruct.Kind.KALEIDOSCOPE_ULT
	ult.owner_fighter = self
	ult.global_position = target_pos
	ult.facing_dir = facing
	ult.tint_color = SURFACE_COLOR
	ult.secondary_color = SHADOW_COLOR
	get_parent().add_child(ult)

func _draw() -> void:
	# 60fps 空间折跃光带：连接瞬移起点与终点，让视觉轨迹极度顺滑不突兀
	if _blink_trail_timer > 0.0:
		var tr_a: float = clampf(_blink_trail_timer / 0.18, 0.0, 1.0)
		var local_from: Vector2 = to_local(_blink_origin + Vector2(0.0, -52.0))
		var local_to := Vector2(0.0, -52.0)
		var col_t: Color = _get_stance_color()
		draw_line(local_from, local_to, Color(col_t.r, col_t.g, col_t.b, 0.55 * tr_a), 14.0 * tr_a, true)
		draw_line(local_from, local_to, Color(0.99, 0.94, 0.55, 0.88 * tr_a), 5.0 * tr_a, true)
	if sprite and not sprite.visible:
		return
	super._draw()
	if is_ko:
		return
	# 60fps 丝滑低多边形 3D 旋转八面体棱镜 + 3 颗绕转微晶（悬浮于魔杖尖端，随【表/里】姿态无级变色！）
	var t: float = _breath_time
	var is_idle_now: bool = (_current_anim == "idle" and is_on_floor() and action_anim_timer <= 0.0 and not guarding)
	var bob: float = sin(t * 2.6) * 5.0
	var pos := Vector2(float(facing) * (44.0 if is_idle_now else -34.0), (-118.0 if is_idle_now else -98.0) + bob)

	# 60fps 柔和色相流转：表态在翡翠绿⇄金绿间呼吸，里态在幽紫⇄青碧间流转，表里双生呈璀璨金绿紫
	var wave: float = 0.5 + 0.5 * sin(t * 1.8)
	var c_base: Color
	var c_hi: Color
	var c_dark: Color
	if dual_persona_timer > 0.0:
		c_base = SURFACE_COLOR.lerp(SHADOW_COLOR, wave)
		c_hi = Color("#fde047")
		c_dark = c_base.darkened(0.32)
	elif stance == Stance.SURFACE:
		c_base = Color("#34d399").lerp(Color("#a3e635"), wave * 0.65)
		c_hi = Color("#fef08a").lerp(Color("#a7f3d0"), 1.0 - wave)
		c_dark = Color("#047857")
	else:
		c_base = Color("#8b5cf6").lerp(Color("#2dd4bf"), wave * 0.55)
		c_hi = Color("#ddd6fe").lerp(Color("#99f6e4"), wave)
		c_dark = Color("#4c1d95")

	# 3D 投影八面体 4 个侧面实时旋转（60fps 绝对丝滑！）
	var rot_spd: float = 1.65 if is_idle_now else 2.6
	var yaw: float = t * rot_spd
	var rx: float = 14.5 if is_idle_now else 11.5
	var ry: float = 21.0 if is_idle_now else 16.5
	var top_p := pos + Vector2(0.0, -ry)
	var bot_p := pos + Vector2(0.0, ry)
	var mid_x: float = sin(yaw) * rx
	var left_p := pos + Vector2(-rx, 0.0)
	var right_p := pos + Vector2(rx, 0.0)
	var ridge_p := pos + Vector2(mid_x, 2.5 * cos(yaw))

	# 左侧上下两切面
	draw_colored_polygon(PackedVector2Array([top_p, ridge_p, left_p]), c_hi)
	draw_colored_polygon(PackedVector2Array([bot_p, left_p, ridge_p]), c_base)
	# 右侧上下两切面
	draw_colored_polygon(PackedVector2Array([top_p, right_p, ridge_p]), c_base.lightened(0.12))
	draw_colored_polygon(PackedVector2Array([bot_p, ridge_p, right_p]), c_dark)

	# 3 颗 60fps 椭圆轨道绕转的微小低多边形菱形碎片
	for i in range(3):
		var a: float = yaw * 1.25 + float(i) * (TAU / 3.0)
		var sp := pos + Vector2(cos(a) * (rx + 9.0), sin(a) * 10.5)
		var sc: float = 3.6 if sin(a) >= 0.0 else 2.4
		var shard_col: Color = c_hi if (i % 2 == 0) else c_base
		draw_colored_polygon(PackedVector2Array([
			sp + Vector2(0.0, -sc * 1.4),
			sp + Vector2(sc, 0.0),
			sp + Vector2(0.0, sc * 1.4),
			sp + Vector2(-sc, 0.0)
		]), Color(shard_col.r, shard_col.g, shard_col.b, 0.92))
