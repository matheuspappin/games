# =============================================================================
# enemy_ai.gd
# IA Tática estilo Call of Duty (MW3 / Black Ops 1 & BO3)
# Suporta:
# - Combate inteligente estilo CoD: rajadas de 3-5 tiros, pausas táticas e strafe
# - Checagem estrita de Linha de Fogo (Line of Fire): NUNCA atira através de paredes
# - Suporte nativo a esqueletos ValveBiped (CS) e Mixamo: braços flexionados (sem A-Pose)
# - Anexação da arma diretamente no osso ValveBiped.weapon_bone_RHand com escala compensada
# - Percepção com cone de visão real, audição de passos e perseguição tática
# =============================================================================
class_name EnemyAI
extends CharacterBody3D

const SkinRegistry = preload("res://scripts/characters/skin_registry.gd")
const CharacterRetargeter = preload("res://scripts/characters/character_retargeter.gd")

signal enemy_spotted_player(player: CharacterBody3D)
signal enemy_lost_player
signal enemy_died(enemy: EnemyAI)

# ── IDENTIFICAÇÃO E EQUIPES ──────────────────────────────────────────────────
@export var team                 : int    = 1  # 0 = Alpha (CT), 1 = Bravo (T)
@export var bot_id               : int    = 0  # ID estável persistente (ex: 101, 201)
@export var bot_name             : String = ""
@export var bot_display_name     : String = "SoldierBot"

func get_team() -> int:
	return team

# ── ARQUÉTIPOS E PERSONALIDADES (FASE 2) ──────────────────────────────────────
enum BotArchetype { BALANCED, RUSHER, FLANKER, ANCHOR }
@export var archetype            : BotArchetype = BotArchetype.BALANCED
@export var assigned_lane        : int = 1  # 0=Flank Left, 1=Street Center, 2=Houses, 3=Flank Right
@export var lateral_sign         : float = 0.0 # -1.0 (ombro esquerdo da lane) ou +1.0 (ombro direito da lane)
var lateral_lane_offset          : float = 0.0
var _lane_rotation_count         : int = 0


# ── STATS & DIFICULDADE ──────────────────────────────────────────────────────
@export_group("Stats")
@export var max_health           : int   = 100
@export var move_speed           : float = 3.8
@export var sprint_speed         : float = 5.8
@export var rotation_speed       : float = 8.5
@export var reaction_time        : float = 0.22
@export var fire_rate_rpm        : float = 500.0
@export var damage_per_shot      : int   = 26
@export var accuracy_hip         : float = 0.040
@export var accuracy_aim         : float = 0.018
@export var aim_tolerance_angle_deg : float = 7.0
@export var headshot_chance      : float = 0.15
@export var close_sense_range    : float = 4.5
@export var current_difficulty   : int   = 2

# ── PERCEPÇÃO ─────────────────────────────────────────────────────────────────
@export_group("Percepção")
@export var sight_range          : float = 38.0
@export var sight_fov_degrees    : float = 125.0
@export var hearing_range        : float = 20.0
@export var lose_sight_delay     : float = 3.5

# ── NÓS INTERNOS ──────────────────────────────────────────────────────────────
@export_group("Nós")
@export var nav_agent            : NavigationAgent3D
@export var eyes_pivot           : Node3D
@export var gun_muzzle           : Node3D
@export var gun_audio            : AudioStreamPlayer3D
@export_group("Customização")
@export var skin_id               : String = ""

# ── NAVEGAÇÃO TÁTICA TOPOLÓGICA (A* + BIGODES + ANTI-STUCK) ───────────────────
const TacticalNavGraphScript = preload("res://scripts/ai/tactical_nav_graph.gd")
var _nav_graph                        = null
var _current_path      : PackedVector3Array = PackedVector3Array()
var _path_idx          : int = 0
var _current_dest      : Vector3 = Vector3(9999, 9999, 9999)
var _repath_timer      : float = 0.0

# Sistema Anti-Stuck (Recuperação Inteligente de Paredes/Quinas)
var _stuck_sample_pos  : Vector3 = Vector3.ZERO
var _stuck_timer       : float = 0.0
var _stuck_frames      : int = 0
var _is_recovering     : bool = false
var _recovery_timer    : float = 0.0
var _recovery_dir      : Vector3 = Vector3.ZERO
var _wall_contact_timer: float = 0.0

# ── ESTADO ───────────────────────────────────────────────────────────────────
enum AIState { PATROL, SUSPICIOUS, ALERT, COMBAT, SEARCHING, RETREAT_HEAL, DEAD }

var ai_state           : AIState = AIState.PATROL
var current_health     : int
var target_combatant   : CharacterBody3D = null

var last_attacker      : Node = null
var last_attacker_team : int = -1

var _lose_sight_timer  : float = 0.0
var _reaction_timer    : float = 0.0
var _fire_cooldown     : float = 0.0
var _patrol_timer      : float = 0.0
var _patrol_target     : Vector3 = Vector3.ZERO
var _last_known_pos    : Vector3 = Vector3.ZERO
var _search_timer      : float = 0.0
var _fire_interval     : float
var _nameplate         : Label3D = null

# Sistema de Disparo em Rajadas (Burst Fire estilo CoD)
var _burst_shots_fired : int = 0
var _burst_max_shots   : int = 4
var _burst_base_shots  : int = 4
var _burst_pause_base  : float = 0.20
var _burst_pause_timer : float = 0.0

# Sistema de Estabilidade Tática e Histerese (Fase 1: Prevenção de Oscilação/Ping-Pong)
var _lost_lof_timer    : float = 0.0
var _combat_retreating : bool = false
var _strafe_timer      : float = 0.0
var _strafe_dir_sign   : float = 1.0
var _last_patrol_wp    : Vector3 = Vector3(9999, 9999, 9999)

# Sistema de Micro-Comportamentos Humanos (Fase 3: Saltos, Agachamento e Fuga Tática)
var _jump_cooldown        : float = 0.0
var _crouch_timer         : float = 0.0
var _is_fleeing_to_heal   : bool = false
var _flee_timer           : float = 0.0
var _flee_cover_dest      : Vector3 = Vector3.ZERO

# Sistema de Imprevisibilidade e Dispersão Humana (Fase 3: Pausas Táticas e Repulsão Boids)
var _tactical_pause_timer : float = 0.0
var _tactical_look_target : Vector3 = Vector3.ZERO
var _recent_patrol_wps    : Array[Vector3] = []
var _departure_delay      : float = 0.0


# Animação Mixamo & Procedural
@export var use_mixamo_model     : bool = true
var _anim_player                 : AnimationPlayer = null
var _move_direction              : String = "idle"  # idle, forward, backward, strafe_left, strafe_right
var _skeleton                    : Skeleton3D = null
var _bone_r_arm        : int = -1
var _bone_r_forearm    : int = -1
var _bone_l_arm        : int = -1
var _bone_l_forearm    : int = -1
var _bone_spine        : int = -1
var _bone_head         : int = -1
var _is_overriding_bones : bool = false
var _bone_l_thigh      : int = -1
var _bone_l_calf       : int = -1
var _bone_r_thigh      : int = -1
var _bone_r_calf       : int = -1
var _is_valve_rig      : bool = false

var _rest_l_thigh      : Quaternion = Quaternion.IDENTITY
var _rest_l_calf       : Quaternion = Quaternion.IDENTITY
var _rest_r_thigh      : Quaternion = Quaternion.IDENTITY
var _rest_r_calf       : Quaternion = Quaternion.IDENTITY

var _cur_l_thigh_q     : Quaternion = Quaternion.IDENTITY
var _cur_l_calf_q      : Quaternion = Quaternion.IDENTITY
var _cur_r_thigh_q     : Quaternion = Quaternion.IDENTITY
var _cur_r_calf_q      : Quaternion = Quaternion.IDENTITY

var _anim_clock        : float = 0.0
var _stride_phase      : float = 0.0
var is_crouching       : bool = false

# Cache de referências e otimização de percepção (SUB-7)
var _cached_gun_holder : Node3D = null
var _cached_bot_rifle  : Node3D = null
var _perception_offset : int = 0

# ── INICIALIZAÇÃO ────────────────────────────────────────────────────────────
func _ready() -> void:
	current_health = max_health
	_fire_interval = 60.0 / fire_rate_rpm
	add_to_group("enemies")
	add_to_group("combatants")

	if not nav_agent:
		nav_agent = get_node_or_null("NavigationAgent3D")
	if not eyes_pivot:
		eyes_pivot = get_node_or_null("EyesPivot")
	if not gun_muzzle:
		gun_muzzle = get_node_or_null("GunMuzzle")
	if not gun_audio:
		gun_audio = get_node_or_null("GunAudio")

	var health_comp = get_node_or_null("HealthComponent") as HealthComponent
	if health_comp:
		health_comp.damage_taken.connect(_on_health_damage_taken)
		health_comp.died.connect(func(dir, bone): self._die(dir, bone))
		health_comp.activate_spawn_protection(1.0)

	_setup_nameplate()
	_apply_bot_skin()
	_setup_combat_posture()
	_cached_gun_holder = find_child("GunHolder", true, false)
	_cached_bot_rifle = find_child("BotRifle3D", true, false)
	_perception_offset = abs(get_instance_id()) % 3

	# Configurações físicas de locomoção e escadas (Step-Clamping & Suavidade)
	collision_layer = 4
	collision_mask = 7  # 1 (Cenário) | 2 (Hitboxes/Player) | 4 (SoldierBots)
	safe_margin = 0.08
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	wall_min_slide_angle = deg_to_rad(15.0)
	floor_snap_length = 0.35
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(50.0)
	floor_stop_on_slope = true

	var current_scene = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_parent()
	_nav_graph = TacticalNavGraphScript.new(current_scene)
	_stuck_sample_pos = global_position
	if lateral_sign == 0.0:
		lateral_sign = 1.0 if (bot_id % 2 == 0) else -1.0
	lateral_lane_offset = lateral_sign * 1.35
	_set_random_patrol_target()

func apply_difficulty(diff: int) -> void:
	current_difficulty = clampi(diff, 0, 4)
	match current_difficulty:
		0:  # RECRUTA (Muito Fácil / Aprendizado)
			rotation_speed = 4.0          # ~230 deg/s (giro suave)
			reaction_time = 0.48          # Reação suave, dá tempo do player reagir
			aim_tolerance_angle_deg = 14.0 # Alinhamento menos rigoroso
			damage_per_shot = 18
			accuracy_hip = 0.090
			accuracy_aim = 0.055          # Erra vários tiros em média/longa distância
			fire_rate_rpm = 380.0
			move_speed = 3.0
			sprint_speed = 4.5
			sight_fov_degrees = 90.0      # Visão em túnel
			close_sense_range = 0.0       # Sem sexto sentido de costas
			headshot_chance = 0.00
			_burst_base_shots = 3
			_burst_max_shots = 3
			_burst_pause_base = 0.42
		1:  # INICIANTE (Fácil / Casual)
			rotation_speed = 6.0          # ~345 deg/s
			reaction_time = 0.34
			aim_tolerance_angle_deg = 10.0
			damage_per_shot = 22
			accuracy_hip = 0.065
			accuracy_aim = 0.035
			fire_rate_rpm = 430.0
			move_speed = 3.4
			sprint_speed = 5.0
			sight_fov_degrees = 110.0
			close_sense_range = 2.5
			headshot_chance = 0.05
			_burst_base_shots = 3
			_burst_max_shots = 4
			_burst_pause_base = 0.30
		2:  # REGULAR (Normal / Balanceado estilo CoD)
			rotation_speed = 8.5          # ~485 deg/s
			reaction_time = 0.22
			aim_tolerance_angle_deg = 7.0
			damage_per_shot = 26
			accuracy_hip = 0.040
			accuracy_aim = 0.018
			fire_rate_rpm = 500.0
			move_speed = 3.8
			sprint_speed = 5.8
			sight_fov_degrees = 125.0
			close_sense_range = 4.5
			headshot_chance = 0.15
			_burst_base_shots = 4
			_burst_max_shots = 4
			_burst_pause_base = 0.20
		3:  # VETERANO (Difícil / Tático)
			rotation_speed = 11.5         # ~660 deg/s
			reaction_time = 0.13
			aim_tolerance_angle_deg = 4.5
			damage_per_shot = 30
			accuracy_hip = 0.025
			accuracy_aim = 0.010
			fire_rate_rpm = 570.0
			move_speed = 4.2
			sprint_speed = 6.2
			sight_fov_degrees = 140.0
			close_sense_range = 6.5
			headshot_chance = 0.30
			_burst_base_shots = 4
			_burst_max_shots = 5
			_burst_pause_base = 0.12
		4:  # ESPECIALISTA (Hardcore / Modo Torneio)
			rotation_speed = 15.0         # ~860 deg/s (flick instantâneo)
			reaction_time = 0.07
			aim_tolerance_angle_deg = 3.0
			damage_per_shot = 34
			accuracy_hip = 0.015
			accuracy_aim = 0.006
			fire_rate_rpm = 640.0
			move_speed = 4.5
			sprint_speed = 6.6
			sight_fov_degrees = 160.0
			close_sense_range = 8.0
			headshot_chance = 0.50
			_burst_base_shots = 5
			_burst_max_shots = 6
			_burst_pause_base = 0.08
	_fire_interval = 60.0 / fire_rate_rpm

func apply_archetype(arch: BotArchetype, forced_lane: int = -1) -> void:
	archetype = arch
	if forced_lane >= 0:
		assigned_lane = forced_lane
	else:
		match archetype:
			BotArchetype.RUSHER:
				# Agressivo (SMG/Shotgun style): força avanços pelo centro (1) ou flancos rápidos (0 ou 3)
				var r = randf()
				assigned_lane = 1 if r < 0.50 else (3 if r < 0.75 else 0)
			BotArchetype.FLANKER:
				# Furtivo (Infiltrador): divide 50/50 entre Flanco Esquerdo (0) e Flanco Direito (3)!
				assigned_lane = 0 if randf() < 0.50 else 3
			BotArchetype.ANCHOR:
				# Tático / Defensor: controla Centro (1), Flanco Direito (3) ou Casas (2)
				var r = randf()
				assigned_lane = 1 if r < 0.40 else (3 if r < 0.70 else 2)
			BotArchetype.BALANCED:
				var r = randf()
				assigned_lane = 0 if r < 0.35 else (3 if r < 0.70 else (1 if r < 0.90 else 2))

	match archetype:
		BotArchetype.RUSHER:
			move_speed *= 1.12
			sprint_speed *= 1.15
			reaction_time *= 0.80
			_burst_max_shots = randi_range(4, 6)
		BotArchetype.FLANKER:
			accuracy_hip *= 0.75
			accuracy_aim *= 0.75
			_burst_max_shots = 3
		BotArchetype.ANCHOR:
			move_speed *= 0.95
			reaction_time *= 1.10
			accuracy_hip *= 0.85
			_burst_max_shots = randi_range(3, 4)
		BotArchetype.BALANCED:
			pass


