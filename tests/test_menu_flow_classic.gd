extends SceneTree

func _init() -> void:
	print("=== TESTANDO DEPLOY NO MAPA CLÁSSICO (BO1) ===")
	call_deferred("_run")

func _run() -> void:
	var menu_scn = load("res://scenes/ui/main_menu.tscn") as PackedScene
	var menu = menu_scn.instantiate()
	root.add_child(menu)
	current_scene = menu

	for i in range(5):
		await process_frame

	print("Selecionando Nuketown Clássica...")
	menu._select_map("res://scenes/_world/map_nuketown_1v1.tscn", "NUKETOWN CLÁSSICA (BO1 1960)")
	
	for i in range(5):
		await process_frame

	print("Simulando clique no botão Deploy...")
	menu._on_deploy_pressed()

	for i in range(120):
		await process_frame
		await physics_frame

	var vp = root.get_viewport()
	var cam = vp.get_camera_3d()
	print("\n--- PÓS-DEPLOY MAPA CLÁSSICO ---")
	print("Cena atual: ", current_scene.name if current_scene else "null")
	if cam:
		print("Câmera ativa: ", cam.get_path())
		print("Camera current: ", cam.current)
		print("Camera global_position: ", cam.global_position)
	else:
		print("ALERTA: NENHUMA CÂMERA 3D ATIVA NO VIEWPORT!")

	var p = root.find_child("Player*", true, false)
	if p:
		print("Player encontrado: ", p.name, " em ", p.global_position)
	else:
		print("Player NÃO ENCONTRADO!")

	await RenderingServer.frame_post_draw
	var img = vp.get_texture().get_image()
	if img:
		img.save_png("c:/gemini cli/games/test_menu_flow_classic.png")
		print("Screenshot salva em c:/gemini cli/games/test_menu_flow_classic.png")

	quit(0)
