# =============================================================================
# attachment_data.gd
# Resource de acessório de arma — modificadores aditivos sobre WeaponData base
# MS-5: Gunsmith & Acessórios
# =============================================================================
class_name AttachmentData
extends Resource

enum Slot { OPTIC, BARREL, UNDERBARREL, STOCK, GRIP, AMMO }

@export_group("Identidade")
@export var attachment_name     : String
@export var attachment_id       : String
@export var slot                : Slot
@export var icon                : Texture2D
@export var mesh_override       : Mesh      # malha que substitui o slot na arma
@export var unlock_level        : int = 1

@export_group("Modificadores")
@export var delta_damage            : int   = 0
@export var delta_recoil            : float = 0.0    # negativo = menos recuo
@export var delta_ads_time          : float = 0.0    # negativo = mira mais rápida
@export var delta_bloom             : float = 0.0    # negativo = mais preciso
@export var delta_movement_speed    : float = 0.0    # negativo = mais lento
@export var delta_magazine          : int   = 0      # pente estendido
@export var delta_damage_range      : float = 0.0    # positivo = mais alcance
@export var delta_reload_speed      : float = 0.0    # positivo = recarga mais rápida (0.35 = 35%)
@export var delta_ads_move_speed    : float = 0.0    # positivo = anda mais rápido mirando
@export var delta_flinch            : float = 0.0    # negativo = menos tranco na mira ao levar tiro
@export var delta_sprint_to_fire    : float = 0.0    # negativo = atira mais cedo ao sair do sprint
@export var optic_zoom_fov          : float = 0.0    # FOV adicional da óptica
@export var suppressed              : bool  = false   # troca som de disparo
@export var penetration_bonus       : int   = 0      # FMJ: +1 penetração
