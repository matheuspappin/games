# =============================================================================
# mp_hud.gd
# HUD Completo do NUKE — 1v1 Wager, 6v6 TDM e PvE Bot Arena
# Suporta Pote Dourado, Sudden Death, Near-Miss HP e Revanche Dobro ou Nada
# =============================================================================
class_name MPHud
extends CanvasLayer

@export var score_label      : Label
@export var status_label     : Label
@export var health_bar       : ProgressBar
@export var health_label     : Label
@export var ammo_label       : Label
@export var hitmarker_ctrl   : Control
@export var hitmarker_label  : Label
@export var connection_panel : PanelContainer
@export var winner_panel     : PanelContainer
@export var winner_title     : Label
@export var ip_input         : LineEdit

# Elementos dinâmicos do estilo AAA
var pot_label                : Label = null
var near_miss_label          : Label = null
var rematch_button           : Button = null
var sudden_death_banner      : Label = null
var rematch_countdown        : float = 10.0
var rematch_timer_active     : bool = false

# Feedback de Dano Visual e Sonoro AAA (Módulos 3, 4 e 6)
var blood_vignette_rect        : ColorRect = null
var blood_vignette_mat         : ShaderMaterial = null
var blood_flash_intensity      : float = 0.0
var blood_pulse_timer          : float = 0.0
var damage_wheel_control       : Control = null
var active_damage_indicators   : Array[Dictionary] = []
var heartbeat_audio            : AudioStreamPlayer = null

# Kill Feed & Death Screen (SUB-3)
var kill_feed_container      : VBoxContainer = null
var death_overlay            : Control = null
var death_title_label        : Label = null
var death_sub_label          : Label = null
var death_timer_label        : Label = null
var death_countdown          : float = 3.0
var spawn_shield_banner      : PanelContainer = null
var spawn_shield_label       : Label = null

# Gamificação: Popups de Medalhas & Kill Streaks (SUB-8)
var medal_popup_container    : Control = null
var medal_title_label        : Label = null
var medal_xp_label           : Label = null
var streak_banner_label      : Label = null
var streak_hud_label         : Label = null
var current_player_streak    : int = 0

# Placar Completo (Scoreboard TAB — Teams & K/D)
var scoreboard_panel         : PanelContainer = null
var scoreboard_title_label   : Label = null
var scoreboard_alpha_list    : VBoxContainer = null
var scoreboard_bravo_list    : VBoxContainer = null
var scoreboard_stats_cache   : Dictionary = {}

# Relatório Pós-Combate (AAR) Estilo Call of Duty
var aar_overlay              : PanelContainer = null
var aar_outcome_title        : Label = null
var aar_outcome_subtitle     : Label = null
var aar_score_banner         : Label = null
var aar_mvp_label            : Label = null
var aar_personal_stats_label : Label = null
var aar_rank_badge_label     : Label = null
var aar_xp_progress_bar      : ProgressBar = null
var aar_xp_detail_label      : Label = null
var aar_level_up_banner      : Label = null
var aar_alpha_list           : VBoxContainer = null
var aar_bravo_list           : VBoxContainer = null
var aar_auto_timer_label     : Label = null
var aar_auto_timer_progress  : ProgressBar = null
var aar_auto_timer           : float = 25.0
var aar_auto_timer_max       : float = 25.0
var aar_auto_timer_active    : bool = false
var aar_auto_timer_paused    : bool = false
var btn_play_again           : Button = null
var btn_return_lobby         : Button = null
var btn_main_menu            : Button = null
var btn_pause_timer          : Button = null

# Contagem Regressiva Pré-Partida (Estilo Call of Duty)
var countdown_panel          : PanelContainer = null
var countdown_header_label   : Label = null
var countdown_number_label   : Label = null
var countdown_sub_label      : Label = null
var countdown_audio_player   : AudioStreamPlayer = null
var _countdown_tick_wav      : AudioStreamWAV = null
var _countdown_go_wav        : AudioStreamWAV = null

# Sistema de Vantagens e High Alert BO6
var high_alert_left_rect     : ColorRect = null
var high_alert_right_rect    : ColorRect = null
var high_alert_back_rect     : ColorRect = null
var recon_wallhack_banner    : PanelContainer = null
var perks_hud_container      : PanelContainer = null
var perks_specialty_label    : Label = null
var perks_icons_label        : Label = null

var network_mgr : Node = null
var local_player: PlayerCharacter = null
var mode_mgr    : GameModeManager = null
var minimap_hud : Control = null
var choose_class_screen: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_dynamic_hud_elements()
	call_deferred("_check_initial_class_selection")
	
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.mode_manager:
		mode_mgr = gm.mode_manager
		mode_mgr.score_updated.connect(_on_mode_score_updated)
		mode_mgr.game_ended.connect(_on_mode_game_ended)
		mode_mgr.sudden_death_started.connect(_on_mode_sudden_death)
		mode_mgr.tokens_farmed_updated.connect(_on_tokens_updated)
		mode_mgr.kill_registered.connect(_on_mode_kill_registered)
		mode_mgr.multi_kill_achieved.connect(_on_multi_kill_achieved)
		mode_mgr.streak_achieved.connect(_on_streak_achieved)
		mode_mgr.medal_awarded.connect(_on_medal_awarded)
		mode_mgr.match_countdown_started.connect(_on_countdown_started)
		mode_mgr.match_countdown_tick.connect(_on_countdown_tick)
		mode_mgr.match_countdown_completed.connect(_on_countdown_completed)
		mode_mgr.assist_registered.connect(_on_mode_assist_registered)

		if mode_mgr.has_method("is_in_countdown") and mode_mgr.is_in_countdown():
			_on_countdown_started(mode_mgr.countdown_remaining)

	network_mgr = get_node_or_null("/root/NetworkManager")
	if not network_mgr:
		var parent_node = get_parent()
		if parent_node:
			network_mgr = parent_node.get_node_or_null("NetworkManager") as NetworkManager
			if not network_mgr:
				network_mgr = parent_node.find_child("NetworkManager", true, false) as NetworkManager
	if not network_mgr and get_tree().current_scene:
		network_mgr = get_tree().current_scene.find_child("NetworkManager", true, false) as NetworkManager

	if network_mgr:
		if not network_mgr.score_updated.is_connected(_on_score_updated):
			network_mgr.score_updated.connect(_on_score_updated)
		if not network_mgr.match_ended.is_connected(_on_match_ended):
			network_mgr.match_ended.connect(_on_match_ended)
		if not network_mgr.match_started.is_connected(_on_match_started):
			network_mgr.match_started.connect(_on_match_started)
		if not network_mgr.stats_updated.is_connected(_on_stats_updated):
			network_mgr.stats_updated.connect(_on_stats_updated)

	if connection_panel:
		var gm_active = gm and gm.is_match_active
		var is_bot_session = gm and (gm.play_mode == gm.PlayMode.BOTS)
		var is_class_screen_active = (choose_class_screen and choose_class_screen.is_open)
		if (gm_active or OS.has_feature("web") or is_bot_session) and not is_class_screen_active:
			connection_panel.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif connection_panel.visible or is_class_screen_active:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Configurar título e pote de acordo com o modo ativo
	if gm:
		var is_bot = (gm.play_mode == gm.PlayMode.BOTS)
		if is_bot:
			if pot_label:
				pot_label.visible = false
			if status_label:
				match gm.selected_game_mode:
					"6v6":
						var t_size = int((gm.bot_count + 1) / 2)
						var target_meta = network_mgr.target_kills if network_mgr else (50 if t_size >= 5 else (25 if t_size >= 3 else 10))
						if t_size > 1:
							status_label.text = "MATA-MATA EM EQUIPE (BOTS %dv%d) — META: %d KILLS" % [t_size, t_size, target_meta]
						else:
							status_label.text = "DUELO TÁTICO CONTRA BOT (1v1) — META: %d KILLS" % target_meta
					"1v1":
						var target_meta = network_mgr.target_kills if network_mgr else 10
						status_label.text = "DUELO TÁTICO CONTRA BOT (1v1) — META: %d KILLS" % target_meta
					"pve":
						status_label.text = "PVE BOT ARENA — SOBREVIVÊNCIA"
					_:
						status_label.text = "MODO DE TREINO TÁTICO"
			if score_label:
				score_label.text = "🛡️ ALPHA: 0   |   💣 BRAVO: 0"
		else:
			if mode_mgr and mode_mgr.current_pot > 0.0:
				if pot_label:
					pot_label.visible = true
					pot_label.text = "💰 POTE: $%.2f USDC (WAGER 1v1)" % mode_mgr.current_pot
			elif pot_label:
				pot_label.visible = false

	if hitmarker_ctrl:
		hitmarker_ctrl.modulate.a = 0.0

	if winner_panel:
		winner_panel.visible = false

func _create_dynamic_hud_elements() -> void:
	# 1. Pote de Dinheiro / Tokens no Topo Central (Apenas se aposta ativa)
	pot_label = Label.new()
	pot_label.name = "PotBannerLabel"
	pot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pot_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	pot_label.offset_top = 16
	pot_label.offset_bottom = 44
	pot_label.text = "💰 POTE: $20.00 USDC (WAGER 1v1)"
	pot_label.modulate = Color(1.0, 0.85, 0.2, 1.0)
	pot_label.add_theme_font_size_override("font_size", 18)
	pot_label.visible = false
	add_child(pot_label)

	# 2. Banner de Sudden Death
	sudden_death_banner = Label.new()
	sudden_death_banner.name = "SuddenDeathBanner"
	sudden_death_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sudden_death_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sudden_death_banner.offset_top = 60
	sudden_death_banner.text = "⚡ SUDDEN DEATH! PONTO DA VITÓRIA (9 x 9) ⚡"
	sudden_death_banner.modulate = Color(1.0, 0.2, 0.3, 1.0)
	sudden_death_banner.add_theme_font_size_override("font_size", 22)
	sudden_death_banner.visible = false
	add_child(sudden_death_banner)

	# 2.1 Banner de Escudo de Spawn (Invencibilidade de 3s estilo CoD)
	spawn_shield_banner = PanelContainer.new()
	spawn_shield_banner.name = "SpawnShieldBanner"
	spawn_shield_banner.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	spawn_shield_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	spawn_shield_banner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	spawn_shield_banner.offset_left = -160
	spawn_shield_banner.offset_right = 160
	spawn_shield_banner.offset_top = -175
	spawn_shield_banner.offset_bottom = -135

	var shield_style = StyleBoxFlat.new()
	shield_style.bg_color = Color(0.04, 0.12, 0.22, 0.85)
	shield_style.border_color = Color(0.18, 0.75, 1.0, 0.95)
	shield_style.set_border_width_all(2)
	shield_style.set_corner_radius_all(6)
	shield_style.content_margin_left = 14
	shield_style.content_margin_right = 14
	shield_style.content_margin_top = 6
	shield_style.content_margin_bottom = 6
	spawn_shield_banner.add_theme_stylebox_override("panel", shield_style)

	spawn_shield_label = Label.new()
	spawn_shield_label.name = "SpawnShieldLabel"
	spawn_shield_label.text = "🛡️ ESCUDO DE SPAWN: 3.0s"
	spawn_shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spawn_shield_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	spawn_shield_label.add_theme_font_size_override("font_size", 16)
	spawn_shield_label.modulate = Color(0.4, 0.9, 1.0, 1.0)
	spawn_shield_banner.add_child(spawn_shield_label)
	spawn_shield_banner.visible = false
	add_child(spawn_shield_banner)

	# 3. Componentes no Painel de Vencedor
	if winner_panel:
		var vbox = winner_panel.find_child("VBoxContainer", true, false)
		if not vbox:
			vbox = winner_panel.get_node_or_null("MarginContainer/VBoxContainer")
		if vbox:
			near_miss_label = Label.new()
			near_miss_label.name = "NearMissLabel"
			near_miss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			near_miss_label.text = "O INIMIGO SOBREVIVEU COM APENAS 6 DE HP!"
			near_miss_label.modulate = Color(1.0, 0.5, 0.1, 1.0)
			near_miss_label.visible = false
			vbox.add_child(near_miss_label)

			rematch_button = Button.new()
			rematch_button.name = "RematchButton"
			rematch_button.text = "⚔️ REVANCHE: DOBRO OU NADA ($40 USDC) [10s]"
			rematch_button.modulate = Color(0.1, 0.95, 1.0, 1.0)
			rematch_button.pressed.connect(_on_rematch_pressed)
			rematch_button.visible = false
			vbox.add_child(rematch_button)

	_setup_scoreboard_ui()
	_setup_kill_feed_ui()
	_setup_death_screen_ui()
	_setup_streak_medal_ui()
	_setup_match_end_aar_ui()
	_setup_damage_feedback_ui()
	_setup_pre_match_countdown_ui()
	_setup_bo6_perks_hud()

	# Mini-Mapa Tático no Canto Superior Esquerdo (Estilo Call of Duty)
	minimap_hud = find_child("MinimapHUD", true, false) as Control
	if not minimap_hud:
		var m_res = load("res://scenes/ui/minimap_hud.tscn")
		if m_res:
			minimap_hud = m_res.instantiate() as Control
			add_child(minimap_hud)

	# Tela de Seleção de Classe e Preparação Tática Estilo Call of Duty (MW3 / BO3)
	var ccs_script = load("res://scripts/ui/choose_class_screen.gd")
	if ccs_script:
		choose_class_screen = ccs_script.new()
		choose_class_screen.name = "ChooseClassScreen"
		add_child(choose_class_screen)

