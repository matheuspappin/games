extends Node
# Vista de cima de um mapa com os limites/paredes invisíveis pintados de vermelho e os spawns marcados.
# uso: -- --map=res://scenes/_world/map_nuketown_1v1.tscn --name=classic
func _ready() -> void:
	if get_tree().current_scene == self:
		var r = Node.new(); r.set_script(get_script()); r.name = "MapTop"
		get_tree().root.add_child.call_deferred(r)
		return
	_run.call_deferred()
func _run() -> void:
	var map_path := "res://scenes/_world/map_nuketown_1v1.tscn"
	var nm := "classic"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="): map_path = a.substr(6)
		if a.begins_with("--name="): nm = a.substr(7)
	get_tree().change_scene_to_file(map_path)
	await get_tree().create_timer(9.0).timeout
	var sc = get_tree().current_scene
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false): c.visible = false
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(1, 0, 0, 0.55); red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var lines := []
	for b in sc.find_children("*", "CSGBox3D", true, false):
		if b.name == "SafetyFloor": continue
		b.material = red
		lines.append("%s pos=%s size=%s" % [b.name, b.global_position, b.size])
	var blue := StandardMaterial3D.new(); blue.albedo_color = Color(0.1, 0.2, 1.0); blue.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mb = sc.find_child("MapBoundaryWalls", true, false)
	if mb:
		for cs in mb.get_children():
			if not (cs is CollisionShape3D): continue
			var bm := MeshInstance3D.new(); var bx := BoxMesh.new(); bx.size = cs.shape.size; bm.mesh = bx
			bm.material_override = blue; mb.add_child(bm); bm.position = cs.position
		lines.append("paredes de limite: %d" % mb.get_child_count())
	var yel := StandardMaterial3D.new(); yel.albedo_color = Color(1, 1, 0); yel.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for s in sc.find_children("Spawn_*", "Node3D", true, false):
		if s.get_child_count() > 0: continue
		var m := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.6; cm.bottom_radius = 0.6; cm.height = 0.3
		m.mesh = cm; m.material_override = yel; sc.add_child(m); m.global_position = s.global_position + Vector3.UP * 12
		lines.append("%s %s" % [s.name, s.global_position])
	var model = sc.find_child("NuketownModel", true, false)
	if model == null: model = sc.find_child("Nuk3townModel", true, false)
	var bb := AABB(); var first := true
	if model:
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var g: AABB = mi.global_transform * mi.get_aabb()
			if g.size.length() > 300: continue
			bb = g if first else bb.merge(g); first = false
	lines.append("modelo aabb=%s" % bb)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 110
	sc.add_child(cam); cam.global_position = Vector3(0, 80, 0); cam.rotation_degrees = Vector3(-90, 0, 0); cam.current = true
	cam.far = 200
	var env = sc.find_child("WorldEnvironment", true, false)
	if env: env.environment = null
	await get_tree().process_frame; await get_tree().process_frame; await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://_prints/top_%s.png" % nm)
	# vistas em perspectiva das paredes dos quintais (pintadas de vermelho) para conferir se há cerca de verdade
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE; cam.fov = 70
	var views := [["oeste_meio", Vector3(-13.0, 1.7, 0.0), Vector3(-26.0, 1.0, 0.0)], ["leste_carro", Vector3(8.0, 1.7, -1.5), Vector3(20.0, 1.0, -1.5)], ["bravo_leste", Vector3(2.0, 1.7, 30.0), Vector3(12.0, 1.0, 30.0)], ["alpha_oeste", Vector3(-12.0, 1.7, -28.0), Vector3(-26.0, 1.0, -28.0)],
		["bravo_fundo", Vector3(0.0, 1.7, 28.0), Vector3(0.0, 1.0, 42.0)], ["alpha_fundo", Vector3(-14.0, 1.7, -26.0), Vector3(-14.0, 1.0, -40.0)]]
	for v in views:
		cam.global_position = v[1]; cam.look_at(v[2], Vector3.UP)
		await get_tree().process_frame; await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://_prints/view_%s_%s.png" % [nm, v[0]])
	FileAccess.open("res://_prints/top_%s.txt" % nm, FileAccess.WRITE).store_string("\n".join(lines))
	get_tree().quit()
