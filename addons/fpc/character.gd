# COPYRIGHT Colormatic Studios
# MIT license
# Quality Godot First Person Controller v2


extends CharacterBody3D
class_name Character


#region Character Export Group

## The settings for the character's movement and feel.
@export_category("Character")
## The speed that the character moves at without crouching or sprinting.
@export var base_speed : float = 3.0
## The speed that the character moves at when sprinting.
@export var sprint_speed : float = 6.0
## The speed that the character moves at when crouching.
@export var crouch_speed : float = 1.0

## How fast the character speeds up and slows down when Motion Smoothing is on.
@export var acceleration : float = 10.0
## How high the player jumps.
@export var jump_velocity : float = 4.5
## Maximum step height the character can automatically climb (curbs, stairs, ledges).
@export var max_step_height : float = 0.40
## How far the player turns when the mouse is moved.
@export var mouse_sensitivity : float = 0.1
## Invert the X axis input for the camera.
@export var invert_camera_x_axis : bool = false
## Invert the Y axis input for the camera.
@export var invert_camera_y_axis : bool = false
## Whether the player can use movement inputs. Does not stop outside forces or jumping. See Jumping Enabled.
@export var immobile : bool = false
## The reticle file to import at runtime. By default are in res://addons/fpc/reticles/. Set to an empty string to remove.
@export_file var default_reticle
## ADS (Aim Down Sights) amount [0.0 to 1.0]
@export var ads_amount : float = 0.0

#endregion

#region Nodes Export Group

@export_group("Nodes")
## A reference to the camera for use in the character script. This is the parent node to the camera and is rotated instead of the camera for mouse input.
@export var HEAD : Node3D
## A reference to the camera for use in the character script.
@export var CAMERA : Camera3D
## A reference to the headbob animation for use in the character script.
@export var HEADBOB_ANIMATION : AnimationPlayer
## A reference to the jump animation for use in the character script.
@export var JUMP_ANIMATION : AnimationPlayer
## A reference to the crouch animation for use in the character script.
@export var CROUCH_ANIMATION : AnimationPlayer
## A reference to the the player's collision shape for use in the character script.
@export var COLLISION_MESH : CollisionShape3D

#endregion

#region Controls Export Group

# We are using UI controls because they are built into Godot Engine so they can be used right away
@export_group("Controls")
## Use the Input Map to map a mouse/keyboard input to an action and add a reference to it to this dictionary to be used in the script.
@export var controls : Dictionary = {
	LEFT = "ui_left",
	RIGHT = "ui_right",
	FORWARD = "ui_up",
	BACKWARD = "ui_down",
	JUMP = "ui_accept",
	CROUCH = "crouch",
	SPRINT = "sprint",
	PAUSE = "ui_cancel"
	}
@export_subgroup("Controller Specific")
## This only affects how the camera is handled, the rest should be covered by adding controller inputs to the existing actions in the Input Map.
@export var controller_support : bool = false
## Use the Input Map to map a controller input to an action and add a reference to it to this dictionary to be used in the script.
@export var controller_controls : Dictionary = {
	LOOK_LEFT = "look_left",
	LOOK_RIGHT = "look_right",
	LOOK_UP = "look_up",
	LOOK_DOWN = "look_down"
	}
## The sensitivity of the analog stick that controls camera rotation. Lower is less sensitive and higher is more sensitive.
@export_range(0.001, 0.1, 0.001) var look_sensitivity : float = 0.035

#endregion

#region Feature Settings Export Group

@export_group("Feature Settings")
## Enable or disable jumping. Useful for restrictive storytelling environments.
@export var jumping_enabled : bool = true
## Whether the player can move in the air or not.
@export var in_air_momentum : bool = true
## Smooths the feel of walking.
@export var motion_smoothing : bool = true
## Enables or disables sprinting.
@export var sprint_enabled : bool = true
## Toggles the sprinting state when button is pressed or requires the player to hold the button down to remain sprinting.
@export_enum("Hold to Sprint", "Toggle Sprint") var sprint_mode : int = 0
## Enables or disables crouching.
@export var crouch_enabled : bool = true
## Toggles the crouch state when button is pressed or requires the player to hold the button down to remain crouched.
@export_enum("Hold to Crouch", "Toggle Crouch") var crouch_mode : int = 0
## Wether sprinting should effect FOV.
@export var dynamic_fov : bool = true
## If the player holds down the jump button, should the player keep hopping.
@export var continuous_jumping : bool = true
## Enables the view bobbing animation.
@export var view_bobbing : bool = true
## Enables an immersive animation when the player jumps and hits the ground.
@export var view_tilting : bool = false
## Enables an immersive "view tilting" effect when the player turns their head.
@export var jump_animation : bool = true
## This determines wether the player can use the pause button, not wether the game will actually pause.
@export var pausing_enabled : bool = true
## Use with caution.
@export var gravity_enabled : bool = true

#endregion

#region Tactical Sprint Export Group

@export_group("Tactical Sprint")
## Corrida tática estilo CoD MW: toque duplo no Shift durante a corrida (arma levantada, mais rápido, tempo limitado).
@export var tac_sprint_enabled : bool = true
## Multiplicador sobre a velocidade de corrida normal.
@export var tac_sprint_speed_mult : float = 1.28
## Duração máxima (s) com a barra cheia.
@export var tac_sprint_duration : float = 3.0
## Tempo (s) para a barra recarregar do zero ao cheio.
@export var tac_sprint_recharge : float = 4.0
## Carga mínima (0-1) para poder entrar de novo.
@export_range(0.0, 1.0) var tac_sprint_min_energy : float = 0.35
## Janela (s) entre soltar e apertar o Shift de novo para contar como toque duplo.
@export var tac_sprint_double_tap : float = 0.32

#endregion

#region Prone, Lean & Mantle Export Group

@export_group("Prone, Lean & Mantle")
## Deitar (Z): velocidade rastejando.
@export var prone_enabled : bool = true
@export var prone_speed : float = 0.9
## Inclinar (Q/E): ângulo da cabeça e deslocamento lateral da câmera.
@export var lean_enabled : bool = true
@export var lean_angle_deg : float = 13.0
@export var lean_offset : float = 0.32
## Escalar (Espaço perto de uma borda): alturas mínima e máxima (m, a partir dos pés).
@export var mantle_enabled : bool = true
@export var mantle_min_height : float = 0.45
@export var mantle_max_height : float = 2.1

#endregion

#region Member Variable Initialization

# These are variables used in this script that don't need to be exposed in the editor.
var speed : float = base_speed
var current_speed : float = 0.0
# States: normal, crouching, sprinting
var state : String = "normal"
var low_ceiling : bool = false # This is for when the ceiling is too low and the player needs to crouch.
var was_on_floor : bool = true # Was the player on the floor last frame (for landing animation)

# The reticle should always have a Control node as the root
var RETICLE : Control

# Accumulates mouse input until the next camera rotation (on Web, only the latest event, see web_mouse_workaround)
var mouse_input : Vector2 = Vector2(0,0)

