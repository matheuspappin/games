extends SceneTree

func _init() -> void:
	print("=== INICIANDO TESTE DO NOVO FLUXO: MENU -> LOBBY COD -> LOADING BAR -> 3D MAP ===")
	call_deferred("_run")

func _run() -> void:
	# 1. Carregar Main Menu
	var menu_scn = load("res://scenes/ui/main_menu.tscn") as PackedScene
	var menu = menu_scn.instantiate()
	root.add_child(menu)
	current_scene = menu

	for i in range(5):
		await process_frame

	print("[1/4] Menu carregado. Pressionando botão de deploy...")
	menu._on_deploy_pressed()

	# 2. Aguardar transição para LobbyScreen
	for i in range(15):
		await process_frame

	print("[2/4] Verificando LobbyScreen...")
	print("Cena atual: ", current_scene.name if current_scene else "null")

	# Deixar alguns bots entrarem na sala (0.6 segundos)
	for i in range(35):
		await process_frame

	await RenderingServer.frame_post_draw
	var vp = root.get_viewport()
	var img_lobby = vp.get_texture().get_image()
	if img_lobby:
		img_lobby.save_png("c:/gemini cli/games/test_lobby_screenshot.png")
		print("Screenshot do LOBBY salva em: c:/gemini cli/games/test_lobby_screenshot.png")

	# 3. Forçar início no Lobby para ir à Loading Screen
	var lobby_node = current_scene
	if lobby_node and lobby_node.has_method("_on_force_start"):
		print("[3/4] Forçando início da partida no Lobby...")
		lobby_node._on_force_start()

	# Aguardar transição para LoadingScreen
	for i in range(15):
		await process_frame

	print("Cena atual após início do lobby: ", current_scene.name if current_scene else "null")

	# Aguardar barra de progresso avançar
	for i in range(25):
		await process_frame

	await RenderingServer.frame_post_draw
	var img_loading = vp.get_texture().get_image()
	if img_loading:
		img_loading.save_png("c:/gemini cli/games/test_loading_screenshot.png")
		print("Screenshot do LOADING salva em: c:/gemini cli/games/test_loading_screenshot.png")

	# 4. Aguardar conclusão do loading e transição para o mapa 3D
	print("[4/4] Aguardando conclusão do loading e transição para mapa 3D...")
	var max_wait_frames = 400
	while max_wait_frames > 0 and current_scene and current_scene.name == "LoadingScreen":
		max_wait_frames -= 1
		await process_frame
		await physics_frame

	print("Cena atual no jogo após carregamento: ", current_scene.name if current_scene else "null")
	
	# Aguardar alguns frames para spawn e posicionamento
	for i in range(30):
		await process_frame
		await physics_frame

	var cam = vp.get_camera_3d()
	if cam:
		print("Câmera 3D ativa: ", cam.get_path(), " current: ", cam.current)
	else:
		print("ALERTA: Nenhuma câmera 3D ativa!")

	var p = root.find_child("Player*", true, false)
	if p:
		print("Player encontrado: ", p.name, " em ", p.global_position)

	await RenderingServer.frame_post_draw
	var img_game = vp.get_texture().get_image()
	if img_game:
		img_game.save_png("c:/gemini cli/games/test_game_after_loading.png")
		print("Screenshot do JOGO FINAL salva em: c:/gemini cli/games/test_game_after_loading.png")

	quit(0)
