# =============================================================================
# map_nuketown.gd
# Gerenciador e Configurador de Cenário — Nuketown (Call of Duty Style)
# Configura colisões trimesh automáticas, shaders de grama/asfalto e ambientação
# =============================================================================
class_name MapNuketown
extends Node3D

@export var setup_collisions_on_ready: bool = true

func _ready() -> void:
	print("[MapNuketown] Inicializando mapa Nuketown BO1...")
	_setup_materials_and_collisions()
	await _create_collisions_sliced()
	_setup_bot_manager()
	_setup_player()
	await _adjust_spawn_heights()

func _adjust_spawn_heights() -> void:
	# Aguardar 2 frames de física para que as colisões trimesh estejam 100% integradas no PhysicsServer3D
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	var space = get_world_3d().direct_space_state if get_world_3d() else null
	if not space:
		return
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
		# Raycast de cima (Y=6.0) para baixo (Y=-6.0)
		var ray_from = Vector3(pos.x, 6.0, pos.z)
		var ray_to = Vector3(pos.x, -6.0, pos.z)
		var query = PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1) # Layer 1: Geometria
		var hit = space.intersect_ray(query)
		if hit and hit.collider and not ("Safety" in hit.collider.name) and not ("Player" in hit.collider.name) and not ("Bot" in hit.collider.name):
			# Não fixar pontos de spawn em telhados ou toldos que estejam a mais de 0.8m do solo
			if hit.position.y <= 0.8:
				s_node.global_position.y = hit.position.y + 0.1
				print("[MapNuketown] Ponto de spawn %s ajustado para Y=%.3f (chão: %s)" % [s_node.name, s_node.global_position.y, hit.collider.name])
			else:
				s_node.global_position.y = 0.05
				print("[MapNuketown] Ponto de spawn %s ignorou telhado Y=%.3f e fixou no solo Y=0.05" % [s_node.name, hit.position.y])

func _setup_player() -> void:
	var cur_player = find_child("Player*", true, false)
	if not cur_player:
		var nm = get_node_or_null("/root/NetworkManager")
		if nm and nm.has_method("ensure_local_player_spawned"):
			nm.ensure_local_player_spawned(self)
		elif nm and nm.has_method("on_map_scene_ready"):
			nm.on_map_scene_ready()
	var args = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if "--test-screenshot" in args or "--test-quit" in args:
		for i in range(30):
			await get_tree().process_frame
		print("[MapNuketown] Test auto-run completed successfully!")
		get_tree().quit(0)

const BotManagerScript = preload("res://scripts/ai/bot_manager.gd")

func _setup_bot_manager() -> void:
	if not find_child("BotManager", true, false):
		var bm = BotManagerScript.new()
		bm.name = "BotManager"
		add_child(bm)

# Colisões trimesh criadas em fatias de ~6 ms por frame (antes: tudo num frame só, ~7 s de tela congelada)
var _pending_collisions: Array[MeshInstance3D] = []

func _create_collisions_sliced() -> void:
	var budget_us := 6000
	var t := Time.get_ticks_usec()
	for n in _pending_collisions:
		if not is_instance_valid(n):
			continue
		n.create_trimesh_collision()
		for child in n.get_children():
			if child is StaticBody3D:
				for col_child in child.get_children():
					if col_child is CollisionShape3D and col_child.shape is ConcavePolygonShape3D:
						col_child.shape.backface_collision = true
		if Time.get_ticks_usec() - t > budget_us:
			await get_tree().process_frame
			t = Time.get_ticks_usec()
	_pending_collisions.clear()

