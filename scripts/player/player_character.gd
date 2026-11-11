# =============================================================================
# player_character.gd
# Extensão Multiplayer e Combate do FPC (Colormatic Studios v2)
# Gerencia autoridade de rede, hitboxes, vida, HUD e respawn
# =============================================================================
class_name PlayerCharacter
extends Character
const TP_ARM_IK = preload("res://scripts/characters/tp_arm_ik.gd")  # pegada da arma em 3ª pessoa

const CharacterRetargeter = preload("res://scripts/characters/character_retargeter.gd")

signal player_killed(victim_peer_id: int, killer_peer_id: int)

@export var health_component: HealthComponent
@export var shadow_soldier: Node3D
@export var viewmodel_rig: Node3D
@export var weapon_manager: WeaponManager
@export var perk_manager: PerkManager
@export var synchronizer: MultiplayerSynchronizer
@export var team: int = 0

var peer_id: int = 1
var is_dead: bool = false
var respawn_timer: float = 0.0
var _high_alert_timer: float = 0.0
var original_spawn_transform: Transform3D
var _shadow_anim_player: AnimationPlayer = null
var _death_cam_target_pos: Vector3 = Vector3(0, 0.25, 0)
var _death_cam_target_rot: Vector3 = Vector3.ZERO
var _original_head_pos: Vector3 = Vector3(0, 1.5, 0)

var _cam_flinch_rot: Vector3 = Vector3.ZERO
# Postura e inclinação replicadas (MultiplayerSynchronizer): 0 em pé, 1 agachado, 2 deitado; -1..1
var stance_sync: int = 0
var lean_sync: float = 0.0
var _vis_crouch: float = 0.0
var _vis_prone: float = 0.0
var _vis_lean: float = 0.0
var _shadow_base_xf: Transform3D = Transform3D.IDENTITY
var _shadow_base_ready: bool = false
var _stance_legs: StanceLegModifier = null
var _cam_flinch_vel: Vector3 = Vector3.ZERO
var sound_flesh_impact: AudioStream = null
var sound_soldier_grunt: AudioStream = null

func get_team() -> int:
	var net = _get_network_manager()
	if net and net.multiplayer.has_multiplayer_peer() and net.multiplayer.get_peers().size() > 0:
		return 0 if net.is_player_alpha(peer_id) else 1
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		return 0 if gm.local_player_team == 1 else 1
	return team

func is_local_player() -> bool:
	if name.begins_with("Player_Old_") or is_queued_for_deletion():
		return false
	if not is_inside_tree() or multiplayer == null or multiplayer.multiplayer_peer == null:
		return peer_id == 1 or peer_id == 0
	return is_multiplayer_authority()

func _enter_tree() -> void:
	if name.begins_with("Player_Old_") or is_queued_for_deletion():
		peer_id = -1
		return
	# Configurar autoridade de rede baseada no nome do nó (ex: Player_1 -> 1)
	var id_str = name.trim_prefix("Player_")
	if id_str.is_valid_int():
		peer_id = id_str.to_int()
	else:
		peer_id = multiplayer.get_unique_id() if (is_inside_tree() and multiplayer != null and multiplayer.multiplayer_peer != null) else 1
	set_multiplayer_authority(peer_id)

func _ready() -> void:
	add_to_group("player")
	super._ready()
	original_spawn_transform = global_transform

	if HEAD:
		_original_head_pos = HEAD.position

	if not health_component:
		health_component = get_node_or_null("HealthComponent") as HealthComponent

	if not shadow_soldier:
		shadow_soldier = get_node_or_null("ShadowSoldier") as Node3D

	if not viewmodel_rig:
		viewmodel_rig = get_node_or_null("Head/Camera/WeaponRig") as Node3D

	if not weapon_manager and viewmodel_rig:
		weapon_manager = viewmodel_rig.get_node_or_null("WeaponManager") as WeaponManager

	if weapon_manager and not weapon_manager.fire_event.is_connected(_on_weapon_fire_event):
		weapon_manager.fire_event.connect(_on_weapon_fire_event)

	_apply_character_skin()
	_setup_multiplayer_view()
	_setup_hitboxes()

	if health_component:
		health_component.died.connect(_on_death)
		health_component.damage_received.connect(_on_health_damage_received)

	if ResourceLoader.exists("res://assets/audio/foley/flesh_impact.wav"):
		sound_flesh_impact = load("res://assets/audio/foley/flesh_impact.wav")
	if ResourceLoader.exists("res://assets/audio/foley/soldier_grunt.wav"):
		sound_soldier_grunt = load("res://assets/audio/foley/soldier_grunt.wav")

	# Escudo de Invencibilidade de 3s no spawn inicial
	if health_component and health_component.has_method("activate_spawn_protection"):
		health_component.activate_spawn_protection(3.0)

	# Inicialização e Configuração do PerkManager (Estilo Black Ops 6)
	if not perk_manager:
		perk_manager = get_node_or_null("PerkManager") as PerkManager
		if not perk_manager:
			perk_manager = PerkManager.new()
			perk_manager.name = "PerkManager"
			add_child(perk_manager)

	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if is_local_player():
			perk_manager.configure_loadout(
				gm.selected_perk1,
				gm.selected_perk2,
				gm.selected_perk3,
				gm.selected_specialty
			)
			perk_manager.recon_reveal_triggered.connect(_on_recon_reveal_triggered)

		if gm.is_in_countdown():
			immobile = true
			jumping_enabled = false
		gm.match_countdown_started.connect(_on_countdown_started)
		gm.match_countdown_completed.connect(_on_countdown_completed)

func _on_countdown_started(_duration: float) -> void:
	if is_local_player():
		immobile = true
		jumping_enabled = false

func _on_countdown_completed() -> void:
	if is_local_player():
		immobile = false
		jumping_enabled = true

func _on_weapon_fire_event() -> void:
	play_shadow_shoot()
	if health_component and health_component.has_method("cancel_spawn_protection"):
		health_component.cancel_spawn_protection()
	if multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
		rpc("rpc_shadow_shoot")

