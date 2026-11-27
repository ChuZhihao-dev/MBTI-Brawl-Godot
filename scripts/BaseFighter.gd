extends CharacterBody2D
class_name BaseFighter

const PaintBlobProjectileScene = preload("res://scripts/PaintBlobProjectile.gd")
const PaintPuddleHazardScene = preload("res://scripts/PaintPuddleHazard.gd")

signal ko_triggered(fighter: BaseFighter, killer: BaseFighter, by_ultimate: bool)

@export var player_index: int = 1
@export var fighter_id: String = "enfj"
@export var fighter_name: String = "ENFJ"
@export var theme_color: Color = Color("#10b981")
@export var max_hp: int = 110
@export var move_speed: float = 330.0
@export var jump_force: float = 650.0
@export var gravity_force: float = 1650.0
@export var portrait_texture: Texture2D
@export var target_sprite_height: float = 132.0
@export var sprite_scale_mult: float = 1.0
@export var sprite_y_offset: float = 0.0

var hp: int = 110
var ep: float = 0.0
var facing: int = 1
var is_ko: bool = false
var battle_locked: bool = false

# AI 接管支持（任意角色自动支持 1P vs AI 对战）
var is_ai_controlled: bool = false
var practice_full_energy := false
var practice_last_damage := 0
var practice_best_hits := 0
var practice_best_damage := 0
var practice_skip_skill_cooldowns := false
var ai_input: Dictionary = {}

# 战斗手感与进阶机制（二段跳、土狼时间、输入缓冲、完美格挡、连击统计）
var air_jumps_left: int = 1
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var attack_buffer_type: String = ""
var attack_buffer_timer: float = 0.0
var parry_window_timer: float = 0.0
var _was_guard_held: bool = false

var current_combo_hits: int = 0
var current_combo_damage: int = 0
var _combo_expire_timer: float = 0.0

# 传统大乱斗深度机制：护盾耐久/破防、快落/空砸、墙角弹墙、受身
var shield_hp: float = 100.0
var shield_broken_timer: float = 0.0
var fast_falling: bool = false
var air_slamming: bool = false
var _tech_window_timer: float = 0.0
var _wall_bounced_in_stun: bool = false

var dash_timer: float = 0.0
var dash_cd: float = 0.0
var dash_dir: int = 1
var dash_ghost_timer: float = 0.0
var invincible_timer: float = 0.0
var super_armor_timer: float = 0.0
var can_hit_cancel: bool = false
var hitstun_timer: float = 0.0
var hit_flash_timer: float = 0.0
var block_hit_timer: float = 0.0
var jump_startup_timer: float = 0.0
var landing_timer: float = 0.0
var action_anim_timer: float = 0.0
var action_anim_state: String = ""
var can_cancel_attack: bool = false
var has_hit_target_in_attack: bool = false
var light_attack_hit_registered: bool = false
var heavy_attack_hit_registered: bool = false
var isfp_startup_step_timer: float = 0.0
var isfp_light_active: bool = false
var isfp_heavy_active: bool = false
var isfp_skill1_active: bool = false
var isfp_skill1_projectile_spawned: bool = false
var paint_slow_timer: float = 0.0
var paint_slow_mult: float = 1.0
var paint_slip_timer: float = 0.0
var paint_slip_dir: float = 0.0
var skill1_buffer_timer: float = 0.0
var guarding: bool = false
var basic_cd: float = 0.0
var skill1_cd: float = 0.0
var skill2_cd: float = 0.0
var _was_on_floor: bool = true

# 精灵表动画播放器状态
var _sheet_configs: Dictionary = {}
var _sheet_textures: Dictionary = {}
var _current_anim: String = ""
var _anim_time: float = 0.0
var _base_sprite_scale: Vector2 = Vector2.ONE
var _juice_scale: Vector2 = Vector2.ONE
var _juice_rot: float = 0.0
var _breath_time: float = 0.0

# 三档蓄力状态机（U/4 与 I/5 通用）
var _charge_particles: Array[Dictionary] = []
var _charge_particle_timer: float = 0.0
var charging_slot: String = ""
var charge_elapsed: float = 0.0
var charge_level: int = 1
var charge_dir: String = "neutral"
var _last_charge_level: int = 1
var current_attack_damage: int = 10
var current_attack_knockback: Vector2 = Vector2.ZERO
var current_attack_is_ult: bool = false
var hitbox_active_timer: float = 0.0

# 记录 BaseFighter 初始默认的 Hitbox 尺寸与偏移（供未定制角色的普攻使用）
var default_hitbox_size: Vector2 = Vector2(48.0, 40.0)
var default_hitbox_pos: Vector2 = Vector2(40.0, -48.0)

var paint_counter_knockback := false
@onready var paint_counter = get_node_or_null("PaintCounter")

var isfp_ultimate_owner: BaseFighter
@onready var paint_ultimate = get_node_or_null("PaintUltimate")

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox_col: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var hitbox_shape: RectangleShape2D = $Hitbox/CollisionShape2D.shape as RectangleShape2D
@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
var rig: FighterRig = null

func _ready() -> void:
	hp = max_hp
	facing = 1 if player_index == 1 else -1

	# 记录在 BaseFighter 编辑器中绘制的初始 Hitbox 尺寸与位置，并确保开局禁用
	if hitbox_shape:
		default_hitbox_size = hitbox_shape.size
	if hitbox_col:
		default_hitbox_pos = hitbox_col.position
		hitbox_col.disabled = true

	load_fighter_sprites(fighter_id)
	_update_facing_visual()

func load_fighter_sprites(fid: String) -> void:
	fighter_id = fid
	var rig_dir: String = "res://assets/fighters/%s/rig" % fid
	if ResourceLoader.exists(rig_dir + "/head.png"):
		if rig == null:
			rig = FighterRig.new()
			rig.name = "FighterRig"
			add_child(rig)
		rig.theme_color = theme_color
		rig.load_parts(rig_dir)
		rig.set_facing(facing)
		rig.visible = true
		if sprite:
			sprite.visible = false
		_play_anim("idle", true)
		return
	elif rig != null:
		rig.visible = false
		if sprite:
			sprite.visible = true

	# 如果本角色已经在场景里使用 AnimationPlayer 编排了专属动画，自动校准缩放并跳过旧系统的强行换图！
	if anim_player != null:
		if sprite and sprite.texture:
			var rows: float = float(maxi(1, sprite.vframes))
			var frame_h: float = sprite.texture.get_size().y / rows
			var sc: float = (target_sprite_height / maxf(1.0, frame_h)) * sprite_scale_mult
			_base_sprite_scale = Vector2(sc, sc)
			sprite.scale = _base_sprite_scale
			sprite.position = Vector2(0.0, -target_sprite_height * 0.5 + sprite_y_offset)
		_play_anim("idle", true)
		return

	_sheet_configs = GameManager.get_sprite_config(fid)
	if _sheet_configs.is_empty():
		var avatar_sheet_path := "res://assets/fighters/%s/concept/avatar_sheet.png" % fid
		if ResourceLoader.exists(avatar_sheet_path):
			_sheet_configs = {
				"idle": {"path": avatar_sheet_path, "cols": 8, "rows": 8, "start": 0, "frames": 64, "fps": 22.0, "loop": true}
			}
	_sheet_textures.clear()
	for state_name in _sheet_configs.keys():
		var cfg: Dictionary = _sheet_configs[state_name] as Dictionary
		var p: String = String(cfg["path"])
		if ResourceLoader.exists(p):
			_sheet_textures[state_name] = load(p) as Texture2D
	_current_anim = ""
	if _sheet_textures.is_empty():
		var tex: Texture2D = GameManager.get_portrait_texture(fid)
		if tex == null:
			tex = portrait_texture
		if tex and sprite:
			sprite.texture = tex
			sprite.hframes = 1
			sprite.vframes = 1
			sprite.frame = 0
			if sprite.material is ShaderMaterial:
				(sprite.material as ShaderMaterial).set_shader_parameter("enable_white_key", 0.0)
			var sc: float = target_sprite_height / maxf(1.0, tex.get_size().y)
			_base_sprite_scale = Vector2(sc, sc)
			sprite.scale = _base_sprite_scale
			sprite.position = Vector2(0.0, -target_sprite_height * 0.5)
	else:
		_play_anim("idle", true)

func trigger_squash(sx: float, sy: float) -> void:
	_juice_scale = Vector2(sx, sy)

func spawn_slash_arc(start_deg: float, end_deg: float, radius: float, color: Color, duration: float = 0.16, _thickness: float = 26.0) -> void:
	var vfx := BattleVFX.get_current(get_tree())
	if vfx:
		vfx.spawn_slash_arc(global_position + Vector2(facing * 20.0, -56.0), start_deg, end_deg, radius, color, duration, facing)

func get_active_buff_status() -> String:
	if shield_broken_timer > 0.0:
		return "破防眩晕 %.1fs" % shield_broken_timer
	return ""

func reset_for_new_round(spawn_pos: Vector2, keep_ep_ratio: float = 0.3) -> void:
	if paint_counter != null:
		paint_counter.finish()
	paint_counter_knockback = false
	if paint_ultimate != null:
		paint_ultimate.finish()
	isfp_ultimate_owner = null
	hp = max_hp
	ep = 100.0 if practice_full_energy else clampf(ep * keep_ep_ratio, 0.0, 100.0)
	shield_hp = 100.0
	shield_broken_timer = 0.0
	is_ko = false
	guarding = false
	charging_slot = ""
	_charge_particles.clear()
	_charge_particle_timer = 0.0
	charge_elapsed = 0.0
	charge_level = 1
	_last_charge_level = 1
	fast_falling = false
	air_slamming = false
	_tech_window_timer = 0.0
	_wall_bounced_in_stun = false
	hitstun_timer = 0.0
	hit_flash_timer = 0.0
	block_hit_timer = 0.0
	dash_timer = 0.0
	dash_cd = 0.0
	invincible_timer = 0.0
	super_armor_timer = 0.0
	basic_cd = 0.0
	skill1_cd = 0.0
	skill2_cd = 0.0
	action_anim_timer = 0.0
	action_anim_state = ""
	can_cancel_attack = false
	can_hit_cancel = false
	isfp_light_active = false
	isfp_heavy_active = false
	isfp_skill1_active = false
	isfp_skill1_projectile_spawned = false
	paint_slow_timer = 0.0
	paint_slow_mult = 1.0
	paint_slip_timer = 0.0
	paint_slip_dir = 0.0
	skill1_buffer_timer = 0.0
	light_attack_hit_registered = false
	heavy_attack_hit_registered = false
	current_combo_hits = 0
	current_combo_damage = 0
	_combo_expire_timer = 0.0
	GameManager.combo_updated.emit(player_index, 0, 0)
	velocity = Vector2.ZERO
	global_position = spawn_pos
	facing = 1 if player_index == 1 else -1
	_update_facing_visual()
	if sprite and sprite.material is ShaderMaterial:
		(sprite.material as ShaderMaterial).set_shader_parameter("flash_amount", 0.0)
	if sprite:
		sprite.offset = Vector2.ZERO
	if hitbox_col:
		hitbox_col.disabled = true
	_play_anim("idle", true)
	queue_redraw()

