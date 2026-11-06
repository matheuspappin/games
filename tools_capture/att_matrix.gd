extends Node3D
# Matriz de acessórios: cada arma de lado (câmera ortográfica), sem nada e com UM acessório por vez.
# Usa o mesmo montador do Gunsmith (instantiate_weapon_showcase + update_attachments).
const WEAPONS := ["acr68", "m4a1", "scar_h", "man_o_war", "mp7", "pp90m1", "vmp", "smg", "spas12", "krm262", "shotgun", "rpk", "lmg", "deagle", "pistol"]
const VARIANTS := [
	["base", "", ""],
	["optic", "optic_red_dot", ""], ["optic", "optic_holo", ""], ["optic", "optic_acog", ""], ["optic", "optic_sniper", ""],
	["muzzle", "muzzle_suppressor", ""], ["muzzle", "muzzle_compensator", ""],
	["barrel", "barrel_extended", ""], ["barrel", "barrel_short", ""],
	["mag", "mag_extended", ""], ["mag", "mag_fast", ""],
	["underbarrel", "grip_vertical", ""], ["underbarrel", "grip_angled", ""],
	["stock", "stock_light", ""], ["stock", "stock_heavy", ""],
	["grip", "grip_rubber", ""], ["grip", "grip_stippled", ""],
]
var cam: Camera3D
var out := []
func _ready() -> void:
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.82, 0.84, 0.86)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.7, 0.7, 0.72); e.ambient_light_energy = 0.9
	env.environment = e; add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, 30, 0); sun.light_energy = 1.2; add_child(sun)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-20, 200, 0); fill.light_energy = 0.5; add_child(fill)
	cam = Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.keep_aspect = Camera3D.KEEP_WIDTH
	add_child(cam); cam.current = true
	_run.call_deferred()
func _aabb(n: Node3D) -> AABB:
	var ab := AABB(); var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null or not m.is_visible_in_tree(): continue
		var b: AABB = m.global_transform * m.get_aabb()
		ab = b if first else ab.merge(b); first = false
	return ab
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints/attm"))
	await get_tree().create_timer(1.0).timeout
	var only := FileAccess.get_file_as_string("res://_prints/attm_only.txt").strip_edges() if FileAccess.file_exists("res://_prints/attm_only.txt") else ""
	for w in WEAPONS:
		if only != "" and not (w in only.split(",")): continue
		var path := "res://resources/weapons/%s.tres" % w
		var slots: Array = WeaponVisualRegistry.get_allowed_slots(path)
		var wrap: Node3D = WeaponVisualRegistry.instantiate_weapon_showcase(path)
		add_child(wrap)
		var pivot := wrap.get_node("Pivot") as Node3D
		pivot.rotation_degrees = Vector3(0, 90, 0)   # de lado: cano para a esquerda da tela
		await get_tree().process_frame
		var base_ab := _aabb(wrap)
		var c := base_ab.get_center()
		cam.size = base_ab.size.x * 1.55
		cam.global_position = Vector3(c.x, c.y, c.z + 3.0)
		cam.look_at(c)
		var line := "%s encaixes=%s" % [w, str(slots)]
		for v in VARIANTS:
			var slot: String = v[0]; var att: String = v[1]
			var name := "%s__%s" % [w, att if att != "" else "base"]
			if slot != "base" and not (slot in slots):
				line += " | %s: (sem encaixe)" % att
				continue
			var a := {"optic": "none", "muzzle": "none", "mag": "none", "underbarrel": "none", "stock": "none", "grip": "none", "barrel": "none"}
			if slot != "base": a[slot] = att
			WeaponVisualRegistry.update_attachments(wrap, a["optic"], a["muzzle"], a["mag"], a["underbarrel"], a["stock"], a["grip"], a["barrel"])
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://_prints/attm/%s.png" % name)
			var an: Node3D = wrap.find_child("Att_" + slot, true, false) as Node3D
			if an:
				var ab := _aabb(an)
				line += " | %s: pos=%s tam=%s" % [att, str((ab.get_center() - c).snapped(Vector3.ONE * 0.001)), str(ab.size.snapped(Vector3.ONE * 0.001))]
		out.append(line)
		wrap.queue_free()
		await get_tree().process_frame
	FileAccess.open("res://_prints/attm.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
