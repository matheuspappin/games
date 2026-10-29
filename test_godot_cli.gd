extends MainLoop

const WeaponModifier = preload("res://scripts/weapons/weapon_modifier.gd")
const CamoRegistry = preload("res://scripts/weapons/camo_registry.gd")
const SaveSystem = preload("res://scripts/systems/save_system.gd")

func _process(_delta: float) -> bool:
	var f = FileAccess.open("C:/gemini cli/games/test_output.txt", FileAccess.WRITE)
	var log_msg = func(txt: String):
		print(txt)
		if f: f.store_line(txt)

	log_msg.call("========================================================")
	log_msg.call("  TESTANDO GUNSMITH & PERSONALIZAÇÃO DE ARMAS ESTILO COD")
	log_msg.call("========================================================")
	
	# 1. Testar CamoRegistry
	var camos = CamoRegistry.get_all_camos()
	assert(camos.size() == 6, "Deveriam existir 6 camuflagens cadastradas!")
	log_msg.call("✔ CamoRegistry validado: 6 camuflagens encontradas.")
	for c in camos:
		log_msg.call("   • %s (%s) - Cor: %s" % [c["name"], c["id"], c["albedo"]])

	# 2. Testar Acessórios
	var att_ids = [
		"optic_red_dot", "optic_holo", "optic_sniper",
		"muzzle_suppressor", "muzzle_compensator",
		"mag_extended", "ammo_fmj"
	]
	var loaded_atts: Array[AttachmentData] = []
	for a_id in att_ids:
		var att = WeaponModifier.get_attachment_resource(a_id)
		assert(att != null, "Falha ao carregar acessório: " + a_id)
		loaded_atts.append(att)
		log_msg.call("✔ Acessório carregado: %s [Slot %d]" % [att.attachment_name, att.slot])

	# 3. Testar Modificador de Armas
	var base_ak = load("res://resources/weapons/ak47.tres") as WeaponData
	assert(base_ak != null, "Falha ao carregar ak47.tres!")
	log_msg.call("✔ AK-47 Base: Dano %d | Pente %d | Recuo %s | ADS %.2fs" % [
		base_ak.damage_close, base_ak.magazine_capacity, base_ak.recoil_kick, base_ak.ads_time
	])

	# Equipar Red Dot + Silenciador + Pente Estendido
	var my_atts: Array[AttachmentData] = [
		WeaponModifier.get_attachment_resource("optic_red_dot"),
		WeaponModifier.get_attachment_resource("muzzle_suppressor"),
		WeaponModifier.get_attachment_resource("mag_extended")
	]
	var mod_ak = WeaponModifier.apply_attachments(base_ak, my_atts)
	assert(mod_ak != null, "Falha ao aplicar modificadores!")
	assert(mod_ak.magazine_capacity == 45, "Pente estendido deveria ser 45!")
	assert(mod_ak.has_optic == true, "Deveria ter óptica ativa!")
	assert(mod_ak.damage_falloff_end < base_ak.damage_falloff_end, "Silenciador deveria reduzir alcance!")

	log_msg.call("✔ AK-47 Modificada com Gunsmith:")
	log_msg.call("   • Dano: %d" % mod_ak.damage_close)
	log_msg.call("   • Pente: %d (Reserva: %d)" % [mod_ak.magazine_capacity, mod_ak.reserve_ammo_max])
	log_msg.call("   • Recuo: %s" % mod_ak.recoil_kick)
	log_msg.call("   • ADS: %.2fs" % mod_ak.ads_time)
	log_msg.call("   • Tem Óptica: %s (Tipo %d)" % [mod_ak.has_optic, mod_ak.optic_type])

	# 4. Testar Cálculo de Estatísticas da UI (Barras COD)
	var ui_stats = WeaponModifier.calculate_ui_stats(base_ak, my_atts)
	log_msg.call("✔ Estatísticas para barras da UI (0 a 100):")
	log_msg.call("   • Dano: %d / 100" % ui_stats["damage"])
	log_msg.call("   • Precisão: %d / 100" % ui_stats["accuracy"])
	log_msg.call("   • Alcance: %d / 100" % ui_stats["range"])
	log_msg.call("   • Controle de Recuo: %d / 100" % ui_stats["recoil_control"])
	log_msg.call("   • Mobilidade: %d / 100" % ui_stats["mobility"])
	log_msg.call("   • Silenciado: %s" % ui_stats["suppressed"])

	# 5. Testar Persistência no SaveSystem
	var p_data = SaveSystem.load_player_data()
	p_data["loadouts"][0]["primary_camo"] = "gold"
	p_data["loadouts"][0]["primary_optic"] = "optic_red_dot"
	p_data["loadouts"][0]["primary_muzzle"] = "muzzle_suppressor"
	p_data["loadouts"][0]["primary_mag"] = "mag_extended"
	var save_ok = SaveSystem.save_player_data(p_data)
	assert(save_ok, "Falha ao salvar player_data!")
	
	var reloaded = SaveSystem.load_player_data()
	assert(reloaded["loadouts"][0]["primary_camo"] == "gold", "Camo salva deveria ser gold!")
	log_msg.call("✔ Persistência no SaveSystem testada e validada com sucesso.")

	log_msg.call("========================================================")
	log_msg.call("  TODOS OS TESTES DO GUNSMITH PASSARAM COM SUCESSO! 🎯")
	log_msg.call("========================================================")
	if f: f.close()
	return true
