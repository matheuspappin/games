extends SceneTree

func _init() -> void:
	call_deferred("_run_capture")

func _run_capture() -> void:
	var scr = load("res://scripts/ui/choose_class_screen.gd")
	var screen = scr.new()
	root.add_child(screen)
	screen.open_screen(false)

	# Aguardar renderização de alguns frames para carregar malhas e iluminação
	for i in range(15):
		await process_frame

	var artifact_dir = "C:/Users/lala/.gemini/antigravity-ide/brain/56be7ec3-35b0-4e45-9d8a-d04dd948261b"

	# 1. Capturar Camada 1: Bancada de Armas
	var img1 = root.get_viewport().get_texture().get_image()
	if img1:
		img1.save_png(artifact_dir + "/gunsmith_workbench_ingame.png")
		print("[CAPTURE] Salvo: gunsmith_workbench_ingame.png")

	# 2. Alternar para Camada 2: Gunsmith 3D Dedicado
	screen._switch_to_gunsmith_mode()
	screen._on_socket_pin_pressed("optic") # Exibir carrossel de miras

	for i in range(15):
		await process_frame

	var img2 = root.get_viewport().get_texture().get_image()
	if img2:
		img2.save_png(artifact_dir + "/gunsmith_build_weapon_ingame.png")
		print("[CAPTURE] Salvo: gunsmith_build_weapon_ingame.png")

	screen.queue_free()
	quit(0)
