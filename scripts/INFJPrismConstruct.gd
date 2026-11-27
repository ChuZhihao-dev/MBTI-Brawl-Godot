extends Node2D
class_name INFJPrismConstruct

enum Kind { BOUNCE_BLADE, RIFT_SLASH, GRAVITY_PRISM, DECOY_ILLUSION, PRISM_TRAP, KALEIDOSCOPE_ULT }

var kind: Kind = Kind.BOUNCE_BLADE
var owner_fighter: BaseFighter
var attack_priority: int = BaseFighter.AttackPriority.BASIC
var velocity: Vector2 = Vector2.ZERO
var damage: int = 9
var knockback: Vector2 = Vector2(260.0, -160.0)
var tint_color: Color = Color("#10b981")
var secondary_color: Color = Color("#8b5cf6")
var max_lifetime: float = 1.6
var bounces_left: int = 2
var radius: float = 28.0
var facing_dir: int = 1
var mimic_on_spawn: bool = false

var _elapsed: float = 0.0
var _triggered: bool = false
var _mimic_fired: bool = false
var _ult_slash_idx: int = 0
var _ult_slash_angles: Array[float] = [-0.55, 0.45, -2.55, 2.35]
var _hit_ids: Dictionary = {}
var _ult_layer: CanvasLayer
var _ult_overlay: Control
var _ult_bg_sprite: Sprite2D
var _ult_bg_mat: ShaderMaterial
var _ult_hd_frames: Array[Texture2D] = []
var _ult_shatter_rect: TextureRect
var _ult_shards: Array[Dictionary] = []
var _saved_fighter_z: Dictionary = {}

func _ready() -> void:
	z_index = 27
	add_to_group("infj_constructs")
	if kind == Kind.BOUNCE_BLADE:
		add_to_group("projectiles")
	if kind == Kind.KALEIDOSCOPE_ULT:
		_setup_fullscreen_kaleidoscope()
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add_mat

func _exit_tree() -> void:
	if is_instance_valid(_ult_layer):
		_ult_layer.queue_free()
	if is_instance_valid(_ult_bg_sprite):
		_ult_bg_sprite.queue_free()
	for node in get_tree().get_nodes_in_group("fighters"):
		if is_instance_valid(node) and node is Node2D:
			var nid: int = node.get_instance_id()
			if _saved_fighter_z.has(nid):
				(node as Node2D).z_index = int(_saved_fighter_z[nid])
	_saved_fighter_z.clear()