func _check_initial_class_selection() -> void:
	if choose_class_screen and not choose_class_screen.has_chosen_initial_class:
		choose_class_screen.open_screen(true)

func _process(delta: float) -> void:
	if not local_player:
		_find_local_player()

	# Decaimento do flash de sangue ao tomar dano (Módulo 4)
	if blood_flash_intensity > 0.0:
		blood_flash_intensity = max(0.0, blood_flash_intensity - delta * 3.2)
		if blood_vignette_mat:
			blood_vignette_mat.set_shader_parameter("flash_intensity", blood_flash_intensity)

	# Atualização de vida baixa (< 35%) com pulso e batimentos cardíacos CoD (Módulos 4 e 6)
	if local_player and local_player.health_component:
		var hp_ratio = local_player.health_component.get_health_ratio()
		if blood_vignette_mat:
			blood_vignette_mat.set_shader_parameter("health_ratio", hp_ratio)
		if hp_ratio < 0.35 and not local_player.is_dead:
			blood_pulse_timer += delta * 7.5
			var pulse = (sin(blood_pulse_timer) + 1.0) * 0.5
			if blood_vignette_mat:
				blood_vignette_mat.set_shader_parameter("pulse_intensity", pulse)
			if heartbeat_audio and not heartbeat_audio.playing:
				heartbeat_audio.play()
		else:
			if blood_vignette_mat:
				blood_vignette_mat.set_shader_parameter("pulse_intensity", 0.0)
			if heartbeat_audio and heartbeat_audio.playing:
				heartbeat_audio.stop()

	# Atualização do Escudo de Invencibilidade de Respawn (3s estilo CoD)
	if local_player and local_player.health_component and local_player.health_component.has_method("is_invulnerable"):
		if local_player.health_component.is_invulnerable() and not local_player.is_dead:
			var rem = local_player.health_component.invulnerable_timer
			if spawn_shield_banner:
				spawn_shield_banner.visible = true
				if spawn_shield_label:
					spawn_shield_label.text = "🛡️ ESCUDO DE SPAWN: %.1fs" % rem
		else:
			if spawn_shield_banner and spawn_shield_banner.visible:
				spawn_shield_banner.visible = false

	# Atualização e expiração dos arcos de dano 360 no Damage Wheel (Módulo 3)
	if active_damage_indicators.size() > 0:
		var i = active_damage_indicators.size() - 1
		while i >= 0:
			var ind = active_damage_indicators[i]
			ind.lifetime -= delta
			if ind.lifetime <= 0.0:
				active_damage_indicators.remove_at(i)
			i -= 1
		if damage_wheel_control:
			damage_wheel_control.queue_redraw()

	if death_overlay and death_overlay.visible:
		death_countdown -= delta
		if death_timer_label:
			death_timer_label.text = "RESPAWNANDO EM: %d..." % maxi(1, int(ceil(death_countdown)))

	if aar_auto_timer_active and aar_overlay and aar_overlay.visible and not aar_auto_timer_paused:
		aar_auto_timer -= delta
		if aar_auto_timer_label:
			aar_auto_timer_label.text = "⏱️ RETORNANDO AO LOBBY EM: %02ds..." % maxi(0, int(ceil(aar_auto_timer)))
		if aar_auto_timer_progress:
			aar_auto_timer_progress.value = clampf(aar_auto_timer / aar_auto_timer_max, 0.0, 1.0)
		if aar_auto_timer <= 0.0:
			aar_auto_timer_active = false
			_on_return_to_lobby_pressed()

	if rematch_timer_active and rematch_button:
		rematch_countdown -= delta
		if rematch_countdown > 0:
			rematch_button.text = "⚔️ REVANCHE: DOBRO OU NADA [00:%02d]" % int(rematch_countdown)
		else:
			rematch_timer_active = false
			rematch_button.disabled = true
			rematch_button.text = "TEMPO DE REVANCHE EXPIRADO"

func _find_local_player() -> void:
	if not get_tree().current_scene:
		return

	if not mode_mgr:
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.mode_manager:
			mode_mgr = gm.mode_manager
			if not mode_mgr.score_updated.is_connected(_on_mode_score_updated):
				mode_mgr.score_updated.connect(_on_mode_score_updated)
			if not mode_mgr.game_ended.is_connected(_on_mode_game_ended):
				mode_mgr.game_ended.connect(_on_mode_game_ended)
			if not mode_mgr.sudden_death_started.is_connected(_on_mode_sudden_death):
				mode_mgr.sudden_death_started.connect(_on_mode_sudden_death)
			if not mode_mgr.tokens_farmed_updated.is_connected(_on_tokens_updated):
				mode_mgr.tokens_farmed_updated.connect(_on_tokens_updated)
			if not mode_mgr.kill_registered.is_connected(_on_mode_kill_registered):
				mode_mgr.kill_registered.connect(_on_mode_kill_registered)
			if not mode_mgr.multi_kill_achieved.is_connected(_on_multi_kill_achieved):
				mode_mgr.multi_kill_achieved.connect(_on_multi_kill_achieved)
			if not mode_mgr.streak_achieved.is_connected(_on_streak_achieved):
				mode_mgr.streak_achieved.connect(_on_streak_achieved)
			if not mode_mgr.medal_awarded.is_connected(_on_medal_awarded):
				mode_mgr.medal_awarded.connect(_on_medal_awarded)
			if not mode_mgr.match_countdown_started.is_connected(_on_countdown_started):
				mode_mgr.match_countdown_started.connect(_on_countdown_started)
			if not mode_mgr.match_countdown_tick.is_connected(_on_countdown_tick):
				mode_mgr.match_countdown_tick.connect(_on_countdown_tick)
			if not mode_mgr.match_countdown_completed.is_connected(_on_countdown_completed):
				mode_mgr.match_countdown_completed.connect(_on_countdown_completed)
			if not mode_mgr.assist_registered.is_connected(_on_mode_assist_registered):
				mode_mgr.assist_registered.connect(_on_mode_assist_registered)

	var my_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var node = get_tree().current_scene.get_node_or_null("Player_" + str(my_id)) as PlayerCharacter
	if not node:
		node = get_tree().current_scene.find_child("Player", true, false) as PlayerCharacter

	if node:
		local_player = node
		if minimap_hud:
			minimap_hud.local_player = local_player
		if local_player.health_component:
			if not local_player.health_component.health_changed.is_connected(_on_health_changed):
				local_player.health_component.health_changed.connect(_on_health_changed)
			if not local_player.health_component.damage_received.is_connected(_on_damage_received):
				local_player.health_component.damage_received.connect(_on_damage_received)
			_on_health_changed(local_player.health_component.current_health, local_player.health_component.max_health)
		if local_player.weapon_manager:
			local_player.weapon_manager.ammo_changed.connect(_on_ammo_changed)
			local_player.weapon_manager.hit_confirmed.connect(_on_hit_confirmed)
			_on_ammo_changed(local_player.weapon_manager.current_ammo, local_player.weapon_manager.reserve_ammo)
		if local_player.perk_manager:
			if not local_player.perk_manager.perks_updated.is_connected(_on_perks_updated):
				local_player.perk_manager.perks_updated.connect(_on_perks_updated)
			_on_perks_updated(
				local_player.perk_manager.active_perks,
				local_player.perk_manager.active_specialty,
				local_player.perk_manager.is_synergy_active
			)

func _on_mode_score_updated(alpha: int, bravo: int) -> void:
	if score_label:
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.selected_game_mode == "1v1":
			score_label.text = "VOCÊ: %d   |   OPONENTE: %d" % [alpha, bravo]
		else:
			score_label.text = "🛡️ ALPHA: %d   |   💣 BRAVO: %d" % [alpha, bravo]

func _on_tokens_updated(total: int) -> void:
	if pot_label:
		pot_label.text = "🪙 TOKENS FARMADOS: %d $NUKE" % total
		pot_label.modulate = Color(0.2, 1.0, 0.5, 1.0)

func _on_mode_sudden_death() -> void:
	if sudden_death_banner:
		sudden_death_banner.visible = true
		var tween = create_tween().set_loops(10)
		tween.tween_property(sudden_death_banner, "modulate:a", 0.3, 0.4)
		tween.tween_property(sudden_death_banner, "modulate:a", 1.0, 0.4)

func _on_mode_game_ended(winner: int, details: Dictionary) -> void:
	show_match_end_aar(winner, details)

func _on_rematch_pressed() -> void:
	rematch_timer_active = false
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.restart_match_rematch(20.0)
	if winner_panel:
		winner_panel.visible = false
	if sudden_death_banner:
		sudden_death_banner.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	# Se a tela final AAR CoD estiver aberta, tratar atalhos de navegação
	if aar_overlay and aar_overlay.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_TAB:
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_ESCAPE:
				_on_return_to_lobby_pressed()
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
				_on_play_again_pressed()
				get_viewport().set_input_as_handled()
				return

	# Tecla TAB para Placar Completo em partida ativa (Teams e K/D)
	if event is InputEventKey and event.keycode == KEY_TAB and not event.echo:
		if scoreboard_panel:
			scoreboard_panel.visible = event.pressed
			if event.pressed:
				_refresh_scoreboard()
		get_viewport().set_input_as_handled()
		return

	if connection_panel and connection_panel.visible:
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
			connection_panel.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_H:
				_on_host_pressed()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_J:
				_on_join_pressed()
				get_viewport().set_input_as_handled()

func _on_host_pressed() -> void:
	if connection_panel:
		connection_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if network_mgr:
		network_mgr.start_host()
	if status_label:
		status_label.text = "HOST (Partida Aberta)"

func _on_join_pressed() -> void:
	if connection_panel:
		connection_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if network_mgr:
		var ip = ip_input.text.strip_edges() if ip_input and ip_input.text != "" else "127.0.0.1"
		network_mgr.join_game(ip)
	if status_label:
		status_label.text = "Conectando ao Host..."

func _on_match_started() -> void:
	if connection_panel:
		connection_panel.visible = false
	if not (choose_class_screen and choose_class_screen.is_open):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if status_label:
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.mode_manager:
			match gm.mode_manager.game_mode:
				GameModeManager.GameMode.WAGER_1V1:
					status_label.text = "1v1 WAGER MATCH — META: 10 KILLS"
				GameModeManager.GameMode.TDM_6V6:
					var target = network_mgr.target_kills if network_mgr else 50
					var t_size = int((gm.bot_count + 1) / 2) if gm else 6
					if gm and gm.play_mode == gm.PlayMode.BOTS:
						status_label.text = "MATA-MATA EM EQUIPE (BOTS %dv%d) — META: %d KILLS" % [t_size, t_size, target]
					else:
						status_label.text = "6v6 TDM COMPETITIVO — META: %d KILLS" % target
				GameModeManager.GameMode.PVE_BOTS_ARENA:
					status_label.text = "PVE BOT ARENA — SOBREVIVÊNCIA"
				_:
					var target = network_mgr.target_kills if network_mgr else 10
					status_label.text = "PARTIDA EM ANDAMENTO (Meta: %d Kills)" % target
		else:
			var target = network_mgr.target_kills if network_mgr else 10
			status_label.text = "PARTIDA EM ANDAMENTO (Meta: %d Kills)" % target

