extends Control

var active_slot: int = 1
var _card_buttons: Dictionary = {}
var _cutout_shader: Shader = preload("res://shaders/cutout_white.gdshader")
var _spot_anims: Dictionary = {1: {}, 2: {}}
var _spot_rigs: Dictionary = {1: null, 2: null}
var _breath_elapsed: float = 0.0

@onready var p1_btn: Button = $TopTools/P1SlotBtn
@onready var p2_btn: Button = $TopTools/P2SlotBtn
@onready var random_btn: Button = $TopTools/RandomBtn
@onready var top_tools: HBoxContainer = $TopTools
var _mode_btn: Button
@onready var back_btn: Button = $BottomDock/Actions/BackBtn
@onready var start_fight_btn: Button = $BottomDock/Actions/StartFightBtn
@onready var p1_panel: PanelContainer = $P1Panel
@onready var p2_panel: PanelContainer = $P2Panel
@onready var p1_name: Label = $P1Panel/VBox/NameLabel
@onready var p1_title: Label = $P1Panel/VBox/TitleLabel
@onready var p1_stats: Label = $P1Panel/VBox/StatsLabel
@onready var p2_name: Label = $P2Panel/VBox/NameLabel
@onready var p2_title: Label = $P2Panel/VBox/TitleLabel
@onready var p2_stats: Label = $P2Panel/VBox/StatsLabel
@onready var p1_portrait: TextureRect = $P1Spotlight
@onready var p2_portrait: TextureRect = $P2Spotlight
@onready var roster_row: HBoxContainer = $BottomDock/RosterRow
@onready var stage_fx: Control = $StageFX

const FACTIONS: Array[Dictionary] = [
	{"id": "NT", "label": "NT 分析家", "color": Color("#7c3aed")},
	{"id": "NF", "label": "NF 外交家", "color": Color("#10b981")},
	{"id": "SJ", "label": "SJ 守护者", "color": Color("#3b82f6")},
	{"id": "SP", "label": "SP 探险家", "color": Color("#d97706")}
]

func _ready() -> void:
	var mat1 := ShaderMaterial.new()
	mat1.shader = _cutout_shader
	p1_portrait.material = mat1
	var mat2 := ShaderMaterial.new()
	mat2.shader = _cutout_shader
	p2_portrait.material = mat2

	UIStyle.style_secondary_btn(random_btn)
	UIStyle.style_secondary_btn(back_btn)
	UIStyle.style_primary_btn(start_fight_btn, true)

	_mode_btn = Button.new()
	_mode_btn.custom_minimum_size = Vector2(168, 42)
	_mode_btn.pressed.connect(_on_mode_toggle_pressed)
	top_tools.add_child(_mode_btn)
	_refresh_mode_btn()

	_build_faction_roster()
	_refresh_ui(0)

func _refresh_mode_btn() -> void:
	if _mode_btn == null:
		return
	if GameManager.battle_mode == "ai":
		var diff_s := "困难" if GameManager.ai_difficulty == "hard" else "普通"
		_mode_btn.text = "模式：AI（%s）" % diff_s
		UIStyle.style_secondary_btn(_mode_btn, Color("#059669") if GameManager.ai_difficulty == "normal" else Color("#d97706"))
	else:
		_mode_btn.text = "模式：双人 2P"
		UIStyle.style_secondary_btn(_mode_btn, Color("#1e293b"))

func _on_mode_toggle_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	if GameManager.battle_mode == "pvp":
		GameManager.battle_mode = "ai"
		GameManager.ai_difficulty = "normal"
	elif GameManager.ai_difficulty == "normal":
		GameManager.ai_difficulty = "hard"
	else:
		GameManager.battle_mode = "pvp"
	_refresh_mode_btn()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var kev := event as InputEventKey
		if kev.keycode == KEY_ENTER or kev.keycode == KEY_SPACE:
			_on_start_fight_pressed()

func _build_faction_roster() -> void:
	_card_buttons.clear()
	for child in roster_row.get_children():
		child.queue_free()

	for faction: Dictionary in FACTIONS:
		var group_box := VBoxContainer.new()
		group_box.add_theme_constant_override("separation", 6)

		var header_wrap := PanelContainer.new()
		var f_col: Color = faction["color"] as Color
		header_wrap.add_theme_stylebox_override("panel", UIStyle.make_box(f_col, Color(0, 0, 0, 0), 0, 6, 10, 3, 0.16, 4))
		header_wrap.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

		var header := Label.new()
		header.text = String(faction["label"])
		header.add_theme_color_override("font_color", Color("#ffffff"))
		header.add_theme_font_size_override("font_size", 14)
		header_wrap.add_child(header)
		group_box.add_child(header_wrap)

		var cards := HBoxContainer.new()
		cards.add_theme_constant_override("separation", 6)
		group_box.add_child(cards)

		for meta: Dictionary in GameManager.ROSTER:
			if String(meta["group"]) != String(faction["id"]):
				continue
			var fid: String = String(meta["id"])
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(78, 98)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.text = String(meta["name"])
			btn.icon = GameManager.get_portrait_texture(fid)
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			btn.expand_icon = true
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.pressed.connect(_on_fighter_picked.bind(fid))
			cards.add_child(btn)
			_card_buttons[fid] = {"btn": btn, "color": Color(String(meta["color"]))}

		roster_row.add_child(group_box)

