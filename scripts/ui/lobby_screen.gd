# =============================================================================
# lobby_screen.gd
# Tela de Lobby Pré-Jogo Estilo Clássico Call of Duty (MW3 / Black Ops)
# - Exibe modo de jogo, mapa selecionado com votação e alternância de cenários
# - Lista de jogadores com ícones de microfone, tags de clã, patentes e ping
# - Animação de busca de jogadores ("Procurando... ★") e entrada sequencial de bots
# - Modais táticos funcionais: Gunsmith, Callsign & Emblema, Quartel e Placar
# - Contagem regressiva tática e início forçado com transição de tela
# =============================================================================
class_name LobbyScreen
extends Control

const SkinRegistry = preload("res://scripts/characters/skin_registry.gd")
const WeaponModifier = preload("res://scripts/weapons/weapon_modifier.gd")
const CamoRegistry = preload("res://scripts/weapons/camo_registry.gd")

@export_group("UI References")
@export var lbl_mode_title     : Label
@export var lbl_status_header  : Label
@export var lbl_player_count   : Label
@export var vbox_players       : VBoxContainer
@export var img_map_preview    : TextureRect
@export var lbl_map_name       : Label
@export var lbl_map_votes      : Label
@export var btn_vote_map       : Button
@export var btn_force_start    : Button
@export var btn_gunsmith       : Button
@export var btn_callsign       : Button
@export var btn_barracks       : Button
@export var btn_leaderboard    : Button
@export var btn_back           : Button
@export var lbl_bottom_ticker  : Label
@export var modal_layer        : Control
@export var panel_gunsmith     : PanelContainer

# Configuração do Lobby
var countdown_seconds          : float = 6.0
var is_starting                : bool = false
var total_lobby_slots          : int = 12
var bots_to_add                : Array[Dictionary] = []
var added_players              : Array[Dictionary] = []
var bot_spawn_timer            : float = 0.0

# Estado Online e Sincronização
var is_online_session          : bool = false
var local_is_ready             : bool = false
var copy_feedback_timer        : float = 0.0

@onready var lbl_room_code     : Label  = get_node_or_null("MainLayout/VBox/HeaderHBox/BadgeVBox/RoomCodeHBox/LblRoomCode")
@onready var btn_copy_code     : Button = get_node_or_null("MainLayout/VBox/HeaderHBox/BadgeVBox/RoomCodeHBox/BtnCopyCode")
@onready var btn_social_hub    : Button = get_node_or_null("MainLayout/VBox/HeaderHBox/BadgeVBox/RoomCodeHBox/BtnSocial")
@onready var social_modal      : Control = get_node_or_null("SocialModal")

# Identidade do Jogador Local
var local_clan_tag             : String = "[TF141]"
var local_calling_card_id      : String = "solana"

# Sistema de Votação de Mapas
const MAP_OPTIONS: Array[Dictionary] = [
	{
		"path": "res://scenes/_world/map_nuk3town_bo3.tscn",
		"name": "NUKETOWN 2065 (BO3 FUTURISTA)",
		"short_name": "Nuketown 2065",
		"preview": "res://web/public/assets/nuketown_2065.jpg",
		"votes": 7
	},
	{
		"path": "res://scenes/_world/map_nuketown_1v1.tscn",
		"name": "NUKETOWN CLÁSSICA (BO1 1960)",
		"short_name": "Nuketown 1960",
		"preview": "res://web/public/assets/nuketown_bo1.jpg",
		"votes": 5
	}
]
var current_map_idx            : int = 0
var player_voted_idx           : int = 0

const RANKS: Array[Dictionary] = [
	{"icon": "★", "lvl": 65, "color": Color(1.0, 0.8, 0.2)},
	{"icon": "⭐", "lvl": 60, "color": Color(0.3, 0.85, 1.0)},
	{"icon": "🎖️", "lvl": 55, "color": Color(0.9, 0.6, 0.2)},
	{"icon": "★", "lvl": 49, "color": Color(0.8, 0.8, 0.8)},
	{"icon": "🎖️", "lvl": 42, "color": Color(0.7, 0.85, 0.7)},
	{"icon": "★", "lvl": 35, "color": Color(0.75, 0.75, 0.75)},
	{"icon": "⭐", "lvl": 70, "color": Color(1.0, 0.4, 0.4)}
]

const CLAN_TAGS: Array[String] = [
	"[TF141]", "[DELTA]", "[SAS]", "[DEVGRU]", "[ALPHA]", "[BRAVO]", "[SHADOW]", "[GHOST]"
]

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("cleanup_lingering_players"):
		nm.cleanup_lingering_players()

	_ensure_modal_layer()
	_init_lobby_data()
	_setup_buttons()
	_init_map_selection()
	_build_initial_player_list()

func _ensure_modal_layer() -> void:
	if not modal_layer:
		modal_layer = get_node_or_null("ModalLayer") as Control
	if not modal_layer:
		modal_layer = Control.new()
		modal_layer.name = "ModalLayer"
		modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		modal_layer.visible = false
		modal_layer.z_index = 30
		add_child(modal_layer)

func _init_lobby_data() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var target_count = 5
	var map_name = "NUKETOWN 2065 (BO3 FUTURISTA)"

	if gm:
		target_count = gm.bot_count
		is_online_session = (gm.play_mode == gm.PlayMode.ONLINE_HOST or gm.play_mode == gm.PlayMode.ONLINE_CLIENT)

		# Respeitar mapa pré-selecionado ou realizar sorteio no Lobby
		var found_idx = -1
		if not gm.target_map_path.is_empty():
			for i in range(MAP_OPTIONS.size()):
				if MAP_OPTIONS[i]["path"] == gm.target_map_path:
					found_idx = i
					break
		if found_idx != -1:
			current_map_idx = found_idx
		else:
			current_map_idx = randi() % MAP_OPTIONS.size()

		player_voted_idx = current_map_idx
		var drawn_map = MAP_OPTIONS[current_map_idx]
		gm.target_map_path = drawn_map["path"]
		gm.target_map_display_name = drawn_map["name"]
		map_name = drawn_map["name"]

	# Determinar total de slots da sala
	if is_online_session:
		total_lobby_slots = 2
	else:
		total_lobby_slots = max(2, target_count + 1)

	if lbl_mode_title:
		var mode_name = "MATA-MATA EM EQUIPE (6v6 TDM)"
		if gm:
			match gm.selected_game_mode:
				"6v6":
					var t_size = int((target_count + 1) / 2)
					if t_size > 1:
						mode_name = "MATA-MATA EM EQUIPE (%dv%d TDM)" % [t_size, t_size]
					else:
						mode_name = "DUELO TÁTICO (1v1 BOTS)"
				"1v1":
					mode_name = "DUELO TÁTICO (1v1 BOTS)" if not is_online_session else "DUELO TÁTICO (1v1 ONLINE)"
				"pve":
					mode_name = "PVE BOT ARENA (SOBREVIVÊNCIA)"
				_:
					var t_size = int((target_count + 1) / 2)
					mode_name = "MATA-MATA EM EQUIPE (%dv%d TDM)" % [t_size, t_size] if t_size > 1 else "DUELO TÁTICO (1v1)"
		lbl_mode_title.text = mode_name

	# Configurar badges de status do lobby e código da sala
	var lbl_lobby_stat = get_node_or_null("MainLayout/VBox/HeaderHBox/BadgeVBox/LblLobbyStatus") as Label
	if not is_online_session:
		if lbl_room_code:
			lbl_room_code.visible = false
		if btn_copy_code:
			btn_copy_code.visible = false
		if lbl_lobby_stat:
			lbl_lobby_stat.text = "● MODO TREINO TÁTICO (OFFLINE)"
			lbl_lobby_stat.modulate = Color(0.2, 0.85, 1.0, 1.0)
	else:
		if lbl_room_code:
			lbl_room_code.visible = true
		if btn_copy_code:
			btn_copy_code.visible = true
		if lbl_lobby_stat:
			lbl_lobby_stat.text = "● LOBBY MULTIPLAYER ONLINE"
			lbl_lobby_stat.modulate = Color(0.3, 0.9, 0.4, 1.0)

	if lbl_bottom_ticker:
		lbl_bottom_ticker.text = "Lobby tático pronto • Operador conectado em %s" % map_name

	if is_online_session:
		_init_online_lobby()
	else:
		_prepare_bot_queue(target_count)

