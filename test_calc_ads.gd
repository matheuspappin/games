extends Node3D

func _ready() -> void:
	var f = FileAccess.open("C:/gemini cli/games/scratch/iron_debug_out.txt", FileAccess.WRITE)
	f.store_line("=== RUNNING ACR IRON SIGHTS AUDIT ===")

	var vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.own_world_3d = true
	add_child(vp)

	var cam = Camera3D.new()
	cam.position = Vector3(0, 1.5, 0)
	vp.add_child(cam)

	var fp = FpsHandsViewModel.new()
	fp.process_priority = 1000
	fp.camera = cam
	cam.add_child(fp)

	var w_res = load("res://resources/weapons/ak47.tres") as WeaponData
	fp.equip_weapon_data(w_res)
	fp.set_weapon_customization("default", "none", "none")
	fp.set_ads(true, 1.0)
	
	# Simulate 10 frames of processing
	for i in range(10):
		fp._process(0.016)

	var c = fp.current_custom_model_instance
	var pivot = c.get_node_or_null("Pivot") if c else null
	if pivot:
		var cfg = preload("res://scripts/weapons/weapon_visual_registry.gd").get_weapon_config("ak47")
		var sight_pos = cfg.get("socket_iron_ads")
		var sight_world = pivot.to_global(sight_pos)
		var sight_cam = cam.to_local(sight_world)
		var screen_pt = cam.unproject_position(sight_world)
		
		var front_post_pivot = Vector3(0.0064, 0.14304, -0.2845)
		var rear_aperture_pivot = Vector3(0.0064, 0.14001, 0.1832)
		var front_world = pivot.to_global(front_post_pivot)
		var rear_world = pivot.to_global(rear_aperture_pivot)
		var front_screen = cam.unproject_position(front_world)
		var rear_screen = cam.unproject_position(rear_world)
		
		f.store_line("socket_iron_ads:       %s" % str(sight_pos))
		f.store_line("sight_cam:             %s" % str(sight_cam))
		f.store_line("configured sight_pt:   %s (center is 640, 360)" % str(screen_pt))
		f.store_line("front_post_screen_pt:  %s" % str(front_screen))
		f.store_line("rear_aper_screen_pt:   %s" % str(rear_screen))
		f.store_line("Difference front-rear: %s" % str(front_screen - rear_screen))
		f.store_line("pivot.global_position: %s" % str(pivot.global_position))
		f.store_line("pivot.rotation_deg:    %s" % str(pivot.rotation_degrees))
		f.store_line("pivot.global_basis euler deg: %s" % str(pivot.global_basis.get_euler() * 180.0 / PI))
		f.store_line("fps_hands.weapon.pos:  %s" % str(fp.fps_hands.weapon.position))
		f.store_line("fps_hands.ads_pos:     %s" % str(fp.fps_hands.ads_pos))
	else:
		f.store_line("ERROR: pivot is null!")

	f.close()
	get_tree().quit(0)
