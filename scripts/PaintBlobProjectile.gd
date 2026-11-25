extends Node2D
class_name PaintBlobProjectile

const PaintPuddleHazardScene = preload("res://scripts/PaintPuddleHazard.gd")

var owner_fighter: BaseFighter
var velocity: Vector2 = Vector2.ZERO
var gravity_accel: float = 1200.0 # g 约 1100-1300 px/s²
var damage: int = 9 # 轻量伤害 8-10
var charge_level: int = 1
var charge_elapsed: float = 0.0
var dir_param: String = "neutral"

var hit_radius: float = 24.0
var blob_radius: float = 12.0
var max_lifetime: float = 2.5
var _elapsed: float = 0.0

var paint_colors: Array[Color] = [
	Color("#f59e0b"), # 温暖琥珀金
	Color("#ec4899"), # 浪漫品红
	Color("#06b6d4"), # 纯净天青
	Color("#84cc16")  # 活力青柠
]

# 舞台地面高度与各层平台
# 舞台地面上表面高度（580 - 24 = 556.0）与各层平台
const STAGE_GROUND_Y: float = 556.0
# 单向平台左、右、顶（平台顶部表面分别位于 412 - 8 = 404.0 与 282 - 8 = 274.0）
const PLATFORMS: Array[Dictionary] = [
	{"top": 404.0, "half_w": 160.0, "center_x": 561.0},
	{"top": 404.0, "half_w": 160.0, "center_x": 1232.0},
	{"top": 274.0, "half_w": 220.0, "center_x": 900.0}
]

func _ready() -> void:
	z_index = 28
	# 随蓄力时间略增颜料块大小
	blob_radius = 12.0 + float(charge_level - 1) * 3.5
	hit_radius = 22.0 + float(charge_level - 1) * 5.0

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= max_lifetime:
		queue_free()
		return

	# 抛物线运动更新
	var prev_pos := global_position
	velocity.y += gravity_accel * delta
	global_position += velocity * delta

	# 边缘越界检查
	if global_position.x < 150.0 or global_position.x > 1650.0 or global_position.y > 800.0:
		queue_free()
		return

	# 拖尾小微粒
	var vfx := BattleVFX.get_current(get_tree())
	if vfx and randf() < 0.4:
		var col: Color = paint_colors[randi() % paint_colors.size()]
		vfx.spawn_paint_spark_drop(global_position + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0)), col)

	# 1. 检测空中直接命中对手
	for node in get_tree().get_nodes_in_group("fighters"):
		if node == owner_fighter or not (node is BaseFighter):
			continue
		var target := node as BaseFighter
		if target.is_ko:
			continue
		var target_center: Vector2 = target.global_position + Vector2(0.0, -48.0)
		if global_position.distance_to(target_center) <= hit_radius + 20.0:
			_on_hit_target(target)
			return

	# 2. 检测落地（主地面或平台顶部）
	if velocity.y > 0.0:
		# 主地面检测 (Y ~ 580)
		if prev_pos.y <= STAGE_GROUND_Y and global_position.y >= STAGE_GROUND_Y:
			global_position.y = STAGE_GROUND_Y
			_on_land(false)
			return

		# 平台顶部穿透与碰撞
		for p in PLATFORMS:
			var py: float = float(p["top"])
			var h_w: float = float(p["half_w"])
			var px: float = float(p["center_x"])
			if prev_pos.y <= py and global_position.y >= py:
				if absf(global_position.x - px) <= h_w:
					global_position.y = py
					_on_land(false)
					return

	queue_redraw()

func _on_hit_target(target: BaseFighter) -> void:
	# 空中直接命中反馈：颜料块立即炸开，造成轻量伤害，3 帧 Hitstop，10 帧轻硬直，轻微水平击退与受击闪白
	var facing_dir: float = signf(velocity.x) if absf(velocity.x) > 10.0 else (1.0 if owner_fighter == null else float(owner_fighter.facing))
	var kb := Vector2(facing_dir * 180.0, -80.0)
	
	target.take_damage(damage, kb, owner_fighter, false)
	# 强制特调为需求指定的轻硬直 (10 帧 = 0.166s)、受击闪白 (2 帧 = 0.033s) 与 3 帧 Hitstop (0.05s)
	target.hitstun_timer = 0.166
	target.hit_flash_timer = 0.033
	GameManager.trigger_hitstop(0.05)
	GameManager.trigger_shake(3.0, 0.08, Vector2(facing_dir, 0.0))

	# 炸开飞溅粒子
	var vfx := BattleVFX.get_current(get_tree())
	if vfx:
		vfx.spawn_paint_hit_sparks(global_position, false)
	AudioManager.play_sfx("hit_light", -3.0, 1.15)

	# 命中点下方自然滴落形成小型临时颜料滩（持续时间减半）
	_spawn_puddle_at(global_position, true)
	queue_free()

func _on_land(is_temp: bool) -> void:
	# 播放“啪嗒”摊开动画与微弱地面水花特效
	AudioManager.play_sfx("swing_light", -4.0, 1.35)
	var vfx := BattleVFX.get_current(get_tree())
	if vfx:
		vfx.spawn_paint_hit_sparks(global_position, false)
		vfx.spawn_shockwave_ring(global_position, Color("#f59e0b"), 6.0, 36.0, 0.15, 2.5)

	# 铺开彩色颜料区
	_spawn_puddle_at(global_position, is_temp)
	queue_free()

func _spawn_puddle_at(pos: Vector2, temp: bool) -> void:
	# 场上最多同时存在 1-2 滩，新生成时顶掉最早一滩
	var existing = get_tree().get_nodes_in_group("paint_puddles")
	if existing.size() >= 2:
		var oldest: Node = existing[0]
		if is_instance_valid(oldest):
			oldest.queue_free()

	# 投射到底部最近地面或平台顶部基准线
	var land_y: float = STAGE_GROUND_Y
	for p in PLATFORMS:
		var py: float = float(p["top"])
		var h_w: float = float(p["half_w"])
		var px: float = float(p["center_x"])
		if pos.y <= py + 16.0 and absf(pos.x - px) <= h_w:
			land_y = py
			break

	var puddle := PaintPuddleHazardScene.new()
	puddle.owner_fighter = owner_fighter
	puddle.global_position = Vector2(pos.x, land_y)
	puddle.is_temp = temp
	# 随蓄力等级提升颜料滩大小与持续时间
	if not temp:
		puddle.base_radius_x = 48.0 + float(charge_level - 1) * 12.0
		puddle.lifetime = 3.5 + float(charge_level - 1) * 0.8
	get_parent().add_child(puddle)

func _draw() -> void:
	# 绘制饱满流体感的彩色颜料块
	var main_col: Color = paint_colors[0] # 金黄底色
	draw_circle(Vector2.ZERO, blob_radius, main_col)
	# 内部高光与多色混彩
	draw_circle(Vector2(-blob_radius * 0.25, -blob_radius * 0.25), blob_radius * 0.65, paint_colors[1])
	draw_circle(Vector2(blob_radius * 0.3, blob_radius * 0.2), blob_radius * 0.45, paint_colors[2])
	draw_circle(Vector2(-blob_radius * 0.35, -blob_radius * 0.35), blob_radius * 0.3, Color(1.0, 1.0, 1.0, 0.85))
