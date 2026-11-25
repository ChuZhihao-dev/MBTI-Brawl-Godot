extends Control

const BRUSH_SHEET = preload("res://assets/fighters/isfp/newframes/ultimate_paint_slash_cracks_sheet_v2.png")
const SPLASH = preload("res://assets/fighters/isfp/newframes/ultimate_paint_splash_concept.png")
const COLORS: Array[Color] = [Color("#ff2392"), Color("#ffcc14"), Color("#00d4ff"), Color("#64e52a"), Color("#a341eb"), Color("#ff7218")]

var frame := 0
var shatter_age := 0.0
var burst_origin := Vector2(0.54, 0.46)
var bursting := false
var shatter_duration := 0.4
var paint: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index in range(36):
		var angle := TAU * (index + randf_range(-0.3, 0.3)) / 36.0
		var direction := Vector2.from_angle(angle)
		paint.append({
			"direction": direction,
			"color": COLORS[index % COLORS.size()],
			"distance": randf_range(1.1, 2.0),
			"spin": randf_range(-5.0, 5.0),
			"width": randf_range(0.012, 0.045),
			"stretch": randf_range(0.85, 1.50)
		})

func begin_frame(next_frame: int) -> void:
	frame = next_frame
	queue_redraw()

func burst(screen_fraction: Vector2) -> void:
	burst_origin = screen_fraction.clamp(Vector2(0.1, 0.1), Vector2(0.9, 0.9))
	bursting = true
	queue_redraw()

func _physics_process(delta: float) -> void:
	if bursting and not GameManager.is_pause_menu_open:
		shatter_age += delta
		queue_redraw()

func _draw() -> void:
	if frame >= 1 and frame <= 5:
		var opacity := [0.14, 0.28, 0.24, 0.18, 0.08]
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.06, 0.12, opacity[frame - 1]))
	if frame >= 9 and not bursting:
		var cell := 0 if frame < 11 else (1 if frame < 13 else 2)
		var cell_size := Vector2(BRUSH_SHEET.get_width() / 3.0, BRUSH_SHEET.get_height())
		draw_texture_rect_region(BRUSH_SHEET, Rect2(Vector2.ZERO, size), Rect2(Vector2(cell * cell_size.x, 0.0), cell_size))
	if not bursting:
		return
	var progress := clampf(shatter_age / shatter_duration, 0.0, 1.0)
	var opacity := 1.0 - smoothstep(0.48, 1.0, progress)
	_draw_shatter(opacity)
	# The standalone splash fills the screen on impact, then individual blobs carry the motion.
	draw_texture_rect(SPLASH, Rect2(Vector2.ZERO, size), false, Color(1.0, 1.0, 1.0, opacity * 0.22 * (1.0 - progress)))
	for blob in paint:
		var direction: Vector2 = blob.direction
		var color: Color = blob.color
		color.a = opacity
		var spread := 0.035 + progress * float(blob.distance) * 0.65
		var position := size * burst_origin + direction * size * spread
		var radius := minf(size.x, size.y) * float(blob.width)
		var rotation := direction.angle() + float(blob.spin) * shatter_age
		draw_set_transform(position, rotation, Vector2(float(blob.stretch), 1.0) * radius)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-1.42, -0.03), Vector2(-0.67, -0.56), Vector2(0.04, -0.72),
			Vector2(0.72, -0.57), Vector2(1.06, -0.03), Vector2(0.74, 0.54),
			Vector2(0.11, 0.72), Vector2(-0.51, 0.49)
		]), color)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-1.42, -0.03), Vector2(-0.24, 0.14), Vector2(1.06, -0.03),
			Vector2(0.74, 0.54), Vector2(0.11, 0.72), Vector2(-0.51, 0.49)
		]), color.darkened(0.26))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-0.55, -0.27), Vector2(0.04, -0.58), Vector2(0.66, -0.39), Vector2(0.12, -0.2)
		]), color.lightened(0.43))
	draw_set_transform(Vector2.ZERO)

func _draw_shatter(opacity: float) -> void:
	var core := size * burst_origin
	for index in range(8):
		var direction := Vector2.from_angle(0.21 + TAU * index / 8.0)
		var turn := direction.orthogonal()
		var joint := core + (direction * 0.19 + turn * 0.045) * size
		var points := PackedVector2Array([
			core, joint, core + (direction * 0.37 - turn * 0.035) * size,
			core + direction * size * 0.76
		])
		draw_polyline(points, Color(0.10, 0.14, 0.24, 0.60 * opacity), 4.0, true)
		draw_polyline(points, Color(0.80, 0.96, 1.0, 0.84 * opacity), 1.5, true)
		draw_line(joint, joint + (direction * 0.18 + turn * 0.15) * size,
			Color(0.80, 0.96, 1.0, 0.67 * opacity), 1.5, true)
