extends Node
func _ready() -> void:
	var out := []
	var inst: Node3D = load(WeaponVisualRegistry.get_weapon_config("man_o_war")["scene"]).instantiate()
	add_child(inst)
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if String(mi.name) != "Sight": continue
		for s in mi.mesh.get_surface_count():
			var mat = mi.get_active_material(s)
			var arr = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var lo := Vector3(INF, INF, INF); var hi := -lo
			for v in verts:
				var p: Vector3 = mi.transform * v
				lo = lo.min(p); hi = hi.max(p)
			var info := "surf %d verts=%d mat=%s" % [s, verts.size(), str(mat.resource_name if mat else "null")]
			if mat is BaseMaterial3D:
				info += " albedo=%s transp=%d metal=%.2f rough=%.2f tex=%s" % [str(mat.albedo_color), mat.transparency, mat.metallic, mat.roughness, str(mat.albedo_texture != null)]
			info += " box=%s..%s" % [str(lo), str(hi)]
			out.append(info)
	FileAccess.open("res://_prints/glass_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
