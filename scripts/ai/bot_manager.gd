# =============================================================================
# bot_manager.gd
# Gerenciador Tático de Bots IA do NUKE — Nuketown 2065 & Nuketown BO1
# Gerencia balanceamento de equipes (CT vs T), nomes icônicos de Call of Duty,
# dificuldade, posicionamento em solo real via raycast e respawn dinâmico.
# =============================================================================
class_name BotManager
extends Node

const BOT_SCENE = preload("res://scenes/enemies/soldier_bot.tscn")

const NAMES_ALPHA: Array[String] = [
	"Ghost", "Soap", "Price", "Roach", "Gaz", "Griggs",
	"Sandman", "Frost", "Yuri", "Kamal", "Overlord", "Ozone"
]

const NAMES_BRAVO: Array[String] = [
	"Woods", "Mason", "Reznov", "Bowman", "Weaver", "Hudson",
	"Dragovich", "Kravchenko", "Steiner", "Menendez", "Salazar", "Harper"
]

var active_bots: Array[CharacterBody3D] = []
var is_active: bool = false
var spawn_alpha_node: Node3D = null
var spawn_bravo_node: Node3D = null

# ── SQUAD SHARED INTEL (RADAR COLETIVO DE ESQUADRÃO) ─────────────────────────
var team_last_contact: Dictionary = {
	0: { "pos": Vector3.ZERO, "time": 0 },
	1: { "pos": Vector3.ZERO, "time": 0 }
}

func report_enemy_contact(reporting_team: int, contact_pos: Vector3) -> void:
	if reporting_team != 0 and reporting_team != 1:
		return
	team_last_contact[reporting_team] = {
		"pos": contact_pos,
		"time": Time.get_ticks_msec()
	}

func get_team_last_contact(team_id: int) -> Dictionary:
	if not team_last_contact.has(team_id):
		return { "pos": Vector3.ZERO, "time": 0 }
	var data = team_last_contact[team_id]
	var now = Time.get_ticks_msec()
	# Contato ativo por até 12 segundos (12000 ms)
	if now - data["time"] < 12000 and data["pos"] != Vector3.ZERO:
		return data
	return { "pos": Vector3.ZERO, "time": 0 }

func _get_map_node() -> Node3D:
	if get_parent() is Node3D and get_parent() != get_tree().root:
		return get_parent() as Node3D
	if get_tree() and get_tree().current_scene is Node3D and get_tree().current_scene != get_tree().root:
		return get_tree().current_scene as Node3D
	if get_tree() and get_tree().root:
		for ch in get_tree().root.get_children():
			if ch is Node3D and ("Map" in ch.name or "nuketown" in ch.name.to_lower()):
				return ch as Node3D
	return null

func _ready() -> void:
	call_deferred("_initialize_match_bots")

func _initialize_match_bots() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var play_with_bots = true
	var bot_count = 5
	var distribution = 0  # 0 = BALANCED, 1 = ALL_ENEMIES
	var difficulty = 2    # 2 = REGULAR (0=RECRUIT, 1=NOVICE, 2=REGULAR, 3=VETERAN, 4=EXPERT)

	if gm:
		if gm.play_mode == gm.PlayMode.ONLINE_CLIENT:
			# Cliente online não spawna bots localmente (o servidor os gerencia)
			return
		elif gm.play_mode == gm.PlayMode.ONLINE_HOST:
			play_with_bots = gm.online_fill_bots
			bot_count = gm.bot_count if gm.bot_count > 0 else 5
		else:
			play_with_bots = true
			bot_count = gm.bot_count if gm.bot_count > 0 else 5

		distribution = gm.bot_distribution
		difficulty = gm.bot_difficulty

	# Suporte a argumentos CLI
	var all_args = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for arg in all_args:
		if arg.begins_with("--bots="):
			var b_str = arg.trim_prefix("--bots=")
			if b_str.is_valid_int():
				bot_count = b_str.to_int()
				play_with_bots = bot_count > 0

	if not play_with_bots or bot_count <= 0:
		print("[BotManager] Partida configurada sem bots.")
		return

	_find_spawns()
	_cleanup_target_dummies()
	spawn_all_bots(bot_count, distribution, difficulty)

func _find_spawns() -> void:
	var scene = _get_map_node()
	if not scene:
		return

	spawn_alpha_node = scene.find_child("Spawn_Alpha", true, false) as Node3D
	spawn_bravo_node = scene.find_child("Spawn_Bravo", true, false) as Node3D