# Workaround for camera jumps in web exports (6dfad6e): in Chrome on Windows, pointer lock sometimes reports false
# mouse motion of almost half the window size in one event. On Web, input accumulation is disabled (see _ready) and
# only the latest mouse motion event is used (see _unhandled_input). This hides most of the false motion, but also
# loses real motion when several events arrive before the next camera rotation.
var web_mouse_workaround : bool = OS.get_name() == "Web"

# View tilting measures the head turn over intervals of at least 1/60 s and one frame (see _handle_head_rotation)
var tilt_turned : float = 0.0
var tilt_time : float = 0.0
var target_tilt : float = 0.0

# Stores horizontal movement input
var input_dir : Vector2 = Vector2.ZERO

# Corrida tática: estado, barra (0-1) e pose suavizada (0-1) usada pela arma, câmera e FOV
var tac_sprinting : bool = false
var tac_sprint_energy : float = 1.0
var tac_sprint_pose : float = 0.0
var _sprint_release_time : float = -10.0
var _sprint_blocked_until_repress : bool = false
# Alturas de postura (cabeça, centro e altura da cápsula). Em pé/agachado seguem a animação "crouch";
# deitar (e sair do deitado) é interpolado por código.
const STANCE_STAND  := Vector3(1.5, 1.0, 2.0)
const STANCE_CROUCH := Vector3(1.12508, 0.75, 1.5)
const STANCE_PRONE  := Vector3(0.42, 0.39, 0.78)
var _stance_lerp_active : bool = false
var _stance_from : Vector3 = STANCE_STAND
var _stance_to : Vector3 = STANCE_STAND
var _stance_t : float = 0.0
var _stance_dur : float = 0.4
# Inclinação: -1 (esquerda) .. 1 (direita), suavizada e limitada por paredes
var lean_amount : float = 0.0
# Escalada
var mantling : bool = false
var _mantle_from : Vector3
var _mantle_mid : Vector3
var _mantle_to : Vector3
var _mantle_t : float = 0.0
var _mantle_dur : float = 0.4
# Rotação extra da câmera (pitch, roll) somada pelo jogador (ex.: tranco de dano)
var cam_extra_rot : Vector2 = Vector2.ZERO
# Mergulho da câmera (mola) ao entrar/sair da corrida tática
var _tac_dip : float = 0.0
var _tac_dip_v : float = 0.0
# Whether or not the player is moving
var moving : bool = false

# Foley Audio
var _footstep_timer : float = 0.0
var _footstep_stream : AudioStream = preload("res://assets/audio/foley/footstep.wav")
var _audio_player : AudioStreamPlayer3D = null

# Procedural Soldier Animation (Shadow & Lower Body Legs)
var _shadow_skel : Skeleton3D = null
var _b_l_arm : int = -1
var _b_r_arm : int = -1
var _b_l_forearm : int = -1
var _b_r_forearm : int = -1
var _b_l_leg : int = -1
var _b_r_leg : int = -1
var _b_l_knee : int = -1
var _b_r_knee : int = -1
var _stride_phase : float = 0.0

# Procedural Camera Bobbing (Balanço tático e suave estilo MW3/CoD)
var _bob_phase : float = 0.0
var _bob_offset : Vector3 = Vector3.ZERO
var _bob_roll : float = 0.0

#endregion



#region Main Control Flow

func _ready() -> void:
	# Capturar mouse somente se nenhuma tela de seleção de classe / menu estiver ativa
	var ccs = get_tree().root.find_child("ChooseClassScreen", true, false) if (is_inside_tree() and get_tree() and get_tree().root) else null
	if ccs and ccs.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		immobile = true
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	HEAD.rotation.y = 0.0

	# With physics interpolation, the head is rotated every rendered frame (see _process), so it must not be
	# physics-interpolated itself. It still follows the interpolated body. A mode set in the scene is kept.
	if HEAD.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_INHERIT:
		HEAD.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	if default_reticle:
		change_reticle(default_reticle)

	if CAMERA:
		CAMERA.near = 0.01

	# Cópias próprias da cápsula/malha: os sub-recursos da cena são compartilhados entre jogadores,
	# e agachar/deitar mudaria a colisão de todos
	if COLLISION_MESH and COLLISION_MESH.shape:
		COLLISION_MESH.shape = COLLISION_MESH.shape.duplicate()
	var body_mesh := get_node_or_null("Mesh") as MeshInstance3D
	if body_mesh and body_mesh.mesh:
		body_mesh.mesh = body_mesh.mesh.duplicate()

	_initialize_animations()
	_check_controls()
	_enter_normal_state()

	# Configurar Sombra Tática Realista de Soldado (Opção 1 - Padrão MW3 / Black Ops 1)
	var shadow_soldier = get_node_or_null("ShadowSoldier")
	if shadow_soldier:
		_setup_shadow_soldier(shadow_soldier)

	if web_mouse_workaround:
		Input.set_use_accumulated_input(false)


func _process(delta : float) -> void:
	if pausing_enabled:
		_handle_pausing()

	# With physics interpolation, the body is drawn between physics ticks, so the camera is rotated every rendered frame.
	# Without it, or if the head is interpolated (a mode set in the scene), the camera is rotated on physics ticks.
	if is_physics_interpolated_and_enabled() and not HEAD.is_physics_interpolated():
		_handle_head_rotation(delta)

	if dynamic_fov: # This may be changed to an AnimationPlayer
		_update_camera_fov()

	if view_bobbing:
		_update_head_bob(delta)

	_update_debug_menu_per_frame()


func _physics_process(delta : float) -> void:
	if not is_on_floor() and gravity_enabled:
		velocity += get_gravity() * delta
	elif gravity_enabled:
		if velocity.y < 0.0:
			velocity.y = -0.5 # Força downward para firme aderência ao chão

	if mantling:
		_update_mantle(delta)
		current_speed = 0.0
		if not is_physics_interpolated_and_enabled() or HEAD.is_physics_interpolated():
			_handle_head_rotation(delta)
		_update_lean(delta)
		was_on_floor = true
		return

	_handle_jumping()

	input_dir = Vector2.ZERO

	if not immobile: # Immobility works by interrupting user input, so other forces can still be applied to the player
		input_dir = Input.get_vector(controls.LEFT, controls.RIGHT, controls.FORWARD, controls.BACKWARD)

	moving = input_dir != Vector2.ZERO

	_handle_movement(delta, input_dir)
	current_speed = Vector3.ZERO.distance_to(get_real_velocity())

	if not is_physics_interpolated_and_enabled() or HEAD.is_physics_interpolated(): # Otherwise it is rotated in _process
		_handle_head_rotation(delta)

	# The player is not able to stand up if the ceiling is too low
	low_ceiling = $CrouchCeilingDetection.is_colliding()

	# ADS Aim Handling
	var is_aiming = Input.is_action_pressed("ads") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var ads_target = 1.0 if is_aiming else 0.0
	ads_amount = move_toward(ads_amount, ads_target, delta * 6.0)

	if RETICLE:
		RETICLE.modulate.a = clampf(1.0 - (ads_amount * 1.5), 0.0, 1.0)

	# Footstep Audio Foley
	if is_on_floor() and moving:
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			_play_footstep()
			_footstep_timer = (0.27 if tac_sprinting else 0.32) if state == "sprinting" else 0.52
	else:
		_footstep_timer = 0.1

	_handle_state(moving)
	_handle_tac_sprint(delta)
	_update_stance_lerp(delta)
	_update_lean(delta)
	_update_procedural_stride(delta)

	if jump_animation:
		_play_jump_animation()

	_update_debug_menu_per_tick()

	was_on_floor = is_on_floor() # This must always be at the end of physics_process

