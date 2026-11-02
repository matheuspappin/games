extends Node3D
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
const WEAPONS := ["ak47", "m4a1", "scar_h", "man_o_war", "lmg", "rpk", "smg", "mp7", "vmp", "pp90m1", "shotgun", "krm262", "spas12"]
func _ready() -> void:
	_run.call_deferred()
func _aabb_pivot(n: Node3D, piv: Node3D) -> AABB:
	var ab := AABB(); var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null: continue
		var b: AABB = (piv.global_transform.affine_inverse() * m.global_transform) * m.get_aabb()
		ab = b if first else ab.merge(b); first = false
	return ab
func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	var out := []
	for w in WEAPONS:
		vm.equip_weapon_data(load("res://resources/weapons/%s.tres" % w))
		await get_tree().create_timer(1.0).timeout
		var piv: Node3D = vm.current_custom_model_instance.get_node("Pivot")
		var k: float = vm.current_custom_model_instance.get_meta("attachment_scale", 1.0)
		var line: String = w + ":"
		# cano longo + silenciador
		vm.set_weapon_customization("default", "none", "muzzle_suppressor", "none", "none", "none", "none", "barrel_extended")
		await get_tree().create_timer(0.3).timeout
		var bar = vm.current_custom_model_instance.find_child("Att_barrel", true, false)
		var muz = vm.current_custom_model_instance.find_child("Att_muzzle", true, false)
		if bar and bar.get_child_count() > 0:
			var bb := _aabb_pivot(bar, piv)
			var mb := _aabb_pivot(muz, piv) if muz else AABB()
			var front := -1.0 if bb.get_center().z < 0 else 1.0
			var bar_end: float = bb.position.z if front < 0 else bb.end.z
			var muz_rear: float = mb.end.z if front < 0 else mb.position.z
			line += " cano=%.1fcm diam=%.1fcm fresta_silenciador=%.1fmm" % [bb.size.z / k * 100.0, bb.size.x / k * 100.0, (muz_rear - bar_end) * -front / k * 1000.0]
		else:
			line += " cano NAO CRIADO"
		# cano curto: quebra-chamas do modelo some?
		vm.set_weapon_customization("default", "none", "none", "none", "none", "none", "none", "barrel_short")
		await get_tree().create_timer(0.3).timeout
		var hidden := []
		for m in vm.current_custom_model_instance.find_children("*", "MeshInstance3D", true, false):
			if String(m.name).to_lower().begins_with("muzzle"):
				hidden.append("%s=%s" % [m.name, "escondido" if not m.is_visible_in_tree() else "visivel"])
		line += " | curto: %s" % (", ".join(hidden) if hidden else "modelo sem quebra-chamas separado (so atributos)")
		out.append(line)
	FileAccess.open("res://_prints/barrel_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
