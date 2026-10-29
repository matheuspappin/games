# =============================================================================
# minimap_hud.gd
# HUD de Mini-Mapa Tático no Canto Superior Esquerdo (Estilo Call of Duty: Black Ops / MW)
# Suporta:
# - Bússola deslizante horizontal (Compass Tape) com pontos cardeais (N, NE, E, SE, S, SW, W, NW)
# - Visão top-down com rotação dinâmica em torno do jogador (mapa gira com o ângulo de visão)
# - Plantas esquemáticas vetoriais precisas de Nuketown BO1 e Nuketown 2065 (BO3)
# - Marcadores com contorno ciano (#38bdf8), preenchimento ardósia e scanlines CRT
# - Seta amarela central do jogador local (pointing straight UP)
# - Aliados verdes com fixação/edge-clamping nas bordas quando fora do raio
# - Inimigos com ping vermelho pulsante ao disparar arma (Gunshot Red Dot Ping de 3s)
# - Marcador tático de Objetivo "B" (Domination Flag B) fixado na borda com seta direcional
# - Varredura de radar UAV contínua (Radar Sweep) com facho giratório
# =============================================================================
class_name MinimapHUD
extends Control

enum MapType { NUKETOWN_BO1, NUKETOWN_BO3 }

# ── CONFIGURAÇÕES VISUAIS & ESCALA ───────────────────────────────────────────
@export var current_map_type     : MapType = MapType.NUKETOWN_BO1
@export var minimap_size         : Vector2 = Vector2(216.0, 216.0)
@export var compass_height       : float   = 24.0
@export var zoom_pixels_per_meter: float   = 3.8
@export var edge_padding         : float   = 10.0
@export var radar_sweep_enabled  : bool    = true
@export var scanlines_enabled    : bool    = true

# ── CORES TÁTICAS (CALL OF DUTY AAA PALETTE) ─────────────────────────────────
const COLOR_BG_FRAME       = Color(0.06, 0.08, 0.11, 0.94)
const COLOR_FRAME_BORDER   = Color(0.22, 0.28, 0.36, 0.95)
const COLOR_FRAME_INNER    = Color(0.12, 0.16, 0.22, 0.9)
const COLOR_CORNER_ACCENT  = Color(0.22, 0.85, 1.0, 0.9)

const COLOR_MAP_BG         = Color(0.08, 0.11, 0.15, 0.95)
const COLOR_SCANLINE       = Color(0.0, 0.0, 0.0, 0.20)
const COLOR_SWEEP_LINE     = Color(0.25, 0.92, 1.0, 0.35)
const COLOR_SWEEP_CONE     = Color(0.15, 0.80, 1.0, 0.08)

const COLOR_BUILDING_FILL  = Color(0.14, 0.18, 0.24, 0.92)
const COLOR_BUILDING_EDGE  = Color(0.28, 0.85, 0.98, 0.95)
const COLOR_BUILDING_DIV   = Color(0.22, 0.55, 0.65, 0.55)
const COLOR_STREET_FILL    = Color(0.10, 0.13, 0.17, 0.85)
const COLOR_FENCE_LINE     = Color(0.45, 0.58, 0.68, 0.75)
const COLOR_VEHICLE_FILL   = Color(0.18, 0.25, 0.32, 0.95)
const COLOR_VEHICLE_EDGE   = Color(0.0, 0.92, 1.0, 1.0)

const COLOR_PLAYER_ARROW   = Color(0.96, 0.88, 0.18, 1.0) # Amarelo clássico CoD
const COLOR_PLAYER_OUTLINE = Color(0.12, 0.16, 0.04, 1.0)

const COLOR_ALLY_CHEVRON   = Color(0.18, 0.88, 0.28, 1.0) # Verde tático aliado CoD
const COLOR_ALLY_OUTLINE   = Color(0.04, 0.22, 0.06, 1.0)

const COLOR_ENEMY_PING     = Color(0.95, 0.15, 0.15, 1.0) # Ponto vermelho hostil
const COLOR_ENEMY_RING     = Color(1.0, 0.45, 0.12, 0.85)

const COLOR_OBJ_B_FILL     = Color(0.16, 0.82, 0.24, 1.0) # Verde objetivo B
const COLOR_OBJ_B_BORDER   = Color(0.02, 0.12, 0.04, 1.0)

# ── CONTROLES INTERNOS ───────────────────────────────────────────────────────
var compass_control : Control = null
var map_viewport    : Control = null

# ── ESTADO DINÂMICO ──────────────────────────────────────────────────────────
var local_player      : CharacterBody3D = null
var current_heading   : float = 0.0 # Em graus (0 = Norte)
var sweep_angle       : float = 0.0 # Varredura radar contínua (radianos)
var enemy_pings       : Array[Dictionary] = [] # { "pos": Vector3, "time": float, "duration": float }

# ── OBJETIVO CENTRAL (BANDEIRA B) ────────────────────────────────────────────
var objective_b_world_pos : Vector3 = Vector3.ZERO
var uav_drone_angle       : float   = 0.0

# ── DADOS ESQUEMÁTICOS DE NUKETOWN BO1 ───────────────────────────────────────
var bo1_buildings : Array[Dictionary] = []
var bo1_vehicles  : Array[Dictionary] = []
var bo1_fences    : Array[PackedVector2Array] = []
var bo1_roads     : Array[PackedVector2Array] = []

# ── DADOS ESQUEMÁTICOS DE NUKETOWN 2065 (BO3) ────────────────────────────────
var bo3_buildings : Array[Dictionary] = []
var bo3_vehicles  : Array[Dictionary] = []
var bo3_fences    : Array[PackedVector2Array] = []
var bo3_roads     : Array[PackedVector2Array] = []

