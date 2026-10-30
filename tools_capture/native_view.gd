extends Node3D
# Mostra a arma NATIVA do addon (sem modelo customizado) para servir de referência visual.
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints/native"))
	await get_tree().create_timer(2.0).timeout
	for wid in ["pistol", "ak47", "lmg"]:
		vm.equip_weapon_data(load("res://resources/weapons/%s.tres" % wid))
		vm.set_ads(false)
		await get_tree().create_timer(1.6).timeout
		if vm.current_custom_model_instance:
			vm.current_custom_model_instance.visible = false
		for m in vm.fps_hands.weapon.find_children("*", "Node3D", true, false):
			m.visible = true
			if m is VisualInstance3D:
				m.layers = 2
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png("res://_prints/native/%s_hip.png" % wid)
	FileAccess.open("res://_prints/native/FIM.txt", FileAccess.WRITE).store_string("ok")
	get_tree().quit()
