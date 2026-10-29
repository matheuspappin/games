# =============================================================================
# pause_menu.gd
# Menu de Pausa Tático — Call of Duty Style
# =============================================================================
class_name PauseMenu
extends Control

@onready var btn_resume    : Button = $Panel/VBox/BtnResume
@onready var btn_settings  : Button = $Panel/VBox/BtnSettings
@onready var btn_restart   : Button = $Panel/VBox/BtnRestart
@onready var btn_main_menu : Button = $Panel/VBox/BtnMainMenu
@onready var btn_quit      : Button = $Panel/VBox/BtnQuit
@onready var settings_menu : Control = $SettingsMenu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	btn_resume.pressed.connect(resume_game)
	if btn_settings:
		btn_settings.pressed.connect(open_settings)
	btn_restart.pressed.connect(restart_match)
	btn_main_menu.pressed.connect(return_to_main_menu)
	btn_quit.pressed.connect(quit_game)

func open_settings() -> void:
	if settings_menu:
		settings_menu.open_menu()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		var gm = get_node_or_null("/root/GameManager")
		if gm and (not gm.is_match_active or gm.current_state == gm.GameState.MATCH_ENDED):
			return
		var hud = get_parent()
		if hud and "aar_overlay" in hud and hud.aar_overlay and hud.aar_overlay.visible:
			return

		if settings_menu and settings_menu.visible:
			settings_menu.visible = false
		elif visible:
			resume_game()
		else:
			pause_game()
		get_viewport().set_input_as_handled()

func pause_game() -> void:
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func resume_game() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func restart_match() -> void:
	get_tree().paused = false
	var gm = get_node_or_null("/root/GameManager")
	var cur_path = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	if gm and gm.has_cached_scene(cur_path):
		get_tree().change_scene_to_packed(gm.get_cached_scene(cur_path))
	else:
		get_tree().reload_current_scene()

func return_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func quit_game() -> void:
	get_tree().quit()
