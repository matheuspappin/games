extends Node3D

func _ready():
	var scn = load("res://addons/fps-hands/fps-ak/fps-ak.tscn") as PackedScene
	var inst = scn.instantiate()
	var skel = inst.find_child("Skeleton3D", true, false) as Skeleton3D

	var f = FileAccess.open("C:/gemini cli/games/test_bones_out.txt", FileAccess.WRITE)
	if skel:
		f.store_line("Skeleton bone count: %d" % skel.get_bone_count())
		for i in range(skel.get_bone_count()):
			var parent_idx = skel.get_bone_parent(i)
			var parent_name = skel.get_bone_name(parent_idx) if parent_idx >= 0 else "NONE"
			f.store_line("  Bone %d: '%s' (parent=%s), rest_pos=%s, rest_rot=%s" % [
				i, skel.get_bone_name(i), parent_name,
				str(skel.get_bone_rest(i).origin),
				str(skel.get_bone_rest(i).basis.get_euler())
			])
	f.close()
	get_tree().quit(0)
