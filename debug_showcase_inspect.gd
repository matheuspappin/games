extends MainLoop

func _process(_delta: float) -> bool:
	var f = FileAccess.open("C:/gemini cli/games/debug_showcase_inspect.txt", FileAccess.WRITE)
	var log_msg = func(txt: String):
		if f: f.store_line(txt)

	var wvr_cls = load("res://scripts/weapons/weapon_visual_registry.gd")
	if not wvr_cls:
		log_msg.call("Failed to load weapon_visual_registry.gd")
		if f: f.close()
		return true

	log_msg.call("=== DEBUGGING SHOWCASE FOR AK47 (ACR 6.8) AND LOCUS ===")
	
	for w_id in ["ak47", "locus", "m4a1", "smg", "shotgun"]:
		log_msg.call("\n---------------------------------------------------------")
		log_msg.call("WEAPON ID: " + w_id)
		log_msg.call("---------------------------------------------------------")
		var wrapper = wvr_cls.instantiate_weapon_showcase(w_id)
		if not wrapper:
			log_msg.call("  [ERROR] wrapper is NULL")
			continue
		
		# Check before camo
		log_msg.call("BEFORE apply_camo:")
		_dump_materials(wrapper, "  ", log_msg)
		
		# Call apply_camo with "default"
		wvr_cls.apply_camo(wrapper, "default")
		log_msg.call("\nAFTER apply_camo('default'):")
		_dump_materials(wrapper, "  ", log_msg)
		
		# Check attachments
		wvr_cls.update_attachments(wrapper, "optic_red_dot", "none", "none")
		log_msg.call("\nATTACHMENTS DUMP:")
		var att = wrapper.find_child("AttachmentContainer", true, false)
		if att:
			_dump_node(att, "  ", log_msg)
		else:
			log_msg.call("  No AttachmentContainer")
			
		# Check transforms of wrapper, pivot, inst
		var pivot = wrapper.get_node_or_null("Pivot")
		log_msg.call("\nTRANSFORMS:")
		log_msg.call("  wrapper pos=" + str(wrapper.position) + " scale=" + str(wrapper.scale))
		if pivot:
			log_msg.call("  pivot pos=" + str(pivot.position) + " rot=" + str(pivot.rotation_degrees))
			for c in pivot.get_children():
				if c is Node3D:
					log_msg.call("    child " + c.name + " pos=" + str(c.position) + " scale=" + str(c.scale) + " rot=" + str(c.rotation_degrees))
	
	if f: f.close()
	return true

func _dump_materials(n: Node, indent: String, log_msg: Callable) -> void:
	if n is MeshInstance3D:
		var mi = n as MeshInstance3D
		var override_mat = str(mi.material_override) if mi.material_override else "null"
		var surf0_mat = "none"
		if mi.mesh and mi.mesh.get_surface_count() > 0:
			var sm = mi.get_surface_override_material(0)
			if not sm: sm = mi.mesh.surface_get_material(0)
			surf0_mat = str(sm)
		log_msg.call(indent + mi.name + " (vis=" + str(mi.visible) + "): override=" + override_mat + " surf0=" + surf0_mat)
	for c in n.get_children():
		_dump_materials(c, indent + "  ", log_msg)

func _dump_node(node: Node, indent: String, log_msg: Callable) -> void:
	var info = ""
	if node is Node3D:
		info = " pos=" + str(node.position) + " scale=" + str(node.scale)
	log_msg.call(indent + "- " + node.name + " (" + node.get_class() + ")" + info)
	for child in node.get_children():
		_dump_node(child, indent + "  ", log_msg)
