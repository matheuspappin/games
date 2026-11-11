extends Node
# Mira do quadril estilo CoD: cone real por estado (parado/andando/agachado/ADS) e prints do HUD.
var out := []
func _ready() -> void:
	add_child(load("res://scenes/_world/map_firing_range.tscn").instantiate())
	_run.call_deferred()
func _shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png("res://_prints/cross/%s.png" % n)
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints/cross"))
	await get_tree().create_timer(4.0).timeout
	var p = get_tree().get_first_node_in_group("player")
	var wm = p.weapon_manager
	var ccs = get_tree().root.find_child("ChooseClassScreen", true, false)
	if ccs: ccs.visible = false
	p.immobile = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for w in ["m4a1", "mp7", "rpk", "pistol"]:
		wm.equip(load("res://resources/weapons/%s.tres" % w))
		await get_tree().create_timer(1.0).timeout
		var c0 := rad_to_deg(wm.get_spread_rad())
		_shot(w + "_parado")
		# andando: força a velocidade (as sondas não movem o personagem pelo input)
		p.velocity = Vector3(0, 0, -PlayerConstants.WALK_SPEED)
		var c1 := rad_to_deg(wm.get_spread_rad())
		await get_tree().process_frame
		p.velocity = Vector3.ZERO
		p.stance_sync = 1
		var c2 := rad_to_deg(wm.get_spread_rad())
		p.stance_sync = 0
		p.ads_amount = 1.0
		var c3 := rad_to_deg(wm.get_spread_rad())
		p.ads_amount = 0.0
		# raio do cone a 10 m e 25 m
		out.append("%s cone(graus) parado=%.2f andando=%.2f agachado=%.2f ADS=%.2f | raio parado: 10m=%.0fcm 25m=%.0fcm" % [w, c0, c1, c2, c3, tan(deg_to_rad(c0)) * 1000.0, tan(deg_to_rad(c0)) * 2500.0])
	FileAccess.open("res://_prints/crosshair_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