@rpc("call_remote")
func rpc_shadow_shoot() -> void:
	play_shadow_shoot()

func play_shadow_shoot() -> void:
	if _shadow_anim_player and _shadow_anim_player.has_animation("shoot"):
		_shadow_anim_player.play("shoot", 0.08)

func _apply_character_skin() -> void:
	# Usar modelo Mixamo X Bot como representação 3D do jogador
	# (visível para outros jogadores no multiplayer e como sombra local)
	var need_instantiate = false
	if shadow_soldier:
		var existing_ap = shadow_soldier.find_child("AnimationPlayer", true, false)
		if not existing_ap or not existing_ap.has_animation("idle"):
			need_instantiate = true
	else:
		need_instantiate = true

	if need_instantiate:
		var mixamo_scene = load("res://assets/models/mixamo/x_bot.glb") as PackedScene
		if not mixamo_scene:
			return

		var new_skin: Node3D = mixamo_scene.instantiate() as Node3D
		new_skin.name = "CharacterSkin"
		new_skin.rotation.y = PI

		if shadow_soldier and shadow_soldier != self:
			var parent = shadow_soldier.get_parent()
			var old_pos = shadow_soldier.position
			shadow_soldier.queue_free()
			parent.add_child(new_skin)
			new_skin.position = old_pos
			shadow_soldier = new_skin
		else:
			add_child(new_skin)
			shadow_soldier = new_skin

	var skin_skel = shadow_soldier.find_child("Skeleton3D", true, false) as Skeleton3D
	if skin_skel:
		var hips_idx = skin_skel.find_bone("mixamorig_Hips")
		if hips_idx >= 0:
			var hips_pose = skin_skel.get_bone_global_pose(hips_idx)
			shadow_soldier.position.x = -hips_pose.origin.x

	# Corrigir binds de esqueleto
	ModelFixer.fix_skins(shadow_soldier)

	# Configurar AnimationPlayer do modelo Mixamo para o shadow soldier
	_shadow_anim_player = shadow_soldier.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _shadow_anim_player:
		for anim_name in ["idle", "walk", "run", "walk_backward", "run_backward", "strafe_left", "strafe_right"]:
			if _shadow_anim_player.has_animation(anim_name):
				_shadow_anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		if _shadow_anim_player.has_animation("idle"):
			_shadow_anim_player.play("idle")

	# Anexar rifle 3D à mão direita do soldado Mixamo para representação multiplayer completa
	var skel = shadow_soldier.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel:
		var r_hand_idx = skel.find_bone("mixamorig_RightHand")
		if r_hand_idx >= 0:
			var bone_att = skel.get_node_or_null("RightHandAttachment") as BoneAttachment3D
			if not bone_att:
				bone_att = BoneAttachment3D.new()
				bone_att.name = "RightHandAttachment"
				bone_att.bone_name = "mixamorig_RightHand"
				skel.add_child(bone_att)

			var rifle = bone_att.get_node_or_null("PlayerRifle3D")
			if not rifle:
				var rifle_scn = load("res://scenes/weapons/bot_rifle_3d.tscn") as PackedScene
				if rifle_scn:
					rifle = rifle_scn.instantiate() as Node3D
					rifle.name = "PlayerRifle3D"
					bone_att.add_child(rifle)
					rifle.scale = CharacterRetargeter.CS_RIFLE_LOCAL_SCALE
					rifle.position = CharacterRetargeter.CS_RIFLE_LOCAL_POS
					rifle.rotation_degrees = CharacterRetargeter.CS_RIFLE_LOCAL_ROT
					rifle.visible = true
					var arm_ik := TP_ARM_IK.new()
					arm_ik.name = "TpArmIK"
					skel.add_child(arm_ik)
					arm_ik.rifle = rifle
					arm_ik.facing = self
					# a arma em 3ª pessoa mostra a classe DESTE jogador (antes usava a classe do jogador local)
					var nm_l = get_node_or_null("/root/NetworkManager")
					if nm_l and nm_l.peer_loadouts.has(peer_id):
						apply_remote_loadout(nm_l.peer_loadouts[peer_id])
					elif is_local_player():
						apply_remote_loadout(nm_l.build_local_loadout() if nm_l else {})

	if is_local_player() and shadow_soldier:
		_set_mesh_shadow_only(shadow_soldier, true)


func _setup_multiplayer_view() -> void:
	var is_local = is_local_player()
	var peer_null = not is_inside_tree() or multiplayer == null or multiplayer.multiplayer_peer == null
	print("   peer_id: ", peer_id, " | is_local: ", is_local, " | peer_null: ", peer_null)

	# Se for um nó antigo ou marcado para exclusão, silenciar e desativar imediatamente
	if is_queued_for_deletion() or name.begins_with("Player_Old_"):
		if CAMERA:
			CAMERA.current = false
		if viewmodel_rig:
			viewmodel_rig.visible = false
			viewmodel_rig.process_mode = Node.PROCESS_MODE_DISABLED
		process_mode = Node.PROCESS_MODE_DISABLED
		return

	# Garantir que somente UM jogador local ativo possua câmera ativa e viewmodel visível no mundo
	if is_local and is_inside_tree():
		var all_players = get_tree().get_nodes_in_group("player")
		for other in all_players:
			if other != self and is_instance_valid(other) and not other.is_queued_for_deletion() and not other.name.begins_with("Player_Old_"):
				if other.has_node("Head/Camera"):
					var other_cam = other.get_node("Head/Camera") as Camera3D
					if other_cam and other_cam.current:
						is_local = false
						break

	if is_local:
		# Jogador Local: ativa câmera e arma 1P, oculta malha do corpo (apenas sombra)
		if CAMERA:
			CAMERA.current = true
			CAMERA.near = 0.005
			CAMERA.cull_mask = 1048571 # Camada 1 (Mundo) e Camada 2 (Viewmodel) — exclui Camada 3 (Sombra do jogador local)
			print("   -> SUCESSO: CAMERA.current ATIVADA COM ÊXITO!")
		if viewmodel_rig:
			viewmodel_rig.visible = true
			viewmodel_rig.process_mode = Node.PROCESS_MODE_INHERIT
		if shadow_soldier:
			_set_mesh_shadow_only(shadow_soldier, true)
		if has_node("Mesh"):
			$Mesh.visible = false
	else:
		# Oponente Remoto: desativa câmera local, oculta arma 1P, exibe soldado 3D completo
		if CAMERA:
			CAMERA.current = false
		if viewmodel_rig:
			viewmodel_rig.visible = false
			viewmodel_rig.process_mode = Node.PROCESS_MODE_DISABLED
		if shadow_soldier:
			shadow_soldier.visible = true
			_set_mesh_shadow_only(shadow_soldier, false)
		if has_node("Mesh"):
			$Mesh.visible = false

