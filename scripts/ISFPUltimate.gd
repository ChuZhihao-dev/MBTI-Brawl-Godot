extends Node2D

const ORIGINAL_SHEET = preload("res://assets/fighters/isfp/newframes/ultimate_16f_sheet.png")
const AIR_COMBO_SHEET = preload("res://assets/fighters/isfp/newframes/ultimate_16f_sheet_v2.png")
const UPDATED_STRIKE_SHEET = preload("res://assets/fighters/isfp/newframes/ultimate_16f_sheet_v3.png")
const CAGE_ART = preload("res://assets/fighters/isfp/newframes/ultimate_paint_rope_cage_concept.png")
const CUTOUT = preload("res://shaders/cutout_white.gdshader")
const FRAME_TICKS: Array[int] = [2, 3, 3, 3, 3, 4, 18, 5, 3, 3, 3, 3, 3, 9, 4, 14, 4]
const STEP: float = 1.0 / 60.0
const DURATION: float = 3.0
const BURST_FRAME := 16
const BLOW_BEFORE_BURST := 0.18
const LAUNCH_HEIGHT: float = 118.0
const LAUNCH_VELOCITY: float = -460.0
# Endpoint in each atlas cell, measured from the top of that cell.
const ROPE_COLORS: Array[Color] = [Color("#ff379d"), Color("#fdd72b"), Color("#16dce6"), Color("#8e61ff")]
const FEET_Y: Array[float] = [327, 325, 325, 320, 318, 318, 318, 258, 246, 224, 278, 244, 271, 262, 318, 321, 321]

@onready var fighter: BaseFighter = get_parent()
@onready var pose: Sprite2D = $Pose
@onready var player: AnimationPlayer = $AnimationPlayer

var active := false
var frame := 0
var target: BaseFighter
var pending_ko: BaseFighter
var overlay: Control
var camera: Camera2D
var cage: Sprite2D
var launch_ghost: Sprite2D
var startup_target: BaseFighter
var launch_origin: Vector2
var launch_motion_start: float
var launch_end: float
var caster_floor: float
var rope_progress := 0.0
var original_ticks := 0
var blow_started_at := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_physics_process(false)
	var material := ShaderMaterial.new()
	material.shader = CUTOUT
	material.set_shader_parameter("enable_white_key", 1.0)
	material.set_shader_parameter("white_threshold", 0.83)
	material.set_shader_parameter("feather", 0.035)
	pose.material = material
	pose.hide()
	pose.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	cage = Sprite2D.new()
	cage.texture = CAGE_ART
	cage.top_level = true
	cage.z_index = 4
	var cage_material := ShaderMaterial.new()
	cage_material.shader = CUTOUT
	cage_material.set_shader_parameter("enable_white_key", 1.0)
	cage_material.set_shader_parameter("white_threshold", 0.93)
	cage.material = cage_material
	cage.hide()
	add_child(cage)

	var animation := Animation.new()
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath("Pose:texture"))
	animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
	for ticks in FRAME_TICKS:
		original_ticks += ticks
	var elapsed := 0
	for index in range(FRAME_TICKS.size()):
		var atlas := AtlasTexture.new()
		var sheet := ORIGINAL_SHEET if index == 0 or index >= BURST_FRAME - 1 else AIR_COMBO_SHEET
		var source_index := index - 1 if index >= BURST_FRAME - 1 else index
		if index in [5, 6, 8, 10, 12]:
			sheet = UPDATED_STRIKE_SHEET
		atlas.atlas = sheet
		var left := roundi(float(source_index % 8) * sheet.get_width() / 8.0)
		var right := roundi(float(source_index % 8 + 1) * sheet.get_width() / 8.0)
		var height := sheet.get_height() / 2.0
		atlas.region = Rect2(left, floori(source_index / 8.0) * height, right - left, height)
		atlas.filter_clip = true
		var time := elapsed * DURATION / original_ticks
		if index == 7:
			launch_end = time
		animation.track_insert_key(track, time, atlas)
		elapsed += FRAME_TICKS[index]
	animation.length = DURATION
	var library := AnimationLibrary.new()
	library.add_animation(&"ultimate", animation)
	player.add_animation_library(&"", library)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL

