extends Node3D
# Mede onde os encaixes (cabo/guarda-mão) de cada arma caem no suporte 3ª pessoa (BotRifle3D).
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	var lines := []
	var scn: PackedScene = load("res://scenes/weapons/bot_rifle_3d.tscn")
	var r = scn.instantiate(); add_child(r)
	await get_tree().process_frame
	for w in ["acr68","ak47","m4a1","scar_h","man_o_war","vmp","mp7","pp90m1","smg","rpk","lmg","krm262","spas12","shotgun","pistol","deagle"]:
		r.set_weapon_loadout("res://resources/weapons/%s.tres" % w, {})
		await get_tree().process_frame
		var lm: Node3D = r._loadout_model
		var pv: Node3D = lm.get_node("Pivot")
		var cfg = WeaponVisualRegistry.get_weapon_config("res://resources/weapons/%s.tres" % w)
		var g: Vector3 = r.to_local(pv.global_transform * cfg.get("socket_rear_grip", Vector3.ZERO))
		var u: Vector3 = r.to_local(pv.global_transform * cfg.get("socket_underbarrel", Vector3.ZERO))
		var b: Basis = (r.global_transform.affine_inverse() * pv.global_transform).basis
		var sc: float = b.get_scale().x
		b = b.orthonormalized()
		lines.append("%s cat=%s grip=%s ub=%s front=%s up=%s s=%.3f inv=%s rot_deg=%s" % [w, cfg.get("category",""), g, u, -b.z, b.y, sc, cfg.get("model_inverted", false), cfg.get("rotation_deg", "")])
	FileAccess.open("res://_prints/bot_calib.txt", FileAccess.WRITE).store_string("\n".join(lines))
	get_tree().quit()
