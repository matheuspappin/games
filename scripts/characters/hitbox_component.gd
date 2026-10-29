# =============================================================================
# hitbox_component.gd
# Detecção de região de impacto — HEAD, CHEST, STOMACH, ARM, LEG
# MS-4: Personagens & Física
# =============================================================================
class_name HitboxComponent
extends Area3D

enum Region { HEAD, CHEST, STOMACH, ARM_L, ARM_R, LEG_L, LEG_R }

@export var region    : Region = Region.CHEST
@export var bone_name : String = "Chest"   # PhysicalBone3D correspondente

# Chamado pelo WeaponManager ao confirmar hit por RayCast
func receive_hit(direction: Vector3, weapon_data: WeaponData, distance: float, attacker: Node = null) -> void:
	if has_meta("firing_target"):
		var ft = get_meta("firing_target")
		if is_instance_valid(ft) and ft.has_method("receive_bullet_hit"):
			var is_crit = (region == Region.HEAD)
			ft.receive_bullet_hit(get_region_name(), weapon_data, distance, is_crit, attacker)
			return

	if attacker != null and _is_friendly_fire(attacker):
		return

	var mult      = _get_multiplier(region, weapon_data)
	var base_dmg  = weapon_data.get_damage_at_distance(distance)
	var final_dmg = int(base_dmg * mult)

	var health = _find_health_component()
	if health:
		health.take_damage(final_dmg, direction, bone_name, attacker)

	var ai = _find_ai()
	if ai and ai.has_method("notify_attacked") and attacker:
		ai.notify_attacked(attacker, final_dmg)

func get_character() -> Node:
	var node = get_parent()
	while node != null:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null

func _is_friendly_fire(attacker: Node) -> bool:
	var target_char = get_character()
	if not target_char or not attacker:
		return false

	var my_team = -1
	if target_char.has_method("get_team"):
		my_team = target_char.get_team()
	elif target_char.get("team") != null:
		my_team = target_char.get("team")
	elif target_char.is_in_group("player"):
		var gm = get_node_or_null("/root/GameManager")
		my_team = 0 if (gm and gm.local_player_team == 1) else 1

	var atk_team = -1
	if attacker.has_method("get_team"):
		atk_team = attacker.get_team()
	elif attacker.get("team") != null:
		atk_team = attacker.get("team")
	elif attacker.is_in_group("player"):
		var gm = get_node_or_null("/root/GameManager")
		atk_team = 0 if (gm and gm.local_player_team == 1) else 1

	if my_team == -1 or atk_team == -1:
		return false

	var is_ffa = false
	var gmm = get_node_or_null("/root/GameModeManager")
	if not gmm and get_tree() and get_tree().current_scene:
		gmm = get_tree().current_scene.find_child("GameModeManager", true, false)
	if gmm and "game_mode" in gmm and gmm.game_mode == 4:
		is_ffa = true

	return not is_ffa and (my_team == atk_team)

func _find_ai() -> Node:
	var node = get_parent()
	while node != null:
		if node is EnemyAI or node.has_method("notify_attacked"):
			return node
		node = node.get_parent()
	return null

func _get_multiplier(r: Region, w: WeaponData) -> float:
	match r:
		Region.HEAD:
			return w.headshot_multiplier
		Region.CHEST, Region.STOMACH:
			return w.chest_multiplier
		_:
			return w.limb_multiplier

func _find_health_component() -> HealthComponent:
	var node = get_parent()
	while node != null:
		if node.has_node("HealthComponent"):
			return node.get_node("HealthComponent") as HealthComponent
		node = node.get_parent()
	return null

func get_region_name() -> String:
	match region:
		Region.HEAD:    return "HEAD"
		Region.CHEST:   return "CHEST"
		Region.STOMACH: return "STOMACH"
		Region.ARM_L:   return "ARM_L"
		Region.ARM_R:   return "ARM_R"
		Region.LEG_L:   return "LEG_L"
		Region.LEG_R:   return "LEG_R"
	return "UNKNOWN"

func is_headshot() -> bool:
	return region == Region.HEAD
