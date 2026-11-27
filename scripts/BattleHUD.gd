extends CanvasLayer

@export var p1_path: NodePath
@export var p2_path: NodePath

@onready var top_bar: HBoxContainer = $TopBar
@onready var p1_box: VBoxContainer = $TopBar/P1Box
@onready var p2_box: VBoxContainer = $TopBar/P2Box
@onready var p1_bar: ProgressBar = $TopBar/P1Box/P1HP
@onready var p2_bar: ProgressBar = $TopBar/P2Box/P2HP
@onready var p1_label: Label = $TopBar/P1Box/P1Label
@onready var p2_label: Label = $TopBar/P2Box/P2Label
@onready var back_btn: Button = $TopBar/BackBtn

var _p1: BaseFighter
var _p2: BaseFighter
var _p1_ep_bar: ProgressBar
var _p2_ep_bar: ProgressBar
var _p1_shield_bar: ProgressBar
var _p2_shield_bar: ProgressBar
var _p1_ep_lbl: Label
var _p2_ep_lbl: Label
var _p1_status_lbl: Label
var _p2_status_lbl: Label
var _p1_trail_val: float = 100.0
var _p2_trail_val: float = 100.0
var _p1_trail_bar: ProgressBar
var _p2_trail_bar: ProgressBar
var _p1_combo_lbl: Label
var _p2_combo_lbl: Label
var practice_panel

signal practice_cooldowns_toggled(enabled: bool)
signal practice_combat_toggled(enabled: bool)

var _p1_rounds_lbl: Label
var _p2_rounds_lbl: Label
var _timer_lbl: Label
var _mute_btn: Button
var _bgm_btn: Button
var _hint_lbl: Label

var _pause_overlay: Control
var _pause_mute_btn: Button
var _pause_bgm_btn: Button
var _ko_overlay: Control
var _ko_badge_lbl: Label
var _ko_winner_lbl: Label
var _ko_stats_lbl: Label
var _ko_portrait: TextureRect

var _rebind_action: String = ""
var _rebind_buttons: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_p1 = get_node_or_null(p1_path) as BaseFighter
	_p2 = get_node_or_null(p2_path) as BaseFighter

	UIStyle.style_hp_bar(p1_bar, Color("#16a34a"))
	UIStyle.style_hp_bar(p2_bar, Color("#16a34a"))
	UIStyle.style_secondary_btn(back_btn)

	_build_hud_extensions()
	_build_pause_panel()
	_build_ko_panel()
	if GameManager.battle_mode == "practice":
		practice_panel = preload("res://scripts/PracticePanel.gd").new()
		add_child(practice_panel)
	_refresh_key_hints()
	AudioManager.mute_changed.connect(_on_mute_changed)
	AudioManager.bgm_mute_changed.connect(_on_bgm_mute_changed)
	GameManager.keybindings_changed.connect(_refresh_key_hints)
	GameManager.combo_updated.connect(_on_combo_updated)

func bind_fighters(p1: BaseFighter, p2: BaseFighter) -> void:
	_p1 = p1
	_p2 = p2
	if practice_panel != null:
		practice_panel.bind_fighters(p1, p2)
	if _p1:
		_p1_trail_val = float(_p1.hp)
	if _p2:
		_p2_trail_val = float(_p2.hp)

