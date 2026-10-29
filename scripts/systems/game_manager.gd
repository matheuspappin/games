# =============================================================================
# game_manager.gd
# Autoload Singleton — gerencia estado global do jogo, modo de jogo e sessão
# Integrado com GameModeManager (1v1, 6v6, PvE) e WebBridge para navegador
# =============================================================================
extends Node

const SkinRegistry = preload("res://scripts/characters/skin_registry.gd")
const CombatRecordScript = preload("res://scripts/gamification/combat_record.gd")
const WeaponModifier = preload("res://scripts/weapons/weapon_modifier.gd")

signal game_state_changed(new_state: String)
signal match_started
signal match_countdown_started(duration: float)
signal match_countdown_tick(seconds_left: int)
signal match_countdown_completed
signal assist_registered(assistant_id: int, victim_id: int, damage_dealt: int, is_major: bool)
signal match_ended(winner_team: int, details: Dictionary)
signal player_died(player_id: int, killer_id: int)
signal player_spawned(player_id: int)

enum GameState { MENU, LOADING, PLAYING, PAUSED, MATCH_ENDED }

var current_state : GameState = GameState.MENU
var match_time_elapsed : float = 0.0
var is_match_active : bool = false
var local_player_team : int = 1  # 1 = Allied (CT), 2 = Enemy (T)
var local_player_name : String = "Operador_Alpha"
var lobby_roster      : Array[Dictionary] = []

# Configurações pendentes de partida para deploy pós-loading
var pending_match_mode  : int = 0
var pending_score_limit : int = 25
var pending_stake       : float = 0.0

# Gerenciador de modos competitivo e gamificação
var mode_manager  : GameModeManager = null
var xp_system     : XPSystem = null
var combat_record = null

# Estatísticas da partida atual (Telemetria de Precisão estilo BO3)
var player_stats : Dictionary = {
	"kills": 0,
	"deaths": 0,
	"assists": 0,
	"score": 0,
	"headshots": 0,
	"crouch_kills": 0,
	"shots_fired": 0,
	"shots_hit": 0,
	"accuracy": 0.0
}

# ── MODOS DE EXECUÇÃO & CONFIGURAÇÃO DE BOTS ───────────────────────────────
enum PlayMode { BOTS, ONLINE_HOST, ONLINE_CLIENT }
var play_mode : PlayMode = PlayMode.BOTS

enum BotDistribution { BALANCED, ALL_ENEMIES }
var bot_distribution : BotDistribution = BotDistribution.BALANCED
var bot_count : int = 5

enum BotDifficulty { RECRUIT, NOVICE, REGULAR, VETERAN, EXPERT }
var bot_difficulty : BotDifficulty = BotDifficulty.REGULAR

var online_ip : String = "127.0.0.1"
var online_port : int = 7777
var online_fill_bots : bool = false
var selected_game_mode : String = "6v6"  # "6v6", "1v1", "pve"

# ── MAPA / CENÁRIO ALVO PARA DEPLOY ─────────────────────────────────────────
var target_map_path         : String = "res://scenes/_world/map_nuk3town_bo3.tscn"
var target_map_display_name : String = "NUKETOWN 2065 (FUTURISTA)"

# ── LOADOUT / CLASSE SELECIONADA PELO JOGADOR ───────────────────────────────
var primary_weapon_res   : String = "res://resources/weapons/ak47.tres"
var secondary_weapon_res : String = "res://resources/weapons/pistol.tres"
var melee_weapon_res     : String = "res://resources/weapons/knife.tres"
var selected_class_name  : String = "Assalto"
var selected_faction     : int = 1  # 1 = Counter-Terrorist, 2 = Terrorist
var selected_skin_id     : String = "ct_urban"

# ── CUSTOMIZAÇÃO DE ARMA / GUNSMITH ──────────────────────────────────────────
var primary_camo   : String = "default"
var primary_optic  : String = "optic_red_dot"
var primary_muzzle : String = "none"
var primary_mag    : String = "none"

