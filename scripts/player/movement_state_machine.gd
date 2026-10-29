# =============================================================================
# movement_state_machine.gd
# Máquina de estados de movimento — 10 estados estilo CoD MW3 / Black Ops 1
# MS-1: Player Controller
# =============================================================================
class_name MovementStateMachine
extends Node

enum State {
	IDLE,
	WALK,
	SPRINT,
	TACT_SPRINT,
	CROUCH,
	PRONE,
	SLIDE,
	JUMP,
	AIR_MOVE,
	MANTLE
}

signal state_changed(old_state: State, new_state: State)

var current_state : State = State.IDLE
var previous_state: State = State.IDLE

# Referência ao player
var player : CharacterBody3D

# Controle do tactical sprint
var tact_sprint_timer     : float = 0.0
const TACT_SPRINT_MAX     : float = 2.5   # duração máxima em segundos
var last_sprint_press_time: float = 0.0
var sprint_press_count    : int   = 0
var is_sprint_active      : bool  = false

# Controle do slide
var slide_speed           : float = 0.0
var was_sprinting_before  : bool  = false

# Controle do mantle
var is_mantling           : bool  = false
var mantle_target_pos     : Vector3 = Vector3.ZERO

# Controle do crouch / prone
var crouch_hold_timer     : float = 0.0
const PRONE_HOLD_DURATION : float = 0.5   # segundos segurando para ativar prone

func _init(p_player: CharacterBody3D = null) -> void:
	player = p_player

# ── TRANSIÇÃO DE ESTADOS ──────────────────────────────────────────────────────
func transition(new_state: State) -> void:
	if new_state == current_state:
		return
	var old = current_state
	_exit_state(old)
	previous_state = old
	current_state  = new_state
	_enter_state(new_state)
	state_changed.emit(old, new_state)

func _enter_state(s: State) -> void:
	match s:
		State.SLIDE:
			slide_speed = PlayerConstants.SLIDE_IMPULSE
		State.TACT_SPRINT:
			tact_sprint_timer = 0.0
		State.MANTLE:
			is_mantling = true

func _exit_state(s: State) -> void:
	match s:
		State.TACT_SPRINT:
			tact_sprint_timer = 0.0
		State.MANTLE:
			is_mantling = false

