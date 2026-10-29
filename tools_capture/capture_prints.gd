extends Node
# Captura prints e metricas de desempenho de cenas do jogo (ferramenta de QA).
const SHOTS := [
	["res://scenes/ui/main_menu.tscn", "menu", 5.0],
	["res://scenes/_world/map_nuketown_1v1.tscn", "nuketown_1v1", 8.0],
	["res://scenes/_world/map_nuk3town_bo3.tscn", "nuk3town_bo3", 10.0],
	["res://scenes/_world/map_firing_range.tscn", "firing_range", 8.0],
]
var report := {}

func _ready() -> void:
	if get_parent() != get_tree().root or get_tree().current_scene == self:
		var runner = Node.new()
		runner.set_script(get_script())
		runner.name = "CaptureRunner"
		get_tree().root.add_child.call_deferred(runner)
		return
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints"))
	for s in SHOTS:
		var t0 := Time.get_ticks_msec()
		get_tree().change_scene_to_file(s[0])
		await get_tree().process_frame
		await get_tree().process_frame
		var load_ms := Time.get_ticks_msec() - t0
		await get_tree().create_timer(s[2]).timeout
		var frames := 0
		var t1 := Time.get_ticks_usec()
		var worst := 0.0
		while Time.get_ticks_usec() - t1 < 3000000:
			var f0 := Time.get_ticks_usec()
			await get_tree().process_frame
			worst = max(worst, (Time.get_ticks_usec() - f0) / 1000.0)
			frames += 1
		var secs := (Time.get_ticks_usec() - t1) / 1000000.0
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://_prints/%s.png" % s[1])
		report[s[1]] = {
			"fps_medio": snappedf(frames / secs, 0.1),
			"pior_frame_ms": snappedf(worst, 0.1),
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"objetos": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"primitivas": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"vram_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 1),
			"memoria_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 1),
			"carregamento_ms": load_ms,
			"resolucao": str(img.get_size()),
		}
		print("[CAPTURE] ", s[1], " ", report[s[1]])
	var f := FileAccess.open("res://_prints/report.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	print("[CAPTURE] FIM")
	get_tree().quit()
