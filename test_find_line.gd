extends SceneTree

func _init() -> void:
	var f = FileAccess.open("res://scripts/ui/lobby_screen.gd", FileAccess.READ)
	var txt = f.get_as_text()
	f.close()
	var lines = txt.split("\n")
	
	print("Binary search / progressive test of lobby_screen.gd...")
	# Let's test chunks
	for n in range(800, lines.size(), 50):
		var sub_lines = lines.slice(0, n)
		var scr = GDScript.new()
		scr.source_code = "\n".join(sub_lines)
		var err = scr.reload()
		if err != OK:
			print("Failed at line count: ", n)
			# Find exact line
			for line_idx in range(n - 50, n + 1):
				var check_lines = lines.slice(0, line_idx)
				var s = GDScript.new()
				s.source_code = "\n".join(check_lines)
				if s.reload() != OK:
					print("EXACT FAILING LINE: ", line_idx)
					print("Line content: ", lines[line_idx - 1])
					quit(1)
					return
			quit(1)
			return
	print("Whole file parsed?!")
	quit(0)