func _set_mesh_shadow_only(root: Node, shadow_only: bool) -> void:
	if root is VisualInstance3D:
		root.layers = 4 if shadow_only else 1 # 4: invisível para a câmera 1P, mas gera sombras; 1: visível no mundo
	if root is GeometryInstance3D: # Luzes (ex.: clarão do cano) não têm cast_shadow
		root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if shadow_only else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in root.get_children():
		_set_mesh_shadow_only(child, shadow_only)

func _setup_hitboxes() -> void:
	# Garantir Hitboxes com colisão para detecção de raycast
	if not has_node("Hitbox_Head"):
		var head_hb = HitboxComponent.new()
		head_hb.name = "Hitbox_Head"
		head_hb.region = HitboxComponent.Region.HEAD
		head_hb.collision_layer = 0b10  # Camada 2: Hitboxes
		head_hb.collision_mask = 0
		var col = CollisionShape3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = 0.28
		col.shape = sphere
		col.position = Vector3(0, 1.6, 0)
		head_hb.add_child(col)
		add_child(head_hb)

	if not has_node("Hitbox_Chest"):
		var chest_hb = HitboxComponent.new()
		chest_hb.name = "Hitbox_Chest"
		chest_hb.region = HitboxComponent.Region.CHEST
		chest_hb.collision_layer = 0b10  # Camada 2: Hitboxes
		chest_hb.collision_mask = 0
		var col = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(0.5, 0.7, 0.4)
		col.shape = box
		col.position = Vector3(0, 1.05, 0)
		chest_hb.add_child(col)
		add_child(chest_hb)

	if not has_node("Hitbox_Legs"):
		var legs_hb = HitboxComponent.new()
		legs_hb.name = "Hitbox_Legs"
		legs_hb.region = HitboxComponent.Region.LEG_L
		legs_hb.collision_layer = 0b10  # Camada 2: Hitboxes
		legs_hb.collision_mask = 0
		var col = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(0.5, 0.7, 0.4)
		col.shape = box
		col.position = Vector3(0, 0.35, 0)
		legs_hb.add_child(col)
		add_child(legs_hb)

func _input(event: InputEvent) -> void:
	if not is_local_player() or is_dead or is_queued_for_deletion() or name.begins_with("Player_Old_"):
		return
	super._input(event)

func _process(delta: float) -> void:
	if not is_local_player() or is_dead or is_queued_for_deletion() or name.begins_with("Player_Old_"):
		return
	super._process(delta)
	_update_tac_sprint_pose()

	if perk_manager and perk_manager.has_perk("high_alert"):
		_update_high_alert_sensor(delta)

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion() or name.begins_with("Player_Old_"):
		return
	if is_dead:
		respawn_timer -= delta
		if is_local_player() and HEAD:
			HEAD.position = HEAD.position.lerp(_death_cam_target_pos, delta * 7.0)
			HEAD.rotation.x = lerp_angle(HEAD.rotation.x, _death_cam_target_rot.x, delta * 6.5)
			HEAD.rotation.z = lerp_angle(HEAD.rotation.z, _death_cam_target_rot.z, delta * 6.5)
		if respawn_timer <= 0.0 and is_local_player():
			respawn()
		_update_shadow_animation(delta)
		return

	if is_local_player():
		super._physics_process(delta)
		# Recuperação por mola do Camera Flinch (Módulo 5)
		if CAMERA and not is_dead:
			var spring_k = 220.0
			var damping = 24.0
			_cam_flinch_vel += -spring_k * _cam_flinch_rot * delta - damping * _cam_flinch_vel * delta
			_cam_flinch_rot += _cam_flinch_vel * delta
			cam_extra_rot = Vector2(_cam_flinch_rot.x, _cam_flinch_rot.z)   # aplicado junto com balanço e inclinação
		stance_sync = stance_id()
		lean_sync = lean_amount
		# Proteção contra queda acidental no vazio / fora do mapa
		if global_position.y < -15.0 and not is_dead:
			respawn()
	else:
		# Sincronização remota suave
		move_and_slide()

	_update_shadow_animation(delta)
	_update_stance_body(delta)