func _play_anim(state_name: String, force_reset: bool = false) -> void:
	if rig != null and rig.visible:
		rig.play_state(state_name, force_reset, maxf(0.22, action_anim_timer))
		return
	# ----------------- 【AnimationPlayer 优先通道】 -----------------
	if anim_player and anim_player.has_animation(state_name):
		# 蓄力动画播完后保留末帧，直到战斗状态切换。
		if fighter_id == "isfp" and state_name in ["skill1_charge", "skill1"] and anim_player.assigned_animation == state_name and not force_reset:
			return
		# 如果当前已经在播放这个动画，且没有要求强制重播，就让它继续播，不要每帧打断！
		if anim_player.current_animation == state_name and anim_player.is_playing() and not force_reset:
			return
		anim_player.play(state_name)
		# 核心关键：立即将动画推进一步（advance(0)），让 AnimationPlayer 的第 0 秒贴图和切片轨道立即生效！
		anim_player.advance(0.0)

		# 此时 sprite.texture 已经是新动画切换后的正式图片了，再进行缩放与踩地高度校准！
		if sprite and sprite.texture:
			var tex_path: String = sprite.texture.resource_path.to_lower()
			var rows: float = float(maxi(1, sprite.vframes))
			var frame_h: float = sprite.texture.get_size().y / rows
			var mult: float = sprite_scale_mult
			var y_off: float = sprite_y_offset

			if tex_path.ends_with("jump.png") or state_name == "jump" or state_name == "fall":
				# jump/fall 序列帧人物实际躯干占高 ~288px，统一缩放到与 stand(407px)/move(317px) 完全一致的视觉比例！
				mult = sprite_scale_mult * (407.0 / 288.0)
				y_off = -17.0
			elif rows > 1.0 or tex_path.ends_with("move.png") or tex_path.ends_with("fighter_light.png") or tex_path.ends_with("fighter_thump.png") or tex_path.ends_with("u.png") or state_name == "walk" or state_name == "light" or state_name == "heavy" or state_name == "skill1" or state_name == "skill1_charge":
				# move.png, fighter_light.png 与 fighter_thump.png 躯干高度 ~313-318px / 362px
				mult = sprite_scale_mult * (407.0 / 724.0) / (318.0 / 362.0)
				y_off = sprite_y_offset * 0.4
			else:
				# stand.png 躯干高度 407px / 724px
				mult = sprite_scale_mult
				y_off = sprite_y_offset

			var sc: float = (target_sprite_height / maxf(1.0, frame_h)) * mult
			_base_sprite_scale = Vector2(sc, sc)
			sprite.scale = _base_sprite_scale
			sprite.position = Vector2(0.0, -target_sprite_height * 0.5 + y_off)
		return
	# ---------------------------------------------------------------
	if _sheet_textures.is_empty() or sprite == null:
		return
	var target: String = state_name if _sheet_textures.has(state_name) else "idle"
	if not _sheet_textures.has(target):
		return
	if _current_anim == target and not force_reset:
		return
	_current_anim = target
	_anim_time = 0.0
	var cfg: Dictionary = _sheet_configs[target] as Dictionary
	var tex: Texture2D = _sheet_textures[target] as Texture2D
	var cols: int = int(cfg["cols"])
	var rows: int = int(cfg["rows"])
	sprite.texture = tex
	sprite.hframes = cols
	sprite.vframes = rows
	sprite.frame = int(cfg.get("start", 0))
	if sprite.material is ShaderMaterial:
		var is_jpg: bool = String(cfg["path"]).to_lower().ends_with(".jpg") or String(cfg["path"]).to_lower().ends_with(".jpeg")
		(sprite.material as ShaderMaterial).set_shader_parameter("enable_white_key", 1.0 if is_jpg else 0.0)
	var cell_h: float = tex.get_size().y / float(rows)
	var sc: float = target_sprite_height / maxf(1.0, cell_h)
	_base_sprite_scale = Vector2(sc, sc)
	sprite.scale = _base_sprite_scale
	sprite.position = Vector2(0.0, -target_sprite_height * 0.5)

func _advance_anim(delta: float) -> void:
	# 【核心修复】：如果当前 AnimationPlayer 正在播放动画，直接返回，绝不插手覆盖帧！
	if anim_player and anim_player.is_playing():
		return
	if _sheet_textures.is_empty() or _current_anim == "" or sprite == null:
		return
	var cfg: Dictionary = _sheet_configs[_current_anim] as Dictionary
	_anim_time += delta
	var total: int = maxi(1, int(cfg["frames"]))
	var fps: float = float(cfg["fps"])
	var raw_idx: int = int(floor(_anim_time * fps))
	var idx: int = 0
	if bool(cfg.get("loop", true)):
		var loop_start: int = clampi(int(cfg.get("loop_start", 0)), 0, total - 1)
		if raw_idx < total:
			idx = raw_idx
		else:
			var loop_len: int = maxi(1, total - loop_start)
			idx = loop_start + ((raw_idx - loop_start) % loop_len)
	else:
		idx = mini(total - 1, raw_idx)
	sprite.frame = int(cfg.get("start", 0)) + idx

func _act(suffix: String) -> String:
	return ("p1_" if player_index == 1 else "p2_") + suffix

func _is_move_key_held(action: String) -> bool:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		if key.physical_keycode != 0 and Input.is_physical_key_pressed(key.physical_keycode):
			return true
		if key.keycode != 0 and Input.is_key_pressed(key.keycode):
			return true
	return false

func _read_inputs() -> Dictionary:
	if is_ai_controlled:
		return {
			"horiz": float(ai_input.get("horiz", 0.0)),
			"up_held": bool(ai_input.get("up_held", false)),
			"up_just": bool(ai_input.get("up_just", false)),
			"guard_held": bool(ai_input.get("guard_held", false)),
			"light_just": bool(ai_input.get("light_just", false)),
			"heavy_just": bool(ai_input.get("heavy_just", false)),
			"dash_just": bool(ai_input.get("dash_just", false)),
			"skill1_held": bool(ai_input.get("skill1_held", false)),
			"skill1_just": bool(ai_input.get("skill1_just", false)),
			"skill2_held": bool(ai_input.get("skill2_held", false)),
			"skill2_just": bool(ai_input.get("skill2_just", false)),
			"ult_just": bool(ai_input.get("ult_just", false))
		}
	var left_action := _act("left")
	var right_action := _act("right")
	var filtered_horiz: float = 0.0
	if player_index == 1:
		# 按当前键位读取实际按住的方向，避免动作状态残留造成持续走动。
		filtered_horiz = float(_is_move_key_held(right_action)) - float(_is_move_key_held(left_action))
	else:
		var is_left := Input.is_action_pressed(left_action)
		var is_right := Input.is_action_pressed(right_action)
		if is_left != is_right:
			filtered_horiz = float(is_right) - float(is_left)
		elif is_left:
			var raw_horiz := Input.get_axis(left_action, right_action)
			filtered_horiz = raw_horiz if absf(raw_horiz) > 0.15 else 0.0

	return {
		"horiz": filtered_horiz,
		"up_held": Input.is_action_pressed(_act("up")),
		"up_just": Input.is_action_just_pressed(_act("up")),
		"guard_held": Input.is_action_pressed(_act("guard")),
		"light_just": Input.is_action_just_pressed(_act("light")),
		"heavy_just": Input.is_action_just_pressed(_act("heavy")),
		"dash_just": Input.is_action_just_pressed(_act("dash")),
		"skill1_held": Input.is_action_pressed(_act("skill1")),
		"skill1_just": Input.is_action_just_pressed(_act("skill1")),
		"skill2_held": Input.is_action_pressed(_act("skill2")),
		"skill2_just": Input.is_action_just_pressed(_act("skill2")),
		"ult_just": Input.is_action_just_pressed(_act("ult"))
	}

func set_practice_skill_cooldowns(enabled: bool) -> void:
	practice_skip_skill_cooldowns = not enabled
	if practice_skip_skill_cooldowns:
		skill1_cd = 0.0
		skill2_cd = 0.0

func clear_practice_dummy_input() -> void:
	ai_input.clear()
	guarding = false
	charging_slot = ""
	_charge_particles.clear()
	attack_buffer_timer = 0.0
	jump_buffer_timer = 0.0
	skill1_buffer_timer = 0.0
	if dash_timer > 0.0:
		dash_timer = 0.0
		velocity.x = 0.0

func _get_effective_move_speed() -> float:
	var spd: float = move_speed
	if paint_slow_timer > 0.0:
		spd *= paint_slow_mult
	return spd

func _get_attack_speed_mult() -> float:
	return 1.0

func _get_melee_range_bonus() -> float:
	return 0.0

func _update_hit_flash(delta: float) -> void:
	if hit_flash_timer <= 0.0:
		return
	hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
	if rig != null and rig.visible:
		rig.set_flash(1.0 if hit_flash_timer > 0.0 else 0.0, Color.WHITE)
	elif sprite:
		if sprite.material is ShaderMaterial:
			sprite.material.set_shader_parameter("flash_amount", 1.0 if hit_flash_timer > 0.0 else 0.0)
		sprite.offset.x = sin(Time.get_ticks_msec() * 0.09) * 5.0 if hit_flash_timer > 0.0 else 0.0

