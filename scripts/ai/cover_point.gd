# =============================================================================
# cover_point.gd
# Ponto de cobertura para a IA — marcador de posição tática no nível
# MS-7: IA Tática
# =============================================================================
class_name CoverPoint
extends Node3D

@export var protection_direction : Vector3 = Vector3.FORWARD  # Normal da superfície protetora
@export var is_crouchable        : bool    = true             # Pode usar agachado
@export var is_half_cover        : bool    = false            # Pode espreitar sem agachar
@export var tactical_value       : float   = 0.5              # 0.0–1.0
@export var max_agents           : int     = 1                # Máx. bots simultâneos

var occupants : Array[Node] = []

func is_available() -> bool:
	# Limpar referências inválidas
	occupants = occupants.filter(func(n): return is_instance_valid(n))
	return occupants.size() < max_agents

func reserve(agent: Node) -> bool:
	if not is_available():
		return false
	occupants.append(agent)
	return true

func release(agent: Node) -> void:
	occupants.erase(agent)

func get_peek_position() -> Vector3:
	# Posição de espreitar: ligeiramente acima e ao lado da cobertura
	return global_position + Vector3.UP * (0.8 if is_crouchable else 1.4)
