# =============================================================================
# network_manager.gd
# Gerenciador de Rede Multiplayer do NUKE (ENet) para Godot 4
# Suporta:
# - Servidor Dedicado Neutro (Headless / Nuvem / Docker) - OPÇÃO A
# - Listen Server (Host local) & Partida Solo com Bots
# - Modos 1v1 Wager (2 jogadores) até 6v6 TDM (12 jogadores)
# - Sincronização em tempo real de Sala / Lobby Pré-Jogo estilo Call of Duty
# - Códigos de Sala amigáveis (Room Codes) e UPnP automático
# - Balanceamento dinâmico de times (Alpha/CT vs Bravo/T)
# - Sincronização e replicação confiável via RPC
# =============================================================================
extends Node

const RoomCodeHelper = preload("res://scripts/network/room_code_helper.gd")

signal match_started
signal score_updated(alpha_kills: int, bravo_kills: int)
signal match_ended(winning_team: int)
signal player_respawned(peer_id: int)
signal stats_updated(player_stats: Dictionary)

# Sinais do Lobby Sincronizado estilo CoD
signal lobby_updated(roster: Array[Dictionary])
signal lobby_player_joined(peer_id: int, player_data: Dictionary)
signal lobby_player_left(peer_id: int)
signal lobby_map_changed(map_idx: int)
signal lobby_match_launching(map_path: String, map_name: String)
signal room_code_created(code: String)

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS_1V1: int = 2
const MAX_PLAYERS_6V6: int = 12

# IP Padrão do Servidor Dedicado na Nuvem (VPS Docker - Opção A)
var dedicated_server_ip: String = "127.0.0.1"

@export var player_scene: PackedScene = preload("res://scenes/player/player.tscn")
@export var spawn_alpha_path: NodePath = "Spawn_Alpha"
@export var spawn_bravo_path: NodePath = "Spawn_Bravo"

# Configuração de Partida
var max_players: int = 12
var target_kills: int = 10  # 10 para 1v1, 50 para 6v6
var is_dedicated: bool = false
var match_active: bool = false

# Estado do Lobby
var is_in_lobby: bool = false
var current_room_code: String = ""
var is_room_host: bool = false
var lobby_roster: Dictionary = {}
var lobby_map_idx: int = 0

# Placar por Equipe (Time Alpha = CT = 0, Time Bravo = T = 1)
var score_alpha: int = 0
var score_bravo: int = 0

# Estatísticas Individuais (K/D, Pontos, Times)
var player_stats: Dictionary = {}

# Gerenciamento de Equipes (Até 6v6)
var team_alpha_peers: Array[int] = []
var team_bravo_peers: Array[int] = []
var host_peer_id: int = 1

var spawn_alpha: Node3D = null
var spawn_bravo: Node3D = null

func _ready() -> void:
	# Se for uma instância secundária dentro do mapa, libera-se e deixa o Autoload global gerenciar
	if get_tree().root.has_node("NetworkManager") and get_tree().root.get_node("NetworkManager") != self:
		print("[NetworkManager] Instância secundária de cena detectada. Usando singleton /root/NetworkManager.")
		queue_free()
		return

	process_mode = Node.PROCESS_MODE_ALWAYS

	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

	# Navegador: rede liberada via WebSocket (cliente). Argumentos de linha de comando não existem no web.
	if OS.has_feature("web"):
		print("[NetworkManager] Plataforma Web detectada. Multiplayer via WebSocket disponível.")
		return

	# Suporte a argumentos de linha de comando
	var args = OS.get_cmdline_args()
	var user_args = OS.get_cmdline_user_args()
	var all_args = args + user_args
	var is_headless = DisplayServer.get_name() == "headless" or "--headless" in all_args

	_parse_game_rules(all_args)

	var is_script_run = "-s" in all_args or "--script" in all_args
	# Modo de teste (QA): --qa-shot=caminho.png salva prints da partida e fecha o jogo
	for a in all_args:
		if str(a).begins_with("--qa-shot="):
			_qa_capture.call_deferred(str(a).trim_prefix("--qa-shot="))
	# --client tem prioridade: permite clientes sem tela (testes automáticos / bots de carga)
	if "--client" in all_args:
		var c_ip = _get_target_ip_from_args(all_args)
		var c_port = _get_port_from_args(all_args)
		call_deferred("join_game", c_ip, c_port)
	elif ("--server" in all_args or "--dedicated" in all_args or (is_headless and not is_script_run)):
		var port = _get_port_from_args(all_args)
		call_deferred("start_dedicated_server", port)
	elif "--host" in all_args:
		var port = _get_port_from_args(all_args)
		call_deferred("start_host", port)
	elif "--client" in all_args:
		var ip = _get_target_ip_from_args(all_args)
		var port = _get_port_from_args(all_args)
		call_deferred("join_game", ip, port)
	else:
		# Se estamos no Menu Principal ou Lobby, apenas aguarda comando do usuário
		var cur_scene = get_tree().current_scene
		var scene_name = cur_scene.name if cur_scene else ""
		if scene_name == "MainMenu" or scene_name == "LobbyScreen" or scene_name == "LoadingScreen" or scene_name == "":
			print("[NetworkManager] Autoload global ativo. Aguardando seleção do operador no menu.")
			return

