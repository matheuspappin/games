extends Node
# Sequência de prints correndo de verdade (área aberta x=100): corrida normal e tática, fuzil e pistola
var p
const O := Vector3(100, 0, 0)
func _ready() -> void:
	add_child(load("res://scenes/_world/map_firing_range.tscn").instantiate())
	_run.call_deferred()
func _box(pos: Vector3, size: Vector3) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = size; cs.shape = bs; sb.add_child(cs)
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; sb.add_child(mi)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.45, 0.5, 0.42); mi.material_override = mat
	add_child(sb); sb.global_position = pos
func _act(a: String, down: bool) -> void:
	var ev := InputEventAction.new(); ev.action = a; ev.pressed = down; Input.parse_input_event(ev)
func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_prints/run/%s.png" % n)
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints/run"))
	await get_tree().create_timer(4.0).timeout
	p = get_tree().get_first_node_in_group("player")
	var ccs = get_tree().root.find_child("ChooseClassScreen", true, false)
	if ccs: ccs.visible = false
	p.immobile = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_box(O + Vector3(0, -0.5, -60), Vector3(40, 1, 160))
	for i in 12:
		_box(O + Vector3(-6 if i % 2 == 0 else 6, 1.0, -i * 10.0), Vector3(1, 2, 1))
	var wm = p.weapon_manager
	for w in ["m4a1", "pistol"]:
		wm.equip(load("res://resources/weapons/%s.tres" % w))
		p.global_position = O + Vector3(0, 0.05, 15); p.velocity = Vector3.ZERO; p.rotation.y = 0.0; p.HEAD.rotation = Vector3.ZERO
		p.tac_sprint_energy = 1.0
		await get_tree().create_timer(1.3).timeout
		_act("move_forward", true); _act("sprint", true)
		await get_tree().create_timer(1.0).timeout
		for i in 4:
			await _shot("%s_corrida_%d" % [w, i])
			await get_tree().create_timer(0.09).timeout
		_act("sprint", false); await get_tree().create_timer(0.08).timeout; _act("sprint", true)
		await get_tree().create_timer(0.6).timeout
		var info := "%s tatica=%s vel=%.2f" % [w, str(p.tac_sprinting), Vector2(p.velocity.x, p.velocity.z).length()]
		FileAccess.open("res://_prints/run/info_%s.txt" % w, FileAccess.WRITE).store_string(info)
		for i in 8:
			await _shot("%s_tatica_%d" % [w, i])
			await get_tree().create_timer(0.07).timeout
		_act("move_forward", false); _act("sprint", false)
		await get_tree().create_timer(1.0).timeout
	get_tree().quit()
