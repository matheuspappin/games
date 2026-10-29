extends SceneTree

func _init() -> void:
	print("==================================================")
	print(" TEST: AAA GUNSMITH & LOADOUT WORKBENCH")
	print("==================================================")
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("[1/3] Instanciando ChooseClassScreen (AAA Gunsmith)...")
	var scr = load("res://scripts/ui/choose_class_screen.gd")
	assert(scr != null, "Falha ao carregar choose_class_screen.gd")

	var screen = scr.new()
	assert(screen != null, "Falha ao instanciar ChooseClassScreen")
	root.add_child(screen)

	await process_frame
	await process_frame

	print("[2/3] Testando abertura e inicialização de Bancada...")
	screen.open_screen(false)
	assert(screen.is_open == true, "A tela deveria estar aberta")
	assert(screen.current_mode == screen.UIMode.LOADOUT_WORKBENCH, "Deveria iniciar no modo bancada")
	assert(screen.weapon_model_wrapper != null, "Modelo 3D da arma deveria estar instanciado")

	print("[3/3] Testando transição para Gunsmith 3D Dedicado e Sockets...")
	screen._switch_to_gunsmith_mode()
	assert(screen.current_mode == screen.UIMode.GUNSMITH_3D, "Deveria estar no modo Gunsmith 3D")
	assert(screen.socket_pins.size() >= 7, "Deveria ter ao menos 7 pinos espaciais registrados")

	# Testar abertura de carrossel de um socket (ex: optic)
	screen._on_socket_pin_pressed("optic")
	assert(screen.carousel_container.visible == true, "O carrossel de acessórios deveria estar visível")
	assert(screen.carousel_cards_hbox.get_child_count() > 0, "O carrossel deveria conter opções de mira")

	# Testar equipar acessório
	screen._equip_attachment_from_carousel("optic", "optic_red_dot")
	var cur_class = screen.classes[screen.selected_class_index]
	assert(cur_class.get("optic") == "optic_red_dot", "Acessório optic_red_dot deveria estar equipado na classe")

	# Testar aba de customização
	screen._set_gunsmith_tab(screen.GunsmithTab.CUSTOMIZE)
	assert(screen.customize_panel.visible == true, "Painel de camuflagens deveria estar visível")

	# Testar voltar para bancada
	screen._switch_to_workbench_mode()
	assert(screen.current_mode == screen.UIMode.LOADOUT_WORKBENCH, "Deveria retornar ao modo bancada")

	print("==================================================")
	print(" TODOS OS TESTES DO NOVO GUNSMITH PASSARAM COM SUCESSO!")
	print("==================================================")
	screen.queue_free()
	quit(0)