func _physics_process(delta: float) -> void:
	dash_timer = maxf(0.0, dash_timer - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	dash_ghost_timer = maxf(0.0, dash_ghost_timer - delta)
	invincible_timer = maxf(0.0, invincible_timer - delta)
	super_armor_timer = maxf(0.0, super_armor_timer - delta)
	hitstun_timer = maxf(0.0, hitstun_timer - delta)
	block_hit_timer = maxf(0.0, block_hit_timer - delta)
	jump_startup_timer = maxf(0.0, jump_startup_timer - delta)
	landing_timer = maxf(0.0, landing_timer - delta)
	basic_cd = maxf(0.0, basic_cd - delta)
	if basic_cd <= 0.0:
		can_hit_cancel = false
	skill1_cd = maxf(0.0, skill1_cd - delta)
	skill2_cd = maxf(0.0, skill2_cd - delta)
	action_anim_timer = maxf(0.0, action_anim_timer - delta)
	skill1_buffer_timer = maxf(0.0, skill1_buffer_timer - delta)
	if paint_slow_timer > 0.0:
		paint_slow_timer = maxf(0.0, paint_slow_timer - delta)
		if paint_slow_timer <= 0.0:
			paint_slow_mult = 1.0
	if paint_slip_timer > 0.0:
		paint_slip_timer = maxf(0.0, paint_slip_timer - delta)
		if is_on_floor():
			velocity.x = move_toward(velocity.x, paint_slip_dir * 180.0, 900.0 * delta)
	if isfp_startup_step_timer > 0.0:
		isfp_startup_step_timer = maxf(0.0, isfp_startup_step_timer - delta)
		if is_on_floor() and absf(velocity.x) < 220.0:
			velocity.x = facing * 120.0

	# ---------------------------------------------------------------
	# 攻击判定生效窗口（Active）与取消窗口（Cancel Window）
	# ---------------------------------------------------------------
	if action_anim_state == "light" and isfp_light_active:
		var elapsed_time: float = 0.20 - action_anim_timer
		# 第 7-9 帧（0.10s <= t <= 0.15s）：激活稳定单次轻击判定
		if elapsed_time >= 0.10 and elapsed_time <= 0.15 and not light_attack_hit_registered:
			_check_isfp_light_hitbox()
		# 取消窗口：从第 8 帧（命中确认后）或后摇阶段（第 8-12 帧，t >= 0.116s）允许立即派生取消
		if elapsed_time >= 0.116 or has_hit_target_in_attack:
			can_cancel_attack = true
	elif action_anim_state == "heavy" and isfp_heavy_active:
		var elapsed_heavy: float = 0.38 - action_anim_timer
		# 重击判定生效期（第 5-8 帧，0.17s <= t <= 0.31s）：向前重击覆盖
		if elapsed_heavy >= 0.17 and elapsed_heavy <= 0.31 and not heavy_attack_hit_registered:
			_check_isfp_heavy_hitbox()
		# 重击取消窗口：命中确认后（On-Hit Cancel）或后摇阶段（第 10 帧起，t >= 0.33s）允许衔接 dash、技能与大招
		if elapsed_heavy >= 0.33 or has_hit_target_in_attack:
			can_cancel_attack = true
	elif action_anim_state == "skill1" and isfp_skill1_active:
		# 第 5-8 帧准时生成投射物
		if (action_anim_timer <= 0.134 or isfp_skill1_projectile_spawned) and not isfp_skill1_projectile_spawned:
			_spawn_isfp_paint_blob()
		# 收招与取消（最后 3 帧，剩余时间 <= 0.05s 时对应第 10-12 帧）：开放提前取消窗口
		if action_anim_timer <= 0.05:
			can_cancel_attack = true
	elif (action_anim_state == "light" or action_anim_state == "heavy" or action_anim_state == "skill1") and has_hit_target_in_attack:
		can_cancel_attack = true
	elif action_anim_timer <= 0.0:
		can_cancel_attack = false
		isfp_light_active = false
		isfp_heavy_active = false
		isfp_skill1_active = false
		isfp_skill1_projectile_spawned = false
		light_attack_hit_registered = false
		heavy_attack_hit_registered = false
	coyote_timer = maxf(0.0, coyote_timer - delta)
	jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)
	attack_buffer_timer = maxf(0.0, attack_buffer_timer - delta)
	parry_window_timer = maxf(0.0, parry_window_timer - delta)
	_tech_window_timer = maxf(0.0, _tech_window_timer - delta)
	if hitstun_timer <= 0.0:
		_wall_bounced_in_stun = false
	if shield_broken_timer > 0.0:
		shield_broken_timer = maxf(0.0, shield_broken_timer - delta)
		if shield_broken_timer <= 0.0:
			shield_hp = 55.0

	if _combo_expire_timer > 0.0:
		_combo_expire_timer = maxf(0.0, _combo_expire_timer - delta)
		if _combo_expire_timer <= 0.0:
			current_combo_hits = 0
			current_combo_damage = 0
			GameManager.combo_updated.emit(player_index, 0, 0)

	_update_hit_flash(delta)
	if paint_counter != null and (battle_locked or is_ko):
		paint_counter.finish()

	if paint_ultimate != null and paint_ultimate.active:
		return
	if is_instance_valid(isfp_ultimate_owner) and not is_ko and not battle_locked:
		_play_anim("hit")
		queue_redraw()
		return

	# 攻击框生效时间倒计时，时间一到自动关闭 Hitbox
	if hitbox_active_timer > 0.0:
		hitbox_active_timer -= delta
		if hitbox_active_timer <= 0.0 and hitbox_col:
			hitbox_col.disabled = true

	if rig != null and rig.visible:
		rig.move_velocity = velocity
		rig.is_grounded = is_on_floor()

	if is_ko:
		guarding = false
		charging_slot = ""
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		if not is_on_floor():
			velocity.y += gravity_force * delta
		move_and_slide()
		global_position.x = clampf(global_position.x, 220.0, 1580.0)
		if (rig != null and rig.visible) or _sheet_textures.has("ko"):
			_play_anim("ko")
		elif _sheet_textures.has("hit"):
			_play_anim("hit")
		_advance_anim(delta)
		queue_redraw()
		return

	if battle_locked:
		guarding = false
		charging_slot = ""
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
		if not is_on_floor():
			velocity.y += gravity_force * delta
		move_and_slide()
		_play_anim("idle")
		_advance_anim(delta)
		queue_redraw()
		return

	if is_on_floor():
		coyote_timer = 0.10
		air_jumps_left = 1

	var inp: Dictionary = _read_inputs()
	var can_act: bool = hitstun_timer <= 0.0 and shield_broken_timer <= 0.0
	var horiz: float = float(inp["horiz"])
	var guard_held: bool = bool(inp["guard_held"])
	var up_pressed: bool = bool(inp["up_just"])
	var up_held: bool = bool(inp["up_held"])

	if paint_counter != null:
		if paint_counter.active:
			if paint_counter.tick(delta, inp):
				queue_redraw()
				return
		elif can_act and bool(inp["skill2_just"]) and skill2_cd <= 0.0 and dash_timer <= 0.0 and charging_slot == "" and (action_anim_timer <= 0.0 or can_cancel_attack):
			paint_counter.start()
			paint_counter.tick(delta, inp)
			queue_redraw()
			return

	# 受击硬直期间按下闪避键（L/3）预存受身窗口，落地瞬间触发无敌受身翻滚
	if hitstun_timer > 0.0 and bool(inp["dash_just"]):
		_tech_window_timer = 0.18

	if up_pressed:
		jump_buffer_timer = 0.12
	if bool(inp["light_just"]):
		attack_buffer_type = "light"
		attack_buffer_timer = 0.14
	elif bool(inp["heavy_just"]):
		attack_buffer_type = "heavy"
		attack_buffer_timer = 0.14
	if bool(inp["skill1_just"]):
		skill1_buffer_timer = 0.10 # 4-5 帧预输入缓冲队列

	if guard_held and not _was_guard_held and is_on_floor() and can_act and shield_hp > 0.0:
		parry_window_timer = 0.14
	_was_guard_held = guard_held

	# 0. 必杀大招（O / 6，满 100 能量可释放，可从普攻/重击命中确认取消中顺畅派生）
	if can_act and charging_slot == "" and dash_timer <= 0.0 and ep >= 100.0 and bool(inp["ult_just"]):
		if can_cancel_attack and (action_anim_state == "light" or action_anim_state == "heavy" or action_anim_state == "skill1"):
			action_anim_timer = 0.0
			action_anim_state = ""
			can_cancel_attack = false
		ep = 100.0 if practice_full_energy else 0.0
		guarding = false
		on_ultimate_cast()
		if paint_ultimate != null and paint_ultimate.active:
			return
	# 1. 蓄力小技能处理（支持方向键派生，或由普攻/重击取消窗口提前中断后摇派生）
	elif _process_charge_skill(delta, can_act, horiz, guard_held, up_held, inp):
		if can_cancel_attack and (action_anim_state == "light" or action_anim_state == "heavy" or action_anim_state == "skill1"):
			action_anim_timer = 0.0
			action_anim_state = ""
			can_cancel_attack = false
		velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
	elif can_act:
		# 攻击后摇取消窗口：允许立即取消并衔接 dash（闪避）
		var allow_dash_cancel: bool = can_cancel_attack and (action_anim_state == "light" or action_anim_state == "heavy" or action_anim_state == "skill1") and bool(inp["dash_just"])
		if allow_dash_cancel:
			action_anim_timer = 0.0
			action_anim_state = ""
			can_cancel_attack = false

		# 2. 单向平台下+跳快速穿落 / 护盾防御（带护盾耐久消耗与破防）
		if is_on_floor() and guard_held and up_pressed and global_position.y < 520.0:
			global_position.y += 8.0
			jump_buffer_timer = 0.0
		else:
			guarding = is_on_floor() and guard_held and dash_timer <= 0.0 and shield_hp > 0.0 and shield_broken_timer <= 0.0

		# 2.5 空中快速下落（Fast-Fall）与空中下砸（Down-Slam：空中 S/↓ + 重击）
		if not is_on_floor() and charging_slot == "" and dash_timer <= 0.0:
			if guard_held and bool(inp["heavy_just"]) and not air_slamming and basic_cd <= 0.0:
				air_slamming = true
				fast_falling = false
				attack_buffer_timer = 0.0
				basic_cd = 0.55
				action_anim_state = "heavy"
				action_anim_timer = 0.45
				velocity = Vector2(facing * 120.0, 960.0)
				trigger_squash(0.76, 1.30)
				_play_anim("heavy", true)
				AudioManager.play_sfx("air_slam", -2.5)
			elif guard_held and velocity.y > 40.0 and not fast_falling and not air_slamming:
				fast_falling = true
				velocity.y = maxf(velocity.y, 460.0)

		# 3. 冲刺 / 闪避（L / 3）
		if bool(inp["dash_just"]) and dash_cd <= 0.0 and not guarding:
			dash_dir = int(signf(horiz)) if horiz != 0.0 else facing
			facing = dash_dir
			dash_timer = 0.22
			dash_cd = 0.85
			invincible_timer = 0.16
			dash_ghost_timer = 0.0
			trigger_squash(1.22, 0.84)
			_update_facing_visual()
			AudioManager.play_sfx("dash", -4.0, randf_range(0.95, 1.08))
			var vfx := BattleVFX.get_current(get_tree())
			if vfx:
				vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -32.0), theme_color, 8.0, 48.0, 0.18, 3.0)

		# 4. 水平移动、土狼跳与二段跳
		var eff_speed: float = _get_effective_move_speed()
		if dash_timer > 0.0:
			velocity.x = dash_dir * eff_speed * 2.2
			# 冲刺取消：冲刺中段可直接取消派生轻/重击！
			if dash_timer < 0.16 and basic_cd <= 0.0 and attack_buffer_timer > 0.0:
				dash_timer = 0.0
				attack_buffer_timer = 0.0
				if attack_buffer_type == "light":
					_perform_light_attack()
				else:
					_perform_heavy_attack()
			elif dash_ghost_timer <= 0.0:
				dash_ghost_timer = 0.042
				var vfx := BattleVFX.get_current(get_tree())
				if vfx:
					if rig != null and rig.visible:
						rig.spawn_ghost_into(vfx, theme_color, 0.22)
					else:
						vfx.spawn_ghost(sprite, theme_color, 0.22)
		elif not guarding:
			# 普攻前摇阶段（Startup 第 1-6 帧）与重击起手允许角色微调朝向与微量惯性移动；其余攻击动作锁死转向
			var in_light_startup: bool = action_anim_state == "light" and isfp_light_active and (0.20 - action_anim_timer < 0.10)
			var in_heavy_startup: bool = action_anim_state == "heavy" and isfp_heavy_active and (0.38 - action_anim_timer < 0.12)
			var in_skill1_startup: bool = action_anim_state == "skill1" and isfp_skill1_active and (0.20 - action_anim_timer < 0.067)
			var can_move_facing: bool = action_anim_timer <= 0.0 or in_light_startup or in_heavy_startup or in_skill1_startup
			if horiz != 0.0:
				if can_move_facing:
					facing = int(signf(horiz))
					_update_facing_visual()
				if action_anim_timer <= 0.0:
					velocity.x = horiz * eff_speed
				elif in_light_startup or in_heavy_startup or in_skill1_startup:
					velocity.x = move_toward(velocity.x, horiz * eff_speed * 0.45, 1200.0 * delta)
				else:
					velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
			elif player_index == 1 and not is_ai_controlled and action_anim_timer <= 0.0:
				velocity.x = 0.0
			else:
				velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
			if absf(velocity.x) < 5.0 and horiz == 0.0:
				velocity.x = 0.0
			# 地面跳（含土狼时间 + 跳跃缓冲）
			if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
				velocity.y = -jump_force
				coyote_timer = 0.0
				jump_buffer_timer = 0.0
				jump_startup_timer = 0.14
				trigger_squash(0.84, 1.18)
				AudioManager.play_sfx("swing_light", -10.0, 1.35)
				_play_anim("jump", true)
			# 空中二段跳
			elif up_pressed and not is_on_floor() and air_jumps_left > 0:
				air_jumps_left -= 1
				velocity.y = -jump_force * 0.90
				jump_buffer_timer = 0.0
				jump_startup_timer = 0.12
				trigger_squash(0.86, 1.18)
				AudioManager.play_sfx("jump_double", -5.0, randf_range(0.96, 1.08))
				_play_anim("jump", true)
				var vfx := BattleVFX.get_current(get_tree())
				if vfx:
					vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -8.0), Color("#e2e8f0"), 10.0, 56.0, 0.22, 3.0)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)

		# 5. 普攻（J/1）与重击（K/2）（带预输入缓冲 + 命中取消重击派生）
		var allow_light_cancel: bool = can_cancel_attack and action_anim_state == "light" and attack_buffer_timer > 0.0 and basic_cd <= 0.0
		var allow_heavy_cancel: bool = can_cancel_attack and action_anim_state == "heavy" and attack_buffer_timer > 0.0 and basic_cd <= 0.0
		var allow_hit_heavy_cancel: bool = can_hit_cancel and attack_buffer_timer > 0.0 and attack_buffer_type == "heavy"
		if (not guarding and dash_timer <= 0.0 and basic_cd <= 0.0 and attack_buffer_timer > 0.0) or allow_light_cancel or allow_heavy_cancel or allow_hit_heavy_cancel:
			if allow_light_cancel or allow_heavy_cancel or allow_hit_heavy_cancel:
				action_anim_timer = 0.0
				action_anim_state = ""
				can_cancel_attack = false
				can_hit_cancel = false
			attack_buffer_timer = 0.0
			if attack_buffer_type == "light":
				_perform_light_attack()
			else:
				_perform_heavy_attack()
	else:
		guarding = false
		# 空中受击方向影响（DI）：受击硬直时按左右方向微调击飞轨迹
		if hitstun_timer > 0.0 and horiz != 0.0:
			velocity.x += horiz * 280.0 * delta
		if paint_counter_knockback and hitstun_timer > 0.0:
			velocity.x *= pow(0.84, delta * 60.0)
		else:
			paint_counter_knockback = false
			velocity.x = move_toward(velocity.x, 0.0, 620.0 * delta)

	# 护盾耐久消耗与自动恢复
	if guarding:
		shield_hp = maxf(0.0, shield_hp - 18.0 * delta)
		if shield_hp <= 0.0:
			_trigger_shield_break()
	elif shield_broken_timer <= 0.0:
		shield_hp = minf(100.0, shield_hp + 16.0 * delta)

	# 重力与移动碰撞（支持快落 1.65x 与空砸 1.35x 重力）
	if not is_on_floor():
		var grav_mult: float = 1.65 if fast_falling else (1.35 if air_slamming else 1.0)
		velocity.y += gravity_force * grav_mult * delta
	move_and_slide()

	# 墙角弹墙（Wall Bounce）：高速受击撞到舞台左右边界时触发反弹连段机会
	if hitstun_timer > 0.0 and not paint_counter_knockback and not _wall_bounced_in_stun and (global_position.x <= 224.0 or global_position.x >= 1576.0) and absf(velocity.x) > 340.0:
		_wall_bounced_in_stun = true
		velocity.x = -velocity.x * 0.72
		velocity.y = minf(velocity.y, -280.0)
		hitstun_timer += 0.16
		trigger_squash(0.75, 1.28)
		AudioManager.play_sfx("wall_bounce", -2.0)
		GameManager.trigger_shake(7.5, 0.14, Vector2(signf(velocity.x), 0.0))
		var wb_vfx := BattleVFX.get_current(get_tree())
		if wb_vfx:
			var wx: float = 224.0 if global_position.x <= 224.0 else 1576.0
			wb_vfx.spawn_shockwave_ring(Vector2(wx, global_position.y - 48.0), Color("#38bdf8"), 12.0, 96.0, 0.25, 5.0)
			wb_vfx.spawn_floating_text(global_position + Vector2(0.0, -108.0), "WALL BOUNCE!", Color("#38bdf8"), 1.15)
	global_position.x = clampf(global_position.x, 220.0, 1580.0)

	# 落地反馈检测（空砸冲击波 / 受身无敌翻滚 / 普通落地）
	var on_floor_now: bool = is_on_floor()
	if on_floor_now and not _was_on_floor:
		fast_falling = false
		if air_slamming:
			air_slamming = false
			landing_timer = 0.22
			trigger_squash(1.36, 0.68)
			_trigger_air_slam_impact()
		elif hitstun_timer > 0.0 and _tech_window_timer > 0.0:
			_tech_window_timer = 0.0
			hitstun_timer = 0.0
			invincible_timer = 0.28
			var roll_dir: int = int(signf(horiz)) if horiz != 0.0 else -facing
			dash_dir = roll_dir
			dash_timer = 0.18
			velocity = Vector2(float(roll_dir) * 420.0, 0.0)
			trigger_squash(1.24, 0.80)
			AudioManager.play_sfx("tech_roll", -2.5)
			var tech_vfx := BattleVFX.get_current(get_tree())
			if tech_vfx:
				tech_vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -24.0), Color("#34d399"), 10.0, 74.0, 0.22, 4.0)
				tech_vfx.spawn_floating_text(global_position + Vector2(0.0, -96.0), "受身 TECH!", Color("#34d399"), 1.08)
				if sprite and sprite.visible:
					tech_vfx.spawn_ghost(sprite, Color("#34d399"), 0.24)
		else:
			landing_timer = 0.14
			trigger_squash(1.18, 0.82)
	_was_on_floor = on_floor_now

	# 60fps 2D 挤压拉伸、呼吸律动与运动前倾（脚底锚定不离地）
	_breath_time += delta
	_juice_scale = _juice_scale.lerp(Vector2.ONE, 1.0 - exp(-15.0 * delta))
	var target_rot: float = 0.0
	if hitstun_timer > 0.0:
		target_rot = -0.18 * float(facing)
	elif dash_timer > 0.0:
		target_rot = 0.18 * float(dash_dir)
	elif absf(velocity.x) > 30.0 and is_on_floor():
		target_rot = 0.06 * signf(velocity.x)
	_juice_rot = lerpf(_juice_rot, target_rot, 1.0 - exp(-16.0 * delta))

	# 自动同步战斗精灵动画状态
	_sync_animation_state()
	var isfp_skill1_pose: bool = fighter_id == "isfp" and anim_player != null and (
		(charging_slot == "skill1" and anim_player.assigned_animation == "skill1_charge")
		or (action_anim_timer > 0.0 and action_anim_state == "skill1" and anim_player.assigned_animation == "skill1")
	)
	if not isfp_skill1_pose:
		_advance_anim(delta)

	if sprite and sprite.visible:
		var use_fake_breath: bool = not isfp_skill1_pose and (_sheet_textures.is_empty() or (_current_anim == "idle" and int((_sheet_configs.get("idle", {}) as Dictionary).get("frames", 1)) <= 1))
		var breath_sy: float = 1.0 + sin(_breath_time * 3.8) * 0.025 if use_fake_breath else 1.0
		var breath_sx: float = 1.0 - sin(_breath_time * 3.8) * 0.015 if use_fake_breath else 1.0
		var final_sx: float = 1.0 if isfp_skill1_pose else _juice_scale.x * breath_sx
		var final_sy: float = 1.0 if isfp_skill1_pose else _juice_scale.y * breath_sy
		sprite.scale = Vector2(_base_sprite_scale.x * final_sx, _base_sprite_scale.y * final_sy)
		sprite.position.y = -target_sprite_height * 0.5 * final_sy + 4.0
		sprite.rotation = 0.0 if isfp_skill1_pose else _juice_rot

	queue_redraw()