# ── EQUIPAMENTOS & VANTAGENS (PERKS / BO6) ───────────────────────────────────
var selected_lethal    : String = "semtex"      # "semtex", "frag", "c4", "molotov"
var selected_tactical  : String = "stim"        # "stim", "flash", "smoke", "stun"
var selected_perk1     : String = "flak_jacket" # "flak_jacket", "ghost", "ninja"
var selected_perk2     : String = "tracker"     # "tracker", "fast_hands", "scavenger"
var selected_perk3     : String = "high_alert"  # "high_alert", "tac_mask", "dexterity"
var selected_specialty : String = "recon"       # "recon", "enforcer", "strategist"

func set_equipment_and_perks(lethal: String, tactical: String, p1: String, p2: String, p3: String, specialty: String) -> void:
	selected_lethal = lethal if lethal != "" else "semtex"
	selected_tactical = tactical if tactical != "" else "stim"
	selected_perk1 = p1 if p1 != "" else "flak_jacket"
	selected_perk2 = p2 if p2 != "" else "tracker"
	selected_perk3 = p3 if p3 != "" else "high_alert"
	selected_specialty = specialty if specialty != "" else "recon"

# ── CACHE GLOBAL DE CENÁRIOS EMPACOTADOS (EVITA REIMPORTAÇÃO GLTF NO 2º LOAD) ──
var scene_cache : Dictionary = {}
var _recent_victim_kills : Dictionary = {}

func has_cached_scene(path: String) -> bool:
	return scene_cache.has(path) and is_instance_valid(scene_cache[path])

func get_cached_scene(path: String) -> PackedScene:
	if has_cached_scene(path):
		return scene_cache[path]
	return null

func cache_scene(path: String, scn: PackedScene) -> void:
	if scn and is_instance_valid(scn):
		scene_cache[path] = scn

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_mode_manager()
	xp_system = XPSystem.new()
	xp_system.name = "XPSystem"
	add_child(xp_system)
	xp_system.load_from_disk()
	combat_record = CombatRecordScript.new()

func _setup_mode_manager() -> void:
	mode_manager = GameModeManager.new()
	mode_manager.name = "GameModeManager"
	add_child(mode_manager)
	
	mode_manager.score_updated.connect(_on_mode_score_updated)
	mode_manager.game_ended.connect(_on_mode_game_ended)
	mode_manager.sudden_death_started.connect(_on_mode_sudden_death)
	mode_manager.match_countdown_started.connect(func(dur): match_countdown_started.emit(dur))
	mode_manager.match_countdown_tick.connect(func(sec): match_countdown_tick.emit(sec))
	mode_manager.match_countdown_completed.connect(func(): match_countdown_completed.emit())

func _process(delta: float) -> void:
	if is_match_active:
		match_time_elapsed += delta

func configure_and_launch_game(mode_str: String, map_str: String, stake: float = 10.0, player_name: String = "Operador") -> void:
	local_player_name = player_name
	is_match_active = false
	
	# Mapear mapa
	match map_str.to_lower():
		"nuketown_classic", "nuketown_bo1", "bo1":
			target_map_path = "res://scenes/_world/map_nuketown_1v1.tscn"
			target_map_display_name = "NUKETOWN CLÁSSICO (1960)"
		"hardhat", "hardhat_1v1":
			target_map_path = "res://scenes/_world/map_hardhat_1v1.tscn"
			target_map_display_name = "HARDHAT ARENA"
		_:
			target_map_path = "res://scenes/_world/map_nuk3town_bo3.tscn"
			target_map_display_name = "NUKETOWN 2065"

	# Mapear modo
	var selected_enum = GameModeManager.GameMode.WAGER_1V1
	match mode_str.to_lower():
		"6v6", "6v6_tdm", "tdm":
			selected_enum = GameModeManager.GameMode.TDM_6V6
		"pve", "bots", "pve_bots":
			selected_enum = GameModeManager.GameMode.PVE_BOTS_ARENA
		_:
			selected_enum = GameModeManager.GameMode.WAGER_1V1

	# Carregar mapa e iniciar de forma segura
	print("[GameManager] Inicializando sessão: %s no mapa %s (Aposta: $%.2f)" % [mode_str, map_str, stake])
	if has_cached_scene(target_map_path):
		print("[GameManager] Instanciando mapa direto do cache de memória...")
		var cached_scn = get_cached_scene(target_map_path)
		get_tree().change_scene_to_packed(cached_scn)
	elif ResourceLoader.exists("res://scenes/ui/loading_screen.tscn"):
		get_tree().change_scene_to_file("res://scenes/ui/loading_screen.tscn")
	else:
		get_tree().change_scene_to_file(target_map_path)
	
	await get_tree().create_timer(0.3).timeout
	start_match(selected_enum, stake)