# ── LÓGICA DE DETECÇÃO DE ESTADO ─────────────────────────────────────────────
func compute_next_state(
	move_dir     : Vector2,
	on_floor     : bool,
	_was_on_floor: bool,
	_velocity    : Vector3,
	can_mantle   : bool,
	is_ads       : bool,
	delta        : float
) -> State:

	var is_moving        = move_dir.length() > 0.05
	var moving_forward   = move_dir.y < -0.1 # Em Godot, andar para frente gera Y negativo
	var sprint_pressed   = Input.is_action_just_pressed("sprint")
	var sprint_held      = Input.is_action_pressed("sprint")
	var crouch_pressed   = Input.is_action_just_pressed("crouch")
	var crouch_held      = Input.is_action_pressed("crouch")
	var jump_pressed     = Input.is_action_just_pressed("jump")
	var prone_pressed    = Input.is_action_just_pressed("prone")

	# ── Atualizar flag persistente de sprint (estilo CoD) ──────────────────────
	if (sprint_pressed or sprint_held) and moving_forward and on_floor and not is_ads and current_state not in [State.CROUCH, State.PRONE, State.SLIDE]:
		is_sprint_active = true
	elif not moving_forward or is_ads or not is_moving or current_state in [State.CROUCH, State.PRONE, State.SLIDE]:
		is_sprint_active = false

	# ── Checagem de Mantle (prioridade alta) ──────────────────────────────────
	if can_mantle and jump_pressed and not on_floor:
		return State.MANTLE

	# ── Morte do Mantle ───────────────────────────────────────────────────────
	if current_state == State.MANTLE and not is_mantling:
		return State.IDLE

	# ── Pulo ─────────────────────────────────────────────────────────────────
	if jump_pressed and on_floor and current_state != State.SLIDE:
		return State.JUMP

	# ── No ar ────────────────────────────────────────────────────────────────
	if not on_floor and current_state != State.JUMP and current_state != State.MANTLE:
		return State.AIR_MOVE

	# ── Aterrizagem ──────────────────────────────────────────────────────────
	if current_state == State.AIR_MOVE and on_floor:
		if is_moving and (is_sprint_active or sprint_held) and moving_forward:
			return State.SPRINT
		elif is_moving:
			return State.WALK
		else:
			return State.IDLE

	# ── Prone via tecla direta 'prone' (Z) ───────────────────────────────────
	if prone_pressed and on_floor and current_state != State.SLIDE:
		if current_state == State.PRONE:
			return State.IDLE
		else:
			return State.PRONE

	# ── Slide (Sprint + Crouch) ───────────────────────────────────────────────
	if (current_state == State.SPRINT or current_state == State.TACT_SPRINT) and crouch_pressed and is_moving:
		was_sprinting_before = true
		is_sprint_active = false
		return State.SLIDE

	# ── Fim do Slide ──────────────────────────────────────────────────────────
	if current_state == State.SLIDE:
		if slide_speed < PlayerConstants.SLIDE_MIN_SPEED or jump_pressed or is_ads:
			if crouch_held:
				return State.CROUCH
			if is_moving and (sprint_held or is_sprint_active) and moving_forward:
				return State.SPRINT
			elif is_moving:
				return State.WALK
			return State.IDLE
		# Enquanto slide está ativo, manter o estado
		return State.SLIDE

	# ── Prone (Segurar Crouch / C) ───────────────────────────────────────────
	if (current_state == State.CROUCH or current_state == State.IDLE) and crouch_held:
		crouch_hold_timer += delta
		if crouch_hold_timer >= PRONE_HOLD_DURATION and current_state != State.PRONE:
			return State.PRONE
	else:
		crouch_hold_timer = 0.0

	# ── Saída do Prone (se crouch pressionado ou sprint pressionado) ──────────
	if current_state == State.PRONE:
		if crouch_pressed or jump_pressed:
			return State.CROUCH
		if (sprint_held or is_sprint_active) and is_moving:
			return State.WALK
		return State.PRONE

	# ── Crouch (tap em C) ────────────────────────────────────────────────────
	if crouch_pressed and on_floor and current_state not in [State.SLIDE, State.PRONE]:
		if current_state == State.CROUCH:
			return State.IDLE
		else:
			return State.CROUCH

	# ── Tactical Sprint (duplo-tap em Shift) ──────────────────────────────────
	if current_state == State.TACT_SPRINT:
		tact_sprint_timer += delta
		if tact_sprint_timer >= TACT_SPRINT_MAX or is_ads or not moving_forward:
			return State.SPRINT

	# ── Detecção de duplo-tap para Tact Sprint ────────────────────────────────
	if Input.is_action_just_pressed("sprint") and current_state == State.SPRINT:
		var now = Time.get_ticks_msec() / 1000.0
		if now - last_sprint_press_time < 0.35:
			return State.TACT_SPRINT
		last_sprint_press_time = now

	# ── Sprint (ANTES do Walk para ter prioridade correta) ────────────────────
	if (is_sprint_active or sprint_held) and moving_forward and is_moving and on_floor and not is_ads:
		if current_state not in [State.CROUCH, State.PRONE, State.SLIDE]:
			return State.SPRINT

	# ── Walk ──────────────────────────────────────────────────────────────────
	# SLIDE excluído: não interromper slide com walk
	if is_moving and on_floor and current_state not in [State.CROUCH, State.PRONE, State.SLIDE]:
		return State.WALK

	# ── Crouch Walk ──────────────────────────────────────────────────────────
	if is_moving and on_floor and current_state == State.CROUCH:
		return State.CROUCH

	# ── Idle ─────────────────────────────────────────────────────────────────
	if not is_moving and on_floor and current_state not in [State.CROUCH, State.PRONE]:
		return State.IDLE

	return current_state

# ── GETTERS ÚTEIS ─────────────────────────────────────────────────────────────
func get_target_speed() -> float:
	match current_state:
		State.WALK:        return PlayerConstants.WALK_SPEED
		State.SPRINT:      return PlayerConstants.SPRINT_SPEED
		State.TACT_SPRINT: return PlayerConstants.TACT_SPRINT_SPEED
		State.CROUCH:      return PlayerConstants.CROUCH_SPEED
		State.PRONE:       return PlayerConstants.PRONE_SPEED
		State.SLIDE:       return slide_speed
		_:                 return 0.0

func get_capsule_target_height() -> float:
	match current_state:
		State.CROUCH, State.SLIDE: return PlayerConstants.CAPSULE_HEIGHT_CROUCH
		State.PRONE:               return PlayerConstants.CAPSULE_HEIGHT_PRONE
		_:                         return PlayerConstants.CAPSULE_HEIGHT_STAND

func get_head_target_y() -> float:
	match current_state:
		State.CROUCH, State.SLIDE: return PlayerConstants.HEAD_HEIGHT_CROUCH
		State.PRONE:               return PlayerConstants.HEAD_HEIGHT_PRONE
		_:                         return PlayerConstants.HEAD_HEIGHT_STAND

func is_grounded_state() -> bool:
	return current_state in [State.IDLE, State.WALK, State.SPRINT, State.TACT_SPRINT,
							 State.CROUCH, State.PRONE, State.SLIDE]

func is_in_slide() -> bool:
	return current_state == State.SLIDE

func is_standing() -> bool:
	return current_state not in [State.CROUCH, State.PRONE, State.SLIDE]
