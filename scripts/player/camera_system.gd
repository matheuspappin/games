# =============================================================================
# camera_system.gd
# Sistema de câmera procedural — Head Bobbing, Sway, Recoil, Lean, Landing
# MS-1: Player Controller
# =============================================================================
class_name CameraSystem
extends Node

# ── REFERÊNCIAS ───────────────────────────────────────────────────────────────
@export var head           : Node3D
@export var camera         : Camera3D
@export var weapon_rig     : Node3D

var player                 : CharacterBody3D

# ── HEAD BOBBING ──────────────────────────────────────────────────────────────
var bob_time               : float  = 0.0
var bob_enabled            : bool   = true

# ── SWAY ──────────────────────────────────────────────────────────────────────
var sway_target            : Vector3 = Vector3.ZERO
var sway_current           : Vector3 = Vector3.ZERO
var last_mouse_delta       : Vector2 = Vector2.ZERO

# ── LEAN ──────────────────────────────────────────────────────────────────────
var lean_current_angle     : float   = 0.0
var lean_current_offset    : float   = 0.0

# ── SLIDE TILT ────────────────────────────────────────────────────────────────
var slide_tilt_current     : float   = 0.0

# ── LANDING IMPACT ────────────────────────────────────────────────────────────
var was_on_floor           : bool    = false
var air_fall_velocity      : float   = 0.0
var land_impact_timer      : float   = 0.0
var land_impact_strength   : float   = 0.0
var landing_pitch_offset   : float   = 0.0

# ── FOV ───────────────────────────────────────────────────────────────────────
var fov_target             : float   = PlayerConstants.FOV_DEFAULT
var fov_current            : float   = PlayerConstants.FOV_DEFAULT

# ── ADS ───────────────────────────────────────────────────────────────────────
var ads_amount             : float   = 0.0   # 0.0 = hip, 1.0 = ADS completo
var ads_fov_delta          : float   = PlayerConstants.FOV_ADS_DELTA

func initialize(p_player: CharacterBody3D) -> void:
	player = p_player

# ── TICK PRINCIPAL ────────────────────────────────────────────────────────────
func process_camera(delta: float, state: MovementStateMachine.State,
					move_dir: Vector2, is_ads: bool, on_floor: bool) -> void:
	_process_fov(delta, state, is_ads)
	_process_head_bobbing(delta, state, move_dir)
	_process_sway(delta)
	_process_lean_and_tilt(delta, state)
	_process_landing_impact(delta, on_floor)

# ── FOV DINÂMICO ──────────────────────────────────────────────────────────────
func _process_fov(delta: float, state: MovementStateMachine.State, is_ads: bool) -> void:
	if not camera:
		return

	var base = PlayerConstants.FOV_DEFAULT

	if is_ads:
		fov_target = base + ads_fov_delta
	elif state == MovementStateMachine.State.SPRINT:
		fov_target = base + PlayerConstants.FOV_SPRINT_ADD
	elif state == MovementStateMachine.State.TACT_SPRINT:
		fov_target = base + PlayerConstants.FOV_SPRINT_ADD * 1.5
	else:
		fov_target = base

	fov_current = lerp(fov_current, fov_target, delta * 8.0)
	camera.fov   = fov_current

# ── HEAD BOBBING (aplicado na camera para desacoplar da altura da cabeça) ──────
func _process_head_bobbing(delta: float, state: MovementStateMachine.State,
							move_dir: Vector2) -> void:
	if not bob_enabled or not camera:
		return

	var speed_ratio  : float = 0.0
	var amp_mult     : float = 1.0

	match state:
		MovementStateMachine.State.WALK:
			speed_ratio = 1.0
		MovementStateMachine.State.SPRINT:
			speed_ratio = 1.5
			amp_mult    = PlayerConstants.BOB_SPRINT_MULT
		MovementStateMachine.State.TACT_SPRINT:
			speed_ratio = 1.9
			amp_mult    = PlayerConstants.BOB_SPRINT_MULT * 1.2
		MovementStateMachine.State.CROUCH:
			speed_ratio = 0.6
			amp_mult    = 0.5
		MovementStateMachine.State.PRONE:
			speed_ratio = 0.3
			amp_mult    = 0.25
		_:
			speed_ratio = 0.0

	if move_dir.length() < 0.1:
		speed_ratio = 0.0

	bob_time += delta * PlayerConstants.BOB_FREQUENCY * speed_ratio

	var bob_x = sin(bob_time * 2.0)  * PlayerConstants.BOB_AMPLITUDE_X * amp_mult
	var bob_y = abs(sin(bob_time))   * PlayerConstants.BOB_AMPLITUDE_Y * amp_mult

	var bob_offset = Vector3(bob_x, bob_y, 0.0)
	camera.position = camera.position.lerp(bob_offset, delta * 10.0)