func _play_footstep() -> void:
	var pm = get_node_or_null("PerkManager")
	if pm and pm.has_method("get_footstep_volume_multiplier"):
		if pm.get_footstep_volume_multiplier() <= 0.0:
			return # Ninja: Silêncio absoluto nos passos

	if not _audio_player:
		_audio_player = AudioStreamPlayer3D.new()
		_audio_player.bus = "Master"
		_audio_player.max_distance = 25.0
		add_child(_audio_player)
	if _footstep_stream:
		_audio_player.stream = _footstep_stream
		_audio_player.pitch_scale = randf_range(0.92, 1.08)
		_audio_player.play()

#endregion

#region Input Handling

func _handle_jumping() -> void:
	if state == "prone" or immobile:
		return
	# Escalar: Espaço perto de uma borda à frente (no chão ou no meio do pulo)
	if mantle_enabled and Input.is_action_just_pressed(controls.JUMP) and _try_mantle():
		return
	if mantle_enabled and not is_on_floor() and Input.is_action_pressed(controls.JUMP) and velocity.y < 2.5 and _try_mantle():
		return
	if jumping_enabled:
		if continuous_jumping: # Hold down the jump button
			if Input.is_action_pressed(controls.JUMP) and is_on_floor() and !low_ceiling and velocity.y <= 0.0: # Not while still rising, so jumps can't stack
				if jump_animation:
					JUMP_ANIMATION.play("jump", 0.25)
				velocity.y += jump_velocity # Adding instead of setting so jumping on slopes works properly
		else:
			if Input.is_action_just_pressed(controls.JUMP) and is_on_floor() and !low_ceiling and velocity.y <= 0.0:
				if jump_animation:
					JUMP_ANIMATION.play("jump", 0.25)
				velocity.y += jump_velocity


## Multiplicador de velocidade sobreposto pelas subclasses (arma, mira); 1.0 = sem efeito
func _speed_multiplier() -> float:
	return 1.0


func _handle_movement(delta : float, input_dir : Vector2) -> void:
	var direction2D := input_dir.rotated(-rotation.y - HEAD.rotation.y)
	var direction3D := Vector3(direction2D.x, 0, direction2D.y) * _speed_multiplier()

	if in_air_momentum:
		if is_on_floor():
			if motion_smoothing:
				velocity.x = lerp(velocity.x, direction3D.x * speed, acceleration * delta)
				velocity.z = lerp(velocity.z, direction3D.z * speed, acceleration * delta)
			else:
				velocity.x = direction3D.x * speed
				velocity.z = direction3D.z * speed
	else:
		if motion_smoothing:
			velocity.x = lerp(velocity.x, direction3D.x * speed, acceleration * delta)
			velocity.z = lerp(velocity.z, direction3D.z * speed, acceleration * delta)
		else:
			velocity.x = direction3D.x * speed
			velocity.z = direction3D.z * speed

	# Assistência física para subir escadas e degraus automaticamente
	_snap_up_stairs_check(delta)

	move_and_slide()

## Detecta degraus à frente e eleva o personagem suavemente sobre o obstáculo
func _snap_up_stairs_check(delta : float) -> void:
	if not is_on_floor() and not was_on_floor:
		return
	if velocity.y > 0.0: # Não aplicar durante subida de pulo
		return

	var horiz_vel := Vector3(velocity.x, 0.0, velocity.z)
	if horiz_vel.length_squared() < 0.01:
		return

	var motion := horiz_vel * delta
	# Testar se o movimento horizontal colide com um degrau/obstáculo
	if test_move(global_transform, motion):
		var up_col := KinematicCollision3D.new()
		var test_up := Vector3(0.0, max_step_height, 0.0)
		var actual_up := max_step_height
		if test_move(global_transform, test_up, up_col):
			actual_up = up_col.get_travel().y

		# Se há espaço vertical livre suficiente para subir
		if actual_up > 0.04:
			var xform_up := global_transform.translated(Vector3(0.0, actual_up, 0.0))
			var fwd_col := KinematicCollision3D.new()
			# Verificar se no topo o caminho horizontal está livre
			if not test_move(xform_up, motion, fwd_col):
				var xform_fwd := xform_up.translated(motion)
				var down_col := KinematicCollision3D.new()
				var test_down := Vector3(0.0, -actual_up - 0.12, 0.0)
				# Testar para baixo para encontrar a superfície do degrau
				if test_move(xform_fwd, test_down, down_col):
					var n := down_col.get_normal()
					# Se a superfície do degrau for um chão caminhável válido
					if n.angle_to(Vector3.UP) <= floor_max_angle:
						var step_surface_y := xform_fwd.origin.y - down_col.get_travel().length()
						var step_diff := step_surface_y - global_position.y
						if step_diff > 0.005 and step_diff <= max_step_height:
							global_position.y += step_diff
							velocity.y = 0.0


func _handle_head_rotation(delta : float) -> void:
	var yaw_before : float = HEAD.rotation.y # For view tilting, which follows how fast the head turns

	if controller_support:
		# look_sensitivity is the turn in 1/60 s, so it is scaled by delta to keep the stick speed the same at any FPS
		var controller_view_rotation = Input.get_vector(controller_controls.LOOK_DOWN, controller_controls.LOOK_UP, controller_controls.LOOK_RIGHT, controller_controls.LOOK_LEFT) * look_sensitivity * delta * 60.0 # These are inverted because of the nature of 3D rotation.
		if invert_camera_y_axis:
			HEAD.rotation.x += controller_view_rotation.x * -1
		else:
			HEAD.rotation.x += controller_view_rotation.x

		if invert_camera_x_axis:
			HEAD.rotation.y += controller_view_rotation.y * -1
		else:
			HEAD.rotation.y += controller_view_rotation.y

	if view_tilting:
		# The tilt is 1.5x the degrees the head turns in 1/60 s. The turn is measured over intervals of at least 1/60 s
		# and one rendered frame, so the tilt does not depend on the frame rate or on how often the mouse reports motion.
		if delta > 0.0: # At Engine.time_scale 0, turns are not added up, so the tilt does not jump when time resumes
			tilt_turned += rad_to_deg(HEAD.rotation.y - yaw_before) # Not wrapped, so a turn of more than 180° keeps its sign
			tilt_time += delta
		if tilt_time >= maxf(1.0 / 60.0, get_process_delta_time()):
			target_tilt = clampf(tilt_turned / (tilt_time * 60.0) * 1.5, -5.0, 5.0)
			tilt_turned = 0.0
			tilt_time = 0.0
		HEAD.rotation_degrees.z = lerpf(
			HEAD.rotation_degrees.z,
			target_tilt,
			1.0 - exp(-12.0 * delta) # Change -12.0 to adjust tilt responsiveness: lower is floatier, higher is snappier
		)

	mouse_input = Vector2.ZERO
	HEAD.rotation_degrees.x = clamp(HEAD.rotation_degrees.x, -89.0, 89.0)