func _cleanup_target_dummies() -> void:
	var scene = _get_map_node()
	if not scene:
		return

	# Ocultar ou remover bonecos de treino estáticos para liberar arena para os bots móveis
	var dummies = scene.find_children("TargetDummy*", "Node3D", true, false)
	for d in dummies:
		d.visible = false
		d.process_mode = Node.PROCESS_MODE_DISABLED

func spawn_all_bots(total_bots: int = 11, distribution_mode: int = 0, difficulty: int = 2) -> void:
	is_active = true
	_find_spawns()

	var gm = get_node_or_null("/root/GameManager")
	var net = get_node_or_null("/root/NetworkManager")
	if not net:
		var scene_map = _get_map_node()
		if scene_map:
			net = scene_map.find_child("NetworkManager", true, false)

	# 1. Pré-registrar o jogador local no NetworkManager com seu nome real
	var my_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var local_name = gm.local_player_name if (gm and not gm.local_player_name.is_empty()) else "Operador_Alpha"
	if net and net.has_method("register_player_stat"):
		net.register_player_stat(my_id, true, local_name)

	# 2. Se temos o lobby_roster definido pelo LobbyScreen, instanciamos a lista exata do lobby
	var spawned_count = 0
	if gm and not gm.lobby_roster.is_empty():
		var alpha_slot = 0
		var bravo_slot = 0
		for member in gm.lobby_roster:
			if member.get("is_local", false):
				continue
			var b_team = int(member.get("team", 1))
			var b_name = str(member.get("name", "SoldierBot"))
			var b_id = int(member.get("id", (100 + alpha_slot + 1) if b_team == 0 else (200 + bravo_slot + 1)))
			var slot = alpha_slot if b_team == 0 else bravo_slot
			if b_team == 0:
				alpha_slot += 1
			else:
				bravo_slot += 1

			# Pré-registrar bot no NetworkManager para que já apareça no Placar TAB desde o início
			if net and net.has_method("register_player_stat"):
				net.register_player_stat(b_id, b_team == 0, b_name)

			_spawn_single_bot(b_team, b_name, slot, difficulty, b_id)
			spawned_count += 1

		print("[BotManager] %d bots IA instanciados a partir do LobbyRoster oficial." % spawned_count)
		if spawned_count >= total_bots:
			return

	# 3. Fallback ou complemento de bots faltantes para atingir exatamente total_bots
	var missing = total_bots - spawned_count
	if missing > 0:
		var cur_alpha = 0
		var cur_bravo = 0
		for b in active_bots:
			if is_instance_valid(b) and b is CharacterBody3D:
				if b.get("team") == 0: cur_alpha += 1
				else: cur_bravo += 1

		print("[BotManager] Completando %d bots faltantes (Total esperado: %d | Já ativos: %d)" % [
			missing, total_bots, spawned_count
		])

		for i in range(missing):
			var is_alpha = false
			if distribution_mode == 0:
				# Equilibrar times incluindo o jogador humano local no Alpha (Alpha total = cur_alpha + 1)
				is_alpha = (cur_alpha + 1 <= cur_bravo)
			else:
				is_alpha = false

			var slot = cur_alpha if is_alpha else cur_bravo
			var b_name = NAMES_ALPHA[cur_alpha % NAMES_ALPHA.size()] if is_alpha else NAMES_BRAVO[cur_bravo % NAMES_BRAVO.size()]
			var b_id = (100 + cur_alpha + 1) if is_alpha else (200 + cur_bravo + 1)
			if is_alpha: cur_alpha += 1
			else: cur_bravo += 1

			if net and net.has_method("register_player_stat"):
				net.register_player_stat(b_id, is_alpha, b_name)

			_spawn_single_bot(0 if is_alpha else 1, b_name, slot, difficulty, b_id)
			spawned_count += 1

