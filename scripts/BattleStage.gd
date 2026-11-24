extends Node2D

const MATCH_DURATION: float = 99.0

var p1: BaseFighter
var p2: BaseFighter
var vfx: BattleVFX
var match_time: float = MATCH_DURATION
var match_ended: bool = false

@onready var camera: Camera2D = $SmashCamera2D
@onready var hud: CanvasLayer = $HUD

func _ready() -> void:
	GameManager.is_pause_menu_open = false
	GameManager.hitstop_timer = 0.0
	get_tree().paused = false

	vfx = BattleVFX.new()
	vfx.name = "BattleVFX"
	add_child(vfx)

	# 2D HDR Bloom 后期辉光（阈值 1.05：背景和 UI 保持锐利，仅 HDR 特效发光）
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.05
	env.glow_intensity = 0.9
	env.glow_strength = 1.15
	env.glow_bloom = 0.22
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	world_env.environment = env
	add_child(world_env)

	var p1_pos := Vector2(580.0, 550.0)
	var p2_pos := Vector2(1210.0, 550.0)
	var old_p1 := get_node_or_null("P1")
	if old_p1:
		p1_pos = old_p1.position
		remove_child(old_p1)
		old_p1.queue_free()
	var old_p2 := get_node_or_null("P2")
	if old_p2:
		p2_pos = old_p2.position
		remove_child(old_p2)
		old_p2.queue_free()

	p1 = _spawn_fighter(GameManager.selected_p1, 1, p1_pos)
	p2 = _spawn_fighter(GameManager.selected_p2, 2, p2_pos)

	if camera and camera.has_method("set_targets"):
		camera.set_targets(p1, p2)
	if hud and hud.has_method("bind_fighters"):
		hud.bind_fighters(p1, p2)

func _spawn_fighter(fid: String, player_idx: int, spawn_pos: Vector2) -> BaseFighter:
	var scene: PackedScene = GameManager.get_fighter_scene(fid)
	var fighter: BaseFighter = scene.instantiate() as BaseFighter
	fighter.name = "P1" if player_idx == 1 else "P2"
	fighter.player_index = player_idx
	fighter.position = spawn_pos

	var meta: Dictionary = GameManager.get_fighter_meta(fid)
	fighter.fighter_id = fid
	fighter.fighter_name = String(meta["name"])
	fighter.theme_color = Color(String(meta["color"]))
	fighter.max_hp = int(meta["hp"])
	fighter.hp = fighter.max_hp
	fighter.move_speed = float(meta["speed"])
	fighter.jump_force = float(meta["jump"])

	add_child(fighter)
	fighter.load_fighter_sprites(fid)
	fighter.ko_triggered.connect(_on_fighter_ko)
	return fighter

func _process(delta: float) -> void:
	if match_ended:
		return
	match_time = maxf(0.0, match_time - delta)
	if hud and hud.has_method("set_timer_value"):
		hud.set_timer_value(int(ceil(match_time)))
	if match_time <= 0.0:
		_finish_by_timeout()

func _on_fighter_ko(loser: BaseFighter, _killer: BaseFighter, by_ultimate: bool) -> void:
	if match_ended:
		return
	match_ended = true
	if p1:
		p1.battle_locked = true
	if p2:
		p2.battle_locked = true

	var winner: BaseFighter = p2 if loser == p1 else p1
	if by_ultimate and winner and winner.fighter_id == "enfj" and vfx:
		var t1 := get_tree().create_timer(0.75)
		t1.timeout.connect(func() -> void:
			if is_instance_valid(vfx):
				vfx.play_empathy_finisher(winner.fighter_name, func() -> void:
					if is_instance_valid(hud) and hud.has_method("show_ko_overlay"):
						hud.show_ko_overlay(winner, "ULTIMATE FINISH!")
				)
		)
	else:
		var t2 := get_tree().create_timer(1.2)
		t2.timeout.connect(func() -> void:
			if is_instance_valid(hud) and hud.has_method("show_ko_overlay"):
				hud.show_ko_overlay(winner, "K.O.!")
		)

func _finish_by_timeout() -> void:
	if match_ended:
		return
	match_ended = true
	if p1:
		p1.battle_locked = true
	if p2:
		p2.battle_locked = true
	AudioManager.play_sfx("ko", -2.0)

	var p1_ratio: float = float(p1.hp) / maxf(1.0, float(p1.max_hp)) if p1 else 0.0
	var p2_ratio: float = float(p2.hp) / maxf(1.0, float(p2.max_hp)) if p2 else 0.0
	var winner: BaseFighter = null
	if p1_ratio > p2_ratio:
		winner = p1
	elif p2_ratio > p1_ratio:
		winner = p2
	if hud and hud.has_method("show_ko_overlay"):
		hud.show_ko_overlay(winner, "TIME UP!")