func start_match(mode_enum: GameModeManager.GameMode = GameModeManager.GameMode.WAGER_1V1, stake: float = 10.0) -> void:
	pending_match_mode = mode_enum
	pending_stake = stake
	deploy_match_start()

func deploy_match_start() -> void:
	is_match_active = true
	match_time_elapsed = 0.0
	player_stats = {
		"kills": 0, "deaths": 0, "assists": 0, "score": 0, "headshots": 0,
		"crouch_kills": 0, "shots_fired": 0, "shots_hit": 0, "accuracy": 0.0
	}
	if combat_record:
		combat_record.reset_match_stats()
	set_state(GameState.PLAYING)
	
	if mode_manager:
		var mode_enum = pending_match_mode
		var score_lim = pending_score_limit if pending_score_limit > 0 else 25
		var stake = pending_stake
		mode_manager.start_match(mode_enum, score_lim, stake, false)

	match_started.emit()
	
	var wb = get_node_or_null("/root/WebBridge")
	if wb:
		wb.notify_web("match_started", {
			"mode": GameModeManager.GameMode.keys()[pending_match_mode],
			"map": target_map_display_name,
			"player": local_player_name,
			"stake": pending_stake
		})

func restart_match_rematch(new_stake: float = 10.0) -> void:
	print("[GameManager] Revanche aceita com aposta: $%.2f!" % new_stake)
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("reset_match_state"):
		nm.reset_match_state()
	launch_configured_match()

func end_match(winner_team: int, details: Dictionary = {}) -> void:
	is_match_active = false
	set_state(GameState.MATCH_ENDED)
	var my_team = 0 if local_player_team == 1 else 1
	var is_victory = (winner_team == my_team)
	if combat_record:
		combat_record.record_match_end(is_victory, match_time_elapsed, player_stats.score)
		details["combat_record"] = combat_record.match_stats
	match_ended.emit(winner_team, details)
	
	var wb = get_node_or_null("/root/WebBridge")
	if wb:
		wb.notify_web("match_ended", details)

func _on_mode_score_updated(alpha: int, bravo: int) -> void:
	var wb = get_node_or_null("/root/WebBridge")
	if wb:
		wb.notify_web("score_updated", {
			"score_alpha": alpha,
			"score_bravo": bravo
		})

func _on_mode_game_ended(winner: int, details: Dictionary) -> void:
	end_match(winner, details)

func _on_mode_sudden_death() -> void:
	var wb = get_node_or_null("/root/WebBridge")
	if wb:
		wb.notify_web("sudden_death", { "active": true })

func record_shot_fired() -> void:
	if combat_record:
		combat_record.record_shot_fired()
	player_stats["shots_fired"] = combat_record.match_stats["shots_fired"] if combat_record else int(player_stats.get("shots_fired", 0)) + 1
	var f = float(player_stats["shots_fired"])
	var h = float(player_stats.get("shots_hit", 0))
	player_stats["accuracy"] = (h / maxf(1.0, f)) * 100.0

