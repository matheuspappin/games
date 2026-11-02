extends Node3D
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
func _ready() -> void:
	_run.call_deferred()
func _skel() -> Skeleton3D:
	return vm.left_hand_ik.get_parent() as Skeleton3D if vm.left_hand_ik else null
func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	var out := []
	for w in ["mp7"]:
		vm.equip_weapon_data(load("res://resources/weapons/%s.tres" % w))
		await get_tree().create_timer(2.5).timeout
		var sk := _skel()
		out.append("== %s esqueleto=%s ossos=%d" % [w, str(sk.get_path()) if sk else "?", sk.get_bone_count() if sk else 0])
		if not sk: continue
		for i in sk.get_bone_count():
			var n := sk.get_bone_name(i)
			if n.begins_with("L_") or not n.begins_with("R_"):
				out.append("%d %s pai=%s" % [i, n, sk.get_bone_name(sk.get_bone_parent(i)) if sk.get_bone_parent(i) >= 0 else "-"])
	FileAccess.open("res://_prints/finger_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
