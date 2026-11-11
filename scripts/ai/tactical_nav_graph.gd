# =============================================================================
# tactical_nav_graph.gd
# Rede Topológica de Navegação Tática A* para Nuketown 2065 (BO3) e Nuketown BO1
# Guia os bots através de portas, corredores, becos, calçadas, garagens e 2º andar,
# garantindo conectividade 100% livre de bloqueios e passagens suaves por portais.
# =============================================================================
class_name TacticalNavGraph
extends RefCounted

class NavNode:
	var id: int
	var position: Vector3
	var label: String
	var neighbors: Array[int] = []
	var is_portal: bool = false
	var is_power_pos: bool = false
	var power_look_dir: Vector3 = Vector3.ZERO
	var floor_level: int = 0  # 0 = térreo, 1 = 1º andar / superior

	func _init(p_id: int, p_pos: Vector3, p_label: String = "", p_neighbors: Array[int] = [], p_portal: bool = false, p_power: bool = false, p_look: Vector3 = Vector3.ZERO, p_floor: int = 0):
		id = p_id
		position = p_pos
		label = p_label
		neighbors = p_neighbors
		is_portal = p_portal
		is_power_pos = p_power
		power_look_dir = p_look
		floor_level = p_floor

enum TacticalLane {
	FLANK_LEFT = 0,    # Beco Esquerdo (Beco Norte no BO3 / Beco Oeste no BO1)
	FLANK_ALLEY = 0,   # Alias de compatibilidade
	STREET_CENTER = 1, # Rua Central (Combate direto entre veículos e ônibus)
	HOUSES = 2,        # Interior das casas, salas, portas, escadas e 2º andar
	FLANK_RIGHT = 3    # Beco Direito (Beco Sul & Garagens no BO3 / Beco Leste no BO1)
}

var scene_ref: Node = null
var is_bo3: bool = false
var nodes: Dictionary = {} # id -> NavNode
var astar: AStar3D = AStar3D.new()
var patrol_waypoints: Array[Vector3] = []
var lane_nodes: Dictionary = { 0: [], 1: [], 2: [], 3: [] }
var power_positions: Array[Dictionary] = []

func _init(scene_or_map: Node = null):
	scene_ref = scene_or_map
	if scene_or_map:
		_detect_map_type(scene_or_map)
	else:
		is_bo3 = true
	_build_graph()

func _detect_map_type(map_node: Node) -> void:
	var scene_name = map_node.name.to_lower()
	var scene_path = map_node.scene_file_path.to_lower() if ("scene_file_path" in map_node) else ""
	if "bo3" in scene_name or "2065" in scene_name or "bo3" in scene_path or "2065" in scene_path:
		is_bo3 = true
	elif map_node.find_child("Nuk3townModel", true, false) != null:
		is_bo3 = true
	else:
		is_bo3 = false

func _build_graph() -> void:
	astar.clear()
	nodes.clear()
	patrol_waypoints.clear()
	power_positions.clear()
	lane_nodes = { 0: [], 1: [], 2: [], 3: [] }

	if is_bo3:
		_build_bo3_graph()
	else:
		_build_bo1_graph()

	# Registrar pontos no AStar3D com peso tático em portas/passagens estreitas
	for id in nodes:
		var n: NavNode = nodes[id]
		var weight = 1.6 if n.is_portal else 1.0
		astar.add_point(n.id, n.position, weight)

	# Registrar arestas bidirecionais garantindo topologia 100% íntegra (sem auto-sabotagem por raycasts de soleira)
	for id in nodes:
		var n: NavNode = nodes[id]
		for n_id in n.neighbors:
			if nodes.has(n_id) and not astar.are_points_connected(id, n_id):
				astar.connect_points(id, n_id, true)

