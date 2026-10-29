extends SceneTree

func _init():
	var t0 = Time.get_ticks_msec()
	var scn = load("res://scenes/_world/map_nuk3town_bo3.tscn")
	var t1 = Time.get_ticks_msec()
	print("Load synchronous took: ", (t1 - t0), " ms. Scn: ", scn)
	quit()