func _on_fighter_picked(fid: String) -> void:
	AudioManager.play_sfx("ui_confirm", -5.0, 1.08)
	if active_slot == 1:
		GameManager.selected_p1 = fid
	else:
		GameManager.selected_p2 = fid
	_refresh_ui(active_slot)

func _play_slam_tween(node: Control) -> void:
	node.scale = Vector2(1.16, 1.16)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, 0.28)

func _setup_spotlight_visual(slot: int, portrait_rect: TextureRect, fid: String) -> void:
	# 若角色已升级为 2D 分层骨骼部件（rig/head.png），直接在选人聚光灯舞台展示 60fps 实时呼吸骨骼！
	var old_rig: FighterRig = _spot_rigs.get(slot, null) as FighterRig
	if is_instance_valid(old_rig):
		old_rig.queue_free()
		_spot_rigs[slot] = null

	var rig_dir: String = "res://assets/fighters/%s/rig" % fid
	if ResourceLoader.exists(rig_dir + "/head.png"):
		_spot_anims[slot] = {}
		portrait_rect.texture = null
		var preview_rig := FighterRig.new()
		preview_rig.rig_scale = 0.42
		preview_rig.position = Vector2(portrait_rect.size.x * 0.5, portrait_rect.size.y * 0.92)
		portrait_rect.add_child(preview_rig)
		var meta: Dictionary = GameManager.get_fighter_meta(fid)
		preview_rig.theme_color = Color(String(meta["color"]))
		preview_rig.load_parts(rig_dir)
		preview_rig.set_facing(1 if slot == 1 else -1)
		preview_rig.play_state("idle", true)
		_spot_rigs[slot] = preview_rig
		return

	# 优先加载选人专属精灵表 avatar_sheet.png，其次播放角色待机动画 idle_sheet，否则用 1024 高清立绘
	var avatar_sheet_path: String = "res://assets/fighters/%s/concept/avatar_sheet.png" % fid
	var sheet_cfg: Dictionary = {}
	if ResourceLoader.exists(avatar_sheet_path):
		sheet_cfg = {"path": avatar_sheet_path, "cols": 4, "rows": 4, "start": 0, "frames": 16, "fps": 16.0}
	else:
		var fighter_sheets: Dictionary = GameManager.get_sprite_config(fid)
		if fighter_sheets.has("idle"):
			sheet_cfg = fighter_sheets["idle"] as Dictionary

	if not sheet_cfg.is_empty() and ResourceLoader.exists(String(sheet_cfg["path"])):
		var tex: Texture2D = load(String(sheet_cfg["path"])) as Texture2D
		if tex:
			if portrait_rect.material is ShaderMaterial:
				var p_low: String = String(sheet_cfg["path"]).to_lower()
				(portrait_rect.material as ShaderMaterial).set_shader_parameter("enable_white_key", 1.0 if (p_low.ends_with(".jpg") or p_low.ends_with(".jpeg")) else 0.0)
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			var cols: int = int(sheet_cfg["cols"])
			var rows: int = int(sheet_cfg["rows"])
			var fw: float = tex.get_size().x / float(cols)
			var fh: float = tex.get_size().y / float(rows)
			atlas.region = Rect2(0.0, 0.0, fw, fh)
			portrait_rect.texture = atlas
			_spot_anims[slot] = {
				"atlas": atlas,
				"cols": cols,
				"fw": fw,
				"fh": fh,
				"start": int(sheet_cfg.get("start", 0)),
				"frames": int(sheet_cfg["frames"]),
				"fps": float(sheet_cfg["fps"]),
				"elapsed": 0.0
			}
			return

	_spot_anims[slot] = {}
	if portrait_rect.material is ShaderMaterial:
		(portrait_rect.material as ShaderMaterial).set_shader_parameter("enable_white_key", 0.0)
	portrait_rect.texture = GameManager.get_portrait_texture(fid)

func _process(delta: float) -> void:
	_breath_elapsed += delta
	var b_sy: float = 1.0 + sin(_breath_elapsed * 3.2) * 0.022
	var b_sx: float = 1.0 - sin(_breath_elapsed * 3.2) * 0.012
	p1_portrait.pivot_offset = Vector2(p1_portrait.size.x * 0.5, p1_portrait.size.y)
	p2_portrait.pivot_offset = Vector2(p2_portrait.size.x * 0.5, p2_portrait.size.y)
	if p1_portrait.scale.length() < 1.55:
		p1_portrait.scale = Vector2(b_sx, b_sy) if (_spot_anims.get(1, {}) as Dictionary).is_empty() else Vector2.ONE
	if p2_portrait.scale.length() < 1.55:
		p2_portrait.scale = Vector2(b_sx, b_sy) if (_spot_anims.get(2, {}) as Dictionary).is_empty() else Vector2.ONE

	for slot_key in [1, 2]:
		var pr: FighterRig = _spot_rigs.get(slot_key, null) as FighterRig
		if is_instance_valid(pr):
			var rect: TextureRect = p1_portrait if slot_key == 1 else p2_portrait
			pr.position = Vector2(rect.size.x * 0.5, rect.size.y * 0.90)
		var anim: Dictionary = _spot_anims.get(slot_key, {}) as Dictionary
		if anim.is_empty():
			continue
		anim["elapsed"] = float(anim["elapsed"]) + delta
		var idx: int = int(floor(float(anim["elapsed"]) * float(anim["fps"]))) % maxi(1, int(anim["frames"]))
		var real_idx: int = int(anim["start"]) + idx
		var cols: int = int(anim["cols"])
		var col: int = real_idx % cols
		var row: int = real_idx / cols
		var atlas: AtlasTexture = anim["atlas"] as AtlasTexture
		atlas.region = Rect2(float(col) * float(anim["fw"]), float(row) * float(anim["fh"]), float(anim["fw"]), float(anim["fh"]))