## kick.x = graus para cima (pitch), kick.y = graus para o lado (yaw). Já vem suavizado pelo WeaponManager.
func apply_recoil(kick: Vector3) -> void:
	if HEAD:
		HEAD.rotation_degrees.x += kick.x
		rotation_degrees.y += kick.y
		HEAD.rotation_degrees.x = clamp(HEAD.rotation_degrees.x, -72.0, 85.0)

func _setup_shadow_soldier(soldier_node: Node) -> void:
	if not soldier_node:
		return

	# Pés e calças (Object_13 e Object_14) visíveis para a câmera E projetam sombra (SHADOW_CASTING_SETTING_ON)
	# Tronco, cabeça e braços (Object_17, Object_18, etc.) apenas projetam sombra (SHADOWS_ONLY) para não clipar a visão
	var vis_list = soldier_node.find_children("*", "VisualInstance3D", true, false)
	for vi in vis_list:
		if vi is GeometryInstance3D:
			vi.visible = true
			var node_name = vi.name.to_lower()
			if "object_13" in node_name or "object_14" in node_name or "shoes" in node_name or "bottoms" in node_name or "leg" in node_name:
				vi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			else:
				vi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

	_shadow_skel = soldier_node.find_child("Skeleton3D", true, false) as Skeleton3D
	if _shadow_skel:
		# Localizar ossos Mixamo (no Godot 4 nomes usam '_' em vez de ':')
		_b_l_arm = _find_soldier_bone(["mixamorig_LeftArm_08", "mixamorig:LeftArm_08", "LeftArm"])
		_b_r_arm = _find_soldier_bone(["mixamorig_RightArm_024", "mixamorig:RightArm_024", "RightArm"])
		_b_l_forearm = _find_soldier_bone(["mixamorig_LeftForeArm_09", "mixamorig:LeftForeArm_09", "LeftForeArm"])
		_b_r_forearm = _find_soldier_bone(["mixamorig_RightForeArm_025", "mixamorig:RightForeArm_025", "RightForeArm"])
		_b_l_leg = _find_soldier_bone(["mixamorig_LeftUpLeg_039", "mixamorig:LeftUpLeg_039", "LeftUpLeg"])
		_b_r_leg = _find_soldier_bone(["mixamorig_RightUpLeg_044", "mixamorig:RightUpLeg_044", "RightUpLeg"])
		_b_l_knee = _find_soldier_bone(["mixamorig_LeftLeg_040", "mixamorig:LeftLeg_040", "LeftLeg"])
		_b_r_knee = _find_soldier_bone(["mixamorig_RightLeg_045", "mixamorig:RightLeg_045", "RightLeg"])

		_apply_tactical_upper_pose()

func _find_soldier_bone(names: Array) -> int:
	if not _shadow_skel:
		return -1
	for bname in names:
		var idx = _shadow_skel.find_bone(bname)
		if idx >= 0:
			return idx
	return -1

func _apply_tactical_upper_pose() -> void:
	if not _shadow_skel:
		return
	# Pose tática com arma em punho para silhueta realista na sombra (elimina o T-pose)
	if _b_l_arm >= 0:
		_shadow_skel.set_bone_pose_rotation(_b_l_arm, Quaternion(Vector3(0, 0, 1), deg_to_rad(-70)) * Quaternion(Vector3(1, 0, 0), deg_to_rad(25)))
	if _b_r_arm >= 0:
		_shadow_skel.set_bone_pose_rotation(_b_r_arm, Quaternion(Vector3(0, 0, 1), deg_to_rad(70)) * Quaternion(Vector3(1, 0, 0), deg_to_rad(25)))
	if _b_l_forearm >= 0:
		_shadow_skel.set_bone_pose_rotation(_b_l_forearm, Quaternion(Vector3(0, 1, 0), deg_to_rad(30)))
	if _b_r_forearm >= 0:
		_shadow_skel.set_bone_pose_rotation(_b_r_forearm, Quaternion(Vector3(0, -1, 0), deg_to_rad(30)))

func _update_procedural_stride(delta: float) -> void:
	if not _shadow_skel:
		return

	if is_on_floor() and moving and current_speed > 0.2:
		var stride_freq = 9.0 if state == "sprinting" else 6.5
		var speed_factor = clampf(current_speed / maxf(speed, 1.0), 0.3, 1.5)
		_stride_phase += delta * stride_freq * speed_factor

		var max_swing = deg_to_rad(26.0 if state == "sprinting" else 20.0)
		var swing = sin(_stride_phase) * max_swing

		# Flexão natural dos joelhos durante a passada (joelho dobra ao recuar a perna)
		var knee_l = maxf(0.0, -sin(_stride_phase)) * deg_to_rad(35.0)
		var knee_r = maxf(0.0, sin(_stride_phase)) * deg_to_rad(35.0)

		if _b_l_leg >= 0:
			_shadow_skel.set_bone_pose_rotation(_b_l_leg, Quaternion(Vector3(1, 0, 0), swing))
		if _b_r_leg >= 0:
			_shadow_skel.set_bone_pose_rotation(_b_r_leg, Quaternion(Vector3(1, 0, 0), -swing))
		if _b_l_knee >= 0:
			_shadow_skel.set_bone_pose_rotation(_b_l_knee, Quaternion(Vector3(1, 0, 0), knee_l))
		if _b_r_knee >= 0:
			_shadow_skel.set_bone_pose_rotation(_b_r_knee, Quaternion(Vector3(1, 0, 0), knee_r))
	else:
		# Transição suave para postura de repouso (em pé)
		if _b_l_leg >= 0:
			_shadow_skel.set_bone_pose_rotation(_b_l_leg, _shadow_skel.get_bone_pose_rotation(_b_l_leg).slerp(Quaternion.IDENTITY, delta * 10.0))
		if _b_r_leg >= 0:
			_shadow_skel.set_bone_pose_rotation(_b_r_leg, _shadow_skel.get_bone_pose_rotation(_b_r_leg).slerp(Quaternion.IDENTITY, delta * 10.0))
		if _b_l_knee >= 0:
			_shadow_skel.set_bone_pose_rotation(_b_l_knee, _shadow_skel.get_bone_pose_rotation(_b_l_knee).slerp(Quaternion.IDENTITY, delta * 10.0))
		if _b_r_knee >= 0:
			_shadow_skel.set_bone_pose_rotation(_b_r_knee, _shadow_skel.get_bone_pose_rotation(_b_r_knee).slerp(Quaternion.IDENTITY, delta * 10.0))