func _setup_fullscreen_kaleidoscope() -> void:
	# 1. 临时将双方角色抬至 z_index = 12，让万花筒领域(z_index = 5)完美夹在「地图(0)」与「人物(12)」之间！
	_saved_fighter_z.clear()
	for node in get_tree().get_nodes_in_group("fighters"):
		if is_instance_valid(node) and node is Node2D:
			var f2d := node as Node2D
			_saved_fighter_z[f2d.get_instance_id()] = f2d.z_index
			f2d.z_index = 12

	# 自动扫描加载所有高清 16:9 逐帧单图（ult_hd_01.png ~ ult_hd_08.png），每帧原生满清零糊边！
	_ult_hd_frames.clear()
	for idx in range(1, 9):
		var fp := "res://assets/fighters/infj/frames/v3/ult_hd_%02d.png" % idx
		if ResourceLoader.exists(fp):
			var t: Texture2D = load(fp) as Texture2D
			if t:
				_ult_hd_frames.append(t)

	if not _ult_hd_frames.is_empty():
		var first_tex: Texture2D = _ult_hd_frames[0]
		_ult_bg_sprite = Sprite2D.new()
		_ult_bg_sprite.texture = first_tex
		_ult_bg_sprite.z_index = 5
		_ult_bg_sprite.position = Vector2(960.0, 540.0)
		var sc_hd: float = maxf(2040.0 / maxf(1.0, first_tex.get_size().x), 1160.0 / maxf(1.0, first_tex.get_size().y))
		_ult_bg_sprite.scale = Vector2(sc_hd, sc_hd)
		_ult_bg_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
		get_parent().add_child(_ult_bg_sprite)
	else:
		var bg_path := "res://assets/fighters/infj/frames/v3/ult_domain_bg.png"
		if ResourceLoader.exists(bg_path):
			var tex: Texture2D = load(bg_path) as Texture2D
			_ult_bg_sprite = Sprite2D.new()
			_ult_bg_sprite.texture = tex
			_ult_bg_sprite.z_index = 5
			_ult_bg_sprite.position = Vector2(960.0, 540.0)
			var sc2: float = maxf(2040.0 / maxf(1.0, tex.get_size().x), 1160.0 / maxf(1.0, tex.get_size().y))
			_ult_bg_sprite.scale = Vector2(sc2, sc2)
			_ult_bg_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
			get_parent().add_child(_ult_bg_sprite)

	# 2. 前景仅放极轻量的纯加法高光层（layer = 0 严格位于 HUD 之下，只叠加空间裂痕激光与终结碎镜星爆！）
	_ult_layer = CanvasLayer.new()
	_ult_layer.layer = 0
	get_tree().current_scene.add_child(_ult_layer)

	var shatter_path := "res://assets/fighters/infj/frames/v3/ult_shatter_fx.png"
	if ResourceLoader.exists(shatter_path):
		_ult_shatter_rect = TextureRect.new()
		_ult_shatter_rect.texture = load(shatter_path) as Texture2D
		_ult_shatter_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_ult_shatter_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_ult_shatter_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_ult_shatter_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var add_m := CanvasItemMaterial.new()
		add_m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_ult_shatter_rect.material = add_m
		_ult_shatter_rect.modulate = Color(1.35, 1.3, 1.2, 0.0)
		_ult_layer.add_child(_ult_shatter_rect)

	_ult_overlay = Control.new()
	_ult_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ult_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ult_overlay.draw.connect(_draw_fullscreen_kaleidoscope)
	_ult_layer.add_child(_ult_overlay)
	# 预生成 24 块终结飞散碎镜粒子
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_ticks_msec()) % 99991
	_ult_shards.clear()
	for i in range(24):
		var ang: float = float(i) * (TAU / 24.0) + rng.randf_range(-0.12, 0.12)
		_ult_shards.append({
			"ang": ang,
			"spd": rng.randf_range(680.0, 1480.0),
			"size": rng.randf_range(22.0, 52.0),
			"rot_spd": rng.randf_range(-7.0, 7.0),
			"col_idx": i % 3
		})

func reflect(new_owner: BaseFighter) -> void:
	if kind != Kind.BOUNCE_BLADE:
		return
	owner_fighter = new_owner
	velocity = -velocity * 1.25
	knockback.x = -knockback.x
	damage = int(round(float(damage) * 1.25))
	bounces_left = maxi(bounces_left, 1)
	_elapsed = 0.0
	_hit_ids.clear()
	tint_color = Color("#fde047")

func _physics_process(delta: float) -> void:
	_elapsed += delta
	match kind:
		Kind.BOUNCE_BLADE:
			_tick_bounce_blade(delta)
		Kind.RIFT_SLASH:
			_tick_rift_slash()
		Kind.GRAVITY_PRISM:
			_tick_gravity_prism(delta)
		Kind.DECOY_ILLUSION:
			_tick_decoy_illusion()
		Kind.PRISM_TRAP:
			_tick_prism_trap()
		Kind.KALEIDOSCOPE_ULT:
			_tick_kaleidoscope_ult()
	queue_redraw()

func _get_enemy() -> BaseFighter:
	for node in get_tree().get_nodes_in_group("fighters"):
		if node != owner_fighter and node is BaseFighter:
			var f := node as BaseFighter
			if not f.is_ko:
				return f
	return null

