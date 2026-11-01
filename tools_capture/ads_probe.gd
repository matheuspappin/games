extends Node3D
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
@onready var cam: Camera3D = $Camera
const WEAPONS := ["ak47", "m4a1", "scar_h", "man_o_war", "lmg", "rpk", "smg", "mp7", "vmp", "pp90m1", "pistol", "deagle", "shotgun", "krm262", "spas12"]
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	var out := []
	var c := get_viewport().get_visible_rect().size / 2.0
	for w in WEAPONS:
		var data = load("res://resources/weapons/%s.tres" % w)
		vm.equip_weapon_data(data)
		vm.set_ads(false)
		await get_tree().create_timer(1.4).timeout
		vm.set_ads(true, 1.0)
		await get_tree().create_timer(1.0).timeout
		var cfg = WeaponVisualRegistry.get_weapon_config(data.weapon_id.to_lower())
		var ref = vm._rig_ref_mesh()
		var line := "%s [otica=%s braços=%s]:" % [w, str(vm.current_optic_id), str(cfg.get("has_arms", true))]
		if ref and cfg.has("ads_front"):
			var r: Vector3 = ref.global_transform * (cfg["ads_rear"] as Vector3)
			var f: Vector3 = ref.global_transform * (cfg["ads_front"] as Vector3)
			var rp := cam.unproject_position(r) - c
			var fp := cam.unproject_position(f) - c
			var wpm: float = ref.global_basis.get_scale().x
			var eye_cm: float = -cam.to_local(r).z / wpm * 100.0
			line += " massa=(%d,%d)px alça=(%d,%d)px paralelismo=(%d,%d)px olho->alça=%.1fcm" % [fp.x, fp.y, rp.x, rp.y, rp.x - fp.x, rp.y - fp.y, eye_cm]
			var piv = vm.current_custom_model_instance.get_node_or_null("Pivot")
			if vm.current_optic_instance and is_instance_valid(vm.current_optic_instance):
				var ret: Vector3 = vm.OPTIC_RETICLE_OFFSETS.get(vm.current_optic_id, Vector3(0.0, 0.027023, -0.010408))
				var o_s: Vector3 = vm.current_optic_instance.scale
				var rw: Vector3 = vm.current_optic_instance.global_transform * Vector3(ret.x / o_s.x, ret.y / o_s.y, ret.z / o_s.z)
				var rpp := cam.unproject_position(rw) - c
				line += " RETICULO=(%d,%d)px olho->retículo=%.1fcm" % [rpp.x, rpp.y, -cam.to_local(rw).z / wpm * 100.0]
				line += " | glb: camera=%s retículo=%s otica_origem=%s" % [str(ref.to_local(cam.global_position)), str(ref.to_local(rw)), str(ref.to_local(vm.current_optic_instance.global_position))]
		else:
			line += " sem pontos de mira"
		out.append(line)
		get_viewport().get_texture().get_image().save_png("res://_prints/ads/%s.png" % w)
	FileAccess.open("res://_prints/ads_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
