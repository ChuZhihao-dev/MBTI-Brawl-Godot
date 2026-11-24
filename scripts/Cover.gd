extends Control

@onready var dock_panel: PanelContainer = $MenuDock
@onready var start_btn: Button = $MenuDock/MenuBar/StartBtn
@onready var versus_btn: Button = $MenuDock/MenuBar/VersusBtn
@onready var quit_btn: Button = $MenuDock/MenuBar/QuitBtn

func _ready() -> void:
	GameManager.is_pause_menu_open = false
	GameManager.hitstop_timer = 0.0
	get_tree().paused = false

	UIStyle.style_frosted_panel(dock_panel, Color(0.886, 0.91, 0.941, 0.95), 2)
	start_btn.text = "人机对战 (1P vs AI)"
	versus_btn.text = "双人对战 (1P vs 2P)"
	UIStyle.style_primary_btn(start_btn, true)
	UIStyle.style_secondary_btn(versus_btn)
	UIStyle.style_secondary_btn(quit_btn)

	if not versus_btn.pressed.is_connected(_on_versus_pressed):
		versus_btn.pressed.connect(_on_versus_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var kev := event as InputEventKey
		if kev.keycode == KEY_ENTER or kev.keycode == KEY_SPACE:
			_on_start_pressed()

func _on_start_pressed() -> void:
	AudioManager.play_sfx("ui_confirm")
	GameManager.battle_mode = "ai"
	get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")

func _on_versus_pressed() -> void:
	AudioManager.play_sfx("ui_confirm")
	GameManager.battle_mode = "pvp"
	get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")

func _on_quit_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	get_tree().quit()