func _init() -> void:
	name = "MinimapHUD"

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(minimap_size.x, minimap_size.y + compass_height + 4.0)
	size = custom_minimum_size

	add_to_group("minimap")
	add_to_group("radar_listeners")

	_build_schematics_data()
	_create_sub_controls()
	_detect_current_map()

func _create_sub_controls() -> void:
	# 1. Bússola Superior (Horizontal Compass Tape)
	compass_control = Control.new()
	compass_control.name = "CompassTape"
	compass_control.custom_minimum_size = Vector2(minimap_size.x, compass_height)
	compass_control.size = Vector2(minimap_size.x, compass_height)
	compass_control.position = Vector2(0, 0)
	compass_control.mouse_filter = MOUSE_FILTER_IGNORE
	compass_control.clip_contents = true
	compass_control.draw.connect(_on_compass_draw)
	add_child(compass_control)

	# 2. Tela de Mini-Mapa Quadrada (Map Viewport)
	map_viewport = Control.new()
	map_viewport.name = "MapView"
	map_viewport.custom_minimum_size = minimap_size
	map_viewport.size = minimap_size
	map_viewport.position = Vector2(0, compass_height + 3.0)
	map_viewport.mouse_filter = MOUSE_FILTER_IGNORE
	map_viewport.clip_contents = true
	map_viewport.draw.connect(_on_map_draw)
	add_child(map_viewport)

func _process(delta: float) -> void:
	if not is_instance_valid(local_player):
		_find_local_player()

	# Atualizar varredura do radar UAV
	sweep_angle = fmod(sweep_angle + delta * 1.85, TAU)
	uav_drone_angle = fmod(uav_drone_angle + delta * 0.45, TAU)

	# Atualizar orientação da bússola e visão do jogador
	_update_player_transform()

	# Limpar pings expirados de disparos de arma
	var now = Time.get_ticks_msec() / 1000.0
	var i = enemy_pings.size() - 1
	while i >= 0:
		if now - enemy_pings[i]["time"] > enemy_pings[i]["duration"]:
			enemy_pings.remove_at(i)
		i -= 1

	if compass_control:
		compass_control.queue_redraw()
	if map_viewport:
		map_viewport.queue_redraw()

func _find_local_player() -> void:
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return

	var my_id = multiplayer.get_unique_id() if (multiplayer and multiplayer.has_multiplayer_peer()) else 1
	var node = tree.current_scene.get_node_or_null("Player_" + str(my_id)) as CharacterBody3D
	if not node:
		node = tree.current_scene.find_child("Player*", true, false) as CharacterBody3D

	if node:
		local_player = node

func _detect_current_map() -> void:
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return

	var sname = tree.current_scene.name.to_lower()
	var spath = tree.current_scene.scene_file_path.to_lower() if ("scene_file_path" in tree.current_scene) else ""

	if "bo3" in sname or "2065" in sname or "bo3" in spath or "2065" in spath:
		current_map_type = MapType.NUKETOWN_BO3
		objective_b_world_pos = Vector3(0.0, 0.0, 0.0) # Centro exato da rua BO3
	else:
		current_map_type = MapType.NUKETOWN_BO1
		objective_b_world_pos = Vector3(0.0, 0.0, 0.0) # Centro da rua entre ônibus BO1

func _update_player_transform() -> void:
	if not is_instance_valid(local_player):
		return

	var fwd = -local_player.global_transform.basis.z
	var cam = local_player.get_node_or_null("Head/Camera") as Camera3D
	if not cam:
		cam = local_player.find_child("Camera*", true, false) as Camera3D
	if cam:
		fwd = -cam.global_transform.basis.z

	var fwd_2d = Vector2(fwd.x, fwd.z).normalized()
	if fwd_2d.length_squared() > 0.001:
		# Heading em graus (0° = Norte, 90° = Leste, 180° = Sul, 270° = Oeste)
		var h_rad = atan2(fwd_2d.x, -fwd_2d.y)
		current_heading = fmod(rad_to_deg(h_rad) + 360.0, 360.0)

# ── NOTIFICAÇÃO DE DISPARO DE ARMAS (GUNSHOT RADAR PING) ─────────────────────
func notify_gunshot(pos: Vector3, shooter_team: int, is_silenced: bool = false) -> void:
	if is_silenced:
		return
	var my_team = _get_local_player_team()
	# Se quem atirou foi um inimigo (equipe diferente), registrar ping vermelho
	if shooter_team != my_team:
		enemy_pings.append({
			"pos": pos,
			"time": Time.get_ticks_msec() / 1000.0,
			"duration": 3.0 # Visível por 3 segundos
		})

func notify_gunshot_heard(pos: Vector3, shooter_team: int, is_silenced: bool = false) -> void:
	notify_gunshot(pos, shooter_team, is_silenced)

func _get_local_player_team() -> int:
	if is_instance_valid(local_player) and local_player.has_method("get_team"):
		return local_player.get_team()
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		return 0 if gm.local_player_team == 1 else 1
	return 0

