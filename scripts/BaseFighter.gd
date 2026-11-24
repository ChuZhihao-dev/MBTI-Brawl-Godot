extends CharacterBody2D
class_name BaseFighter

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

var dash_timer: float = 0.0
var dash_cd: float = 0.0
var dash_dir: int = 1
var dash_ghost_timer: float = 0.0
var invincible_timer: float = 0.0
var hitstun_timer: float = 0.0
var hit_flash_timer: float = 0.0
var block_hit_timer: float = 0.0
var jump_startup_timer: float = 0.0
var landing_timer: float = 0.0
var action_anim_timer: float = 0.0
var action_anim_state: String = ""
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
var _slash_arc_active: bool = false
var _slash_arc_elapsed: float = 0.0
var _slash_arc_duration: float = 0.16
var _slash_arc_start: float = 0.0
var _slash_arc_end: float = 0.0
var _slash_arc_radius: float = 92.0
var _slash_arc_thick: float = 24.0
var _slash_arc_color: Color = Color("#6ee7b7")
var _slash_arc_facing: int = 1

# 三档蓄力状态机（U/4 与 I/5 通用）
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

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox_col: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var hitbox_shape: RectangleShape2D = $Hitbox/CollisionShape2D.shape as RectangleShape2D
@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")

var rig: FighterRig = null

func _ready() -> void:
	hp = max_hp
	facing = 1 if player_index == 1 else -1

	# 1. 记录在 BaseFighter 编辑器中绘制的初始 Hitbox 尺寸与位置
	if hitbox_shape:
		default_hitbox_size = hitbox_shape.size
	if hitbox_col:
		default_hitbox_pos = hitbox_col.position
		# 确保游戏开局时 Hitbox 绝对处于关闭状态
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

func _play_anim(state_name: String, force_reset: bool = false) -> void:
	if rig != null and rig.visible:
		rig.play_state(state_name, force_reset, maxf(0.22, action_anim_timer))
		return
	# ----------------- 【AnimationPlayer 优先通道】 -----------------
	if anim_player and anim_player.has_animation(state_name):
		# 如果当前已经在播放这个动画，且没有要求强制重播，就让它继续播，不要每帧打断！
		if anim_player.current_animation == state_name and anim_player.is_playing() and not force_reset:
			return
		anim_player.play(state_name)
		# 核心关键：立即将动画推进一步（advance(0)），让 AnimationPlayer 的第 0 秒贴图和切片轨道立即生效！
		anim_player.advance(0.0)

		# 此时 sprite.texture 已经是新动画切换后的正式图片了，再进行缩放与踩地高度校准！
		if sprite and sprite.texture:
			var rows: float = float(maxi(1, sprite.vframes))
			var frame_h: float = sprite.texture.get_size().y / rows
			# 根据是 stand.png（留白很多）还是 move.png（几乎占满）分别给最协调的比例
			var mult: float = sprite_scale_mult if rows == 1.0 else (sprite_scale_mult * (407.0 / 724.0) / (318.0 / 362.0))
			var sc: float = (target_sprite_height / maxf(1.0, frame_h)) * mult
			_base_sprite_scale = Vector2(sc, sc)
			sprite.scale = _base_sprite_scale
			var y_off: float = sprite_y_offset if rows == 1.0 else (sprite_y_offset * 0.4)
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
	var idx: int = (raw_idx % total) if bool(cfg.get("loop", true)) else mini(total - 1, raw_idx)
	sprite.frame = int(cfg.get("start", 0)) + idx

func _act(suffix: String) -> String:
	return ("p1_" if player_index == 1 else "p2_") + suffix

func _get_effective_move_speed() -> float:
	return move_speed

func _get_attack_speed_mult() -> float:
	return 1.0

func _get_melee_range_bonus() -> float:
	return 0.0