## QA: espera o jogador local nascer, salva prints (cintura e após 4 s) e um relatório do viewmodel, depois fecha
func _qa_capture(path: String) -> void:
	var t0 := Time.get_ticks_msec()
	var me: Node = null
	while Time.get_ticks_msec() - t0 < 90000:
		await get_tree().create_timer(0.5).timeout
		if multiplayer.has_multiplayer_peer():
			me = get_tree().root.find_child("Player_%d" % multiplayer.get_unique_id(), true, false)
		if me:
			break
	var lines := ["jogador_encontrado=%s" % (me != null)]
	await get_tree().create_timer(6.0).timeout
	get_viewport().get_texture().get_image().save_png(path)
	if me:
		var vm = me.find_child("FpsHandsViewModel", true, false)
		var wm = me.find_child("WeaponManager", true, false)
		lines.append("viewmodel=%s visivel=%s" % [vm != null, vm.is_visible_in_tree() if vm else false])
		if vm:
			lines.append("arma_custom=%s fps_hands=%s" % [vm.get("current_custom_model_instance") != null, vm.get("fps_hands") != null])
		lines.append("weapon_manager=%s" % (wm != null))
		var cam := get_viewport().get_camera_3d()
		lines.append("camera=%s cull_mask=%s" % [cam.get_path() if cam else "nenhuma", cam.cull_mask if cam else 0])
		var hud = get_tree().root.find_child("MPHud", true, false)
		lines.append("hud=%s visivel=%s" % [hud != null, hud.visible if hud and "visible" in hud else "?"])
		var ccs = get_tree().root.find_child("ChooseClassScreen", true, false)
		lines.append("tela_classe=%s aberta=%s" % [ccs != null, ccs.get("is_open") if ccs else "?"])
	var f := FileAccess.open(path.get_basename() + ".txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines))
		f.close()
	get_tree().quit()

func _process(delta: float) -> void:
	_dedicated_heartbeat(delta)

# Pulso do servidor dedicado no log (a cada 5 s): estado da rede e jogadores conectados
var _heartbeat_t: float = 0.0
func _dedicated_heartbeat(delta: float) -> void:
	if not is_dedicated:
		return
	_heartbeat_t += delta
	if _heartbeat_t < 5.0:
		return
	_heartbeat_t = 0.0
	var mp_peer = multiplayer.multiplayer_peer
	var st := "sem peer" if mp_peer == null else ("%s status=%d" % [mp_peer.get_class(), mp_peer.get_connection_status()])
	print("[Servidor] pulso | rede: %s | conectados: %d | alpha=%d bravo=%d" % [st, multiplayer.get_peers().size(), team_alpha_peers.size(), team_bravo_peers.size()])

func _exit_tree() -> void:
	# Só a instância global (/root/NetworkManager) pode fechar a rede.
	# Antes, a cópia que vem dentro da cena do mapa se apagava e derrubava o servidor/cliente.
	if get_tree() and get_tree().root.get_node_or_null("NetworkManager") != self:
		return
	_cleanup_network()

func _cleanup_network() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	cleanup_lingering_players()

## Expulsa quaisquer entidades de jogador ou bot órfãs remanescentes no root
func cleanup_lingering_players() -> void:
	if not get_tree() or not get_tree().root:
		return

	for ch in get_tree().root.get_children():
		if ch is CharacterBody3D and ("Player" in ch.name or "Bot" in ch.name):
			print("[NetworkManager] Limpando entidade órfã de jogador/bot no root: ", ch.name)
			ch.queue_free()

	var cur_scene = get_tree().current_scene
	if cur_scene and not (cur_scene is Node3D):
		var lingering_cams = get_tree().root.find_children("*", "Camera3D", true, false)
		for cam in lingering_cams:
			if cam is Camera3D and cam.current:
				cam.current = false

func _parse_game_rules(args: Array) -> void:
	for arg in args:
		if arg == "--mode=1v1" or arg == "--1v1":
			max_players = MAX_PLAYERS_1V1
			target_kills = 10
		elif arg == "--mode=6v6" or arg == "--6v6" or arg == "--tdm":
			max_players = MAX_PLAYERS_6V6
			target_kills = 50
		elif arg.begins_with("--max-players="):
			var val = arg.trim_prefix("--max-players=").to_int()
			if val > 0: max_players = val
		elif arg.begins_with("--target-kills="):
			var val = arg.trim_prefix("--target-kills=").to_int()
			if val > 0: target_kills = val

func _get_port_from_args(args: Array) -> int:
	for arg in args:
		if arg.begins_with("--port="):
			var p_str = arg.trim_prefix("--port=")
			if p_str.is_valid_int():
				return p_str.to_int()
	return DEFAULT_PORT

func _get_target_ip_from_args(args: Array) -> String:
	for arg in args:
		if arg.begins_with("--server-ip="):
			return arg.trim_prefix("--server-ip=").strip_edges()
		elif arg.begins_with("--ip="):
			return arg.trim_prefix("--ip=").strip_edges()
		elif arg.begins_with("--connect-ip="):
			return arg.trim_prefix("--connect-ip=").strip_edges()
	return "127.0.0.1"

# ── SERVIÇO DE SALAS & CÓDIGOS (ROOM CODE - FASE 2) ──────────────────────────
## Cria uma sala privada como Host, gera o Room Code e abre o Lobby
func create_room(port: int = DEFAULT_PORT) -> String:
	is_in_lobby = true
	is_room_host = true
	max_players = MAX_PLAYERS_1V1

	var actual_port = start_host(port)
	if actual_port <= 0:
		push_error("[NetworkManager] Falha ao criar servidor local na porta %d ou adjacentes." % port)
		return ""

	# Tentar UPnP automático para abrir a porta no roteador (Fase 4 WAN)
	var upnp_data = RoomCodeHelper.try_setup_upnp(actual_port)
	var host_ip = upnp_data.get("external_ip", "")
	if host_ip.is_empty():
		host_ip = RoomCodeHelper.get_local_lan_ip()

	current_room_code = RoomCodeHelper.encode_room_code(host_ip, actual_port)
	print("[NetworkManager] Sala criada com sucesso! CÓDIGO DA SALA: %s (IP Base: %s:%d)" % [current_room_code, host_ip, actual_port])

	# Registrar o Host no Lobby
	lobby_roster.clear()
	var host_data = _build_local_player_data(true)
	host_data["is_host"] = true
	host_data["is_ready"] = true
	host_data["team"] = 0
	host_data["team_name"] = "ALPHA"
	lobby_roster[1] = host_data

	room_code_created.emit(current_room_code)
	lobby_updated.emit(get_lobby_roster_array())

	return current_room_code

## Entra em uma sala existente através de um código ou endereço de IP
func join_room(code_or_ip: String) -> bool:
	is_in_lobby = true
	is_room_host = false
	max_players = MAX_PLAYERS_1V1

	var decoded = RoomCodeHelper.decode_room_code(code_or_ip)
	if not decoded.get("valid", false):
		push_warning("[NetworkManager] Código de sala inválido: %s" % code_or_ip)
		return false

	var target_ip = decoded.get("ip", "127.0.0.1")
	var target_port = decoded.get("port", DEFAULT_PORT)
	current_room_code = code_or_ip.strip_edges().to_upper()

	print("[NetworkManager] Conectando à sala: %s -> %s:%d..." % [code_or_ip, target_ip, target_port])
	return join_game(target_ip, target_port)

## Conecta diretamente ao Servidor Dedicado Neutro (Opção A)
func connect_to_dedicated_server(ip: String = "", port: int = DEFAULT_PORT) -> bool:
	var s_ip = ip if not ip.is_empty() else dedicated_server_ip
	is_in_lobby = false
	is_room_host = false
	print("[NetworkManager] Conectando ao SERVIDOR DEDICADO NEUTRO (Opção A): %s:%d..." % [s_ip, port])
	return join_game(s_ip, port)

func get_lobby_roster_array() -> Array[Dictionary]:
	var arr: Array[Dictionary] = []
	for p_id in lobby_roster.keys():
		arr.append(lobby_roster[p_id])
	return arr

func _build_local_player_data(is_host_flag: bool = false) -> Dictionary:
	var gm = get_node_or_null("/root/GameManager")
	var p_name = gm.local_player_name if (gm and not gm.local_player_name.is_empty()) else "Operador"
	var p_lvl = gm.xp_system.current_level if (gm and gm.xp_system) else 1
	var p_prestige = gm.xp_system.current_prestige if (gm and gm.xp_system) else 0
	var r_tag = gm.xp_system.get_rank_tag(p_lvl, p_prestige) if (gm and gm.xp_system) else "[PVT 1]"
	var r_icon = gm.xp_system.get_rank_icon(p_lvl, p_prestige) if (gm and gm.xp_system) else "★"
	var r_color = gm.xp_system.get_rank_color(p_lvl, p_prestige) if (gm and gm.xp_system) else Color(1.0, 0.8, 0.2)
	var skin = gm.selected_skin_id if gm else "ct_urban"

	return {
		"id": multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else (1 if is_host_flag else 2),
		"name": p_name,
		"tag": r_tag,
		"level": p_lvl,
		"prestige": p_prestige,
		"rank_icon": r_icon,
		"rank_color": r_color,
		"ping": "15ms",
		"is_host": is_host_flag,
		"is_ready": is_host_flag,
		"skin_id": skin,
		"team": 0 if is_host_flag else 1,
		"team_name": "ALPHA" if is_host_flag else "BRAVO"
	}

# ── TRANSPORTE DE REDE ─────────────────────────────────────────────────────────
## WebSocket em todas as plataformas: navegador não abre UDP (ENet), então desktop,
## navegador e servidor dedicado usam o mesmo transporte para jogar juntos.
## Em produção o servidor fica atrás de um proxy TLS (Caddy/Nginx) e o cliente web usa wss://.
const USE_WEBSOCKET := true

func _make_peer() -> MultiplayerPeer:
	if USE_WEBSOCKET:
		return WebSocketMultiplayerPeer.new()
	return ENetMultiplayerPeer.new()

func _peer_create_server(peer: MultiplayerPeer, port: int) -> Error:
	if peer is WebSocketMultiplayerPeer:
		return (peer as WebSocketMultiplayerPeer).create_server(port)
	return (peer as ENetMultiplayerPeer).create_server(port, max_players)

func _peer_create_client(peer: MultiplayerPeer, address: String, port: int) -> Error:
	if peer is WebSocketMultiplayerPeer:
		var url := address
		if not (address.begins_with("ws://") or address.begins_with("wss://")):
			# Página servida por https exige wss://; em LAN/desktop, ws:// direto na porta
			var secure := OS.has_feature("web") and str(JavaScriptBridge.eval("location.protocol", true)) == "https:"
			url = ("wss://%s" % address) if secure else ("ws://%s:%d" % [address, port])
		return (peer as WebSocketMultiplayerPeer).create_client(url)
	return (peer as ENetMultiplayerPeer).create_client(address, port)

# ── INICIALIZAÇÃO DE SERVIDOR / CLIENTE ────────────────────────────────────────
## Inicia o Servidor Dedicado Neutro (Headless / Nuvem / Docker - Opção A)
# ── CLASSE DOS JOGADORES NA REDE (arma + acessórios visíveis em 3ª pessoa) ─────
var peer_loadouts := {}  # peer_id -> {weapon, camo, optic, muzzle, mag, underbarrel, stock, grip}
const LOADOUT_SLOTS := ["optic", "muzzle", "mag", "underbarrel", "stock", "grip"]

## Monta o dicionário da classe local a partir do GameManager
func build_local_loadout() -> Dictionary:
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		return {}
	var d := {"weapon": str(gm.primary_weapon_res), "camo": str(gm.primary_camo)}
	var att: Dictionary = gm.get_primary_attachment_ids() if gm.has_method("get_primary_attachment_ids") else {}
	for k in LOADOUT_SLOTS:
		d[k] = str(att.get(k, "none"))
	return d

## Cliente: envia a própria classe ao servidor (ao entrar no mapa e ao confirmar uma classe)
func submit_local_loadout() -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	var d := build_local_loadout()
	if d.is_empty():
		return
	if multiplayer.is_server():
		_server_accept_loadout(multiplayer.get_unique_id(), d)
	else:
		rpc_id(1, "rpc_submit_loadout", d)

func _sanitize_loadout(d: Dictionary) -> Dictionary:
	var out := {}
	var w := str(d.get("weapon", ""))
	if not (w.begins_with("res://resources/weapons/") and w.ends_with(".tres") and ResourceLoader.exists(w)):
		return {}
	out["weapon"] = w
	out["camo"] = str(d.get("camo", "default")).substr(0, 32)
	for k in LOADOUT_SLOTS:
		var v := str(d.get(k, "none"))
		out[k] = v if (v == "none" or WeaponVisualRegistry.ATTACHMENT_SCENES.has(v)) else "none"
	return out

@rpc("any_peer", "call_remote", "reliable")
func rpc_submit_loadout(d: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	_server_accept_loadout(multiplayer.get_remote_sender_id(), d)

func _server_accept_loadout(pid: int, d: Dictionary) -> void:
	var clean := _sanitize_loadout(d)
	if clean.is_empty():
		return
	peer_loadouts[pid] = clean
	rpc("rpc_apply_peer_loadout", pid, clean)
	rpc_apply_peer_loadout(pid, clean)

## Servidor -> todos: a classe de um jogador (cada cliente atualiza a arma 3ª pessoa dele)
@rpc("authority", "call_remote", "reliable")
func rpc_apply_peer_loadout(pid: int, d: Dictionary) -> void:
	peer_loadouts[pid] = d
	var p = get_tree().root.find_child("Player_%d" % pid, true, false)
	if p and p.has_method("apply_remote_loadout"):
		p.apply_remote_loadout(d)

## Servidor: manda a quem acabou de entrar as classes de quem já estava na partida
func _server_send_known_loadouts(to_pid: int) -> void:
	for pid in peer_loadouts:
		rpc_id(to_pid, "rpc_apply_peer_loadout", pid, peer_loadouts[pid])

# ── MAPA DO SERVIDOR DEDICADO ──────────────────────────────────────────────────
# Mesmos nomes do GameManager: "nuketown_2065" é o BO3 futurista; o clássico (1960) é o do BO1
const DEDICATED_MAPS := {
	"nuketown_2065": "res://scenes/_world/map_nuk3town_bo3.tscn",
	"nuketown_classic": "res://scenes/_world/map_nuketown_1v1.tscn",
	"nuketown_bo1": "res://scenes/_world/map_nuketown_1v1.tscn",
	"bo1": "res://scenes/_world/map_nuketown_1v1.tscn",
	"nuketown_1v1": "res://scenes/_world/map_nuketown_1v1.tscn",
	"nuk3town_bo3": "res://scenes/_world/map_nuk3town_bo3.tscn",
	"bo3": "res://scenes/_world/map_nuk3town_bo3.tscn",
	"firing_range": "res://scenes/_world/map_firing_range.tscn",
}
var dedicated_map_path: String = "res://scenes/_world/map_nuk3town_bo3.tscn" # padrão: Nuketown 2065

func _map_from_args(args: Array) -> String:
	for a in args:
		var arg := str(a)
		if arg.begins_with("--map="):
			var key := arg.trim_prefix("--map=").strip_edges().to_lower()
			if DEDICATED_MAPS.has(key):
				return DEDICATED_MAPS[key]
	return dedicated_map_path

func start_dedicated_server(port: int = DEFAULT_PORT) -> bool:
	_cleanup_network()
	dedicated_map_path = _map_from_args(OS.get_cmdline_args() + OS.get_cmdline_user_args())

	var peer = _make_peer()
	var err = _peer_create_server(peer, port)
	if err != OK:
		push_error("[NetworkManager] Falha ao criar servidor dedicado na porta %d (Código: %d)" % [port, err])
		return false

	multiplayer.multiplayer_peer = peer
	is_dedicated = true
	host_peer_id = 1
	team_alpha_peers.clear()
	team_bravo_peers.clear()
	player_stats.clear()
	score_alpha = 0
	score_bravo = 0
	match_active = false
	is_in_lobby = false
	_setup_spawns()

	print("==================================================================")
	print("[NetworkManager] SERVIDOR DEDICADO ONLINE NA PORTA %d (WebSocket/TCP)" % port)
	print("[NetworkManager] Capacidade Máxima: %d jogadores (Suporta até 6v6)" % max_players)
	print("[NetworkManager] Meta da Partida: %d Kills" % target_kills)
	print("[NetworkManager] Mapa: %s" % dedicated_map_path)
	print("==================================================================")
	# O servidor carrega o mapa na hora; quem entra recebe o mapa e só é admitido depois de carregar
	get_tree().change_scene_to_file.call_deferred(dedicated_map_path)
	return true

## Inicia uma partida local offline (Solo / Web)
func start_local_match() -> void:
	_cleanup_network()
	cleanup_lingering_players()

	is_dedicated = false
	host_peer_id = 1
	team_alpha_peers = [1]
	team_bravo_peers.clear()
	player_stats.clear()
	_register_player_stat(1, true)
	score_alpha = 0
	score_bravo = 0
	match_active = true
	is_in_lobby = false

	# Apenas spawna o jogador se já estivermos dentro de uma cena 3D de mapa válida
	var cur_scn = get_tree().current_scene if get_tree() else null
	if cur_scn and cur_scn is Node3D and not (cur_scn.name in ["MainMenu", "LobbyScreen", "LoadingScreen"]):
		_setup_spawns()
		_spawn_player(1, true, cur_scn)

	match_started.emit()
	print("[NetworkManager] Partida Local configurada!")

## Inicia um Listen Server (Host + Jogador Local)
## Retorna a porta alocada com sucesso (> 0) ou 0 se todas as portas falharem.
func start_host(port: int = DEFAULT_PORT) -> int:
	_cleanup_network()
	cleanup_lingering_players()

	var peer = _make_peer()
	var target_port = port
	var err = _peer_create_server(peer, target_port)

	# Se a porta estiver em uso, buscar portas subsequentes (port+1 até port+10)
	if err != OK:
		for p in range(port + 1, port + 11):
			peer = _make_peer()
			err = _peer_create_server(peer, p)
			if err == OK:
				target_port = p
				print("[NetworkManager] Porta %d ocupada. Servidor iniciado com sucesso na porta alternativa: %d" % [port, target_port])
				break

	if err != OK:
		push_error("[NetworkManager] Falha ao criar servidor (Código: %d). Nenhuma porta disponível." % err)
		return 0

	multiplayer.multiplayer_peer = peer
	is_dedicated = false
	host_peer_id = 1
	team_alpha_peers = [1]
	team_bravo_peers.clear()
	player_stats.clear()
	_register_player_stat(1, true)
	score_alpha = 0
	score_bravo = 0

	print("[NetworkManager] Listen Server iniciado na porta %d (Capacidade: %d)" % [target_port, max_players])
	return target_port

## Conecta como Cliente a um Servidor ENet
func join_game(ip: String = "127.0.0.1", port: int = DEFAULT_PORT) -> bool:
	_cleanup_network()
	cleanup_lingering_players()

	var peer = _make_peer()
	var err = _peer_create_client(peer, ip, port)
	if err != OK:
		push_warning("[NetworkManager] Falha ao conectar a %s:%d (Código: %d)." % [ip, port, err])
		return false

	multiplayer.multiplayer_peer = peer
	print("[NetworkManager] Conectando a %s:%d..." % [ip, port])
	return true

# ── CALLBACKS DE CONEXÃO ───────────────────────────────────────────────────────
func _on_peer_connected(id: int) -> void:
	print("[NetworkManager] Novo peer conectado com ID: %d" % id)
	if not multiplayer.is_server():
		return

	# Se estamos no LOBBY: aguarda o cliente enviar seus dados de perfil
	if is_in_lobby:
		print("[NetworkManager] Peer %d entrou na sala de espera do Lobby." % id)
		return

	# Se estamos em PARTIDA ATIVA ou SERVIDOR DEDICADO:
	var max_team_size = max(1, max_players / 2)
	var is_alpha = false

	if is_dedicated:
		print("[NetworkManager] Peer %d recebendo o mapa %s" % [id, dedicated_map_path])
		rpc_id(id, "rpc_load_match_map", dedicated_map_path)
		return

	_server_admit_peer_legacy(id, max_team_size)

func _server_admit_peer_legacy(id: int, max_team_size: int) -> void:
	var is_alpha = false
	# Listen Server em jogo ativo
	if team_alpha_peers.size() <= team_bravo_peers.size() and team_alpha_peers.size() < max_team_size:
		team_alpha_peers.append(id)
		is_alpha = true
	else:
		team_bravo_peers.append(id)
		is_alpha = false

	_register_player_stat(id, is_alpha)

	for p_id in team_alpha_peers:
		if p_id != id: rpc_id(id, "rpc_spawn_player", p_id, true)
	for p_id in team_bravo_peers:
		if p_id != id: rpc_id(id, "rpc_spawn_player", p_id, false)

	rpc("rpc_spawn_player", id, is_alpha)
	rpc("sync_player_stats", player_stats)
	rpc("sync_match_state", score_alpha, score_bravo)
	match_active = true
	match_started.emit()

## Servidor -> cliente: carregar o mapa da partida antes de entrar
@rpc("authority", "call_remote", "reliable")
func rpc_load_match_map(map_path: String) -> void:
	print("[NetworkManager] Servidor pediu o mapa: %s" % map_path)
	# Servidor dedicado não tem sala de espera: sai do modo lobby e entra direto na partida
	is_in_lobby = false
	is_room_host = false
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.target_map_path = map_path
		# Partida ativa no cliente: libera captura do mouse (câmera), HUD e fluxo de classe,
		# como no modo solo. Sem isso o clique não prendia o mouse e a câmera não girava.
		gm.is_match_active = true
		gm.match_time_elapsed = 0.0
	match_active = true
	get_tree().change_scene_to_file("res://scenes/ui/loading_screen.tscn")
	# Espera o mapa terminar de carregar e avisa o servidor
	while is_inside_tree():
		await get_tree().process_frame
		var cs = get_tree().current_scene
		if cs and cs is Node3D and cs.scene_file_path == map_path:
			break
	await get_tree().create_timer(0.5).timeout
	if multiplayer.has_multiplayer_peer():
		rpc_id(1, "rpc_client_ready_in_map")
		submit_local_loadout()

## Cliente -> servidor: mapa carregado, pode entrar na partida
@rpc("any_peer", "call_remote", "reliable")
func rpc_client_ready_in_map() -> void:
	if not multiplayer.is_server() or not is_dedicated:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender in team_alpha_peers or sender in team_bravo_peers:
		return
	print("[NetworkManager] Peer %d carregou o mapa e foi admitido na partida." % sender)
	_server_admit_dedicated(sender)
	_server_send_known_loadouts(sender)

func _server_admit_dedicated(id: int) -> void:
	var max_team_size = max(1, max_players / 2)
	var is_alpha = false
	if true: # servidor dedicado
		if team_alpha_peers.size() <= team_bravo_peers.size() and team_alpha_peers.size() < max_team_size:
			team_alpha_peers.append(id)
			is_alpha = true
		elif team_bravo_peers.size() < max_team_size:
			team_bravo_peers.append(id)
			is_alpha = false
		else:
			push_warning("[NetworkManager] Servidor cheio! Peer %d excedeu limite." % id)
			return

		_register_player_stat(id, is_alpha)

		for p_id in team_alpha_peers:
			if p_id != id: rpc_id(id, "rpc_spawn_player", p_id, true)
		for p_id in team_bravo_peers:
			if p_id != id: rpc_id(id, "rpc_spawn_player", p_id, false)

		rpc("rpc_spawn_player", id, is_alpha)
		rpc("sync_player_stats", player_stats)
		rpc("sync_match_state", score_alpha, score_bravo)

		if team_alpha_peers.size() >= 1 and team_bravo_peers.size() >= 1:
			match_active = true
			rpc("rpc_match_started")

func _on_peer_disconnected(id: int) -> void:
	peer_loadouts.erase(id)
	print("[NetworkManager] Peer desconectado: %d" % id)
	if is_in_lobby:
		if lobby_roster.has(id):
			lobby_roster.erase(id)
			lobby_player_left.emit(id)
			lobby_updated.emit(get_lobby_roster_array())
			if multiplayer.is_server():
				rpc("rpc_sync_entire_lobby", lobby_roster, lobby_map_idx)
		return

	if multiplayer.is_server():
		rpc("rpc_despawn_player", id)
		team_alpha_peers.erase(id)
		team_bravo_peers.erase(id)
		player_stats.erase(id)
		rpc("sync_player_stats", player_stats)

		if team_alpha_peers.is_empty() and team_bravo_peers.is_empty():
			score_alpha = 0
			score_bravo = 0
			match_active = false
			print("[NetworkManager] Todos saíram. Partida reiniciada no servidor.")

func _on_connected_to_server() -> void:
	print("[NetworkManager] Conexão estabelecida com o Servidor com sucesso!")
	var my_id = multiplayer.get_unique_id()

	if is_in_lobby:
		# Enviar dados do jogador local para o Host registrar no Lobby
		var my_data = _build_local_player_data(false)
		my_data["id"] = my_id
		my_data["is_host"] = false
		my_data["is_ready"] = false
		rpc_id(1, "rpc_client_request_lobby_join", my_data)
	else:
		# Conexão direta em partida ou servidor dedicado
		_setup_spawns()
		_spawn_player(my_id, false)
		match_active = true
		match_started.emit()

func _on_server_disconnected() -> void:
	print("[NetworkManager] Desconectado do Servidor.")
	match_active = false
	is_in_lobby = false
	lobby_roster.clear()

# ── PROTOCOLO RPC DE LOBBY SINCRONIZADO (FASE 1) ──────────────────────────────
@rpc("any_peer", "call_local", "reliable")
func rpc_client_request_lobby_join(client_info: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	if is_dedicated:
		return # o dedicado já mandou o mapa na conexão (rpc_load_match_map)

	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = client_info.get("id", 2)

	client_info["id"] = sender_id
	client_info["team"] = 1  # Cliente vai para o Time Bravo (T) no 1v1
	client_info["team_name"] = "BRAVO"
	client_info["is_host"] = false
	client_info["is_ready"] = false

	lobby_roster[sender_id] = client_info
	print("[NetworkManager] Cliente %s (ID %d) registrado com sucesso no Lobby!" % [client_info.get("name", "Operador"), sender_id])

	# Registrar também no SocialManager para histórico recente
	var sm = get_node_or_null("/root/SocialManager")
	if sm:
		sm.add_recent_player(str(client_info.get("name", "Operador")), str(client_info.get("tag", "[TF141]")))

	rpc("rpc_sync_entire_lobby", lobby_roster, lobby_map_idx)

@rpc("call_local", "reliable")
func rpc_sync_entire_lobby(roster: Dictionary, current_map_idx: int) -> void:
	lobby_roster = roster
	lobby_map_idx = current_map_idx
	var my_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1

	# Ajustar flag is_local
	for p_id in lobby_roster.keys():
		lobby_roster[p_id]["is_local"] = (p_id == my_id)

	lobby_map_changed.emit(current_map_idx)
	lobby_updated.emit(get_lobby_roster_array())

@rpc("any_peer", "call_local", "reliable")
func rpc_set_lobby_ready(peer_id: int, is_ready: bool) -> void:
	if lobby_roster.has(peer_id):
		lobby_roster[peer_id]["is_ready"] = is_ready
		lobby_updated.emit(get_lobby_roster_array())
		if multiplayer.is_server():
			rpc("rpc_sync_entire_lobby", lobby_roster, lobby_map_idx)

@rpc("any_peer", "call_local", "reliable")
func rpc_host_vote_map(map_idx: int) -> void:
	lobby_map_idx = map_idx
	lobby_map_changed.emit(map_idx)
	if multiplayer.is_server():
		rpc("rpc_sync_entire_lobby", lobby_roster, lobby_map_idx)

## Dispara o lançamento da partida sincronizado para todos os operadores da sala
func launch_match_from_lobby(map_path: String, map_name: String) -> void:
	if not multiplayer.is_server():
		return
	print("[NetworkManager] Lançando partida a partir do Lobby para todos os clientes: %s" % map_name)
	rpc("rpc_launch_match_from_lobby", map_path, map_name)

@rpc("call_local", "reliable")
func rpc_launch_match_from_lobby(map_path: String, map_name: String) -> void:
	is_in_lobby = false
	match_active = true

	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.target_map_path = map_path
		gm.target_map_display_name = map_name
		gm.is_match_active = true
		gm.match_time_elapsed = 0.0

		var roster_arr = get_lobby_roster_array()
		gm.lobby_roster = roster_arr
		gm.pending_match_mode = GameModeManager.GameMode.WAGER_1V1
		gm.pending_score_limit = target_kills
		gm.pending_stake = 10.0

	lobby_match_launching.emit(map_path, map_name)
	get_tree().change_scene_to_file("res://scenes/ui/loading_screen.tscn")

## Chamado quando a cena do mapa 3D termina de carregar para posicionar os jogadores
func on_map_scene_ready() -> void:
	_setup_spawns()
	var my_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1

	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			team_alpha_peers = [1]
			team_bravo_peers.clear()

			# Alocar clientes nos times
			for p_id in lobby_roster.keys():
				if p_id != 1:
					team_bravo_peers.append(p_id)

			# 1. Spawna o Host local (Alpha / CT) apenas se ainda não existir
			ensure_local_player_spawned()

			# 2. Spawna os clientes conectados no Time Bravo (T)
			for c_id in team_bravo_peers:
				_spawn_player(c_id, false)
				rpc("rpc_spawn_player", c_id, false)
				rpc_id(c_id, "rpc_spawn_player", 1, true)

			match_active = true
			rpc("rpc_match_started")
			var gm = get_node_or_null("/root/GameManager")
			if gm and gm.has_method("deploy_match_start"):
				gm.deploy_match_start()
		else:
			# Cliente avisa que carregou o mapa
			ensure_local_player_spawned()
	else:
		# Modo Offline / Bots IA (Sem peer de rede): Garante operador local único sem duplicar
		team_alpha_peers = [1]
		team_bravo_peers.clear()
		ensure_local_player_spawned()
		match_active = true
		match_started.emit()
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("deploy_match_start"):
			gm.deploy_match_start()

## Garante que o jogador local esteja sempre instanciado no mapa atual
func ensure_local_player_spawned(target_map: Node = null) -> Node:
	if is_in_lobby:
		return null
	# Servidor dedicado só arbitra a partida: não tem jogador próprio
	if is_dedicated:
		return null

	var cur_scn = get_tree().current_scene if get_tree() else null
	if cur_scn and (cur_scn.name == "LobbyScreen" or cur_scn.name == "MainMenu" or cur_scn.name == "LoadingScreen"):
		return null

	var cur_scene = target_map
	if not cur_scene and get_tree():
		cur_scene = get_tree().current_scene
		# Se a cena atual for o loading_screen ou vazia, procurar o mapa dentro do root
		if (not cur_scene or cur_scene.name == "LoadingScreen" or not (cur_scene is Node3D)) and get_tree().root:
			for ch in get_tree().root.get_children():
				if ch is Node3D and ("Map" in ch.name or "nuketown" in ch.name.to_lower()):
					cur_scene = ch
					break
	if not cur_scene or not (cur_scene is Node3D):
		return null

	# Checar se o jogador já existe na cena do mapa ou na raiz
	var existing = cur_scene.find_child("Player_*", true, false)
	if not existing:
		existing = cur_scene.find_child("Player", true, false)
	if not existing and get_tree() and get_tree().root:
		for ch in get_tree().root.get_children():
			if ch is CharacterBody3D and "Player" in ch.name:
				existing = ch
				break

	if existing and is_instance_valid(existing):
		return existing

	_setup_spawns()
	var my_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var is_alpha = true
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		is_alpha = (gm.local_player_team == 0 or gm.local_player_team == 1)
	return _spawn_player(my_id, is_alpha, cur_scene)

# ── PROTOCOLO RPC DE COMBATE & PONTUAÇÃO ───────────────────────────────────────
@rpc("call_local", "reliable")
func rpc_start_countdown(duration: float = 5.0) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.mode_manager:
		gm.mode_manager.countdown_duration = duration
		if not gm.mode_manager.is_in_countdown():
			gm.mode_manager.start_match(gm.mode_manager.game_mode, gm.mode_manager.score_limit, gm.mode_manager.stake_amount, false)

@rpc("call_local", "reliable")
func rpc_match_started() -> void:
	match_active = true
	match_started.emit()

@rpc("call_local", "reliable")
func rpc_spawn_player(peer_id: int, is_alpha: bool) -> void:
	_spawn_player(peer_id, is_alpha)

@rpc("call_local", "reliable")
func rpc_despawn_player(peer_id: int) -> void:
	var target_parent = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_parent()
	if target_parent:
		var node = target_parent.get_node_or_null("Player_" + str(peer_id))
		if node:
			node.queue_free()

func is_player_alpha(peer_id: int) -> bool:
	return peer_id in team_alpha_peers or peer_id == 1

func _setup_spawns() -> void:
	if spawn_alpha and is_instance_valid(spawn_alpha) and spawn_bravo and is_instance_valid(spawn_bravo):
		return

	if get_tree() and get_tree().current_scene:
		var scene = get_tree().current_scene
		spawn_alpha = scene.find_child("Spawn_Alpha", true, false) as Node3D
		spawn_bravo = scene.find_child("Spawn_Bravo", true, false) as Node3D

	var parent_node = get_parent()
	if parent_node:
		if not spawn_alpha: spawn_alpha = parent_node.find_child("Spawn_Alpha", true, false) as Node3D
		if not spawn_bravo: spawn_bravo = parent_node.find_child("Spawn_Bravo", true, false) as Node3D

func get_spawn_transform(is_alpha: bool, peer_id: int = 1) -> Transform3D:
	var cur_scene = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_parent()
	if cur_scene:
		var bm = cur_scene.find_child("BotManager", true, false)
		if bm and bm.has_method("get_optimal_spawn_transform"):
			return bm.get_optimal_spawn_transform(0 if is_alpha else 1, abs(peer_id) % 6)

	_setup_spawns()
	var base_node = spawn_alpha if is_alpha else spawn_bravo

	var base_pos = Vector3(-14.0, 0.5, -31.0) if is_alpha else Vector3(2.0, 0.5, 34.0)
	var base_rot = Basis().rotated(Vector3.UP, PI) if is_alpha else Basis()

	var slot = abs(peer_id) % 6
	if base_node and is_instance_valid(base_node):
		var children = base_node.get_children()
		if not children.is_empty():
			var ch = children[slot % children.size()] as Node3D
			if ch:
				return _snap_transform_to_floor(Transform3D(ch.global_basis, ch.global_position))
		base_pos = base_node.global_position
		base_rot = base_node.global_basis

	var offset_x = (float(slot % 3) - 1.0) * 1.8
	var offset_z = (float(slot / 3) - 0.5) * 1.5
	var final_pos = base_pos + Vector3(offset_x, 0, offset_z)

	var tx = Transform3D(base_rot, final_pos)
	return _snap_transform_to_floor(tx)

func _snap_transform_to_floor(tx: Transform3D) -> Transform3D:
	if not is_inside_tree():
		return tx
	var vp = get_viewport()
	if not vp:
		return tx
	var w3d = vp.find_world_3d()
	if not w3d:
		return tx
	var space = w3d.direct_space_state
	if not space:
		return tx
	var pos = tx.origin
	var ray_from = Vector3(pos.x, pos.y + 6.0, pos.z)
	var ray_to = Vector3(pos.x, pos.y - 12.0, pos.z)
	var query = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.collision_mask = 1
	var hit = space.intersect_ray(query)
	if hit and hit.collider and not ("Safety" in hit.collider.name) and not ("Player" in hit.collider.name):
		var snapped_origin = Vector3(pos.x, hit.position.y + 0.25, pos.z)
		return Transform3D(tx.basis, snapped_origin)
	return tx

func _spawn_player(peer_id: int, is_alpha: bool, target_parent: Node = null) -> Node:
	# 0. REGRA ESTRITA: NUNCA spawnar jogador se estamos no Lobby, Menu Principal ou Loading Screen!
	if is_in_lobby:
		push_warning("[NetworkManager] Spawn bloqueado: sessão está em fase de Lobby.")
		return null

	var cur_scene_ref = get_tree().current_scene if (get_tree() and get_tree().current_scene) else null
	if cur_scene_ref and (cur_scene_ref.name == "LobbyScreen" or cur_scene_ref.name == "MainMenu" or cur_scene_ref.name == "LoadingScreen"):
		push_warning("[NetworkManager] Spawn bloqueado: cena ativa é interface de menu/lobby (%s)." % cur_scene_ref.name)
		return null

	if not target_parent:
		target_parent = cur_scene_ref
		# Se a cena atual for o loading_screen ou não for Node3D, procurar o mapa dentro do root
		if (not target_parent or target_parent.name == "LoadingScreen" or not (target_parent is Node3D)) and get_tree() and get_tree().root:
			for ch in get_tree().root.get_children():
				if ch is Node3D and ("Map" in ch.name or "nuketown" in ch.name.to_lower()):
					target_parent = ch
					break

	# Se mesmo assim não encontrou um mapa 3D válido, NÃO anexa no root nem em UI
	if not target_parent or not (target_parent is Node3D) or target_parent == get_tree().root:
		push_warning("[NetworkManager] Spawn cancelado: nenhum nó de Mapa 3D disponível como destino.")
		return null

	# 1. Checar se já existe uma instância do jogador com este peer_id no parent ou na árvore
	var existing = target_parent.get_node_or_null("Player_" + str(peer_id))
	if not existing:
		existing = target_parent.find_child("Player_" + str(peer_id), true, false)
	if not existing and get_tree() and get_tree().root:
		existing = get_tree().root.find_child("Player_" + str(peer_id), true, false)

	# Se já existe o jogador, reaproveitá-lo posicionando no spawn correto sem criar cópia duplicada!
	if existing and is_instance_valid(existing):
		var spawn_tx = get_spawn_transform(is_alpha, peer_id)
		existing.global_transform = spawn_tx
		if existing.has_method("respawn") and "is_dead" in existing and existing.is_dead:
			existing.respawn()
		return existing

	# 2. Limpar quaisquer nós antigos ou órfãos
	var stale = target_parent.get_node_or_null("Player_Old_" + str(peer_id))
	if stale and is_instance_valid(stale):
		target_parent.remove_child(stale)
		stale.queue_free()

	# Limpar instâncias perdidas no root caso target_parent seja o mapa
	if target_parent != get_tree().root and get_tree() and get_tree().root:
		var root_orphan = get_tree().root.get_node_or_null("Player_" + str(peer_id))
		if root_orphan and is_instance_valid(root_orphan):
			root_orphan.queue_free()

	# 3. Instanciar novo jogador
	var player = player_scene.instantiate()
	player.name = "Player_" + str(peer_id)
	player.set_multiplayer_authority(peer_id)

	target_parent.add_child(player)
	var spawn_tx = get_spawn_transform(is_alpha, peer_id)
	player.global_transform = spawn_tx

	return player

@rpc("any_peer", "call_local")
func report_kill(killer_peer_id: int, victim_peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	var is_alpha_kill = (killer_peer_id in team_alpha_peers or killer_peer_id == 1)
	if is_alpha_kill:
		score_alpha += 1
	else:
		score_bravo += 1

	if not player_stats.has(killer_peer_id):
		_register_player_stat(killer_peer_id, is_alpha_kill)
	if not player_stats.has(victim_peer_id):
		_register_player_stat(victim_peer_id, not is_alpha_kill)

	player_stats[killer_peer_id]["kills"] += 1
	player_stats[killer_peer_id]["score"] += 100
	player_stats[victim_peer_id]["deaths"] += 1

	rpc("sync_match_state", score_alpha, score_bravo)
	rpc("sync_player_stats", player_stats)

	if score_alpha >= target_kills:
		rpc("announce_winner", 0)
	elif score_bravo >= target_kills:
		rpc("announce_winner", 1)

func record_team_score(killer_team: int, victim_team: int, killer_id: int, victim_id: int, is_headshot: bool = false, is_crouch: bool = false) -> void:
	if killer_team == 0:
		score_alpha += 1
	else:
		score_bravo += 1

	if not player_stats.has(killer_id):
		_register_player_stat(killer_id, killer_team == 0)
	if not player_stats.has(victim_id):
		_register_player_stat(victim_id, victim_team == 0)

	player_stats[killer_id]["kills"] += 1
	var pts = 100
	if is_headshot:
		player_stats[killer_id]["headshots"] = int(player_stats[killer_id].get("headshots", 0)) + 1
		pts += 25
	if is_crouch:
		player_stats[killer_id]["crouch_kills"] = int(player_stats[killer_id].get("crouch_kills", 0)) + 1
		pts += 25
	player_stats[killer_id]["score"] += pts
	player_stats[victim_id]["deaths"] += 1

	score_updated.emit(score_alpha, score_bravo)
	stats_updated.emit(player_stats)

	if score_alpha >= target_kills:
		announce_winner(0)
	elif score_bravo >= target_kills:
		announce_winner(1)

func register_player_stat(id: int, is_alpha: bool, custom_name: String = "") -> void:
	var team_code = 0 if is_alpha else 1
	var p_name = custom_name
	var gm = get_node_or_null("/root/GameManager")
	if p_name.is_empty():
		if id == 1 and not is_dedicated:
			p_name = gm.local_player_name if (gm and not gm.local_player_name.is_empty()) else "Operador_Alpha"
		else:
			p_name = "Jogador %d" % id

	var p_lvl = gm.xp_system.current_level if (gm and gm.xp_system) else 1
	var p_prestige = gm.xp_system.current_prestige if (gm and gm.xp_system) else 0
	var r_tag = gm.xp_system.get_rank_tag(p_lvl, p_prestige) if (gm and gm.xp_system) else "[PVT 1]"
	var r_icon = gm.xp_system.get_rank_icon(p_lvl, p_prestige) if (gm and gm.xp_system) else "★"
	var r_color = gm.xp_system.get_rank_color(p_lvl, p_prestige) if (gm and gm.xp_system) else Color(1.0, 0.8, 0.2)

	if not player_stats.has(id):
		player_stats[id] = {
			"peer_id": id,
			"name": p_name,
			"team": team_code,
			"kills": 0,
			"deaths": 0,
			"assists": 0,
			"headshots": 0,
			"crouch_kills": 0,
			"shots_fired": 0,
			"shots_hit": 0,
			"accuracy": 0.0,
			"score": 0,
			"rank_lvl": p_lvl,
			"rank_prestige": p_prestige,
			"rank_tag": r_tag,
			"rank_icon": r_icon,
			"rank_color": r_color
		}
	else:
		if custom_name != "":
			player_stats[id]["name"] = custom_name

func _register_player_stat(id: int, is_alpha: bool, custom_name: String = "") -> void:
	register_player_stat(id, is_alpha, custom_name)

@rpc("call_local", "reliable")
func sync_player_stats(stats: Dictionary) -> void:
	player_stats = stats
	stats_updated.emit(player_stats)

@rpc("call_local")
func sync_match_state(alpha_pts: int, bravo_pts: int) -> void:
	score_alpha = alpha_pts
	score_bravo = bravo_pts
	score_updated.emit(score_alpha, score_bravo)

@rpc("call_local")
func announce_winner(winner_team: int) -> void:
	match_active = false
	match_ended.emit(winner_team)

func reset_match_state() -> void:
	match_active = true
	score_alpha = 0
	score_bravo = 0
	player_stats.clear()
	if multiplayer.has_multiplayer_peer():
		var my_id = multiplayer.get_unique_id()
		var is_alpha = is_player_alpha(my_id)
		var gm = get_node_or_null("/root/GameManager")
		var p_name = gm.local_player_name if (gm and not gm.local_player_name.is_empty()) else "Operador"
		register_player_stat(my_id, is_alpha, p_name)
	score_updated.emit(0, 0)
	stats_updated.emit(player_stats)
