extends Node2D
class_name FighterRig

@export var rig_scale: float = 0.195
@export var parts_dir: String = "res://assets/fighters/enfj/rig"
@export var theme_color: Color = Color("#10b981")

# 骨骼层级节点
var rig_root: Node2D
var hip_pivot: Node2D
var torso_pivot: Node2D
var head_pivot: Node2D
var cape_pivot: Node2D
var back_arm_pivot: Node2D
var front_arm_pivot: Node2D
var weapon_pivot: Node2D
var back_leg_pivot: Node2D
var front_leg_pivot: Node2D

var _part_sprites: Array[Sprite2D] = []
var _part_material: ShaderMaterial
var _slash_fx: _SlashArcFX

# 动画与物理表现状态
var current_state: String = "idle"
var state_time: float = 0.0
var state_duration: float = 0.35
var facing: int = 1
var move_velocity: Vector2 = Vector2.ZERO
var is_grounded: bool = true
var aura_active: bool = false

var _squash_scale: Vector2 = Vector2.ONE
var _cape_angle_vel: float = 0.0
var _cape_spring_angle: float = 0.0
var _hit_shake_time: float = 0.0
var _flash_amount: float = 0.0
var _flash_color: Color = Color.WHITE

func _ready() -> void:
	_setup_material()
	_build_hierarchy()
	load_parts(parts_dir)

func _setup_material() -> void:
	var sh := load("res://shaders/fighter_part.gdshader") as Shader
	if sh:
		_part_material = ShaderMaterial.new()
		_part_material.shader = sh
		_part_material.set_shader_parameter("rim_strength", 0.24)
		_part_material.set_shader_parameter("aura_color", theme_color.lightened(0.25))

func _make_part(parent: Node2D, part_name: String, pos: Vector2, z: int) -> Node2D:
	var pivot := Node2D.new()
	pivot.name = part_name + "Pivot"
	pivot.position = pos
	pivot.z_index = z
	parent.add_child(pivot)

	var sp := Sprite2D.new()
	sp.name = "Sprite"
	sp.centered = true
	if _part_material:
		sp.material = _part_material
	pivot.add_child(sp)
	_part_sprites.append(sp)
	return pivot

func _build_hierarchy() -> void:
	z_index = 10
	rig_root = Node2D.new()
	rig_root.name = "RigRoot"
	rig_root.scale = Vector2(rig_scale, rig_scale)
	add_child(rig_root)

	hip_pivot = Node2D.new()
	hip_pivot.name = "HipPivot"
	hip_pivot.position = Vector2(0.0, -256.0)
	rig_root.add_child(hip_pivot)

	# 根节点 z_index = 10 保证整体在背景之上；子节点用精确相对 z_index 严格区分前后遮挡
	back_leg_pivot = _make_part(hip_pivot, "BackLeg", Vector2(40.0, -18.0), 1)
	front_leg_pivot = _make_part(hip_pivot, "FrontLeg", Vector2(-36.0, -14.0), 2)
	back_leg_pivot.scale = Vector2(0.76, 0.76)
	front_leg_pivot.scale = Vector2(0.76, 0.76)

	torso_pivot = _make_part(hip_pivot, "Torso", Vector2(0.0, 14.0), 4)
	torso_pivot.scale = Vector2(0.84, 0.84)

	cape_pivot = _make_part(torso_pivot, "Cape", Vector2(-18.0, -188.0), -4)
	cape_pivot.scale = Vector2(1.06, 1.02)

	back_arm_pivot = _make_part(torso_pivot, "BackArm", Vector2(72.0, -168.0), -1)
	back_arm_pivot.scale = Vector2(0.92, 0.92)

	head_pivot = _make_part(torso_pivot, "Head", Vector2(4.0, -206.0), 2)
	head_pivot.scale = Vector2(1.24, 1.24)

	front_arm_pivot = _make_part(torso_pivot, "FrontArm", Vector2(-68.0, -168.0), 4)
	front_arm_pivot.scale = Vector2(0.95, 0.95)

	weapon_pivot = _make_part(front_arm_pivot, "Weapon", Vector2(142.0, 174.0), -1)
	weapon_pivot.scale = Vector2(0.92, 0.92)

	_slash_fx = _SlashArcFX.new()
	_slash_fx.z_index = 14
	add_child(_slash_fx)

