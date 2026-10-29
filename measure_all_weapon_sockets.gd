extends MainLoop

const WeaponVisualRegistryScript = preload("res://scripts/weapons/weapon_visual_registry.gd")

func _process(_delta: float) -> bool:
	var f = FileAccess.open("C:/gemini cli/games/measure_out.txt", FileAccess.WRITE)
	if not f:
		return true
		
	f.store_line("==================================================")
	f.store_line("=== MEASURING WEAPON BOUNDS & SOCKET LOCATIONS ===")
	f.store_line("==================================================")
	
	var weapons = WeaponVisualRegistryScript.REGISTRY.keys()
	for w_id in weapons:
		var wrapper = WeaponVisualRegistryScript.instantiate_weapon_showcase(w_id)
		if not wrapper:
			f.store_line("[%s] FAILED to instantiate!" % w_id)
			continue
			
		var pivot = wrapper.get_node_or_null("Pivot")
		var inst: Node3D = null
		for c in pivot.get_children():
			if c is Node3D and c.name != "AttachmentContainer":
				inst = c
				break
				
		var aabb = _calc_aabb(inst)
		var center = aabb.get_center()
		var size = aabb.size
		var top_rail = Vector3(0, aabb.position.y + size.y, center.z)
		var muzzle = Vector3(0, center.y, aabb.position.z) # Front is usually -Z
		var stock = Vector3(0, center.y, aabb.position.z + size.z) # Rear is +Z
		var mag = Vector3(0, aabb.position.y, center.z) # Bottom
		var grip_pos = Vector3(0, aabb.position.y + size.y * 0.25, center.z - size.z * 0.2)
		
		f.store_line("\n[%s] Scale: %0.4f | AABB Center: %s | Size: %s" % [w_id, inst.scale.x, str(center), str(size)])
		f.store_line("  Calculated: Optic=%s | Muzzle=%s | Mag=%s | Stock=%s | Underbarrel=%s" % [
			_v_str(top_rail), _v_str(muzzle), _v_str(mag), _v_str(stock), _v_str(grip_pos)
		])
		
		var cfg = wrapper.get_meta("config", {})
		f.store_line("  Current in Registry: Optic=%s | Muzzle=%s | Mag=%s" % [
			cfg.get("socket_optic", Vector3.ZERO),
			cfg.get("socket_muzzle", Vector3.ZERO),
			cfg.get("socket_mag", Vector3.ZERO)
		])
		
		wrapper.free()
		
	f.close()
	return true

func _v_str(v: Vector3) -> String:
	return "Vector3(%0.4f, %0.4f, %0.4f)" % [v.x, v.y, v.z]

func _calc_aabb(root: Node3D) -> AABB:
	var total = AABB()
	var first = true
	var stack: Array = [[root, root.transform]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var curr = item[0]
		var tf: Transform3D = item[1]
		if curr is MeshInstance3D and curr.visible and curr.mesh:
			var mi = curr as MeshInstance3D
			var mesh_aabb = tf * mi.get_aabb()
			if first:
				total = mesh_aabb
				first = false
			else:
				total = total.merge(mesh_aabb)
		for c in curr.get_children():
			if c is Node3D:
				stack.append([c, tf * c.transform])
			else:
				stack.append([c, tf])
	return total
