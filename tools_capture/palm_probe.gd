extends Node3D
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
@onready var cam: Camera3D = $Camera
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	var out := []
	for wid in ["ak47", "pistol", "smg"]:
		vm.equip_weapon_data(load("res://resources/weapons/%s.tres" % wid))
		await get_tree().create_timer(1.6).timeout
		var skel: Skeleton3D = vm.fps_hands.weapon.find_children("*", "Skeleton3D", true, false).front()
		var res := {}
		for i in skel.get_bone_count():
			var n := skel.get_bone_name(i)
			for pre in ["R_palm", "L_palm", "R_wrist", "R_arm"]:
				if n.begins_with(pre): res[pre] = cam.to_local(skel.global_transform * skel.get_bone_global_pose(i).origin).snapped(Vector3.ONE * 0.001)
		out.append("%s | %s | rig_pos=%s escala=%s" % [wid, str(res), str(vm.fps_hands.position), str(vm.fps_hands.scale)])
	FileAccess.open("res://_prints/palm_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
