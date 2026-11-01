extends Node3D
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
func _ready() -> void:
	_run.call_deferred()
func _len(nodes: Array) -> float:
	var bb := AABB(); var f := true
	for m in nodes:
		var b: AABB = m.global_transform * m.get_aabb()
		bb = b if f else bb.merge(b); f = false
	return bb.get_longest_axis_size()
func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	vm.equip_weapon_data(load("res://resources/weapons/ak47.tres"))
	await get_tree().create_timer(1.6).timeout
	var model: Node3D = vm.current_custom_model_instance
	var rec := []
	for m in model.find_children("*", "MeshInstance3D", true, false):
		if String(m.name).begins_with("Receiver"): rec.append(m)
	var base_mesh = vm.fps_hands.weapon.find_child("base_ak74_0", true, false)
	var out := "ACR=%.4f AK=%.4f razao=%.3f | base.global_scale=%s model.scale=%s" % [_len(rec), _len([base_mesh]), _len(rec) / _len([base_mesh]), str(model.get_parent().global_basis.get_scale()), str(model.transform.basis.get_scale())]
	for m in model.find_children("*", "MeshInstance3D", true, false):
		out += "\n malha %s | aabb_local=%s | escala_global=%s | caminho=%s" % [m.name, str(m.get_aabb().size), str(m.global_basis.get_scale()), str(model.get_path_to(m))]
	FileAccess.open("res://_prints/fit_check.txt", FileAccess.WRITE).store_string(out)
	get_tree().quit()
