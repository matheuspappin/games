extends Node3D
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	vm.equip_weapon_data(load("res://resources/weapons/pp90m1.tres"))
	await get_tree().create_timer(1.8).timeout
	var out := []
	for m in vm.current_custom_model_instance.find_children("*", "MeshInstance3D", true, false):
		if not m.is_visible_in_tree():
			continue
		for s in m.mesh.get_surface_count():
			var mat = m.get_active_material(s)
			var desc := "nulo"
			if mat is StandardMaterial3D:
				desc = "cor=%s tex=%s metal=%.2f" % [mat.albedo_color, mat.albedo_texture != null, mat.metallic]
			elif mat:
				desc = mat.get_class()
			out.append("%s [%s] s%d %s cena=%s" % [m.name, m.get_parent().name, s, desc, m.owner.scene_file_path if m.owner else ""])
	FileAccess.open("res://_prints/mat_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
