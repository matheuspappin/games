extends SceneTree

const BotManagerScript = preload("res://scripts/ai/bot_manager.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================")
	print(" TESTE: BOTS, SPAWNS NOS QUINTAIS E DETECÇÃO DE DANO")
	print("==================================================")

	# 1. Testar SoldierBot com arma 3D
	print("[1/4] Testando instanciação do SoldierBot com arma...")
	var bot_scn = load("res://scenes/enemies/soldier_bot.tscn") as PackedScene
	assert(bot_scn != null, "Falha ao carregar soldier_bot.tscn")
	var bot = bot_scn.instantiate() as EnemyAI
	root.add_child(bot)
	await process_frame
	
	var rifle = bot.find_child("BotRifle3D", true, false)
	assert(rifle != null, "BotRifle3D não encontrado no SoldierBot")
	assert(bot.has_method("notify_attacked"), "notify_attacked não encontrado no EnemyAI")
	assert(bot.has_method("take_damage"), "take_damage não encontrado no EnemyAI")
	print("-> SoldierBot com arma 3D e combate aprovado com sucesso!")

	# 2. Testar mapa Nuk3town BO3 e posições de spawn nos quintais
	print("[2/4] Testando Spawns nos quintais da Nuk3town BO3...")
	var map_scn = load("res://scenes/_world/map_nuk3town_bo3.tscn") as PackedScene
	assert(map_scn != null, "Falha ao carregar map_nuk3town_bo3.tscn")
	var map = map_scn.instantiate()
	root.add_child(map)
	for i in range(12):
		await process_frame

	var spawn_a = map.find_child("Spawn_Alpha", true, false) as Node3D
	var spawn_b = map.find_child("Spawn_Bravo", true, false) as Node3D
	assert(spawn_a != null, "Spawn_Alpha não encontrado")
	assert(spawn_b != null, "Spawn_Bravo não encontrado")

	# Verificar que estão nos quintais (X > 35 para Alpha / Casa Azul, X < -35 para Bravo / Casa Laranja)
	print("Posição Spawn_Alpha (Casa Azul / Quintal): ", spawn_a.global_position)
	print("Posição Spawn_Bravo (Casa Laranja / Quintal): ", spawn_b.global_position)
	assert(spawn_a.global_position.x > 35.0, "Spawn_Alpha deveria estar no quintal da Casa Azul (X > 35)")
	assert(spawn_b.global_position.x < -35.0, "Spawn_Bravo deveria estar no quintal da Casa Laranja (X < -35)")
	print("-> Spawns autenticados nos quintais e atrás das casas com sucesso!")

	# 3. Testar BotManager gerando bots nos quintais
	var bm = map.find_child("BotManager", true, false)
	assert(bm != null, "BotManager não encontrado no mapa")
	print("Total bots ativos no mapa: ", bm.active_bots.size())
	assert(bm.active_bots.size() > 0, "Deveria haver bots gerados")
	for b in bm.active_bots:
		var team_name = "Alpha" if b.team == 0 else "Bravo"
		print("Bot %s [%s] em posição: %s" % [b.name, team_name, b.global_position])
		# Certificar que não estão caindo no vazio ou no meio da rua
		assert(abs(b.global_position.x) > 20.0, "Bot deveria nascer na área das casas/quintais, não no meio da rua!")
	print("-> Posições de spawn dos bots validadas com 100% de precisão!")

	# 4. Testar sistema de acerto e dano no bot (incluindo fogo amigo e eliminação de double kill)
	print("[4/4] Testando combate: dano inimigo, proteção de fogo amigo e morte única...")
	var target_bot = bm.active_bots[0]
	var initial_hp = target_bot.current_health

	# 4.1 Fogo amigo: bot aliado (mesmo time) não causa dano
	var ally_bot = bot_scn.instantiate() as EnemyAI
	ally_bot.team = target_bot.team
	root.add_child(ally_bot)
	target_bot.take_damage(30, Vector3.FORWARD, ally_bot)
	print("HP após tiro de aliado: %d (esperado: %d)" % [target_bot.current_health, initial_hp])
	assert(target_bot.current_health == initial_hp, "Bot aliado não deveria sofrer dano de fogo amigo!")

	# 4.2 Dano inimigo: bot de time oposto causa dano
	bot.team = 1 if target_bot.team == 0 else 0
	target_bot.take_damage(35, Vector3.FORWARD, bot)
	print("HP inicial: %d | HP após tiro inimigo: %d" % [initial_hp, target_bot.current_health])
	assert(target_bot.current_health == initial_hp - 35, "Dano inimigo não foi subtraído corretamente")
	assert(target_bot.ai_state == EnemyAI.AIState.COMBAT, "Bot deveria ter entrado em COMBAT após ser atacado por inimigo")

	# 4.3 Morte do bot: deve registrar estado DEAD e ignorar dano/chamadas subsequentes (sem double kill)
	target_bot.take_damage(200, Vector3.FORWARD, bot)
	assert(target_bot.ai_state == EnemyAI.AIState.DEAD, "Bot deveria estar morto após dano fatal")
	# Chamada subsequente acidental não deve reexecutar _die nem duplicar kill
	target_bot._die(Vector3.FORWARD)
	assert(target_bot.ai_state == EnemyAI.AIState.DEAD, "Guarda de morte deve manter estado DEAD")
	print("-> Sistema de dano, proteção a fogo amigo e morte única aprovados com 100% de sucesso!")

	print("==================================================")
	print(" TODOS OS TESTES PASSARAM COM SUCESSO! ")
	print("==================================================")
	quit(0)
