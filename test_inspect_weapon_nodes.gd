extends MainLoop

func _process(_delta: float) -> bool:
	var f = FileAccess.open("C:/gemini cli/games/test_model_nodes.txt", FileAccess.WRITE)
	var log_msg = func(txt: String):
		print(txt)
		if f: f.store_line(txt)

	log_msg.call("=== INSPECIONANDO MODELOS 3D ===")
	
	var models = [
		{"type": "smg", "path": "res://addons/fps-hands/fps-smg45/resources/fps_animated_smg.glb"},
		{"type": "ak", "path": "res://addons/fps-hands/fps-ak/reasources/fps_ak_animated.glb"},
		{"type": "rifle", "path": "res://assets/models/fps_hands_rifle/scene.gltf"},
		{"type": "lmg", "path": "res://addons/fps-hands/fps-lmg63/resources/lmg_animated.glb"},
		{"type": "shotgun", "path": "res://addons/fps-hands/fps-sawnoff/resources/sawnoff_animated.glb"},
		{"type": "pistol", "path": "res://addons/fps-hands/fps-c19/resources/fps_pistol_animated.glb"},
		{"type": "knife", "path": "res://addons/fps-hands/fps-knife/resources/knife_animated.glb"},
	]

	for item in models:
		log_msg.call("\n==========================================")
		log_msg.call("Model: %s (%s)" % [item.type, item.path])
		if not ResourceLoader.exists(item.path):
			log_msg.call("  [ERROR] File does not exist!")
			continue
		var sc = load(item.path) as PackedScene
		if not sc:
			log_msg.call("  [ERROR] PackedScene load failed!")
			continue
		var inst = sc.instantiate()
		_clean_arms(inst)
		_dump_nodes(inst, "  ", log_msg)
		var aabb = _calc_visible_aabb(inst)
		log_msg.call("  -> Visible Meshes AABB:")
		log_msg.call("     pos: %s, size: %s" % [aabb.position, aabb.size])
		log_msg.call("     center: %s, longest_axis: %.3f" % [aabb.get_center(), aabb.get_longest_axis_size()])
		inst.free()

	if f: f.close()
	return true

func _clean_arms(node: Node) -> void:
	if node is MeshInstance3D:
		var n_low = node.name.to_lower()
		var m_name = node.mesh.resource_name.to_lower() if node.mesh else ""
		if "arm" in n_low or "hand" in n_low or "pole" in n_low or "wrist" in n_low or node.name == "Object_7" or "arm" in m_name:
			node.visible = false
	for child in node.get_children():
		_clean_arms(child)

func _dump_nodes(node: Node, indent: String, log_msg: Callable) -> void:
	for child in node.get_children():
		var info = "%s%s (%s, vis=%s)" % [indent, child.name, child.get_class(), str(child.visible if child is Node3D else true)]
		if child is MeshInstance3D:
			var mi = child as MeshInstance3D
			info += " [mesh: %s, aabb_pos: %s, aabb_size: %s, xform_pos: %s]" % [
				(mi.mesh.resource_name if mi.mesh else "none"),
				mi.get_aabb().position,
				mi.get_aabb().size,
				mi.position
			]
		log_msg.call(info)
		if child.get_child_count() > 0 and indent.length() < 10:
			_dump_nodes(child, indent + "  ", log_msg)

func _calc_visible_aabb(root: Node3D) -> AABB:
	var total = AABB()
	var first = true
	var stack = [root]
	while not stack.is_empty():
		var curr = stack.pop_back()
		if curr is MeshInstance3D and curr.visible:
			var mi = curr as MeshInstance3D
			# transform mesh local aabb to root space
			var tf = root.global_transform.affine_inverse() * mi.global_transform
			var mesh_aabb = tf * mi.get_aabb()
			if first:
				total = mesh_aabb
				first = false
			else:
				total = total.merge(mesh_aabb)
		for c in curr.get_children():
			stack.append(c)
	return total
