extends Control

signal reset_requested(preset: int)
signal behavior_changed(behavior: int)
signal fighters_selected(p1_id: String, p2_id: String)

var _p1: BaseFighter
var _p2: BaseFighter
var _stats: Label
var _modal: Control
var _selectors: Array[OptionButton] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 48.0
	panel.offset_top = -157.0
	panel.offset_bottom = -57.0
	UIStyle.style_frosted_panel(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	_stats = Label.new()
	_stats.add_theme_color_override("font_color", Color("#0f172a"))
	_stats.add_theme_font_size_override("font_size", 17)
	column.add_child(_stats)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var position := _options(row, ["近身", "中距离", "墙角"])
	var reset := _button(row, "重置站位")
	reset.pressed.connect(func() -> void: reset_requested.emit(position.selected))
	var behavior := _options(row, ["木桩：站桩", "木桩：防御", "木桩：跳跃", "木桩：受击反击", "木桩：持续攻击"])
	behavior.item_selected.connect(behavior_changed.emit)
	var change := _button(row, "换人 (P)")
	change.pressed.connect(toggle_picker)
	_build_picker()

func bind_fighters(p1: BaseFighter, p2: BaseFighter) -> void:
	_p1 = p1
	_p2 = p2

func _process(_delta: float) -> void:
	if is_instance_valid(_p1):
		_stats.text = "上一击 %d    连段伤害 %d    连击 %d    最高连击 %d    最高连段伤害 %d" % [
			_p1.practice_last_damage, _p1.current_combo_damage, _p1.current_combo_hits,
			_p1.practice_best_hits, _p1.practice_best_damage
		]

func _button(parent: Control, label: String) -> Button:
	var button := Button.new()
	button.text = label
	UIStyle.style_secondary_btn(button)
	parent.add_child(button)
	return button

func _options(parent: Control, labels: Array[String]) -> OptionButton:
	var options := OptionButton.new()
	UIStyle.style_secondary_btn(options)
	parent.add_child(options)
	for label in labels:
		options.add_item(label)
	return options

func _build_picker() -> void:
	_modal = Control.new()
	add_child(_modal)
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.hide()
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.09, 0.17, 0.58)
	_modal.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_modal.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	UIStyle.style_frosted_panel(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 340.0
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "练习场换人"
	heading.add_theme_color_override("font_color", Color("#0f172a"))
	heading.add_theme_font_size_override("font_size", 22)
	column.add_child(heading)
	for label in ["1P", "2P"]:
		var row := HBoxContainer.new()
		column.add_child(row)
		var player_label := Label.new()
		player_label.text = label
		player_label.add_theme_color_override("font_color", Color("#0f172a"))
		row.add_child(player_label)
		var options := _options(row, [])
		options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for info in GameManager.ROSTER:
			options.add_item(String(info["name"]))
			options.set_item_metadata(options.item_count - 1, info["id"])
		_selectors.append(options)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(actions)
	_button(actions, "取消").pressed.connect(close_picker)
	_button(actions, "确认换人").pressed.connect(_apply_fighters)

func toggle_picker() -> void:
	if _modal.visible:
		close_picker()
		return
	if GameManager.is_pause_menu_open or not is_instance_valid(_p1) or not is_instance_valid(_p2):
		return
	var ids := [_p1.fighter_id, _p2.fighter_id]
	for index in range(_selectors.size()):
		var options := _selectors[index]
		for entry in range(options.item_count):
			if options.get_item_metadata(entry) == ids[index]:
				options.select(entry)
				break
	_modal.show()
	GameManager.is_pause_menu_open = true
	GameManager.sync_battle_pause()
	_selectors[0].grab_focus()

func consume_shortcut(key: int) -> bool:
	if _modal.visible and key == KEY_ESCAPE:
		close_picker()
		return true
	if key == KEY_P:
		toggle_picker()
		return true
	return false

func close_picker() -> void:
	if not _modal.visible:
		return
	_modal.hide()
	GameManager.is_pause_menu_open = false
	GameManager.sync_battle_pause()

func _apply_fighters() -> void:
	fighters_selected.emit(
		String(_selectors[0].get_selected_metadata()),
		String(_selectors[1].get_selected_metadata())
	)
	close_picker()

func _exit_tree() -> void:
	if is_instance_valid(_modal) and _modal.visible:
		GameManager.is_pause_menu_open = false
		GameManager.sync_battle_pause()