func load_parts(dir_path: String) -> void:
	parts_dir = dir_path
	_assign_tex(head_pivot, "head.png", Vector2(-2.0, -116.0))
	_assign_tex(torso_pivot, "torso.png", Vector2(0.0, -62.0))
	_assign_tex(cape_pivot, "cape.png", Vector2(0.0, 199.0))
	_assign_tex(back_arm_pivot, "arm_back.png", Vector2(35.0, 138.0))
	_assign_tex(front_arm_pivot, "arm_front.png", Vector2(60.0, 100.0))
	_assign_tex(weapon_pivot, "sword.png", Vector2(0.0, -170.0))
	_assign_tex(back_leg_pivot, "leg_back.png", Vector2(41.0, 161.0))
	_assign_tex(front_leg_pivot, "leg_front.png", Vector2(39.0, 157.0))

func _assign_tex(pivot: Node2D, filename: String, offset_px: Vector2) -> void:
	var sp := pivot.get_node_or_null("Sprite") as Sprite2D
	if sp == null:
		return
	var full := "%s/%s" % [parts_dir, filename]
	if ResourceLoader.exists(full):
		sp.texture = load(full) as Texture2D
		sp.offset = offset_px

func set_facing(dir: int) -> void:
	facing = 1 if dir >= 0 else -1
	if rig_root:
		rig_root.scale = Vector2(absf(rig_scale) * float(facing), rig_scale)

func set_flash(amount: float, col: Color = Color.WHITE) -> void:
	_flash_amount = amount
	_flash_color = col
	if amount > 0.01:
		_hit_shake_time = 0.12
	if _part_material:
		_part_material.set_shader_parameter("flash_amount", amount)
		_part_material.set_shader_parameter("flash_color", col)

func set_aura_glow(active: bool, col: Color = Color("#34d399")) -> void:
	aura_active = active
	if _part_material:
		_part_material.set_shader_parameter("aura_glow", 1.0 if active else 0.0)
		_part_material.set_shader_parameter("aura_color", col)

func trigger_squash(sx: float, sy: float) -> void:
	_squash_scale = Vector2(sx, sy)

func trigger_slash_arc(start_deg: float, end_deg: float, radius: float, color: Color, duration: float = 0.16, thickness: float = 28.0) -> void:
	if _slash_fx:
		_slash_fx.play_arc(start_deg, end_deg, radius, color, duration, thickness, facing)

func play_state(state_name: String, force_reset: bool = false, duration: float = 0.35) -> void:
	if current_state == state_name and not force_reset:
		return
	current_state = state_name
	state_time = 0.0
	state_duration = maxf(0.08, duration)

	# 根据动作自动触发挤压拉伸与高质量刀光弧
	match state_name:
		"jump_startup":
			trigger_squash(1.18, 0.82)
		"landing":
			trigger_squash(1.22, 0.78)
		"dash":
			trigger_squash(1.24, 0.84)
		"light_1":
			trigger_squash(1.12, 0.92)
			trigger_slash_arc(-65.0, 48.0, 96.0, Color("#6ee7b7"), 0.14, 24.0)
		"light_2":
			trigger_squash(0.92, 1.12)
			trigger_slash_arc(62.0, -78.0, 100.0, Color("#34d399"), 0.15, 26.0)
		"light_3":
			trigger_squash(1.18, 0.88)
			trigger_slash_arc(-22.0, 22.0, 114.0, Color("#a7f3d0"), 0.13, 20.0)
		"light_4":
			trigger_squash(1.1, 0.94)
			trigger_slash_arc(-115.0, 35.0, 102.0, Color("#6ee7b7"), 0.16, 26.0)
		"light_5":
			trigger_squash(0.9, 1.16)
			trigger_slash_arc(-135.0, 58.0, 114.0, Color("#fde047"), 0.18, 32.0)
		"heavy_1":
			trigger_squash(1.18, 0.85)
			trigger_slash_arc(-140.0, 52.0, 134.0, Color("#fde047"), 0.22, 42.0)
		"heavy_2":
			trigger_squash(1.22, 0.84)
			trigger_slash_arc(-88.0, 74.0, 138.0, Color("#4ade80"), 0.22, 40.0)
		"heavy_3":
			trigger_squash(0.86, 1.2)
			trigger_slash_arc(85.0, -110.0, 136.0, Color("#fde047"), 0.24, 44.0)
		"triple_wave":
			trigger_squash(1.14, 0.9)
			trigger_slash_arc(-100.0, 62.0, 124.0, Color("#34d399"), 0.24, 34.0)
		"aura_buff":
			trigger_squash(0.88, 1.18)
		"ultimate":
			trigger_squash(1.25, 0.82)
			trigger_slash_arc(-155.0, 68.0, 168.0, Color("#fde047"), 0.34, 56.0)

