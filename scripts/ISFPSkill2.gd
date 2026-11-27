extends Node2D

const NO_HIT = preload("res://assets/fighters/isfp/newframes/skill_i_no_hit_12f_stand_v2.png")
const ON_HIT = preload("res://assets/fighters/isfp/newframes/skill_i_on_hit_12f_stand_v2.png")
const IDLE_TRANSITION = preload("res://assets/fighters/isfp/newframes/skill_i_idle_transition_3f_v2.png")
const STEP := 1.0 / 60.0
const skill2BranchA_NoHitConfig := {
	"startup_ticks": [3, 3, 3, 4],
	"breath_ticks": [12, 12],
	"window_ticks": 120,
	"recovery_ticks": [6, 7, 7, 7, 6, 5],
	"slide_speed": 75.0,
	"cancel_frame": 11,
	"buffer_ticks": 5,
	"cooldown": 5.0,
}
const COUNTER_TICKS: Array[int] = [3, 3, 3, 4, 4, 7]
const RADIUS := 135.0
const IDLE_BLEND_TICKS := 4
const IDLE_TRANSITION_TICKS: Array[int] = [4, 4, 5]

@onready var fighter: BaseFighter = get_parent()
@onready var pose: Sprite2D = $Pose
@onready var player: AnimationPlayer = $AnimationPlayer

var active := false
var applying_pulse := false
var finishing_pulse := false
var phase: StringName
var ticks := 0
var frame := 0
var buffer_ticks := 0
var last_pulse_frame := 0
var connected := false
var absorbed_attacker: BaseFighter
var elapsed_ticks := 0.0
var idle_blend_tick := 0

func _ready() -> void:
	var library := AnimationLibrary.new()
	_add_clip(library, &"startup", NO_HIT, 0, skill2BranchA_NoHitConfig.startup_ticks)
	_add_clip(library, &"sense", NO_HIT, 4, skill2BranchA_NoHitConfig.breath_ticks, true)
	_add_clip(library, &"recover", NO_HIT, 6, skill2BranchA_NoHitConfig.recovery_ticks)
	_add_clip(library, &"counter", ON_HIT, 6, COUNTER_TICKS)
	_add_clip(library, &"idle_transition", IDLE_TRANSITION, 0, IDLE_TRANSITION_TICKS)
	player.add_animation_library(&"", library)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL

func _add_clip(library: AnimationLibrary, clip: StringName, sheet: Texture2D, first: int, durations: Array, loop := false) -> void:
	var animation := Animation.new()
	var path := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(path, NodePath("Pose:frame"))
	animation.value_track_set_update_mode(path, Animation.UPDATE_DISCRETE)
	var texture_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(texture_track, NodePath("Pose:texture"))
	animation.value_track_set_update_mode(texture_track, Animation.UPDATE_DISCRETE)
	animation.track_insert_key(texture_track, 0.0, sheet)
	var time := 0
	for index in range(durations.size()):
		animation.track_insert_key(path, time * STEP, first + index)
		time += durations[index]
	animation.length = time * STEP
	if loop:
		animation.loop_mode = Animation.LOOP_LINEAR
	library.add_animation(clip, animation)

func start() -> void:
	active = true
	connected = false
	absorbed_attacker = null
	buffer_ticks = 0
	last_pulse_frame = 0
	elapsed_ticks = 0.0
	idle_blend_tick = 0
	pose.self_modulate.a = 1.0
	fighter.charging_slot = ""
	fighter.guarding = false
	fighter.attack_buffer_timer = 0.0
	fighter.jump_buffer_timer = 0.0
	fighter.skill1_buffer_timer = 0.0
	fighter.action_anim_state = "skill2"
	fighter.action_anim_timer = 0.0
	fighter.isfp_startup_step_timer = 0.0
	fighter.hitbox_active_timer = 0.0
	fighter.hitbox_col.set_deferred("disabled", true)
	pose.flip_h = fighter.facing < 0
	fighter.sprite.hide()
	pose.show()
	_play(&"startup")

func _play(clip: StringName) -> void:
	phase = clip
	ticks = 0
	var is_transition := clip == &"idle_transition"
	pose.frame = 0
	pose.hframes = 3 if is_transition else 6
	pose.vframes = 1 if is_transition else 2
	if is_transition:
		_align_pose(670.0, 325.0)
	else:
		_align_pose(326.0, 167.0)
	player.play(clip)
	player.advance(0.0)
	frame = pose.frame + (13 if is_transition else 1)

func _align_pose(art_height: float, sole_from_center: float) -> void:
	var idle_scale := fighter.target_sprite_height * fighter.sprite_scale_mult / 724.0
	pose.scale = Vector2.ONE * (idle_scale * 392.0 / art_height)
	var idle_sole := -fighter.target_sprite_height * 0.5 + 4.0 + 192.0 * idle_scale
	pose.position.y = idle_sole - sole_from_center * pose.scale.y

