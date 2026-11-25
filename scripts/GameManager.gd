extends Node

const SETTINGS_PATH: String = "user://settings.cfg"

var selected_p1: String = "enfj"
var selected_p2: String = "infj"
var battle_mode: String = "pvp" # "pvp" 或 "ai"
var ai_difficulty: String = "normal" # "normal" 或 "hard"
var hitstop_timer: float = 0.0
var is_pause_menu_open: bool = false

# BO3 三局两胜制与局末 MVP 统计
var rounds_to_win: int = 2
var p1_rounds: int = 0
var p2_rounds: int = 0
var current_round: int = 1
var match_stats: Dictionary = {}

signal camera_shake_requested(intensity: float, duration: float, dir: Vector2)
signal keybindings_changed()
signal combo_updated(attacker_index: int, combo_count: int, total_damage: int)

const ACTION_META: Array[Dictionary] = [
	{"suffix": "left", "label": "向左移动"},
	{"suffix": "right", "label": "向右移动"},
	{"suffix": "up", "label": "跳跃 / 向上派生"},
	{"suffix": "guard", "label": "防御 / 向下派生"},
	{"suffix": "light", "label": "轻击"},
	{"suffix": "heavy", "label": "重击"},
	{"suffix": "dash", "label": "冲刺 / 闪避"},
	{"suffix": "skill1", "label": "技能 1（蓄力）"},
	{"suffix": "skill2", "label": "技能 2（蓄力）"},
	{"suffix": "ult", "label": "必杀大招（满能）"}
]

const DEFAULT_KEYS: Dictionary = {
	"p1_left": [KEY_A],
	"p1_right": [KEY_D],
	"p1_up": [KEY_W],
	"p1_guard": [KEY_S],
	"p1_light": [KEY_J],
	"p1_heavy": [KEY_K],
	"p1_dash": [KEY_L],
	"p1_skill1": [KEY_U],
	"p1_skill2": [KEY_I],
	"p1_ult": [KEY_O],
	"p2_left": [KEY_LEFT],
	"p2_right": [KEY_RIGHT],
	"p2_up": [KEY_UP],
	"p2_guard": [KEY_DOWN],
	"p2_light": [KEY_1, KEY_KP_1],
	"p2_heavy": [KEY_2, KEY_KP_2],
	"p2_dash": [KEY_3, KEY_KP_3],
	"p2_skill1": [KEY_4, KEY_KP_4],
	"p2_skill2": [KEY_5, KEY_KP_5],
	"p2_ult": [KEY_6, KEY_KP_6]
}

const ROSTER: Array[Dictionary] = [
	{"id": "intj", "name": "INTJ", "title": "建筑师 · 紫老头", "group": "NT", "color": "#7c3aed", "hp": 120, "speed": 280.0, "jump": 600.0},
	{"id": "intp", "name": "INTP", "title": "逻辑学家", "group": "NT", "color": "#8b5cf6", "hp": 100, "speed": 310.0, "jump": 630.0},
	{"id": "entj", "name": "ENTJ", "title": "指挥官", "group": "NT", "color": "#6d28d9", "hp": 125, "speed": 300.0, "jump": 610.0},
	{"id": "entp", "name": "ENTP", "title": "辩论家", "group": "NT", "color": "#a855f7", "hp": 100, "speed": 340.0, "jump": 660.0},
	{"id": "infj", "name": "INFJ", "title": "提倡者 · 绿老头", "group": "NF", "color": "#10b981", "hp": 105, "speed": 310.0, "jump": 640.0},
	{"id": "infp", "name": "INFP", "title": "调停者", "group": "NF", "color": "#34d399", "hp": 95, "speed": 315.0, "jump": 650.0},
	{"id": "enfj", "name": "ENFJ", "title": "主人公 · 耀光剑士", "group": "NF", "color": "#059669", "hp": 110, "speed": 330.0, "jump": 645.0},
	{"id": "enfp", "name": "ENFP", "title": "竞选者 · 快乐小狗", "group": "NF", "color": "#22c55e", "hp": 95, "speed": 355.0, "jump": 680.0},
	{"id": "istj", "name": "ISTJ", "title": "物流师", "group": "SJ", "color": "#2563eb", "hp": 130, "speed": 270.0, "jump": 585.0},
	{"id": "isfj", "name": "ISFJ", "title": "守卫者", "group": "SJ", "color": "#3b82f6", "hp": 125, "speed": 285.0, "jump": 600.0},
	{"id": "estj", "name": "ESTJ", "title": "总经理", "group": "SJ", "color": "#1d4ed8", "hp": 120, "speed": 295.0, "jump": 610.0},
	{"id": "esfj", "name": "ESFJ", "title": "执政官", "group": "SJ", "color": "#0ea5e9", "hp": 115, "speed": 305.0, "jump": 620.0},
	{"id": "istp", "name": "ISTP", "title": "鉴赏家", "group": "SP", "color": "#d97706", "hp": 100, "speed": 345.0, "jump": 665.0},
	{"id": "isfp", "name": "ISFP", "title": "探险家 · 随性画师", "group": "SP", "color": "#f59e0b", "hp": 95, "speed": 340.0, "jump": 660.0},
	{"id": "estp", "name": "ESTP", "title": "企业家", "group": "SP", "color": "#eab308", "hp": 105, "speed": 350.0, "jump": 670.0},
	{"id": "esfp", "name": "ESFP", "title": "表演者", "group": "SP", "color": "#f97316", "hp": 95, "speed": 345.0, "jump": 675.0}
]