func _tick_bounce_blade(delta: float) -> void:
	if _elapsed >= max_lifetime:
		queue_free()
		return
	global_position += velocity * delta
	var bounced: bool = false
	if global_position.y >= 544.0 and velocity.y > 0.0:
		global_position.y = 544.0
		velocity.y = -absf(velocity.y)
		bounced = true
	elif global_position.y <= 115.0 and velocity.y < 0.0:
		global_position.y = 115.0
		velocity.y = absf(velocity.y)
		bounced = true
	if global_position.x <= 228.0 and velocity.x < 0.0:
		global_position.x = 228.0
		velocity.x = absf(velocity.x)
		bounced = true
	elif global_position.x >= 1572.0 and velocity.x > 0.0:
		global_position.x = 1572.0
		velocity.x = -absf(velocity.x)
		bounced = true

	if bounced:
		if bounces_left <= 0:
			queue_free()
			return
		bounces_left -= 1
		_hit_ids.clear()
		# 每次折射轻微修正朝向对手，体现“洞察预判弹道”
		var enemy := _get_enemy()
		if enemy:
			var to_enemy: Vector2 = (enemy.global_position + Vector2(0.0, -48.0) - global_position).normalized()
			var spd: float = velocity.length() * 1.06
			velocity = velocity.normalized().lerp(to_enemy, 0.42).normalized() * spd
		AudioManager.play_sfx("charge_2", -6.0, 1.15 + float(2 - bounces_left) * 0.1)
		var vfx := BattleVFX.get_current(get_tree())
		if vfx:
			vfx.spawn_shockwave_ring(global_position, tint_color, 6.0, 44.0, 0.16, 3.0)

	var enemy_hit := _get_enemy()
	if enemy_hit:
		var tid: int = enemy_hit.get_instance_id()
		if not _hit_ids.has(tid) and global_position.distance_to(enemy_hit.global_position + Vector2(0.0, -48.0)) <= radius + 22.0:
			_hit_ids[tid] = true
			var kb_x: float = signf(velocity.x) * absf(knockback.x)
			enemy_hit.take_damage(damage, Vector2(kb_x, knockback.y), owner_fighter, false, attack_priority)
			queue_free()

func _tick_rift_slash() -> void:
	if not _triggered and _elapsed >= 0.24:
		_triggered = true
		AudioManager.play_sfx("swing_heavy", -3.0, 1.32)
		var vfx := BattleVFX.get_current(get_tree())
		if vfx:
			vfx.spawn_shockwave_ring(global_position, secondary_color, 10.0, 88.0, 0.22, 5.0)
			vfx.spawn_hit_particles(global_position, secondary_color, 14, 300.0)
		var enemy := _get_enemy()
		if enemy and global_position.distance_to(enemy.global_position + Vector2(0.0, -48.0)) <= 96.0:
			var interrupted := enemy.take_damage(damage, knockback, owner_fighter, false, attack_priority)
			if vfx and interrupted:
				vfx.spawn_floating_text(enemy.global_position + Vector2(0.0, -108.0), "背刺裂隙!", secondary_color.lightened(0.25), 1.02)
	if _elapsed >= 0.48:
		queue_free()

func _tick_gravity_prism(delta: float) -> void:
	global_position += velocity * delta
	velocity = velocity.move_toward(Vector2.ZERO, 920.0 * delta)
	global_position.x = clampf(global_position.x, 240.0, 1560.0)

	# 爆发前产生轻微向心牵引力，打乱对手走位
	var enemy := _get_enemy()
	if not _triggered and enemy and _elapsed >= 0.08 and enemy.get_action_armor() <= attack_priority and enemy.invincible_timer <= 0.0 and not enemy.is_isfp_ultimate_invulnerable():
		var to_center: Vector2 = global_position - (enemy.global_position + Vector2(0.0, -48.0))
		if to_center.length() <= 165.0 and to_center.length() > 16.0:
			enemy.velocity += to_center.normalized() * 520.0 * delta

	if not _triggered and _elapsed >= 0.36:
		_triggered = true
		AudioManager.play_sfx("hit_heavy", -2.5, 1.12)
		var vfx := BattleVFX.get_current(get_tree())
		if vfx:
			vfx.spawn_shockwave_ring(global_position, secondary_color, 14.0, 152.0, 0.28, 6.5)
			vfx.spawn_shockwave_ring(global_position, tint_color, 8.0, 108.0, 0.22, 4.0)
			vfx.spawn_hit_particles(global_position, secondary_color, 20, 360.0)
		if enemy and global_position.distance_to(enemy.global_position + Vector2(0.0, -48.0)) <= 152.0:
			var push_x: float = signf(enemy.global_position.x - global_position.x)
			if push_x == 0.0:
				push_x = float(facing_dir)
			var interrupted := enemy.take_damage(damage, Vector2(push_x * 240.0, -390.0), owner_fighter, false, attack_priority)
			if interrupted:
				GameManager.trigger_shake(6.5, 0.14, Vector2(0.0, -1.0))
			if vfx and interrupted:
				vfx.spawn_floating_text(enemy.global_position + Vector2(0.0, -112.0), "维度坍缩!", secondary_color.lightened(0.25), 1.08)
	if _elapsed >= 0.56:
		queue_free()

