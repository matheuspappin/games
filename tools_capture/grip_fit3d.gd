extends Node3D
# Mão direita no cabo nos 3 eixos: a palma vai ao terço superior do cabo (onde a "teia" entre polegar e
# indicador encosta no topo, como na pegada real), no centro lateral do cabo.
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
const GRIP_REF := {"man_o_war": [0.377, 0.700], "smg": [0.319, 0.754], "vmp": [0.153, 0.550], "pistol": [0.099, 0.315]}
var lines := []

func _ready() -> void:
	_run.call_deferred()

func _palm(skel: Skeleton3D) -> Vector3:
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).begins_with("R_palm"):
			return skel.global_transform * skel.get_bone_global_pose(i).origin
	return Vector3.INF

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints/grip3d"))
	await get_tree().create_timer(2.0).timeout
	for f in DirAccess.get_files_at("res://resources/weapons"):
		if not f.ends_with(".tres"): continue
		var wid := f.get_basename()
		var cfg = WeaponVisualRegistry.get_weapon_config(wid)
		if cfg.get("has_arms", true): continue
		if wid != "mp7": continue
		vm.equip_weapon_data(load("res://resources/weapons/" + f))
		vm.set_weapon_customization("default", "none", "none", "none", "none", "none", "none")
		vm.set_ads(false)
		await get_tree().create_timer(1.8).timeout
		var model: Node3D = vm.current_custom_model_instance
		var pivot: Node3D = model.get_node("Pivot")
		var mount: Node3D = model.get_parent()
		var skel: Skeleton3D = vm.fps_hands.weapon.find_children("*", "Skeleton3D", true, false).front()
		var front := -1.0 if float(cfg.get("socket_muzzle", Vector3(0, 0, -1)).z) < 0.0 else 1.0
		var anchor := Vector3.INF
		var how := ""
		for it in 3:
			var inv := pivot.global_transform.affine_inverse()
			var pts := PackedVector3Array()
			var mag := AABB(); var has_mag := false
			var rg := AABB(); var has_rg := false
			var rec := AABB(); var has_rec := false
			for m in model.find_children("*", "MeshInstance3D", true, false):
				if not m.is_visible_in_tree() or m.mesh == null: continue
				var xf: Transform3D = inv * m.global_transform
				var nm := String(m.name).to_lower()
				for sidx in m.mesh.get_surface_count():
					for v in m.mesh.surface_get_arrays(sidx)[Mesh.ARRAY_VERTEX]:
						var p: Vector3 = xf * v
						pts.append(p)
						if nm.begins_with("magazine"): mag = AABB(p, Vector3.ZERO) if not has_mag else mag.expand(p); has_mag = true
						if nm.begins_with("reargrip"): rg = AABB(p, Vector3.ZERO) if not has_rg else rg.expand(p); has_rg = true
						if nm.begins_with("receiver"): rec = AABB(p, Vector3.ZERO) if not has_rec else rec.expand(p); has_rec = true
			var bb := AABB(pts[0], Vector3.ZERO)
			for p in pts: bb = bb.expand(p)
			var step := 0.01
			var nb := int(ceil(bb.size.z / step)) + 1
			var bottom := []; bottom.resize(nb); bottom.fill(INF)
			for p in pts:
				var b := int((p.z - bb.position.z) / step)
				if p.y < bottom[b]: bottom[b] = p.y
			var vals := bottom.filter(func(x): return x != INF); vals.sort()
			var baseline: float = vals[int(vals.size() * 0.6)]
			# z do cabo
			var gz := INF
			if has_rg:
				gz = rg.get_center().z; how = "RearGrip"
			elif wid == "mp7" and has_mag:
				gz = mag.get_center().z; how = "pente_no_cabo"   # na MP7 real o pente entra pelo cabo
			elif GRIP_REF.has(wid) and has_rec:
				var ref: Array = GRIP_REF[wid]
				var rr: float = rec.end.z if front < 0 else rec.position.z
				gz = rr + front * float(ref[0]) * rec.size.z / float(ref[1]); how = "medido_blender"
			else:
				var mag_rear: float = (mag.position.z + (mag.size.z if front < 0 else 0.0)) if has_mag else bb.get_center().z
				var thr := baseline - 0.025
				var best_s := 0.0; var best_n := 0; var cs := 0.0; var cn := 0
				var rear_end: float = bb.end.z if front < 0 else bb.position.z
				for b in nb:
					var z := bb.position.z + (b + 0.5) * step
					var ok: bool = (z - mag_rear) * front < -0.005 and absf(z - rear_end) > 0.06 and bottom[b] != INF and bottom[b] < thr
					if ok: cs += z; cn += 1
					elif cn > 0:
						if best_n == 0 or absf(cs / cn - mag_rear) < absf(best_s / best_n - mag_rear): best_s = cs; best_n = cn
						cs = 0.0; cn = 0
				if cn > 0 and (best_n == 0 or absf(cs / cn - mag_rear) < absf(best_s / best_n - mag_rear)): best_s = cs; best_n = cn
				if best_n > 0: gz = best_s / best_n; how = "forma"
			if gz == INF:
				break
			# altura: terço superior do cabo; lado: centro do cabo
			var g_bot := INF; var sx := 0.0; var nx := 0
			for p in pts:
				if absf(p.z - gz) < 0.02 and p.y < baseline:
					g_bot = minf(g_bot, p.y); sx += p.x; nx += 1
			if g_bot == INF: g_bot = baseline - 0.08
			var gx: float = (sx / nx) if nx > 0 else bb.get_center().x
			anchor = Vector3(gx, g_bot + 0.65 * (baseline - g_bot), gz)
			var palm_w := _palm(skel)
			var delta_w: Vector3 = palm_w - pivot.to_global(anchor)
			model.position += mount.global_basis.inverse() * delta_w
			await get_tree().create_timer(0.3).timeout
		var resid := (_palm(skel) - pivot.to_global(anchor)).length() * 100.0 if anchor != Vector3.INF else -1.0
		get_viewport().get_texture().get_image().save_png("res://_prints/grip3d/%s.png" % wid)
		lines.append('%s|%s|"vm_offset": Vector3(%.4f, %.4f, %.4f),|residuo_cm=%.1f' % [wid, how, model.position.x, model.position.y, model.position.z, resid])
	FileAccess.open("res://_prints/grip_fit3d.txt", FileAccess.WRITE).store_string("\n".join(lines))
	get_tree().quit()
