extends Node2D
class_name SwordWaveProjectile

var owner_fighter: BaseFighter
var velocity: Vector2 = Vector2(760.0, 0.0)
var damage: int = 8
var knockback: Vector2 = Vector2(280.0, -140.0)
var max_lifetime: float = 0.85
var hit_radius: float = 44.0
var is_ultimate: bool = false
var charge_level: int = 1
var tint_color: Color = Color("#34d399")
var wave_scale: float = 1.0

var _elapsed: float = 0.0
var _ghost_timer: float = 0.0
var _hit_ids: Dictionary = {}
var _sprite: Sprite2D

func _ready() -> void:
	z_index = 25
	add_to_group("projectiles")
	_sprite = Sprite2D.new()
	var tex_path := "res://assets/fighters/enfj/frames/reduced_v2/ultimate_projectile.png" if is_ultimate else ("res://assets/fighters/enfj/frames/reduced_v2/sword_wave_lv%d.png" % clampi(charge_level, 1, 3))
	if not ResourceLoader.exists(tex_path):
		tex_path = "res://assets/fighters/enfj/frames/reduced_v2/sword_wave_lv1.png"
	if not ResourceLoader.exists(tex_path):
		tex_path = "res://assets/fighters/enfj/frames/reduced_v2/sword_wave_projectile.png"
	if not ResourceLoader.exists(tex_path):
		tex_path = "res://assets/fighters/enfj/frames/sword_wave_projectile.png"
	if ResourceLoader.exists(tex_path):
		var tex: Texture2D = load(tex_path) as Texture2D
		_sprite.texture = tex
		var base_h: float = 128.0 * wave_scale
		var sc: float = base_h / maxf(1.0, tex.get_size().y)
		_sprite.scale = Vector2(sc, sc)
	_sprite.flip_h = velocity.x < 0.0
	if velocity.length() > 1.0:
		var ang: float = velocity.angle()
		if velocity.x < 0.0:
			ang = wrapf(ang - PI, -PI, PI)
		_sprite.rotation = ang
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sprite.material = add_mat
	if is_ultimate:
		_sprite.modulate = Color(2.1, 1.95, 0.95, 1.0)
	elif charge_level >= 3:
		_sprite.modulate = Color(1.85, 1.75, 0.85, 1.0)
	elif charge_level == 2:
		_sprite.modulate = Color(1.45, 1.65, 1.15, 0.98)
	else:
		_sprite.modulate = Color(tint_color.r * 1.45, tint_color.g * 1.45, tint_color.b * 1.45, 0.95)
	add_child(_sprite)

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= max_lifetime:
		queue_free()
		return
	global_position += velocity * delta
	if global_position.x < 80.0 or global_position.x > 1720.0 or global_position.y < -120.0 or global_position.y > 860.0:
		queue_free()
		return

	_ghost_timer -= delta
	if _ghost_timer <= 0.0:
		_ghost_timer = 0.032 if is_ultimate else 0.05
		var vfx := BattleVFX.get_current(get_tree())
		if vfx and _sprite:
			vfx.spawn_ghost(_sprite, Color("#fde047") if is_ultimate else tint_color, 0.16)
			vfx.spawn_ember_burst(global_position, Color("#fde047") if is_ultimate else tint_color, 5 if is_ultimate else 2)

	for node in get_tree().get_nodes_in_group("fighters"):
		if node == owner_fighter or not (node is BaseFighter):
			continue
		var target := node as BaseFighter
		if target.is_ko:
			continue
		var tid: int = target.get_instance_id()
		if _hit_ids.has(tid):
			continue
		var target_center: Vector2 = target.global_position + Vector2(0.0, -48.0)
		if global_position.distance_to(target_center) <= hit_radius:
			_hit_ids[tid] = true
			target.take_damage(damage, knockback, owner_fighter, is_ultimate, BaseFighter.AttackPriority.SKILL)
			if not is_ultimate and charge_level < 3:
				queue_free()
				return

func reflect(new_owner: BaseFighter) -> void:
	if is_ultimate:
		return
	owner_fighter = new_owner
	velocity = -velocity * 1.25
	knockback.x = -knockback.x
	damage = int(round(float(damage) * 1.2))
	_elapsed = 0.0
	_hit_ids.clear()
	tint_color = Color("#fde047")
	if _sprite:
		_sprite.flip_h = velocity.x < 0.0
		_sprite.modulate = Color(1.9, 1.85, 0.95, 1.0)
