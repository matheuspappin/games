extends SceneTree

func _init() -> void:
	print("=== INICIANDO DIAGNÓSTICO DO ERRO DE TELA CINZA ===")
	call_deferred("_run_diagnosis")

func _run_diagnosis() -> void:
	var gm = root.get_node_or_null("GameManager")
	if not gm:
		print("AVISO: GameManager não é autoload! Tentando carregar...")
	
	# Testar carregamento da cena Nuketown BO3
	print("\n--- TESTE 1: Instanciando map_nuk3town_bo3.tscn ---")
	var map_bo3_scn = load("res://scenes/_world/map_nuk3town_bo3.tscn") as PackedScene
	if not map_bo3_scn:
		print("ERRO FATAL: Falha ao carregar map_nuk3town_bo3.tscn")
		quit(1)
		return
	
	var map_instance = map_bo3_scn.instantiate()
	root.add_child(map_instance)
	current_scene = map_instance
	
	# Processar alguns quadros para _ready() rodar
	for i in range(10):
		await process_frame
		await physics_frame
	
	print("\nVerificando nós na cena pós-inicialização:")
	var player = map_instance.find_child("Player*", true, false)
	if player:
		print("-> Player encontrado: ", player.name)
		print("   Posição global do Player: ", player.global_position)
		var cam = player.find_child("Camera", true, false) as Camera3D
		if cam:
			print("   Camera encontrada! Current: ", cam.current)
			print("   Posição global da Camera: ", cam.global_position)
			print("   Fov: ", cam.fov, " | Near: ", cam.near, " | Far: ", cam.far)
			print("   Cull Mask: ", cam.cull_mask)
		else:
			print("   ALERTA: Camera3D NÃO encontrada no player!")
			
		var viewmodel_rig = player.find_child("WeaponRig", true, false)
		if viewmodel_rig:
			print("   WeaponRig visível: ", viewmodel_rig.visible)
			for c in viewmodel_rig.get_children():
				print("     Sub-nó WeaponRig: ", c.name, " (visível: ", c.visible if c is CanvasItem or c is Node3D else "n/a", ")")
	else:
		print("-> ALERTA: Nenhum nó Player encontrado!")

	var nukemodel = map_instance.find_child("Nuk3townModel", true, false)
	if nukemodel:
		print("-> Nuk3townModel encontrado! Visível: ", nukemodel.visible)
		print("   Posição global do modelo: ", nukemodel.global_position)
	else:
		print("-> ALERTA: Nuk3townModel NÃO encontrado!")

	var env = map_instance.find_child("WorldEnvironment", true, false)
	if env:
		print("-> WorldEnvironment encontrado: ", env.name)
	else:
		print("-> ALERTA: WorldEnvironment NÃO encontrado!")
		
	# Checar spawns
	var sa = map_instance.find_child("Spawn_Alpha", true, false)
	var sb = map_instance.find_child("Spawn_Bravo", true, false)
	if sa:
		print("-> Spawn_Alpha global_position: ", sa.global_position)
	if sb:
		print("-> Spawn_Bravo global_position: ", sb.global_position)

	print("\n=== DIAGNÓSTICO CONCLUÍDO COM SUCESSO ===")
	quit(0)