func _sync_animation_state() -> void:
	var has_rig: bool = rig != null and rig.visible
	if hitstun_timer > 0.0 and (has_rig or _sheet_textures.has("hit")):
		_play_anim("hit")
	elif charging_slot != "":
		var charge_anim_name := charging_slot + "_charge"
		if anim_player and anim_player.has_animation(charge_anim_name):
			_play_anim(charge_anim_name)
		elif _sheet_textures.has(charge_anim_name):
			_play_anim(charge_anim_name)
	elif block_hit_timer > 0.0 and (has_rig or _sheet_textures.has("block_hit")):
		_play_anim("block_hit")
	elif dash_timer > 0.0:
		_play_anim("dash")
	elif guarding:
		_play_anim("guard")
	elif action_anim_timer > 0.0 and action_anim_state != "":
		_play_anim(action_anim_state)
	elif not is_on_floor():
		if jump_startup_timer > 0.0 and (has_rig or _sheet_textures.has("jump_startup")):
			_play_anim("jump_startup")
		elif velocity.y > 60.0 and anim_player and anim_player.has_animation("fall") and not (anim_player.current_animation == "jump" and anim_player.is_playing() and anim_player.current_animation_position < 0.40):
			# 在中层或高层下落时（未主动起跳，或起跳上升期结束后进入下落阶段），切换到专属下落动画帧
			_play_anim("fall")
		else:
			_play_anim("jump")
	elif landing_timer > 0.0 and absf(velocity.x) <= 25.0 and (has_rig or _sheet_textures.has("landing")):
		_play_anim("landing")
	elif absf(velocity.x) > 20.0:
		_play_anim("walk")
	else:
		_play_anim("idle")

