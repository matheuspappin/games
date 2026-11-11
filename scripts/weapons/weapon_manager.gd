# =============================================================================
# weapon_manager.gd
# Gerenciador de armas — disparo hitscan, recarga, bloom, recoil, ADS e áudio
# MS-2: Sistema de Armas
# =============================================================================
class_name WeaponManager
extends Node3D

signal ammo_changed(current: int, reserve: int)
signal weapon_switched(weapon_data: WeaponData)
signal hit_confirmed(is_headshot: bool, target_pos: Vector3)
signal fire_event
signal reload_started(reload_time: float)
signal reload_finished

@export var default_weapon   : WeaponData
@export var secondary_weapon : WeaponData
@export var melee_weapon     : WeaponData
@export var camera           : Camera3D
@export var player           : CharacterBody3D
@export var weapon_rig       : Node3D
@export var muzzle_point     : Node3D

var weapon_data              : WeaponData = null
var current_ammo             : int        = 0
var reserve_ammo             : int        = 0
var is_reloading             : bool       = false
var cooldown_timer           : float      = 0.0
var current_bloom            : float      = 0.0   # abertura extra do cone do quadril, em GRAUS (cresce por tiro)
var _since_last_shot         : float      = 99.0
var _shots_in_string         : int        = 0      # disparos seguidos (recoil sobe nos primeiros, estilo CoD)
var _recoil_pending          : Vector2    = Vector2.ZERO  # (pitch, yaw) em graus ainda a aplicar na câmera
var _recoil_h_drift          : float      = 0.0
var fire_mode_state          : int        = 0

# Posições de repouso e mira
var hip_position             : Vector3 = Vector3(0.0, 0.0, 0.0)
var ads_position             : Vector3 = Vector3(-0.233, 0.099, -0.05)
var base_camera_fov          : float   = 75.0
var current_viewmodel        : Node3D = null
var primary_viewmodel        : Node3D = null
var secondary_viewmodel      : Node3D = null
var _muzzle_light            : OmniLight3D = null
var pip_scope_viewport       : PipScopeViewport = null

func _is_player_dead() -> bool:
	return player != null and "is_dead" in player and player.is_dead

func _is_countdown_active() -> bool:
	var gm = get_node_or_null("/root/GameManager")
	return gm != null and gm.has_method("is_in_countdown") and gm.is_in_countdown()

func on_player_died() -> void:
	is_reloading = false
	cooldown_timer = 0.0
	current_bloom = 0.0
	_recoil_pending = Vector2.ZERO
	if _muzzle_light:
		_muzzle_light.visible = false
	if weapon_rig:
		weapon_rig.visible = false
	if current_viewmodel:
		current_viewmodel.visible = false

func reset_on_respawn() -> void:
	is_reloading = false
	cooldown_timer = 0.0
	current_bloom = 0.0
	_recoil_pending = Vector2.ZERO
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if gm.has_method("get_primary_weapon") and gm.get_primary_weapon():
			default_weapon = gm.get_primary_weapon()
		if gm.has_method("get_secondary_weapon") and gm.get_secondary_weapon():
			secondary_weapon = gm.get_secondary_weapon()
		if gm.has_method("get_melee_weapon") and gm.get_melee_weapon():
			melee_weapon = gm.get_melee_weapon()
	if weapon_rig:
		weapon_rig.visible = true
	if current_viewmodel:
		current_viewmodel.visible = true
	if default_weapon:
		equip(default_weapon)
	elif weapon_data:
		equip(weapon_data)

func _ready() -> void:
	# Auto-encontrar player
	if not player:
		var p = get_parent()
		while p != null:
			if p is CharacterBody3D:
				player = p
				break
			p = p.get_parent()

	if not camera:
		if player:
			camera = player.get_node_or_null("Head/Camera") as Camera3D
			if not camera:
				camera = player.get_node_or_null("Head/MainCamera3D") as Camera3D
			if not camera:
				camera = player.find_child("Camera3D", true, false) as Camera3D
		if not camera:
			var parent_node = get_parent()
			while parent_node != null:
				if parent_node is Camera3D:
					camera = parent_node
					break
				parent_node = parent_node.get_parent()
		if not camera and get_viewport():
			camera = get_viewport().get_camera_3d()

	if camera:
		base_camera_fov = camera.fov

	if not weapon_rig:
		weapon_rig = get_parent() as Node3D

	_find_viewmodels()

	# Carregar armas do GameManager caso configuradas no menu de seleção
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_method("get_primary_weapon") and gm.get_primary_weapon():
			default_weapon = gm.get_primary_weapon()
		if gm.has_method("get_secondary_weapon") and gm.get_secondary_weapon():
			secondary_weapon = gm.get_secondary_weapon()
		if gm.has_method("get_melee_weapon") and gm.get_melee_weapon():
			melee_weapon = gm.get_melee_weapon()

	if not default_weapon:
		default_weapon = load("res://resources/weapons/ak47.tres") as WeaponData
	if not secondary_weapon:
		secondary_weapon = load("res://resources/weapons/pistol.tres") as WeaponData
	if not melee_weapon:
		melee_weapon = load("res://resources/weapons/knife.tres") as WeaponData

	if default_weapon:
		equip(default_weapon)
	call_deferred("_ensure_initial_weapon_equipped")
	call_deferred("_setup_pip_scope")

