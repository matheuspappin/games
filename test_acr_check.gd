extends MainLoop

func _process(_delta: float) -> bool:
	var f = FileAccess.open("C:/gemini cli/games/test_acr_check_log.txt", FileAccess.WRITE)
	f.store_line("=== ACR 6.8 CHECK START ===")
	
	var sc = load("res://assets/models/weapons/clean/acr_rifle_clean.glb") as PackedScene
	if not sc:
		f.store_line("ERROR: Failed to load res://assets/models/weapons/clean/acr_rifle_clean.glb")
		f.close()
		return true
		
	var inst = sc.instantiate()
	f.store_line("Loaded GLB root: %s" % inst.name)
	for child in inst.get_children():
		f.store_line("  child: %s (%s)" % [child.name, child.get_class()])
		if child is MeshInstance3D and child.mesh:
			var aabb = child.mesh.get_aabb()
			f.store_line("    mesh: %s, aabb pos: %s, size: %s" % [child.mesh.resource_name, str(aabb.position), str(aabb.size)])
			for s in range(child.mesh.get_surface_count()):
				var mat = child.get_active_material(s)
				f.store_line("    surf %d: %s" % [s, mat.resource_name if mat else "default"])
	
	# Check WeaponVisualRegistry config for ak47
	var WVR = load("res://scripts/weapons/weapon_visual_registry.gd")
	var cfg = WVR.get_weapon_config("ak47")
	f.store_line("\nWeaponVisualRegistry config for 'ak47':")
	for k in cfg.keys():
		f.store_line("  %s: %s" % [str(k), str(cfg[k])])
		
	f.store_line("=== ACR 6.8 CHECK COMPLETE ===")
	f.close()
	return true
