# =============================================================================
# rank_badge_registry.gd
# Registro Oficial de Patentes, Insígnias e Prestígios — Padrão CoD Black Ops 3
# 55 Níveis Militares + 10 Níveis de Prestígio + Mestre do Prestígio (Níveis 56-1000)
# Suporta renderização dinâmica de insígnias vetoriais (SVG), cores táticas e tags
# =============================================================================
class_name RankBadgeRegistry
extends RefCounted

## Estrutura de dados de uma Patente Militar (1 a 55)
const MILITARY_RANKS: Array[Dictionary] = [
	{
		"tier": 1,
		"min_lvl": 1, "max_lvl": 3,
		"title": "RECRUTA", "tag": "PVT",
		"icon_unicode": "˄",
		"color": Color(0.72, 0.75, 0.80), # Prata fosca
		"svg_symbol": "single_chevron"
	},
	{
		"tier": 2,
		"min_lvl": 4, "max_lvl": 6,
		"title": "SOLDADO DE 1ª CLASSE", "tag": "PFC",
		"icon_unicode": "˄_",
		"color": Color(0.65, 0.82, 0.75), # Verde militar claro
		"svg_symbol": "chevron_rocker"
	},
	{
		"tier": 3,
		"min_lvl": 7, "max_lvl": 9,
		"title": "ESPECIALISTA", "tag": "SPEC",
		"icon_unicode": "🛡️",
		"color": Color(0.55, 0.85, 0.90), # Ciano tático
		"svg_symbol": "specialist_shield"
	},
	{
		"tier": 4,
		"min_lvl": 10, "max_lvl": 12,
		"title": "CABO", "tag": "CPL",
		"icon_unicode": "˄˄",
		"color": Color(0.40, 0.88, 0.70), # Esmeralda tática
		"svg_symbol": "double_chevron"
	},
	{
		"tier": 5,
		"min_lvl": 13, "max_lvl": 15,
		"title": "TERCEIRO SARGENTO", "tag": "SGT",
		"icon_unicode": "˄˄˄",
		"color": Color(0.30, 0.85, 1.00), # Azul cobalto militar
		"svg_symbol": "triple_chevron"
	},
	{
		"tier": 6,
		"min_lvl": 16, "max_lvl": 18,
		"title": "SEGUNDO SARGENTO", "tag": "SSG",
		"icon_unicode": "🎖️",
		"color": Color(0.35, 0.75, 1.00), # Azul marinho vivo
		"svg_symbol": "triple_chevron_1rocker"
	},
	{
		"tier": 7,
		"min_lvl": 19, "max_lvl": 21,
		"title": "PRIMEIRO SARGENTO", "tag": "GSG",
		"icon_unicode": "🎖️",
		"color": Color(0.45, 0.70, 0.95),
		"svg_symbol": "triple_chevron_2rockers"
	},
	{
		"tier": 8,
		"min_lvl": 22, "max_lvl": 24,
		"title": "SUBTENENTE", "tag": "MSG",
		"icon_unicode": "🎖️",
		"color": Color(0.55, 0.95, 0.75),
		"svg_symbol": "triple_chevron_3rockers"
	},
	{
		"tier": 9,
		"min_lvl": 25, "max_lvl": 27,
		"title": "PRIMEIRO SARGENTO CHEFE", "tag": "1SG",
		"icon_unicode": "⭐",
		"color": Color(0.95, 0.80, 0.30), # Dourado leve
		"svg_symbol": "first_sergeant_diamond"
	},
	{
		"tier": 10,
		"min_lvl": 28, "max_lvl": 30,
		"title": "SARGENTO-MOR", "tag": "MGySgt",
		"icon_unicode": "⭐",
		"color": Color(0.98, 0.75, 0.25),
		"svg_symbol": "master_gunnery_bomb"
	},
	{
		"tier": 11,
		"min_lvl": 31, "max_lvl": 33,
		"title": "SARGENTO-MOR DE COMANDO", "tag": "SgtMaj",
		"icon_unicode": "⭐",
		"color": Color(1.00, 0.70, 0.20),
		"svg_symbol": "sergeant_major_star"
	},
	{
		"tier": 12,
		"min_lvl": 34, "max_lvl": 36,
		"title": "SEGUNDO TENENTE", "tag": "2LT",
		"icon_unicode": "❚",
		"color": Color(1.00, 0.82, 0.15), # Barra de Ouro
		"svg_symbol": "gold_bar"
	},
	{
		"tier": 13,
		"min_lvl": 37, "max_lvl": 39,
		"title": "PRIMEIRO TENENTE", "tag": "1LT",
		"icon_unicode": "❚",
		"color": Color(0.90, 0.95, 1.00), # Barra de Prata
		"svg_symbol": "silver_bar"
	},
	{
		"tier": 14,
		"min_lvl": 40, "max_lvl": 42,
		"title": "CAPITÃO", "tag": "CPT",
		"icon_unicode": "❚❚",
		"color": Color(0.95, 0.98, 1.00), # Barras Duplas de Prata
		"svg_symbol": "double_silver_bars"
	},
	{
		"tier": 15,
		"min_lvl": 43, "max_lvl": 45,
		"title": "MAJOR", "tag": "MAJ",
		"icon_unicode": "☘",
		"color": Color(1.00, 0.78, 0.10), # Folha de Carvalho Dourada
		"svg_symbol": "gold_oak_leaf"
	},
	{
		"tier": 16,
		"min_lvl": 46, "max_lvl": 48,
		"title": "TENENTE-CORONEL", "tag": "LTC",
		"icon_unicode": "⚜",
		"color": Color(0.85, 0.92, 1.00), # Folha de Carvalho Prateada
		"svg_symbol": "silver_oak_leaf"
	},
	{
		"tier": 17,
		"min_lvl": 49, "max_lvl": 51,
		"title": "CORONEL", "tag": "COL",
		"icon_unicode": "🦅",
		"color": Color(1.00, 0.88, 0.40), # Águia de Prata/Ouro
		"svg_symbol": "silver_eagle"
	},
	{
		"tier": 18,
		"min_lvl": 52, "max_lvl": 54,
		"title": "GENERAL DE BRIGADA", "tag": "BG",
		"icon_unicode": "🌟",
		"color": Color(1.00, 0.65, 0.15), # Estrela General
		"svg_symbol": "general_stars"
	},
	{
		"tier": 19,
		"min_lvl": 55, "max_lvl": 55,
		"title": "GENERAL DE EXÉRCITO (COMANDANTE)", "tag": "CMD",
		"icon_unicode": "👑",
		"color": Color(1.00, 0.45, 0.15), # Âmbar Radiante / Ouro Fogo
		"svg_symbol": "commander_skull_crest"
	}
]

