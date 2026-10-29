# =============================================================================
# test_bo6_perks.gd
# Teste automatizado do Sistema de Perks e Especialidades de Combate BO6
# =============================================================================
extends SceneTree

var log_file: FileAccess

func log_msg(msg: String) -> void:
	print(msg)
	if log_file:
		log_file.store_line(msg)
		log_file.flush()

func _init() -> void:
	log_file = FileAccess.open("res://perks_test_log.txt", FileAccess.WRITE)
	log_msg("=================================================================")
	log_msg("[TEST] INICIANDO TESTES DO SISTEMA DE PERKS BLACK OPS 6...")
	log_msg("=================================================================")

	var all_passed = true

	# 1. Teste de Instanciação e Banco de Dados de Vantagens
	log_msg("\n--- TESTE 1: Banco de Dados de Perks ---")
	var pm = PerkManager.new()
	pm.name = "PerkManager"
	if pm.PERK_DATABASE.size() >= 9:
		log_msg("  [PASS] Banco de perks carregado com %d vantagens." % pm.PERK_DATABASE.size())
	else:
		log_msg("  [FAIL] Banco de dados incompleto.")
		all_passed = false

	# 2. Teste de Sinergia BO6: ENFORCER (3 Vermelhos)
	log_msg("\n--- TESTE 2: Sinergia Enforcer (3 Vermelhos) ---")
	# fast_hands (Red), dexterity (Red), assassin (Red)
	pm.configure_loadout("fast_hands", "dexterity", "assassin")
	if pm.is_synergy_active and pm.has_specialty("enforcer"):
		log_msg("  [PASS] Sinergia Enforcer identificada com sucesso!")
	else:
		log_msg("  [FAIL] Falha ao identificar sinergia Enforcer. active_specialty=%s, is_synergy=%s" % [pm.active_specialty, pm.is_synergy_active])
		all_passed = false

	# 3. Teste de Sinergia BO6: RECON (3 Azuis)
	log_msg("\n--- TESTE 3: Sinergia Recon (3 Azuis) ---")
	# ghost (Blue), tracker (Blue), high_alert (Blue)
	pm.configure_loadout("ghost", "tracker", "high_alert")
	if pm.is_synergy_active and pm.has_specialty("recon"):
		log_msg("  [PASS] Sinergia Recon identificada com sucesso!")
	else:
		log_msg("  [FAIL] Falha ao identificar sinergia Recon.")
		all_passed = false

	# 4. Teste de Sinergia BO6: STRATEGIST (3 Verdes)
	log_msg("\n--- TESTE 4: Sinergia Strategist (3 Verdes) ---")
	# flak_jacket (Green), scavenger (Green), tac_mask (Green)
	pm.configure_loadout("flak_jacket", "scavenger", "tac_mask")
	if pm.is_synergy_active and pm.has_specialty("strategist"):
		log_msg("  [PASS] Sinergia Strategist identificada com sucesso!")
	else:
		log_msg("  [FAIL] Falha ao identificar sinergia Strategist.")
		all_passed = false

	# 5. Teste de Modificadores de Vantagens
	log_msg("\n--- TESTE 5: Modificadores e Multiplicadores ---")
	# Loadout Híbrido: flak_jacket, fast_hands, ninja
	pm.configure_loadout("flak_jacket", "fast_hands", "ninja", "recon")
	if not pm.is_synergy_active:
		log_msg("  [PASS] Loadout híbrido detectado sem sinergia automática (especialidade manual mantida).")

	# Teste Fast Hands (Recarga 30% mais rápida)
	var r_mult = pm.get_reload_speed_multiplier()
	if is_equal_approx(r_mult, 0.70):
		log_msg("  [PASS] Fast Hands reduz tempo de recarga para 70% (0.70x).")
	else:
		log_msg("  [FAIL] Multiplicador de recarga incorreto: %f" % r_mult)
		all_passed = false

	# Teste Flak Jacket (Dano explosivo reduzido em 50%)
	var exp_mult = pm.get_explosive_damage_multiplier()
	if is_equal_approx(exp_mult, 0.50):
		log_msg("  [PASS] Flak Jacket reduz dano explosivo para 50% (0.50x).")
	else:
		log_msg("  [FAIL] Multiplicador de explosão incorreto: %f" % exp_mult)
		all_passed = false

	# Teste Ninja (Passos silenciosos)
	var foot_mult = pm.get_footstep_volume_multiplier()
	if is_equal_approx(foot_mult, 0.0):
		log_msg("  [PASS] Ninja silencia volume de passos para 0.0x.")
	else:
		log_msg("  [FAIL] Multiplicador de passos incorreto: %f" % foot_mult)
		all_passed = false

	# 6. Teste de Adrenalina Enforcer
	log_msg("\n--- TESTE 6: Gatilho de Adrenalina Enforcer ao Abater Inimigo ---")
	pm.configure_loadout("fast_hands", "dexterity", "assassin")
	pm.on_enemy_eliminated(null)
	var spd_mult = pm.get_sprint_speed_multiplier()
	if is_equal_approx(spd_mult, 1.25):
		log_msg("  [PASS] Bônus de velocidade Enforcer ativo: 1.25x (+25% sprint).")
	else:
		log_msg("  [FAIL] Falha no bônus de velocidade Enforcer: %f" % spd_mult)
		all_passed = false

	# 7. Teste de Integração com HealthComponent (Dano Explosivo e Instant Regen)
	log_msg("\n--- TESTE 7: Integração HealthComponent + Flak Jacket ---")
	pm.configure_loadout("flak_jacket", "fast_hands", "ninja")
	var dummy_actor = Node3D.new()
	var hc = HealthComponent.new()
	hc.name = "HealthComponent"
	dummy_actor.add_child(hc)
	dummy_actor.add_child(pm)
	root.add_child(dummy_actor)

	# Tomar dano explosivo de 120 HP com Flak Jacket ativo
	hc.take_damage(120, Vector3.ZERO, "Chest", null, true)
	if hc.current_health == 40: # 100 - (120 * 0.5 = 60) = 40
		log_msg("  [PASS] Flak Jacket mitigou dano de 120 para 60 no HealthComponent (Restou 40 HP).")
	else:
		log_msg("  [FAIL] Cálculo de dano com Flak Jacket incorreto: HP atual = %d" % hc.current_health)
		all_passed = false

	# Testar Instant Regen
	hc.start_instant_regen()
	if hc.is_regenerating:
		log_msg("  [PASS] start_instant_regen() ativou cura imediata com sucesso.")
	else:
		log_msg("  [FAIL] start_instant_regen() não ativou regeneração.")
		all_passed = false

	dummy_actor.queue_free()

	log_msg("\n=================================================================")
	if all_passed:
		log_msg("[TEST RESULT] TODOS OS TESTES PASSARAM COM SUCESSO! (100% OK)")
	else:
		log_msg("[TEST RESULT] ALGUNS TESTES FALHARAM!")
	log_msg("=================================================================\n")

	quit(0 if all_passed else 1)