func _on_score_updated(alpha_pts: int, bravo_pts: int) -> void:
	if score_label:
		score_label.text = "🛡️ ALPHA: %d   |   💣 BRAVO: %d" % [alpha_pts, bravo_pts]

func _on_health_changed(curr: int, max_hp: int) -> void:
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = curr
	if health_label:
		health_label.text = "HP: %d" % curr
	if blood_vignette_mat:
		blood_vignette_mat.set_shader_parameter("health_ratio", float(curr) / float(max(1, max_hp)))
	if curr >= max_hp:
		if heartbeat_audio and heartbeat_audio.playing:
			heartbeat_audio.stop()
		if blood_vignette_mat:
			blood_vignette_mat.set_shader_parameter("pulse_intensity", 0.0)
			blood_vignette_mat.set_shader_parameter("health_ratio", 1.0)

func _on_ammo_changed(curr: int, reserve: int) -> void:
	if ammo_label:
		ammo_label.text = "%02d / %d" % [curr, reserve]

func _on_hit_confirmed(is_headshot: bool, _hit_pos: Vector3) -> void:
	if not hitmarker_ctrl:
		return
	hitmarker_ctrl.modulate = Color(1.0, 0.2, 0.2, 1.0) if is_headshot else Color(1.0, 1.0, 1.0, 1.0)
	if hitmarker_label:
		hitmarker_label.text = "✦" if is_headshot else "✕"

	var tween = create_tween()
	tween.tween_property(hitmarker_ctrl, "modulate:a", 1.0, 0.05)
	tween.tween_property(hitmarker_ctrl, "modulate:a", 0.0, 0.25)

func _on_match_ended(winner_team: int) -> void:
	show_match_end_aar(winner_team, {})

func _on_restart_pressed() -> void:
	_on_play_again_pressed()

func _on_stats_updated(stats: Dictionary) -> void:
	scoreboard_stats_cache = stats
	if scoreboard_panel and scoreboard_panel.visible:
		_refresh_scoreboard()
	if aar_overlay and aar_overlay.visible:
		var my_peer_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
		_render_team_lists_to_containers(aar_alpha_list, aar_bravo_list, _get_consolidated_stats(), my_peer_id)

## Configura e instancia a interface visual do Placar Militar (Scoreboard TAB)
func _setup_scoreboard_ui() -> void:
	scoreboard_panel = PanelContainer.new()
	scoreboard_panel.name = "ScoreboardPanel"
	scoreboard_panel.visible = false
	scoreboard_panel.set_anchors_preset(Control.PRESET_CENTER)
	scoreboard_panel.custom_minimum_size = Vector2(880, 500)
	scoreboard_panel.offset_left = -440
	scoreboard_panel.offset_top = -250
	scoreboard_panel.offset_right = 440
	scoreboard_panel.offset_bottom = 250
	scoreboard_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	scoreboard_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.06, 0.09, 0.95)
	panel_style.border_color = Color(0.35, 0.45, 0.58, 0.85)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	scoreboard_panel.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	scoreboard_panel.add_child(margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(root_vbox)

	# 1. Cabeçalho Geral
	var header_vbox = VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 2)
	root_vbox.add_child(header_vbox)

	var main_title = Label.new()
	main_title.text = "📊 RELATÓRIO DE COMBATE MULTIPLAYER (TAB)"
	main_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_title.add_theme_font_size_override("font_size", 18)
	main_title.modulate = Color(1.0, 0.85, 0.25)
	header_vbox.add_child(main_title)

	scoreboard_title_label = Label.new()
	scoreboard_title_label.text = "🛡️ ALPHA: 0  |  META: 50 KILLS  |  💣 BRAVO: 0"
	scoreboard_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scoreboard_title_label.add_theme_font_size_override("font_size", 14)
	scoreboard_title_label.modulate = Color(0.85, 0.85, 0.85)
	header_vbox.add_child(scoreboard_title_label)

	var sep = HSeparator.new()
	root_vbox.add_child(sep)

	# 2. Painel das Equipes (Duas Colunas lado a lado)
	var teams_hbox = HBoxContainer.new()
	teams_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	teams_hbox.add_theme_constant_override("separation", 16)
	root_vbox.add_child(teams_hbox)

	# Time Alpha (Esquerda - Azul / CT)
	var alpha_col = _create_team_column("🛡️ TIME ALPHA (CONTRA-TERRORISTAS)", Color(0.18, 0.35, 0.75, 0.9), Color(0.65, 0.82, 1.0))
	teams_hbox.add_child(alpha_col["container"])
	scoreboard_alpha_list = alpha_col["list"]

	var vsep = VSeparator.new()
	teams_hbox.add_child(vsep)

	# Time Bravo (Direita - Vermelho / T)
	var bravo_col = _create_team_column("💣 TIME BRAVO (TERRORISTAS)", Color(0.75, 0.22, 0.18, 0.9), Color(1.0, 0.65, 0.6))
	teams_hbox.add_child(bravo_col["container"])
	scoreboard_bravo_list = bravo_col["list"]

	# 3. Rodapé com dica de atalho
	var hint_label = Label.new()
	hint_label.text = "[ SEGURE A TECLA TAB PARA VISUALIZAR | SOLTE PARA FECHAR ]"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.modulate = Color(0.6, 0.65, 0.75, 0.7)
	root_vbox.add_child(hint_label)

	add_child(scoreboard_panel)

func _create_team_column(team_title: String, header_bg: Color, text_color: Color) -> Dictionary:
	var col_vbox = VBoxContainer.new()
	col_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_vbox.add_theme_constant_override("separation", 6)

	var banner_panel = PanelContainer.new()
	var b_style = StyleBoxFlat.new()
	b_style.bg_color = header_bg
	b_style.set_corner_radius_all(4)
	b_style.set_content_margin_all(6)
	banner_panel.add_theme_stylebox_override("panel", b_style)

	var b_label = Label.new()
	b_label.text = team_title
	b_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b_label.add_theme_font_size_override("font_size", 13)
	b_label.modulate = Color.WHITE
	banner_panel.add_child(b_label)
	col_vbox.add_child(banner_panel)

	# Cabeçalho das Colunas
	var cols_header = HBoxContainer.new()
	cols_header.custom_minimum_size.y = 22

	var lbl_name = Label.new()
	lbl_name.text = "JOGADOR"
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_name.size_flags_stretch_ratio = 2.4
	lbl_name.add_theme_font_size_override("font_size", 11)
	lbl_name.modulate = text_color
	cols_header.add_child(lbl_name)

	var lbl_k = Label.new()
	lbl_k.text = "K"
	lbl_k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_k.size_flags_stretch_ratio = 0.8
	lbl_k.add_theme_font_size_override("font_size", 11)
	lbl_k.modulate = text_color
	cols_header.add_child(lbl_k)

	var lbl_d = Label.new()
	lbl_d.text = "D"
	lbl_d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_d.size_flags_stretch_ratio = 0.8
	lbl_d.add_theme_font_size_override("font_size", 11)
	lbl_d.modulate = text_color
	cols_header.add_child(lbl_d)

	var lbl_a = Label.new()
	lbl_a.text = "A"
	lbl_a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_a.size_flags_stretch_ratio = 0.8
	lbl_a.add_theme_font_size_override("font_size", 11)
	lbl_a.modulate = text_color
	cols_header.add_child(lbl_a)

	var lbl_kd = Label.new()
	lbl_kd.text = "K/D"
	lbl_kd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_kd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_kd.size_flags_stretch_ratio = 1.0
	lbl_kd.add_theme_font_size_override("font_size", 11)
	lbl_kd.modulate = text_color
	cols_header.add_child(lbl_kd)

	var lbl_pts = Label.new()
	lbl_pts.text = "PTS"
	lbl_pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_pts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_pts.size_flags_stretch_ratio = 1.0
	lbl_pts.add_theme_font_size_override("font_size", 11)
	lbl_pts.modulate = text_color
	cols_header.add_child(lbl_pts)

	col_vbox.add_child(cols_header)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col_vbox.add_child(scroll)

	var list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(list_vbox)

	return { "container": col_vbox, "list": list_vbox }

func _refresh_scoreboard() -> void:
	if not scoreboard_alpha_list or not scoreboard_bravo_list:
		return

	var stats = _get_consolidated_stats()
	var my_peer_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1

	if scoreboard_title_label:
		var target = network_mgr.target_kills if network_mgr else 10
		var score_a = network_mgr.score_alpha if network_mgr else 0
		var score_b = network_mgr.score_bravo if network_mgr else 0
		scoreboard_title_label.text = "🛡️ ALPHA: %d  |  META: %d KILLS  |  💣 BRAVO: %d" % [score_a, target, score_b]

	_render_team_lists_to_containers(scoreboard_alpha_list, scoreboard_bravo_list, stats, my_peer_id)

## Retorna o dicionário unificado e completo de estatísticas de combate de todos os participantes
func _get_consolidated_stats() -> Dictionary:
	var stats: Dictionary = {}
	if network_mgr and not network_mgr.player_stats.is_empty():
		stats = network_mgr.player_stats.duplicate(true)
	elif not scoreboard_stats_cache.is_empty():
		stats = scoreboard_stats_cache.duplicate(true)

	var my_peer_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var gm_ref = get_node_or_null("/root/GameManager")
	var p_name = gm_ref.local_player_name if (gm_ref and not gm_ref.local_player_name.is_empty()) else "Operador_Alpha"

	# Garante que o jogador local SEMPRE esteja no dicionário de estatísticas
	if not stats.has(my_peer_id):
		stats[my_peer_id] = {
			"peer_id": my_peer_id,
			"name": p_name,
			"team": gm_ref.local_player_team if (gm_ref and "local_player_team" in gm_ref) else 0,
			"kills": gm_ref.player_stats.kills if gm_ref else 0,
			"deaths": gm_ref.player_stats.deaths if gm_ref else 0,
			"assists": gm_ref.player_stats.assists if gm_ref else 0,
			"score": gm_ref.player_stats.score if gm_ref else 0
		}
	else:
		var cur_name = str(stats[my_peer_id].get("name", ""))
		if cur_name == "Host (Alpha)" or cur_name.begins_with("Jogador ") or cur_name.is_empty():
			stats[my_peer_id]["name"] = p_name

	if gm_ref and stats.has(my_peer_id):
		if gm_ref.player_stats.kills > stats[my_peer_id].get("kills", 0):
			stats[my_peer_id]["kills"] = gm_ref.player_stats.kills
		if gm_ref.player_stats.deaths > stats[my_peer_id].get("deaths", 0):
			stats[my_peer_id]["deaths"] = gm_ref.player_stats.deaths
		if gm_ref.player_stats.assists > stats[my_peer_id].get("assists", 0):
			stats[my_peer_id]["assists"] = gm_ref.player_stats.assists
		if gm_ref.player_stats.score > stats[my_peer_id].get("score", 0):
			stats[my_peer_id]["score"] = gm_ref.player_stats.score

	return stats

