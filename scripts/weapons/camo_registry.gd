# =============================================================================
# camo_registry.gd
# Registro central de camuflagens e pinturas táticas das armas
# MS-5: Gunsmith & Acessórios
# =============================================================================
class_name CamoRegistry
extends RefCounted

const CAMOS = {
	"default": {
		"id": "default",
		"name": "Padrão de Fábrica",
		"desc": "Acabamento original militar fosco",
		"albedo": Color(1.0, 1.0, 1.0, 1.0),
		"metallic": 0.85,
		"roughness": 0.35,
		"icon_color": Color(0.2, 0.2, 0.22, 1.0)
	},
	"desert": {
		"id": "desert",
		"name": "Coyote Tan (Deserto)",
		"desc": "Camuflagem tática para ambiente árido",
		"albedo": Color(0.78, 0.68, 0.50, 1.0),
		"metallic": 0.45,
		"roughness": 0.65,
		"icon_color": Color(0.78, 0.68, 0.50, 1.0)
	},
	"olive": {
		"id": "olive",
		"name": "Verde Floresta (OD Green)",
		"desc": "Padrão das Forças Especiais em selva",
		"albedo": Color(0.35, 0.44, 0.32, 1.0),
		"metallic": 0.50,
		"roughness": 0.60,
		"icon_color": Color(0.35, 0.44, 0.32, 1.0)
	},
	"urban": {
		"id": "urban",
		"name": "Digital Urbano",
		"desc": "Padrão cinza tático para combate CQB em edifícios",
		"albedo": Color(0.55, 0.62, 0.68, 1.0),
		"metallic": 0.70,
		"roughness": 0.45,
		"icon_color": Color(0.55, 0.62, 0.68, 1.0)
	},
	"red_tiger": {
		"id": "red_tiger",
		"name": "Tigre Vermelho (Red Tiger)",
		"desc": "Pintura lendária de prestígio e combate agressivo",
		"albedo": Color(0.92, 0.24, 0.24, 1.0),
		"metallic": 0.60,
		"roughness": 0.40,
		"icon_color": Color(0.92, 0.24, 0.24, 1.0)
	},
	"gold": {
		"id": "gold",
		"name": "Ouro Militar (Gold Mastery)",
		"desc": "Acabamento banhado a ouro reluzente de alta patente",
		"albedo": Color(1.25, 0.98, 0.32, 1.0),
		"metallic": 0.95,
		"roughness": 0.20,
		"icon_color": Color(1.0, 0.85, 0.2, 1.0)
	}
}

static func get_camo(id: String) -> Dictionary:
	if CAMOS.has(id):
		return CAMOS[id]
	return CAMOS["default"]

static func get_all_camos() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for k in ["default", "desert", "olive", "urban", "red_tiger", "gold"]:
		list.append(CAMOS[k])
	return list
