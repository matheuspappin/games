extends Node
# Sonda da mão solta na corrida tática: testa orientações da palma e fotografa fases da passada.
var out := []
const CANDS := [["v2", Vector3(1.0, 0.25, 0.0), 0.9]]
func _ready() -> void:
	add_child(load("res://scenes/_world/map_firing_range.tscn").instantiate())
	_run.call_deferred()
func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("res://_prints/swing/%s.png" % name)
func _axes(p, vm) -> String:
	var sk: Skeleton3D = vm.left_hand_ik.get_parent() as Skeleton3D
	var cb: Basis = p.CAMERA.global_basis.orthonormalized()
	var wi: int = vm.left_hand_ik.end_idx
	var wb: Basis = (sk.global_basis * sk.get_bone_global_pose(wi).basis).orthonormalized()
	var rel := cb.inverse() * wb
	var wpos: Vector3 = sk.global_transform * sk.get_bone_global_pose(wi).origin
	var mi := sk.find_bone("L_middle1_011")
	var mp: Vector3 = sk.global_transform * sk.get_bone_global_pose(mi).origin
	var pi := sk.find_bone("L_palm_015")
	var pp: Vector3 = sk.global_transform * sk.get_bone_global_pose(pi).origin
	var ti := sk.find_bone("L_thumb1_04")
	var tp: Vector3 = sk.global_transform * sk.get_bone_global_pose(ti).origin
	var scr: Vector2 = p.CAMERA.unproject_position(wpos)
	return "y=%s dedos=%s polegar=%s palma=%s tela=%s" % [str(rel.y.snapped(Vector3.ONE*0.01)), str((cb.inverse()*(mp-wpos)).normalized().snapped(Vector3.ONE*0.01)), str((cb.inverse()*(tp-wpos)).normalized().snapped(Vector3.ONE*0.01)), str((cb.inverse()*(pp-wpos)).normalized().snapped(Vector3.ONE*0.01)), str(scr.round())]
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints/swing"))
	await get_tree().create_timer(4.0).timeout
	var p = get_tree().get_first_node_in_group("player")
	var wm = p.weapon_manager
	var ccs = get_tree().root.find_child("ChooseClassScreen", true, false)
	if ccs: ccs.visible = false
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		c.visible = false
	p.immobile = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var gm = get_node_or_null("/root/GameManager")
	if gm and "is_match_active" in gm: gm.is_match_active = true
	var vm = p.get_node_or_null("Head/Camera/WeaponRig/FpsHandsViewModel")
	var weapons := ["m4a1"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--weapons="): weapons = Array(a.substr(10).split(","))
	for w in weapons:
		wm.equip(load("res://resources/weapons/%s.tres" % w))
		await get_tree().create_timer(1.2).timeout
		for c in CANDS:
			vm.swing_palm_cam = c[1]; vm.swing_twist_limit = c[2]
			p.tac_sprint_energy = 1.0
			p.global_position = Vector3(0, p.global_position.y, 0)
			Input.action_press("move_forward"); Input.action_press("sprint")
			await get_tree().create_timer(0.5).timeout
			Input.action_release("sprint"); await get_tree().create_timer(0.08).timeout; Input.action_press("sprint")
			await get_tree().create_timer(0.7).timeout
			for k in 4:
				_shot("%s_%s_%d" % [w, c[0], k])
				out.append("%s %s f%d tac=%s amt=%.2f %s" % [w, c[0], k, p.tac_sprinting, vm._swing_amount, _axes(p, vm)])
				await get_tree().create_timer(0.09).timeout
			Input.action_release("move_forward"); Input.action_release("sprint")
			await get_tree().create_timer(1.0).timeout
	FileAccess.open("res://_prints/swing_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
