extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var path = "res://scenes/_world/map_nuk3town_bo3.tscn"
	var err = ResourceLoader.load_threaded_request(path)
	print("Threaded request err: ", err)
	
	var progress = []
	while true:
		var status = ResourceLoader.load_threaded_get_status(path, progress)
		print("Status: ", status, " progress: ", progress[0] if progress.size() > 0 else 0.0)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var scn = ResourceLoader.load_threaded_get(path)
			print("Scn loaded successfully: ", scn)
			break
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			print("Threaded load failed: ", status)
			break
		await process_frame
		
	quit(0)