func start() -> void:
	active = true
	set_physics_process(true)
	GameManager.begin_cinematic(self)
	frame = 1
	rope_progress = 0.0
	startup_target = null
	caster_floor = fighter.global_position.y
	fighter.invincible_timer = 0.0
	fighter.action_anim_state = ""
	fighter.action_anim_timer = 0.0
	fighter.can_hit_cancel = false
	fighter.can_cancel_attack = false
	fighter.hitbox_active_timer = 0.0
	fighter.hitbox_col.set_deferred("disabled", true)
	fighter.guarding = false
	fighter.velocity = Vector2.ZERO
	pose.flip_h = fighter.facing < 0
	pose.scale = Vector2.ONE * (fighter.target_sprite_height / 260.0)
	pose.show()
	fighter.sprite.hide()
	player.play(&"ultimate")
	player.advance(0.0)
	_position_pose()
	camera = get_viewport().get_camera_2d()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	overlay = preload("res://scripts/ISFPUltimateOverlay.gd").new()
	layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.shatter_duration = DURATION * float(FRAME_TICKS[BURST_FRAME - 1] + FRAME_TICKS[BURST_FRAME]) / original_ticks - BLOW_BEFORE_BURST
	overlay.begin_frame(1)
	AudioManager.play_sfx("ult_cast", -1.5)

func _exit_tree() -> void:
	if active:
		_release_target()
		GameManager.end_cinematic(self)

func _physics_process(delta: float) -> void:
	if GameManager.is_pause_menu_open:
		return
	if is_instance_valid(camera) and camera.has_method("advance_cinematic"):
		camera.advance_cinematic(delta)
	if is_instance_valid(target):
		target._update_hit_flash(delta)
	if is_instance_valid(pending_ko) and pending_ko != target:
		pending_ko._update_hit_flash(delta)
	fighter.queue_redraw()
	_tick_cinematic(delta)

func _tick_cinematic(delta: float) -> void:
	if fighter.is_ko or fighter.battle_locked or (frame >= 6 and not overlay.bursting and not is_instance_valid(target)):
		finish()
		return
	var previous_texture := pose.texture
	player.advance(delta)
	if not player.is_playing():
		finish()
		return
	if pose.texture != previous_texture:
		frame += 1
		_position_pose()
		_enter_frame()
		if not active:
			return
	if frame == BURST_FRAME and not overlay.bursting and player.current_animation_position - blow_started_at >= BLOW_BEFORE_BURST:
		_break_cage()
	# The held strike pose counts toward the three-second budget.
	if GameManager.hitstop_timer > 0.0:
		return
	delta *= original_ticks * STEP / DURATION

	if frame >= 3 and frame <= 5:
		_pull_target(delta)
	if frame == 5:
		rope_progress = minf(rope_progress + delta * 15.0, 1.0)
		queue_redraw()
	if frame == 6:
		var center := fighter.global_position.x + 94.0 * fighter.facing
		target.move_and_collide(Vector2(clampf(center - target.global_position.x, -1000.0 * delta, 1000.0 * delta), 0.0))
	elif frame == 7:
		var progress := clampf((player.current_animation_position - launch_motion_start) / (launch_end - launch_motion_start), 0.0, 1.0)
		var rise := progress * (2.0 - progress)
		target.global_position = launch_origin - Vector2(0.0, LAUNCH_HEIGHT * rise)
		target.velocity.y = LAUNCH_VELOCITY * (1.0 - progress)
		if is_instance_valid(launch_ghost):
			launch_ghost.modulate.a = 0.34 * (1.0 - progress)
	elif frame == 10:
		target.global_position.y += target.velocity.y * delta
		target.velocity.y = move_toward(target.velocity.y, 0.0, 650.0 * delta)

	if frame <= 7 or frame >= 14:
		fighter.velocity.y += fighter.gravity_force * delta
		var collision := fighter.move_and_collide(fighter.velocity * delta)
		if collision and collision.get_normal().y < -0.7:
			fighter.velocity.y = 0.0
	_update_cage()

