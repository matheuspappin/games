extends Node
# Partida real com bots: confere arma/IK de cada bot e fotografa alguns de perto.
func _ready() -> void:
	if get_tree().current_scene == self:
		var r = Node.new(); r.set_script(get_script()); r.name = "BotSmoke"
		get_tree().root.add_child.call_deferred(r)
		return
	_run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints/smoke"))
	# Nuketown precisa de mais memória livre do que o PC tem com o app aberto: estande de tiro + bots com IA ligada
	get_tree().change_scene_to_file("res://scenes/_world/map_firing_range.tscn")
	await get_tree().create_timer(5.0).timeout
	var scn: PackedScene = load("res://scenes/enemies/soldier_bot.tscn")
	var arqs := [0, 1, 2, 3]
	for i in 4:
		var bt = scn.instantiate()
		bt.set("bot_id", 101 + i)
		bt.set("team", 1)
		get_tree().current_scene.add_child(bt)
		bt.global_position = Vector3(-3.0 + i * 2.0, 0.2, -9.0)
		bt.apply_archetype(arqs[i])
	await get_tree().create_timer(8.0).timeout
	var lines := []
	var bots := get_tree().get_nodes_in_group("enemies")
	lines.append("bots=%d" % bots.size())
	var cam := Camera3D.new(); cam.fov = 45
	get_tree().root.add_child(cam)
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false): c.visible = false
	var k := 0
	for b in bots:
		var sk: Skeleton3D = b.get("_skeleton")
		var ik = sk.get_node_or_null("TpArmIK") if sk else null
		var rf = b.find_child("BotRifle3D", true, false)
		lines.append("%s arq=%s arma=%s ik=%s erro=%.3f estado=%s" % [b.name, b.get("archetype"), rf._loadout_path if rf else "-", ik != null, ik.last_error if ik else -1.0, b.get("ai_state")])
		if k < 4 and sk:
			var p: Vector3 = b.global_position + Vector3.UP * 1.35
			var f: Vector3 = -b.global_basis.z
			cam.global_position = p + f * 2.2 + b.global_basis.x * 1.0 + Vector3.UP * 0.1
			cam.look_at(p, Vector3.UP); cam.current = true
			await get_tree().process_frame; await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("res://_prints/smoke/bot_%d.png" % k)
			k += 1
	FileAccess.open("res://_prints/bot_smoke.txt", FileAccess.WRITE).store_string("\n".join(lines))
	get_tree().quit()