# =============================================================================
# 1. RENDERIZAÇÃO DA BÚSSOLA HORIZONTAL (COMPASS TAPE)
# =============================================================================
func _on_compass_draw() -> void:
	var w = compass_control.size.x
	var h = compass_control.size.y
	var center_x = w * 0.5
	var font = get_theme_default_font()

	# Fundo da Bússola com gradiente metálico escuro
	compass_control.draw_rect(Rect2(0, 0, w, h), COLOR_BG_FRAME, true)
	compass_control.draw_line(Vector2(0, h - 1), Vector2(w, h - 1), COLOR_FRAME_BORDER, 1.5)
	compass_control.draw_line(Vector2(0, 0), Vector2(w, 0), COLOR_FRAME_BORDER, 1.0)

	# Ângulo visível: 180° no total (±90° do centro)
	var px_per_deg = w / 180.0

	var start_deg = floorf((current_heading - 90.0) / 15.0) * 15.0
	var end_deg   = ceilf((current_heading + 90.0) / 15.0) * 15.0

	var d = start_deg
	while d <= end_deg:
		var norm_d = int(round(fmod(fmod(d, 360.0) + 360.0, 360.0)))
		var x_pos = center_x + (d - current_heading) * px_per_deg

		if x_pos >= -10.0 and x_pos <= w + 10.0:
			var is_major = (norm_d % 45 == 0)

			if is_major:
				# Traço maior e letra cardinal
				compass_control.draw_line(Vector2(x_pos, h - 1), Vector2(x_pos, h - 8), Color(0.85, 0.92, 1.0, 0.9), 1.5)
				var label = _get_cardinal_label(norm_d)
				if label != "":
					var str_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
					compass_control.draw_string_outline(
						font, Vector2(x_pos - str_size.x * 0.5, 11),
						label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, 2, Color.BLACK
					)
					compass_control.draw_string(
						font, Vector2(x_pos - str_size.x * 0.5, 11),
						label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10,
						Color(1.0, 0.95, 0.85, 1.0) if (label in ["N", "S", "E", "W"]) else Color(0.75, 0.82, 0.9, 0.9)
					)
			else:
				# Traço menor intermediário a cada 15°
				compass_control.draw_line(Vector2(x_pos, h - 1), Vector2(x_pos, h - 4), Color(0.55, 0.65, 0.75, 0.5), 1.0)

		d += 15.0

	# Marcador central de orientação (Yellow/Cyan Notch)
	compass_control.draw_line(Vector2(center_x, 0), Vector2(center_x, 6), Color(0.96, 0.88, 0.22, 1.0), 2.0)
	var arrow_tri = PackedVector2Array([
		Vector2(center_x - 3.5, 0),
		Vector2(center_x + 3.5, 0),
		Vector2(center_x, 4.5)
	])
	compass_control.draw_colored_polygon(arrow_tri, Color(0.96, 0.88, 0.22, 1.0))

func _get_cardinal_label(deg: int) -> String:
	match deg:
		0, 360: return "N"
		45:     return "NE"
		90:     return "E"
		135:    return "SE"
		180:    return "S"
		225:    return "SW"
		270:    return "W"
		315:    return "NW"
	return ""

# =============================================================================
# 2. RENDERIZAÇÃO DO MINI-MAPA TOP-DOWN ROTACIONADO
# =============================================================================
func _on_map_draw() -> void:
	var w = map_viewport.size.x
	var h = map_viewport.size.y
	var center = Vector2(w * 0.5, h * 0.5)

	# 1. Fundo Tático do Mini-Mapa
	map_viewport.draw_rect(Rect2(0, 0, w, h), COLOR_MAP_BG, true)

	# Determinar posição e vetor forward do jogador local
	var player_pos = local_player.global_position if is_instance_valid(local_player) else Vector3.ZERO
	var fwd_2d = Vector2(0, -1)
	if is_instance_valid(local_player):
		var fwd = -local_player.global_transform.basis.z
		var cam = local_player.get_node_or_null("Head/Camera") as Camera3D
		if not cam:
			cam = local_player.find_child("Camera*", true, false) as Camera3D
		if cam:
			fwd = -cam.global_transform.basis.z
		var norm = Vector2(fwd.x, fwd.z).normalized()
		if norm.length_squared() > 0.001:
			fwd_2d = norm

	# Vetor lateral (Right) perpendicular
	var right_2d = Vector2(-fwd_2d.y, fwd_2d.x)

	# 2. Círculos Táticos de Distância / Grid de Radar
	var r1 = 15.0 * zoom_pixels_per_meter
	var r2 = 30.0 * zoom_pixels_per_meter
	map_viewport.draw_arc(center, r1, 0, TAU, 32, Color(0.2, 0.4, 0.5, 0.12), 1.0)
	map_viewport.draw_arc(center, r2, 0, TAU, 48, Color(0.2, 0.4, 0.5, 0.10), 1.0)

	# 3. Desenhar Planta Baixa Arquitetônica (BO1 ou BO3)
	if current_map_type == MapType.NUKETOWN_BO3:
		_draw_bo3_schematics(center, player_pos, fwd_2d, right_2d)
	else:
		_draw_bo1_schematics(center, player_pos, fwd_2d, right_2d)

	# 4. Varredura do Radar UAV (Sweep Beam & Cone)
	if radar_sweep_enabled:
		_draw_radar_sweep(center, w * 0.72)

	# 5. Scanlines CRT Horizontais (Efeito de tela militar idêntico ao modelo)
	if scanlines_enabled:
		var sy = 0.0
		while sy < h:
			map_viewport.draw_line(Vector2(0, sy), Vector2(w, sy), COLOR_SCANLINE, 1.0)
			sy += 3.0

	# 6. Marcador de Objetivo "B" (Domination Flag B - Centro de Nuketown)
	_draw_objective_marker(center, objective_b_world_pos, "B", player_pos, fwd_2d, right_2d)

	# 7. Marcador Aéreo de Killstreak / Drone UAV (no topo à direita)
	_draw_aerial_killstreak(center, w * 0.48)

	# 8. Pings Vermelhos de Disparo de Inimigos (Gunshot Pings)
	_draw_enemy_pings(center, player_pos, fwd_2d, right_2d)

	# 9. Jogadores e Bots Aliados (Green Chevrons com Edge Clamping)
	_draw_friendly_entities(center, player_pos, fwd_2d, right_2d)

	# 10. Seta Amarela Central do Jogador Local
	_draw_local_player_arrow(center)

	# 11. Moldura Tática Externa (Double Border & Corner Brackets)
	_draw_tactical_bezel(w, h)