func _setup_nameplate() -> void:
	_nameplate = get_node_or_null("NameplateLabel") as Label3D
	if not _nameplate:
		_nameplate = Label3D.new()
		_nameplate.name = "NameplateLabel"
		_nameplate.position = Vector3(0, 2.25, 0)
		_nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_nameplate.font_size = 22
		_nameplate.outline_size = 4
		_nameplate.no_depth_test = false
		add_child(_nameplate)

	var team_tag = "[ALIADO] " if team == 0 else "[INIMIGO] "
	_nameplate.text = team_tag + bot_display_name
	if team == 0:  # Alpha = CT (Azul ciano tático)
		_nameplate.modulate = Color(0.25, 0.85, 1.0, 0.95)
	else:  # Bravo = T (Laranja/Vermelho tático)
		_nameplate.modulate = Color(1.0, 0.35, 0.20, 0.95)

func _apply_bot_skin() -> void:
	var vis_root = get_node_or_null("VisualRoot")
	if not vis_root:
		return

	var target_skin = skin_id
	if target_skin.is_empty():
		var ct_skins = ["ct_urban", "ct_sas", "ct_gsg9", "ct_gign"]
		var t_skins = ["t_phoenix", "t_leet", "t_guerilla", "t_arctic"]
		var pool = ct_skins if team == 0 else t_skins
		target_skin = pool[abs(bot_id) % pool.size()]

	var skin_inst = SkinRegistry.instantiate_skin(target_skin)
	if skin_inst:
		var soldier = vis_root.get_node_or_null("SoldierModel")
		if soldier:
			soldier.visible = false
			soldier.process_mode = Node.PROCESS_MODE_DISABLED

		skin_inst.name = "BotSkinModel"
		vis_root.add_child(skin_inst)
		skin_inst.visible = true
	else:
		var soldier = vis_root.get_node_or_null("SoldierModel")
		if soldier:
			var team_color = Color(0.20, 0.50, 0.95, 1.0) if team == 0 else Color(0.95, 0.40, 0.15, 1.0)
			var joints = soldier.find_child("Beta_Joints", true, false) as MeshInstance3D
			if joints:
				var mat = StandardMaterial3D.new()
				mat.albedo_color = team_color
				mat.roughness = 0.35
				mat.metallic = 0.45
				joints.material_override = mat

func _find_character_skeleton() -> Skeleton3D:
	var vis_root = get_node_or_null("VisualRoot")
	if not vis_root:
		return null

	for child_name in ["BotSkinModel", "SoldierModel"]:
		var model_node = vis_root.get_node_or_null(child_name)
		if model_node:
			var skel = model_node.find_child("Skeleton3D", true, false) as Skeleton3D
			if skel:
				return skel

	for child in vis_root.get_children():
		if child.name != "GunHolder" and child.name != "BotRifle3D":
			var skel = child.find_child("Skeleton3D", true, false) as Skeleton3D
			if skel:
				return skel

	return null

func _find_character_anim_player() -> AnimationPlayer:
	var vis_root = get_node_or_null("VisualRoot")
	if not vis_root:
		return null
	var model = vis_root.get_node_or_null("BotSkinModel")
	if not model:
		model = vis_root.get_node_or_null("SoldierModel")
	if model:
		var ap = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			return ap
	for child in vis_root.get_children():
		if child.name != "GunHolder" and child.name != "BotRifle3D" and not ("Rifle" in child.name):
			var ap = child.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if ap:
				return ap
	return null

func _setup_mixamo_animations() -> void:
	if not _anim_player:
		return
	for anim_name in ["idle", "walk", "run", "walk_backward", "run_backward", "strafe_left", "strafe_right"]:
		if _anim_player.has_animation(anim_name):
			_anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	if _anim_player.has_animation("idle"):
		_anim_player.play("idle")

# ── POSTURA TÁTICA E EMPUNHADURA DE ARMA ──────────────────────────────────────
func _setup_combat_posture() -> void:
	_skeleton = _find_character_skeleton()
	_is_valve_rig = false
	if _skeleton:
		for i in range(_skeleton.get_bone_count()):
			if _skeleton.get_bone_name(i).begins_with("ValveBiped"):
				_is_valve_rig = true
				break

	# SEMPRE buscar AnimationPlayer — priorizar animações Mixamo sobre procedural
	_anim_player = _find_character_anim_player()

	if _skeleton:
		_bone_spine = _find_bone_fuzzy(_skeleton, ["mixamorig_Spine", "ValveBiped.Bip01_Spine", "Spine"])
		_bone_r_arm = _find_bone_fuzzy(_skeleton, ["mixamorig_RightArm", "ValveBiped.Bip01_R_UpperArm", "RightArm"])
		_bone_r_forearm = _find_bone_fuzzy(_skeleton, ["mixamorig_RightForeArm", "ValveBiped.Bip01_R_Forearm", "RightForeArm"])
		_bone_l_arm = _find_bone_fuzzy(_skeleton, ["mixamorig_LeftArm", "ValveBiped.Bip01_L_UpperArm", "LeftArm"])
		_bone_l_forearm = _find_bone_fuzzy(_skeleton, ["mixamorig_LeftForeArm", "ValveBiped.Bip01_L_Forearm", "LeftForeArm"])
		_bone_head = _find_bone_fuzzy(_skeleton, ["mixamorig_Head", "ValveBiped.Bip01_Head1", "Head"])

		if not _is_valve_rig and _anim_player and _anim_player.get_animation_list().size() > 1:
			if _skeleton.skeleton_updated.is_connected(_apply_tactical_upper_body_override):
				_skeleton.skeleton_updated.disconnect(_apply_tactical_upper_body_override)
		elif not _skeleton.skeleton_updated.is_connected(_apply_tactical_upper_body_override):
			_skeleton.skeleton_updated.connect(_apply_tactical_upper_body_override)

	if _anim_player and _anim_player.get_animation_list().size() > 1:
		if _skeleton and _skeleton.skeleton_updated.is_connected(_apply_tactical_upper_body_override):
			_skeleton.skeleton_updated.disconnect(_apply_tactical_upper_body_override)
		_setup_mixamo_animations()
	else:
		_anim_player = null
		if _skeleton and not _skeleton.skeleton_updated.is_connected(_apply_tactical_upper_body_override):
			_skeleton.skeleton_updated.connect(_apply_tactical_upper_body_override)
		_apply_arm_poses()
		_setup_leg_bones()

	_setup_weapon_attachment()

func _find_bone_fuzzy(skel: Skeleton3D, keywords: Array) -> int:
	if not skel:
		return -1
	for kw in keywords:
		var b = skel.find_bone(kw)
		if b >= 0:
			return b
		for i in range(skel.get_bone_count()):
			var bname = skel.get_bone_name(i)
			if kw in bname:
				return i
	return -1

func _apply_arm_poses() -> void:
	if not _skeleton:
		return

	var r_upper = _find_bone_fuzzy(_skeleton, ["ValveBiped.Bip01_R_UpperArm", "R_UpperArm", "RightArm", "UpperArm.R", "mixamorig_RightArm"])
	var r_forearm = _find_bone_fuzzy(_skeleton, ["ValveBiped.Bip01_R_Forearm", "R_Forearm", "RightForeArm", "ForeArm.R", "mixamorig_RightForeArm"])
	var r_hand = _find_bone_fuzzy(_skeleton, ["ValveBiped.Bip01_R_Hand", "R_Hand", "RightHand", "Hand.R", "mixamorig_RightHand"])

	var l_upper = _find_bone_fuzzy(_skeleton, ["ValveBiped.Bip01_L_UpperArm", "L_UpperArm", "LeftArm", "UpperArm.L", "mixamorig_LeftArm"])
	var l_forearm = _find_bone_fuzzy(_skeleton, ["ValveBiped.Bip01_L_Forearm", "L_Forearm", "LeftForeArm", "ForeArm.L", "mixamorig_LeftForeArm"])
	var l_hand = _find_bone_fuzzy(_skeleton, ["ValveBiped.Bip01_L_Hand", "L_Hand", "LeftHand", "Hand.L", "mixamorig_LeftHand"])

	var is_valve = false
	if r_upper >= 0 and _skeleton.get_bone_name(r_upper).begins_with("ValveBiped"):
		is_valve = true
	elif l_upper >= 0 and _skeleton.get_bone_name(l_upper).begins_with("ValveBiped"):
		is_valve = true

	if is_valve:
		# Posição tática idêntica ao Counter-Strike:
		# Mão direita segura o gatilho/pistol grip com a coronha no ombro direito
		if r_upper >= 0:
			var rest = _skeleton.get_bone_rest(r_upper).basis.get_rotation_quaternion()
			var d_ru = Quaternion(Vector3.FORWARD, deg_to_rad(48.0)) * Quaternion(Vector3.UP, deg_to_rad(-16.0))
			_skeleton.set_bone_pose_rotation(r_upper, rest * d_ru)

		if r_forearm >= 0:
			var rest = _skeleton.get_bone_rest(r_forearm).basis.get_rotation_quaternion()
			var d_rf = Quaternion(Vector3.FORWARD, deg_to_rad(62.0))
			_skeleton.set_bone_pose_rotation(r_forearm, rest * d_rf)

		if r_hand >= 0:
			var rest = _skeleton.get_bone_rest(r_hand).basis.get_rotation_quaternion()
			var d_rh = Quaternion(Vector3.RIGHT, deg_to_rad(-18.0)) * Quaternion(Vector3.UP, deg_to_rad(12.0))
			_skeleton.set_bone_pose_rotation(r_hand, rest * d_rh)

		# Mão esquerda estendida segurando firmemente o guarda-mão (handguard) à frente do carregador
		if l_upper >= 0:
			var rest = _skeleton.get_bone_rest(l_upper).basis.get_rotation_quaternion()
			var d_lu = Quaternion(Vector3.FORWARD, deg_to_rad(85.0)) * Quaternion(Vector3.UP, deg_to_rad(28.0)) * Quaternion(Vector3.RIGHT, deg_to_rad(12.0))
			_skeleton.set_bone_pose_rotation(l_upper, rest * d_lu)

		if l_forearm >= 0:
			var rest = _skeleton.get_bone_rest(l_forearm).basis.get_rotation_quaternion()
			var d_lf = Quaternion(Vector3.FORWARD, deg_to_rad(8.0)) * Quaternion(Vector3.RIGHT, deg_to_rad(22.0))
			_skeleton.set_bone_pose_rotation(l_forearm, rest * d_lf)

		if l_hand >= 0:
			var rest = _skeleton.get_bone_rest(l_hand).basis.get_rotation_quaternion()
			var d_lh = Quaternion(Vector3.FORWARD, deg_to_rad(25.0)) * Quaternion(Vector3.UP, deg_to_rad(-25.0)) * Quaternion(Vector3.RIGHT, deg_to_rad(20.0))
			_skeleton.set_bone_pose_rotation(l_hand, rest * d_lh)

		# Curvatura natural dos dedos envolvendo a empunhadura e o guarda-mão
		for i in range(_skeleton.get_bone_count()):
			var bname = _skeleton.get_bone_name(i)
			if "R_Finger" in bname:
				var rest_f = _skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
				_skeleton.set_bone_pose_rotation(i, rest_f * Quaternion(Vector3.FORWARD, deg_to_rad(30.0)))
			elif "L_Finger" in bname:
				var rest_f = _skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
				_skeleton.set_bone_pose_rotation(i, rest_f * Quaternion(Vector3.FORWARD, deg_to_rad(40.0)))
	else:
		# Posição tática CS: low-ready (arma no peito/costela, coronha sob axila)
		# Braço direito: ombro abaixado ~45°, antebraço dobrado segurando pistol grip
		if r_upper >= 0:
			var rest = _skeleton.get_bone_rest(r_upper).basis.get_rotation_quaternion()
			var d_ru = Quaternion(Vector3.BACK, deg_to_rad(42.0)) * Quaternion(Vector3.UP, deg_to_rad(-20.0))
			_skeleton.set_bone_pose_rotation(r_upper, rest * d_ru)

		if r_forearm >= 0:
			var rest = _skeleton.get_bone_rest(r_forearm).basis.get_rotation_quaternion()
			var d_rf = Quaternion(Vector3.UP, deg_to_rad(-55.0)) * Quaternion(Vector3.BACK, deg_to_rad(10.0))
			_skeleton.set_bone_pose_rotation(r_forearm, rest * d_rf)

		# Braço esquerdo: estendido segurando o handguard na frente, mais baixo
		if l_upper >= 0:
			var rest = _skeleton.get_bone_rest(l_upper).basis.get_rotation_quaternion()
			var d_lu = Quaternion(Vector3.FORWARD, deg_to_rad(42.0)) * Quaternion(Vector3.UP, deg_to_rad(28.0))
			_skeleton.set_bone_pose_rotation(l_upper, rest * d_lu)

		if l_forearm >= 0:
			var rest = _skeleton.get_bone_rest(l_forearm).basis.get_rotation_quaternion()
			var d_lf = Quaternion(Vector3.UP, deg_to_rad(38.0)) * Quaternion(Vector3.FORWARD, deg_to_rad(10.0))
			_skeleton.set_bone_pose_rotation(l_forearm, rest * d_lf)

func _apply_tactical_upper_body_override() -> void:
	# Desativado: animações nativas do Mixamo (rifle aiming idle, run, etc.) já possuem a postura correta com as duas mãos na arma
	return

func _setup_leg_bones() -> void:
	if not _skeleton:
		return

	_bone_l_thigh = _find_bone_fuzzy(_skeleton, ["ValveBiped.Bip01_L_Thigh", "L_Thigh", "LeftUpLeg", "Thigh.L", "mixamorig_LeftUpLeg"])
	_bone_l_calf  = _find_bone_fuzzy(_skeleton, ["ValveBiped.Bip01_L_Calf", "L_Calf", "LeftLeg", "Calf.L", "mixamorig_LeftLeg"])
	_bone_r_thigh = _find_bone_fuzzy(_skeleton, ["ValveBiped.Bip01_R_Thigh", "R_Thigh", "RightUpLeg", "Thigh.R", "mixamorig_RightUpLeg"])
	_bone_r_calf  = _find_bone_fuzzy(_skeleton, ["ValveBiped.Bip01_R_Calf", "R_Calf", "RightLeg", "Calf.R", "mixamorig_RightLeg"])

	if _bone_l_thigh >= 0:
		_rest_l_thigh = _skeleton.get_bone_rest(_bone_l_thigh).basis.get_rotation_quaternion()
		_cur_l_thigh_q = _rest_l_thigh
	if _bone_l_calf >= 0:
		_rest_l_calf = _skeleton.get_bone_rest(_bone_l_calf).basis.get_rotation_quaternion()
		_cur_l_calf_q = _rest_l_calf
	if _bone_r_thigh >= 0:
		_rest_r_thigh = _skeleton.get_bone_rest(_bone_r_thigh).basis.get_rotation_quaternion()
		_cur_r_thigh_q = _rest_r_thigh
	if _bone_r_calf >= 0:
		_rest_r_calf = _skeleton.get_bone_rest(_bone_r_calf).basis.get_rotation_quaternion()
		_cur_r_calf_q = _rest_r_calf

	_is_valve_rig = false
	if _bone_l_thigh >= 0 and _skeleton.get_bone_name(_bone_l_thigh).begins_with("ValveBiped"):
		_is_valve_rig = true
	elif _skeleton.find_bone("ValveBiped.Bip01_Pelvis") >= 0 or _skeleton.find_bone("ValveBiped.Bip01_Spine") >= 0:
		_is_valve_rig = true

	_apply_initial_leg_pose()

