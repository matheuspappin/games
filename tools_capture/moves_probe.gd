extends Node
# Sonda de deitar / inclinar / escalar numa área de teste própria (x=100) dentro do mapa do estande
var out := []
var p
var ext_cam: Camera3D
const O := Vector3(100, 0, 0)

func _ready() -> void:
	add_child(load("res://scenes/_world/map_firing_range.tscn").instantiate())
	_run.call_deferred()

func _box(pos: Vector3, size: Vector3) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = size; cs.shape = bs; sb.add_child(cs)
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; sb.add_child(mi)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.55, 0.6, 0.7); mi.material_override = mat
	add_child(sb); sb.global_position = pos

func _act(a: String, down: bool) -> void:
	var ev := InputEventAction.new(); ev.action = a; ev.pressed = down; Input.parse_input_event(ev)

func _tap(a: String) -> void:
	_act(a, true); await get_tree().physics_frame; await get_tree().physics_frame; _act(a, false)

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_prints/moves/%s.png" % n)

func _ext(n: String, off: Vector3) -> void:
	var target: Vector3 = p.global_position + Vector3(0, 0.7, 0)
	ext_cam.global_position = target + off
	ext_cam.look_at(target)
	ext_cam.current = true
	await get_tree().process_frame
	await _shot(n)
	p.CAMERA.current = true

func _hb(n: String) -> Vector3:
	var hb = p.get_node_or_null(n)
	return (hb.get_child(0).global_position - p.global_position) if hb else Vector3.ZERO

func _tp(pos: Vector3) -> void:
	p.global_position = pos; p.velocity = Vector3.ZERO; p.rotation.y = 0.0; p.HEAD.rotation = Vector3.ZERO
	await get_tree().physics_frame

