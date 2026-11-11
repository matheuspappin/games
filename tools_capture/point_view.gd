extends Node
# Fotografa pontos de bloqueio (colisão) do mapa: câmera a 4 m olhando o ponto, com a colisão do nó
# atingido destacada em vermelho translúcido por cima da malha visível.
const PTS := [["veh_rua", Vector3(6.0, -0.2, 0.2), Vector3(0, 0, 1)], ["veh_sala_laranja", Vector3(-19.8, -0.2, -0.5), Vector3(1, 0, 0)],
	["veh_rua_norte", Vector3(2.7, -0.2, -6.6), Vector3(0, 0, 1)], ["props8_rua", Vector3(-0.3, -0.2, 4.7), Vector3(1, 0, 0)], ["veh_beco", Vector3(4.2, -0.2, -15.1), Vector3(1, 0, 0)]]
func _ready() -> void:
	if get_tree().current_scene == self:
		var r = Node.new(); r.set_script(get_script()); r.name = "PointView"
		get_tree().root.add_child.call_deferred(r)
		return
	_run.call_deferred()
func _run() -> void:
	get_tree().change_scene_to_file("res://scenes/_world/map_nuk3town_bo3.tscn")
	await get_tree().create_timer(10.0).timeout
	var sc = get_tree().current_scene
	for b in get_tree().get_nodes_in_group("enemies"): b.queue_free()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false): c.visible = false
	var space = sc.get_world_3d().direct_space_state
	var cam := Camera3D.new(); cam.fov = 75; sc.add_child(cam); cam.current = true
	var lines := []
	for p in PTS:
		var target: Vector3 = p[1]
		var dir: Vector3 = p[2]
		cam.global_position = target - dir * 4.0 + Vector3.UP * 0.3
		cam.look_at(target, Vector3.UP)
		# o que o raio da câmera até o ponto acerta primeiro (malha visível ou colisão)
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, target + dir * 0.3, 1)
		var hit = space.intersect_ray(q)
		lines.append("%s: %s" % [p[0], ("acerta %s em %s face=%s" % [hit.collider.name, hit.position, hit.get("face_index", -1)]) if hit else "nada"])
		await get_tree().process_frame; await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://_prints/pt_%s.png" % p[0])
	FileAccess.open("res://_prints/point_view.txt", FileAccess.WRITE).store_string("\n".join(lines))
	get_tree().quit()
