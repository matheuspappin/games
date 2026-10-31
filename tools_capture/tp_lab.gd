extends Node
# Arma em 3ª pessoa: troca a arma do soldado do menu (mesmo suporte dos outros jogadores) e tira prints.
func _ready() -> void:
	if get_tree().current_scene == self:
		var r = Node.new(); r.set_script(get_script()); r.name = "TpLabRunner"
		get_tree().root.add_child.call_deferred(r)
		return
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints/tp"))
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await get_tree().create_timer(5.0).timeout
	var rifle: Node = null
	for n in get_tree().root.find_children("*", "Node3D", true, false):
		if n.has_method("set_weapon_loadout"):
			rifle = n; break
	var lines := ["suporte encontrado: %s" % (rifle != null)]
	if rifle:
		for c in get_tree().root.find_children("*", "CanvasItem", true, false):
			if c is Control and c.get_parent() is CanvasLayer: c.visible = false
		var cases := [["ak47", "res://resources/weapons/ak47.tres", {}],
]
		for c in cases:
			rifle.set_weapon_loadout(c[1], c[2])
			await get_tree().create_timer(0.8).timeout
			get_viewport().get_texture().get_image().save_png("res://_prints/tp/%s.png" % c[0])
			var info := "%s | ref=%s" % [c[0], str(rifle._box_local(rifle.model_root))]
			if rifle._loadout_model:
				var lm = rifle._loadout_model
				var n_mesh := 0; var n_vis := 0
				for m in lm.find_children("*", "MeshInstance3D", true, false):
					n_mesh += 1
					if m.is_visible_in_tree(): n_vis += 1
				info += " | nova=%s escala=%s malhas=%d visiveis=%d camadas=%s" % [str(rifle._box_local(lm)), str(lm.scale), n_mesh, n_vis, str(lm.find_children("*", "MeshInstance3D", true, false).front().layers if n_mesh > 0 else -1)]
				var ref_m = rifle.model_root.find_children("*", "MeshInstance3D", true, false)
				if ref_m.size() > 0: info += " | camada_ref=%d" % ref_m.front().layers
			if rifle._loadout_model:
				var lm2: Node3D = rifle._loadout_model
				var skinned := 0
				for m in lm2.find_children("*", "MeshInstance3D", true, false):
					if m.skin != null or m.skeleton != NodePath(""): skinned += 1
				var gw := AABB(); var fw := true
				for m in lm2.find_children("*", "MeshInstance3D", true, false):
					if not m.is_visible_in_tree(): continue
					var bb: AABB = m.global_transform * m.get_aabb()
					gw = bb if fw else gw.merge(bb); fw = false
				var gr := AABB(); var fr := true
				for m in rifle.model_root.find_children("*", "MeshInstance3D", true, false):
					var bb2: AABB = m.global_transform * m.get_aabb()
					gr = bb2 if fr else gr.merge(bb2); fr = false
				info += " || GLOBAL nova=%s ref(oculta)=%s skinned=%d escala_global_nova=%s CENTRO nova=%s ref=%s cam=%s" % [str(gw.size), str(gr.size), skinned, str(lm2.global_transform.basis.get_scale()), str(gw.get_center()), str(gr.get_center()), str(get_viewport().get_camera_3d().global_position if get_viewport().get_camera_3d() else "?")]
			lines.append(info)
	FileAccess.open("res://_prints/tp_lab.txt", FileAccess.WRITE).store_string("\n".join(lines))
	get_tree().quit()
