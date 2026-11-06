extends Node
# Perfil do topo de cada arma (espaço do mesh "receiver*"): altura máxima por fatia de 1 cm ao longo do comprimento,
# só perto da linha central; e lista de malhas com caixa (para achar alça, massa e óticas embutidas)
const WEAPONS := ["acr68", "m4a1", "scar_h", "man_o_war", "mp7", "pp90m1", "vmp", "smg", "spas12", "krm262", "shotgun", "rpk", "lmg", "deagle", "pistol"]
func _ready() -> void:
	var out := []
	for w in WEAPONS:
		var cfg = WeaponVisualRegistry.get_weapon_config(w)
		var inst: Node3D = load(cfg["scene"]).instantiate()
		add_child(inst)
		var ref: MeshInstance3D = null
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			if String(m.name).to_lower().begins_with("receiver"):
				ref = m; break
		if not ref:
			out.append("== %s: sem receiver" % w); inst.queue_free(); continue
		var inv := ref.global_transform.affine_inverse()
		var cx: float = (cfg.get("ads_front", Vector3.ZERO) as Vector3).x
		var prof := {}
		out.append("== %s ref=%s ads_rear=%s ads_front=%s" % [w, ref.name, str(cfg.get("ads_rear")), str(cfg.get("ads_front"))])
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if not mi.mesh: continue
			var xf := inv * mi.global_transform
			var lo := Vector3(INF, INF, INF); var hi := -lo
			for s in mi.mesh.get_surface_count():
				var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
				for v in verts:
					var p := xf * v
					lo = lo.min(p); hi = hi.max(p)
					if absf(p.x - cx) < 0.012 and mi.is_visible_in_tree():
						var k := int(floor(p.z * 100.0))
						if not prof.has(k) or (p.y < prof[k][0] if w == "pp90m1" else p.y > prof[k][0]):
							prof[k] = [p.y, String(mi.name)]
			out.append("  malha %-28s vis=%s  x[%.3f,%.3f] y[%.3f,%.3f] z[%.3f,%.3f]" % [mi.name, str(mi.is_visible_in_tree()), lo.x, hi.x, lo.y, hi.y, lo.z, hi.z])
		var ks := prof.keys(); ks.sort()
		out.append("  sockets: mag=%s ub=%s stock=%s grip=%s" % [str(cfg.get("socket_mag")), str(cfg.get("socket_underbarrel")), str(cfg.get("socket_stock")), str(cfg.get("socket_rear_grip"))])
		inst.queue_free()
	FileAccess.open("res://_prints/sight_profile.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
