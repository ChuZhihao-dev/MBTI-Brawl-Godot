extends Node2D
class_name BattleVFX

var _overlay_layer: CanvasLayer
var _flash_rect: ColorRect
var _spark_tex: ImageTexture
var _dot_tex: ImageTexture
var _shockwave_shader: Shader
var _slash_shader: Shader
var _add_mat: CanvasItemMaterial

func _ready() -> void:
	z_index = 45
	add_to_group("battle_vfx")
	_shockwave_shader = load("res://shaders/vfx_shockwave.gdshader") as Shader
	_slash_shader = load("res://shaders/vfx_slash.gdshader") as Shader
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_spark_tex = _build_spark_texture()
	_dot_tex = _build_soft_dot_texture()

	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 20
	_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay_layer)

	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(1.0, 0.98, 0.88, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(_flash_rect)

static func get_current(tree: SceneTree) -> BattleVFX:
	if tree == null:
		return null
	var nodes := tree.get_nodes_in_group("battle_vfx")
	if not nodes.is_empty():
		return nodes[0] as BattleVFX
	return null

func _build_spark_texture() -> ImageTexture:
	# 程序化拉长柔光火花贴图（告别实心方块粒子）
	var w: int = 16
	var h: int = 48
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		var ny: float = (float(y) / float(h - 1)) * 2.0 - 1.0
		for x in range(w):
			var nx: float = (float(x) / float(w - 1)) * 2.0 - 1.0
			var d: float = sqrt(nx * nx * 1.15 + ny * ny)
			var a: float = clampf(pow(maxf(0.0, 1.0 - d), 1.85), 0.0, 1.0)
			var core: float = clampf(pow(maxf(0.0, 1.0 - d * 1.7), 2.2), 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * 0.85 + core * 0.15))
	return ImageTexture.create_from_image(img)

func _build_soft_dot_texture() -> ImageTexture:
	var s: int = 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in range(s):
		var ny: float = (float(y) / float(s - 1)) * 2.0 - 1.0
		for x in range(s):
			var nx: float = (float(x) / float(s - 1)) * 2.0 - 1.0
			var d: float = sqrt(nx * nx + ny * ny)
			var a: float = clampf(pow(maxf(0.0, 1.0 - d), 2.1), 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)

func trigger_screen_flash(color: Color, peak_alpha: float = 0.24, duration: float = 0.16) -> void:
	if _flash_rect == null:
		return
	_flash_rect.color = Color(color.r, color.g, color.b, peak_alpha)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_flash_rect, "color:a", 0.0, duration).set_ease(Tween.EASE_OUT)

func spawn_hit_fx(pos: Vector2, color: Color, is_heavy: bool = false, is_block: bool = false) -> void:
	var fx_color: Color = Color("#38bdf8") if is_block else (Color("#fde047") if is_heavy else color.lightened(0.28))
	spawn_cross_star(pos, fx_color, 84.0 if is_heavy else 54.0, 0.22 if is_heavy else 0.15, is_heavy)
	spawn_shockwave_ring(pos, fx_color, 10.0, 128.0 if is_heavy else 78.0, 0.26 if is_heavy else 0.18, 6.0 if is_heavy else 4.0)
	spawn_hit_particles(pos, fx_color, 26 if is_heavy else 15, 480.0 if is_heavy else 310.0)
	if is_heavy and not is_block:
		trigger_screen_flash(fx_color.lightened(0.45), 0.22, 0.15)

func spawn_slash_arc(pos: Vector2, start_deg: float, end_deg: float, radius: float, color: Color, duration: float = 0.18, face_dir: int = 1) -> void:
	if _slash_shader == null:
		return
	var rect := ColorRect.new()
	var sz: float = radius * 2.5
	rect.size = Vector2(sz, sz)
	rect.position = pos - Vector2(sz * 0.5, sz * 0.5)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = _slash_shader
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("start_angle", deg_to_rad(start_deg))
	mat.set_shader_parameter("end_angle", deg_to_rad(end_deg))
	mat.set_shader_parameter("facing", 1.0 if face_dir >= 0 else -1.0)
	mat.set_shader_parameter("tint_color", color)
	mat.set_shader_parameter("hdr_boost", 2.35)
	rect.material = mat
	add_child(rect)

	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		if is_instance_valid(mat):
			mat.set_shader_parameter("progress", v)
	, 0.0, 1.0, duration)
	tw.tween_callback(rect.queue_free)

