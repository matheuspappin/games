# =============================================================================
# social_manager.gd
# Gerenciador Social do NUKE / Tactical Warfare — Autoload Singleton
# Estilo Call of Duty: Modern Warfare & Black Ops
# - Lista de Amigos persistida em disco (user://friends_data.json)
# - Histórico de Jogadores Recentes (adversários e aliados de duelos)
# - Sistema de Convites de Grupo / Duelo em Tempo Real com Notificação Tática
# - Presença Online simulada e sincronizada
# =============================================================================
extends Node

signal friends_updated
signal recent_players_updated
signal invite_received(invite: Dictionary)
signal invite_accepted(invite: Dictionary)
signal invite_declined(invite: Dictionary)

const FRIENDS_SAVE_PATH = "user://friends_data.json"
const RECENTS_SAVE_PATH = "user://recent_players.json"

var friends_list: Array[Dictionary] = []
var recent_players: Array[Dictionary] = []
var pending_invites: Array[Dictionary] = []

# Mock inicial de amigos para novos operadores estilo Call of Duty Task Force 141
const DEFAULT_PRESET_FRIENDS: Array[Dictionary] = [
	{
		"name": "Ghost",
		"tag": "[TF141]",
		"level": 65,
		"rank_icon": "★",
		"rank_color": "#FFC000",
		"status": "Online (Pronto para Duelo)",
		"skin_id": "ct_urban"
	},
	{
		"name": "Soap",
		"tag": "[TF141]",
		"level": 58,
		"rank_icon": "⭐",
		"rank_color": "#4CE0FF",
		"status": "No Menu Principal",
		"skin_id": "ct_urban"
	},
	{
		"name": "Price",
		"tag": "[BRAVO-6]",
		"level": 70,
		"rank_icon": "⭐",
		"rank_color": "#FF5555",
		"status": "Jogando Nuketown 2065",
		"skin_id": "ct_urban"
	},
	{
		"name": "Woods",
		"tag": "[SOG]",
		"level": 60,
		"rank_icon": "🎖️",
		"rank_color": "#FFAA33",
		"status": "Ausente",
		"skin_id": "t_guerilla"
	}
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_friends()
	load_recent_players()

func load_friends() -> void:
	if FileAccess.file_exists(FRIENDS_SAVE_PATH):
		var file = FileAccess.open(FRIENDS_SAVE_PATH, FileAccess.READ)
		if file:
			var text = file.get_as_text()
			var json = JSON.new()
			if json.parse(text) == OK and json.data is Array:
				friends_list.clear()
				for item in json.data:
					if item is Dictionary:
						friends_list.append(item)
				print("[SocialManager] %d amigos carregados do disco." % friends_list.size())
				friends_updated.emit()
				return
	
	# Se for o primeiro acesso, usa o preset clássico de operadores do CoD
	friends_list = DEFAULT_PRESET_FRIENDS.duplicate(true)
	save_friends()
	friends_updated.emit()

func save_friends() -> void:
	var file = FileAccess.open(FRIENDS_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(friends_list, "\t"))

func load_recent_players() -> void:
	if FileAccess.file_exists(RECENTS_SAVE_PATH):
		var file = FileAccess.open(RECENTS_SAVE_PATH, FileAccess.READ)
		if file:
			var text = file.get_as_text()
			var json = JSON.new()
			if json.parse(text) == OK and json.data is Array:
				recent_players.clear()
				for item in json.data:
					if item is Dictionary:
						recent_players.append(item)
				recent_players_updated.emit()
				return
	recent_players.clear()

func save_recent_players() -> void:
	var file = FileAccess.open(RECENTS_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(recent_players, "\t"))

func get_friends() -> Array[Dictionary]:
	return friends_list

func add_friend(player_name: String, clan_tag: String = "[TF141]", level: int = 25) -> bool:
	var clean_name = player_name.strip_edges()
	if clean_name.is_empty():
		return false

	for f in friends_list:
		if f.get("name", "").to_lower() == clean_name.to_lower():
			return false

	friends_list.append({
		"name": clean_name,
		"tag": clan_tag,
		"level": level,
		"rank_icon": "★",
		"rank_color": "#FFCC00",
		"status": "Online (Recém Adicionado)",
		"skin_id": "ct_urban"
	})
	save_friends()
	friends_updated.emit()
	print("[SocialManager] Novo amigo adicionado: %s %s" % [clan_tag, clean_name])
	return true

func remove_friend(player_name: String) -> void:
	for i in range(friends_list.size() - 1, -1, -1):
		if friends_list[i].get("name", "") == player_name:
			friends_list.remove_at(i)
			save_friends()
			friends_updated.emit()
			print("[SocialManager] Amigo removido: %s" % player_name)
			return

func add_recent_player(player_name: String, clan_tag: String = "[TF141]") -> void:
	var clean = player_name.strip_edges()
	if clean.is_empty() or clean.begins_with("Operador_Alpha"):
		return

	# Não duplicar
	for i in range(recent_players.size() - 1, -1, -1):
		if recent_players[i].get("name", "") == clean:
			recent_players.remove_at(i)

	recent_players.push_front({
		"name": clean,
		"tag": clan_tag,
		"date": Time.get_date_string_from_system() + " " + Time.get_time_string_from_system().substr(0, 5),
		"mode": "Duelo 1v1 Nuketown"
	})

	if recent_players.size() > 20:
		recent_players.resize(20)

	save_recent_players()
	recent_players_updated.emit()

## Dispara envio de convite para um amigo
func send_invite(target_name: String, room_code: String, map_name: String = "NUKETOWN 2065") -> void:
	print("[SocialManager] Convite enviado para %s (Sala: %s | Mapa: %s)" % [target_name, room_code, map_name])
	# Notificar via WebBridge se ativo para amigos na web
	var wb = get_node_or_null("/root/WebBridge")
	if wb:
		wb.notify_web("friend_invite_sent", {
			"target": target_name,
			"room_code": room_code,
			"map": map_name
		})

## Simula ou recebe um convite de entrada
func receive_invite(inviter_name: String, inviter_tag: String, room_code: String, map_name: String = "NUKETOWN 2065") -> void:
	var inv = {
		"id": randi(),
		"inviter": inviter_name,
		"tag": inviter_tag,
		"room_code": room_code,
		"map": map_name,
		"timestamp": Time.get_ticks_msec()
	}
	pending_invites.append(inv)
	invite_received.emit(inv)

	# Efeito sonoro tático
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		var sfx = load("res://assets/audio/weapons/hitmarker.wav")
		if sfx:
			am.play_sfx(sfx, 3.0, 1.4)

func accept_invite(invite: Dictionary) -> void:
	var code = invite.get("room_code", "")
	pending_invites.erase(invite)
	invite_accepted.emit(invite)

	print("[SocialManager] Convite aceito! Conectando à sala: %s" % code)
	var nm = get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("join_room"):
		nm.join_room(code)

func decline_invite(invite: Dictionary) -> void:
	pending_invites.erase(invite)
	invite_declined.emit(invite)
	print("[SocialManager] Convite de %s recusado." % invite.get("inviter", "Operador"))
