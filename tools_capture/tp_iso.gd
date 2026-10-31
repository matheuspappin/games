extends Node3D
# Teste isolado da arma em 3ª pessoa: fuzil original x suporte com a arma da classe, lado a lado.
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints/tp"))
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 0, 2.6)
	cam.look_at(Vector3.ZERO)
	cam.make_current()
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-45, 30, 0)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.25, 0.28, 0.32)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.environment = e
	add_child(env)
	var scn := load("res://scenes/weapons/bot_rifle_3d.tscn") as PackedScene
	var lines := []
	for c in [["ak47", "res://resources/weapons/ak47.tres", {}], ["m4a1_full", "res://resources/weapons/m4a1.tres", {"optic": "optic_holo", "muzzle": "muzzle_suppressor", "underbarrel": "grip_vertical", "mag": "mag_extended"}], ["smg", "res://resources/weapons/smg.tres", {}], ["pistol", "res://resources/weapons/pistol.tres", {}]]:
		var a := scn.instantiate() as Node3D
		var b := scn.instantiate() as Node3D
		add_child(a); add_child(b)
		a.position = Vector3.ZERO
		b.position = Vector3.ZERO
		a.rotation_degrees = Vector3(0, 90, 0)
		b.rotation_degrees = Vector3(0, 90, 0)
		cam.position = Vector3(0, 0.05, 1.3)
		cam.look_at(Vector3(0, 0.0, 0))
		b.visible = false
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png("res://_prints/tp/iso_%s_ref.png" % c[0])
		a.visible = false
		b.visible = true
		b.set_weapon_loadout(c[1], c[2])
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png("res://_prints/tp/iso_%s.png" % c[0])
		lines.append("%s | ref_frame=%s" % [c[0], str(b._reference_frame())])
		a.queue_free(); b.queue_free()
		await get_tree().process_frame
	FileAccess.open("res://_prints/tp_iso.txt", FileAccess.WRITE).store_string("\n".join(lines))
	get_tree().quit()
