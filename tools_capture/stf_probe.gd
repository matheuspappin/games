extends Node
func _ready() -> void:
	add_child(load("res://scenes/_world/map_firing_range.tscn").instantiate())
	_run.call_deferred()
func _run() -> void:
	await get_tree().create_timer(4.0).timeout
	var player = get_tree().get_first_node_in_group("player")
	var wm = player.weapon_manager
	var gm = get_node("/root/GameManager")
	var ccs = get_tree().root.find_child("ChooseClassScreen", true, false)
	if ccs: ccs.visible = false
	player.immobile = false
	var out := []
	for cfg in [["m4a1", "none", "none"], ["m4a1", "stock_light", "none"], ["m4a1", "none", "grip_stippled"], ["m4a1", "stock_heavy", "none"], ["lmg", "none", "none"], ["pistol", "none", "none"]]:
		gm.primary_weapon_res = "res://resources/weapons/%s.tres" % cfg[0]
		gm.set_weapon_customization("default", "none", "none", "none", "none", cfg[1], cfg[2], "none")
		wm.equip(gm.get_primary_weapon())
		await get_tree().create_timer(1.5).timeout
		# saída do sprint
		player.state = "sprinting"
		wm._was_sprinting = true
		var ammo0: int = wm.current_ammo
		var t0 := Time.get_ticks_msec()
		wm.try_fire()
		var fired_ms := -1
		for i in 60:
			await get_tree().process_frame
			if wm.current_ammo < ammo0:
				fired_ms = Time.get_ticks_msec() - t0
				break
		# flinch
		player._cam_flinch_vel = Vector3.ZERO
		seed(7)
		player._apply_damage_flinch(30, Vector3.ZERO)
		var fl: float = rad_to_deg(player._cam_flinch_vel.length())
		out.append("%s coronha=%s cabo=%s | tiro saiu após o sprint em %d ms (esperado %.0f ms) | tranco %.2f° | mult sprint=%.2f flinch=%.2f" % [cfg[0], cfg[1], cfg[2], fired_ms, wm._sprint_to_fire_time() * 1000.0, fl, wm.weapon_data.sprint_to_fire_mult, wm.weapon_data.flinch_mult])
		await get_tree().create_timer(0.6).timeout
	FileAccess.open("res://_prints/stf_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
