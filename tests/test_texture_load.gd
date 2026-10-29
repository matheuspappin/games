extends SceneTree

func _init():
	var tex1 = load("res://web/public/assets/nuketown_2065.jpg")
	var tex2 = load("res://web/public/assets/nuketown_bo1.jpg")
	var tex3 = load("res://web/public/assets/nuke_tournament.jpg")
	print("tex1 (nuketown_2065): ", tex1, " size: ", tex1.get_size() if tex1 else "null")
	print("tex2 (nuketown_bo1): ", tex2, " size: ", tex2.get_size() if tex2 else "null")
	print("tex3 (nuke_tournament): ", tex3, " size: ", tex3.get_size() if tex3 else "null")
	
	var menu_scene = load("res://scenes/ui/main_menu.tscn")
	print("menu_scene: ", menu_scene)
	if menu_scene:
		var instance = menu_scene.instantiate()
		print("instance created: ", instance)
		var img1 = instance.get_node_or_null("MainLayout/VBox/CardsHBox/CardNuk3town/Margin/VBox/ImgNuk3town")
		var img2 = instance.get_node_or_null("MainLayout/VBox/CardsHBox/CardClassic/Margin/VBox/ImgClassic")
		print("img1 node: ", img1, " texture: ", img1.texture if img1 else "null")
		print("img2 node: ", img2, " texture: ", img2.texture if img2 else "null")
		if img1 and img1.texture:
			print("img1 texture size: ", img1.texture.get_size())
		if img2 and img2.texture:
			print("img2 texture size: ", img2.texture.get_size())
		instance.queue_free()
	quit()