func _update_shadow_animation(delta: float) -> void:
	if not _shadow_anim_player:
		return

	if is_dead:
		if _shadow_anim_player.has_animation("die") and _shadow_anim_player.current_animation != "die":
			_shadow_anim_player.play("die", 0.15)
		return

	# Não interromper animação de disparo se estiver tocando
	if _shadow_anim_player.current_animation == "shoot" and _shadow_anim_player.is_playing():
		return

	var speed_h = Vector2(velocity.x, velocity.z).length()

	# Pulo / queda no ar
	if not is_on_floor() and abs(velocity.y) > 1.2:
		var jump_anim = "jump_forward" if speed_h > 0.5 else "jump_backward"
		if _shadow_anim_player.has_animation(jump_anim) and _shadow_anim_player.current_animation != jump_anim:
			_shadow_anim_player.play(jump_anim, 0.15)
		return

	if speed_h < 0.3:
		if _shadow_anim_player.current_animation != "idle":
			_shadow_anim_player.play("idle", 0.25)
		_shadow_anim_player.speed_scale = 1.0
		return

	# Determinar direção de movimento relativa ao facing do jogador
	var facing_dir = -global_transform.basis.z
	facing_dir.y = 0.0
	facing_dir = facing_dir.normalized()

	var move_dir = Vector3(velocity.x, 0, velocity.z).normalized()
	var dot_fwd = facing_dir.dot(move_dir)
	var cross_y = facing_dir.cross(move_dir).y

	var is_sprinting = speed_h > 4.8

	if dot_fwd > 0.5:
		if is_sprinting and _shadow_anim_player.has_animation("run"):
			if _shadow_anim_player.current_animation != "run":
				_shadow_anim_player.play("run", 0.2)
			_shadow_anim_player.speed_scale = clampf(speed_h / 6.0, 0.6, 1.6)
		else:
			if _shadow_anim_player.current_animation != "walk":
				_shadow_anim_player.play("walk", 0.2)
			_shadow_anim_player.speed_scale = clampf(speed_h / 2.2, 0.5, 2.0)
	elif dot_fwd < -0.5:
		if is_sprinting and _shadow_anim_player.has_animation("run_backward"):
			if _shadow_anim_player.current_animation != "run_backward":
				_shadow_anim_player.play("run_backward", 0.2)
			_shadow_anim_player.speed_scale = clampf(speed_h / 5.5, 0.6, 1.6)
		elif _shadow_anim_player.has_animation("walk_backward"):
			if _shadow_anim_player.current_animation != "walk_backward":
				_shadow_anim_player.play("walk_backward", 0.2)
			_shadow_anim_player.speed_scale = clampf(speed_h / 2.0, 0.5, 2.0)
		else:
			if _shadow_anim_player.current_animation != "walk":
				_shadow_anim_player.play("walk", 0.2)
	elif cross_y > 0.3:
		if _shadow_anim_player.has_animation("strafe_right"):
			if _shadow_anim_player.current_animation != "strafe_right":
				_shadow_anim_player.play("strafe_right", 0.2)
			_shadow_anim_player.speed_scale = clampf(speed_h / 3.5, 0.6, 1.5)
		else:
			if _shadow_anim_player.current_animation != "walk":
				_shadow_anim_player.play("walk", 0.2)
	elif cross_y < -0.3:
		if _shadow_anim_player.has_animation("strafe_left"):
			if _shadow_anim_player.current_animation != "strafe_left":
				_shadow_anim_player.play("strafe_left", 0.2)
			_shadow_anim_player.speed_scale = clampf(speed_h / 3.5, 0.6, 1.5)
		else:
			if _shadow_anim_player.current_animation != "walk":
				_shadow_anim_player.play("walk", 0.2)
	else:
		if _shadow_anim_player.current_animation != "walk":
			_shadow_anim_player.play("walk", 0.2)

func take_damage(amount: int, direction: Vector3 = Vector3.ZERO, attacker: Node = null) -> void:
	if is_dead:
		return
	if health_component:
		if health_component.is_dead:
			return
		health_component.take_damage(amount, direction, "Chest", attacker)

@rpc("any_peer", "call_local")
func take_damage_rpc(amount: int, is_headshot: bool, hit_dir: Vector3, attacker_id: int) -> void:
	# só o servidor aplica dano (cliente não consegue mandar "tome X de dano")
	if not _from_server():
		return
	if is_dead:
		return
	if health_component and health_component.is_dead:
		return

	if health_component:
		health_component.take_damage(amount, hit_dir, "Head" if is_headshot else "Chest")

	# morte decidida pelo servidor, pela vida da cópia dele
	if _is_server_side() and health_component and health_component.current_health <= 0:
		if _net_online():
			rpc("sync_death", attacker_id)
		else:
			sync_death(attacker_id)

## Chamada veio do servidor (ou é local, sem rede)
func _from_server() -> bool:
	if not _net_online():
		return true
	var s := multiplayer.get_remote_sender_id()
	return s == 1 or (s == 0 and multiplayer.is_server())

func _net_online() -> bool:
	return multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)

func _is_server_side() -> bool:
	return (not _net_online()) or multiplayer.is_server()

var _death_reported: bool = false
var _death_time_ms: int = 0

@rpc("any_peer", "call_local", "reliable")
func sync_death(killer_id: int) -> void:
	if not _from_server() or _death_reported:
		return
	_death_reported = true
	_death_time_ms = Time.get_ticks_msec()
	if is_local_player() and not is_dead:
		_on_death(Vector3.ZERO, "Chest")
	is_dead = true
	respawn_timer = 3.0
	
	if is_local_player():
		if weapon_manager and weapon_manager.has_method("on_player_died"):
			weapon_manager.on_player_died()
		elif viewmodel_rig:
			viewmodel_rig.visible = false
		ads_amount = 0.0
		velocity = Vector3.ZERO
		_start_death_camera(Vector3.ZERO)
	else:
		visible = false
	
	# Desativar colisões temporariamente
	if has_node("Collision"):
		get_node("Collision").set_deferred("disabled", true)

	# Notificar NetworkManager para pontuação
	var net = _get_network_manager()
	if net and net.has_method("report_kill"):
		net.report_kill(killer_id, peer_id)

func _on_health_damage_received(amount: int, direction: Vector3, _attacker: Node) -> void:
	if is_dead or not is_local_player():
		return
	_apply_damage_flinch(amount, direction)
	_play_damage_audio(amount)

func _apply_damage_flinch(amount: int, direction: Vector3) -> void:
	var strength = clampf(float(amount) / 45.0, 0.4, 1.2)
	# coronha pesada etc.: menos tranco na mira
	var wd_f = weapon_manager.weapon_data if weapon_manager and "weapon_data" in weapon_manager else null
	if wd_f and "flinch_mult" in wd_f:
		strength *= float(wd_f.flinch_mult)
	_cam_flinch_vel.x += deg_to_rad(randf_range(2.0, 4.0) * strength)
	if direction != Vector3.ZERO:
		var cam_right = global_transform.basis.x
		var dot_r = direction.dot(cam_right)
		_cam_flinch_vel.z += deg_to_rad(dot_r * randf_range(2.0, 4.5) * strength)
	else:
		_cam_flinch_vel.z += deg_to_rad(randf_range(-2.0, 2.0) * strength)