# =============================================================================
# 3. PROJEÇÃO DO MUNDO 3D PARA COORDENADAS 2D DO MINI-MAPA
# =============================================================================
func _world_to_map_point(world_pos: Vector3, player_pos: Vector3, fwd_2d: Vector2, right_2d: Vector2, center: Vector2) -> Vector2:
	var dx = world_pos.x - player_pos.x
	var dz = world_pos.z - player_pos.z

	# Projeção escalar:
	# d_fwd  = distância à frente do jogador (eixo Y da tela invertido: frente = para cima)
	# d_right = distância à direita do jogador (eixo X da tela: direita = +X)
	var d_fwd   = dx * fwd_2d.x + dz * fwd_2d.y
	var d_right = dx * right_2d.x + dz * right_2d.y

	return Vector2(
		center.x + d_right * zoom_pixels_per_meter,
		center.y - d_fwd * zoom_pixels_per_meter
	)

func _clamp_to_bounds(point: Vector2, center: Vector2, half_w: float, half_h: float) -> Dictionary:
	var offset = point - center
	var is_clamped = false

	if absf(offset.x) > half_w or absf(offset.y) > half_h:
		is_clamped = true
		var scale_x = half_w / absf(offset.x) if absf(offset.x) > 0.001 else 999999.0
		var scale_y = half_h / absf(offset.y) if absf(offset.y) > 0.001 else 999999.0
		var factor = minf(scale_x, scale_y)
		offset = offset * factor

	return {
		"pos": center + offset,
		"clamped": is_clamped,
		"dir_angle": offset.angle()
	}

# =============================================================================
# 4. DESENHO ESQUEMÁTICO DE NUKETOWN BO1 E NUKETOWN 2065
# =============================================================================
func _draw_bo1_schematics(center: Vector2, p_pos: Vector3, fwd: Vector2, right: Vector2) -> void:
	# 1. Estradas e calçadas
	for road in bo1_roads:
		var pts = PackedVector2Array()
		for pt3 in road:
			pts.append(_world_to_map_point(Vector3(pt3.x, 0, pt3.y), p_pos, fwd, right, center))
		if pts.size() >= 3:
			map_viewport.draw_colored_polygon(pts, COLOR_STREET_FILL)
			map_viewport.draw_polyline(pts, Color(0.2, 0.28, 0.35, 0.5), 1.0)

	# 2. Cercas e limites
	for fence in bo1_fences:
		var pts = PackedVector2Array()
		for pt3 in fence:
			pts.append(_world_to_map_point(Vector3(pt3.x, 0, pt3.y), p_pos, fwd, right, center))
		if pts.size() >= 2:
			map_viewport.draw_polyline(pts, COLOR_FENCE_LINE, 1.2)

	# 3. Edifícios (Casa Amarela e Casa Verde)
	for b in bo1_buildings:
		var pts = PackedVector2Array()
		for pt3 in b["poly"]:
			pts.append(_world_to_map_point(Vector3(pt3.x, 0, pt3.y), p_pos, fwd, right, center))
		if pts.size() >= 3:
			map_viewport.draw_colored_polygon(pts, COLOR_BUILDING_FILL)
			# Contorno ciano vibrante característico da imagem
			pts.append(pts[0])
			map_viewport.draw_polyline(pts, COLOR_BUILDING_EDGE, 2.0)

		# Linhas divisórias internas de salas
		if b.has("divs"):
			for div in b["divs"]:
				var p1 = _world_to_map_point(Vector3(div[0].x, 0, div[0].y), p_pos, fwd, right, center)
				var p2 = _world_to_map_point(Vector3(div[1].x, 0, div[1].y), p_pos, fwd, right, center)
				map_viewport.draw_line(p1, p2, COLOR_BUILDING_DIV, 1.0)

	# 4. Veículos (Ônibus Amarelo Central, Caminhão de Mudança e Carro Cul-de-sac)
	for v in bo1_vehicles:
		var pts = PackedVector2Array()
		for pt3 in v["poly"]:
			pts.append(_world_to_map_point(Vector3(pt3.x, 0, pt3.y), p_pos, fwd, right, center))
		if pts.size() >= 3:
			map_viewport.draw_colored_polygon(pts, COLOR_VEHICLE_FILL)
			pts.append(pts[0])
			map_viewport.draw_polyline(pts, COLOR_VEHICLE_EDGE, 1.8)

func _draw_bo3_schematics(center: Vector2, p_pos: Vector3, fwd: Vector2, right: Vector2) -> void:
	# 1. Estradas e corredores de flanqueamento BO3
	for road in bo3_roads:
		var pts = PackedVector2Array()
		for pt3 in road:
			pts.append(_world_to_map_point(Vector3(pt3.x, 0, pt3.y), p_pos, fwd, right, center))
		if pts.size() >= 3:
			map_viewport.draw_colored_polygon(pts, COLOR_STREET_FILL)
			map_viewport.draw_polyline(pts, Color(0.2, 0.28, 0.35, 0.5), 1.0)

	# 2. Cercas e limites
	for fence in bo3_fences:
		var pts = PackedVector2Array()
		for pt3 in fence:
			pts.append(_world_to_map_point(Vector3(pt3.x, 0, pt3.y), p_pos, fwd, right, center))
		if pts.size() >= 2:
			map_viewport.draw_polyline(pts, COLOR_FENCE_LINE, 1.2)

	# 3. Edifícios (Casa Azul e Casa Laranja de 2065)
	for b in bo3_buildings:
		var pts = PackedVector2Array()
		for pt3 in b["poly"]:
			pts.append(_world_to_map_point(Vector3(pt3.x, 0, pt3.y), p_pos, fwd, right, center))
		if pts.size() >= 3:
			map_viewport.draw_colored_polygon(pts, COLOR_BUILDING_FILL)
			pts.append(pts[0])
			map_viewport.draw_polyline(pts, COLOR_BUILDING_EDGE, 2.0)

		if b.has("divs"):
			for div in b["divs"]:
				var p1 = _world_to_map_point(Vector3(div[0].x, 0, div[0].y), p_pos, fwd, right, center)
				var p2 = _world_to_map_point(Vector3(div[1].x, 0, div[1].y), p_pos, fwd, right, center)
				map_viewport.draw_line(p1, p2, COLOR_BUILDING_DIV, 1.0)

	# 4. Veículos Futuristas (Ônibus de Levitação Magnética e Caminhão)
	for v in bo3_vehicles:
		var pts = PackedVector2Array()
		for pt3 in v["poly"]:
			pts.append(_world_to_map_point(Vector3(pt3.x, 0, pt3.y), p_pos, fwd, right, center))
		if pts.size() >= 3:
			map_viewport.draw_colored_polygon(pts, COLOR_VEHICLE_FILL)
			pts.append(pts[0])
			map_viewport.draw_polyline(pts, COLOR_VEHICLE_EDGE, 1.8)