func _init_online_lobby() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var nm = get_node_or_null("/root/NetworkManager")
	if not nm or not gm:
		return

	if not nm.lobby_updated.is_connected(_on_network_lobby_updated):
		nm.lobby_updated.connect(_on_network_lobby_updated)
	if not nm.lobby_map_changed.is_connected(_on_network_map_changed):
		nm.lobby_map_changed.connect(_on_network_map_changed)
	if not nm.room_code_created.is_connected(_on_room_code_created):
		nm.room_code_created.connect(_on_room_code_created)

	if gm.play_mode == gm.PlayMode.ONLINE_HOST:
		var code = nm.create_room(gm.online_port)
		if code.is_empty():
			if lbl_status_header:
				lbl_status_header.text = "ERRO: NÃO FOI POSSÍVEL ABRIR SERVIDOR LOCAL"
			if lbl_room_code:
				lbl_room_code.text = "⚠️ ERRO DE REDE"
		else:
			_on_room_code_created(code)
		if btn_force_start:
			btn_force_start.text = "▶ INICIAR DUELO (ESPAÇO)"
	elif gm.play_mode == gm.PlayMode.ONLINE_CLIENT:
		nm.join_room(gm.online_ip)
		_on_room_code_created(gm.online_ip)
		if btn_force_start:
			btn_force_start.text = "✔ ESTOU PRONTO"
		if btn_vote_map:
			btn_vote_map.disabled = true

func _on_room_code_created(code: String) -> void:
	if lbl_room_code:
		lbl_room_code.text = "🏷️ SALA: %s" % code

func _on_copy_code_pressed() -> void:
	var nm = get_node_or_null("/root/NetworkManager")
	var code = nm.current_room_code if (nm and not nm.current_room_code.is_empty()) else "NK-LOCAL"
	DisplayServer.clipboard_set(code)
	if btn_copy_code:
		btn_copy_code.text = "✔ COPIADO!"
		copy_feedback_timer = 2.0

func _on_social_hub_pressed() -> void:
	if social_modal and social_modal.has_method("toggle"):
		social_modal.toggle()

func _on_network_lobby_updated(roster_arr: Array[Dictionary]) -> void:
	added_players = roster_arr
	_render_player_rows()

	if lbl_status_header:
		if added_players.size() < 2:
			lbl_status_header.text = "AGUARDANDO ADVERSÁRIO (1/2) // COMPARTILHE O CÓDIGO DA SALA"
		else:
			var all_ready = true
			for p in added_players:
				if not p.get("is_ready", false):
					all_ready = false
					break
			if all_ready:
				lbl_status_header.text = "AMBOS OPERADORES PRONTOS! O HOST PODE INICIAR O DUELO."
			else:
				lbl_status_header.text = "ADVERSÁRIO CONECTADO (2/2) // AGUARDANDO STATUS PRONTO"

func _on_network_map_changed(map_idx: int) -> void:
	current_map_idx = map_idx
	player_voted_idx = map_idx
	var sel_map = MAP_OPTIONS[current_map_idx]
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.target_map_path = sel_map["path"]
		gm.target_map_display_name = sel_map["name"]
	_update_map_card_display()

func _setup_buttons() -> void:
	if btn_force_start and not btn_force_start.pressed.is_connected(_on_force_start):
		btn_force_start.pressed.connect(_on_force_start)
	if btn_back and not btn_back.pressed.is_connected(_on_back_pressed):
		btn_back.pressed.connect(_on_back_pressed)
	if btn_vote_map and not btn_vote_map.pressed.is_connected(_on_vote_map):
		btn_vote_map.pressed.connect(_on_vote_map)

	if not btn_copy_code:
		btn_copy_code = get_node_or_null("MainLayout/VBox/HeaderHBox/BadgeVBox/RoomCodeHBox/BtnCopyCode") as Button
	if not btn_social_hub:
		btn_social_hub = get_node_or_null("MainLayout/VBox/HeaderHBox/BadgeVBox/RoomCodeHBox/BtnSocial") as Button
	if not lbl_room_code:
		lbl_room_code = get_node_or_null("MainLayout/VBox/HeaderHBox/BadgeVBox/RoomCodeHBox/LblRoomCode") as Label

	if btn_copy_code and not btn_copy_code.pressed.is_connected(_on_copy_code_pressed):
		btn_copy_code.pressed.connect(_on_copy_code_pressed)
	if btn_social_hub and not btn_social_hub.pressed.is_connected(_on_social_hub_pressed):
		btn_social_hub.pressed.connect(_on_social_hub_pressed)

	# Botões do Menu Tático Esquerdo
	if not btn_gunsmith:
		btn_gunsmith = get_node_or_null("MainLayout/VBox/ContentHBox/LeftCol/VBox/TacticalMenuVBox/BtnGunsmith") as Button
	if not btn_callsign:
		btn_callsign = get_node_or_null("MainLayout/VBox/ContentHBox/LeftCol/VBox/TacticalMenuVBox/BtnCallsign") as Button
	if not btn_barracks:
		btn_barracks = get_node_or_null("MainLayout/VBox/ContentHBox/LeftCol/VBox/TacticalMenuVBox/BtnBarracks") as Button
	if not btn_leaderboard:
		btn_leaderboard = get_node_or_null("MainLayout/VBox/ContentHBox/LeftCol/VBox/TacticalMenuVBox/BtnLeaderboard") as Button

	if btn_gunsmith and not btn_gunsmith.pressed.is_connected(_open_gunsmith):
		btn_gunsmith.pressed.connect(_open_gunsmith)
	if btn_callsign and not btn_callsign.pressed.is_connected(_open_callsign):
		btn_callsign.pressed.connect(_open_callsign)
	if btn_barracks and not btn_barracks.pressed.is_connected(_open_barracks):
		btn_barracks.pressed.connect(_open_barracks)
	if btn_leaderboard and not btn_leaderboard.pressed.is_connected(_open_leaderboard):
		btn_leaderboard.pressed.connect(_open_leaderboard)

# ── VOTAÇÃO & ALTERNÂNCIA DE MAPAS ───────────────────────────────────────────
func _init_map_selection() -> void:
	_update_map_card_display()

