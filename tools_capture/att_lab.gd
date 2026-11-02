extends Node3D
# Laboratório de acessórios: cada arma sem nada e com montagem completa, na cintura e no ADS.
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
const WEAPONS := ["ak47", "m4a1", "scar_h", "lmg", "smg", "mp7", "pp90m1", "spas12", "krm262"]
const FULL := ["optic_holo", "muzzle_suppressor", "mag_extended", "grip_vertical", "stock_heavy", "none"]
var lines := []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints/att"))
	await get_tree().create_timer(2.0).timeout
	for wid in WEAPONS:
		for mode in ["cano_longo", "cano_curto"]:
			vm.equip_weapon_data(load("res://resources/weapons/%s.tres" % wid))
			await get_tree().create_timer(1.6).timeout
			if mode == "cano_longo":
				vm.set_weapon_customization("default", "none", "muzzle_suppressor", "none", "none", "none", "none", "barrel_extended")
			elif mode == "cano_curto":
				vm.set_weapon_customization("default", "none", "none", "none", "none", "none", "none", "barrel_short")
			elif mode == "completa":
				vm.set_weapon_customization("default", FULL[0], FULL[1], FULL[2], FULL[3], FULL[4], FULL[5])
			else:
				vm.set_weapon_customization("default", "none", "none", "none", "none", "none", "none")
			vm.set_ads(false)
			await get_tree().create_timer(0.8).timeout
			get_viewport().get_texture().get_image().save_png("res://_prints/att/%s_%s_hip.png" % [wid, mode])
			var cont = vm.current_custom_model_instance.get_node_or_null("Pivot/AttachmentContainer") if vm.current_custom_model_instance else null
			var names := []
			if cont:
				for c in cont.get_children(): names.append(String(c.name))
			lines.append("%s %s | acessorios=%s | optica=%s" % [wid, mode, str(names), vm.current_optic_instance != null if "current_optic_instance" in vm else "?"])
			# vista lateral (perfil) da arma montada
			var main_cam: Camera3D = $Camera
			var side := Camera3D.new()
			side.fov = 40.0
			side.near = 0.01
			add_child(side)
			var target: Vector3 = main_cam.to_global(Vector3(0.08, -0.22, -0.55))
			side.global_position = target + main_cam.global_basis.x * 1.3 + Vector3(0, 0.15, 0)
			side.look_at(target, Vector3.UP)
			side.cull_mask = 0xFFFFF
			side.make_current()
			var lamp := OmniLight3D.new()
			lamp.omni_range = 4.0
			lamp.light_energy = 2.5
			add_child(lamp)
			lamp.global_position = side.global_position + Vector3(0, 0.5, 0)
			await get_tree().create_timer(0.4).timeout
			get_viewport().get_texture().get_image().save_png("res://_prints/att/%s_%s_side.png" % [wid, mode])
			main_cam.make_current()
			side.queue_free()
			lamp.queue_free()
			vm.set_ads(true, 1.0)
			await get_tree().create_timer(1.2).timeout
			get_viewport().get_texture().get_image().save_png("res://_prints/att/%s_%s_ads.png" % [wid, mode])
			vm.set_ads(false)
			await get_tree().create_timer(0.5).timeout
	FileAccess.open("res://_prints/att_lab.txt", FileAccess.WRITE).store_string("\n".join(lines))
	get_tree().quit()