func _physics_process(delta: float) -> void:
	dash_timer = maxf(0.0, dash_timer - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	dash_ghost_timer = maxf(0.0, dash_ghost_timer - delta)
	invincible_timer = maxf(0.0, invincible_timer - delta)
	hitstun_timer = maxf(0.0, hitstun_timer - delta)
	block_hit_timer = maxf(0.0, block_hit_timer - delta)
	jump_startup_timer = maxf(0.0, jump_startup_timer - delta)
	landing_timer = maxf(0.0, landing_timer - delta)
	basic_cd = maxf(0.0, basic_cd - delta)
	skill1_cd = maxf(0.0, skill1_cd - delta)
	skill2_cd = maxf(0.0, skill2_cd - delta)
	action_anim_timer = maxf(0.0, action_anim_timer - delta)

	if hit_flash_timer > 0.0:
		hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
		if rig != null and rig.visible:
			rig.set_flash(1.0 if hit_flash_timer > 0.0 else 0.0, Color.WHITE)
		else:
			if sprite and sprite.material is ShaderMaterial:
				sprite.material.set_shader_parameter("flash_amount", 1.0 if hit_flash_timer > 0.0 else 0.0)
			if sprite:
				sprite.offset.x = sin(Time.get_ticks_msec() * 0.09) * 5.0 if hit_flash_timer > 0.0 else 0.0
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

	var can_act := hitstun_timer <= 0.0
	var horiz := Input.get_axis(_act("left"), _act("right"))
	var guard_held := Input.is_action_pressed(_act("guard"))
	var up_pressed := Input.is_action_just_pressed(_act("up"))

	# 0. 必杀大招（O / 6，满 100 能量可释放）
	if can_act and charging_slot == "" and dash_timer <= 0.0 and ep >= 100.0 and Input.is_action_just_pressed(_act("ult")):
		ep = 0.0
		guarding = false
		on_ultimate_cast()
	# 1. 蓄力小技能处理（支持方向键派生）
	elif _process_charge_skill(delta, can_act, horiz, guard_held):
		velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
	elif can_act:
		# 2. 单向平台下+跳快速穿落
		if is_on_floor() and guard_held and up_pressed and global_position.y < 520.0:
			global_position.y += 6.0
		else:
			guarding = is_on_floor() and guard_held and dash_timer <= 0.0

		# 3. 冲刺 / 闪避（L / 3）
		if Input.is_action_just_pressed(_act("dash")) and dash_cd <= 0.0 and not guarding:
			dash_dir = int(signf(horiz)) if horiz != 0.0 else facing
			facing = dash_dir
			dash_timer = 0.22
			dash_cd = 0.85
			invincible_timer = 0.16
			dash_ghost_timer = 0.0
			_update_facing_visual()
			AudioManager.play_sfx("dash", -4.0, randf_range(0.95, 1.08))
			var vfx := BattleVFX.get_current(get_tree())
			if vfx:
				vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -32.0), theme_color, 8.0, 44.0, 0.18, 3.0)

		# 4. 水平移动与跳跃
		var eff_speed: float = _get_effective_move_speed()
		if dash_timer > 0.0:
			velocity.x = dash_dir * eff_speed * 2.2
			if dash_ghost_timer <= 0.0:
				dash_ghost_timer = 0.042
				var vfx := BattleVFX.get_current(get_tree())
				if vfx:
					if rig != null and rig.visible:
						rig.spawn_ghost_into(vfx, theme_color, 0.22)
					else:
						vfx.spawn_ghost(sprite, theme_color, 0.22)
		elif not guarding:
			if horiz != 0.0:
				velocity.x = horiz * eff_speed
				facing = int(signf(horiz))
				_update_facing_visual()
			else:
				velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
			if up_pressed and is_on_floor():
				velocity.y = -jump_force
				jump_startup_timer = 0.14
				trigger_squash(0.84, 1.18)
				AudioManager.play_sfx("swing_light", -10.0, 1.35)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)

		# 5. 普攻（J/1）与性格技能（K/2）
		if not guarding and dash_timer <= 0.0:
			if Input.is_action_just_pressed(_act("light")) and basic_cd <= 0.0:
				_perform_light_attack()
			elif Input.is_action_just_pressed(_act("heavy")) and basic_cd <= 0.0:
				_perform_heavy_attack()
	else:
		guarding = false
		velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)

	# 重力与移动碰撞
	if not is_on_floor():
		velocity.y += gravity_force * delta
	move_and_slide()
	global_position.x = clampf(global_position.x, 220.0, 1580.0)

	# 落地反馈检测
	var on_floor_now: bool = is_on_floor()
	if on_floor_now and not _was_on_floor:
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

	if _slash_arc_active:
		_slash_arc_elapsed += delta
		if _slash_arc_elapsed >= _slash_arc_duration:
			_slash_arc_active = false

	# 自动同步战斗精灵动画状态
	_sync_animation_state()
	_advance_anim(delta)

	if sprite and sprite.visible:
		var breath_sy: float = 1.0 + sin(_breath_time * 3.8) * 0.025 if (_current_anim == "idle" or _sheet_textures.is_empty()) else 1.0
		var breath_sx: float = 1.0 - sin(_breath_time * 3.8) * 0.015 if (_current_anim == "idle" or _sheet_textures.is_empty()) else 1.0
		var final_sx: float = _juice_scale.x * breath_sx
		var final_sy: float = _juice_scale.y * breath_sy
		sprite.scale = Vector2(_base_sprite_scale.x * final_sx, _base_sprite_scale.y * final_sy)
		sprite.position.y = -target_sprite_height * 0.5 * final_sy + 4.0
		sprite.rotation = _juice_rot

	queue_redraw()