func _tick_decoy_illusion() -> void:
	if _elapsed >= max_lifetime:
		queue_free()
		return
	if mimic_on_spawn and not _mimic_fired and _elapsed >= 0.28:
		_mimic_fired = true
		if is_instance_valid(owner_fighter):
			var blade := INFJPrismConstruct.new()
			blade.kind = Kind.BOUNCE_BLADE
			blade.owner_fighter = owner_fighter
			blade.attack_priority = attack_priority
			blade.global_position = global_position + Vector2(facing_dir * 26.0, -48.0)
			blade.velocity = Vector2(facing_dir * 660.0, 0.0)
			blade.damage = 7
			blade.knockback = Vector2(facing_dir * 240.0, -130.0)
			blade.tint_color = tint_color
			blade.bounces_left = 1
			blade.max_lifetime = 1.05
			get_parent().add_child(blade)
			AudioManager.play_sfx("swing_light", -6.0, 1.25)

	var enemy := _get_enemy()
	if enemy and _elapsed >= 0.10:
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist <= 62.0 or (dist <= 105.0 and enemy.action_anim_timer > 0.0):
			var push_x := signf(enemy.global_position.x - global_position.x)
			if push_x == 0.0:
				push_x = float(facing_dir)
			var interrupted := enemy.take_damage(damage, Vector2(push_x * 340.0, -260.0), owner_fighter, false, attack_priority)
			if interrupted:
				AudioManager.play_sfx("parry", -2.0, 1.05)
				GameManager.trigger_hitstop(0.07)
				GameManager.trigger_shake(6.0, 0.14, Vector2(push_x, -0.3))
				var vfx := BattleVFX.get_current(get_tree())
				if vfx:
					vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -48.0), Color("#fde047"), 14.0, 130.0, 0.28, 6.0)
					vfx.spawn_hit_particles(global_position + Vector2(0.0, -48.0), tint_color, 22, 340.0)
					vfx.spawn_floating_text(enemy.global_position + Vector2(0.0, -112.0), "幻象反制!", Color("#fde047"), 1.14)
			queue_free()

func _tick_prism_trap() -> void:
	if _elapsed >= max_lifetime:
		queue_free()
		return
	if _elapsed < 0.28:
		return
	var enemy := _get_enemy()
	if enemy and global_position.distance_to(enemy.global_position) <= 68.0:
		var interrupted := enemy.take_damage(damage, Vector2(0.0, -340.0), owner_fighter, false, attack_priority)
		if interrupted:
			enemy.hitstun_timer = maxf(enemy.hitstun_timer, 0.34)
			AudioManager.play_sfx("hit_heavy", -3.0, 1.2)
			var vfx := BattleVFX.get_current(get_tree())
			if vfx:
				vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -24.0), Color("#fde047"), 10.0, 118.0, 0.26, 5.5)
				vfx.spawn_hit_particles(global_position + Vector2(0.0, -24.0), tint_color, 18, 320.0)
				vfx.spawn_floating_text(enemy.global_position + Vector2(0.0, -110.0), "折光捕获!", Color("#fde047"), 1.08)
		queue_free()