func _refresh_ui(animate_slot: int = 0) -> void:
	UIStyle.style_secondary_btn(p1_btn, Color("#0284c7") if active_slot == 1 else Color(0, 0, 0, 0))
	UIStyle.style_secondary_btn(p2_btn, Color("#e11d48") if active_slot == 2 else Color(0, 0, 0, 0))

	var m1: Dictionary = GameManager.get_fighter_meta(GameManager.selected_p1)
	var c1 := Color(String(m1["color"]))
	UIStyle.style_frosted_panel(p1_panel, c1 if active_slot == 1 else Color(0.12, 0.16, 0.23, 0.16), 3 if active_slot == 1 else 1)
	p1_name.text = "1P  %s" % String(m1["name"])
	p1_name.add_theme_color_override("font_color", c1)
	p1_title.text = String(m1["title"])
	p1_title.add_theme_color_override("font_color", Color("#334155"))
	p1_stats.text = "HP %d  ·  移速 %d  ·  跳跃 %d" % [int(m1["hp"]), int(m1["speed"]), int(m1["jump"])]
	p1_stats.add_theme_color_override("font_color", Color("#475569"))
	_setup_spotlight_visual(1, p1_portrait, GameManager.selected_p1)

	var m2: Dictionary = GameManager.get_fighter_meta(GameManager.selected_p2)
	var c2 := Color(String(m2["color"]))
	UIStyle.style_frosted_panel(p2_panel, c2 if active_slot == 2 else Color(0.12, 0.16, 0.23, 0.16), 3 if active_slot == 2 else 1)
	p2_name.text = "2P  %s" % String(m2["name"])
	p2_name.add_theme_color_override("font_color", c2)
	p2_title.text = String(m2["title"])
	p2_title.add_theme_color_override("font_color", Color("#334155"))
	p2_stats.text = "HP %d  ·  移速 %d  ·  跳跃 %d" % [int(m2["hp"]), int(m2["speed"]), int(m2["jump"])]
	p2_stats.add_theme_color_override("font_color", Color("#475569"))
	_setup_spotlight_visual(2, p2_portrait, GameManager.selected_p2)

	if stage_fx and stage_fx.has_method("set_colors"):
		stage_fx.call("set_colors", c1, c2)
		if animate_slot == 1:
			stage_fx.call("trigger_lock_burst", 1, c1)
			_play_slam_tween(p1_portrait)
		elif animate_slot == 2:
			stage_fx.call("trigger_lock_burst", 2, c2)
			_play_slam_tween(p2_portrait)

	for fid_key in _card_buttons.keys():
		var entry: Dictionary = _card_buttons[fid_key]
		var btn: Button = entry["btn"] as Button
		var card_col: Color = entry["color"] as Color
		var is_p1: bool = String(fid_key) == GameManager.selected_p1
		var is_p2: bool = String(fid_key) == GameManager.selected_p2
		var border_col: Color = Color("#0284c7") if is_p1 else (Color("#e11d48") if is_p2 else card_col.lerp(Color.WHITE, 0.45))
		var border_w: int = 3 if (is_p1 or is_p2) else 2
		var normal := UIStyle.make_box(Color(1.0, 1.0, 1.0, 0.94), border_col, border_w, 10, 4, 4, 0.14, 5)
		var hover := UIStyle.make_box(Color(1.0, 0.99, 0.95, 1.0), card_col, 3, 10, 4, 4, 0.24, 8)
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", hover)
		btn.add_theme_color_override("font_color", Color("#0f172a"))
		btn.add_theme_color_override("font_hover_color", card_col)

func _on_p1_slot_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	active_slot = 1
	_refresh_ui(0)

func _on_p2_slot_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	active_slot = 2
	_refresh_ui(0)

func _on_random_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	var pick: Dictionary = GameManager.ROSTER[randi() % GameManager.ROSTER.size()]
	_on_fighter_picked(String(pick["id"]))

func _on_back_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	get_tree().change_scene_to_file("res://scenes/Cover.tscn")

func _on_start_fight_pressed() -> void:
	AudioManager.play_sfx("ui_confirm")
	get_tree().change_scene_to_file("res://scenes/BattleStage.tscn")
