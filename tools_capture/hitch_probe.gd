extends Node
# Sonda de travadas: entra num mapa e registra os frames longos e o que foi criado neles.
const MAP := "res://scenes/_world/map_nuketown_1v1.tscn"
var added := {}
var log := []

func _ready() -> void:
	if get_tree().current_scene == self:
		var r = Node.new(); r.set_script(get_script()); r.name = "HitchProbe"
		get_tree().root.add_child.call_deferred(r)
		return
	get_tree().node_added.connect(func(n):
		var k = n.get_class()
		if n.get_script(): k = n.get_script().resource_path.get_file()
		elif n.scene_file_path != "": k = n.scene_file_path.get_file()
		added[k] = added.get(k, 0) + 1)
	_run.call_deferred()

func _run() -> void:
	var t0 := Time.get_ticks_msec()
	get_tree().change_scene_to_file(MAP)
	var last := Time.get_ticks_usec()
	while Time.get_ticks_msec() - t0 < 25000:
		added.clear()
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		if ms > 250.0:
			var top := added.keys()
			top.sort_custom(func(a, b): return added[a] > added[b])
			var parts := []
			for k in top.slice(0, 8): parts.append("%s x%d" % [k, added[k]])
			var line := "[HITCH] t=%.1fs frame=%.0fms criados: %s" % [(Time.get_ticks_msec() - t0) / 1000.0, ms, ", ".join(parts)]
			print(line)
			log.append(line)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints"))
	var f := FileAccess.open("res://_prints/hitch.txt", FileAccess.WRITE)
	f.store_string("\n".join(log) + "\nFIM\n")
	f.close()
	print("[HITCH] FIM")
	get_tree().quit()
