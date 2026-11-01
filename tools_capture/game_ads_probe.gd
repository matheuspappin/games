extends Node
# Sonda de mira no JOGO REAL: mapa do estande + personagem completo (balanço, câmera, zoom de mira)
const COMBOS := [["ak47", "optic_red_dot"], ["m4a1", "optic_red_dot"], ["scar_h", "optic_red_dot"], ["man_o_war", "optic_red_dot"], ["lmg", "optic_red_dot"], ["rpk", "optic_red_dot"], ["smg", "optic_red_dot"], ["mp7", "optic_red_dot"], ["vmp", "optic_red_dot"], ["pp90m1", "optic_red_dot"], ["m4a1", "optic_holo"], ["rpk", "optic_acog"]]
const WEAPONS := ["ak47", "m4a1", "scar_h", "man_o_war", "lmg", "rpk", "smg", "mp7", "vmp", "pp90m1", "pistol", "deagle", "shotgun", "krm262", "spas12"]
var out := []
func _ready() -> void:
	var map = load("res://scenes/_world/map_firing_range.tscn").instantiate()
	add_child(map)
	_run.call_deferred()
func _aim_point(vm) -> Vector3:
	var data = vm.current_weapon_data
	var cfg = WeaponVisualRegistry.get_weapon_config(data.weapon_id.to_lower())
	var ref = vm._rig_ref_mesh()
	if vm.current_optic_instance and is_instance_valid(vm.current_optic_instance) and vm.current_optic_id != "none":
		return vm.optic_reticle_world()
	if ref and cfg.has("ads_front"):
		return ref.global_transform * (cfg["ads_front"] as Vector3)
	return Vector3.ZERO
func _run() -> void:
	await get_tree().create_timer(4.0).timeout
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		FileAccess.open("res://_prints/game_ads_probe.txt", FileAccess.WRITE).store_string("sem jogador no mapa")
		get_tree().quit(); return
	var cam: Camera3D = get_viewport().get_camera_3d()
	var wm = player.get_node_or_null("Head/Camera/WeaponRig/WeaponManager")
	var vm = player.get_node_or_null("Head/Camera/WeaponRig/FpsHandsViewModel")
	out.append("camera=%s wm=%s vm=%s" % [str(cam.get_path()) if cam else "?", str(wm != null), str(vm != null)])
	var c := get_viewport().get_visible_rect().size / 2.0
	for combo in COMBOS:
		var w: String = combo[0]
		var opt: String = combo[1]
		Input.action_release("ads")
		wm.equip(load("res://resources/weapons/%s.tres" % w))
		await get_tree().create_timer(1.2).timeout
		vm.set_weapon_customization("default", opt, "none", "none", "none", "none", "none")
		await get_tree().create_timer(0.5).timeout
		Input.action_press("ads")
		await get_tree().create_timer(1.2).timeout
		var p := _aim_point(vm)
		var a := cam.unproject_position(p) - c
		get_viewport().get_texture().get_image().save_png("res://_prints/game_ads/%s__%s.png" % [w, opt])
		out.append("%s %s: calculado=(%d,%d)px otica_atual=%s" % [w, opt, a.x, a.y, str(vm.current_optic_id)])
		var refm = vm._rig_ref_mesh()
		var axw: Vector3 = (refm.global_basis * Vector3(0, 0, -1)).normalized()
		if w == "pp90m1": axw = -axw
		out.append("   angulo eixo do modelo x camera: %.2f graus" % rad_to_deg(axw.angle_to(-cam.global_basis.z)))
		var oi = vm.current_optic_instance
		if oi and is_instance_valid(oi):
			out.append("   otica: visivel=%s pai=%s pos_no_glb=%s escala_global=%s dist_camera=%.3f" % [str(oi.is_visible_in_tree()), str(oi.get_parent().name), str(refm.to_local(oi.global_position)), str(oi.global_basis.get_scale()), cam.global_position.distance_to(oi.global_position)])
			var cfgk = WeaponVisualRegistry.get_weapon_config(vm.current_weapon_data.weapon_id.to_lower())
			out.append("   socket_optic=%s optic_rail=%s" % [str(cfgk.get("socket_optic")), str(cfgk.get("optic_rail"))])
		continue
		for i in 30:
			if player.has_method("inject_mouse_delta"):
				player.inject_mouse_delta(Vector2(18, 6))
			elif "camera_system" in player and player.camera_system:
				player.camera_system.inject_mouse_delta(Vector2(18, 6))
			await get_tree().process_frame
		var p2 := _aim_point(vm)
		var b := cam.unproject_position(p2) - c
		get_viewport().get_texture().get_image().save_png("res://_prints/game_ads/%s_mouse.png" % w)
		out.append("%s [otica=%s ads=%.2f fov=%.0f]: parado=(%d,%d)px mexendo_mouse=(%d,%d)px" % [w, str(vm.current_optic_id), float(player.ads_amount), cam.fov, a.x, a.y, b.x, b.y])
	Input.action_release("ads")
	FileAccess.open("res://_prints/game_ads_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
