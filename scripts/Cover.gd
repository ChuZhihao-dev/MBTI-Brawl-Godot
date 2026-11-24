extends Control

@onready var dock_panel: PanelContainer = $MenuDock
@onready var start_btn: Button = $MenuDock/MenuBar/StartBtn
@onready var versus_btn: Button = $MenuDock/MenuBar/VersusBtn
@onready var quit_btn: Button = $MenuDock/MenuBar/QuitBtn

func _ready() -> void:
	UIStyle.style_frosted_panel(dock_panel, Color(0.886, 0.91, 0.941, 0.95), 2)
	UIStyle.style_primary_btn(start_btn, false)
	UIStyle.style_secondary_btn(versus_btn)
	UIStyle.style_secondary_btn(quit_btn)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
