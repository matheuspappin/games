extends Node3D
# Pegada da arma em 3ª pessoa: bots com várias armas/animações, fotografados de 3 ângulos.
# Saída: _prints/bg/<caso>.png e _prints/bot_grip_lab.txt
const WEAPONS := ["acr68", "m4a1", "mp7", "rpk", "krm262", "man_o_war", "pistol"]
const ANIMS := ["idle", "run", "shoot"]
var cam: Camera3D
var lines: Array = []

func _ready() -> void:
	_run.call_deferred()

func _env() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.6, 0.66)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.75, 0.8)
	e.ambient_light_energy = 0.9
	we.environment = e
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 160, 0)
	sun.light_energy = 1.3
	add_child(sun)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-20, -60, 0); fill.light_energy = 0.6; add_child(fill)
	var floor_m := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(30, 30)
	floor_m.mesh = pm
	add_child(floor_m)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new()
	bs.size = Vector3(30, 0.2, 30); cs.shape = bs; cs.position.y = -0.1; sb.add_child(cs); add_child(sb)
	cam = Camera3D.new(); cam.fov = 40; add_child(cam); cam.current = true

func _chest(bot: Node) -> Vector3:
	var sk: Skeleton3D = bot.get("_skeleton")
	if sk:
		var b := sk.find_bone("mixamorig_Spine2")
		if b < 0: b = sk.find_bone("mixamorig_Spine1")
		if b >= 0:
			var p: Vector3 = (sk.global_transform * sk.get_bone_global_pose(b)).origin
			return p + Vector3(0, 0.0, -0.15)
	return Vector3(0, 1.35, 0)

func _shot(name: String, target: Vector3, from: Vector3) -> void:
	cam.global_position = from
	cam.look_at(target, Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://_prints/bg/%s.png" % name)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints/bg"))
	_env()
	var args := OS.get_cmdline_user_args()
	var skins := ["t_phoenix", "ct_sas"]
	var weapons: Array = WEAPONS
	for a in args:
		if a.begins_with("--skins="): skins = a.substr(8).split(",")
		if a.begins_with("--weapons="): weapons = Array(a.substr(10).split(","))
	var scn: PackedScene = load("res://scenes/enemies/soldier_bot.tscn")
	for skin in skins:
		var bot = scn.instantiate()
		bot.set("skin_id", skin)
		add_child(bot)
		bot.global_position = Vector3.ZERO
		bot.rotation = Vector3.ZERO
		await get_tree().process_frame
		bot.set_physics_process(false)
		bot.set_process(false)
		var rifle = bot.find_child("BotRifle3D", true, false)
		var ap: AnimationPlayer = bot.get("_anim_player")
		lines.append("skin=%s rifle=%s ap=%s valve=%s parent=%s" % [skin, rifle != null, ap != null, str(bot.get("_is_valve_rig")), str(rifle.get_parent().name) if rifle else "-"])
		var skv: Skeleton3D = bot.get("_skeleton")
		var ikn = skv.get_node_or_null("TpArmIK") if skv else null
		if ikn:
			for bn in ["mixamorig_LeftHand", "mixamorig_RightHand"]:
				var bi := skv.find_bone(bn)
				var pl: Vector3 = ikn._palm_local(skv, bi)
				if bn == "mixamorig_RightHand" and rifle:
					lines.append("   palma direita no espaco da arma=%s (GRIP_ANCHOR=%s)" % [rifle.transform.affine_inverse() * pl, rifle.GRIP_ANCHOR])
				lines.append("%s palma %s: local=%s esqueleto_repouso=%s punho_repouso=%s (comparar com blender_hands.json)" % [skin, bn, pl, skv.get_bone_global_rest(bi) * pl, skv.get_bone_global_rest(bi).origin])
		for w in weapons:
			if rifle:
				rifle.set_weapon_loadout("" if w == "" else "res://resources/weapons/%s.tres" % w, {})
			for an in ANIMS:
				if ap and ap.has_animation(an):
					ap.play(an); ap.seek(0.35, true); ap.pause()
				await get_tree().create_timer(0.15).timeout
				var wn: String = "ref" if w == "" else w
				var base := "%s_%s_%s" % [skin, wn, an]
				var chest := _chest(bot)
				var skx: Skeleton3D = bot.get("_skeleton")
				if skx and rifle:
					var lh: Vector3 = skx.global_transform * skx.get_bone_global_pose(skx.find_bone("mixamorig_LeftHand")).origin
					var lm: Vector3 = skx.global_transform * skx.get_bone_global_pose(skx.find_bone("mixamorig_LeftHandMiddle1")).origin
					var rh: Vector3 = skx.global_transform * skx.get_bone_global_pose(skx.find_bone("mixamorig_RightHand")).origin
					var sp: Vector3 = rifle.to_global(rifle.get_support_point())
					var ik2 = skx.get_node_or_null("TpArmIK")
					lines.append("   erro_IK_mao_esq=%.3f m" % (ik2.last_error if ik2 else -1.0))
					lines.append("%s %s %s: apoio=%s maoE=%s palmaE=%s maoD=%s arma=%s dist_palma_apoio=%.3f" % [skin, w, an, sp, lh, (lh+lm)*0.5, rh, rifle.global_position, ((lh+lm)*0.5).distance_to(sp)])
				await _shot(base + "_34", chest, chest + Vector3(0.9, 0.15, -1.5))
				await _shot(base + "_dir", chest, chest + Vector3(1.7, 0.05, -0.25))
				if an == "idle":
					await _shot(base + "_esq", chest, chest + Vector3(-1.7, 0.05, -0.35))
		bot.queue_free()
		await get_tree().process_frame
	FileAccess.open("res://_prints/bot_grip_lab.txt", FileAccess.WRITE).store_string("\n".join(lines))
	get_tree().quit()
