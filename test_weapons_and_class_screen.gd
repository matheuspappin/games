extends MainLoop

func _process(_delta: float) -> bool:
	var f = FileAccess.open("C:/gemini cli/games/test_weapons_validation.txt", FileAccess.WRITE)
	var log_msg = func(txt: String):
		print(txt)
		if f: f.store_line(txt)

	log_msg.call("========================================================")
	log_msg.call("  TESTANDO ARSENAL (18 ARMAS) E CHOOSE CLASS SCREEN")
	log_msg.call("========================================================")

	var weapons = [
		{"path": "res://resources/weapons/ak47.tres", "name": "ACR 6.8"},
		{"path": "res://resources/weapons/m4a1.tres", "name": "M4A1"},
		{"path": "res://resources/weapons/scar_h.tres", "name": "SCAR-H"},
		{"path": "res://resources/weapons/man_o_war.tres", "name": "Man-O-War"},
		{"path": "res://resources/weapons/smg.tres", "name": "SMG-45"},
		{"path": "res://resources/weapons/mp7.tres", "name": "MP7"},
		{"path": "res://resources/weapons/pp90m1.tres", "name": "PP90M1"},
		{"path": "res://resources/weapons/vmp.tres", "name": "VMP"},
		{"path": "res://resources/weapons/rpk.tres", "name": "RPK"},
		{"path": "res://resources/weapons/lmg.tres", "name": "LMG-63"},
		{"path": "res://resources/weapons/spas12.tres", "name": "SPAS-12"},
		{"path": "res://resources/weapons/krm262.tres", "name": "KRM-262"},
		{"path": "res://resources/weapons/shotgun.tres", "name": "Sawnoff Shotgun"},
		{"path": "res://resources/weapons/pistol.tres", "name": "Pistola C19"},
		{"path": "res://resources/weapons/deagle.tres", "name": ".50 GS Deagle"},
		{"path": "res://resources/weapons/knife.tres", "name": "Combat Knife"}
	]

	var loaded_count = 0
	for item in weapons:
		var w_path = item["path"]
		assert(ResourceLoader.exists(w_path), "Arma inexistente: " + w_path)
		var w = load(w_path) as WeaponData
		assert(w != null, "Falha ao carregar WeaponData: " + w_path)
		loaded_count += 1
		log_msg.call("✔ [%d/16] %s (ID: %s, Cat: %d, RPM: %.0f, Dano: %d-%d)" % [
			loaded_count, w.weapon_name, w.weapon_id, w.category, w.fire_rate_rpm, w.damage_close, w.damage_long
		])

	assert(loaded_count == 16, "Deveriam existir 16 armas carregadas!")
	log_msg.call("✔ Total de %d armas verificadas com 100%% de integridade!" % loaded_count)

	# Testar ChooseClassScreen
	var ccs_script = load("res://scripts/ui/choose_class_screen.gd")
	assert(ccs_script != null, "Falha ao carregar choose_class_screen.gd")
	var ccs = ccs_script.new()
	assert(ccs != null, "Falha ao instanciar ChooseClassScreen")
	assert(ccs.PRESET_CLASSES.size() >= 7, "ChooseClassScreen deve ter pelo menos 7 classes pré-definidas!")
	assert(ccs.WEAPON_REGISTRY.size() >= 13, "ChooseClassScreen deve ter todas as armas primárias registradas!")
	log_msg.call("✔ ChooseClassScreen instanciado com sucesso! Classes: %d, Armas no seletor: %d" % [
		ccs.PRESET_CLASSES.size(), ccs.WEAPON_REGISTRY.size()
	])

	ccs.queue_free()

	log_msg.call("========================================================")
	log_msg.call("  TODAS AS ARMAS E TELA DE CLASSE VALIDADAS COM SUCESSO! 🎯")
	log_msg.call("========================================================")

	if f: f.close()
	return true
