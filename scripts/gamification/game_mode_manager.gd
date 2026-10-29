# =============================================================================
# game_mode_manager.gd
# Gerenciador de Modos de Jogo do NUKE — 1v1 Wager, 6v6 TDM e PvE Bot Arena
# Suporta regras competitivas, Sudden Death, Bounties, MVP e Farm de Tokens
# =============================================================================
class_name GameModeManager
extends Node

enum GameMode {
	WAGER_1V1,          # Duelo até 10 kills com aposta USDC, Sudden Death no 9x9, Near-Miss HP, Revanche
	CASUAL_1V1,         # Duelo tático 1v1 casual/treino contra bots sem aposta monetária
	TDM_6V6,            # 12 jogadores (CT vs T), meta de 50 kills, cálculo de MVP e Bounties
	PVE_BOTS_ARENA,     # Treino contra ondas de SoldierBots, durabilidade e tokens $NUKE farmados
	TDM_CLASSIC,
	FFA
}

enum Team { NONE = -1, ALPHA = 0, BRAVO = 1 }
enum MatchPhase { NOT_STARTED, COUNTDOWN, ACTIVE, ENDED }

# Sinais de eventos de partida
signal score_updated(team_a_score: int, team_b_score: int)
signal timer_updated(seconds_remaining: float)
signal match_countdown_started(duration: float)
signal match_countdown_tick(seconds_left: int)
signal match_countdown_completed
signal assist_registered(assistant_id: int, victim_id: int, damage_dealt: int, is_major: bool)
signal sudden_death_started
signal game_ended(winning_team: int, details: Dictionary)
signal kill_registered(killer_id: int, victim_id: int, weapon_id: String, is_headshot: bool)
signal streak_achieved(killer_id: int, streak_count: int, streak_name: String)
signal multi_kill_achieved(killer_id: int, count: int, medal_name: String, xp_bonus: int)
signal medal_awarded(killer_id: int, medal_name: String, xp_amount: int)
signal tokens_farmed_updated(total_tokens: int)
signal bot_wave_spawned(wave_number: int, bot_count: int)
signal rematch_offered(double_stake: float)

@export var game_mode        : GameMode = GameMode.WAGER_1V1
@export var score_limit      : int      = 10      # 10 para 1v1, 50 para 6v6, 25 para PvE
@export var time_limit       : float    = 300.0   # 5 minutos
@export var countdown_duration: float   = 5.0     # 5 segundos de contagem pré-partida estilo CoD
@export var stake_amount     : float    = 10.0    # Valor da aposta em USDC / $NUKE
@export var stake_currency   : String   = "USDC"

# Estado da partida
var match_phase              : MatchPhase = MatchPhase.NOT_STARTED
var countdown_remaining      : float = 0.0
var _last_countdown_sec_emitted: int = -1
var score_alpha              : int   = 0   # Jogador local / Time Alpha (CT)
var score_bravo              : int   = 0   # Oponente / Time Bravo (T)
var time_remaining           : float = 0.0
var is_active                : bool  = false
var sudden_death_active      : bool  = false

# Estatísticas individuais e Bounties
var player_kills_map         : Dictionary = {}  # { player_id: int }
var player_assists_map       : Dictionary = {}  # { player_id: int }
var player_streaks           : Dictionary = {}  # { player_id: int }
var _last_kill_times         : Dictionary = {}  # { player_id: float }
var _multi_kill_counts       : Dictionary = {}  # { player_id: int }
var mvp_id                   : int        = 0
var last_opponent_hp         : int        = 100

# Estatísticas PvE Bots
var current_bot_wave         : int        = 1
var bots_killed_count        : int        = 0
var tokens_farmed            : int        = 0
var tokens_per_kill          : int        = 50
var tokens_headshot_bonus    : int        = 50

# Nós do cenário
var bot_spawner_timer        : Timer = null

func _ready() -> void:
	time_remaining = time_limit
	_setup_bot_timer()

func _process(delta: float) -> void:
	if match_phase == MatchPhase.COUNTDOWN:
		countdown_remaining -= delta
		var sec_ceil = int(ceil(max(0.0, countdown_remaining)))
		if sec_ceil != _last_countdown_sec_emitted:
			_last_countdown_sec_emitted = sec_ceil
			match_countdown_tick.emit(sec_ceil)
		if countdown_remaining <= 0.0:
			_complete_countdown()
		return

	if not is_active or match_phase != MatchPhase.ACTIVE:
		return
		
	time_remaining -= delta
	timer_updated.emit(max(0.0, time_remaining))
	if time_remaining <= 0.0:
		_time_expired()

func is_in_countdown() -> bool:
	return match_phase == MatchPhase.COUNTDOWN

