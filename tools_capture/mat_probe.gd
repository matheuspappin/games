extends Node3D
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	var out := []
	for w in ["pp90m1", "vmp"]:
		vm.equip_weapon_data(load("res://resources/weapons/%s.tres" % w))
		await get_tree().create_timer(1.5).timeout
		for m in vm.current_custom_model_instance.find_children("*", "MeshInstance3D", true, false):
			if not m.mesh: continue
			for si in min(m.mesh.get_surface_count(), 3):
				var mat = m.get_active_material(si)
				var src := "override" if m.get_surface_override_material(si) else ("material_override" if m.material_override else "malha")
				if mat is StandardMaterial3D:
					out.append("%s %s s%d [%s] albedo=%s tex=%s metal=%.2f rug=%.2f transp=%d shading=%d vcolor=%s cull=%d" % [w, m.name, si, src, str(mat.albedo_color), str(mat.albedo_texture != null), mat.metallic, mat.roughness, mat.transparency, mat.shading_mode, str(mat.vertex_color_use_as_albedo), mat.cull_mode])
				else:
					out.append("%s %s s%d [%s] %s" % [w, m.name, si, src, str(mat)])
	FileAccess.open("res://_prints/mat_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
