# =============================================================================
# xp_system.gd
# Sistema de XP, Níveis, Patentes e Prestígio — Padrão Call of Duty Black Ops 3
# Suporta 55 Níveis Militares + 10 Prestígios + Mestre do Prestígio (Níveis 56 a 1000)
# Integrado com RankBadgeRegistry para insígnias vetoriais e títulos militares reais
# =============================================================================
class_name XPSystem
extends Node

const RankBadgeRegistry = preload("res://scripts/gamification/rank_badge_registry.gd")

signal xp_gained(amount: int, source: String)
signal level_up(new_level: int)
signal prestige_available
signal prestige_completed(new_prestige: int)

const MAX_MILITARY_LEVEL : int = 55
const MAX_PRESTIGE       : int = 10
const MAX_MASTER_LEVEL   : int = 1000

# Curva de XP por nível militar (Nível 1 ao 55 — Padrão Black Ops 3)
# O índice 0 representa o XP necessário para ir do Nível 1 para o Nível 2
const XP_PER_LEVEL : Array[int] = [
	0,      # Nível 0 (início)
	4000,   # 1 -> 2
	4500,   # 2 -> 3
	5000,   # 3 -> 4
	6000,   # 4 -> 5
	7000,   # 5 -> 6
	8000,   # 6 -> 7
	9500,   # 7 -> 8
	11000,  # 8 -> 9
	12500,  # 9 -> 10
	14000,  # 10 -> 11
	15500,  # 11 -> 12
	17000,  # 12 -> 13
	18500,  # 13 -> 14
	20000,  # 14 -> 15
	21500,  # 15 -> 16
	23000,  # 16 -> 17
	24500,  # 17 -> 18
	26000,  # 18 -> 19
	27500,  # 19 -> 20
	29000,  # 20 -> 21
	30500,  # 21 -> 22
	32000,  # 22 -> 23
	33500,  # 23 -> 24
	35000,  # 24 -> 25
	36500,  # 25 -> 26
	38000,  # 26 -> 27
	39500,  # 27 -> 28
	41000,  # 28 -> 29
	42500,  # 29 -> 30
	44000,  # 30 -> 31
	45500,  # 31 -> 32
	47000,  # 32 -> 33
	48500,  # 33 -> 34
	50000,  # 34 -> 35
	51000,  # 35 -> 36
	52000,  # 36 -> 37
	53000,  # 37 -> 38
	54000,  # 38 -> 39
	55000,  # 39 -> 40
	55000,  # 40 -> 41
	55000,  # 41 -> 42
	55000,  # 42 -> 43
	55000,  # 43 -> 44
	55000,  # 44 -> 45
	55000,  # 45 -> 46
	55000,  # 46 -> 47
	55000,  # 47 -> 48
	55000,  # 48 -> 49
	55000,  # 49 -> 50
	55000,  # 50 -> 51
	55000,  # 51 -> 52
	55000,  # 52 -> 53
	55000,  # 53 -> 54
	55000   # 54 -> 55 (Comandante Supremo)
]

const MASTER_PRESTIGE_XP_PER_LEVEL : int = 55000

# Recompensas de Pontuação & XP por Ação (Padrão BO3)
const XP_KILL            : int = 100
const XP_HEADSHOT        : int = 25   # Bônus de Headshot
const XP_CROUCH_KILL     : int = 25   # Bônus Agachado / Slide ("scouchs" / Low Blow)
const XP_LONGSHOT        : int = 25   # > 25 metros
const XP_POINT_BLANK     : int = 25   # < 3 metros
const XP_ASSIST          : int = 50   # Assistência padrão
const XP_MAJOR_ASSIST    : int = 75   # Assistência com > 50 de dano
const XP_FIRST_BLOOD     : int = 100  # Primeiro abate da partida
const XP_REVENGE         : int = 25   # Abate de vingança
const XP_BUZZKILL        : int = 100  # Interrupção de streak do inimigo
const XP_WIN_BONUS       : int = 500  # Bônus por vitória na partida

