extends Node3D
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
@onready var cam: Camera3D = $Camera
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	var out := []
	for wid in ["rpk", "lmg"]:
		vm.equip_weapon_data(load("res://resources/weapons/%s.tres" % wid))
		await get_tree().create_timer(1.6).timeout
		vm.set_ads(true, 1.0)
		await get_tree().create_timer(1.5).timeout
		var model: Node3D = vm.current_custom_model_instance
		var pivot: Node3D = model.get_node("Pivot")
		var cfg = WeaponVisualRegistry.get_weapon_config(wid)
		var s_cam := cam.to_local(pivot.to_global(cfg.get("socket_iron_ads", Vector3.ZERO)))
		var parts := []
		for m in model.find_children("*", "MeshInstance3D", true, false):
			if not m.is_visible_in_tree():
				continue
			var b: AABB = m.global_transform * m.get_aabb()
			var lb := AABB(cam.to_local(b.position), b.size)
			if lb.size.length() > 0.15:
				parts.append("%s %s" % [m.name, str(lb)])
		out.append("%s ads_amount=%s optic=%s sight_cam=%s pivot_scale=%s | %s" % [wid, vm.current_ads_amount, vm.current_optic_id, s_cam, pivot.global_basis.get_scale(), " ; ".join(parts)])
		vm.set_ads(false)
		await get_tree().create_timer(0.6).timeout
	FileAccess.open("res://_prints/ads_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
