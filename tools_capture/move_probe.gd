extends Node
# Velocidade real do jogador no estande: andando sem mirar e mirando, com e sem coronha leve/pesada
func _ready() -> void:
	add_child(load("res://scenes/_world/map_firing_range.tscn").instantiate())
	_run.call_deferred()
func _speed(player) -> float:
	var v: Vector3 = player.velocity
	return Vector2(v.x, v.z).length()
func _measure(player, ads: bool) -> float:
	Input.action_release("ads")
	if ads: Input.action_press("ads")
	Input.action_press("move_forward")
	await get_tree().create_timer(1.6).timeout
	var s := _speed(player)
	Input.action_release("move_forward"); Input.action_release("ads")
	await get_tree().create_timer(0.8).timeout
	return s
func _run() -> void:
	await get_tree().create_timer(4.0).timeout
	var player = get_tree().get_first_node_in_group("player")
	var wm = player.weapon_manager
	var vm = player.get_node_or_null("Head/Camera/WeaponRig/FpsHandsViewModel")
	var out := []
	for cfg in [["m4a1", "none", "none"], ["m4a1", "stock_light", "none"], ["m4a1", "stock_heavy", "none"], ["m4a1", "none", "barrel_extended"]]:
		var gm = get_node_or_null("/root/GameManager")
		gm.primary_weapon_res = "res://resources/weapons/%s.tres" % cfg[0]
		gm.set_weapon_customization("default", "none", "none", "none", "none", cfg[1], "none", cfg[2])
		wm.equip(gm.get_primary_weapon())
		var ccs = get_tree().root.find_child("ChooseClassScreen", true, false)
		if ccs: ccs.visible = false
		player.immobile = false
		await get_tree().create_timer(1.2).timeout
		player.ads_amount = 0.0
		var hip: float = player.base_speed * player._speed_multiplier()
		player.ads_amount = 1.0
		var ads: float = player.base_speed * player._speed_multiplier()
		player.ads_amount = 0.0
		var wd = wm.weapon_data
		out.append("%s coronha=%s cano=%s | andando=%.2f m/s | mirando=%.2f m/s (%.0f%%) | mult arma=%.2f mirando=%.2f" % [cfg[0], cfg[1], cfg[2], hip, ads, ads / maxf(hip, 0.01) * 100.0, wd.move_speed_mult, wd.ads_move_mult])
	FileAccess.open("res://_prints/move_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