func _check_controls() -> void: # If you add a control, you might want to add a check for it here.
	# Auto-detect standard FPS input actions if present in project InputMap
	if InputMap.has_action("move_left") and controls.LEFT == "ui_left":
		controls.LEFT = "move_left"
	if InputMap.has_action("move_right") and controls.RIGHT == "ui_right":
		controls.RIGHT = "move_right"
	if InputMap.has_action("move_forward") and controls.FORWARD == "ui_up":
		controls.FORWARD = "move_forward"
	if InputMap.has_action("move_backward") and controls.BACKWARD == "ui_down":
		controls.BACKWARD = "move_backward"
	if InputMap.has_action("jump") and controls.JUMP == "ui_accept":
		controls.JUMP = "jump"
	if InputMap.has_action("crouch") and controls.CROUCH == "crouch":
		controls.CROUCH = "crouch"
	if InputMap.has_action("sprint") and controls.SPRINT == "sprint":
		controls.SPRINT = "sprint"
	if InputMap.has_action("pause") and controls.PAUSE == "ui_cancel":
		controls.PAUSE = "pause"

	# The actions are being disabled so the engine doesn't halt the entire game in debug mode
	if !InputMap.has_action(controls.JUMP):
		push_error("No control mapped for jumping. Please add an input map control. Disabling jump.")
		jumping_enabled = false
	if !InputMap.has_action(controls.LEFT):
		push_error("No control mapped for move left. Please add an input map control. Disabling movement.")
		immobile = true
	if !InputMap.has_action(controls.RIGHT):
		push_error("No control mapped for move right. Please add an input map control. Disabling movement.")
		immobile = true
	if !InputMap.has_action(controls.FORWARD):
		push_error("No control mapped for move forward. Please add an input map control. Disabling movement.")
		immobile = true
	if !InputMap.has_action(controls.BACKWARD):
		push_error("No control mapped for move backward. Please add an input map control. Disabling movement.")
		immobile = true
	if !InputMap.has_action(controls.PAUSE):
		push_error("No control mapped for pause. Please add an input map control. Disabling pausing.")
		pausing_enabled = false
	if !InputMap.has_action(controls.CROUCH):
		push_error("No control mapped for crouch. Please add an input map control. Disabling crouching.")
		crouch_enabled = false
	if !InputMap.has_action(controls.SPRINT):
		push_error("No control mapped for sprint. Please add an input map control. Disabling sprinting.")
		sprint_enabled = false

#endregion

#region State Handling

func _handle_state(moving : bool) -> void:
	# ── Deitar (Z) ────────────────────────────────────────────────────────────
	if prone_enabled and InputMap.has_action("prone") and Input.is_action_just_pressed("prone") and not immobile:
		if state == "prone":
			if not _try_leave_prone("normal"):
				_try_leave_prone("crouching")
		elif is_on_floor():
			_enter_prone_state()
	if state == "prone":
		if Input.is_action_just_pressed(controls.CROUCH) or Input.is_action_just_pressed(controls.JUMP):
			_try_leave_prone("crouching")
		elif sprint_enabled and Input.is_action_just_pressed(controls.SPRINT) and moving:
			if _try_leave_prone("normal"):
				_enter_sprint_state()
		return
	if _sprint_blocked_until_repress and (Input.is_action_just_pressed(controls.SPRINT) or not Input.is_action_pressed(controls.SPRINT)):
		_sprint_blocked_until_repress = false
	if sprint_enabled:
		var can_sprint = state != "crouching" and ads_amount < 0.3 and not _sprint_blocked_until_repress
		if sprint_mode == 0:
			if Input.is_action_pressed(controls.SPRINT) and can_sprint:
				if moving:
					if state != "sprinting":
						_enter_sprint_state()
				else:
					if state == "sprinting":
						_enter_normal_state()
			elif state == "sprinting":
				_enter_normal_state()
		elif sprint_mode == 1:
			if moving and can_sprint:
				# If the player is holding sprint before moving, handle that scenario
				if Input.is_action_pressed(controls.SPRINT) and state == "normal":
					_enter_sprint_state()
				if Input.is_action_just_pressed(controls.SPRINT):
					match state:
						"normal":
							_enter_sprint_state()
						"sprinting":
							if tac_sprint_enabled and not tac_sprinting and input_dir.y < -0.5 and tac_sprint_energy >= tac_sprint_min_energy:
								_start_tac_sprint()
							else:
								_enter_normal_state()
			elif state == "sprinting":
				_enter_normal_state()

	if crouch_enabled:
		if crouch_mode == 0:
			if Input.is_action_pressed(controls.CROUCH) and state != "sprinting":
				if state != "crouching":
					_enter_crouch_state()
			elif state == "crouching" and !$CrouchCeilingDetection.is_colliding():
				_enter_normal_state()
		elif crouch_mode == 1:
			if Input.is_action_just_pressed(controls.CROUCH):
				match state:
					"normal":
						_enter_crouch_state()
					"crouching":
						if !$CrouchCeilingDetection.is_colliding():
							_enter_normal_state()


# Any enter state function should only be called once when you want to enter that state, not every frame.
func _enter_normal_state() -> void:
	#print("entering normal state")
	var prev_state = state
	if prev_state == "prone" or _stance_lerp_active:
		_start_stance_lerp(STANCE_STAND, 0.38)
	elif prev_state == "crouching":
		CROUCH_ANIMATION.play_backwards("crouch")
	state = "normal"
	speed = base_speed
	tac_sprinting = false

func _enter_crouch_state() -> void:
	#print("entering crouch state")
	var prev_state = state
	state = "crouching"
	speed = crouch_speed
	tac_sprinting = false
	if prev_state == "prone" or _stance_lerp_active:
		_start_stance_lerp(STANCE_CROUCH, 0.3)
	else:
		CROUCH_ANIMATION.play("crouch")

func _enter_sprint_state() -> void:
	#print("entering sprint state")
	var prev_state = state
	if prev_state == "prone" or _stance_lerp_active:
		_start_stance_lerp(STANCE_STAND, 0.38)
	elif prev_state == "crouching":
		CROUCH_ANIMATION.play_backwards("crouch")
	state = "sprinting"
	speed = sprint_speed * _sprint_perk_mult()

func _sprint_perk_mult() -> float:
	var pm = get_node_or_null("PerkManager")
	return pm.get_sprint_speed_multiplier() if (pm and pm.has_method("get_sprint_speed_multiplier")) else 1.0

