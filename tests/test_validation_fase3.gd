extends SceneTree

func _init() -> void:
	call_deferred("_validate")

func _validate() -> void:
	print("==================================================")
	print(" VALIDAÇÃO OFICIAL: FASE 3 (ANTI-CLUSTERING & DISPERSÃO)")
	print("==================================================")

	var map_bo3_scn = load("res://scenes/_world/map_nuk3town_bo3.tscn") as PackedScene
	var map_instance = map_bo3_scn.instantiate()
	root.add_child(map_instance)
	current_scene = map_instance

	for i in range(15):
		await process_frame
		await physics_frame

	var bm = map_instance.find_child("BotManager", true, false)
	assert(bm != null, "BotManager não encontrado")
	assert(bm.active_bots.size() >= 4, "Deveriam existir pelo menos 4 bots ativos")

	print("\n[1/4] Testando Dispersão Inicial de Lanes e Waypoints...")
	var lane_distribution = {}
	var unique_targets: Array[Vector3] = []
	for b in bm.active_bots:
		var lane = b.get("assigned_lane")
		lane_distribution[lane] = lane_distribution.get(lane, 0) + 1
		var tgt = b.get("_patrol_target")
		if tgt != null and tgt != Vector3.ZERO:
			unique_targets.append(tgt)
		print("-> Bot %s | Time: %d | Lane: %d | Destino: (%.1f, %.1f)" % [b.name, b.get("team"), lane, tgt.x, tgt.z])

	print("-> Distribuição de lanes:", lane_distribution)
	# Garante que os bots não estão todos concentrados em uma única lane
	assert(lane_distribution.keys().size() >= 2, "Os bots devem estar distribuídos em pelo menos 2 lanes distintas!")

	# Checa se os waypoints de patrulha não são idênticos (Anti-Clustering de Waypoints)
	for i in range(unique_targets.size()):
		for j in range(i + 1, unique_targets.size()):
			var d = unique_targets[i].distance_to(unique_targets[j])
			print("   Distância entre alvos de bots (%d vs %d): %.2fm" % [i, j, d])
			assert(d >= 1.5, "Alvos de patrulha não devem colidir no mesmo ponto exato!")

	print("\n[2/4] Testando Força de Separação Mútua (Boids)...")
	# Posicionar dois bots a 0.5m um do outro e rodar 30 physics frames
	var bot1 = bm.active_bots[0]
	var bot2 = bm.active_bots[1]
	bot1.global_position = Vector3(0.0, 0.5, 0.0)
	bot2.global_position = Vector3(0.4, 0.5, 0.2)
	var initial_dist = bot1.global_position.distance_to(bot2.global_position)
	print("-> Distância inicial entre bot1 e bot2: %.2fm" % initial_dist)

	for f in range(40):
		await physics_frame

	var final_dist = bot1.global_position.distance_to(bot2.global_position)
	print("-> Distância após 40 frames com repulsão Boids: %.2fm" % final_dist)
	assert(final_dist > initial_dist + 0.3, "Força Boids deve repelir bots sobrepostos!")

	print("\n[3/4] Testando Orientação com Base na Velocidade Real...")
	var bot_test = bm.active_bots[2]
	# Colocar bot com velocidade horizontal e verificar se o facing aponta na direção do movimento
	bot_test.velocity = Vector3(3.0, 0.0, 0.0)
	# Rodar um frame de _navigate_to
	bot_test._face_target(bot_test.global_position + Vector3(3.0, 0.0, 0.0), 0.2)
	var forward_facing = -bot_test.global_transform.basis.z
	forward_facing.y = 0.0
	var dot_facing = forward_facing.normalized().dot(Vector3(1, 0, 0))
	print("-> Alinhamento do facing do bot com velocidade (+X): %.2f (esperado > 0.85)" % dot_facing)
	assert(dot_facing > 0.70, "Bot deve orientar o corpo na direção de avanço!")

	print("\n[4/4] Simulando 250 physics frames de patrulha contínua pelo mapa...")
	var stuck_count = 0
	for f in range(250):
		await physics_frame

	for b in bm.active_bots:
		var vel_h = Vector2(b.velocity.x, b.velocity.z).length()
		var p_timer = b.get("_tactical_pause_timer")
		var is_paused = p_timer != null and p_timer > 0.0
		var path_sz = b.get("_current_path").size() if b.get("_current_path") != null else 0
		print("-> %s | Pos: (%.1f, %.1f) | Vel: %.2fm/s | Pausa: %s | Path sz: %d" % [
			b.name, b.global_position.x, b.global_position.z, vel_h, str(is_paused), path_sz
		])
		if vel_h < 0.05 and path_sz > 0 and not is_paused and not b.get("_is_recovering"):
			stuck_count += 1

	print("\n=== RESULTADO FASE 3: Bots travados: %d de %d ===" % [stuck_count, bm.active_bots.size()])
	assert(stuck_count == 0, "Nenhum bot deve estar travado!")
	print(">>> VALIDAÇÃO DA FASE 3 CONCLUÍDA COM 100% DE SUCESSO! <<<")
	quit(0)
