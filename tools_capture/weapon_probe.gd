extends Node3D
# Mede, para cada arma, o osso da mão direita/esquerda e a caixa (AABB) do modelo customizado.
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
var lines := []

func _ready() -> void:
	_run.call_deferred()

func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		if not m.visible or not m.is_visible_in_tree():
			continue
		var b: AABB = m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	var cam: Camera3D = $Camera
	for f in DirAccess.get_files_at("res://resources/weapons"):
		if not f.ends_with(".tres"):
			continue
		var wid := f.get_basename()
		vm.equip_weapon_data(load("res://resources/weapons/" + f))
		vm.set_ads(false)
		await get_tree().create_timer(1.6).timeout
		var fh = vm.fps_hands
		var sk_list = fh.weapon.find_children("*", "Skeleton3D", true, false)
		var skel: Skeleton3D = sk_list.front() if sk_list.size() > 0 else null
		var hr := Vector3.ZERO
		var hl := Vector3.ZERO
		var names := []
		if skel:
			for i in skel.get_bone_count():
				var bn := skel.get_bone_name(i)
				var low := bn.to_lower()
				if ("wrist" in low) and names.size() < 6:
					names.append(bn)
				var p := cam.to_local(skel.global_transform * skel.get_bone_global_pose(i).origin)
				if low.begins_with("r_wrist"):
					hr = p
				if low.begins_with("l_wrist"):
					hl = p
		var model = vm.current_custom_model_instance
		var box := AABB()
		if model and is_instance_valid(model):
			var gb := _aabb(model)
			box = AABB(cam.to_local(gb.position), gb.size)
		lines.append("%s | maoD %s | maoE %s | modelo pos %s tam %s | ossos %s" % [wid, hr.snapped(Vector3.ONE * 0.001), hl.snapped(Vector3.ONE * 0.001), box.position.snapped(Vector3.ONE * 0.001), box.size.snapped(Vector3.ONE * 0.001), str(names)])
	var fl := FileAccess.open("res://_prints/weapon_probe.txt", FileAccess.WRITE)
	fl.store_string("\n".join(lines))
	fl.close()
	get_tree().quit()