func tick(delta: float, input: Dictionary) -> bool:
	if not active:
		return false
	if fighter.is_ko or fighter.battle_locked or fighter.hitstun_timer > 0.0:
		finish()
		return false
	elapsed_ticks += delta / STEP
	while active and elapsed_ticks >= 0.9999:
		elapsed_ticks -= 1.0
		if not _step(input):
			return false
		if get_tree().paused:
			return true
	fighter.velocity.x = 0.0
	if phase == &"startup" and frame <= 3:
		fighter.velocity.x = signf(float(input["horiz"])) * float(skill2BranchA_NoHitConfig.slide_speed)
	if not fighter.is_on_floor():
		fighter.velocity.y += fighter.gravity_force * delta
	fighter.move_and_slide()
	fighter.global_position.x = clampf(fighter.global_position.x, 220.0, 1580.0)
	return active

func _step(input: Dictionary) -> bool:
	ticks += 1
	buffer_ticks = maxi(0, buffer_ticks - 1)
	if phase == &"recover" and bool(input["light_just"]):
		buffer_ticks = skill2BranchA_NoHitConfig.buffer_ticks
	player.advance(STEP)
	frame = pose.frame + (13 if phase == &"idle_transition" else 1)
	match phase:
		&"startup":
			if not player.is_playing():
				_play(&"sense")
		&"sense":
			if ticks >= int(skill2BranchA_NoHitConfig.window_ticks):
				_play(&"recover")
		&"recover":
			if frame >= int(skill2BranchA_NoHitConfig.cancel_frame):
				if bool(input["dash_just"]) and fighter.dash_cd <= 0.0:
					finish()
					return false
				if buffer_ticks > 0 and fighter.basic_cd <= 0.0:
					finish()
					fighter.attack_buffer_type = "light"
					fighter.attack_buffer_timer = buffer_ticks * STEP
					return false
			if not player.is_playing():
				_play(&"idle_transition")
		&"counter":
			if frame in [9, 10, 11] and frame != last_pulse_frame:
				last_pulse_frame = frame
				_pulse()
			if frame == 12 and bool(input["dash_just"]) and fighter.dash_cd <= 0.0:
				finish()
				return false
			if not player.is_playing():
				_play(&"idle_transition")
		&"idle_transition":
			if bool(input["dash_just"]) and fighter.dash_cd <= 0.0:
				finish()
				return false
			if not player.is_playing():
				finish()
				return false
			if frame == 15:
				_blend_into_idle()
	return true

func _blend_into_idle() -> void:
	if idle_blend_tick == 0:
		fighter._play_anim("idle", true)
		fighter.anim_player.pause()
		fighter.sprite.position.y = -fighter.target_sprite_height * 0.5 + 4.0
		fighter.sprite.rotation = 0.0
		fighter.sprite.show()
	idle_blend_tick += 1
	pose.self_modulate.a = 1.0 - smoothstep(0.0, float(IDLE_BLEND_TICKS), float(idle_blend_tick))

func absorb(attacker: BaseFighter) -> bool:
	if not active or not is_instance_valid(attacker) or attacker == fighter:
		return false
	if phase == &"counter" and frame <= 11:
		return attacker == absorbed_attacker
	if phase != &"sense":
		return false
	absorbed_attacker = attacker
	_play(&"counter")
	var vfx := BattleVFX.get_current(get_tree())
	if vfx:
		vfx.trigger_screen_flash(Color("#fff3d0"), 0.16, 0.12)
	AudioManager.play_sfx("parry", -3.0)
	return true

func _pulse() -> void:
	var center := fighter.global_position - Vector2(0.0, 55.0)
	var vfx := BattleVFX.get_current(get_tree())
	finishing_pulse = frame == 11
	applying_pulse = true
	for node in get_tree().get_nodes_in_group("fighters"):
		var target := node as BaseFighter
		if target == null or target == fighter or target.is_ko or target.battle_locked:
			continue
		var delta := (target.global_position - Vector2(0.0, 55.0)) - center
		if delta.length_squared() > RADIUS * RADIUS:
			continue
		var side := signf(delta.x) if absf(delta.x) > 0.01 else float(fighter.facing)
		var knockback := Vector2(side * 480.0, -180.0) if finishing_pulse else Vector2.ZERO
		var before := target.hp
		target.take_damage(8, knockback, fighter)
		connected = connected or target.hp < before
	applying_pulse = false
	if finishing_pulse:
		if vfx:
			vfx.spawn_paint_hit_sparks(center, true)
		if connected:
			GameManager.trigger_shake(7.0, 6.0 * STEP)
			GameManager.trigger_hitstop(8.0 * STEP)
	finishing_pulse = false

func finish() -> void:
	if not active:
		return
	active = false
	absorbed_attacker = null
	player.stop()
	pose.hide()
	pose.self_modulate.a = 1.0
	fighter.sprite.show()
	fighter.velocity.x = 0.0
	fighter.action_anim_state = ""
	fighter.skill2_cd = 0.0 if fighter.practice_skip_skill_cooldowns else skill2BranchA_NoHitConfig.cooldown
	fighter._play_anim("idle", true)
