extends SceneTree

const BotManagerScript = preload("res://scripts/ai/bot_manager.gd")

func _init() -> void:
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	print("==================================================================")
	print(" TESTE: CONTAGEM REGRESSIVA PRÉ-PARTIDA E ASSISTÊNCIAS ESTILO COD")
	print("==================================================================")

	# --- TESTE 1: GameModeManager - Contagem Regressiva e Ticks ---
	print("\n[1/4] Testando ciclo de Contagem Regressiva no GameModeManager...")
	var gmm = GameModeManager.new()
	root.add_child(gmm)
	gmm.countdown_duration = 3.0
	var ticks_received: Array[int] = []
	var results = {"countdown_ended": false}
	gmm.match_countdown_tick.connect(func(s): ticks_received.append(s))
	gmm.match_countdown_completed.connect(func(): results["countdown_ended"] = true)

	gmm.start_match(GameModeManager.GameMode.WAGER_1V1, 10, 10.0, false)
	assert(gmm.is_in_countdown(), "GameModeManager deveria estar em contagem regressiva!")
	assert(gmm.match_phase == GameModeManager.MatchPhase.COUNTDOWN, "Fase deveria ser COUNTDOWN")
	assert(not gmm.is_active, "is_active deveria ser falso durante a contagem")

	# Simular passagem de tempo
	gmm._process(1.0)
	assert(gmm.is_in_countdown(), "Ainda deveria estar em contagem após 1s")
	gmm._process(1.0)
	assert(gmm.is_in_countdown(), "Ainda deveria estar em contagem após 2s")
	gmm._process(1.1)
	assert(not gmm.is_in_countdown(), "Contagem deveria ter terminado!")
	assert(gmm.match_phase == GameModeManager.MatchPhase.ACTIVE, "Fase deveria ser ACTIVE")
	assert(gmm.is_active, "Partida deveria estar ativa após o término da contagem")
	assert(results["countdown_ended"], "Sinal match_countdown_completed deveria ter sido emitido")
	print("Ticks recebidos: ", ticks_received)
	assert(ticks_received.size() >= 3, "Deveria ter recebido ticks de contagem (3, 2, 1)")
	print("-> Teste 1 APROVADO: Contagem e transição de fase 100% funcionais!")
	gmm.queue_free()

	# --- TESTE 2: GameManager - Integração de Contagem e is_in_countdown() ---
	print("\n[2/4] Testando integração de Contagem no GameManager...")
	var gm = root.get_node_or_null("GameManager")
	assert(gm != null, "Autoload GameManager não encontrado")
	assert(gm.has_method("is_in_countdown"), "GameManager deve ter o método is_in_countdown()")
	assert(gm.has_method("register_assist"), "GameManager deve ter o método register_assist()")
	print("-> Teste 2 APROVADO: GameManager expõe APIs necessárias com sucesso!")

	# --- TESTE 3: Rastreamento de Dano e Sistema de Assistências no HealthComponent ---
	print("\n[3/4] Testando Lógica de Assistência e Histórico de Dano...")
	var dummy_victim = Node3D.new()
	dummy_victim.name = "Bot_Victim"
	dummy_victim.set("bot_id", 101)
	dummy_victim.set("team", 1) # Time Bravo (T)
	root.add_child(dummy_victim)

	var hp = HealthComponent.new()
	hp.name = "HealthComponent"
	hp.max_health = 100
	hp.current_health = 100
	dummy_victim.add_child(hp)
	await process_frame

	var assistant_node = Node3D.new()
	assistant_node.name = "Player_Assistant"
	assistant_node.add_to_group("player")
	assistant_node.set("peer_id", 1)
	assistant_node.set("team", 0) # Time Alpha (CT)
	root.add_child(assistant_node)

	var killer_node = Node3D.new()
	killer_node.name = "Ally_Killer"
	killer_node.set("bot_id", 102)
	killer_node.set("team", 0) # Time Alpha (CT)
	root.add_child(killer_node)

	var assist_captured: Dictionary = {}
	hp.assist_recorded.connect(func(ast_id, ast_team, vic_id, dmg, is_maj):
		assist_captured["assistant_id"] = ast_id
		assist_captured["assistant_team"] = ast_team
		assist_captured["victim_id"] = vic_id
		assist_captured["damage"] = dmg
		assist_captured["is_major"] = is_maj
	)

	# 3.1: Assistente causa 40 de dano
	hp.take_damage(40, Vector3.ZERO, "Chest", assistant_node)
	assert(hp.current_health == 60, "HP da vítima deveria ser 60")
	assert(hp.damage_records.has(1), "damage_records deveria registrar atacante ID 1")
	assert(hp.damage_records[1]["damage"] == 40, "Dano registrado para atacante 1 deveria ser 40")

	# 3.2: Killer causa 65 de dano fatal
	var initial_assists = gm.player_stats.get("assists", 0)
	hp.take_damage(65, Vector3.ZERO, "Chest", killer_node)
	assert(hp.current_health == 0, "Vítima deveria estar com 0 HP")
	assert(hp.is_dead, "Vítima deveria estar morta")

	# Validar assistência capturada
	assert(not assist_captured.is_empty(), "Uma assistência deveria ter sido registrada!")
	assert(assist_captured["assistant_id"] == 1, "ID do assistente deveria ser 1 (jogador local)")
	assert(assist_captured["damage"] == 40, "Dano de assistência deveria ser 40")
	assert(assist_captured["victim_id"] != 0, "ID da vítima deve ser válido")
	assert(gm.player_stats.assists == initial_assists + 1, "player_stats.assists deveria ter incrementado")
	print("Assistência capturada: ", assist_captured)
	print("Estatísticas atuais: ", gm.player_stats)
	print("-> Teste 3 APROVADO: Assistência e divisão Killer/Assistant 100% corretas!")

	# --- TESTE 4: Regra de Cura Completa Descartando Assistência (Regra CoD) ---
	print("\n[4/4] Testando descarte de assistência após cura de 100% de HP...")
	hp.revive()
	assert(hp.damage_records.is_empty(), "damage_records deveria estar limpo após revive()")
	
	hp.take_damage(30, Vector3.ZERO, "Chest", assistant_node)
	assert(hp.damage_records.has(1), "damage_records deveria conter atacante após dano")
	
	# Simular regeneração até 100%
	hp.heal(50)
	assert(hp.current_health == 100, "HP deveria estar em 100")
	hp._apply_regen(0.1) # Dispara verificação de 100% HP
	assert(hp.damage_records.is_empty(), "damage_records deveria ter sido limpo após recuperação de 100% de vida")
	print("-> Teste 4 APROVADO: Descarte de assistência por cura total validado com sucesso!")

	# Limpeza
	dummy_victim.queue_free()
	assistant_node.queue_free()
	killer_node.queue_free()

	print("\n==================================================================")
	print(" TODOS OS TESTES PASSARAM COM 100% DE SUCESSO! ")
	print("==================================================================")
	quit(0)