func _spawn_single_bot(team: int, bot_name: String, slot_idx: int, difficulty: int, bot_id: int = 0) -> CharacterBody3D:
	var scene = _get_map_node()
	if not scene or not BOT_SCENE:
		return null

	if bot_id == 0:
		bot_id = (100 + slot_idx + 1) if team == 0 else (200 + slot_idx + 1)

	var bot = BOT_SCENE.instantiate() as CharacterBody3D
	var team_str = "Alpha" if team == 0 else "Bravo"
	bot.name = "Bot_%s_%s" % [team_str, bot_name]

	# Propriedades do bot
	bot.set("team", team)
	bot.set("bot_id", bot_id)
	bot.set("bot_name", bot_name)
	bot.set("bot_display_name", bot_name)
	if bot.has_method("apply_difficulty"):
		bot.apply_difficulty(difficulty)

	# Atribuição de Arquétipo tático e Distribuição Equilibrada de Lanes (Anti-Conga & 6v6)
	var arch_to_apply = 0 # BALANCED
	var lower_name = bot_name.to_lower()
	if "ghost" in lower_name or "reznov" in lower_name or "yuri" in lower_name or "menendez" in lower_name or "frost" in lower_name:
		arch_to_apply = 2 # FLANKER
	elif "soap" in lower_name or "woods" in lower_name or "bowman" in lower_name or "griggs" in lower_name or "gaz" in lower_name or "harper" in lower_name:
		arch_to_apply = 1 # RUSHER
	elif "price" in lower_name or "mason" in lower_name or "sandman" in lower_name or "hudson" in lower_name or "weaver" in lower_name:
		arch_to_apply = 3 # ANCHOR
	else:
		match slot_idx % 3:
			0: arch_to_apply = 2 # FLANKER
			1: arch_to_apply = 1 # RUSHER
			2: arch_to_apply = 3 # ANCHOR

	# Distribuição balanceada com Gravidade Central (60% Meio / Ruas / Ônibus):
	# O miolo de Nuketown precisa ser uma zona de confronto intensa contínua.
	var lane_to_assign = 1 # STREET_CENTER por padrão
	match slot_idx % 5:
		0: lane_to_assign = 1 # Centro (Ponta de Lança frontal)
		1: lane_to_assign = 1 # Centro (Dupla de Assalto)
		2: lane_to_assign = 0 # Flanco Esquerdo (Alley / Beco Aberto 100% livre)
		3: lane_to_assign = 3 # Flanco Direito (Garagens / Pátio)
		4: lane_to_assign = 1 # Centro (Reforço do Miolo)

	# Escalonamento lateral para formação em dupla
	var lat_sign = -1.0 if (slot_idx % 2 == 0) else 1.0
	bot.set("lateral_sign", lat_sign)

	# Micro-delay de partida para formação orgânica em fila/dupla sem atrasar o confronto
	bot.set("_departure_delay", float(slot_idx % 5) * 0.05)

	if bot.has_method("apply_archetype"):
		bot.apply_archetype(arch_to_apply, lane_to_assign)
	bot.set("assigned_lane", lane_to_assign)

	# Obter Transform3D ideal via Sistema Dinâmico de Spawns com Spawn Flipping (Fase 2)
	var opt_transform = get_optimal_spawn_transform(team, slot_idx)
	bot.global_transform = opt_transform

	if bot.has_signal("enemy_died"):
		bot.enemy_died.connect(func(b): _on_bot_died(b, team, bot_name, slot_idx, difficulty, bot_id))

	active_bots.append(bot)
	scene.add_child(bot)
	return bot

# ── SISTEMA DINÂMICO DE SPAWN FLIPPING & SCORING DE SEGURANÇA (FASE 2) ────────
# ── SISTEMA DINÂMICO DE SPAWN FLIPPING & SCORING DE SEGURANÇA (ESTILO CALL OF DUTY) ──
var is_spawns_flipped: bool = false
signal spawn_flipped(is_flipped: bool)