var current_xp           : int = 0
var current_level        : int = 1
var current_prestige     : int = 0

const SAVE_PATH: String = "user://player_progression.json"

func _ready() -> void:
	load_from_disk()

func add_xp(amount: int, source: String = "") -> void:
	current_xp += amount
	xp_gained.emit(amount, source)
	_check_level_up()

func _check_level_up() -> void:
	# 1. Se estiver no Mestre do Prestígio (Prestígio 10+ e Nível >= 56 até 1000)
	if current_prestige >= MAX_PRESTIGE and current_level >= MAX_MILITARY_LEVEL:
		while current_level < MAX_MASTER_LEVEL:
			if current_xp >= MASTER_PRESTIGE_XP_PER_LEVEL:
				current_xp -= MASTER_PRESTIGE_XP_PER_LEVEL
				current_level += 1
				level_up.emit(current_level)
			else:
				break
		return

	# 2. Progressão Regular de Nível Militar (1 a 55)
	while current_level < MAX_MILITARY_LEVEL:
		var xp_needed = _get_xp_for_next_level()
		if current_xp >= xp_needed:
			current_xp -= xp_needed
			current_level += 1
			level_up.emit(current_level)
		else:
			break

	if current_level >= MAX_MILITARY_LEVEL:
		prestige_available.emit()

func _get_xp_for_next_level() -> int:
	if current_prestige >= MAX_PRESTIGE and current_level >= MAX_MILITARY_LEVEL:
		return MASTER_PRESTIGE_XP_PER_LEVEL
	var idx = current_level - 1
	if idx >= 0 and idx < XP_PER_LEVEL.size():
		return XP_PER_LEVEL[idx]
	return 55000

func get_rank_title(lvl: int = -1, prestige: int = -1) -> String:
	var l = current_level if lvl <= 0 else lvl
	var p = current_prestige if prestige < 0 else prestige
	return RankBadgeRegistry.get_rank_title(l, p)

func get_rank_tag(lvl: int = -1, prestige: int = -1) -> String:
	var l = current_level if lvl <= 0 else lvl
	var p = current_prestige if prestige < 0 else prestige
	return RankBadgeRegistry.get_rank_tag(l, p)

func get_rank_icon(lvl: int = -1, prestige: int = -1) -> String:
	var l = current_level if lvl <= 0 else lvl
	var p = current_prestige if prestige < 0 else prestige
	return RankBadgeRegistry.get_rank_icon_symbol(l, p)

func get_rank_color(lvl: int = -1, prestige: int = -1) -> Color:
	var l = current_level if lvl <= 0 else lvl
	var p = current_prestige if prestige < 0 else prestige
	return RankBadgeRegistry.get_rank_color(l, p)

func get_rank_badge_texture(lvl: int = -1, prestige: int = -1, size: int = 64) -> Texture2D:
	var l = current_level if lvl <= 0 else lvl
	var p = current_prestige if prestige < 0 else prestige
	return RankBadgeRegistry.get_badge_texture(l, p, size)

## Executa o Prestígio exatamente como no Call of Duty
func do_prestige() -> void:
	if current_level < MAX_MILITARY_LEVEL:
		push_warning("[XPSystem] Nível insuficiente para prestigiar. Requer Nível %d." % MAX_MILITARY_LEVEL)
		return

	if current_prestige < MAX_PRESTIGE:
		current_prestige += 1
		current_level     = 1
		current_xp        = 0
		save_to_disk()
		prestige_completed.emit(current_prestige)
		print("[XPSystem] ★★★ PARABÉNS! VOCÊ ENTROU NO PRESTÍGIO %d! ★★★" % current_prestige)
	elif current_prestige == MAX_PRESTIGE and current_level == MAX_MILITARY_LEVEL:
		# Desbloqueia Mestre do Prestígio (Níveis 56 a 1000)
		current_level = 56
		current_xp = 0
		save_to_disk()
		prestige_completed.emit(current_prestige)
		print("[XPSystem] 👑 VOCÊ ALCANÇOU O STATUS DE MESTRE DO PRESTÍGIO! 👑")