func spawn_cross_star(pos: Vector2, color: Color, radius: float = 56.0, duration: float = 0.18, is_heavy: bool = false) -> void:
	var star := _CrossStarNode.new()
	star.position = pos
	star.color = color
	star.max_radius = radius
	star.duration = duration
	star.is_heavy = is_heavy
	star.material = _add_mat
	add_child(star)

func spawn_shockwave_ring(pos: Vector2, color: Color, _start_r: float = 12.0, end_r: float = 96.0, duration: float = 0.26, _width: float = 5.0) -> void:
	if _shockwave_shader == null:
		return
	var rect := ColorRect.new()
	var sz: float = end_r * 2.25
	rect.size = Vector2(sz, sz)
	rect.position = pos - Vector2(sz * 0.5, sz * 0.5)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = _shockwave_shader
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("tint_color", color)
	mat.set_shader_parameter("hdr_boost", 2.15)
	mat.set_shader_parameter("ring_thickness", 0.16)
	rect.material = mat
	add_child(rect)

	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		if is_instance_valid(mat):
			mat.set_shader_parameter("progress", v)
	, 0.0, 1.0, duration)
	tw.tween_callback(rect.queue_free)

func spawn_hit_particles(pos: Vector2, color: Color, amount: int = 18, speed: float = 340.0) -> void:
	var p := GPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.96
	p.amount = amount
	p.lifetime = 0.36
	p.emitting = true
	p.material = _add_mat
	p.texture = _spark_tex

	var mat := ParticleProcessMaterial.new()
	mat.particle_flag_align_y = true
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.direction = Vector3(0.0, -0.3, 0.0)
	mat.spread = 180.0
	mat.initial_velocity_min = speed * 0.42
	mat.initial_velocity_max = speed
	mat.gravity = Vector3(0.0, 520.0, 0.0)
	mat.damping_min = 180.0
	mat.damping_max = 320.0
	mat.scale_min = 0.45
	mat.scale_max = 1.05

	var hdr_col := Color(color.r * 1.9, color.g * 1.9, color.b * 1.9, 1.0)
	var grad := Gradient.new()
	grad.add_point(0.0, Color(2.4, 2.4, 2.2, 1.0))
	grad.add_point(0.28, hdr_col)
	grad.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	p.process_material = mat
	add_child(p)

	var timer := get_tree().create_timer(0.55)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)

func spawn_ember_burst(pos: Vector2, color: Color, amount: int = 8) -> void:
	var p := GPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = amount
	p.lifetime = 0.28
	p.emitting = true
	p.material = _add_mat
	p.texture = _dot_tex

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 18.0
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 110.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 130.0
	mat.gravity = Vector3(0.0, -60.0, 0.0)
	mat.scale_min = 0.3
	mat.scale_max = 0.7
	var grad := Gradient.new()
	grad.add_point(0.0, Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 0.95))
	grad.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	p.process_material = mat
	add_child(p)

	var timer := get_tree().create_timer(0.45)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)

func spawn_ghost(source_sprite: Sprite2D, tint: Color, duration: float = 0.24) -> void:
	if source_sprite == null or source_sprite.texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = source_sprite.texture
	ghost.hframes = source_sprite.hframes
	ghost.vframes = source_sprite.vframes
	ghost.frame = source_sprite.frame
	ghost.flip_h = source_sprite.flip_h
	ghost.global_position = source_sprite.global_position
	ghost.scale = source_sprite.global_scale
	ghost.z_index = -1
	ghost.material = _add_mat
	ghost.modulate = Color(tint.r * 1.4, tint.g * 1.4, tint.b * 1.4, 0.55)
	add_child(ghost)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ghost, "modulate:a", 0.0, duration).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "scale", ghost.scale * 1.05, duration)
	tw.chain().tween_callback(ghost.queue_free)

