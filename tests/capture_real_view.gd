extends SceneTree

func _init() -> void:
	print("=== INICIANDO CAPTURA DE TELA REAL DO COMBATE ===")
	call_deferred("_run")

func _run() -> void:
	# Simular GameManager com partida em Bots
	var gm = root.get_node_or_null("GameManager")
	if gm:
		gm.configure_bot_match("res://scenes/_world/map_nuketown_1v1.tscn", "NUKETOWN CLÁSSICA (BO1)", 5, gm.BotDistribution.BALANCED, gm.BotDifficulty.REGULAR)

	var scn = load("res://scenes/_world/map_nuketown_1v1.tscn") as PackedScene
	var map = scn.instantiate()
	root.add_child(map)
	current_scene = map

	var net = map.find_child("NetworkManager", true, false)
	if net:
		net.start_local_match()

	for i in range(40):
		await process_frame
		await physics_frame

	var vp = root.get_viewport()
	var cam = vp.get_camera_3d()
	print("--- ESTADO DA CÂMERA DO VIEWPORT ---")
	if cam:
		print("Câmera ativa no Viewport: ", cam.get_path())
		print("Camera current: ", cam.current)
		print("Camera global_position: ", cam.global_position)
		print("Camera global_rotation: ", cam.global_rotation)
		print("Camera cull_mask: ", cam.cull_mask)
		print("Camera fov: ", cam.fov, " | near: ", cam.near, " | far: ", cam.far)
	else:
		print("ALERTA CRÍTICO: NENHUMA Camera3D ATIVA NO VIEWPORT! viewport.get_camera_3d() é NULL!")

	var p1 = map.find_child("Player_1", true, false)
	if p1:
		print("Player_1 global_position: ", p1.global_position)
		print("Player_1 visible: ", p1.visible)
		var pcam = p1.find_child("Camera", true, false)
		if pcam:
			print("Player Camera node: ", pcam.get_path(), " | current: ", pcam.current)
	else:
		print("Player_1 NÃO ENCONTRADO!")

	var bots = map.find_children("Bot_*", "CharacterBody3D", true, false)
	print("Quantidade de bots no mapa: ", bots.size())
	for b in bots:
		print(" - ", b.name, " em ", b.global_position)

	# Salvar imagem
	await RenderingServer.frame_post_draw
	var img = vp.get_texture().get_image()
	if img:
		img.save_png("c:/gemini cli/games/test_real_view.png")
		print("Screenshot salva em c:/gemini cli/games/test_real_view.png")
	else:
		print("Falha ao capturar imagem do viewport!")

	quit(0)