# =============================================================================
# 5. RENDERIZAÇÃO DE ENTIDADES, PINGS E OBJETIVOS
# =============================================================================
func _draw_local_player_arrow(center: Vector2) -> void:
	# Seta Amarela Central do Jogador (Chevron afiado apontando para cima estilo CoD)
	# Pontos relativos ao centro:
	var tip = center + Vector2(0, -9.0)
	var left = center + Vector2(-7.5, 8.5)
	var notch = center + Vector2(0, 4.0)
	var right = center + Vector2(7.5, 8.5)

	var chevron = PackedVector2Array([tip, right, notch, left])

	# Sombra suave sob a seta
	var shadow_poly = PackedVector2Array([
		tip + Vector2(1, 1.5),
		right + Vector2(1, 1.5),
		notch + Vector2(1, 1.5),
		left + Vector2(1, 1.5)
	])
	map_viewport.draw_colored_polygon(shadow_poly, Color(0, 0, 0, 0.55))

	# Preenchimento amarelo CoD vibrante
	map_viewport.draw_colored_polygon(chevron, COLOR_PLAYER_ARROW)
	chevron.append(tip)
	map_viewport.draw_polyline(chevron, COLOR_PLAYER_OUTLINE, 1.8)

func _draw_friendly_entities(center: Vector2, p_pos: Vector3, fwd: Vector2, right: Vector2) -> void:
	var my_team = _get_local_player_team()
	var half_w = map_viewport.size.x * 0.5 - edge_padding
	var half_h = map_viewport.size.y * 0.5 - edge_padding

	# 1. Jogadores em rede
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if p == local_player or not is_instance_valid(p):
			continue
		if p.has_method("get_team") and p.get_team() == my_team:
			var is_dead = p.get("is_dead") if ("is_dead" in p) else false
			if not is_dead:
				_draw_single_ally_chevron(p.global_position, p.global_transform.basis.z, center, p_pos, fwd, right, half_w, half_h)

	# 2. Bots aliados
	var bm = get_node_or_null("/root/BotManager")
	if not bm and get_tree() and get_tree().current_scene:
		bm = get_tree().current_scene.find_child("BotManager", true, false)
	if bm and "active_bots" in bm:
		for bot in bm.active_bots:
			if is_instance_valid(bot) and bot != local_player:
				if "team" in bot and bot.team == my_team:
					var is_dead = bot.get("is_dead") if ("is_dead" in bot) else false
					if not is_dead:
						_draw_single_ally_chevron(bot.global_position, bot.global_transform.basis.z, center, p_pos, fwd, right, half_w, half_h)

func _draw_single_ally_chevron(world_pos: Vector3, facing_z: Vector3, center: Vector2, p_pos: Vector3, fwd: Vector2, right: Vector2, half_w: float, half_h: float) -> void:
	var raw_pt = _world_to_map_point(world_pos, p_pos, fwd, right, center)
	var clamp_data = _clamp_to_bounds(raw_pt, center, half_w, half_h)
	var draw_pos = clamp_data["pos"]
	var is_clamped = clamp_data["clamped"]

	var rot_angle = 0.0
	if is_clamped:
		# Se estiver fixado na borda (edge clamped): apontar na direção do alvo fora de tela
		rot_angle = clamp_data["dir_angle"] - PI * 0.5
	else:
		# Se estiver no interior da tela: apontar na direção em que o aliado está olhando
		var ally_fwd = -facing_z
		var ally_fwd_2d = Vector2(ally_fwd.x, ally_fwd.z).normalized()
		var d_fwd = ally_fwd_2d.x * fwd.x + ally_fwd_2d.y * fwd.y
		var d_right = ally_fwd_2d.x * right.x + ally_fwd_2d.y * right.y
		rot_angle = atan2(d_right, -d_fwd)

	# Desenhar chevron verde aliado
	var tip = draw_pos + Vector2(0, -6.0).rotated(rot_angle)
	var left = draw_pos + Vector2(-5.0, 5.0).rotated(rot_angle)
	var notch = draw_pos + Vector2(0, 2.0).rotated(rot_angle)
	var r_pt = draw_pos + Vector2(5.0, 5.0).rotated(rot_angle)

	var chevron = PackedVector2Array([tip, r_pt, notch, left])
	map_viewport.draw_colored_polygon(chevron, COLOR_ALLY_CHEVRON)
	chevron.append(tip)
	map_viewport.draw_polyline(chevron, COLOR_ALLY_OUTLINE, 1.4)