func play_round_intro(on_fight: Callable, round_title: String = "READY...") -> void:
	var banner := Label.new()
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.offset_left = -420.0
	banner.offset_right = 420.0
	banner.offset_top = -90.0
	banner.offset_bottom = 90.0
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.text = round_title
	banner.add_theme_font_size_override("font_size", 86)
	banner.add_theme_color_override("font_color", Color("#fef08a"))
	banner.add_theme_color_override("font_outline_color", Color("#0f172a"))
	banner.add_theme_constant_override("outline_size", 14)
	banner.pivot_offset = Vector2(420.0, 90.0)
	banner.scale = Vector2(0.5, 0.5)
	add_child(banner)

	AudioManager.play_sfx("round_ready", -2.0)
	var tw := create_tween()
	tw.tween_property(banner, "scale", Vector2(1.08, 1.08), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.58)
	tw.tween_callback(func() -> void:
		if is_instance_valid(banner):
			banner.text = "FIGHT!!"
			banner.add_theme_color_override("font_color", Color("#4ade80"))
			banner.scale = Vector2(1.55, 1.55)
		AudioManager.play_sfx("round_fight", -1.5)
		if on_fight.is_valid():
			on_fight.call()
	)
	tw.tween_property(banner, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_property(banner, "modulate:a", 0.0, 0.25)
	tw.tween_callback(banner.queue_free)

func show_round_banner(title_text: String, accent: Color) -> void:
	var banner := Label.new()
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.offset_left = -460.0
	banner.offset_right = 460.0
	banner.offset_top = -80.0
	banner.offset_bottom = 80.0
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.text = title_text
	banner.add_theme_font_size_override("font_size", 68)
	banner.add_theme_color_override("font_color", accent.lightened(0.25))
	banner.add_theme_color_override("font_outline_color", Color("#0f172a"))
	banner.add_theme_constant_override("outline_size", 12)
	banner.pivot_offset = Vector2(460.0, 80.0)
	banner.scale = Vector2(0.6, 0.6)
	add_child(banner)

	var tw := create_tween()
	tw.tween_property(banner, "scale", Vector2(1.05, 1.05), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.05)
	tw.tween_property(banner, "modulate:a", 0.0, 0.30)
	tw.tween_callback(banner.queue_free)

func set_round_scores(p1_wins: int, p2_wins: int) -> void:
	var total: int = GameManager.rounds_to_win
	if _p1_rounds_lbl:
		var s1 := ""
		for i in range(total):
			s1 += "● " if i < p1_wins else "○ "
		_p1_rounds_lbl.text = s1.strip_edges()
	if _p2_rounds_lbl:
		var s2 := ""
		for i in range(total):
			s2 += "● " if i < p2_wins else "○ "
		_p2_rounds_lbl.text = s2.strip_edges()

func _on_combo_updated(attacker_idx: int, combo_count: int, total_dmg: int) -> void:
	var lbl: Label = _p1_combo_lbl if attacker_idx == 1 else _p2_combo_lbl
	if lbl == null:
		return
	if combo_count < 2:
		lbl.visible = false
		return
	lbl.visible = true
	var suffix := " SUPER!!" if combo_count >= 5 else ("!" if combo_count >= 3 else "")
	lbl.text = "%d HITS%s  ·  %d DMG" % [combo_count, suffix, total_dmg]
	lbl.add_theme_color_override("font_color", Color("#fde047") if combo_count >= 4 else Color("#38bdf8"))
	lbl.scale = Vector2(1.32, 1.32)
	var tw := create_tween()
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func set_timer_value(sec: int) -> void:
	if _timer_lbl:
		_timer_lbl.text = "%02d" % maxi(0, sec)
		_timer_lbl.add_theme_color_override("font_color", Color("#ef4444") if sec <= 15 else Color("#0f172a"))

func _build_hud_extensions() -> void:
	# 延迟扣血黄条（叠加在血条底层）
	_p1_trail_bar = ProgressBar.new()
	_p1_trail_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_p1_trail_bar.show_percentage = false
	_p1_trail_bar.z_index = -1
	UIStyle.style_hp_bar(_p1_trail_bar, Color("#facc15"))
	p1_bar.add_child(_p1_trail_bar)

	_p2_trail_bar = ProgressBar.new()
	_p2_trail_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_p2_trail_bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	_p2_trail_bar.show_percentage = false
	_p2_trail_bar.z_index = -1
	UIStyle.style_hp_bar(_p2_trail_bar, Color("#facc15"))
	p2_bar.add_child(_p2_trail_bar)

	# 1P / 2P 能量条（EP）、护盾耐久条（Shield）与技能冷却/Buff 状态条
	_p1_ep_bar = ProgressBar.new()
	_p1_ep_bar.custom_minimum_size = Vector2(0, 11)
	_p1_ep_bar.max_value = 100.0
	_p1_ep_bar.show_percentage = false
	UIStyle.style_hp_bar(_p1_ep_bar, Color("#0ea5e9"))
	p1_box.add_child(_p1_ep_bar)

	_p1_shield_bar = ProgressBar.new()
	_p1_shield_bar.custom_minimum_size = Vector2(0, 6)
	_p1_shield_bar.max_value = 100.0
	_p1_shield_bar.value = 100.0
	_p1_shield_bar.show_percentage = false
	UIStyle.style_hp_bar(_p1_shield_bar, Color("#38bdf8"))
	p1_box.add_child(_p1_shield_bar)

	var p1_sub := HBoxContainer.new()
	p1_box.add_child(p1_sub)
	_p1_ep_lbl = Label.new()
	_p1_ep_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p1_ep_lbl.add_theme_font_size_override("font_size", 14)
	_p1_ep_lbl.add_theme_color_override("font_color", Color("#0f172a"))
	p1_sub.add_child(_p1_ep_lbl)

	_p1_status_lbl = Label.new()
	_p1_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_p1_status_lbl.add_theme_font_size_override("font_size", 13)
	_p1_status_lbl.add_theme_color_override("font_color", Color("#059669"))
	p1_sub.add_child(_p1_status_lbl)

	_p2_ep_bar = ProgressBar.new()
	_p2_ep_bar.custom_minimum_size = Vector2(0, 11)
	_p2_ep_bar.max_value = 100.0
	_p2_ep_bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	_p2_ep_bar.show_percentage = false
	UIStyle.style_hp_bar(_p2_ep_bar, Color("#0ea5e9"))
	p2_box.add_child(_p2_ep_bar)

	_p2_shield_bar = ProgressBar.new()
	_p2_shield_bar.custom_minimum_size = Vector2(0, 6)
	_p2_shield_bar.max_value = 100.0
	_p2_shield_bar.value = 100.0
	_p2_shield_bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	_p2_shield_bar.show_percentage = false
	UIStyle.style_hp_bar(_p2_shield_bar, Color("#38bdf8"))
	p2_box.add_child(_p2_shield_bar)

	var p2_sub := HBoxContainer.new()
	p2_box.add_child(p2_sub)
	_p2_status_lbl = Label.new()
	_p2_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_p2_status_lbl.add_theme_font_size_override("font_size", 13)
	_p2_status_lbl.add_theme_color_override("font_color", Color("#059669"))
	p2_sub.add_child(_p2_status_lbl)

	_p2_ep_lbl = Label.new()
	_p2_ep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_p2_ep_lbl.add_theme_font_size_override("font_size", 14)
	_p2_ep_lbl.add_theme_color_override("font_color", Color("#0f172a"))
	p2_sub.add_child(_p2_ep_lbl)

	# 实时连击标牌
	_p1_combo_lbl = Label.new()
	_p1_combo_lbl.position = Vector2(46.0, 148.0)
	_p1_combo_lbl.add_theme_font_size_override("font_size", 32)
	_p1_combo_lbl.add_theme_color_override("font_outline_color", Color("#0f172a"))
	_p1_combo_lbl.add_theme_constant_override("outline_size", 8)
	_p1_combo_lbl.visible = false
	add_child(_p1_combo_lbl)

	_p2_combo_lbl = Label.new()
	_p2_combo_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_p2_combo_lbl.offset_left = -420.0
	_p2_combo_lbl.offset_right = -46.0
	_p2_combo_lbl.offset_top = 148.0
	_p2_combo_lbl.offset_bottom = 196.0
	_p2_combo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_p2_combo_lbl.add_theme_font_size_override("font_size", 32)
	_p2_combo_lbl.add_theme_color_override("font_outline_color", Color("#0f172a"))
	_p2_combo_lbl.add_theme_constant_override("outline_size", 8)
	_p2_combo_lbl.visible = false
	add_child(_p2_combo_lbl)

	# 中央倒计时 + BO3 胜场圆点 + 暂停/音效/BGM 开关
	var center_box := VBoxContainer.new()
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.add_theme_constant_override("separation", 4)

	var timer_row := HBoxContainer.new()
	timer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	timer_row.add_theme_constant_override("separation", 10)
	center_box.add_child(timer_row)

	_p1_rounds_lbl = Label.new()
	_p1_rounds_lbl.text = "○ ○"
	_p1_rounds_lbl.add_theme_font_size_override("font_size", 22)
	_p1_rounds_lbl.add_theme_color_override("font_color", Color("#f59e0b"))
	_p1_rounds_lbl.add_theme_color_override("font_outline_color", Color("#0f172a"))
	_p1_rounds_lbl.add_theme_constant_override("outline_size", 5)
	timer_row.add_child(_p1_rounds_lbl)

	var timer_panel := PanelContainer.new()
	UIStyle.style_frosted_panel(timer_panel, Color("#1e293b"), 2)
	_timer_lbl = Label.new()
	_timer_lbl.text = "99"
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_lbl.custom_minimum_size = Vector2(82, 36)
	_timer_lbl.add_theme_font_size_override("font_size", 32)
	_timer_lbl.add_theme_color_override("font_color", Color("#0f172a"))
	timer_panel.add_child(_timer_lbl)
	timer_row.add_child(timer_panel)

	_p2_rounds_lbl = Label.new()
	_p2_rounds_lbl.text = "○ ○"
	_p2_rounds_lbl.add_theme_font_size_override("font_size", 22)
	_p2_rounds_lbl.add_theme_color_override("font_color", Color("#f59e0b"))
	_p2_rounds_lbl.add_theme_color_override("font_outline_color", Color("#0f172a"))
	_p2_rounds_lbl.add_theme_constant_override("outline_size", 5)
	timer_row.add_child(_p2_rounds_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 6)

	var pause_btn := Button.new()
	pause_btn.text = "暂停(ESC)"
	pause_btn.add_theme_font_size_override("font_size", 12)
	UIStyle.style_secondary_btn(pause_btn)
	pause_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click")
		_toggle_pause()
	)
	btn_row.add_child(pause_btn)

	_mute_btn = Button.new()
	_mute_btn.text = "音效关" if AudioManager.muted else "音效开"
	_mute_btn.add_theme_font_size_override("font_size", 12)
	UIStyle.style_secondary_btn(_mute_btn)
	_mute_btn.pressed.connect(func() -> void:
		AudioManager.toggle_mute()
		AudioManager.play_sfx("ui_click")
	)
	btn_row.add_child(_mute_btn)

	_bgm_btn = Button.new()
	_bgm_btn.text = "BGM关" if AudioManager.bgm_muted else "BGM开"
	_bgm_btn.add_theme_font_size_override("font_size", 12)
	UIStyle.style_secondary_btn(_bgm_btn)
	_bgm_btn.pressed.connect(func() -> void:
		AudioManager.toggle_bgm()
		AudioManager.play_sfx("ui_click")
	)
	btn_row.add_child(_bgm_btn)
	center_box.add_child(btn_row)
	if GameManager.battle_mode == "practice":
		_p1_rounds_lbl.hide()
		_p2_rounds_lbl.hide()
		_timer_lbl.text = "练习场"
		var practice_row := HBoxContainer.new()
		practice_row.alignment = BoxContainer.ALIGNMENT_CENTER
		practice_row.add_theme_constant_override("separation", 8)
		for setting in ["技能冷却", "AI 对练"]:
			var checkbox := CheckBox.new()
			checkbox.name = "PracticeCooldowns" if setting == "技能冷却" else "PracticeCombat"
			checkbox.text = setting
			checkbox.add_theme_font_size_override("font_size", 14)
			UIStyle.style_secondary_btn(checkbox)
			if setting == "技能冷却":
				checkbox.toggled.connect(practice_cooldowns_toggled.emit)
			else:
				checkbox.toggled.connect(practice_combat_toggled.emit)
			practice_row.add_child(checkbox)
		center_box.add_child(practice_row)

	back_btn.visible = false
	top_bar.add_child(center_box)
	top_bar.move_child(center_box, 1)

	# 底部键位提示条
	var hint_bar := PanelContainer.new()
	hint_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint_bar.offset_left = 48.0
	hint_bar.offset_right = -48.0
	hint_bar.offset_top = -46.0
	hint_bar.offset_bottom = -10.0
	UIStyle.style_frosted_panel(hint_bar, Color(0.12, 0.16, 0.23, 0.22), 1)
	_hint_lbl = Label.new()
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_lbl.add_theme_font_size_override("font_size", 14)
	_hint_lbl.add_theme_color_override("font_color", Color("#1e293b"))
	hint_bar.add_child(_hint_lbl)
	add_child(hint_bar)