func spawn_ghost_into(vfx: Node2D, tint: Color, duration: float = 0.22) -> void:
	if vfx == null or rig_root == null:
		return
	var ghost_holder := Node2D.new()
	ghost_holder.global_position = global_position
	ghost_holder.z_index = -1
	ghost_holder.modulate = Color(tint.r, tint.g, tint.b, 0.48)
	vfx.add_child(ghost_holder)

	for sp in _part_sprites:
		if sp.texture == null:
			continue
		var gsp := Sprite2D.new()
		gsp.texture = sp.texture
		gsp.offset = sp.offset
		gsp.centered = true
		gsp.global_transform = sp.global_transform
		gsp.global_position = sp.global_position
		gsp.modulate = tint
		ghost_holder.add_child(gsp)

	var tw := vfx.create_tween()
	tw.tween_property(ghost_holder, "modulate:a", 0.0, duration).set_ease(Tween.EASE_OUT)
	tw.tween_callback(ghost_holder.queue_free)

func _process(delta: float) -> void:
	state_time += delta
	_squash_scale = _squash_scale.lerp(Vector2.ONE, 1.0 - exp(-14.0 * delta))

	var shake_x: float = 0.0
	if _hit_shake_time > 0.0:
		_hit_shake_time = maxf(0.0, _hit_shake_time - delta)
		shake_x = sin(Time.get_ticks_msec() * 0.11) * 5.5

	if rig_root:
		rig_root.position.x = shake_x
		rig_root.scale = Vector2(absf(rig_scale) * float(facing) * _squash_scale.x, rig_scale * _squash_scale.y)

	_update_pose(delta)
	_update_cape_spring(delta)
	queue_redraw()