func _perform_light_attack() -> void:
	var is_isfp: bool = (fighter_id == "isfp") or (anim_player and anim_player.has_animation("light"))
	has_hit_target_in_attack = false
	can_cancel_attack = false
	light_attack_hit_registered = false

	if is_isfp:
		# 严格 12 帧（60 FPS = 0.20s）时间轴切片
		action_anim_state = "light"
		action_anim_timer = 0.20
		basic_cd = 0.133 # 第 8 帧起冷却解除，允许无缝衔接下一次轻击缓冲
		isfp_light_active = true
		isfp_startup_step_timer = 0.034 # 第 1-2 帧微弱前进惯性/滑步补偿（~2 帧）
		if is_on_floor():
			velocity.x = facing * 120.0
		_play_anim("light", true)
		trigger_squash(1.08, 0.94)
		# 纯净保留 fighter_light 自身美术表现，移除额外叠加的弧光，甩笔声效清脆跟手
		AudioManager.play_sfx("swing_light", -6.0, randf_range(0.96, 1.08))
	else:
		basic_cd = 0.28 / _get_attack_speed_mult()
		action_anim_state = "light"
		action_anim_timer = 0.26 / _get_attack_speed_mult()
		isfp_light_active = false
		_play_anim("light", true)
		trigger_squash(1.12, 0.90)
		spawn_slash_arc(-65.0, 48.0, 90.0, theme_color.lightened(0.25), 0.14)
		AudioManager.play_sfx("swing_light", -6.0, randf_range(0.94, 1.1))
		_perform_melee(8, Vector2(facing * 240.0, -120.0), false)

func _check_isfp_light_hitbox() -> void:
	if light_attack_hit_registered:
		return
	var reach := 88.0 if action_anim_timer <= 0.084 else 76.0
	var hit := _check_isfp_attack_box(Rect2(-8.0, -96.0, reach + 8.0, 48.0), 8, Vector2(facing * 220.0, -90.0))
	if hit:
		light_attack_hit_registered = true
		has_hit_target_in_attack = true
		can_cancel_attack = true

func _perform_heavy_attack() -> void:
	var is_isfp: bool = (fighter_id == "isfp") or (anim_player and anim_player.has_animation("heavy"))
	has_hit_target_in_attack = false
	can_cancel_attack = false
	heavy_attack_hit_registered = false

	if is_isfp:
		# 不等长帧率节奏（总计 0.38s）：前摇蓄势(0.17s) -> 强力下劈判定(0.17-0.31s) -> 顺畅收招(0.31-0.38s)
		action_anim_state = "heavy"
		action_anim_timer = 0.38
		basic_cd = 0.33 # 后摇阶段冷却解除，允许衔接预输入动作
		isfp_heavy_active = true
		isfp_startup_step_timer = 0.05 # 前摇前踏步补偿（防止贴身空挥）
		if is_on_floor():
			velocity.x = facing * 150.0
		_play_anim("heavy", true)
		trigger_squash(1.18, 0.82)
		AudioManager.play_sfx("swing_heavy", -4.0, randf_range(0.92, 1.04))
	else:
		basic_cd = 0.48 / _get_attack_speed_mult()
		action_anim_state = "heavy"
		action_anim_timer = 0.36 / _get_attack_speed_mult()
		isfp_heavy_active = false
		_play_anim("heavy", true)
		trigger_squash(1.20, 0.85)
		spawn_slash_arc(-125.0, 55.0, 118.0, Color("#fde047"), 0.20)
		AudioManager.play_sfx("swing_heavy", -4.0, randf_range(0.92, 1.06))
		_perform_melee(13, Vector2(facing * 360.0, -210.0), true)

func _check_isfp_heavy_hitbox() -> void:
	if heavy_attack_hit_registered:
		return
	var reach := 82.0 if action_anim_timer > 0.16 else 108.0
	var hit := _check_isfp_attack_box(Rect2(-6.0, -108.0, reach + 6.0, 62.0), 14, Vector2(facing * 340.0, -230.0))
	if hit:
		heavy_attack_hit_registered = true
		has_hit_target_in_attack = true
		can_cancel_attack = true
		can_hit_cancel = true

func _check_isfp_attack_box(local_box: Rect2, damage: int, knockback: Vector2) -> bool:
	if facing < 0:
		local_box.position.x = -local_box.end.x
	var attack_box := Rect2(global_position + local_box.position, local_box.size)
	for node in get_tree().get_nodes_in_group("fighters"):
		var target := node as BaseFighter
		if target == null or target == self or target.is_ko or target.hp <= 0:
			continue
		if target.invincible_timer > 0.0 or target.is_isfp_ultimate_invulnerable():
			continue
		var hurtbox := target.get_node("Hurtbox/CollisionShape2D") as CollisionShape2D
		var shape := hurtbox.shape as RectangleShape2D
		if hurtbox.disabled or shape == null:
			continue
		var bounds := hurtbox.global_transform * Rect2(-shape.size * 0.5, shape.size)
		if attack_box.intersects(bounds):
			target.take_damage(damage, knockback, self)
			return true
	return false

func _process_charge_skill(delta: float, can_act: bool, horiz: float, guard_held: bool, up_held: bool, inp: Dictionary) -> bool:
	if not can_act:
		charging_slot = ""
		return false

	var aim := ""
	if up_held:
		aim = "up"
	elif guard_held:
		aim = "down"
	elif horiz != 0.0:
		aim = "forward" if int(signf(horiz)) == facing else "back"

	if charging_slot != "":
		var held: bool = bool(inp["skill1_held"]) if charging_slot == "skill1" else bool(inp["skill2_held"])
		if aim != "":
			charge_dir = aim
		charge_elapsed = minf(1.05, charge_elapsed + delta)
		charge_level = 3 if charge_elapsed >= 0.95 else (2 if charge_elapsed >= 0.42 else 1)
		if charge_level > _last_charge_level:
			_last_charge_level = charge_level
			AudioManager.play_sfx("charge_%d" % charge_level, -3.5)
			var vfx := BattleVFX.get_current(get_tree())
			if vfx:
				var ring_col := Color("#facc15") if charge_level >= 3 else Color("#38bdf8")
				if charging_slot != "skill1" or fighter_id != "isfp":
					vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -48.0), ring_col, 14.0, 74.0, 0.22, 4.0)
				vfx.spawn_floating_text(global_position + Vector2(0.0, -110.0), "MAX 蓄力!" if charge_level >= 3 else "LV.2 蓄力!", ring_col, 0.92)

		# ISFP U技能（Skill 1）彩色粒子不规则向笔尖聚拢效果更新
		if charging_slot == "skill1" and (fighter_id == "isfp" or (anim_player and anim_player.has_animation("skill1_charge"))):
			_update_isfp_charge_particles(delta)

		if not held:
			var slot := charging_slot
			var lv := charge_level
			var d := charge_dir
			charging_slot = ""
			_charge_particles.clear()
			on_charge_skill_release(slot, lv, d)
			if practice_skip_skill_cooldowns:
				skill1_cd = 0.0
				skill2_cd = 0.0
			if fighter_id == "isfp" and slot == "skill1":
				guarding = false
				return true
		return charging_slot != ""

	var trigger_skill1: bool = (bool(inp["skill1_just"]) or skill1_buffer_timer > 0.0) and skill1_cd <= 0.0
	if trigger_skill1:
		skill1_buffer_timer = 0.0
		charging_slot = "skill1"
		charge_elapsed = 0.0
		charge_level = 1
		_last_charge_level = 1
		charge_dir = aim if aim != "" else "neutral"
		AudioManager.play_sfx("charge_1", -7.0)
		return true
	if paint_counter == null and bool(inp["skill2_just"]) and skill2_cd <= 0.0:
		charging_slot = "skill2"
		charge_elapsed = 0.0
		charge_level = 1
		_last_charge_level = 1
		charge_dir = aim if aim != "" else "neutral"
		AudioManager.play_sfx("charge_1", -7.0)
		return true
	return false