## Renderiza jogadores nos contêineres de cada equipe e calcula MVP / dados do jogador local
func _render_team_lists_to_containers(alpha_container: VBoxContainer, bravo_container: VBoxContainer, stats: Dictionary, my_peer_id: int) -> Dictionary:
	if not alpha_container or not bravo_container:
		return {}

	# Limpa dados anteriores
	for child in alpha_container.get_children():
		child.queue_free()
	for child in bravo_container.get_children():
		child.queue_free()

	var alpha_players: Array = []
	var bravo_players: Array = []

	for peer_id in stats.keys():
		var p = stats[peer_id].duplicate()
		p["peer_id"] = peer_id
		var is_alpha = (int(p.get("team", 0)) == 0)
		if is_alpha:
			alpha_players.append(p)
		else:
			bravo_players.append(p)

	# Ordena cada equipe por pontuação decrescente (PTS / Kills)
	var sort_func = func(a, b):
		var sa = int(a.get("score", 0))
		var sb = int(b.get("score", 0))
		if sa != sb:
			return sa > sb
		return int(a.get("kills", 0)) > int(b.get("kills", 0))

	alpha_players.sort_custom(sort_func)
	bravo_players.sort_custom(sort_func)

	var local_player_data = null
	var mvp_data = null
	var all_players = alpha_players + bravo_players

	for p in all_players:
		if mvp_data == null:
			mvp_data = p
		else:
			var sa = int(p.get("score", 0))
			var sm = int(mvp_data.get("score", 0))
			if sa > sm or (sa == sm and int(p.get("kills", 0)) > int(mvp_data.get("kills", 0))):
				mvp_data = p

	for p in alpha_players:
		var is_me = (int(p["peer_id"]) == my_peer_id)
		if is_me:
			local_player_data = p
		var row = _create_player_row(p, is_me)
		alpha_container.add_child(row)

	for p in bravo_players:
		var is_me = (int(p["peer_id"]) == my_peer_id)
		if is_me:
			local_player_data = p
		var row = _create_player_row(p, is_me)
		bravo_container.add_child(row)

	return {
		"mvp": mvp_data,
		"local_player": local_player_data,
		"alpha_count": alpha_players.size(),
		"bravo_count": bravo_players.size()
	}

func _create_player_row(p: Dictionary, is_me: bool) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.custom_minimum_size.y = 26

	var p_name = str(p.get("name", "Jogador"))
	if is_me and not p_name.ends_with("(VOCÊ)"):
		p_name += " (VOCÊ)"

	var kills = int(p.get("kills", 0))
	var deaths = int(p.get("deaths", 0))
	var pts = int(p.get("score", kills * 100))

	var kd_str = "%.2f" % (float(kills) / float(deaths)) if deaths > 0 else (str(kills) + ".00")
	var kd_val = float(kills) / float(deaths) if deaths > 0 else float(kills)

	# 1. Nome do Jogador
	var lbl_name = Label.new()
	lbl_name.text = p_name
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_name.size_flags_stretch_ratio = 2.4
	if is_me:
		lbl_name.modulate = Color(1.0, 0.85, 0.2)  # Dourado para destacar o jogador
	hbox.add_child(lbl_name)

	# 2. Kills (K)
	var lbl_k = Label.new()
	lbl_k.text = str(kills)
	lbl_k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_k.size_flags_stretch_ratio = 0.8
	hbox.add_child(lbl_k)

	# 3. Deaths (D)
	var lbl_d = Label.new()
	lbl_d.text = str(deaths)
	lbl_d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_d.size_flags_stretch_ratio = 0.8
	hbox.add_child(lbl_d)

	# 4. Assists (A)
	var assists = int(p.get("assists", 0))
	var gm_ref = get_node_or_null("/root/GameManager")
	if is_me and gm_ref:
		assists = gm_ref.player_stats.get("assists", assists)
	var lbl_a = Label.new()
	lbl_a.text = str(assists)
	lbl_a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_a.size_flags_stretch_ratio = 0.8
	hbox.add_child(lbl_a)

	# 5. K/D Ratio
	var lbl_kd = Label.new()
	lbl_kd.text = kd_str
	lbl_kd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_kd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_kd.size_flags_stretch_ratio = 1.0
	lbl_kd.modulate = Color(0.3, 1.0, 0.4) if kd_val >= 1.0 else Color(1.0, 0.4, 0.4)
	hbox.add_child(lbl_kd)

	# 5. Pontos (PTS)
	var lbl_pts = Label.new()
	lbl_pts.text = str(pts)
	lbl_pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_pts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_pts.size_flags_stretch_ratio = 1.0
	hbox.add_child(lbl_pts)

	return hbox

# ── KILL FEED MODERNO ESTILO COD (SUB-3) ─────────────────────────────────────
func _setup_kill_feed_ui() -> void:
	kill_feed_container = VBoxContainer.new()
	kill_feed_container.name = "KillFeedContainer"
	kill_feed_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	kill_feed_container.offset_left = -380
	kill_feed_container.offset_top = 40
	kill_feed_container.offset_right = -16
	kill_feed_container.offset_bottom = 260
	kill_feed_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kill_feed_container.add_theme_constant_override("separation", 6)
	add_child(kill_feed_container)

func add_kill_feed_entry(killer_name: String, victim_name: String, weapon_name: String = "ACR 6.8", is_player_kill: bool = false, is_player_death: bool = false) -> void:
	if not kill_feed_container:
		return

	# Manter no máximo 5 notificações no feed
	while kill_feed_container.get_child_count() >= 5:
		var oldest = kill_feed_container.get_child(0)
		kill_feed_container.remove_child(oldest)
		oldest.queue_free()

	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	if is_player_kill:
		style.bg_color = Color(0.08, 0.22, 0.12, 0.88)
		style.border_color = Color(0.3, 0.95, 0.45, 0.9)
	elif is_player_death:
		style.bg_color = Color(0.28, 0.06, 0.06, 0.88)
		style.border_color = Color(1.0, 0.25, 0.25, 0.9)
	else:
		style.bg_color = Color(0.05, 0.07, 0.10, 0.75)
		style.border_color = Color(0.25, 0.35, 0.45, 0.5)

	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var lbl_killer = Label.new()
	lbl_killer.text = killer_name
	lbl_killer.add_theme_font_size_override("font_size", 13)
	lbl_killer.modulate = Color(0.3, 0.95, 0.45) if is_player_kill else (Color(1.0, 0.4, 0.3) if is_player_death else Color(0.85, 0.85, 0.85))
	hbox.add_child(lbl_killer)

	var lbl_weapon = Label.new()
	lbl_weapon.text = "︻╦デ═— " + weapon_name
	lbl_weapon.add_theme_font_size_override("font_size", 11)
	lbl_weapon.modulate = Color(0.7, 0.75, 0.8)
	hbox.add_child(lbl_weapon)

	var lbl_victim = Label.new()
	lbl_victim.text = victim_name
	lbl_victim.add_theme_font_size_override("font_size", 13)
	lbl_victim.modulate = Color(1.0, 0.3, 0.3) if is_player_death else (Color(1.0, 0.85, 0.2) if is_player_kill else Color(0.7, 0.7, 0.7))
	hbox.add_child(lbl_victim)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.add_child(hbox)
	card.add_child(margin)

	kill_feed_container.add_child(card)

	# Animação suave de fade out após 3.5s
	var tween = create_tween()
	tween.tween_interval(3.5)
	tween.tween_property(card, "modulate:a", 0.0, 0.5)
	tween.tween_callback(card.queue_free)

# ── TELA DE MORTE ESTILO COD (SUB-3) ─────────────────────────────────────────
func _setup_death_screen_ui() -> void:
	death_overlay = Control.new()
	death_overlay.name = "DeathScreenOverlay"
	death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_overlay.visible = false
	death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Vinheta avermelhada
	var vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.35, 0.02, 0.02, 0.45)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_overlay.add_child(vignette)

	# Banner central
	var center_panel = PanelContainer.new()
	center_panel.set_anchors_preset(Control.PRESET_CENTER)
	center_panel.offset_left = -280
	center_panel.offset_top = -90
	center_panel.offset_right = 280
	center_panel.offset_bottom = 90
	center_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.06, 0.92)
	style.border_color = Color(0.9, 0.15, 0.15, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	center_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)

	death_title_label = Label.new()
	death_title_label.text = "💀 VOCÊ FOI ELIMINADO 💀"
	death_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_title_label.add_theme_font_size_override("font_size", 24)
	death_title_label.modulate = Color(1.0, 0.25, 0.25)
	vbox.add_child(death_title_label)

	death_sub_label = Label.new()
	death_sub_label.text = "Eliminado por Inimigo com ACR 6.8"
	death_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_sub_label.add_theme_font_size_override("font_size", 16)
	death_sub_label.modulate = Color(0.9, 0.9, 0.9)
	vbox.add_child(death_sub_label)

	death_timer_label = Label.new()
	death_timer_label.text = "RESPAWNANDO EM: 3s..."
	death_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_timer_label.add_theme_font_size_override("font_size", 14)
	death_timer_label.modulate = Color(1.0, 0.85, 0.2)
	vbox.add_child(death_timer_label)

	var change_class_hint = Label.new()
	change_class_hint.text = "⚡ Pressione [F1] para trocar de classe e armamento"
	change_class_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	change_class_hint.add_theme_font_size_override("font_size", 12)
	change_class_hint.modulate = Color(0.3, 0.85, 1.0, 0.95)
	vbox.add_child(change_class_hint)

	center_panel.add_child(vbox)
	death_overlay.add_child(center_panel)
	add_child(death_overlay)

func _setup_damage_feedback_ui() -> void:
	# 1. Overlay de Vinheta de Sangue Shader (Módulo 4)
	var shader = load("res://shaders/blood_vignette.gdshader") as Shader
	if shader:
		blood_vignette_mat = ShaderMaterial.new()
		blood_vignette_mat.shader = shader
		blood_vignette_mat.set_shader_parameter("flash_intensity", 0.0)
		blood_vignette_mat.set_shader_parameter("health_ratio", 1.0)
		blood_vignette_mat.set_shader_parameter("pulse_intensity", 0.0)

		blood_vignette_rect = ColorRect.new()
		blood_vignette_rect.name = "BloodVignetteOverlay"
		blood_vignette_rect.material = blood_vignette_mat
		blood_vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		blood_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(blood_vignette_rect)
		move_child(blood_vignette_rect, 0)

	# 2. Damage Wheel 360 (Indicadores Direcionais em Arco ao redor da mira - Módulo 3)
	damage_wheel_control = Control.new()
	damage_wheel_control.name = "DamageWheelControl"
	damage_wheel_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_wheel_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_wheel_control.draw.connect(_on_damage_wheel_draw)
	add_child(damage_wheel_control)
	move_child(damage_wheel_control, 1)

	# 3. Audio de Batimento Cardíaco (Loop de Vida Crítica - Módulo 6)
	heartbeat_audio = AudioStreamPlayer.new()
	heartbeat_audio.name = "HeartbeatAudio"
	heartbeat_audio.bus = "SFX"
	if ResourceLoader.exists("res://assets/audio/foley/heartbeat.wav"):
		heartbeat_audio.stream = load("res://assets/audio/foley/heartbeat.wav") as AudioStream
	heartbeat_audio.volume_db = -3.0
	add_child(heartbeat_audio)

func _on_damage_received(amount: int, direction: Vector3, attacker: Node) -> void:
	# 1. Flash de vinheta de sangue (Módulo 4)
	blood_flash_intensity = clampf(blood_flash_intensity + float(amount) / 38.0, 0.45, 1.0)
	if blood_vignette_mat:
		blood_vignette_mat.set_shader_parameter("flash_intensity", blood_flash_intensity)

	# 2. Registrar arco no Damage Wheel 360 (Módulo 3)
	var attacker_pos = Vector3.ZERO
	if attacker and is_instance_valid(attacker) and attacker is Node3D:
		attacker_pos = attacker.global_position

	var ind = {
		"lifetime": 1.7,
		"max_lifetime": 1.7,
		"pos": attacker_pos,
		"dir": direction
	}
	active_damage_indicators.append(ind)
	if damage_wheel_control:
		damage_wheel_control.queue_redraw()

