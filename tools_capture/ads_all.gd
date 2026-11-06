extends Node
# Print de mira (ADS, mira de ferro) de todas as armas + posição na tela de alça/massa configuradas
const WEAPONS := ["acr68", "ak47", "m4a1", "scar_h", "man_o_war", "mp7", "pp90m1", "vmp", "smg", "spas12", "krm262", "shotgun", "rpk", "lmg", "deagle", "pistol"]
var out := []
func _ready() -> void:
	add_child(load("res://scenes/_world/map_firing_range.tscn").instantiate())
	_run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints/ads_all"))
	await get_tree().create_timer(4.0).timeout
	var p = get_tree().get_first_node_in_group("player")
	var ccs = get_tree().root.find_child("ChooseClassScreen", true, false)
	if ccs: ccs.visible = false
	p.immobile = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var cam: Camera3D = p.CAMERA
	var wm = p.weapon_manager
	var vm = p.get_node_or_null("Head/Camera/WeaponRig/FpsHandsViewModel")
	var only := FileAccess.get_file_as_string("res://_prints/ads_only.txt").strip_edges() if FileAccess.file_exists("res://_prints/ads_only.txt") else ""
	for w in WEAPONS:
		if only != "" and not (w in only.split(",")):
			continue
		Input.action_release("ads")
		wm.equip(load("res://resources/weapons/%s.tres" % w))
		await get_tree().create_timer(1.0).timeout
		vm.set_weapon_customization("default", "none", "none", "none", "none", "none", "none", "none")
		await get_tree().create_timer(0.4).timeout
		Input.action_press("ads")
		await get_tree().create_timer(1.4).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://_prints/ads_all/%s.png" % w)
		var sz := img.get_size()
		var c := Vector2(sz) / 2.0
		var line := "%s ads=%.2f fov=%.0f" % [w, float(p.ads_amount), cam.fov]
		var cfg = WeaponVisualRegistry.get_weapon_config(w)
		var ref = vm._rig_ref_mesh() if vm.has_method("_rig_ref_mesh") else null
		if ref and cfg.has("ads_front"):
			var fw: Vector3 = ref.global_transform * (cfg["ads_front"] as Vector3)
			var rw: Vector3 = ref.global_transform * (cfg["ads_rear"] as Vector3)
			var fp := cam.unproject_position(fw) - c
			var rp := cam.unproject_position(rw) - c
			var axis: Vector3 = (fw - rw).normalized()
			line += " | massa=(%d,%d)px alca=(%d,%d)px angulo_linha_mira=%.2f°" % [fp.x, fp.y, rp.x, rp.y, rad_to_deg(axis.angle_to(-cam.global_basis.z))]
			# eixo do modelo (comprimento) x câmera
			var ax2: Vector3 = (ref.global_basis * Vector3(0, 0, -1)).normalized()
			line += " eixo_modelo=%.2f°" % rad_to_deg(ax2.angle_to(-cam.global_basis.z))
		else:
			line += " | sem ads_front/ref (rig_fit=%s)" % str(vm._current_has_rig_fit())
		out.append(line)
	Input.action_release("ads")
	FileAccess.open("res://_prints/ads_all.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