func _update_pose(delta: float) -> void:
	var t: float = state_time
	var p: float = clampf(state_time / maxf(0.05, state_duration), 0.0, 1.0)
	var blend: float = 1.0 - exp(-22.0 * delta)

	# 默认中性姿态目标（基线 hip_y = -256，匹配缩放后的精确脚底基线）
	var hip_y: float = -256.0
	var hip_x: float = 0.0
	var torso_rot: float = 0.0
	var head_rot: float = 0.0
	var f_arm_rot: float = -0.06
	var b_arm_rot: float = -0.18
	var weapon_rot: float = 0.55
	var f_leg_rot: float = -0.05
	var b_leg_rot: float = 0.07

	match current_state:
		"idle":
			var breath: float = sin(t * 3.6)
			hip_y = -256.0 + breath * 6.0
			torso_rot = breath * 0.03
			head_rot = -breath * 0.035
			f_arm_rot = -0.06 + breath * 0.06
			b_arm_rot = -0.18 - breath * 0.05
			weapon_rot = 0.55 + sin(t * 3.6 - 0.5) * 0.06
			f_leg_rot = -0.05
			b_leg_rot = 0.08
		"walk":
			var cyc: float = t * 13.5
			var stride: float = sin(cyc)
			var bounce: float = absf(cos(cyc))
			hip_y = -250.0 - bounce * 18.0
			torso_rot = 0.14 + stride * 0.04
			head_rot = -0.08
			f_leg_rot = stride * 0.58
			b_leg_rot = -stride * 0.58
			f_arm_rot = -stride * 0.28 + 0.08
			b_arm_rot = stride * 0.42 - 0.12
			weapon_rot = 0.95 - stride * 0.12
		"jump_startup":
			hip_y = -226.0
			torso_rot = 0.20
			f_arm_rot = 0.35
			b_arm_rot = 0.35
			f_leg_rot = -0.32
			b_leg_rot = 0.40
			weapon_rot = 1.15
		"jump":
			var rising: bool = move_velocity.y < 0.0
			hip_y = -274.0 if rising else -258.0
			torso_rot = -0.08 if rising else 0.16
			head_rot = -0.10 if rising else 0.08
			f_leg_rot = -0.42 if rising else 0.26
			b_leg_rot = 0.36 if rising else -0.30
			f_arm_rot = -0.65 if rising else -0.95
			b_arm_rot = -0.75 if rising else -1.15
			weapon_rot = 0.45 if rising else 0.95
		"landing":
			hip_y = -228.0
			torso_rot = 0.16
			f_leg_rot = -0.26
			b_leg_rot = 0.30
			f_arm_rot = 0.28
			weapon_rot = 1.05
		"dash":
			hip_y = -236.0
			hip_x = 32.0
			torso_rot = 0.42
			head_rot = -0.24
			f_arm_rot = 0.55
			b_arm_rot = 0.65
			weapon_rot = 1.65
			f_leg_rot = -0.62
			b_leg_rot = 0.72
		"guard":
			hip_y = -240.0
			torso_rot = -0.10
			head_rot = 0.06
			f_arm_rot = -0.62
			b_arm_rot = -0.52
			weapon_rot = 0.15
			f_leg_rot = -0.22
			b_leg_rot = 0.26
		"block_hit":
			hip_y = -232.0
			hip_x = -26.0
			torso_rot = -0.24
			f_arm_rot = -0.82
			weapon_rot = 0.05
			f_leg_rot = -0.32
			b_leg_rot = 0.36
		"light_1":
			var swing: float = _attack_curve(p, 0.22, 0.52)
			hip_y = -248.0
			hip_x = lerpf(-16.0, 52.0, swing)
			torso_rot = lerpf(-0.26, 0.34, swing)
			f_arm_rot = lerpf(-1.45, 0.48, swing)
			b_arm_rot = lerpf(0.32, -0.68, swing)
			weapon_rot = lerpf(-0.45, 1.85, swing)
			f_leg_rot = -0.26
			b_leg_rot = 0.38
		"light_2":
			var swing2: float = _attack_curve(p, 0.22, 0.54)
			hip_y = lerpf(-234.0, -276.0, swing2)
			hip_x = lerpf(-12.0, 44.0, swing2)
			torso_rot = lerpf(0.26, -0.20, swing2)
			f_arm_rot = lerpf(0.58, -1.55, swing2)
			b_arm_rot = lerpf(-0.22, 0.45, swing2)
			weapon_rot = lerpf(1.85, -0.35, swing2)
			f_leg_rot = -0.22
			b_leg_rot = 0.34
		"light_3":
			var thrust: float = _attack_curve(p, 0.20, 0.50)
			hip_y = -244.0
			hip_x = lerpf(-22.0, 74.0, thrust)
			torso_rot = lerpf(-0.16, 0.38, thrust)
			f_arm_rot = lerpf(0.42, -0.78, thrust)
			b_arm_rot = 0.58
			weapon_rot = lerpf(1.15, 2.15, thrust)
			f_leg_rot = -0.38
			b_leg_rot = 0.52
		"light_4":
			var swing4: float = _attack_curve(p, 0.24, 0.56)
			hip_y = -248.0
			hip_x = lerpf(12.0, 54.0, swing4)
			torso_rot = lerpf(-0.32, 0.36, swing4)
			f_arm_rot = lerpf(-1.75, 0.42, swing4)
			b_arm_rot = lerpf(-0.55, 0.48, swing4)
			weapon_rot = lerpf(-0.65, 1.72, swing4)
			f_leg_rot = -0.28
			b_leg_rot = 0.40
		"light_5":
			var swing5: float = _attack_curve(p, 0.26, 0.58)
			hip_y = -274.0 + sin(p * PI) * -32.0 + swing5 * 44.0
			hip_x = lerpf(-14.0, 62.0, swing5)
			torso_rot = lerpf(-0.34, 0.48, swing5)
			f_arm_rot = lerpf(-2.05, 0.65, swing5)
			b_arm_rot = lerpf(-1.1, 0.64, swing5)
			weapon_rot = lerpf(-0.75, 2.05, swing5)
			f_leg_rot = -0.32
			b_leg_rot = 0.48
		"heavy_1", "heavy_2", "heavy_3":
			var h_swing: float = _attack_curve(p, 0.34, 0.64)
			hip_y = lerpf(-236.0, -248.0, h_swing)
			hip_x = lerpf(-32.0, 80.0, h_swing)
			torso_rot = lerpf(-0.44, 0.52, h_swing)
			head_rot = lerpf(0.16, -0.20, h_swing)
			if current_state == "heavy_3":
				f_arm_rot = lerpf(0.75, -1.75, h_swing)
				weapon_rot = lerpf(1.95, -0.45, h_swing)
			else:
				f_arm_rot = lerpf(-2.15, 0.72, h_swing)
				weapon_rot = lerpf(-0.85, 2.15, h_swing)
			b_arm_rot = lerpf(-1.35, 0.72, h_swing)
			f_leg_rot = -0.40
			b_leg_rot = 0.54
		"triple_wave":
			var pulse3: float = sin(clampf(p * 3.0, 0.0, 3.0) * PI)
			hip_y = -248.0
			hip_x = 28.0 + pulse3 * 26.0
			torso_rot = 0.14 + pulse3 * 0.22
			f_arm_rot = -0.85 + pulse3 * 1.25
			b_arm_rot = 0.42 - pulse3 * 0.36
			weapon_rot = 0.35 + pulse3 * 1.45
			f_leg_rot = -0.30
			b_leg_rot = 0.42
		"aura_buff":
			hip_y = -264.0
			torso_rot = -0.14
			head_rot = -0.20
			f_arm_rot = -1.95
			b_arm_rot = -1.45
			weapon_rot = -0.15
			f_leg_rot = -0.18
			b_leg_rot = 0.22
		"ultimate":
			var u_swing: float = _attack_curve(p, 0.46, 0.76)
			hip_y = lerpf(-218.0, -256.0, u_swing)
			hip_x = lerpf(-38.0, 96.0, u_swing)
			torso_rot = lerpf(-0.38, 0.54, u_swing)
			head_rot = lerpf(0.20, -0.22, u_swing)
			f_arm_rot = lerpf(-2.25, 0.72, u_swing)
			b_arm_rot = lerpf(-1.60, 0.78, u_swing)
			weapon_rot = lerpf(-0.85, 2.18, u_swing)
			f_leg_rot = -0.44
			b_leg_rot = 0.58
		"hit":
			hip_y = -248.0
			hip_x = -30.0
			torso_rot = -0.38
			head_rot = -0.24
			f_arm_rot = -0.78
			b_arm_rot = -1.05
			weapon_rot = 0.75
			f_leg_rot = 0.24
			b_leg_rot = -0.20
		"ko":
			var k: float = clampf(t / 0.55, 0.0, 1.0)
			hip_y = lerpf(-244.0, -158.0, k)
			torso_rot = lerpf(0.0, 0.32, k)
			head_rot = lerpf(0.0, 0.38, k)
			f_arm_rot = lerpf(-0.06, -0.35, k)
			b_arm_rot = lerpf(-0.18, 0.48, k)
			weapon_rot = lerpf(0.55, 3.10, k)
			f_leg_rot = lerpf(0.0, -0.82, k)
			b_leg_rot = lerpf(0.0, 1.08, k)

	hip_pivot.position = hip_pivot.position.lerp(Vector2(hip_x, hip_y), blend)
	torso_pivot.rotation = lerp_angle(torso_pivot.rotation, torso_rot, blend)
	head_pivot.rotation = lerp_angle(head_pivot.rotation, head_rot, blend)
	front_arm_pivot.rotation = lerp_angle(front_arm_pivot.rotation, f_arm_rot, blend)
	back_arm_pivot.rotation = lerp_angle(back_arm_pivot.rotation, b_arm_rot, blend)
	weapon_pivot.rotation = lerp_angle(weapon_pivot.rotation, weapon_rot, blend)
	front_leg_pivot.rotation = lerp_angle(front_leg_pivot.rotation, f_leg_rot, blend)
	back_leg_pivot.rotation = lerp_angle(back_leg_pivot.rotation, b_leg_rot, blend)

