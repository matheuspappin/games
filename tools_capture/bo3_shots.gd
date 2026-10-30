extends Node
# Linha de base / comparação do mapa BO3: 10 câmeras fixas (a partir dos pontos de spawn) + métricas.
# Uso: crie _prints/bo3_tag.txt com o nome da etapa (ex.: "base"); prints vão para _prints/bo3/<etapa>/
const MAP := "res://scenes/_world/map_nuk3town_bo3.tscn"
const SPAWNS := ["Spawn_Alpha", "Spawn_Alpha_Left", "Spawn_Alpha_Patio", "Spawn_Alpha_Corner", "Spawn_Alpha_RearYard",
	"Spawn_Bravo", "Spawn_Bravo_Right", "Spawn_Bravo_Greenhouse", "Spawn_Bravo_Corner", "Spawn_Bravo_RearYard"]

func _ready() -> void:
	if get_tree().current_scene == self:
		var r = Node.new(); r.set_script(get_script()); r.name = "Bo3Shots"
		get_tree().root.add_child.call_deferred(r)
		return
	_run.call_deferred()

func _run() -> void:
	var tag := FileAccess.get_file_as_string("res://_prints/bo3_tag.txt").strip_edges()
	if tag == "": tag = "base"
	var out := "res://_prints/bo3/" + tag
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.bot_count = 0 # sem bots: libera memória e deixa os prints comparáveis
	var t0 := Time.get_ticks_msec()
	get_tree().change_scene_to_file(MAP)
	await get_tree().process_frame
	await get_tree().process_frame
	var load_ms := Time.get_ticks_msec() - t0
	await get_tree().create_timer(6.0).timeout
	var map := get_tree().current_scene
	# esconder HUD/telas e congelar bots para prints limpos e comparáveis
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		c.visible = false
	for b in get_tree().get_nodes_in_group("enemies"):
		b.process_mode = Node.PROCESS_MODE_DISABLED
		b.visible = false
	var center := Vector3.ZERO
	var pts := []
	for n in SPAWNS:
		var s = map.find_child(n, true, false)
		if s: pts.append(s.global_position); center += s.global_position
	if pts.size() > 0: center /= pts.size()
	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.far = 500.0
	map.add_child(cam)
	cam.make_current()
	var rep := {"carregamento_ms": load_ms, "views": {}}
	var i := 0
	for p in pts:
		i += 1
		var pos: Vector3 = p + Vector3(0, 1.7, 0)
		cam.global_position = pos
		cam.look_at(Vector3(center.x, pos.y - 0.5, center.z), Vector3.UP)
		await get_tree().create_timer(1.2).timeout
		var frames := 0
		var t1 := Time.get_ticks_usec()
		while Time.get_ticks_usec() - t1 < 1000000:
			await get_tree().process_frame
			frames += 1
		get_viewport().get_texture().get_image().save_png("%s/v%02d.png" % [out, i])
		rep["views"]["v%02d" % i] = {"fps": frames, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "tris": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	rep["vram_mb"] = snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 1)
	var f := FileAccess.open(out + "/report.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(rep, "  "))
	f.close()
	get_tree().quit()
