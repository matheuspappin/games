extends SceneTree

func _init() -> void:
	print("=== CHECKING ACR 6.8 SIGHTS AND ADS ===")
	
	var WVR = load("res://scripts/weapons/weapon_visual_registry.gd")
	var cfg = WVR.get_weapon_config("ak47")
	print("ak47 cfg socket_iron_ads: ", cfg.get("socket_iron_ads"))
	print("ak47 cfg model_rotation: ", cfg.get("model_rotation"))
	print("ak47 cfg vm_rotation: ", cfg.get("vm_rotation"))
	print("ak47 cfg vm_rot_y: ", cfg.get("vm_rot_y"))
	print("ak47 cfg vm_offset: ", cfg.get("vm_offset"))
	
	# Instantiate weapon
	var wrapper = WVR.instantiate_weapon_for_hand("ak47")
	if not wrapper:
		print("ERROR: wrapper is null")
		quit(1)
		return
		
	var pivot = wrapper.get_node("Pivot")
	var inst = pivot.get_child(0) as Node3D
	print("inst.position: ", inst.position)
	print("inst.scale: ", inst.scale)
	print("inst.rotation_degrees: ", inst.rotation_degrees)
	
	# Find top vertices of mesh
	var mesh_inst: MeshInstance3D = null
	for c in inst.find_children("*", "MeshInstance3D", true, false):
		if c.name.contains("Rifle_0.001"):
			mesh_inst = c
			break
	if not mesh_inst:
		for c in inst.find_children("*", "MeshInstance3D", true, false):
			mesh_inst = c
			break
			
	if mesh_inst and mesh_inst.mesh:
		print("Found mesh: ", mesh_inst.name)
		var mdt = MeshDataTool.new()
		mdt.create_from_surface(mesh_inst.mesh, 0)
		var vc = mdt.get_vertex_count()
		
		# Find front and rear sights
		var front_top = Vector3(-999, -999, -999)
		var rear_top = Vector3(-999, -999, -999)
		
		for i in range(vc):
			var v = mdt.get_vertex(i)
			# front sight is at Z < -0.25
			if v.z < -0.25 and v.y > front_top.y:
				front_top = v
			# rear sight is at Z > 0.15
			if v.z > 0.15 and v.y > rear_top.y:
				rear_top = v
				
		print("In GLB local mesh coords:")
		print("  Front top vertex: ", front_top)
		print("  Rear top vertex:  ", rear_top)
		
		# Transform into Pivot coords:
		# inst has scale and translation
		var front_in_pivot = inst.position + front_top * inst.scale
		var rear_in_pivot = inst.position + rear_top * inst.scale
		print("In Pivot coords:")
		print("  Front sight peak in pivot: ", front_in_pivot)
		print("  Rear sight peak in pivot:  ", rear_in_pivot)
		print("  Delta (front - rear):      ", front_in_pivot - rear_in_pivot)
		
	quit(0)
