# =============================================================================
# health_component.gd
# Componente de saúde com regeneração automática estilo CoD
# MS-4: Personagens & Física
# =============================================================================
class_name HealthComponent
extends Node

signal health_changed(current: int, max_hp: int)
signal damage_taken(amount: int, direction: Vector3)
signal damage_received(amount: int, direction: Vector3, attacker: Node)
signal died(death_direction: Vector3, hit_bone: String)
signal regen_started
signal regen_stopped
signal invulnerability_changed(is_active: bool, time_remaining: float)
signal assist_recorded(assistant_id: int, assistant_team: int, victim_id: int, damage_dealt: int, is_major: bool)

@export var max_health       : int   = 100
@export var regen_delay      : float = 3.5    # segundos sem dano para iniciar regen (estilo CoD)
@export var regen_rate       : float = 30.0   # HP/s durante regeneração (~3.3s para cura completa)
@export var regen_enabled    : bool  = true

var _health_float            : float = 100.0
var current_health           : int   = 100:
	set(value):
		current_health = clampi(value, 0, max_health)
		if not is_regenerating:
			_health_float = float(current_health)

var regen_timer              : float = 0.0
var is_dead                  : bool  = false
var is_regenerating          : bool  = false
var last_attacker            : Node  = null
var invulnerable_timer       : float = 0.0

# Rastreamento de histórico de dano para Assistências (Estilo CoD)
# { attacker_id: { "damage": int, "team": int, "attacker": Node, "timestamp": float } }
var damage_records           : Dictionary = {}

func _ready() -> void:
	current_health = max_health
	_health_float = float(max_health)

func _process(delta: float) -> void:
	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
		if invulnerable_timer <= 0.0:
			invulnerable_timer = 0.0
			invulnerability_changed.emit(false, 0.0)

	if is_dead or current_health >= max_health or not regen_enabled:
		if is_regenerating:
			is_regenerating = false
			regen_stopped.emit()
		return

	if regen_timer < regen_delay:
		var time_needed = regen_delay - regen_timer
		regen_timer += delta
		if regen_timer >= regen_delay:
			is_regenerating = true
			regen_started.emit()
			var surplus_delta = delta - time_needed
			if surplus_delta > 0.0001:
				_apply_regen(surplus_delta)
	else:
		_apply_regen(delta)

func _apply_regen(dt: float) -> void:
	_health_float = minf(_health_float + (regen_rate * dt), float(max_health))
	var new_int = int(floor(_health_float))
	if new_int != current_health:
		current_health = new_int
		health_changed.emit(current_health, max_health)

	if current_health >= max_health:
		_health_float = float(max_health)
		is_regenerating = false
		regen_stopped.emit()
		# Ao recuperar 100% da vida, limpa histórico de assistências (Regra CoD)
		damage_records.clear()

func activate_spawn_protection(duration: float = 3.0) -> void:
	invulnerable_timer = duration
	invulnerability_changed.emit(true, duration)

func cancel_spawn_protection() -> void:
	if invulnerable_timer > 0.0:
		invulnerable_timer = 0.0
		invulnerability_changed.emit(false, 0.0)

func is_invulnerable() -> bool:
	return invulnerable_timer > 0.0

func start_instant_regen() -> void:
	if is_dead: return
	regen_timer = regen_delay
	is_regenerating = true
	regen_started.emit()