func _play_damage_audio(amount: int) -> void:
	var am = get_node_or_null("/root/AudioManager")
	if not am:
		return
	am.play_sfx(sound_flesh_impact, 1.0, randf_range(0.95, 1.05))
	if amount >= 20 or randf() < 0.45:
		am.play_sfx(sound_soldier_grunt, -1.0, randf_range(0.96, 1.06))

func _start_death_camera(death_dir: Vector3) -> void:
	if not is_local_player() or not HEAD:
		return

	var roll_sign = 1.0 if randf() > 0.5 else -1.0
	if death_dir != Vector3.ZERO:
		var cam_right = global_transform.basis.x
		var dot_right = death_dir.dot(cam_right)
		roll_sign = -1.0 if dot_right > 0.0 else 1.0

	_death_cam_target_pos = Vector3(roll_sign * 0.12, 0.22, 0.06)
	_death_cam_target_rot = Vector3(deg_to_rad(randf_range(16.0, 26.0)), HEAD.rotation.y, deg_to_rad(roll_sign * randf_range(22.0, 32.0)))

func _on_death(_death_dir: Vector3, _hit_bone: String) -> void:
	if is_dead:
		return
	is_dead = true
	respawn_timer = 3.0
	print("[Player] Morreu! Respawn em 3 segundos...")

	# Trava imediata de combate estilo CoD (Módulo 1)
	if weapon_manager and weapon_manager.has_method("on_player_died"):
		weapon_manager.on_player_died()
	elif viewmodel_rig:
		viewmodel_rig.visible = false

	ads_amount = 0.0
	velocity = Vector3.ZERO

	# Câmera de Morte Colapso Físico 1P estilo CoD (Módulo 2)
	_start_death_camera(_death_dir)

	# Desativar colisão física temporariamente
	if has_node("Collision"):
		get_node("Collision").set_deferred("disabled", true)

	if _shadow_anim_player and _shadow_anim_player.has_animation("die"):
		_shadow_anim_player.play("die", 0.15)

	var killer_name = "Inimigo"
	var killer_id = 0
	var killer_team = 1
	var is_head = (_hit_bone == "Head")

	if health_component and health_component.last_attacker and is_instance_valid(health_component.last_attacker):
		var att = health_component.last_attacker
		if "bot_display_name" in att and not str(att.bot_display_name).is_empty():
			killer_name = att.bot_display_name
		elif "name" in att:
			killer_name = att.name
		if "bot_id" in att and att.bot_id > 0:
			killer_id = att.bot_id
		else:
			killer_id = att.get_instance_id()
		if "team" in att:
			killer_team = att.team

	var dist = 0.0
	var is_cr = false
	var is_sl = false
	if health_component and health_component.last_attacker and is_instance_valid(health_component.last_attacker) and health_component.last_attacker is Node3D:
		dist = global_position.distance_to(health_component.last_attacker.global_position)
		if "state_machine" in health_component.last_attacker and health_component.last_attacker.state_machine:
			var st = health_component.last_attacker.state_machine.current_state
			is_cr = (st == MovementStateMachine.State.CROUCH or st == MovementStateMachine.State.PRONE)
			is_sl = (st == MovementStateMachine.State.SLIDE)

	# 1. Registrar no GameManager (SUB-5: incrementa deaths do player e pontua time inimigo)
	var gm = get_node_or_null("/root/GameManager")
	var my_team = 0
	if gm:
		my_team = 0 if gm.local_player_team == 1 else 1
		gm.register_team_kill(killer_team, my_team, killer_id, 1, is_head, is_cr, is_sl, dist)

	# 2. Exibir mensagem de morte estilo CoD na HUD (SUB-3)
	var hud = _find_hud()
	if hud and hud.has_method("show_death_message"):
		hud.show_death_message(killer_name, "ACR 6.8", 3.0)

func respawn() -> void:
	is_dead = false
	_death_reported = false
	tac_sprinting = false
	tac_sprint_pose = 0.0
	tac_sprint_energy = 1.0
	tac_visual = 0.0; _tac_visual_v = 0.0
	run_visual = 0.0; _run_visual_v = 0.0
	busy_visual = 0.0; _busy_visual_v = 0.0
	# volta em pé, sem inclinação nem escalada
	mantling = false
	lean_amount = 0.0
	_stance_lerp_active = false
	state = "normal"
	speed = base_speed
	_apply_stance_values(STANCE_STAND)
	if CROUCH_ANIMATION and CROUCH_ANIMATION.has_animation("RESET"):
		CROUCH_ANIMATION.play("RESET")
	stance_sync = 0
	lean_sync = 0.0
	cam_extra_rot = Vector2.ZERO
	if viewmodel_rig:
		viewmodel_rig.transform = Transform3D.IDENTITY
	visible = true
	
	if has_node("Collision"):
		get_node("Collision").set_deferred("disabled", false)

	# Restaurar câmera normal em pé estilo CoD (Módulo 2 e 5)
	_cam_flinch_rot = Vector3.ZERO
	_cam_flinch_vel = Vector3.ZERO
	if HEAD:
		HEAD.position = _original_head_pos
		HEAD.rotation = Vector3.ZERO
	if CAMERA:
		CAMERA.position = Vector3.ZERO
		CAMERA.rotation = Vector3.ZERO

	if health_component:
		health_component.revive()
		health_component.activate_spawn_protection(3.0)

	# Re-equipar e recarregar arma com munição cheia estilo CoD (SUB-4)
	if weapon_manager and weapon_manager.has_method("reset_on_respawn"):
		weapon_manager.reset_on_respawn()

	# Notificar PerkManager sobre o respawn (ativa Recon Wallhack se aplicável)
	if perk_manager:
		perk_manager.on_player_respawned()

	# Esconder tela de morte na HUD
	var hud = _find_hud()
	if hud and hud.has_method("hide_death_message"):
		hud.hide_death_message()

	# Buscar spawn seguro no NetworkManager
	var net = _get_network_manager()
	if net and net.has_method("get_spawn_transform"):
		var is_alpha = net.is_player_alpha(peer_id) if net.has_method("is_player_alpha") else (peer_id == 1)
		global_transform = net.get_spawn_transform(is_alpha, peer_id)
	else:
		global_transform = original_spawn_transform

	velocity = Vector3.ZERO
	if _shadow_anim_player and _shadow_anim_player.has_animation("idle"):
		_shadow_anim_player.play("idle", 0.1)
	_setup_multiplayer_view()
	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer != null:
		rpc("sync_respawn", global_position)

