extends Node2D
class_name ArenaItem

enum Kind { ENERGY_CRYSTAL, HEAL_FRUIT, TIME_BOMB }

var kind: Kind = Kind.ENERGY_CRYSTAL
var _elapsed: float = 0.0
var _bomb_fuse: float = 3.8
var _consumed: bool = false

func _ready() -> void:
	z_index = 22
	add_to_group("arena_items")
	var vfx := BattleVFX.get_current(get_tree())
	if vfx:
		var col := _get_color()
		vfx.spawn_shockwave_ring(global_position, col, 10.0, 76.0, 0.30, 4.0)

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
	# 外圈柔光环
	draw_arc(pos, 26.0 + sin(_elapsed * 6.0) * 3.0, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.65), 3.0, true)

	match kind:
		Kind.ENERGY_CRYSTAL:
			# 菱形能量水晶
			var pts := PackedVector2Array([
				pos + Vector2(0.0, -20.0),
				pos + Vector2(14.0, 0.0),
				pos + Vector2(0.0, 20.0),
				pos + Vector2(-14.0, 0.0)
			])
			draw_colored_polygon(pts, Color("#38bdf8"))
			draw_colored_polygon(PackedVector2Array([pos + Vector2(0.0, -14.0), pos + Vector2(7.0, 0.0), pos + Vector2(0.0, 12.0), pos + Vector2(-5.0, 0.0)]), Color("#e0f2fe"))
		Kind.HEAL_FRUIT:
			# 翡翠生命圣果 + 叶片
			draw_circle(pos + Vector2(0.0, 2.0), 15.0, Color("#22c55e"))
			draw_circle(pos + Vector2(-4.0, -2.0), 6.0, Color("#bbf7d0"))
			draw_colored_polygon(PackedVector2Array([pos + Vector2(0.0, -12.0), pos + Vector2(12.0, -22.0), pos + Vector2(4.0, -10.0)]), Color("#86efac"))
		Kind.TIME_BOMB:
			# 闪烁定时炸弹
			var flash_spd: float = 16.0 if _bomb_fuse < 1.3 else 7.0
			var blink: bool = sin(_elapsed * flash_spd) > 0.0
			draw_circle(pos + Vector2(0.0, 2.0), 16.0, Color("#ef4444") if blink else Color("#1e293b"))
			draw_arc(pos + Vector2(0.0, 2.0), 16.0, 0.0, TAU, 20, Color("#fde047"), 2.5, true)
			draw_line(pos + Vector2(0.0, -14.0), pos + Vector2(8.0, -24.0), Color("#fbbf24"), 3.0)
			draw_circle(pos + Vector2(9.0, -25.0), 4.5, Color("#fef08a") if blink else Color("#f97316"))