func evaluate_spawn_flip() -> bool:
	var scene = _get_map_node()
	if not scene:
		return is_spawns_flipped

	var is_bo3 = _is_map_bo3(scene)

	# Coletar combatentes vivos de cada equipe (jogadores e bots)
	var alpha_positions: Array[Vector3] = []
	var bravo_positions: Array[Vector3] = []

	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p is CharacterBody3D:
			var p_team = p.get_team() if p.has_method("get_team") else (0 if p.get("team") == 0 else 1)
			var is_alive = true
			if p.has_node("HealthComponent"):
				var hp = p.get_node("HealthComponent")
				is_alive = hp and hp.current_health > 0
			if is_alive:
				if p_team == 0:
					alpha_positions.append(p.global_position)
				else:
					bravo_positions.append(p.global_position)

	for b in active_bots:
		if is_instance_valid(b) and b is CharacterBody3D and b.get("ai_state") != 6: # not DEAD
			var b_team = b.get("team")
			if b_team == 0:
				alpha_positions.append(b.global_position)
			elif b_team == 1:
				bravo_positions.append(b.global_position)

	var prev_state = is_spawns_flipped

	# ── CÁLCULO DE AMEAÇA E PRESSÃO TERRITORIAL POR BASE (CoD Threat Model) ──
	var alpha_threat: float = 0.0
	var bravo_threat: float = 0.0

	if is_bo3:
		# BO3: Alpha = +X (Base em X=+42, Portão em X=34, Casa em X=26), Bravo = -X (Base em X=-42, Pátio em X=-34, Casa em X=-26).
		# Midline da rua central é X=0.0 (|X| <= 10.0 é zona neutra de combate livre, NUNCA ativa spawn flip).
		var base_alpha_pos = Vector3(40.0, -1.45, -8.0)
		var base_bravo_pos = Vector3(-40.0, -1.45, -10.0)

		# Ameaça contra Alpha: invasores Bravo que penetrarem fundo no quintal Alpha (X > 26.0)
		for p in bravo_positions:
			var d = p.distance_to(base_alpha_pos)
			if d < 14.0 or p.x > 32.0:
				alpha_threat += 100.0 + (14.0 - minf(d, 14.0)) * 15.0
			elif p.x > 26.0:
				alpha_threat += (p.x - 26.0) * 8.0

		# Ameaça contra Bravo: invasores Alpha que penetrarem fundo no quintal Bravo (X < -26.0)
		for p in alpha_positions:
			var d = p.distance_to(base_bravo_pos)
			if d < 14.0 or p.x < -32.0:
				bravo_threat += 100.0 + (14.0 - minf(d, 14.0)) * 15.0
			elif p.x < -26.0:
				bravo_threat += (-26.0 - p.x) * 8.0
	else:
		# BO1: Alpha = -Z (Base em Z=-30, Pátio em Z=-25), Bravo = +Z (Base em Z=+32, Pátio em Z=+26).
		# Midline da rua central é Z=0.0 (|Z| <= 8.0 é zona neutra, NUNCA ativa spawn flip).
		var base_alpha_pos = Vector3(-14.0, 0.2, -30.0)
		var base_bravo_pos = Vector3(0.0, 0.2, 32.0)

		# Ameaça contra Alpha: invasores Bravo no quintal norte da Casa Amarela (Z < -18.0)
		for p in bravo_positions:
			var d = p.distance_to(base_alpha_pos)
			if d < 14.0 or p.z < -25.0:
				alpha_threat += 100.0 + (14.0 - minf(d, 14.0)) * 15.0
			elif p.z < -18.0:
				alpha_threat += (-18.0 - p.z) * 8.0

		# Ameaça contra Bravo: invasores Alpha no quintal sul da Casa Verde (Z > 18.0)
		for p in alpha_positions:
			var d = p.distance_to(base_bravo_pos)
			if d < 14.0 or p.z > 25.0:
				bravo_threat += 100.0 + (14.0 - minf(d, 14.0)) * 15.0
			elif p.z > 18.0:
				bravo_threat += (p.z - 18.0) * 8.0

	# Decisão de Spawn Flip baseada em pressão profunda com histerese forte estilo Call of Duty:
	# Só inverte se houver invasão consolidada (>= 100 pontos) com folga sobre a base oposta
	if alpha_threat >= 100.0 and alpha_threat > bravo_threat + 35.0:
		is_spawns_flipped = true # Base Alpha invadida -> time Alpha spawna em Bravo
	elif bravo_threat >= 100.0 and bravo_threat > alpha_threat + 35.0:
		is_spawns_flipped = false # Base Bravo invadida -> time Bravo spawna em Alpha

	if is_spawns_flipped != prev_state:
		print("[SpawnSystem] >>> CALL OF DUTY SPAWN FLIP ACIONADO! Inversão: %s (AlphaThreat=%.1f | BravoThreat=%.1f)" % [
			"INVERTIDAS" if is_spawns_flipped else "PADRÃO",
			alpha_threat, bravo_threat
		])
		spawn_flipped.emit(is_spawns_flipped)

	return is_spawns_flipped