func _find_hud() -> Node:
	if get_tree() and get_tree().current_scene:
		var h = get_tree().current_scene.get_node_or_null("MPHud")
		if h: return h
		h = get_tree().current_scene.find_child("MPHud", true, false)
		if h: return h
		var canvas = get_tree().current_scene.find_child("CanvasLayer", true, false)
		if canvas and canvas is MPHud: return canvas
	return null

func _get_network_manager() -> Node:
	var net = get_node_or_null("/root/NetworkManager")
	if net: return net
	if get_tree() and get_tree().current_scene:
		net = get_tree().current_scene.get_node_or_null("NetworkManager")
		if net: return net
		net = get_tree().current_scene.find_child("NetworkManager", true, false)
		if net: return net
	return null

@rpc("call_local")
func sync_respawn(pos: Vector3) -> void:
	# servidor: não aceita voltar antes do tempo de respawn
	if _net_online() and multiplayer.is_server() and _death_reported and Time.get_ticks_msec() - _death_time_ms < 2500:
		return
	_death_reported = false
	if health_component and health_component.is_dead:
		health_component.revive()
	is_dead = false
	visible = true
	global_position = pos
	if has_node("Collision"):
		get_node("Collision").set_deferred("disabled", false)

# ── SISTEMA DE VANTAGENS BO6 (SENSORES & EVENTOS) ────────────────────────────
func _update_high_alert_sensor(delta: float) -> void:
	_high_alert_timer += delta
	if _high_alert_timer < 0.16:
		return
	_high_alert_timer = 0.0

	var my_team = get_team()
	var my_pos = global_position + Vector3(0, 1.2, 0)
	var cam_fwd = -CAMERA.global_transform.basis.z if CAMERA else -global_transform.basis.z
	var cam_right = CAMERA.global_transform.basis.x if CAMERA else global_transform.basis.x

	var enemies: Array[Node] = []
	for b in get_tree().get_nodes_in_group("enemies"):
		enemies.append(b)
	for p in get_tree().get_nodes_in_group("player"):
		if p != self and is_instance_valid(p) and not enemies.has(p):
			enemies.append(p)

	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy == self:
			continue
		if "is_dead" in enemy and enemy.is_dead:
			continue
		var e_team = enemy.get_team() if enemy.has_method("get_team") else (enemy.team if "team" in enemy else -1)
		if e_team == my_team and my_team != -1:
			continue

		var enemy_pos = enemy.global_position + Vector3(0, 1.2, 0)
		var dist_sq = my_pos.distance_squared_to(enemy_pos)
		if dist_sq > (45.0 * 45.0):
			continue

		var dir_from_enemy_to_me = (my_pos - enemy_pos).normalized()
		var enemy_fwd = -enemy.global_transform.basis.z
		if "HEAD" in enemy and enemy.HEAD:
			enemy_fwd = -enemy.HEAD.global_transform.basis.z

		# Inimigo está mirando na direção do jogador local?
		if enemy_fwd.dot(dir_from_enemy_to_me) > 0.92:
			# Está fora do campo de visão frontal direto?
			var dir_from_me_to_enemy = -dir_from_enemy_to_me
			var forward_dot = cam_fwd.dot(dir_from_me_to_enemy)
			if forward_dot < 0.65:
				var side_dot = cam_right.dot(dir_from_me_to_enemy)
				var side = "behind"
				if side_dot > 0.35:
					side = "right"
				elif side_dot < -0.35:
					side = "left"

				var hud = _find_hud()
				if hud and hud.has_method("trigger_high_alert_pulse"):
					hud.trigger_high_alert_pulse(side)
				break

func _on_recon_reveal_triggered(duration: float) -> void:
	var hud = _find_hud()
	if hud and hud.has_method("trigger_recon_wallhack_pulse"):
		hud.trigger_recon_wallhack_pulse(duration)

## Arma em 3ª pessoa com a classe recebida pela rede (arma + acessórios + camuflagem)
func apply_remote_loadout(d: Dictionary) -> void:
	if d.is_empty():
		return
	var rifle = find_child("PlayerRifle3D", true, false)
	if rifle and rifle.has_method("set_weapon_loadout"):
		rifle.set_weapon_loadout(str(d.get("weapon", "")), d, str(d.get("camo", "default")))