func _build_bo3_graph() -> void:
	# Y do chão no BO3 é ~ -1.45, 2º andar é ~ 1.95 a 2.05
	var gy = -1.45
	var raw_nodes: Array[NavNode] = [
		# --- BASE ALPHA (Leste / Casa Azul) ---
		NavNode.new(0, Vector3(42.0, gy, -8.0), "Alpha_Spawn", [1, 2, 3]),
		NavNode.new(1, Vector3(38.0, gy, -12.0), "Alpha_Yard_North", [0, 4]),
		NavNode.new(2, Vector3(40.0, gy, -2.0), "Alpha_Yard_South", [0, 3, 12]),
		NavNode.new(3, Vector3(34.0, gy, -2.0), "Alpha_Backyard_Gate", [0, 2, 8, 12], true),

		# --- BECO NORTE (FLANK ESQUERDO ALPHA / FLANK DIREITO BRAVO) ---
		NavNode.new(4, Vector3(34.0, gy, -18.5), "Blue_Alley_East", [1, 6]),
		NavNode.new(6, Vector3(20.0, gy, -18.5), "Blue_Alley_Mid", [4, 7]),
		NavNode.new(7, Vector3(10.0, gy, -18.5), "Blue_Alley_West", [6, 14]),
		NavNode.new(14, Vector3(4.0, gy, -15.0), "Street_North_Blue", [7, 18]),
		NavNode.new(18, Vector3(0.0, gy, -12.0), "Street_Center_NorthTruck", [14, 15, 57, 58, 19]),
		NavNode.new(15, Vector3(-4.0, gy, -15.0), "Street_North_Orange", [18, 24]),
		NavNode.new(24, Vector3(-10.0, gy, -18.5), "Orange_Alley_East", [15, 25]),
		NavNode.new(25, Vector3(-20.0, gy, -18.5), "Orange_Alley_Mid", [24, 34]),
		NavNode.new(34, Vector3(-34.0, gy, -18.5), "Orange_Alley_West", [25, 35]),

		# --- CASA AZUL & GARAGEM ---
		NavNode.new(8, Vector3(26.0, gy, -0.5), "Blue_Back_Door", [3, 9, 41], true),
		NavNode.new(9, Vector3(18.0, gy, -0.5), "Blue_Living_Room", [8, 10, 13, 41], true),
		NavNode.new(10, Vector3(12.0, gy, -0.5), "Blue_Front_Door", [9, 11], true),
		NavNode.new(11, Vector3(6.0, gy, -0.5), "Blue_Front_Porch", [10, 17, 19]),
		NavNode.new(12, Vector3(26.0, gy, 3.5), "Blue_Garage_Back", [2, 3, 40], true),
		NavNode.new(40, Vector3(19.0, gy, 3.5), "Blue_Garage_Inside", [12, 13]),
		NavNode.new(13, Vector3(12.0, gy, 3.5), "Blue_Garage_Driveway", [9, 40, 17], true),
		NavNode.new(17, Vector3(6.0, gy, 3.5), "Blue_Driveway_Street", [11, 13, 21]),

		# --- CASA AZUL 2º ANDAR & ESCADAS (HIGH GROUND POWER POSITION) ---
		NavNode.new(41, Vector3(23.7, gy, -2.25), "Blue_Stairs_Bottom", [8, 9, 42], true),
		NavNode.new(42, Vector3(29.1, 2.02, -3.90), "Blue_Stairs_Top", [41, 43], true),
		NavNode.new(43, Vector3(22.0, 2.02, -3.5), "Blue_Upper_Hall", [42, 44, 45], true, false, Vector3.ZERO, 1),
		NavNode.new(44, Vector3(13.5, 2.02, -3.5), "Blue_Upper_Window", [43], false, true, Vector3(-1, 0, 0), 1),
		NavNode.new(45, Vector3(11.0, 2.02, 1.5), "Blue_Upper_Balcony", [43], false, true, Vector3(-1, 0, 0), 1),

		# --- RUA CENTRAL (Entre Ônibus, Caminhão e Rotatória) ---
		NavNode.new(57, Vector3(3.0, gy, -6.0), "Street_Center_Truck_East", [18, 19]),
		NavNode.new(58, Vector3(-3.0, gy, -6.0), "Street_Center_Truck_West", [18, 19]),
		NavNode.new(19, Vector3(0.0, gy, 0.0), "Street_Center_Mid", [18, 57, 58, 59, 11, 26]),
		NavNode.new(59, Vector3(0.0, gy, 2.5), "Street_Center_Bus_Aisle", [19, 21]),
		NavNode.new(21, Vector3(0.0, gy, 5.0), "Street_South_Bus", [59, 17, 51]),

		# --- CASA LARANJA & GARAGEM ---
		NavNode.new(26, Vector3(-6.0, gy, -0.5), "Orange_Front_Porch", [19, 28, 51]),
		NavNode.new(28, Vector3(-12.0, gy, -0.5), "Orange_Front_Door", [26, 30], true),
		NavNode.new(30, Vector3(-18.0, gy, -0.5), "Orange_Living_Room", [28, 31, 27, 52], true),
		NavNode.new(31, Vector3(-26.0, gy, -0.5), "Orange_Back_Door", [30, 32], true),
		NavNode.new(32, Vector3(-34.0, gy, -2.0), "Orange_Back_Patio", [31, 36, 33], true),
		NavNode.new(51, Vector3(-6.0, gy, 3.5), "Orange_Driveway_Street", [21, 26, 27]),
		NavNode.new(27, Vector3(-12.0, gy, 3.5), "Orange_Garage_Driveway", [30, 51, 50], true),
		NavNode.new(50, Vector3(-19.0, gy, 3.5), "Orange_Garage_Inside", [27, 29]),
		NavNode.new(29, Vector3(-26.0, gy, 3.5), "Orange_Garage_Back", [50, 33], true),

		# --- CASA LARANJA 2º ANDAR & ESCADAS (HIGH GROUND POWER POSITION) ---
		NavNode.new(52, Vector3(-19.1, -1.35, -17.50), "Orange_Stairs_Bottom", [30, 25, 53], true),
		NavNode.new(53, Vector3(-23.65, 1.74, -19.00), "Orange_Stairs_Top", [52, 54], true),
		NavNode.new(54, Vector3(-22.0, 1.74, -12.0), "Orange_Upper_Hall", [53, 55, 56], true, false, Vector3.ZERO, 1),
		NavNode.new(55, Vector3(-13.5, 1.74, -3.5), "Orange_Upper_Window", [54], false, true, Vector3(1, 0, 0), 1),
		NavNode.new(56, Vector3(-11.0, 1.74, 1.5), "Orange_Upper_Balcony", [54], false, true, Vector3(1, 0, 0), 1),

		# --- BASE BRAVO (Oeste / Casa Laranja) ---
		NavNode.new(33, Vector3(-38.0, gy, 1.0), "Bravo_Yard_South", [29, 32, 36]),
		NavNode.new(35, Vector3(-38.0, gy, -12.0), "Bravo_Yard_North", [34, 36]),
		NavNode.new(36, Vector3(-42.0, gy, -8.0), "Bravo_Spawn", [32, 33, 35]),
	]

	for n in raw_nodes:
		nodes[n.id] = n
		if n.is_power_pos:
			power_positions.append({
				"id": n.id,
				"position": n.position,
				"look_dir": n.power_look_dir,
				"label": n.label,
				"team_bias": 0 if n.position.x > 0 else 1
			})
		if n.id in [0, 4, 6, 7, 9, 11, 14, 17, 18, 19, 21, 24, 25, 26, 30, 32, 34, 36, 44, 55]:
			patrol_waypoints.append(n.position)

	# ── MAPEAMENTO DE 4 LANES TÁTICAS (BO3) ──
	# Lane 0 (Flank Left / Beco Norte): flanco periférico aberto pela cerca norte de spawn a spawn
	lane_nodes[0] = [0, 1, 4, 6, 7, 14, 18, 15, 24, 25, 34, 35, 36]
	# Lane 1 (Street Center / Rua Central & Invasão Frontal): avanço central direto em torno dos veículos até a base oposta
	lane_nodes[1] = [0, 2, 3, 17, 11, 57, 18, 19, 58, 59, 21, 26, 51, 27, 50, 29, 32, 33, 36]
	# Lane 2 (Houses / Interior das Casas & 2º Andar): salas, varandas, escadas e janelas de spawn a spawn
	lane_nodes[2] = [0, 3, 8, 9, 10, 11, 41, 42, 43, 44, 45, 19, 26, 28, 30, 31, 32, 52, 53, 54, 55, 56, 36]
	# Lane 3 (Flank Right / Beco Sul & Garagens): flanco periférico pelas garagens e pátio sul de spawn a spawn
	lane_nodes[3] = [0, 2, 12, 40, 13, 17, 21, 51, 27, 50, 29, 33, 36]