func _tick_kaleidoscope_ult() -> void:
	var vfx := BattleVFX.get_current(get_tree())
	var enemy := _get_enemy()
	if enemy and _elapsed < 0.62:
		global_position = global_position.lerp(enemy.global_position + Vector2(0.0, -52.0), 0.18)

	# 阶段 1：4 道贯穿全屏的表里空间斩裂光束（0.16s, 0.28s, 0.40s, 0.52s）
	var slash_times: Array[float] = [0.16, 0.28, 0.40, 0.52]
	if _ult_slash_idx < slash_times.size() and _elapsed >= slash_times[_ult_slash_idx]:
		var col: Color = tint_color if (_ult_slash_idx % 2 == 0) else secondary_color
		AudioManager.play_sfx("swing_heavy", -2.0, 1.12 + float(_ult_slash_idx) * 0.09)
		GameManager.trigger_shake(6.5, 0.09, Vector2(cos(_ult_slash_angles[_ult_slash_idx]), sin(_ult_slash_angles[_ult_slash_idx])))
		if vfx:
			vfx.trigger_screen_flash(col, 0.16, 0.09)
			vfx.spawn_shockwave_ring(global_position, col, 16.0, 155.0, 0.22, 6.0)
			vfx.spawn_hit_particles(global_position, col, 18, 380.0)
		if enemy and global_position.distance_to(enemy.global_position + Vector2(0.0, -48.0)) <= 230.0:
			enemy.take_damage(6, Vector2(0.0, -95.0), owner_fighter, true, BaseFighter.AttackPriority.ULTIMATE)
		_ult_slash_idx += 1

	# 阶段 2：0.72s 全屏万花筒镜界向中心坍缩 · 玻璃碎裂终结！
	if not _triggered and _elapsed >= 0.72:
		_triggered = true
		AudioManager.play_sfx("shield_break", -0.5, 0.88)
		AudioManager.play_sfx("ko", -1.5, 1.18)
		GameManager.trigger_hitstop(0.16)
		GameManager.trigger_shake(18.0, 0.34, Vector2(float(facing_dir), -0.35))
		if vfx:
			vfx.trigger_screen_flash(Color("#fef9c3"), 0.58, 0.26)
			vfx.spawn_shockwave_ring(global_position, Color("#fde047"), 24.0, 320.0, 0.42, 11.0)
			vfx.spawn_shockwave_ring(global_position, secondary_color, 16.0, 250.0, 0.36, 8.5)
			vfx.spawn_hit_particles(global_position, Color("#fde047"), 38, 620.0)
			vfx.spawn_floating_text(global_position + Vector2(0.0, -96.0), "万花筒镜界 · 坍缩!!", Color("#fde047"), 1.48)
		if enemy and global_position.distance_to(enemy.global_position + Vector2(0.0, -48.0)) <= 270.0:
			var push_x: float = signf(enemy.global_position.x - global_position.x)
			if push_x == 0.0:
				push_x = float(facing_dir)
			enemy.take_damage(16, Vector2(push_x * 580.0, -370.0), owner_fighter, true, BaseFighter.AttackPriority.ULTIMATE)

	# 全高清 16:9 逐帧序列播放（支持 4~8 帧自动均分时间轴，每帧原生满清锐利、严格夹在地图与人物之间！）
	if is_instance_valid(_ult_bg_sprite):
		var fi: float = clampf(_elapsed / 0.10, 0.0, 1.0)
		var fo: float = clampf((1.18 - _elapsed) / 0.24, 0.0, 1.0)
		if not _ult_hd_frames.is_empty():
			var norm_t: float = clampf(_elapsed / 1.02, 0.0, 0.999)
			var f_idx: int = clampi(int(floor(norm_t * float(_ult_hd_frames.size()))), 0, _ult_hd_frames.size() - 1)
			var target_tex: Texture2D = _ult_hd_frames[f_idx]
			if _ult_bg_sprite.texture != target_tex:
				_ult_bg_sprite.texture = target_tex
		_ult_bg_sprite.modulate = Color(0.94, 0.96, 0.98, 0.90 * fi * fo)

	if is_instance_valid(_ult_shatter_rect):
		var vp_s: Vector2 = _ult_shatter_rect.get_viewport_rect().size
		_ult_shatter_rect.pivot_offset = vp_s * 0.5
		if _elapsed >= 0.70:
			var dt_s: float = _elapsed - 0.70
			var s_a: float = clampf(1.0 - dt_s / 0.40, 0.0, 1.0)
			var s_sc: float = lerpf(0.85, 1.32, clampf(dt_s / 0.30, 0.0, 1.0))
			_ult_shatter_rect.scale = Vector2(s_sc, s_sc)
			_ult_shatter_rect.modulate = Color(0.95, 0.92, 0.88, s_a * 0.62)
		else:
			_ult_shatter_rect.modulate.a = 0.0

	if is_instance_valid(_ult_overlay):
		_ult_overlay.queue_redraw()
	if _elapsed >= 1.18:
		queue_free()