func get_xp_progress_ratio() -> float:
	var needed = _get_xp_for_next_level()
	if needed <= 0:
		return 1.0
	return clampf(float(current_xp) / float(needed), 0.0, 1.0)

func get_xp_for_next() -> int:
	return _get_xp_for_next_level()

## Calcula e concede XP com telemetria detalhada (Kills, Headshots, Crouch Kills, Longshots, Assists)
func award_match_xp(kills: int, headshots: int, assists: int, is_victory: bool,
					custom_bonus: int = 0, crouch_kills: int = 0, longshots: int = 0) -> Dictionary:
	var prev_lvl = current_level
	var prev_xp = current_xp
	var prev_needed = _get_xp_for_next_level()

	var k_xp = kills * XP_KILL
	var hs_xp = headshots * XP_HEADSHOT
	var cr_xp = crouch_kills * XP_CROUCH_KILL # Bônus "scouchs" / Low Blow
	var ls_xp = longshots * XP_LONGSHOT
	var ast_xp = assists * XP_ASSIST
	var win_xp = XP_WIN_BONUS if is_victory else 150
	var total_gain = k_xp + hs_xp + cr_xp + ls_xp + ast_xp + win_xp + custom_bonus

	add_xp(total_gain, "Fim de Missão")
	save_to_disk()

	var did_level_up = (current_level > prev_lvl)
	return {
		"previous_level": prev_lvl,
		"previous_xp": prev_xp,
		"previous_needed": prev_needed,
		"kills_xp": k_xp,
		"headshots_xp": hs_xp,
		"crouch_kills_xp": cr_xp,
		"longshots_xp": ls_xp,
		"assists_xp": ast_xp,
		"win_bonus_xp": win_xp,
		"custom_bonus_xp": custom_bonus,
		"total_xp_gained": total_gain,
		"new_level": current_level,
		"new_prestige": current_prestige,
		"new_xp": current_xp,
		"new_needed": _get_xp_for_next_level(),
		"new_progress_ratio": get_xp_progress_ratio(),
		"leveled_up": did_level_up,
		"levels_gained": (current_level - prev_lvl),
		"rank_title": get_rank_title(current_level, current_prestige),
		"rank_tag": get_rank_tag(current_level, current_prestige),
		"rank_icon": get_rank_icon(current_level, current_prestige),
		"rank_color": get_rank_color(current_level, current_prestige),
		"is_prestige_available": (current_level >= MAX_MILITARY_LEVEL and current_prestige < MAX_PRESTIGE)
	}

func save() -> Dictionary:
	return {
		"xp"      : current_xp,
		"level"   : current_level,
		"prestige": current_prestige
	}

func load_from(data: Dictionary) -> void:
	current_xp       = int(data.get("xp",       0))
	current_level    = int(data.get("level",     1))
	current_prestige = int(data.get("prestige",  0))

func save_to_disk() -> bool:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_warning("[XPSystem] Falha ao abrir %s para escrita" % SAVE_PATH)
		return false
	var data = save()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("[XPSystem] Progresso salvo: %s (Nível %d | P%d) | XP: %d" % [
		get_rank_title(), current_level, current_prestige, current_xp
	])
	return true

func load_from_disk() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var json_str = file.get_as_text()
	file.close()
	var test_json = JSON.new()
	var err = test_json.parse(json_str)
	if err == OK and test_json.data is Dictionary:
		load_from(test_json.data)
		print("[XPSystem] Progresso carregado: %s (Nível %d | P%d) | XP: %d" % [
			get_rank_title(), current_level, current_prestige, current_xp
		])
		return true
	return false