func _build_bo1_graph() -> void:
	# Y do chão no BO1 é ~ 0.05, 2º andar é ~ 3.60
	var gy = 0.05
	var raw_nodes: Array[NavNode] = [
		# --- BASE ALPHA (Norte / Casa Amarela, Z ~ -31) ---
		NavNode.new(0, Vector3(-14.0, gy, -31.0), "BO1_Alpha_Spawn", [1, 2, 3]),
		NavNode.new(1, Vector3(-17.0, gy, -25.0), "BO1_Alpha_Yard_West", [0, 2, 3]),
		NavNode.new(2, Vector3(-4.5, gy, -26.0), "BO1_Alpha_Yard_Center", [0, 1, 5]),

		# --- FLANCO OESTE / DRIVEWAY CASA AMARELA (100% Desobstruído) ---
		# x/z medidos (tools_capture/lane_audit): em (-18,-15) o nó encostava na quina da casa amarela e a
		# linha até a rua atravessava a parede; aqui tem visão livre para o quintal (1) e para a rua (6)
		NavNode.new(3, Vector3(-20.0, gy, -12.5), "BO1_Yellow_Driveway_Mid", [0, 1, 6]),
		NavNode.new(6, Vector3(-16.0, gy, -6.0), "BO1_Yellow_Driveway_Street", [3, 9, 10]),

		# --- CASA AMARELA (Térreo & 2º Andar — Portas e Corredor 100% Desobstruídos) ---
		NavNode.new(10, Vector3(-1.0, gy, -6.0), "BO1_Yellow_Front_Porch", [6, 9, 13, 14]),
		NavNode.new(13, Vector3(-1.0, gy, -9.5), "BO1_Yellow_Front_Door", [10, 12], true),
		NavNode.new(12, Vector3(-1.0, gy, -13.0), "BO1_Yellow_Living_Room", [13, 40, 41], true),
		NavNode.new(40, Vector3(-1.0, gy, -17.0), "BO1_Yellow_Corridor_Turn", [12, 5], true),
		NavNode.new(5, Vector3(-4.5, gy, -21.0), "BO1_Yellow_Back_Door", [40, 2], true),
		# 2º andar Casa Amarela (Power Position)
		NavNode.new(41, Vector3(-3.5, 3.6, -11.0), "BO1_Yellow_Upper_Floor", [12, 42], true, false, Vector3.ZERO, 1),
		NavNode.new(42, Vector3(-3.0, 3.6, -7.0), "BO1_Yellow_Upper_Window", [41], false, true, Vector3(0, 0, 1), 1),

		# --- RUA CENTRAL BO1 (Z ~ -6 a +6, ônibus, caminhão e barricada do carro) ---
		NavNode.new(9, Vector3(-10.0, gy, -5.0), "BO1_Street_NW", [6, 10, 15]),
		NavNode.new(11, Vector3(8.0, gy, -2.0), "BO1_Street_East", [14, 16, 35, 19]),
		NavNode.new(14, Vector3(0.0, gy, -5.0), "BO1_Street_North_Center", [10, 11, 17]),
		NavNode.new(15, Vector3(-8.0, gy, 0.0), "BO1_Street_West_Lane", [9, 17, 18]),
		NavNode.new(16, Vector3(5.0, gy, 0.0), "BO1_Street_East_Lane", [11, 17, 19, 35]),
		NavNode.new(17, Vector3(0.0, gy, 0.0), "BO1_Street_Cross_Mid", [14, 15, 16, 20]),
		NavNode.new(18, Vector3(-8.0, gy, 5.0), "BO1_Street_SW", [15, 20, 21]),
		NavNode.new(19, Vector3(5.0, gy, 5.0), "BO1_Street_SE", [16, 20, 23, 60, 11]),
		NavNode.new(20, Vector3(0.0, gy, 5.0), "BO1_Street_South_Center", [17, 18, 19, 23]),
		# Posição de cobertura no Carro do Cul-de-sac
		NavNode.new(35, Vector3(13.0, gy, -1.5), "BO1_Street_CulDeSac_Car", [11, 16, 23], false, true, Vector3(-1, 0, 0), 1),

		# --- CASA VERDE & INTERIOR (Térreo, Escada e 2º Andar — Acesso Frontal 100% Desobstruído) ---
		NavNode.new(23, Vector3(4.2, gy, 7.0), "BO1_Green_Front_Porch", [18, 19, 20, 21, 24, 35]),
		NavNode.new(24, Vector3(2.5, gy, 9.5), "BO1_Green_Living_Room", [23, 43], true),
		NavNode.new(43, Vector3(1.5, gy, 14.0), "BO1_Green_Stairs_Turn", [24, 51], true),
		# 2º andar Casa Verde (Power Position)
		NavNode.new(51, Vector3(2.5, 3.6, 12.0), "BO1_Green_Upper_Floor", [43, 52], true, false, Vector3.ZERO, 1),
		NavNode.new(52, Vector3(2.0, 3.6, 8.5), "BO1_Green_Upper_Window", [51], false, true, Vector3(0, 0, -1), 1),

		# --- BECO OESTE CASA VERDE (100% Desobstruído pelo jardim lateral de spawn a spawn) ---
		NavNode.new(21, Vector3(-8.5, gy, 10.0), "BO1_Green_Alley_W_North", [18, 23, 28]),
		NavNode.new(28, Vector3(-8.5, gy, 18.0), "BO1_Green_Alley_W_Mid", [21, 29]),
		NavNode.new(29, Vector3(-7.5, gy, 26.0), "BO1_Green_Alley_W_South", [28, 30, 31]),

		# --- FLANCO LESTE CASA VERDE: entrada da garagem -> faixa de grama a leste da garagem -> atrás da
		# garagem -> quintal Bravo (antes nenhuma lane passava por aqui: todos os bots iam pelo beco oeste) ---
		NavNode.new(60, Vector3(6.5, gy, 10.0), "BO1_Green_Driveway", [19, 23, 61]),
		NavNode.new(61, Vector3(11.5, gy, 16.0), "BO1_Green_East_Strip", [60, 63]),
		NavNode.new(63, Vector3(11.3, gy, 21.6), "BO1_Green_East_Corner", [61, 62]),
		NavNode.new(62, Vector3(6.0, gy, 21.6), "BO1_Green_Behind_Garage", [63, 32]),

		# --- BASE BRAVO (Sul / Quintal Casa Verde, Z ~ 30 a 34 — Rota 100% Limpa rumo ao Beco e Meio) ---
		NavNode.new(30, Vector3(-4.0, gy, 31.0), "BO1_Bravo_Yard_West", [29, 31]),
		NavNode.new(31, Vector3(0.0, gy, 33.0), "BO1_Bravo_Spawn", [29, 30, 32]),
		NavNode.new(32, Vector3(4.0, gy, 31.0), "BO1_Bravo_Yard_East", [30, 31, 62]),
	]

	for n in raw_nodes:
		nodes[n.id] = n
		if n.is_power_pos:
			power_positions.append({
				"id": n.id,
				"position": n.position,
				"look_dir": n.power_look_dir,
				"label": n.label,
				"team_bias": 0 if n.position.z < 0 else 1
			})
		if n.id in [0, 1, 2, 3, 5, 6, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 23, 24, 28, 29, 30, 31, 32, 35, 40, 41, 42, 43, 51, 52, 60, 61, 62, 63]:
			patrol_waypoints.append(n.position)

	# ── MAPEAMENTO DE 4 LANES TÁTICAS (BO1) ──
	# Lane 0 (Flank Left / Beco Oeste Driveway): flanco direto pela garagem amarela e jardim verde de spawn a spawn
	lane_nodes[0] = [0, 1, 3, 6, 9, 15, 18, 21, 28, 29, 30, 31]
	# Lane 1 (Street Center / Rua Central & Invasão Frontal): confronto direto entre ônibus, caminhão e barricada até a base oposta
	lane_nodes[1] = [0, 1, 2, 6, 10, 11, 14, 16, 17, 18, 19, 20, 23, 35, 21, 28, 29, 30, 31, 32]
	# Lane 2 (Houses / Interior das Casas & 2º Andar): salas, portas, varandas e janelas superiores de spawn a spawn
	lane_nodes[2] = [0, 2, 5, 40, 12, 13, 10, 41, 42, 17, 23, 24, 43, 51, 52, 21, 28, 29, 30, 31]
	# Lane 3 (Flanco Leste): rua leste e carro do cul-de-sac, entrada da garagem verde, faixa leste e fundo
	# da garagem até o quintal Bravo. Antes era quase a mesma rota da lane 1 e terminava no beco oeste.
	lane_nodes[3] = [0, 1, 3, 6, 10, 14, 11, 19, 60, 61, 63, 62, 32, 31]

