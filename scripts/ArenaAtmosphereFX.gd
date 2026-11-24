extends Node2D
class_name ArenaAtmosphereFX

var _time: float = 0.0
var _motes: Array[Dictionary] = []

func _ready() -> void:
	z_index = 4
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	for i in range(42):
		_motes.append({
			"x": randf_range(120.0, 1680.0),
			"y": randf_range(60.0, 680.0),
			"vy": randf_range(-12.0, -28.0),
			"vx": randf_range(-8.0, 10.0),
			"r": randf_range(2.0, 5.0),
			"phase": randf() * TAU,
			"alpha": randf_range(0.18, 0.48)
		})

func _process(delta: float) -> void:
	_time += delta
	for m: Dictionary in _motes:
		m["x"] = float(m["x"]) + float(m["vx"]) * delta
		m["y"] = float(m["y"]) + float(m["vy"]) * delta
		if float(m["y"]) < 30.0:
			m["y"] = 690.0
			m["x"] = randf_range(140.0, 1660.0)
	queue_redraw()

func _draw() -> void:
	# 柔和斜射天空阳光丁达尔光束
	var ray_a: float = 0.055 + 0.02 * sin(_time * 0.9)
	for i in range(3):
		var bx: float = 420.0 + float(i) * 430.0 + sin(_time * 0.4 + float(i)) * 28.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx, 0.0),
			Vector2(bx + 150.0, 0.0),
			Vector2(bx - 90.0, 770.0),
			Vector2(bx - 240.0, 770.0)
		]), Color(1.0, 0.96, 0.80, ray_a))

	# 空气上升暖金光尘
	for m: Dictionary in _motes:
		var pulse: float = 0.65 + 0.35 * sin(_time * 2.2 + float(m["phase"]))
		var pos := Vector2(float(m["x"]), float(m["y"]))
		var r: float = float(m["r"])
		var a: float = float(m["alpha"]) * pulse
		draw_circle(pos, r, Color(1.0, 0.95, 0.72, a))
