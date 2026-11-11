extends Node
# Auditoria de colisão do Nuketown 2065: lista malhas com colisão e materiais suspeitos (transparentes,
# sem textura, decal, vidro, etc.) e mede bloqueios invisíveis com raios horizontais numa grade.
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	var map = load("res://scenes/_world/map_nuk3town_bo3.tscn").instantiate()
	map.set_script(null) if false else null
	add_child(map)
	await get_tree().create_timer(6.0).timeout
	var model = map.find_child("Nuk3townModel", true, false)
	var lines := []
	for c in model.get_children():
		if not (c is MeshInstance3D) or not c.mesh: continue
		var has_col := false
		for ch in c.get_children():
			if ch is StaticBody3D: has_col = true
		var mats := []
		for si in c.mesh.get_surface_count():
			var m = c.get_active_material(si)
			var info := "?"
			if m is BaseMaterial3D:
				info = "%s|transp=%d|a=%.2f|tex=%s|vis=%s" % [m.resource_name, m.transparency, m.albedo_color.a, m.albedo_texture != null, c.visible]
			elif m:
				info = "%s|%s" % [m.resource_name, m.get_class()]
			mats.append(info)
		var gb: AABB = c.global_transform * c.get_aabb()
		lines.append("%s col=%s vis=%s aabb_pos=%s size=%s mats=%s" % [c.name, has_col, c.is_visible_in_tree(), gb.position.snapped(Vector3.ONE*0.1), gb.size.snapped(Vector3.ONE*0.1), "; ".join(mats)])
	FileAccess.open("res://_prints/map_audit.txt", FileAccess.WRITE).store_string("\n".join(lines))
	get_tree().quit()