func _ensure_initial_weapon_equipped() -> void:
	if not default_weapon:
		var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
		if gm and gm.has_method("get_primary_weapon") and gm.get_primary_weapon():
			default_weapon = gm.get_primary_weapon()
		if not default_weapon and ResourceLoader.exists("res://resources/weapons/ak47.tres"):
			default_weapon = load("res://resources/weapons/ak47.tres") as WeaponData

	if default_weapon and (weapon_data == null or current_viewmodel == null or not is_instance_valid(current_viewmodel)):
		equip(default_weapon)
	elif default_weapon and current_viewmodel and current_viewmodel is FpsHandsViewModel:
		if not current_viewmodel.current_custom_model_instance and not (current_viewmodel.fps_hands and is_instance_valid(current_viewmodel.fps_hands.weapon)):
			equip(default_weapon)

func _setup_pip_scope() -> void:
	if not camera:
		if player:
			camera = player.get_node_or_null("Head/Camera") as Camera3D
	if not camera:
		return
	
	pip_scope_viewport = camera.get_node_or_null("PipScopeViewport") as PipScopeViewport
	if not pip_scope_viewport:
		pip_scope_viewport = PipScopeViewport.new()
		pip_scope_viewport.name = "PipScopeViewport"
		pip_scope_viewport.add_to_group("pip_scope_viewport")
		camera.add_child(pip_scope_viewport)
	else:
		pip_scope_viewport.add_to_group("pip_scope_viewport")

	if weapon_rig:
		set_viewmodel_layers(weapon_rig, 2)

static func set_viewmodel_layers(node: Node, layer_mask: int = 2) -> void:
	if not node:
		return
	if node is VisualInstance3D:
		node.layers = layer_mask
	for child in node.get_children():
		set_viewmodel_layers(child, layer_mask)


func _find_viewmodels() -> void:
	if weapon_rig:
		var fps_vm = weapon_rig.get_node_or_null("FpsHandsViewModel")
		if fps_vm:
			primary_viewmodel = fps_vm
			secondary_viewmodel = fps_vm
			current_viewmodel = fps_vm
			return

		primary_viewmodel = weapon_rig.get_node_or_null("ViewModelFPS")
		if not primary_viewmodel:
			primary_viewmodel = weapon_rig.get_node_or_null("AK47ViewModel")
		secondary_viewmodel = weapon_rig.get_node_or_null("PistolViewModel")

		# Fallback se não encontrado por nome
		if not primary_viewmodel or not secondary_viewmodel:
			for c in weapon_rig.get_children():
				if c is Node3D and c != self and not c is MeshInstance3D and not c is Light3D:
					if not primary_viewmodel:
						primary_viewmodel = c
					elif not secondary_viewmodel and c != primary_viewmodel:
						secondary_viewmodel = c

func _unhandled_input(event: InputEvent) -> void:
	if _is_player_dead() or is_reloading:
		return
	# Troca com a roda do mouse (Wheel Up / Down)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			toggle_weapon()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if weapon_data and not is_reloading and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				if weapon_data.fire_mode == WeaponData.FireMode.SEMI or weapon_data.category == WeaponData.WeaponCategory.MELEE:
					try_fire()

func toggle_weapon() -> void:
	if is_reloading:
		return
	if weapon_data == default_weapon:
		if secondary_weapon:
			equip(secondary_weapon)
		elif melee_weapon:
			equip(melee_weapon)
	elif weapon_data == secondary_weapon:
		if melee_weapon:
			equip(melee_weapon)
		elif default_weapon:
			equip(default_weapon)
	elif weapon_data == melee_weapon:
		if default_weapon:
			equip(default_weapon)
		elif secondary_weapon:
			equip(secondary_weapon)
	elif default_weapon:
		equip(default_weapon)