func _on_damage_wheel_draw() -> void:
	if not local_player:
		return
	var cam: Camera3D = null
	if "CAMERA" in local_player and local_player.CAMERA:
		cam = local_player.CAMERA
	elif local_player.has_node("Head/Camera"):
		cam = local_player.get_node("Head/Camera") as Camera3D
	elif local_player.find_child("Camera3D", true, false):
		cam = local_player.find_child("Camera3D", true, false) as Camera3D

	if not cam:
		return

	var vp_size = get_viewport().get_visible_rect().size
	var screen_center = vp_size * 0.5
	var base_radius = min(screen_center.x, screen_center.y) * 0.35

	var cam_fwd = -cam.global_transform.basis.z
	cam_fwd.y = 0.0
	if cam_fwd.length_squared() < 0.001:
		return
	cam_fwd = cam_fwd.normalized()

	var cam_right = cam.global_transform.basis.x
	cam_right.y = 0.0
	if cam_right.length_squared() < 0.001:
		return
	cam_right = cam_right.normalized()

	for ind in active_damage_indicators:
		var dir = Vector3.ZERO
		if ind.get("pos", Vector3.ZERO) != Vector3.ZERO:
			dir = (ind.pos - cam.global_position)
		elif ind.get("dir", Vector3.ZERO) != Vector3.ZERO:
			dir = -ind.dir
		dir.y = 0.0
		if dir.length_squared() < 0.001:
			continue
		dir = dir.normalized()

		var lx = cam_right.dot(dir)
		var lz = cam_fwd.dot(dir)
		var angle = atan2(lx, lz)

		var phi = -PI * 0.5 + angle
		var alpha = clampf(ind.lifetime / ind.max_lifetime, 0.0, 1.0)
		var col = Color(1.0, 0.15, 0.15, alpha * 0.95)
		var glow_col = Color(0.85, 0.0, 0.0, alpha * 0.40)

		var arc_span = deg_to_rad(36.0)
		damage_wheel_control.draw_arc(screen_center, base_radius, phi - arc_span * 0.55, phi + arc_span * 0.55, 14, glow_col, 8.0, true)
		damage_wheel_control.draw_arc(screen_center, base_radius, phi - arc_span * 0.5, phi + arc_span * 0.5, 14, col, 3.5, true)

		var tip = screen_center + Vector2(cos(phi), sin(phi)) * (base_radius + 15.0)
		var left_pt = screen_center + Vector2(cos(phi - 0.11), sin(phi - 0.11)) * (base_radius + 3.0)
		var right_pt = screen_center + Vector2(cos(phi + 0.11), sin(phi + 0.11)) * (base_radius + 3.0)
		damage_wheel_control.draw_colored_polygon(PackedVector2Array([tip, right_pt, left_pt]), col)

func show_death_message(killer_name: String, weapon_name: String = "ACR 6.8", timer_sec: float = 3.0) -> void:
	death_countdown = timer_sec
	current_player_streak = 0
	_update_streak_hud()

	if heartbeat_audio and heartbeat_audio.playing:
		heartbeat_audio.stop()
	active_damage_indicators.clear()
	if damage_wheel_control:
		damage_wheel_control.queue_redraw()
	blood_flash_intensity = 0.0
	if blood_vignette_mat:
		blood_vignette_mat.set_shader_parameter("flash_intensity", 0.0)
		blood_vignette_mat.set_shader_parameter("pulse_intensity", 0.0)

	if death_sub_label:
		death_sub_label.text = "Eliminado por: %s  |  Arma: %s" % [killer_name, weapon_name]
	if death_timer_label:
		death_timer_label.text = "RESPAWNANDO EM: %d..." % int(ceil(death_countdown))
	if death_overlay:
		death_overlay.visible = true
		death_overlay.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(death_overlay, "modulate:a", 1.0, 0.25)

	# Registrar no Kill Feed
	add_kill_feed_entry(killer_name, "Você", weapon_name, false, true)

func hide_death_message() -> void:
	if heartbeat_audio and heartbeat_audio.playing:
		heartbeat_audio.stop()
	active_damage_indicators.clear()
	if damage_wheel_control:
		damage_wheel_control.queue_redraw()
	blood_flash_intensity = 0.0
	if blood_vignette_mat:
		blood_vignette_mat.set_shader_parameter("flash_intensity", 0.0)
		blood_vignette_mat.set_shader_parameter("pulse_intensity", 0.0)
		blood_vignette_mat.set_shader_parameter("health_ratio", 1.0)

	if death_overlay and death_overlay.visible:
		var tween = create_tween()
		tween.tween_property(death_overlay, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func(): death_overlay.visible = false)

# ── GAMIFICAÇÃO & MEDALHAS ESTILO COD (SUB-8) ────────────────────────────────
func _setup_streak_medal_ui() -> void:
	# 1. Popup de Medalhas no centro da tela
	medal_popup_container = Control.new()
	medal_popup_container.name = "MedalPopupContainer"
	medal_popup_container.set_anchors_preset(Control.PRESET_CENTER)
	medal_popup_container.offset_left = -200
	medal_popup_container.offset_top = -120
	medal_popup_container.offset_right = 200
	medal_popup_container.offset_bottom = -20
	medal_popup_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	medal_popup_container.modulate.a = 0.0

	var medal_vbox = VBoxContainer.new()
	medal_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	medal_vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	medal_title_label = Label.new()
	medal_title_label.text = "⚡ DOUBLE KILL! ⚡"
	medal_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	medal_title_label.add_theme_font_size_override("font_size", 28)
	medal_title_label.modulate = Color(1.0, 0.85, 0.2)
	medal_vbox.add_child(medal_title_label)

	medal_xp_label = Label.new()
	medal_xp_label.text = "+200 XP"
	medal_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	medal_xp_label.add_theme_font_size_override("font_size", 18)
	medal_xp_label.modulate = Color(0.2, 1.0, 0.4)
	medal_vbox.add_child(medal_xp_label)

	medal_popup_container.add_child(medal_vbox)
	add_child(medal_popup_container)

	# 2. Banner de Streak consecutivo
	streak_banner_label = Label.new()
	streak_banner_label.name = "StreakBannerLabel"
	streak_banner_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	streak_banner_label.offset_top = 100
	streak_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	streak_banner_label.add_theme_font_size_override("font_size", 20)
	streak_banner_label.modulate = Color(1.0, 0.4, 0.1)
	streak_banner_label.visible = false
	add_child(streak_banner_label)

	# 3. Badge persistente de Streak no canto inferior direito
	streak_hud_label = Label.new()
	streak_hud_label.name = "StreakHudLabel"
	streak_hud_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	streak_hud_label.offset_left = -260
	streak_hud_label.offset_top = -110
	streak_hud_label.offset_right = -30
	streak_hud_label.offset_bottom = -80
	streak_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	streak_hud_label.add_theme_font_size_override("font_size", 16)
	streak_hud_label.modulate = Color(1.0, 0.7, 0.2)
	streak_hud_label.text = ""
	add_child(streak_hud_label)

func _show_medal_popup(title: String, xp: int, color: Color = Color(1.0, 0.85, 0.2)) -> void:
	if not medal_popup_container:
		return
	if medal_title_label:
		medal_title_label.text = title
		medal_title_label.modulate = color
	if medal_xp_label:
		medal_xp_label.text = "+%d XP" % xp

	# CoD Pop Punch Animation (scale 1.35 -> 1.0)
	medal_popup_container.visible = true
	medal_popup_container.modulate.a = 1.0
	medal_popup_container.scale = Vector2(1.35, 1.35)

	var tween = create_tween()
	tween.tween_property(medal_popup_container, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.2)
	tween.tween_property(medal_popup_container, "position:y", medal_popup_container.position.y - 25, 0.3)
	tween.parallel().tween_property(medal_popup_container, "modulate:a", 0.0, 0.3)

func _show_streak_banner(title: String, _streak_val: int) -> void:
	if not streak_banner_label:
		return
	streak_banner_label.text = "🎯 %s" % title
	streak_banner_label.visible = true
	streak_banner_label.modulate.a = 1.0

	var tween = create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(streak_banner_label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): streak_banner_label.visible = false)

func _update_streak_hud() -> void:
	if not streak_hud_label:
		return
	if current_player_streak > 0:
		streak_hud_label.text = "🔥 STREAK: %d" % current_player_streak
		streak_hud_label.visible = true
		if current_player_streak >= 5:
			streak_hud_label.modulate = Color(1.0, 0.2, 0.2)
		elif current_player_streak >= 3:
			streak_hud_label.modulate = Color(1.0, 0.6, 0.1)
		else:
			streak_hud_label.modulate = Color(1.0, 0.85, 0.3)
	else:
		streak_hud_label.text = ""
		streak_hud_label.visible = false

func _on_mode_kill_registered(killer_id: int, victim_id: int, weapon_id: String, is_headshot: bool) -> void:
	var my_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var is_me_killer = (killer_id == 1 or killer_id == 0 or killer_id == my_id)
	var is_me_victim = (victim_id == 1 or victim_id == 0 or victim_id == my_id)

	var gm_ref = get_node_or_null("/root/GameManager")
	var local_name = gm_ref.local_player_name if (gm_ref and not gm_ref.local_player_name.is_empty()) else "Você"
	var killer_name = local_name if is_me_killer else ("Inimigo_" + str(abs(killer_id) % 100))
	var victim_name = local_name if is_me_victim else ("Inimigo_" + str(abs(victim_id) % 100))

	# Tentar recuperar nome real do bot via player_stats ou nós do cenário
	if network_mgr and not network_mgr.player_stats.is_empty():
		if network_mgr.player_stats.has(killer_id):
			killer_name = str(network_mgr.player_stats[killer_id].get("name", killer_name))
		if network_mgr.player_stats.has(victim_id):
			victim_name = str(network_mgr.player_stats[victim_id].get("name", victim_name))

	var tree = get_tree()
	if tree and tree.current_scene:
		var bots = tree.get_nodes_in_group("enemies")
		for b in bots:
			var b_match_killer = ("bot_id" in b and b.bot_id == killer_id) or b.get_instance_id() == killer_id
			var b_match_victim = ("bot_id" in b and b.bot_id == victim_id) or b.get_instance_id() == victim_id
			if b_match_killer and "bot_display_name" in b:
				killer_name = b.bot_display_name
			elif b_match_victim and "bot_display_name" in b:
				victim_name = b.bot_display_name

	var cfg = WeaponVisualRegistry.get_weapon_config(weapon_id)
	var w_name = cfg.get("name", weapon_id.to_upper())
	if is_headshot:
		w_name += " [HEADSHOT]"
	add_kill_feed_entry(killer_name, victim_name, w_name, is_me_killer, is_me_victim)

	if is_me_killer:
		current_player_streak += 1
		_update_streak_hud()

func _on_multi_kill_achieved(killer_id: int, _count: int, medal_name: String, xp_bonus: int) -> void:
	var my_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if killer_id == 1 or killer_id == 0 or killer_id == my_id:
		_show_medal_popup(medal_name, xp_bonus, Color(1.0, 0.8, 0.2))

func _on_streak_achieved(killer_id: int, streak_count: int, streak_name: String) -> void:
	var my_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if killer_id == 1 or killer_id == 0 or killer_id == my_id:
		current_player_streak = streak_count
		_update_streak_hud()
		_show_streak_banner(streak_name, streak_count)

func _on_medal_awarded(killer_id: int, medal_name: String, xp_amount: int) -> void:
	var my_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if killer_id == 1 or killer_id == 0 or killer_id == my_id:
		var col = Color(1.0, 0.85, 0.2)
		match medal_name:
			"HEADSHOT": col = Color(1.0, 0.35, 0.2)
			"LOW BLOW": col = Color(0.35, 0.95, 0.70)
			"LONG SHOT": col = Color(0.40, 0.85, 1.00)
			"POINT BLANK": col = Color(1.00, 0.60, 0.15)
			"FIRST BLOOD": col = Color(1.00, 0.25, 0.25)
			"BLOODTHIRSTY", "MERCILESS", "RUTHLESS", "RELENTLESS", "BRUTAL", "NUCLEAR":
				col = Color(1.00, 0.85, 0.10)
			_: col = Color(0.95, 0.95, 1.0)
		_show_medal_popup(medal_name, xp_amount, col)

func _on_mode_assist_registered(assistant_id: int, _victim_id: int, _damage_dealt: int, is_major: bool) -> void:
	var my_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if assistant_id == 1 or assistant_id == 0 or assistant_id == my_id:
		var xp = 75 if is_major else 50
		var title = "ASSISTÊNCIA PRINCIPAL" if is_major else "ASSISTÊNCIA"
		_show_medal_popup(title, xp, Color(0.35, 0.85, 1.0) if not is_major else Color(1.0, 0.85, 0.25))

# =============================================================================
# CONTAGEM REGRESSIVA PRÉ-PARTIDA ESTILO CALL OF DUTY
# =============================================================================