func _draw() -> void:
	if not active or frame != 5 or not is_instance_valid(startup_target):
		return
	var facing_direction := float(fighter.facing)
	var brush_origin := Vector2(36.0 * facing_direction, -65.0)
	var cage_center := to_local(startup_target.global_position) + Vector2(0.0, -59.0)
	for index in range(ROPE_COLORS.size()):
		var spacing := (index - 1.5) * 14.0
		var points := PackedVector2Array([
			brush_origin,
			brush_origin.lerp(cage_center, rope_progress * 0.36) + Vector2(0.0, spacing * 0.6),
			brush_origin.lerp(cage_center, rope_progress * 0.78) + Vector2(0.0, spacing),
			brush_origin.lerp(cage_center, rope_progress) + Vector2(2.0 * facing_direction, spacing - 8.0)
		])
		draw_polyline(points, ROPE_COLORS[index].darkened(0.32), 7.0, true)
		draw_polyline(points, ROPE_COLORS[index], 4.0, true)

func _update_cage() -> void:
	if not is_instance_valid(target):
		return
	cage.global_position = target.global_position - Vector2(0.0, target.target_sprite_height * 0.48)
	cage.scale = Vector2.ONE * (target.target_sprite_height * 1.2 / CAGE_ART.get_height())

func _position_pose() -> void:
	pose.position.y = (181.0 - FEET_Y[frame - 1]) * pose.scale.y

func _enter_frame() -> void:
	overlay.begin_frame(frame)
	match frame:
		2:
			if is_instance_valid(camera) and camera.has_method("set_ultimate_zoom"):
				camera.set_ultimate_zoom(self, 1.06)
		6:
			if is_instance_valid(camera) and camera.has_method("set_ultimate_zoom"):
				camera.set_ultimate_zoom(self, 1.0)
			queue_redraw()
			_lock_target()
			if not is_instance_valid(target):
				finish()
				return
			_update_cage()
			cage.show()
		7:
			launch_origin = target.global_position
			launch_motion_start = player.current_animation_position + 3.0 * STEP
			_strike(9, LAUNCH_VELOCITY, 3, 0.0, 0)
			_leave_launch_ghost()
		8:
			_teleport_to_apex()
			_clear_launch_ghost()
			pose.show()
		9:
			_strike(8, 0.0, 3, 6.0, 4)
		10:
			if is_instance_valid(target):
				target.velocity.y = -40.0
		11:
			_strike(8, 0.0, 3, 7.0, 4)
		13:
			_strike(12, 0.0, 0, 14.0, 8)
		14:
			var landing_time := (FRAME_TICKS[13] + FRAME_TICKS[14]) * STEP
			var drop := maxf(0.0, caster_floor - fighter.global_position.y)
			fighter.velocity = Vector2(0.0, maxf(165.0, drop / landing_time - fighter.gravity_force * landing_time * 0.5))

		BURST_FRAME:
			blow_started_at = player.current_animation_position

func _break_cage() -> void:
	var viewport_size := get_viewport_rect().size
	var screen_position := get_canvas_transform() * cage.global_position
	overlay.burst(screen_position / viewport_size)
	_release_target()
	AudioManager.play_sfx("glass_shatter", -2.5)
	GameManager.trigger_hitstop(4.0 * STEP)
	GameManager.trigger_shake(12.0, 8.0 * STEP)

