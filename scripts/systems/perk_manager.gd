# =============================================================================
# perk_manager.gd
# Sistema de Vantagens (Perks) e Especialidades de Combate estilo Black Ops 6
# Suporta:
# - Categorização em 3 Estilos: Enforcer (Vermelho), Recon (Azul), Strategist (Verde)
# - Sinergia de Especialidade BO6 (3 perks da mesma cor ativam o bônus pleno)
# - Pipeline de Modificadores para Saúde, Recarga, Passos, Radar e Movimentação
# =============================================================================
class_name PerkManager
extends Node

signal perks_updated(perks: Array[String], active_specialty: String, is_synergy_active: bool)
signal enforcer_adrenaline_started(duration: float)
signal enforcer_adrenaline_ended
signal recon_reveal_triggered(duration: float)
signal scavenger_replenished(ammo_amount: int)

enum Category {
	ENFORCER,   # 🔴 Combate Agressivo, Velocidade e Armas
	RECON,      # 🔵 Inteligência, Furtividade e Percepção
	STRATEGIST  # 🟢 Sobrevivência, Utilitários e Suporte
}

const CATEGORY_NAMES = {
	Category.ENFORCER: "Enforcer",
	Category.RECON: "Recon",
	Category.STRATEGIST: "Strategist"
}

const CATEGORY_COLORS = {
	Category.ENFORCER: Color(1.0, 0.28, 0.28, 1.0),   # Vermelho vibrante
	Category.RECON: Color(0.24, 0.68, 1.0, 1.0),      # Azul tático
	Category.STRATEGIST: Color(0.32, 0.95, 0.45, 1.0) # Verde tático
}

const PERK_DATABASE: Dictionary = {
	# ── SLOT 1 / DEFENSA & FURTIVIDADE ──
	"flak_jacket": {
		"name": "Flak Jacket",
		"category": Category.STRATEGIST,
		"icon": "🛡️",
		"desc": "Reduz o dano de explosivos e fogo em 50% e evita baixas por impacto único indireto."
	},
	"ghost": {
		"name": "Fantasma / Ghost",
		"category": Category.RECON,
		"icon": "🥷",
		"desc": "Indetectável por radares/UAVs e sensores térmicos inimigos enquanto estiver em movimento."
	},
	"ninja": {
		"name": "Ninja",
		"category": Category.RECON,
		"icon": "👟",
		"desc": "Seus passos são completamente silenciosos para outros jogadores."
	},

	# ── SLOT 2 / LOGÍSTICA & COMBATE ──
	"tracker": {
		"name": "Rastreador",
		"category": Category.RECON,
		"icon": "🦅",
		"desc": "Inimigos deixam pegadas térmicas recentes no chão; oculta marcas de crânio dos alvos mortos."
	},
	"fast_hands": {
		"name": "Mão Leve",
		"category": Category.ENFORCER,
		"icon": "🏃",
		"desc": "Recarrega armas e troca de armamento 30% mais rápido."
	},
	"scavenger": {
		"name": "Abastecedor",
		"category": Category.STRATEGIST,
		"icon": "🧭",
		"desc": "Recupera munição reserva e equipamentos ao abater adversários."
	},

	# ── SLOT 3 / PERCEPÇÃO & AGILIDADE ──
	"high_alert": {
		"name": "Alerta Máximo",
		"category": Category.RECON,
		"icon": "👁️",
		"desc": "A borda da tela pulsa quando um inimigo fora do seu campo de visão está mirando em você."
	},
	"tac_mask": {
		"name": "Máscara Tática",
		"category": Category.STRATEGIST,
		"icon": "🤿",
		"desc": "Reduz o tempo e efeito de granadas Flashbang e Stun em 65%."
	},
	"dexterity": {
		"name": "Destreza",
		"category": Category.ENFORCER,
		"icon": "⚡",
		"desc": "Reduz o coice visual ao saltar/deslizar e acelera a transição de mira pós-corrida."
	},
	"assassin": {
		"name": "Assassino",
		"category": Category.ENFORCER,
		"icon": "🎯",
		"desc": "Inimigos em sequência de baixas recebem marcador exclusivo e concedem bônus de pontuação."
	}
}

# Estado ativo do operador
var active_perks: Array[String] = []
var active_specialty: String = "recon"
var is_synergy_active: bool = false

# Timers e Buffs dinâmicos de combate (BO6 Enforcer / Recon)
var enforcer_buff_timer: float = 0.0
const ENFORCER_BUFF_DURATION: float = 4.0

var player_owner: Node = null

func _ready() -> void:
	player_owner = get_parent()

func _process(delta: float) -> void:
	if enforcer_buff_timer > 0.0:
		enforcer_buff_timer -= delta
		if enforcer_buff_timer <= 0.0:
			enforcer_buff_timer = 0.0
			enforcer_adrenaline_ended.emit()