func record_shot_hit(is_headshot: bool = false, dist: float = 0.0) -> void:
	if combat_record:
		combat_record.record_shot_hit(is_headshot, dist)
	player_stats["shots_hit"] = combat_record.match_stats["shots_hit"] if combat_record else int(player_stats.get("shots_hit", 0)) + 1
	var f = float(player_stats.get("shots_fired", 1))
	var h = float(player_stats["shots_hit"])
	player_stats["accuracy"] = (h / maxf(1.0, f)) * 100.0

func register_kill(killer_id: int, victim_id: int, is_headshot: bool, is_crouch: bool = false, is_slide: bool = false, distance: float = 0.0) -> void:
	var k_team = GameModeManager.Team.ALPHA if (killer_id == 0 or killer_id == 1) else GameModeManager.Team.BRAVO
	var v_team = GameModeManager.Team.BRAVO if (victim_id != 0 and victim_id != 1) else GameModeManager.Team.ALPHA
	register_team_kill(k_team, v_team, killer_id, victim_id, is_headshot, is_crouch, is_slide, distance)

func register_team_kill(killer_team: int, victim_team: int, killer_id: int, victim_id: int,
                        is_headshot: bool = false, is_crouch: bool = false, is_slide: bool = false, distance: float = 0.0) -> void:
	var now_ms = Time.get_ticks_msec()
	if _recent_victim_kills.has(victim_id) and (now_ms - _recent_victim_kills[victim_id] < 1500):
		print("[GameManager] Ignorando registro duplicado de morte para victim_id: %d" % victim_id)
		return
	_recent_victim_kills[victim_id] = now_ms

	# Bloqueio de pontuação por fogo amigo (em modos com times)
	if killer_team == victim_team and killer_team != -1:
		print("[GameManager] Fogo amigo registrado (killer_team == victim_team). Pontuação de kill cancelada.")
		if victim_id == 0 or victim_id == 1:
			player_stats.deaths += 1
			if combat_record:
				combat_record.record_death()
		return

	if killer_id == 0 or killer_id == 1:
		player_stats.kills += 1
		if is_headshot:
			player_stats.headshots += 1
		if is_crouch or is_slide:
			player_stats["crouch_kills"] = int(player_stats.get("crouch_kills", 0)) + 1
		
		# Pontuação calculada estilo BO3 (+100 Kill, +25 Headshot, +25 Low Blow, +25 Longshot)
		var pts = 100
		if is_headshot: pts += 25
		if is_crouch or is_slide: pts += 25
		if distance >= 25.0: pts += 25

		# Notificar PerkManager sobre a eliminação (ativa Enforcer Adrenaline e Scavenger)
		var p_node = get_tree().current_scene.find_child("Player*", true, false) if get_tree() and get_tree().current_scene else null
		if p_node and "perk_manager" in p_node and p_node.perk_manager:
			pts = int(float(pts) * p_node.perk_manager.get_score_multiplier())
			p_node.perk_manager.on_enemy_eliminated(null)

		player_stats.score += pts

		if combat_record:
			combat_record.record_kill(is_headshot, is_crouch, is_slide, distance, "ak47")

	if victim_id == 0 or victim_id == 1:
		player_stats.deaths += 1
		if combat_record:
			combat_record.record_death()

	if mode_manager:
		mode_manager.register_kill(killer_team, victim_team, killer_id, victim_id, "ak47", is_headshot, is_crouch, is_slide, distance)

	# Atualizar NetworkManager para sincronizar com HUD
	var net = get_node_or_null("/root/NetworkManager")
	if not net and get_tree().current_scene:
		net = get_tree().current_scene.get_node_or_null("NetworkManager")
		if not net:
			net = get_tree().current_scene.find_child("NetworkManager", true, false)
	if net and net.has_method("record_team_score"):
		net.record_team_score(killer_team, victim_team, killer_id, victim_id, is_headshot, is_crouch or is_slide)

func is_in_countdown() -> bool:
	return mode_manager != null and mode_manager.is_in_countdown()