func _draw_enemy_pings(center: Vector2, p_pos: Vector3, fwd: Vector2, right: Vector2) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	var half_w = map_viewport.size.x * 0.5 - edge_padding
	var half_h = map_viewport.size.y * 0.5 - edge_padding

	for ping in enemy_pings:
		var age = now - ping["time"]
		var life_ratio = 1.0 - clampf(age / ping["duration"], 0.0, 1.0)
		if life_ratio <= 0.0:
			continue

		var raw_pt = _world_to_map_point(ping["pos"], p_pos, fwd, right, center)
		var clamp_data = _clamp_to_bounds(raw_pt, center, half_w, half_h)
		var draw_pos = clamp_data["pos"]
		var is_clamped = clamp_data["clamped"]

		if is_clamped:
			# Triângulo indicador vermelho na borda
			var angle = clamp_data["dir_angle"] - PI * 0.5
			var tip = draw_pos + Vector2(0, -5.5).rotated(angle)
			var l_pt = draw_pos + Vector2(-4.5, 4.5).rotated(angle)
			var r_pt = draw_pos + Vector2(4.5, 4.5).rotated(angle)
			var tri = PackedVector2Array([tip, r_pt, l_pt])
			map_viewport.draw_colored_polygon(tri, Color(COLOR_ENEMY_PING.r, COLOR_ENEMY_PING.g, COLOR_ENEMY_PING.b, life_ratio))
		else:
			# Onda de choque expansiva nos primeiros 0.6s
			if age < 0.65:
				var wave_r = 4.0 + (age / 0.65) * 12.0
				var wave_a = (1.0 - (age / 0.65)) * 0.8
				map_viewport.draw_arc(draw_pos, wave_r, 0, TAU, 16, Color(COLOR_ENEMY_RING.r, COLOR_ENEMY_RING.g, COLOR_ENEMY_RING.b, wave_a), 1.5)

			# Halo de brilho laranja
			map_viewport.draw_circle(draw_pos, 6.5, Color(COLOR_ENEMY_RING.r, COLOR_ENEMY_RING.g, COLOR_ENEMY_RING.b, 0.45 * life_ratio))
			# Ponto vermelho central
			map_viewport.draw_circle(draw_pos, 4.0, Color(COLOR_ENEMY_PING.r, COLOR_ENEMY_PING.g, COLOR_ENEMY_PING.b, life_ratio))
			map_viewport.draw_arc(draw_pos, 4.0, 0, TAU, 16, Color(0, 0, 0, 0.8 * life_ratio), 1.2)

func _draw_objective_marker(center: Vector2, world_pos: Vector3, label_text: String, p_pos: Vector3, fwd: Vector2, right: Vector2) -> void:
	var raw_pt = _world_to_map_point(world_pos, p_pos, fwd, right, center)
	var half_w = map_viewport.size.x * 0.5 - (edge_padding + 6.0)
	var half_h = map_viewport.size.y * 0.5 - (edge_padding + 6.0)

	var clamp_data = _clamp_to_bounds(raw_pt, center, half_w, half_h)
	var draw_pos = clamp_data["pos"]
	var is_clamped = clamp_data["clamped"]
	var font = get_theme_default_font()

	# Se estiver fixado na borda: desenhar pequena seta apontando para a direção do objetivo
	if is_clamped:
		var dir_ang = clamp_data["dir_angle"]
		var pointer_tip = draw_pos + Vector2(cos(dir_ang), sin(dir_ang)) * 11.0
		var pointer_l   = draw_pos + Vector2(cos(dir_ang + 2.5), sin(dir_ang + 2.5)) * 6.0
		var pointer_r   = draw_pos + Vector2(cos(dir_ang - 2.5), sin(dir_ang - 2.5)) * 6.0
		var p_poly = PackedVector2Array([pointer_tip, pointer_l, pointer_r])
		map_viewport.draw_colored_polygon(p_poly, COLOR_OBJ_B_FILL)

	# Escudo pentagonal característico de objetivos Call of Duty (Domination B)
	var s = 9.0
	var shield = PackedVector2Array([
		draw_pos + Vector2(0, -s),
		draw_pos + Vector2(s, -s * 0.4),
		draw_pos + Vector2(s * 0.65, s * 0.9),
		draw_pos + Vector2(-s * 0.65, s * 0.9),
		draw_pos + Vector2(-s, -s * 0.4)
	])

	# Sombra do escudo
	var s_shadow = PackedVector2Array()
	for pt in shield:
		s_shadow.append(pt + Vector2(1, 1))
	map_viewport.draw_colored_polygon(s_shadow, Color(0, 0, 0, 0.6))

	# Preenchimento verde do distintivo
	map_viewport.draw_colored_polygon(shield, COLOR_OBJ_B_FILL)
	shield.append(shield[0])
	map_viewport.draw_polyline(shield, COLOR_OBJ_B_BORDER, 1.8)

	# Letra do objetivo "B" em preto negrito
	var str_sz = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
	map_viewport.draw_string(font, Vector2(draw_pos.x - str_sz.x * 0.5, draw_pos.y + 4.0), label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color.BLACK)

func _draw_aerial_killstreak(center: Vector2, radius: float) -> void:
	# Ícone tático verde de aeronave / UAV de reconhecimento no canto superior direito
	var angle = deg_to_rad(-40.0)
	var drone_pos = center + Vector2(cos(angle), sin(angle)) * radius

	# Silhueta de aeronave UAV CoD em vetor
	var nose = drone_pos + Vector2(-3, -3)
	var tail = drone_pos + Vector2(4, 4)
	var left_wing  = drone_pos + Vector2(-7, 3)
	var right_wing = drone_pos + Vector2(3, -7)

	var uav_lines = PackedVector2Array([nose, tail, left_wing, right_wing])
	map_viewport.draw_line(nose, tail, Color(0.2, 0.95, 0.3, 0.85), 2.0)
	map_viewport.draw_line(left_wing, right_wing, Color(0.2, 0.95, 0.3, 0.85), 2.0)

	# Mini seta indicadora
	var arr_tip = drone_pos + Vector2(5, 5)
	var arr_l = drone_pos + Vector2(2, 5)
	var arr_r = drone_pos + Vector2(5, 2)
	map_viewport.draw_line(arr_tip, arr_l, Color(0.2, 0.95, 0.3, 0.85), 1.5)
	map_viewport.draw_line(arr_tip, arr_r, Color(0.2, 0.95, 0.3, 0.85), 1.5)

