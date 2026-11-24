extends Camera2D

@export var p1_path: NodePath
@export var p2_path: NodePath
@export var stage_width: float = 1800.0
@export var stage_height: float = 770.0
@export var min_zoom: float = 1.05
@export var max_zoom: float = 1.45
@export var smooth_speed: float = 7.0

var _p1: Node2D
var _p2: Node2D
var _shake_timer: float = 0.0
var _shake_duration: float = 0.15
var _shake_intensity: float = 0.0
var _shake_dir: Vector2 = Vector2.ZERO

func _ready() -> void:
	_p1 = get_node_or_null(p1_path)
	_p2 = get_node_or_null(p2_path)
	limit_left = 0
	limit_top = 0
	limit_right = int(stage_width)
	limit_bottom = int(stage_height)
	GameManager.camera_shake_requested.connect(_on_shake_requested)

func set_targets(p1: Node2D, p2: Node2D) -> void:
	_p1 = p1
	_p2 = p2

func _on_shake_requested(intensity: float, duration: float, dir: Vector2) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_timer = maxf(_shake_timer, duration)
	_shake_duration = maxf(_shake_duration, duration)
	if dir != Vector2.ZERO:
		_shake_dir = dir.normalized()

func _process(delta: float) -> void:
	if is_instance_valid(_p1) and is_instance_valid(_p2):
		var mid: Vector2 = (_p1.global_position + _p2.global_position) * 0.5 + Vector2(0.0, -48.0)
		var dist: float = _p1.global_position.distance_to(_p2.global_position)
		var t: float = clampf(dist / 950.0, 0.0, 1.0)
		var target_zoom_val: float = lerpf(max_zoom, min_zoom, t)
		var weight: float = 1.0 - exp(-smooth_speed * delta)
		global_position = global_position.lerp(mid, weight)
		zoom = zoom.lerp(Vector2(target_zoom_val, target_zoom_val), weight)

	if _shake_timer > 0.0:
		_shake_timer = maxf(0.0, _shake_timer - delta)
		var progress: float = _shake_timer / maxf(0.01, _shake_duration)
		var mag: float = _shake_intensity * progress
		var wave: float = sin(progress * PI * 5.0)
		if _shake_dir != Vector2.ZERO:
			offset = _shake_dir * mag * wave + Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4)) * mag
		else:
			offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * mag
		if _shake_timer <= 0.0:
			offset = Vector2.ZERO
			_shake_intensity = 0.0
			_shake_dir = Vector2.ZERO
