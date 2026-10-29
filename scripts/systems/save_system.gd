# =============================================================================
# save_system.gd
# Sistema de save/load usando JSON em user://saves/
# Persiste: nível, XP, prestige, loadouts, configurações
# MS-8: Persistência
# =============================================================================
class_name SaveSystem
extends Node

const SAVE_DIR  : String = "user://saves/"
const SAVE_FILE : String = "user://saves/player_data.json"

static func save_player_data(data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var json_str = JSON.stringify(data, "\t")
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: Não foi possível abrir o arquivo para escrita.")
		return false
	file.store_string(json_str)
	file.close()
	return true

static func load_player_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_FILE):
		return _default_player_data()
	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	if file == null:
		push_error("SaveSystem: Não foi possível abrir o arquivo para leitura.")
		return _default_player_data()
	var json_str = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(json_str)
	if parsed is Dictionary:
		return parsed
	return _default_player_data()

static func get_default_loadouts() -> Array[Dictionary]:
	return [
		{
			"id": 1,
			"name": "Assalto",
			"icon": "🎯",
			"desc_short": "ACR 6.8 + PISTOLA C19",
			"primary": "res://resources/weapons/ak47.tres",
			"secondary": "res://resources/weapons/pistol.tres",
			"melee": "res://resources/weapons/knife.tres",
			"optic": "none",
			"muzzle": "none",
			"mag": "none",
			"camo": "default",
			"lethal": "semtex",
			"tactical": "stim",
			"perk1": "flak_jacket",
			"perk2": "fast_hands",
			"perk3": "high_alert",
			"specialty": "enforcer",
			"color_hex": "#f2c033",
			"key": "1"
		},
		{
			"id": 2,
			"name": "CQB",
			"icon": "⚡",
			"desc_short": "MP7 + PISTOLA C19",
			"primary": "res://resources/weapons/mp7.tres",
			"secondary": "res://resources/weapons/pistol.tres",
			"melee": "res://resources/weapons/knife.tres",
			"optic": "none",
			"muzzle": "none",
			"mag": "none",
			"camo": "default",
			"lethal": "frag",
			"tactical": "flash",
			"perk1": "ninja",
			"perk2": "tracker",
			"perk3": "dexterity",
			"specialty": "recon",
			"color_hex": "#4cb3ff",
			"key": "2"
		},
		{
			"id": 3,
			"name": "Suporte",
			"icon": "🛡️",
			"desc_short": "LMG-63 + PISTOLA C19",
			"primary": "res://resources/weapons/lmg.tres",
			"secondary": "res://resources/weapons/pistol.tres",
			"melee": "res://resources/weapons/knife.tres",
			"optic": "none",
			"muzzle": "none",
			"mag": "none",
			"camo": "default",
			"lethal": "c4",
			"tactical": "smoke",
			"perk1": "flak_jacket",
			"perk2": "scavenger",
			"perk3": "tac_mask",
			"specialty": "strategist",
			"color_hex": "#e6a640",
			"key": "3"
		},
		{
			"id": 4,
			"name": "Breacher",
			"icon": "💥",
			"desc_short": "SPAS-12 + .50 GS DEAGLE",
			"primary": "res://resources/weapons/spas12.tres",
			"secondary": "res://resources/weapons/deagle.tres",
			"melee": "res://resources/weapons/knife.tres",
			"optic": "none",
			"muzzle": "none",
			"mag": "none",
			"camo": "default",
			"lethal": "semtex",
			"tactical": "stun",
			"perk1": "flak_jacket",
			"perk2": "fast_hands",
			"perk3": "tac_mask",
			"specialty": "enforcer",
			"color_hex": "#ff594d",
			"key": "4"
		},
		{
			"id": 5,
			"name": "Sniper",
			"icon": "🔭",
			"desc_short": "NOVA SNIPER (EM BREVE) + .50 GS",
			"primary": "res://resources/weapons/acr68.tres",
			"secondary": "res://resources/weapons/deagle.tres",
			"melee": "res://resources/weapons/knife.tres",
			"optic": "none",
			"muzzle": "none",
			"mag": "none",
			"camo": "default",
			"lethal": "c4",
			"tactical": "smoke",
			"perk1": "ghost",
			"perk2": "tracker",
			"perk3": "high_alert",
			"specialty": "recon",
			"color_hex": "#b373ff",
			"key": "5"
		},
		{
			"id": 6,
			"name": "Rapid Fire",
			"icon": "🌪️",
			"desc_short": "PP90M1 + PISTOLA C19",
			"primary": "res://resources/weapons/pp90m1.tres",
			"secondary": "res://resources/weapons/pistol.tres",
			"melee": "res://resources/weapons/knife.tres",
			"optic": "none",
			"muzzle": "none",
			"mag": "none",
			"camo": "default",
			"lethal": "molotov",
			"tactical": "stim",
			"perk1": "ninja",
			"perk2": "fast_hands",
			"perk3": "dexterity",
			"specialty": "enforcer",
			"color_hex": "#33e6b3",
			"key": "6"
		},
		{
			"id": 7,
			"name": "Força Especial",
			"icon": "🎖️",
			"desc_short": "M4A1 + .50 GS DEAGLE",
			"primary": "res://resources/weapons/m4a1.tres",
			"secondary": "res://resources/weapons/deagle.tres",
			"melee": "res://resources/weapons/knife.tres",
			"optic": "none",
			"muzzle": "none",
			"mag": "none",
			"camo": "default",
			"lethal": "semtex",
			"tactical": "flash",
			"perk1": "flak_jacket",
			"perk2": "tracker",
			"perk3": "high_alert",
			"specialty": "recon",
			"color_hex": "#66ccf2",
			"key": "7"
		},
		{
			"id": 8,
			"name": "Pesado 7.62",
			"icon": "⚙️",
			"desc_short": "SCAR-H + PISTOLA C19",
			"primary": "res://resources/weapons/scar_h.tres",
			"secondary": "res://resources/weapons/pistol.tres",
			"melee": "res://resources/weapons/knife.tres",
			"optic": "none",
			"muzzle": "none",
			"mag": "none",
			"camo": "default",
			"lethal": "frag",
			"tactical": "stun",
			"perk1": "flak_jacket",
			"perk2": "scavenger",
			"perk3": "high_alert",
			"specialty": "strategist",
			"color_hex": "#d98c33",
			"key": "8"
		},
		{
			"id": 9,
			"name": "Stealth CQB",
			"icon": "🕶️",
			"desc_short": "VMP + FACA TÁTICA",
			"primary": "res://resources/weapons/vmp.tres",
			"secondary": "res://resources/weapons/knife.tres",
			"melee": "res://resources/weapons/knife.tres",
			"optic": "none",
			"muzzle": "none",
			"mag": "none",
			"camo": "default",
			"lethal": "semtex",
			"tactical": "smoke",
			"perk1": "ghost",
			"perk2": "tracker",
			"perk3": "ninja",
			"specialty": "recon",
			"color_hex": "#80b399",
			"key": "9"
		},
		{
			"id": 10,
			"name": "Custom 10",
			"icon": "⭐",
			"desc_short": "CONFIGURAÇÃO LIVRE",
			"primary": "res://resources/weapons/man_o_war.tres",
			"secondary": "res://resources/weapons/pistol.tres",
			"melee": "res://resources/weapons/knife.tres",
			"optic": "none",
			"muzzle": "none",
			"mag": "none",
			"camo": "default",
			"lethal": "semtex",
			"tactical": "stim",
			"perk1": "flak_jacket",
			"perk2": "fast_hands",
			"perk3": "high_alert",
			"specialty": "recon",
			"color_hex": "#ffd959",
			"key": "0"
		}
	]

