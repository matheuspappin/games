extends Node
# Para cada lane dos bots: raio na altura do peito entre waypoints consecutivos. Mostra o que bloqueia.
# uso: -- --map=res://scenes/_world/map_nuk3town_bo3.tscn --name=bo3
func _ready() -> void:
	if get_tree().current_scene == self:
		var r = Node.new(); r.set_script(get_script()); r.name = "LaneAudit"
		get_tree().root.add_child.call_deferred(r)
		return
	_run.call_deferred()
func _run() -> void:
	var map_path := "res://scenes/_world/map_nuk3town_bo3.tscn"
	var nm := "bo3"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="): map_path = a.substr(6)
		if a.begins_with("--name="): nm = a.substr(7)
	get_tree().change_scene_to_file(map_path)
	await get_tree().create_timer(10.0).timeout
	var sc = get_tree().current_scene
	for b in get_tree().get_nodes_in_group("enemies"): b.queue_free()
	await get_tree().physics_frame
	var g = load("res://scripts/ai/tactical_nav_graph.gd").new(sc)
	var space = sc.get_world_3d().direct_space_state
	var lines := ["mapa=%s" % map_path]
	for lane in 4:
		var ids: Array = g.lane_nodes[lane]
		for i in range(ids.size() - 1):
			var a: Vector3 = g.nodes[ids[i]].position + Vector3.UP * 1.2
			var b: Vector3 = g.nodes[ids[i + 1]].position + Vector3.UP * 1.2
			var q := PhysicsRayQueryParameters3D.create(a, b, 1)
			var hit = space.intersect_ray(q)
			var tag := "livre"
			if hit:
				tag = "BLOQUEADO por %s em %s" % [hit.collider.name, (hit.position as Vector3).snapped(Vector3.ONE * 0.1)]
			# chão sob o waypoint de destino (nó flutuando ou dentro de algo = rota quebrada)
			var fq := PhysicsRayQueryParameters3D.create(b + Vector3.UP * 2.0, b - Vector3.UP * 4.0, 1)
			var fh = space.intersect_ray(fq)
			var floor_tag: String = ("chao %s y=%.2f" % [fh.collider.name, fh.position.y]) if fh else "SEM CHAO"
			lines.append("lane %d  %d(%s)->%d(%s)  %s | %s" % [lane, ids[i], g.nodes[ids[i]].label, ids[i + 1], g.nodes[ids[i + 1]].label, tag, floor_tag])
	# candidatos para o nó 3 (garagem amarela): visão livre até os vizinhos 1 e 6 e chão baixo
	if nm == "classic":
		var n1: Vector3 = g.nodes[1].position + Vector3.UP * 1.2
		var n6: Vector3 = g.nodes[6].position + Vector3.UP * 1.2
		for dx in [-2.0, -1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0, 3.0]:
			for dz in [-3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0]:
				var c: Vector3 = g.nodes[3].position + Vector3(dx, 1.2, dz)
				var ok1 = space.intersect_ray(PhysicsRayQueryParameters3D.create(c, n1, 1)).is_empty()
				var ok6 = space.intersect_ray(PhysicsRayQueryParameters3D.create(c, n6, 1)).is_empty()
				var fh = space.intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3.UP * 0.5, c - Vector3.UP * 3.0, 1))
				if ok1 and ok6 and fh and fh.position.y < 0.5:
					lines.append("candidato no3 livre: %s" % (c - Vector3.UP * 1.2))
	FileAccess.open("res://_prints/lane_audit_%s.txt" % nm, FileAccess.WRITE).store_string("\n".join(lines))
	get_tree().quit()