func _setup_materials_and_collisions() -> void:
	var nuketown_model = find_child("NuketownModel", true, false)
	if not nuketown_model:
		return

	# Helper para instanciar materiais com mapeamento triplanar de escala real
	var make_pbr_mat = func(albedo_path: String, norm_path: String, world_scale: Vector3, roughness: float, spec: float, tint: Color = Color.WHITE) -> StandardMaterial3D:
		var mat = StandardMaterial3D.new()
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = world_scale
		mat.roughness = roughness
		mat.metallic_specular = spec
		mat.albedo_color = tint
		if albedo_path != "" and ResourceLoader.exists(albedo_path):
			mat.albedo_texture = load(albedo_path)
		if norm_path != "" and ResourceLoader.exists(norm_path):
			mat.normal_enabled = true
			mat.normal_texture = load(norm_path)
		return mat

	# Materiais PBR fiéis ao Call of Duty: Black Ops (Nuketown 1960s)
	var mat_mint_house = make_pbr_mat.call("res://assets/textures/nuketown_classic/siding_mint_green.png", "res://assets/textures/nuketown_classic/siding_mint_green_norm.png", Vector3(0.35, 0.35, 0.35), 0.75, 0.15)
	var mat_yellow_house = make_pbr_mat.call("res://assets/textures/nuketown_classic/siding_vintage_yellow.png", "res://assets/textures/nuketown_classic/siding_vintage_yellow_norm.png", Vector3(0.35, 0.35, 0.35), 0.75, 0.15)
	var mat_roof = make_pbr_mat.call("res://assets/textures/nuketown_classic/roof_shingles_charcoal.png", "res://assets/textures/nuketown_classic/roof_shingles_norm.png", Vector3(0.45, 0.45, 0.45), 0.82, 0.10)
	var mat_brick = make_pbr_mat.call("res://assets/textures/nuketown_classic/brick_wall_red.png", "res://assets/textures/nuketown_classic/brick_wall_norm.png", Vector3(0.50, 0.50, 0.50), 0.80, 0.10)
	var mat_fence = make_pbr_mat.call("res://assets/textures/nuketown_classic/white_picket_fence.png", "", Vector3(0.60, 0.60, 0.60), 0.40, 0.30)
	var mat_deck = make_pbr_mat.call("res://assets/textures/nuketown_classic/deck_wood_planks.png", "", Vector3(0.50, 0.50, 0.50), 0.70, 0.15)
	var mat_dark_wood = make_pbr_mat.call("res://assets/textures/nuketown_classic/deck_wood_planks.png", "", Vector3(0.50, 0.50, 0.50), 0.65, 0.15, Color(0.45, 0.35, 0.28))
	var mat_garage = make_pbr_mat.call("res://assets/textures/nuketown_classic/garage_door_white.png", "", Vector3(0.30, 0.30, 0.30), 0.50, 0.25)
	var mat_grass = make_pbr_mat.call("res://assets/textures/nuketown_classic/suburban_lawn_grass.png", "", Vector3(0.22, 0.22, 0.22), 0.90, 0.08)
	var mat_road = make_pbr_mat.call("res://assets/textures/nuketown_classic/road_asphalt_dark.png", "res://assets/textures/nuketown_classic/road_asphalt_norm.png", Vector3(0.18, 0.18, 0.18), 0.85, 0.15)
	var mat_sidewalk = make_pbr_mat.call("res://assets/textures/nuketown_classic/sidewalk_concrete_clean.png", "", Vector3(0.35, 0.35, 0.35), 0.82, 0.12)

	var mat_glass = StandardMaterial3D.new()
	mat_glass.albedo_color = Color(0.20, 0.28, 0.32, 0.9)
	mat_glass.roughness = 0.10
	mat_glass.metallic = 0.30
	mat_glass.metallic_specular = 0.90

	var stack = [nuketown_model]
	while stack.size() > 0:
		var n : Node = stack.pop_back()
		if n is MeshInstance3D and n.mesh:
			var mname = n.name.to_lower()
			
			# Identificar meshes de cerca (cubos 056 a 114)
			var is_fence_cube = false
			if mname.begins_with("cube."):
				for f_idx in range(56, 115):
					if ("cube.%03d" % f_idx) in mname or ("cube.%d" % f_idx) in mname:
						is_fence_cube = true
						break

			if is_fence_cube:
				for s in range(n.mesh.get_surface_count()):
					n.set_surface_override_material(s, mat_fence)
			else:
				for s in range(n.mesh.get_surface_count()):
					var mat = n.get_active_material(s)
					if mat:
						var rname = mat.resource_name.to_lower()
						if "green_house" in rname:
							n.set_surface_override_material(s, mat_mint_house)
						elif "yellow_house" in rname:
							n.set_surface_override_material(s, mat_yellow_house)
						elif "roof" in rname:
							n.set_surface_override_material(s, mat_roof)
						elif "brick" in rname:
							n.set_surface_override_material(s, mat_brick)
						elif "whitw_wood" in rname or "fence" in rname:
							n.set_surface_override_material(s, mat_fence)
						elif "light_wood" in rname or "8.001" in rname:
							n.set_surface_override_material(s, mat_deck)
						elif "dark_wood" in rname:
							n.set_surface_override_material(s, mat_dark_wood)
						elif "garage" in rname:
							n.set_surface_override_material(s, mat_garage)
						elif "material.014" in rname or "plane.002" in rname or rname == "material_014":
							n.set_surface_override_material(s, mat_grass)
						elif "road.001" in rname:
							n.set_surface_override_material(s, mat_road)
						elif "road" in rname:
							n.set_surface_override_material(s, mat_sidewalk)
						elif "window" in rname:
							n.set_surface_override_material(s, mat_glass)

			# Gerar colisão trimesh se ainda não houver
			if setup_collisions_on_ready:
				var has_col = false
				for c in n.get_children():
					if c is StaticBody3D:
						has_col = true
						break
				if not has_col and not ("wire" in mname or "text" in mname or "window" in mname or "glass" in mname or "plane_074" in mname or "plane_095" in mname or "plane_102" in mname or "plane_103" in mname or "plane_104" in mname or "plane_105" in mname or "plane_106" in mname or "plane_107" in mname):
					_pending_collisions.append(n)

		for c in n.get_children():
			stack.push_back(c)

