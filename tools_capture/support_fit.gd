extends Node3D
# Calibrador da mão de apoio (esquerda): a PALMA vai ao ponto certo de cada arma, por regra de tipo
# (vida real / CoD), com 3 passadas de correção medindo a palma DEPOIS do IK.
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
@onready var cam: Camera3D = $Camera
const PUMP := {"krm262": 0.86, "spas12": 0.66}      # parte da frente da bomba (perto do corpo a mão cobria a visão)      # centro da bomba: fração do comprimento a partir da traseira (medido no Blender)
const DOUBLE_BARREL := {"shotgun": 0.72}           # madeira sob os canos
const PISTOLS := ["pistol", "deagle"]
const FOREGRIP := ["m4a1", "lmg", "smg"]          # empunhadura vertical embutida no modelo (conferido nos prints)
const BULLPUP := ["man_o_war", "vmp"]             # carregador atrás do cabo
const MAG_IN_GRIP := ["mp7"]                      # pente dentro do cabo
var lines := []
var _palm := Vector3.INF

func _ready() -> void:
	_run.call_deferred()

func _on_skel(skel: Skeleton3D) -> void:
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).begins_with("L_palm"):
			_palm = skel.global_transform * skel.get_bone_global_pose(i).origin
			return

func _bone(skel: Skeleton3D, prefix: String) -> Vector3:
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).begins_with(prefix):
			return skel.global_transform * skel.get_bone_global_pose(i).origin
	return Vector3.INF

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints/support"))
	await get_tree().create_timer(2.0).timeout
	for f in DirAccess.get_files_at("res://resources/weapons"):
		if not f.ends_with(".tres"): continue
		var wid := f.get_basename()
		var cfg = WeaponVisualRegistry.get_weapon_config(wid)
		if cfg.get("has_arms", true): continue
		vm.equip_weapon_data(load("res://resources/weapons/" + f))
		vm.set_weapon_customization("default", "none", "none", "none", "none", "none", "none")
		vm.set_ads(false)
		await get_tree().create_timer(1.8).timeout
		if not (wid in ["spas12", "shotgun"]): continue
		var model: Node3D = vm.current_custom_model_instance
		var pivot: Node3D = model.get_node("Pivot")
		var inv := pivot.global_transform.affine_inverse()
		var front := -1.0 if float(cfg.get("socket_muzzle", Vector3(0, 0, -1)).z) < 0.0 else 1.0
		# geometria (espaço do Pivot)
		var pts := PackedVector3Array()
		var mag := AABB(); var has_mag := false
		for m in model.find_children("*", "MeshInstance3D", true, false):
			if not m.is_visible_in_tree() or m.mesh == null: continue
			if m.get_parent() and String(m.get_parent().name) in ["AttachmentContainer", "GripL"]: continue
			var xf: Transform3D = inv * m.global_transform
			var nm := String(m.name).to_lower()
			for sidx in m.mesh.get_surface_count():
				for v in m.mesh.surface_get_arrays(sidx)[Mesh.ARRAY_VERTEX]:
					var p: Vector3 = xf * v
					pts.append(p)
					if nm.begins_with("magazine"):
						mag = AABB(p, Vector3.ZERO) if not has_mag else mag.expand(p); has_mag = true
		var bb := AABB(pts[0], Vector3.ZERO)
		for p in pts: bb = bb.expand(p)
		var rear_z: float = bb.end.z if front < 0 else bb.position.z
		var front_z: float = bb.position.z if front < 0 else bb.end.z
		var L: float = absf(front_z - rear_z)
		var step := 0.01
		var nb := int(ceil(bb.size.z / step)) + 1
		var bottom := []; bottom.resize(nb); bottom.fill(INF)
		for p in pts:
			var b := int((p.z - bb.position.z) / step)
			if p.y < bottom[b]: bottom[b] = p.y
		var zat := func(t: float) -> float: return rear_z + front * t * L          # t = fração a partir da traseira
		var bottom_at := func(z: float) -> float:
			var b := clampi(int((z - bb.position.z) / step), 0, nb - 1)
			var best := INF
			for k in range(maxi(0, b - 1), mini(nb, b + 2)):
				if bottom[k] < best: best = bottom[k]
			return best
		var target := Vector3.INF
		var rule := ""
		var skel: Skeleton3D = vm.fps_hands.weapon.find_children("*", "Skeleton3D", true, false).front()
		if wid in PISTOLS:
			# duas mãos: palma esquerda envolve a mão direita (por baixo e à esquerda, no espaço da câmera)
			var rp: Vector3 = _bone(skel, "R_palm")
			var t_cam := cam.to_local(rp) + Vector3(-0.035, -0.03, -0.005)
			target = inv * cam.to_global(t_cam)
			rule = "pistola_duas_maos"
		elif PUMP.has(wid) or DOUBLE_BARREL.has(wid):
			var t: float = PUMP.get(wid, DOUBLE_BARREL.get(wid, 0.5))
			var z: float = zat.call(t)
			var by: float = bottom_at.call(z)
			var k := 1
			while by == INF and k < 12:   # vão sob os canos: usa o fundo mais próximo
				by = minf(float(bottom_at.call(z + step * k)), float(bottom_at.call(z - step * k)))
				k += 1
			target = Vector3(bb.get_center().x, by - 0.012, z)
			rule = "bomba" if PUMP.has(wid) else "madeira_sob_canos"
		else:
			# guarda-mão: do fim do carregador (ou do meio da arma) até onde o fundo sobe para o cano
			var mag_front_z: float = (mag.position.z if front < 0 else mag.end.z) if has_mag else float(zat.call(0.45))
			var bullpup: bool = wid in BULLPUP
			var hg_start: float = float(zat.call(0.55)) if bullpup else mag_front_z + front * (0.03 if wid in MAG_IN_GRIP else 0.0)
			# fundo típico do guarda-mão e onde ele termina (à frente disso só cano/bocal)
			# fundo típico do guarda-mão: só a primeira metade da região (antes do cano fino)
			var vals := []
			var z := hg_start
			var span := absf(front_z - hg_start)
			while (front_z - z) * front > 0.0 and absf(z - hg_start) < span * 0.5:
				var bt: float = bottom_at.call(z)
				if bt != INF: vals.append(bt)
				z += front * step
			vals.sort()
			var hg_bottom: float = vals[vals.size() / 2] if vals.size() > 0 else bb.position.y
			# empunhadura vertical embutida: algo bem abaixo do guarda-mão, à frente do carregador
			var fg_sum := 0.0; var fg_n := 0
			var hg_end := hg_start
			z = hg_start + front * 0.03
			while (front_z - z) * front > 0.0:
				var bt2: float = bottom_at.call(z)
				if bt2 != INF and bt2 < hg_bottom - (0.02 if wid in FOREGRIP else 0.035):
					fg_sum += z; fg_n += 1
				if bt2 != INF and bt2 <= hg_bottom + 0.012:
					hg_end = z
				z += front * step
			if fg_n > 0 and wid in FOREGRIP:
				var fz := fg_sum / fg_n
				var zt := fz - front * 0.03
				target = Vector3(bb.get_center().x, hg_bottom - 0.012, zt)
				rule = "empunhadura_embutida"
			else:
				var zt2 := hg_start + front * 0.6 * absf(hg_end - hg_start)
				if absf(hg_end - zt2) < 0.04: zt2 = hg_end - front * 0.04
				var by: float = bottom_at.call(zt2)
				if by == INF: by = hg_bottom   # vão no guarda-mão: usa a altura típica dele
				target = Vector3(bb.get_center().x, by - 0.012, zt2)
				rule = "c_clamp_guarda_mao" + ("_bullpup" if bullpup else "")
		# alvo do punho = alvo da palma - (palma - punho); 3 passadas medindo a palma depois do IK
		var marker := pivot.get_node_or_null("GripL") as Marker3D
		if not marker:
			marker = Marker3D.new(); marker.name = "GripL"; pivot.add_child(marker)
		var wrist := inv * _bone(skel, "L_wrist")
		var palm0 := inv * _bone(skel, "L_palm")
		marker.position = target - (palm0 - wrist)
		skel.skeleton_updated.connect(_on_skel.bind(skel))
		var resid := 99.0
		for it in 4:
			await get_tree().create_timer(0.35).timeout
			if _palm == Vector3.INF: continue
			var pn := inv * _palm
			var d := target - pn
			resid = d.length() * 100.0 * pivot.global_basis.get_scale().x
			if it < 3:
				marker.position += d
		skel.skeleton_updated.disconnect(_on_skel)
		_palm = Vector3.INF
		get_viewport().get_texture().get_image().save_png("res://_prints/support/%s_hip.png" % wid)
		var side := Camera3D.new(); side.fov = 40.0; side.near = 0.01; add_child(side)
		var tgt: Vector3 = cam.to_global(Vector3(0.08, -0.22, -0.55))
		side.global_position = tgt + cam.global_basis.x * 1.3 + Vector3(0, 0.15, 0)
		side.look_at(tgt, Vector3.UP); side.make_current()
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png("res://_prints/support/%s_side.png" % wid)
		cam.make_current(); side.queue_free()
		lines.append('%s|%s|"grip_l": Vector3(%.4f, %.4f, %.4f),|residuo_cm=%.1f' % [wid, rule, marker.position.x, marker.position.y, marker.position.z, resid])
	FileAccess.open("res://_prints/support_fit.txt", FileAccess.WRITE).store_string("\n".join(lines))
	get_tree().quit()
