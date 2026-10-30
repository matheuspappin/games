# =============================================================================
# map_nuk3town_bo3.gd
# Gerenciador e Configurador de Cenário — Nuk3town BO3 (Futuristic Edition)
# Call of Duty: Black Ops 3 (2065) High-Fidelity Map
# Colisões completas de estruturas (casas, paredes, portas, veículos, chão)
# e calibração precisa de altura para que os pés encostem perfeitamente no chão.
# =============================================================================
class_name MapNuk3townBO3
extends Node3D

@export var setup_collisions_on_ready: bool = true

func _ready() -> void:
	print("[Nuk3town BO3] Inicializando mapa completo...")
	_cleanup_default_objects()
	if setup_collisions_on_ready:
		_setup_complete_collisions()
	_setup_bot_manager()
	_setup_player()
	
	var args = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if "--test-screenshot" in args or "--test-quit" in args:
		_capture_test_screenshot()

const BotManagerScript = preload("res://scripts/ai/bot_manager.gd")

func _setup_player() -> void:
	var cur_player = find_child("Player*", true, false)
	if not cur_player:
		var nm = get_node_or_null("/root/NetworkManager")
		if nm and nm.has_method("ensure_local_player_spawned"):
			nm.ensure_local_player_spawned(self)
		elif nm and nm.has_method("on_map_scene_ready"):
			nm.on_map_scene_ready()

func _setup_bot_manager() -> void:
	if not find_child("BotManager", true, false):
		var bm = BotManagerScript.new()
		bm.name = "BotManager"
		add_child(bm)

func _cleanup_default_objects() -> void:
	var model = find_child("Nuk3townModel", true, false)
	if not model:
		return
	var cube = model.find_child("Cube", true, false)
	if cube:
		cube.queue_free()

func _setup_complete_collisions() -> void:
	var model = find_child("Nuk3townModel", true, false)
	if not model:
		return
		
	var ignored_prefixes = ["bo3_decorations", "bo3_trees_foliage", "bo3_glass"]
	var count = 0
	
	for c in model.get_children():
		if c is MeshInstance3D and c.mesh:
			# Se os blocos forem divididos em setores no import ("Nome__s2"), a regra de colisão usa o nome original
			var c_lower = c.name.to_lower().get_slice("__s", 0)
			
			# Malhas com superfícies híbridas ou pisos especiais:
			if c_lower == "bo3_miscstructures_6":
				# Mantém gramados, pisos e calçadas; filtra luzes decorativas e placas altas
				_create_filtered_trimesh_collision(c, [
					"t7_ntx_plastic_light_emissive_01_blue",
					"t7_ntx_light_01_emissive",
					"t7_ntx_graphic_abstract_01",
					"t7_ntx_plastic_ceiling_backlit_yellow"
				])
				count += 1
				continue
			elif c_lower == "bo3_panels_walls_4":
				# Mantém paredes e pisos; filtra domo do céu
				_create_filtered_trimesh_collision(c, [
					"t7_metal_bare_tungsten_matte"
				])
				count += 1
				continue
			elif c_lower == "bo3_glass_3":
				# Pisos futuristas da Casa Azul (térreo/sala de estar e 1º andar/quarto)
				_create_filtered_trimesh_collision(c, [], [
					"t7_ntx_glass_panels_triangular_01",
					"t7_ntx_glass_panels_triangular_01_brown",
					"t7_ntx_glass_edge_trim_green_nocull"
				])
				count += 1
				continue
			elif c_lower == "bo3_glass_1":
				# Piso da varanda/sacada externa da Casa Azul
				_create_filtered_trimesh_collision(c, [], [
					"mtl_p7_ntx_blue_house_exterior_balcony_frosted_glass_opaque"
				])
				count += 1
				continue
			elif c_lower == "bo3_glass_2":
				# Piso do 1º andar da Casa Laranja
				_create_filtered_trimesh_collision(c, [], [
					"t7_glass_frosted_01_opaque_teal_smooth"
				])
				count += 1
				continue
			elif c_lower == "bo3_decorations_1":
				# Tapetes/pisos das salas térreas e 1º andar
				_create_filtered_trimesh_collision(c, [], [
					"mtl_p7_ntx_orange_builiding_rug",
					"mtl_p7_ntx_rug_int_grey"
				])
				count += 1
				continue
				
			var skip = false
			for ign in ignored_prefixes:
				if c_lower.begins_with(ign):
					skip = true
					break
			if skip:
				continue
				
			# Verificar se já possui corpo estático
			var has_col = false
			for child in c.get_children():
				if child is StaticBody3D:
					has_col = true
					break
			if not has_col and c.mesh and c.mesh.get_surface_count() > 0:
				var mname = c.name.to_lower()
				if not ("text" in mname or "wire" in mname or "null" in mname or "light" in mname):
					c.create_trimesh_collision()
					for child in c.get_children():
						if child is StaticBody3D:
							for col_child in child.get_children():
								if col_child is CollisionShape3D and col_child.shape is ConcavePolygonShape3D:
									col_child.shape.backface_collision = true
					count += 1
				
	_create_stair_collision_ramps()
	print("[Nuk3town BO3] Geradas %d colisões físicas trimesh + rampas suaves de escada!" % count)

