extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scn = load("res://scenes/ui/main_menu.tscn") as PackedScene
	var menu = scn.instantiate()
	root.add_child(menu)
	current_scene = menu

	for i in range(5):
		await process_frame

	# Clica no card clássico
	menu.card_classic.emit_signal("pressed")

	for i in range(5):
		await process_frame

	await RenderingServer.frame_post_draw
	var vp = root.get_viewport()
	var img = vp.get_texture().get_image()
	if img:
		img.save_png("c:/gemini cli/games/debug_menu_classic_selected.png")
		print("Screenshot classic card selected salva!")
	quit(0)
