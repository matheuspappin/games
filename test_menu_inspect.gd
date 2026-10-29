extends Node

func _ready():
	print("--- INSPECTING MAIN MENU NODES ---")
	var scn = load("res://scenes/ui/main_menu.tscn")
	if not scn:
		print("ERROR: Could not load main_menu.tscn")
		get_tree().quit(1)
		return
	var menu = scn.instantiate()
	add_child(menu)
	print("Instantiated successfully!")
	print("card_mode_tdm = ", menu.card_mode_tdm)
	print("btn_deploy_main = ", menu.btn_deploy_main)
	print("box_bots_config = ", menu.box_bots_config)
	print("btn_preset_6v6 = ", menu.btn_preset_6v6)
	
	await get_tree().create_timer(0.5).timeout
	
	var img = get_viewport().get_texture().get_image()
	if img:
		img.save_png("res://test_menu_current.png")
		print("Screenshot saved to res://test_menu_current.png")
	
	get_tree().quit(0)