func _process(delta: float) -> void:
	_update_sprint_to_fire(delta)
	if _is_player_dead():
		if weapon_rig and weapon_rig.visible:
			weapon_rig.visible = false
		return
	if weapon_data == null:
		return

	# Reduzir cooldown entre disparos
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	# Cone do quadril só fecha depois de parar de atirar (spread per shot do CoD)
	_since_last_shot += delta
	if _since_last_shot > WeaponData.HIP_BLOOM_DECAY_DELAY:
		current_bloom = maxf(0.0, current_bloom - WeaponData.HIP_BLOOM_DECAY_DEG_S * delta)
		_shots_in_string = 0
	_update_recoil(delta)

	# Alinhamento ADS do Viewmodel e Zoom da Câmera (estilo Call of Duty)
	if player and "ads_amount" in player:
		var ads_t: float = player.ads_amount
		if pip_scope_viewport:
			pip_scope_viewport.set_ads_amount(ads_t)
		if current_viewmodel and current_viewmodel.has_method("set_ads"):
			current_viewmodel.set_ads(ads_t > 0.4, ads_t)
		elif weapon_rig:
			var target_pos = hip_position.lerp(ads_position, ads_t)
			weapon_rig.position = weapon_rig.position.lerp(target_pos, delta * 24.0)
		# Dynamic ADS FOV (Zoom realista) — só atua quando estiver ativamente mirando (ADS)
		# para não colidir com o FOV dinâmico de corrida/sprint gerenciado pelo Character
		if camera and ads_t > 0.01:
			var fov_delta = weapon_data.ads_fov_delta if weapon_data else -20.0
			if pip_scope_viewport and pip_scope_viewport.is_active:
				fov_delta = -8.0
			var target_fov = base_camera_fov + (fov_delta * ads_t)
			camera.fov = lerp(camera.fov, target_fov, delta * 18.0)

	# Atualizar animação de movimento no viewmodel
	if current_viewmodel and player and not is_reloading:
		var ads_t: float = player.ads_amount if "ads_amount" in player else 0.0
		if ads_t > 0.2:
			if current_viewmodel.has_method("play_idle"):
				current_viewmodel.play_idle()
		else:
			var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
			var is_sprinting: bool = false
			if "state" in player:
				is_sprinting = (player.state == "sprinting")
			elif "state_machine" in player and player.state_machine:
				var s = player.state_machine.current_state
				is_sprinting = s in [MovementStateMachine.State.SPRINT, MovementStateMachine.State.TACT_SPRINT]

			if not is_sprinting and Input.is_action_pressed("sprint") and speed > 4.5:
				is_sprinting = true

			if is_sprinting and speed > 1.2:
				if current_viewmodel.has_method("play_sprint"):
					current_viewmodel.play_sprint()
			elif speed > 0.4:
				if current_viewmodel.has_method("play_walk"):
					current_viewmodel.play_walk()
			else:
				if current_viewmodel.has_method("play_idle"):
					current_viewmodel.play_idle()

	# Inspecionar arma com tecla F
	if Input.is_key_pressed(KEY_F) and not is_reloading:
		if current_viewmodel and current_viewmodel.has_method("play_inspect"):
			current_viewmodel.play_inspect()

	# Troca direta por slot (1 = Primária, 2 = Secundária, 3/V = Faca)
	if Input.is_action_just_pressed("weapon_primary") and default_weapon and weapon_data != default_weapon:
		equip(default_weapon)
	elif Input.is_action_just_pressed("weapon_secondary") and secondary_weapon and weapon_data != secondary_weapon:
		equip(secondary_weapon)
	elif (Input.is_action_just_pressed("weapon_melee") or Input.is_key_pressed(KEY_3)) and melee_weapon and weapon_data != melee_weapon:
		equip(melee_weapon)

	# Entrada de disparo (bloqueada durante contagem regressiva pré-partida estilo CoD)
	if _is_countdown_active():
		return

	var fire_down = (Input.is_action_pressed("fire") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var fire_just = (Input.is_action_just_pressed("fire") or Input.is_action_just_pressed("ui_accept")) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

	if weapon_data.fire_mode == WeaponData.FireMode.AUTO:
		if fire_down and not is_reloading:
			try_fire()
	elif weapon_data.fire_mode == WeaponData.FireMode.SEMI:
		if fire_just and not is_reloading:
			try_fire()
	elif weapon_data.fire_mode == WeaponData.FireMode.BURST:
		if fire_just and not is_reloading:
			_fire_burst()

	# Recarga manual
	if Input.is_action_just_pressed("reload") and not is_reloading:
		if current_ammo < weapon_data.magazine_capacity and reserve_ammo > 0:
			start_reload()

func equip(data: WeaponData) -> void:
	weapon_data  = data
	if data.category == WeaponData.WeaponCategory.MELEE:
		current_ammo = 1
		reserve_ammo = 0
	else:
		current_ammo = data.magazine_capacity
		reserve_ammo = data.reserve_ammo_max
	is_reloading = false
	cooldown_timer = 0.0
	current_bloom  = 0.0
	_recoil_pending = Vector2.ZERO
	if data.ads_position != Vector3.ZERO:
		ads_position = data.ads_position

	# Se temos o FpsHandsViewModel unificado, usamos ele diretamente
	var fps_vm = weapon_rig.get_node_or_null("FpsHandsViewModel") if weapon_rig else null
	if fps_vm:
		current_viewmodel = fps_vm
		if fps_vm.has_method("equip_weapon_data"):
			fps_vm.equip_weapon_data(data)
		if has_node("/root/GameManager") and fps_vm.has_method("set_weapon_customization"):
			var gm = get_node("/root/GameManager")
			var is_prim = (data == default_weapon) or (data and data.category != WeaponData.WeaponCategory.PISTOL and data.category != WeaponData.WeaponCategory.MELEE)
			if is_prim:
				fps_vm.set_weapon_customization(gm.primary_camo, gm.primary_optic, gm.primary_muzzle, gm.primary_mag, gm.primary_underbarrel, gm.primary_stock, gm.primary_grip, gm.primary_barrel)
			else:
				fps_vm.set_weapon_customization("default", "none", "none")
		if primary_viewmodel and primary_viewmodel != fps_vm:
			primary_viewmodel.visible = false
		if secondary_viewmodel and secondary_viewmodel != fps_vm:
			secondary_viewmodel.visible = false
	else:
		# Alternar visibilidade e animação de saque (Draw) dos viewmodels legados
		var is_primary = (data == default_weapon) or (data and data.category != WeaponData.WeaponCategory.PISTOL and data.category != WeaponData.WeaponCategory.MELEE)
		if is_primary:
			if secondary_viewmodel:
				secondary_viewmodel.visible = false
			if primary_viewmodel:
				primary_viewmodel.visible = true
				if primary_viewmodel.has_method("play_draw"):
					primary_viewmodel.play_draw()
			current_viewmodel = primary_viewmodel
		else:
			if primary_viewmodel:
				primary_viewmodel.visible = false
			if secondary_viewmodel:
				secondary_viewmodel.visible = true
				if secondary_viewmodel.has_method("play_draw"):
					secondary_viewmodel.play_draw()
			current_viewmodel = secondary_viewmodel

	ammo_changed.emit(current_ammo, reserve_ammo)
	weapon_switched.emit(data)

# ── DISPARO ───────────────────────────────────────────────────────────────────
## Atraso para atirar ao sair do sprint (s), por categoria — base inspirada no CoD
const SPRINT_TO_FIRE_BASE := {
	WeaponData.WeaponCategory.PISTOL: 0.12, WeaponData.WeaponCategory.SMG: 0.16,
	WeaponData.WeaponCategory.SHOTGUN: 0.20, WeaponData.WeaponCategory.ASSAULT_RIFLE: 0.22,
	WeaponData.WeaponCategory.LMG: 0.32, WeaponData.WeaponCategory.SNIPER: 0.32,
	WeaponData.WeaponCategory.LAUNCHER: 0.35,
}
var sprint_out_timer := 0.0
const TAC_SPRINT_TO_FIRE_MULT := 1.6
var _was_sprinting := false
var _queued_shot := false

func _player_is_sprinting() -> bool:
	if not player:
		return false
	if "state" in player:
		return player.state == "sprinting"
	if "state_machine" in player and player.state_machine:
		return player.state_machine.current_state in [MovementStateMachine.State.SPRINT, MovementStateMachine.State.TACT_SPRINT]
	return false

func _sprint_to_fire_time() -> float:
	if weapon_data == null:
		return 0.0
	var base: float = SPRINT_TO_FIRE_BASE.get(weapon_data.category, 0.2)
	return base * (float(weapon_data.sprint_to_fire_mult) if "sprint_to_fire_mult" in weapon_data else 1.0)

## Chamado a cada quadro: arma o atraso ao sair do sprint e solta o tiro guardado quando ele termina
func _update_sprint_to_fire(delta: float) -> void:
	var now := _player_is_sprinting()
	if _was_sprinting and not now:
		var tac_pose: float = player.tac_sprint_pose if (player and "tac_sprint_pose" in player) else 0.0
		sprint_out_timer = maxf(sprint_out_timer, _sprint_to_fire_time() * lerpf(1.0, TAC_SPRINT_TO_FIRE_MULT, tac_pose))
	_was_sprinting = now
	if sprint_out_timer > 0.0:
		sprint_out_timer = maxf(0.0, sprint_out_timer - delta)
		if sprint_out_timer == 0.0 and _queued_shot:
			_queued_shot = false
			try_fire()

func try_fire() -> void:
	if _is_player_dead():
		return
	if weapon_data == null or is_reloading:
		return
	if cooldown_timer > 0.0:
		return
	# rastejando, indo ao chão ou escalando: a arma está fora de posição (como no CoD)
	if player and player.has_method("blocks_firing") and player.blocks_firing():
		return
	if weapon_data.category == WeaponData.WeaponCategory.MELEE:
		_execute_melee()
		return
	# saída do sprint: o primeiro tiro espera a arma subir (fica guardado, não se perde)
	if _player_is_sprinting():
		var was_tac: bool = "tac_sprinting" in player and player.tac_sprinting
		_stop_player_sprint()
		_was_sprinting = false
		# da corrida tática a arma desce de mais alto: atraso maior
		sprint_out_timer = maxf(sprint_out_timer, _sprint_to_fire_time() * (TAC_SPRINT_TO_FIRE_MULT if was_tac else 1.0))
		_queued_shot = true
		return
	if sprint_out_timer > 0.0:
		_queued_shot = true
		return
	if current_ammo <= 0:
		_play_sound(weapon_data.sound_dry_fire)
		return

	_execute_fire()

## Sai da corrida (e da tática) por causa de uma ação da arma; a corrida só volta com novo toque no Shift
func _stop_player_sprint() -> void:
	if player and player.has_method("stop_sprint_for_action"):
		player.stop_sprint_for_action()
	elif player and player.has_method("_enter_normal_state"):
		player._enter_normal_state()

func _execute_fire() -> void:
	if player and "state" in player and player.state == "sprinting":
		_stop_player_sprint()

	if not camera:
		if player:
			camera = player.get_node_or_null("Head/Camera") as Camera3D
			if not camera:
				camera = player.get_node_or_null("Head/MainCamera3D") as Camera3D
			if not camera:
				camera = player.find_child("Camera3D", true, false) as Camera3D
		if not camera and get_viewport():
			camera = get_viewport().get_camera_3d()
	if not camera:
		return

	# 1. Direção dentro do cone de dispersão (quadril/ADS, movimento, postura e bloom — estilo CoD)
	var cam_basis = camera.global_transform.basis.orthonormalized()
	var direction = -cam_basis.z
	var cone := get_spread_rad()
	if cone > 0.0:
		# ponto uniforme no disco do cone (sqrt: sem concentrar tudo no centro como o "quadrado" antigo)
		var r := cone * sqrt(randf())
		var th := randf() * TAU
		var axis: Vector3 = (cam_basis.x * cos(th) + cam_basis.y * sin(th)).normalized()
		direction = direction.rotated(axis, r)
	direction = direction.normalized()

	# 2. Raycast com suporte a Hitbox Area3D, Bots IA e Players
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("record_shot_fired"):
		gm.record_shot_fired()

	var space  = camera.get_world_3d().direct_space_state
	var params = PhysicsRayQueryParameters3D.create(
		camera.global_position,
		camera.global_position + direction * weapon_data.max_range,
		0b1111,  # Layers 1=Geometria, 2=Hitboxes, 3=Players, 4=Bots IA
		[player]
	)
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var result = space.intersect_ray(params)

	# Partida online: o servidor refaz o tiro e é o único que aplica dano em jogadores
	var net_client := _is_net_client()
	if net_client:
		var nm = get_node_or_null("/root/NetworkManager")
		if nm and nm.has_method("rpc_server_shot"):
			nm.rpc_id(1, "rpc_server_shot", camera.global_position, direction, String(weapon_data.resource_path), false)

	# 3. Processar impacto e dano
	var _hit_pos = camera.global_position + direction * 50.0
	if result:
		_hit_pos = result.position
		var dist = camera.global_position.distance_to(result.position)
		var collider = result.collider

		var is_headshot = false
		var target_player: PlayerCharacter = null
		var target_ai: Node = null

		# Identificar PlayerCharacter
		if collider is PlayerCharacter:
			target_player = collider
		else:
			var p_node = collider.get_parent()
			while p_node != null:
				if p_node is PlayerCharacter:
					target_player = p_node
					break
				p_node = p_node.get_parent()

		# Identificar Bot IA
		if collider is EnemyAI:
			target_ai = collider
		else:
			var ai_node = collider.get_parent()
			while ai_node != null:
				if ai_node is EnemyAI:
					target_ai = ai_node
					break
				ai_node = ai_node.get_parent()

		var damage_dealt = false
		var is_friendly = _is_friendly_target(collider) or _is_friendly_target(target_ai) or _is_friendly_target(target_player)

		if not is_friendly:
			# A. Acerto em Hitbox específica (Head, Chest, Legs)
			if collider is HitboxComponent and net_client and target_player:
				# online: só o indicador de acerto (o dano vem do servidor)
				is_headshot = collider.is_headshot()
				hit_confirmed.emit(is_headshot, result.position)
				if gm and gm.has_method("record_shot_hit"):
					gm.record_shot_hit(is_headshot, dist)
				damage_dealt = true
			elif collider is HitboxComponent:
				collider.receive_hit(direction, weapon_data, dist, player)
				is_headshot = collider.is_headshot()
				hit_confirmed.emit(is_headshot, result.position)
				if gm and gm.has_method("record_shot_hit"):
					gm.record_shot_hit(is_headshot, dist)
				damage_dealt = true
			elif collider.has_node("HitboxComponent"):
				var hb = collider.get_node("HitboxComponent") as HitboxComponent
				hb.receive_hit(direction, weapon_data, dist, player)
				is_headshot = hb.is_headshot()
				hit_confirmed.emit(is_headshot, result.position)
				if gm and gm.has_method("record_shot_hit"):
					gm.record_shot_hit(is_headshot, dist)
				damage_dealt = true

			# B. Dano em Bot IA (caso tenha atingido a cápsula do corpo diretamente)
			if target_ai and not damage_dealt:
				var mult = weapon_data.chest_multiplier
				var dmg = int(weapon_data.get_damage_at_distance(dist) * mult)
				if target_ai.has_method("take_damage"):
					target_ai.take_damage(dmg, direction, player)
				hit_confirmed.emit(false, result.position)
				if gm and gm.has_method("record_shot_hit"):
					gm.record_shot_hit(false, dist)
				damage_dealt = true

			# C. Dano em Player Remoto (partida hospedada por este jogador: ele é o servidor)
			if target_player and target_player != player and not net_client:
				var mult = weapon_data.headshot_multiplier if is_headshot else 1.0
				var dmg = int(weapon_data.get_damage_at_distance(dist) * mult)
				var my_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
				_server_apply_player_damage(target_player, dmg, is_headshot, direction, my_id)
				hit_confirmed.emit(is_headshot, result.position)
				if gm and gm.has_method("record_shot_hit"):
					gm.record_shot_hit(is_headshot, dist)
				damage_dealt = true

		_spawn_hit_spark(result.position, result.normal)

	# 4. Recoil estilo CoD: a câmera SOBE a cada tiro e não volta sozinha — você puxa o mouse para baixo
	_add_recoil_kick()

	# 5. Cone do quadril abre a cada disparo (no ADS não há cone; o recoil é o que importa)
	_since_last_shot = 0.0
	_shots_in_string += 1
	current_bloom = clampf(current_bloom + weapon_data.get_hip_bloom_per_shot_deg(), 0.0, weapon_data.get_hip_bloom_max_deg())

	# 6. Atualizar munição
	current_ammo -= 1
	ammo_changed.emit(current_ammo, reserve_ammo)

	# 7. Cadência
	cooldown_timer = weapon_data.get_fire_interval()

	# 8. Efeitos audiovisuais
	_play_sound(weapon_data.sound_fire)
	_flash_muzzle()
	if current_viewmodel and current_viewmodel.has_method("play_shoot"):
		current_viewmodel.play_shoot()
	fire_event.emit()

	# Notificação acústica de disparo para a IA dos bots e Mini-Mapa HUD
	var gm_ref = get_node_or_null("/root/GameManager")
	var p_t = 0 if (gm_ref and gm_ref.local_player_team == 1) else 1
	var shoot_pos = player.global_position if (player and is_instance_valid(player)) else global_position
	var is_silenced = is_weapon_suppressed()
	get_tree().call_group("enemies", "notify_gunshot_heard", shoot_pos, p_t, is_silenced)
	if not is_silenced:
		get_tree().call_group("minimap", "notify_gunshot", shoot_pos, p_t, false)

func is_weapon_suppressed() -> bool:
	if weapon_data and weapon_data.is_silenced:
		return true
	var gm_ref = get_node_or_null("/root/GameManager")
	if gm_ref:
		var is_prim = (weapon_data == default_weapon) or (weapon_data and weapon_data.category != WeaponData.WeaponCategory.PISTOL and weapon_data.category != WeaponData.WeaponCategory.MELEE)
		if is_prim and ("primary_muzzle" in gm_ref and (gm_ref.primary_muzzle == "muzzle_suppressor" or gm_ref.primary_muzzle == "silencer")):
			return true
	return false

	# 9. Auto-reload quando acabar a munição do carregador
	if current_ammo <= 0 and reserve_ammo > 0:
		start_reload()

## Meio ângulo (rad) do cone do próximo tiro. Lido também pelo HUD para desenhar a mira do tamanho real.
## Quadril: cone da classe + movimento + ar, reduzido agachado/deitado, + abertura acumulada dos disparos.
## ADS: cone zero (1º tiro exato, como no CoD). Durante a transição (ads_amount 0..1) o cone vai fechando,
## então atirar no meio da animação de mira ainda espalha — não dá para "quick-scope" de quadril.
func get_spread_rad() -> float:
	if not weapon_data:
		return 0.0
	var hip_deg := weapon_data.get_hip_spread_deg() + current_bloom
	var ads := 0.0
	if player:
		var spd := Vector2(player.velocity.x, player.velocity.z).length()
		hip_deg += weapon_data.move_spread_deg * clampf(spd / PlayerConstants.WALK_SPEED, 0.0, 1.5)
		if not player.is_on_floor():
			hip_deg += weapon_data.air_spread_deg
		var st: int = int(player.get("stance_sync")) if "stance_sync" in player else 0
		if st == 1:
			hip_deg *= lerpf(1.0, weapon_data.crouch_bloom_mult, 0.5)
		elif st == 2:
			hip_deg *= lerpf(1.0, weapon_data.prone_bloom_mult, 0.5)
		ads = clampf(float(player.get("ads_amount")), 0.0, 1.0) if "ads_amount" in player else 0.0
	# curva: o cone só fica realmente pequeno no fim da transição de mira
	var t := ads * ads
	return deg_to_rad(lerpf(hip_deg, 0.0, t))

## Recoil estilo CoD. recoil_kick.y = subida vertical por tiro (graus), recoil_kick.x = amplitude horizontal.
## Os primeiros tiros sobem um pouco menos e o coice estabiliza; o horizontal segue um "drift" com ruído,
## não um tremor aleatório. Do quadril o coice é maior. A câmera NÃO recentraliza: o controle é do jogador.
const RECOIL_VERT_SCALE := 0.55
const RECOIL_HIP_MULT := 1.3
func _add_recoil_kick() -> void:
	if not weapon_data:
		return
	var k: Vector3 = weapon_data.recoil_kick
	var ads := clampf(float(player.get("ads_amount")), 0.0, 1.0) if (player and "ads_amount" in player) else 0.0
	var mult := lerpf(RECOIL_HIP_MULT, 1.0, ads)
	if player and "stance_sync" in player:
		var st := int(player.get("stance_sync"))
		if st == 1: mult *= 0.85
		elif st == 2: mult *= 0.7
	var ramp := lerpf(0.75, 1.1, clampf(float(_shots_in_string) / 6.0, 0.0, 1.0))
	var vert := k.y * RECOIL_VERT_SCALE * ramp * mult * randf_range(0.9, 1.1)
	if _shots_in_string == 0:
		_recoil_h_drift = randf_range(-1.0, 1.0)
	_recoil_h_drift = clampf(_recoil_h_drift + randf_range(-0.6, 0.6), -1.0, 1.0)
	var horiz := k.x * mult * (_recoil_h_drift * 0.8 + randf_range(-0.35, 0.35))
	_recoil_pending += Vector2(vert, horiz)

## Aplica o coice em ~50 ms (sobe rápido mas sem teletransportar a câmera).
func _update_recoil(delta: float) -> void:
	if _recoil_pending.length_squared() < 0.000001:
		return
	var step := _recoil_pending * (1.0 - exp(-40.0 * delta))
	_recoil_pending -= step
	if player and player.has_method("apply_recoil"):
		player.apply_recoil(Vector3(step.x, step.y, 0.0))

func _fire_burst() -> void:
	if _is_player_dead():
		return
	# rajada também respeita a saída do sprint (o primeiro tiro passa por try_fire)
	if _player_is_sprinting() or sprint_out_timer > 0.0:
		try_fire()
		return
	for i in weapon_data.burst_count:
		if _is_player_dead() or current_ammo <= 0:
			break
		_execute_fire()
		await get_tree().create_timer(weapon_data.burst_delay).timeout

func _execute_melee() -> void:
	if _is_player_dead():
		return
	cooldown_timer = 0.45

	if current_viewmodel and current_viewmodel.has_method("play_melee"):
		current_viewmodel.play_melee()
	elif current_viewmodel and current_viewmodel.has_method("play_shoot"):
		current_viewmodel.play_shoot()

	var melee_sfx = weapon_data.sound_melee if weapon_data.sound_melee else weapon_data.sound_fire
	if melee_sfx:
		_play_sound(melee_sfx)

	if not camera:
		if player:
			camera = player.get_node_or_null("Head/Camera") as Camera3D
			if not camera:
				camera = player.get_node_or_null("Head/MainCamera3D") as Camera3D
			if not camera:
				camera = player.find_child("Camera3D", true, false) as Camera3D
		if not camera and get_viewport():
			camera = get_viewport().get_camera_3d()
	if not camera:
		return

	var cam_basis = camera.global_transform.basis
	var direction = -cam_basis.z.normalized()
	var space = camera.get_world_3d().direct_space_state
	var params = PhysicsRayQueryParameters3D.create(
		camera.global_position,
		camera.global_position + direction * 2.5,
		0b1111,
		[player]
	)
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var result = space.intersect_ray(params)
	var net_client := _is_net_client()
	if net_client:
		var nm = get_node_or_null("/root/NetworkManager")
		if nm and nm.has_method("rpc_server_shot"):
			nm.rpc_id(1, "rpc_server_shot", camera.global_position, direction, String(weapon_data.resource_path), true)
	if result:
		var collider = result.collider
		var target_player: PlayerCharacter = null
		var target_ai: Node = null

		if collider is PlayerCharacter:
			target_player = collider
		else:
			var p_node = collider.get_parent()
			while p_node != null:
				if p_node is PlayerCharacter:
					target_player = p_node
					break
				p_node = p_node.get_parent()

		if collider is EnemyAI:
			target_ai = collider
		else:
			var ai_node = collider.get_parent()
			while ai_node != null:
				if ai_node is EnemyAI:
					target_ai = ai_node
					break
				ai_node = ai_node.get_parent()

		var melee_dealt = false
		var is_friendly = _is_friendly_target(collider) or _is_friendly_target(target_ai) or _is_friendly_target(target_player)

		if not is_friendly:
			if net_client and target_player:
				hit_confirmed.emit(false, result.position)   # dano vem do servidor
				melee_dealt = true
			elif collider is HitboxComponent:
				collider.receive_hit(direction, weapon_data, 1.0, player)
				hit_confirmed.emit(false, result.position)
				melee_dealt = true
			elif collider.has_node("HitboxComponent"):
				var hb = collider.get_node("HitboxComponent") as HitboxComponent
				hb.receive_hit(direction, weapon_data, 1.0, player)
				hit_confirmed.emit(false, result.position)
				melee_dealt = true

			if target_ai and not melee_dealt:
				if target_ai.has_method("take_damage"):
					target_ai.take_damage(100, direction, player)
				hit_confirmed.emit(false, result.position)
				melee_dealt = true

			if target_player and target_player != player and not net_client:
				var my_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
				_server_apply_player_damage(target_player, 100, false, direction, my_id)
				hit_confirmed.emit(false, result.position)

		_spawn_hit_spark(result.position, result.normal)
	
	fire_event.emit()

## Conectado a um servidor (não é o servidor): o dano em jogadores é decidido lá
func _is_net_client() -> bool:
	return multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) \
		and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and not multiplayer.is_server()