func _on_vote_map() -> void:
	player_voted_idx = 1 if player_voted_idx == 0 else 0
	current_map_idx = player_voted_idx

	var sel_map = MAP_OPTIONS[current_map_idx]
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.target_map_path = sel_map["path"]
		gm.target_map_display_name = sel_map["name"]

	_update_map_card_display()

	if is_online_session:
		var nm = get_node_or_null("/root/NetworkManager")
		if nm and multiplayer.is_server():
			nm.rpc("rpc_host_vote_map", current_map_idx)

func _update_map_card_display() -> void:
	var sel_map = MAP_OPTIONS[current_map_idx]
	var other_map = MAP_OPTIONS[1 - current_map_idx]

	if lbl_map_name:
		lbl_map_name.text = sel_map["name"].to_upper()
	if lbl_map_votes:
		lbl_map_votes.text = "Votos: %d (Seu Voto: ✔)" % [sel_map["votes"] + 1]
	if btn_vote_map:
		btn_vote_map.text = "✔ VOTAR EM %s" % other_map["short_name"].to_upper()
	if img_map_preview and ResourceLoader.exists(sel_map["preview"]):
		img_map_preview.texture = load(sel_map["preview"])
	if lbl_bottom_ticker:
		lbl_bottom_ticker.text = "Lobby tático pronto • Operador conectado em %s" % sel_map["name"]

# ── PREPARAÇÃO DA FILA DE BOTS ───────────────────────────────────────────────
func _prepare_bot_queue(count: int) -> void:
	var pool_alpha = [
		"Ghost", "Soap", "Price", "Roach", "Gaz", "Griggs",
		"Sandman", "Frost", "Yuri", "Kamal", "Overlord", "Ozone"
	]
	var pool_bravo = [
		"Woods", "Mason", "Reznov", "Bowman", "Weaver", "Hudson",
		"Dragovich", "Kravchenko", "Steiner", "Menendez", "Salazar", "Harper"
	]

	bots_to_add.clear()
	var alpha_bot_count = 0
	var bravo_bot_count = 0

	var gm = get_node_or_null("/root/GameManager")
	var is_all_enemies = false
	if gm:
		if gm.bot_distribution == gm.BotDistribution.ALL_ENEMIES or gm.selected_game_mode == "pve":
			is_all_enemies = true

	# O jogador humano inicia na equipe ALPHA (Time 0).
	# alpha_total_players inclui o jogador humano (1) + bots adicionados ao Alpha.
	# bravo_total_players inclui bots adicionados ao Bravo.
	var alpha_total_players = 1
	var bravo_total_players = 0

	for i in range(count):
		var is_alpha = false
		if is_all_enemies:
			is_alpha = false
		else:
			# Balanceamento tático dinâmico:
			# Se Alpha tiver mais que Bravo, o bot VAI PARA BRAVO (inimigo).
			# Se Alpha e Bravo estiverem empatados, o bot vai para BRAVO (inimigo),
			# garantindo que o jogador sempre enfrente número justo e equilibrado de oponentes!
			if alpha_total_players <= bravo_total_players:
				is_alpha = true
			else:
				is_alpha = false

		if is_alpha:
			alpha_total_players += 1
		else:
			bravo_total_players += 1

		var b_name = pool_alpha[alpha_bot_count % pool_alpha.size()] if is_alpha else pool_bravo[bravo_bot_count % pool_bravo.size()]
		var r_data = RANKS[i % RANKS.size()]
		var c_tag = CLAN_TAGS[i % CLAN_TAGS.size()]
		var ping = randi_range(14, 38)
		var bot_id = (100 + alpha_bot_count + 1) if is_alpha else (200 + bravo_bot_count + 1)
		if is_alpha:
			alpha_bot_count += 1
		else:
			bravo_bot_count += 1

		bots_to_add.append({
			"id": bot_id,
			"name": b_name,
			"tag": c_tag,
			"team": 0 if is_alpha else 1,
			"team_name": "ALPHA" if is_alpha else "BRAVO",
			"rank_icon": r_data["icon"],
			"level": r_data["lvl"],
			"rank_color": r_data["color"],
			"ping": "%dms" % ping,
			"is_local": false
		})

# ── CONSTRUÇÃO DA LISTA DE JOGADORES ─────────────────────────────────────────
func _build_initial_player_list() -> void:
	added_players.clear()

	var gm = get_node_or_null("/root/GameManager")
	var p_name = gm.local_player_name if (gm and not gm.local_player_name.is_empty()) else "Operador_Alpha"
	var p_lvl = gm.xp_system.current_level if (gm and gm.xp_system) else 1
	var p_prestige = gm.xp_system.current_prestige if (gm and gm.xp_system) else 0
	var r_tag = gm.xp_system.get_rank_tag(p_lvl, p_prestige) if (gm and gm.xp_system) else "[PVT 1]"
	var r_icon = gm.xp_system.get_rank_icon(p_lvl, p_prestige) if (gm and gm.xp_system) else "★"
	var r_color = gm.xp_system.get_rank_color(p_lvl, p_prestige) if (gm and gm.xp_system) else Color(1.0, 0.8, 0.2)

	added_players.append({
		"id": 1,
		"name": p_name,
		"tag": r_tag,
		"team": 0,
		"team_name": "ALPHA",
		"rank_icon": r_icon,
		"level": p_lvl,
		"rank_color": r_color,
		"ping": "5ms",
		"is_local": true
	})

	# Preencher imediatamente com todos os bots táticos da partida
	if not is_online_session:
		for b in bots_to_add:
			added_players.append(b)
		bots_to_add.clear()

	_render_player_rows()

func _render_player_rows() -> void:
	if not vbox_players: return

	for child in vbox_players.get_children():
		child.queue_free()

	for p in added_players:
		var row = _create_player_row(p)
		if row:
			vbox_players.add_child(row)

	var remaining = total_lobby_slots - added_players.size()
	for i in range(remaining):
		var search_row = _create_searching_row(i)
		if search_row:
			vbox_players.add_child(search_row)

	if lbl_player_count:
		lbl_player_count.text = "%d/%d JOGADORES" % [added_players.size(), total_lobby_slots]