func take_damage(amount: int, direction: Vector3 = Vector3.ZERO,
				 bone: String = "Chest", attacker: Node = null, is_explosive: bool = false) -> void:
	if is_dead or is_invulnerable():
		return

	# Suporte a Vantagem Flak Jacket (Redução de 50% de dano explosivo e proteção contra instakill)
	if is_explosive:
		var pm = get_parent().get_node_or_null("PerkManager") if get_parent() else null
		if pm and pm.has_method("get_explosive_damage_multiplier"):
			amount = int(float(amount) * pm.get_explosive_damage_multiplier())
			amount = mini(amount, 80) # Impede one-shot kill por explosão indireta se o operador estiver saudável

	var attacker_id = -1
	var attacker_team = -1

	if attacker != null:
		last_attacker = attacker
		attacker_id = _resolve_entity_id(attacker)
		attacker_team = _resolve_entity_team(attacker)
		
		# Registrar / acumular dano no histórico para assistências
		var rec = damage_records.get(attacker_id, {
			"damage": 0,
			"team": attacker_team,
			"attacker": attacker,
			"timestamp": 0.0
		})
		rec["damage"] += amount
		rec["team"] = attacker_team
		rec["attacker"] = attacker
		rec["timestamp"] = Time.get_ticks_msec() / 1000.0
		damage_records[attacker_id] = rec

	# Para regeneração ao tomar dano e reseta o temporizador
	regen_timer = 0.0
	if is_regenerating:
		is_regenerating = false
		regen_stopped.emit()

	current_health = clampi(current_health - amount, 0, max_health)
	_health_float = float(current_health)
	health_changed.emit(current_health, max_health)
	damage_taken.emit(amount, direction)
	damage_received.emit(amount, direction, attacker)

	if current_health <= 0:
		is_dead = true
		_evaluate_assists_on_death(attacker_id)
		died.emit(direction, bone)

func _resolve_entity_id(entity: Node) -> int:
	if not entity:
		return -1
	if "peer_id" in entity and entity.peer_id > 0:
		return entity.peer_id
	if "bot_id" in entity and entity.bot_id > 0:
		return entity.bot_id
	if entity.is_in_group("player"):
		return 1
	return entity.get_instance_id()

func _resolve_entity_team(entity: Node) -> int:
	if not entity:
		return -1
	if "team" in entity:
		return entity.team
	if entity.has_method("get_team"):
		return entity.get_team()
	if entity.is_in_group("player"):
		var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
		return 0 if (gm and gm.local_player_team == 1) else 1
	return -1

func _evaluate_assists_on_death(killer_id: int) -> void:
	if not is_inside_tree():
		return
	var my_id = _resolve_entity_id(get_parent())
	var my_team = _resolve_entity_team(get_parent())
	var now_sec = Time.get_ticks_msec() / 1000.0

	var gm = get_node_or_null("/root/GameManager")

	for att_id in damage_records.keys():
		if att_id == killer_id:
			continue # Quem matou recebe a Kill, não Assistência

		var rec = damage_records[att_id]
		var dmg = int(rec.get("damage", 0))
		var att_team = int(rec.get("team", -1))
		var ts = float(rec.get("timestamp", 0.0))

		# Requisitos estilo CoD:
		# 1. Dano relevante (>= 15 HP)
		# 2. Ocorrido nos últimos 15 segundos
		# 3. Time oposto (não premia fogo amigo)
		var is_enemy = (att_team != my_team) or (att_team == -1 or my_team == -1)
		var is_recent = (now_sec - ts <= 15.0)

		if dmg >= 15 and is_enemy and is_recent:
			var is_major = (dmg >= 50)
			assist_recorded.emit(att_id, att_team, my_id, dmg, is_major)
			if gm and gm.has_method("register_assist"):
				gm.register_assist(att_id, att_team, my_id, dmg, is_major)

func heal(amount: int) -> void:
	if is_dead:
		return
	current_health = mini(current_health + amount, max_health)
	_health_float = float(current_health)
	health_changed.emit(current_health, max_health)

func revive() -> void:
	is_dead         = false
	current_health  = max_health
	_health_float   = float(max_health)
	regen_timer     = 0.0
	is_regenerating = false
	damage_records.clear()
	health_changed.emit(current_health, max_health)

func get_health_ratio() -> float:
	return float(current_health) / float(max(1, max_health))

func is_low_health() -> bool:
	return get_health_ratio() < 0.35   # < 35 HP = estado crítico (heartbeat, vinheta)
