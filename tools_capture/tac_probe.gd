extends Node
# Sonda da corrida tática: toque duplo no Shift, velocidade, pose da arma, saída ao atirar e fim da barra
var out := []
func _ready() -> void:
	add_child(load("res://scenes/_world/map_firing_range.tscn").instantiate())
	_run.call_deferred()
func _spd(p) -> float:
	return Vector2(p.velocity.x, p.velocity.z).length()
func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("res://_prints/tac/%s.png" % name)
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints/tac"))
	await get_tree().create_timer(4.0).timeout
	var p = get_tree().get_first_node_in_group("player")
	var wm = p.weapon_manager
	var ccs = get_tree().root.find_child("ChooseClassScreen", true, false)
	if ccs: ccs.visible = false
	p.immobile = false
	p.jumping_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	out.append("countdown=%s mouse=%d" % [str(wm._is_countdown_active()), Input.mouse_mode])
	var gm = get_node_or_null("/root/GameManager")
	if gm and "is_match_active" in gm: gm.is_match_active = true
	var vm = p.get_node_or_null("Head/Camera/WeaponRig/FpsHandsViewModel")
	await get_tree().create_timer(1.0).timeout
	if vm and vm.left_hand_ik:
		var sk: Skeleton3D = vm.left_hand_ik.get_parent() as Skeleton3D
		var cb: Basis = p.CAMERA.global_basis.orthonormalized()
		var names := []
		for i in sk.get_bone_count():
			if sk.get_bone_name(i).begins_with("L_"): names.append(sk.get_bone_name(i))
		out.append("ossos L: " + ", ".join(names))
		var wi: int = vm.left_hand_ik.end_idx
		var wb: Basis = (sk.global_basis * sk.get_bone_global_pose(wi).basis).orthonormalized()
		var rel := cb.inverse() * wb
		out.append("punho em espaco da camera: x=%s y=%s z=%s" % [str(rel.x), str(rel.y), str(rel.z)])
		var wpos: Vector3 = sk.global_transform * sk.get_bone_global_pose(wi).origin
		for nm in names:
			if nm.begins_with("L_middle") or nm.begins_with("L_palm") or nm.begins_with("L_index"):
				var bi := sk.find_bone(nm)
				var bp: Vector3 = sk.global_transform * sk.get_bone_global_pose(bi).origin
				out.append("  %s dir camera=%s dist=%.3f" % [nm, str((cb.inverse() * (bp - wpos)).normalized()), bp.distance_to(wpos)])
		out.append("punho pos camera=%s" % str(p.CAMERA.global_transform.affine_inverse() * wpos))
	for w in ["m4a1", "pistol"]:
		wm.equip(load("res://resources/weapons/%s.tres" % w))
		await get_tree().create_timer(1.5).timeout
		_shot("%s_0_parado" % w)
		Input.action_press("move_forward")
		Input.action_press("sprint")
		await get_tree().create_timer(1.0).timeout
		await get_tree().physics_frame
		out.append("   dbg input=%s moving=%s chao=%s pos=%s mult=%.2f proc_fis=%s" % [str(p.input_dir), str(p.moving), str(p.is_on_floor()), str(p.global_position), p._speed_multiplier(), str(p.is_physics_processing())])
		out.append("%s corrida: estado=%s tac=%s vel=%.2f alvo=%.2f imovel=%s fov=%.1f" % [w, p.state, p.tac_sprinting, _spd(p), p.speed, str(p.immobile), p.CAMERA.fov])
		_shot("%s_1_corrida" % w)
		Input.action_release("sprint")
		await get_tree().create_timer(0.08).timeout
		Input.action_press("sprint")
		await get_tree().create_timer(0.8).timeout
		out.append("%s tatica: estado=%s tac=%s vel=%.2f alvo=%.2f fov=%.1f pose=%.2f barra=%.2f rig=%s" % [w, p.state, p.tac_sprinting, _spd(p), p.speed, p.CAMERA.fov, p.tac_sprint_pose, p.tac_sprint_energy, str(p.viewmodel_rig.rotation_degrees)])
		_shot("%s_2_tatica" % w)
		await get_tree().create_timer(0.17).timeout
		_shot("%s_3_tatica_b" % w)
		# atirar durante a tática: encerra e só dispara após baixar a arma
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var ammo0: int = wm.current_ammo
		var t0 := Time.get_ticks_msec()
		var shot_ms := -1
		out.append("%s antes do tiro: cooldown=%.2f recarregando=%s modo=%d municao=%d" % [w, wm.cooldown_timer, str(wm.is_reloading), wm.weapon_data.fire_mode, wm.current_ammo])
		var ev := InputEventAction.new(); ev.action = "fire"; ev.pressed = true
		Input.parse_input_event(ev)
		for i in 3: await get_tree().process_frame
		out.append("   apos clique: tac=%s estado=%s timer=%.2f fila=%s" % [p.tac_sprinting, p.state, wm.sprint_out_timer, str(wm._queued_shot)])
		var ev2 := InputEventAction.new(); ev2.action = "fire"; ev2.pressed = false
		Input.parse_input_event(ev2)
		while Time.get_ticks_msec() - t0 < 1500:
			await get_tree().process_frame
			if wm.current_ammo < ammo0 and shot_ms < 0:
				shot_ms = Time.get_ticks_msec() - t0
		out.append("%s tiro na tatica: tac=%s estado=%s primeiro tiro apos %d ms" % [w, p.tac_sprinting, p.state, shot_ms])
		Input.action_release("move_forward"); Input.action_release("sprint")
		await get_tree().create_timer(1.2).timeout
	# fim da barra
	p.tac_sprint_energy = 1.0
	Input.action_press("move_forward"); Input.action_press("sprint")
	await get_tree().create_timer(0.6).timeout
	Input.action_release("sprint"); await get_tree().create_timer(0.08).timeout; Input.action_press("sprint")
	await get_tree().create_timer(0.3).timeout
	var t1 := Time.get_ticks_msec()
	while p.tac_sprinting and Time.get_ticks_msec() - t1 < 6000:
		await get_tree().process_frame
	out.append("duracao tatica=%.2fs; depois: estado=%s vel=%.2f barra=%.2f" % [(Time.get_ticks_msec() - t1) / 1000.0 + 0.3, p.state, _spd(p), p.tac_sprint_energy])
	Input.action_release("sprint"); await get_tree().create_timer(0.08).timeout; Input.action_press("sprint")
	await get_tree().create_timer(0.3).timeout
	out.append("reentrada com barra baixa: tac=%s (esperado false)" % p.tac_sprinting)
	Input.action_release("move_forward"); Input.action_release("sprint")
	FileAccess.open("res://_prints/tac_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