func _apply_initial_leg_pose() -> void:
	if not _skeleton:
		return
	var l_thigh_deg = 10.0
	var l_calf_deg = -16.0
	var r_thigh_deg = -4.0
	var r_calf_deg = -10.0

	if _is_valve_rig:
		_cur_l_thigh_q = _rest_l_thigh * Quaternion(Vector3.FORWARD, deg_to_rad(l_thigh_deg))
		_cur_l_calf_q  = _rest_l_calf  * Quaternion(Vector3.FORWARD, deg_to_rad(l_calf_deg))
		_cur_r_thigh_q = _rest_r_thigh * Quaternion(Vector3.FORWARD, deg_to_rad(r_thigh_deg))
		_cur_r_calf_q  = _rest_r_calf  * Quaternion(Vector3.FORWARD, deg_to_rad(r_calf_deg))
	else:
		_cur_l_thigh_q = _rest_l_thigh * Quaternion(Vector3.RIGHT, deg_to_rad(-l_thigh_deg))
		_cur_l_calf_q  = _rest_l_calf  * Quaternion(Vector3.RIGHT, deg_to_rad(-l_calf_deg))
		_cur_r_thigh_q = _rest_r_thigh * Quaternion(Vector3.RIGHT, deg_to_rad(-r_thigh_deg))
		_cur_r_calf_q  = _rest_r_calf  * Quaternion(Vector3.RIGHT, deg_to_rad(-r_calf_deg))

	if _bone_l_thigh >= 0:
		_skeleton.set_bone_pose_rotation(_bone_l_thigh, _cur_l_thigh_q)
	if _bone_l_calf >= 0:
		_skeleton.set_bone_pose_rotation(_bone_l_calf, _cur_l_calf_q)
	if _bone_r_thigh >= 0:
		_skeleton.set_bone_pose_rotation(_bone_r_thigh, _cur_r_thigh_q)
	if _bone_r_calf >= 0:
		_skeleton.set_bone_pose_rotation(_bone_r_calf, _cur_r_calf_q)

func _setup_weapon_attachment() -> void:
	var vis_root = get_node_or_null("VisualRoot")
	if not vis_root:
		return

	# Se for o esqueleto do Mixamo, anexar diretamente ao osso da mão direita
	if _skeleton:
		var r_hand_idx = _find_bone_fuzzy(_skeleton, ["mixamorig_RightHand", "RightHand"])
		if r_hand_idx >= 0 and not _is_valve_rig:
			var bone_att = _skeleton.get_node_or_null("RightHandAttachment") as BoneAttachment3D
			if not bone_att:
				bone_att = BoneAttachment3D.new()
				bone_att.name = "RightHandAttachment"
				bone_att.bone_name = _skeleton.get_bone_name(r_hand_idx)
				bone_att.bone_idx = r_hand_idx
				_skeleton.add_child(bone_att)
			else:
				bone_att.bone_idx = r_hand_idx

			if _anim_player and _anim_player.has_animation("idle"):
				_anim_player.play("idle")
				_anim_player.seek(0.1, true)
			bone_att.on_skeleton_update()

			var rifle = find_child("BotRifle3D", true, false)
			if not rifle:
				var rifle_scn = load("res://scenes/weapons/bot_rifle_3d.tscn") as PackedScene
				if rifle_scn:
					rifle = rifle_scn.instantiate()

			if rifle:
				if rifle.get_parent() != bone_att:
					var old_p = rifle.get_parent()
					if old_p:
						old_p.remove_child(rifle)
					bone_att.add_child(rifle)

				# Calibração tática de escala e orientação do fuzil
				var is_cs_skin = _skeleton and _skeleton.get_parent() and not ("Armature" in _skeleton.get_parent().name)
				if is_cs_skin:
					rifle.scale = CharacterRetargeter.CS_RIFLE_LOCAL_SCALE
					rifle.position = CharacterRetargeter.CS_RIFLE_LOCAL_POS
					rifle.rotation_degrees = CharacterRetargeter.CS_RIFLE_LOCAL_ROT
				else:
					rifle.scale = CharacterRetargeter.XBOT_RIFLE_LOCAL_SCALE
					rifle.position = CharacterRetargeter.XBOT_RIFLE_LOCAL_POS
					rifle.rotation_degrees = CharacterRetargeter.XBOT_RIFLE_LOCAL_ROT
				rifle.visible = true

			var old_holder = vis_root.get_node_or_null("GunHolder")
			if old_holder:
				old_holder.visible = false
			return

	var gun_holder = vis_root.get_node_or_null("GunHolder")
	if not gun_holder:
		gun_holder = Node3D.new()
		gun_holder.name = "GunHolder"
		vis_root.add_child(gun_holder)

	# Empunhadura tática do Counter-Strike:
	gun_holder.position = Vector3(0.08, 1.18, -0.22)
	gun_holder.rotation_degrees = Vector3(0.0, -3.0, 0.0)
	gun_holder.visible = true

	var rifle = find_child("BotRifle3D", true, false)
	if not rifle:
		var rifle_scn = load("res://scenes/weapons/bot_rifle_3d.tscn") as PackedScene
		if rifle_scn:
			rifle = rifle_scn.instantiate()

	if rifle:
		if rifle.get_parent() != gun_holder:
			var old_p = rifle.get_parent()
			if old_p:
				old_p.remove_child(rifle)
			gun_holder.add_child(rifle)
		rifle.position = Vector3.ZERO
		rifle.rotation = Vector3.ZERO
		rifle.scale = Vector3.ONE
		rifle.visible = true

func _get_movement_direction() -> String:
	## Determina a direção de movimento relativa ao facing do bot
	## Retorna: "idle", "forward", "backward", "strafe_left", "strafe_right"
	var speed_h = Vector2(velocity.x, velocity.z).length()
	if speed_h < 0.3:
		return "idle"

	var facing_dir = -global_transform.basis.z  # Frente do bot
	facing_dir.y = 0.0
	facing_dir = facing_dir.normalized()

	var move_dir = Vector3(velocity.x, 0, velocity.z).normalized()

	# Produto escalar: 1 = frente, -1 = trás
	var dot_forward = facing_dir.dot(move_dir)
	# Produto cruzado vertical para saber esquerda/direita
	var cross_y = facing_dir.cross(move_dir).y

	if dot_forward > 0.5:
		return "forward"
	elif dot_forward < -0.5:
		return "backward"
	elif cross_y > 0.3:
		return "strafe_right"
	elif cross_y < -0.3:
		return "strafe_left"
	else:
		return "forward"

func _update_mixamo_motion(delta: float, speed_h: float) -> void:
	if ai_state == AIState.DEAD:
		if _anim_player.has_animation("die") and _anim_player.current_animation != "die":
			_anim_player.play("die", 0.15)
		return

	# Rajada de tiros em combate
	if _burst_shots_fired > 0 and _anim_player.has_animation("shoot"):
		if _anim_player.current_animation != "shoot":
			_anim_player.play("shoot", 0.08)
		return

	if _anim_player.current_animation == "shoot" and _anim_player.is_playing() and _burst_shots_fired > 0:
		return

	# Pulo / queda no ar
	if not is_on_floor() and abs(velocity.y) > 1.2:
		var j_anim = "jump_forward" if speed_h > 0.5 else "jump_backward"
		if _anim_player.has_animation(j_anim) and _anim_player.current_animation != j_anim:
			_anim_player.play(j_anim, 0.15)
		return

	# Determinar direção de movimento relativa ao facing
	_move_direction = _get_movement_direction()

	# Locomoção direcional completa com todas as animações Mixamo
	match _move_direction:
		"idle":
			if _anim_player.current_animation != "idle":
				_anim_player.play("idle", 0.25)
			_anim_player.speed_scale = 1.0
		"forward":
			if speed_h > 3.8:
				if _anim_player.current_animation != "run":
					_anim_player.play("run", 0.2)
				_anim_player.speed_scale = clampf(speed_h / 5.5, 0.6, 1.5)
			else:
				if _anim_player.current_animation != "walk":
					_anim_player.play("walk", 0.2)
				_anim_player.speed_scale = clampf(speed_h / 1.6, 0.5, 2.0)
		"backward":
			if speed_h > 3.8 and _anim_player.has_animation("run_backward"):
				if _anim_player.current_animation != "run_backward":
					_anim_player.play("run_backward", 0.2)
				_anim_player.speed_scale = clampf(speed_h / 5.0, 0.6, 1.5)
			elif _anim_player.has_animation("walk_backward"):
				if _anim_player.current_animation != "walk_backward":
					_anim_player.play("walk_backward", 0.2)
				_anim_player.speed_scale = clampf(speed_h / 1.6, 0.5, 2.0)
			else:
				if _anim_player.current_animation != "walk":
					_anim_player.play("walk", 0.2)
				_anim_player.speed_scale = clampf(speed_h / 1.6, 0.5, 2.0)
		"strafe_left":
			if _anim_player.has_animation("strafe_left"):
				if _anim_player.current_animation != "strafe_left":
					_anim_player.play("strafe_left", 0.2)
				_anim_player.speed_scale = clampf(speed_h / 3.5, 0.6, 1.5)
			else:
				if _anim_player.current_animation != "walk":
					_anim_player.play("walk", 0.2)
		"strafe_right":
			if _anim_player.has_animation("strafe_right"):
				if _anim_player.current_animation != "strafe_right":
					_anim_player.play("strafe_right", 0.2)
				_anim_player.speed_scale = clampf(speed_h / 3.5, 0.6, 1.5)
			else:
				if _anim_player.current_animation != "walk":
					_anim_player.play("walk", 0.2)

func _update_procedural_motion(delta: float) -> void:
	_anim_clock += delta
	var speed_h = Vector2(velocity.x, velocity.z).length()

	if _anim_player:
		_update_mixamo_motion(delta, speed_h)
		return

	# Avançar fase de passada de locomoção
	if speed_h > 0.2:
		_stride_phase += delta * speed_h * 7.5
	else:
		_stride_phase = fmod(_stride_phase, TAU)

	# 1. Movimento orgânico da arma (respiração em idle + oscilação ao andar estilo CS)
	var gun_holder = _cached_gun_holder if _cached_gun_holder else find_child("GunHolder", true, false)
	var hip_bob: float = 0.0
	var base_gun_y = 0.88 if is_crouching else 1.18

	if is_crouching:
		hip_bob = -0.32
	elif speed_h > 0.2:
		hip_bob = -abs(sin(_stride_phase)) * 0.02
	else:
		hip_bob = 0.0

	if gun_holder:
		var breath = sin(_anim_clock * 2.5 + float(get_instance_id() % 7)) * 0.006
		gun_holder.position.y = base_gun_y + breath + (hip_bob * 0.6)

	# 2. Inclinação lateral tática sutil do tronco (banking ao andar) e oscilação vertical
	var vis = get_node_or_null("VisualRoot")
	if vis:
		var lean = sin(_stride_phase) * deg_to_rad(2.0) if speed_h > 0.2 else 0.0
		vis.rotation.z = lean
		vis.position.y = hip_bob

	# 3. Cinemática Procedural das Pernas e Joelhos (Knee Flexion & Locomotion)
	_update_procedural_legs(delta, speed_h)

func _update_procedural_legs(delta: float, speed_h: float) -> void:
	if not _skeleton:
		return

	var l_thigh_deg: float = 0.0
	var r_thigh_deg: float = 0.0
	var l_calf_deg: float  = -10.0
	var r_calf_deg: float  = -10.0

	if is_crouching:
		# Posição tática agachada (Crouch Stance CS: flexão profunda dos joelhos)
		l_thigh_deg = 45.0
		l_calf_deg  = -65.0
		r_thigh_deg = 45.0
		r_calf_deg  = -65.0
	elif speed_h > 0.2:
		# Ciclo dinâmico de locomoção (Walk/Run):
		# Alternância rítmica das coxas com flexão ativa dos joelhos durante o passo
		var swing = sin(_stride_phase)
		l_thigh_deg = swing * 22.0
		r_thigh_deg = -swing * 22.0

		# Flexão natural do joelho:
		# Quando a perna avança (swing > 0), o joelho flexiona para erguer o pé do chão (-26°)
		# Na fase de sustentação/empurrão posterior, há flexão de amortecimento (-12°)
		var l_swing_flex = max(0.0, swing) * -26.0
		var l_push_flex  = max(0.0, -swing) * -12.0
		l_calf_deg = -10.0 + l_swing_flex + l_push_flex

		var r_swing_flex = max(0.0, -swing) * -26.0
		var r_push_flex  = max(0.0, swing) * -12.0
		r_calf_deg = -10.0 + r_swing_flex + r_push_flex
	else:
		# Postura Atlética de Prontidão (Idle Combat Stance do CS: joelhos relaxados e flexionados):
		# Evita pernas rígidas/esticadas estilo estátua
		l_thigh_deg = 10.0
		l_calf_deg  = -16.0
		r_thigh_deg = -4.0
		r_calf_deg  = -10.0

	var target_lt_q: Quaternion = Quaternion.IDENTITY
	var target_lc_q: Quaternion = Quaternion.IDENTITY
	var target_rt_q: Quaternion = Quaternion.IDENTITY
	var target_rc_q: Quaternion = Quaternion.IDENTITY

	if _is_valve_rig:
		target_lt_q = _rest_l_thigh * Quaternion(Vector3.FORWARD, deg_to_rad(l_thigh_deg))
		target_lc_q = _rest_l_calf  * Quaternion(Vector3.FORWARD, deg_to_rad(l_calf_deg))
		target_rt_q = _rest_r_thigh * Quaternion(Vector3.FORWARD, deg_to_rad(r_thigh_deg))
		target_rc_q = _rest_r_calf  * Quaternion(Vector3.FORWARD, deg_to_rad(r_calf_deg))
	else:
		target_lt_q = _rest_l_thigh * Quaternion(Vector3.RIGHT, deg_to_rad(-l_thigh_deg))
		target_lc_q = _rest_l_calf  * Quaternion(Vector3.RIGHT, deg_to_rad(-l_calf_deg))
		target_rt_q = _rest_r_thigh * Quaternion(Vector3.RIGHT, deg_to_rad(-r_thigh_deg))
		target_rc_q = _rest_r_calf  * Quaternion(Vector3.RIGHT, deg_to_rad(-r_calf_deg))

	# Interpolação suave (Slerp) para transições orgânicas sem estalos
	var lerp_weight = clamp(delta * 14.0, 0.0, 1.0)
	_cur_l_thigh_q = _cur_l_thigh_q.slerp(target_lt_q, lerp_weight)
	_cur_l_calf_q  = _cur_l_calf_q.slerp(target_lc_q, lerp_weight)
	_cur_r_thigh_q = _cur_r_thigh_q.slerp(target_rt_q, lerp_weight)
	_cur_r_calf_q  = _cur_r_calf_q.slerp(target_rc_q, lerp_weight)

	if _bone_l_thigh >= 0:
		_skeleton.set_bone_pose_rotation(_bone_l_thigh, _cur_l_thigh_q)
	if _bone_l_calf >= 0:
		_skeleton.set_bone_pose_rotation(_bone_l_calf, _cur_l_calf_q)
	if _bone_r_thigh >= 0:
		_skeleton.set_bone_pose_rotation(_bone_r_thigh, _cur_r_thigh_q)
	if _bone_r_calf >= 0:
		_skeleton.set_bone_pose_rotation(_bone_r_calf, _cur_r_calf_q)

