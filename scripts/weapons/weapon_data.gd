# =============================================================================
# weapon_data.gd
# Resource de dados de arma — orientado a dados, editável no Inspector do Godot
# MS-2: Sistema de Armas
# =============================================================================
class_name WeaponData
extends Resource

enum WeaponCategory { ASSAULT_RIFLE, SMG, LMG, SNIPER, SHOTGUN, PISTOL, LAUNCHER, MELEE }
enum FireMode       { AUTO, SEMI, BURST }

# ── IDENTIDADE ────────────────────────────────────────────────────────────────
@export_group("Identidade")
@export var weapon_name         : String          = "ACR 6.8"
@export var weapon_id           : String          = "acr68"
@export var category            : WeaponCategory  = WeaponCategory.ASSAULT_RIFLE
@export var fire_mode           : FireMode        = FireMode.AUTO
@export var weapon_icon         : Texture2D
@export var viewmodel_scene     : PackedScene
@export var world_model_scene   : PackedScene

# ── DANO & ALCANCE ────────────────────────────────────────────────────────────
@export_group("Dano & Alcance")
@export var damage_close        : int   = 55     # < falloff_start metros
@export var damage_medium       : int   = 38
@export var damage_long         : int   = 28     # > falloff_end metros
@export var damage_falloff_start: float = 15.0
@export var damage_falloff_end  : float = 40.0
@export var headshot_multiplier : float = 2.0
@export var chest_multiplier    : float = 1.0
@export var limb_multiplier     : float = 0.75
@export var max_range           : float = 1000.0  # metros (raycast máximo)

# ── CADÊNCIA & MUNIÇÃO ────────────────────────────────────────────────────────
@export_group("Cadência & Munição")
@export var fire_rate_rpm       : float = 600.0
@export var burst_count         : int   = 3
@export var burst_delay         : float = 0.05
@export var magazine_capacity   : int   = 30
@export var reserve_ammo_max    : int   = 120

# ── RECARGA ───────────────────────────────────────────────────────────────────
@export_group("Recarga")
@export var reload_tactical_time: float = 2.1
@export var reload_empty_time   : float = 2.8
@export var can_cancel_reload   : bool  = true

# ── RECOIL & DISPERSÃO ────────────────────────────────────────────────────────
@export_group("Recoil & Dispersão")
@export var recoil_kick         : Vector3 = Vector3(0.3, 1.8, 0.1)  ## x = horizontal (±graus), y = vertical (sobe por tiro), z = coice visual
@export var recoil_snappiness   : float   = 6.0
@export var recoil_return_speed : float   = 5.0
@export var bloom_per_shot      : float   = 0.02
@export var bloom_max           : float   = 0.12
@export var bloom_recovery_rate : float   = 8.0
@export var ads_bloom_mult      : float   = 0.3
@export var crouch_bloom_mult   : float   = 0.6
@export var prone_bloom_mult    : float   = 0.4
@export var sprint_bloom_mult   : float   = 3.5

# ── TIRO DO QUADRIL (estilo CoD) ─────────────────────────────────────────────
# No CoD o tiro sem mirar sai num cone aleatório (inclusive o 1º tiro), do tamanho da mira de 4 traços.
# O cone CRESCE a cada disparo do quadril (spread per shot) e só volta depois que você para de atirar;
# andando/pulando abre mais, agachado/deitado fecha um pouco. Mirando (ADS) o 1º tiro é exato e não há
# cone — quem decide é o recoil. Resultado: quadril só funciona colado no inimigo (≈ até 7–10 m com SMG).
# Valores = meio ângulo do cone, em graus. Ordem por classe igual ao CoD: SMG/pistola melhores, fuzil no
# meio, LMG e sniper piores.
@export_group("Tiro do quadril")
@export var hip_spread_deg      : float   = -1.0   ## -1 = padrão da classe da arma
@export var move_spread_deg     : float   = 2.4    ## extra andando na velocidade de caminhada
@export var air_spread_deg      : float   = 4.5    ## extra no ar (pulo/queda)