## Servidor (ou partida local): aplica o dano e avisa todos
static func _server_apply_player_damage(target: Node, dmg: int, is_headshot: bool, direction: Vector3, attacker_id: int) -> void:
	if not is_instance_valid(target):
		return
	if target.multiplayer.has_multiplayer_peer() and not (target.multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		target.rpc("take_damage_rpc", dmg, is_headshot, direction, attacker_id)
	else:
		target.take_damage_rpc(dmg, is_headshot, direction, attacker_id)

# ── RECARGA ───────────────────────────────────────────────────────────────────
func start_reload() -> void:
	if _is_player_dead() or is_reloading or weapon_data == null:
		return
	if weapon_data.category == WeaponData.WeaponCategory.MELEE:
		return
	if current_ammo == weapon_data.magazine_capacity or reserve_ammo <= 0:
		return
	if player and player.has_method("end_tac_sprint"):
		player.end_tac_sprint(false)

	is_reloading    = true
	var is_empty    = (current_ammo == 0)
	var pm = player.get_node_or_null("PerkManager") if player else null
	var reload_mult = pm.get_reload_speed_multiplier() if (pm and pm.has_method("get_reload_speed_multiplier")) else 1.0
	reload_mult *= float(weapon_data.reload_speed_mult) if "reload_speed_mult" in weapon_data else 1.0  # pente rápido etc.
	var reload_time = (weapon_data.reload_empty_time if is_empty else weapon_data.reload_tactical_time) * reload_mult
	reload_started.emit(reload_time)

	var reload_sound = weapon_data.sound_reload_empty if is_empty else weapon_data.sound_reload_tact
	_play_sound(reload_sound)
	if current_viewmodel and current_viewmodel.has_method("set_reload_time"):
		current_viewmodel.set_reload_time(reload_time)
	if current_viewmodel and current_viewmodel.has_method("play_reload"):
		current_viewmodel.play_reload()

	await get_tree().create_timer(reload_time).timeout

	if _is_player_dead():
		is_reloading = false
		return

	if is_reloading:
		var needed   = weapon_data.magazine_capacity - current_ammo
		var loaded   = mini(needed, reserve_ammo)
		current_ammo += loaded
		reserve_ammo -= loaded
		is_reloading  = false
		ammo_changed.emit(current_ammo, reserve_ammo)
		reload_finished.emit()

func cancel_reload() -> void:
	if is_reloading and weapon_data.can_cancel_reload:
		is_reloading = false

func replenish_reserve_ammo(amount: int) -> void:
	if weapon_data == null or weapon_data.category == WeaponData.WeaponCategory.MELEE:
		return
	var max_reserve = weapon_data.magazine_capacity * 5
	reserve_ammo = mini(reserve_ammo + amount, max_reserve)
	ammo_changed.emit(current_ammo, reserve_ammo)

# ── EFEITOS VISUAIS DE TIRO ──────────────────────────────────────────────────
func _flash_muzzle() -> void:
	if not weapon_rig:
		return
	if not _muzzle_light:
		_muzzle_light = OmniLight3D.new()
		_muzzle_light.name = "PooledMuzzleLight"
		_muzzle_light.light_color = Color(1.0, 0.85, 0.4)
		_muzzle_light.light_energy = 3.0
		_muzzle_light.omni_range = 4.0
		_muzzle_light.position = Vector3(0, 0, -0.4)
		_muzzle_light.visible = false
		weapon_rig.add_child(_muzzle_light)

	_muzzle_light.visible = true
	var timer = get_tree().create_timer(0.04)
	timer.timeout.connect(func():
		if is_instance_valid(_muzzle_light):
			_muzzle_light.visible = false
	)

func _spawn_hit_spark(_pos: Vector3, _normal: Vector3) -> void:
	# Não instanciar OmniLight3D dinâmico a cada bala para evitar stutters e quedas de FPS (SUB-7)
	pass

func _play_sound(stream: AudioStream) -> void:
	if stream == null:
		return
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		am.play_sfx(stream)
		return
	var asp = AudioStreamPlayer3D.new()
	asp.stream = stream
	asp.bus = "SFX"
	add_child(asp)
	asp.play()
	asp.finished.connect(asp.queue_free)

func _is_friendly_target(target: Node) -> bool:
	if not target:
		return false

	var target_char: Node = target
	if target is HitboxComponent:
		target_char = target.get_parent()
		while target_char != null and not (target_char is CharacterBody3D):
			target_char = target_char.get_parent()
	elif not (target is CharacterBody3D):
		var p_node = target.get_parent()
		while p_node != null and not (p_node is CharacterBody3D):
			p_node = p_node.get_parent()
		if p_node:
			target_char = p_node

	if not target_char or target_char == player:
		return false

	var my_team = -1
	if player and player.has_method("get_team"):
		my_team = player.get_team()
	elif player and player.get("team") != null:
		my_team = player.get("team")
	else:
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			my_team = 0 if gm.local_player_team == 1 else 1

	var target_team = -1
	if target_char.has_method("get_team"):
		target_team = target_char.get_team()
	elif target_char.get("team") != null:
		target_team = target_char.get("team")
	elif target_char is PlayerCharacter:
		var net = get_node_or_null("/root/NetworkManager")
		if net and net.has_method("is_player_alpha") and "peer_id" in target_char:
			target_team = 0 if net.is_player_alpha(target_char.peer_id) else 1

	if my_team == -1 or target_team == -1:
		return false

	var is_ffa = false
	var gmm = get_node_or_null("/root/GameModeManager")
	if not gmm and get_tree() and get_tree().current_scene:
		gmm = get_tree().current_scene.find_child("GameModeManager", true, false)
	if gmm and "game_mode" in gmm and gmm.game_mode == 4:
		is_ffa = true

	return not is_ffa and (my_team == target_team)
