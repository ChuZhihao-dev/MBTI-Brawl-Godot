extends Node2D
class_name MysticOrbProjectile

var owner_fighter: BaseFighter
var velocity: Vector2 = Vector2(560.0, 0.0)
var damage: int = 8
var knockback: Vector2 = Vector2(210.0, -110.0)
var max_lifetime: float = 0.95
var hit_radius: float = 24.0
var orb_radius: float = 15.0
var tint_color: Color = Color("#10b981")
var hit_callout: String = ""
var is_mine: bool = false
var mine_arm_time: float = 0.32
var explode_radius: float = 92.0
var is_ultimate: bool = false

var _elapsed: float = 0.0
var _ember_timer: float = 0.0
var _add_mat: CanvasItemMaterial

func _ready() -> void:
	z_index = 26
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = _add_mat

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= max_lifetime:
		if is_mine:
			_detonate_mine()
		else:
			queue_free()
		return

	if not is_mine:
		global_position += velocity * delta
		if global_position.x < 100.0 or global_position.x > 1700.0 or global_position.y < -120.0 or global_position.y > 840.0:
			queue_free()
			return

	_ember_timer -= delta
	if _ember_timer <= 0.0:
		_ember_timer = 0.06 if not is_mine else 0.14
		var vfx := BattleVFX.get_current(get_tree())
		if vfx:
			vfx.spawn_ember_burst(global_position, tint_color, 2)

	if is_mine and _elapsed < mine_arm_time:
		queue_redraw()
		return

	for node in get_tree().get_nodes_in_group("fighters"):
		if node == owner_fighter or not (node is BaseFighter):
			continue
		var target := node as BaseFighter
		if target.is_ko:
			continue
		var target_center: Vector2 = target.global_position + Vector2(0.0, -48.0)
		var trigger_r: float = (explode_radius * 0.55) if is_mine else hit_radius
		if global_position.distance_to(target_center) <= trigger_r:
			if is_mine:
				_detonate_mine()
			else:
				_hit_target(target)
				queue_free()
			return

	queue_redraw()

func _hit_target(target: BaseFighter) -> void:
	target.take_damage(damage, knockback, owner_fighter, is_ultimate)
	if hit_callout != "":
		var vfx := BattleVFX.get_current(get_tree())
		if vfx:
			vfx.spawn_floating_text(target.global_position + Vector2(0.0, -108.0), hit_callout, tint_color.lightened(0.3), 0.94)

func _detonate_mine() -> void:
	var vfx := BattleVFX.get_current(get_tree())
	AudioManager.play_sfx("hit_heavy", -3.0, 1.1)
	if vfx:
		vfx.spawn_shockwave_ring(global_position, tint_color, 12.0, explode_radius, 0.28, 6.0)
		vfx.spawn_hit_particles(global_position, tint_color, 18, 320.0)
	for node in get_tree().get_nodes_in_group("fighters"):
		if node == owner_fighter or not (node is BaseFighter):
			continue
		var target := node as BaseFighter
		if target.is_ko:
			continue
		var target_center: Vector2 = target.global_position + Vector2(0.0, -48.0)
		if global_position.distance_to(target_center) <= explode_radius:
			var push_dir: float = signf(target.global_position.x - global_position.x)
			if push_dir == 0.0:
				push_dir = 1.0
			target.take_damage(damage, Vector2(push_dir * absf(knockback.x), knockback.y), owner_fighter, is_ultimate)
			if hit_callout != "":
				if vfx:
					vfx.spawn_floating_text(target.global_position + Vector2(0.0, -112.0), hit_callout, Color("#fde047"), 1.05)
	queue_free()

func _draw() -> void:
	var pulse: float = 1.0 + 0.14 * sin(_elapsed * 18.0)
	var r: float = orb_radius * pulse
	var hdr_outer := Color(tint_color.r * 1.9, tint_color.g * 1.9, tint_color.b * 1.9, 0.65)
	var hdr_mid := Color(tint_color.r * 2.2, tint_color.g * 2.2, tint_color.b * 2.2, 0.92)
	var hdr_core := Color(2.5, 2.6, 2.4, 1.0)

	if is_mine:
		var rot: float = _elapsed * 3.5
		draw_arc(Vector2.ZERO, r * 1.65, rot, rot + PI * 1.5, 24, hdr_mid, 3.0, true)
		draw_circle(Vector2.ZERO, r * 0.85, hdr_outer)
		draw_circle(Vector2.ZERO, r * 0.42, hdr_core)
	else:
		# 灵球主体 + 速度拖尾菱形光晕
		var tail_dir: Vector2 = -velocity.normalized() if velocity.length() > 1.0 else Vector2(-1.0, 0.0)
		var perp := Vector2(-tail_dir.y, tail_dir.x)
		draw_colored_polygon(PackedVector2Array([
			perp * (r * 0.72),
			tail_dir * (r * 2.4),
			-perp * (r * 0.72),
			-tail_dir * (r * 0.65)
		]), hdr_outer)
		draw_circle(Vector2.ZERO, r, hdr_mid)
		draw_circle(Vector2.ZERO, r * 0.52, hdr_core)