# CORREÇÃO CRÍTICA: Safe typing e conversão estrita int/String
func _create_player_row(p: Dictionary) -> PanelContainer:
	var is_local: bool = bool(p.get("is_local", false))
	var team_val: int = int(p.get("team", 0))
	var is_alpha: bool = (team_val == 0 or str(p.get("team_name", "")).to_upper() == "ALPHA")

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.16, 0.9) if not is_local else Color(0.18, 0.14, 0.06, 0.95)
	style.border_width_left = 3
	style.border_color = Color(1.0, 0.75, 0.2, 1.0) if is_local else (Color(0.2, 0.75, 1.0, 0.8) if is_alpha else Color(1.0, 0.35, 0.3, 0.8))
	style.corner_radius_top_left = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	# 1. Ícone de Microfone / Som
	var mic_lbl = Label.new()
	mic_lbl.text = "🔊"
	mic_lbl.modulate = Color(0.85, 0.9, 1.0, 0.9)
	hbox.add_child(mic_lbl)

	# 2. Tag de Clã
	var tag_lbl = Label.new()
	tag_lbl.text = str(p.get("tag", "[TF141]"))
	tag_lbl.modulate = Color(0.3, 0.85, 1.0, 1.0) if is_alpha else Color(1.0, 0.6, 0.3, 1.0)
	tag_lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(tag_lbl)

	# 3. Nome do Jogador
	if is_local:
		var name_edit = LineEdit.new()
		name_edit.text = str(p.get("name", "Operador"))
		name_edit.placeholder_text = "Seu Nome..."
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_edit.add_theme_font_size_override("font_size", 15)
		name_edit.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
		var le_style = StyleBoxFlat.new()
		le_style.bg_color = Color(0, 0, 0, 0.35)
		le_style.border_width_bottom = 1
		le_style.border_color = Color(1.0, 0.85, 0.3, 0.7)
		le_style.corner_radius_top_left = 3
		le_style.corner_radius_top_right = 3
		le_style.set_content_margin_all(4)
		name_edit.add_theme_stylebox_override("normal", le_style)
		name_edit.text_changed.connect(func(new_text: String):
			var final_val = new_text.strip_edges()
			if final_val.is_empty():
				final_val = "Operador"
			p["name"] = final_val
			var gm_inst = get_node_or_null("/root/GameManager")
			if gm_inst:
				gm_inst.local_player_name = final_val
		)
		hbox.add_child(name_edit)
	else:
		var name_lbl = Label.new()
		name_lbl.text = str(p.get("name", "Operador"))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.modulate = Color(0.95, 0.95, 0.95, 1.0)
		hbox.add_child(name_lbl)

	# 4. Ícone de Patente / Prestígio & Nível
	var rank_lbl = Label.new()
	rank_lbl.text = "%s %d" % [str(p.get("rank_icon", "★")), int(p.get("level", 1))]
	rank_lbl.modulate = p.get("rank_color", Color(1.0, 0.8, 0.2))
	rank_lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(rank_lbl)

	# 5. Ping
	var ping_lbl = Label.new()
	ping_lbl.text = str(p.get("ping", "25ms"))
	ping_lbl.modulate = Color(0.3, 0.9, 0.4, 0.8)
	ping_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(ping_lbl)

	# 6. Status de Pronto (Ready Badge estilo CoD)
	var is_ready = bool(p.get("is_ready", false))
	var ready_lbl = Label.new()
	ready_lbl.text = "✔ PRONTO" if is_ready else "⏳ PREPARANDO..."
	ready_lbl.modulate = Color(0.2, 1.0, 0.4, 1.0) if is_ready else Color(1.0, 0.75, 0.2, 0.8)
	ready_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(ready_lbl)

	return panel

func _create_searching_row(_idx: int) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.09, 0.5)
	style.border_width_left = 1
	style.border_color = Color(0.2, 0.25, 0.35, 0.4)
	style.corner_radius_top_left = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	var search_lbl = Label.new()
	if is_online_session:
		search_lbl.text = "Aguardando adversário... Compartilhe o Código da Sala!"
	else:
		search_lbl.text = "Procurando operadores..."
	search_lbl.modulate = Color(0.45, 0.52, 0.65, 0.65)
	search_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(search_lbl)

	var star_lbl = Label.new()
	star_lbl.text = "🎮" if is_online_session else "★"
	star_lbl.modulate = Color(0.35, 0.45, 0.6, 0.6)
	hbox.add_child(star_lbl)

	return panel

# ── LOOP PRINCIPAL DO MATCHMAKING ────────────────────────────────────────────
func _process(delta: float) -> void:
	if copy_feedback_timer > 0.0:
		copy_feedback_timer -= delta
		if copy_feedback_timer <= 0.0 and btn_copy_code:
			btn_copy_code.text = "📋 COPIAR"

	if is_online_session:
		return

	if bots_to_add.size() > 0:
		bot_spawn_timer += delta
		if bot_spawn_timer >= 0.28:
			bot_spawn_timer = 0.0
			var next_bot = bots_to_add.pop_front()
			added_players.append(next_bot)
			_render_player_rows()

			if lbl_status_header:
				var need = total_lobby_slots - added_players.size()
				if need > 0 and bots_to_add.size() > 0:
					lbl_status_header.text = "Conectando operadores táticos (%d restantes)..." % need
				else:
					lbl_status_header.text = "Lobby completo! Iniciando partida..."
	else:
		if not is_starting:
			countdown_seconds -= delta
			var sec_int = int(ceil(countdown_seconds))
			if lbl_status_header:
				lbl_status_header.text = "A PARTIDA COMEÇA EM: %d" % max(0, sec_int)

			if countdown_seconds <= 0.0:
				_start_loading()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			if modal_layer and modal_layer.visible:
				_close_modal()
			elif social_modal and social_modal.visible:
				social_modal.close()
			else:
				_on_back_pressed()
		elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			if not (modal_layer and modal_layer.visible) and not (social_modal and social_modal.visible):
				_on_force_start()
		elif event.keycode == KEY_C:
			if not (modal_layer and modal_layer.visible) and not (social_modal and social_modal.visible):
				_open_gunsmith()
		elif event.keycode == KEY_F2 or event.keycode == KEY_O:
			_on_social_hub_pressed()

func _on_force_start() -> void:
	if is_starting: return

	if is_online_session:
		var gm = get_node_or_null("/root/GameManager")
		var nm = get_node_or_null("/root/NetworkManager")
		if nm and gm:
			if gm.play_mode == gm.PlayMode.ONLINE_HOST:
				var sel_map = MAP_OPTIONS[current_map_idx]
				nm.launch_match_from_lobby(sel_map["path"], sel_map["name"])
			else:
				var my_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 2
				local_is_ready = not local_is_ready
				if btn_force_start:
					btn_force_start.text = "✖ CANCELAR PRONTO" if local_is_ready else "✔ ESTOU PRONTO"
				nm.rpc("rpc_set_lobby_ready", my_id, local_is_ready)
		return

	_start_loading()

func _start_loading() -> void:
	is_starting = true
	set_process(false)
	print("[LobbyScreen] Transição para Tela de Carregamento com Barra de Progresso!")

	var gm = get_node_or_null("/root/GameManager")
	if gm:
		var full_roster: Array[Dictionary] = []
		for p in added_players:
			full_roster.append(p)
		for b in bots_to_add:
			full_roster.append(b)
		gm.lobby_roster = full_roster

		var score_lim = 25
		if gm.selected_game_mode == "1v1" or gm.bot_count <= 2:
			score_lim = 10
		elif gm.selected_game_mode == "pve":
			score_lim = 25
		elif gm.bot_count > 6:
			score_lim = 50

		var mode_enum = GameModeManager.GameMode.TDM_6V6
		var match_stake: float = 0.0
		
		if is_online_session:
			if gm.online_stake > 0.0:
				mode_enum = GameModeManager.GameMode.WAGER_1V1
				match_stake = gm.online_stake
			else:
				mode_enum = GameModeManager.GameMode.CASUAL_1V1
		else:
			# Modo de Treino com Bots: nunca aposta monetária, sempre seguro
			match_stake = 0.0
			if gm.selected_game_mode == "1v1":
				mode_enum = GameModeManager.GameMode.CASUAL_1V1
			elif gm.selected_game_mode == "pve":
				mode_enum = GameModeManager.GameMode.PVE_BOTS_ARENA
			else:
				mode_enum = GameModeManager.GameMode.TDM_6V6

		gm.pending_match_mode = mode_enum
		gm.pending_score_limit = score_lim
		gm.pending_stake = match_stake

		var nm = get_node_or_null("/root/NetworkManager")
		if nm:
			nm.target_kills = score_lim

		gm.is_match_active = false
		gm.match_time_elapsed = 0.0
		gm.set_state(gm.GameState.LOADING)

	get_tree().change_scene_to_file("res://scenes/ui/loading_screen.tscn")