func _complete_countdown() -> void:
	match_phase = MatchPhase.ACTIVE
	is_active = true
	countdown_remaining = 0.0
	match_countdown_completed.emit()
	print("[GameModeManager] Contagem regressiva finalizada! COMBATE INICIADO!")

func _setup_bot_timer() -> void:
	bot_spawner_timer = Timer.new()
	bot_spawner_timer.name = "BotSpawnerTimer"
	bot_spawner_timer.wait_time = 4.0
	bot_spawner_timer.one_shot = false
	bot_spawner_timer.timeout.connect(_on_bot_spawner_tick)
	add_child(bot_spawner_timer)

func start_match(mode: GameMode = GameMode.WAGER_1V1, custom_score_limit: int = 0, stake: float = 10.0, skip_countdown: bool = false) -> void:
	game_mode = mode
	stake_amount = stake
	score_alpha = 0
	score_bravo = 0
	sudden_death_active = false
	
	player_kills_map.clear()
	player_assists_map.clear()
	player_streaks.clear()
	tokens_farmed = 0
	bots_killed_count = 0
	current_bot_wave = 1
	
	match game_mode:
		GameMode.WAGER_1V1, GameMode.CASUAL_1V1:
			score_limit = 10 if custom_score_limit <= 0 else custom_score_limit
			time_limit = 300.0  # 5 minutos
			call_deferred("_setup_1v1_bots")
		GameMode.TDM_6V6:
			score_limit = 50 if custom_score_limit <= 0 else custom_score_limit
			time_limit = 420.0  # 7 minutos
			call_deferred("_setup_6v6_bots")
		GameMode.PVE_BOTS_ARENA:
			score_limit = 25 if custom_score_limit <= 0 else custom_score_limit
			time_limit = 600.0  # 10 minutos
			if bot_spawner_timer:
				bot_spawner_timer.start()
				call_deferred("_spawn_bot_wave", 3)

	time_remaining = time_limit
	score_updated.emit(score_alpha, score_bravo)
	
	if skip_countdown:
		_complete_countdown()
	else:
		is_active = false
		match_phase = MatchPhase.COUNTDOWN
		countdown_remaining = countdown_duration
		_last_countdown_sec_emitted = int(ceil(countdown_duration))
		match_countdown_started.emit(countdown_duration)
		match_countdown_tick.emit(_last_countdown_sec_emitted)
		print("[GameModeManager] Iniciando contagem regressiva pré-partida: %.1fs" % countdown_duration)

	print("[GameModeManager] Partida configurada no modo: %s | Meta: %d | Aposta: $%.2f %s" % [
		GameMode.keys()[game_mode], score_limit, stake_amount, stake_currency
	])

func register_assist(assistant_id: int, victim_id: int, damage_dealt: int, is_major: bool) -> void:
	var prev = player_assists_map.get(assistant_id, 0)
	player_assists_map[assistant_id] = prev + 1
	assist_registered.emit(assistant_id, victim_id, damage_dealt, is_major)

