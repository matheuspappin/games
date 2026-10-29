extends SceneTree

func _init() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	print("==================================================================")
	print(" VALIDATING SILENCER MINIMAP SUPPRESSION & COUNTDOWN FIXES")
	print("==================================================================")

	# ── TESTE 1: Mini-Mapa e Silenciador ──────────────────────────────────────────
	print("\n[1/3] Testando supressão de disparo com silenciador no Mini-Mapa HUD...")
	var minimap_scn = load("res://scenes/ui/minimap_hud.tscn") as PackedScene
	assert(minimap_scn != null, "Falha ao carregar minimap_hud.tscn")
	var minimap = minimap_scn.instantiate()
	root.add_child(minimap)
	await process_frame

	# Simular disparo INIMIGO SEM silenciador -> DEVE registrar ping
	var enemy_pos_unsuppressed = Vector3(10, 0, 10)
	var local_team = minimap._get_local_player_team()
	var enemy_team = 1 if local_team == 0 else 0

	minimap.notify_gunshot(enemy_pos_unsuppressed, enemy_team, false)
	assert(minimap.enemy_pings.size() == 1, "Tiro sem silenciador DEVE gerar ping no minimapa!")
	print("✔ Tiro sem silenciador gerou ping vermelho no radar como esperado.")

	# Simular disparo INIMIGO COM silenciador -> NÃO DEVE registrar ping
	var enemy_pos_suppressed = Vector3(15, 0, 15)
	minimap.notify_gunshot(enemy_pos_suppressed, enemy_team, true)
	assert(minimap.enemy_pings.size() == 1, "Tiro COM silenciador NÃO PODE gerar ping no minimapa!")
	print("✔ Tiro COM silenciador foi suprimido e NÃO apareceu no radar! (Regra CoD 100% OK)")
	minimap.queue_free()

	# ── TESTE 2: Percepção Acústica de Bots (enemy_ai) com Silenciador ─────────────
	print("\n[2/3] Testando raio acústico da IA para tiros silenciados...")
	var bot_scn = load("res://scenes/enemies/soldier_bot.tscn") as PackedScene
	assert(bot_scn != null, "Falha ao carregar soldier_bot.tscn")
	var bot = bot_scn.instantiate()
	root.add_child(bot)
	bot.global_position = Vector3(0, 0, 0)
	bot.set("team", 1) # Inimigo
	bot.set("ai_state", 0) # PATROL
	await process_frame

	# Tiro a 18 metros COM silenciador (fora do alcance de 8m do silenciador)
	var shoot_pos_far = Vector3(18, 0, 0)
	bot.notify_gunshot_heard(shoot_pos_far, 0, true) # Silenciado
	assert(bot.get("ai_state") == 0, "Bot NÃO deve ouvir tiro silenciado a 18m de distância!")
	print("✔ Bot permaneceu em patrulha (não ouviu tiro silenciado a 18m).")

	# Tiro a 5 metros COM silenciador (dentro do alcance acústico reduzido de 8m)
	var shoot_pos_close = Vector3(5, 0, 0)
	bot.notify_gunshot_heard(shoot_pos_close, 0, true)
	assert(bot.get("ai_state") == 2, "Bot DEVE ouvir tiro silenciado que ocorreu a 5m de distância!")
	print("✔ Bot detectou tiro silenciado a curta distância (5m).")
	bot.queue_free()

	# ── TESTE 3: Fluxo de Contagem Regressiva e Deploy sem Perda no Loading ───────
	print("\n[3/3] Testando deploy e contagem regressiva pré-partida...")
	var gm = root.get_node_or_null("GameManager")
	assert(gm != null, "GameManager autoload ausente")
	
	# Simular configuração que o Lobby define
	gm.pending_match_mode = GameModeManager.GameMode.TDM_6V6
	gm.pending_score_limit = 50
	gm.pending_stake = 0.0

	# Acionar deploy pós-carregamento como feito pelo NetworkManager ao instanciar o mapa
	gm.deploy_match_start()
	assert(gm.mode_manager != null, "ModeManager não inicializado")
	assert(gm.mode_manager.is_in_countdown(), "ModeManager deve iniciar em fase COUNTDOWN!")
	assert(gm.mode_manager.countdown_remaining > 0.0, "Tempo de contagem deve ser > 0 ao nascer no mapa!")
	print("✔ Contagem iniciada corretamente no deploy: %.1fs restantes com o mapa em exibição!" % gm.mode_manager.countdown_remaining)

	print("\n==================================================================")
	print(" TODOS OS TESTES PASSARAM COM 100% DE SUCESSO! 🎯")
	print("==================================================================")
	quit(0)
