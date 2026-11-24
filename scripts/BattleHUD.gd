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
var _p1_ep_lbl: Label
var _p2_ep_lbl: Label
var _timer_lbl: Label
var _mute_btn: Button
var _hint_lbl: Label

var _pause_overlay: Control
var _pause_mute_btn: Button
var _ko_overlay: Control
var _ko_badge_lbl: Label
var _ko_winner_lbl: Label
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
	_refresh_key_hints()
	AudioManager.mute_changed.connect(_on_mute_changed)
	GameManager.keybindings_changed.connect(_refresh_key_hints)

func bind_fighters(p1: BaseFighter, p2: BaseFighter) -> void:
	_p1 = p1
	_p2 = p2

func set_timer_value(sec: int) -> void:
	if _timer_lbl:
		_timer_lbl.text = "%02d" % maxi(0, sec)
		_timer_lbl.add_theme_color_override("font_color", Color("#ef4444") if sec <= 15 else Color("#0f172a"))

func _build_hud_extensions() -> void:
	# 1P / 2P 能量条（EP）
	_p1_ep_bar = ProgressBar.new()
	_p1_ep_bar.custom_minimum_size = Vector2(0, 12)
	_p1_ep_bar.max_value = 100.0
	_p1_ep_bar.show_percentage = false
	UIStyle.style_hp_bar(_p1_ep_bar, Color("#0ea5e9"))
	p1_box.add_child(_p1_ep_bar)

	_p1_ep_lbl = Label.new()
	_p1_ep_lbl.add_theme_font_size_override("font_size", 14)
	_p1_ep_lbl.add_theme_color_override("font_color", Color("#0f172a"))
	p1_box.add_child(_p1_ep_lbl)

	_p2_ep_bar = ProgressBar.new()
	_p2_ep_bar.custom_minimum_size = Vector2(0, 12)
	_p2_ep_bar.max_value = 100.0
	_p2_ep_bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	_p2_ep_bar.show_percentage = false
	UIStyle.style_hp_bar(_p2_ep_bar, Color("#0ea5e9"))
	p2_box.add_child(_p2_ep_bar)

	_p2_ep_lbl = Label.new()
	_p2_ep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_p2_ep_lbl.add_theme_font_size_override("font_size", 14)
	_p2_ep_lbl.add_theme_color_override("font_color", Color("#0f172a"))
	p2_box.add_child(_p2_ep_lbl)

	# 中央倒计时 + 暂停/静音区（替换原本孤立的 BackBtn 布局）
	var center_box := VBoxContainer.new()
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.add_theme_constant_override("separation", 4)

	var timer_panel := PanelContainer.new()
	UIStyle.style_frosted_panel(timer_panel, Color("#1e293b"), 2)
	_timer_lbl = Label.new()
	_timer_lbl.text = "99"
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_lbl.custom_minimum_size = Vector2(88, 38)
	_timer_lbl.add_theme_font_size_override("font_size", 34)
	_timer_lbl.add_theme_color_override("font_color", Color("#0f172a"))
	timer_panel.add_child(_timer_lbl)
	center_box.add_child(timer_panel)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 6)

	var pause_btn := Button.new()
	pause_btn.text = "暂停(ESC)"
	pause_btn.add_theme_font_size_override("font_size", 13)
	UIStyle.style_secondary_btn(pause_btn)
	pause_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click")
		_toggle_pause()
	)
	btn_row.add_child(pause_btn)

	_mute_btn = Button.new()
	_mute_btn.text = "静音" if AudioManager.muted else "音效开"
	_mute_btn.add_theme_font_size_override("font_size", 13)
	UIStyle.style_secondary_btn(_mute_btn)
	_mute_btn.pressed.connect(func() -> void:
		AudioManager.toggle_mute()
		AudioManager.play_sfx("ui_click")
	)
	btn_row.add_child(_mute_btn)
	center_box.add_child(btn_row)

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
	card.custom_minimum_size = Vector2(540, 440)
	UIStyle.style_frosted_panel(card, Color("#f59e0b"), 3)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	_ko_badge_lbl = Label.new()
	_ko_badge_lbl.text = "K.O.!"
	_ko_badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ko_badge_lbl.add_theme_font_size_override("font_size", 52)
	_ko_badge_lbl.add_theme_color_override("font_color", Color("#d97706"))
	vbox.add_child(_ko_badge_lbl)

	_ko_portrait = TextureRect.new()
	_ko_portrait.custom_minimum_size = Vector2(180, 180)
	_ko_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ko_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(_ko_portrait)

	_ko_winner_lbl = Label.new()
	_ko_winner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ko_winner_lbl.add_theme_font_size_override("font_size", 28)
	_ko_winner_lbl.add_theme_color_override("font_color", Color("#0f172a"))
	vbox.add_child(_ko_winner_lbl)

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
		_ko_winner_lbl.text = "%dP %s 获胜！ · %s" % [winner.player_index, winner.fighter_name, String(meta["title"])]
		_ko_portrait.texture = GameManager.get_portrait_texture(winner.fighter_id)
		_ko_portrait.visible = _ko_portrait.texture != null
	else:
		_ko_winner_lbl.text = "势均力敌 · 平局 (DRAW)"
		_ko_portrait.visible = false
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
		_mute_btn.text = "静音" if is_muted else "音效开"
	if _pause_mute_btn:
		_pause_mute_btn.text = "音效：关闭" if is_muted else "音效：开启"

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
		get_tree().paused = true
	else:
		GameManager.hitstop_timer = 0.0
		get_tree().paused = false

func _process(_delta: float) -> void:
	if is_instance_valid(_p1):
		p1_bar.max_value = _p1.max_hp
		p1_bar.value = _p1.hp
		p1_label.text = "1P %s   %d / %d" % [_p1.fighter_name, _p1.hp, _p1.max_hp]
		_p1_ep_bar.value = _p1.ep
		if _p1.ep >= 100.0:
			_p1_ep_lbl.text = "EP 100% · 大招就绪 (%s)" % GameManager.get_action_key_label("p1_ult")
			_p1_ep_lbl.add_theme_color_override("font_color", Color("#d97706"))
		else:
			_p1_ep_lbl.text = "EP %d%%" % int(_p1.ep)
			_p1_ep_lbl.add_theme_color_override("font_color", Color("#0f172a"))
	if is_instance_valid(_p2):
		p2_bar.max_value = _p2.max_hp
		p2_bar.value = _p2.hp
		p2_label.text = "%d / %d   %s 2P" % [_p2.hp, _p2.max_hp, _p2.fighter_name]
		_p2_ep_bar.value = _p2.ep
		if _p2.ep >= 100.0:
			_p2_ep_lbl.text = "(%s) 大招就绪 · EP 100%%" % GameManager.get_action_key_label("p2_ult")
			_p2_ep_lbl.add_theme_color_override("font_color", Color("#d97706"))
		else:
			_p2_ep_lbl.text = "EP %d%%" % int(_p2.ep)
			_p2_ep_lbl.add_theme_color_override("font_color", Color("#0f172a"))

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
