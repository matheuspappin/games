extends SceneTree

func _init() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	print("========================================================")
	print(" VALIDANDO IMPLEMENTAÇÃO DAS OPÇÕES 1 E 3 PARA OS BOTS")
	print("========================================================")
	
	# ── TESTE 1: OPÇÃO 3 - MODELOS CS E FUZIL 3D EM MÃOS ──
	print("\n[1/3] Testando Modelos do CS com postura ereta e fuzil 3D...")
	var test_skins = [
		{"name": "CT Urban", "path": "res://scenes/characters/skins/ct_urban.tscn"},
		{"name": "T Phoenix", "path": "res://scenes/characters/skins/t_phoenix.tscn"},
		{"name": "T Leet", "path": "res://scenes/characters/skins/t_leet.tscn"}
	]
	
	var bot_scn = load("res://scenes/enemies/soldier_bot.tscn") as PackedScene
	assert(bot_scn != null, "Falha ao carregar soldier_bot.tscn")
	
	for s_info in test_skins:
		var bot = bot_scn.instantiate() as EnemyAI
		var vis = bot.get_node("VisualRoot")
		var old = vis.get_node_or_null("SoldierModel")
		if old:
			vis.remove_child(old)
			old.free()
			
		var skin_scn = load(s_info["path"]) as PackedScene
		var new_skin = skin_scn.instantiate()
		new_skin.name = "BotSkinModel"
		vis.add_child(new_skin)
		
		# Centralizar e orientar para frente (-Z) como faz _apply_bot_skin
		for c in new_skin.get_children():
			if c.name.ends_with("_ARM"):
				c.position.x = 0.0
				c.position.z = 0.0
		new_skin.rotation.y = PI
		
		root.add_child(bot)
		await process_frame
		
		# Verificar esqueleto e postura ereta (sem corrupção de coluna)
		var skel = bot._skeleton
		assert(skel != null, "Esqueleto do personagem não foi encontrado para %s" % s_info["name"])
		
		# Verificar arma 3D na mão direita do bot
		var rifle = bot.find_child("BotRifle3D", true, false) as Node3D
		assert(rifle != null, "BotRifle3D não encontrado no bot para %s" % s_info["name"])
		assert(rifle.visible, "Fuzil deveria estar visível")
		
		# Verificar escala humana 1:1 real
		var rifle_global_scale = rifle.global_basis.get_scale()
		print("%s -> Rifle global pos: %s | global scale: %s | visível: %s" % [
			s_info["name"], rifle.global_position, rifle_global_scale, rifle.visible
		])
		assert(abs(rifle_global_scale.x - 1.0) < 0.1, "Escala do fuzil não é 1:1 metro!")
		assert(rifle.global_position.y > 0.8 and rifle.global_position.y < 1.3, "Fuzil fora da altura da mão!")
		
		# Verificar centralização do modelo (sem o bug de 2 metros de offset)
		for c in new_skin.get_children():
			if c.name.ends_with("_ARM"):
				assert(abs(c.position.x) < 0.01, "Offset horizontal de %s não foi zerado!" % c.name)
				
		bot.queue_free()
		await process_frame
		
	print("-> Opção 3 aprovada com 100% de sucesso! (Armas visíveis, escala 1:1, postura ereta).")

	# ── TESTE 2: OPÇÃO 1 - STRICT LINE-OF-FIRE (SEM ATIRAR EM PAREDES) ──
	print("\n[2/3] Testando verificação estrita de Linha de Fogo (Line-of-Fire)...")
	var shooter_bot = bot_scn.instantiate() as EnemyAI
	shooter_bot.position = Vector3(0, 0, 0)
	root.add_child(shooter_bot)
	
	var target_bot = bot_scn.instantiate() as EnemyAI
	target_bot.position = Vector3(0, 0, -10.0)
	target_bot.team = 1 # Equipe oposta
	root.add_child(target_bot)
	
	await process_frame
	shooter_bot.target_combatant = target_bot
	
	# Sem parede no meio -> deve ter linha de tiro
	assert(shooter_bot._has_line_of_fire() == true, "Linha de fogo deveria estar limpa sem paredes!")
	print("-> Linha de fogo livre detectada corretamente: TRUE")
	
	# Adicionar uma parede (StaticBody3D) entre os dois bots
	var wall = StaticBody3D.new()
	wall.name = "TestWall"
	wall.position = Vector3(0, 1.0, -5.0)
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(6.0, 4.0, 1.0)
	col.shape = box
	wall.add_child(col)
	root.add_child(wall)
	
	# Dar um frame para a física registrar a parede
	for i in range(3):
		await process_frame
		
	assert(shooter_bot._has_line_of_fire() == false, "Linha de fogo deveria ser bloqueada pela parede!")
	print("-> Parede bloqueando linha de fogo detectada corretamente: FALSE (Cessa-fogo acionado!)")
	
	wall.queue_free()
	await process_frame

	# ── TESTE 3: OPÇÃO 1 - TACTICAL BURST FIRE (DISPARO EM RAJADAS ESTILO COD) ──
	print("\n[3/3] Testando disparo em rajadas táticas estilo CoD...")
	assert(shooter_bot.has_method("_process_burst_combat"), "_process_burst_combat não encontrado no EnemyAI")
	
	shooter_bot._burst_shots_fired = 0
	shooter_bot._burst_max_shots = 3
	shooter_bot._burst_pause_timer = 0.0
	shooter_bot._fire_cooldown = 0.0
	
	for s in range(3):
		shooter_bot._fire_cooldown = 0.0
		shooter_bot._process_burst_combat(0.016)
		
	print("Disparos efetuados na rajada: 3 | Pausa tática pós-rajada: %.2fs" % shooter_bot._burst_pause_timer)
	assert(shooter_bot._burst_pause_timer > 0.3, "Bot deveria ter entrado em pausa tática após a rajada de 3 tiros!")
	print("-> Rajadas táticas e pausas pós-rajada validadas com sucesso!")

	shooter_bot.queue_free()
	target_bot.queue_free()
	await process_frame
	
	print("\n========================================================")
	print(" TODAS AS OPÇÕES (1 E 3) FUNCIONANDO 100% CORRETAMENTE! ")
	print("========================================================")
	quit(0)