func get_patrol_waypoints() -> Array[Vector3]:
	return patrol_waypoints

func get_power_positions() -> Array[Dictionary]:
	return power_positions

func is_node_portal(node_id: int) -> bool:
	if nodes.has(node_id):
		return nodes[node_id].is_portal
	return false

func is_position_near_portal(pos: Vector3, threshold: float = 2.2) -> bool:
	for id in nodes:
		if nodes[id].is_portal and pos.distance_to(nodes[id].position) <= threshold:
			return true
	return false

func is_position_in_house_or_corridor(pos: Vector3, threshold: float = 2.8) -> bool:
	if is_bo3:
		# BO3: Casa Azul (X entre 9 e 32, Z entre -8 e 6) ou Casa Laranja (X entre -32 e -9, Z entre -8 e 6)
		if (pos.x >= 9.0 and pos.x <= 32.0 and pos.z >= -8.0 and pos.z <= 6.0) or \
		   (pos.x <= -9.0 and pos.x >= -32.0 and pos.z >= -8.0 and pos.z <= 6.0):
			return true
	else:
		# BO1: Casa Amarela (Z entre -24 e -7.5, X entre -8 e 2.5) ou Casa Verde (Z entre 9.5 e 28, X entre -3 e 6.5)
		if (pos.z <= -7.5 and pos.z >= -24.0 and pos.x >= -8.0 and pos.x <= 2.5) or \
		   (pos.z >= 9.5 and pos.z <= 28.0 and pos.x >= -3.0 and pos.x <= 6.5):
			return true

	for id in nodes:
		var n: NavNode = nodes[id]
		if (n.is_portal or n.floor_level > 0 or ("corridor" in n.label.to_lower()) or ("hall" in n.label.to_lower()) or ("door" in n.label.to_lower()) or ("room" in n.label.to_lower())) and pos.distance_to(n.position) <= threshold:
			return true
	return false