## Velocidade do jogador pela arma (como no CoD): mobilidade dos acessórios e mira mais lenta,
## ajustada pelas coronhas. Correndo não se mira, então a redução de mira só vale andando/agachado.
# ── POSE DA ARMA NA CORRIDA (estilo CoD MW/Warzone) ─────────────────────────
# Move o WeaponRig inteiro (braços + arma, qualquer viewmodel) girando em volta da empunhadura.
# Corrida normal: arma baixa e virada para a esquerda. Corrida tática: arma erguida, cano para cima.
# Entrada e saída usam mola (passa um pouco do ponto e assenta), como as animações do CoD.
# Posição em metros, rotação em graus, tudo no espaço da câmera.
const TAC_POSE_POS        := Vector3(0.20, 0.01, -0.01)   # arma erguida no canto superior direito, quase saindo da tela (CoD)
const TAC_POSE_ROT        := Vector3(36.0, 4.0, 40.0)
const TAC_POSE_PIVOT      := Vector3(0.11, -0.17, -0.36)   # empunhadura (gira em torno da mão, não do olho)
const TAC_POSE_POS_PISTOL := Vector3(0.13, -0.03, -0.03)   # pistola erguida ao lado do rosto, à direita
const TAC_POSE_ROT_PISTOL := Vector3(44.0, -4.0, 10.0)
const TAC_POSE_PIVOT_PISTOL := Vector3(0.03, -0.16, -0.34)
const RUN_POSE_POS        := Vector3(-0.01, -0.035, 0.02)
const RUN_POSE_ROT        := Vector3(-12.0, 28.0, -8.0)
const RUN_POSE_POS_PISTOL := Vector3(0.0, -0.04, 0.02)
const RUN_POSE_ROT_PISTOL := Vector3(-30.0, 12.0, 4.0)
const BUSY_POSE_POS        := Vector3(0.02, -0.17, 0.07)    # rastejando/escalando: arma baixa, fora de uso
const BUSY_POSE_ROT        := Vector3(-38.0, 26.0, -22.0)
const BUSY_POSE_POS_PISTOL := Vector3(0.0, -0.15, 0.05)
const BUSY_POSE_ROT_PISTOL := Vector3(-48.0, 10.0, 0.0)
const POSE_SPRING_K       := 190.0   # rigidez
const POSE_SPRING_C       := 17.0    # amortecimento (< 2*sqrt(K) = passa um pouco do ponto)

## Pose visual com mola (0 = arma em posição de tiro, 1 = pose completa). Lidas também pelo viewmodel.
var tac_visual : float = 0.0
var run_visual : float = 0.0
var _tac_visual_v : float = 0.0
var _run_visual_v : float = 0.0
var busy_visual : float = 0.0
var _busy_visual_v : float = 0.0

func _spring(x: float, v: float, target: float, dt: float) -> Vector2:
	v += (POSE_SPRING_K * (target - x) - POSE_SPRING_C * v) * dt
	x += v * dt
	return Vector2(x, v)

func _update_tac_sprint_pose() -> void:
	if not viewmodel_rig:
		return
	var dt : float = minf(get_process_delta_time(), 0.05)
	var tac_t : float = 1.0 if tac_sprinting else 0.0
	var running : bool = state == "sprinting" and not tac_sprinting and is_on_floor() and moving
	var run_t : float = 1.0 if running else 0.0
	var r := _spring(tac_visual, _tac_visual_v, tac_t, dt)
	tac_visual = r.x; _tac_visual_v = r.y
	r = _spring(run_visual, _run_visual_v, run_t, dt)
	run_visual = r.x; _run_visual_v = r.y
	r = _spring(busy_visual, _busy_visual_v, 1.0 if blocks_firing() else 0.0, dt)
	busy_visual = r.x; _busy_visual_v = r.y
	if absf(tac_visual) < 0.0005 and absf(run_visual) < 0.0005 and absf(busy_visual) < 0.0005 \
			and absf(_tac_visual_v) < 0.001 and absf(_run_visual_v) < 0.001 and absf(_busy_visual_v) < 0.001:
		tac_visual = 0.0; run_visual = 0.0; busy_visual = 0.0
		if viewmodel_rig.transform != Transform3D.IDENTITY:
			viewmodel_rig.transform = Transform3D.IDENTITY
		return
	var pistol := false
	var wd = weapon_manager.weapon_data if weapon_manager and "weapon_data" in weapon_manager else null
	if wd and wd.category == WeaponData.WeaponCategory.PISTOL:
		pistol = true
	var t : float = tac_visual
	var s : float = run_visual
	var pos : Vector3 = (TAC_POSE_POS_PISTOL if pistol else TAC_POSE_POS) * t + (RUN_POSE_POS_PISTOL if pistol else RUN_POSE_POS) * s
	var rot : Vector3 = (TAC_POSE_ROT_PISTOL if pistol else TAC_POSE_ROT) * t + (RUN_POSE_ROT_PISTOL if pistol else RUN_POSE_ROT) * s
	pos += (BUSY_POSE_POS_PISTOL if pistol else BUSY_POSE_POS) * busy_visual
	rot += (BUSY_POSE_ROT_PISTOL if pistol else BUSY_POSE_ROT) * busy_visual
	var pivot : Vector3 = TAC_POSE_PIVOT_PISTOL if pistol else TAC_POSE_PIVOT
	# balanço no ritmo da passada: lateral a meio ciclo, batida vertical a cada passo
	var side : float = sin(_bob_phase * 0.5)
	var step : float = abs(sin(_bob_phase))
	# corrida normal: balanço moderado; corrida tática: a arma quica forte a cada passo (como no Warzone)
	var sw : float = clampf(s, 0.0, 1.2) * 0.7
	var tw : float = clampf(t, 0.0, 1.2)
	pos += Vector3(side * 0.014, -step * 0.012, 0.0) * sw + Vector3(side * 0.022, -step * 0.032, step * 0.012) * tw
	rot += Vector3(step * 3.0, side * 2.5, side * 4.0) * sw + Vector3(step * 7.5, side * 3.5, side * 7.0) * tw
	var basis := Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z)))
	# T = mover(pos) * mover(pivot) * girar * mover(-pivot)
	viewmodel_rig.transform = Transform3D(basis, pos + pivot - basis * pivot)

# ── POSTURA NO CORPO: HITBOXES E MODELO EM 3ª PESSOA (local e remoto) ─────────
# Hitboxes seguem a postura e a inclinação (balas e bots acertam onde o jogador realmente está).
# Deitado, o corpo fica atrás da câmera (a câmera é a cabeça). Frente do jogador = -Z.
const HB_STAND  := {"head": Vector3(0, 1.6, 0),     "chest": Vector3(0, 1.05, 0),   "legs": Vector3(0, 0.35, 0),
		"chest_size": Vector3(0.5, 0.7, 0.4), "legs_size": Vector3(0.5, 0.7, 0.4)}
