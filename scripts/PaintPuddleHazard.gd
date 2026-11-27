extends Node2D
class_name PaintPuddleHazard

var owner_fighter: BaseFighter
var lifetime: float = 3.5 # 210 帧 (3.5s)
var is_temp: bool = false # 命中掉落的小型临时颜料滩（持续减半）
var base_radius_x: float = 85.0
var base_radius_y: float = 24.0

var paint_colors: Array[Color] = [
	Color("#f59e0b"), # 温暖琥珀金
	Color("#ec4899"), # 浪漫品红
	Color("#06b6d4"), # 纯净天青
	Color("#84cc16")  # 活力青柠
]

var _elapsed: float = 0.0
# 打滑冷却字典：对每个目标记录冷却时间，防止无脑无限硬直（1.2 秒冷却）
var _slip_cooldowns: Dictionary = {} # target -> float timer

var _sprite: Sprite2D
var _mat: ShaderMaterial

func _ready() -> void:
	z_index = 5 # 处于地面之上、角色阴影与模型之下
	add_to_group("paint_puddles")

	if is_temp:
		lifetime = 1.75
		base_radius_x *= 0.65
		base_radius_y *= 0.65

	# 创建独立原画 Sprite2D 并配置抠图着色器
	_sprite = Sprite2D.new()
	var tex = load("res://assets/fighters/isfp/newframes/skill1_paint_puddle_concept.png")
	_sprite.texture = tex

	var shader = load("res://shaders/puddle_cutout.gdshader")
	if shader:
		_mat = ShaderMaterial.new()
		_mat.shader = shader
		_mat.set_shader_parameter("bg_color", Vector3(0.898, 0.898, 0.898))
		_mat.set_shader_parameter("threshold", 0.06)
		_mat.set_shader_parameter("feather", 0.04)
		_mat.set_shader_parameter("alpha_mult", 1.0)
		_sprite.material = _mat

	# 尺寸调优：原画 1254x1254，有效颜料斑块约 1225x423
	# 缩放至战斗舞台中合适的范围（宽度约 170px，厚度约 58px）
	var target_w: float = base_radius_x * 2.0
	var sc: float = target_w / 1225.0
	_sprite.scale = Vector2(sc, sc)
	# 垂直锚定微调：有效内容中心在 y=676（相较图像中心偏移约 49px），微移使滩面底部刚好贴齐地面基准线
	_sprite.position = Vector2(0.0, -18.0 * (sc / 0.14))
	add_child(_sprite)

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return

	# 边缘渐隐与收缩动画：最后 0.6 秒淡出并提示即将消失
	var remain: float = lifetime - _elapsed
	var alpha: float = 1.0
	if remain < 0.6:
		alpha = clampf(remain / 0.6, 0.0, 1.0)
		if _mat:
			_mat.set_shader_parameter("alpha_mult", alpha)

	# 更新打滑冷却计时
	var to_remove: Array = []
	for k in _slip_cooldowns.keys():
		_slip_cooldowns[k] -= delta
		if _slip_cooldowns[k] <= 0.0:
			to_remove.append(k)
	for k in to_remove:
		_slip_cooldowns.erase(k)

	# 检测对手进入颜料区
	for node in get_tree().get_nodes_in_group("fighters"):
		if node == owner_fighter or not (node is BaseFighter):
			continue
		var target := node as BaseFighter
		if target.is_ko or target.get_action_armor() > BaseFighter.AttackPriority.SKILL:
			continue

		var diff: Vector2 = target.global_position - global_position
		# 触发判定：X 轴在颜料区范围内，Y 轴在地面及上方 54px 范围内
		if absf(diff.x) <= base_radius_x * 1.15 and diff.y >= -54.0 and diff.y <= 16.0:
			_apply_puddle_effect(target, delta)

func contains_feet(world_position: Vector2) -> bool:
	var offset := world_position - global_position
	return _elapsed < lifetime and not is_queued_for_deletion() and absf(offset.x) <= base_radius_x and absf(offset.y) <= base_radius_y

func _apply_puddle_effect(target: BaseFighter, delta: float) -> void:
	# 1. 移动减速状态（降低至 58%），刷新减速持续时间
	target.paint_slow_timer = 0.22
	target.paint_slow_mult = 0.58

	# 2. 彩色脚印与颜料粘附粒子
	if absf(target.velocity.x) > 20.0:
		var vfx := BattleVFX.get_current(get_tree())
		if vfx and randf() < 0.35:
			var rand_col: Color = paint_colors[randi() % paint_colors.size()]
			vfx.spawn_paint_spark_drop(target.global_position + Vector2(randf_range(-10.0, 10.0), 0.0), rand_col)

	# 3. 首次踏入或急停转向打滑微硬直（约 6-8 帧 = 0.10s-0.13s，1.2s 冷却）
	if not _slip_cooldowns.has(target):
		_slip_cooldowns[target] = 1.2
		# 触发打滑微硬直与滑步小惯性
		target.trigger_paint_slip(0.12, signf(target.velocity.x) if absf(target.velocity.x) > 10.0 else float(target.facing))