func _setup_pre_match_countdown_ui() -> void:
	_countdown_tick_wav = _create_tone_wav(720.0, 0.12, 0.45)
	_countdown_go_wav = _create_go_chord_wav()

	countdown_audio_player = AudioStreamPlayer.new()
	countdown_audio_player.name = "CountdownAudioPlayer"
	countdown_audio_player.bus = "Master"
	add_child(countdown_audio_player)

	countdown_panel = PanelContainer.new()
	countdown_panel.name = "PreMatchCountdownPanel"
	countdown_panel.set_anchors_preset(Control.PRESET_CENTER)
	countdown_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	countdown_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	countdown_panel.offset_left = -220
	countdown_panel.offset_right = 220
	countdown_panel.offset_top = -140
	countdown_panel.offset_bottom = -20
	countdown_panel.pivot_offset = Vector2(220, 60)
	countdown_panel.visible = false

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.08, 0.88)
	style.border_color = Color(0.25, 0.55, 0.85, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	countdown_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	countdown_panel.add_child(vbox)

	countdown_header_label = Label.new()
	countdown_header_label.text = "/// A PARTIDA COMEÇA EM"
	countdown_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_header_label.add_theme_font_size_override("font_size", 13)
	countdown_header_label.modulate = Color(0.65, 0.82, 1.0, 0.95)
	vbox.add_child(countdown_header_label)

	countdown_number_label = Label.new()
	countdown_number_label.text = "5"
	countdown_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_number_label.add_theme_font_size_override("font_size", 54)
	countdown_number_label.modulate = Color(1.0, 0.85, 0.25)
	countdown_number_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	countdown_number_label.add_theme_constant_override("outline_size", 6)
	vbox.add_child(countdown_number_label)

	countdown_sub_label = Label.new()
	countdown_sub_label.text = "POSIÇÕES DE SPAWN BLOQUEADAS"
	countdown_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_sub_label.add_theme_font_size_override("font_size", 10)
	countdown_sub_label.modulate = Color(0.7, 0.7, 0.7, 0.8)
	vbox.add_child(countdown_sub_label)

	add_child(countdown_panel)

func _on_countdown_started(duration: float) -> void:
	if not countdown_panel:
		return
	countdown_panel.visible = true
	countdown_panel.modulate.a = 1.0
	countdown_header_label.text = "/// A PARTIDA COMEÇA EM"
	countdown_sub_label.text = "POSIÇÕES DE SPAWN BLOQUEADAS"
	_on_countdown_tick(int(ceil(duration)))

func _on_countdown_tick(seconds_left: int) -> void:
	if not countdown_panel:
		return
	if seconds_left <= 0:
		return
	countdown_panel.visible = true
	countdown_number_label.text = str(seconds_left)
	countdown_number_label.modulate = Color(1.0, 0.85, 0.25)

	countdown_panel.scale = Vector2(1.22, 1.22)
	var tween = create_tween()
	tween.tween_property(countdown_panel, "scale", Vector2(1.0, 1.0), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if countdown_audio_player and _countdown_tick_wav:
		countdown_audio_player.stream = _countdown_tick_wav
		countdown_audio_player.play()

func _on_countdown_completed() -> void:
	if not countdown_panel:
		return
	countdown_panel.visible = true
	countdown_header_label.text = "/// ORDEM DE MISSÃO"
	countdown_number_label.text = "COMBATE INICIADO!"
	countdown_number_label.modulate = Color(0.2, 1.0, 0.5)
	countdown_sub_label.text = "ELIMINE TODOS OS ALVOS HOSTIS"

	countdown_panel.scale = Vector2(1.35, 1.35)
	var tween = create_tween()
	tween.tween_property(countdown_panel, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.2)
	tween.tween_property(countdown_panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): countdown_panel.visible = false)

	if countdown_audio_player and _countdown_go_wav:
		countdown_audio_player.stream = _countdown_go_wav
		countdown_audio_player.play()

func _create_tone_wav(freq: float, duration: float, volume: float = 0.5) -> AudioStreamWAV:
	var sample_rate = 22050
	var num_samples = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(sample_rate)
		var env = exp(-t * 14.0)
		var val = sin(2.0 * PI * freq * t) * env * volume
		var val16 = clampi(int(val * 32767.0), -32768, 32767)
		byte_data.encode_s16(i * 2, val16)

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = byte_data
	return wav

func _create_go_chord_wav() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.45
	var num_samples = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(sample_rate)
		var env = exp(-t * 6.5)
		var val = (sin(2.0 * PI * 880.0 * t) * 0.35 + sin(2.0 * PI * 1100.0 * t) * 0.35 + sin(2.0 * PI * 220.0 * t) * 0.4) * env
		var val16 = clampi(int(val * 32767.0), -32768, 32767)
		byte_data.encode_s16(i * 2, val16)

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = byte_data
	return wav

# =============================================================================
# RELATÓRIO PÓS-COMBATE (AAR) ESTILO CALL OF DUTY
# =============================================================================

## Constrói e inicializa a interface completa de AAR estilo Call of Duty
func _setup_match_end_aar_ui() -> void:
	aar_overlay = PanelContainer.new()
	aar_overlay.name = "AARMatchEndOverlay"
	aar_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	aar_overlay.visible = false
	aar_overlay.z_index = 100
	aar_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	aar_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg_box = StyleBoxFlat.new()
	bg_box.bg_color = Color(0.03, 0.05, 0.08, 0.96)
	bg_box.border_color = Color(0.22, 0.32, 0.45, 0.8)
	bg_box.set_border_width_all(2)
	aar_overlay.add_theme_stylebox_override("panel", bg_box)

	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	aar_overlay.add_child(margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(root_vbox)

	# --- 1. Top Section: Header, Outcome Title, Subtitle, Score Banner ---
	var top_vbox = VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 2)
	root_vbox.add_child(top_vbox)

	var aar_tag = Label.new()
	aar_tag.text = "/// RELATÓRIO PÓS-COMBATE  •  AFTER ACTION REPORT (AAR)"
	aar_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aar_tag.add_theme_font_size_override("font_size", 12)
	aar_tag.modulate = Color(0.55, 0.7, 0.85, 0.8)
	top_vbox.add_child(aar_tag)

	aar_outcome_title = Label.new()
	aar_outcome_title.name = "AAROutcomeTitle"
	aar_outcome_title.text = "VITÓRIA"
	aar_outcome_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aar_outcome_title.add_theme_font_size_override("font_size", 44)
	aar_outcome_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	aar_outcome_title.add_theme_constant_override("outline_size", 8)
	top_vbox.add_child(aar_outcome_title)

	aar_outcome_subtitle = Label.new()
	aar_outcome_subtitle.name = "AAROutcomeSubtitle"
	aar_outcome_subtitle.text = "MISSÃO CUMPRIDA // FORÇAS ALIADAS DOMINARAM A ZONA DE COMBATE"
	aar_outcome_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aar_outcome_subtitle.add_theme_font_size_override("font_size", 13)
	aar_outcome_subtitle.modulate = Color(0.85, 0.88, 0.92)
	top_vbox.add_child(aar_outcome_subtitle)

	aar_score_banner = Label.new()
	aar_score_banner.name = "AARScoreBanner"
	aar_score_banner.text = "🛡️ FORÇAS ALPHA: 10   —   7 :FORÇAS BRAVO 💣"
	aar_score_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aar_score_banner.add_theme_font_size_override("font_size", 20)
	aar_score_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	aar_score_banner.add_theme_constant_override("outline_size", 5)
	top_vbox.add_child(aar_score_banner)

	# --- 2. Destaques: MVP, Gamificação Real de XP e Estatísticas ---
	var highlight_panel = PanelContainer.new()
	var h_box = StyleBoxFlat.new()
	h_box.bg_color = Color(0.06, 0.09, 0.14, 0.94)
	h_box.border_color = Color(0.85, 0.7, 0.25, 0.8)
	h_box.set_border_width_all(1)
	h_box.set_corner_radius_all(6)
	highlight_panel.add_theme_stylebox_override("panel", h_box)

	var h_margin = MarginContainer.new()
	h_margin.add_theme_constant_override("margin_left", 16)
	h_margin.add_theme_constant_override("margin_right", 16)
	h_margin.add_theme_constant_override("margin_top", 8)
	h_margin.add_theme_constant_override("margin_bottom", 8)
	highlight_panel.add_child(h_margin)

	var h_vbox = VBoxContainer.new()
	h_vbox.add_theme_constant_override("separation", 4)
	h_margin.add_child(h_vbox)

	# Banner animado de Level Up (visível apenas ao subir de nível)
	aar_level_up_banner = Label.new()
	aar_level_up_banner.name = "AARLevelUpBanner"
	aar_level_up_banner.text = "🎖️ PROMOÇÃO DE PATENTE! VOCÊ ALCANÇOU UM NOVO NÍVEL!"
	aar_level_up_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aar_level_up_banner.add_theme_font_size_override("font_size", 16)
	aar_level_up_banner.modulate = Color(1.0, 0.85, 0.2)
	aar_level_up_banner.visible = false
	h_vbox.add_child(aar_level_up_banner)

	# MVP da Partida
	aar_mvp_label = Label.new()
	aar_mvp_label.name = "AARMVPLabel"
	aar_mvp_label.text = "⭐ MVP DA PARTIDA: Operador (12 Kills | 4.00 K/D | 1200 PTS)"
	aar_mvp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aar_mvp_label.add_theme_font_size_override("font_size", 14)
	aar_mvp_label.modulate = Color(1.0, 0.88, 0.3)
	h_vbox.add_child(aar_mvp_label)

	# Linha de Patente e Barra de Progresso Real de XP
	var xp_hbox = HBoxContainer.new()
	xp_hbox.add_theme_constant_override("separation", 12)
	h_vbox.add_child(xp_hbox)

	aar_rank_badge_label = Label.new()
	aar_rank_badge_label.name = "AARRankBadgeLabel"
	aar_rank_badge_label.text = "★ NÍVEL 1 — RECRUTA"
	aar_rank_badge_label.add_theme_font_size_override("font_size", 13)
	aar_rank_badge_label.modulate = Color(1.0, 0.85, 0.2)
	xp_hbox.add_child(aar_rank_badge_label)

	var bar_vbox = VBoxContainer.new()
	bar_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_vbox.add_theme_constant_override("separation", 2)
	xp_hbox.add_child(bar_vbox)

	aar_xp_progress_bar = ProgressBar.new()
	aar_xp_progress_bar.name = "AARXPProgressBar"
	aar_xp_progress_bar.custom_minimum_size = Vector2(0, 14)
	aar_xp_progress_bar.show_percentage = false
	aar_xp_progress_bar.max_value = 1.0

	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	bar_bg.set_corner_radius_all(3)
	aar_xp_progress_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.18, 0.85, 0.45, 0.95)
	bar_fill.set_corner_radius_all(3)
	aar_xp_progress_bar.add_theme_stylebox_override("fill", bar_fill)
	bar_vbox.add_child(aar_xp_progress_bar)

	aar_xp_detail_label = Label.new()
	aar_xp_detail_label.name = "AARXPDetailLabel"
	aar_xp_detail_label.text = "XP: 0 / 1000  •  (+0 XP)"
	aar_xp_detail_label.add_theme_font_size_override("font_size", 11)
	aar_xp_detail_label.modulate = Color(0.7, 0.82, 0.95, 0.85)
	bar_vbox.add_child(aar_xp_detail_label)

	# Grid de Estatísticas Reais de Combate
	aar_personal_stats_label = Label.new()
	aar_personal_stats_label.name = "AARPersonalStatsLabel"
	aar_personal_stats_label.text = "🎯 ABATES: 0  |  💀 MORTES: 0  |  ⚡ K/D: 0.00  |  💥 HEADSHOTS: 0  |  🔥 SEQUÊNCIA: 0  |  🏆 PTS: 0"
	aar_personal_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aar_personal_stats_label.add_theme_font_size_override("font_size", 13)
	aar_personal_stats_label.modulate = Color(0.35, 0.9, 1.0)
	h_vbox.add_child(aar_personal_stats_label)

	root_vbox.add_child(highlight_panel)

	# --- 3. Placar Completo Consolidado Lado a Lado ---
	var teams_hbox = HBoxContainer.new()
	teams_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	teams_hbox.add_theme_constant_override("separation", 16)
	root_vbox.add_child(teams_hbox)

	var alpha_col = _create_team_column("🛡️ FORÇAS ALPHA (CONTRA-TERRORISTAS)", Color(0.16, 0.32, 0.7, 0.9), Color(0.65, 0.82, 1.0))
	teams_hbox.add_child(alpha_col["container"])
	aar_alpha_list = alpha_col["list"]

	var vsep = VSeparator.new()
	teams_hbox.add_child(vsep)

	var bravo_col = _create_team_column("💣 FORÇAS BRAVO (TERRORISTAS)", Color(0.7, 0.2, 0.16, 0.9), Color(1.0, 0.65, 0.6))
	teams_hbox.add_child(bravo_col["container"])
	aar_bravo_list = bravo_col["list"]

	# --- 4. Barra de Ações Inferior (Botões Estilo CoD & Timer Regressivo) ---
	var bottom_vbox = VBoxContainer.new()
	bottom_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_vbox.add_theme_constant_override("separation", 6)
	root_vbox.add_child(bottom_vbox)

	# Linha do Timer Regressivo com Botão de Pausa
	var timer_hbox = HBoxContainer.new()
	timer_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	timer_hbox.add_theme_constant_override("separation", 12)
	bottom_vbox.add_child(timer_hbox)

	aar_auto_timer_label = Label.new()
	aar_auto_timer_label.text = "⏱️ RETORNANDO AO LOBBY EM: 25s..."
	aar_auto_timer_label.add_theme_font_size_override("font_size", 12)
	aar_auto_timer_label.modulate = Color(0.65, 0.78, 0.9, 0.9)
	timer_hbox.add_child(aar_auto_timer_label)

	btn_pause_timer = Button.new()
	btn_pause_timer.text = "[ ⏸️ PAUSAR TIMER ]"
	btn_pause_timer.add_theme_font_size_override("font_size", 11)
	btn_pause_timer.flat = true
	btn_pause_timer.modulate = Color(0.8, 0.85, 0.95, 0.8)
	btn_pause_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	btn_pause_timer.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_pause_timer.pressed.connect(_on_pause_timer_pressed)
	timer_hbox.add_child(btn_pause_timer)

	aar_auto_timer_progress = ProgressBar.new()
	aar_auto_timer_progress.custom_minimum_size = Vector2(0, 3)
	aar_auto_timer_progress.show_percentage = false
	aar_auto_timer_progress.max_value = 1.0
	aar_auto_timer_progress.value = 1.0

	var p_fill = StyleBoxFlat.new()
	p_fill.bg_color = Color(0.2, 0.85, 1.0, 0.85)
	aar_auto_timer_progress.add_theme_stylebox_override("fill", p_fill)
	var p_bg = StyleBoxFlat.new()
	p_bg.bg_color = Color(0.08, 0.12, 0.18, 0.5)
	aar_auto_timer_progress.add_theme_stylebox_override("background", p_bg)
	bottom_vbox.add_child(aar_auto_timer_progress)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 24)
	bottom_vbox.add_child(btn_hbox)

	btn_play_again = _create_cod_button("🔄 JOGAR NOVAMENTE", Color(0.2, 0.85, 1.0))
	btn_play_again.pressed.connect(_on_play_again_pressed)
	btn_hbox.add_child(btn_play_again)

	btn_return_lobby = _create_cod_button("🛡️ VOLTAR AO LOBBY", Color(0.3, 0.9, 0.45))
	btn_return_lobby.pressed.connect(_on_return_to_lobby_pressed)
	btn_hbox.add_child(btn_return_lobby)

	btn_main_menu = _create_cod_button("🏠 MENU PRINCIPAL", Color(0.75, 0.8, 0.85))
	btn_main_menu.pressed.connect(_on_main_menu_pressed)
	btn_hbox.add_child(btn_main_menu)

	add_child(aar_overlay)