func _draw_fullscreen_kaleidoscope() -> void:
	if not is_instance_valid(_ult_overlay):
		return
	var vp: Vector2 = _ult_overlay.get_viewport_rect().size
	var center: Vector2 = vp * 0.5
	var has_art_bg: bool = is_instance_valid(_ult_bg_sprite)
	var fade_in: float = clampf(_elapsed / 0.14, 0.0, 1.0)
	var fade_out: float = clampf((1.18 - _elapsed) / 0.30, 0.0, 1.0)
	var alpha: float = fade_in * fade_out

	# 若已加载精绘万花筒背景图，仅叠加极轻暗角与空间斩裂激光；不再画粗糙的纯色大三角！
	if not has_art_bg:
		var dark_a: float = 0.58 * alpha if _elapsed < 0.72 else 0.42 * fade_out
		_ult_overlay.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.04, 0.03, 0.11, dark_a), true)

	if _elapsed < 0.74:
		# 4 道贯穿整个 1920x1080 屏幕的空间斩裂激光（叠加在精绘万花筒隧道上极度炸裂！）
		for k in range(_ult_slash_idx):
			var slash_t: float = _elapsed - (0.16 + float(k) * 0.12)
			var s_fade: float = clampf(1.0 - slash_t / 0.36, 0.0, 1.0)
			if s_fade <= 0.0:
				continue
			var sa: float = _ult_slash_angles[k]
			var sv := Vector2(cos(sa), sin(sa))
			var scol: Color = tint_color if (k % 2 == 0) else secondary_color
			_ult_overlay.draw_line(center - sv * 1400.0, center + sv * 1400.0, Color(scol.r, scol.g, scol.b, 0.78 * s_fade), 24.0 * s_fade, true)
			_ult_overlay.draw_line(center - sv * 1400.0, center + sv * 1400.0, Color(1.0, 1.0, 0.92, 0.96 * s_fade), 6.0 * s_fade, true)
	else:
		# 0.72s 终结：叠加碎镜冲击裂纹与飞散镜片（若加载了 ult_shatter_fx.png 则作为额外粒子层次烘托）
		var dt_boom: float = _elapsed - 0.72
		var crack_a: float = clampf(1.0 - dt_boom / 0.38, 0.0, 1.0)
		if not is_instance_valid(_ult_shatter_rect):
			for r_i in range(10):
				var ca: float = float(r_i) * (TAU / 10.0) + 0.18
				var cv := Vector2(cos(ca), sin(ca))
				_ult_overlay.draw_line(center, center + cv * 1100.0, Color(1.0, 0.96, 0.78, 0.72 * crack_a), 4.0 * crack_a, true)
		for sh: Dictionary in _ult_shards:
			var ang: float = float(sh["ang"])
			var spd: float = float(sh["spd"])
			var sz: float = float(sh["size"]) * (1.0 - dt_boom * 0.55)
			if sz <= 2.0:
				continue
			var pos: Vector2 = center + Vector2(cos(ang), sin(ang)) * (dt_boom * spd)
			var srot: float = ang + dt_boom * float(sh["rot_spd"])
			var c_idx: int = int(sh["col_idx"])
			var scol2: Color = tint_color if c_idx == 0 else (secondary_color if c_idx == 1 else Color("#fde047"))
			var fdir := Vector2(cos(srot), sin(srot))
			var fperp := Vector2(-fdir.y, fdir.x)
			_ult_overlay.draw_colored_polygon(PackedVector2Array([
				pos + fdir * sz,
				pos + fperp * (sz * 0.52),
				pos - fdir * (sz * 0.85),
				pos - fperp * (sz * 0.45)
			]), Color(scol2.r, scol2.g, scol2.b, 0.85 * crack_a))