func _on_back_pressed() -> void:
	if is_online_session:
		var nm = get_node_or_null("/root/NetworkManager")
		if nm:
			nm._cleanup_network()
			nm.is_in_lobby = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

# ═════════════════════════════════════════════════════════════════════════════
# SISTEMA DE MODAIS TÁTICOS (GUNSMITH, CALLSIGN, BARRACKS, LEADERBOARD)
# ═════════════════════════════════════════════════════════════════════════════

func _close_modal() -> void:
	if modal_layer:
		for child in modal_layer.get_children():
			child.queue_free()
		modal_layer.visible = false

func _create_modal_base(title: String, subtitle: String, width: float = 980, height: float = 620) -> Dictionary:
	_ensure_modal_layer()
	_close_modal()
	modal_layer.visible = true

	# Backdrop escurecido
	var bg_dim = ColorRect.new()
	bg_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_dim.color = Color(0.02, 0.03, 0.05, 0.88)
	modal_layer.add_child(bg_dim)

	# Painel Central Estilizado
	var panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -width / 2.0
	panel.offset_top = -height / 2.0
	panel.offset_right = width / 2.0
	panel.offset_bottom = height / 2.0

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.75, 0.2, 0.85)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.shadow_color = Color(0, 0, 0, 0.75)
	style.shadow_size = 24
	panel.add_theme_stylebox_override("panel", style)
	modal_layer.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(main_vbox)

	# Cabeçalho
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var titles_vbox = VBoxContainer.new()
	titles_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(titles_vbox)

	var lbl_title = Label.new()
	lbl_title.text = title
	lbl_title.add_theme_font_size_override("font_size", 20)
	lbl_title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2, 1.0))
	titles_vbox.add_child(lbl_title)

	var lbl_sub = Label.new()
	lbl_sub.text = subtitle
	lbl_sub.add_theme_font_size_override("font_size", 12)
	lbl_sub.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0, 1.0))
	titles_vbox.add_child(lbl_sub)

	var btn_close = Button.new()
	btn_close.text = " ✕ "
	btn_close.custom_minimum_size = Vector2(36, 32)
	btn_close.pressed.connect(_close_modal)
	header_hbox.add_child(btn_close)

	var sep = HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.2)
	main_vbox.add_child(sep)

	var content_box = VBoxContainer.new()
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 10)
	main_vbox.add_child(content_box)

	return {
		"backdrop": bg_dim,
		"panel": panel,
		"content": content_box,
		"close_btn": btn_close,
		"main_vbox": main_vbox
	}

# ── 1. MODAL GUNSMITH / ARSENAL TÁTICO (CREATE-A-CLASS) ─────────────────────────
var choose_class_screen: Node = null

func _open_gunsmith() -> void:
	if not choose_class_screen:
		var scr = load("res://scripts/ui/choose_class_screen.gd")
		if scr:
			choose_class_screen = scr.new()
			choose_class_screen.class_selected.connect(_on_class_screen_selected_lobby)
			add_child(choose_class_screen)
	if choose_class_screen:
		choose_class_screen.open_screen(false)

func _on_class_screen_selected_lobby(class_data: Dictionary) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if class_data.has("primary"):
			gm.primary_weapon_res = class_data["primary"]
		if class_data.has("secondary"):
			gm.secondary_weapon_res = class_data["secondary"]
		if class_data.has("melee"):
			gm.melee_weapon_res = class_data["melee"]
		if class_data.has("camo"):
			gm.primary_camo = class_data["camo"]
		if class_data.has("optic"):
			gm.primary_optic = class_data["optic"]
		if class_data.has("muzzle"):
			gm.primary_muzzle = class_data["muzzle"]
		if class_data.has("mag"):
			gm.primary_mag = class_data["mag"]
		if class_data.has("faction") and class_data.has("skin_id"):
			gm.set_character_skin(class_data["faction"], class_data["skin_id"])
		gm.set_equipment_and_perks(
			class_data.get("lethal", "semtex"),
			class_data.get("tactical", "stim"),
			class_data.get("perk1", "flak_jacket"),
			class_data.get("perk2", "tracker"),
			class_data.get("perk3", "high_alert"),
			class_data.get("specialty", "recon")
		)