static func _default_player_data() -> Dictionary:
	return {
		"version"  : 1,
		"player"   : {
			"xp"       : 0,
			"level"    : 1,
			"prestige" : 0,
			"name"     : "Operador"
		},
		"loadouts" : get_default_loadouts(),
		"settings" : {
			"sensitivity"   : 0.0018,
			"fov"           : 90.0,
			"volume_master" : 1.0,
			"volume_sfx"    : 1.0,
			"volume_music"  : 0.7
		}
	}

static func get_loadouts() -> Array[Dictionary]:
	var data = load_player_data()
	var raw_loadouts = data.get("loadouts", [])
	var defaults = get_default_loadouts()
	var result: Array[Dictionary] = []

	for i in range(10):
		var base = defaults[i].duplicate()
		if i < raw_loadouts.size() and raw_loadouts[i] is Dictionary:
			var saved = raw_loadouts[i]
			for k in saved.keys():
				base[k] = saved[k]

		# Sanitizar referências a snipers antigas removidas (Locus e DSR-50)
		var p_path = str(base.get("primary", ""))
		if p_path.contains("locus.tres") or p_path.contains("dsr50.tres"):
			base["primary"] = "res://resources/weapons/acr68.tres"
			base["desc_short"] = "NOVA SNIPER (EM BREVE) + .50 GS"

		# Garantir armas de fábrica (Stock / Sem acessórios) para futura atualização
		base["optic"] = "none"
		base["muzzle"] = "none"
		base["barrel"] = "none"
		base["underbarrel"] = "none"
		base["mag"] = "none"
		base["stock"] = "none"
		base["grip"] = "none"
		base["camo"] = "default"

		if not base.has("color") and base.has("color_hex"):
			base["color"] = Color.from_string(str(base["color_hex"]), Color(0.95, 0.75, 0.2))
		elif not base.has("color"):
			base["color"] = Color(0.95, 0.75, 0.2)
		result.append(base)

	return result

