extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scn = load("res://scenes/ui/main_menu.tscn") as PackedScene
	var menu = scn.instantiate()
	root.add_child(menu)
	current_scene = menu

	for i in range(10):
		await process_frame

	var img1: TextureRect = menu.get_node_or_null("MainLayout/VBox/CardsHBox/CardNuk3town/Margin/VBox/ImgNuk3town")
	var img2: TextureRect = menu.get_node_or_null("MainLayout/VBox/CardsHBox/CardClassic/Margin/VBox/ImgClassic")
	
	if img1:
		print("img1 visible: ", img1.is_visible_in_tree())
		print("img1 size: ", img1.size)
		print("img1 global_pos: ", img1.global_position)
		print("img1 texture: ", img1.texture)
		print("img1 modulate: ", img1.modulate, " self_modulate: ", img1.self_modulate)
	if img2:
		print("img2 visible: ", img2.is_visible_in_tree())
		print("img2 size: ", img2.size)
		print("img2 global_pos: ", img2.global_position)
		print("img2 texture: ", img2.texture)
		print("img2 modulate: ", img2.modulate, " self_modulate: ", img2.self_modulate)

	await RenderingServer.frame_post_draw
	var vp = root.get_viewport()
	var img = vp.get_texture().get_image()
	if img:
		img.save_png("c:/gemini cli/games/debug_menu_img.png")
		print("Saved debug_menu_img.png")
	quit(0)