# ── 2. MODAL CALLSIGN & EMBLEMA ──────────────────────────────────────────────
func _open_callsign() -> void:
	var modal = _create_modal_base("🎖️ IDENTIDADE OPERACIONAL — CALLSIGN & EMBLEMA", "PERSONALIZE SUA TAG DE CLÃ, NOME E CARTÃO DE VISITAS TÁTICO", 850, 540)
	var content = modal["content"] as VBoxContainer
	var gm = get_node_or_null("/root/GameManager")

	var current_name = gm.local_player_name if gm else "Operador_Alpha"
	var current_tag = local_clan_tag

	var preview_card = PanelContainer.new()
	preview_card.custom_minimum_size = Vector2(0, 90)
	var st_card = StyleBoxFlat.new()
	st_card.bg_color = Color(0.12, 0.16, 0.24, 0.95)
	st_card.border_width_left = 4
	st_card.border_color = Color(1.0, 0.75, 0.2, 1.0)
	st_card.corner_radius_top_left = 6
	st_card.corner_radius_top_right = 6
	st_card.corner_radius_bottom_right = 6
	st_card.corner_radius_bottom_left = 6
	preview_card.add_theme_stylebox_override("panel", st_card)
	content.add_child(preview_card)

	var card_margin = MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 20)
	card_margin.add_theme_constant_override("margin_right", 20)
	card_margin.add_theme_constant_override("margin_top", 14)
	card_margin.add_theme_constant_override("margin_bottom", 14)
	preview_card.add_child(card_margin)

	var card_hbox = HBoxContainer.new()
	card_hbox.add_theme_constant_override("separation", 16)
	card_margin.add_child(card_hbox)

	var lbl_card_icon = Label.new()
	lbl_card_icon.text = "★"
	lbl_card_icon.add_theme_font_size_override("font_size", 36)
	lbl_card_icon.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1.0))
	card_hbox.add_child(lbl_card_icon)

	var card_vbox = VBoxContainer.new()
	card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_hbox.add_child(card_vbox)

	var lbl_card_name = Label.new()
	lbl_card_name.text = "%s %s" % [current_tag, current_name]
	lbl_card_name.add_theme_font_size_override("font_size", 22)
	lbl_card_name.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
	card_vbox.add_child(lbl_card_name)

	var lbl_card_sub = Label.new()
	lbl_card_sub.text = "CALLING CARD • SOLANA WAGER VAULT VETERAN"
	lbl_card_sub.add_theme_font_size_override("font_size", 12)
	lbl_card_sub.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0, 1.0))
	card_vbox.add_child(lbl_card_sub)

	# Seção de Entrada de Dados
	var form_grid = GridContainer.new()
	form_grid.columns = 2
	form_grid.add_theme_constant_override("h_separation", 16)
	form_grid.add_theme_constant_override("v_separation", 12)
	content.add_child(form_grid)

	# Tag de Clã
	var lbl_tag_title = Label.new()
	lbl_tag_title.text = "TAG DE CLÃ (MAX 6 CARACTERES):"
	lbl_tag_title.add_theme_font_size_override("font_size", 13)
	form_grid.add_child(lbl_tag_title)

	# Nome
	var lbl_name_title = Label.new()
	lbl_name_title.text = "NOME DO OPERADOR (CALLSIGN):"
	lbl_name_title.add_theme_font_size_override("font_size", 13)
	form_grid.add_child(lbl_name_title)

	var edit_tag = LineEdit.new()
	edit_tag.text = current_tag
	edit_tag.custom_minimum_size = Vector2(240, 38)
	form_grid.add_child(edit_tag)

	var edit_name = LineEdit.new()
	edit_name.text = current_name
	edit_name.custom_minimum_size = Vector2(360, 38)
	form_grid.add_child(edit_name)

	var _refresh_card = func():
		var t = edit_tag.text.strip_edges()
		if not t.begins_with("["): t = "[" + t
		if not t.ends_with("]"): t = t + "]"
		var n = edit_name.text.strip_edges()
		if n.is_empty(): n = "Operador"
		lbl_card_name.text = "%s %s" % [t, n]

	edit_tag.text_changed.connect(func(_t): _refresh_card.call())
	edit_name.text_changed.connect(func(_t): _refresh_card.call())

	# Presets de Tags de Clã
	var quick_tags_box = HBoxContainer.new()
	quick_tags_box.add_theme_constant_override("separation", 8)
	content.add_child(quick_tags_box)

	var lbl_quick = Label.new()
	lbl_quick.text = "TAGS RÁPIDAS:"
	lbl_quick.add_theme_font_size_override("font_size", 12)
	quick_tags_box.add_child(lbl_quick)

	for q_tag in ["[TF141]", "[DELTA]", "[GHOST]", "[SOL]", "[SAS]"]:
		var q_btn = Button.new()
		q_btn.text = q_tag
		q_btn.custom_minimum_size = Vector2(70, 32)
		q_btn.pressed.connect(func():
			edit_tag.text = q_tag
			_refresh_card.call()
		)
		quick_tags_box.add_child(q_btn)

	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	content.add_child(footer)

	var btn_cancel = Button.new()
	btn_cancel.text = "← CANCELAR"
	btn_cancel.custom_minimum_size = Vector2(160, 42)
	btn_cancel.pressed.connect(_close_modal)
	footer.add_child(btn_cancel)

	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(sp)

	var btn_confirm = Button.new()
	btn_confirm.text = "✔ APLICAR IDENTIDADE"
	btn_confirm.custom_minimum_size = Vector2(260, 42)
	var st_btn = StyleBoxFlat.new()
	st_btn.bg_color = Color(1.0, 0.72, 0.15, 1.0)
	st_btn.corner_radius_top_left = 4
	st_btn.corner_radius_top_right = 4
	st_btn.corner_radius_bottom_right = 4
	st_btn.corner_radius_bottom_left = 4
	btn_confirm.add_theme_stylebox_override("normal", st_btn)
	btn_confirm.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05, 1.0))
	btn_confirm.pressed.connect(func():
		var final_tag = edit_tag.text.strip_edges()
		if not final_tag.begins_with("["): final_tag = "[" + final_tag
		if not final_tag.ends_with("]"): final_tag = final_tag + "]"
		var final_name = edit_name.text.strip_edges()
		if final_name.is_empty(): final_name = "Operador"

		local_clan_tag = final_tag
		if gm:
			gm.local_player_name = final_name

		if added_players.size() > 0:
			added_players[0]["tag"] = local_clan_tag
			added_players[0]["name"] = final_name
			_render_player_rows()

		_close_modal()
	)
	footer.add_child(btn_confirm)

