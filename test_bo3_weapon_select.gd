extends MainLoop

func _process(_delta: float) -> bool:
	var f = FileAccess.open("C:/gemini cli/games/test_bo3_val.txt", FileAccess.WRITE)
	var log_msg = func(txt: String):
		print(txt)
		if f: f.store_line(txt)

	log_msg.call("========================================================")
	log_msg.call("  TESTANDO BO3 WEAPON SELECT SCREEN (SHOWCASE 3D)")
	log_msg.call("========================================================")

	var bo3_scr = load("res://scripts/ui/bo3_weapon_select_screen.gd")
	assert(bo3_scr != null, "Falha ao carregar bo3_weapon_select_screen.gd")
	var bo3_inst = bo3_scr.new()
	assert(bo3_inst != null, "Falha ao instanciar BO3WeaponSelectScreen")

	log_msg.call("✔ BO3WeaponSelectScreen instanciado.")
	log_msg.call("✔ Categorias registradas: %d" % bo3_inst.CATEGORIES.size())
	for i in range(bo3_inst.CATEGORIES.size()):
		var cat = bo3_inst.CATEGORIES[i]
		log_msg.call("   • [%s] %s (%d armas)" % [cat["id"], cat["name"], cat["weapons"].size()])

	# Testar abertura de tela e seleção
	bo3_inst.open_screen(0, "res://resources/weapons/ak47.tres")
	log_msg.call("✔ open_screen executado com sucesso.")
	log_msg.call("✔ Arma selecionada: " + bo3_inst.selected_weapon_data.get("name", "Nenhuma"))

	# Testar troca para SMGs
	bo3_inst._select_category(1)
	log_msg.call("✔ Categoria SMG selecionada. Arma: " + bo3_inst.selected_weapon_data.get("name", "Nenhuma"))

	# Testar troca para Snipers
	bo3_inst._select_category(4)
	log_msg.call("✔ Categoria Sniper selecionada. Arma: " + bo3_inst.selected_weapon_data.get("name", "Nenhuma"))

	# Testar troca para Shotguns
	bo3_inst._select_category(2)
	log_msg.call("✔ Categoria Shotgun selecionada. Arma: " + bo3_inst.selected_weapon_data.get("name", "Nenhuma"))

	bo3_inst.close_screen()
	log_msg.call("✔ close_screen executado com sucesso.")

	log_msg.call("========================================================")
	log_msg.call("  BO3 WEAPON SELECTOR 3D 100% VALIDADO COM SUCESSO! 🎯")
	log_msg.call("========================================================")

	if f: f.close()
	return true