# 各角色子类重写此方法，实现完全不同的蓄力与方向派生效果
func on_charge_skill_release(slot: String, level: int, dir: String) -> void:
	var vfx := BattleVFX.get_current(get_tree())
	if slot == "skill1":
		if fighter_id == "isfp" or (anim_player and anim_player.has_animation("skill1")):
			_perform_isfp_skill1(level, dir, true)
			return
		skill1_cd = 2.8
		action_anim_state = "skill"
		action_anim_timer = 0.42
		_play_anim("skill", true)
		AudioManager.play_sfx("skill_wave", -3.0)
		if dir == "back":
			global_position.x = clampf(global_position.x - facing * 90.0, 220.0, 1580.0)
		if vfx:
			vfx.spawn_floating_text(global_position + Vector2(0.0, -108.0), "%s 技1·LV%d!" % [fighter_name, level], theme_color.lightened(0.2), 1.0)
		# 通用远程/近战差异化：NT/NF 发射能量灵弹，SJ/SP 发动突进冲击
		var meta: Dictionary = GameManager.get_fighter_meta(fighter_id)
		var grp: String = String(meta.get("group", "SP"))
		if grp == "NT" or grp == "NF":
			var orb := MysticOrbProjectile.new()
			orb.owner_fighter = self
			orb.global_position = global_position + Vector2(facing * 36.0, -54.0)
			var ang: float = deg_to_rad(-24.0) if dir == "up" else (deg_to_rad(14.0) if dir == "down" else 0.0)
			var spd: float = 580.0 + level * 70.0
			orb.velocity = Vector2(facing * cos(ang) * spd, sin(ang) * spd)
			orb.damage = 8 + level * 4
			orb.knockback = Vector2(facing * (240.0 + level * 60.0), -170.0)
			orb.orb_radius = 15.0 + level * 3.0
			orb.hit_radius = 30.0 + level * 4.0
			orb.tint_color = theme_color
			get_parent().add_child(orb)
		else:
			velocity.x = facing * (340.0 + level * 70.0)
			spawn_slash_arc(-110.0, 60.0, 118.0 + level * 12.0, theme_color.lightened(0.2), 0.22)
			_perform_melee(8 + level * 4, Vector2(facing * (260.0 + level * 75.0), -260.0 if dir == "down" else -160.0), level >= 2)
	else:
		skill2_cd = 6.0
		ep = minf(100.0, ep + 10.0 * level)
		AudioManager.play_sfx("aura_buff", -3.0)
		if vfx:
			vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -48.0), theme_color, 16.0, 118.0, 0.3, 5.0)
			vfx.spawn_floating_text(global_position + Vector2(0.0, -108.0), "性格共鸣 +%d EP" % int(10 * level), Color("#38bdf8"), 1.0)
		if level >= 2:
			_perform_melee(8 + level * 3, Vector2(facing * 380.0, -220.0), true)

func is_isfp_ultimate_invulnerable() -> bool:
	return paint_ultimate != null and paint_ultimate.active and paint_ultimate.frame <= 4

func on_ultimate_cast() -> void:
	if paint_ultimate != null:
		paint_ultimate.start()
		return
	AudioManager.play_sfx("ult_cast", -1.5)
	invincible_timer = 0.65
	action_anim_state = "heavy"
	action_anim_timer = 0.55
	_play_anim("heavy", true)
	var vfx := BattleVFX.get_current(get_tree())
	if vfx:
		vfx.play_ult_cutin(fighter_name, "%s · 性格觉醒奥义!" % fighter_name, GameManager.get_portrait_texture(fighter_id), theme_color, facing)
		vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -48.0), Color("#facc15"), 20.0, 190.0, 0.36, 7.0)
	GameManager.trigger_hitstop(0.18)
	_perform_melee(26, Vector2(facing * 520.0, -320.0), true, 175.0, true)

func _perform_melee(damage: int, knockback: Vector2, is_heavy: bool, custom_range: float = -1.0, is_ultimate: bool = false) -> bool:
	current_attack_damage = damage
	current_attack_knockback = knockback
	current_attack_is_ult = is_ultimate

	# 1. 物理层 Hitbox 动态开启
	if hitbox_shape:
		if not hitbox_shape.resource_local_to_scene:
			hitbox_shape.resource_local_to_scene = true
		if custom_range > 0.0:
			hitbox_shape.size = Vector2(custom_range, default_hitbox_size.y if not is_heavy else default_hitbox_size.y * 1.5)
			if hitbox_col:
				hitbox_col.position = Vector2(custom_range * 0.5, default_hitbox_pos.y)
		else:
			hitbox_shape.size = default_hitbox_size
			if hitbox_col:
				hitbox_col.position = default_hitbox_pos

	if hitbox_col:
		hitbox_col.disabled = false
	hitbox_active_timer = 0.18 if (is_heavy or is_ultimate) else 0.12

	# 2. 保留数学判定兜底检测，保证 AI 与非 Area2D 实体交互正常
	var hit_any: bool = false
	var reach: float = (custom_range if custom_range > 0.0 else (118.0 if is_heavy else 92.0)) + _get_melee_range_bonus()
	for node in get_tree().get_nodes_in_group("fighters"):
		if node == self or not (node is BaseFighter):
			continue
		var target := node as BaseFighter
		if target.is_ko:
			continue
		var diff: Vector2 = target.global_position - global_position
		if (int(signf(diff.x)) == facing or absf(diff.x) < 28.0) and absf(diff.x) < reach and absf(diff.y) < 92.0:
			target.take_damage(damage, knockback, self, is_ultimate)
			hit_any = true
	return hit_any

func register_combo_hit(dealt_damage: int) -> void:
	current_combo_hits += 1
	current_combo_damage += dealt_damage
	if practice_full_energy:
		practice_last_damage = dealt_damage
		practice_best_hits = maxi(practice_best_hits, current_combo_hits)
		practice_best_damage = maxi(practice_best_damage, current_combo_damage)
	_combo_expire_timer = 1.65
	GameManager.record_stat(player_index, "max_combo", current_combo_hits)
	GameManager.combo_updated.emit(player_index, current_combo_hits, current_combo_damage)

func _trigger_shield_break() -> void:
	if shield_broken_timer > 0.0:
		return
	guarding = false
	shield_hp = 0.0
	shield_broken_timer = 1.8
	hitstun_timer = maxf(hitstun_timer, 0.4)
	velocity = Vector2(-facing * 180.0, -240.0)
	AudioManager.play_sfx("shield_break", -1.5)
	GameManager.trigger_hitstop(0.10)
	GameManager.trigger_shake(10.0, 0.20, Vector2(0.0, -1.0))
	var vfx := BattleVFX.get_current(get_tree())
	if vfx:
		vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -48.0), Color("#ef4444"), 16.0, 138.0, 0.34, 6.0)
		vfx.spawn_hit_particles(global_position + Vector2(0.0, -48.0), Color("#fca5a5"), 22, 360.0)
		vfx.spawn_floating_text(global_position + Vector2(0.0, -118.0), "破防! SHIELD BREAK!", Color("#ef4444"), 1.32)

func _trigger_air_slam_impact() -> void:
	AudioManager.play_sfx("hit_heavy", -1.5, 0.84)
	GameManager.trigger_shake(9.5, 0.18, Vector2(0.0, 1.0))
	var vfx := BattleVFX.get_current(get_tree())
	if vfx:
		vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -6.0), Color("#facc15"), 18.0, 155.0, 0.30, 6.5)
		vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -6.0), theme_color, 10.0, 110.0, 0.24, 4.5)
		vfx.spawn_hit_particles(global_position + Vector2(0.0, -12.0), Color("#fde047"), 18, 340.0)
		vfx.spawn_floating_text(global_position + Vector2(0.0, -104.0), "重坠震地!", Color("#fde047"), 1.08)
	for node in get_tree().get_nodes_in_group("fighters"):
		if node == self or not (node is BaseFighter):
			continue
		var target := node as BaseFighter
		if target.is_ko:
			continue
		var diff: Vector2 = target.global_position - global_position
		if absf(diff.x) <= 145.0 and absf(diff.y) <= 95.0:
			var push_x: float = signf(diff.x) if absf(diff.x) > 4.0 else float(facing)
			target.take_damage(14, Vector2(push_x * 340.0, -390.0), self, false)