## Configura e aplica o loadout de vantagens estilo BO6
func configure_loadout(p1: String, p2: String, p3: String, preferred_specialty: String = "") -> void:
	active_perks.clear()
	if p1 != "" and PERK_DATABASE.has(p1): active_perks.append(p1)
	if p2 != "" and PERK_DATABASE.has(p2): active_perks.append(p2)
	if p3 != "" and PERK_DATABASE.has(p3): active_perks.append(p3)

	# Avaliar Sinergia das 3 Cores do BO6
	var cat_counts = {
		Category.ENFORCER: 0,
		Category.RECON: 0,
		Category.STRATEGIST: 0
	}

	for p in active_perks:
		var p_info = PERK_DATABASE.get(p)
		if p_info:
			var cat = p_info.get("category", Category.RECON)
			cat_counts[cat] = cat_counts.get(cat, 0) + 1

	is_synergy_active = false
	if cat_counts[Category.ENFORCER] >= 3:
		active_specialty = "enforcer"
		is_synergy_active = true
	elif cat_counts[Category.RECON] >= 3:
		active_specialty = "recon"
		is_synergy_active = true
	elif cat_counts[Category.STRATEGIST] >= 3:
		active_specialty = "strategist"
		is_synergy_active = true
	else:
		# Não há sinergia pura de 3 cores; usa a selecionada manualmente
		active_specialty = preferred_specialty.to_lower() if preferred_specialty != "" else "recon"
		is_synergy_active = false

	perks_updated.emit(active_perks, active_specialty, is_synergy_active)

## Consulta direta se o jogador possui determinado perk
func has_perk(id: String) -> bool:
	return active_perks.has(id.to_lower())

## Consulta se determinada especialidade está ativa
func has_specialty(id: String) -> bool:
	return active_specialty.to_lower() == id.to_lower()

# ── PIPELINE DE MODIFICADORES ────────────────────────────────────────────────

## Multiplicador de velocidade de recarga (Fast Hands: 30% mais rápido -> tempo * 0.70)
func get_reload_speed_multiplier() -> float:
	if has_perk("fast_hands"):
		return 0.70
	return 1.0

## Multiplicador de dano explosivo (Flak Jacket: 50% de redução)
func get_explosive_damage_multiplier() -> float:
	if has_perk("flak_jacket"):
		return 0.50
	return 1.0

## Multiplicador de volume de passos (Ninja: silenciado)
func get_footstep_volume_multiplier() -> float:
	if has_perk("ninja"):
		return 0.0
	return 1.0

## Multiplicador de duração/força de Flash/Stun (Tac Mask: 65% de redução)
func get_tactical_resistance_multiplier() -> float:
	if has_perk("tac_mask"):
		return 0.35
	return 1.0

## Multiplicador de transição de mira pós-corrida (Dexterity: 20% mais rápido)
func get_sprint_to_fire_multiplier() -> float:
	if has_perk("dexterity"):
		return 0.80
	return 1.0

## Multiplicador de velocidade de sprint (Bônus de Adrenalina Enforcer: +25%)
func get_sprint_speed_multiplier() -> float:
	if enforcer_buff_timer > 0.0:
		return 1.25
	return 1.0

## Multiplicador de ganho de pontuação/XP (Strategist: +50% em objetivos/suporte)
func get_score_multiplier() -> float:
	if has_specialty("strategist"):
		return 1.50
	return 1.0

# ── GATILHOS DE EVENTOS BO6 ──────────────────────────────────────────────────

## Disparado quando o operador elimina um inimigo (Evento de Kill)
func on_enemy_eliminated(_victim: Node) -> void:
	# 1. Bônus Especialidade ENFORCER: Adrenalina (+25% velocidade e cura imediata)
	if has_specialty("enforcer"):
		enforcer_buff_timer = ENFORCER_BUFF_DURATION
		enforcer_adrenaline_started.emit(ENFORCER_BUFF_DURATION)

		if player_owner and "health_component" in player_owner and player_owner.health_component:
			if player_owner.health_component.has_method("start_instant_regen"):
				player_owner.health_component.start_instant_regen()

	# 2. Vantagem ABASTECEDOR / SCAVENGER: Reabastece munição reserva
	if has_perk("scavenger"):
		if player_owner and "weapon_manager" in player_owner and player_owner.weapon_manager:
			var wm = player_owner.weapon_manager
			if wm.has_method("replenish_reserve_ammo"):
				wm.replenish_reserve_ammo(30)
				scavenger_replenished.emit(30)

## Disparado quando o operador renasce (Evento de Respawn)
func on_player_respawned() -> void:
	enforcer_buff_timer = 0.0
	
	# Bônus Especialidade RECON: Visão através das paredes por 2.0s no respawn
	if has_specialty("recon"):
		recon_reveal_triggered.emit(2.0)