func get_optimal_spawn_transform(team: int, slot_idx: int = 0) -> Transform3D:
	_find_spawns()
	var scene = _get_map_node()
	var is_bo3 = _is_map_bo3(scene)

	evaluate_spawn_flip()

	# Determinar bases candidatas prioritária e alternativa
	var spawn_at_alpha = (team == 0) if not is_spawns_flipped else (team != 0)
	var primary_base = spawn_alpha_node if spawn_at_alpha else spawn_bravo_node
	var secondary_base = spawn_bravo_node if spawn_at_alpha else spawn_alpha_node

	# Fallbacks seguros por mapa (100% no interior dos quintais)
	var default_alpha = Vector3(40.0, -1.45, -8.0) if is_bo3 else Vector3(-14.0, 0.2, -30.0)
	var default_bravo = Vector3(-40.0, -1.45, -10.0) if is_bo3 else Vector3(0.0, 0.2, 32.0)
	var default_rot_alpha = Basis().rotated(Vector3.UP, -PI * 0.5) if is_bo3 else Basis().rotated(Vector3.UP, PI)
	var default_rot_bravo = Basis().rotated(Vector3.UP, PI * 0.5) if is_bo3 else Basis()

	# 1. Coleta de nós candidatos verificados na cena (SEM offsets matemáticos randômicos cegos)
	var primary_candidates: Array[Dictionary] = []
	var secondary_candidates: Array[Dictionary] = []

	var collect_nodes = func(base_node: Node3D, target_arr: Array[Dictionary], is_primary: bool):
		if not base_node or not is_instance_valid(base_node):
			return
		target_arr.append({ "tx": Transform3D(base_node.global_basis, base_node.global_position), "is_primary": is_primary })
		for child in base_node.get_children():
			if child is Node3D:
				target_arr.append({ "tx": Transform3D(child.global_basis, child.global_position), "is_primary": is_primary })

	collect_nodes.call(primary_base, primary_candidates, true)
	collect_nodes.call(secondary_base, secondary_candidates, false)

	var candidates: Array[Dictionary] = []
	candidates.append_array(primary_candidates)
	candidates.append_array(secondary_candidates)

	# Se nenhum nó foi encontrado, usar posições verificadas fixas (100% no quintal)
	if candidates.is_empty():
		var fb_pos = default_alpha if spawn_at_alpha else default_bravo
		var fb_rot = default_rot_alpha if spawn_at_alpha else default_rot_bravo
		var ground_y = _find_ground_y(fb_pos, scene)
		return Transform3D(fb_rot, Vector3(fb_pos.x, ground_y + 0.12, fb_pos.z))

	# 2. Coletar inimigos e aliados vivos com suas orientações de mira
	var enemy_data: Array[Dictionary] = []
	var friendly_positions: Array[Vector3] = []
	var space = scene.get_world_3d().direct_space_state if (scene and scene is Node3D) else null

	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p is CharacterBody3D:
			var p_team = p.get_team() if p.has_method("get_team") else 0
			var is_alive = true
			if p.has_node("HealthComponent"):
				var hp = p.get_node("HealthComponent")
				is_alive = hp and hp.current_health > 0
			if is_alive:
				if p_team != team:
					var fwd = -p.global_transform.basis.z
					fwd.y = 0.0
					enemy_data.append({ "pos": p.global_position, "fwd": fwd.normalized() })
				else:
					friendly_positions.append(p.global_position)

	for b in active_bots:
		if is_instance_valid(b) and b is CharacterBody3D and b.get("ai_state") != 6:
			var b_team = b.get("team")
			if b_team != team:
				var fwd = -b.global_transform.basis.z
				fwd.y = 0.0
				enemy_data.append({ "pos": b.global_position, "fwd": fwd.normalized() })
			else:
				friendly_positions.append(b.global_position)

	# 3. Algoritmo de Pontuação de Ameaça Call of Duty (Threat & Safety Scoring)
	var best_score = -999999.0
	var best_tx = candidates[0]["tx"]

	for item in candidates:
		var tx: Transform3D = item["tx"]
		var c_pos = tx.origin
		var is_prim = item["is_primary"]

		# Bônus de afinidade territorial para base recomendada
		var score = 100.0 if is_prim else 40.0

		# ── ANTI-OVERLAP ESTRITO: NUNCA nascer sobreposto a outro combatente ──
		var is_occupied = false
		for f_pos in friendly_positions:
			var f_dist = c_pos.distance_to(f_pos)
			if f_dist < 2.2:
				score -= 5000.0 # Ponto ocupado por outro jogador/bot aliado!
				is_occupied = true
			elif f_dist > 6.0 and f_dist < 20.0:
				score += 30.0 # Bônus de companheiro seguro como âncora tática

		for ed in enemy_data:
			var e_pos: Vector3 = ed["pos"]
			var e_fwd: Vector3 = ed["fwd"]
			var d = c_pos.distance_to(e_pos)

			# Penalidade Crítica de Proximidade (Anti-Spawn Kill)
			if d < 2.5:
				score -= 6000.0 # Ponto ocupado diretamente por inimigo!
			elif d < 7.0:
				score -= 1200.0 # Proximidade fatal imediata: NUNCA nasça aqui!
			elif d < 16.0:
				score -= (16.0 - d) * 45.0
			elif d < 26.0:
				score -= (26.0 - d) * 5.0
			else:
				score += minf((d - 26.0) * 1.5, 50.0)

			# Linha de Visão Direta (Line of Sight - LoS Check)
			if space and d < 35.0:
				var q = PhysicsRayQueryParameters3D.create(e_pos + Vector3.UP * 1.6, c_pos + Vector3.UP * 1.3, 1)
				var hit = space.intersect_ray(q)
				if hit.is_empty():
					score -= 500.0 # O inimigo tem visada limpa do ponto de respawn!

					# Se o inimigo estiver olhando na direção do ponto (dentro do cone de tiro)
					var to_cand = (c_pos - e_pos).normalized()
					to_cand.y = 0.0
					if e_fwd.dot(to_cand) > 0.4:
						score -= 200.0 # Ponto está exatamente na mira frontal do inimigo!

		# ── DISTRIBUIÇÃO EQUILIBRADA DE SLOTS NA BASE DESIGNADA ──
		if not primary_candidates.is_empty() and is_prim:
			var pref_cand_idx = slot_idx % primary_candidates.size()
			var ref_pos = primary_candidates[pref_cand_idx]["tx"].origin
			var dist_to_pref = c_pos.distance_to(ref_pos)
			if dist_to_pref < 0.6:
				score += 250.0 # Forte prioridade para o nó reservado a este slot da equipe!
			else:
				score -= dist_to_pref * 2.0

		if score > best_score:
			best_score = score
			best_tx = tx

	var final_pos = best_tx.origin
	var final_rot = best_tx.basis
	var ground_y = _find_ground_y(final_pos, scene)
	final_pos.y = ground_y + 0.15

	return Transform3D(final_rot, final_pos)

