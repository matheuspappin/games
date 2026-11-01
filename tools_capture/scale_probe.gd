extends Node3D
# Mede a mão do modelo e o tamanho de cada arma NO JOGO (metros reais da câmera), para comparar com as armas reais.
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
func _ready() -> void:
	_run.call_deferred()
func _b(skel: Skeleton3D, prefix: String) -> Vector3:
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).begins_with(prefix):
			return skel.global_transform * skel.get_bone_global_pose(i).origin
	return Vector3.INF
func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	var out := []
	var first := true
	for f in DirAccess.get_files_at("res://resources/weapons"):
		if not f.ends_with(".tres"): continue
		var wid := f.get_basename()
		var cfg = WeaponVisualRegistry.get_weapon_config(wid)
		if cfg.get("has_arms", true): continue
		vm.equip_weapon_data(load("res://resources/weapons/" + f))
		vm.set_weapon_customization("default", "none", "none", "none", "none", "none", "none")
		await get_tree().create_timer(1.6).timeout
		var skel: Skeleton3D = vm.fps_hands.weapon.find_children("*", "Skeleton3D", true, false).front()
		if first:
			first = false
			# mão: punho -> base do dedo médio -> pontas; largura da palma (indicador <-> mínimo)
			var w := _b(skel, "R_wrist"); var m1 := _b(skel, "R_middle1"); var m3 := _b(skel, "R_middle3")
			var p1 := _b(skel, "R_point1"); var k1 := _b(skel, "R_pink1")
			out.append("MAO: punho->base_dedos=%.1fcm punho->falange_final_medio=%.1fcm largura_palma(base indicador-minimo)=%.1fcm" % [w.distance_to(m1) * 100, w.distance_to(m3) * 100, p1.distance_to(k1) * 100])
		var model: Node3D = vm.current_custom_model_instance
		var pivot: Node3D = model.get_node("Pivot")
		var s := pivot.global_basis.get_scale().x
		var inv := pivot.global_transform.affine_inverse()
		var bb := AABB(); var fb := true
		for m in model.find_children("*", "MeshInstance3D", true, false):
			if not m.is_visible_in_tree() or m.mesh == null: continue
			var b: AABB = inv * m.global_transform * m.get_aabb()
			bb = b if fb else bb.merge(b); fb = false
		var nb := AABB(); var nf := true
		for m in vm.fps_hands.weapon.find_children("*", "MeshInstance3D", true, false):
			if m.name == "Object_7" or model.is_ancestor_of(m) or m.mesh == null: continue
			if "bullet" in String(m.name).to_lower(): continue
			var b2: AABB = m.global_transform * m.get_aabb()
			nb = b2 if nf else nb.merge(b2); nf = false
		out.append("   arma ORIGINAL do addon nesta familia: maior lado=%.1fcm" % (nb.get_longest_axis_size() * 100))
		var names := []
		for i in skel.get_bone_count():
			var bn := skel.get_bone_name(i)
			if bn.begins_with("R_middle") or bn.begins_with("R_wrist") or bn.begins_with("R_palm"):
				names.append("%s(pai=%s)" % [bn, skel.get_bone_name(skel.get_bone_parent(i)) if skel.get_bone_parent(i) >= 0 else "-"])
		if wid == "ak47": out.append("   ossos: " + ", ".join(names))
		out.append("%s | comprimento=%.1fcm altura=%.1fcm largura=%.1fcm" % [wid, bb.size.z * s * 100, bb.size.y * s * 100, bb.size.x * s * 100])
	FileAccess.open("res://_prints/scale_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