## Corrida tática: entra com toque duplo no Shift correndo para frente; sai ao acabar a barra,
## soltar o Shift, parar de ir para frente, mirar, atirar ou recarregar (ver end_tac_sprint).
func _handle_tac_sprint(delta : float) -> void:
	var now : float = Time.get_ticks_msec() / 1000.0
	var forward : bool = input_dir.y < -0.5
	if tac_sprinting:
		tac_sprint_energy = maxf(0.0, tac_sprint_energy - delta / maxf(tac_sprint_duration, 0.1))
		var key_ok : bool = sprint_mode == 1 or Input.is_action_pressed(controls.SPRINT)
		if tac_sprint_energy <= 0.0 or state != "sprinting" or not forward or ads_amount > 0.05 or not key_ok:
			end_tac_sprint(false)
	else:
		tac_sprint_energy = minf(1.0, tac_sprint_energy + delta / maxf(tac_sprint_recharge, 0.1))
		if sprint_mode == 0 and tac_sprint_enabled and not immobile:
			if Input.is_action_just_released(controls.SPRINT):
				_sprint_release_time = now
			elif Input.is_action_just_pressed(controls.SPRINT):
				if now - _sprint_release_time <= tac_sprint_double_tap and state == "sprinting" and forward and is_on_floor() and tac_sprint_energy >= tac_sprint_min_energy:
					_start_tac_sprint()
				_sprint_release_time = -10.0
	# Entrada mais rápida que a saída: ao sair, a arma ainda leva um instante para voltar à posição de tiro
	var target : float = 1.0 if tac_sprinting else 0.0
	tac_sprint_pose = move_toward(tac_sprint_pose, target, delta * (5.5 if tac_sprinting else 3.2))

func _start_tac_sprint() -> void:
	tac_sprinting = true
	_tac_dip_v -= 0.42   # corpo "arranca": a câmera afunda e volta
	speed = sprint_speed * _sprint_perk_mult() * tac_sprint_speed_mult

## Encerra a corrida tática. stop_sprint = true também sai da corrida (usado ao atirar/recarregar).
func end_tac_sprint(stop_sprint : bool = false) -> void:
	if not tac_sprinting:
		return
	tac_sprinting = false
	_tac_dip_v -= 0.18
	if stop_sprint:
		_enter_normal_state()
	elif state == "sprinting":
		speed = sprint_speed * _sprint_perk_mult()

## Atirar/recarregar tira o jogador da corrida; segurar o Shift não volta a correr, só um novo toque.
func stop_sprint_for_action() -> void:
	if tac_sprinting:
		_tac_dip_v -= 0.18
	tac_sprinting = false
	if state == "sprinting":
		_enter_normal_state()
	_sprint_blocked_until_repress = Input.is_action_pressed(controls.SPRINT)

# ── DEITAR ────────────────────────────────────────────────────────────────────
func _enter_prone_state() -> void:
	if state == "prone":
		return
	tac_sprinting = false
	state = "prone"
	speed = prone_speed
	_start_stance_lerp(STANCE_PRONE, 0.45)
	_tac_dip_v -= 0.25   # o corpo vai ao chão

## Sai do deitado para "normal" ou "crouching" se houver espaço; devolve false se não couber.
func _try_leave_prone(to_state : String) -> bool:
	var h : float = STANCE_STAND.z if to_state == "normal" else STANCE_CROUCH.z
	if not _fits_height_at(global_position, h):
		return false
	if to_state == "normal":
		_enter_normal_state()
	else:
		_enter_crouch_state()
	return true

func _start_stance_lerp(target : Vector3, duration : float) -> void:
	if CROUCH_ANIMATION and CROUCH_ANIMATION.is_playing():
		CROUCH_ANIMATION.pause()
	_stance_from = _read_stance_values()
	_stance_to = target
	_stance_t = 0.0
	_stance_dur = maxf(duration, 0.05)
	_stance_lerp_active = true

func _read_stance_values() -> Vector3:
	var cap : CapsuleShape3D = (COLLISION_MESH.shape as CapsuleShape3D) if COLLISION_MESH else null
	return Vector3(HEAD.position.y, COLLISION_MESH.position.y if COLLISION_MESH else 1.0, cap.height if cap else 2.0)

func _apply_stance_values(v : Vector3) -> void:
	HEAD.position.y = v.x
	if COLLISION_MESH:
		COLLISION_MESH.position.y = v.y
		var cap := COLLISION_MESH.shape as CapsuleShape3D
		if cap:
			cap.height = maxf(v.z, cap.radius * 2.0)
	var body_mesh := get_node_or_null("Mesh") as MeshInstance3D
	if body_mesh:
		body_mesh.position.y = v.y
		if body_mesh.mesh is CapsuleMesh:
			(body_mesh.mesh as CapsuleMesh).height = maxf(v.z, (body_mesh.mesh as CapsuleMesh).radius * 2.0)

func _update_stance_lerp(delta : float) -> void:
	if not _stance_lerp_active:
		return
	_stance_t = minf(1.0, _stance_t + delta / _stance_dur)
	_apply_stance_values(_stance_from.lerp(_stance_to, smoothstep(0.0, 1.0, _stance_t)))
	if _stance_t >= 1.0:
		_stance_lerp_active = false
		# deixa a animação "crouch" no mesmo ponto, para agachar/levantar depois continuar dela
		if CROUCH_ANIMATION and CROUCH_ANIMATION.has_animation("crouch"):
			if _stance_to == STANCE_CROUCH:
				CROUCH_ANIMATION.play("crouch")
				CROUCH_ANIMATION.seek(CROUCH_ANIMATION.get_animation("crouch").length, true)
			elif _stance_to == STANCE_STAND:
				CROUCH_ANIMATION.play("crouch")
				CROUCH_ANIMATION.seek(0.0, true)
				CROUCH_ANIMATION.pause()

## Uma cápsula do raio do jogador, com altura h, cabe com os pés em feet?
func _fits_height_at(feet : Vector3, h : float) -> bool:
	var cap : CapsuleShape3D = (COLLISION_MESH.shape as CapsuleShape3D) if COLLISION_MESH else null
	var shape := CapsuleShape3D.new()
	shape.radius = (cap.radius if cap else 0.38) * 0.92
	shape.height = maxf(h - 0.06, shape.radius * 2.0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), feet + Vector3(0.0, h * 0.5 + 0.04, 0.0))
	q.collision_mask = collision_mask
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

# ── INCLINAR (Q/E) ────────────────────────────────────────────────────────────
func _update_lean(delta : float) -> void:
	var want : float = 0.0
	if lean_enabled and not immobile and state != "prone" and state != "sprinting" and not mantling \
			and InputMap.has_action("lean_left") and InputMap.has_action("lean_right"):
		if Input.is_action_pressed("lean_left"):
			want -= 1.0
		if Input.is_action_pressed("lean_right"):
			want += 1.0
	if want != 0.0:
		want *= _lean_free_fraction(signf(want))
	lean_amount = move_toward(lean_amount, want, delta * 5.5)