func _leave_launch_ghost() -> void:
	launch_ghost = Sprite2D.new()
	launch_ghost.texture = pose.texture
	launch_ghost.material = pose.material
	launch_ghost.flip_h = pose.flip_h
	launch_ghost.top_level = true
	launch_ghost.z_index = pose.z_index
	add_child(launch_ghost)
	launch_ghost.global_transform = pose.global_transform
	launch_ghost.modulate = Color(0.45, 0.85, 1.0, 0.34)
	pose.hide()

func _clear_launch_ghost() -> void:
	if is_instance_valid(launch_ghost):
		launch_ghost.hide()
		launch_ghost.queue_free()
	launch_ghost = null

func _teleport_to_apex() -> void:
	target.global_position = launch_origin - Vector2(0.0, LAUNCH_HEIGHT)
	target.velocity = Vector2.ZERO
	var side := fighter.facing
	var reach := target.global_position.x - 88.0 * side
	if reach < 220.0 or reach > 1580.0:
		side = -side
		reach = target.global_position.x - 88.0 * side
	fighter.global_position = Vector2(clampf(reach, 220.0, 1580.0), target.global_position.y + 10.0)
	fighter.velocity = Vector2.ZERO
	fighter.facing = side
	fighter._update_facing_visual()
	pose.flip_h = side < 0
	_update_cage()

func _find_target() -> BaseFighter:
	for node in get_tree().get_nodes_in_group("fighters"):
		var other := node as BaseFighter
		if other == null or other == fighter or other.is_ko or other.battle_locked:
			continue
		if is_instance_valid(other.isfp_ultimate_owner) or other.invincible_timer > 0.0 or other.is_isfp_ultimate_invulnerable():
			continue
		var gap := other.global_position - fighter.global_position
		if gap.length() <= 260.0 and gap.x * fighter.facing >= -18.0:
			return other
	return null

func _pull_target(delta: float) -> void:
	startup_target = _find_target()
	if startup_target:
		var center := fighter.global_position.x + 94.0 * fighter.facing
		startup_target.move_and_collide(Vector2(clampf(center - startup_target.global_position.x, -220.0 * delta, 220.0 * delta), 0.0))

func _lock_target() -> void:
	target = startup_target if is_instance_valid(startup_target) and startup_target == _find_target() else null
	if target:
		if target.paint_ultimate != null and target.paint_ultimate.active:
			target.paint_ultimate.finish()
		target.isfp_ultimate_owner = fighter
		target.velocity = Vector2.ZERO
		target.guarding = false
		target.charging_slot = ""
		target.dash_timer = 0.0
		target._play_anim("hit", true)

func _strike(damage: int, vertical_speed: float, stop_ticks: int, shake: float, shake_ticks: int) -> void:
	if shake > 0.0:
		GameManager.trigger_shake(shake, shake_ticks * STEP)
	if not is_instance_valid(target):
		return
	if target.hp <= 0:
		return
	var health := target.hp
	target.take_damage(damage, Vector2(0.0, vertical_speed), fighter, true)
	if target.hp < health and stop_ticks > 0:
		GameManager.trigger_hitstop(stop_ticks * STEP)

func _release_target() -> void:
	cage.hide()
	startup_target = null
	if is_instance_valid(target):
		target.isfp_ultimate_owner = null
		target.velocity = Vector2.ZERO
	target = null

func finish() -> void:
	if not active:
		return
	active = false
	set_physics_process(false)
	GameManager.end_cinematic(self)
	_release_target()
	_clear_launch_ghost()
	if is_instance_valid(camera) and camera.has_method("set_ultimate_zoom"):
		camera.set_ultimate_zoom(self, 1.0)
	if is_instance_valid(overlay):
		overlay.hide()
		overlay.get_parent().queue_free()
		overlay = null
	player.stop()
	pose.hide()
	queue_redraw()
	fighter.sprite.show()
	fighter._play_anim("idle", true)
	if is_instance_valid(pending_ko):
		var defeated := pending_ko
		pending_ko = null
		defeated._trigger_ko(fighter, true)
