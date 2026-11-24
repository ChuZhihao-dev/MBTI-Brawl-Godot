extends Node2D
class_name WindGeyser

@export var launch_velocity_y: float = -890.0
@export var half_width: float = 46.0
@export var column_height: float = 210.0

var _time: float = 0.0
var _cooldowns: Dictionary = {}

func _ready() -> void:
	z_index = 8
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat

func _physics_process(delta: float) -> void:
	_time += delta
	for key in _cooldowns.keys():
		_cooldowns[key] = maxf(0.0, float(_cooldowns[key]) - delta)

	for node in get_tree().get_nodes_in_group("fighters"):
		if not (node is BaseFighter):
			continue
		var f := node as BaseFighter
		if f.is_ko or f.battle_locked:
			continue
		var fid: int = f.get_instance_id()
		if float(_cooldowns.get(fid, 0.0)) > 0.0:
			continue
		var dx: float = absf(f.global_position.x - global_position.x)
		var dy: float = global_position.y - f.global_position.y
		if dx <= half_width and dy >= -16.0 and dy <= 95.0:
			_cooldowns[fid] = 0.65
			f.velocity.y = launch_velocity_y
			f.air_jumps_left = 1
			f.trigger_squash(0.78, 1.28)
			AudioManager.play_sfx("wind_boost", -4.0, randf_range(0.95, 1.12))
			var vfx := BattleVFX.get_current(get_tree())
			if vfx:
				vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -24.0), Color("#7dd3fc"), 14.0, 92.0, 0.28, 5.0)
				vfx.spawn_floating_text(f.global_position + Vector2(0.0, -108.0), "上升气流!", Color("#7dd3fc"), 0.88)
	queue_redraw()

func _draw() -> void:
	# 底座风环
	draw_set_transform(Vector2(0.0, 0.0), 0.0, Vector2(1.0, 0.30))
	draw_arc(Vector2.ZERO, half_width * 0.92, 0.0, TAU, 28, Color(0.45, 0.92, 1.0, 0.55), 4.0, true)
	draw_arc(Vector2.ZERO, half_width * 0.62, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.65), 2.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 4 条上升螺旋风带
	for i in range(4):
		var phase: float = fmod(_time * 2.2 + float(i) * 0.25, 1.0)
		var y_base: float = -phase * column_height
		var alpha: float = sin(phase * PI) * 0.55
		var sway: float = sin(_time * 4.5 + float(i) * 1.6) * (half_width * 0.45)
		var x_off: float = (float(i) - 1.5) * 16.0 + sway * 0.45
		var col := Color(0.55, 0.95, 1.0, alpha)
		draw_line(Vector2(x_off, y_base), Vector2(x_off + sway * 0.2, y_base - 48.0), col, 3.5, true)

	# 向上箭头提示
	var arrow_y: float = -34.0 - fmod(_time * 80.0, 68.0)
	var arrow_a: float = sin(clampf((-arrow_y - 34.0) / 68.0, 0.0, 1.0) * PI) * 0.6
	draw_polyline(PackedVector2Array([
		Vector2(-16.0, arrow_y + 10.0),
		Vector2(0.0, arrow_y - 6.0),
		Vector2(16.0, arrow_y + 10.0)
	]), Color(0.9, 0.98, 1.0, arrow_a), 3.0, true)
