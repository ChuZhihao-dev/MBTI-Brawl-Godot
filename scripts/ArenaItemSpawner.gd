extends Node2D
class_name ArenaItemSpawner

@export var spawn_position: Vector2 = Vector2(900.0, 244.0)
@export var spawn_interval: float = 10.5

var _timer: float = 6.0
var _warning_timer: float = 0.0
var _next_kind: ArenaItem.Kind = ArenaItem.Kind.ENERGY_CRYSTAL

func _ready() -> void:
	z_index = 18

func _process(delta: float) -> void:
	# 场上已有道具时暂停计时，避免堆叠
	if not get_tree().get_nodes_in_group("arena_items").is_empty():
		_warning_timer = 0.0
		queue_redraw()
		return

	if _warning_timer > 0.0:
		_warning_timer -= delta
		if _warning_timer <= 0.0:
			_spawn_item()
		queue_redraw()
		return

	_timer -= delta
	if _timer <= 0.0:
		_timer = spawn_interval
		var roll: float = randf()
		if roll < 0.42:
			_next_kind = ArenaItem.Kind.ENERGY_CRYSTAL
		elif roll < 0.76:
			_next_kind = ArenaItem.Kind.HEAL_FRUIT
		else:
			_next_kind = ArenaItem.Kind.TIME_BOMB
		_warning_timer = 1.15
		AudioManager.play_sfx("charge_1", -6.0, 1.2)
		queue_redraw()

func _spawn_item() -> void:
	var item := ArenaItem.new()
	item.kind = _next_kind
	item.global_position = spawn_position
	get_parent().add_child(item)

func _draw() -> void:
	if _warning_timer <= 0.0:
		return
	var col := Color("#38bdf8") if _next_kind == ArenaItem.Kind.ENERGY_CRYSTAL else (Color("#4ade80") if _next_kind == ArenaItem.Kind.HEAL_FRUIT else Color("#f97316"))
	var t: float = 1.0 - (_warning_timer / 1.15)
	var beam_w: float = lerpf(42.0, 8.0, t)
	var alpha: float = sin(t * PI) * 0.55
	draw_rect(Rect2(spawn_position.x - beam_w * 0.5, 0.0, beam_w, spawn_position.y + 24.0), Color(col.r, col.g, col.b, alpha), true)
	draw_arc(spawn_position, lerpf(58.0, 16.0, t), 0.0, TAU, 28, Color(col.r, col.g, col.b, alpha * 1.4), 3.0, true)
