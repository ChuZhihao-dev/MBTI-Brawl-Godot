extends Node2D
class_name DoorSlamEffect

var owner_fighter: BaseFighter
var damage: int = 32
var knockback_dir: float = 1.0
var impact_pos: Vector2 = Vector2.ZERO

var _elapsed: float = 0.0
var _slammed: bool = false
var _door_y: float = -340.0
var _door_open: float = 1.0
var _alpha: float = 1.0

func _ready() -> void:
	z_index = 36
	global_position = impact_pos

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.24:
		# 第一阶段：巨型翡翠符文石门在空中显现并缓缓张开
		var t: float = _elapsed / 0.24
		_door_y = lerpf(-340.0, -180.0, t)
		_door_open = 1.0
	elif _elapsed < 0.36:
		# 第二阶段：轰然坠落并狠狠合门（Door Slam!）
		var t2: float = (_elapsed - 0.24) / 0.12
		var ease_t: float = t2 * t2 * t2
		_door_y = lerpf(-180.0, 0.0, ease_t)
		_door_open = lerpf(1.0, 0.0, ease_t)
	else:
		_door_y = 0.0
		_door_open = 0.0
		if not _slammed:
			_slammed = true
			_trigger_slam_impact()
		if _elapsed > 0.82:
			_alpha = maxf(0.0, 1.0 - (_elapsed - 0.82) / 0.32)
		if _elapsed >= 1.15:
			queue_free()
			return
	queue_redraw()

func _trigger_slam_impact() -> void:
	AudioManager.play_sfx("hit_heavy", 0.0, 0.72)
	AudioManager.play_sfx("ko", -4.0, 1.15)
	GameManager.trigger_shake(16.0, 0.32, Vector2(0.0, 1.0))
	var vfx := BattleVFX.get_current(get_tree())
	if vfx:
		vfx.trigger_screen_flash(Color("#a7f3d0"), 0.32, 0.22)
		vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -30.0), Color("#34d399"), 20.0, 230.0, 0.38, 8.0)
		vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -30.0), Color("#fde047"), 14.0, 170.0, 0.30, 6.0)
		vfx.spawn_hit_particles(global_position + Vector2(0.0, -40.0), Color("#6ee7b7"), 30, 520.0)

	for node in get_tree().get_nodes_in_group("fighters"):
		if node == owner_fighter or not (node is BaseFighter):
			continue
		var target := node as BaseFighter
		if target.is_ko:
			continue
		if absf(target.global_position.x - global_position.x) <= 155.0 and absf(target.global_position.y - global_position.y) <= 170.0:
			# 清空对手增益 Buff（如 ENFJ 的气焰共鸣）
			if target.get("aura_buff_timer") != null and float(target.get("aura_buff_timer")) > 0.0:
				target.set("aura_buff_timer", 0.0)
				if vfx:
					vfx.spawn_floating_text(target.global_position + Vector2(0.0, -148.0), "增益清空!", Color("#38bdf8"), 1.05)
			var push_x: float = knockback_dir if knockback_dir != 0.0 else 1.0
			target.take_damage(damage, Vector2(push_x * 580.0, -350.0), owner_fighter, true)
			if vfx:
				vfx.spawn_floating_text(target.global_position + Vector2(0.0, -118.0), "关门大吉!!", Color("#fde047"), 1.32)

func _draw() -> void:
	# 地面召唤预警符文阵
	var rune_alpha: float = _alpha * 0.85
	draw_set_transform(Vector2(0.0, 0.0), 0.0, Vector2(1.0, 0.3))
	draw_arc(Vector2.ZERO, 128.0, 0.0, TAU, 36, Color(0.25, 0.95, 0.65, rune_alpha), 5.0, true)
	draw_arc(Vector2.ZERO, 96.0, 0.0, TAU, 32, Color(0.99, 0.9, 0.35, rune_alpha * 0.85), 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 巨型翡翠双开符文石门
	var top_y: float = _door_y - 230.0
	var bot_y: float = _door_y
	var half_w: float = 96.0
	var gap: float = _door_open * 28.0

	var frame_col := Color(0.06, 0.24, 0.20, _alpha)
	var leaf_l_col := Color(0.09, 0.42, 0.33, _alpha)
	var leaf_r_col := Color(0.07, 0.35, 0.28, _alpha)
	var gold_trim := Color(0.95, 0.86, 0.38, _alpha)
	var rune_glow := Color(0.45, 1.0, 0.78, _alpha)

	# 外石门框
	draw_rect(Rect2(-half_w - 14.0, top_y - 16.0, (half_w + 14.0) * 2.0, 246.0), frame_col, true)
	draw_rect(Rect2(-half_w - 14.0, top_y - 16.0, (half_w + 14.0) * 2.0, 246.0), gold_trim, false, 4.0)

	# 左门扇
	var l_rect := Rect2(-half_w - gap, top_y, half_w - 2.0, 226.0)
	draw_rect(l_rect, leaf_l_col, true)
	draw_rect(l_rect, gold_trim, false, 3.0)
	draw_circle(Vector2(-18.0 - gap, (top_y + bot_y) * 0.5), 9.0, gold_trim)

	# 右门扇
	var r_rect := Rect2(2.0 + gap, top_y, half_w - 2.0, 226.0)
	draw_rect(r_rect, leaf_r_col, true)
	draw_rect(r_rect, gold_trim, false, 3.0)
	draw_circle(Vector2(18.0 + gap, (top_y + bot_y) * 0.5), 9.0, gold_trim)

	# 门面居中翡翠封印符文
	var mid_y: float = (top_y + bot_y) * 0.5 - 32.0
	draw_arc(Vector2(-half_w * 0.5 - gap, mid_y), 24.0, 0.0, TAU, 16, rune_glow, 3.0, true)
	draw_arc(Vector2(half_w * 0.5 + gap, mid_y), 24.0, 0.0, TAU, 16, rune_glow, 3.0, true)
