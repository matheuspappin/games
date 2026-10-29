@tool
extends SceneTree

var log_lines = []

func log_msg(msg: String):
	print(msg)
	log_lines.append(msg)

func _init():
	log_msg("--- INSPECTING X_BOT.GLB ---")
	inspect_glb("res://assets/models/mixamo/x_bot.glb")

	log_msg("\n--- INSPECTING CT_URBAN.GLB ---")
	inspect_glb("res://assets/models/mixamo/ct_urban.glb")

	log_msg("\n--- INSPECTING T_LEET.GLB ---")
	inspect_glb("res://assets/models/mixamo/t_leet.glb")

	var f = FileAccess.open("res://debug_inspect_output.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.close()

	quit()

func inspect_glb(path: String):
	var scn = load(path) as PackedScene
	if not scn:
		log_msg("Failed to load: " + path)
		return
	var inst = scn.instantiate()
	log_msg("Root name: " + str(inst.name) + " type: " + str(inst.get_class()))
	
	var ap = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		log_msg("AnimationPlayer found! Animations (" + str(ap.get_animation_list().size()) + "):")
		for anim in ap.get_animation_list():
			log_msg("  - " + str(anim) + " (len: " + str(ap.get_animation(anim).length) + "s, tracks: " + str(ap.get_animation(anim).get_track_count()) + ")")
	else:
		log_msg("NO AnimationPlayer found directly in root scene.")
		var all_aps = inst.find_children("*", "AnimationPlayer", true, false)
		log_msg("All AnimationPlayers found: " + str(all_aps.size()))
		for a in all_aps:
			log_msg("  AP path: " + str(a.get_path()) + " anims: " + str(a.get_animation_list()))

	var skel = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	if not skel:
		var all_skels = inst.find_children("*", "Skeleton3D", true, false)
		if all_skels.size() > 0:
			skel = all_skels[0] as Skeleton3D
	if skel:
		log_msg("Skeleton found: " + str(skel.name) + " with " + str(skel.get_bone_count()) + " bones.")
		log_msg("First 10 bones:")
		for i in range(mini(10, skel.get_bone_count())):
			log_msg("  " + str(i) + ": " + str(skel.get_bone_name(i)))
		var r_hand = skel.find_bone("mixamorig_RightHand")
		log_msg("Right hand bone index: " + str(r_hand))
		if r_hand >= 0:
			log_msg("Right hand rest: " + str(skel.get_bone_rest(r_hand)))
	else:
		log_msg("NO Skeleton3D found!")

	# Check meshes
	var meshes = inst.find_children("*", "MeshInstance3D", true, false)
	log_msg("Meshes found (" + str(meshes.size()) + "):")
	for m in meshes:
		log_msg("  - Mesh: " + str(m.name) + " skin? " + str(m.skin != null) + " skel_path: " + str(m.skeleton))
