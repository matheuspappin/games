extends Node3D

var frames = 0
var player: CharacterBody3D
var cam: Camera3D
var file: FileAccess

func _ready():
	file = FileAccess.open("C:/gemini cli/games/test_gameplay_frames_out.txt", FileAccess.WRITE)
	file.store_line("=== RUNNING GAMEPLAY FRAMES TEST ===")

	var p_scn = load("res://scenes/player/player.tscn") as PackedScene
	if not p_scn:
		file.store_line("ERROR: Cannot load player.tscn")
		return
	player = p_scn.instantiate()
	add_child(player)

	cam = player.find_child("Camera", true, false) as Camera3D
	file.store_line("Player instantiated. Cam: %s" % str(cam))

func _process(_delta: float):
	frames += 1
	if frames == 2:
		_inspect_state("FRAME 2 (Equipped default AK47)")
	elif frames == 15:
		# Now equip SCAR-H
		var wm = player.find_child("WeaponManager", true, false)
		var scar = load("res://resources/weapons/scar_h.tres") as WeaponData
		wm.equip(scar)
		_inspect_state("FRAME 15 (Equipped SCAR-H)")
	elif frames == 30:
		_inspect_state("FRAME 30 (Playing idle/take)")
	elif frames == 60:
		_inspect_state("FRAME 60")
		if file: file.close()
		get_tree().quit(0)

func _inspect_state(tag: String):
	if not file: return
	file.store_line("\n--- " + tag + " ---")
	if not player:
		file.store_line("Player is null")
		return

	var fps_vm = player.find_child("FpsHandsViewModel", true, false)
	if not fps_vm:
		file.store_line("No FpsHandsViewModel!")
		return

	file.store_line("fps_vm: visible=%s, in_tree_vis=%s" % [fps_vm.visible, fps_vm.is_visible_in_tree()])
	if not fps_vm.fps_hands:
		file.store_line("fps_vm.fps_hands is NULL")
		return

	var hands = fps_vm.fps_hands
	file.store_line("fps_hands: visible=%s, in_tree_vis=%s, pos=%s, rot=%s, top_level=%s" % [hands.visible, hands.is_visible_in_tree(), str(hands.position), str(hands.rotation_degrees), hands.top_level])
	file.store_line("fps_hands.weapon: %s" % str(hands.weapon))
	if hands.weapon:
		file.store_line("  weapon pos=%s, rot=%s, scale=%s, vis=%s, in_tree_vis=%s" % [str(hands.weapon.position), str(hands.weapon.rotation_degrees), str(hands.weapon.scale), hands.weapon.visible, hands.weapon.is_visible_in_tree()])
		var atree = hands.weapon.find_child("AnimationTree", true, false) as AnimationTree
		if atree:
			var sm = atree.get("parameters/playback") as AnimationNodeStateMachinePlayback
			file.store_line("  AnimationTree current node: %s" % (sm.get_current_node() if sm else "null"))

		var obj7 = hands.weapon.find_child("Object_7", true, false) as MeshInstance3D
		if obj7:
			file.store_line("  Object_7: vis=%s, in_tree_vis=%s, global_pos=%s" % [obj7.visible, obj7.is_visible_in_tree(), str(obj7.global_position)])
			if cam:
				var cam_local = cam.global_transform.affine_inverse() * obj7.global_position
				var unproj = cam.unproject_position(obj7.global_position)
				file.store_line("  Object_7 cam space pos: %s, unproject (screen): %s" % [str(cam_local), str(unproj)])
		else:
			file.store_line("  Object_7 NOT FOUND!")

		var custom_w = hands.weapon.find_child("CustomWeaponModel", true, false)
		if custom_w:
			file.store_line("  CustomWeaponModel: vis=%s, pos=%s, global_pos=%s" % [custom_w.visible, str(custom_w.position), str(custom_w.global_position)])
			if cam:
				var cam_local = cam.global_transform.affine_inverse() * custom_w.global_position
				var unproj = cam.unproject_position(custom_w.global_position)
				file.store_line("  CustomWeaponModel cam space: %s, screen: %s" % [str(cam_local), str(unproj)])
		else:
			file.store_line("  CustomWeaponModel NOT FOUND!")