func _draw() -> void:
	match kind:
		Kind.BOUNCE_BLADE:
			var ang: float = velocity.angle() if velocity.length() > 1.0 else 0.0
			draw_set_transform(Vector2.ZERO, ang, Vector2.ONE)
			var pts := PackedVector2Array([
				Vector2(26.0, 0.0),
				Vector2(0.0, 11.0),
				Vector2(-24.0, 0.0),
				Vector2(0.0, -11.0)
			])
			draw_colored_polygon(pts, Color(tint_color.r * 1.8, tint_color.g * 1.8, tint_color.b * 1.8, 0.92))
			var core := PackedVector2Array([
				Vector2(15.0, 0.0),
				Vector2(0.0, 5.0),
				Vector2(-12.0, 0.0),
				Vector2(0.0, -5.0)
			])
			draw_colored_polygon(core, Color(2.4, 2.5, 2.3, 1.0))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		Kind.RIFT_SLASH:
			var prog: float = clampf(_elapsed / 0.24, 0.0, 1.0)
			var w: float = 5.0 if not _triggered else 22.0 * (1.0 - clampf((_elapsed - 0.24) / 0.24, 0.0, 1.0))
			var h: float = 48.0 * prog if not _triggered else 76.0
			draw_set_transform(Vector2.ZERO, -0.35 * float(facing_dir), Vector2.ONE)
			var pts := PackedVector2Array([
				Vector2(0.0, -h),
				Vector2(w, 0.0),
				Vector2(0.0, h),
				Vector2(-w, 0.0)
			])
			draw_colored_polygon(pts, Color(secondary_color.r * 2.0, secondary_color.g * 2.0, secondary_color.b * 2.0, 0.9))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		Kind.GRAVITY_PRISM:
			var rot: float = _elapsed * 8.5
			var sc: float = 1.0 + sin(_elapsed * 20.0) * 0.14
			draw_set_transform(Vector2.ZERO, rot, Vector2(sc, sc))
			var pts := PackedVector2Array([
				Vector2(0.0, -24.0),
				Vector2(20.0, 0.0),
				Vector2(0.0, 24.0),
				Vector2(-20.0, 0.0)
			])
			draw_colored_polygon(pts, Color(secondary_color.r * 1.8, secondary_color.g * 1.8, secondary_color.b * 1.8, 0.88))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var pull_r: float = lerpf(135.0, 28.0, clampf(_elapsed / 0.36, 0.0, 1.0))
			draw_arc(Vector2.ZERO, pull_r, rot, rot + PI * 1.6, 28, Color(tint_color.r * 1.6, tint_color.g * 1.6, tint_color.b * 1.6, 0.65), 3.0, true)

		Kind.DECOY_ILLUSION:
			var fade: float = clampf(1.0 - _elapsed / max_lifetime, 0.2, 1.0)
			var pulse: float = 0.5 + 0.5 * sin(_elapsed * 12.0)
			var c := Color(tint_color.r * 1.4, tint_color.g * 1.4, tint_color.b * 1.4, 0.55 * fade)
			# 低多边形水晶人影轮廓
			var body := PackedVector2Array([
				Vector2(0.0, -108.0),
				Vector2(22.0, -78.0),
				Vector2(18.0, -14.0),
				Vector2(0.0, 0.0),
				Vector2(-18.0, -14.0),
				Vector2(-22.0, -78.0)
			])
			draw_colored_polygon(body, c)
			draw_arc(Vector2(0.0, -56.0), 40.0 + pulse * 6.0, 0.0, TAU, 24, Color(1.0, 0.92, 0.45, 0.55 * fade), 2.5, true)

		Kind.PRISM_TRAP:
			var armed: bool = _elapsed >= 0.28
			var al: float = 0.72 if armed else 0.35
			var col := Color(tint_color.r * 1.6, tint_color.g * 1.6, tint_color.b * 1.6, al)
			var pts := PackedVector2Array([
				Vector2(-32.0, -2.0),
				Vector2(0.0, -16.0),
				Vector2(32.0, -2.0),
				Vector2(0.0, 6.0)
			])
			draw_colored_polygon(pts, col)
			draw_arc(Vector2(0.0, -4.0), 38.0, 0.0, TAU, 20, Color(0.99, 0.9, 0.4, al * 0.7), 2.0, true)

		Kind.KALEIDOSCOPE_ULT:
			var rot: float = _elapsed * 3.8
			var shrink: float = lerpf(1.0, 0.25, clampf((_elapsed - 0.50) / 0.18, 0.0, 1.0)) if _elapsed > 0.50 else 1.0
			var ring_r: float = 148.0 * shrink
			for i in range(6):
				var a: float = rot + float(i) * (TAU / 6.0)
				var p := Vector2(cos(a), sin(a)) * ring_r
				var shard_col: Color = tint_color if (i % 2 == 0) else secondary_color
				draw_set_transform(p, a + PI * 0.5, Vector2.ONE)
				draw_colored_polygon(PackedVector2Array([
					Vector2(0.0, -22.0),
					Vector2(14.0, 0.0),
					Vector2(0.0, 22.0),
					Vector2(-14.0, 0.0)
				]), Color(shard_col.r * 1.9, shard_col.g * 1.9, shard_col.b * 1.9, 0.85))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 36, Color(2.0, 1.9, 1.1, 0.75), 4.0, true)
			# 绘制已触发的交错斩击光线
			for k in range(_ult_slash_idx):
				var sa: float = _ult_slash_angles[k]
				var dir_v := Vector2(cos(sa), sin(sa))
				var lcol: Color = tint_color if (k % 2 == 0) else secondary_color
				draw_line(-dir_v * 180.0, dir_v * 180.0, Color(lcol.r * 2.1, lcol.g * 2.1, lcol.b * 2.1, 0.85), 6.0, true)
