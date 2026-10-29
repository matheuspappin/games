extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- TEST LOBBY TO BO1 ---")
	var gm = root.get_node_or_null("GameManager")
	if not gm:
		print("GameManager not found in root")
		quit(1)
		return

	# Configurar como o LobbyScreen configura
	gm.target_map_path = "res://scenes/_world/map_nuketown_1v1.tscn"
	gm.target_map_display_name = "NUKETOWN CLÁSSICA (BO1 1960)"
	gm.play_mode = gm.PlayMode.BOTS
	gm.bot_count = 5

	# Roster do Lobby
	var r: Array[Dictionary] = [
		{ "id": 1, "name": "Operador_Alpha", "team": 0, "is_local": true },
		{ "id": 101, "name": "Ghost", "team": 0, "is_local": false },
		{ "id": 102, "name": "Soap", "team": 0, "is_local": false },
		{ "id": 201, "name": "Woods", "team": 1, "is_local": false },
		{ "id": 202, "name": "Mason", "team": 1, "is_local": false },
		{ "id": 203, "name": "Reznov", "team": 1, "is_local": false }
	]
	gm.lobby_roster = r

	var scn = load(gm.target_map_path)
	var map = scn.instantiate()
	root.add_child(map)

	for i in range(15):
		await process_frame

	var bm = map.find_child("BotManager", true, false)
	print("BotManager exists: ", bm != null)
	if bm:
		print("bm.is_active: ", bm.is_active)
		print("bm.active_bots count: ", bm.active_bots.size())
		for b in bm.active_bots:
			print(" - Bot: ", b.name, " team: ", b.get("team"), " pos: ", b.global_position, " visible: ", b.visible)

	var child_bots = map.find_children("Bot_*", "CharacterBody3D", true, false)
	print("Total child bots in map: ", child_bots.size())
	for b in child_bots:
		print(" - Child bot: ", b.name, " pos: ", b.global_position, " visible: ", b.visible)

	quit(0)
