extends Node
# Recarga no tempo da arma: estado da animação e munição ao longo da recarga (LMG ~6 s, fuzil ~2 s).
var out := []
func _ready() -> void:
	add_child(load("res://scenes/_world/map_firing_range.tscn").instantiate())
	_run.call_deferred()
func _run() -> void:
	await get_tree().create_timer(4.0).timeout
	var p = get_tree().get_first_node_in_group("player")
	var wm = p.weapon_manager
	var ccs = get_tree().root.find_child("ChooseClassScreen", true, false)
	if ccs: ccs.visible = false
	for w in ["m4a1", "lmg", "lmg"]:
		wm.equip(load("res://resources/weapons/%s.tres" % w))
		await get_tree().create_timer(4.0).timeout
		wm.current_ammo = 5
		var vm = wm.current_viewmodel
		if vm and vm.fps_hands and vm.fps_hands.animation:
			var fh = vm.fps_hands
			var sm = fh.animation.tree_root
			out.append("%s arma=%s ammo_type=%s inv=%s mag=%s estados_reload=%s/%s cur=%s" % [w, fh.weapon.name, fh.weapon.get_meta("ammo_type", "none"), str(fh.inventory.get("ammo")), str(fh.magazine), sm.has_node("reload"), sm.has_node("reload_full"), fh.state_machine.get_current_node()])
		var t0 := Time.get_ticks_msec()
		wm.start_reload()
		var last_st := ""
		var anim_end := -1
		while Time.get_ticks_msec() - t0 < 9000:
			await get_tree().process_frame
			var st := ""
			if vm and vm.fps_hands and vm.fps_hands.state_machine:
				st = str(vm.fps_hands.state_machine.get_current_node())
			if st != last_st:
				out.append("%s t=%.2fs anim=%s municao=%d recarregando=%s" % [w, (Time.get_ticks_msec() - t0) / 1000.0, st, wm.current_ammo, wm.is_reloading])
				last_st = st
			if not wm.is_reloading and not st.begins_with("reload") and Time.get_ticks_msec() - t0 > 300:
				anim_end = Time.get_ticks_msec() - t0
				break
		out.append("%s fim em %.2fs (dados: %.1fs) municao=%d" % [w, anim_end / 1000.0, wm.weapon_data.reload_tactical_time, wm.current_ammo])
	FileAccess.open("res://_prints/reload_time_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