# ── LOOP PRINCIPAL DE FÍSICA & COMBATE ─────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if ai_state == AIState.DEAD:
		return

	# Pausa tática pré-partida estilo Call of Duty (aguarda contagem regressiva)
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("is_in_countdown") and gm.is_in_countdown():
		velocity.x = lerp(velocity.x, 0.0, 10.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 10.0 * delta)
		if not is_on_floor():
			velocity.y -= 22.0 * delta
		elif velocity.y < 0.0:
			velocity.y = 0.0
		if _anim_player and _anim_player.has_animation("idle") and _anim_player.current_animation != "idle":
			_anim_player.play("idle", 0.15)
		move_and_slide()
		return

	if _departure_delay > 0.0:
		_departure_delay -= delta
		velocity.x = lerp(velocity.x, 0.0, 10.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 10.0 * delta)
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= 22.0 * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	_update_cooldowns(delta)
	_update_crouch_geometry(delta)
	# Percepção escalonada entre frames para eliminar oscilação de FPS (SUB-7)
	if Engine.get_physics_frames() % 3 == _perception_offset:
		_detect_enemies(delta * 3.0)
	_update_procedural_motion(delta)

	match ai_state:
		AIState.PATROL:       _state_patrol(delta)
		AIState.ALERT:        _state_alert(delta)
		AIState.COMBAT:       _state_combat(delta)
		AIState.SEARCHING:    _state_search(delta)
		AIState.RETREAT_HEAL: _state_retreat_heal(delta)

	# Força de repulsão contínua em bolha elástica: NUNCA permite sobreposição/clipping de corpos
	_apply_continuous_separation_repulsion(delta)

	move_and_slide()

func _apply_continuous_separation_repulsion(delta: float) -> void:
	var my_pos = global_position
	var space = get_world_3d().direct_space_state
	var all_bots = get_tree().get_nodes_in_group("enemies")
	for other in all_bots:
		if other == self or not is_instance_valid(other) or not (other is CharacterBody3D):
			continue
		if other.get("ai_state") == AIState.DEAD:
			continue
		var to_self = my_pos - other.global_position
		to_self.y = 0.0
		var dist = to_self.length()
		if dist < 1.7 and dist > 0.001:
			var rep_dir = to_self / dist
			var push = (1.0 - (dist / 1.7)) * 4.5
			# Se a repulsão empurrar contra uma parede próxima, desliza paralelo à parede
			if space:
				var rep_q = PhysicsRayQueryParameters3D.create(my_pos + Vector3.UP * 0.8, my_pos + Vector3.UP * 0.8 + rep_dir * 0.70, 1, [self.get_rid(), other.get_rid()])
				var rep_hit = space.intersect_ray(rep_q)
				if not rep_hit.is_empty():
					var hit_norm = rep_hit.normal
					hit_norm.y = 0.0
					if hit_norm.length_squared() > 0.01:
						rep_dir = rep_dir.slide(hit_norm.normalized()).normalized()
						push *= 0.35
			velocity.x += rep_dir.x * push
			velocity.z += rep_dir.z * push
		elif dist <= 0.001:
			var angle = randf() * TAU
			velocity.x += cos(angle) * 3.0
			velocity.z += sin(angle) * 3.0

	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p is CharacterBody3D:
			var to_self_p = my_pos - p.global_position
			to_self_p.y = 0.0
			var dist_p = to_self_p.length()
			if dist_p < 1.6 and dist_p > 0.001:
				var rep_dir_p = to_self_p / dist_p
				var push_p = (1.0 - (dist_p / 1.6)) * 4.0
				if space:
					var rep_qp = PhysicsRayQueryParameters3D.create(my_pos + Vector3.UP * 0.8, my_pos + Vector3.UP * 0.8 + rep_dir_p * 0.70, 1, [self.get_rid(), p.get_rid()])
					var rep_hit_p = space.intersect_ray(rep_qp)
					if not rep_hit_p.is_empty():
						var hit_norm_p = rep_hit_p.normal
						hit_norm_p.y = 0.0
						if hit_norm_p.length_squared() > 0.01:
							rep_dir_p = rep_dir_p.slide(hit_norm_p.normalized()).normalized()
							push_p *= 0.35
				velocity.x += rep_dir_p.x * push_p
				velocity.z += rep_dir_p.z * push_p

	# Tratamento físico de contato com paredes (elimina trancamento em paredes/quinas)
	if is_on_wall():
		_handle_wall_collision(delta)
	else:
		_wall_contact_timer = max(0.0, _wall_contact_timer - delta * 2.0)

func _handle_wall_collision(delta: float) -> void:
	var wall_norm = get_wall_normal()
	wall_norm.y = 0.0
	if wall_norm.length_squared() < 0.01:
		return
	wall_norm = wall_norm.normalized()
	_wall_contact_timer += delta

	# Assistência para Degraus e Escadas (Step-Clamping):
	# Se a colisão ocorre na canela (altura < 0.35m) e o peito está livre de paredes,
	# trata como um degrau de escada em vez de parede sólida, permitindo subir sem repulsão.
	var space = get_world_3d().direct_space_state
	if space:
		var foot_y = global_position + Vector3.UP * 0.18
		var chest_y = global_position + Vector3.UP * 0.90
		var check_dir = -wall_norm * 0.65
		var low_hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(foot_y, foot_y + check_dir, 1, [self.get_rid()]))
		var high_hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(chest_y, chest_y + check_dir, 1, [self.get_rid()]))
		if not low_hit.is_empty() and high_hit.is_empty():
			# É um degrau ou rampa de escada: ajuda a subir
			velocity.y = maxf(velocity.y, 2.6)
			_wall_contact_timer = 0.0
			return

	# 1. Se a velocidade horizontal empurra contra a parede, desliza ao longo da superfície
	var h_vel = Vector3(velocity.x, 0.0, velocity.z)
	if h_vel.dot(wall_norm) < 0.0:
		var slid = h_vel.slide(wall_norm)
		velocity.x = slid.x
		velocity.z = slid.z

	# 2. Se continuar pressionando continuamente contra a parede por > 0.20s:
	if _wall_contact_timer > 0.20:
		velocity.x += wall_norm.x * 2.6
		velocity.z += wall_norm.z * 2.6
		if ai_state == AIState.COMBAT:
			_strafe_dir_sign = -_strafe_dir_sign
			_combat_retreating = false
		elif ai_state == AIState.PATROL or ai_state == AIState.SEARCHING:
			_stuck_frames += 1
			if _stuck_frames >= 2:
				if space:
					_trigger_stuck_recovery(space)

func _update_cooldowns(delta: float) -> void:
	_fire_cooldown  = max(0.0, _fire_cooldown - delta)
	_reaction_timer = max(0.0, _reaction_timer - delta)
	_jump_cooldown  = max(0.0, _jump_cooldown - delta)
	if _crouch_timer > 0.0:
		_crouch_timer -= delta
		if _crouch_timer <= 0.0 and not _is_fleeing_to_heal:
			is_crouching = false

func _update_crouch_geometry(delta: float) -> void:
	var target_vis_y = -0.35 if is_crouching else 0.0
	var vis = get_node_or_null("VisualRoot")
	if vis:
		vis.position.y = lerp(vis.position.y, target_vis_y, 10.0 * delta)

	var head_box = get_node_or_null("Hitbox_Head")
	if head_box:
		var target_head_y = 1.25 if is_crouching else 1.65
		head_box.position.y = lerp(head_box.position.y, target_head_y, 10.0 * delta)

	var chest_box = get_node_or_null("Hitbox_Chest")
	if chest_box:
		var target_chest_y = 0.85 if is_crouching else 1.20
		chest_box.position.y = lerp(chest_box.position.y, target_chest_y, 10.0 * delta)


# ── PERCEPÇÃO TÁTICA (JOGADOR + BOTS INIMIGOS) ────────────────────────────────
func _detect_enemies(delta: float) -> void:
	var potential_enemies: Array[CharacterBody3D] = []

	# Checar se o modo é Free-For-All (FFA)
	var is_ffa = false
	var gmm = get_node_or_null("/root/GameModeManager")
	if not gmm and get_tree() and get_tree().current_scene:
		gmm = get_tree().current_scene.find_child("GameModeManager", true, false)
	if gmm and "game_mode" in gmm and gmm.game_mode == 4: # GameMode.FFA
		is_ffa = true

	# 1. Verificar jogadores humanos
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if p is CharacterBody3D:
			var p_team = 0
			var gm = get_node_or_null("/root/GameManager")
			if gm:
				p_team = 0 if gm.local_player_team == 1 else 1
			if is_ffa or p_team != self.team:
				var is_alive = true
				if p.has_node("HealthComponent"):
					var hp = p.get_node("HealthComponent") as HealthComponent
					is_alive = hp and hp.current_health > 0
				if is_alive:
					potential_enemies.append(p)

	# 2. Verificar bots inimigos (grupo enemies)
	var bots = get_tree().get_nodes_in_group("enemies")
	for b in bots:
		if b is CharacterBody3D and b != self:
			var b_team = b.get("team")
			if is_ffa or (b_team != null and b_team != self.team):
				var b_state = b.get("ai_state")
				if b_state == null or b_state != AIState.DEAD:
					potential_enemies.append(b)

	var best_enemy: CharacterBody3D = null
	var best_score: float = -99999.0
	var space = get_world_3d().direct_space_state
	var my_eye = global_position + Vector3.UP * 1.5
	var forward = -global_transform.basis.z

	for enemy in potential_enemies:
		var e_eye = enemy.global_position + Vector3.UP * 1.5
		var e_chest = enemy.global_position + Vector3.UP * 1.1
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= sight_range:
			var enemy_spd = Vector2(enemy.velocity.x, enemy.velocity.z).length() if "velocity" in enemy else 0.0
			var can_hear = dist <= hearing_range and enemy_spd > 0.8
			var can_sense_close = (close_sense_range > 0.0) and (dist <= close_sense_range)

			var dir_to_enemy = (e_chest - my_eye).normalized()
			var angle = rad_to_deg(forward.angle_to(dir_to_enemy))
			var in_fov = angle <= sight_fov_degrees * 0.5

			if in_fov or can_hear or can_sense_close:
				var exc: Array[RID] = [self.get_rid(), enemy.get_rid()]
				var query_chest = PhysicsRayQueryParameters3D.create(my_eye, e_chest, 1, exc)
				var hit = space.intersect_ray(query_chest)
				var has_los = hit.is_empty() or hit.collider == enemy or (hit.collider.get_parent() and hit.collider.get_parent() == enemy)
				if not has_los:
					var query_eye = PhysicsRayQueryParameters3D.create(my_eye, e_eye, 1, exc)
					var hit_eye = space.intersect_ray(query_eye)
					has_los = hit_eye.is_empty() or hit_eye.collider == enemy or (hit_eye.collider.get_parent() and hit_eye.collider.get_parent() == enemy)

				if has_los:
					# Pontuação neutra e simétrica: trata players e bots inimigos de forma perfeitamente idêntica
					var score = (sight_range - dist) * 1.5
					if in_fov:
						score += (1.0 - (angle / (sight_fov_degrees * 0.5))) * 15.0
					# Histerese e stickiness: valoriza duelos em andamento para não abandonar bot inimigo para focar no player
					if enemy == target_combatant:
						score += 25.0
					if enemy == last_attacker:
						score += 20.0

					if score > best_score:
						best_score = score
						best_enemy = enemy

	if best_enemy != null:
		_lose_sight_timer = lose_sight_delay
		_last_known_pos = best_enemy.global_position
		target_combatant = best_enemy

		# Notificar esquadrão aliado via Squad Shared Intel
		var bm = get_node_or_null("/root/BotManager")
		if not bm and get_tree() and get_tree().current_scene:
			bm = get_tree().current_scene.find_child("BotManager", true, false)
		if bm and bm.has_method("report_enemy_contact"):
			bm.report_enemy_contact(self.team, best_enemy.global_position)

		if ai_state != AIState.COMBAT and ai_state != AIState.ALERT:
			_reaction_timer = reaction_time * randf_range(0.85, 1.15)
			ai_state = AIState.ALERT
			enemy_spotted_player.emit(best_enemy)
	else:
		if target_combatant != null:
			_lose_sight_timer -= delta
			if _lose_sight_timer <= 0.0:
				_transition_to_search()

# ── ESTADO: PATRULHA ──────────────────────────────────────────────────────────
func _state_patrol(delta: float) -> void:
	if _tactical_pause_timer > 0.0:
		_tactical_pause_timer -= delta
		velocity.x = lerp(velocity.x, 0.0, 10.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 10.0 * delta)
		if _tactical_look_target != Vector3.ZERO:
			_face_target(_tactical_look_target, delta)
		return

	_patrol_timer -= delta
	var h_dist = Vector2(global_position.x - _patrol_target.x, global_position.z - _patrol_target.z).length()
	if _patrol_timer <= 0.0 or h_dist < 2.2:
		_set_random_patrol_target()

	_navigate_to(_patrol_target, move_speed * 0.95, delta)

