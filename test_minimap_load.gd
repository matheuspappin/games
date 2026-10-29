extends MainLoop

func _process(_delta: float) -> bool:
	var f = FileAccess.open("C:/gemini cli/games/test_minimap_output.txt", FileAccess.WRITE)
	var log_msg = func(txt: String):
		print(txt)
		if f: f.store_line(txt)

	log_msg.call("========================================================")
	log_msg.call("  TESTANDO COMPILAÇÃO & CARREGAMENTO DO MINIMAP HUD")
	log_msg.call("========================================================")

	var hud_scene = load("res://scenes/ui/minimap_hud.tscn")
	assert(hud_scene != null, "Falha ao carregar scenes/ui/minimap_hud.tscn!")
	log_msg.call("✔ scenes/ui/minimap_hud.tscn carregado com sucesso!")

	var hud_inst = hud_scene.instantiate()
	assert(hud_inst != null, "Falha ao instanciar MinimapHUD!")
	log_msg.call("✔ MinimapHUD instanciado com sucesso!")

	# Validar dados de Nuketown BO1 e BO3
	assert(hud_inst.bo1_buildings.size() > 0, "Plantas de BO1 devem ter edifícios!")
	assert(hud_inst.bo3_buildings.size() > 0, "Plantas de BO3 devem ter edifícios!")
	log_msg.call("✔ Plantas esquemáticas validadas:")
	log_msg.call("   • BO1: %d edifícios, %d veículos, %d cercas" % [hud_inst.bo1_buildings.size(), hud_inst.bo1_vehicles.size(), hud_inst.bo1_fences.size()])
	log_msg.call("   • BO3: %d edifícios, %d veículos, %d cercas" % [hud_inst.bo3_buildings.size(), hud_inst.bo3_vehicles.size(), hud_inst.bo3_fences.size()])

	# Testar projeção matemática de coordenadas
	var center = Vector2(108, 108)
	var p_pos = Vector3(0, 0, 0)
	var fwd = Vector2(0, -1)
	var right = Vector2(1, 0)

	var p_ahead = hud_inst._world_to_map_point(Vector3(0, 0, -10), p_pos, fwd, right, center)
	log_msg.call("✔ Teste Projeção Frente (0, 0, -10): %s -> Y esperado < 108 (acima na tela)" % str(p_ahead))
	assert(p_ahead.y < 108, "Objeto à frente deveria ficar acima no mapa!")

	var p_right = hud_inst._world_to_map_point(Vector3(10, 0, 0), p_pos, fwd, right, center)
	log_msg.call("✔ Teste Projeção Direita (10, 0, 0): %s -> X esperado > 108 (à direita na tela)" % str(p_right))
	assert(p_right.x > 108, "Objeto à direita deveria ficar à direita no mapa!")

	# Testar Edge Clamping
	var clamped = hud_inst._clamp_to_bounds(Vector2(500, 108), center, 98.0, 98.0)
	log_msg.call("✔ Teste Edge Clamping (500, 108): %s Clamped: %s" % [str(clamped["pos"]), str(clamped["clamped"])])
	assert(clamped["clamped"] == true, "Deveria estar clamped na borda!")
	assert(is_equal_approx(clamped["pos"].x, 108 + 98.0), "Deveria estar na borda direita!")

	# Testar MP Hud com o Minimapa integrado
	var mp_hud_scene = load("res://scenes/ui/mp_hud.tscn")
	assert(mp_hud_scene != null, "Falha ao carregar mp_hud.tscn!")
	var mp_hud_inst = mp_hud_scene.instantiate()
	assert(mp_hud_inst != null, "Falha ao instanciar MPHud!")
	var found_minimap = mp_hud_inst.find_child("MinimapHUD", true, false)
	assert(found_minimap != null, "MPHud deve conter o nó MinimapHUD!")
	log_msg.call("✔ MPHud contém MinimapHUD integrado perfeitamente!")

	hud_inst.queue_free()
	mp_hud_inst.queue_free()

	log_msg.call("========================================================")
	log_msg.call("  TODOS OS TESTES DO MINIMAPA PASSARAM COM SUCESSO! 🎯")
	log_msg.call("========================================================")
	if f: f.close()
	return true