func _sync_animation_state() -> void:
	var has_rig: bool = rig != null and rig.visible
	if hitstun_timer > 0.0 and (has_rig or _sheet_textures.has("hit")):
		_play_anim("hit")
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
		else:
			_play_anim("jump")
	elif landing_timer > 0.0 and absf(velocity.x) <= 25.0 and (has_rig or _sheet_textures.has("landing")):
		_play_anim("landing")
	elif absf(velocity.x) > 20.0:
		_play_anim("walk")
	else:
		_play_anim("idle")

func _perform_light_attack() -> void:
	basic_cd = 0.28 / _get_attack_speed_mult()
	action_anim_state = "light"
	action_anim_timer = 0.26 / _get_attack_speed_mult()
	_play_anim("light", true)
	AudioManager.play_sfx("swing_light", -6.0, randf_range(0.94, 1.1))
	_perform_melee(8, Vector2(facing * 240.0, -120.0), false)

func _perform_heavy_attack() -> void:
	basic_cd = 0.48 / _get_attack_speed_mult()
	action_anim_state = "heavy"
	action_anim_timer = 0.36 / _get_attack_speed_mult()
	_play_anim("heavy", true)
	AudioManager.play_sfx("swing_heavy", -4.0, randf_range(0.92, 1.06))
	_perform_melee(13, Vector2(facing * 360.0, -210.0), true)

func _process_charge_skill(delta: float, can_act: bool, horiz: float, guard_held: bool) -> bool:
	if not can_act:
		charging_slot = ""
		return false

	var aim := ""
	if Input.is_action_pressed(_act("up")):
		aim = "up"
	elif guard_held:
		aim = "down"
	elif horiz != 0.0:
		aim = "forward" if int(signf(horiz)) == facing else "back"

	if charging_slot != "":
		var held := Input.is_action_pressed(_act(charging_slot))
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
				vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -48.0), ring_col, 14.0, 74.0, 0.22, 4.0)
				vfx.spawn_floating_text(global_position + Vector2(0.0, -110.0), "MAX 蓄力!" if charge_level >= 3 else "LV.2 蓄力!", ring_col, 0.92)
		if not held:
			var slot := charging_slot
			var lv := charge_level
			var d := charge_dir
			charging_slot = ""
			on_charge_skill_release(slot, lv, d)
		return charging_slot != ""

	if Input.is_action_just_pressed(_act("skill1")) and skill1_cd <= 0.0:
		charging_slot = "skill1"
		charge_elapsed = 0.0
		charge_level = 1
		_last_charge_level = 1
		charge_dir = aim if aim != "" else "neutral"
		AudioManager.play_sfx("charge_1", -7.0)
		return true
	if Input.is_action_just_pressed(_act("skill2")) and skill2_cd <= 0.0:
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
		skill1_cd = 2.8
		action_anim_state = "skill"
		action_anim_timer = 0.42
		_play_anim("skill", true)
		AudioManager.play_sfx("skill_wave", -3.0)
		if dir == "back":
			global_position.x = clampf(global_position.x - facing * 90.0, 220.0, 1580.0)
		if vfx:
			vfx.spawn_floating_text(global_position + Vector2(0.0, -108.0), "%s 技1·LV%d!" % [fighter_name, level], theme_color.lightened(0.2), 1.0)
		_perform_melee(7 + level * 4, Vector2(facing * (240.0 + level * 80.0), -260.0 if dir == "down" else -150.0), level >= 2)
	else:
		skill2_cd = 6.0
		ep = minf(100.0, ep + 10.0 * level)
		AudioManager.play_sfx("aura_buff", -3.0)
		if vfx:
			vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -48.0), theme_color, 16.0, 110.0, 0.3, 5.0)
			vfx.spawn_floating_text(global_position + Vector2(0.0, -108.0), "能量共鸣 +%d EP" % int(10 * level), Color("#38bdf8"), 1.0)
		if level >= 2:
			_perform_melee(8 + level * 3, Vector2(facing * 380.0, -220.0), true)