func _set_random_patrol_target() -> void:
	var rng = RandomNumberGenerator.new()

	# 1. Defesa Tática de Base: Se inimigos invadiram o quintal ou garagem da nossa base
	var base_threat = _check_base_threat()
	if base_threat != Vector3.ZERO:
		_patrol_target = base_threat
		_patrol_timer = rng.randf_range(4.0, 7.0)
		_tactical_pause_timer = 0.0
		_invalidate_path()
		return

	# 2. Squad Shared Intel: Convergir com moderação tática
	# Bots da Lane 1 (Street Center) e Rushers mantêm o avanço contínuo para o meio do mapa
	var bm = get_node_or_null("/root/BotManager")
	if not bm and get_tree() and get_tree().current_scene:
		bm = get_tree().current_scene.find_child("BotManager", true, false)
	if bm and bm.has_method("get_team_last_contact"):
		var contact = bm.get_team_last_contact(self.team)
		if contact.get("pos", Vector3.ZERO) != Vector3.ZERO:
			var contact_pos: Vector3 = contact["pos"]
			var dist_to_contact = global_position.distance_to(contact_pos)
			var should_divert = (archetype == BotArchetype.ANCHOR or dist_to_contact < 11.0)
			if assigned_lane == 1 and (archetype == BotArchetype.RUSHER or archetype == BotArchetype.BALANCED):
				# 75% das vezes ignora desvios e continua o avanço maciço pelo meio da rua!
				should_divert = (rng.randf() < 0.25)
			if should_divert and dist_to_contact > 4.5:
				var to_c = (contact_pos - global_position).normalized()
				var perp = Vector3(-to_c.z, 0.0, to_c.x)
				var flank_offset = perp * (lateral_sign * rng.randf_range(2.0, 4.5))
				_patrol_target = contact_pos + flank_offset
				_patrol_timer = rng.randf_range(4.0, 7.0)
				_tactical_pause_timer = 0.0
				_invalidate_path()
				return

	# Coleta alvos atuais de ALIADOS para evitar aglomeração no mesmo ponto (Anti-Clustering restrito a aliados)
	var occupied_wps: Array[Vector3] = []
	var same_lane_count = 0
	for other in get_tree().get_nodes_in_group("enemies"):
		if other != self and is_instance_valid(other) and other is CharacterBody3D:
			if other.get("team") == self.team and other.get("ai_state") != AIState.DEAD:
				var ot_tgt = other.get("_patrol_target")
				if ot_tgt != null and ot_tgt != Vector3.ZERO:
					occupied_wps.append(ot_tgt)
				if other.get("assigned_lane") == assigned_lane:
					same_lane_count += 1

	# Rotação orgânica de lane de acordo com arquétipo
	var lane_swap_chance = 0.35
	if archetype == BotArchetype.RUSHER:
		lane_swap_chance = 0.50
	elif archetype == BotArchetype.FLANKER:
		lane_swap_chance = 0.40
	elif archetype == BotArchetype.ANCHOR:
		lane_swap_chance = 0.20

	_lane_rotation_count += 1
	if same_lane_count >= 3 or (_lane_rotation_count >= 3 and rng.randf() < lane_swap_chance):
		_lane_rotation_count = 0
		if archetype == BotArchetype.RUSHER:
			assigned_lane = 1 if assigned_lane != 1 else (3 if rng.randf() < 0.50 else 0)
		elif archetype == BotArchetype.FLANKER:
			assigned_lane = 3 if assigned_lane == 0 else 0
		elif archetype == BotArchetype.ANCHOR:
			assigned_lane = 1 if randf() < 0.60 else 3
		else:
			assigned_lane = [0, 1, 3, 1][rng.randi() % 4]

	var chosen_wp = Vector3.ZERO
	if _nav_graph and _nav_graph.has_method("get_next_lane_waypoint"):
		chosen_wp = _nav_graph.get_next_lane_waypoint(global_position, assigned_lane, team, _last_patrol_wp, occupied_wps, _recent_patrol_wps)
	elif _nav_graph:
		var waypoints: Array[Vector3] = _nav_graph.get_patrol_waypoints()
		if not waypoints.is_empty():
			chosen_wp = waypoints[rng.randi_range(0, waypoints.size() - 1)]

	if chosen_wp != Vector3.ZERO:
		_last_patrol_wp = chosen_wp
		_recent_patrol_wps.append(chosen_wp)
		if _recent_patrol_wps.size() > 3:
			_recent_patrol_wps.pop_front()

		# Jitter suave para não empurrar bots em pilastras ou quinas
		var off_x = rng.randf_range(-0.3, 0.3)
		var off_z = rng.randf_range(-0.3, 0.3)
		_patrol_target = Vector3(chosen_wp.x + off_x, chosen_wp.y, chosen_wp.z + off_z)
	else:
		var off_x = rng.randf_range(-4.0, 4.0)
		var off_z = rng.randf_range(-4.0, 4.0)
		_patrol_target = global_position + Vector3(off_x, 0, off_z)

	# Clampar _patrol_target estritamente dentro da arena de jogo (evita andar contra cercas)
	var scene_cur = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_parent()
	var s_n = scene_cur.name.to_lower() if scene_cur else ""
	var is_bo3_arena = ("bo3" in s_n or "2065" in s_n) or (scene_cur and scene_cur.find_child("Nuk3townModel", true, false) != null)
	if is_bo3_arena:
		_patrol_target.x = clampf(_patrol_target.x, -39.0, 39.0)
		_patrol_target.z = clampf(_patrol_target.z, -17.0, 17.0)
	else:
		_patrol_target.x = clampf(_patrol_target.x, -17.5, 13.0)
		_patrol_target.z = clampf(_patrol_target.z, -29.5, 33.0)

	var target_dist = global_position.distance_to(_patrol_target)
	var travel_time = (target_dist / maxf(move_speed * 0.90, 2.0)) + rng.randf_range(4.0, 7.0)
	_patrol_timer = clampf(travel_time, 8.0, 15.0)
	_tactical_pause_timer = 0.0

	_invalidate_path()

func _check_base_threat() -> Vector3:
	var scene = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_parent()
	if not scene:
		return Vector3.ZERO
	var is_bo3 = false
	var s_name = scene.name.to_lower()
	if "bo3" in s_name or "2065" in s_name or scene.find_child("Nuk3townModel", true, false) != null:
		is_bo3 = true

	# Defesa de base só se aplica a bots que já estejam no setor defensivo da base (< 24m da base)
	# Bots que já estão avançando pelo meio ou flancos mantêm a linha de frente e não recuam!
	var home_base_pos = Vector3(40.0, -1.45, -8.0) if self.team == 0 else Vector3(-40.0, -1.45, -10.0)
	if not is_bo3:
		home_base_pos = Vector3(-14.0, 0.2, -30.0) if self.team == 0 else Vector3(0.0, 0.2, 32.0)

	var dist_to_home = global_position.distance_to(home_base_pos)
	if dist_to_home > 24.0:
		return Vector3.ZERO # Bot avançado mantém a pressão frontal no meio!

	var enemy_combatants: Array[CharacterBody3D] = []
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p is CharacterBody3D:
			var p_team = p.get_team() if p.has_method("get_team") else 0
			if p_team != self.team:
				enemy_combatants.append(p)
	for b in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(b) and b is CharacterBody3D and b != self:
			if b.get("team") != self.team and b.get("ai_state") != AIState.DEAD:
				enemy_combatants.append(b)

	for enemy in enemy_combatants:
		var ep = enemy.global_position
		var in_my_base = false
		if is_bo3:
			# Ameaça real apenas se o invasor penetrou fundo no quintal de spawn
			if self.team == 0 and ep.x > 30.0: # Quintal Alpha
				in_my_base = true
			elif self.team == 1 and ep.x < -30.0: # Quintal Bravo
				in_my_base = true
		else:
			if self.team == 0 and ep.z < -22.0: # Quintal Alpha BO1
				in_my_base = true
			elif self.team == 1 and ep.z > 22.0: # Quintal Bravo BO1
				in_my_base = true

		if in_my_base:
			return ep
	return Vector3.ZERO

# ── ESTADO: ALERTA ────────────────────────────────────────────────────────────
func _state_alert(delta: float) -> void:
	if not _is_target_valid():
		ai_state = AIState.PATROL
		return

	_face_target(target_combatant.global_position, delta)
	_reaction_timer -= delta
	if _reaction_timer <= 0.0:
		ai_state = AIState.COMBAT

# ── CHECAGEM ESTRITA DE LINHA DE FOGO (LINE OF FIRE) ─────────────────────────
func _has_line_of_fire() -> bool:
	if not _is_target_valid():
		return false

	var space = get_world_3d().direct_space_state
	if not space:
		return false

	# 1. Ponto de origem seguro dentro da cápsula do corpo (NUNCA atravessa paredes)
	var body_eye = global_position + Vector3.UP * 1.5
	var target_chest = target_combatant.global_position + Vector3.UP * 1.1
	var target_head = target_combatant.global_position + Vector3.UP * 1.6

	# 2. Se a arma possui muzzle projetado, checa se a arma não está enfiada dentro de uma parede/quina
	var dist_to_tgt = body_eye.distance_to(target_chest)
	var bot_rifle = _cached_bot_rifle if _cached_bot_rifle else find_child("BotRifle3D", true, false)
	if dist_to_tgt > 2.5 and bot_rifle and bot_rifle.has_node("MuzzleFlash"):
		var muzzle_pos = bot_rifle.get_node("MuzzleFlash").global_position
		var muzzle_query = PhysicsRayQueryParameters3D.create(body_eye, muzzle_pos, 1, [self.get_rid(), target_combatant.get_rid()])
		var muzzle_hit = space.intersect_ray(muzzle_query)
		if not muzzle_hit.is_empty() and muzzle_hit.collider != target_combatant:
			# A arma está clipando dentro de uma parede/esquina sólida: impossível disparar!
			return false

	# 3. Raycast estrito de linha de visão/fogo da cápsula do bot até o alvo (peito e cabeça)
	var exc: Array[RID] = [self.get_rid(), target_combatant.get_rid()]
	var query_chest = PhysicsRayQueryParameters3D.create(body_eye, target_chest, 1, exc)
	var hit_chest = space.intersect_ray(query_chest)
	if hit_chest.is_empty() or hit_chest.collider == target_combatant or (hit_chest.collider.get_parent() and hit_chest.collider.get_parent() == target_combatant):
		return true

	var query_head = PhysicsRayQueryParameters3D.create(body_eye, target_head, 1, exc)
	var hit_head = space.intersect_ray(query_head)
	if hit_head.is_empty() or hit_head.collider == target_combatant or (hit_head.collider.get_parent() and hit_head.collider.get_parent() == target_combatant):
		return true

	# Bloqueado por parede ou obstáculo sólido
	return false