const FIGHTER_SCENES: Dictionary = {
	"enfj": "res://scenes/ENFJ.tscn",
	"isfp": "res://scenes/ISFP.tscn",
	"infj": "res://scenes/INFJ.tscn"
}

# 已有精灵表角色的切帧配置（后续新增角色或导出 avatar_sheet.png 只需在此登记即可自动生效）
const SPRITE_SHEETS: Dictionary = {
	"enfj": {
		"idle": {"path": "res://assets/fighters/enfj/frames/reduced_v2/idle_sheet.png", "cols": 4, "rows": 1, "start": 0, "frames": 4, "fps": 6.0, "loop": true},
		"walk": {"path": "res://assets/fighters/enfj/frames/reduced_v2/walk_sheet.png", "cols": 4, "rows": 1, "start": 0, "frames": 4, "fps": 12.0, "loop": true},
		"jump_startup": {"path": "res://assets/fighters/enfj/frames/reduced_v2/jump_startup_sheet.png", "cols": 4, "rows": 1, "start": 0, "frames": 4, "fps": 12.0, "loop": false},
		"jump": {"path": "res://assets/fighters/enfj/frames/reduced_v2/jump_air_sheet.png", "cols": 6, "rows": 1, "start": 0, "frames": 6, "fps": 12.0, "loop": false},
		"landing": {"path": "res://assets/fighters/enfj/frames/reduced_v2/landing_sheet.png", "cols": 4, "rows": 1, "start": 0, "frames": 4, "fps": 12.0, "loop": false},
		"dash": {"path": "res://assets/fighters/enfj/frames/reduced_v2/dash_sheet.png", "cols": 6, "rows": 1, "start": 0, "frames": 6, "fps": 20.0, "loop": false},
		"guard": {"path": "res://assets/fighters/enfj/frames/reduced_v2/guard_sheet.png", "cols": 4, "rows": 1, "start": 0, "frames": 4, "fps": 6.0, "loop": true},
		"block_hit": {"path": "res://assets/fighters/enfj/frames/reduced_v2/block_hit_sheet.png", "cols": 4, "rows": 1, "start": 0, "frames": 4, "fps": 15.0, "loop": false},
		"light": {"path": "res://assets/fighters/enfj/frames/reduced_v2/keyframes/light_attack_1_sheet.png", "cols": 4, "rows": 1, "start": 0, "frames": 4, "fps": 16.0, "loop": false},
		"light_1": {"path": "res://assets/fighters/enfj/frames/reduced_v2/keyframes/light_attack_1_sheet.png", "cols": 4, "rows": 1, "start": 0, "frames": 4, "fps": 18.0, "loop": false},
		"light_2": {"path": "res://assets/fighters/enfj/frames/reduced_v2/keyframes/light_attack_2_sheet.png", "cols": 4, "rows": 1, "start": 0, "frames": 4, "fps": 17.0, "loop": false},
		"light_3": {"path": "res://assets/fighters/enfj/frames/reduced_v2/keyframes/light_attack_3_sheet.png", "cols": 4, "rows": 1, "start": 0, "frames": 4, "fps": 16.0, "loop": false},
		"light_4": {"path": "res://assets/fighters/enfj/frames/reduced_v2/keyframes/light_attack_4_sheet.png", "cols": 4, "rows": 1, "start": 0, "frames": 4, "fps": 15.0, "loop": false},
		"light_5": {"path": "res://assets/fighters/enfj/frames/reduced_v2/keyframes/light_attack_5_sheet.png", "cols": 4, "rows": 1, "start": 0, "frames": 4, "fps": 14.0, "loop": false},
		"heavy": {"path": "res://assets/fighters/enfj/frames/reduced_v2/keyframes/heavy_attack_1_sheet.png", "cols": 5, "rows": 1, "start": 0, "frames": 5, "fps": 14.0, "loop": false},
		"heavy_1": {"path": "res://assets/fighters/enfj/frames/reduced_v2/keyframes/heavy_attack_1_sheet.png", "cols": 5, "rows": 1, "start": 0, "frames": 5, "fps": 14.0, "loop": false},
		"heavy_2": {"path": "res://assets/fighters/enfj/frames/reduced_v2/keyframes/heavy_attack_2_sheet.png", "cols": 5, "rows": 1, "start": 0, "frames": 5, "fps": 13.0, "loop": false},
		"heavy_3": {"path": "res://assets/fighters/enfj/frames/reduced_v2/keyframes/heavy_attack_3_sheet.png", "cols": 5, "rows": 1, "start": 0, "frames": 5, "fps": 12.0, "loop": false},
		"skill": {"path": "res://assets/fighters/enfj/frames/reduced_v2/triple_sword_wave_sheet.png", "cols": 10, "rows": 1, "start": 0, "frames": 10, "fps": 17.0, "loop": false},
		"skill1_charge": {"path": "res://assets/fighters/enfj/frames/reduced_v2/skill1_charge_sheet.png", "cols": 3, "rows": 2, "start": 0, "frames": 6, "fps": 12.0, "loop": true, "loop_start": 2},
		"skill2_charge": {"path": "res://assets/fighters/enfj/frames/reduced_v2/skill2_charge_sheet.png", "cols": 3, "rows": 2, "start": 0, "frames": 6, "fps": 12.0, "loop": true, "loop_start": 2},
		"triple_wave": {"path": "res://assets/fighters/enfj/frames/reduced_v2/triple_sword_wave_sheet.png", "cols": 10, "rows": 1, "start": 0, "frames": 10, "fps": 17.0, "loop": false},
		"aura_buff": {"path": "res://assets/fighters/enfj/frames/reduced_v2/aura_buff_sheet.png", "cols": 8, "rows": 1, "start": 0, "frames": 8, "fps": 20.0, "loop": false},
		"ultimate": {"path": "res://assets/fighters/enfj/frames/reduced_v2/ultimate_clean_sheet.png", "cols": 10, "rows": 1, "start": 0, "frames": 10, "fps": 14.0, "loop": false},
		"ko": {"path": "res://assets/fighters/enfj/frames/reduced_v2/ko_kneeling_sword_sheet.png", "cols": 8, "rows": 1, "start": 0, "frames": 8, "fps": 12.0, "loop": false}
	},
	"isfp": {
		"idle": {"path": "res://assets/fighters/isfp/frames/idle_sheet.png", "cols": 4, "rows": 1, "start": 0, "frames": 4, "fps": 6.0, "loop": true},
		"walk": {"path": "res://assets/fighters/isfp/frames/walk_sheet.png", "cols": 4, "rows": 1, "start": 0, "frames": 4, "fps": 11.0, "loop": true},
		"jump": {"path": "res://assets/fighters/isfp/frames/jump_sheet.png", "cols": 4, "rows": 1, "start": 0, "frames": 4, "fps": 9.0, "loop": false},
		"light": {"path": "res://assets/fighters/isfp/frames/attack_sheet.png", "cols": 4, "rows": 1, "start": 0, "frames": 4, "fps": 16.0, "loop": false},
		"heavy": {"path": "res://assets/fighters/isfp/frames/attack_sheet.png", "cols": 4, "rows": 1, "start": 0, "frames": 4, "fps": 12.0, "loop": false},
		"hit": {"path": "res://assets/fighters/isfp/frames/hit_sheet.png", "cols": 2, "rows": 1, "start": 0, "frames": 2, "fps": 10.0, "loop": false}
	},
	"infj": {
		"idle": {"path": "res://assets/fighters/infj/frames/v2/idle_sheet.png", "cols": 8, "rows": 1, "start": 0, "frames": 8, "fps": 6.0, "loop": true},
		"walk": {"path": "res://assets/fighters/infj/frames/walk_sheet.png", "cols": 4, "rows": 1, "start": 0, "frames": 4, "fps": 11.0, "loop": true},
		"jump": {"path": "res://assets/fighters/infj/frames/jump_sheet.png", "cols": 4, "rows": 1, "start": 0, "frames": 4, "fps": 9.0, "loop": false},
		"light": {"path": "res://assets/fighters/infj/frames/attack_sheet.png", "cols": 4, "rows": 1, "start": 0, "frames": 4, "fps": 15.0, "loop": false},
		"heavy": {"path": "res://assets/fighters/infj/frames/skill_sheet.png", "cols": 4, "rows": 1, "start": 0, "frames": 4, "fps": 12.0, "loop": false},
		"skill": {"path": "res://assets/fighters/infj/frames/skill_sheet.png", "cols": 4, "rows": 1, "start": 0, "frames": 4, "fps": 12.0, "loop": false},
		"hit": {"path": "res://assets/fighters/infj/frames/hit_sheet.png", "cols": 2, "rows": 1, "start": 0, "frames": 2, "fps": 10.0, "loop": false}
	}
}