func _draw_radar_sweep(center: Vector2, radius: float) -> void:
	# Facho giratório de varredura radar (UAV Sweep)
	var sweep_dir = Vector2(cos(sweep_angle), sin(sweep_angle))
	var end_pt = center + sweep_dir * radius

	# Linha frontal de varredura
	map_viewport.draw_line(center, end_pt, COLOR_SWEEP_LINE, 1.5)

	# Arco suave de rastro do radar (trailing gradient cone)
	var trail_points = PackedVector2Array([center])
	for st in range(8):
		var a = sweep_angle - float(st) * 0.08
		trail_points.append(center + Vector2(cos(a), sin(a)) * radius)
	if trail_points.size() >= 3:
		map_viewport.draw_colored_polygon(trail_points, COLOR_SWEEP_CONE)

func _draw_tactical_bezel(w: float, h: float) -> void:
	# Borda externa militar metálica (Dark Slate Bezel com cantos tecnológicos)
	var outer_rect = Rect2(0, 0, w, h)
	map_viewport.draw_rect(outer_rect, COLOR_FRAME_BORDER, false, 1.8)

	var inner_rect = Rect2(1.5, 1.5, w - 3.0, h - 3.0)
	map_viewport.draw_rect(inner_rect, COLOR_FRAME_INNER, false, 1.0)

	# 4 Cantos com cantoneiras destacadas (Corner Brackets)
	var b_len = 8.0
	# Top-Left
	map_viewport.draw_line(Vector2(0, 0), Vector2(b_len, 0), COLOR_CORNER_ACCENT, 2.0)
	map_viewport.draw_line(Vector2(0, 0), Vector2(0, b_len), COLOR_CORNER_ACCENT, 2.0)
	# Top-Right
	map_viewport.draw_line(Vector2(w, 0), Vector2(w - b_len, 0), COLOR_CORNER_ACCENT, 2.0)
	map_viewport.draw_line(Vector2(w, 0), Vector2(w, b_len), COLOR_CORNER_ACCENT, 2.0)
	# Bottom-Left
	map_viewport.draw_line(Vector2(0, h), Vector2(b_len, h), COLOR_CORNER_ACCENT, 2.0)
	map_viewport.draw_line(Vector2(0, h), Vector2(0, h - b_len), COLOR_CORNER_ACCENT, 2.0)
	# Bottom-Right
	map_viewport.draw_line(Vector2(w, h), Vector2(w - b_len, h), COLOR_CORNER_ACCENT, 2.0)
	map_viewport.draw_line(Vector2(w, h), Vector2(w, h - b_len), COLOR_CORNER_ACCENT, 2.0)

