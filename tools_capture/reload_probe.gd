extends Node3D
# Recarga: mede a distância mão esquerda -> pente do modelo durante a recarga e tira prints.
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
var lines := []
var _post_wrist := Vector3.INF

func _on_skel(skel: Skeleton3D) -> void:
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).begins_with("L_wrist"):
			_post_wrist = skel.global_transform * skel.get_bone_global_pose(i).origin
			return

func _ready() -> void:
	_run.call_deferred()

func _bone(skel: Skeleton3D, prefix: String) -> Vector3:
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).begins_with(prefix):
			return skel.global_transform * skel.get_bone_global_pose(i).origin
	return Vector3.INF

func _mag_center() -> Vector3:
	var box := AABB(); var first := true
	for e in vm._mag_custom:
		var n: Node3D = e["node"]
		for m in ([n] if n is MeshInstance3D else []) + n.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = m.global_transform * m.get_aabb()
			box = b if first else box.merge(b); first = false
	return box.get_center() if not first else Vector3.INF

func _native_center() -> Vector3:
	var n = vm._mag_native
	if not n: return Vector3.INF
	var box := AABB(); var first := true
	for m in ([n] if n is MeshInstance3D else []) + n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = m.global_transform * m.get_aabb()
		box = b if first else box.merge(b); first = false
	return box.get_center() if not first else n.global_position

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints/reload"))
	await get_tree().create_timer(2.0).timeout
	for wid in ["mp7", "pp90m1", "krm262", "spas12"]:
		vm.equip_weapon_data(load("res://resources/weapons/%s.tres" % wid))
		vm.set_ads(false)
		await get_tree().create_timer(2.0).timeout
		var info := "%s | nativo=%s custom=%d" % [wid, vm._mag_native.name if vm._mag_native else "-", vm._mag_custom.size()]
		if vm._mag_custom.is_empty():
			lines.append(info + " | sem pente separado no modelo"); continue
		var nat_rest: Vector3 = _native_center()
		var cus_rest: Vector3 = _mag_center()
		var rest_gap := nat_rest.distance_to(cus_rest) * 100.0
		var cus0: Vector3 = cus_rest
		var skel0: Skeleton3D = vm.fps_hands.weapon.find_children("*", "Skeleton3D", true, false).front()
		skel0.skeleton_updated.connect(_on_skel.bind(skel0))
		vm.fps_hands.state_machine.travel("reload")
		var best_ik := INF
		var best := INF
		var best_nat := INF
		var max_move := 0.0
		var t0 := Time.get_ticks_msec()
		var shot := 0
		while Time.get_ticks_msec() - t0 < 3000:
			await get_tree().process_frame
			var skel: Skeleton3D = vm.fps_hands.weapon.find_children("*", "Skeleton3D", true, false).front()
			var lp := _bone(skel, "L_palm")
			if lp == Vector3.INF: lp = _bone(skel, "L_wrist")
			var mc := _mag_center()
			if lp != Vector3.INF and mc != Vector3.INF:
				best = minf(best, lp.distance_to(mc))
				best_nat = minf(best_nat, lp.distance_to(_native_center()))
				max_move = maxf(max_move, mc.distance_to(cus0))
				if _post_wrist != Vector3.INF:
					best_ik = minf(best_ik, _post_wrist.distance_to(mc))
			var el := Time.get_ticks_msec() - t0
			if (shot == 0 and el > 700) or (shot == 1 and el > 1300) or (shot == 2 and el > 2000):
				get_viewport().get_texture().get_image().save_png("res://_prints/reload/%s_%d.png" % [wid, shot])
				shot += 1
		skel0.skeleton_updated.disconnect(_on_skel)
		lines.append(info + " | COM IK: punho->pente_modelo=%.1f cm" % (best_ik * 100.0) + " | mao->pente_modelo=%.1f cm | mao->pente_original=%.1f cm | pentes_em_repouso_separados=%.1f cm | pente_modelo_moveu=%.1f cm" % [best * 100.0, best_nat * 100.0, rest_gap, max_move * 100.0])
		await get_tree().create_timer(1.0).timeout
	FileAccess.open("res://_prints/reload_probe.txt", FileAccess.WRITE).store_string("\n".join(lines))
	get_tree().quit()
