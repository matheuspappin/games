extends Node3D
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints/ik"))
	await get_tree().create_timer(2.0).timeout
	for wid in ["m4a1", "krm262"]:
		vm.equip_weapon_data(load("res://resources/weapons/%s.tres" % wid))
		vm.set_ads(false)
		await get_tree().create_timer(2.0).timeout
		vm.set_process(false)
		var ik = vm.left_hand_ik
		var skel: Skeleton3D = ik.get_parent()
		var info := "modo=%s " % skel.modifier_callback_mode_process
		for v in [0.0, 1.0]:
			ik.influence = v
			await get_tree().create_timer(0.3).timeout
			get_viewport().get_texture().get_image().save_png("res://_prints/ik/%s_%d.png" % [wid, int(v)])
		vm.set_process(true)
		FileAccess.open("res://_prints/ik/%s_info.txt" % wid, FileAccess.WRITE).store_string(info)
	FileAccess.open("res://_prints/ik/FIM.txt", FileAccess.WRITE).store_string("ok")
	get_tree().quit()