func register_kill(killer_team: Team, _victim_team: Team,
				   killer_id: int, victim_id: int,
				   weapon_id: String, is_headshot: bool,
				   is_crouch: bool = false, is_slide: bool = false, distance: float = 0.0) -> void:
	if not is_active:
		return

	# Atualizar contadores individuais
	var prev_kills = player_kills_map.get(killer_id, 0)
	player_kills_map[killer_id] = prev_kills + 1
	
	# Streaks e Bounties
	var streak = player_streaks.get(killer_id, 0) + 1
	player_streaks[killer_id] = streak
	player_streaks[victim_id] = 0 # resetar streak da vítima

	kill_registered.emit(killer_id, victim_id, weapon_id, is_headshot)

	# Multi-Kill Tracking (janela de 4.0s - estilo CoD)
	var now = Time.get_ticks_msec() / 1000.0
	var last_time = _last_kill_times.get(killer_id, 0.0)
	var multi_count = 1
	if now - last_time <= 4.0:
		multi_count = _multi_kill_counts.get(killer_id, 1) + 1
	_last_kill_times[killer_id] = now
	_multi_kill_counts[killer_id] = multi_count

	# 1. Multi-Kills estilo BO3
	if multi_count == 2:
		multi_kill_achieved.emit(killer_id, 2, "DOUBLE KILL!", 100)
	elif multi_count == 3:
		multi_kill_achieved.emit(killer_id, 3, "TRIPLE KILL!", 150)
	elif multi_count == 4:
		multi_kill_achieved.emit(killer_id, 4, "FURY KILL!", 200)
	elif multi_count == 5:
		multi_kill_achieved.emit(killer_id, 5, "FRENZY KILL!", 250)
	elif multi_count == 6:
		multi_kill_achieved.emit(killer_id, 6, "SUPER KILL!", 300)
	elif multi_count == 7:
		multi_kill_achieved.emit(killer_id, 7, "MEGA KILL!", 350)
	elif multi_count == 8:
		multi_kill_achieved.emit(killer_id, 8, "ULTRA KILL!", 400)
	elif multi_count >= 9:
		multi_kill_achieved.emit(killer_id, multi_count, "CHAIN KILL!", 500)
	else:
		medal_awarded.emit(killer_id, "KILL", 100)

	# 2. Medalhas de Combate Situacional BO3
	if is_headshot:
		medal_awarded.emit(killer_id, "HEADSHOT", 25)
	if is_slide or is_crouch:
		# "Low Blow" no BO3 = matar o oponente agachado ou durante deslize tático
		medal_awarded.emit(killer_id, "LOW BLOW", 25)
	if distance >= 25.0:
		medal_awarded.emit(killer_id, "LONG SHOT", 25)
	elif distance > 0.0 and distance <= 3.2:
		medal_awarded.emit(killer_id, "POINT BLANK", 25)
	if (score_alpha + score_bravo) == 0:
		medal_awarded.emit(killer_id, "FIRST BLOOD", 100)

	# 3. Streaks sem morrer estilo BO3 (Bloodthirsty, Merciless, Ruthless, Relentless, Brutal, Nuclear)
	match streak:
		5:
			streak_achieved.emit(killer_id, 5, "BLOODTHIRSTY (5 SEM MORRER!)")
			medal_awarded.emit(killer_id, "BLOODTHIRSTY", 200)
		10:
			streak_achieved.emit(killer_id, 10, "MERCILESS (10 SEM MORRER!)")
			medal_awarded.emit(killer_id, "MERCILESS", 400)
		15:
			streak_achieved.emit(killer_id, 15, "RUTHLESS (15 SEM MORRER!)")
			medal_awarded.emit(killer_id, "RUTHLESS", 600)
		20:
			streak_achieved.emit(killer_id, 20, "RELENTLESS (20 SEM MORRER!)")
			medal_awarded.emit(killer_id, "RELENTLESS", 800)
		25:
			streak_achieved.emit(killer_id, 25, "BRUTAL (25 SEM MORRER!)")
			medal_awarded.emit(killer_id, "BRUTAL", 1000)
		30:
			streak_achieved.emit(killer_id, 30, "NUCLEAR (30 SEM MORRER!)")
			medal_awarded.emit(killer_id, "NUCLEAR", 1500)

	match game_mode:
		GameMode.WAGER_1V1:
			if killer_team == Team.ALPHA:
				score_alpha += 1
			else:
				score_bravo += 1
			_check_1v1_sudden_death()

		GameMode.TDM_6V6:
			if killer_team == Team.ALPHA:
				score_alpha += 1
			else:
				score_bravo += 1
			_update_mvp()

		GameMode.PVE_BOTS_ARENA:
			if killer_team == Team.ALPHA:
				score_alpha += 1
				bots_killed_count += 1
				var earned = tokens_per_kill + (tokens_headshot_bonus if is_headshot else 0)
				tokens_farmed += earned
				tokens_farmed_updated.emit(tokens_farmed)

	score_updated.emit(score_alpha, score_bravo)
	_check_score_limit()

func _check_1v1_sudden_death() -> void:
	if game_mode == GameMode.WAGER_1V1:
		# Se empatar em 9 a 9 numa disputa até 10 kills
		if score_alpha == score_limit - 1 and score_bravo == score_limit - 1:
			if not sudden_death_active:
				sudden_death_active = true
				sudden_death_started.emit()
				print("[GameModeManager] SUDDEN DEATH ATIVADO! PONTO DA VITÓRIA!")

func _update_mvp() -> void:
	var top_id = -1
	var max_k = -1
	for pid in player_kills_map.keys():
		if player_kills_map[pid] > max_k:
			max_k = player_kills_map[pid]
			top_id = pid
	mvp_id = top_id

func _check_score_limit() -> void:
	if score_alpha >= score_limit:
		_end_game(Team.ALPHA)
	elif score_bravo >= score_limit:
		_end_game(Team.BRAVO)

func _time_expired() -> void:
	is_active = false
	var winner = Team.ALPHA if score_alpha > score_bravo else \
				 (Team.BRAVO if score_bravo > score_alpha else Team.NONE)
	_end_game(winner)

func _end_game(winning_team: int) -> void:
	is_active = false
	if bot_spawner_timer:
		bot_spawner_timer.stop()

	var winner_takes = stake_amount * 2.0 * 0.94 # menos 6% rake
	var details = {
		"game_mode": GameMode.keys()[game_mode],
		"winner_team": winning_team,
		"score_alpha": score_alpha,
		"score_bravo": score_bravo,
		"payout": winner_takes,
		"tokens_farmed": tokens_farmed,
		"mvp_id": mvp_id,
		"last_opponent_hp": last_opponent_hp
	}

	game_ended.emit(winning_team, details)
	print("[GameModeManager] Fim de partida! Vencedor: Time %d | Detalhes: %s" % [winning_team, str(details)])