func get_lane_waypoints(lane_idx: int) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if lane_nodes.has(lane_idx):
		for node_id in lane_nodes[lane_idx]:
			if nodes.has(node_id):
				result.append(nodes[node_id].position)
	return result

func get_next_lane_waypoint(current_pos: Vector3, lane_idx: int, bot_team: int, last_target: Vector3 = Vector3.ZERO, occupied_wps: Array[Vector3] = [], recent_wps: Array[Vector3] = []) -> Vector3:
	var wps = get_lane_waypoints(lane_idx)
	if wps.is_empty():
		return patrol_waypoints.pick_random() if not patrol_waypoints.is_empty() else current_pos

	# Determina vetor de avanço implacável rumo ao centro e à base inimiga:
	# BO3: Time 0 (Alpha) nasce em X=+42 e avança para -X (até invadir Base Bravo em X=-42).
	#      Time 1 (Bravo) nasce em X=-42 e avança para +X (até invadir Base Alpha em X=+42).
	# BO1: Time 0 (Alpha) nasce em Z=-31 e avança para +Z (até invadir Base Bravo em Z=+34).
	#      Time 1 (Bravo) nasce em Z=+34 e avança para -Z (até invadir Base Alpha em Z=-31).
	var forward_wps: Array[Vector3] = []
	for wp in wps:
		if current_pos.distance_to(wp) < 2.5:
			continue
		if last_target != Vector3.ZERO and wp.distance_to(last_target) < 2.0:
			continue

		# Evita waypoints visitados recentemente para evitar ping-pong
		var was_recently_visited = false
		for r_wp in recent_wps:
			if wp.distance_to(r_wp) < 2.5:
				was_recently_visited = true
				break
		if was_recently_visited:
			continue

		var is_advancing = false
		if is_bo3:
			if bot_team == 0:
				# Alpha avança persistentemente para -X rumo ao meio e à base inimiga Bravo
				is_advancing = wp.x < (current_pos.x - 0.5)
			else:
				# Bravo avança persistentemente para +X rumo ao meio e à base inimiga Alpha
				is_advancing = wp.x > (current_pos.x + 0.5)
		else:
			if bot_team == 0:
				# Alpha avança persistentemente para +Z rumo ao meio e à base inimiga Bravo
				is_advancing = wp.z > (current_pos.z + 0.5)
			else:
				# Bravo avança persistentemente para -Z rumo ao meio e à base inimiga Alpha
				is_advancing = wp.z < (current_pos.z - 0.5)

		if is_advancing:
			forward_wps.append(wp)

	# Se tivermos waypoints de avanço, pontua com Gravidade Central e Pressão de Invasão
	if not forward_wps.is_empty():
		var non_occupied: Array[Vector3] = []
		for wp in forward_wps:
			var is_occ = false
			for occ in occupied_wps:
				if wp.distance_to(occ) < 3.2:
					is_occ = true
					break
			if not is_occ:
				non_occupied.append(wp)

		var candidates = non_occupied if not non_occupied.is_empty() else forward_wps
		var best_wp = candidates[0]
		var best_score = -99999.0
		var rng_score = RandomNumberGenerator.new()

		for wp in candidates:
			var d = current_pos.distance_to(wp)
			var score = 0.0

			# 1. Pacing de progressão ideal (entre 4m e 22m adiante)
			if d >= 4.0 and d <= 22.0:
				score += 50.0
			elif d < 4.0:
				score += (d / 4.0) * 20.0
			else:
				score += maxf(0.0, 50.0 - (d - 22.0) * 2.0)

			# 2. Gravidade Tática do Miolo & Pressão de Invasão
			var mid_dist = abs(wp.x) if is_bo3 else abs(wp.z)
			var on_my_side = false
			if is_bo3:
				on_my_side = (bot_team == 0 and current_pos.x > 5.0) or (bot_team == 1 and current_pos.x < -5.0)
			else:
				on_my_side = (bot_team == 0 and current_pos.z < -5.0) or (bot_team == 1 and current_pos.z > 5.0)

			if on_my_side:
				# Força máxima para sair da base e ocupar a rua central!
				if mid_dist <= 8.0:
					score += (8.0 - mid_dist) * 10.0 # Até +80 pontos para controlar o centro!
			else:
				# Já está no centro ou invadindo: prioriza penetração profunda na base inimiga!
				var enemy_depth = 0.0
				if is_bo3:
					enemy_depth = -wp.x if bot_team == 0 else wp.x
				else:
					enemy_depth = wp.z if bot_team == 0 else -wp.z
				if enemy_depth > 0.0:
					score += enemy_depth * 2.5 # Bônus para empurrar fundo na base inimiga!

			# 3. Dispersão orgânica suave
			score += rng_score.randf_range(-3.0, 3.0)

			if score > best_score:
				best_score = score
				best_wp = wp

		return best_wp

	# Chegou ao fim da lane (invadiu a base inimiga):
	# Varre os pontos do setor inimigo e do miolo para manter pressão total!
	var enemy_sector_wps: Array[Vector3] = []
	for wp in wps:
		if current_pos.distance_to(wp) < 3.0:
			continue
		var is_enemy_sector = false
		if is_bo3:
			if bot_team == 0:
				# Alpha mantém controle do setor inimigo (X <= 4.0)
				is_enemy_sector = wp.x <= 4.0
			else:
				# Bravo mantém controle do setor inimigo (X >= -4.0)
				is_enemy_sector = wp.x >= -4.0
		else:
			if bot_team == 0:
				is_enemy_sector = wp.z >= -4.0
			else:
				is_enemy_sector = wp.z <= 4.0

		if is_enemy_sector:
			var was_recent = false
			for r_wp in recent_wps:
				if wp.distance_to(r_wp) < 3.0:
					was_recent = true
					break
			if not was_recent:
				enemy_sector_wps.append(wp)

	if not enemy_sector_wps.is_empty():
		return enemy_sector_wps[randi() % enemy_sector_wps.size()]

	return wps[randi() % wps.size()]

