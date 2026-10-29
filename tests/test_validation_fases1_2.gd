extends SceneTree

func _init() -> void:
	call_deferred("_validate")

func _validate() -> void:
	print("==================================================")
	print(" VALIDAÇÃO OFICIAL: FASES 1 E 2 CONCLUÍDAS")
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

	print("[1/4] Verificando Spawn e Diferenciação Visual...")
	assert(bm.active_bots.size() >= 4, "Deveriam existir pelo menos 4 bots ativos")

	var allies_count = 0
	var enemies_count = 0
	for b in bm.active_bots:
		var npl = b.find_child("NameplateLabel", true, false) as Label3D
		assert(npl != null, "NameplateLabel ausente no bot " + b.name)
		print("-> Bot: %s | Time: %d | Nameplate: '%s' | Modulate: %s" % [b.name, b.get("team"), npl.text, npl.modulate])
		if b.get("team") == 0:
			allies_count += 1
			assert("[ALIADO]" in npl.text, "Bot Alpha deve conter [ALIADO]")
		else:
			enemies_count += 1
			assert("[INIMIGO]" in npl.text, "Bot Bravo deve conter [INIMIGO]")

	print("-> Foguete visual aprovado: %d Aliados e %d Inimigos com tags e cores distintas!" % [allies_count, enemies_count])

	print("\n[2/4] Testando Percepção Acústica de Tiros (notify_gunshot_heard)...")
	# Posicionar um bot Bravo em estado PATROL e disparar um tiro próximo
	var bravo_bot = null
	for b in bm.active_bots:
		if b.get("team") == 1:
			bravo_bot = b
			break
	assert(bravo_bot != null, "Bot Bravo não encontrado")
	bravo_bot.set("ai_state", 0) # PATROL

	# Notificar tiro do jogador a 15 metros do bot
	var gun_pos = bravo_bot.global_position + Vector3(10, 0, 10)
	bravo_bot.notify_gunshot_heard(gun_pos, 0)
	print("-> Bot Bravo estado pós-tiro: ", bravo_bot.get("ai_state"), " (2 = ALERT)")
	assert(bravo_bot.get("ai_state") == 2, "Bot deveria entrar em ALERT (2) ao ouvir tiro!")

	print("\n[3/4] Testando Percepção de Presença Próxima 360° (Situational Awareness)...")
	# Criar um combatente fictício simulando jogador parado atrás do bot Bravo
	var dummy_player = CharacterBody3D.new()
	dummy_player.name = "TestPlayerBody"
	dummy_player.add_to_group("player")
	var hp_comp = HealthComponent.new()
	hp_comp.name = "HealthComponent"
	hp_comp.max_health = 100
	hp_comp.current_health = 100
	dummy_player.add_child(hp_comp)
	map_instance.add_child(dummy_player)

	# Posicionar jogador a 3 metros atrás do bot
	var back_dir = bravo_bot.global_transform.basis.z # Atrás
	dummy_player.global_position = bravo_bot.global_position + back_dir * 3.0

	bravo_bot.set("ai_state", 0) # PATROL
	bravo_bot.target_combatant = null
	bravo_bot._detect_enemies(0.016)

	print("-> Bot Bravo detectou jogador atrás sem tiro? ", bravo_bot.target_combatant != null)
	assert(bravo_bot.target_combatant == dummy_player, "Bot deveria detectar jogador em raio de proximidade de 3.8m mesmo de costas!")
	dummy_player.queue_free()

	print("\n[4/4] Simulando 200 physics frames de deslocamento pelo novo grafo calibrado...")
	for frame in range(200):
		await physics_frame

	var stuck_count = 0
	for b in bm.active_bots:
		var vel_h = Vector2(b.velocity.x, b.velocity.z).length()
		var is_recovering = b.get("_is_recovering")
		var path_sz = b.get("_current_path").size() if b.get("_current_path") != null else 0
		print("-> %s | Time: %d | Pos: (%.1f, %.1f) | Vel: %.2f | Path size: %d | Recovering: %s" % [
			b.name, b.get("team"), b.global_position.x, b.global_position.z, vel_h, path_sz, str(is_recovering)
		])
		if vel_h < 0.05 and path_sz > 0 and not is_recovering:
			stuck_count += 1

	print("\n=== RESULTADO: Bots travados: %d de %d ===" % [stuck_count, bm.active_bots.size()])
	assert(stuck_count == 0, "Nenhum bot deve estar travado com velocidade 0 em meio ao caminho!")
	print(">>> TODAS AS VALIDAÇÕES DAS FASES 1 E 2 FORAM APROVADAS COM 100% DE SUCESSO! <<<")
	quit(0)
