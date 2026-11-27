extends Node2D
class_name INFJPrismConstruct

enum Kind { BOUNCE_BLADE, RIFT_SLASH, GRAVITY_PRISM, DECOY_ILLUSION, PRISM_TRAP, KALEIDOSCOPE_ULT }

var kind: Kind = Kind.BOUNCE_BLADE
var owner_fighter: BaseFighter
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

func _ready() -> void:
	z_index = 27
	add_to_group("infj_constructs")
	if kind == Kind.BOUNCE_BLADE:
		add_to_group("projectiles")
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add_mat

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
			enemy_hit.take_damage(damage, Vector2(kb_x, knockback.y), owner_fighter, false)
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
			enemy.take_damage(damage, knockback, owner_fighter, false)
			if vfx:
				vfx.spawn_floating_text(enemy.global_position + Vector2(0.0, -108.0), "背刺裂隙!", secondary_color.lightened(0.25), 1.02)
	if _elapsed >= 0.48:
		queue_free()

func _tick_gravity_prism(delta: float) -> void:
	global_position += velocity * delta
	velocity = velocity.move_toward(Vector2.ZERO, 920.0 * delta)
	global_position.x = clampf(global_position.x, 240.0, 1560.0)

	# 爆发前产生轻微向心牵引力，打乱对手走位
	var enemy := _get_enemy()
	if not _triggered and enemy and _elapsed >= 0.08:
		var to_center: Vector2 = global_position - (enemy.global_position + Vector2(0.0, -48.0))
		if to_center.length() <= 165.0 and to_center.length() > 16.0:
			enemy.velocity += to_center.normalized() * 520.0 * delta

	if not _triggered and _elapsed >= 0.36:
		_triggered = true
		AudioManager.play_sfx("hit_heavy", -2.5, 1.12)
		GameManager.trigger_shake(6.5, 0.14, Vector2(0.0, -1.0))
		var vfx := BattleVFX.get_current(get_tree())
		if vfx:
			vfx.spawn_shockwave_ring(global_position, secondary_color, 14.0, 152.0, 0.28, 6.5)
			vfx.spawn_shockwave_ring(global_position, tint_color, 8.0, 108.0, 0.22, 4.0)
			vfx.spawn_hit_particles(global_position, secondary_color, 20, 360.0)
		if enemy and global_position.distance_to(enemy.global_position + Vector2(0.0, -48.0)) <= 152.0:
			var push_x: float = signf(enemy.global_position.x - global_position.x)
			if push_x == 0.0:
				push_x = float(facing_dir)
			enemy.take_damage(damage, Vector2(push_x * 240.0, -390.0), owner_fighter, false)
			if vfx:
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
			# 对手误触或攻击幻象 -> 反击碎裂爆破！
			AudioManager.play_sfx("parry", -2.0, 1.05)
			GameManager.trigger_hitstop(0.07)
			GameManager.trigger_shake(6.0, 0.14, Vector2(signf(enemy.global_position.x - global_position.x), -0.3))
			var vfx := BattleVFX.get_current(get_tree())
			if vfx:
				vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -48.0), Color("#fde047"), 14.0, 130.0, 0.28, 6.0)
				vfx.spawn_hit_particles(global_position + Vector2(0.0, -48.0), tint_color, 22, 340.0)
				vfx.spawn_floating_text(global_position + Vector2(0.0, -112.0), "幻象反制!", Color("#fde047"), 1.14)
			var push_x: float = signf(enemy.global_position.x - global_position.x)
			if push_x == 0.0:
				push_x = float(facing_dir)
			enemy.take_damage(damage, Vector2(push_x * 340.0, -260.0), owner_fighter, false)
			queue_free()

func _tick_prism_trap() -> void:
	if _elapsed >= max_lifetime:
		queue_free()
		return
	if _elapsed < 0.28:
		return
	var enemy := _get_enemy()
	if enemy and global_position.distance_to(enemy.global_position) <= 68.0:
		AudioManager.play_sfx("hit_heavy", -3.0, 1.2)
		var vfx := BattleVFX.get_current(get_tree())
		if vfx:
			vfx.spawn_shockwave_ring(global_position + Vector2(0.0, -24.0), Color("#fde047"), 10.0, 118.0, 0.26, 5.5)
			vfx.spawn_hit_particles(global_position + Vector2(0.0, -24.0), tint_color, 18, 320.0)
			vfx.spawn_floating_text(enemy.global_position + Vector2(0.0, -110.0), "折光捕获!", Color("#fde047"), 1.08)
		enemy.take_damage(damage, Vector2(0.0, -340.0), owner_fighter, false)
		enemy.hitstun_timer = maxf(enemy.hitstun_timer, 0.34)
		queue_free()

func _tick_kaleidoscope_ult() -> void:
	var vfx := BattleVFX.get_current(get_tree())
	var enemy := _get_enemy()
	if enemy and _elapsed < 0.56:
		global_position = global_position.lerp(enemy.global_position + Vector2(0.0, -52.0), 0.16)

	# 阶段 1：四面八方表里幻影交错穿刺（0.14s, 0.26s, 0.38s, 0.50s）
	var slash_times: Array[float] = [0.14, 0.26, 0.38, 0.50]
	if _ult_slash_idx < slash_times.size() and _elapsed >= slash_times[_ult_slash_idx]:
		var col: Color = tint_color if (_ult_slash_idx % 2 == 0) else secondary_color
		AudioManager.play_sfx("swing_heavy", -2.5, 1.15 + float(_ult_slash_idx) * 0.08)
		if vfx:
			vfx.spawn_shockwave_ring(global_position, col, 14.0, 130.0, 0.22, 5.5)
			vfx.spawn_hit_particles(global_position, col, 14, 340.0)
		if enemy and global_position.distance_to(enemy.global_position + Vector2(0.0, -48.0)) <= 185.0:
			enemy.take_damage(6, Vector2(0.0, -90.0), owner_fighter, true)
		_ult_slash_idx += 1

	# 阶段 2：0.68s 万花筒镜界向中心坍缩碎裂终结！
	if not _triggered and _elapsed >= 0.68:
		_triggered = true
		AudioManager.play_sfx("ko", -2.0, 1.25)
		GameManager.trigger_hitstop(0.16)
		GameManager.trigger_shake(15.0, 0.28, Vector2(float(facing_dir), -0.35))
		if vfx:
			vfx.trigger_screen_flash(Color("#a7f3d0"), 0.36, 0.24)
			vfx.spawn_shockwave_ring(global_position, Color("#fde047"), 20.0, 240.0, 0.38, 9.0)
			vfx.spawn_shockwave_ring(global_position, secondary_color, 14.0, 195.0, 0.32, 7.0)
			vfx.spawn_hit_particles(global_position, Color("#fde047"), 32, 520.0)
			vfx.spawn_floating_text(global_position + Vector2(0.0, -82.0), "万花筒坍缩!", Color("#fde047"), 1.38)
		if enemy and global_position.distance_to(enemy.global_position + Vector2(0.0, -48.0)) <= 220.0:
			var push_x: float = signf(enemy.global_position.x - global_position.x)
			if push_x == 0.0:
				push_x = float(facing_dir)
			enemy.take_damage(16, Vector2(push_x * 540.0, -350.0), owner_fighter, true)

	if _elapsed >= 0.98:
		queue_free()

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