# Encontra o ID do nó do grafo mais próximo com visibilidade e orientação
func find_closest_visible_node(pos: Vector3, space: PhysicsDirectSpaceState3D, exclude_col: CollisionObject3D = null, preferred_dir: Vector3 = Vector3.ZERO) -> int:
	var closest_id = -1
	var min_cost = 99999.0
	var eye = pos + Vector3(0, 0.85, 0)

	# 1. Tentar nó visível diretamente (sem colisão com parede)
	if space:
		for id in nodes:
			var n_pos: Vector3 = nodes[id].position
			var n_eye = n_pos + Vector3(0, 0.85, 0)
			var dist = pos.distance_to(n_pos)
			var cost = dist
			if preferred_dir != Vector3.ZERO and dist > 0.6:
				var to_node = (n_pos - pos).normalized()
				to_node.y = 0.0
				var dot = preferred_dir.dot(to_node)
				if dot < -0.1:
					cost += 6.0 * (1.0 - dot)

			if cost < min_cost:
				var query = PhysicsRayQueryParameters3D.create(eye, n_eye, 1, [exclude_col] if exclude_col else [])
				var hit = space.intersect_ray(query)
				if hit.is_empty():
					min_cost = cost
					closest_id = id

	# 2. Se nenhum nó tiver linha de visão desobstruída (ex: canto de parede), escolher o mais próximo por distância
	if closest_id == -1:
		min_cost = 99999.0
		for id in nodes:
			var n_pos: Vector3 = nodes[id].position
			var dist = pos.distance_to(n_pos)
			var cost = dist
			if preferred_dir != Vector3.ZERO and dist > 0.6:
				var to_node = (n_pos - pos).normalized()
				to_node.y = 0.0
				var dot = preferred_dir.dot(to_node)
				if dot < -0.1:
					cost += 6.0 * (1.0 - dot)
			if cost < min_cost:
				min_cost = cost
				closest_id = id

	return closest_id

