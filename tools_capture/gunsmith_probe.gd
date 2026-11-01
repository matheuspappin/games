extends Node3D
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
@onready var cam: Camera3D = $Camera
const WEAPONS := ["ak47", "m4a1", "scar_h", "man_o_war", "lmg", "rpk", "smg", "mp7", "vmp", "pp90m1", "pistol", "deagle", "shotgun", "krm262", "spas12"]
const OPTIONS := {
	"optic": ["optic_red_dot", "optic_holo", "optic_acog", "optic_sniper"],
	"muzzle": ["muzzle_suppressor", "muzzle_compensator"],
	"mag": ["mag_extended", "mag_fast"],
	"underbarrel": ["grip_vertical", "grip_angled"],
	"stock": ["stock_light", "stock_heavy"],
	"grip": ["grip_rubber", "grip_stippled"],
}
func _ready() -> void:
	_run.call_deferred()
func _apply(cfg: Dictionary) -> void:
	vm.set_weapon_customization("default", cfg.get("optic", "none"), cfg.get("muzzle", "none"), cfg.get("mag", "none"), cfg.get("underbarrel", "none"), cfg.get("stock", "none"), cfg.get("grip", "none"))
func _attachments() -> Array:
	var res := []
	if not vm.current_custom_model_instance:
		return res
	for n in vm.current_custom_model_instance.find_children("Att_*", "Node3D", true, false):
		res.append(n)
	if vm.current_optic_instance and is_instance_valid(vm.current_optic_instance) and vm.current_optic_id != "none":
		res.append(vm.current_optic_instance)
	return res
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints/gunsmith"))
	await get_tree().create_timer(2.0).timeout
	var out := []
	var falhas := 0
	for w in WEAPONS:
		vm.equip_weapon_data(load("res://resources/weapons/%s.tres" % w))
		await get_tree().create_timer(1.2).timeout
		var slots: Array = WeaponVisualRegistry.get_allowed_slots("res://resources/weapons/%s.tres" % w)
		var ref = vm._rig_ref_mesh()
		var center: Vector3 = ref.global_transform * ref.get_aabb().get_center() if ref else vm.current_custom_model_instance.global_position
		var length: float = (ref.global_basis * ref.get_aabb().size).length() if ref else 1.0
		var line := "%s  encaixes=%s" % [w, str(slots)]
		for slot in OPTIONS:
			if not slot in slots:
				continue
			for att in OPTIONS[slot]:
				var c := {}; c[slot] = att
				_apply(c)
				await get_tree().create_timer(0.25).timeout
				var ok := "FALHA(nao criado)"
				for n in _attachments():
					var nslot: String = String(n.get_meta("slot", "optic"))
					if nslot != slot and not (slot == "underbarrel" and nslot in ["underbarrel", "grip"]):
						continue
					if n.is_visible_in_tree():
						var d: float = n.global_position.distance_to(center)
						ok = "ok" if d < length * 0.8 else "FALHA(solto %.2f)" % (d / length)
				if ok != "ok":
					falhas += 1
				line += "\n   %-12s %-20s %s" % [slot, att, ok]
		# montagem completa (até 5 modificações)
		var full := {}
		var count := 0
		for slot in ["optic", "muzzle", "underbarrel", "mag", "stock"]:
			if slot in slots and count < 5:
				full[slot] = OPTIONS[slot][0]; count += 1
		_apply(full)
		await get_tree().create_timer(0.4).timeout
		line += "\n   completa %s -> %d peças visíveis" % [str(full.values()), _attachments().filter(func(n): return n.is_visible_in_tree()).size()]
		var piv = vm.current_custom_model_instance
		cam.global_position = center + Vector3(-0.9, 0.05, 0.0) * length
		cam.look_at(center)
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png("res://_prints/gunsmith/%s_completa.png" % w)
		cam.transform = Transform3D.IDENTITY
		_apply({})
		out.append(line)
	out.append("TOTAL DE FALHAS: %d" % falhas)
	FileAccess.open("res://_prints/gunsmith_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
