extends Node2D

const MATCH_DURATION: float = 99.0

var p1: BaseFighter
var p2: BaseFighter
var p2_ai: FighterAI
var vfx: BattleVFX
var p1_spawn_pos := Vector2(580.0, 550.0)
var p2_spawn_pos := Vector2(1210.0, 550.0)
var match_time: float = MATCH_DURATION
var match_started: bool = false
var round_ending: bool = false
var match_ended: bool = false
var practice_mode: bool = false
var _practice_cooldowns := false
var _practice_combat := false
var _practice_behavior := 0
var _practice_position := 0
const PRACTICE_POSITIONS: Array[Vector2] = [Vector2(855.0, 945.0), Vector2(760.0, 1040.0), Vector2(1465.0, 1550.0)]

@onready var camera: Camera2D = $SmashCamera2D
@onready var hud: CanvasLayer = $HUD

func _ready() -> void:
	practice_mode = GameManager.battle_mode == "practice"
	GameManager.is_pause_menu_open = false
	GameManager.hitstop_timer = 0.0
	GameManager.reset_match_state()
	get_tree().paused = false
	AudioManager.start_battle_bgm()

	# 动态阳光丁达尔光束与飘浮光尘氛围
	var atmo := ArenaAtmosphereFX.new()
	atmo.name = "ArenaAtmosphereFX"
	add_child(atmo)

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

	# 天空竞技场左右上升风柱弹射跳板
	var left_geyser := WindGeyser.new()
	left_geyser.name = "WindGeyserLeft"
	left_geyser.position = Vector2(275.0, 554.0)
	add_child(left_geyser)

	var right_geyser := WindGeyser.new()
	right_geyser.name = "WindGeyserRight"
	right_geyser.position = Vector2(1525.0, 554.0)
	add_child(right_geyser)

	# 中央顶层悬浮台随机道具与定时炸弹刷新器
	if not practice_mode:
		var spawner := ArenaItemSpawner.new()
		spawner.name = "ArenaItemSpawner"
		spawner.spawn_position = Vector2(900.0, 244.0)
		add_child(spawner)

	p1_spawn_pos = Vector2(580.0, 550.0)
	p2_spawn_pos = Vector2(1210.0, 550.0)
	var old_p1 := get_node_or_null("P1")
	if old_p1:
		p1_spawn_pos = old_p1.position
		remove_child(old_p1)
		old_p1.queue_free()
	var old_p2 := get_node_or_null("P2")
	if old_p2:
		p2_spawn_pos = old_p2.position
		remove_child(old_p2)
		old_p2.queue_free()

	if practice_mode:
		p1_spawn_pos.x = PRACTICE_POSITIONS[0].x
		p2_spawn_pos.x = PRACTICE_POSITIONS[0].y
	p1 = _spawn_fighter(GameManager.selected_p1, 1, p1_spawn_pos)
	p2 = _spawn_fighter(GameManager.selected_p2, 2, p2_spawn_pos)

	if GameManager.battle_mode == "ai":
		_spawn_p2_ai(GameManager.ai_difficulty)

	if camera and camera.has_method("set_targets"):
		camera.set_targets(p1, p2)
	if hud and hud.has_method("bind_fighters"):
		hud.bind_fighters(p1, p2)
	if hud and hud.has_method("set_round_scores"):
		hud.set_round_scores(GameManager.p1_rounds, GameManager.p2_rounds)

	if practice_mode:
		_configure_practice_fighters()
		hud.practice_cooldowns_toggled.connect(_set_practice_cooldowns)
		hud.practice_combat_toggled.connect(_set_practice_combat)
		hud.practice_panel.reset_requested.connect(_reset_practice_positions)
		hud.practice_panel.behavior_changed.connect(_set_practice_behavior)
		hud.practice_panel.fighters_selected.connect(_replace_practice_fighters)
		match_started = true
	else:
		_play_round_intro()

func _spawn_p2_ai(difficulty: String) -> void:
	p2_ai = FighterAI.new()
	p2_ai.name = "P2_AI"
	add_child(p2_ai)
	p2_ai.setup(p2, p1, difficulty)

func _configure_practice_fighters() -> void:
	for fighter in [p1, p2]:
		fighter.practice_full_energy = true
		fighter.ep = 100.0
	_set_practice_cooldowns(_practice_cooldowns)
	_refresh_practice_controller()

func _set_practice_cooldowns(enabled: bool) -> void:
	_practice_cooldowns = enabled
	p1.set_practice_skill_cooldowns(enabled)
	p2.set_practice_skill_cooldowns(enabled)

func _set_practice_combat(enabled: bool) -> void:
	_practice_combat = enabled
	_refresh_practice_controller()

func _set_practice_behavior(behavior: int) -> void:
	_practice_behavior = behavior
	_refresh_practice_controller()

func _remove_p2_ai() -> void:
	if is_instance_valid(p2_ai):
		p2_ai.set_physics_process(false)
		remove_child(p2_ai)
		p2_ai.queue_free()
	p2_ai = null

func _refresh_practice_controller() -> void:
	_remove_p2_ai()
	p2.is_ai_controlled = true
	p2.clear_practice_dummy_input()
	if _practice_combat or _practice_behavior > 0:
		_spawn_p2_ai("easy")
		p2_ai.practice_behavior = 0 if _practice_combat else _practice_behavior

func _clear_practice_projectiles() -> void:
	for node in get_children():
		if node is PaintBlobProjectile or node is PaintPuddleHazard or node is MysticOrbProjectile or node is SwordWaveProjectile:
			remove_child(node)
			node.queue_free()