func register_assist(assistant_id: int, assistant_team: int, victim_id: int, damage_dealt: int, is_major: bool = false) -> void:
	if assistant_id == 0 or assistant_id == 1:
		player_stats.assists += 1
		var pts = 75 if is_major else 50
		var p_node = get_tree().current_scene.find_child("Player*", true, false) if get_tree() and get_tree().current_scene else null
		if p_node and "perk_manager" in p_node and p_node.perk_manager:
			pts = int(float(pts) * p_node.perk_manager.get_score_multiplier())

		player_stats.score += pts
		if combat_record:
			combat_record.record_assist(is_major)
		if xp_system:
			xp_system.add_xp(pts, "Assistência" if not is_major else "Assistência Principal")

	if mode_manager:
		mode_manager.register_assist(assistant_id, victim_id, damage_dealt, is_major)

	# Atualizar NetworkManager para sincronizar com Placar e HUD
	var net = get_node_or_null("/root/NetworkManager")
	if not net and get_tree().current_scene:
		net = get_tree().current_scene.get_node_or_null("NetworkManager")
		if not net:
			net = get_tree().current_scene.find_child("NetworkManager", true, false)
	if net:
		if not net.player_stats.has(assistant_id):
			net.player_stats[assistant_id] = {"kills": 0, "deaths": 0, "assists": 0, "score": 0, "team": assistant_team}
		net.player_stats[assistant_id]["assists"] = int(net.player_stats[assistant_id].get("assists", 0)) + 1
		net.player_stats[assistant_id]["score"] = int(net.player_stats[assistant_id].get("score", 0)) + (75 if is_major else 50)
		if net.has_signal("stats_updated"):
			net.stats_updated.emit(net.player_stats)

	assist_registered.emit(assistant_id, victim_id, damage_dealt, is_major)
	print("[GameManager] Assistência registrada! Assistente: %d | Vítima: %d | Dano: %d | Principal: %s" % [
		assistant_id, victim_id, damage_dealt, str(is_major)
	])

func configure_bot_match(map_path: String, map_name: String, count: int, distribution: BotDistribution, difficulty: BotDifficulty, mode_str: String = "6v6") -> void:
	play_mode = PlayMode.BOTS
	target_map_path = map_path
	target_map_display_name = map_name
	bot_count = count
	bot_distribution = distribution
	bot_difficulty = difficulty
	selected_game_mode = mode_str
	lobby_roster.clear()

func configure_online_match(map_path: String, map_name: String, is_host: bool, ip: String = "127.0.0.1", port: int = 7777, fill_bots: bool = false, count: int = 0, mode_str: String = "6v6") -> void:
	play_mode = PlayMode.ONLINE_HOST if is_host else PlayMode.ONLINE_CLIENT
	target_map_path = map_path
	target_map_display_name = map_name
	online_ip = ip
	online_port = port
	online_fill_bots = fill_bots
	bot_count = count
	selected_game_mode = mode_str

func launch_configured_match() -> void:
	print("[GameManager] Lançando partida: %s (%s) | Bots: %d | Modo: %s" % [
		target_map_display_name,
		"Com Bots" if play_mode == PlayMode.BOTS else ("Host Online" if play_mode == PlayMode.ONLINE_HOST else "Cliente Online"),
		bot_count if play_mode == PlayMode.BOTS else 0,
		selected_game_mode
	])

	is_match_active = true
	match_time_elapsed = 0.0
	player_stats = {
		"kills": 0, "deaths": 0, "assists": 0, "score": 0, "headshots": 0,
		"crouch_kills": 0, "shots_fired": 0, "shots_hit": 0, "accuracy": 0.0
	}
	if combat_record:
		combat_record.reset_match_stats()
	set_state(GameState.PLAYING)

	var score_lim = 50
	if selected_game_mode == "1v1" or bot_count <= 2:
		score_lim = 10
	elif selected_game_mode == "pve":
		score_lim = 25
	elif bot_count >= 3 and bot_count <= 6:
		score_lim = 25

	if mode_manager:
		var mode_enum = GameModeManager.GameMode.TDM_6V6
		if selected_game_mode == "pve":
			mode_enum = GameModeManager.GameMode.PVE_BOTS_ARENA
		elif selected_game_mode == "1v1" or (play_mode != PlayMode.BOTS and bot_count <= 2):
			mode_enum = GameModeManager.GameMode.WAGER_1V1
		var stake_val = 0.0 if play_mode == PlayMode.BOTS else 10.0
		mode_manager.start_match(mode_enum, score_lim, stake_val)

	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("reset_match_state"):
		nm.reset_match_state()

	match_started.emit()

	if ResourceLoader.exists("res://scenes/ui/loading_screen.tscn"):
		get_tree().change_scene_to_file("res://scenes/ui/loading_screen.tscn")
	elif has_cached_scene(target_map_path):
		get_tree().change_scene_to_packed(get_cached_scene(target_map_path))
	else:
		get_tree().change_scene_to_file(target_map_path)