# ── 3. MODAL QUARTEL / BARRACKS ──────────────────────────────────────────────
func _open_barracks() -> void:
	var modal = _create_modal_base("🏛️ QUARTEL GENERAL — REGISTRO DE SERVIÇO & CARREIRA", "HISTÓRICO MILITAR, ESTATÍSTICAS DE COMBATE E PROGRESSÃO DE PATENTE", 920, 600)
	var content = modal["content"] as VBoxContainer
	var gm = get_node_or_null("/root/GameManager")

	var lvl = gm.xp_system.current_level if (gm and gm.xp_system) else 1
	var prestige = gm.xp_system.current_prestige if (gm and gm.xp_system) else 0
	var xp_cur = gm.xp_system.current_xp if (gm and gm.xp_system) else 0
	var xp_need = gm.xp_system._get_xp_for_next_level() if (gm and gm.xp_system) else 1000
	var r_title = gm.xp_system.get_rank_title(lvl, prestige) if (gm and gm.xp_system) else "RECRUTA"
	var r_tag = gm.xp_system.get_rank_tag(lvl, prestige) if (gm and gm.xp_system) else "[PVT 1]"
	var r_icon = gm.xp_system.get_rank_icon(lvl, prestige) if (gm and gm.xp_system) else "★"
	var r_color = gm.xp_system.get_rank_color(lvl, prestige) if (gm and gm.xp_system) else Color(1.0, 0.8, 0.2)

	var split_hbox = HBoxContainer.new()
	split_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_hbox.add_theme_constant_override("separation", 24)
	content.add_child(split_hbox)

	# COLUNA ESQUERDA: PATENTE, INSÍGNIA E PRESTÍGIO
	var left_panel = PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(380, 0)
	var st_p = StyleBoxFlat.new()
	st_p.bg_color = Color(0.08, 0.11, 0.16, 0.85)
	st_p.border_width_left = 3
	st_p.border_color = r_color
	st_p.corner_radius_top_left = 6
	st_p.corner_radius_top_right = 6
	st_p.corner_radius_bottom_right = 6
	st_p.corner_radius_bottom_left = 6
	left_panel.add_theme_stylebox_override("panel", st_p)
	split_hbox.add_child(left_panel)

	var left_margin = MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 20)
	left_margin.add_theme_constant_override("margin_right", 20)
	left_margin.add_theme_constant_override("margin_top", 16)
	left_margin.add_theme_constant_override("margin_bottom", 16)
	left_panel.add_child(left_margin)

	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 10)
	left_margin.add_child(left_vbox)

	var rank_icon_lbl = Label.new()
	rank_icon_lbl.text = r_icon
	rank_icon_lbl.add_theme_font_size_override("font_size", 54)
	rank_icon_lbl.add_theme_color_override("font_color", r_color)
	rank_icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(rank_icon_lbl)

	var rank_title_lbl = Label.new()
	rank_title_lbl.text = r_title
	rank_title_lbl.add_theme_font_size_override("font_size", 16)
	rank_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
	rank_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(rank_title_lbl)

	var rank_info_lbl = Label.new()
	if prestige >= 10 and lvl >= 56:
		rank_info_lbl.text = "%s  •  MESTRE DO PRESTÍGIO NÍVEL %d" % [r_tag, lvl]
	elif prestige > 0:
		rank_info_lbl.text = "%s  •  PRESTÍGIO %d (NÍVEL %d)" % [r_tag, prestige, lvl]
	else:
		rank_info_lbl.text = "%s  •  NÍVEL MILITAR %d / 55" % [r_tag, lvl]
	rank_info_lbl.add_theme_font_size_override("font_size", 13)
	rank_info_lbl.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0, 1.0))
	rank_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(rank_info_lbl)

	var sep_bar = HSeparator.new()
	sep_bar.modulate = Color(1, 1, 1, 0.2)
	left_vbox.add_child(sep_bar)

	var lbl_xp_title = Label.new()
	lbl_xp_title.text = "PROGRESSÃO DE EXPERIÊNCIA (XP):"
	lbl_xp_title.add_theme_font_size_override("font_size", 12)
	lbl_xp_title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2, 1.0))
	left_vbox.add_child(lbl_xp_title)

	var xp_bar = ProgressBar.new()
	xp_bar.min_value = 0
	xp_bar.max_value = max(1, xp_need)
	xp_bar.value = xp_cur
	xp_bar.custom_minimum_size = Vector2(0, 24)
	left_vbox.add_child(xp_bar)

	var pct = float(xp_cur) / float(max(1, xp_need)) * 100.0
	var lbl_xp_vals = Label.new()
	lbl_xp_vals.text = "%d / %d XP (%d%%)" % [xp_cur, xp_need, int(pct)]
	lbl_xp_vals.add_theme_font_size_override("font_size", 13)
	lbl_xp_vals.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(lbl_xp_vals)

	# Botão de Prestígio estilo Call of Duty (disponível quando atinge nível 55 max)
	if gm and gm.xp_system and (lvl >= 55 or prestige > 0):
		var btn_prestige = Button.new()
		if lvl >= 55:
			btn_prestige.text = "🎖️ ENTRAR NO PRESTÍGIO %d" % (prestige + 1)
			btn_prestige.modulate = Color(1.0, 0.85, 0.2)
		else:
			btn_prestige.text = "🔒 PRESTÍGIO (REQUER NÍVEL 55)"
			btn_prestige.disabled = true
			btn_prestige.modulate = Color(0.6, 0.6, 0.6, 0.8)
		btn_prestige.custom_minimum_size = Vector2(0, 38)
		btn_prestige.pressed.connect(func():
			if gm and gm.xp_system and lvl >= 55:
				gm.xp_system.do_prestige()
				_close_modal()
				_open_barracks()
		)
		left_vbox.add_child(btn_prestige)

	# COLUNA DIREITA: REGISTRO DE COMBATE & TELEMETRIA DE PRECISÃO
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 12)
	split_hbox.add_child(right_vbox)

	var lbl_stats_title = Label.new()
	lbl_stats_title.text = "REGISTRO DE COMBATE // TELEMETRIA DE CARREIRA:"
	lbl_stats_title.add_theme_font_size_override("font_size", 14)
	lbl_stats_title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2, 1.0))
	right_vbox.add_child(lbl_stats_title)

	var cr = gm.combat_record.career_stats if (gm and gm.combat_record) else {}
	var kills = int(cr.get("total_kills", gm.player_stats.get("kills", 0)))
	var deaths = int(cr.get("total_deaths", gm.player_stats.get("deaths", 0)))
	var kd = float(cr.get("career_kd", float(kills) / maxf(1.0, float(deaths))))
	var headshots = int(cr.get("total_headshots", gm.player_stats.get("headshots", 0)))
	var hs_pct = float(cr.get("career_headshot_pct", 0.0))
	var crouch_kills = int(cr.get("total_crouch_kills", gm.player_stats.get("crouch_kills", 0)))
	var acc_pct = float(cr.get("career_accuracy_pct", gm.player_stats.get("accuracy", 0.0)))
	var streak = int(cr.get("highest_killstreak", 0))
	var spm = float(cr.get("career_spm", 0.0))
	var wl = float(cr.get("win_loss_ratio", 0.0))

	var stats_grid = GridContainer.new()
	stats_grid.columns = 3
	stats_grid.add_theme_constant_override("h_separation", 10)
	stats_grid.add_theme_constant_override("v_separation", 8)
	right_vbox.add_child(stats_grid)

	var make_stat_card = func(card_label: String, val_str: String):
		var p_card = PanelContainer.new()
		var sc = StyleBoxFlat.new()
		sc.bg_color = Color(0.1, 0.13, 0.18, 0.8)
		sc.corner_radius_top_left = 4
		sc.corner_radius_top_right = 4
		sc.corner_radius_bottom_right = 4
		sc.corner_radius_bottom_left = 4
		p_card.add_theme_stylebox_override("panel", sc)
		var mg = MarginContainer.new()
		mg.add_theme_constant_override("margin_left", 12)
		mg.add_theme_constant_override("margin_right", 12)
		mg.add_theme_constant_override("margin_top", 8)
		mg.add_theme_constant_override("margin_bottom", 8)
		p_card.add_child(mg)
		var vb = VBoxContainer.new()
		mg.add_child(vb)
		var l1 = Label.new()
		l1.text = card_label
		l1.add_theme_font_size_override("font_size", 11)
		l1.modulate = Color(0.65, 0.75, 0.88, 1.0)
		vb.add_child(l1)
		var l2 = Label.new()
		l2.text = val_str
		l2.add_theme_font_size_override("font_size", 16)
		l2.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
		vb.add_child(l2)
		return p_card

	stats_grid.add_child(make_stat_card.call("TOTAL ABATES", str(kills)))
	stats_grid.add_child(make_stat_card.call("TOTAL MORTES", str(deaths)))
	stats_grid.add_child(make_stat_card.call("RAZÃO K/D", "%.2f" % kd))
	stats_grid.add_child(make_stat_card.call("HEADSHOTS", "%d (%.1f%%)" % [headshots, hs_pct]))
	stats_grid.add_child(make_stat_card.call("AGACHADO / SLIDE", str(crouch_kills)))
	stats_grid.add_child(make_stat_card.call("PRECISÃO TIRO", "%.1f%%" % acc_pct))
	stats_grid.add_child(make_stat_card.call("MAIOR SEQUÊNCIA", str(streak)))
	stats_grid.add_child(make_stat_card.call("SPM (PTS/MIN)", "%.0f" % spm))
	stats_grid.add_child(make_stat_card.call("RAZÃO W/L", "%.2f" % wl))

	var sep_weapons = HSeparator.new()
	sep_weapons.modulate = Color(1, 1, 1, 0.2)
	right_vbox.add_child(sep_weapons)

	var lbl_weap_title = Label.new()
	lbl_weap_title.text = "ARSENAL DESBLOQUEADO POR NÍVEL:"
	lbl_weap_title.add_theme_font_size_override("font_size", 13)
	lbl_weap_title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2, 1.0))
	right_vbox.add_child(lbl_weap_title)

	var weapons_list = [
		{"name": "ACR 6.8 (Fuzil de Assalto)", "lvl": 1},
		{"name": "Pistola Tática C19", "lvl": 1},
		{"name": "Faca de Combate Militar", "lvl": 1},
		{"name": "SMG-45 (Submetralhadora)", "lvl": 5},
		{"name": "LMG-63 (Metralhadora Leve)", "lvl": 15},
		{"name": "Escopeta Sawn-Off (Cano Serrado)", "lvl": 25}
	]

	for w in weapons_list:
		var w_hbox = HBoxContainer.new()
		var is_unlocked = (lvl >= w["lvl"])
		var status_icon = Label.new()
		status_icon.text = "✔" if is_unlocked else "🔒"
		status_icon.modulate = Color(0.3, 0.9, 0.4, 1.0) if is_unlocked else Color(0.7, 0.7, 0.7, 0.6)
		w_hbox.add_child(status_icon)
		var w_name_lbl = Label.new()
		w_name_lbl.text = "%s (Nível %d)" % [w["name"], w["lvl"]]
		w_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		w_name_lbl.add_theme_font_size_override("font_size", 12)
		w_name_lbl.modulate = Color(0.95, 0.95, 0.95, 1.0) if is_unlocked else Color(0.6, 0.6, 0.6, 0.6)
		w_hbox.add_child(w_name_lbl)
		right_vbox.add_child(w_hbox)

	var footer = HBoxContainer.new()
	content.add_child(footer)
	var btn_close = Button.new()
	btn_close.text = "← FECHAR REGISTRO DE SERVIÇO"
	btn_close.custom_minimum_size = Vector2(260, 42)
	btn_close.pressed.connect(_close_modal)
	footer.add_child(btn_close)

