extends Node
func _ready() -> void:
	var out := []
	for f in DirAccess.get_files_at("res://scenes/weapons/attachments"):
		if not f.ends_with(".tscn"): continue
		var inst: Node3D = load("res://scenes/weapons/attachments/" + f).instantiate()
		add_child(inst)
		var ab := AABB(); var first := true
		var parts := []
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			if m.mesh == null: continue
			var b: AABB = (inst.global_transform.affine_inverse() * m.global_transform) * m.get_aabb()
			ab = b if first else ab.merge(b); first = false
			parts.append("%s vis=%s %s..%s" % [m.name, str(m.is_visible_in_tree()), str(b.position.snapped(Vector3.ONE*0.001)), str(b.end.snapped(Vector3.ONE*0.001))])
		out.append("%s: tam=%s de %s a %s raiz_rot=%s escala=%s" % [f, str(ab.size.snapped(Vector3.ONE*0.001)), str(ab.position.snapped(Vector3.ONE*0.001)), str(ab.end.snapped(Vector3.ONE*0.001)), str(inst.rotation_degrees), str(inst.scale)])
		for p in parts: out.append("    " + p)
		inst.queue_free()
	FileAccess.open("res://_prints/att_dims.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
