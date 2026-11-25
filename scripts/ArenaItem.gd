extends Node2D
class_name ArenaItem

enum Kind { ENERGY_CRYSTAL, HEAL_FRUIT, TIME_BOMB }

const ITEM_TEXTURES: Dictionary = {
	Kind.ENERGY_CRYSTAL: "res://assets/items/energy_crystal.png",
	Kind.HEAL_FRUIT: "res://assets/items/heal_fruit.png",
	Kind.TIME_BOMB: "res://assets/items/time_bomb.png"
}

var kind: Kind = Kind.ENERGY_CRYSTAL
var _elapsed: float = 0.0
var _bomb_fuse: float = 3.8
var _consumed: bool = false
var _sprite: Sprite2D
var _base_scale: float = 1.0

func _ready() -> void:
	z_index = 22
	add_to_group("arena_items")
	_setup_sprite()
	var vfx := BattleVFX.get_current(get_tree())
	if vfx:
		vfx.spawn_shockwave_ring(global_position, _get_color(), 10.0, 76.0, 0.30, 4.0)

func _setup_sprite() -> void:
	var path: String = String(ITEM_TEXTURES.get(kind, ""))
	if path == "" or not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	var target_h: float = 58.0 if kind == Kind.ENERGY_CRYSTAL else 54.0
	_base_scale = target_h / maxf(1.0, tex.get_size().y)
	_sprite.scale = Vector2(_base_scale, _base_scale)
	add_child(_sprite)

func _get_color() -> Color:
	match kind:
		Kind.ENERGY_CRYSTAL:
			return Color("#38bdf8")
		Kind.HEAL_FRUIT:
			return Color("#4ade80")
		Kind.TIME_BOMB:
			return Color("#f97316")
	return Color.WHITE

func _physics_process(delta: float) -> void:
	if _consumed:
		return
	_elapsed += delta

	if kind == Kind.TIME_BOMB:
		_bomb_fuse -= delta
		if _bomb_fuse <= 0.0:
			_explode_bomb()
			return
	elif _elapsed >= 13.0:
		queue_free()
		return

	if _sprite:
		var bob: float = sin(_elapsed * 4.5) * 6.0
		_sprite.position.y = bob
		if kind == Kind.TIME_BOMB:
			var flash_spd: float = 18.0 if _bomb_fuse < 1.4 else 7.5
			var pulse: float = 0.5 + 0.5 * sin(_elapsed * flash_spd)
			var sc: float = _base_scale * (1.0 + pulse * (0.14 if _bomb_fuse < 1.4 else 0.06))
			_sprite.scale = Vector2(sc, sc)
			_sprite.modulate = Color(1.0, 0.45, 0.35, 1.0) if (pulse > 0.65 and _bomb_fuse < 1.6) else Color.WHITE
		else:
			var sc2: float = _base_scale * (1.0 + sin(_elapsed * 3.8) * 0.04)
			_sprite.scale = Vector2(sc2, sc2)

	for node in get_tree().get_nodes_in_group("fighters"):
		if not (node is BaseFighter):
			continue
		var f := node as BaseFighter
		if f.is_ko or f.battle_locked:
			continue
		var center: Vector2 = f.global_position + Vector2(0.0, -48.0)
		if global_position.distance_to(center) <= 52.0:
			if kind == Kind.TIME_BOMB:
				if _elapsed >= 0.45:
					_explode_bomb()
			else:
				_pickup(f)
			return
	queue_redraw()

func _pickup(f: BaseFighter) -> void:
	_consumed = true
	GameManager.record_stat(f.player_index, "items", 1)
	AudioManager.play_sfx("item_pickup", -2.5)
	var vfx := BattleVFX.get_current(get_tree())
	if kind == Kind.ENERGY_CRYSTAL:
		f.ep = minf(100.0, f.ep + 45.0)
		if vfx:
			vfx.spawn_shockwave_ring(global_position, Color("#38bdf8"), 12.0, 110.0, 0.28, 5.0)
			vfx.spawn_hit_particles(global_position, Color("#7dd3fc"), 18, 280.0)
			vfx.spawn_floating_text(f.global_position + Vector2(0.0, -112.0), "能量水晶 +45 EP!", Color("#38bdf8"), 1.12)
	elif kind == Kind.HEAL_FRUIT:
		f.hp = mini(f.max_hp, f.hp + 25)
		if vfx:
			vfx.spawn_shockwave_ring(global_position, Color("#4ade80"), 12.0, 110.0, 0.28, 5.0)
			vfx.spawn_hit_particles(global_position, Color("#86efac"), 18, 260.0)
			vfx.spawn_floating_text(f.global_position + Vector2(0.0, -112.0), "生命圣果 +25 HP!", Color("#4ade80"), 1.12)
	queue_free()

func _explode_bomb() -> void:
	_consumed = true
	AudioManager.play_sfx("bomb_explode", -1.0)
	GameManager.trigger_shake(14.0, 0.28, Vector2(0.0, -1.0))
	var vfx := BattleVFX.get_current(get_tree())
	if vfx:
		vfx.trigger_screen_flash(Color("#fb923c"), 0.28, 0.20)
		vfx.spawn_shockwave_ring(global_position, Color("#f97316"), 16.0, 195.0, 0.34, 8.0)
		vfx.spawn_shockwave_ring(global_position, Color("#fde047"), 10.0, 140.0, 0.26, 6.0)
		vfx.spawn_hit_particles(global_position, Color("#fb923c"), 32, 480.0)
	for node in get_tree().get_nodes_in_group("fighters"):
		if not (node is BaseFighter):
			continue
		var f := node as BaseFighter
		if f.is_ko:
			continue
		var center: Vector2 = f.global_position + Vector2(0.0, -48.0)
		if global_position.distance_to(center) <= 175.0:
			var push_x: float = signf(f.global_position.x - global_position.x)
			if push_x == 0.0:
				push_x = 1.0
			f.take_damage(22, Vector2(push_x * 480.0, -340.0), null, false)
			if vfx:
				vfx.spawn_floating_text(f.global_position + Vector2(0.0, -118.0), "定时炸弹 BOOM!", Color("#fb923c"), 1.2)
	queue_free()

func _draw() -> void:
	var bob: float = sin(_elapsed * 4.5) * 6.0
	var pos := Vector2(0.0, bob)
	var col := _get_color()
	# 柔和外围脉冲光环（烘托道具可拾取/危险高亮感）
	var ring_a: float = 0.72 if (kind == Kind.TIME_BOMB and _bomb_fuse < 1.4) else 0.45
	draw_arc(pos, 32.0 + sin(_elapsed * 6.0) * 3.0, 0.0, TAU, 28, Color(col.r, col.g, col.b, ring_a), 2.5, true)
	if _sprite == null:
		draw_circle(pos, 14.0, col)
