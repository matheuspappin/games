# =============================================================================
# player_constants.gd
# Constantes físicas e de câmera do jogador — estilo CoD MW3 / Black Ops 1
# MS-1: Player Controller
# =============================================================================
class_name PlayerConstants

# ── VELOCIDADES ───────────────────────────────────────────────────────────────
const WALK_SPEED           : float = 3.8    # m/s — caminhada normal
const SPRINT_SPEED         : float = 6.5    # m/s — sprint (Shift)
const TACT_SPRINT_SPEED    : float = 8.2    # m/s — tactical sprint (Shift duplo)
const CROUCH_SPEED         : float = 2.4    # m/s — agachado
const PRONE_SPEED          : float = 1.2    # m/s — deitado
const ADS_SPEED_MULT       : float = 0.75   # multiplicador ao mirar (hip → ads)

# ── FÍSICA DE SOLO ────────────────────────────────────────────────────────────
const GRAVITY              : float = 20.0   # m/s² — maior que 9.8 = feel arcade pesado
const JUMP_VELOCITY        : float = 4.8    # m/s vertical
const GROUND_ACCEL         : float = 14.0   # arrancada rápida ao pressionar WASD
const GROUND_FRICTION      : float = 9.0    # parada imediata ao soltar WASD
const AIR_ACCEL            : float = 1.8    # controle aéreo mínimo no ar
const AIR_FRICTION         : float = 0.2    # conserva momento horizontal no ar
const STEP_HEIGHT          : float = 0.35   # degrau máximo que o player sobe automaticamente

# ── SLIDE ─────────────────────────────────────────────────────────────────────
const SLIDE_IMPULSE        : float = 5.5    # velocidade inicial do slide
const SLIDE_FRICTION       : float = 2.5    # decaimento do slide por segundo
const SLIDE_MIN_SPEED      : float = 1.5    # velocidade mínima para manter slide ativo
const SLIDE_TILT_ANGLE     : float = 3.0    # graus de inclinação da câmera no slide

# ── MANTLE ────────────────────────────────────────────────────────────────────
const MANTLE_SPEED         : float = 0.35   # duração do Tween do mantle
const MANTLE_MAX_HEIGHT    : float = 1.8    # altura máxima que o player consegue trepar
const MANTLE_REACH         : float = 0.6    # distância à frente que o raycast verifica

# ── CÂMERA ────────────────────────────────────────────────────────────────────
const FOV_DEFAULT          : float = 90.0   # FOV normal
const FOV_SPRINT_ADD       : float = 5.0    # FOV adicional durante sprint
const FOV_ADS_DELTA        : float = -10.0  # redução de FOV ao mirar (base sem óptica)
const MOUSE_SENSITIVITY    : float = 0.0018 # radianos por pixel de movimento do mouse
const CAMERA_PITCH_MIN     : float = -72.0  # graus — olhar para baixo (estilo CoD, impede vazamento no tronco)
const CAMERA_PITCH_MAX     : float = 85.0   # graus — olhar para cima

# ── HEAD BOBBING ──────────────────────────────────────────────────────────────
const BOB_FREQUENCY        : float = 8.0    # Hz — velocidade do ciclo de bobbing
const BOB_AMPLITUDE_X      : float = 0.006  # metros de oscilação lateral
const BOB_AMPLITUDE_Y      : float = 0.008  # metros de oscilação vertical
const BOB_SPRINT_MULT      : float = 1.8    # multiplicador de amplitude durante sprint

# ── SWAY (INÉRCIA DO MOUSE) ───────────────────────────────────────────────────
const SWAY_AMOUNT          : float = 0.0012 # escala de sway por pixel de mouse
const SWAY_TILT            : float = 0.0008 # inclinação Z em sway horizontal
const SWAY_SPEED           : float = 6.0    # velocidade de interpolação do sway

# ── LEAN (DEBRUÇAR — Q/E) ────────────────────────────────────────────────────
const LEAN_ANGLE           : float = 15.0   # graus de inclinação lateral
const LEAN_OFFSET          : float = 0.3    # metros de offset lateral na câmera
const LEAN_SPEED           : float = 8.0    # velocidade de interpolação

# ── ALTURA DA CÁPSULA (HUMANO TÁTICO: 1.85m) ──────────────────────────────────
const CAPSULE_HEIGHT_STAND : float = 1.85   # altura total em pé (1,85m)
const CAPSULE_HEIGHT_CROUCH: float = 1.30   # altura total agachado (1,30m)
const CAPSULE_HEIGHT_PRONE : float = 0.50   # altura total deitado
const HEAD_HEIGHT_STAND    : float = 1.72   # Y dos olhos em pé (1,72m do chão)
const HEAD_HEIGHT_CROUCH   : float = 1.15   # Y dos olhos agachado
const HEAD_HEIGHT_PRONE    : float = 0.35   # Y dos olhos deitado
const CROUCH_TRANSITION    : float = 0.12   # segundos de interpolação ao agachar

# ── LANDING IMPACT ────────────────────────────────────────────────────────────
const LAND_IMPACT_THRESHOLD: float = 3.0    # metros de queda para sentir impacto
const LAND_IMPACT_STRENGTH : float = 0.06   # força do pitch negativo ao pousar
const LAND_IMPACT_SPEED    : float = 0.08   # duração do efeito

# ── MANTLE RAYCAST ALTURAS ────────────────────────────────────────────────────
const MANTLE_RAY_CHEST_H   : float = 1.20   # Y do raycast do peito
const MANTLE_RAY_HEAD_H    : float = 1.85   # Y do raycast da cabeça (verifica espaço acima)
