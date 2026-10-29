extends Node3D
# Laboratório de armas: equipa cada arma no viewmodel e salva prints na cintura e mirando (ADS).
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := "res://_prints/weapons"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	await get_tree().create_timer(2.0).timeout
	var files := DirAccess.get_files_at("res://resources/weapons")
	for f in files:
		if not f.ends_with(".tres"):
			continue
		var data = load("res://resources/weapons/" + f)
		var wid := f.get_basename()
		vm.equip_weapon_data(data)
		vm.set_ads(false)
		await get_tree().create_timer(1.6).timeout
		get_viewport().get_texture().get_image().save_png("%s/%s_hip.png" % [out, wid])
		vm.set_ads(true, 1.0)
		await get_tree().create_timer(1.2).timeout
		get_viewport().get_texture().get_image().save_png("%s/%s_ads.png" % [out, wid])
		vm.set_ads(false)
		await get_tree().create_timer(0.6).timeout
	var fl := FileAccess.open(out + "/FIM.txt", FileAccess.WRITE)
	fl.store_string("ok")
	get_tree().quit()
