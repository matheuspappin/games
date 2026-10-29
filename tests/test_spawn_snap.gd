extends SceneTree

func _init() -> void:
	print("=== TESTANDO POSIÇÃO DO PLAYER NAS DUAS NUKETOWNS ===")
	call_deferred("_run_test")

func _run_test() -> void:
	# Testar Nuk3town BO3
	print("\n--- 1. Testando Spawn na Nuk3town BO3 ---")
	var scn_bo3 = load("res://scenes/_world/map_nuk3town_bo3.tscn") as PackedScene
	var map_bo3 = scn_bo3.instantiate()
	root.add_child(map_bo3)
	current_scene = map_bo3

	var net1 = map_bo3.find_child("NetworkManager", true, false)
	if net1:
		net1.start_local_match()

	for i in range(15):
		await process_frame
		await physics_frame

	var p1 = map_bo3.find_child("Player_1", true, false)
	if p1:
		print("Player_1 posição inicial: ", p1.global_position)
		for f in range(30):
			await process_frame
			await physics_frame
		print("Player_1 posição após 30 frames: ", p1.global_position)
		print("Player_1 no chão? ", p1.is_on_floor() if p1.has_method("is_on_floor") else "n/a")
	else:
		print("Player_1 não foi criado!")

	map_bo3.queue_free()
	await process_frame
	await process_frame

	# Testar Nuketown Classic BO1
	print("\n--- 2. Testando Spawn na Nuketown Classic BO1 ---")
	var scn_bo1 = load("res://scenes/_world/map_nuketown_1v1.tscn") as PackedScene
	var map_bo1 = scn_bo1.instantiate()
	root.add_child(map_bo1)
	current_scene = map_bo1

	var net2 = map_bo1.find_child("NetworkManager", true, false)
	if net2:
		net2.start_local_match()

	for i in range(15):
		await process_frame
		await physics_frame

	var p2 = map_bo1.find_child("Player_1", true, false)
	if p2:
		print("Player_1 posição inicial: ", p2.global_position)
		for f in range(30):
			await process_frame
			await physics_frame
		print("Player_1 posição após 30 frames: ", p2.global_position)
		print("Player_1 no chão? ", p2.is_on_floor() if p2.has_method("is_on_floor") else "n/a")
	else:
		print("Player_1 não foi criado!")

	print("\n=== TESTE CONCLUÍDO ===")
	quit(0)