func _attack_curve(p: float, windup_end: float, strike_end: float) -> float:
	if p < windup_end:
		return 0.0
	if p < strike_end:
		var u: float = (p - windup_end) / maxf(0.01, strike_end - windup_end)
		return 1.0 - pow(1.0 - u, 4.0)
	return 1.0

func _update_cape_spring(delta: float) -> void:
	if cape_pivot == null:
		return
	var speed_factor: float = clampf(absf(move_velocity.x) / 380.0, 0.0, 1.6)
	var fall_factor: float = clampf(-move_velocity.y / 650.0, -0.7, 0.8)
	var target_ang: float = 0.06 + speed_factor * 0.42 - fall_factor * 0.35 + sin(state_time * 5.2) * (0.06 + speed_factor * 0.08)
	if current_state == "aura_buff":
		target_ang = 0.58 + sin(state_time * 16.0) * 0.14
	elif current_state == "ko":
		target_ang = -0.25
	var stiffness: float = 65.0
	var damping: float = 9.5
	var force: float = (target_ang - _cape_spring_angle) * stiffness - _cape_angle_vel * damping
	_cape_angle_vel += force * delta
	_cape_spring_angle += _cape_angle_vel * delta
	cape_pivot.rotation = clampf(_cape_spring_angle, -0.65, 1.1)