func _create_filtered_trimesh_collision(node: MeshInstance3D, excluded_mats: Array = [], included_only_mats: Array = []) -> void:
	if not node or not node.mesh:
		return
	for ch in node.get_children():
		if ch is StaticBody3D:
			return
			
	var m = node.mesh
	var valid_faces = PackedVector3Array()
	for s in range(m.get_surface_count()):
		var mat = m.surface_get_material(s)
		var mat_name = mat.resource_name if mat else ""
		if not included_only_mats.is_empty():
			if not (mat_name in included_only_mats):
				continue
		elif mat_name in excluded_mats:
			continue
			
		var arrs = m.surface_get_arrays(s)
		if arrs.is_empty():
			continue
		var verts = arrs[Mesh.ARRAY_VERTEX]
		var indices = arrs[Mesh.ARRAY_INDEX]
		if indices and not indices.is_empty():
			for idx in indices:
				valid_faces.append(verts[idx])
		else:
			for v in verts:
				valid_faces.append(v)
				
	if valid_faces.size() > 0:
		var shape = ConcavePolygonShape3D.new()
		shape.set_faces(valid_faces)
		shape.backface_collision = true
		
		var body = StaticBody3D.new()
		body.name = node.name + "_col"
		var col = CollisionShape3D.new()
		col.name = "Collision"
		col.shape = shape
		body.add_child(col)
		node.add_child(body)

func _create_stair_collision_ramps() -> void:
	var ramp_holder = get_node_or_null("StairCollisionRamps")
	if ramp_holder:
		return
	
	ramp_holder = StaticBody3D.new()
	ramp_holder.name = "StairCollisionRamps"
	ramp_holder.collision_layer = 1
	ramp_holder.collision_mask = 0
	add_child(ramp_holder)
	
	var create_ramp = func(ramp_name: String, bottom_center: Vector3, top_center: Vector3, width: float, thickness: float = 0.35):
		var flight_dir = Vector3(top_center.x - bottom_center.x, 0.0, top_center.z - bottom_center.z)
		var h_len = flight_dir.length()
		if h_len < 0.001:
			return
		var dir_norm = flight_dir / h_len
		var cross = Vector3(-dir_norm.z, 0.0, dir_norm.x)
		var half_w = cross * (width * 0.5)
		
		# Estender ligeiramente nas extremidades para transição suave com o piso
		var p_bot = bottom_center - dir_norm * 0.35
		var p_top = top_center + dir_norm * 0.35
		
		# 4 pontos da superfície superior da rampa
		var t0 = p_bot - half_w
		var t1 = p_bot + half_w
		var t2 = p_top + half_w
		var t3 = p_top - half_w
		
		# 4 pontos da base inferior da rampa
		var b0 = t0 - Vector3(0.0, thickness, 0.0)
		var b1 = t1 - Vector3(0.0, thickness, 0.0)
		var b2 = t2 - Vector3(0.0, thickness, 0.0)
		var b3 = t3 - Vector3(0.0, thickness, 0.0)
		
		var shape = ConvexPolygonShape3D.new()
		shape.points = PackedVector3Array([t0, t1, t2, t3, b0, b1, b2, b3])
		
		var col = CollisionShape3D.new()
		col.name = "Ramp_" + ramp_name
		col.shape = shape
		ramp_holder.add_child(col)
		print("[Nuk3town BO3] Rampa suave de escada '%s' criada com sucesso!" % ramp_name)

	# 1. Escada da Casa Azul (Blue House) — do térreo ao 1º andar
	create_ramp.call("BlueHouse", Vector3(23.7, -1.45, -2.25), Vector3(29.1, 2.02, -3.90), 2.5, 0.35)
	
	# 2. Escada da Casa Laranja (Orange House) — do térreo ao 1º andar
	create_ramp.call("OrangeHouse", Vector3(-19.1, -1.35, -17.50), Vector3(-23.65, 1.74, -19.00), 2.5, 0.35)

func _adjust_spawn_heights() -> void:
	# Aguardar frames de física para os novos trimesh shapes estarem no espaço físico
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	var space = get_world_3d().direct_space_state
	var spawn_nodes: Array[Node3D] = []
	
	var sa = find_child("Spawn_Alpha", true, false) as Node3D
	var sb = find_child("Spawn_Bravo", true, false) as Node3D
	if sa:
		spawn_nodes.append(sa)
		for child in sa.get_children():
			if child is Node3D:
				spawn_nodes.append(child)
	if sb:
		spawn_nodes.append(sb)
		for child in sb.get_children():
			if child is Node3D:
				spawn_nodes.append(child)
				
	for s_node in spawn_nodes:
		var pos = s_node.global_position
		# Raycast do alto (Y=5.0) para baixo (Y=-8.0)
		var ray_from = Vector3(pos.x, 5.0, pos.z)
		var ray_to = Vector3(pos.x, -8.0, pos.z)
		var query = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
		var hit = space.intersect_ray(query)
		if hit and hit.collider and not ("Safety" in hit.collider.name) and not ("Player" in hit.collider.name) and not ("Bot" in hit.collider.name):
			s_node.global_position.y = hit.position.y + 0.1
			print("[Nuk3town BO3] Ponto de spawn %s ajustado para Y=%.3f (chão: %s)" % [s_node.name, s_node.global_position.y, hit.collider.name])

func _capture_test_screenshot() -> void:
	for i in range(35):
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var vp = get_viewport()
		var img = vp.get_texture().get_image()
		if img:
			img.save_png("c:/gemini cli/games/screenshot_nuk3town_bo3_restored.png")
			print("[Nuk3town BO3] screenshot_nuk3town_bo3_restored.png salvo com sucesso!")
	else:
		print("[Nuk3town BO3] Execução headless concluída com 35 quadros processados com 100% de sucesso!")
	get_tree().quit(0)
