extends Node3D

func _ready():
	var p_scn = load("res://scenes/player/player.tscn") as PackedScene
	var player = p_scn.instantiate()
	add_child(player)

	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	light.light_energy = 1.2
	add_child(light)

	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.35, 0.45, 0.55)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment = e
	add_child(env)

	var wm = player.find_child("WeaponManager", true, false)
	var fps_vm = player.find_child("FpsHandsViewModel", true, false)

	var ak_data = load("res://resources/weapons/ak47.tres") as WeaponData
	wm.equip(ak_data)

	get_viewport().size = Vector2i(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame

	# Wait a few frames for attachments and models to sync
	for i in range(10):
		await get_tree().process_frame

	var img_hip = get_viewport().get_texture().get_image()
	img_hip.save_png("C:/gemini cli/games/scratch/preview_acr_fixed_hip.png")

	# Test ADS
	fps_vm.set_ads(true, 1.0)
	if fps_vm.fps_hands and "ads_pos" in fps_vm.fps_hands:
		fps_vm.fps_hands.weapon.position = fps_vm.fps_hands.ads_pos

	for i in range(10):
		await get_tree().process_frame

	var img_ads = get_viewport().get_texture().get_image()
	img_ads.save_png("C:/gemini cli/games/scratch/preview_acr_fixed_ads.png")

	get_tree().quit(0)



	# Now let's check animations
	var anim_player = fps_vm.fps_hands.weapon.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var anim_tree = fps_vm.fps_hands.weapon.find_child("AnimationTree", true, false) as AnimationTree
	log_msg.call("AnimationPlayer: %s, current_anim: %s, is_playing: %s" % [str(anim_player), anim_player.current_animation if anim_player else "", anim_player.is_playing() if anim_player else false])
	log_msg.call("AnimationTree: %s, active: %s" % [str(anim_tree), anim_tree.active if anim_tree else false])

	if f: f.close()
	get_tree().quit(0)