func _draw() -> void:
	# 实时接地阴影（柔和贴合地面）
	var shadow_scale: float = 1.0 if is_grounded else 0.56
	var shadow_alpha: float = 0.22 if is_grounded else 0.10
	draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(shadow_scale, 0.26 * shadow_scale))
	draw_circle(Vector2.ZERO, 36.0, Color(0.05, 0.08, 0.14, shadow_alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class _SlashArcFX extends Node2D:
	var _active: bool = false
	var _elapsed: float = 0.0
	var _duration: float = 0.16
	var _start_rad: float = 0.0
	var _end_rad: float = 0.0
	var _radius: float = 96.0
	var _thickness: float = 26.0
	var _color: Color = Color("#6ee7b7")
	var _facing: int = 1

	func play_arc(start_deg: float, end_deg: float, radius: float, color: Color, duration: float, thickness: float, face_dir: int) -> void:
		_active = true
		_elapsed = 0.0
		_duration = maxf(0.06, duration)
		_start_rad = deg_to_rad(start_deg)
		_end_rad = deg_to_rad(end_deg)
		_radius = radius
		_color = color
		_thickness = thickness
		_facing = 1 if face_dir >= 0 else -1
		queue_redraw()

	func _process(delta: float) -> void:
		if not _active:
			return
		_elapsed += delta
		if _elapsed >= _duration:
			_active = false
		queue_redraw()

	func _draw() -> void:
		if not _active:
			return
		var t: float = clampf(_elapsed / _duration, 0.0, 1.0)
		var alpha: float = pow(1.0 - t, 1.45)
		var lead_t: float = minf(1.0, t * 2.2)
		var tail_t: float = maxf(0.0, (t - 0.15) / 0.85)
		var a0: float = lerpf(_start_rad, _end_rad, tail_t)
		var a1: float = lerpf(_start_rad, _end_rad, lead_t)
		var steps: int = 16
		var outer_pts := PackedVector2Array()
		var inner_pts := PackedVector2Array()
		var center := Vector2(_facing * 18.0, -64.0)
		for i in range(steps + 1):
			var u: float = float(i) / float(steps)
			var ang: float = lerpf(a0, a1, u)
			var taper: float = sin(u * PI)
			var r_out: float = _radius + _thickness * 0.45 * taper
			var r_in: float = maxf(10.0, _radius - _thickness * 0.55 * taper)
			var dir_v := Vector2(cos(ang) * _facing, sin(ang))
			outer_pts.append(center + dir_v * r_out)
			inner_pts.append(center + dir_v * r_in)
		var poly := PackedVector2Array()
		for p in outer_pts:
			poly.append(p)
		for i in range(inner_pts.size() - 1, -1, -1):
			poly.append(inner_pts[i])
		if poly.size() >= 3:
			draw_colored_polygon(poly, Color(_color.r, _color.g, _color.b, alpha * 0.88))
			draw_polyline(outer_pts, Color(1.0, 1.0, 1.0, alpha * 0.95), 3.5, true)
