extends Node3D
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
@onready var cam: Camera3D = $Camera
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	var out := []
	var seen := {}
	for f in DirAccess.get_files_at("res://resources/weapons"):
		if not f.ends_with(".tres"): continue
		var wid := f.get_basename()
		vm.equip_weapon_data(load("res://resources/weapons/" + f))
		vm.set_ads(false)
		await get_tree().create_timer(1.6).timeout
		var fam: String = vm.fps_hands.weapon.scene_file_path.get_file() if vm.fps_hands.weapon.scene_file_path != "" else str(vm.current_inventory_idx)
		var line := "%s | familia=%s idx=%d" % [wid, fam, vm.current_inventory_idx]
		if not seen.has(fam):
			seen[fam] = true
			var root: Node3D = vm.fps_hands.weapon.find_child("Sketchfab_model", true, false)
			if root:
				var rel: Transform3D = root.global_transform.affine_inverse() * cam.global_transform
				line += " | CAM origem=%s frente=%s cima=%s" % [str(rel.origin), str(-rel.basis.z.normalized()), str(rel.basis.y.normalized())]
		out.append(line)
	FileAccess.open("res://_prints/family_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