func _build_pause_panel() -> void:
	_pause_overlay = Control.new()
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.visible = false
	add_child(_pause_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.08, 0.14, 0.62)
	_pause_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(960, 620)
	UIStyle.style_frosted_panel(card, Color("#1e293b"), 3)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "暂停 · 1P / 2P 自定义改键"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#0f172a"))
	vbox.add_child(title)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 12)
	vbox.add_child(action_row)

	var resume_btn := Button.new()
	resume_btn.text = "继续战斗 (ESC)"
	UIStyle.style_primary_btn(resume_btn, true)
	resume_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_confirm")
		_set_pause_open(false)
	)
	action_row.add_child(resume_btn)

	var rematch_btn := Button.new()
	rematch_btn.text = "再来一局"
	UIStyle.style_secondary_btn(rematch_btn)
	rematch_btn.pressed.connect(_on_rematch_pressed)
	action_row.add_child(rematch_btn)

	_pause_mute_btn = Button.new()
	_pause_mute_btn.text = "音效：关闭" if AudioManager.muted else "音效：开启"
	UIStyle.style_secondary_btn(_pause_mute_btn)
	_pause_mute_btn.pressed.connect(func() -> void:
		AudioManager.toggle_mute()
		AudioManager.play_sfx("ui_click")
	)
	action_row.add_child(_pause_mute_btn)

	_pause_bgm_btn = Button.new()
	_pause_bgm_btn.text = "BGM：关闭" if AudioManager.bgm_muted else "BGM：开启"
	UIStyle.style_secondary_btn(_pause_bgm_btn)
	_pause_bgm_btn.pressed.connect(func() -> void:
		AudioManager.toggle_bgm()
		AudioManager.play_sfx("ui_click")
	)
	action_row.add_child(_pause_bgm_btn)

	var reset_btn := Button.new()
	reset_btn.text = "恢复默认键位"
	UIStyle.style_secondary_btn(reset_btn)
	reset_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click")
		_rebind_action = ""
		GameManager.reset_default_keybindings()
		_refresh_rebind_buttons()
	)
	action_row.add_child(reset_btn)

	var select_btn := Button.new()
	select_btn.text = "返回选人"
	UIStyle.style_secondary_btn(select_btn)
	select_btn.pressed.connect(_on_back_cover_pressed)
	action_row.add_child(select_btn)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 24)
	vbox.add_child(cols)

	cols.add_child(_build_player_rebind_col(1, "1P 键位设置"))
	cols.add_child(_build_player_rebind_col(2, "2P 键位设置"))

