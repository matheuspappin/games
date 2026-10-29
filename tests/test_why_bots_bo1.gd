extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- TEST BO1 BOTS ---")
	var scn = load("res://scenes/_world/map_nuketown_1v1.tscn")
	var map = scn.instantiate()
	root.add_child(map)
	
	for i in range(10):
		await process_frame
	
	var bm = map.find_child("BotManager", true, false)
	print("BotManager found: ", bm != null)
	if bm:
		print("bm.is_active: ", bm.is_active)
		print("bm.active_bots size: ", bm.active_bots.size())
		print("active_bots in scene: ")
		for b in bm.active_bots:
			print(" - Bot: ", b.name, " team: ", b.get("team"), " pos: ", b.global_position, " visible: ", b.visible)
	
	var all_bots = map.find_children("Bot_*", "CharacterBody3D", true, false)
	print("Total Bot_* children in map: ", all_bots.size())
	for b in all_bots:
		print(" - Found child bot: ", b.name, " pos: ", b.global_position)
	
	quit(0)