## Cria botão tático estilizado no padrão Call of Duty com micro-interações
func _create_cod_button(title: String, accent_color: Color) -> Button:
	var btn = Button.new()
	btn.text = title
	btn.custom_minimum_size = Vector2(250, 48)
	btn.pivot_offset = Vector2(125, 24)
	btn.add_theme_font_size_override("font_size", 14)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.mouse_filter = Control.MOUSE_FILTER_STOP

	var normal_box = StyleBoxFlat.new()
	normal_box.bg_color = Color(0.07, 0.10, 0.15, 0.95)
	normal_box.border_color = accent_color
	normal_box.set_border_width_all(2)
	normal_box.set_corner_radius_all(6)
	normal_box.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal_box)

	var hover_box = StyleBoxFlat.new()
	hover_box.bg_color = Color(0.14, 0.20, 0.30, 0.98)
	hover_box.border_color = Color(1.0, 1.0, 1.0, 0.95)
	hover_box.set_border_width_all(2)
	hover_box.set_corner_radius_all(6)
	hover_box.set_content_margin_all(8)
	btn.add_theme_stylebox_override("hover", hover_box)

	var pressed_box = StyleBoxFlat.new()
	pressed_box.bg_color = Color(0.04, 0.06, 0.10, 1.0)
	pressed_box.border_color = accent_color
	pressed_box.set_border_width_all(2)
	pressed_box.set_corner_radius_all(6)
	pressed_box.set_content_margin_all(8)
	btn.add_theme_stylebox_override("pressed", pressed_box)

	var focus_box = StyleBoxFlat.new()
	focus_box.draw_center = false
	focus_box.border_color = accent_color
	focus_box.set_border_width_all(2)
	focus_box.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("focus", focus_box)

	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	btn.mouse_entered.connect(func():
		var tw = btn.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.08)
	)
	btn.mouse_exited.connect(func():
		var tw = btn.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)
	)

	return btn