func _st() -> String:
	return "estado=%s cabeca=%.2f capsula=%.2f pos=%s tiro_bloq=%s" % [p.state, p.HEAD.position.y, (p.COLLISION_MESH.shape as CapsuleShape3D).height, str((p.global_position - O).snapped(Vector3.ONE * 0.01)), str(p.blocks_firing())]

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints/moves"))
	await _wait(4.0)
	p = get_tree().get_first_node_in_group("player")
	var ccs = get_tree().root.find_child("ChooseClassScreen", true, false)
	if ccs: ccs.visible = false
	p.immobile = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for vi in p.shadow_soldier.find_children("*", "GeometryInstance3D", true, false):
		vi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	ext_cam = Camera3D.new(); add_child(ext_cam)
	# área de teste
	_box(O + Vector3(0, -0.5, 0), Vector3(30, 1, 30))
	_box(O + Vector3(0, 0.5, -3.0), Vector3(3, 1.0, 2))        # plataforma 1,0 m (z -2..-4)
	_box(O + Vector3(6, 0.45, -3.0), Vector3(3, 0.9, 0.25))    # mureta 0,9 m fina
	_box(O + Vector3(-6, 0.95, -3.0), Vector3(3, 1.9, 2))      # plataforma 1,9 m
	_box(O + Vector3(12, 1.5, -3.0), Vector3(3, 3.0, 2))       # parede 3 m (não escala)
	_box(O + Vector3(-12.75, 1.5, 6), Vector3(0.5, 3, 4))      # parede à esquerda (inclinação)
	await _wait(0.5)

	# ── DEITAR ──
	await _tp(O + Vector3(0, 0.05, 6))
	await _shot("00_em_pe")
	out.append("em pe: " + _st() + " | hb cabeca=%s peito=%s" % [str(_hb("Hitbox_Head").snapped(Vector3.ONE*0.01)), str(_hb("Hitbox_Chest").snapped(Vector3.ONE*0.01))])
	await _ext("00_ext_em_pe", Vector3(2.0, 0.6, 1.6))
	await _tap("prone"); await _wait(0.8)
	out.append("deitado: " + _st() + " | hb cabeca=%s peito=%s pernas=%s" % [str(_hb("Hitbox_Head").snapped(Vector3.ONE*0.01)), str(_hb("Hitbox_Chest").snapped(Vector3.ONE*0.01)), str(_hb("Hitbox_Legs").snapped(Vector3.ONE*0.01))])
	await _shot("01_deitado")
	await _ext("01_ext_deitado", Vector3(2.4, 1.0, 1.0))
	Input.action_press("move_forward"); await _wait(1.0)
	out.append("rastejando: vel=%.2f " % Vector2(p.velocity.x, p.velocity.z).length() + _st())
	await _shot("02_rastejando")
	Input.action_release("move_forward"); await _wait(0.5)
	out.append("parado deitado: " + _st())
	await _tap("jump"); await _wait(0.6)
	out.append("espaco no deitado -> " + _st())
	_act("crouch", true); await _wait(0.6)
	out.append("segurando agachar: " + _st())
	await _ext("03_ext_agachado", Vector3(2.0, 0.4, 0.0))
	_act("crouch", false); await _wait(0.5)
	out.append("soltou agachar: " + _st())
	await _tap("prone"); await _wait(0.7)
	await _tap("prone"); await _wait(0.7)
	out.append("Z de novo (levanta): " + _st())

	# ── INCLINAR ──
	await _tp(O + Vector3(-6, 0.05, 6))
	_act("lean_left", true); await _wait(0.6)
	out.append("inclinar esq (livre): lean=%.2f cam_x=%.2f roll=%.1f hb cabeca x=%.2f" % [p.lean_amount, p.CAMERA.position.x, rad_to_deg(p.CAMERA.rotation.z), _hb("Hitbox_Head").x])
	await _shot("04_inclinar_esq")
	await _ext("04_ext_inclinar_esq", Vector3(0.0, 0.8, 2.6))
	_act("lean_left", false)
	_act("lean_right", true); await _wait(0.6)
	out.append("inclinar dir: lean=%.2f roll=%.1f" % [p.lean_amount, rad_to_deg(p.CAMERA.rotation.z)])
	await _shot("05_inclinar_dir")
	_act("lean_right", false); await _wait(0.4)
	await _tp(O + Vector3(-12.0, 0.05, 6))   # parede logo à esquerda
	_act("lean_left", true); await _wait(0.6)
	out.append("inclinar esq com parede a 0,5 m: lean=%.2f (esperado < 1)" % p.lean_amount)
	_act("lean_left", false); await _wait(0.3)

	# ── ESCALAR ──
	for t in [["plataforma 1,0 m", Vector3(0, 0.05, -0.8), "06"], ["mureta fina 0,9 m", Vector3(6, 0.05, -2.2), "07"], ["plataforma 1,9 m", Vector3(-6, 0.05, -1.2), "08"], ["parede 3 m", Vector3(12, 0.05, -1.2), "09"]]:
		await _tp(O + t[1])
		await _wait(0.3)
		Input.action_press("move_forward")
		await _wait(0.15)
		var y0: float = p.global_position.y
		await _tap("jump")
		var started: bool = false
		var peak: float = -99.0
		var t0 := Time.get_ticks_msec()
		var shot_mid := false
		while Time.get_ticks_msec() - t0 < 1500:
			await get_tree().physics_frame
			if p.mantling: started = true
			peak = maxf(peak, p.global_position.y)
			if not p.mantling and started and Input.is_action_pressed("move_forward"):
				Input.action_release("move_forward")
			if p.mantling and not shot_mid and Time.get_ticks_msec() - t0 > 150:
				shot_mid = true
				await _shot(t[2] + "_meio_escalada")
		Input.action_release("move_forward")
		await _wait(0.4)
		out.append("%s: escalou=%s pico=%.2f y final=%.2f (inicio %.2f) pos=%s estado=%s" % [t[0], str(started), peak, p.global_position.y, y0, str((p.global_position - O).snapped(Vector3.ONE * 0.01)), p.state])
	await _shot("10_final")
	FileAccess.open("res://_prints/moves_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
