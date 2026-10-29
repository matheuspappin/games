extends Node3D

func _ready():
	var f = FileAccess.open("C:/gemini cli/games/test_check_meshes_out.txt", FileAccess.WRITE)
	var log_msg = func(s: String):
		print(s)
		if f: f.store_line(s)

	var scenes = [
		"res://addons/fps-hands/fps-ak/fps-ak.tscn",
		"res://addons/fps-hands/fps-c19/fps-c19.tscn",
		"res://addons/fps-hands/fps-smg45/fps-smg45.tscn",
		"res://addons/fps-hands/fps-lmg63/fps-lmg63.tscn",
		"res://addons/fps-hands/fps-sawnoff/fps-sawnoff.tscn",
		"res://addons/fps-hands/fps-knife/fps-knife.tscn"
	]
	
	for p in scenes:
		log_msg.call("=== " + p + " ===")
		var scn = load(p) as PackedScene
		if not scn:
			log_msg.call("FAILED TO LOAD")
			continue
		var inst = scn.instantiate()
		for child in inst.find_children("*", "MeshInstance3D", true, false):
			var m = child as MeshInstance3D
			var parent_name = m.get_parent().name if m.get_parent() else "none"
			var parent_class = m.get_parent().get_class() if m.get_parent() else "none"
			log_msg.call("  Mesh: name='%s', path='%s', parent='%s' (%s), mat='%s'" % [m.name, m.get_path(), parent_name, parent_class, str(m.material_override)])
		inst.free()

	if f: f.close()
	get_tree().quit(0)
