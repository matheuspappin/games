extends SceneTree

func _init() -> void:
	print("=== CAPTURANDO SCREENSHOT DO NOVO MENU PRINCIPAL ===")
	call_deferred("_run")

func _run() -> void:
	var scn = load("res://scenes/ui/main_menu.tscn") as PackedScene
	var menu = scn.instantiate()
	root.add_child(menu)
	current_scene = menu

	for i in range(15):
		await process_frame

	await RenderingServer.frame_post_draw
	var vp = root.get_viewport()
	var img = vp.get_texture().get_image()
	if img:
		img.save_png("c:/gemini cli/games/screenshot_main_menu_new.png")
		print("Screenshot do menu salva em c:/gemini cli/games/screenshot_main_menu_new.png")

	quit(0)
