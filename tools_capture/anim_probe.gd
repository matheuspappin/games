extends Node
# Lista o que as animações de recarga das armas nativas movem (para o pente do modelo customizado acompanhar).
func _ready() -> void:
	var out := []
	for w in ["fps-ak/fps-ak.tscn", "fps-smg45/fps-smg45.tscn", "fps-c19/fps-c19.tscn", "fps-lmg63/fps-lmg63.tscn", "fps-sawnoff/fps-sawnoff.tscn"]:
		var path: String = "res://addons/fps-hands/" + w
		if not ResourceLoader.exists(path):
			out.append("%s: nao existe" % w); continue
		var inst: Node = load(path).instantiate()
		var aps := inst.find_children("*", "AnimationPlayer", true, false)
		for ap in aps:
			for lib_name in ap.get_animation_library_list():
				var lib: AnimationLibrary = ap.get_animation_library(lib_name)
				for an in lib.get_animation_list():
					if not an.begins_with("reload"): continue
					var a: Animation = lib.get_animation(an)
					var tracks := []
					for t in a.get_track_count():
						var p: String = str(a.track_get_path(t))
						if not ("Skeleton3D:" in p and ("_L" in p or "L_" in p or "R_" in p)):
							tracks.append(p + "(" + str(a.track_get_type(t)) + ")")
					out.append("%s | %s %.2fs | %s" % [w.get_file(), an, a.length, ", ".join(tracks.slice(0, 14))])
		inst.free()
	FileAccess.open("res://_prints/anim_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
