# =============================================================================
# hud_controller.gd
# HUD estilo Call of Duty MW3 / Black Ops 1
# Controla: Crosshair dinâmico com bloom, Hitmarker com som/cor, Contador de munição e Stance
# =============================================================================
class_name HUDController
extends CanvasLayer

@export var crosshair_root    : Control
@export var hitmarker_root    : Control
@export var hitmarker_label   : Label
@export var ammo_label        : Label
@export var weapon_label      : Label
@export var stance_label      : Label

# Crosshair lines
@export var crosshair_top     : Control
@export var crosshair_bottom  : Control
@export var crosshair_left    : Control
@export var crosshair_right   : Control

var player         : CharacterBody3D
var weapon_manager : WeaponManager

var hitmarker_timer : float = 0.0

func _ready() -> void:
	if hitmarker_root:
		hitmarker_root.modulate.a = 0.0

	# Localizar Player e WeaponManager
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_node_or_null("../Player") as CharacterBody3D

	# Garantir que nenhum elemento visual de HUD bloqueie cliques ou movimento do mouse
	_ignore_all_mouse(self)

	if player:
		weapon_manager = player.get_node_or_null("Head/MainCamera3D/WeaponRig/WeaponManager") as WeaponManager
		if not weapon_manager:
			weapon_manager = player.find_child("WeaponManager", true, false) as WeaponManager
		if weapon_manager:
			weapon_manager.ammo_changed.connect(_on_ammo_changed)
			weapon_manager.weapon_switched.connect(_on_weapon_switched)
			weapon_manager.hit_confirmed.connect(_on_hit_confirmed)
			if weapon_manager.weapon_data:
				_on_weapon_switched(weapon_manager.weapon_data)
				_on_ammo_changed(weapon_manager.current_ammo, weapon_manager.reserve_ammo)

func _ignore_all_mouse(node: Node) -> void:
	if node is Control and not (node is PauseMenu or node.name == "PauseMenu" or node.owner is PauseMenu):
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_ignore_all_mouse(c)

func _process(delta: float) -> void:
	_update_crosshair(delta)
	_update_hitmarker(delta)
	_update_stance()

func _update_crosshair(delta: float) -> void:
	if not player or not crosshair_root:
		return

	# Ocultar crosshair no ADS
	var ads = player.ads_amount if "ads_amount" in player else 0.0
	crosshair_root.modulate.a = lerp(crosshair_root.modulate.a, 1.0 - ads, delta * 15.0)

	# Calcular expansão com base no bloom e velocidade
	var base_spread = 8.0
	var vel_spread = Vector2(player.velocity.x, player.velocity.z).length() * 2.5
	var bloom_spread = (weapon_manager.current_bloom * 400.0) if weapon_manager else 0.0
	var total_spread = base_spread + vel_spread + bloom_spread

	if crosshair_top:
		crosshair_top.position.y = -total_spread - 8.0
	if crosshair_bottom:
		crosshair_bottom.position.y = total_spread
	if crosshair_left:
		crosshair_left.position.x = -total_spread - 8.0
	if crosshair_right:
		crosshair_right.position.x = total_spread

func _update_hitmarker(delta: float) -> void:
	if hitmarker_timer > 0.0:
		hitmarker_timer -= delta
		if hitmarker_root:
			hitmarker_root.modulate.a = clampf(hitmarker_timer / 0.15, 0.0, 1.0)
	elif hitmarker_root and hitmarker_root.modulate.a > 0.0:
		hitmarker_root.modulate.a = 0.0

var sound_hitmarker: AudioStream = preload("res://assets/audio/weapons/hitmarker.wav")
var sound_headshot: AudioStream = preload("res://assets/audio/weapons/headshot.wav")

func _on_hit_confirmed(is_headshot: bool, _hit_pos: Vector3) -> void:
	var sfx = sound_headshot if is_headshot else sound_hitmarker
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx(sfx)

	if not hitmarker_root:
		return

	hitmarker_timer = 0.18
	hitmarker_root.modulate.a = 1.0

	if is_headshot:
		hitmarker_root.modulate = Color(1.0, 0.15, 0.15, 1.0)
		if hitmarker_label:
			hitmarker_label.text = "✕"
	else:
		hitmarker_root.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if hitmarker_label:
			hitmarker_label.text = "✕"

func _on_ammo_changed(current: int, reserve: int) -> void:
	if ammo_label:
		if weapon_manager and weapon_manager.weapon_data and weapon_manager.weapon_data.category == WeaponData.WeaponCategory.MELEE:
			ammo_label.text = "MELEE"
			ammo_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			ammo_label.text = "%d / %d" % [current, reserve]
			if current <= 5:
				ammo_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
			else:
				ammo_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_weapon_switched(data: WeaponData) -> void:
	if weapon_label and data:
		weapon_label.text = data.weapon_name

func _update_stance() -> void:
	if not player or not stance_label:
		return

	if "state_machine" in player and player.state_machine:
		var s = player.state_machine.current_state
		match s:
			MovementStateMachine.State.IDLE, MovementStateMachine.State.WALK:
				stance_label.text = "EM PÉ"
			MovementStateMachine.State.SPRINT:
				stance_label.text = "SPRINT"
			MovementStateMachine.State.TACT_SPRINT:
				stance_label.text = "TACT SPRINT"
			MovementStateMachine.State.CROUCH:
				stance_label.text = "AGACHADO"
			MovementStateMachine.State.PRONE:
				stance_label.text = "DEITADO"
			MovementStateMachine.State.SLIDE:
				stance_label.text = "SLIDE"
			MovementStateMachine.State.JUMP, MovementStateMachine.State.AIR_MOVE:
				stance_label.text = "NO AR"
			MovementStateMachine.State.MANTLE:
				stance_label.text = "MANTLE"
	elif "state" in player:
		if not player.is_on_floor():
			stance_label.text = "NO AR"
		else:
			match player.state:
				"normal":
					stance_label.text = "EM PÉ"
				"sprinting":
					stance_label.text = "SPRINT"
				"crouching":
					stance_label.text = "AGACHADO"