# ── ESTADO: COMBATE (COM DISPARO EM RAJADAS E SEM ATIRAR EM PAREDES) ─────────
func _state_combat(delta: float) -> void:
	if not _is_target_valid():
		target_combatant = null
		ai_state = AIState.PATROL
		return

	var dist = global_position.distance_to(target_combatant.global_position)
	var has_lof = _has_line_of_fire()
	if has_lof:
		_face_target(target_combatant.global_position, delta)
		_last_known_pos = target_combatant.global_position
		_lost_lof_timer = 0.0
	else:
		_face_target(_last_known_pos, delta)
		_lost_lof_timer += delta

	var space = get_world_3d().direct_space_state
	var my_chest = global_position + Vector3.UP * 0.85
	var exc_self = [self.get_rid()]

	var right_dir = global_transform.basis.x
	right_dir.y = 0.0
	if right_dir.length_squared() > 0.01:
		right_dir = right_dir.normalized()
	else:
		right_dir = Vector3.RIGHT

	var left_dir = -right_dir
	var away_dir = (global_position - target_combatant.global_position).normalized()
	away_dir.y = 0.0
	if away_dir.length_squared() < 0.01:
		away_dir = -global_transform.basis.z
		away_dir.y = 0.0
		away_dir = away_dir.normalized()

	# ── SISTEMA DE FOLGA DE MANOBRA (SAFE SPACE CLEARANCE) ──
	# Raycasts nas 3 direções para garantir que o bot nunca bata ou tente strafar contra paredes/móveis
	var left_clear = true
	var right_clear = true
	var rear_clear = true

	if space:
		var q_left = PhysicsRayQueryParameters3D.create(my_chest, my_chest + left_dir * 1.35, 1, exc_self)
		left_clear = space.intersect_ray(q_left).is_empty()

		var q_right = PhysicsRayQueryParameters3D.create(my_chest, my_chest + right_dir * 1.35, 1, exc_self)
		right_clear = space.intersect_ray(q_right).is_empty()

		var q_rear = PhysicsRayQueryParameters3D.create(my_chest, my_chest + away_dir * 1.40, 1, exc_self)
		rear_clear = space.intersect_ray(q_rear).is_empty()

	# Dispersão dinâmica de combate: cada bot possui preferência de distância individual escalonada
	var bot_dist_bias = float((bot_id * 7) % 5) * 1.2 - 2.4 # varia de -2.4m a +2.4m
	var retreat_min = 4.0 + bot_dist_bias
	var retreat_max = 7.5 + bot_dist_bias
	if archetype == BotArchetype.RUSHER:
		retreat_min = 2.4 + bot_dist_bias * 0.4
		retreat_max = 5.6 + bot_dist_bias * 0.4
	elif archetype == BotArchetype.ANCHOR:
		retreat_min = 6.5 + bot_dist_bias * 0.5
		retreat_max = 10.5 + bot_dist_bias * 0.5

	if dist < retreat_min and rear_clear and not is_on_wall():
		_combat_retreating = true
	elif dist > retreat_max or not rear_clear or is_on_wall():
		_combat_retreating = false

	# ── DISPERSÃO TÁTICA MÚTUA (ANTI-ALINHAMENTO / CROSSFIRE ANGULAR) ──
	var ally_crossfire = Vector3.ZERO
	var all_allies = get_tree().get_nodes_in_group("enemies")
	for other in all_allies:
		if other == self or not is_instance_valid(other) or not (other is CharacterBody3D):
			continue
		if other.get("team") == self.team and other.get("ai_state") == AIState.COMBAT:
			var to_me = global_position - other.global_position
			to_me.y = 0.0
			var d_other = to_me.length()
			if d_other < 4.2 and d_other > 0.01:
				var to_enemy = (target_combatant.global_position - global_position).normalized()
				to_enemy.y = 0.0
				var lateral_cross = Vector3(-to_enemy.z, 0.0, to_enemy.x)
				var push_side = 1.0 if to_me.dot(lateral_cross) >= 0.0 else -1.0
				var rep_str = (1.0 - (d_other / 4.2))
				ally_crossfire += lateral_cross * push_side * (rep_str * 3.2)

	# Se ally_crossfire empurrar contra uma parede, anula
	if ally_crossfire.length_squared() > 0.01 and space:
		var q_cross = PhysicsRayQueryParameters3D.create(my_chest, my_chest + ally_crossfire.normalized() * 0.85, 1, exc_self)
		if not space.intersect_ray(q_cross).is_empty():
			ally_crossfire = Vector3.ZERO

	# Checa se o bot está confinado em portas, corredores ou atrás de casas
	var in_confined = false
	if _nav_graph:
		in_confined = _nav_graph.is_position_near_portal(global_position, 2.8) or _nav_graph.is_position_in_house_or_corridor(global_position, 3.0)

	# Movimentação tática inteligente sem oscilação
	if not has_lof:
		if _lost_lof_timer > 0.20:
			# Alvo oculto: persegue imediatamente com sprint para fechar ângulo e manter pressão
			_navigate_to(_last_known_pos, sprint_speed, delta)
	elif in_confined or dist > 5.5:
		# Em portas, corredores, atrás de casas ou à média/longa distância:
		# NUNCA fica travado na quina/porta! Avança ativamente com TacticalNavGraph para ocupar a rua e invadir o miolo do mapa!
		_navigate_to(target_combatant.global_position, move_speed * 1.05, delta)
	elif _combat_retreating:
		# Recuo tático seguro mantendo a mira firme no inimigo
		is_crouching = false
		var retreat_vec = away_dir
		if ally_crossfire.length_squared() > 0.01:
			retreat_vec = (retreat_vec + ally_crossfire * 0.3).normalized()
		var target_vx = retreat_vec.x * move_speed
		var target_vz = retreat_vec.z * move_speed
		if is_on_wall():
			var wall_n = get_wall_normal()
			wall_n.y = 0.0
			if wall_n.length_squared() > 0.01:
				wall_n = wall_n.normalized()
				var slid = Vector3(target_vx, 0, target_vz).slide(wall_n)
				target_vx = slid.x + wall_n.x * 0.4
				target_vz = slid.z + wall_n.z * 0.4
		velocity.x = lerp(velocity.x, target_vx, 8.0 * delta)
		velocity.z = lerp(velocity.z, target_vz, 8.0 * delta)
	else:
		# Combate aberto em curta distância (<= 5.5m):
		# Combina avanço frontal agressivo com strafe lateral
		if not left_clear and not right_clear:
			_strafe_dir_sign = 0.0
		elif not left_clear and right_clear:
			_strafe_dir_sign = 1.0
		elif not right_clear and left_clear:
			_strafe_dir_sign = -1.0
		else:
			_strafe_timer -= delta
			if _strafe_timer <= 0.0:
				_strafe_timer = randf_range(0.6, 1.4)
				_strafe_dir_sign = 1.0 if randf() > 0.5 else -1.0
				if randf() < 0.15:
					_strafe_dir_sign = 0.0
					_strafe_timer = randf_range(0.2, 0.4)

		var perp = right_dir * _strafe_dir_sign

		# Salto evasivo ocasional em combate aberto
		if _jump_cooldown <= 0.0 and is_on_floor() and not is_crouching and left_clear and right_clear:
			if (archetype == BotArchetype.RUSHER and randf() < 0.06) or (archetype == BotArchetype.FLANKER and randf() < 0.04):
				velocity.y = 4.6
				_jump_cooldown = randf_range(3.5, 6.5)

		# Agachamento tático (drop-shot) em média distância
		if _crouch_timer <= 0.0 and is_on_floor() and dist > 5.5 and dist < 14.0:
			if archetype == BotArchetype.ANCHOR and randf() < 0.08:
				is_crouching = true
				_crouch_timer = randf_range(0.8, 1.4)
			elif archetype == BotArchetype.BALANCED and randf() < 0.05:
				is_crouching = true
				_crouch_timer = randf_range(0.6, 1.2)

		var strafe_speed_mult = 1.10 if archetype == BotArchetype.RUSHER else 0.95
		var to_enemy = (target_combatant.global_position - global_position).normalized()
		to_enemy.y = 0.0
		var fwd_weight = 0.50 if dist > 3.5 else 0.10
		var move_combat_vec = (to_enemy * fwd_weight + perp * 0.70).normalized() * (move_speed * strafe_speed_mult)
		if ally_crossfire.length_squared() > 0.01:
			move_combat_vec += ally_crossfire * 0.50

		# Amortecimento e descolamento físico imediato ao tocar em paredes
		if is_on_wall():
			_strafe_dir_sign = -_strafe_dir_sign
			_strafe_timer = randf_range(0.8, 1.5)
			var wall_n = get_wall_normal()
			wall_n.y = 0.0
			if wall_n.length_squared() > 0.01:
				wall_n = wall_n.normalized()
				if move_combat_vec.dot(wall_n) < 0.0:
					move_combat_vec = move_combat_vec.slide(wall_n)
				move_combat_vec += wall_n * 0.75

		velocity.x = lerp(velocity.x, move_combat_vec.x, 8.0 * delta)
		velocity.z = lerp(velocity.z, move_combat_vec.z, 8.0 * delta)

	# Disparar ESTRITAMENTE quando houver linha de tiro desobstruída E mira alinhada
	if has_lof:
		var fwd = -global_transform.basis.z
		fwd.y = 0.0
		var to_tgt = (target_combatant.global_position - global_position)
		to_tgt.y = 0.0
		var aim_angle_deg = rad_to_deg(fwd.angle_to(to_tgt)) if (fwd.length_squared() > 0.01 and to_tgt.length_squared() > 0.01) else 0.0
		if aim_angle_deg <= aim_tolerance_angle_deg:
			_process_burst_combat(delta)
		else:
			# Ainda virando o corpo para mirar: não atira enquanto estiver desalinhado
			_burst_shots_fired = 0
	else:
		_burst_shots_fired = 0
		_burst_pause_timer = max(_burst_pause_timer - delta, 0.0)


func _process_burst_combat(delta: float) -> void:
	if _burst_pause_timer > 0.0:
		_burst_pause_timer -= delta
		return

	if _fire_cooldown <= 0.0:
		_fire_at_target()
		_burst_shots_fired += 1

		# Intervalo dinâmico entre disparos com jitter orgânico individual
		_fire_cooldown = _fire_interval * randf_range(0.92, 1.08)

		if _burst_shots_fired >= _burst_max_shots:
			_burst_shots_fired = 0
			var dist_to_tgt = global_position.distance_to(target_combatant.global_position)
			var pause_mult = 1.0
			if dist_to_tgt < 6.0:
				_burst_max_shots = randi_range(_burst_base_shots, _burst_base_shots + 2)
				pause_mult = 0.75
			elif dist_to_tgt > 16.0:
				_burst_max_shots = randi_range(maxi(2, _burst_base_shots - 1), _burst_base_shots)
				pause_mult = 1.35
			else:
				_burst_max_shots = randi_range(_burst_base_shots, _burst_base_shots + 1)
				pause_mult = 1.0
			_burst_pause_timer = _burst_pause_base * pause_mult * randf_range(0.85, 1.15)
			_fire_cooldown = _burst_pause_timer


func _is_target_valid() -> bool:
	if target_combatant == null or not is_instance_valid(target_combatant):
		return false
	if target_combatant.has_node("HealthComponent"):
		var hp = target_combatant.get_node("HealthComponent") as HealthComponent
		if hp and hp.current_health <= 0:
			return false
	var state = target_combatant.get("ai_state")
	if state != null and state == AIState.DEAD:
		return false
	return true

# ── ESTADO: PROCURANDO ────────────────────────────────────────────────────────
func _state_search(delta: float) -> void:
	_search_timer -= delta
	_navigate_to(_last_known_pos, move_speed, delta)

	if _search_timer <= 0.0 or global_position.distance_to(_last_known_pos) < 2.5:
		target_combatant = null
		ai_state = AIState.PATROL
		enemy_lost_player.emit()

func _transition_to_search() -> void:
	ai_state = AIState.SEARCHING
	_search_timer = 6.0
	target_combatant = null
	enemy_lost_player.emit()

# ── ESTADO: RECUO TÁTICO PARA COBERTURA / CURA (FASE 3) ───────────────────────
func _trigger_tactical_cover_retreat() -> void:
	if not _is_target_valid():
		return

	var enemy_pos = target_combatant.global_position
	var space = get_world_3d().direct_space_state
	if not space:
		return

	var best_dest = Vector3.ZERO
	var min_cost = 99999.0

	# 1. Procurar pontos em nós do grafo que quebrem linha de visão com o inimigo
	var candidates: Array[Vector3] = []
	if _nav_graph:
		for id in _nav_graph.nodes:
			var n_pos: Vector3 = _nav_graph.nodes[id].position
			var d_me = global_position.distance_to(n_pos)
			var d_enemy = enemy_pos.distance_to(n_pos)
			# Distância razoável para fuga: 4m a 18m do bot, sem estar colado no inimigo
			if d_me > 3.5 and d_me < 18.0 and d_enemy > 7.0:
				candidates.append(n_pos)

	for cand in candidates:
		var eye_cand = cand + Vector3(0, 0.8, 0)
		var eye_enemy = enemy_pos + Vector3(0, 1.2, 0)
		var query = PhysicsRayQueryParameters3D.create(eye_enemy, eye_cand, 1, [self, target_combatant])
		var hit = space.intersect_ray(query)
		# Se a linha de tiro do inimigo atingir parede, o ponto oferece cobertura sólida!
		if not hit.is_empty():
			var dist = global_position.distance_to(cand)
			if dist < min_cost:
				min_cost = dist
				best_dest = cand

	if best_dest != Vector3.ZERO:
		_flee_cover_dest = best_dest
		_is_fleeing_to_heal = true
		_flee_timer = randf_range(4.5, 6.5)
		is_crouching = false
		ai_state = AIState.RETREAT_HEAL
		_invalidate_path()

func _state_retreat_heal(delta: float) -> void:
	_flee_timer -= delta

	# Checar se a saúde regenerou suficientemente (CoD Health Regen) ou o tempo expirou
	var hp_comp = get_node_or_null("HealthComponent") as HealthComponent
	var hp_val = hp_comp.current_health if hp_comp else current_health
	if hp_val >= 65 or _flee_timer <= 0.0:
		_is_fleeing_to_heal = false
		is_crouching = false
		if _is_target_valid():
			ai_state = AIState.COMBAT
		else:
			ai_state = AIState.PATROL
		return

	var dist_to_cover = global_position.distance_to(_flee_cover_dest)
	var has_lof = _has_line_of_fire()

	if dist_to_cover > 1.8:
		# Ainda a caminho da cobertura: corre em sprint máximo
		is_crouching = false
		_navigate_to(_flee_cover_dest, sprint_speed * 1.1, delta)
	else:
		# Atingiu a cobertura! Fica agachado e protegido
		is_crouching = true
		velocity.x = lerp(velocity.x, 0.0, 10.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 10.0 * delta)
		if _is_target_valid():
			_face_target(target_combatant.global_position, delta)
			# Se o inimigo o contornar e invadir a cobertura, defende-se!
			if has_lof:
				_process_burst_combat(delta)


# ── NAVEGAÇÃO TÁTICA TOPOLÓGICA & DESVIO DE OBSTÁCULOS ────────────────────────
func _invalidate_path() -> void:
	_current_path.clear()
	_path_idx = 0
	_current_dest = Vector3(9999, 9999, 9999)

func _cast_ray(space: PhysicsDirectSpaceState3D, origin: Vector3, dir: Vector3, dist: float) -> Dictionary:
	var query = PhysicsRayQueryParameters3D.create(origin, origin + dir.normalized() * dist, 1, [self.get_rid()])
	return space.intersect_ray(query)

func _trigger_stuck_recovery(space: PhysicsDirectSpaceState3D) -> void:
	_is_recovering = true
	_recovery_timer = 0.55
	_stuck_frames = 0

	# 0. Se estiver travado em porta/passagem estreita com gargalo, rotaciona lane para corredor aberto (Beco ou Pátio)
	if _nav_graph and _nav_graph.has_method("is_position_near_portal") and _nav_graph.is_position_near_portal(global_position, 2.5):
		assigned_lane = 0 if randf() < 0.65 else 3
		_lane_rotation_count = 0
		_invalidate_path()
		_set_random_patrol_target()
		return

	# 1. Se estiver contra uma parede física, usa a normal da colisão como vetor primário de fuga
	var wall_norm = Vector3.ZERO
	if is_on_wall():
		wall_norm = get_wall_normal()
		wall_norm.y = 0.0
		if wall_norm.length_squared() > 0.01:
			_recovery_dir = wall_norm.normalized()

	# 2. Desengasgo Progressivo: se tiver uma rota ativa com pontos à frente, avança na rota!
	# NUNCA regredir para trás na sala anterior (elimina o efeito ping-pong em portas e cantos)
	if _current_path.size() > 0 and _path_idx < _current_path.size() - 1:
		_path_idx += 1
		var next_pt = _current_path[_path_idx]
		var to_next = (next_pt - global_position).normalized()
		to_next.y = 0.0
		if wall_norm != Vector3.ZERO:
			_recovery_dir = (wall_norm * 0.6 + to_next * 0.7).normalized()
		else:
			_recovery_dir = to_next
		
		# Micro-impulso para descolar da quina e avançar
		velocity.x = _recovery_dir.x * (move_speed * 1.15)
		velocity.z = _recovery_dir.z * (move_speed * 1.15)
		return

	# 3. Se estiver no final da rota, busca o nó visível mais próximo orientado para o objetivo
	if _nav_graph:
		var heading = (_patrol_target - global_position).normalized()
		heading.y = 0.0
		var nearest_node_id = _nav_graph.find_closest_visible_node(global_position, space, self, heading)
		if nearest_node_id != -1 and _nav_graph.nodes.has(nearest_node_id):
			var n_pos = _nav_graph.nodes[nearest_node_id].position
			_recovery_dir = (n_pos - global_position).normalized()
			_recovery_dir.y = 0.0
			_current_dest = n_pos
			_current_path = PackedVector3Array([n_pos])
			_path_idx = 0
			return

	# 4. Fallback caso não haja nó visível
	var bwd_dir = global_transform.basis.z
	var right_dir = global_transform.basis.x
	var ray_r = _cast_ray(space, global_position + Vector3.UP * 0.8, right_dir, 1.6)
	var ray_l = _cast_ray(space, global_position + Vector3.UP * 0.8, -right_dir, 1.6)

	if not is_on_wall():
		if ray_r.is_empty():
			_recovery_dir = (right_dir * 0.85 + bwd_dir * 0.5).normalized()
		elif ray_l.is_empty():
			_recovery_dir = (-right_dir * 0.85 + bwd_dir * 0.5).normalized()
		else:
			_recovery_dir = bwd_dir

	if ai_state == AIState.PATROL:
		_set_random_patrol_target()
	else:
		_invalidate_path()


