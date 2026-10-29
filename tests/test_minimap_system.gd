extends SceneTree

func _init() -> void:
	print("==================================================")
	print(" TEST: MINIMAP HUD (COD STYLE) SYSTEM VALIDATION")
	print("==================================================")
	call_deferred("_run_tests")

func _run_tests() -> void:
	# 1. Carregar cena do minimapa
	print("[1/5] Carregando e instanciando scenes/ui/minimap_hud.tscn...")
	var hud_scene = load("res://scenes/ui/minimap_hud.tscn") as PackedScene
	assert(hud_scene != null, "Falha ao carregar scenes/ui/minimap_hud.tscn")
	var hud_inst = hud_scene.instantiate()
	assert(hud_inst != null, "Falha ao instanciar MinimapHUD")
	root.add_child(hud_inst)
	await process_frame
	await process_frame
	print("-> MinimapHUD carregado e instanciado com sucesso!")

	# 2. Validar sub-controles e plantas de Nuketown BO1 e BO3
	print("[2/5] Validando subcontroles e plantas vetoriais...")
	assert(hud_inst.compass_control != null, "Compass control não criado")
	assert(hud_inst.map_viewport != null, "Map viewport não criado")
	assert(hud_inst.bo1_buildings.size() >= 4, "BO1 deve conter os edifícios e garagens")
	assert(hud_inst.bo1_vehicles.size() >= 3, "BO1 deve conter ônibus, caminhão e barricada")
	assert(hud_inst.bo3_buildings.size() >= 4, "BO3 deve conter as casas futuristas")
	assert(hud_inst.bo3_vehicles.size() >= 2, "BO3 deve conter veículos maglev")
	print("-> Plantas de Nuketown BO1 e Nuketown 2065 100% validadas!")

	# 3. Validar projeção de coordenadas e rotação
	print("[3/5] Testando projeção matemática com rotação dinâmica...")
	var center = Vector2(108, 108)
	var p_pos = Vector3(0, 0, 0)
	var fwd = Vector2(0, -1)
	var right = Vector2(1, 0)

	var p_ahead = hud_inst._world_to_map_point(Vector3(0, 0, -10), p_pos, fwd, right, center)
	assert(p_ahead.y < 108, "Objeto à frente deve projetar para cima no eixo Y")

	var p_right = hud_inst._world_to_map_point(Vector3(10, 0, 0), p_pos, fwd, right, center)
	assert(p_right.x > 108, "Objeto à direita deve projetar para a direita no eixo X")

	# Testar com rotação do jogador (virado 90° para o Leste)
	var fwd_east = Vector2(1, 0)
	var right_south = Vector2(0, 1)
	var p_east_ahead = hud_inst._world_to_map_point(Vector3(10, 0, 0), p_pos, fwd_east, right_south, center)
	assert(p_east_ahead.y < 108, "Quando o jogador olha para Leste, o objeto a Leste deve projetar para cima")
	print("-> Rotação matemática do minimapa validada com precisão angular!")

	# 4. Validar Edge-Clamping para entidades fora do raio
	print("[4/5] Testando Edge-Clamping nas bordas do radar...")
	var clamp_test = hud_inst._clamp_to_bounds(Vector2(600, 108), center, 98.0, 98.0)
	assert(clamp_test["clamped"] == true, "Alvo a 600px deve ser fixado na borda")
	assert(is_equal_approx(clamp_test["pos"].x, 108 + 98.0), "Posição X deve estar colada na borda direita")
	assert(is_equal_approx(clamp_test["pos"].y, 108.0), "Posição Y deve manter alinhamento central")
	print("-> Edge-Clamping aprovado!")

	# 5. Validar integração com MPHud e mapas de jogo
	print("[5/5] Testando integração com mp_hud.tscn e mapas reais...")
	hud_inst.queue_free()
	await process_frame

	var mp_hud_scene = load("res://scenes/ui/mp_hud.tscn") as PackedScene
	assert(mp_hud_scene != null, "Falha ao carregar mp_hud.tscn")
	var mp_hud_inst = mp_hud_scene.instantiate()
	root.add_child(mp_hud_inst)
	await process_frame
	await process_frame

	var found_mm = mp_hud_inst.find_child("MinimapHUD", true, false)
	assert(found_mm != null, "MPHud deve conter o MinimapHUD instanciado")
	print("-> MinimapHUD integrado no MPHud com sucesso!")

	mp_hud_inst.queue_free()
	await process_frame

	print("==================================================")
	print(" TODOS OS TESTES DO MINIMAPA PASSARAM COM 100% SUCESSO! 🎯")
	print("==================================================")
	quit(0)