# ── MOUSE SWAY ────────────────────────────────────────────────────────────────
func inject_mouse_delta(delta_px: Vector2) -> void:
	last_mouse_delta = delta_px

func _process_sway(delta: float) -> void:
	if weapon_rig == null:
		return

	sway_target = Vector3(
		-last_mouse_delta.y * PlayerConstants.SWAY_AMOUNT,
		-last_mouse_delta.x * PlayerConstants.SWAY_AMOUNT,
		-last_mouse_delta.x * PlayerConstants.SWAY_TILT
	)
	# Amortece o delta do mouse ao longo do frame
	last_mouse_delta = last_mouse_delta.lerp(Vector2.ZERO, delta * 15.0)

	sway_current = sway_current.lerp(sway_target, PlayerConstants.SWAY_SPEED * delta)
	weapon_rig.rotation = weapon_rig.rotation.lerp(sway_current, PlayerConstants.SWAY_SPEED * delta)

# ── LEAN & SLIDE TILT COMBINADOS ──────────────────────────────────────────────
func _process_lean_and_tilt(delta: float, state: MovementStateMachine.State) -> void:
	if not head:
		return

	var lean_target_angle  : float = 0.0
	var lean_target_offset : float = 0.0

	if Input.is_action_pressed("lean_left"):
		lean_target_angle  = -PlayerConstants.LEAN_ANGLE
		lean_target_offset = -PlayerConstants.LEAN_OFFSET
	elif Input.is_action_pressed("lean_right"):
		lean_target_angle  =  PlayerConstants.LEAN_ANGLE
		lean_target_offset =  PlayerConstants.LEAN_OFFSET

	lean_current_angle  = lerp(lean_current_angle,  lean_target_angle,  delta * PlayerConstants.LEAN_SPEED)
	lean_current_offset = lerp(lean_current_offset, lean_target_offset, delta * PlayerConstants.LEAN_SPEED)

	# Offset lateral aplicado no X do head
	head.position.x = lean_current_offset

	# Slide tilt
	var slide_target = PlayerConstants.SLIDE_TILT_ANGLE if state == MovementStateMachine.State.SLIDE else 0.0
	slide_tilt_current = lerp(slide_tilt_current, slide_target, delta * 10.0)

	# Roll final combinado
	head.rotation.z = deg_to_rad(lean_current_angle + slide_tilt_current)

# ── LANDING IMPACT ────────────────────────────────────────────────────────────
func notify_airborne(vel_y: float) -> void:
	air_fall_velocity = min(vel_y, 0.0)  # armazena velocidade negativa (queda)

func notify_landed() -> void:
	var fall_dist_approx = abs(air_fall_velocity)
	if fall_dist_approx >= PlayerConstants.LAND_IMPACT_THRESHOLD:
		var strength = clamp(
			(fall_dist_approx - PlayerConstants.LAND_IMPACT_THRESHOLD) * 0.015,
			0.0, PlayerConstants.LAND_IMPACT_STRENGTH
		)
		land_impact_strength = strength
		land_impact_timer    = 0.0

func _process_landing_impact(delta: float, on_floor: bool) -> void:
	if not was_on_floor and on_floor:
		notify_landed()
	was_on_floor = on_floor

	if land_impact_strength > 0.0:
		land_impact_timer += delta
		var t = clamp(land_impact_timer / PlayerConstants.LAND_IMPACT_SPEED, 0.0, 1.0)
		landing_pitch_offset = -land_impact_strength * sin(t * PI)
		if land_impact_timer >= PlayerConstants.LAND_IMPACT_SPEED:
			land_impact_strength = 0.0
			landing_pitch_offset = 0.0
	else:
		landing_pitch_offset = lerp(landing_pitch_offset, 0.0, delta * 10.0)

	if camera:
		camera.rotation.x = landing_pitch_offset
