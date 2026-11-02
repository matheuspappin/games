# =============================================================================
# weapon_modifier.gd
# Utilitário de composição de modificadores de acessórios (Gunsmith Engine)
# Aplica modificações sobre WeaponData em tempo de execução sem alterar os arquivos base
# =============================================================================
class_name WeaponModifier
extends RefCounted

const ATTACHMENT_PATHS = {
	"optic_red_dot": "res://resources/attachments/optic_red_dot.tres",
	"optic_holo": "res://resources/attachments/optic_holo.tres",
	"optic_sniper": "res://resources/attachments/optic_sniper.tres",
	"muzzle_suppressor": "res://resources/attachments/muzzle_suppressor.tres",
	"muzzle_compensator": "res://resources/attachments/muzzle_compensator.tres",
	"mag_extended": "res://resources/attachments/mag_extended.tres",
	"barrel_extended": "res://resources/attachments/barrel_extended.tres",
	"barrel_short": "res://resources/attachments/barrel_short.tres",
	"ammo_fmj": "res://resources/attachments/ammo_fmj.tres"
}

static func get_attachment_resource(att_id: String) -> AttachmentData:
	if ATTACHMENT_PATHS.has(att_id):
		var path = ATTACHMENT_PATHS[att_id]
		if ResourceLoader.exists(path):
			return load(path) as AttachmentData
	return null

static func apply_attachments(base_data: WeaponData, attachments: Array[AttachmentData]) -> WeaponData:
	if not base_data:
		return null
	
	# Clonar recurso em memória para não alterar o arquivo .tres original
	var w: WeaponData = base_data.duplicate() as WeaponData
	
	var total_delta_dmg: int = 0
	var total_delta_recoil: float = 0.0
	var total_delta_ads: float = 0.0
	var total_delta_bloom: float = 0.0
	var total_delta_mag: int = 0
	var total_delta_range: float = 0.0
	var total_pen_bonus: int = 0
	var is_suppressed: bool = false
	var has_optic_att: bool = false
	var optic_att_type: int = WeaponData.OpticType.NONE
	var optic_zoom_delta: float = 0.0

	for att in attachments:
		if not att:
			continue
		total_delta_dmg += att.delta_damage
		total_delta_recoil += att.delta_recoil
		total_delta_ads += att.delta_ads_time
		total_delta_bloom += att.delta_bloom
		total_delta_mag += att.delta_magazine
		total_delta_range += att.delta_damage_range
		total_pen_bonus += att.penetration_bonus
		if att.suppressed:
			is_suppressed = true
		
		if att.slot == AttachmentData.Slot.OPTIC:
			has_optic_att = true
			optic_zoom_delta += att.optic_zoom_fov
			if att.attachment_id.contains("holo"):
				optic_att_type = WeaponData.OpticType.HOLOGRAPHIC
			elif att.attachment_id.contains("sniper"):
				optic_att_type = WeaponData.OpticType.SNIPER_SCOPE
			else:
				optic_att_type = WeaponData.OpticType.RED_DOT

	# 1. Dano & Alcance
	w.damage_close = max(1, w.damage_close + total_delta_dmg)
	w.damage_medium = max(1, w.damage_medium + total_delta_dmg)
	w.damage_long = max(1, w.damage_long + total_delta_dmg)
	
	if total_delta_range != 0.0:
		w.damage_falloff_start *= (1.0 + total_delta_range)
		w.damage_falloff_end *= (1.0 + total_delta_range)

	# 2. Recuo & Dispersão
	var recoil_factor = maxf(0.2, 1.0 + total_delta_recoil)
	w.recoil_kick *= recoil_factor
	w.bloom_per_shot = maxf(0.005, w.bloom_per_shot * (1.0 + total_delta_bloom))

	# 3. ADS & Óptica
	w.ads_time = clampf(w.ads_time + total_delta_ads, 0.12, 0.6)
	if has_optic_att:
		w.has_optic = true
		w.optic_type = optic_att_type
		w.ads_fov_delta += optic_zoom_delta
	else:
		w.has_optic = false
		w.optic_type = WeaponData.OpticType.NONE

	# 4. Capacidade (Escalonamento inteligente por categoria para manter coerência tática)
	if total_delta_mag > 0:
		var mag_bonus: int = total_delta_mag
		if base_data.category == WeaponData.WeaponCategory.PISTOL:
			mag_bonus = max(2, int(round(base_data.magazine_capacity * 0.45))) # Deagle 7 -> +3 (10), M9 15 -> +5 (20)
		elif base_data.category == WeaponData.WeaponCategory.SHOTGUN:
			mag_bonus = max(1, int(round(base_data.magazine_capacity * 0.5)))  # Sawnoff 2 -> +1 (3), SPAS 8 -> +4 (12)
		elif base_data.category == WeaponData.WeaponCategory.SNIPER:
			mag_bonus = max(2, int(round(base_data.magazine_capacity * 0.5)))  # Locus 5 -> +3 (8)
		elif base_data.category == WeaponData.WeaponCategory.LMG:
			mag_bonus = max(25, int(round(base_data.magazine_capacity * 0.33))) # RPK 75 -> +25 (100)
		w.magazine_capacity = base_data.magazine_capacity + mag_bonus
		w.reserve_ammo_max = max(w.magazine_capacity, base_data.reserve_ammo_max + (mag_bonus * 3))

	# 5. Silenciador (troca áudio para versão abafada e ativa flag de supressão)
	w.is_silenced = is_suppressed
	if is_suppressed and w.sound_fire_silenced:
		w.sound_fire = w.sound_fire_silenced

	# 6. Penetração
	w.penetration_power += total_pen_bonus

	return w

static func calculate_ui_stats(base_data: WeaponData, attachments: Array[AttachmentData]) -> Dictionary:
	if not base_data:
		return {
			"damage": 50, "accuracy": 50, "range": 50, "recoil_control": 50, "mobility": 50,
			"mag": 30, "reserve": 120, "suppressed": false, "has_optic": false
		}
	
	var mod_w = apply_attachments(base_data, attachments)
	
	# Normalização para barras de 0 a 100 estilo Call of Duty
	var dmg_bar = clampf(float(mod_w.damage_close) / 75.0 * 100.0, 10.0, 100.0)
	var range_bar = clampf(float(mod_w.damage_falloff_end) / 50.0 * 100.0, 10.0, 100.0)
	var recoil_ctrl = clampf((3.0 - mod_w.recoil_kick.y) / 2.5 * 100.0, 15.0, 100.0)
	var accuracy_bar = clampf((0.05 - mod_w.bloom_per_shot) / 0.045 * 100.0, 20.0, 100.0)
	var mobility_bar = clampf((0.40 - mod_w.ads_time) / 0.30 * 100.0, 15.0, 100.0)
	
	var is_supp = false
	for att in attachments:
		if att and att.suppressed:
			is_supp = true
			break

	return {
		"damage": int(dmg_bar),
		"accuracy": int(accuracy_bar),
		"range": int(range_bar),
		"recoil_control": int(recoil_ctrl),
		"mobility": int(mobility_bar),
		"mag": mod_w.magazine_capacity,
		"reserve": mod_w.reserve_ammo_max,
		"suppressed": is_supp,
		"has_optic": mod_w.has_optic
	}
