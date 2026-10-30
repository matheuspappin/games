extends Node3D
# Encaixe automático: alinha a caixa do modelo ao punho direito usando regras por família
# e salva prints cintura/ADS + os valores calibrados em _prints/weapon_fit.txt.
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
@onready var cam: Camera3D = $Camera
const TARGETS := ["rpk"]
var lines := []

func _ready() -> void:
	_run.call_deferred()

func _aabb_cam(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		if not m.is_visible_in_tree():
			continue
		var b: AABB = m.global_transform * m.get_aabb()
		b = AABB(cam.to_local(b.position), b.size)
		box = b if first else box.merge(b)
		first = false
	return box

func _native_aabb_cam() -> AABB:
	var box := AABB()
	var first := true
	for m in vm.fps_hands.weapon.find_children("*", "MeshInstance3D", true, false):
		if m.name == "Object_7" or m.name.begins_with("Custom") or m.name.to_lower().contains("bullet"):
			continue
		if vm.current_custom_model_instance and vm.current_custom_model_instance.is_ancestor_of(m):
			continue
		var b: AABB = m.global_transform * m.get_aabb()
		b = AABB(cam.to_local(b.position), b.size)
		box = b if first else box.merge(b)
		first = false
	return box

func _wrist_r() -> Vector3:
	var sk = vm.fps_hands.weapon.find_children("*", "Skeleton3D", true, false)
	var skel: Skeleton3D = sk.front()
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).to_lower().begins_with("r_wrist"):
			return cam.to_local(skel.global_transform * skel.get_bone_global_pose(i).origin)
	return Vector3.ZERO

func _run() -> void:
	var out := "res://_prints/weapons_fit"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	await get_tree().create_timer(2.0).timeout
	for wid in TARGETS:
		vm.equip_weapon_data(load("res://resources/weapons/%s.tres" % wid))
		vm.set_ads(false)
		await get_tree().create_timer(1.6).timeout
		var model: Node3D = vm.current_custom_model_instance
		var mount: Node3D = model.get_parent()
		var w := _wrist_r()
		var box := _aabb_cam(model)
		var f: float = 0.99 / box.size.z
		model.scale *= f
		await get_tree().process_frame
		box = _aabb_cam(model)
		var want_rear_z: float = w.z + 0.212
		var want_top_y: float = w.y + 0.256
		var want_cx: float = w.x - 0.07
		var cur_rear_z := box.position.z + box.size.z
		var cur_top_y := box.position.y + box.size.y
		var cur_cx := box.position.x + box.size.x * 0.5
		var delta_cam := Vector3(want_cx - cur_cx, want_top_y - cur_top_y, want_rear_z - cur_rear_z)
		var delta_world := cam.global_transform.basis * delta_cam
		var delta_local := mount.global_transform.basis.inverse() * delta_world
		model.position += delta_local
		var pivot: Node3D = model.get_node("Pivot")
		var pb := AABB()
		var pf := true
		for m in model.find_children("*", "MeshInstance3D", true, false):
			if not m.is_visible_in_tree():
				continue
			var xf: Transform3D = pivot.global_transform.affine_inverse() * m.global_transform
			var bb: AABB = xf * m.get_aabb()
			pb = bb if pf else pb.merge(bb)
			pf = false
		# frente do modelo = -Z do Pivot? descobrir pelo lado mais perto do cano (socket_muzzle)
		var cfgr = WeaponVisualRegistry.get_weapon_config(wid)
		var muzzle_z: float = cfgr.get("socket_muzzle", Vector3(0, 0, -1)).z
		var rear_z: float = pb.position.z + pb.size.z if muzzle_z < 0 else pb.position.z
		var dir: float = -1.0 if muzzle_z < 0 else 1.0
		var sock := Vector3(pb.position.x + pb.size.x * 0.5, pb.position.y + pb.size.y + 0.004, rear_z + dir * pb.size.z * 0.35)
		lines.append("%s|socket_iron_ads=Vector3(%.4f, %.4f, %.4f)|pivot_aabb=%s" % [wid, sock.x, sock.y, sock.z, str(pb)])
		vm.update_ads_alignment()
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png("%s/%s_hip.png" % [out, wid])
		vm.set_ads(true, 1.0)
		await get_tree().create_timer(1.2).timeout
		get_viewport().get_texture().get_image().save_png("%s/%s_ads.png" % [out, wid])
		vm.set_ads(false)
		lines.append("%s|vm_offset=Vector3(%.4f, %.4f, %.4f)|vm_fit_scale=%.4f" % [wid, model.position.x, model.position.y, model.position.z, f])
		await get_tree().create_timer(0.5).timeout
	var fl := FileAccess.open("res://_prints/weapon_fit.txt", FileAccess.WRITE)
	fl.store_string("\n".join(lines))
	fl.close()
	get_tree().quit()
