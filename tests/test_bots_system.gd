extends SceneTree

func _init() -> void:
	print("==================================================")
	print(" TEST: BOT MANAGER, SELECTOR & MAPS VERIFICATION")
	print("==================================================")
	call_deferred("_run_tests")

func _run_tests() -> void:
	# 1. Test MainMenu instantiation
	print("[1/4] Testando instanciação do MainMenu...")
	var menu_scn = load("res://scenes/ui/main_menu.tscn") as PackedScene
	assert(menu_scn != null, "Falha ao carregar main_menu.tscn")
	var menu = menu_scn.instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	await process_frame

	assert(menu.card_nuk3town != null, "CardNuk3town não encontrado no MainMenu")
	assert(menu.card_classic != null, "CardClassic não encontrado no MainMenu")
	assert(menu.btn_mode_bots != null, "BtnModeBots não encontrado")
	assert(menu.btn_mode_online != null, "BtnModeOnline não encontrado")
	assert(menu.lbl_bot_count != null, "LblBotCount não encontrado")

	# Simular ajuste de bots
	menu._set_bot_count(7)
	assert(menu.selected_bot_count == 7, "Falha ao selecionar 7 bots")
	assert(menu.lbl_bot_count.text.begins_with("7 BOTS"), "Texto de label de bots incorreto")

	# Simular troca de modo
	menu._set_play_mode(false)
	assert(menu.play_mode_bots == false, "Falha ao alternar para modo online")
	assert(menu.box_online_config.visible == true, "BoxOnlineConfig deveria estar visível")
	assert(menu.box_bots_config.visible == false, "BoxBotsConfig deveria estar oculto no modo online")

	# Voltar para bots
	menu._set_play_mode(true)
	assert(menu.play_mode_bots == true, "Falha ao alternar para modo bots")
	assert(menu.box_bots_config.visible == true, "BoxBotsConfig deveria estar visível no modo bots")
	print("-> MainMenu e Seletor aprovados com sucesso!")

	menu.queue_free()
	await process_frame

	# 2. Test SoldierBot instantiation and 5 difficulty levels
	print("[2/4] Testando instanciação do SoldierBot e 5 níveis de dificuldade...")
	var bot_scn = load("res://scenes/enemies/soldier_bot.tscn") as PackedScene
	assert(bot_scn != null, "Falha ao carregar soldier_bot.tscn")
	var bot = bot_scn.instantiate() as EnemyAI
	root.add_child(bot)
	bot.apply_difficulty(0) # Recruit
	assert(bot.damage_per_shot == 18, "Dano de recruta incorreto")
	assert(bot.reaction_time == 0.48, "Reaction time de recruta incorreto")
	bot.apply_difficulty(2) # Regular
	assert(bot.damage_per_shot == 26, "Dano de regular incorreto")
	assert(bot.reaction_time == 0.22, "Reaction time de regular incorreto")
	bot.apply_difficulty(4) # Expert
	assert(bot.damage_per_shot == 34, "Dano de especialista incorreto")
	assert(bot.reaction_time == 0.07, "Reaction time de especialista incorreto")
	print("-> SoldierBot e 5 níveis de dificuldade aprovados com sucesso!")
	bot.queue_free()
	await process_frame

	# 3. Test BotManager on Nuketown 2065
	print("[3/4] Testando BotManager no mapa Nuketown 2065 (BO3)...")
	var nuk3_scn = load("res://scenes/_world/map_nuk3town_bo3.tscn") as PackedScene
	assert(nuk3_scn != null, "Falha ao carregar map_nuk3town_bo3.tscn")
	var nuk3_map = nuk3_scn.instantiate()
	root.add_child(nuk3_map)
	await process_frame
	await process_frame

	var bm_nuk3 = nuk3_map.find_child("BotManager", true, false)
	assert(bm_nuk3 != null, "BotManager não encontrado em map_nuk3town_bo3")
	print("-> Nuketown 2065 integrado com BotManager com sucesso!")
	nuk3_map.queue_free()
	await process_frame

	# 4. Test BotManager on Nuketown Classic (BO1)
	print("[4/4] Testando BotManager no mapa Nuketown Clássica (BO1)...")
	var classic_scn = load("res://scenes/_world/map_nuketown_1v1.tscn") as PackedScene
	assert(classic_scn != null, "Falha ao carregar map_nuketown_1v1.tscn")
	var classic_map = classic_scn.instantiate()
	root.add_child(classic_map)
	await process_frame
	await process_frame

	var bm_classic = classic_map.find_child("BotManager", true, false)
	assert(bm_classic != null, "BotManager não encontrado em map_nuketown_1v1")
	print("-> Nuketown Clássica BO1 integrado com BotManager com sucesso!")
	classic_map.queue_free()
	await process_frame

	print("==================================================")
	print(" TODOS OS 4 TESTES FORAM CONCLUÍDOS COM 100% SUCESSO!")
	print("==================================================")
	quit(0)