func on_ultimate_cast() -> void:
	AudioManager.play_sfx("ult_cast", -1.5)
	invincible_timer = 0.6
	action_anim_state = "heavy"
	action_anim_timer = 0.55
	_play_anim("heavy", true)
	var vfx := BattleVFX.get_current(get_tree())
	if vfx:
		vfx.play_ult_cutin(fighter_name, "%s · 性格觉醒奥义!" % fighter_name, GameManager.get_portrait_texture(fighter_id), theme_color, facing)
		vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -48.0), Color("#facc15"), 20.0, 180.0, 0.36, 7.0)
	GameManager.trigger_hitstop(0.18)
	_perform_melee(26, Vector2(facing * 520.0, -320.0), true, 165.0, true)

# 【出招时开启 Hitbox 判定】
# custom_range <= 0 时完全保持 BaseFighter 的初始尺寸与位置不变
# custom_range > 0 时（如 ENFJ 专属光剑），动态伸展攻击距离
func _perform_melee(damage: int, knockback: Vector2, is_heavy: bool, custom_range: float = -1.0, is_ultimate: bool = false) -> bool:
	current_attack_damage = damage
	current_attack_knockback = knockback
	current_attack_is_ult = is_ultimate

	if hitbox_shape:
		# 保证每个角色独立拥有自己的 Shape，避免互相串改
		if not hitbox_shape.resource_local_to_scene:
			hitbox_shape.resource_local_to_scene = true

		if custom_range > 0.0:
			# 针对指定了自定义距离的攻击（如 ENFJ 光剑）
			hitbox_shape.size = Vector2(custom_range * 0.9, default_hitbox_size.y if not is_heavy else default_hitbox_size.y * 1.4)
			if hitbox_col:
				hitbox_col.position = Vector2(custom_range * 0.55, default_hitbox_pos.y)
		else:
			# 未指定自定义距离时：100% 严格保持 BaseFighter 初始配置的默认大小与位置
			hitbox_shape.size = default_hitbox_size
			if hitbox_col:
				hitbox_col.position = default_hitbox_pos

	if hitbox_col:
		hitbox_col.disabled = false  # 仅在按下攻击键时开启！

	# 攻击判定窗口：持续 0.12s ~ 0.18s，时间一到由 _physics_process 自动关闭
	hitbox_active_timer = 0.18 if (is_heavy or is_ultimate) else 0.12

	return true

func take_damage(amount: int, knockback: Vector2, attacker: BaseFighter, is_ultimate: bool = false) -> void:
	if is_ko or invincible_timer > 0.0:
		return
	var vfx := BattleVFX.get_current(get_tree())
	var hit_pos: Vector2 = global_position + Vector2(0.0, -52.0)
	var from_front: bool = attacker == null or int(signf(attacker.global_position.x - global_position.x)) == facing
	if guarding and from_front and not is_ultimate:
		var chip: int = maxi(1, int(round(amount * 0.3)))
		hp = maxi(0, hp - chip)
		velocity.x = knockback.x * 0.25
		block_hit_timer = 0.18
		AudioManager.play_sfx("block", -2.5, randf_range(0.95, 1.08))
		if vfx:
			vfx.spawn_hit_fx(hit_pos + Vector2(facing * 20.0, 0.0), Color("#38bdf8"), false, true)
			vfx.spawn_floating_text(hit_pos + Vector2(0.0, -34.0), "格挡 -%d" % chip, Color("#7dd3fc"), 0.9)
		GameManager.trigger_hitstop(0.05)
		GameManager.trigger_shake(4.0, 0.09, Vector2(signf(knockback.x), 0.0))
		if hp <= 0:
			_trigger_ko(attacker, false)
		return

	var is_heavy: bool = amount >= 11 or is_ultimate
	hp = maxi(0, hp - amount)
	ep = minf(100.0, ep + amount * 0.9)
	if attacker:
		attacker.ep = minf(100.0, attacker.ep + amount * (0.0 if is_ultimate else 1.1))
	velocity = knockback
	hitstun_timer = 0.28 if is_ultimate else (0.22 if is_heavy else 0.15)
	hit_flash_timer = 0.18 if is_ultimate else (0.14 if is_heavy else 0.1)
	AudioManager.play_sfx("hit_heavy" if is_heavy else "hit_light", -2.0 if is_heavy else -4.0, randf_range(0.93, 1.08))
	if vfx:
		var fx_col: Color = attacker.theme_color if attacker else theme_color
		vfx.spawn_hit_fx(hit_pos, fx_col, is_heavy, false)
		vfx.spawn_floating_text(hit_pos + Vector2(0.0, -36.0), "-%d" % amount, Color("#fde047") if is_heavy else Color("#ffffff"), 1.25 if is_ultimate else (1.1 if is_heavy else 0.95))
	GameManager.trigger_hitstop(0.11 if is_ultimate else (0.085 if is_heavy else 0.05))
	GameManager.trigger_shake(13.0 if is_ultimate else (9.0 if is_heavy else 4.5), 0.22 if is_ultimate else (0.16 if is_heavy else 0.1), Vector2(signf(knockback.x), -0.25))
	if hp <= 0:
		_trigger_ko(attacker, is_ultimate)

