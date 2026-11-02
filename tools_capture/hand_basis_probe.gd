extends Node3D
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	vm.equip_weapon_data(load("res://resources/weapons/smg.tres"))
	await get_tree().create_timer(2.5).timeout
	var sk: Skeleton3D = vm.left_hand_ik.get_parent() as Skeleton3D
	var wi := sk.find_bone("L_wrist_03")
	var wrist_g: Basis = (sk.global_transform * sk.get_bone_global_pose(wi)).basis.orthonormalized()
	var ref = vm._rig_ref_mesh()
	var h: Quaternion = (ref.global_basis.orthonormalized().inverse() * wrist_g).get_rotation_quaternion()
	FileAccess.open("res://_prints/hand_basis.txt", FileAccess.WRITE).store_string("Quaternion(%f, %f, %f, %f)" % [h.x, h.y, h.z, h.w])
	get_tree().quit()
