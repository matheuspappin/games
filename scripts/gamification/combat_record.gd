# =============================================================================
# combat_record.gd
# Registro de Combate e Telemetria de Precisão — Padrão Call of Duty Black Ops 3
# Monitora e persiste todas as estatísticas de precisão:
# Tiros disparados, acertos, taxa de acerto (accuracy %), headshots %,
# abates agachado/slide (scouchs / Low Blow), longshots, assistências, SPM e K/D
# =============================================================================
class_name CombatRecord
extends RefCounted

const SAVE_PATH : String = "user://combat_record.json"

## Estatísticas da Partida Atual (Tempo Real)
var match_stats : Dictionary = {
	"shots_fired"      : 0,
	"shots_hit"        : 0,
	"accuracy_pct"     : 0.0,
	"kills"            : 0,
	"deaths"           : 0,
	"assists"          : 0,
	"headshots"        : 0,
	"headshot_pct"     : 0.0,
	"crouch_kills"     : 0,   # "scouchs" / abates agachado
	"slide_kills"      : 0,   # abates durante slide ("Low Blow")
	"longshots"        : 0,   # abates > 25 metros
	"point_blanks"     : 0,   # abates queima-roupa < 3 metros
	"current_streak"   : 0,
	"best_streak"      : 0,
	"score"            : 0,
	"match_duration"   : 0.0,
	"spm"              : 0.0,
	"medals_earned"    : {}   # { "HEADSHOT": 3, "LOW_BLOW": 2, ... }
}

## Estatísticas Globais de Carreira (Persistidas no Disco)
var career_stats : Dictionary = {
	"total_shots_fired"    : 0,
	"total_shots_hit"      : 0,
	"career_accuracy_pct"  : 0.0,
	"total_kills"          : 0,
	"total_deaths"         : 0,
	"career_kd"            : 0.0,
	"total_assists"        : 0,
	"total_headshots"      : 0,
	"career_headshot_pct"  : 0.0,
	"total_crouch_kills"   : 0,   # "scouchs" histórico
	"total_slide_kills"    : 0,
	"total_longshots"      : 0,
	"total_point_blanks"   : 0,
	"highest_killstreak"   : 0,
	"total_score"          : 0,
	"total_time_played_sec": 0.0,
	"career_spm"           : 0.0,
	"matches_played"       : 0,
	"matches_won"          : 0,
	"matches_lost"         : 0,
	"win_loss_ratio"       : 0.0,
	"lifetime_medals"      : {}
}

func _init() -> void:
	load_from_disk()

## Reinicia os dados da partida atual mantendo o histórico de carreira
func reset_match_stats() -> void:
	match_stats = {
		"shots_fired"      : 0,
		"shots_hit"        : 0,
		"accuracy_pct"     : 0.0,
		"kills"            : 0,
		"deaths"           : 0,
		"assists"          : 0,
		"headshots"        : 0,
		"headshot_pct"     : 0.0,
		"crouch_kills"     : 0,
		"slide_kills"      : 0,
		"longshots"        : 0,
		"point_blanks"     : 0,
		"current_streak"   : 0,
		"best_streak"      : 0,
		"score"            : 0,
		"match_duration"   : 0.0,
		"spm"              : 0.0,
		"medals_earned"    : {}
	}

# ── TELEMETRIA DE DISPAROS & PRECISÃO ─────────────────────────────────────────

func record_shot_fired() -> void:
	match_stats["shots_fired"] += 1
	_recalc_match_rates()

func record_shot_hit(_is_headshot: bool = false, _dist: float = 0.0) -> void:
	match_stats["shots_hit"] += 1
	_recalc_match_rates()

# ── TELEMETRIA DE ABATES & POSTURA DO OPERADOR ───────────────────────────────

func record_kill(is_headshot: bool, is_crouch: bool, is_slide: bool, dist: float, _weapon_id: String = "ak47") -> void:
	match_stats["kills"] += 1
	match_stats["current_streak"] += 1
	if match_stats["current_streak"] > match_stats["best_streak"]:
		match_stats["best_streak"] = match_stats["current_streak"]

	if is_headshot:
		match_stats["headshots"] += 1
		record_medal("HEADSHOT")

	if is_slide:
		match_stats["slide_kills"] += 1
		record_medal("LOW BLOW") # No BO3, kill deslizando é "Low Blow"
	elif is_crouch:
		match_stats["crouch_kills"] += 1
		record_medal("LOW BLOW") # Kill agachado

	if dist >= 25.0:
		match_stats["longshots"] += 1
		record_medal("LONG SHOT")
	elif dist > 0.0 and dist <= 3.2:
		match_stats["point_blanks"] += 1
		record_medal("POINT BLANK")

	_recalc_match_rates()