func set_loadout(primary_path: String, secondary_path: String, melee_path: String, class_name_str: String = "Personalizado") -> void:
	primary_weapon_res = primary_path
	secondary_weapon_res = secondary_path
	melee_weapon_res = melee_path
	selected_class_name = class_name_str

func set_weapon_customization(camo: String, optic: String, muzzle: String, mag: String) -> void:
	primary_camo = camo if camo != "" else "default"
	primary_optic = optic if optic != "" else "none"
	primary_muzzle = muzzle if muzzle != "" else "none"
	primary_mag = mag if mag != "" else "none"

func get_primary_attachments() -> Array[AttachmentData]:
	var list: Array[AttachmentData] = []
	if primary_optic != "none" and primary_optic != "":
		var att = WeaponModifier.get_attachment_resource(primary_optic)
		if att: list.append(att)
	if primary_muzzle != "none" and primary_muzzle != "":
		var att = WeaponModifier.get_attachment_resource(primary_muzzle)
		if att: list.append(att)
	if primary_mag != "none" and primary_mag != "":
		var att = WeaponModifier.get_attachment_resource(primary_mag)
		if att: list.append(att)
	return list

func set_character_skin(faction: int, skin_id: String) -> void:
	selected_faction = faction
	local_player_team = faction
	selected_skin_id = skin_id

func get_current_skin_scene() -> PackedScene:
	return SkinRegistry.load_skin_scene(selected_skin_id)

func get_bot_skin_scene(bot_idx: int, bot_team: int = 1) -> PackedScene:
	var faction = SkinRegistry.Faction.COUNTER_TERRORIST if bot_team == 0 else SkinRegistry.Faction.TERRORIST
	var skins = SkinRegistry.get_skins_by_faction(faction)
	if skins.is_empty():
		return null
	var skin_info = skins[bot_idx % skins.size()]
	return SkinRegistry.load_skin_scene(skin_info["id"])

func get_primary_weapon() -> WeaponData:
	if ResourceLoader.exists(primary_weapon_res):
		var base_w = load(primary_weapon_res) as WeaponData
		return WeaponModifier.apply_attachments(base_w, get_primary_attachments())
	return null

func get_secondary_weapon() -> WeaponData:
	if ResourceLoader.exists(secondary_weapon_res):
		return load(secondary_weapon_res) as WeaponData
	return null

func get_melee_weapon() -> WeaponData:
	if ResourceLoader.exists(melee_weapon_res):
		return load(melee_weapon_res) as WeaponData
	return null

func set_state(new_state: GameState) -> void:
	current_state = new_state
	game_state_changed.emit(GameState.keys()[new_state])

func pause() -> void:
	if current_state == GameState.PLAYING:
		set_state(GameState.PAUSED)
		get_tree().paused = true

func resume() -> void:
	if current_state == GameState.PAUSED:
		set_state(GameState.PLAYING)
		get_tree().paused = false

func quit_to_menu() -> void:
	get_tree().paused = false
	is_match_active = false
	set_state(GameState.MENU)
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