func set_last_opponent_hp(hp: int) -> void:
	last_opponent_hp = max(1, hp)

func _on_bot_spawner_tick() -> void:
	if not is_active or game_mode != GameMode.PVE_BOTS_ARENA:
		return
	var current_enemies = get_tree().get_nodes_in_group("enemies")
	if current_enemies.size() < 4:
		_spawn_bot_wave(2)

func _spawn_bot_wave(count: int) -> void:
	var scene = get_tree().current_scene
	if not scene:
		return

	var bot_scene = load("res://scenes/enemies/soldier_bot.tscn") as PackedScene
	if not bot_scene:
		return

	var spawn_points = scene.find_children("Spawn_*", "Node3D", true, false)
	var spawned = 0

	for i in range(count):
		var bot = bot_scene.instantiate() as Node3D
		var pos = Vector3(randf_range(-15, 15), 1.0, randf_range(-15, 15))
		if not spawn_points.is_empty():
			var sp = spawn_points[randi() % spawn_points.size()]
			pos = sp.global_position + Vector3(randf_range(-2, 2), 0.5, randf_range(-2, 2))

		bot.position = pos
		scene.add_child(bot)
		spawned += 1

	bot_wave_spawned.emit(current_bot_wave, spawned)
	current_bot_wave += 1

func get_formatted_time() -> String:
	var mins = int(time_remaining) / 60
	var secs = int(time_remaining) % 60
	return "%02d:%02d" % [mins, secs]

func _setup_1v1_bots() -> void:
	# BotManager gerencia os combatentes IA do jogo de forma unificada e estável
	var scene = get_tree().current_scene
	if not scene or scene.find_child("BotManager", true, false) != null or has_node("/root/GameManager"):
		return
	var p2 = scene.get_node_or_null("Player_2")
	if not p2 and not scene.get_node_or_null("Bot_Opponent_Bravo"):
		_spawn_single_bot(Team.BRAVO, "Bot_Opponent_Bravo")

func _setup_6v6_bots() -> void:
	# BotManager gerencia os combatentes IA do jogo de forma unificada e estável
	var scene = get_tree().current_scene
	if not scene or scene.find_child("BotManager", true, false) != null or has_node("/root/GameManager"):
		return
	for i in range(5):
		var b_name = "Bot_Ally_Alpha_%d" % (i + 1)
		if not scene.get_node_or_null(b_name):
			_spawn_single_bot(Team.ALPHA, b_name)
	for i in range(6):
		var b_name = "Bot_Enemy_Bravo_%d" % (i + 1)
		if not scene.get_node_or_null(b_name):
			_spawn_single_bot(Team.BRAVO, b_name)

func _spawn_single_bot(bot_team: Team, bot_name: String) -> CharacterBody3D:
	var scene = get_tree().current_scene
	if not scene:
		return null
	var bot_scene = load("res://scenes/enemies/soldier_bot.tscn") as PackedScene
	if not bot_scene:
		return null
	var bot = bot_scene.instantiate() as CharacterBody3D
	bot.name = bot_name
	bot.team = int(bot_team)

	var is_alpha = (bot_team == Team.ALPHA)
	var sp_name = "Spawn_Alpha" if is_alpha else "Spawn_Bravo"
	var sp = scene.find_child(sp_name, true, false) as Node3D
	if sp:
		var offset = Vector3(randf_range(-3.5, 3.5), 0.2, randf_range(-3.5, 3.5))
		bot.global_position = sp.global_position + offset
		bot.global_rotation = sp.global_rotation
	else:
		bot.global_position = Vector3(0, 0.5, -20.0 if is_alpha else 20.0)

	bot.enemy_died.connect(func(b): _on_bot_killed_respawn(b, bot_team, bot_name))
	scene.add_child(bot)
	return bot

func _on_bot_killed_respawn(_dead_bot: Node3D, bot_team: Team, bot_name: String) -> void:
	await get_tree().create_timer(3.5).timeout
	if is_active and (game_mode == GameMode.WAGER_1V1 or game_mode == GameMode.TDM_6V6):
		var scene = get_tree().current_scene
		if scene and is_instance_valid(scene):
			if game_mode == GameMode.WAGER_1V1 and scene.get_node_or_null("Player_2"):
				return
			_spawn_single_bot(bot_team, bot_name)

func remove_placeholder_bot_for_player() -> void:
	var scene = get_tree().current_scene
	if scene:
		var bot = scene.get_node_or_null("Bot_Opponent_Bravo")
		if bot:
			bot.queue_free()
