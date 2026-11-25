extends Control

@export var p1_spotlight_path: NodePath
@export var p2_spotlight_path: NodePath
@export var bg_rect_path: NodePath

const SPOT_U1: float = 0.278
const SPOT_U2: float = 0.722
const SPOT_V: float = 0.735

var p1_color: Color = Color("#7c3aed")
var p1_target: Color = Color("#7c3aed")
var p2_color: Color = Color("#10b981")
var p2_target: Color = Color("#10b981")

var _time: float = 0.0
var _motes: Array[Dictionary] = []
var _ripples: Array[Dictionary] = []
var _bursts: Array[Dictionary] = []
var _p1_spot: Control
var _p2_spot: Control
var _bg_rect: TextureRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_p1_spot = get_node_or_null(p1_spotlight_path) as Control
	_p2_spot = get_node_or_null(p2_spotlight_path) as Control
	_bg_rect = get_node_or_null(bg_rect_path) as TextureRect
	for i in range(48):
		_motes.append(_spawn_mote(true))

func set_colors(c1: Color, c2: Color) -> void:
	p1_target = c1
	p2_target = c2

func trigger_lock_burst(player_index: int, col: Color) -> void:
	var u: float = SPOT_U1 if player_index == 1 else SPOT_U2
	_ripples.append({"u": u, "v": SPOT_V, "progress": 0.0, "color": col})
	for i in range(16):
		var angle: float = (TAU * float(i)) / 16.0 + randf_range(-0.2, 0.2)
		var spd: float = randf_range(0.08, 0.17)
		_bursts.append({
			"u": u + randf_range(-0.02, 0.02),
			"v": SPOT_V + randf_range(-0.01, 0.01),
			"vu": cos(angle) * spd * 0.65,
			"vv": sin(angle) * spd * 0.45 - 0.1,
			"size": randf_range(4.0, 8.0),
			"life": 0.0,
			"max_life": randf_range(0.5, 0.8),
			"color": col
		})

func _spawn_mote(random_y: bool) -> Dictionary:
	var lane: float = randf()
	var u: float = randf_range(0.08, 0.92)
	var side: int = 0
	if lane < 0.38:
		u = randf_range(0.17, 0.38)
		side = 1
	elif lane < 0.76:
		u = randf_range(0.62, 0.83)
		side = 2
	return {
		"u": u,
		"v": randf() if random_y else randf_range(0.76, 0.88),
		"vy": randf_range(0.028, 0.052),
		"size": randf_range(3.0, 6.0),
		"phase": randf() * TAU,
		"side": side,
		"alpha": randf_range(0.3, 0.75)
	}

func _compute_cover_rect() -> Rect2:
	var view_size: Vector2 = size
	var nat_size: Vector2 = Vector2(1408.0, 768.0)
	if _bg_rect and _bg_rect.texture:
		nat_size = _bg_rect.texture.get_size()
	var scale_f: float = maxf(view_size.x / nat_size.x, view_size.y / nat_size.y)
	var draw_size: Vector2 = nat_size * scale_f
	var offset: Vector2 = (view_size - draw_size) * 0.5
	return Rect2(offset, draw_size)

func _process(delta: float) -> void:
	_time += delta
	var c_step: float = minf(1.0, delta * 6.0)
	p1_color = p1_color.lerp(p1_target, c_step)
	p2_color = p2_color.lerp(p2_target, c_step)

	# 动态按背景图 cover 投影对齐 1P / 2P 人物站位
	var cover: Rect2 = _compute_cover_rect()
	var char_size: float = clampf(cover.size.y * 0.36, 200.0, 390.0)
	var p1_pos := Vector2(cover.position.x + cover.size.x * SPOT_U1, cover.position.y + cover.size.y * SPOT_V)
	var p2_pos := Vector2(cover.position.x + cover.size.x * SPOT_U2, cover.position.y + cover.size.y * SPOT_V)

	if _p1_spot:
		_p1_spot.size = Vector2(char_size, char_size)
		_p1_spot.position = Vector2(p1_pos.x - char_size * 0.5, p1_pos.y - char_size * 0.94)
		_p1_spot.pivot_offset = Vector2(char_size * 0.5, char_size * 0.9)
	if _p2_spot:
		_p2_spot.size = Vector2(char_size, char_size)
		_p2_spot.position = Vector2(p2_pos.x - char_size * 0.5, p2_pos.y - char_size * 0.94)
		_p2_spot.pivot_offset = Vector2(char_size * 0.5, char_size * 0.9)

	for m: Dictionary in _motes:
		m["v"] = float(m["v"]) - float(m["vy"]) * delta
		if float(m["v"]) < 0.05:
			var fresh: Dictionary = _spawn_mote(false)
			for k in fresh.keys():
				m[k] = fresh[k]

	for i in range(_ripples.size() - 1, -1, -1):
		var r: Dictionary = _ripples[i]
		r["progress"] = float(r["progress"]) + delta / 0.65
		if float(r["progress"]) >= 1.0:
			_ripples.remove_at(i)

	for i in range(_bursts.size() - 1, -1, -1):
		var b: Dictionary = _bursts[i]
		b["life"] = float(b["life"]) + delta
		if float(b["life"]) >= float(b["max_life"]):
			_bursts.remove_at(i)
		else:
			b["u"] = float(b["u"]) + float(b["vu"]) * delta
			b["v"] = float(b["v"]) + float(b["vv"]) * delta
			b["vv"] = float(b["vv"]) + 0.2 * delta

	queue_redraw()

func _draw_ellipse_ring(center: Vector2, rx: float, ry: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	var steps: int = 36
	for i in range(steps + 1):
		var a: float = (TAU * float(i)) / float(steps)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, width, true)

func _draw_diamond(pos: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([
		pos + Vector2(0.0, -r),
		pos + Vector2(r * 0.65, 0.0),
		pos + Vector2(0.0, r),
		pos + Vector2(-r * 0.65, 0.0)
	])
	draw_colored_polygon(pts, col)

func _draw() -> void:
	var cover: Rect2 = _compute_cover_rect()

	# 空气上升低多边形光尘
	for m: Dictionary in _motes:
		var v_val: float = float(m["v"])
		var fade_b: float = clampf((0.84 - v_val) / 0.14, 0.0, 1.0)
		var fade_t: float = clampf((v_val - 0.05) / 0.15, 0.0, 1.0)
		var alpha: float = float(m["alpha"]) * fade_b * fade_t
		if alpha <= 0.01:
			continue
		var sway: float = sin(_time * 1.1 + float(m["phase"])) * 0.006
		var pos := Vector2(cover.position.x + cover.size.x * (float(m["u"]) + sway), cover.position.y + cover.size.y * v_val)
		var side: int = int(m["side"])
		var base_c: Color = p1_color if side == 1 else (p2_color if side == 2 else Color("#fef3c7"))
		_draw_diamond(pos, float(m["size"]), Color(base_c.r, base_c.g, base_c.b, alpha))

	# 锁定爆散微晶
	for b: Dictionary in _bursts:
		var t: float = 1.0 - float(b["life"]) / float(b["max_life"])
		var col: Color = b["color"] as Color
		var bp := Vector2(cover.position.x + cover.size.x * float(b["u"]), cover.position.y + cover.size.y * float(b["v"]))
		_draw_diamond(bp, float(b["size"]) * (0.4 + t * 0.6), Color(col.r, col.g, col.b, t * 0.9))