## Apresenta o Relatório Pós-Combate (AAR) estilo Call of Duty com slow-mo e bloqueio de inputs
func show_match_end_aar(winner_team: int, details: Dictionary = {}) -> void:
	if not aar_overlay:
		return

	# 1. Trava disparos e animações do jogador local
	if local_player and local_player.weapon_manager:
		local_player.weapon_manager.set_process(false)
		local_player.weapon_manager.set_physics_process(false)

	# 1.1 Desativa inputs de movimentação/câmera de todos os jogadores para liberar 100% o mouse para a UI
	get_tree().call_group("player", "set_process_input", false)
	get_tree().call_group("player", "set_process_unhandled_input", false)

	# 1.2 Fecha e desativa o PauseMenu se estiver ativo
	var p_menu = get_node_or_null("PauseMenu")
	if p_menu:
		p_menu.visible = false
		p_menu.set_process_unhandled_input(false)

	# 2. Oculta painéis legados para não haver sobreposição
	if winner_panel:
		winner_panel.visible = false
	if scoreboard_panel:
		scoreboard_panel.visible = false
	if sudden_death_banner:
		sudden_death_banner.visible = false

	# 3. Libera o cursor do mouse para navegação e garante que a árvore não está pausada
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# 4. Impacto Cinemático CoD: Câmera Lenta (Slow-mo stinger) de 1.2s reais
	Engine.time_scale = 0.4
	get_tree().create_timer(1.2, true, false, true).timeout.connect(func():
		Engine.time_scale = 1.0
	)

	# 5. Obtém estatísticas consolidadas e identifica a equipe do jogador local
	var stats = _get_consolidated_stats()
	var my_peer_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var gm_ref = get_node_or_null("/root/GameManager")

	var my_team = 0
	if network_mgr and network_mgr.has_method("is_player_alpha"):
		my_team = 0 if network_mgr.is_player_alpha(my_peer_id) else 1
	elif gm_ref and "local_player_team" in gm_ref:
		my_team = gm_ref.local_player_team
	elif stats.has(my_peer_id):
		my_team = int(stats[my_peer_id].get("team", 0))

	# 6. Determina o Resultado da Partida (Vitória / Derrota / Empate)
	var is_draw = (winner_team < 0)
	var is_victory = not is_draw and (winner_team == my_team)

	if aar_outcome_title:
		if is_draw:
			aar_outcome_title.text = "EMPATE"
			aar_outcome_title.modulate = Color(0.85, 0.88, 0.95)
			if aar_outcome_subtitle:
				aar_outcome_subtitle.text = "TEMPO ESGOTADO // NENHUMA EQUIPE ALCANÇOU A VANTAGEM TÁTICA"
		elif is_victory:
			aar_outcome_title.text = "VITÓRIA"
			aar_outcome_title.modulate = Color(0.2, 1.0, 0.45)
			if aar_outcome_subtitle:
				aar_outcome_subtitle.text = "MISSÃO CUMPRIDA // FORÇAS ALIADAS DOMINARAM A ZONA DE COMBATE"
		else:
			aar_outcome_title.text = "DERROTA"
			aar_outcome_title.modulate = Color(1.0, 0.25, 0.25)
			if aar_outcome_subtitle:
				aar_outcome_subtitle.text = "MISSÃO FRACASSADA // O INIMIGO ALCANÇOU A META ANTES DO SEU ESQUADRÃO"

	# 7. Placar Geral (Alpha vs Bravo)
	var score_a = details.get("score_alpha", network_mgr.score_alpha if network_mgr else 0)
	var score_b = details.get("score_bravo", network_mgr.score_bravo if network_mgr else 0)
	if aar_score_banner:
		aar_score_banner.text = "🛡️ FORÇAS ALPHA: %d   —   %d :FORÇAS BRAVO 💣" % [score_a, score_b]

	# 8. Renderiza as listas e obtém MVP e dados do jogador local
	var render_data = _render_team_lists_to_containers(aar_alpha_list, aar_bravo_list, stats, my_peer_id)
	var mvp = render_data.get("mvp", null)
	var my_p = render_data.get("local_player", null)

	# 9. Exibe MVP da Partida
	if aar_mvp_label:
		if mvp:
			var m_name = str(mvp.get("name", "Operador"))
			var m_k = int(mvp.get("kills", 0))
			var m_d = int(mvp.get("deaths", 0))
			var m_kd = ("%.2f" % (float(m_k) / float(m_d))) if m_d > 0 else (str(m_k) + ".00")
			var m_pts = int(mvp.get("score", m_k * 100))
			aar_mvp_label.text = "⭐ MVP DA PARTIDA: %s   |   %d KILLS   |   %s K/D   |   %d PTS" % [m_name, m_k, m_kd, m_pts]
		else:
			aar_mvp_label.text = "⭐ MVP DA PARTIDA: OPERADOR DESTACADO"

	# 10. Resumo Pessoal e Gamificação Real de XP (XPSystem integrado)
	var p_k = int(my_p.get("kills", 0)) if my_p else 0
	var p_d = int(my_p.get("deaths", 0)) if my_p else 0
	var p_kd = ("%.2f" % (float(p_k) / float(p_d))) if p_d > 0 else (str(p_k) + ".00")
	var p_score = int(my_p.get("score", p_k * 100)) if my_p else 0
	var p_hs = gm_ref.player_stats.get("headshots", 0) if gm_ref else 0
	var p_cr = gm_ref.player_stats.get("crouch_kills", 0) if gm_ref else 0
	var p_acc = gm_ref.player_stats.get("accuracy", 0.0) if gm_ref else 0.0
	var p_ast = gm_ref.player_stats.get("assists", 0) if gm_ref else 0
	var p_streak = current_player_streak

	var xp_res: Dictionary = {}
	if gm_ref and gm_ref.xp_system:
		xp_res = gm_ref.xp_system.award_match_xp(p_k, p_hs, p_ast, is_victory, 0, p_cr)

	if aar_rank_badge_label and not xp_res.is_empty():
		var r_tag = xp_res.get("rank_tag", "[PVT 1]")
		var r_icon = xp_res.get("rank_icon", "★")
		var r_title = xp_res.get("rank_title", "RECRUTA")
		aar_rank_badge_label.text = "%s %s  •  %s" % [r_icon, r_tag, r_title]
		aar_rank_badge_label.modulate = xp_res.get("rank_color", Color(1.0, 0.85, 0.2))

	if aar_xp_progress_bar and not xp_res.is_empty():
		var prev_ratio = float(xp_res.get("previous_xp", 0)) / float(maxi(1, xp_res.get("previous_needed", 1000)))
		var target_ratio = xp_res.get("new_progress_ratio", 0.0)
		aar_xp_progress_bar.value = prev_ratio
		var tw_bar = create_tween()
		tw_bar.tween_property(aar_xp_progress_bar, "value", target_ratio, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if aar_xp_detail_label and not xp_res.is_empty():
		aar_xp_detail_label.text = "XP: %d / %d  •  (+%d XP CONQUISTADOS)" % [
			xp_res.get("new_xp", 0),
			xp_res.get("new_needed", 1000),
			xp_res.get("total_xp_gained", 0)
		]

	if aar_level_up_banner and not xp_res.is_empty():
		if xp_res.get("leveled_up", false):
			aar_level_up_banner.visible = true
			aar_level_up_banner.text = "🎖️ PROMOÇÃO DE PATENTE! VOCÊ ALCANÇOU %s (%s)!" % [
				xp_res.get("rank_tag", ""),
				xp_res.get("rank_title", "")
			]
			var tw_lvl = create_tween().set_loops(4)
			tw_lvl.tween_property(aar_level_up_banner, "modulate:a", 0.35, 0.3)
			tw_lvl.tween_property(aar_level_up_banner, "modulate:a", 1.0, 0.3)
		else:
			aar_level_up_banner.visible = false

	if aar_personal_stats_label:
		var stat_txt = "🎯 ABATES: %d  |  💀 MORTES: %d  |  ⚡ K/D: %s  |  💥 HEADSHOTS: %d  |  🥋 AGACHADO: %d  |  🎯 PRECISÃO: %.1f%%  |  🏆 PTS: %d" % [
			p_k, p_d, p_kd, p_hs, p_cr, p_acc, p_score
		]
		if details.has("payout") and float(details["payout"]) > 0.0:
			stat_txt += "  •  💰 PRÊMIO: +$%.2f USDC" % float(details["payout"])
		aar_personal_stats_label.text = stat_txt

	# 11. Inicia o Timer Regressivo de Retorno Automático
	aar_auto_timer = 25.0
	aar_auto_timer_max = 25.0
	aar_auto_timer_active = true
	aar_auto_timer_paused = false
	if aar_auto_timer_label:
		aar_auto_timer_label.text = "⏱️ RETORNANDO AO LOBBY EM: 25s..."
	if aar_auto_timer_progress:
		aar_auto_timer_progress.value = 1.0
	if btn_pause_timer:
		btn_pause_timer.text = "[ ⏸️ PAUSAR TIMER ]"

	# 12. Revela a tela com fade-in suave
	aar_overlay.visible = true
	aar_overlay.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(aar_overlay, "modulate:a", 1.0, 0.3)

func _on_pause_timer_pressed() -> void:
	aar_auto_timer_paused = not aar_auto_timer_paused
	if btn_pause_timer:
		btn_pause_timer.text = "[ ▶️ RETOMAR TIMER ]" if aar_auto_timer_paused else "[ ⏸️ PAUSAR TIMER ]"
	if aar_auto_timer_label:
		if aar_auto_timer_paused:
			aar_auto_timer_label.text = "⏸️ CONTAGEM PAUSADA — ANALISANDO PLACAR"
		else:
			aar_auto_timer_label.text = "⏱️ RETORNANDO AO LOBBY EM: %02ds..." % maxi(0, int(ceil(aar_auto_timer)))

func _on_play_again_pressed() -> void:
	aar_auto_timer_active = false
	if btn_play_again:
		btn_play_again.disabled = true
		btn_play_again.text = "⏳ REINICIANDO PARTIDA..."
	Engine.time_scale = 1.0
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if local_player and local_player.weapon_manager:
		local_player.weapon_manager.set_process(true)
		local_player.weapon_manager.set_physics_process(true)
	get_tree().call_group("player", "set_process_input", true)
	get_tree().call_group("player", "set_process_unhandled_input", true)

	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.is_match_active = true
		gm.match_time_elapsed = 0.0
		gm.player_stats = {"kills": 0, "deaths": 0, "assists": 0, "score": 0, "headshots": 0}
		if gm.has_method("launch_configured_match"):
			gm.launch_configured_match()
			return
		elif gm.has_method("restart_match_rematch"):
			gm.restart_match_rematch()
			return

	if network_mgr and multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			network_mgr.rpc_rematch_match()
			return
		else:
			btn_play_again.text = "⏳ AGUARDANDO HOST..."
			return

	get_tree().reload_current_scene()

func _on_return_to_lobby_pressed() -> void:
	aar_auto_timer_active = false
	if btn_return_lobby:
		btn_return_lobby.disabled = true
		btn_return_lobby.text = "🛡️ RETORNANDO AO LOBBY..."
	Engine.time_scale = 1.0
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_cleanup_multiplayer_if_active()
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.is_match_active = false
		gm.set_state(gm.GameState.MENU)

	get_tree().change_scene_to_file("res://scenes/ui/lobby_screen.tscn")

func _on_main_menu_pressed() -> void:
	aar_auto_timer_active = false
	if btn_main_menu:
		btn_main_menu.disabled = true
		btn_main_menu.text = "🏠 RETORNANDO AO MENU..."
	Engine.time_scale = 1.0
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_cleanup_multiplayer_if_active()
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.is_match_active = false
		gm.match_time_elapsed = 0.0
		gm.set_state(gm.GameState.MENU)
		gm.lobby_roster.clear()

	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _cleanup_multiplayer_if_active() -> void:
	if network_mgr and network_mgr.has_method("_cleanup_network"):
		network_mgr._cleanup_network()
	elif multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

# =============================================================================
# SISTEMA DE INTERFACE DE VANTAGENS BO6 (PERKS & HIGH ALERT)
# =============================================================================
func _setup_bo6_perks_hud() -> void:
	# 1. Overlay Periférico do Alerta Máximo (High Alert)
	high_alert_left_rect = ColorRect.new()
	high_alert_left_rect.name = "HighAlertLeft"
	high_alert_left_rect.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	high_alert_left_rect.custom_minimum_size = Vector2(28, 0)
	high_alert_left_rect.color = Color(1.0, 0.72, 0.08, 0.88)
	high_alert_left_rect.modulate.a = 0.0
	high_alert_left_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(high_alert_left_rect)

	high_alert_right_rect = ColorRect.new()
	high_alert_right_rect.name = "HighAlertRight"
	high_alert_right_rect.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	high_alert_right_rect.custom_minimum_size = Vector2(28, 0)
	high_alert_right_rect.color = Color(1.0, 0.72, 0.08, 0.88)
	high_alert_right_rect.modulate.a = 0.0
	high_alert_right_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(high_alert_right_rect)

	high_alert_back_rect = ColorRect.new()
	high_alert_back_rect.name = "HighAlertBack"
	high_alert_back_rect.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	high_alert_back_rect.custom_minimum_size = Vector2(0, 22)
	high_alert_back_rect.color = Color(1.0, 0.72, 0.08, 0.88)
	high_alert_back_rect.modulate.a = 0.0
	high_alert_back_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(high_alert_back_rect)

	# 2. Banner de Especialidade RECON (Wallhack de Respawn)
	recon_wallhack_banner = PanelContainer.new()
	recon_wallhack_banner.name = "ReconWallhackBanner"
	recon_wallhack_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	recon_wallhack_banner.offset_top = 95
	recon_wallhack_banner.offset_left = -170
	recon_wallhack_banner.offset_right = 170
	recon_wallhack_banner.offset_bottom = 135

	var recon_style = StyleBoxFlat.new()
	recon_style.bg_color = Color(0.04, 0.12, 0.22, 0.85)
	recon_style.border_color = Color(0.25, 0.75, 1.0, 0.95)
	recon_style.set_border_width_all(2)
	recon_style.set_corner_radius_all(6)
	recon_style.content_margin_left = 12
	recon_style.content_margin_right = 12
	recon_style.content_margin_top = 4
	recon_style.content_margin_bottom = 4
	recon_wallhack_banner.add_theme_stylebox_override("panel", recon_style)

	var recon_lbl = Label.new()
	recon_lbl.text = "🎖️ RECON ATIVO: INIMIGOS REVELADOS"
	recon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	recon_lbl.add_theme_font_size_override("font_size", 13)
	recon_lbl.modulate = Color(0.4, 0.9, 1.0, 1.0)
	recon_wallhack_banner.add_child(recon_lbl)
	recon_wallhack_banner.visible = false
	add_child(recon_wallhack_banner)

	# 3. Badge Tático de Vantagens Ativas no Canto Inferior Direito
	perks_hud_container = PanelContainer.new()
	perks_hud_container.name = "PerksHUDContainer"
	perks_hud_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	perks_hud_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	perks_hud_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	perks_hud_container.offset_left = -230
	perks_hud_container.offset_right = -20
	perks_hud_container.offset_top = -125
	perks_hud_container.offset_bottom = -75

	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.05, 0.07, 0.10, 0.75)
	p_style.border_color = Color(0.2, 0.3, 0.45, 0.6)
	p_style.set_border_width_all(1)
	p_style.set_corner_radius_all(4)
	p_style.content_margin_left = 8
	p_style.content_margin_right = 8
	p_style.content_margin_top = 4
	p_style.content_margin_bottom = 4
	perks_hud_container.add_theme_stylebox_override("panel", p_style)

	var p_vbox = VBoxContainer.new()
	p_vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	perks_specialty_label = Label.new()
	perks_specialty_label.text = "🔵 RECON ★"
	perks_specialty_label.add_theme_font_size_override("font_size", 11)
	perks_specialty_label.modulate = Color(0.3, 0.8, 1.0, 1.0)
	p_vbox.add_child(perks_specialty_label)

	perks_icons_label = Label.new()
	perks_icons_label.text = "🛡️ 🦅 👁️"
	perks_icons_label.add_theme_font_size_override("font_size", 14)
	p_vbox.add_child(perks_icons_label)

	perks_hud_container.add_child(p_vbox)
	perks_hud_container.visible = false
	add_child(perks_hud_container)

## Pulso Direcional do Alerta Máximo (High Alert)
func trigger_high_alert_pulse(side: String) -> void:
	match side:
		"left":
			if high_alert_left_rect:
				high_alert_left_rect.modulate.a = 0.95
				var tw = create_tween()
				tw.tween_property(high_alert_left_rect, "modulate:a", 0.0, 0.4)
		"right":
			if high_alert_right_rect:
				high_alert_right_rect.modulate.a = 0.95
				var tw = create_tween()
				tw.tween_property(high_alert_right_rect, "modulate:a", 0.0, 0.4)
		_:
			if high_alert_back_rect:
				high_alert_back_rect.modulate.a = 0.95
				var tw = create_tween()
				tw.tween_property(high_alert_back_rect, "modulate:a", 0.0, 0.4)

## Revelação Tática ao Renascer (Recon Specialty Wallhack)
func trigger_recon_wallhack_pulse(duration: float = 2.0) -> void:
	if recon_wallhack_banner:
		recon_wallhack_banner.visible = true
		recon_wallhack_banner.modulate.a = 1.0
		var tw = create_tween()
		tw.tween_interval(duration)
		tw.tween_property(recon_wallhack_banner, "modulate:a", 0.0, 0.35)
		tw.tween_callback(func(): recon_wallhack_banner.visible = false)

## Atualização dos Ícones e Especialidade no HUD
func _on_perks_updated(perks: Array[String], specialty: String, is_synergy: bool) -> void:
	if not perks_hud_container:
		return
	perks_hud_container.visible = true

	var spec_color = Color(1.0, 0.35, 0.35) if specialty == "enforcer" else (Color(0.28, 0.75, 1.0) if specialty == "recon" else Color(0.35, 0.95, 0.45))
	var spec_tag = ("🔴 ENFORCER" if specialty == "enforcer" else ("🔵 RECON" if specialty == "recon" else "🟢 STRATEGIST"))
	if is_synergy:
		spec_tag += " ★ SINERGIA"

	if perks_specialty_label:
		perks_specialty_label.text = spec_tag
		perks_specialty_label.modulate = spec_color

	if perks_icons_label:
		var icons_str = ""
		for p in perks:
			var p_info = PerkManager.PERK_DATABASE.get(p)
			if p_info:
				icons_str += p_info.get("icon", "🔹") + " "
		perks_icons_label.text = icons_str.strip_edges()
