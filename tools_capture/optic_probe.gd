extends Node3D
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	var out := []
	for wid in ["ak47", "scar_h", "rpk"]:
		vm.equip_weapon_data(load("res://resources/weapons/%s.tres" % wid))
		await get_tree().create_timer(1.6).timeout
		vm.set_weapon_customization("default", "optic_holo", "none", "none", "none", "none", "none")
		await get_tree().create_timer(0.5).timeout
		var o: Node3D = vm.current_optic_instance
		var pivot: Node3D = vm.current_custom_model_instance.get_node("Pivot")
		var inv := pivot.global_transform.affine_inverse()
		var ob := AABB(); var f := true
		for m in o.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = inv * m.global_transform * m.get_aabb()
			ob = b if f else ob.merge(b); f = false
		var names := []
		for m in o.find_children("*", "MeshInstance3D", true, false):
			names.append("%s vis=%s" % [m.name, m.is_visible_in_tree()])
		var hits := {}
		for m in pivot.find_children("*", "MeshInstance3D", true, false):
			if o.is_ancestor_of(m) or m.mesh == null: continue
			var xf: Transform3D = inv * m.global_transform
			for sidx in m.mesh.get_surface_count():
				for v in m.mesh.surface_get_arrays(sidx)[Mesh.ARRAY_VERTEX]:
					var p: Vector3 = xf * v
					if p.z >= ob.position.z and p.z <= ob.end.z and absf(p.x - ob.get_center().x) < 0.03 and p.y > ob.position.y - 0.08:
						var k := "%s[vis=%s layers=%d]" % [m.name, m.is_visible_in_tree(), m.layers]
						hits[k] = maxf(hits.get(k, -9.0), p.y)
		out.append(wid + " pecas sob a mira (y max): " + str(hits))
		var y0 := o.position.y
		WeaponVisualRegistry.snap_optic_to_rail(pivot, o)
		out.append(wid + " snap manual agora: y %.3f -> %.3f" % [y0, o.position.y])
		out.append("%s | optica pai=%s pos=%s | base_y=%.3f topo_y=%.3f z=[%.3f,%.3f] | malhas=%s" % [wid, o.get_parent().name, o.position, ob.position.y, ob.end.y, ob.position.z, ob.end.z, str(names.slice(0, 6))])
	FileAccess.open("res://_prints/optic_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
