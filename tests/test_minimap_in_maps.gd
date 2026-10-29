extends SceneTree

func _init() -> void:
	print("==================================================")
	print(" TEST: MINIMAP HUD RUNNING INSIDE NUKETOWN MAPS")
	print("==================================================")
	call_deferred("_run_tests")

func _run_tests() -> void:
	# 1. Testar Nuketown BO1 (Clássico)
	print("[1/2] Testando MinimapHUD no mapa Nuketown BO1...")
	var bo1_scn = load("res://scenes/_world/map_nuketown_1v1.tscn") as PackedScene
	assert(bo1_scn != null, "Falha ao carregar map_nuketown_1v1.tscn")
	var bo1_map = bo1_scn.instantiate()
	root.add_child(bo1_map)
	await process_frame
	await process_frame

	var hud_bo1 = bo1_map.find_child("MinimapHUD", true, false)
	assert(hud_bo1 != null, "MinimapHUD deve estar presente em Nuketown BO1")
	assert(hud_bo1.current_map_type == hud_bo1.MapType.NUKETOWN_BO1, "Mapa BO1 deve estar selecionado")
	print("-> MinimapHUD operacional em Nuketown BO1 (Modo Clássico detectado)!")
	bo1_map.queue_free()
	await process_frame

	# 2. Testar Nuketown 2065 (BO3)
	print("[2/2] Testando MinimapHUD no mapa Nuketown 2065 (BO3)...")
	var bo3_scn = load("res://scenes/_world/map_nuk3town_bo3.tscn") as PackedScene
	assert(bo3_scn != null, "Falha ao carregar map_nuk3town_bo3.tscn")
	var bo3_map = bo3_scn.instantiate()
	root.add_child(bo3_map)
	await process_frame
	await process_frame

	var hud_bo3 = bo3_map.find_child("MinimapHUD", true, false)
	assert(hud_bo3 != null, "MinimapHUD deve estar presente em Nuketown 2065")
	assert(hud_bo3.current_map_type == hud_bo3.MapType.NUKETOWN_BO3, "Mapa BO3 deve estar selecionado")
	print("-> MinimapHUD operacional em Nuketown 2065 (Modo Futurista detectado)!")
	bo3_map.queue_free()
	await process_frame

	print("==================================================")
	print(" AMBOS OS MAPAS RODARAM O MINIMAP HUD COM SUCESSO! 🎯")
	print("==================================================")
	quit(0)