## Emblemas e Títulos de Prestígio (1 a 10 + Mestre do Prestígio)
const PRESTIGE_LEVELS: Array[Dictionary] = [
	{
		"prestige": 1,
		"title": "PRESTÍGIO I — ELMO ESPARTANO", "tag": "P1",
		"icon_unicode": "🛡️",
		"color": Color(0.95, 0.75, 0.20),
		"svg_symbol": "prestige_spartan"
	},
	{
		"prestige": 2,
		"title": "PRESTÍGIO II — MACHADO DE GUERRA", "tag": "P2",
		"icon_unicode": "⚔️",
		"color": Color(0.90, 0.50, 0.20),
		"svg_symbol": "prestige_axe"
	},
	{
		"prestige": 3,
		"title": "PRESTÍGIO III — DRAGÃO TÁTICO", "tag": "P3",
		"icon_unicode": "🐉",
		"color": Color(0.30, 0.90, 0.70),
		"svg_symbol": "prestige_dragon"
	},
	{
		"prestige": 4,
		"title": "PRESTÍGIO IV — SERPENTE & ADAGA", "tag": "P4",
		"icon_unicode": "🗡️",
		"color": Color(0.40, 0.80, 1.00),
		"svg_symbol": "prestige_dagger"
	},
	{
		"prestige": 5,
		"title": "PRESTÍGIO V — CAVEIRA DEMONÍACA", "tag": "P5",
		"icon_unicode": "💀",
		"color": Color(0.95, 0.25, 0.25),
		"svg_symbol": "prestige_skull"
	},
	{
		"prestige": 6,
		"title": "PRESTÍGIO VI — FÊNIX DE FOGO", "tag": "P6",
		"icon_unicode": "🔥",
		"color": Color(1.00, 0.45, 0.10),
		"svg_symbol": "prestige_phoenix"
	},
	{
		"prestige": 7,
		"title": "PRESTÍGIO VII — CÉRBERO", "tag": "P7",
		"icon_unicode": "🐺",
		"color": Color(0.75, 0.35, 0.95),
		"svg_symbol": "prestige_cerberus"
	},
	{
		"prestige": 8,
		"title": "PRESTÍGIO VIII — CAVEIRA CIBERNÉTICA", "tag": "P8",
		"icon_unicode": "🤖",
		"color": Color(0.20, 0.95, 0.90),
		"svg_symbol": "prestige_cyberskull"
	},
	{
		"prestige": 9,
		"title": "PRESTÍGIO IX — CEIFADOR BLINDADO", "tag": "P9",
		"icon_unicode": "☠️",
		"color": Color(0.85, 0.15, 0.35),
		"svg_symbol": "prestige_reaper"
	},
	{
		"prestige": 10,
		"title": "PRESTÍGIO X — LEÃO DOURADO", "tag": "P10",
		"icon_unicode": "🦁",
		"color": Color(1.00, 0.85, 0.10),
		"svg_symbol": "prestige_lion"
	},
	{
		"prestige": 11, # Master Prestige (56 a 1000)
		"title": "MESTRE DO PRESTÍGIO", "tag": "MASTER",
		"icon_unicode": "👑",
		"color": Color(1.00, 0.88, 0.20),
		"svg_symbol": "prestige_master"
	}
]