static func get_loadout(index: int) -> Dictionary:
	var all = get_loadouts()
	if index >= 0 and index < all.size():
		return all[index]
	return {}

static func save_all_loadouts(all_loadouts: Array) -> bool:
	var data = load_player_data()
	var serialized_loadouts: Array[Dictionary] = []
	for l in all_loadouts:
		if l is Dictionary:
			var s = l.duplicate()
			if s.has("color") and s["color"] is Color:
				s["color_hex"] = (s["color"] as Color).to_html()
				s.erase("color")
			serialized_loadouts.append(s)
	data["loadouts"] = serialized_loadouts
	return save_player_data(data)

static func save_loadout(index: int, loadout_data: Dictionary) -> bool:
	if index < 0 or index >= 10:
		return false
	var data = load_player_data()
	var all_loadouts = get_loadouts()
	
	var to_save = loadout_data.duplicate()
	if to_save.has("color") and to_save["color"] is Color:
		to_save["color_hex"] = (to_save["color"] as Color).to_html()
		to_save.erase("color")
		
	all_loadouts[index] = to_save
	
	# Sanitizar todos os loadouts para formato serializável
	var serialized_loadouts: Array[Dictionary] = []
	for l in all_loadouts:
		var s = l.duplicate()
		if s.has("color") and s["color"] is Color:
			s["color_hex"] = (s["color"] as Color).to_html()
			s.erase("color")
		serialized_loadouts.append(s)
		
	data["loadouts"] = serialized_loadouts
	return save_player_data(data)

static func rename_loadout(index: int, new_name: String) -> bool:
	if index < 0 or index >= 10:
		return false
	var clean_name = new_name.strip_edges()
	if clean_name.is_empty():
		return false
	var all_loadouts = get_loadouts()
	all_loadouts[index]["name"] = clean_name
	return save_loadout(index, all_loadouts[index])

static func duplicate_loadout(from_idx: int, to_idx: int) -> bool:
	if from_idx < 0 or from_idx >= 10 or to_idx < 0 or to_idx >= 10:
		return false
	var all_loadouts = get_loadouts()
	var copied = all_loadouts[from_idx].duplicate(true)
	copied["id"] = to_idx + 1
	copied["name"] = "%s (Cópia)" % copied.get("name", "Custom")
	return save_loadout(to_idx, copied)

static func reset_loadout(index: int) -> bool:
	if index < 0 or index >= 10:
		return false
	var defaults = get_default_loadouts()
	return save_loadout(index, defaults[index])

static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_FILE):
		DirAccess.remove_absolute(SAVE_FILE)