func _reset_practice_positions(preset: int) -> void:
	if get_tree().paused:
		return
	_practice_position = clampi(preset, 0, PRACTICE_POSITIONS.size() - 1)
	p1_spawn_pos.x = PRACTICE_POSITIONS[_practice_position].x
	p2_spawn_pos.x = PRACTICE_POSITIONS[_practice_position].y
	_clear_practice_projectiles()
	p1.reset_for_new_round(p1_spawn_pos)
	p2.reset_for_new_round(p2_spawn_pos)
	_refresh_practice_controller()

func _replace_practice_fighters(first_id: String, second_id: String) -> void:
	if first_id == p1.fighter_id and second_id == p2.fighter_id:
		return
	_remove_p2_ai()
	_clear_practice_projectiles()
	for fighter in [p1, p2]:
		remove_child(fighter)
		fighter.queue_free()
	GameManager.selected_p1 = first_id
	GameManager.selected_p2 = second_id
	p1 = _spawn_fighter(first_id, 1, p1_spawn_pos)
	p2 = _spawn_fighter(second_id, 2, p2_spawn_pos)
	p1.reset_for_new_round(p1_spawn_pos)
	p2.reset_for_new_round(p2_spawn_pos)
	_configure_practice_fighters()
	camera.set_targets(p1, p2)
	hud.bind_fighters(p1, p2)

func _exit_tree() -> void:
	AudioManager.stop_bgm()

func _get_round_label() -> String:
	if GameManager.p1_rounds == GameManager.rounds_to_win - 1 and GameManager.p2_rounds == GameManager.rounds_to_win - 1:
		return "FINAL ROUND"
	return "ROUND %d" % GameManager.current_round

func _play_round_intro() -> void:
	match_started = false
	round_ending = false
	if p1:
		p1.battle_locked = true
	if p2:
		p2.battle_locked = true
	if hud and hud.has_method("play_round_intro"):
		hud.play_round_intro(func() -> void:
			match_started = true
			if is_instance_valid(p1) and not match_ended:
				p1.battle_locked = false
			if is_instance_valid(p2) and not match_ended:
				p2.battle_locked = false
		, _get_round_label())
	else:
		match_started = true
		if p1:
			p1.battle_locked = false
		if p2:
			p2.battle_locked = false

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
	if practice_mode or match_ended or round_ending or not match_started:
		return
	match_time = maxf(0.0, match_time - delta)
	if hud and hud.has_method("set_timer_value"):
		hud.set_timer_value(int(ceil(match_time)))
	if match_time <= 0.0:
		_finish_by_timeout()

func _on_fighter_ko(loser: BaseFighter, _killer: BaseFighter, by_ultimate: bool) -> void:
	if practice_mode:
		_respawn_practice_fighter.call_deferred(loser)
		return
	if match_ended or round_ending:
		return
	var winner: BaseFighter = p2 if loser == p1 else p1
	_finish_round(winner, "ULTIMATE FINISH!" if by_ultimate else "K.O.!", by_ultimate)

func _respawn_practice_fighter(fighter: BaseFighter) -> void:
	if is_instance_valid(fighter) and fighter.is_inside_tree() and fighter.is_ko:
		var spawn_pos := p1_spawn_pos if fighter == p1 else p2_spawn_pos
		fighter.reset_for_new_round(spawn_pos)

func _finish_by_timeout() -> void:
	if match_ended or round_ending:
		return
	AudioManager.play_sfx("ko", -2.0)
	var p1_ratio: float = float(p1.hp) / maxf(1.0, float(p1.max_hp)) if p1 else 0.0
	var p2_ratio: float = float(p2.hp) / maxf(1.0, float(p2.max_hp)) if p2 else 0.0
	var winner: BaseFighter = null
	if p1_ratio > p2_ratio:
		winner = p1
	elif p2_ratio > p1_ratio:
		winner = p2
	_finish_round(winner, "TIME UP!", false)

func _finish_round(winner: BaseFighter, reason: String, by_ultimate: bool) -> void:
	round_ending = true
	match_started = false
	if p1:
		p1.battle_locked = true
	if p2:
		p2.battle_locked = true

	if winner == p1:
		GameManager.p1_rounds += 1
	elif winner == p2:
		GameManager.p2_rounds += 1
	if hud and hud.has_method("set_round_scores"):
		hud.set_round_scores(GameManager.p1_rounds, GameManager.p2_rounds)

	var series_done: bool = (GameManager.p1_rounds >= GameManager.rounds_to_win) or (GameManager.p2_rounds >= GameManager.rounds_to_win)
	if series_done:
		match_ended = true
		AudioManager.stop_bgm()
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
					hud.show_ko_overlay(winner, reason)
			)
	else:
		# BO3 下一回合准备：保留 30% EP 继承，重置血量、护盾、位置与场上道具
		var banner_text: String = ("%s 拿下本局!" % winner.fighter_name) if winner else "本局平手!"
		if hud and hud.has_method("show_round_banner"):
			hud.show_round_banner(banner_text, winner.theme_color if winner else Color("#38bdf8"))
		var t_next := get_tree().create_timer(1.75)
		t_next.timeout.connect(func() -> void:
			if match_ended or not is_instance_valid(self):
				return
			for item in get_tree().get_nodes_in_group("arena_items"):
				if is_instance_valid(item):
					item.queue_free()
			GameManager.current_round += 1
			match_time = MATCH_DURATION
			if hud and hud.has_method("set_timer_value"):
				hud.set_timer_value(int(MATCH_DURATION))
			if is_instance_valid(p1):
				p1.reset_for_new_round(p1_spawn_pos, 0.3)
			if is_instance_valid(p2):
				p2.reset_for_new_round(p2_spawn_pos, 0.3)
			_play_round_intro()
		)