func _navigate_to(target_pos: Vector3, speed: float, delta: float) -> void:
	var space = get_world_3d().direct_space_state
	if not space:
		return

	# 1. Recuperação ativa se estiver preso em parede
	if _is_recovering:
		_recovery_timer -= delta
		if _recovery_timer <= 0.0:
			_is_recovering = false
			_invalidate_path()
		else:
			var rec_vx = _recovery_dir.x * (speed * 0.85)
			var rec_vz = _recovery_dir.z * (speed * 0.85)
			velocity.x = lerp(velocity.x, rec_vx, 8.0 * delta)
			velocity.z = lerp(velocity.z, rec_vz, 8.0 * delta)
			_face_target(global_position + _recovery_dir * 3.0, delta)
			return

	# 2. Monitor anti-stuck inteligente por amostragem de deslocamento
	_stuck_timer += delta
	if _stuck_timer >= 0.30:
		_stuck_timer = 0.0
		var h_moved = Vector2(global_position.x - _stuck_sample_pos.x, global_position.z - _stuck_sample_pos.z).length()
		var is_trying_to_move = Vector2(velocity.x, velocity.z).length() > 0.8
		if is_trying_to_move and h_moved < 0.14:
			_stuck_frames += 1
		else:
			_stuck_frames = 0
		_stuck_sample_pos = global_position

		if _stuck_frames >= 3:
			_trigger_stuck_recovery(space)
			return

	# 3. Pathfinding topológico via TacticalNavGraph
	_repath_timer -= delta
	var dest_changed = _current_dest.distance_to(target_pos) > 2.0
	var need_repath = _current_path.is_empty() or dest_changed
	if not need_repath and _repath_timer <= 0.0:
		if ai_state == AIState.COMBAT or _path_idx >= _current_path.size():
			need_repath = true
			_repath_timer = 0.8
		else:
			_repath_timer = 2.5

	if need_repath:
		if _nav_graph:
			_current_path = _nav_graph.get_path_to_target(global_position, target_pos, space, self)
		else:
			_current_path = PackedVector3Array([target_pos])
		_path_idx = 0
		_current_dest = target_pos
		_repath_timer = 0.8 if ai_state == AIState.COMBAT else 2.5

	# 4. Obter ponto atual do caminho com avanço de nó e Doorway/Corridor Funneling
	var current_sub_target = target_pos
	var in_confined = false
	if _nav_graph:
		in_confined = _nav_graph.is_position_near_portal(global_position, 2.5) or _nav_graph.is_position_in_house_or_corridor(global_position, 2.8)

	while _path_idx < _current_path.size():
		var pt = _current_path[_path_idx]
		var dist_to_pt = Vector2(global_position.x - pt.x, global_position.z - pt.z).length()

		var pt_in_confined = in_confined
		if not pt_in_confined and _nav_graph:
			pt_in_confined = _nav_graph.is_position_near_portal(pt, 2.5) or _nav_graph.is_position_in_house_or_corridor(pt, 2.8)

		# Limiar calibrado de avanço para transição suave sem travamento em portas ou quinas
		var arrival_dist = 0.90 if pt_in_confined else 1.40

		if dist_to_pt < arrival_dist:
			if _path_idx < _current_path.size() - 1:
				_path_idx += 1
				continue
		elif is_on_wall() and dist_to_pt < 2.0 and _path_idx < _current_path.size() - 1:
			# Avanço assistido por contato com parede para desengasgar imediatamente
			_path_idx += 1
			continue
		elif not pt_in_confined and _path_idx < _current_path.size() - 1:
			var next_pt = _current_path[_path_idx + 1]
			var seg_vec = (next_pt - pt)
			seg_vec.y = 0.0
			var bot_vec = (global_position - pt)
			bot_vec.y = 0.0
			if seg_vec.length_squared() > 0.1:
				var proj = bot_vec.dot(seg_vec.normalized())
				if proj > 0.35:
					_path_idx += 1
					continue

		current_sub_target = pt

		# Doorway & Corridor Funneling: se estiver em corredor ou porta, mantém-se no centro exato da lane (sem offset lateral)
		if not pt_in_confined and _path_idx < _current_path.size() - 1:
			var seg_dir = (_current_path[_path_idx + 1] - pt).normalized()
			seg_dir.y = 0.0
			if seg_dir.length_squared() > 0.1:
				var perp = Vector3(-seg_dir.z, 0.0, seg_dir.x)
				var desired_offset = perp * (lateral_lane_offset if lateral_lane_offset != 0.0 else (0.45 * (1.0 if bot_id % 2 == 0 else -1.0)))
				var wall_check = _cast_ray(space, pt + Vector3.UP * 0.8, desired_offset.normalized(), desired_offset.length() + 0.4)
				if wall_check.is_empty():
					current_sub_target = pt + desired_offset
				else:
					var half_offset = desired_offset * 0.5
					var half_check = _cast_ray(space, pt + Vector3.UP * 0.8, half_offset.normalized(), half_offset.length() + 0.3)
					if half_check.is_empty():
						current_sub_target = pt + half_offset

				# Checagem de linha direta: garante que o caminho do bot até o ponto offset não raspe na quina
				var to_sub = current_sub_target - global_position
				if to_sub.length() > 0.3:
					var corner_check = _cast_ray(space, global_position + Vector3.UP * 0.8, to_sub.normalized(), to_sub.length() - 0.1)
					if not corner_check.is_empty():
						current_sub_target = pt
		break

	var direct = (current_sub_target - global_position)
	direct.y = 0.0
	if direct.length() < 0.25:
		velocity.x = lerp(velocity.x, 0.0, 10.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 10.0 * delta)
		return

	var move_dir = direct.normalized()

	# 4.1 Separação mútua suave para não colidir com aliados
	var separation = Vector3.ZERO
	var move_speed_multiplier = 1.0
	var all_bots = get_tree().get_nodes_in_group("enemies")
	for other in all_bots:
		if other == self or not is_instance_valid(other) or not (other is CharacterBody3D):
			continue
		if other.get("ai_state") == AIState.DEAD:
			continue
		var to_self = global_position - other.global_position
		to_self.y = 0.0
		var d_other = to_self.length()
		if d_other < 2.8 and d_other > 0.001:
			var dir_to_self = to_self / d_other
			var rep_strength = (1.0 - (d_other / 2.8))
			var fwd_dot = abs(move_dir.dot(dir_to_self))
			if fwd_dot > 0.50 and not in_confined:
				var perp = Vector3(-move_dir.z, 0.0, move_dir.x)
				var my_side = 1.0 if (lateral_sign >= 0.0) else -1.0
				separation += (perp * my_side) * (rep_strength * 2.0)
				if move_dir.dot(-dir_to_self) > 0.65 and d_other < 2.2:
					move_speed_multiplier = minf(move_speed_multiplier, 0.75)
			else:
				separation += dir_to_self * (rep_strength * 1.4)
		elif d_other <= 0.001:
			separation += Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * 1.5

	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p is CharacterBody3D:
			var to_self_p = global_position - p.global_position
			to_self_p.y = 0.0
			var d_p = to_self_p.length()
			if d_p < 2.0 and d_p > 0.001:
				separation += (to_self_p / d_p) * (1.0 - (d_p / 2.0)) * 2.0

	if separation.length_squared() > 0.01:
		move_dir = (move_dir * 0.60 + separation.normalized() * 0.40).normalized()

	# 5. Sistema de Bigodes (Whiskers) com Centralização em Corredores e Doorway Funneling
	var chest_y = Vector3.UP * 0.95
	var knee_y  = Vector3.UP * 0.35

	var forward_chest = _cast_ray(space, global_position + chest_y, move_dir, 1.7 if not in_confined else 1.05)
	var forward_knee  = _cast_ray(space, global_position + knee_y, move_dir, 1.7 if not in_confined else 1.05)
	var forward_hit   = forward_chest if not forward_chest.is_empty() else forward_knee

	var shoulder_r: Dictionary = {}
	var shoulder_l: Dictionary = {}
	var right_hit: Dictionary = {}
	var left_hit: Dictionary = {}
	var wide_r_hit: Dictionary = {}
	var wide_l_hit: Dictionary = {}

	if in_confined:
		# Em corredores e portas: bigodes de ombro estreitos (0.36m) ativos para manter o bot no centro do corredor
		var perp_dir = Vector3(-move_dir.z, 0.0, move_dir.x)
		var shoulder_offset = perp_dir * 0.36
		shoulder_r = _cast_ray(space, global_position + shoulder_offset + chest_y, move_dir, 0.90)
		shoulder_l = _cast_ray(space, global_position - shoulder_offset + chest_y, move_dir, 0.90)
		if not shoulder_r.is_empty() and shoulder_l.is_empty():
			# Aproximou-se da parede direita: corrige suavemente para a esquerda
			move_dir = (move_dir * 0.80 - perp_dir * 0.20).normalized()
		elif not shoulder_l.is_empty() and shoulder_r.is_empty():
			# Aproximou-se da parede esquerda: corrige suavemente para a direita
			move_dir = (move_dir * 0.80 + perp_dir * 0.20).normalized()
	else:
		var perp_dir = Vector3(-move_dir.z, 0.0, move_dir.x)
		var shoulder_offset = perp_dir * 0.32
		shoulder_r = _cast_ray(space, global_position + shoulder_offset + chest_y, move_dir, 1.3)
		shoulder_l = _cast_ray(space, global_position - shoulder_offset + chest_y, move_dir, 1.3)
		right_hit  = _cast_ray(space, global_position + chest_y, move_dir.rotated(Vector3.UP, deg_to_rad(-35.0)), 1.3)
		left_hit   = _cast_ray(space, global_position + chest_y, move_dir.rotated(Vector3.UP, deg_to_rad(35.0)), 1.3)
		wide_r_hit = _cast_ray(space, global_position + chest_y, move_dir.rotated(Vector3.UP, deg_to_rad(-65.0)), 0.9)
		wide_l_hit = _cast_ray(space, global_position + chest_y, move_dir.rotated(Vector3.UP, deg_to_rad(65.0)), 0.9)

	var deflection = Vector3.ZERO
	if not in_confined and (not forward_hit.is_empty() or not shoulder_r.is_empty() or not shoulder_l.is_empty()):
		var obstacle_hit = forward_hit
		if obstacle_hit.is_empty():
			obstacle_hit = shoulder_r if not shoulder_r.is_empty() else shoulder_l
		var norm = obstacle_hit.normal
		var tangent = Vector3(-norm.z, 0.0, norm.x).normalized()
		
		var right_blocked = not right_hit.is_empty() or not wide_r_hit.is_empty() or not shoulder_r.is_empty()
		var left_blocked  = not left_hit.is_empty() or not wide_l_hit.is_empty() or not shoulder_l.is_empty()

		if left_blocked and not right_blocked:
			deflection = tangent if move_dir.dot(tangent) >= 0.0 else -tangent
		elif right_blocked and not left_blocked:
			deflection = -tangent if move_dir.dot(-tangent) >= 0.0 else tangent
		else:
			var preferred_tangent = tangent if lateral_sign >= 0.0 else -tangent
			if move_dir.dot(tangent) > 0.2:
				deflection = tangent
			elif move_dir.dot(-tangent) > 0.2:
				deflection = -tangent
			else:
				deflection = preferred_tangent

		move_dir = deflection.normalized()
	elif not in_confined:
		if not left_hit.is_empty() or not wide_l_hit.is_empty():
			deflection += move_dir.rotated(Vector3.UP, deg_to_rad(-45.0)) * 0.5
		if not right_hit.is_empty() or not wide_r_hit.is_empty():
			deflection += move_dir.rotated(Vector3.UP, deg_to_rad(45.0)) * 0.5

		if deflection.length_squared() > 0.01:
			move_dir = (move_dir * 0.5 + deflection.normalized() * 0.5).normalized()

	# Salto tático de quina (Jump-peeking ao virar esquinas estilo CoD)
	if _jump_cooldown <= 0.0 and is_on_floor() and not is_crouching and speed > 3.0 and not in_confined:
		var is_corner = deflection.length_squared() > 0.08
		var should_jump = false
		if archetype == BotArchetype.RUSHER and (is_corner and randf() < 0.40):
			should_jump = true
		elif archetype == BotArchetype.FLANKER and (is_corner and randf() < 0.25):
			should_jump = true

		if should_jump:
			velocity.y = 4.8
			_jump_cooldown = randf_range(3.5, 6.5)

	velocity.x = lerp(velocity.x, move_dir.x * (speed * move_speed_multiplier), 12.0 * delta)
	velocity.z = lerp(velocity.z, move_dir.z * (speed * move_speed_multiplier), 12.0 * delta)
	if ai_state != AIState.COMBAT and ai_state != AIState.ALERT:
		var h_vel = Vector3(velocity.x, 0.0, velocity.z)
		if h_vel.length() > 0.5:
			_face_target(global_position + h_vel.normalized() * 3.0, delta)
		else:
			_face_target(global_position + move_dir * 3.0, delta)




func _face_target(target_pos: Vector3, delta: float, instant: bool = false) -> void:
	var flat_dir = (target_pos - global_position)
	flat_dir.y = 0.0
	if flat_dir.length() < 0.01:
		return
	var target_basis = Basis.looking_at(flat_dir.normalized(), Vector3.UP)
	if instant or delta >= 1.0:
		global_transform.basis = target_basis
		return
	var target_quat  = target_basis.get_rotation_quaternion()
	var current_quat = global_transform.basis.get_rotation_quaternion()
	# Variação sutil por bot para evitar rotação 100% sincronizada (efeito robótico)
	var rot_rate = rotation_speed * (0.90 + float(bot_id % 3) * 0.12)
	global_transform.basis = Basis(current_quat.slerp(target_quat, clampf(rot_rate * delta, 0.0, 1.0)))

