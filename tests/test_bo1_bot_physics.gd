extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- TEST BO1 BOT MOVEMENT & VISIBILITY ---")
	var scn = load("res://scenes/_world/map_nuketown_1v1.tscn")
	var map = scn.instantiate()
	root.add_child(map)

	for i in range(20):
		await process_frame

	var bm = map.find_child("BotManager", true, false)
	print("BotManager bots count: ", bm.active_bots.size())

	# Rodar 60 physics frames para ver se os bots andam ou caem
	for i in range(60):
		await physics_frame

	for b in bm.active_bots:
		print("Bot: ", b.name, " pos: ", b.global_position, " state: ", b.get("ai_state"), " on_floor: ", b.is_on_floor(), " visible: ", b.visible)
		var mesh_vis = true
		for ch in b.find_children("*", "VisualInstance3D", true, false):
			if not ch.visible:
				mesh_vis = false
		print("  -> mesh_vis: ", mesh_vis)

	quit(0)