func record_death() -> void:
	match_stats["deaths"] += 1
	match_stats["current_streak"] = 0
	_recalc_match_rates()

func record_assist(is_major: bool = false) -> void:
	match_stats["assists"] += 1
	record_medal("MAJOR ASSIST" if is_major else "ASSIST")

func record_medal(medal_name: String) -> void:
	var m_earned = match_stats["medals_earned"]
	m_earned[medal_name] = int(m_earned.get(medal_name, 0)) + 1

# ── CONSOLIDAÇÃO & CONCLUSÃO DA PARTIDA ───────────────────────────────────────

func record_match_end(is_victory: bool, duration_sec: float, final_score: int) -> void:
	match_stats["match_duration"] = duration_sec
	match_stats["score"] = final_score
	_recalc_match_rates()

	# Integrar com a carreira persistente
	career_stats["total_shots_fired"]     += match_stats["shots_fired"]
	career_stats["total_shots_hit"]       += match_stats["shots_hit"]
	career_stats["total_kills"]           += match_stats["kills"]
	career_stats["total_deaths"]          += match_stats["deaths"]
	career_stats["total_assists"]         += match_stats["assists"]
	career_stats["total_headshots"]       += match_stats["headshots"]
	career_stats["total_crouch_kills"]    += match_stats["crouch_kills"]
	career_stats["total_slide_kills"]     += match_stats["slide_kills"]
	career_stats["total_longshots"]       += match_stats["longshots"]
	career_stats["total_point_blanks"]    += match_stats["point_blanks"]
	career_stats["total_score"]           += final_score
	career_stats["total_time_played_sec"] += duration_sec
	career_stats["matches_played"]        += 1

	if is_victory:
		career_stats["matches_won"] += 1
	else:
		career_stats["matches_lost"] += 1

	if match_stats["best_streak"] > career_stats["highest_killstreak"]:
		career_stats["highest_killstreak"] = match_stats["best_streak"]

	# Acumular medalhas
	var c_medals = career_stats["lifetime_medals"]
	for m_name in match_stats["medals_earned"].keys():
		c_medals[m_name] = int(c_medals.get(m_name, 0)) + int(match_stats["medals_earned"][m_name])

	_recalc_career_rates()
	save_to_disk()

# ── CÁLCULO DE TAXAS E PERCENTUAIS DE PRECISÃO ───────────────────────────────

func _recalc_match_rates() -> void:
	var f = float(match_stats["shots_fired"])
	var h = float(match_stats["shots_hit"])
	match_stats["accuracy_pct"] = (h / maxf(1.0, f)) * 100.0

	var k = float(match_stats["kills"])
	var hs = float(match_stats["headshots"])
	match_stats["headshot_pct"] = (hs / maxf(1.0, k)) * 100.0

	var min_elapsed = maxf(0.1, match_stats["match_duration"] / 60.0)
	match_stats["spm"] = float(match_stats["score"]) / min_elapsed

func _recalc_career_rates() -> void:
	var tf = float(career_stats["total_shots_fired"])
	var th = float(career_stats["total_shots_hit"])
	career_stats["career_accuracy_pct"] = (th / maxf(1.0, tf)) * 100.0

	var tk = float(career_stats["total_kills"])
	var td = float(career_stats["total_deaths"])
	career_stats["career_kd"] = tk / maxf(1.0, td)

	var ths = float(career_stats["total_headshots"])
	career_stats["career_headshot_pct"] = (ths / maxf(1.0, tk)) * 100.0

	var mw = float(career_stats["matches_won"])
	var ml = float(career_stats["matches_lost"])
	career_stats["win_loss_ratio"] = mw / maxf(1.0, ml)

	var total_min = maxf(0.1, career_stats["total_time_played_sec"] / 60.0)
	career_stats["career_spm"] = float(career_stats["total_score"]) / total_min

# ── PERSISTÊNCIA EM DISCO ────────────────────────────────────────────────────

func save_to_disk() -> bool:
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not f:
		push_warning("[CombatRecord] Falha ao abrir %s para escrita" % SAVE_PATH)
		return false
	var content = JSON.stringify(career_stats, "\t")
	f.store_string(content)
	f.close()
	print("[CombatRecord] Registro de combate persistido com sucesso! K/D: %.2f | Precisão: %.1f%%" % [
		career_stats["career_kd"], career_stats["career_accuracy_pct"]
	])
	return true

func load_from_disk() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return false
	var text = f.get_as_text()
	f.close()
	var json = JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		for k in json.data.keys():
			career_stats[k] = json.data[k]
		_recalc_career_rates()
		print("[CombatRecord] Registro de combate carregado: %d Abates | %d Headshots | %d Agachado" % [
			career_stats["total_kills"], career_stats["total_headshots"], career_stats["total_crouch_kills"]
		])
		return true
	return false