# Checa se a passagem entre dois pontos está desobstruída por paredes,
# considerando a largura física da cápsula do soldado (0.38m de raio lateral)
func _is_passage_clear(p1: Vector3, p2: Vector3, space: PhysicsDirectSpaceState3D, exclude_col: CollisionObject3D = null, capsule_radius: float = 0.38) -> bool:
	if not space:
		return false
	var eye_y = Vector3(0, 0.85, 0)
	var low_y = Vector3(0, 0.40, 0)
	var exc = [exclude_col] if exclude_col else []

	# 1. Trajeto central (peito e canela)
	var q1 = PhysicsRayQueryParameters3D.create(p1 + eye_y, p2 + eye_y, 1, exc)
	if not space.intersect_ray(q1).is_empty():
		return false

	var q2 = PhysicsRayQueryParameters3D.create(p1 + low_y, p2 + low_y, 1, exc)
	if not space.intersect_ray(q2).is_empty():
		return false

	# 2. Trajetos laterais (ombro direito e esquerdo da cápsula do soldado)
	# Impede rigorosamente que o bot atalhe raspando o ombro no batente de portas e quinas
	var dir = (p2 - p1)
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		var norm_dir = dir.normalized()
		var perp = Vector3(-norm_dir.z, 0.0, norm_dir.x) * capsule_radius

		var qr1 = PhysicsRayQueryParameters3D.create(p1 + eye_y + perp, p2 + eye_y + perp, 1, exc)
		if not space.intersect_ray(qr1).is_empty():
			return false

		var ql1 = PhysicsRayQueryParameters3D.create(p1 + eye_y - perp, p2 + eye_y - perp, 1, exc)
		if not space.intersect_ray(ql1).is_empty():
			return false

		var qr2 = PhysicsRayQueryParameters3D.create(p1 + low_y + perp, p2 + low_y + perp, 1, exc)
		if not space.intersect_ray(qr2).is_empty():
			return false

		var ql2 = PhysicsRayQueryParameters3D.create(p1 + low_y - perp, p2 + low_y - perp, 1, exc)
		if not space.intersect_ray(ql2).is_empty():
			return false

	return true