## Quanto da inclinação cabe antes de a cabeça entrar na parede (0..1)
func _lean_free_fraction(side : float) -> float:
	var from : Vector3 = HEAD.global_position
	var right : Vector3 = global_transform.basis.x.normalized()
	var reach : float = lean_offset + 0.22
	var q := PhysicsRayQueryParameters3D.create(from, from + right * side * reach, collision_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return 1.0
	return clampf((from.distance_to(hit.position) - 0.22) / lean_offset, 0.0, 1.0)

# ── ESCALAR (Espaço perto de uma borda) ───────────────────────────────────────
func _ray(a : Vector3, b : Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b, collision_mask, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q)

func _try_mantle() -> bool:
	if mantling or state == "prone" or input_dir.y > -0.3:
		return false
	var fwd : Vector3 = -global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return false
	fwd = fwd.normalized()
	var feet : Vector3 = global_position
	var cap : CapsuleShape3D = (COLLISION_MESH.shape as CapsuleShape3D) if COLLISION_MESH else null
	var radius : float = cap.radius if cap else 0.38
	# 1) obstáculo logo à frente (joelho, cintura ou peito)
	var wall_dist : float = INF
	for hgt in [0.55, 1.0, 1.45]:
		var a : Vector3 = feet + Vector3.UP * hgt
		var hit := _ray(a, a + fwd * (radius + 0.6))
		if not hit.is_empty() and absf(hit.normal.y) < 0.5:
			wall_dist = minf(wall_dist, Vector2(hit.position.x - feet.x, hit.position.z - feet.z).length())
	if wall_dist == INF:
		return false
	# 2) topo da borda, logo depois da face da parede (perto, para pegar muretas finas)
	var probe : Vector3 = feet + fwd * (wall_dist + 0.1)
	var top := _ray(probe + Vector3.UP * (mantle_max_height + 0.4), probe + Vector3.UP * (mantle_min_height - 0.05))
	if top.is_empty() or top.normal.y < 0.7:
		return false
	var top_y : float = top.position.y
	var h : float = top_y - feet.y
	if h < mantle_min_height or h > mantle_max_height:
		return false
	# 3) espaço para subir: a cabeça passa por cima, e cabe em pé (ou agachado) lá em cima
	var up_pos := Vector3(feet.x, top_y + 0.05, feet.z)
	var land : Vector3 = Vector3(probe.x, top_y + 0.02, probe.z) + fwd * 0.45
	# Obstáculo fino e baixo (mureta): pula por cima em vez de ficar em cima
	if h <= 1.25:
		var far : Vector3 = feet + fwd * (wall_dist + 1.0)
		var beyond := _ray(Vector3(far.x, top_y + 0.3, far.z), Vector3(far.x, feet.y - 1.2, far.z))
		if not beyond.is_empty() and beyond.position.y < top_y - 0.35 and beyond.normal.y > 0.7:
			var vault_land := Vector3(far.x, beyond.position.y + 0.02, far.z)
			if _fits_height_at(vault_land, STANCE_STAND.z):
				land = vault_land
	if not _fits_height_at(up_pos, STANCE_CROUCH.z) or not _fits_height_at(land, STANCE_CROUCH.z):
		return false
	mantling = true
	tac_sprinting = false
	if state == "sprinting":
		state = "normal"
		speed = base_speed
	_mantle_from = feet
	_mantle_mid = up_pos
	_mantle_to = land
	_mantle_t = 0.0
	_mantle_dur = 0.30 + h * 0.12
	velocity = Vector3.ZERO
	_tac_dip_v -= 0.3
	return true

func _update_mantle(delta : float) -> void:
	_mantle_t = minf(1.0, _mantle_t + delta / _mantle_dur)
	var k : float = _mantle_t
	var p : Vector3
	if k < 0.55:
		var u : float = k / 0.55
		p = _mantle_from.lerp(_mantle_mid, 1.0 - (1.0 - u) * (1.0 - u))   # sobe rápido e desacelera
	else:
		p = _mantle_mid.lerp(_mantle_to, smoothstep(0.0, 1.0, (k - 0.55) / 0.45))
	global_position = p
	velocity = Vector3.ZERO
	if _mantle_t >= 1.0:
		mantling = false
		_tac_dip_v -= 0.15

## Ações que impedem atirar: escalando, rastejando ou indo ao chão.
func blocks_firing() -> bool:
	return mantling or (state == "prone" and (_stance_lerp_active or (moving and current_speed > 0.15)))

## Postura para rede/hitboxes: 0 em pé, 1 agachado, 2 deitado
func stance_id() -> int:
	match state:
		"crouching":
			return 1
		"prone":
			return 2
	return 0

## A arma só pode atirar depois que a pose da corrida tática baixou o suficiente.
func is_weapon_raised_for_sprint() -> bool:
	return tac_sprinting or tac_sprint_pose > 0.35

#endregion

#region Animation Handling

func _initialize_animations() -> void:
	# Reset the camera position
	# If you want to change the default head height, change these animations.
	if HEADBOB_ANIMATION:
		HEADBOB_ANIMATION.play("RESET")
		HEADBOB_ANIMATION.stop()
	if JUMP_ANIMATION:
		JUMP_ANIMATION.play("RESET")
	if CROUCH_ANIMATION:
		CROUCH_ANIMATION.play("RESET")

func _update_head_bob(delta : float) -> void:
	if not CAMERA:
		return

	# Garantir que animações legadas de headbob não disputem posição com o cálculo procedural
	if HEADBOB_ANIMATION and HEADBOB_ANIMATION.is_playing() and HEADBOB_ANIMATION.current_animation != "RESET":
		HEADBOB_ANIMATION.stop()

	var is_moving_on_ground = is_on_floor() and moving and current_speed > 0.3

	if is_moving_on_ground:
		# Frequência da passada: 9.5 Hz no sprint, 6.8 Hz ao andar normal
		var freq = 9.5 if state == "sprinting" else (4.2 if state == "prone" else 6.8)
		freq = lerpf(freq, 11.0, tac_sprint_pose)
		var speed_factor = clampf(current_speed / maxf(base_speed, 1.0), 0.5, 1.6)
		_bob_phase += delta * freq * speed_factor

		# Amplitudes refinadas (metros) - Balanço tático suave, sem solavancos nem travamentos
		var amp_x = 0.007 if state == "sprinting" else 0.0035
		var amp_y = 0.009 if state == "sprinting" else 0.005
		var amp_roll = deg_to_rad(0.8) if state == "sprinting" else deg_to_rad(0.35)
		var tac_amp : float = lerpf(1.0, 1.35, tac_sprint_pose)
		amp_x *= tac_amp
		amp_y *= tac_amp
		amp_roll *= lerpf(1.0, 2.0, tac_sprint_pose)   # corrida tática: ombros jogam mais

		# Amortecimento em ADS (85% mais estável ao mirar)
		if ads_amount > 0.0:
			var ads_damp = lerp(1.0, 0.15, ads_amount)
			amp_x *= ads_damp
			amp_y *= ads_damp
			amp_roll *= ads_damp

		# Padrão orgânico e contínuo de passada:
		# X: balanço lateral suave a meio-ciclo
		# Y: leve afundamento a cada passo (seno absoluto invertido)
		# Roll: suave inclinação na direção da passada
		var target_x = sin(_bob_phase * 0.5) * amp_x
		var target_y = -abs(sin(_bob_phase)) * amp_y
		var target_roll = sin(_bob_phase * 0.5) * amp_roll

		_bob_offset = _bob_offset.lerp(Vector3(target_x, target_y, 0.0), delta * 15.0)
		_bob_roll = lerpf(_bob_roll, target_roll, delta * 15.0)
	else:
		# Retorno suave para a posição de repouso (sem estalos nem teleporte)
		_bob_offset = _bob_offset.lerp(Vector3.ZERO, delta * 12.0)
		_bob_roll = lerpf(_bob_roll, 0.0, delta * 12.0)

	# Mola do mergulho da corrida tática
	var dd : float = minf(delta, 0.05)
	_tac_dip_v += (-140.0 * _tac_dip - 15.0 * _tac_dip_v) * dd
	_tac_dip += _tac_dip_v * dd
	var cam_target : Vector3 = _bob_offset + Vector3(0.0, _tac_dip, 0.0)
	cam_target += Vector3(lean_amount * lean_offset, -absf(lean_amount) * 0.05, 0.0)

	# Se a animação de pulo/pouso estiver ativa, mesclar suavemente
	if JUMP_ANIMATION and JUMP_ANIMATION.is_playing() and JUMP_ANIMATION.current_animation != "RESET":
		CAMERA.position = CAMERA.position.lerp(cam_target, delta * 6.0)
	else:
		CAMERA.position = cam_target

	CAMERA.rotation.z = _bob_roll - lean_amount * deg_to_rad(lean_angle_deg) + cam_extra_rot.y
	CAMERA.rotation.x = cam_extra_rot.x

func _play_headbob_animation(_moving : bool) -> void:
	# Mantido para retrocompatibilidade
	pass

func _play_jump_animation() -> void:
	if !was_on_floor and is_on_floor(): # The player just landed
		var facing_direction : Vector3 = CAMERA.get_global_transform().basis.x
		var facing_direction_2D : Vector2 = Vector2(facing_direction.x, facing_direction.z).normalized()
		var velocity_2D : Vector2 = Vector2(velocity.x, velocity.z).normalized()

		# Compares velocity direction against the camera direction (via dot product) to determine which landing animation to play.
		var side_landed : int = round(velocity_2D.dot(facing_direction_2D))

		if side_landed > 0:
			JUMP_ANIMATION.play("land_right", 0.25)
		elif side_landed < 0:
			JUMP_ANIMATION.play("land_left", 0.25)
		else:
			JUMP_ANIMATION.play("land_center", 0.25)

#endregion

#region Debug Menu

func _update_debug_menu_per_frame() -> void:
	if !$UserInterface/DebugPanel.visible: return

	$UserInterface/DebugPanel.add_property("FPS", Performance.get_monitor(Performance.TIME_FPS), 0)
	var status : String = ("tactical sprint" if tac_sprinting else state)
	if !is_on_floor():
		status += " in the air"
	$UserInterface/DebugPanel.add_property("State", status, 4)


func _update_debug_menu_per_tick() -> void:
	if !$UserInterface/DebugPanel.visible: return

	# Big thanks to github.com/LorenzoAncora for the concept of the improved debug values
	$UserInterface/DebugPanel.add_property("Speed", snappedf(current_speed, 0.001), 1)
	$UserInterface/DebugPanel.add_property("Target speed", speed, 2)
	var cv : Vector3 = get_real_velocity()
	var vd : Array[float] = [
		snappedf(cv.x, 0.001),
		snappedf(cv.y, 0.001),
		snappedf(cv.z, 0.001)
	]
	var readable_velocity : String = "X: " + str(vd[0]) + " Y: " + str(vd[1]) + " Z: " + str(vd[2])
	$UserInterface/DebugPanel.add_property("Velocity", readable_velocity, 3)


func _input(event : InputEvent) -> void:
	if immobile:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var current_sens : float = mouse_sensitivity
		if ads_amount > 0.0:
			current_sens *= lerp(1.0, 0.65, ads_amount)

		# Usar event.relative (compatibilidade 100% universal e resposta instantânea)
		var m_delta = event.relative
		if m_delta == Vector2.ZERO and "screen_relative" in event:
			m_delta = event.screen_relative

		var dx = m_delta.x * current_sens
		var dy = m_delta.y * current_sens

		if invert_camera_x_axis:
			rotation_degrees.y += dx
		else:
			rotation_degrees.y -= dx

		if invert_camera_y_axis:
			HEAD.rotation_degrees.x += dy
		else:
			HEAD.rotation_degrees.x -= dy

		HEAD.rotation_degrees.x = clamp(HEAD.rotation_degrees.x, -72.0, 85.0)

	# Toggle debug menu com F7
	elif event is InputEventKey and event.is_released():
		if event.keycode == 4194338 or event.keycode == KEY_F7:
			var dbg = get_node_or_null("UserInterface/DebugPanel")
			if dbg:
				dbg.visible = !dbg.visible

#endregion

#region Misc Functions

func change_reticle(reticle) -> void:
	if RETICLE:
		RETICLE.queue_free()

	RETICLE = load(reticle).instantiate()
	RETICLE.character = self
	if RETICLE is Control:
		RETICLE.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for c in RETICLE.get_children():
			if c is Control:
				c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UserInterface.add_child(RETICLE)


func _update_camera_fov() -> void:
	# Quando em ADS, o WeaponManager gerencia o zoom exato da arma (ex: -8 para pistola, -20 para fuzil, -45 para luneta)
	if ads_amount > 0.05:
		return
	var target_fov : float = 75.0
	if state == "sprinting":
		target_fov = 85.0
	target_fov += 6.0 * tac_sprint_pose
	var weight : float = 1.0 - exp(-10.0 * get_process_delta_time())
	CAMERA.fov = lerpf(CAMERA.fov, target_fov, weight)

func _handle_pausing() -> void:
	var ccs = get_tree().root.find_child("ChooseClassScreen", true, false) if (is_inside_tree() and get_tree() and get_tree().root) else null
	if ccs and ccs.visible:
		return
	if Input.is_action_just_pressed(controls.PAUSE):
		# You may want another node to handle pausing, because this player may get paused too.
		match Input.mouse_mode:
			Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				#get_tree().paused = false
			Input.MOUSE_MODE_VISIBLE:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				#get_tree().paused = false

func _unhandled_input(event : InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var ccs = get_tree().root.find_child("ChooseClassScreen", true, false) if (is_inside_tree() and get_tree() and get_tree().root) else null
		if ccs and ccs.visible:
			return
		var gm = get_node_or_null("/root/GameManager")
		if gm and not gm.is_match_active:
			return
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()

#endregion
