extends Node3D
# ADS com mira óptica: onde o centro da retícula cai na tela (tem que ser no centro).
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
@onready var cam: Camera3D = $Camera
const WEAPONS := ["ak47", "m4a1"]
const OPTICS := ["optic_acog"]

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints/ads"))
	await get_tree().create_timer(2.0).timeout
	var out := []
	var center := get_viewport().get_visible_rect().size * 0.5
	for wid in WEAPONS:
		for optic in OPTICS:
			vm.equip_weapon_data(load("res://resources/weapons/%s.tres" % wid))
			await get_tree().create_timer(1.4).timeout
			vm.set_weapon_customization("default", optic, "none", "none", "none", "none", "none")
			await get_tree().create_timer(0.3).timeout
			vm.set_ads(true, 1.0)
			await get_tree().create_timer(1.3).timeout
			var o = vm.current_optic_instance
			if not o:
				out.append("%s %s | sem mira" % [wid, optic]); continue
			var ret: Node3D = null
			var all_names := []
			for n in o.find_children("*", "Node3D", true, false):
				all_names.append(String(n.name))
				if "reticle" in String(n.name).to_lower() and ret == null:
					ret = n
			out.append(wid + " nos da acog: " + str(all_names))
			var p: Vector3 = (ret if ret else o).global_position
			if ret is MeshInstance3D:
				p = ret.global_transform * ret.get_aabb().get_center()
			var sp := cam.unproject_position(p)
			var off := sp - center
			out.append("%s %s | retícula a (%.0f, %.0f) px do centro | dist=%.1f cm" % [wid, optic, off.x, off.y, cam.global_position.distance_to(p) * 100.0])
			if optic == "optic_acog":
				get_viewport().get_texture().get_image().save_png("res://_prints/ads/%s.png" % wid)
			vm.set_ads(false)
			await get_tree().create_timer(0.4).timeout
	FileAccess.open("res://_prints/ads_optic_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