func get_fighter_meta(id: String) -> Dictionary:
	for item: Dictionary in ROSTER:
		if String(item["id"]) == id:
			return item
	return ROSTER[0]

func get_fighter_scene(id: String) -> PackedScene:
	var scene_path: String = String(FIGHTER_SCENES.get(id, "res://scenes/BaseFighter.tscn"))
	if ResourceLoader.exists(scene_path):
		return load(scene_path) as PackedScene
	return load("res://scenes/BaseFighter.tscn") as PackedScene

func get_portrait_texture(id: String) -> Texture2D:
	var path: String = "res://assets/fighters/%s/concept/portrait.png" % id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func get_sprite_config(id: String) -> Dictionary:
	if SPRITE_SHEETS.has(id):
		return SPRITE_SHEETS[id] as Dictionary
	return {}

func trigger_hitstop(seconds: float) -> void:
	hitstop_timer = maxf(hitstop_timer, seconds)
	get_tree().paused = true

func trigger_shake(intensity: float, duration: float = 0.16, dir: Vector2 = Vector2.ZERO) -> void:
	camera_shake_requested.emit(intensity, duration, dir)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_match_state()
	load_keybindings()

func reset_match_state() -> void:
	p1_rounds = 0
	p2_rounds = 0
	current_round = 1
	match_stats = {
		1: {"damage": 0, "max_combo": 0, "parries": 0, "items": 0},
		2: {"damage": 0, "max_combo": 0, "parries": 0, "items": 0}
	}