func _is_map_bo3(scene_node: Node) -> bool:
	if not scene_node:
		return false
	var s_name = scene_node.name.to_lower()
	var s_path = scene_node.scene_file_path.to_lower() if ("scene_file_path" in scene_node) else ""
	if "bo3" in s_name or "2065" in s_name or "bo3" in s_path or "2065" in s_path:
		return true
	if scene_node.find_child("Nuk3townModel", true, false) != null:
		return true
	return false

func _find_ground_y(origin: Vector3, context_node: Node) -> float:
	var space = context_node.get_world_3d().direct_space_state if context_node is Node3D else null
	if not space:
		return origin.y

	var from = Vector3(origin.x, 8.0, origin.z)
	var to = Vector3(origin.x, -12.0, origin.z)
	var query = PhysicsRayQueryParameters3D.create(from, to, 1)  # Layer 1: Geometria
	var result = space.intersect_ray(query)
	if result and not result.is_empty():
		if result.collider and not ("Safety" in result.collider.name):
			return result.position.y
	return origin.y

func _on_bot_died(dead_bot: CharacterBody3D, team: int, bot_name: String, slot_idx: int, difficulty: int, bot_id: int) -> void:
	active_bots.erase(dead_bot)

	if not is_active:
		return

	# Respawn tático estilo CoD após 3.0 segundos
	await get_tree().create_timer(3.0).timeout
	if is_active and is_inside_tree():
		var scene = _get_map_node()
		if scene and is_instance_valid(scene):
			_spawn_single_bot(team, bot_name, slot_idx, difficulty, bot_id)

func stop_bots() -> void:
	is_active = false
	for bot in active_bots:
		if is_instance_valid(bot):
			bot.queue_free()
	active_bots.clear()