# ── 4. MODAL PLACAR DO LOBBY ────────────────────────────────────────────────
func _open_leaderboard() -> void:
	var modal = _create_modal_base("📊 VISÃO TÁTICA DA SALA — PLACAR DOS ESQUADRÕES", "DISTRIBUIÇÃO DE FORÇAS: ESQUADRÃO ALPHA VS EQUIPE BRAVO", 960, 580)
	var content = modal["content"] as VBoxContainer

	var split_hbox = HBoxContainer.new()
	split_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_hbox.add_theme_constant_override("separation", 24)
	content.add_child(split_hbox)

	var make_team_column = func(team_name: String, team_title: String, border_col: Color, bg_col: Color):
		var panel = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var st = StyleBoxFlat.new()
		st.bg_color = bg_col
		st.border_width_left = 3
		st.border_color = border_col
		st.corner_radius_top_left = 4
		st.corner_radius_bottom_left = 4
		st.corner_radius_top_right = 4
		st.corner_radius_bottom_right = 4
		panel.add_theme_stylebox_override("panel", st)

		var mg = MarginContainer.new()
		mg.add_theme_constant_override("margin_left", 14)
		mg.add_theme_constant_override("margin_right", 14)
		mg.add_theme_constant_override("margin_top", 12)
		mg.add_theme_constant_override("margin_bottom", 12)
		panel.add_child(mg)

		var vb = VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		mg.add_child(vb)

		var h_lbl = Label.new()
		h_lbl.text = team_title
		h_lbl.add_theme_font_size_override("font_size", 14)
		h_lbl.add_theme_color_override("font_color", border_col)
		vb.add_child(h_lbl)

		var sep = HSeparator.new()
		sep.modulate = Color(1, 1, 1, 0.2)
		vb.add_child(sep)

		var list_scroll = ScrollContainer.new()
		list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(list_scroll)

		var rows_vbox = VBoxContainer.new()
		rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows_vbox.add_theme_constant_override("separation", 6)
		list_scroll.add_child(rows_vbox)

		# Filtrar jogadores deste time (adicionados + fila de bots)
		var all_pl: Array[Dictionary] = []
		for p in added_players: all_pl.append(p)
		for b in bots_to_add: all_pl.append(b)

		for p in all_pl:
			var t_id = int(p.get("team", 0))
			var t_str = str(p.get("team_name", "")).to_upper()
			var match_team = (team_name == "ALPHA" and (t_id == 0 or t_str == "ALPHA")) or (team_name == "BRAVO" and (t_id == 1 or t_str == "BRAVO"))
			if match_team:
				var r_p = PanelContainer.new()
				var r_st = StyleBoxFlat.new()
				r_st.bg_color = Color(0.04, 0.06, 0.09, 0.7)
				r_st.corner_radius_top_left = 3
				r_st.corner_radius_top_right = 3
				r_st.corner_radius_bottom_right = 3
				r_st.corner_radius_bottom_left = 3
				r_p.add_theme_stylebox_override("panel", r_st)

				var r_mg = MarginContainer.new()
				r_mg.add_theme_constant_override("margin_left", 8)
				r_mg.add_theme_constant_override("margin_right", 8)
				r_mg.add_theme_constant_override("margin_top", 4)
				r_mg.add_theme_constant_override("margin_bottom", 4)
				r_p.add_child(r_mg)

				var r_hb = HBoxContainer.new()
				r_hb.add_theme_constant_override("separation", 8)
				r_mg.add_child(r_hb)

				var p_tag = Label.new()
				p_tag.text = str(p.get("tag", "[TF141]"))
				p_tag.add_theme_font_size_override("font_size", 12)
				p_tag.modulate = border_col
				r_hb.add_child(p_tag)

				var p_name = Label.new()
				p_name.text = str(p.get("name", "Operador"))
				p_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				p_name.add_theme_font_size_override("font_size", 13)
				p_name.modulate = Color(1.0, 0.9, 0.4, 1.0) if p.get("is_local", false) else Color(0.9, 0.9, 0.9, 1.0)
				r_hb.add_child(p_name)

				var p_rank = Label.new()
				p_rank.text = "%s %d" % [str(p.get("rank_icon", "★")), int(p.get("level", 1))]
				p_rank.add_theme_font_size_override("font_size", 12)
				p_rank.modulate = p.get("rank_color", Color(1, 0.8, 0.2))
				r_hb.add_child(p_rank)

				var p_ping = Label.new()
				p_ping.text = str(p.get("ping", "20ms"))
				p_ping.add_theme_font_size_override("font_size", 11)
				p_ping.modulate = Color(0.3, 0.9, 0.4, 0.8)
				r_hb.add_child(p_ping)

				rows_vbox.add_child(r_p)

		return panel

	split_hbox.add_child(make_team_column.call("ALPHA", "FORÇA-TAREFA ALPHA (CONTRA-TERRORISTAS)", Color(0.2, 0.8, 1.0, 1.0), Color(0.06, 0.1, 0.16, 0.9)))
	split_hbox.add_child(make_team_column.call("BRAVO", "EQUIPE BRAVO (TERRORISTAS)", Color(1.0, 0.4, 0.2, 1.0), Color(0.16, 0.08, 0.06, 0.9)))

	var footer = HBoxContainer.new()
	content.add_child(footer)
	var btn_ret = Button.new()
	btn_ret.text = "← RETORNAR AO LOBBY"
	btn_ret.custom_minimum_size = Vector2(220, 42)
	btn_ret.pressed.connect(_close_modal)
	footer.add_child(btn_ret)

# ── NAVEGADOR 3D BO3 NO LOBBY ─────────────────────────────────────────────────
var bo3_weapon_browser_lobby: CanvasLayer = null

func _open_bo3_browser_lobby(cur_path: String, on_select_cb: Callable) -> void:
	if not bo3_weapon_browser_lobby:
		var scr = load("res://scripts/ui/bo3_weapon_select_screen.gd")
		if scr:
			bo3_weapon_browser_lobby = scr.new()
			add_child(bo3_weapon_browser_lobby)
	if bo3_weapon_browser_lobby:
		var conn_callable = func(w_path: String, _w_data: WeaponData):
			on_select_cb.call(w_path)
			var gm = get_node_or_null("/root/GameManager")
			if gm:
				gm.primary_weapon_res = w_path
		if bo3_weapon_browser_lobby.weapon_selected.is_connected(conn_callable):
			bo3_weapon_browser_lobby.weapon_selected.disconnect(conn_callable)
		bo3_weapon_browser_lobby.weapon_selected.connect(conn_callable, CONNECT_ONE_SHOT)
		bo3_weapon_browser_lobby.open_screen(0, cur_path)