func take_damage(amount: int, knockback: Vector2, attacker: BaseFighter, is_ultimate: bool = false) -> void:
	if is_ko or hp <= 0 or invincible_timer > 0.0 or is_isfp_ultimate_invulnerable():
		return
	if amount > 0 and paint_counter != null and paint_counter.absorb(attacker):
		return
	var counter_hit: bool = is_instance_valid(attacker) and attacker.paint_counter != null and attacker.paint_counter.applying_pulse
	var counter_finisher: bool = counter_hit and attacker.paint_counter.finishing_pulse
	var paint_combo: bool = is_ultimate and is_instance_valid(attacker) and isfp_ultimate_owner == attacker
	var eff_amount: int = amount
	var eff_kb: Vector2 = knockback
	var vfx := BattleVFX.get_current(get_tree())
	var hit_pos: Vector2 = global_position + Vector2(0.0, -52.0)
	var from_front: bool = attacker == null or int(signf(attacker.global_position.x - global_position.x)) == facing

	# 完美格挡（Perfect Parry）：按下防御瞬间 0.14 秒内受击 -> 0 伤 + 18 EP + 恢复护盾 + 弹反对手！
	if guarding and from_front and not is_ultimate and parry_window_timer > 0.0:
		parry_window_timer = 0.0
		ep = minf(100.0, ep + 18.0)
		shield_hp = minf(100.0, shield_hp + 20.0)
		block_hit_timer = 0.16
		GameManager.record_stat(player_index, "parries", 1)
		AudioManager.play_sfx("parry", -1.5)
		if attacker:
			attacker.velocity = Vector2(-signf(eff_kb.x) * 320.0, -140.0)
			attacker.hitstun_timer = maxf(attacker.hitstun_timer, 0.26)
		if vfx:
			vfx.spawn_hit_fx(hit_pos + Vector2(facing * 20.0, 0.0), Color("#fde047"), true, false)
			vfx.spawn_floating_text(hit_pos + Vector2(0.0, -48.0), "完美格挡! +18 EP", Color("#fde047"), 1.18)
		GameManager.trigger_hitstop(0.11)
		GameManager.trigger_shake(7.0, 0.14, Vector2(signf(eff_kb.x), 0.0))
		return

	if guarding and from_front and not is_ultimate:
		var chip: int = maxi(1, int(round(eff_amount * 0.3)))
		hp = maxi(0, hp - chip)
		shield_hp = maxf(0.0, shield_hp - float(eff_amount) * 2.2)
		velocity.x = eff_kb.x * 0.25
		block_hit_timer = 0.18
		AudioManager.play_sfx("block", -2.5, randf_range(0.95, 1.08))
		if vfx:
			vfx.spawn_hit_fx(hit_pos + Vector2(facing * 20.0, 0.0), Color("#38bdf8"), false, true)
			vfx.spawn_floating_text(hit_pos + Vector2(0.0, -34.0), "格挡 -%d" % chip, Color("#7dd3fc"), 0.9)
		# 防御顿帧分层：轻击命中防御 2 帧（0.033s）；重击命中防御 4 帧（0.067s）；高冲击/技能 0.08s
		var block_hitstop: float = 0.033 if (attacker and attacker.action_anim_state == "light") else (0.067 if (attacker and attacker.action_anim_state == "heavy") else 0.08)
		GameManager.trigger_hitstop(block_hitstop)
		GameManager.trigger_shake(4.0 if (attacker and attacker.action_anim_state == "heavy") else 2.5, 0.08, Vector2(signf(eff_kb.x), 0.0))
		if hp <= 0:
			_trigger_ko(attacker, false)
		elif shield_hp <= 0.0:
			_trigger_shield_break()
		return

	# 连击伤害递减与防无限连击退递增（Pushback Scaling 防止无限压制）
	var scaled_amount: int = eff_amount
	var pushback_mult: float = 1.0
	if attacker and not is_ultimate and not counter_hit and attacker.current_combo_hits >= 1:
		# 连续命中多次普攻时，逐步提升受击方水平击退距离，避免墙角无限循环
		pushback_mult = 1.0 + float(attacker.current_combo_hits - 1) * 0.18
		if attacker.current_combo_hits >= 2:
			var mult: float = maxf(0.55, 1.0 - float(attacker.current_combo_hits - 1) * 0.07)
			scaled_amount = maxi(2, int(round(float(eff_amount) * mult)))

	# 霸体状态（Super Armor）：承受 70% 伤害但不被打断硬直或击飞
	# 若在技能前摇阶段被打断，则取消投射物生成并正常进入冷却
	if action_anim_state == "skill1" and isfp_skill1_active and not isfp_skill1_projectile_spawned:
		isfp_skill1_active = false
		action_anim_state = ""
		action_anim_timer = 0.0

	if super_armor_timer > 0.0 and not is_ultimate:
		var armor_dmg: int = maxi(1, int(round(float(scaled_amount) * 0.7)))
		var actual_damage := mini(hp, armor_dmg)
		hp = maxi(0, hp - armor_dmg)
		if attacker and attacker.practice_full_energy and actual_damage > 0:
			attacker.register_combo_hit(actual_damage)
		ep = minf(100.0, ep + armor_dmg * 0.9)
		if attacker:
			GameManager.record_stat(attacker.player_index, "damage", armor_dmg)
		hit_flash_timer = 0.09
		AudioManager.play_sfx("block", -3.0, 0.85)
		if vfx:
			vfx.spawn_hit_fx(hit_pos, Color("#fde047"), false, false)
			vfx.spawn_floating_text(hit_pos + Vector2(0.0, -40.0), "霸体 -%d" % armor_dmg, Color("#fde047"), 0.95)
		if hp <= 0:
			_trigger_ko(attacker, false)
		return

	var is_light: bool = attacker != null and attacker.action_anim_state == "light" and not is_ultimate
	var is_heavy: bool = (scaled_amount >= 11 or is_ultimate or (attacker != null and attacker.action_anim_state == "heavy")) and not is_light
	var actual_damage := mini(hp, scaled_amount)
	hp = maxi(0, hp - scaled_amount)
	ep = minf(100.0, ep + scaled_amount * 0.9)
	if attacker:
		attacker.ep = minf(100.0, attacker.ep + scaled_amount * (0.0 if is_ultimate else 1.1))
		attacker.register_combo_hit(actual_damage if attacker.practice_full_energy else scaled_amount)
		GameManager.record_stat(attacker.player_index, "damage", scaled_amount)
	velocity = Vector2(eff_kb.x * pushback_mult, eff_kb.y)
	# 受击硬直：轻击 10-12 帧（约 0.18s-0.20s）；重击沉稳 14-15 帧（0.24s）；奥义 0.28s
	hitstun_timer = (19.0 / 60.0 if counter_finisher else 0.13) if counter_hit else (0.28 if is_ultimate else (0.24 if is_heavy else (0.18 if is_light else 0.15)))
	paint_counter_knockback = counter_finisher
	# 受击闪白（Hit Flash）：轻击 2 帧（0.033s）；重击 3 帧（0.05s）；奥义 0.18s
	hit_flash_timer = 2.0 / 60.0 if paint_combo or counter_hit else (0.18 if is_ultimate else (0.05 if is_heavy else (0.033 if is_light else 0.1)))
	if (paint_combo or counter_hit) and sprite and sprite.material is ShaderMaterial:
		sprite.material.set_shader_parameter("flash_amount", 1.0)
	trigger_squash(0.82, 1.22 if is_heavy else 1.15)
	AudioManager.play_sfx("hit_heavy" if is_heavy else "hit_light", -2.0 if is_heavy else -4.0, randf_range(0.93, 1.08))
	if vfx:
		var fx_col: Color = attacker.theme_color if attacker else theme_color
		var is_paint: bool = (attacker != null and attacker.fighter_id == "isfp")
		if not (is_paint and is_light):
			vfx.spawn_hit_fx(hit_pos, fx_col, is_heavy and not paint_combo, false, is_paint)
		vfx.spawn_floating_text(hit_pos + Vector2(0.0, -36.0), "-%d" % scaled_amount, Color("#fde047") if is_heavy else Color("#ffffff"), 1.25 if is_ultimate else (1.1 if is_heavy else 0.95))
	if counter_hit:
		if hp <= 0:
			_trigger_ko(attacker, false)
		return
	if paint_combo:
		if hp <= 0:
			attacker.paint_ultimate.pending_ko = self
		return
	if paint_ultimate != null and paint_ultimate.active:
		paint_ultimate.finish()
	# 顿帧（Hitstop）：轻击 2-3 帧（0.05s）；重击分层 5 帧（0.083s）；大招 0.11s
	GameManager.trigger_hitstop(0.11 if is_ultimate else (0.083 if is_heavy else 0.05))
	# 镜头震屏：轻击克制轻巧（2.5px，0.06s）；重击沉稳有力（7.5px，0.14s）；大招震撼（13px，0.22s）
	var shake_amp: float = 13.0 if is_ultimate else (7.5 if is_heavy else (2.5 if is_light else 4.5))
	var shake_dur: float = 0.22 if is_ultimate else (0.14 if is_heavy else (0.06 if is_light else 0.1))
	GameManager.trigger_shake(shake_amp, shake_dur, Vector2(signf(eff_kb.x), -0.25))
	if hp <= 0:
		_trigger_ko(attacker, is_ultimate)

func _trigger_ko(killer: BaseFighter, by_ultimate: bool) -> void:
	if is_ko:
		return
	is_ko = true
	if paint_counter != null:
		paint_counter.finish()
	AudioManager.play_sfx("ko", -1.0)
	var vfx := BattleVFX.get_current(get_tree())
	if vfx:
		vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -48.0), Color("#facc15"), 18.0, 220.0, 0.45, 8.0)
		vfx.spawn_floating_text(global_position + Vector2(0.0, -96.0), "K.O.!!", Color("#facc15"), 1.6)
	_on_ko_entered()
	ko_triggered.emit(self, killer, by_ultimate)

func _on_ko_entered() -> void:
	if (rig != null and rig.visible) or _sheet_textures.has("ko"):
		_play_anim("ko", true)

func _update_facing_visual() -> void:
	if rig != null and rig.visible:
		rig.set_facing(facing)
	if sprite:
		sprite.flip_h = facing < 0
	# 让攻击框 Hitbox 跟着人物朝向左右翻转
	if has_node("Hitbox"):
		$Hitbox.scale.x = facing

