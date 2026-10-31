extends Node3D
# Encaixe da mão direita no CABO real de cada arma (só no eixo da arma; altura não muda).
# Cabo: peça "RearGrip" quando existe; senão, a saliência para baixo logo atrás do carregador.
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
@onready var cam: Camera3D = $Camera
var lines := []
# Cabo medido no Blender (vista lateral) para armas que o detector automático erra:
# [distância do cabo até a traseira do corpo (glb), comprimento do corpo (glb)]
const GRIP_REF := {"man_o_war": [0.377, 0.700], "smg": [0.319, 0.754], "vmp": [0.153, 0.550], "pistol": [0.099, 0.315]}
const ONLY := ["man_o_war", "smg", "vmp", "pistol"]

func _ready() -> void:
	_run.call_deferred()

func _palm(skel: Skeleton3D, prefix: String) -> Vector3:
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).begins_with(prefix):
			return skel.global_transform * skel.get_bone_global_pose(i).origin
	return Vector3.INF

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints/grip"))
	await get_tree().create_timer(2.0).timeout
	for f in DirAccess.get_files_at("res://resources/weapons"):
		if not f.ends_with(".tres"): continue
		var wid := f.get_basename()
		var cfg = WeaponVisualRegistry.get_weapon_config(wid)
		if cfg.get("has_arms", true): continue
		if not ONLY.is_empty() and not (wid in ONLY): continue
		vm.equip_weapon_data(load("res://resources/weapons/" + f))
		vm.set_ads(false)
		await get_tree().create_timer(1.8).timeout
		var model: Node3D = vm.current_custom_model_instance
		var pivot: Node3D = model.get_node("Pivot")
		var inv := pivot.global_transform.affine_inverse()
		var front := -1.0 if float(cfg.get("socket_muzzle", Vector3(0, 0, -1)).z) < 0.0 else 1.0
		# vértices visíveis no espaço do Pivot, por peça
		var all_pts := PackedVector3Array()
		var mag := AABB(); var has_mag := false
		var rg := AABB(); var has_rg := false
		for m in model.find_children("*", "MeshInstance3D", true, false):
			if not m.is_visible_in_tree() or m.mesh == null: continue
			var xf: Transform3D = inv * m.global_transform
			var nm := String(m.name).to_lower() + " " + String(m.get_parent().name).to_lower()
			var box := AABB(); var first := true
			for s in m.mesh.get_surface_count():
				for v in m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
					var p: Vector3 = xf * v
					all_pts.append(p)
					box = AABB(p, Vector3.ZERO) if first else box.expand(p)
					first = false
			if "magazine" in nm and not first: mag = box if not has_mag else mag.merge(box); has_mag = true
			if "reargrip" in nm and not first: rg = box if not has_rg else rg.merge(box); has_rg = true
		if all_pts.is_empty(): continue
		var bb := AABB(all_pts[0], Vector3.ZERO)
		for p in all_pts: bb = bb.expand(p)
		# perfil de fundo ao longo da arma (fatias de 1,5 cm)
		var step := 0.015
		var nb := int(ceil(bb.size.z / step)) + 1
		var bottom := []; bottom.resize(nb); bottom.fill(INF)
		for p in all_pts:
			var b := int((p.z - bb.position.z) / step)
			if p.y < bottom[b]: bottom[b] = p.y
		var grip_z := INF
		var method := ""
		var rec := AABB(); var has_rec := false
		for m in model.find_children("*", "MeshInstance3D", true, false):
			if not m.is_visible_in_tree() or m.mesh == null: continue
			if not String(m.name).to_lower().begins_with("receiver"): continue
			var b: AABB = inv * m.global_transform * m.get_aabb()
			rec = b if not has_rec else rec.merge(b); has_rec = true
		if GRIP_REF.has(wid) and has_rec:
			var ref: Array = GRIP_REF[wid]
			var s_scale: float = rec.size.z / float(ref[1])
			var rec_rear: float = rec.end.z if front < 0 else rec.position.z
			grip_z = rec_rear + front * float(ref[0]) * s_scale
			method = "medido_no_blender"
		elif has_rg:
			grip_z = rg.get_center().z; method = "RearGrip"
		else:
			var vals := bottom.filter(func(x): return x != INF)
			vals.sort()
			var baseline: float = vals[int(vals.size() * 0.6)] # fundo típico do corpo
			var thr := baseline - 0.025
			var mag_rear_z: float = (mag.position.z + (mag.size.z if front < 0 else 0.0)) if has_mag else (bb.get_center().z)
			# procurar saliência atrás do carregador (lado traseiro), sem encostar na ponta de trás
			var best_sum := 0.0; var best_n := 0; var cur_sum := 0.0; var cur_n := 0
			for b in nb:
				var z := bb.position.z + (b + 0.5) * step
				var behind: bool = (z - mag_rear_z) * front < -0.005
				var near_end: bool = absf(z - (bb.position.z if front < 0 else bb.end.z)) < 0.06
				if behind and not near_end and bottom[b] != INF and bottom[b] < thr:
					cur_sum += z; cur_n += 1
				else:
					if cur_n > 0 and (best_n == 0 or absf(cur_sum / cur_n - mag_rear_z) < absf(best_sum / best_n - mag_rear_z)):
						best_sum = cur_sum; best_n = cur_n
					cur_sum = 0.0; cur_n = 0
			if cur_n > 0 and (best_n == 0 or absf(cur_sum / cur_n - mag_rear_z) < absf(best_sum / best_n - mag_rear_z)):
				best_sum = cur_sum; best_n = cur_n
			if best_n > 0:
				grip_z = best_sum / best_n; method = "saliencia" + ("+carregador" if has_mag else "")
		var skel: Skeleton3D = vm.fps_hands.weapon.find_children("*", "Skeleton3D", true, false).front()
		var palm_w := _palm(skel, "R_palm")
		if grip_z == INF or palm_w == Vector3.INF:
			lines.append("%s|sem_deteccao" % wid); continue
		var palm := inv * palm_w
		var dz := palm.z - grip_z           # quanto a arma deve andar no eixo dela
		var rear_end: float = bb.end.z if front < 0 else bb.position.z
		var from_rear_cm := absf(grip_z - rear_end) * 100.0 * pivot.global_basis.get_scale().z
		var world_delta: Vector3 = pivot.global_basis * Vector3(0, 0, dz)
		var mount: Node3D = model.get_parent()
		var new_off: Vector3 = model.position + mount.global_basis.inverse() * world_delta
		lines.append("%s|%s|palma_vs_cabo_cm=%.1f|cabo_a_partir_da_traseira_cm=%.1f|vm_offset_novo=Vector3(%.4f, %.4f, %.4f)" % [wid, method, dz * 100.0 * pivot.global_basis.get_scale().z, from_rear_cm, new_off.x, new_off.y, new_off.z])
		model.position = new_off
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png("res://_prints/grip/%s.png" % wid)
	FileAccess.open("res://_prints/grip_fit.txt", FileAccess.WRITE).store_string("\n".join(lines))
	get_tree().quit()
