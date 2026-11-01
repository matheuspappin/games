extends Node3D
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
func _ready() -> void:
	_run.call_deferred()
func _skel() -> Skeleton3D:
	return vm.left_hand_ik.get_parent() as Skeleton3D if vm.left_hand_ik else null
func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	var out := []
	for w in ["smg", "ak47"]:
		vm.equip_weapon_data(load("res://resources/weapons/%s.tres" % w))
		await get_tree().create_timer(2.5).timeout
		var sk := _skel()
		out.append("== %s esqueleto=%s ossos=%d" % [w, str(sk.get_path()) if sk else "?", sk.get_bone_count() if sk else 0])
		if not sk: continue
		for i in sk.get_bone_count():
			var n := sk.get_bone_name(i)
			if n.begins_with("L_") and (n.contains("thumb") or n.contains("point") or n.contains("middle") or n.contains("ring") or n.contains("pink")):
				var q := sk.get_bone_pose_rotation(i)
				out.append('"%s": Quaternion(%f, %f, %f, %f),' % [n, q.x, q.y, q.z, q.w])
	FileAccess.open("res://_prints/finger_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