#                                      AR    SMG   LMG   SNIPER SHOTGUN PISTOL LAUNCHER MELEE
const HIP_SPREAD_BY_CATEGORY      := {0: 4.0, 1: 3.0, 2: 5.5, 3: 9.0, 4: 3.0, 5: 2.6, 6: 5.0, 7: 0.0}
const HIP_BLOOM_SHOT_BY_CATEGORY  := {0: 0.55, 1: 0.40, 2: 0.70, 3: 3.0, 4: 1.0, 5: 0.80, 6: 2.0, 7: 0.0}
const HIP_BLOOM_MAX_BY_CATEGORY   := {0: 5.0, 1: 3.5, 2: 6.5, 3: 4.0, 4: 3.0, 5: 3.5, 6: 3.0, 7: 0.0}
const HIP_BLOOM_DECAY_DEG_S       := 9.0    ## velocidade com que o cone fecha depois de parar de atirar
const HIP_BLOOM_DECAY_DELAY       := 0.15   ## segundos sem atirar até o cone começar a fechar

func get_hip_spread_deg() -> float:
	if hip_spread_deg >= 0.0:
		return hip_spread_deg
	return float(HIP_SPREAD_BY_CATEGORY.get(int(category), 4.0))

## Quanto o cone do quadril abre por disparo (graus). Acessórios mexem via bloom_per_shot (0.02 = padrão).
func get_hip_bloom_per_shot_deg() -> float:
	var k := clampf(bloom_per_shot / 0.02, 0.5, 2.0)
	return float(HIP_BLOOM_SHOT_BY_CATEGORY.get(int(category), 0.55)) * k

func get_hip_bloom_max_deg() -> float:
	return float(HIP_BLOOM_MAX_BY_CATEGORY.get(int(category), 5.0))

# ── ADS ───────────────────────────────────────────────────────────────────────
@export_group("ADS")
@export var ads_position        : Vector3 = Vector3.ZERO
@export var ads_time            : float   = 0.25
@export var ads_fov_delta       : float   = -10.0
@export var ads_sens_mult       : float   = 0.65

# ── ÓPTICA & MIRA (ESTILO CALL OF DUTY) ────────────────────────────────────────
@export_group("Óptica & Mira")
enum OpticType { NONE, RED_DOT, HOLOGRAPHIC, SNIPER_SCOPE }
@export var optic_type          : OpticType       = OpticType.NONE
@export var has_optic           : bool            = false
@export var optic_scene         : PackedScene
@export var optic_mount_offset  : Vector3         = Vector3.ZERO

# ── BALÍSTICA ─────────────────────────────────────────────────────────────────
@export_group("Balística")
@export var is_hitscan          : bool        = true
@export var projectile_speed    : float       = 600.0
@export var projectile_scene    : PackedScene
@export var penetration_power   : int         = 1  # 0=nenhum 1=madeira 2=chapa 3=concreto
@export var penetration_damage_mult: float    = 0.65

# ── ÁUDIO ─────────────────────────────────────────────────────────────────────
@export_group("Áudio")
@export var is_silenced         : bool            = false
@export var sound_fire          : AudioStream
@export var sound_fire_silenced : AudioStream
@export var sound_reload_tact   : AudioStream
@export var sound_reload_empty  : AudioStream
@export var sound_dry_fire      : AudioStream
@export var sound_switch_in     : AudioStream
@export var sound_switch_out    : AudioStream
@export var sound_melee         : AudioStream
@export var sound_shell_eject   : AudioStream

# ── PROGRESSÃO ────────────────────────────────────────────────────────────────
@export_group("Progressão")
@export var xp_per_kill         : int = 100
@export var unlock_level        : int = 1
@export var weapon_level_max    : int = 50

# ── MÉTODOS UTILITÁRIOS ───────────────────────────────────────────────────────
func get_damage_at_distance(distance: float) -> int:
	if distance <= damage_falloff_start:
		return damage_close
	elif distance >= damage_falloff_end:
		return damage_long
	else:
		var t = (distance - damage_falloff_start) / (damage_falloff_end - damage_falloff_start)
		return int(lerp(float(damage_close), float(damage_long), t))

func get_fire_interval() -> float:
	return 60.0 / fire_rate_rpm

# ── Multiplicadores dos acessórios (calculados pelo WeaponModifier; não salvos no recurso) ──
var move_speed_mult   : float = 1.0   # mobilidade geral (ex.: canos)
var ads_move_mult     : float = 1.0   # velocidade andando enquanto mira (ex.: coronhas)
var reload_speed_mult : float = 1.0   # multiplica o tempo de recarga (ex.: pente rápido)
var flinch_mult       : float = 1.0   # tranco na mira ao levar tiro (ex.: coronha pesada)
var sprint_to_fire_mult : float = 1.0 # atraso para atirar ao sair do sprint (ex.: coronha leve)