# Retorna uma lista otimizada de waypoints para o bot seguir até o destino,
# preservando rigorosamente os nós portais (portas e passagens estreitas)
func get_path_to_target(from_pos: Vector3, to_pos: Vector3, space: PhysicsDirectSpaceState3D, exclude_col: CollisionObject3D = null) -> PackedVector3Array:
	var path = PackedVector3Array()
	if not space:
		path.append(to_pos)
		return path

	# 1. Se estiver a curta distância (< 5m) e NÃO estiver em corredor/portal, e houver linha reta limpa, ir direto
	var direct_dist = from_pos.distance_to(to_pos)
	if direct_dist < 5.0 and not is_position_near_portal(from_pos, 2.2) and not is_position_near_portal(to_pos, 2.2) and not is_position_in_house_or_corridor(from_pos, 2.5) and not is_position_in_house_or_corridor(to_pos, 2.5) and _is_passage_clear(from_pos, to_pos, space, exclude_col):
		path.append(to_pos)
		return path

	# 2. Localizar nós do grafo AStar3D
	var heading_dir = (to_pos - from_pos).normalized()
	heading_dir.y = 0.0
	var start_id = find_closest_visible_node(from_pos, space, exclude_col, heading_dir)
	var end_id = find_closest_visible_node(to_pos, space, exclude_col, -heading_dir)

	if start_id == -1 or end_id == -1:
		path.append(to_pos)
		return path

	var astar_pts = astar.get_point_path(start_id, end_id)

	# Se AStar encontrou o caminho, montamos a sequência
	if astar_pts.is_empty():
		# Fallback de segurança se o início coincidir com o fim
		if start_id == end_id and nodes.has(start_id):
			path.append(nodes[start_id].position)
			path.append(to_pos)
			return path
		path.append(to_pos)
		return path

	# 3. Montar sequência bruta de pontos
	var raw_points: Array[Vector3] = []
	raw_points.append(from_pos)
	for pt in astar_pts:
		raw_points.append(pt)
	raw_points.append(to_pos)

	# 4. String Pulling Inteligente com Preservação Rigorosa de Portais e Corredores:
	# Atalha cantos abertos no pátio e na rua, MAS NUNCA atalha portas, quinas internas ou corredores
	var curr_idx = 0
	while curr_idx < raw_points.size() - 1:
		var farthest_idx = curr_idx + 1
		var max_lookahead = mini(raw_points.size() - 1, curr_idx + 2)

		for test_idx in range(max_lookahead, curr_idx, -1):
			var dist = raw_points[curr_idx].distance_to(raw_points[test_idx])
			
			# Preservação Rigorosa: se houver porta, passagem estreita ou corredor interno, NUNCA atalha!
			var contains_restricted = is_position_near_portal(raw_points[curr_idx], 2.2) or is_position_near_portal(raw_points[test_idx], 2.2) or is_position_in_house_or_corridor(raw_points[curr_idx], 2.5) or is_position_in_house_or_corridor(raw_points[test_idx], 2.5)
			if not contains_restricted:
				for mid_i in range(curr_idx + 1, test_idx + 1):
					if is_position_near_portal(raw_points[mid_i], 2.2) or is_position_in_house_or_corridor(raw_points[mid_i], 2.5):
						contains_restricted = true
						break

			if not contains_restricted and dist <= 12.0 and _is_passage_clear(raw_points[curr_idx], raw_points[test_idx], space, exclude_col):
				farthest_idx = test_idx
				break

		var pt_candidate = raw_points[farthest_idx]
		if pt_candidate.distance_to(from_pos) > 0.6:
			path.append(pt_candidate)
		curr_idx = farthest_idx

	if path.is_empty():
		path.append(to_pos)

	return path