# ── DISPARO DE ARMA (ÁUDIO 3D + BALÍSTICA + VISUAL) ──────────────────────────
func _fire_at_target() -> void:
	if not _is_target_valid():
		return

	var h_comp = get_node_or_null("HealthComponent") as HealthComponent
	if h_comp and h_comp.has_method("cancel_spawn_protection"):
		h_comp.cancel_spawn_protection()

	var body_center = global_position + Vector3.UP * 1.35
	var bot_rifle = _cached_bot_rifle if _cached_bot_rifle else find_child("BotRifle3D", true, false)
	var muzzle_pos = body_center
	if bot_rifle and bot_rifle.has_node("MuzzleFlash"):
		muzzle_pos = bot_rifle.get_node("MuzzleFlash").global_position
	elif gun_muzzle:
		muzzle_pos = gun_muzzle.global_position

	var space = get_world_3d().direct_space_state
	if not space:
		return

	# Checa se a ponta da arma está inserida dentro de uma parede/esquina
	if muzzle_pos != body_center:
		var m_chk = space.intersect_ray(PhysicsRayQueryParameters3D.create(body_center, muzzle_pos, 1, [self.get_rid()]))
		if not m_chk.is_empty():
			# Arma enfiada na parede: impede disparo mágico através de quina
			return

	var target_y_offset = 1.55 if (randf() < headshot_chance) else 1.10
	var target_center = target_combatant.global_position + Vector3.UP * target_y_offset

	# Dispersão balística: usa accuracy_aim no combate armado para tiros precisos e letais
	var cur_accuracy = accuracy_aim if (ai_state == AIState.COMBAT or ai_state == AIState.ALERT) else accuracy_hip
	var aim_dir = (target_center - body_center).normalized()
	aim_dir = aim_dir.rotated(Vector3.UP, randf_range(-cur_accuracy, cur_accuracy))
	aim_dir = aim_dir.rotated(aim_dir.cross(Vector3.UP).normalized(), randf_range(-cur_accuracy, cur_accuracy))

	# Efeito visual da arma (Flash de cano + Recoil no modelo 3D)
	if bot_rifle and bot_rifle.has_method("play_shoot_effect"):
		bot_rifle.play_shoot_effect()

	_play_gunfire_sound()
	# Propagação acústica do tiro para outros bots no mapa e radar do Mini-Mapa
	var is_silenced = (bot_rifle != null and ("has_silencer" in bot_rifle) and bot_rifle.has_silencer)
	get_tree().call_group("enemies", "notify_gunshot_heard", global_position, self.team, is_silenced)
	if not is_silenced:
		get_tree().call_group("minimap", "notify_gunshot", global_position, self.team, false)

	# Raycast do projétil partindo da cápsula protegida do corpo (Layer 1=Geometria, 2=Hitboxes, 3=Players, 4=Bots)
	var params = PhysicsRayQueryParameters3D.create(body_center, body_center + aim_dir * 120.0, 0b1111, [self.get_rid()])
	params.collide_with_areas = true
	var result = space.intersect_ray(params)

	if result and not result.is_empty():
		var col = result.collider
		var hit_target = null

		if col == target_combatant or (col.get_parent() and col.get_parent() == target_combatant):
			hit_target = target_combatant
		elif col is HitboxComponent:
			var parent_char = col.get_parent()
			while parent_char != null:
				if parent_char is CharacterBody3D and parent_char != self:
					hit_target = parent_char
					break
				parent_char = parent_char.get_parent()
		elif col is PlayerCharacter or (col.get_parent() and col.get_parent() is PlayerCharacter):
			hit_target = col if col is PlayerCharacter else col.get_parent()

		if hit_target:
			var target_team = -1
			if hit_target.has_method("get_team"):
				target_team = hit_target.get_team()
			elif hit_target.get("team") != null:
				target_team = hit_target.get("team")
			elif hit_target.is_in_group("player"):
				var gm = get_node_or_null("/root/GameManager")
				target_team = 0 if (gm and gm.local_player_team == 1) else 1

			var is_ffa = false
			var gmm = get_node_or_null("/root/GameModeManager")
			if not gmm and get_tree() and get_tree().current_scene:
				gmm = get_tree().current_scene.find_child("GameModeManager", true, false)
			if gmm and "game_mode" in gmm and gmm.game_mode == 4:
				is_ffa = true

			if is_ffa or (target_team != self.team or target_team == -1):
				var is_head = false
				if col is HitboxComponent and col.region == HitboxComponent.Region.HEAD:
					is_head = true
				elif col and "head" in col.name.to_lower():
					is_head = true
				elif target_y_offset > 1.4 and randf() < (headshot_chance * 0.7):
					is_head = true

				var dmg = int(damage_per_shot * 1.8) if is_head else damage_per_shot

				# Cancela proteção de spawn no alvo se for alvejado
				if hit_target.has_node("HealthComponent"):
					var thp = hit_target.get_node("HealthComponent") as HealthComponent
					if thp and thp.has_method("cancel_spawn_protection"):
						thp.cancel_spawn_protection()

				if hit_target.has_method("take_damage"):
					hit_target.take_damage(dmg, aim_dir, self)
				elif hit_target.has_node("HealthComponent"):
					var hp = hit_target.get_node("HealthComponent") as HealthComponent
					if hp:
						hp.take_damage(dmg, aim_dir, "Head" if is_head else "Chest", self)

	_fire_cooldown = _fire_interval

func _play_gunfire_sound() -> void:
	if gun_audio and gun_audio.stream:
		gun_audio.pitch_scale = randf_range(0.95, 1.05)
		gun_audio.play()
	else:
		var am = get_node_or_null("/root/AudioManager")
		if am and ResourceLoader.exists("res://assets/audio/weapons/ak47_shot.wav"):
			var shot_snd = load("res://assets/audio/weapons/ak47_shot.wav") as AudioStream
			am.play_sfx(shot_snd, -3.0, randf_range(0.95, 1.05))

# ── PERCEPÇÃO ACÚSTICA DE DISPAROS ────────────────────────────────────────────
func notify_gunshot_heard(gun_pos: Vector3, shooter_team: int, is_silenced: bool = false) -> void:
	if ai_state == AIState.DEAD:
		return
	# Se já está engajado ativamente em combate armado contra um alvo válido com linha de tiro, mantém o foco
	if ai_state == AIState.COMBAT and _is_target_valid() and _has_line_of_fire():
		return

	# Checar se o modo é Free-For-All (FFA)
	var is_ffa = false
	var gmm = get_node_or_null("/root/GameModeManager")
	if not gmm and get_tree() and get_tree().current_scene:
		gmm = get_tree().current_scene.find_child("GameModeManager", true, false)
	if gmm and "game_mode" in gmm and gmm.game_mode == 4:
		is_ffa = true

	# 1. TIROS DE ALIADOS:
	if not is_ffa and shooter_team == self.team and shooter_team != -1:
		# Aliados NUNCA devem virar para encarar o companheiro/jogador que atirou!
		# Mantêm o foco tático para frente em sua respectiva lane.
		return

	# 2. TIROS DE INIMIGOS:
	var dist = global_position.distance_to(gun_pos)
	# Distância acústica máxima: 24m para tiros normais, 8m para armas com silenciador
	var max_acoustic_dist = 8.0 if is_silenced else 24.0
	if dist > max_acoustic_dist:
		return

	# Adiciona dispersão tática de áudio (ruído humano de percepção sonora aproximada)
	var noise_offset = Vector3(randf_range(-3.5, 3.5), 0.0, randf_range(-3.5, 3.5))
	var sound_target = gun_pos + noise_offset

	# Se estiver em patrulha ou busca, investiga o setor do confronto em estado de alerta
	if ai_state == AIState.PATROL or ai_state == AIState.SEARCHING:
		ai_state = AIState.ALERT
		_last_known_pos = sound_target
		_search_timer = randf_range(4.0, 6.5)
		if dist < 16.0:
			_patrol_target = sound_target
			_patrol_timer = randf_range(3.5, 6.0)
			_invalidate_path()

# ── REAÇÃO A ATAQUE (RETALIAÇÃO IMEDIATA) ────────────────────────────────────
func notify_attacked(attacker: Node, dmg: int = 0) -> void:
	if ai_state == AIState.DEAD:
		return
	last_attacker = attacker
	var atk_team = -1
	if attacker.has_method("get_team"):
		atk_team = attacker.get_team()
	elif attacker.get("team") != null:
		atk_team = attacker.get("team")
	elif attacker.is_in_group("player"):
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			atk_team = 0 if gm.local_player_team == 1 else 1
		else:
			atk_team = 0
	last_attacker_team = atk_team

	# Em partidas de time, aliados não iniciam combate contra fogo amigo acidental
	var is_ffa = false
	if is_inside_tree():
		var gmm = get_node_or_null("/root/GameModeManager")
		if not gmm and get_tree() and get_tree().current_scene:
			gmm = get_tree().current_scene.find_child("GameModeManager", true, false)
		if gmm and "game_mode" in gmm and gmm.game_mode == 4:
			is_ffa = true

	if not is_ffa and atk_team == self.team and atk_team != -1:
		return

	if attacker is CharacterBody3D and is_instance_valid(attacker):
		target_combatant = attacker as CharacterBody3D
		_last_known_pos = attacker.global_position
		_lose_sight_timer = lose_sight_delay
		_reaction_timer = 0.0

		# Giro reflexo instantâneo na direção do tiro para encarar o agressor e revidar imediatamente
		if is_inside_tree():
			_face_target(attacker.global_position, 1.0, true)

		# Notificar esquadrão aliado via Squad Shared Intel para convergência tática
		if is_inside_tree():
			var bm = get_node_or_null("/root/BotManager")
			if not bm and get_tree() and get_tree().current_scene:
				bm = get_tree().current_scene.find_child("BotManager", true, false)
			if bm and bm.has_method("report_enemy_contact"):
				bm.report_enemy_contact(self.team, attacker.global_position)

		# Salto reflexo ao tomar tiro de surpresa
		if _jump_cooldown <= 0.0 and is_on_floor() and not is_crouching and randf() < 0.28:
			velocity.y = 4.4
			_jump_cooldown = randf_range(3.5, 6.0)

		# Fuga para cobertura só ocorre contra jogadores humanos para não atrasar duelos entre bots
		if current_health <= 25 and not _is_fleeing_to_heal and attacker != null and attacker.is_in_group("player"):
			_trigger_tactical_cover_retreat()
		elif not _is_fleeing_to_heal:
			ai_state = AIState.COMBAT

# ── SISTEMA DE DANO & MORTE ──────────────────────────────────────────────────
func _on_health_damage_taken(amount: int, _direction: Vector3) -> void:
	if ai_state == AIState.DEAD:
		return

	var hp = get_node_or_null("HealthComponent") as HealthComponent
	if hp:
		current_health = hp.current_health

	# Duelos entre bots são resolvidos até o fim sem fuga prematura
	if current_health <= 25 and not _is_fleeing_to_heal and current_health > 0 and last_attacker != null and last_attacker.is_in_group("player"):
		_trigger_tactical_cover_retreat()

	# Floating damage number
	if has_node("DamageLabel3D"):
		var lbl = get_node("DamageLabel3D") as Label3D
		lbl.text = "-%d" % amount
		lbl.modulate = Color(1.0, 0.25, 0.2, 1.0)
		var tween = create_tween()
		tween.tween_property(lbl, "position:y", 2.4, 0.25)
		tween.tween_property(lbl, "modulate:a", 0.0, 0.45)

func take_damage(amount: int, direction: Vector3 = Vector3.ZERO, attacker: Node = null) -> void:
	if ai_state == AIState.DEAD:
		return

	# Checagem de fogo amigo (aliados não tomam dano em partidas com times)
	if attacker != null:
		var atk_team = -1
		if attacker.has_method("get_team"):
			atk_team = attacker.get_team()
		elif attacker.get("team") != null:
			atk_team = attacker.get("team")
		elif attacker.is_in_group("player"):
			if is_inside_tree():
				var gm = get_node_or_null("/root/GameManager")
				atk_team = 0 if (gm and gm.local_player_team == 1) else 1
			else:
				atk_team = 0

		var is_ffa = false
		if is_inside_tree():
			var gmm = get_node_or_null("/root/GameModeManager")
			if not gmm and get_tree() and get_tree().current_scene:
				gmm = get_tree().current_scene.find_child("GameModeManager", true, false)
			if gmm and "game_mode" in gmm and gmm.game_mode == 4:
				is_ffa = true

		if not is_ffa and atk_team == self.team and atk_team != -1:
			return

	if attacker != null:
		notify_attacked(attacker, amount)
	elif last_attacker != null and is_instance_valid(last_attacker):
		notify_attacked(last_attacker, amount)

	var hp = get_node_or_null("HealthComponent") as HealthComponent
	if hp:
		hp.take_damage(amount, direction, "Chest", attacker)
		current_health = hp.current_health
	else:
		current_health = clampi(current_health - amount, 0, max_health)
		_on_health_damage_taken(amount, direction)
		if current_health <= 0:
			_die(direction)

func _die(_direction: Vector3, hit_bone: String = "Chest") -> void:
	if ai_state == AIState.DEAD:
		return
	ai_state = AIState.DEAD
	velocity = Vector3.ZERO
	set_physics_process(false)

	if _nameplate:
		_nameplate.visible = false

	# Animação cinematográfica de morte do Mixamo
	if _anim_player and _anim_player.has_animation("die"):
		_anim_player.play("die", 0.15)
	elif has_node("VisualRoot"):
		var tween = create_tween()
		tween.tween_property(get_node("VisualRoot"), "rotation:x", deg_to_rad(-85), 0.35)

	# Desativar colisão
	if has_node("CollisionShape3D"):
		get_node("CollisionShape3D").set_deferred("disabled", true)

	# Registrar pontuação (SUB-5: Identificar corretamente se o killer foi o jogador local)
	var killer_team = 0 if team == 1 else 1
	var killer_id = 1
	if last_attacker != null and is_instance_valid(last_attacker):
		killer_team = last_attacker_team if last_attacker_team != -1 else killer_team
		if last_attacker.is_in_group("player") or last_attacker is PlayerCharacter:
			killer_id = 1
		elif last_attacker is EnemyAI or last_attacker.is_in_group("enemies"):
			if "bot_id" in last_attacker and last_attacker.bot_id > 0:
				killer_id = last_attacker.bot_id
			else:
				killer_id = last_attacker.get_instance_id()
		else:
			killer_id = 1
	var is_head = (hit_bone.to_lower().contains("head") or hit_bone == "Head")
	var is_cr = false
	var is_sl = false
	var dist = 0.0
	if last_attacker != null and is_instance_valid(last_attacker) and last_attacker is Node3D:
		dist = global_position.distance_to(last_attacker.global_position)
		if "state_machine" in last_attacker and last_attacker.state_machine:
			var st = last_attacker.state_machine.current_state
			is_cr = (st == MovementStateMachine.State.CROUCH or st == MovementStateMachine.State.PRONE)
			is_sl = (st == MovementStateMachine.State.SLIDE)
		elif last_attacker.is_in_group("player") and Input.is_action_pressed("crouch"):
			is_cr = true

	var my_bot_id = bot_id if bot_id > 0 else get_instance_id()
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("register_team_kill"):
		gm.register_team_kill(killer_team, team, killer_id, my_bot_id, is_head, is_cr, is_sl, dist)

	enemy_died.emit(self)
	await get_tree().create_timer(4.0).timeout
	queue_free()