const HB_CROUCH := {"head": Vector3(0, 1.2, -0.05), "chest": Vector3(0, 0.8, 0),    "legs": Vector3(0, 0.3, 0.02),
		"chest_size": Vector3(0.5, 0.55, 0.45), "legs_size": Vector3(0.5, 0.6, 0.55)}
const HB_PRONE  := {"head": Vector3(0, 0.3, -0.1),  "chest": Vector3(0, 0.22, 0.45), "legs": Vector3(0, 0.15, 1.2),
		"chest_size": Vector3(0.5, 0.35, 0.75), "legs_size": Vector3(0.45, 0.3, 0.8)}
const SHADOW_CROUCH_DROP := 0.42
const SHADOW_LEAN_DEG    := 12.0

func _hb_mix(key: String) -> Vector3:
	var st : float = clampf(1.0 - _vis_crouch - _vis_prone, 0.0, 1.0)
	return (HB_STAND[key] as Vector3) * st + (HB_CROUCH[key] as Vector3) * _vis_crouch + (HB_PRONE[key] as Vector3) * _vis_prone

func _update_stance_body(delta: float) -> void:
	var sid : int = stance_sync
	var k : float = clampf(delta * 9.0, 0.0, 1.0)
	_vis_crouch = lerpf(_vis_crouch, 1.0 if sid == 1 else 0.0, k)
	_vis_prone = lerpf(_vis_prone, 1.0 if sid == 2 else 0.0, k)
	_vis_lean = lerpf(_vis_lean, lean_sync, k)
	# Hitboxes
	var lean_x : float = _vis_lean * lean_offset
	var hb := get_node_or_null("Hitbox_Head")
	if hb and hb.get_child_count() > 0:
		(hb.get_child(0) as Node3D).position = _hb_mix("head") + Vector3(lean_x, -absf(_vis_lean) * 0.05, 0)
	var hc := get_node_or_null("Hitbox_Chest")
	if hc and hc.get_child_count() > 0:
		var cc := hc.get_child(0) as CollisionShape3D
		cc.position = _hb_mix("chest") + Vector3(lean_x * 0.45, 0, 0)
		if cc.shape is BoxShape3D:
			(cc.shape as BoxShape3D).size = _hb_mix("chest_size")
	var hl := get_node_or_null("Hitbox_Legs")
	if hl and hl.get_child_count() > 0:
		var cl := hl.get_child(0) as CollisionShape3D
		cl.position = _hb_mix("legs")
		if cl.shape is BoxShape3D:
			(cl.shape as BoxShape3D).size = _hb_mix("legs_size")
	# Modelo em 3ª pessoa (outros jogadores veem; o local projeta a sombra)
	if not shadow_soldier or not is_instance_valid(shadow_soldier):
		return
	if not _shadow_base_ready:
		_shadow_base_xf = shadow_soldier.transform
		_shadow_base_ready = true
	var xf : Transform3D = _shadow_base_xf
	xf.origin.y -= SHADOW_CROUCH_DROP * _vis_crouch
	# deitado de bruços: gira -90° no X (cabeça para a frente), corpo para trás da câmera
	var prone_xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5 * _vis_prone), Vector3(0, 0.12, 1.65) * _vis_prone)
	xf = prone_xf * xf
	# inclinação: o tronco tomba em volta do quadril
	var pivot := Vector3(0, 1.0, 0)
	var lean_b := Basis(Vector3.BACK, -deg_to_rad(SHADOW_LEAN_DEG) * _vis_lean)
	xf = Transform3D(lean_b, pivot - lean_b * pivot) * xf
	shadow_soldier.transform = xf
	_update_stance_legs()

## Agachado: joelhos dobram no modelo em 3ª pessoa (roda depois da animação)
func _update_stance_legs() -> void:
	if not _stance_legs or not is_instance_valid(_stance_legs):
		var sk := shadow_soldier.find_child("Skeleton3D", true, false) as Skeleton3D
		if not sk:
			return
		_stance_legs = StanceLegModifier.new()
		_stance_legs.name = "StanceLegs"
		sk.add_child(_stance_legs)
		_stance_legs.setup(sk)
	_stance_legs.crouch = _vis_crouch * (1.0 - _vis_prone)
	_stance_legs.active = _stance_legs.crouch > 0.01

class StanceLegModifier extends SkeletonModifier3D:
	const HIP_DEG := 80.0     # coxa para a frente
	const KNEE_DEG := 105.0   # joelho dobrado
	const HIP_SIGN := 1.0
	const KNEE_SIGN := -1.0
	var crouch := 0.0
	var ups : Array[int] = []
	var knees : Array[int] = []

	func setup(sk: Skeleton3D) -> void:
		for i in sk.get_bone_count():
			var n := sk.get_bone_name(i)
			if n.contains("UpLeg"):
				ups.append(i)
			elif n.contains("Leg") and not n.contains("UpLeg") and (n.contains("LeftLeg") or n.contains("RightLeg")):
				knees.append(i)

	func _process_modification_with_delta(_delta: float) -> void:
		_apply()

	func _process_modification() -> void:
		_apply()

	func _apply() -> void:
		var sk := get_skeleton()
		if not sk or crouch <= 0.001:
			return
		for i in ups:
			sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i) * Quaternion(Vector3.RIGHT, HIP_SIGN * deg_to_rad(HIP_DEG) * crouch))
		for i in knees:
			sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i) * Quaternion(Vector3.RIGHT, KNEE_SIGN * deg_to_rad(KNEE_DEG) * crouch))

func _speed_multiplier() -> float:
	var m := 1.0
	var wd = weapon_manager.weapon_data if weapon_manager and "weapon_data" in weapon_manager else null
	if wd and "move_speed_mult" in wd:
		m *= float(wd.move_speed_mult)
	var ads := clampf(float(ads_amount), 0.0, 1.0) if "ads_amount" in self else 0.0
	if ads > 0.0:
		var ads_mult: float = PlayerConstants.ADS_SPEED_MULT * (float(wd.ads_move_mult) if wd and "ads_move_mult" in wd else 1.0)
		m *= lerpf(1.0, minf(ads_mult, 1.0), ads)
	return m
