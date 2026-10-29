# =============================================================================
# capture_firing_range_screenshot.gd
# Captura um print em alta resolução do Estande de Tiro em execução
# =============================================================================
extends SceneTree

func _init() -> void:
	call_deferred("_run_capture")

func _run_capture() -> void:
	var map_scn = load("res://scenes/_world/map_firing_range.tscn")
	var map = map_scn.instantiate()
	root.add_child(map)

	for i in range(15):
		await process_frame

	var img = root.get_viewport().get_texture().get_image()
	if img:
		img.save_png("res://screenshot_firing_range.png")
		print("[Capture] Screenshot gravado com sucesso em res://screenshot_firing_range.png")

	quit(0)
