extends Node3D
# Revisão de qualidade: cada arma em 5 vistas (quadril, lado direito, lado esquerdo, close da mão esquerda, mira)
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
const WEAPONS := ["m4a1", "spas12", "smg", "mp7"]

func _ready() -> void:
	_run.call_deferred()

func _shot(cam_pos: Vector3, target: Vector3, fov: float, path: String) -> void:
	var c := Camera3D.new()
	c.fov = fov; c.near = 0.005; c.cull_mask = 0xFFFFF
	add_child(c)
	c.global_position = cam_pos
	c.look_at(target, Vector3.UP)
	c.make_current()
	var lamp := OmniLight3D.new()
	lamp.omni_range = 4.0; lamp.light_energy = 2.0
	add_child(lamp)
	lamp.global_position = cam_pos + Vector3(0, 0.4, 0)
	await get_tree().create_timer(0.35).timeout
	get_viewport().get_texture().get_image().save_png(path)
	$Camera.make_current()
	c.queue_free(); lamp.queue_free()

func _palm() -> Vector3:
	var sk: Skeleton3D = vm.left_hand_ik.get_parent() as Skeleton3D if vm.left_hand_ik else null
	if not sk: return Vector3.ZERO
	var i := -1
	for b in sk.get_bone_count():
		if sk.get_bone_name(b).begins_with("L_palm"): i = b; break
	return sk.global_transform * sk.get_bone_global_pose(i).origin if i >= 0 else Vector3.ZERO

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints/review"))
	await get_tree().create_timer(2.0).timeout
	var main_cam: Camera3D = $Camera
	for wid in WEAPONS:
		vm.equip_weapon_data(load("res://resources/weapons/%s.tres" % wid))
		await get_tree().create_timer(1.6).timeout
		vm.set_weapon_customization("default", "none", "none", "none", "none", "none", "none")
		vm.set_ads(false)
		await get_tree().create_timer(0.9).timeout
		get_viewport().get_texture().get_image().save_png("res://_prints/review/%s_1_quadril.png" % wid)
		var target: Vector3 = main_cam.to_global(Vector3(0.08, -0.22, -0.65))
		var right: Vector3 = main_cam.global_basis.x
		await _shot(target + right * 1.9 + Vector3(0, 0.15, 0), target, 40.0, "res://_prints/review/%s_2_lado_dir.png" % wid)
		await _shot(target - right * 1.9 + Vector3(0, 0.15, 0), target, 40.0, "res://_prints/review/%s_3_lado_esq.png" % wid)
		var palm := _palm()
		if palm != Vector3.ZERO:
			await _shot(palm - right * 0.45 + Vector3(0, -0.12, 0.05), palm, 45.0, "res://_prints/review/%s_4_mao_esq.png" % wid)
		vm.set_ads(true, 1.0)
		await get_tree().create_timer(1.2).timeout
		get_viewport().get_texture().get_image().save_png("res://_prints/review/%s_5_mira.png" % wid)
		vm.set_ads(false)
		await get_tree().create_timer(0.5).timeout
	get_tree().quit()