# =============================================================================
# 6. BANCO DE DADOS ESQUEMÁTICO VETORIAL (NUKETOWN BO1 & 2065)
# =============================================================================
func _build_schematics_data() -> void:
	# ─────────────────────────────────────────────────────────────────────────
	# NUKETOWN BO1 (CLÁSSICO)
	# Eixo Z: Norte = -Z (Casa Amarela), Sul = +Z (Casa Verde)
	# Eixo X: Oeste = -X (Driveway Amarela), Leste = +X (Cul-de-sac)
	# ─────────────────────────────────────────────────────────────────────────
	bo1_roads.clear()
	bo1_roads.append(PackedVector2Array([
		Vector2(-22, -6), Vector2(18, -6), Vector2(18, 6), Vector2(-22, 6)
	]))
	bo1_roads.append(PackedVector2Array([
		Vector2(-20, -25), Vector2(-14, -25), Vector2(-14, 25), Vector2(-20, 25)
	]))

	bo1_fences.clear()
	# Cerca fundo Casa Amarela
	bo1_fences.append(PackedVector2Array([
		Vector2(-22, -18), Vector2(-22, -33), Vector2(12, -33), Vector2(12, -21)
	]))
	# Cerca fundo Casa Verde
	bo1_fences.append(PackedVector2Array([
		Vector2(-12, 20), Vector2(-12, 35), Vector2(22, 35), Vector2(22, 20)
	]))

	bo1_buildings.clear()
	# Casa Amarela (Alpha / Norte)
	bo1_buildings.append({
		"poly": PackedVector2Array([
			Vector2(-10, -21), Vector2(4, -21), Vector2(4, -8), Vector2(-10, -8)
		]),
		"divs": [
			[Vector2(-5, -21), Vector2(-5, -8)],
			[Vector2(-10, -14), Vector2(4, -14)]
		]
	})
	# Garagem Casa Amarela
	bo1_buildings.append({
		"poly": PackedVector2Array([
			Vector2(-18, -20), Vector2(-10, -20), Vector2(-10, -9), Vector2(-18, -9)
		])
	})
	# Varanda Frontal Casa Amarela
	bo1_buildings.append({
		"poly": PackedVector2Array([
			Vector2(-5, -8), Vector2(2, -8), Vector2(2, -5), Vector2(-5, -5)
		])
	})

	# Casa Verde (Bravo / Sul)
	bo1_buildings.append({
		"poly": PackedVector2Array([
			Vector2(-2, 8), Vector2(12, 8), Vector2(12, 21), Vector2(-2, 21)
		]),
		"divs": [
			[Vector2(5, 8), Vector2(5, 21)],
			[Vector2(-2, 14), Vector2(12, 14)]
		]
	})
	# Garagem Casa Verde
	bo1_buildings.append({
		"poly": PackedVector2Array([
			Vector2(12, 9), Vector2(20, 9), Vector2(20, 20), Vector2(12, 20)
		])
	})
	# Varanda Frontal Casa Verde
	bo1_buildings.append({
		"poly": PackedVector2Array([
			Vector2(1, 5), Vector2(8, 5), Vector2(8, 8), Vector2(1, 8)
		])
	})

	bo1_vehicles.clear()
	# Ônibus Amarelo Central (inclinado ~25°)
	var bus_c = Vector2(-2.8, -1.5)
	var bus_w = 2.8; var bus_l = 8.8; var bus_ang = deg_to_rad(24.0)
	bo1_vehicles.append({ "poly": _make_oriented_box(bus_c, bus_w, bus_l, bus_ang) })

	# Caminhão de Mudança (inclinado ~ -20°)
	var trk_c = Vector2(3.8, 2.5)
	var trk_w = 3.0; var trk_l = 8.0; var trk_ang = deg_to_rad(-20.0)
	bo1_vehicles.append({ "poly": _make_oriented_box(trk_c, trk_w, trk_l, trk_ang) })

	# Barricada do Carro (Cul-de-sac)
	var car_c = Vector2(15.2, -1.5)
	bo1_vehicles.append({ "poly": _make_oriented_box(car_c, 2.4, 5.0, deg_to_rad(15.0)) })

	# ─────────────────────────────────────────────────────────────────────────
	# NUKETOWN 2065 (BO3 FUTURISTA)
	# Eixo X: Leste = +X (Casa Azul Alpha), Oeste = -X (Casa Laranja Bravo)
	# Eixo Z: Norte = -Z (Beco Flank Left), Sul = +Z (Beco Garagens)
	# ─────────────────────────────────────────────────────────────────────────
	bo3_roads.clear()
	bo3_roads.append(PackedVector2Array([
		Vector2(-6, -18), Vector2(6, -18), Vector2(6, 14), Vector2(-6, 14)
	]))
	bo3_roads.append(PackedVector2Array([
		Vector2(-42, -19), Vector2(42, -19), Vector2(42, -15), Vector2(-42, -15)
	]))
	bo3_roads.append(PackedVector2Array([
		Vector2(-42, 8), Vector2(42, 8), Vector2(42, 12), Vector2(-42, 12)
	]))

	bo3_fences.clear()
	# Cerca Casa Azul (Leste)
	bo3_fences.append(PackedVector2Array([
		Vector2(28, -18), Vector2(44, -18), Vector2(44, 10), Vector2(28, 10)
	]))
	# Cerca Casa Laranja (Oeste)
	bo3_fences.append(PackedVector2Array([
		Vector2(-28, -18), Vector2(-44, -18), Vector2(-44, 10), Vector2(-28, 10)
	]))

	bo3_buildings.clear()
	# Casa Azul (Alpha / Leste)
	bo3_buildings.append({
		"poly": PackedVector2Array([
			Vector2(12, -12), Vector2(28, -12), Vector2(28, 2), Vector2(12, 2)
		]),
		"divs": [
			[Vector2(20, -12), Vector2(20, 2)],
			[Vector2(12, -5), Vector2(28, -5)]
		]
	})
	# Garagem Casa Azul
	bo3_buildings.append({
		"poly": PackedVector2Array([
			Vector2(12, 2), Vector2(28, 2), Vector2(28, 10), Vector2(12, 10)
		])
	})
	# Varanda Frontal Casa Azul
	bo3_buildings.append({
		"poly": PackedVector2Array([
			Vector2(6, -6), Vector2(12, -6), Vector2(12, 4), Vector2(6, 4)
		])
	})

	# Casa Laranja (Bravo / Oeste)
	bo3_buildings.append({
		"poly": PackedVector2Array([
			Vector2(-28, -12), Vector2(-12, -12), Vector2(-12, 2), Vector2(-28, 2)
		]),
		"divs": [
			[Vector2(-20, -12), Vector2(-20, 2)],
			[Vector2(-28, -5), Vector2(-12, -5)]
		]
	})
	# Garagem Casa Laranja
	bo3_buildings.append({
		"poly": PackedVector2Array([
			Vector2(-28, 2), Vector2(-12, 2), Vector2(-12, 10), Vector2(-28, 10)
		])
	})
	# Varanda Frontal Casa Laranja
	bo3_buildings.append({
		"poly": PackedVector2Array([
			Vector2(-12, -6), Vector2(-6, -6), Vector2(-6, 4), Vector2(-12, 4)
		])
	})

	bo3_vehicles.clear()
	# Ônibus Maglev Futurista Central
	bo3_vehicles.append({
		"poly": _make_oriented_box(Vector2(0, 3.5), 3.2, 9.5, deg_to_rad(5.0))
	})
	# Caminhão de Carga Futurista Norte
	bo3_vehicles.append({
		"poly": _make_oriented_box(Vector2(0, -8.0), 3.2, 8.2, deg_to_rad(-8.0))
	})

func _make_oriented_box(center_pt: Vector2, width: float, length: float, angle: float) -> PackedVector2Array:
	var hw = width * 0.5
	var hl = length * 0.5
	var pts = PackedVector2Array([
		Vector2(-hw, -hl).rotated(angle) + center_pt,
		Vector2(hw, -hl).rotated(angle) + center_pt,
		Vector2(hw, hl).rotated(angle) + center_pt,
		Vector2(-hw, hl).rotated(angle) + center_pt
	])
	return pts