## Cache em memória de texturas geradas para máxima performance
static var _texture_cache : Dictionary = {}

## Retorna os dados completos da patente atual
static func get_rank_data(level: int, prestige: int = 0) -> Dictionary:
	# 1. Se for Master Prestige (Prestígio >= 10 e Nível >= 56)
	if prestige >= 10 and level >= 56:
		var master_data = PRESTIGE_LEVELS[10].duplicate()
		master_data["level"] = level
		master_data["prestige"] = prestige
		master_data["is_master"] = true
		return master_data

	# 2. Se estiver em Prestígio (1 a 10)
	if prestige > 0:
		var p_idx = clampi(prestige - 1, 0, PRESTIGE_LEVELS.size() - 2)
		var p_data = PRESTIGE_LEVELS[p_idx].duplicate()
		p_data["level"] = level
		p_data["prestige"] = prestige
		p_data["is_master"] = false
		return p_data

	# 3. Nível Militar Padrão (1 a 55)
	var cl = clampi(level, 1, 55)
	for r in MILITARY_RANKS:
		if cl >= r["min_lvl"] and cl <= r["max_lvl"]:
			var data = r.duplicate()
			data["level"] = cl
			data["prestige"] = 0
			data["is_master"] = false
			return data

	return MILITARY_RANKS[0]

## Retorna o título formatado da patente
static func get_rank_title(level: int, prestige: int = 0) -> String:
	var data = get_rank_data(level, prestige)
	if data.get("is_master", false):
		return "MESTRE DO PRESTÍGIO %d" % level
	elif prestige > 0:
		return "%s (NÍVEL %d)" % [data.get("title", "PRESTÍGIO"), level]
	return str(data.get("title", "RECRUTA"))

## Retorna a tag curta militar da patente (Ex: [PVT], [SGT], [CMD], [P1])
static func get_rank_tag(level: int, prestige: int = 0) -> String:
	var data = get_rank_data(level, prestige)
	if data.get("is_master", false):
		return "[MST %d]" % level
	elif prestige > 0:
		return "[P%d %d]" % [prestige, level]
	return "[%s %d]" % [data.get("tag", "PVT"), level]

## Retorna o ícone em caractere Unicode ou emoji
static func get_rank_icon_symbol(level: int, prestige: int = 0) -> String:
	var data = get_rank_data(level, prestige)
	return str(data.get("icon_unicode", "★"))

## Retorna a cor distintiva da patente
static func get_rank_color(level: int, prestige: int = 0) -> Color:
	var data = get_rank_data(level, prestige)
	return data.get("color", Color(1.0, 0.85, 0.2))