func spawn_floating_text(pos: Vector2, text: String, color: Color = Color("#ffffff"), scale_mult: float = 1.0) -> void:
	var holder := Node2D.new()
	holder.position = pos + Vector2(randf_range(-16.0, 16.0), randf_range(-10.0, 4.0))
	holder.rotation = randf_range(-0.07, 0.07)
	holder.z_index = 65

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", int(round(26.0 * scale_mult)))
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color("#0f172a"))
	lbl.add_theme_constant_override("outline_size", 7)
	lbl.position = Vector2(-140.0, -22.0)
	lbl.custom_minimum_size = Vector2(280.0, 44.0)
	holder.add_child(lbl)
	add_child(holder)

	holder.scale = Vector2(0.45, 0.45)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(holder, "scale", Vector2(1.16, 1.16), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "position:y", holder.position.y - 62.0, 0.72).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(holder, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(holder.queue_free)

func play_ult_cutin(fighter_name: String, skill_title: String, portrait: Texture2D, theme_color: Color, facing: int = 1) -> void:
	if _overlay_layer == null:
		return
	trigger_screen_flash(Color("#fef08a"), 0.35, 0.25)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.06, 0.12, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var band := ColorRect.new()
	band.color = theme_color.darkened(0.25)
	band.color.a = 0.94
	band.position = Vector2(0.0, 380.0)
	band.size = Vector2(1920.0, 260.0)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(band)

	var top_stripe := ColorRect.new()
	top_stripe.color = Color("#fde047")
	top_stripe.position = Vector2(0.0, 372.0)
	top_stripe.size = Vector2(1920.0, 10.0)
	root.add_child(top_stripe)

	var bot_stripe := ColorRect.new()
	bot_stripe.color = Color("#fde047")
	bot_stripe.position = Vector2(0.0, 638.0)
	bot_stripe.size = Vector2(1920.0, 10.0)
	root.add_child(bot_stripe)

	var pic := TextureRect.new()
	pic.texture = portrait
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size = Vector2(360.0, 360.0)
	pic.flip_h = facing < 0
	var start_x: float = -380.0 if facing >= 0 else 1960.0
	var target_x: float = 210.0 if facing >= 0 else 1350.0
	pic.position = Vector2(start_x, 310.0)
	root.add_child(pic)

	var title_box := VBoxContainer.new()
	title_box.position = Vector2(620.0 if facing >= 0 else 360.0, 422.0)
	title_box.size = Vector2(920.0, 180.0)
	root.add_child(title_box)

	var sub_lbl := Label.new()
	sub_lbl.text = "%s · ULTIMATE BURST" % fighter_name
	sub_lbl.add_theme_font_size_override("font_size", 30)
	sub_lbl.add_theme_color_override("font_color", Color("#fef08a"))
	sub_lbl.add_theme_color_override("font_outline_color", Color("#0f172a"))
	sub_lbl.add_theme_constant_override("outline_size", 6)
	title_box.add_child(sub_lbl)

	var main_lbl := Label.new()
	main_lbl.text = skill_title
	main_lbl.add_theme_font_size_override("font_size", 74)
	main_lbl.add_theme_color_override("font_color", Color("#ffffff"))
	main_lbl.add_theme_color_override("font_outline_color", Color("#0f172a"))
	main_lbl.add_theme_constant_override("outline_size", 10)
	title_box.add_child(main_lbl)

	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(dim, "color:a", 0.6, 0.12)
	tw.tween_property(pic, "position:x", target_x, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.42)
	tw.chain().tween_property(root, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(root.queue_free)

func play_empathy_finisher(winner_name: String, on_complete: Callable) -> void:
	if _overlay_layer == null:
		if on_complete.is_valid():
			on_complete.call()
		return
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_layer.add_child(root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.11, 0.16, 0.0)
	root.add_child(bg)

	var banner := Label.new()
	banner.text = "GAME OVER"
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 86.0
	banner.offset_bottom = 196.0
	banner.add_theme_font_size_override("font_size", 82)
	banner.add_theme_color_override("font_color", Color("#fde047"))
	banner.add_theme_color_override("font_outline_color", Color("#0f172a"))
	banner.add_theme_constant_override("outline_size", 12)
	banner.modulate.a = 0.0
	root.add_child(banner)

	var sub := Label.new()
	sub.text = "%s · 同理心送花终结「愿下一场战斗我们都更耀眼！」" % winner_name
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sub.offset_top = -150.0
	sub.offset_bottom = -86.0
	sub.add_theme_font_size_override("font_size", 30)
	sub.add_theme_color_override("font_color", Color("#ecfdf5"))
	sub.add_theme_color_override("font_outline_color", Color("#0f172a"))
	sub.add_theme_constant_override("outline_size", 7)
	sub.modulate.a = 0.0
	root.add_child(sub)

	var center_holder := Node2D.new()
	center_holder.position = Vector2(960.0, 560.0)
	root.add_child(center_holder)

	var anim_sprite := Sprite2D.new()
	var tex_path := "res://assets/fighters/enfj/frames/reduced_v2/keyframes/empathy_finish_sheet.png"
	var finish_cols: int = 4
	var finish_rows: int = 1
	var finish_frames: int = 4
	if not ResourceLoader.exists(tex_path):
		tex_path = "res://assets/fighters/enfj/frames/empathy_finish_sheet.png"
		finish_cols = 6
		finish_rows = 4
		finish_frames = 24
	if ResourceLoader.exists(tex_path):
		var tex: Texture2D = load(tex_path) as Texture2D
		anim_sprite.texture = tex
		anim_sprite.hframes = finish_cols
		anim_sprite.vframes = finish_rows
		anim_sprite.frame = 0
		var cell_h: float = tex.get_size().y / float(finish_rows)
		var sc: float = 420.0 / maxf(1.0, cell_h)
		anim_sprite.scale = Vector2(sc, sc)
		var sh: Shader = load("res://shaders/cutout_white.gdshader") as Shader
		if sh:
			var smat := ShaderMaterial.new()
			smat.shader = sh
			anim_sprite.material = smat
	center_holder.add_child(anim_sprite)

	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(bg, "color:a", 0.72, 0.25)
	tw.tween_property(banner, "modulate:a", 1.0, 0.25)
	tw.tween_property(sub, "modulate:a", 1.0, 0.35)
	tw.chain().tween_method(func(f: float) -> void:
		if is_instance_valid(anim_sprite):
			anim_sprite.frame = clampi(int(floor(f)), 0, finish_frames - 1)
	, 0.0, float(finish_frames) - 0.01, 0.85 if finish_frames <= 6 else 1.35)
	tw.chain().tween_interval(1.15)
	tw.chain().tween_property(root, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(root):
			root.queue_free()
		if on_complete.is_valid():
			on_complete.call()
	)


class _CrossStarNode extends Node2D:
	var color: Color = Color.WHITE
	var max_radius: float = 64.0
	var duration: float = 0.18
	var is_heavy: bool = false
	var _elapsed: float = 0.0
	var _rot_start: float = 0.0
	var _slash_angle: float = 0.0

	func _ready() -> void:
		_rot_start = randf_range(-0.4, 0.4)
		_slash_angle = randf_range(-0.65, 0.65)
		rotation = _rot_start

	func _process(delta: float) -> void:
		_elapsed += delta
		if _elapsed >= duration:
			queue_free()
			return
		rotation = _rot_start + (_elapsed / duration) * 0.25
		queue_redraw()

	func _draw() -> void:
		var t: float = clampf(_elapsed / maxf(0.001, duration), 0.0, 1.0)
		var ease_t: float = 1.0 - pow(1.0 - t, 3.0)
		var alpha: float = pow(1.0 - t, 1.5)
		var r: float = max_radius * (0.35 + 0.85 * ease_t)
		var thickness: float = maxf(1.5, (1.0 - t) * (11.0 if is_heavy else 7.5))

		# HDR 超亮色值，触发 WorldEnvironment 真实光学 Bloom
		var hdr_outer := Color(color.r * 2.1, color.g * 2.1, color.b * 2.1, alpha * 0.92)
		var hdr_core := Color(2.6, 2.55, 2.3, alpha)

		# 1. 瞬态白热核闪（前 35% 生命周期最强）
		if t < 0.45:
			var core_a: float = pow(1.0 - t / 0.45, 1.6)
			draw_circle(Vector2.ZERO, max_radius * 0.34 * (1.0 - t * 0.6), Color(2.8, 2.8, 2.6, core_a))

		# 2. 锐利交叉斩切光束（经典格斗命中确认线）
		var slash_len: float = max_radius * (2.0 if is_heavy else 1.45) * (0.5 + 0.6 * ease_t)
		var sdir := Vector2(cos(_slash_angle), sin(_slash_angle))
		var sperp := Vector2(-sdir.y, sdir.x) * (thickness * 0.72)
		draw_colored_polygon(PackedVector2Array([
			sdir * slash_len, sperp, -sdir * slash_len, -sperp
		]), hdr_core)

		# 3. 四向 + 斜向星芒光针
		for i in range(4):
			var ang: float = i * PI * 0.5
			var tip := Vector2(cos(ang), sin(ang)) * r
			var side := Vector2(-sin(ang), cos(ang)) * thickness
			draw_colored_polygon(PackedVector2Array([side, tip, -side, Vector2.ZERO]), hdr_outer)
		for i in range(4):
			var ang2: float = i * PI * 0.5 + PI * 0.25
			var tip2 := Vector2(cos(ang2), sin(ang2)) * (r * 0.58)
			var side2 := Vector2(-sin(ang2), cos(ang2)) * (thickness * 0.48)
			draw_colored_polygon(PackedVector2Array([side2, tip2, -side2, Vector2.ZERO]), hdr_core)
