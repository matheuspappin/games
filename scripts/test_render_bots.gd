extends SceneTree

func _init():
	var vp = root
	var env = WorldEnvironment.new()
	var env_res = Environment.new()
	env_res.background_mode = Environment.BG_COLOR
	env_res.background_color = Color(0.3, 0.35, 0.4)
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_res.ambient_light_color = Color(0.9, 0.9, 0.9)
	env.environment = env_res
	vp.add_child(env)

	var light = DirectionalLight3D.new()
	light.position = Vector3(2, 4, 3)
	light.look_at_from_position(Vector3(2, 4, 3), Vector3(0, 1.2, 0), Vector3.UP)
	light.light_energy = 1.3
	vp.add_child(light)

	var fill = DirectionalLight3D.new()
	fill.position = Vector3(-2, 3, -3)
	fill.look_at_from_position(Vector3(-2, 3, -3), Vector3(0, 1.2, 0), Vector3.UP)
	fill.light_energy = 0.8
	vp.add_child(fill)

	var cam = Camera3D.new()
	cam.current = true
	vp.add_child(cam)

	var bot_scn = load("res://scenes/enemies/soldier_bot.tscn") as PackedScene
	var bot = bot_scn.instantiate()
	bot.team = 0
	bot.set_physics_process(false)
	vp.add_child(bot)

	for i in range(12):
		await process_frame

	var ap = bot._anim_player
	if ap and ap.has_animation("idle"):
		ap.play("idle")
		ap.advance(0.5)

	for i in range(12):
		await process_frame

	var skel = bot._skeleton
	var rh_idx = skel.find_bone("mixamorig_RightHand") if skel else -1
	var lh_idx = skel.find_bone("mixamorig_LeftHand") if skel else -1
	var rifle = bot.find_child("BotRifle3D", true, false) as Node3D

	if skel and rh_idx >= 0 and lh_idx >= 0:
		print("bot.global_position: ", bot.global_position)
		print("skel.global_position: ", skel.global_position)
		print("skel.global_transform: ", skel.global_transform)
		var rh_local = skel.get_bone_global_pose(rh_idx)
		var lh_local = skel.get_bone_global_pose(lh_idx)
		print("rh_local pose origin: ", rh_local.origin)
		print("lh_local pose origin: ", lh_local.origin)
		var rh_pos = (skel.global_transform * rh_local).origin
		var lh_pos = (skel.global_transform * lh_local).origin
		print("Right Hand global pos: ", rh_pos)
		print("Left Hand global pos:  ", lh_pos)
		print("Distance Right Hand -> Left Hand: ", rh_pos.distance_to(lh_pos))
		if rifle:
			print("Rifle global pos: ", rifle.global_position)
			print("Rifle parent: ", rifle.get_parent().name)
			print("Rifle rot deg: ", rifle.rotation_degrees)

	# Position camera to look directly at the rifle and hands
	cam.position = Vector3(0.8, 1.35, -1.2)
	cam.look_at_from_position(Vector3(0.8, 1.35, -1.2), Vector3(0.0, 1.2, -0.3), Vector3.UP)

	for f in range(6):
		await process_frame

	var img = vp.get_texture().get_image()
	if img:
		img.save_png("res://test_hand_rifle_render.png")
		print("Render saved to test_hand_rifle_render.png!")

	quit(0)
