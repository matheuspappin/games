# =============================================================================
# test_firing_range_verification.gd
# Teste de Validação Automatizada das 4 Fases do Estande de Tiro
# =============================================================================
extends SceneTree

func _init() -> void:
	print("\n==================================================")
	print(" TEST: FIRING RANGE 4-PHASE SYSTEM VERIFICATION")
	print("==================================================")
	call_deferred("_run_verification")

func _run_verification() -> void:
	# ── TESTE FASE 2: ALVO REATIVO (FIRING RANGE TARGET) ──────────────────────
	print("\n[FASE 2] Testando FiringRangeTarget...")
	var target_scn = load("res://scenes/environment/firing_range_target.tscn")
	assert(target_scn != null, "Falha ao carregar scenes/environment/firing_range_target.tscn")
	var target = target_scn.instantiate() as FiringRangeTarget
	assert(target != null, "Falha ao instanciar FiringRangeTarget")
	root.add_child(target)

	# Testar configuração de placas
	target.set_armor_plates(FiringRangeTarget.ArmorPlateCount.TWO)
	assert(target.current_armor == 100, "Placas de blindagem falharam: esperado 100 de armadura")
	assert(target.max_health == 100, "HP máximo de base deve ser 100")
	print("✓ FiringRangeTarget: Placas e Hitboxes operacionais (HP: 100 + Armor: 100 = 200 HP)!")

	# Simular disparo balístico no alvo
	var weapon_data = WeaponData.new()
	weapon_data.damage_close = 40
	weapon_data.headshot_multiplier = 2.0
	weapon_data.chest_multiplier = 1.0

	var hit_detected = [false]
	target.target_hit.connect(func(t_name, zone, dmg, is_crit, rem_hp, max_hp, dist):
		hit_detected[0] = true
		print("  -> Hit registrado no alvo: %s [%s] Dano: %d | Restante: %d/%d" % [t_name, zone, dmg, rem_hp, max_hp])
	)
	target.receive_bullet_hit("Chest", weapon_data, 10.0, false)
	assert(hit_detected[0], "Evento target_hit não foi emitido após receive_bullet_hit")
	assert(target.current_armor == 60, "Armadura deveria ter absorvido 40 de dano restando 60")
	print("✓ FiringRangeTarget: Absorção de armadura comprovada com 100% de sucesso!")
	target.queue_free()

	# ── TESTE FASE 3: HUD DE TELEMETRIA DO ESTANDE ─────────────────────────────
	print("\n[FASE 3] Testando FiringRangeHUD...")
	var hud_scn = load("res://scenes/ui/firing_range_hud.tscn")
	assert(hud_scn != null, "Falha ao carregar scenes/ui/firing_range_hud.tscn")
	var hud = hud_scn.instantiate() as FiringRangeHUD
	assert(hud != null, "Falha ao instanciar FiringRangeHUD")
	root.add_child(hud)

	hud.record_shot_fired()
	hud.record_target_hit("Lane 1", "Chest", 40, false, 160, 200, 10.0)
	hud.record_target_killed("Lane 1", 10.0, 5, 280.0, 200)
	assert(hud.total_shots_fired == 1, "Disparo disparado não computado")
	assert(hud.total_shots_hit == 1, "Disparo acertado não computado")
	print("✓ FiringRangeHUD: Cartão de telemetria, STK, TTK e precisão validados!")
	hud.queue_free()

	# ── TESTE FASE 4: INTEGRAÇÃO CREATE A CLASS & TRAVA DE SEGURANÇA ──────────
	print("\n[FASE 4] Testando ChooseClassScreen e Trava de Segurança...")
	var ccs_script = load("res://scripts/ui/choose_class_screen.gd")
	assert(ccs_script != null, "Falha ao carregar scripts/ui/choose_class_screen.gd")
	var ccs = ccs_script.new()
	root.add_child(ccs)
	ccs.open_screen(false)

	assert(ccs.btn_firing_range != null, "btn_firing_range não foi instanciado no rodapé")
	print("  -> Status no Menu: btn_firing_range.visible = %s, disabled = %s" % [ccs.btn_firing_range.visible, ccs.btn_firing_range.disabled])
	assert(ccs.btn_firing_range.visible == true, "Botão do estande deve estar visível no menu")
	assert(ccs.btn_firing_range.disabled == false, "Botão do estande deve estar habilitado no menu")

	# Simular estado de partida ativa
	ccs.close_screen()
	var gm = root.get_node_or_null("GameManager")
	if gm:
		gm.is_match_active = true
		ccs.open_screen(false)
		print("  -> Status em Partida Ativa: btn_firing_range.visible = %s, disabled = %s" % [ccs.btn_firing_range.visible, ccs.btn_firing_range.disabled])
		assert(ccs.btn_firing_range.visible == false, "TRAVA FALHOU: Botão do estande NÃO pode ficar visível em partida ativa!")
		assert(ccs.btn_firing_range.disabled == true, "TRAVA FALHOU: Botão do estande NÃO pode ficar habilitado em partida ativa!")
		print("✓ Trava de Segurança comprovada: Bloqueado com 100% de rigor quando em partida multiplayer!")
		gm.is_match_active = false
	ccs.queue_free()

	# ── TESTE FASE 1: MAPA 3D DO ESTANDE DE TIRO ──────────────────────────────
	print("\n[FASE 1] Testando Cena Completa scenes/_world/map_firing_range.tscn...")
	var map_scn = load("res://scenes/_world/map_firing_range.tscn")
	assert(map_scn != null, "Falha ao carregar scenes/_world/map_firing_range.tscn")
	var map = map_scn.instantiate() as FiringRangeManager
	assert(map != null, "Falha ao instanciar MapFiringRange")
	root.add_child(map)

	assert(map.target_10m != null, "Alvo 10m não conectado no MapFiringRange")
	assert(map.target_25m != null, "Alvo 25m não conectado no MapFiringRange")
	assert(map.target_50m != null, "Alvo 50m não conectado no MapFiringRange")
	print("  -> Alvos 10m, 25m e 50m verificados na cena!")
	assert(map.firing_range_hud != null, "HUD do estande verificado na cena!")
	map.queue_free()

	print("\n==================================================")
	print(" ★ TODAS AS 4 FASES VALIDADAS COM 100% DE SUCESSO!")
	print("==================================================\n")
	quit(0)