func _trigger_ko(killer: BaseFighter, by_ultimate: bool) -> void:
	if is_ko:
		return
	is_ko = true
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
		# 新增：让攻击框 Hitbox 跟着人物朝向左右翻转！
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

	# 同步发光刀光弧
	if _slash_arc_active:
		var t: float = clampf(_slash_arc_elapsed / maxf(0.01, _slash_arc_duration), 0.0, 1.0)
		var alpha: float = pow(1.0 - t, 1.4)
		var lead_t: float = minf(1.0, t * 2.2)
		var tail_t: float = maxf(0.0, (t - 0.15) / 0.85)
		var a0: float = lerpf(_slash_arc_start, _slash_arc_end, tail_t)
		var a1: float = lerpf(_slash_arc_start, _slash_arc_end, lead_t)
		var steps: int = 16
		var outer_pts := PackedVector2Array()
		var inner_pts := PackedVector2Array()
		var center := Vector2(_slash_arc_facing * 18.0, -58.0)
		for i in range(steps + 1):
			var u: float = float(i) / float(steps)
			var ang: float = lerpf(a0, a1, u)
			var taper: float = sin(u * PI)
			var r_out: float = _slash_arc_radius + _slash_arc_thick * 0.45 * taper
			var r_in: float = maxf(10.0, _slash_arc_radius - _slash_arc_thick * 0.55 * taper)
			var dir_v := Vector2(cos(ang) * _slash_arc_facing, sin(ang))
			outer_pts.append(center + dir_v * r_out)
			inner_pts.append(center + dir_v * r_in)
		var poly := PackedVector2Array()
		for pt in outer_pts:
			poly.append(pt)
		for i in range(inner_pts.size() - 1, -1, -1):
			poly.append(inner_pts[i])
		if poly.size() >= 3:
			draw_colored_polygon(poly, Color(_slash_arc_color.r, _slash_arc_color.g, _slash_arc_color.b, alpha * 0.86))
			draw_polyline(outer_pts, Color(1.0, 1.0, 1.0, alpha * 0.92), 3.0, true)

	if guarding and not is_ko:
		draw_arc(Vector2(facing * 26.0, -48.0), 38.0, -0.9 if facing > 0 else PI - 0.9, 0.9 if facing > 0 else PI + 0.9, 16, Color("#38bdf8"), 4.0)
	if charging_slot != "" and not is_ko:
		var col := Color("#facc15") if charge_level >= 3 else (Color("#38bdf8") if charge_level == 2 else theme_color)
		draw_arc(Vector2(0.0, -48.0), 46.0, 0.0, TAU * minf(1.0, charge_elapsed / 1.05), 24, col, 4.0)


func _on_hitbox_area_entered(area: Area2D) -> void:
	var target = area.owner
	if target != self and target is BaseFighter and not target.is_ko:
		target.take_damage(current_attack_damage, current_attack_knockback, self, current_attack_is_ult)
		if hitbox_col:
			hitbox_col.set_deferred("disabled", true)
