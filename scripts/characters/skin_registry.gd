# =============================================================================
# skin_registry.gd
# Registro central de skins de personagens: Contra-Terroristas (CT) e Terroristas (T)
# Suporta seleção por classe (Assalto, CQB, Suporte, Breacher) e customização manual
# =============================================================================
class_name SkinRegistry
extends RefCounted

const CharacterRetargeter = preload("res://scripts/characters/character_retargeter.gd")

enum Faction {
	COUNTER_TERRORIST = 1,
	TERRORIST = 2
}

const SKINS = {
	"ct_urban": {
		"id": "ct_urban",
		"name": "SEAL Team 6 (Urban)",
		"faction": Faction.COUNTER_TERRORIST,
		"default_class": "Assalto",
		"scene_path": "res://scenes/characters/skins/ct_urban.tscn",
		"desc": "Elite da Marinha dos EUA. Uniforme camuflado urbano para infiltração e fuzis de assalto."
	},
	"ct_sas": {
		"id": "ct_sas",
		"name": "SAS (Special Air Service)",
		"faction": Faction.COUNTER_TERRORIST,
		"default_class": "CQB",
		"scene_path": "res://scenes/characters/skins/ct_sas.tscn",
		"desc": "Forças especiais britânicas com máscara de gás e balaclava para operações CQB rápidas."
	},
	"ct_gsg9": {
		"id": "ct_gsg9",
		"name": "GSG-9 (Antiterrorismo Alemão)",
		"faction": Faction.COUNTER_TERRORIST,
		"default_class": "Suporte",
		"scene_path": "res://scenes/characters/skins/ct_gsg9.tscn",
		"desc": "Unidade federal tática alemã com capacete balístico pesado para suporte e fogo de cobertura."
	},
	"ct_gign": {
		"id": "ct_gign",
		"name": "GIGN (Gendarmerie Francesa)",
		"faction": Faction.COUNTER_TERRORIST,
		"default_class": "Breacher",
		"scene_path": "res://scenes/characters/skins/ct_gign.tscn",
		"desc": "Grupo de intervenção francês de alto risco com visor protetor para arrombamento e invasão."
	},
	"t_phoenix": {
		"id": "t_phoenix",
		"name": "Phoenix Connexion",
		"faction": Faction.TERRORIST,
		"default_class": "Assalto",
		"scene_path": "res://scenes/characters/skins/t_phoenix.tscn",
		"desc": "Célula paramilitar do Leste Europeu com balaclava clássica para combates abertos com fuzis."
	},
	"t_leet": {
		"id": "t_leet",
		"name": "Elite Crew (1337 Krew)",
		"faction": Faction.TERRORIST,
		"default_class": "CQB",
		"scene_path": "res://scenes/characters/skins/t_leet.tscn",
		"desc": "Operadores com óculos escuros e trajes de guerrilha no deserto para incursões velozes CQB."
	},
	"t_guerilla": {
		"id": "t_guerilla",
		"name": "Guerilla Warfare",
		"faction": Faction.TERRORIST,
		"default_class": "Suporte",
		"scene_path": "res://scenes/characters/skins/t_guerilla.tscn",
		"desc": "Guerrilheiros de selva com camuflagem tigrada e faixa vermelha para supressão contínua."
	},
	"t_arctic": {
		"id": "t_arctic",
		"name": "Arctic Avengers",
		"faction": Faction.TERRORIST,
		"default_class": "Breacher",
		"scene_path": "res://scenes/characters/skins/t_arctic.tscn",
		"desc": "Combatentes de ambientes frios com parka ártica branca para invasão pesada de impacto."
	}
}

static func get_skin_info(skin_id: String) -> Dictionary:
	if SKINS.has(skin_id):
		return SKINS[skin_id]
	return SKINS["ct_urban"]

static func get_default_skin_for_class(faction: int, class_name_str: String) -> String:
	match class_name_str:
		"Assalto", "Assalto Personalizado":
			return "ct_urban" if faction == Faction.COUNTER_TERRORIST else "t_phoenix"
		"CQB", "CQB Personalizado":
			return "ct_sas" if faction == Faction.COUNTER_TERRORIST else "t_leet"
		"Suporte", "Suporte Personalizado":
			return "ct_gsg9" if faction == Faction.COUNTER_TERRORIST else "t_guerilla"
		"Breacher", "Breacher Personalizado":
			return "ct_gign" if faction == Faction.COUNTER_TERRORIST else "t_arctic"
		_:
			return "ct_urban" if faction == Faction.COUNTER_TERRORIST else "t_phoenix"

static func get_skins_by_faction(faction: int) -> Array:
	var result = []
	for k in SKINS:
		if SKINS[k]["faction"] == faction:
			result.append(SKINS[k])
	return result

static func load_skin_scene(skin_id: String) -> PackedScene:
	var info = get_skin_info(skin_id)
	var path = info.get("scene_path", "")
	if ResourceLoader.exists(path):
		return load(path) as PackedScene
	return null

static func instantiate_skin(skin_id: String) -> Node3D:
	var pck = load_skin_scene(skin_id)
	if pck:
		var node = pck.instantiate() as Node3D
		CharacterRetargeter.retarget_model(node)
		return node
	return null