func _build_player_rebind_col(player_idx: int, header_text: String) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)

	var hdr := Label.new()
	hdr.text = header_text
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 20)
	hdr.add_theme_color_override("font_color", Color("#059669") if player_idx == 1 else Color("#2563eb"))
	col.add_child(hdr)

	var prefix := "p1_" if player_idx == 1 else "p2_"
	for meta: Dictionary in GameManager.ACTION_META:
		var action_name: String = prefix + String(meta["suffix"])
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = String(meta["label"])
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color("#1e293b"))
		row.add_child(lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(140, 32)
		btn.text = GameManager.get_action_key_label(action_name)
		UIStyle.style_secondary_btn(btn)
		btn.pressed.connect(func() -> void:
			AudioManager.play_sfx("ui_click")
			_start_rebind(action_name)
		)
		row.add_child(btn)
		_rebind_buttons[action_name] = btn
		col.add_child(row)
	return col

func _build_ko_panel() -> void:
	_ko_overlay = Control.new()
	_ko_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ko_overlay.visible = false
	add_child(_ko_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.07, 0.14, 0.68)
	_ko_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ko_overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(620, 520)
	UIStyle.style_frosted_panel(card, Color("#f59e0b"), 3)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	_ko_badge_lbl = Label.new()
	_ko_badge_lbl.text = "K.O.!"
	_ko_badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ko_badge_lbl.add_theme_font_size_override("font_size", 48)
	_ko_badge_lbl.add_theme_color_override("font_color", Color("#d97706"))
	vbox.add_child(_ko_badge_lbl)

	_ko_portrait = TextureRect.new()
	_ko_portrait.custom_minimum_size = Vector2(150, 150)
	_ko_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ko_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(_ko_portrait)

	_ko_winner_lbl = Label.new()
	_ko_winner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ko_winner_lbl.add_theme_font_size_override("font_size", 26)
	_ko_winner_lbl.add_theme_color_override("font_color", Color("#0f172a"))
	vbox.add_child(_ko_winner_lbl)

	_ko_stats_lbl = Label.new()
	_ko_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ko_stats_lbl.add_theme_font_size_override("font_size", 16)
	_ko_stats_lbl.add_theme_color_override("font_color", Color("#334155"))
	vbox.add_child(_ko_stats_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 18)
	vbox.add_child(btn_row)

	var rematch_btn := Button.new()
	rematch_btn.text = "再来一局"
	rematch_btn.custom_minimum_size = Vector2(170, 48)
	UIStyle.style_primary_btn(rematch_btn, true)
	rematch_btn.pressed.connect(_on_rematch_pressed)
	btn_row.add_child(rematch_btn)

	var back_sel_btn := Button.new()
	back_sel_btn.text = "返回选人"
	back_sel_btn.custom_minimum_size = Vector2(170, 48)
	UIStyle.style_secondary_btn(back_sel_btn)
	back_sel_btn.pressed.connect(_on_back_cover_pressed)
	btn_row.add_child(back_sel_btn)

func show_ko_overlay(winner: BaseFighter, badge_text: String = "K.O.!") -> void:
	_set_pause_open(false)
	_ko_badge_lbl.text = badge_text
	if winner:
		var meta: Dictionary = GameManager.get_fighter_meta(winner.fighter_id)
		_ko_winner_lbl.text = "%dP %s 夺得胜利！ (%d : %d) · %s" % [winner.player_index, winner.fighter_name, GameManager.p1_rounds, GameManager.p2_rounds, String(meta["title"])]
		_ko_portrait.texture = GameManager.get_portrait_texture(winner.fighter_id)
		_ko_portrait.visible = _ko_portrait.texture != null
	else:
		_ko_winner_lbl.text = "势均力敌 · 平局 (%d : %d)" % [GameManager.p1_rounds, GameManager.p2_rounds]
		_ko_portrait.visible = false
	if _ko_stats_lbl:
		var s1: Dictionary = GameManager.match_stats.get(1, {}) as Dictionary
		var s2: Dictionary = GameManager.match_stats.get(2, {}) as Dictionary
		var p1_n: String = _p1.fighter_name if is_instance_valid(_p1) else "1P"
		var p2_n: String = _p2.fighter_name if is_instance_valid(_p2) else "2P"
		_ko_stats_lbl.text = "━━ 战局 MVP 数据统计 ━━\n1P %s: 总伤害 %d · 最高连击 %d · 完美格挡 %d · 道具 %d\n2P %s: 总伤害 %d · 最高连击 %d · 完美格挡 %d · 道具 %d" % [
			p1_n, int(s1.get("damage", 0)), int(s1.get("max_combo", 0)), int(s1.get("parries", 0)), int(s1.get("items", 0)),
			p2_n, int(s2.get("damage", 0)), int(s2.get("max_combo", 0)), int(s2.get("parries", 0)), int(s2.get("items", 0))
		]
	_ko_overlay.visible = true

func _start_rebind(action_name: String) -> void:
	_rebind_action = action_name
	_refresh_rebind_buttons()

func _refresh_rebind_buttons() -> void:
	for action_name: String in _rebind_buttons.keys():
		var btn: Button = _rebind_buttons[action_name] as Button
		if action_name == _rebind_action:
			btn.text = "请按下任意键..."
			UIStyle.style_secondary_btn(btn, Color("#f59e0b"))
		else:
			btn.text = GameManager.get_action_key_label(action_name)
			UIStyle.style_secondary_btn(btn)

func _refresh_key_hints() -> void:
	if _hint_lbl == null:
		return
	var p1_s := "1P: %s/%s/%s/%s 移跳防  %s轻 %s重 %s闪 %s技1 %s技2 %s大招" % [
		GameManager.get_action_key_label("p1_left"),
		GameManager.get_action_key_label("p1_right"),
		GameManager.get_action_key_label("p1_up"),
		GameManager.get_action_key_label("p1_guard"),
		GameManager.get_action_key_label("p1_light"),
		GameManager.get_action_key_label("p1_heavy"),
		GameManager.get_action_key_label("p1_dash"),
		GameManager.get_action_key_label("p1_skill1"),
		GameManager.get_action_key_label("p1_skill2"),
		GameManager.get_action_key_label("p1_ult")
	]
	var p2_s := "2P: %s/%s/%s/%s 移跳防  %s轻 %s重 %s闪 %s技1 %s技2 %s大招" % [
		GameManager.get_action_key_label("p2_left"),
		GameManager.get_action_key_label("p2_right"),
		GameManager.get_action_key_label("p2_up"),
		GameManager.get_action_key_label("p2_guard"),
		GameManager.get_action_key_label("p2_light"),
		GameManager.get_action_key_label("p2_heavy"),
		GameManager.get_action_key_label("p2_dash"),
		GameManager.get_action_key_label("p2_skill1"),
		GameManager.get_action_key_label("p2_skill2"),
		GameManager.get_action_key_label("p2_ult")
	]
	_hint_lbl.text = "%s   |   %s" % [p1_s, p2_s]

func _on_mute_changed(is_muted: bool) -> void:
	if _mute_btn:
		_mute_btn.text = "音效关" if is_muted else "音效开"
	if _pause_mute_btn:
		_pause_mute_btn.text = "音效：关闭" if is_muted else "音效：开启"

func _on_bgm_mute_changed(is_bgm_muted: bool) -> void:
	if _bgm_btn:
		_bgm_btn.text = "BGM关" if is_bgm_muted else "BGM开"
	if _pause_bgm_btn:
		_pause_bgm_btn.text = "BGM：关闭" if is_bgm_muted else "BGM：开启"

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var kev := event as InputEventKey
		var code: int = int(kev.physical_keycode) if kev.physical_keycode != 0 else int(kev.keycode)
		if _rebind_action != "":
			if code != KEY_ESCAPE:
				GameManager.rebind_action(_rebind_action, code)
				AudioManager.play_sfx("ui_confirm")
			_rebind_action = ""
			_refresh_rebind_buttons()
			get_viewport().set_input_as_handled()
			return
		if practice_panel != null and not _pause_overlay.visible and practice_panel.consume_shortcut(code):
			get_viewport().set_input_as_handled()
			return
		if code == KEY_ESCAPE and not _ko_overlay.visible:
			AudioManager.play_sfx("ui_click")
			_toggle_pause()
			get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	_set_pause_open(not _pause_overlay.visible)

func _set_pause_open(open: bool) -> void:
	if _pause_overlay == null:
		return
	_rebind_action = ""
	_pause_overlay.visible = open
	GameManager.is_pause_menu_open = open
	if open:
		_refresh_rebind_buttons()
	GameManager.sync_battle_pause()

func _format_fighter_status(f: BaseFighter) -> String:
	var parts: Array[String] = []
	var buff: String = f.get_active_buff_status()
	if buff != "":
		parts.append("★ " + buff)
	parts.append("技1:%s" % ("就绪" if f.skill1_cd <= 0.05 else "%.1fs" % f.skill1_cd))
	parts.append("技2:%s" % ("就绪" if f.skill2_cd <= 0.05 else "%.1fs" % f.skill2_cd))
	return "  |  ".join(parts)

func _process(delta: float) -> void:
	if is_instance_valid(_p1):
		p1_bar.max_value = _p1.max_hp
		p1_bar.value = _p1.hp
		_p1_trail_val = maxf(float(_p1.hp), lerpf(_p1_trail_val, float(_p1.hp), 1.0 - exp(-5.0 * delta)))
		if _p1_trail_bar:
			_p1_trail_bar.max_value = _p1.max_hp
			_p1_trail_bar.value = _p1_trail_val
		p1_label.text = "1P %s   %d / %d" % [_p1.fighter_name, _p1.hp, _p1.max_hp]
		_p1_ep_bar.value = _p1.ep
		if _p1_shield_bar:
			_p1_shield_bar.value = _p1.shield_hp
			_p1_shield_bar.modulate = Color("#ef4444") if (_p1.shield_broken_timer > 0.0 or _p1.shield_hp < 30.0) else Color.WHITE
		if _p1.ep >= 100.0:
			_p1_ep_lbl.text = "EP 100%% · 大招就绪 (%s)" % GameManager.get_action_key_label("p1_ult")
			_p1_ep_lbl.add_theme_color_override("font_color", Color("#d97706"))
		else:
			_p1_ep_lbl.text = "EP %d%% · 盾 %d%%" % [int(_p1.ep), int(_p1.shield_hp)]
			_p1_ep_lbl.add_theme_color_override("font_color", Color("#0f172a"))
		if _p1_status_lbl:
			_p1_status_lbl.text = _format_fighter_status(_p1)
	if is_instance_valid(_p2):
		p2_bar.max_value = _p2.max_hp
		p2_bar.value = _p2.hp
		_p2_trail_val = maxf(float(_p2.hp), lerpf(_p2_trail_val, float(_p2.hp), 1.0 - exp(-5.0 * delta)))
		if _p2_trail_bar:
			_p2_trail_bar.max_value = _p2.max_hp
			_p2_trail_bar.value = _p2_trail_val
		var p2_tag := ("AI·困难" if GameManager.ai_difficulty == "hard" else "AI·普通") if _p2.is_ai_controlled else "2P"
		p2_label.text = "%d / %d   %s %s" % [_p2.hp, _p2.max_hp, _p2.fighter_name, p2_tag]
		_p2_ep_bar.value = _p2.ep
		if _p2_shield_bar:
			_p2_shield_bar.value = _p2.shield_hp
			_p2_shield_bar.modulate = Color("#ef4444") if (_p2.shield_broken_timer > 0.0 or _p2.shield_hp < 30.0) else Color.WHITE
		if _p2.ep >= 100.0:
			_p2_ep_lbl.text = "(%s) 大招就绪 · EP 100%%" % GameManager.get_action_key_label("p2_ult")
			_p2_ep_lbl.add_theme_color_override("font_color", Color("#d97706"))
		else:
			_p2_ep_lbl.text = "盾 %d%% · EP %d%%" % [int(_p2.shield_hp), int(_p2.ep)]
			_p2_ep_lbl.add_theme_color_override("font_color", Color("#0f172a"))
		if _p2_status_lbl:
			_p2_status_lbl.text = _format_fighter_status(_p2)

func _on_rematch_pressed() -> void:
	AudioManager.play_sfx("ui_confirm")
	GameManager.is_pause_menu_open = false
	GameManager.hitstop_timer = 0.0
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_back_cover_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	GameManager.is_pause_menu_open = false
	GameManager.hitstop_timer = 0.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")
