extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("==================================================")
	print(" SIMULATING EXACT 6v6 MENU -> LOBBY -> BO1 FLOW")
	print("==================================================")

	var gm = root.get_node_or_null("GameManager")
	assert(gm != null, "GameManager not found")

	# 1. Menu configures 6v6 with 11 bots on BO1
	gm.configure_bot_match(
		"res://scenes/_world/map_nuketown_1v1.tscn",
		"NUKETOWN CLÁSSICA (BO1 1960)",
		11,
		gm.BotDistribution.BALANCED,
		gm.BotDifficulty.REGULAR,
		"6v6"
	)
	print("[1] Configured: bot_count=%d, map=%s" % [gm.bot_count, gm.target_map_path])

	# 2. Instantiate LobbyScreen
	var lobby_scn = load("res://scenes/ui/lobby_screen.tscn") as PackedScene
	var lobby = lobby_scn.instantiate()
	root.add_child(lobby)
	current_scene = lobby
	await process_frame

	print("[2] LobbyScreen initialized. added_players: %d, bots_to_add: %d" % [
		lobby.added_players.size(), lobby.bots_to_add.size()
	])

	# Trigger _start_loading in lobby
	lobby._start_loading()
	
	# Wait for LoadingScreen to process and change scene
	print("[3] Waiting for LoadingScreen transition...")
	var timeout = 0
	while current_scene == null or current_scene.name == "LobbyScreen" or current_scene.name == "LoadingScreen":
		await process_frame
		timeout += 1
		if timeout > 300:
			print("TIMEOUT waiting for LoadingScreen!")
			break

	print("[4] Current scene is now: ", current_scene.name if current_scene else "null")

	# Wait 30 physics frames for map setup
	for i in range(30):
		await process_frame
		await physics_frame

	var map = current_scene
	var bm = map.find_child("BotManager", true, false)
	assert(bm != null, "BotManager not found in map!")
	print("[5] BotManager active_bots count = %d" % bm.active_bots.size())

	var player = map.find_child("Player*", true, false) as CharacterBody3D
	if not player:
		for c in root.get_children():
			if c is CharacterBody3D and "Player" in c.name:
				player = c
				break
	print("[6] Local player found: %s at pos: %s" % [str(player != null), str(player.global_position if player else Vector3.ZERO)])

	# Print all bots and their target/state/nav
	print("\n--- ALL ACTIVE BOTS IN SCENE ---")
	for b in bm.active_bots:
		print("Bot: %s | Team: %d | Pos: %s | State: %d | Target: %s | Visible: %s" % [
			b.name, b.get("team"), b.global_position, b.get("ai_state"), str(b.get("target_combatant")), b.visible
		])

	# Check combat with player
	if player and bm.active_bots.size() > 0:
		var enemy_bot = null
		for b in bm.active_bots:
			if b.get("team") == 1:
				enemy_bot = b
				break
		if enemy_bot:
			print("\n--- TESTING ENEMY BOT COMBAT WITH PLAYER ---")
			# Teleport player in front of enemy_bot (4 meters away in front of it)
			var forward_dir = -enemy_bot.global_transform.basis.z
			player.global_position = enemy_bot.global_position + forward_dir * 4.0
			print("Placed player at: ", player.global_position, " enemy bot at: ", enemy_bot.global_position)
			
			for i in range(30):
				await physics_frame

			print("Enemy bot target: ", enemy_bot.get("target_combatant"))
			print("Enemy bot ai_state: ", enemy_bot.get("ai_state"))
			if enemy_bot.has_method("_has_line_of_fire"):
				print("Enemy bot has line of fire? ", enemy_bot.call("_has_line_of_fire"))

	quit(0)