## Gera e retorna uma Texture2D nítida da insígnia vetorial SVG
static func get_badge_texture(level: int, prestige: int = 0, size: int = 64) -> Texture2D:
	var cache_key = "%d_%d_%d" % [level, prestige, size]
	if _texture_cache.has(cache_key) and is_instance_valid(_texture_cache[cache_key]):
		return _texture_cache[cache_key]

	var data = get_rank_data(level, prestige)
	var sym = str(data.get("svg_symbol", "single_chevron"))
	var col: Color = data.get("color", Color(1.0, 0.85, 0.2))
	var hex_col = "#%02x%02x%02x" % [int(col.r * 255), int(col.g * 255), int(col.b * 255)]

	var svg_str = _build_svg_xml(sym, hex_col, size)
	var img = Image.new()
	var err = img.load_svg_from_string(svg_str, 1.0)
	if err == OK:
		var tex = ImageTexture.create_from_image(img)
		_texture_cache[cache_key] = tex
		return tex

	# Fallback caso SVG nativo falhe no ambiente
	var fallback_img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	fallback_img.fill(col)
	var fallback_tex = ImageTexture.create_from_image(fallback_img)
	_texture_cache[cache_key] = fallback_tex
	return fallback_tex

## Construtor interno de XML SVG com geometria militar tática de alta definição
static func _build_svg_xml(symbol: String, color_hex: String, size: int) -> String:
	var _s = float(size)
	var paths = ""

	match symbol:
		"single_chevron": # Recruta (1 Chevron)
			paths = """
				<polygon points="32,14 50,32 44,38 32,26 20,38 14,32" fill="%s" filter="drop-shadow(0px 2px 4px rgba(0,0,0,0.8))"/>
			""" % color_hex

		"chevron_rocker": # Soldado 1ª Classe (Chevron + Rocker)
			paths = """
				<polygon points="32,12 50,30 44,36 32,24 20,36 14,30" fill="%s"/>
				<path d="M 16 42 Q 32 50 48 42 L 48 48 Q 32 56 16 48 Z" fill="%s"/>
			""" % [color_hex, color_hex]

		"specialist_shield": # Especialista (Escudo)
			paths = """
				<polygon points="32,8 52,18 48,46 32,56 16,46 12,18" fill="none" stroke="%s" stroke-width="3"/>
				<polygon points="32,18 44,30 38,36 32,30 26,36 20,30" fill="%s"/>
			""" % [color_hex, color_hex]

		"double_chevron": # Cabo (2 Chevrons)
			paths = """
				<polygon points="32,10 50,28 44,34 32,22 20,34 14,28" fill="%s"/>
				<polygon points="32,24 50,42 44,48 32,36 20,48 14,42" fill="%s"/>
			""" % [color_hex, color_hex]

		"triple_chevron": # Sargento (3 Chevrons)
			paths = """
				<polygon points="32,8 50,24 44,30 32,18 20,30 14,24" fill="%s"/>
				<polygon points="32,20 50,36 44,42 32,30 20,42 14,36" fill="%s"/>
				<polygon points="32,32 50,48 44,54 32,42 20,54 14,48" fill="%s"/>
			""" % [color_hex, color_hex, color_hex]

		"triple_chevron_1rocker": # 2º Sargento (3 Chevrons + 1 Arco)
			paths = """
				<polygon points="32,6 50,22 44,28 32,16 20,28 14,22" fill="%s"/>
				<polygon points="32,17 50,33 44,39 32,27 20,39 14,33" fill="%s"/>
				<polygon points="32,28 50,44 44,50 32,38 20,50 14,44" fill="%s"/>
				<path d="M 16 52 Q 32 58 48 52 L 48 56 Q 32 62 16 56 Z" fill="%s"/>
			""" % [color_hex, color_hex, color_hex, color_hex]

		"triple_chevron_2rockers", "triple_chevron_3rockers": # 1º Sargento & Subtenente
			paths = """
				<polygon points="32,6 50,22 44,28 32,16 20,28 14,22" fill="%s"/>
				<polygon points="32,17 50,33 44,39 32,27 20,39 14,33" fill="%s"/>
				<polygon points="32,28 50,44 44,50 32,38 20,50 14,44" fill="%s"/>
				<path d="M 16 51 Q 32 57 48 51 L 48 54 Q 32 60 16 54 Z" fill="%s"/>
				<path d="M 17 56 Q 32 62 47 56 L 47 59 Q 32 65 17 59 Z" fill="%s"/>
			""" % [color_hex, color_hex, color_hex, color_hex, color_hex]

		"first_sergeant_diamond", "master_gunnery_bomb", "sergeant_major_star": # Sargentos Superiores
			paths = """
				<polygon points="32,6 50,22 44,28 32,16 20,28 14,22" fill="%s"/>
				<polygon points="32,17 50,33 44,39 32,27 20,39 14,33" fill="%s"/>
				<polygon points="32,28 50,44 44,50 32,38 20,50 14,44" fill="%s"/>
				<polygon points="32,30 36,36 32,42 28,36" fill="#FFFFFF"/>
				<path d="M 16 52 Q 32 58 48 52 L 48 56 Q 32 62 16 56 Z" fill="%s"/>
			""" % [color_hex, color_hex, color_hex, color_hex]

		"gold_bar", "silver_bar": # Tenentes (Barras)
			paths = """
				<rect x="26" y="12" width="12" height="40" rx="3" fill="%s" stroke="#FFFFFF" stroke-width="1.5"/>
			""" % color_hex

		"double_silver_bars": # Capitão (Barras Duplas)
			paths = """
				<rect x="20" y="12" width="9" height="40" rx="2" fill="%s" stroke="#FFFFFF" stroke-width="1"/>
				<rect x="35" y="12" width="9" height="40" rx="2" fill="%s" stroke="#FFFFFF" stroke-width="1"/>
			""" % [color_hex, color_hex]

		"gold_oak_leaf", "silver_oak_leaf": # Major & Tenente-Coronel (Folha de Carvalho)
			paths = """
				<path d="M 32 8 C 24 16 14 26 20 38 C 22 46 28 50 32 56 C 36 50 42 46 44 38 C 50 26 40 16 32 8 Z" fill="%s" stroke="#FFFFFF" stroke-width="1.5"/>
			""" % color_hex

		"silver_eagle": # Coronel (Águia de Guerra)
			paths = """
				<polygon points="32,10 38,18 48,16 52,28 42,34 46,50 32,44 18,50 22,34 12,28 16,16 26,18" fill="%s" stroke="#FFFFFF" stroke-width="1.5"/>
			""" % color_hex

		"general_stars": # General de Brigada (Estrela com Louros)
			paths = """
				<polygon points="32,12 37,24 49,24 40,32 43,44 32,36 21,44 24,32 15,24 27,24" fill="%s" stroke="#FFFFFF" stroke-width="1.5"/>
				<circle cx="32" cy="32" r="24" fill="none" stroke="%s" stroke-width="2" stroke-dasharray="4,4"/>
			""" % [color_hex, color_hex]

		"commander_skull_crest": # Nível 55 General de Exército / Comandante Supremo
			paths = """
				<circle cx="32" cy="32" r="26" fill="none" stroke="%s" stroke-width="3"/>
				<polygon points="32,8 35,16 44,16 37,22 40,30 32,25 24,30 27,22 20,16 29,16" fill="%s"/>
				<path d="M 22 26 C 22 18 42 18 42 26 C 42 34 38 40 38 46 L 26 46 C 26 40 22 34 22 26 Z" fill="%s"/>
				<circle cx="27" cy="28" r="2.5" fill="#111111"/>
				<circle cx="37" cy="28" r="2.5" fill="#111111"/>
				<line x1="28" y1="42" x2="36" y2="42" stroke="#111111" stroke-width="2"/>
			""" % [color_hex, color_hex, color_hex]

		_: # Emblemas de Prestígio (Brasão com Caveira Dourada e Chamas)
			paths = """
				<polygon points="32,6 56,18 48,50 32,60 16,50 8,18" fill="none" stroke="%s" stroke-width="3"/>
				<circle cx="32" cy="30" r="14" fill="%s"/>
				<circle cx="27" cy="28" r="3" fill="#0A0D14"/>
				<circle cx="37" cy="28" r="3" fill="#0A0D14"/>
				<polygon points="32,32 30,38 34,38" fill="#0A0D14"/>
				<rect x="26" y="40" width="12" height="4" rx="1" fill="%s"/>
			""" % [color_hex, color_hex, color_hex]

	return """<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 64 64">
		%s
	</svg>""" % [size, size, paths]
