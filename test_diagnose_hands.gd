extends Node3D

const WeaponVisualRegistry = preload("res://scripts/weapons/weapon_visual_registry.gd")

func _ready():
	var f = FileAccess.open("C:/gemini cli/games/test_diagnose_hands_out.txt", FileAccess.WRITE)
	var log_msg = func(s: String):
		print(s)
		if f: f.store_line(s)

	log_msg.call("=== PRECISE ADS & HIPFIRE SIGHT DIAGNOSTIC ===")
	var p_scn = load("res://scenes/player/player.tscn") as PackedScene
	if not p_scn:
		log_msg.call("ERROR: Cannot load player.tscn")
		return
	var player = p_scn.instantiate()
	add_child(player)

	get_viewport().size = Vector2i(1280, 720)

	var cam = player.find_child("Camera", true, false) as Camera3D
	var wm = player.find_child("WeaponManager", true, false)
	var fps_vm = player.find_child("FpsHandsViewModel", true, false) as FpsHandsViewModel

	var test_weapons = ["ak47", "m4a1", "scar_h", "mp7", "deagle"]

	for wid in test_weapons:
		var wpath = "res://resources/weapons/%s.tres" % wid
		if not ResourceLoader.exists(wpath):
			log_msg.call("File not found: " + wpath)
			continue
		var wdata = load(wpath) as WeaponData

		# --- A. IRON SIGHTS ---
		fps_vm.set_weapon_customization("default", "none", "none")
		wm.equip(wdata)
		for i in range(10): await get_tree().process_frame

		# 1. Hipfire measurement
		player.ads_amount = 0.0
		fps_vm.set_ads(false, 0.0)
		for i in range(10): await get_tree().process_frame
		_measure_sight(f, wid, "HIPFIRE (Iron)", cam, fps_vm, log_msg)

		# 2. ADS measurement
		player.ads_amount = 1.0
		fps_vm.set_ads(true, 1.0)
		if fps_vm.fps_hands and "ads_pos" in fps_vm.fps_hands:
			fps_vm.fps_hands.weapon.position = fps_vm.fps_hands.ads_pos
		for i in range(15): await get_tree().process_frame
		_measure_sight(f, wid, "ADS (Iron)", cam, fps_vm, log_msg)

		# --- B. RED DOT SIGHT ---
		fps_vm.set_weapon_customization("default", "optic_red_dot", "none")
		for i in range(10): await get_tree().process_frame

		# 1. Hipfire measurement
		player.ads_amount = 0.0
		fps_vm.set_ads(false, 0.0)
		for i in range(10): await get_tree().process_frame
		_measure_sight(f, wid, "HIPFIRE (RedDot)", cam, fps_vm, log_msg)

		# 2. ADS measurement
		player.ads_amount = 1.0
		fps_vm.set_ads(true, 1.0)
		if fps_vm.fps_hands and "ads_pos" in fps_vm.fps_hands:
			fps_vm.fps_hands.weapon.position = fps_vm.fps_hands.ads_pos
		for i in range(15): await get_tree().process_frame
		_measure_sight(f, wid, "ADS (RedDot)", cam, fps_vm, log_msg)

	if f: f.close()
	get_tree().quit(0)

func _measure_sight(f: FileAccess, wid: String, mode_label: String, cam: Camera3D, fps_vm: FpsHandsViewModel, log_msg: Callable) -> void:
	var cam_fwd = -cam.global_transform.basis.z.normalized()

	var sight_pos = Vector3.ZERO
	if fps_vm.current_optic_instance and is_instance_valid(fps_vm.current_optic_instance):
		var reticle = fps_vm.current_optic_instance.find_child("*Reticle*", true, false)
		if not reticle:
			reticle = fps_vm.current_optic_instance.find_child("GlassLens", true, false)
		if reticle and reticle is Node3D:
			sight_pos = reticle.global_position
		else:
			sight_pos = fps_vm.current_optic_instance.global_position
	elif fps_vm.current_custom_model_instance and is_instance_valid(fps_vm.current_custom_model_instance):
		var cfg = WeaponVisualRegistry.get_weapon_config(wid)
		var pivot = fps_vm.current_custom_model_instance.get_node_or_null("Pivot")
		if pivot and cfg.has("socket_iron_ads"):
			sight_pos = pivot.to_global(cfg["socket_iron_ads"])
		else:
			sight_pos = fps_vm.current_custom_model_instance.global_position

	var sight_in_cam = cam.to_local(sight_pos)
	var screen_pos = cam.unproject_position(sight_pos)

	var gun_fwd = Vector3.ZERO
	if fps_vm.current_custom_model_instance and is_instance_valid(fps_vm.current_custom_model_instance):
		var pivot = fps_vm.current_custom_model_instance.get_node_or_null("Pivot")
		if pivot:
			gun_fwd = -pivot.global_transform.basis.z.normalized()
	elif fps_vm.fps_hands and fps_vm.fps_hands.weapon:
		gun_fwd = -fps_vm.fps_hands.weapon.global_transform.basis.z.normalized()

	var angle_deg = rad_to_deg(cam_fwd.angle_to(gun_fwd))

	log_msg.call("\n[%s] - %s:" % [wid.to_upper(), mode_label])
	log_msg.call("  Screen 2D Pos:      (%.1f, %.1f) [Expected Center: (640.0, 360.0)]" % [screen_pos.x, screen_pos.y])
	log_msg.call("  Screen Pixel Error: X=%.1f px, Y=%.1f px (Total Dist: %.1f px)" % [screen_pos.x - 640.0, screen_pos.y - 360.0, screen_pos.distance_to(Vector2(640, 360))])
	log_msg.call("  Camera Local Pos:   X=%.4f m, Y=%.4f m, Z=%.4f m" % [sight_in_cam.x, sight_in_cam.y, sight_in_cam.z])
	log_msg.call("  Angle from Cam Fwd: %.2f degrees" % angle_deg)
	log_msg.call("  Gun Fwd Vector:     %s" % str(gun_fwd))
	log_msg.call("  Cam Fwd Vector:     %s" % str(cam_fwd))