func record_stat(player_idx: int, key: String, val: int) -> void:
	if not match_stats.has(player_idx):
		match_stats[player_idx] = {"damage": 0, "max_combo": 0, "parries": 0, "items": 0}
	var bucket: Dictionary = match_stats[player_idx] as Dictionary
	if key == "max_combo":
		bucket[key] = maxi(int(bucket.get(key, 0)), val)
	else:
		bucket[key] = int(bucket.get(key, 0)) + val

func _process(delta: float) -> void:
	if hitstop_timer > 0.0:
		hitstop_timer -= delta
		if hitstop_timer <= 0.0:
			hitstop_timer = 0.0
			if not is_pause_menu_open:
				get_tree().paused = false

func load_keybindings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	if not cfg.has_section("keybindings"):
		return
	for action_name: String in DEFAULT_KEYS.keys():
		if not InputMap.has_action(action_name):
			continue
		if cfg.has_section_key("keybindings", action_name):
			var codes: Variant = cfg.get_value("keybindings", action_name)
			if codes is Array and not (codes as Array).is_empty():
				InputMap.action_erase_events(action_name)
				for kc in (codes as Array):
					var ev := InputEventKey.new()
					ev.physical_keycode = int(kc)
					InputMap.action_add_event(action_name, ev)

func save_keybindings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	for action_name: String in DEFAULT_KEYS.keys():
		if not InputMap.has_action(action_name):
			continue
		var codes: Array[int] = []
		for ev in InputMap.action_get_events(action_name):
			if ev is InputEventKey:
				var kev := ev as InputEventKey
				var code: int = int(kev.physical_keycode) if kev.physical_keycode != 0 else int(kev.keycode)
				if code != 0 and not codes.has(code):
					codes.append(code)
		cfg.set_value("keybindings", action_name, codes)
	cfg.save(SETTINGS_PATH)

func rebind_action(action_name: String, physical_keycode: int) -> void:
	if not InputMap.has_action(action_name):
		return
	InputMap.action_erase_events(action_name)
	var ev := InputEventKey.new()
	ev.physical_keycode = physical_keycode
	InputMap.action_add_event(action_name, ev)
	save_keybindings()
	keybindings_changed.emit()

func reset_default_keybindings() -> void:
	for action_name: String in DEFAULT_KEYS.keys():
		if not InputMap.has_action(action_name):
			continue
		InputMap.action_erase_events(action_name)
		var defaults: Array = DEFAULT_KEYS[action_name] as Array
		for kc in defaults:
			var ev := InputEventKey.new()
			ev.physical_keycode = int(kc)
			InputMap.action_add_event(action_name, ev)
	save_keybindings()
	keybindings_changed.emit()

func get_action_key_label(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "-"
	var events := InputMap.action_get_events(action_name)
	if events.is_empty():
		return "未绑定"
	for ev in events:
		if ev is InputEventKey:
			var kev := ev as InputEventKey
			var code: Key = kev.physical_keycode if kev.physical_keycode != 0 else kev.keycode
			return OS.get_keycode_string(code)
	return "-"