func _draw() -> void:
	# 脚底实时接地阴影（让 2D 角色稳稳踩在石质竞技场上）
	var on_g: bool = is_on_floor()
	var s_sc: float = 1.0 if on_g else 0.58
	var s_al: float = 0.28 if on_g else 0.12
	draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(s_sc, 0.28 * s_sc))
	draw_circle(Vector2.ZERO, 38.0, Color(0.05, 0.08, 0.14, s_al))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 仅在没有专属防御动作图时显示默认蓝色防御弧
	if guarding and not is_ko and not _sheet_textures.has("guard"):
		var g_col := Color("#fde047") if parry_window_timer > 0.0 else Color("#38bdf8")
		draw_arc(Vector2(facing * 26.0, -48.0), 38.0, -0.9 if facing > 0 else PI - 0.9, 0.9 if facing > 0 else PI + 0.9, 16, g_col, 4.5 if parry_window_timer > 0.0 else 4.0)
	# 仅在没有专属蓄力动画/特效时显示默认蓄力圆环兜底；ISFP使用笔尖聚拢彩色粒子，绝不显示圆圈进度条
	var is_isfp_skill1_charge: bool = charging_slot == "skill1" and (fighter_id == "isfp" or (anim_player != null and anim_player.has_animation("skill1_charge")))
	var has_charge_art: bool = is_isfp_skill1_charge or _sheet_textures.has(charging_slot + "_charge") or (anim_player != null and anim_player.has_animation(charging_slot + "_charge"))
	if charging_slot != "" and not is_ko and not has_charge_art:
		var col := Color("#facc15") if charge_level >= 3 else (Color("#38bdf8") if charge_level == 2 else theme_color)
		draw_arc(Vector2(0.0, -48.0), 46.0, 0.0, TAU * minf(1.0, charge_elapsed / 1.05), 24, col, 4.0)

	# 绘制 ISFP 笔尖聚拢彩色粒子与微弱光核
	if is_isfp_skill1_charge and not is_ko:
		_draw_isfp_charge_particles()

	# 破防眩晕：头顶旋转金星提示
	if shield_broken_timer > 0.0 and not is_ko:
		var t_dizzy: float = _breath_time * 6.5
		for i in range(3):
			var ang: float = t_dizzy + float(i) * (TAU / 3.0)
			var star_pos := Vector2(cos(ang) * 26.0, -target_sprite_height - 10.0 + sin(ang) * 7.0)
			draw_circle(star_pos, 5.5, Color("#facc15", 0.95))
			draw_circle(star_pos, 2.5, Color("#ffffff", 0.95))

	# 快速下落 / 空砸风压线
	if (fast_falling or air_slamming) and not is_on_floor() and not is_ko:
		var streak_col := Color("#fde047", 0.72) if air_slamming else Color("#e2e8f0", 0.48)
		draw_line(Vector2(-24.0, -86.0), Vector2(-24.0, -124.0), streak_col, 2.5)
		draw_line(Vector2(24.0, -86.0), Vector2(24.0, -124.0), streak_col, 2.5)

func _on_hitbox_area_entered(area: Area2D) -> void:
	var target = area.owner
	if target != self and target is BaseFighter and not target.is_ko:
		has_hit_target_in_attack = true
		can_cancel_attack = true
		can_hit_cancel = true
		light_attack_hit_registered = true
		heavy_attack_hit_registered = true
		target.take_damage(current_attack_damage, current_attack_knockback, self, current_attack_is_ult)
		if hitbox_col:
			hitbox_col.set_deferred("disabled", true)

var _pending_isfp_skill1_level: int = 1
var _pending_isfp_skill1_dir: String = "neutral"

func _perform_isfp_skill1(level: int, dir: String, from_charge: bool = false) -> void:
	skill1_cd = 4.8 # 4.5-5.5 秒独立冷却时间
	action_anim_state = "skill1"
	isfp_skill1_active = true
	isfp_skill1_projectile_spawned = false
	can_cancel_attack = false
	_pending_isfp_skill1_level = level
	_pending_isfp_skill1_dir = dir

	if from_charge:
		# 蓄力松手后，直接无缝衔接第 5 帧动作（跳过前 4 帧蓄力动作，剩余 8 帧 = 0.1333s）
		action_anim_timer = 0.1333333
		_play_anim("skill1", true)
		if anim_player and anim_player.has_animation("skill1"):
			# 核心关键：直接推移到第 5 帧时间点（0.0667s），实现视觉帧与逻辑无缝顺畅续接！
			anim_player.seek(0.0666667, true)
		# 松手即出手：立即生成第 5 帧投射物
		_spawn_isfp_paint_blob()
	else:
		action_anim_timer = 0.20 # 完整 12 帧时间轴
		# 第 1-2 帧微弱惯性滑步，不锁死朝向
		isfp_startup_step_timer = 0.034
		if is_on_floor():
			velocity.x = facing * 90.0
		_play_anim("skill1", true)
		trigger_squash(0.92, 1.08)

	AudioManager.play_sfx("swing_light", -5.0, 1.1)

func _spawn_isfp_paint_blob() -> void:
	if isfp_skill1_projectile_spawned:
		return
	isfp_skill1_projectile_spawned = true

	# 笔尖坐标：基于 ISFP 角色锚点，朝向翻转时 x 轴向外延伸
	var tip_pos: Vector2 = global_position + Vector2(facing * 52.0, -56.0)

	# 笔尖短促甩彩粒子，体现“随手一甩”的轻巧节奏
	var vfx := BattleVFX.get_current(get_tree())
	if vfx:
		vfx.spawn_brush_tip_splatter(tip_pos, facing)

	# 生成抛物线彩色颜料块
	var blob := PaintBlobProjectileScene.new()
	blob.owner_fighter = self
	blob.global_position = tip_pos
	blob.charge_level = _pending_isfp_skill1_level
	blob.dir_param = _pending_isfp_skill1_dir

	# 速度与方向派生配置（水平速度 vx 约 380-440，垂直初速度 vy 约 -260 ~ -320，重力 g 约 1100-1300）
	var base_vx: float = 410.0 + float(_pending_isfp_skill1_level - 1) * 60.0
	var base_vy: float = -290.0 - float(_pending_isfp_skill1_level - 1) * 35.0

	if _pending_isfp_skill1_dir == "back":
		# 按住反向：近身脚下近抛（防贴脸突进）
		base_vx = 160.0
		base_vy = -340.0
	elif _pending_isfp_skill1_dir == "forward":
		# 按住正向：低弧度远抛（中远距离骚扰）
		base_vx = 520.0 + float(_pending_isfp_skill1_level - 1) * 70.0
		base_vy = -190.0
	elif _pending_isfp_skill1_dir == "up":
		base_vx = 280.0
		base_vy = -420.0
	elif _pending_isfp_skill1_dir == "down":
		base_vx = 240.0
		base_vy = -140.0

	blob.velocity = Vector2(facing * base_vx, base_vy)
	blob.damage = 9 + (_pending_isfp_skill1_level - 1) * 3
	var p := get_parent()
	if p:
		p.add_child(blob)
	elif is_inside_tree():
		get_tree().root.add_child(blob)

func trigger_paint_slip(duration: float, slip_direction: float) -> void:
	paint_slip_timer = duration
	paint_slip_dir = slip_direction
	hit_flash_timer = 0.033 # 短暂 2 帧受击闪白与打滑微硬直
	trigger_squash(1.22, 0.80)
	AudioManager.play_sfx("tech_roll", -5.0, 1.25)
	var vfx := BattleVFX.get_current(get_tree())
	if vfx:
		vfx.spawn_floating_text(global_position + Vector2(0.0, -88.0), "打滑 SLIP!", Color("#f59e0b"), 0.92)

func _update_isfp_charge_particles(delta: float) -> void:
	# 笔尖局部坐标（相对于角色 CharacterBody2D 原点）
	var tip_local := Vector2(float(facing) * 52.0, -56.0)

	# 随蓄力时间增加生成频率（蓄力越长，聚拢越密集明显）
	var charge_progress: float = clampf(charge_elapsed / 0.95, 0.0, 1.0)
	var spawn_interval: float = lerpf(0.045, 0.016, charge_progress)

	_charge_particle_timer -= delta
	if _charge_particle_timer <= 0.0:
		_charge_particle_timer = spawn_interval
		var cols: Array[Color] = [
			Color("#f59e0b"), Color("#ec4899"), Color("#06b6d4"), Color("#84cc16")
		]
		# 不规则从周围聚拢（生成半径从 35px 到 55px，受时间加成）
		var spawn_r: float = randf_range(32.0, 50.0 + 15.0 * charge_progress)
		var ang: float = randf_range(0.0, TAU)
		var start_p := tip_local + Vector2(cos(ang) * spawn_r * 1.15, sin(ang) * spawn_r * 0.85)

		_charge_particles.append({
			"pos": start_p,
			"tip": tip_local,
			"color": cols[randi() % cols.size()],
			"life": 0.0,
			"max_life": randf_range(0.24, 0.36) / (1.0 + 0.5 * charge_progress),
			"size": randf_range(1.6, 2.8)
		})

	# 更新所有活动聚拢粒子的生命与轨迹
	var alive_particles: Array[Dictionary] = []
	for p in _charge_particles:
		p["life"] += delta
		var t: float = clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
		# 平滑缓动朝向笔尖聚拢（缓入加速聚拢感）
		var ease_t: float = t * t
		p["current_pos"] = (p["pos"] as Vector2).lerp(tip_local, ease_t)
		if t < 1.0:
			alive_particles.append(p)
	_charge_particles = alive_particles

func _draw_isfp_charge_particles() -> void:
	var tip_local := Vector2(float(facing) * 52.0, -56.0)
	var charge_progress: float = clampf(charge_elapsed / 0.95, 0.0, 1.0)

	# 1. 绘制各个聚拢彩色微粒（低饱和柔和透明度，不完全遮挡角色动作）
	for p in _charge_particles:
		var t: float = clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
		var cpos: Vector2 = p.get("current_pos", p["pos"])
		# 透明度适度降低（0.35 - 0.65），亮度适中柔和
		var alpha: float = sin(t * PI) * 0.55
		var col: Color = p["color"]
		col.a = alpha
		var sz: float = float(p["size"]) * (1.0 - t * 0.4)
		draw_circle(cpos, sz, col)

	# 2. 笔尖中心微弱彩色聚能光核：大小严格限制，绝不超过投掷物大小（最大半径 11px <= 投掷物半径 12-15px）
	var core_rad: float = lerpf(3.0, 10.5, charge_progress)
	var pulse: float = 1.0 + sin(_breath_time * 14.0) * 0.12
	var final_rad: float = core_rad * pulse

	var core_col := Color("#f59e0b")
	if charge_level == 2:
		core_col = Color("#ec4899")
	elif charge_level >= 3:
		core_col = Color("#06b6d4")

	# 外层微弱柔和光晕（透明度 0.22）
	core_col.a = 0.22 + 0.12 * charge_progress
	draw_circle(tip_local, final_rad * 1.15, core_col)
	# 核心轻微微光（透明度 0.45）
	core_col.a = 0.45 + 0.15 * charge_progress
	draw_circle(tip_local, final_rad * 0.65, core_col)
