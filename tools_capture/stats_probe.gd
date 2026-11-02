extends Node
func _ready() -> void:
	var base: WeaponData = load("res://resources/weapons/m4a1.tres")
	var out := []
	var cases := [[], ["optic_acog"], ["mag_fast"], ["grip_vertical"], ["grip_angled"], ["stock_heavy"], ["stock_light"], ["grip_rubber"], ["grip_stippled"], ["barrel_extended"], ["barrel_short"], ["grip_vertical", "stock_light", "mag_fast"]]
	for c in cases:
		var atts: Array[AttachmentData] = []
		for id in c:
			var a := WeaponModifier.get_attachment_resource(id)
			if a: atts.append(a)
			else: out.append("FALTA arquivo: " + id)
		var w := WeaponModifier.apply_attachments(base, atts)
		out.append("%-40s recuo_v=%.3f mira=%.4fs disp=%.4f alcance=%s recarga_x=%.2f mobilidade_x=%.2f mirando_x=%.2f" % [str(c), w.recoil_vertical if "recoil_vertical" in w else -1.0, w.ads_time, w.bloom_per_shot, str(w.damage_range) if "damage_range" in w else "?", w.reload_speed_mult, w.move_speed_mult, w.ads_move_mult])
	FileAccess.open("res://_prints/stats_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
