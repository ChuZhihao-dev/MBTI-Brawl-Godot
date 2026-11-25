extends Node
class_name FighterAI

var fighter: BaseFighter
var opponent: BaseFighter
var difficulty: String = "normal"

var _think_timer: float = 0.0
var _desired_horiz: float = 0.0
var _guard_timer: float = 0.0
var _charge_slot: String = ""
var _charge_hold_left: float = 0.0

func setup(controlled: BaseFighter, target: BaseFighter, diff: String = "normal") -> void:
	fighter = controlled
	opponent = target
	difficulty = diff
	fighter.is_ai_controlled = true

func _physics_process(delta: float) -> void:
	if not is_instance_valid(fighter) or not is_instance_valid(opponent):
		return
	if fighter.is_ko or fighter.battle_locked:
		fighter.ai_input = {}
		return

	var inp := {
		"horiz": _desired_horiz,
		"up_held": false,
		"up_just": false,
		"guard_held": false,
		"light_just": false,
		"heavy_just": false,
		"dash_just": false,
		"skill1_held": false,
		"skill1_just": false,
		"skill2_held": false,
		"skill2_just": false,
		"ult_just": false
	}

	# 正在蓄力技能时持续按住直到预定蓄力时长结束
	if _charge_slot != "":
		_charge_hold_left -= delta
		if _charge_hold_left > 0.0:
			inp[_charge_slot + "_held"] = true
			inp["horiz"] = signf(opponent.global_position.x - fighter.global_position.x)
			if opponent.global_position.y < fighter.global_position.y - 90.0:
				inp["up_held"] = true
		else:
			_charge_slot = ""
		fighter.ai_input = inp
		return

	if _guard_timer > 0.0:
		_guard_timer -= delta
		inp["guard_held"] = true
		inp["horiz"] = 0.0
		fighter.ai_input = inp
		return

	var is_hard: bool = difficulty == "hard"

	# 0. 受击空中落地受身（困难 AI 会在快落地时主动按闪避受身）
	if fighter.hitstun_timer > 0.0 and not fighter.is_on_floor() and fighter.velocity.y > 160.0:
		if is_hard and randf() < 0.38:
			inp["dash_just"] = true
			inp["horiz"] = -signf(opponent.global_position.x - fighter.global_position.x)
			fighter.ai_input = inp
			return

	_think_timer -= delta
	if _think_timer > 0.0:
		fighter.ai_input = inp
		return

	_think_timer = randf_range(0.08, 0.16) if is_hard else randf_range(0.16, 0.28)

	# 1. 优先检查场上道具（抢水晶/回血果，躲定时炸弹）
	var items := get_tree().get_nodes_in_group("arena_items")
	var target_pos: Vector2 = opponent.global_position
	var chasing_item: bool = false
	for node in items:
		if node is ArenaItem:
			var it := node as ArenaItem
			if it.kind == ArenaItem.Kind.TIME_BOMB:
				if fighter.global_position.distance_to(it.global_position) < 170.0:
					_desired_horiz = -signf(it.global_position.x - fighter.global_position.x)
					if _desired_horiz == 0.0:
						_desired_horiz = 1.0
					inp["horiz"] = _desired_horiz
					if fighter.dash_cd <= 0.0 and randf() < 0.6:
						inp["dash_just"] = true
					fighter.ai_input = inp
					return
			else:
				var need_heal: bool = it.kind == ArenaItem.Kind.HEAL_FRUIT and fighter.hp < int(fighter.max_hp * 0.78)
				var want_ep: bool = it.kind == ArenaItem.Kind.ENERGY_CRYSTAL and fighter.ep < 85.0
				if (need_heal or want_ep) and fighter.global_position.distance_to(it.global_position) < 480.0:
					target_pos = it.global_position
					chasing_item = true
					break

	var dx: float = target_pos.x - fighter.global_position.x
	var dy: float = target_pos.y - fighter.global_position.y
	var dist_x: float = absf(dx)
	var dir_to_target: float = signf(dx) if absf(dx) > 12.0 else float(fighter.facing)

	# 2. 满能大招判断
	if fighter.ep >= 100.0 and not opponent.is_ko and (dist_x < 460.0 or fighter.fighter_id == "infj"):
		if randf() < (0.65 if is_hard else 0.42):
			inp["horiz"] = dir_to_target
			inp["ult_just"] = true
			fighter.ai_input = inp
			return

	# 3. 防御 / 完美格挡反应（对手近距离出招时，低护盾则改为后撤闪避避免破防）
	var opp_attacking: bool = opponent.action_anim_timer > 0.08 and absf(opponent.global_position.x - fighter.global_position.x) < 160.0
	if opp_attacking and fighter.is_on_floor():
		if fighter.shield_hp < 28.0 and fighter.dash_cd <= 0.0:
			inp["horiz"] = -dir_to_target
			inp["dash_just"] = true
			fighter.ai_input = inp
			return
		if fighter.shield_hp >= 28.0 and randf() < (0.48 if is_hard else 0.24):
			_guard_timer = randf_range(0.16, 0.34)
			inp["guard_held"] = true
			inp["horiz"] = 0.0
			fighter.ai_input = inp
			return

	# 3.5 空中快速下落与空中下砸（正上方压制对手）
	if not fighter.is_on_floor() and fighter.velocity.y > 50.0 and not chasing_item:
		var air_dx: float = absf(opponent.global_position.x - fighter.global_position.x)
		var air_dy: float = opponent.global_position.y - fighter.global_position.y
		if air_dx < 115.0 and air_dy > 70.0 and fighter.basic_cd <= 0.0 and randf() < (0.42 if is_hard else 0.22):
			inp["guard_held"] = true
			inp["heavy_just"] = true
			fighter.ai_input = inp
			return
		elif air_dy > 110.0 and randf() < 0.5:
			inp["guard_held"] = true

	# 4. 平台跳跃与追击移动
	var is_ranged: bool = fighter.fighter_id == "infj"
	var ideal_dist: float = 240.0 if (is_ranged and not chasing_item) else 78.0
	if dist_x > ideal_dist + 28.0:
		_desired_horiz = dir_to_target
	elif is_ranged and not chasing_item and dist_x < 120.0:
		_desired_horiz = -dir_to_target
	else:
		_desired_horiz = 0.0 if randf() < 0.4 else dir_to_target
	inp["horiz"] = _desired_horiz

	if dy < -75.0 and randf() < 0.62:
		inp["up_just"] = true
		inp["up_held"] = true
	elif dy > 95.0 and fighter.is_on_floor() and fighter.global_position.y < 510.0 and randf() < 0.45:
		inp["guard_held"] = true
		inp["up_just"] = true

	if chasing_item:
		fighter.ai_input = inp
		return

	# 5. 进攻决策（普攻 / 重击 / 蓄力技能 / 冲刺）
	var opp_dx: float = absf(opponent.global_position.x - fighter.global_position.x)
	var opp_dy: float = absf(opponent.global_position.y - fighter.global_position.y)

	if opp_dx < 115.0 and opp_dy < 85.0:
		var r: float = randf()
		if r < 0.46:
			inp["light_just"] = true
		elif r < 0.72:
			inp["heavy_just"] = true
		elif r < 0.85 and fighter.skill2_cd <= 0.0:
			_charge_slot = "skill2"
			_charge_hold_left = randf_range(0.22, 0.65)
			inp["skill2_just"] = true
			inp["skill2_held"] = true
		elif fighter.dash_cd <= 0.0:
			inp["dash_just"] = true
	elif opp_dx < 460.0 and opp_dy < 120.0:
		var r2: float = randf()
		if fighter.skill1_cd <= 0.0 and r2 < (0.34 if is_hard else 0.22):
			_charge_slot = "skill1"
			_charge_hold_left = randf_range(0.15, 0.96) if is_hard else randf_range(0.1, 0.55)
			inp["skill1_just"] = true
			inp["skill1_held"] = true
		elif is_ranged and r2 < 0.68:
			inp["light_just"] = true
		elif fighter.skill2_cd <= 0.0 and fighter.hp < int(fighter.max_hp * 0.75) and r2 < 0.82:
			_charge_slot = "skill2"
			_charge_hold_left = randf_range(0.35, 0.98)
			inp["skill2_just"] = true
			inp["skill2_held"] = true
		elif fighter.dash_cd <= 0.0 and opp_dx > 220.0 and r2 < 0.90:
			inp["dash_just"] = true

	fighter.ai_input = inp
