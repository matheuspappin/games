# =============================================================================
# choose_class_screen.gd
# TELA DE ARMAMENTO & GUNSMITH 3D ESTILO CALL OF DUTY: BLACK OPS 6 (AAA)
# - Arquitetura de 2 Camadas:
#     * CAMADA 1: Bancada de Armas (Custom Loadout 1..10 com Cards Táticos e Arma 3D na bancada)
#     * CAMADA 2: Gunsmith 3D Dedicado (Close-up hero 3D com Sockets Espaciais flutuantes e Carrossel)
# - Totalmente desacoplado de menus genéricos / dropdowns
# - Pinos espaciais 3D unprojected em tempo real com linhas guia (Leader Lines)
# - Preview em tempo real de acessórios, camuflagens PBR e comparação de atributos
# - Atalho direto para o Estande de Tiro [ESPAÇO / T]
# =============================================================================
class_name ChooseClassScreen
extends CanvasLayer

const SkinRegistry = preload("res://scripts/characters/skin_registry.gd")
const WeaponModifier = preload("res://scripts/weapons/weapon_modifier.gd")
const CamoRegistry = preload("res://scripts/weapons/camo_registry.gd")
const SaveSystem = preload("res://scripts/systems/save_system.gd")
const WeaponVisualRegistry = preload("res://scripts/weapons/weapon_visual_registry.gd")
const PerkManager = preload("res://scripts/systems/perk_manager.gd")

signal class_selected(class_data: Dictionary)
signal screen_closed

enum UIMode {
	LOADOUT_WORKBENCH, # Camada 1: Bancada com cards e arma no suporte
	GUNSMITH_3D        # Camada 2: Gunsmith detalhado com sockets espaciais e carrossel
}

enum GunsmithTab {
	BUILD_WEAPON,      # Montar Arma (Sockets de Acessórios)
	CUSTOMIZE          # Personalizar (Camuflagens PBR)
}

# ── ESTADO PRINCIPAL ──────────────────────────────────────────────────────────
var is_open: bool = false
var has_chosen_initial_class: bool = false
var selected_class_index: int = 0
var pending_class_change: Dictionary = {}
var selected_faction: int = SkinRegistry.Faction.COUNTER_TERRORIST
var selected_skin_id: String = "ct_urban"
var current_primary_path: String = "res://resources/weapons/ak47.tres"
var current_secondary_path: String = "res://resources/weapons/pistol.tres"
var classes: Array[Dictionary] = []

var current_mode: UIMode = UIMode.LOADOUT_WORKBENCH
var current_gunsmith_tab: GunsmithTab = GunsmithTab.BUILD_WEAPON
var active_socket_id: String = "" # Socket atualmente aberto no carrossel

# ── REGISTRO DE ARMAS DO ARSENAL ──────────────────────────────────────────────
const WEAPON_REGISTRY: Array[Dictionary] = [
	{"name": "ACR 6.8 (Fuzil de Assalto)", "path": "res://resources/weapons/ak47.tres", "cat": "Fuzil de Assalto"},
	{"name": "M4A1 (Fuzil Tático)", "path": "res://resources/weapons/m4a1.tres", "cat": "Fuzil de Assalto"},
	{"name": "SCAR-H (Fuzil Pesado 7.62)", "path": "res://resources/weapons/scar_h.tres", "cat": "Fuzil de Assalto"},
	{"name": "Man-O-War (Fuzil BO3)", "path": "res://resources/weapons/man_o_war.tres", "cat": "Fuzil de Assalto"},
	{"name": "MP7 (Submetralhadora Ágil)", "path": "res://resources/weapons/mp7.tres", "cat": "Submetralhadora"},
	{"name": "PP90M1 (Tambor 64 Munições)", "path": "res://resources/weapons/pp90m1.tres", "cat": "Submetralhadora"},
	{"name": "VMP (Submetralhadora BO3)", "path": "res://resources/weapons/vmp.tres", "cat": "Submetralhadora"},
	{"name": "SMG-45 (Submetralhadora Tática)", "path": "res://resources/weapons/smg.tres", "cat": "Submetralhadora"},
	{"name": "LMG-63 (Metralhadora de Apoio)", "path": "res://resources/weapons/lmg.tres", "cat": "Metralhadora Leve"},
	{"name": "SPAS-12 (Escopeta Tática Pump)", "path": "res://resources/weapons/spas12.tres", "cat": "Escopeta"},
	{"name": "KRM-262 (Escopeta BO3 Devastadora)", "path": "res://resources/weapons/krm262.tres", "cat": "Escopeta"},
	{"name": "Sawnoff Shotgun (Cano Serrado)", "path": "res://resources/weapons/shotgun.tres", "cat": "Escopeta"}
]

# ── CLASSES PREDEFINIDAS ESTILO COD ───────────────────────────────────────────
const PRESET_CLASSES: Array[Dictionary] = [
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
		"barrel": "none",
		"underbarrel": "none",
		"mag": "none",
		"stock": "none",
		"grip": "none",
		"camo": "default",
		"color": Color(0.95, 0.75, 0.2),
		"color_hex": "#f2c033",
		"perk1": "flak_jacket",
		"perk2": "fast_hands",
		"perk3": "high_alert",
		"specialty": "enforcer",
		"lethal": "semtex",
		"tactical": "stim"
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
		"barrel": "none",
		"underbarrel": "none",
		"mag": "none",
		"stock": "none",
		"grip": "none",
		"camo": "default",
		"color": Color(0.3, 0.7, 1.0),
		"color_hex": "#4cb3ff",
		"perk1": "ghost",
		"perk2": "ninja",
		"perk3": "tracker",
		"specialty": "recon",
		"lethal": "semtex",
		"tactical": "flash"
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
		"barrel": "none",
		"underbarrel": "none",
		"mag": "none",
		"stock": "none",
		"grip": "none",
		"camo": "default",
		"color": Color(0.9, 0.65, 0.25),
		"color_hex": "#e6a640",
		"perk1": "flak_jacket",
		"perk2": "scavenger",
		"perk3": "tac_mask",
		"specialty": "strategist",
		"lethal": "frag",
		"tactical": "smoke"
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
		"barrel": "none",
		"underbarrel": "none",
		"mag": "none",
		"stock": "none",
		"grip": "none",
		"camo": "default",
		"color": Color(1.0, 0.35, 0.3),
		"color_hex": "#ff594d",
		"perk1": "dexterity",
		"perk2": "fast_hands",
		"perk3": "enforcer",
		"specialty": "enforcer",
		"lethal": "frag",
		"tactical": "stun"
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
		"barrel": "none",
		"underbarrel": "none",
		"mag": "none",
		"stock": "none",
		"grip": "none",
		"camo": "default",
		"color": Color(0.7, 0.45, 1.0),
		"color_hex": "#b373ff",
		"perk1": "ghost",
		"perk2": "tracker",
		"perk3": "high_alert",
		"specialty": "recon",
		"lethal": "semtex",
		"tactical": "smoke"
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
		"barrel": "none",
		"underbarrel": "none",
		"mag": "none",
		"stock": "none",
		"grip": "none",
		"camo": "default",
		"color": Color(0.2, 0.9, 0.7),
		"color_hex": "#33e6b3",
		"perk1": "dexterity",
		"perk2": "fast_hands",
		"perk3": "high_alert",
		"specialty": "enforcer",
		"lethal": "semtex",
		"tactical": "stim"
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
		"barrel": "none",
		"underbarrel": "none",
		"mag": "none",
		"stock": "none",
		"grip": "none",
		"camo": "default",
		"color": Color(0.4, 0.8, 0.95),
		"color_hex": "#66ccf2",
		"perk1": "flak_jacket",
		"perk2": "fast_hands",
		"perk3": "ghost",
		"specialty": "enforcer",
		"lethal": "semtex",
		"tactical": "stim"
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
		"barrel": "none",
		"underbarrel": "none",
		"mag": "none",
		"stock": "none",
		"grip": "none",
		"camo": "default",
		"color": Color(0.85, 0.55, 0.2),
		"color_hex": "#d98c33",
		"perk1": "flak_jacket",
		"perk2": "scavenger",
		"perk3": "tac_mask",
		"specialty": "strategist",
		"lethal": "frag",
		"tactical": "stim"
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
		"barrel": "none",
		"underbarrel": "none",
		"mag": "none",
		"stock": "none",
		"grip": "none",
		"camo": "default",
		"color": Color(0.5, 0.7, 0.6),
		"color_hex": "#80b399",
		"perk1": "ghost",
		"perk2": "ninja",
		"perk3": "tracker",
		"specialty": "recon",
		"lethal": "semtex",
		"tactical": "smoke"
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
		"barrel": "none",
		"underbarrel": "none",
		"mag": "none",
		"stock": "none",
		"grip": "none",
		"camo": "default",
		"color": Color(1.0, 0.85, 0.35),
		"color_hex": "#ffd959",
		"perk1": "flak_jacket",
		"perk2": "fast_hands",
		"perk3": "high_alert",
		"specialty": "enforcer",
		"lethal": "semtex",
		"tactical": "stim"
	}
]

# ── DEFINIÇÃO DOS SOCKETS ESPACIAIS GUNSMITH ──────────────────────────────────
const SOCKET_DEFINITIONS: Dictionary = {
	"optic": {
		"title": "MIRA",
		"title_en": "OPTIC",
		"icon": "🔭",
		"default_offset_3d": Vector3(0, 0.08, -0.02),
		"pin_direction": Vector2(0.3, -1.0), # Ângulo da linha para fora da arma
		"options": [
			{"id": "none", "name": "Miras de Ferro Padrão", "type": "Padrão de Fábrica", "pros": ["Visada Instantânea", "Sem Penalidades"], "cons": []},
			{"id": "optic_red_dot", "name": "Mira Red Dot Reflex", "type": "Mira Óptica 1x", "pros": ["+ Aquisição de Alvos", "+ Precisão Geral"], "cons": ["- 4% Velocidade ADS"]},
			{"id": "optic_holo", "name": "Holográfica EOTech 553", "type": "Holográfica Tática", "pros": ["+ Retículo Limpo", "+ Alcance Efetivo"], "cons": ["- 7% Velocidade ADS"]},
			{"id": "optic_sniper", "name": "Luneta Tática 4x", "type": "Mira de Alta Precisão", "pros": ["+ Zoom Ótico 4x", "+ Alcance Máximo"], "cons": ["- 14% Velocidade ADS", "- Visão Periférica"]}
		]
	},
	"muzzle": {
		"title": "BOCA",
		"title_en": "MUZZLE",
		"icon": "🔇",
		"default_offset_3d": Vector3(0, 0.025, -0.45),
		"pin_direction": Vector2(-1.0, -0.2),
		"options": [
			{"id": "none", "name": "Sem Acessório de Boca", "type": "Padrão", "pros": ["Sem Penalidade de Peso"], "cons": []},
			{"id": "muzzle_suppressor", "name": "Silenciador Tático", "type": "Supressor Sonoro", "pros": ["+ Furtivo no Minimapa", "+ Recuo Horizontal Suave"], "cons": ["- 5% Alcance Efetivo"]},
			{"id": "muzzle_compensator", "name": "Compensador de Recuo", "type": "Freio de Boca", "pros": ["+ 25% Controle de Recuo Vertical", "+ Estabilidade"], "cons": ["- 6% Velocidade ADS"]}
		]
	},
	"barrel": {
		"title": "CANO",
		"title_en": "BARREL",
		"icon": "📏",
		"default_offset_3d": Vector3(0, 0.04, -0.25),
		"pin_direction": Vector2(-0.8, -0.8),
		"options": [
			{"id": "none", "name": "Cano Padrão 14.5\"", "type": "Padrão Militar", "pros": ["Balanceado para todas as distâncias"], "cons": []},
			{"id": "barrel_extended", "name": "Cano Longo Estriado 18\"", "type": "Cano de Precisão", "pros": ["+ 22% Alcance de Dano", "+ Velocidade do Projétil"], "cons": ["- 8% Mobilidade"]},
			{"id": "barrel_short", "name": "Cano Curto CQB 10.5\"", "type": "Cano Curto Ágil", "pros": ["+ 15% Velocidade ao Mirar", "+ Mobilidade Total"], "cons": ["- 15% Alcance Efetivo"]}
		]
	},
	"underbarrel": {
		"title": "EMPUNHADURA",
		"title_en": "UNDERBARREL",
		"icon": "✊",
		"default_offset_3d": Vector3(0, -0.06, -0.18),
		"pin_direction": Vector2(-0.8, 0.7),
		"options": [
			{"id": "none", "name": "Sem Empunhadura Frontal", "type": "Padrão", "pros": ["Leveza Original"], "cons": []},
			{"id": "grip_vertical", "name": "Empunhadura Vertical", "type": "Foregrip Tático", "pros": ["+ 28% Controle de Recuo Vertical", "+ Precisão Contínua"], "cons": ["- 5% Velocidade ADS"]},
			{"id": "grip_angled", "name": "Empunhadura Angular", "type": "Handstop Angulado", "pros": ["+ 18% Velocidade ADS", "+ Estabilidade ao Andar"], "cons": ["- 5% Controle Horizontal"]}
		]
	},
	"mag": {
		"title": "CARREGADOR",
		"title_en": "MAGAZINE",
		"icon": "🔋",
		"default_offset_3d": Vector3(0, -0.15, -0.02),
		"pin_direction": Vector2(0.0, 1.0),
		"options": [
			{"id": "none", "name": "Carregador Padrão (30 Projéteis)", "type": "Padrão", "pros": ["Tempo de Recarga Padrão"], "cons": []},
			{"id": "mag_extended", "name": "Carregador Estendido (45 Projéteis)", "type": "Alta Capacidade", "pros": ["+ 15 Projéteis por Tambor", "+ Sustentação de Fogo"], "cons": ["- 12% Tempo de Recarga", "- 3% Velocidade de Movimento"]},
			{"id": "mag_fast", "name": "Carregador Rápido Magpul", "type": "Puxada Rápida", "pros": ["+ 35% Velocidade de Recarga"], "cons": ["- Capacidade Padrão 30"]}
		]
	},
	"stock": {
		"title": "CORONHA",
		"title_en": "STOCK",
		"icon": "📐",
		"default_offset_3d": Vector3(0, 0.05, 0.28),
		"pin_direction": Vector2(0.8, -0.8),
		"options": [
			{"id": "none", "name": "Coronha Ajustável Padrão", "type": "Padrão", "pros": ["Balanceamento de Fábrica"], "cons": []},
			{"id": "stock_heavy", "name": "Coronha Tática Pesada", "type": "Estabilidade", "pros": ["+ 35% Resistência ao Flinch", "+ Estabilidade de Mira"], "cons": ["- 8% Velocidade ao Mirar Andando"]},
			{"id": "stock_light", "name": "Coronha de Deslocamento Rápido", "type": "Mobilidade", "pros": ["+ 25% Velocidade Strafe Mirando", "+ Sprint to Fire"], "cons": ["- 10% Controle de Recuo"]}
		]
	},
	"grip": {
		"title": "CABO",
		"title_en": "REAR GRIP",
		"icon": "🖐️",
		"default_offset_3d": Vector3(0, -0.09, 0.08),
		"pin_direction": Vector2(0.9, 0.5),
		"options": [
			{"id": "none", "name": "Empunhadura Padrão", "type": "Padrão", "pros": ["Ergonomia Original"], "cons": []},
			{"id": "grip_stippled", "name": "Empunhadura Granulada Tática", "type": "Aderência Rápida", "pros": ["+ 20% Velocidade Sprint-to-Fire", "+ Puxada Instantânea"], "cons": ["- 5% Estabilidade ao Disparar"]},
			{"id": "grip_rubber", "name": "Empunhadura Emborrachada Soft", "type": "Amortecimento", "pros": ["+ 15% Controle de Recuo Inicial"], "cons": ["- 3% Puxada ADS"]}
		]
	}
}

# ── CAMUFLAGENS DO SISTEMA ───────────────────────────────────────────────────
const CAMO_LIST: Array[Dictionary] = [
	{"id": "default", "name": "Padrão de Fábrica", "desc": "Acabamento militar fosco anodizado", "color": Color(0.25, 0.26, 0.28)},
	{"id": "desert", "name": "Coyote Tan", "desc": "Camuflagem tática para ambiente árido", "color": Color(0.78, 0.68, 0.50)},
	{"id": "olive", "name": "Verde Floresta (OD)", "desc": "Padrão das Forças Especiais em selva", "color": Color(0.35, 0.44, 0.32)},
	{"id": "urban", "name": "Digital Urbano", "desc": "Padrão cinza tático para combate CQB", "color": Color(0.55, 0.62, 0.68)},
	{"id": "red_tiger", "name": "Tigre Vermelho", "desc": "Pintura lendária de prestígio", "color": Color(0.92, 0.24, 0.24)},
	{"id": "gold", "name": "Ouro Militar (Gold)", "desc": "Acabamento banhado a ouro reluzente", "color": Color(1.0, 0.85, 0.20)},
	{"id": "dark_matter", "name": "Matéria Escura", "desc": "Camuflagem mística animada em roxo cósmico", "color": Color(0.65, 0.20, 0.95)},
	{"id": "carbon", "name": "Fibra de Carbono", "desc": "Textura leve de polímero aeroespacial", "color": Color(0.15, 0.16, 0.18)}
]

# ── NODES UI & 3D ─────────────────────────────────────────────────────────────
var root_control: Control
var bg_color_rect: ColorRect

# SubViewport 3D Stage
var subviewport_container: SubViewportContainer
var stage_subviewport: SubViewport
var stage_camera: Camera3D
var stage_turntable: Node3D
var weapon_pivot: Node3D
var weapon_model_wrapper: Node3D = null
var workbench_stand: Node3D = null
var workbench_knife_prop: Node3D = null
var workbench_grenade_prop: Node3D = null

# Câmera 3D Interativa
var target_cam_pos: Vector3 = Vector3(0.0, 0.05, 0.95)
var target_cam_fov: float = 34.0
var turntable_rot_y: float = -0.50
var turntable_pitch_x: float = 0.05
var is_dragging_mouse: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO

# Overlay de Pinos Espaciais (Gunsmith 3D)
var socket_overlay_control: Control
var socket_pins: Dictionary = {} # socket_key -> Control
var socket_screen_coords: Dictionary = {}

# Camada 1: Bancada de Armamento (Custom Loadouts)
var layer1_container: Control
var top_class_tabs_hbox: HBoxContainer
var lbl_loadout_title: Label
var lbl_map_phase: Label
var left_cards_container: VBoxContainer
var card_primary: PanelContainer
var lbl_card_primary_name: Label
var lbl_card_primary_cat: Label
var box_card_primary_attachments: HBoxContainer
var btn_open_gunsmith: Button
var btn_swap_primary: Button

var card_secondary: PanelContainer
var lbl_card_secondary_name: Label
var btn_swap_secondary: Button

var card_melee: PanelContainer
var lbl_card_melee_name: Label

var card_equipment: PanelContainer
var lbl_lethal_tag: Label
var lbl_tactical_tag: Label

var card_perks: PanelContainer
var box_perk_badges: HBoxContainer
var lbl_specialty_tag: Label

var card_operator: PanelContainer
var btn_faction_ct: Button
var btn_faction_t: Button
var lbl_skin_current: Label

# Painel de Atributos & Modificações
var stats_panel: PanelContainer
var lbl_stats_weapon_name: Label
var lbl_modifications_counter: Label
var box_mod_pips: HBoxContainer
var stat_bar_nodes: Dictionary = {}

# Camada 2: Gunsmith 3D Dedicado
var layer2_container: Control
var gunsmith_top_bar: HBoxContainer
var btn_tab_build: Button
var btn_tab_customize: Button
var lbl_gunsmith_weapon_name: Label

# Carrossel Inferior de Acessórios
var carousel_container: PanelContainer
var lbl_carousel_socket_title: Label
var carousel_scroll: ScrollContainer
var carousel_cards_hbox: HBoxContainer
var btn_close_carousel: Button

# Aba Personalizar (Camuflagens)
var customize_panel: PanelContainer
var camos_grid: GridContainer

# Rodapé de Ações
var footer_bar: HBoxContainer
var btn_confirm_deploy: Button
var btn_firing_range_shortcut: Button
var btn_back_button: Button

# Pop-up de Recurso Bloqueado (Gunsmith 3D Futura Atualização)
var gunsmith_locked_popup: PanelContainer = null
var is_hovering_gunsmith_button: bool = false
var locked_popup_held_timer: float = 0.0

# Modal de Renomear
var rename_modal_overlay: ColorRect = null
var rename_line_edit: LineEdit = null

# Tela BO3 de Arsenal
var bo3_weapon_select_screen: Node = null

# Sincronização e temporizador
var auto_close_timer: float = 0.0
var auto_close_max: float = 15.0
var is_initial_spawn: bool = true


# =============================================================================
# INICIALIZAÇÃO E CICLO DE VIDA
# =============================================================================
func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_classes_from_storage()
	_build_ui_scaffolding()
	_setup_3d_workbench_stage()
	visible = false

func _load_classes_from_storage() -> void:
	classes = SaveSystem.get_loadouts()
	if classes.is_empty():
		classes = PRESET_CLASSES.duplicate(true)

	# Garantir que todas as armas estejam em seu padrão de fábrica (Stock / Sem modificações forçadas)
	# para posterior implementação na futura atualização da bancada
	for c in classes:
		c["optic"] = "none"
		c["muzzle"] = "none"
		c["barrel"] = "none"
		c["underbarrel"] = "none"
		c["mag"] = "none"
		c["stock"] = "none"
		c["grip"] = "none"
		c["camo"] = "default"

	SaveSystem.save_all_loadouts(classes)

# =============================================================================
# CONSTRUÇÃO DO AMBIENTE VISUAL AAA
# =============================================================================
func _build_ui_scaffolding() -> void:
	root_control = Control.new()
	root_control.name = "RootGunsmithAAA"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	# Fundo degradê escuro militar
	bg_color_rect = ColorRect.new()
	bg_color_rect.name = "ArmoryBackground"
	bg_color_rect.color = Color(0.02, 0.03, 0.05, 0.96)
	bg_color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(bg_color_rect)

	# 1. 3D SubViewport Container (Ocupa a tela inteira em alta resolução)
	subviewport_container = SubViewportContainer.new()
	subviewport_container.name = "StageViewportContainer"
	subviewport_container.stretch = true
	subviewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	subviewport_container.mouse_filter = Control.MOUSE_FILTER_PASS
	root_control.add_child(subviewport_container)

	stage_subviewport = SubViewport.new()
	stage_subviewport.name = "StageSubViewport"
	stage_subviewport.transparent_bg = true
	stage_subviewport.handle_input_locally = false
	stage_subviewport.size = Vector2i(1920, 1080)
	subviewport_container.add_child(stage_subviewport)

	# 2. Overlay de Pinos Espaciais (Gunsmith 3D com linhas guia)
	socket_overlay_control = Control.new()
	socket_overlay_control.name = "SocketPinsOverlay"
	socket_overlay_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	socket_overlay_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	socket_overlay_control.draw.connect(_on_socket_overlay_draw)
	root_control.add_child(socket_overlay_control)

	_create_spatial_pin_buttons()

	# 3. Camada 1: Bancada de Armas (Custom Loadout 1..10)
	_build_layer1_workbench()

	# 4. Camada 2: Gunsmith 3D Dedicado
	_build_layer2_gunsmith()

	# 5. Painel de Estatísticas da Arma (Comum a ambas as camadas)
	_build_weapon_stats_hud()

	# 6. Rodapé Tático de Navegação
	_build_footer_bar()

# ─────────────────────────────────────────────────────────────────────────────
# 3D WORKBENCH STAGE & ILUMINAÇÃO ESTILO COD
# ─────────────────────────────────────────────────────────────────────────────
func _setup_3d_workbench_stage() -> void:
	stage_subviewport.own_world_3d = true
	var world_3d = stage_subviewport.find_world_3d()
	if not world_3d:
		world_3d = World3D.new()
		stage_subviewport.world_3d = world_3d

	# Ambiente escuro de hangar militar com ACES tonemapper
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.05, 0.0)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.15
	world_3d.environment = env

	# Câmera 3D com profundidade de campo suave
	stage_camera = Camera3D.new()
	stage_camera.name = "StageCamera"
	stage_camera.position = target_cam_pos
	stage_camera.fov = target_cam_fov
	stage_subviewport.add_child(stage_camera)

	# 1. Luz Chave (Key Light) - Frente e acima, neutra com reflexos metálicos
	var key_light = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-35, 30, 0)
	key_light.light_color = Color(1.0, 0.98, 0.94)
	key_light.light_energy = 1.6
	stage_subviewport.add_child(key_light)

	# 2. Luz de Borda Âmbar (Rim Light Signature BO6) - Ilumina o contorno da arma
	var rim_light = DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(15, -150, 0)
	rim_light.light_color = Color(1.0, 0.58, 0.12)
	rim_light.light_energy = 2.2
	stage_subviewport.add_child(rim_light)

	# 3. Luz de Preenchimento Tática (Fill Light) - Azulada fria
	var fill_light = DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-60, -70, 0)
	fill_light.light_color = Color(0.35, 0.55, 0.85)
	fill_light.light_energy = 0.65
	stage_subviewport.add_child(fill_light)

	# 4. Spot de Destaque no Receptor e Trilho Picatinny
	var accent_spot = SpotLight3D.new()
	accent_spot.position = Vector3(0.1, 0.4, 0.5)
	accent_spot.rotation_degrees = Vector3(-45, 10, 0)
	accent_spot.light_color = Color(1.0, 0.95, 0.85)
	accent_spot.light_energy = 1.4
	accent_spot.spot_range = 2.5
	accent_spot.spot_angle = 45.0
	stage_subviewport.add_child(accent_spot)

	# Bancada Tática de Armeiro (Mesa Metálica)
	var table_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(4.0, 0.06, 2.5)
	table_mesh.mesh = box
	var table_mat = StandardMaterial3D.new()
	table_mat.albedo_color = Color(0.06, 0.08, 0.11)
	table_mat.metallic = 0.94
	table_mat.roughness = 0.38
	table_mesh.material_override = table_mat
	table_mesh.position = Vector3(0.0, -0.20, 0.0)
	stage_subviewport.add_child(table_mesh)

	# Tapete Tático / Suporte de Armeiro (Gunsmith Vice)
	workbench_stand = Node3D.new()
	workbench_stand.name = "WorkbenchStand"
	workbench_stand.position = Vector3(0.0, -0.14, 0.0)
	stage_subviewport.add_child(workbench_stand)
	_build_gunsmith_vice_props(workbench_stand)

	# Turntable da Arma
	stage_turntable = Node3D.new()
	stage_turntable.name = "StageTurntable"
	stage_turntable.position = Vector3(0.0, 0.0, 0.0)
	stage_subviewport.add_child(stage_turntable)

	weapon_pivot = Node3D.new()
	weapon_pivot.name = "WeaponPivot"
	stage_turntable.add_child(weapon_pivot)

func _build_gunsmith_vice_props(parent: Node3D) -> void:
	# Base de apoio da bancada de armeiro
	var base_plate = MeshInstance3D.new()
	var b_box = BoxMesh.new()
	b_box.size = Vector3(0.72, 0.02, 0.18)
	base_plate.mesh = b_box
	var plate_mat = StandardMaterial3D.new()
	plate_mat.albedo_color = Color(0.08, 0.10, 0.14)
	plate_mat.metallic = 0.85
	plate_mat.roughness = 0.35
	base_plate.material_override = plate_mat
	base_plate.position = Vector3(0.0, -0.05, 0.0)
	parent.add_child(base_plate)

	# Suportes verticais de armeiro com berço de borracha
	for x_pos in [-0.20, 0.20]:
		var post = MeshInstance3D.new()
		var p_box = BoxMesh.new()
		p_box.size = Vector3(0.035, 0.08, 0.06)
		post.mesh = p_box
		var post_mat = StandardMaterial3D.new()
		post_mat.albedo_color = Color(0.12, 0.14, 0.18)
		post_mat.metallic = 0.8
		post_mat.roughness = 0.4
		post.material_override = post_mat
		post.position = Vector3(x_pos, -0.01, 0.0)
		parent.add_child(post)

		# Berço de borracha de proteção com friso laranja
		var pad = MeshInstance3D.new()
		var pad_box = BoxMesh.new()
		pad_box.size = Vector3(0.045, 0.015, 0.07)
		pad.mesh = pad_box
		var pad_mat = StandardMaterial3D.new()
		pad_mat.albedo_color = Color(0.95, 0.55, 0.12)
		pad_mat.roughness = 0.6
		pad.material_override = pad_mat
		pad.position = Vector3(x_pos, 0.035, 0.0)
		parent.add_child(pad)

# ─────────────────────────────────────────────────────────────────────────────
# PINOS ESPACIAIS COM LEADER LINES (GUNSMITH 3D DEDICADO)
# ─────────────────────────────────────────────────────────────────────────────
func _create_spatial_pin_buttons() -> void:
	for s_key in SOCKET_DEFINITIONS:
		var s_def = SOCKET_DEFINITIONS[s_key]

		var btn_pin = Button.new()
		btn_pin.name = "Pin_" + s_key
		btn_pin.custom_minimum_size = Vector2(160, 44)
		btn_pin.focus_mode = Control.FOCUS_NONE

		var st_norm = StyleBoxFlat.new()
		st_norm.bg_color = Color(0.06, 0.08, 0.12, 0.90)
		st_norm.border_color = Color(0.35, 0.45, 0.60, 0.60)
		st_norm.set_border_width_all(1)
		st_norm.set_corner_radius_all(6)
		st_norm.content_margin_left = 10
		st_norm.content_margin_right = 10
		btn_pin.add_theme_stylebox_override("normal", st_norm)

		var st_hov = st_norm.duplicate()
		st_hov.bg_color = Color(0.12, 0.16, 0.24, 0.95)
		st_hov.border_color = Color(1.0, 0.65, 0.15, 1.0)
		st_hov.set_border_width_all(2)
		btn_pin.add_theme_stylebox_override("hover", st_hov)

		var pin_vbox = VBoxContainer.new()
		pin_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pin_vbox.add_theme_constant_override("separation", 0)
		pin_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn_pin.add_child(pin_vbox)

		var lbl_tag = Label.new()
		lbl_tag.text = "⊕ " + s_def["title_en"]
		lbl_tag.add_theme_font_size_override("font_size", 10)
		lbl_tag.add_theme_color_override("font_color", Color(1.0, 0.70, 0.20, 1.0))
		pin_vbox.add_child(lbl_tag)

		var lbl_name = Label.new()
		lbl_name.name = "SubTitle"
		lbl_name.text = "PADRÃO"
		lbl_name.add_theme_font_size_override("font_size", 11)
		lbl_name.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96, 0.95))
		pin_vbox.add_child(lbl_name)

		btn_pin.pressed.connect(_on_socket_pin_pressed.bind(s_key))
		btn_pin.mouse_entered.connect(func(): _play_ui_tick())

		socket_overlay_control.add_child(btn_pin)
		socket_pins[s_key] = btn_pin

# ─────────────────────────────────────────────────────────────────────────────
# CAMADA 1: BANCADA DE ARMAMENTO (LOADOUT WORKBENCH)
# ─────────────────────────────────────────────────────────────────────────────
func _build_layer1_workbench() -> void:
	layer1_container = Control.new()
	layer1_container.name = "Layer1Workbench"
	layer1_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer1_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(layer1_container)

	# Cabeçalho Superior com Abas de Classes 1..10
	var top_panel = PanelContainer.new()
	top_panel.anchor_left = 0.03
	top_panel.anchor_right = 0.97
	top_panel.anchor_top = 0.03
	top_panel.anchor_bottom = 0.10
	var tp_st = StyleBoxFlat.new()
	tp_st.bg_color = Color(0.04, 0.06, 0.09, 0.85)
	tp_st.border_color = Color(0.2, 0.3, 0.45, 0.4)
	tp_st.set_border_width_all(1)
	tp_st.set_corner_radius_all(6)
	tp_st.content_margin_left = 16
	tp_st.content_margin_right = 16
	top_panel.add_theme_stylebox_override("panel", tp_st)
	layer1_container.add_child(top_panel)

	var top_hbox = HBoxContainer.new()
	top_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	top_hbox.add_theme_constant_override("separation", 16)
	top_panel.add_child(top_hbox)

	var title_vbox = VBoxContainer.new()
	title_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hbox.add_child(title_vbox)

	lbl_loadout_title = Label.new()
	lbl_loadout_title.text = "CUSTOM LOADOUT 1 - ASSALTO"
	lbl_loadout_title.add_theme_font_size_override("font_size", 16)
	lbl_loadout_title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.20, 1.0))
	title_vbox.add_child(lbl_loadout_title)

	lbl_map_phase = Label.new()
	lbl_map_phase.text = "FASE: NUKETOWN 2065 • SISTEMA DE ARMAMENTO TÁTICO"
	lbl_map_phase.add_theme_font_size_override("font_size", 10)
	lbl_map_phase.add_theme_color_override("font_color", Color(0.55, 0.65, 0.78, 0.8))
	title_vbox.add_child(lbl_map_phase)

	var sep = VSeparator.new()
	top_hbox.add_child(sep)

	# Seletor Rápido de Classes em Abas Horizontais (Estilo COD)
	var tabs_scroll = ScrollContainer.new()
	tabs_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	top_hbox.add_child(tabs_scroll)

	top_class_tabs_hbox = HBoxContainer.new()
	top_class_tabs_hbox.add_theme_constant_override("separation", 6)
	tabs_scroll.add_child(top_class_tabs_hbox)
	_rebuild_class_tabs()

	# Coluna Esquerda: Cards Táticos de Equipamento (Sem Dropdowns!)
	var cards_scroll = ScrollContainer.new()
	cards_scroll.anchor_left = 0.03
	cards_scroll.anchor_right = 0.35
	cards_scroll.anchor_top = 0.12
	cards_scroll.anchor_bottom = 0.90
	cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layer1_container.add_child(cards_scroll)

	left_cards_container = VBoxContainer.new()
	left_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_cards_container.add_theme_constant_override("separation", 8)
	cards_scroll.add_child(left_cards_container)

	_build_tactical_loadout_cards()

func _rebuild_class_tabs() -> void:
	for c in top_class_tabs_hbox.get_children():
		c.queue_free()

	for i in range(classes.size()):
		var cls = classes[i]
		var btn = Button.new()
		btn.name = "ClassTab_%d" % i
		btn.custom_minimum_size = Vector2(110, 36)
		btn.text = "[%02d] %s" % [i + 1, cls.get("name", "Custom").to_upper()]
		btn.add_theme_font_size_override("font_size", 11)
		btn.focus_mode = Control.FOCUS_NONE

		var is_sel = (i == selected_class_index)
		var st = StyleBoxFlat.new()
		if is_sel:
			st.bg_color = Color(1.0, 0.55, 0.12, 0.95)
			st.border_color = Color(1.0, 0.85, 0.4, 1.0)
			st.set_border_width_all(1)
			btn.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05, 1.0))
		else:
			st.bg_color = Color(0.08, 0.11, 0.16, 0.75)
			st.border_color = Color(0.25, 0.35, 0.5, 0.3)
			st.set_border_width_all(1)
			btn.add_theme_color_override("font_color", Color(0.85, 0.90, 0.96, 0.85))
		st.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", st)

		btn.pressed.connect(_select_class.bind(i))
		top_class_tabs_hbox.add_child(btn)

func _build_tactical_loadout_cards() -> void:
	# ── CARD 1: ARMA PRIMÁRIA (HERO CARD COM BOTÃO DIRETO GUNSMITH) ───────────
	card_primary = _create_tactical_card("ARMA PRIMÁRIA", Color(1.0, 0.65, 0.15))
	left_cards_container.add_child(card_primary)

	var p_vbox = card_primary.get_node("VBox")

	var p_head_hbox = HBoxContainer.new()
	p_vbox.add_child(p_head_hbox)

	lbl_card_primary_name = Label.new()
	lbl_card_primary_name.text = "ACR 6.8"
	lbl_card_primary_name.add_theme_font_size_override("font_size", 18)
	lbl_card_primary_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	lbl_card_primary_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_head_hbox.add_child(lbl_card_primary_name)

	lbl_card_primary_cat = Label.new()
	lbl_card_primary_cat.text = "FUZIL DE ASSALTO"
	lbl_card_primary_cat.add_theme_font_size_override("font_size", 10)
	lbl_card_primary_cat.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0, 0.9))
	p_head_hbox.add_child(lbl_card_primary_cat)

	box_card_primary_attachments = HBoxContainer.new()
	box_card_primary_attachments.add_theme_constant_override("separation", 6)
	p_vbox.add_child(box_card_primary_attachments)

	var p_act_hbox = HBoxContainer.new()
	p_act_hbox.add_theme_constant_override("separation", 8)
	p_vbox.add_child(p_act_hbox)

	btn_open_gunsmith = Button.new()
	btn_open_gunsmith.text = "🛠 [G] MONTAR ARMA"
	btn_open_gunsmith.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_open_gunsmith.custom_minimum_size = Vector2(0, 36)
	btn_open_gunsmith.add_theme_font_size_override("font_size", 12)
	btn_open_gunsmith.focus_mode = Control.FOCUS_NONE

	# Estilo tático trancado militar (bloqueado até futura atualização)
	var gs_st_norm = StyleBoxFlat.new()
	gs_st_norm.bg_color = Color(0.10, 0.12, 0.16, 0.90)
	gs_st_norm.border_color = Color(0.35, 0.40, 0.50, 0.65)
	gs_st_norm.set_border_width_all(1)
	gs_st_norm.set_corner_radius_all(4)
	btn_open_gunsmith.add_theme_stylebox_override("normal", gs_st_norm)
	btn_open_gunsmith.add_theme_color_override("font_color", Color(0.68, 0.72, 0.80, 0.85))

	var gs_st_hov = gs_st_norm.duplicate()
	gs_st_hov.bg_color = Color(0.14, 0.18, 0.24, 0.96)
	gs_st_hov.border_color = Color(1.0, 0.65, 0.15, 0.90)
	btn_open_gunsmith.add_theme_stylebox_override("hover", gs_st_hov)
	btn_open_gunsmith.add_theme_color_override("font_hover_color", Color(1.0, 0.78, 0.30, 1.0))

	var gs_st_press = gs_st_norm.duplicate()
	gs_st_press.bg_color = Color(0.08, 0.09, 0.12, 0.95)
	btn_open_gunsmith.add_theme_stylebox_override("pressed", gs_st_press)

	btn_open_gunsmith.pressed.connect(_switch_to_gunsmith_mode)
	p_act_hbox.add_child(btn_open_gunsmith)

	btn_swap_primary = Button.new()
	btn_swap_primary.text = "🔄 TROCAR"
	btn_swap_primary.custom_minimum_size = Vector2(75, 36)
	btn_swap_primary.add_theme_font_size_override("font_size", 11)
	btn_swap_primary.pressed.connect(_open_bo3_weapon_browser.bind("primary"))
	p_act_hbox.add_child(btn_swap_primary)

	# ── CARD 2: ARMA SECUNDÁRIA ───────────────────────────────────────────────
	card_secondary = _create_tactical_card("ARMA SECUNDÁRIA", Color(0.4, 0.7, 1.0))
	left_cards_container.add_child(card_secondary)
	var s_vbox = card_secondary.get_node("VBox")

	var s_hbox = HBoxContainer.new()
	s_vbox.add_child(s_hbox)

	lbl_card_secondary_name = Label.new()
	lbl_card_secondary_name.text = "M9 PISTOL"
	lbl_card_secondary_name.add_theme_font_size_override("font_size", 15)
	lbl_card_secondary_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s_hbox.add_child(lbl_card_secondary_name)

	btn_swap_secondary = Button.new()
	btn_swap_secondary.text = "🔄 TROCAR"
	btn_swap_secondary.custom_minimum_size = Vector2(75, 28)
	btn_swap_secondary.add_theme_font_size_override("font_size", 10)
	btn_swap_secondary.pressed.connect(_open_bo3_weapon_browser.bind("secondary"))
	s_hbox.add_child(btn_swap_secondary)

	# ── CARD 3: CORPO A CORPO & EQUIPAMENTOS ──────────────────────────────────
	card_equipment = _create_tactical_card("EQUIPAMENTOS TÁTICOS & LETAL", Color(0.3, 0.9, 0.5))
	left_cards_container.add_child(card_equipment)
	var eq_vbox = card_equipment.get_node("VBox")

	var eq_grid = GridContainer.new()
	eq_grid.columns = 2
	eq_grid.add_theme_constant_override("h_separation", 10)
	eq_grid.add_theme_constant_override("v_separation", 4)
	eq_vbox.add_child(eq_grid)

	lbl_tactical_tag = Label.new()
	lbl_tactical_tag.text = "🧪 TÁTICO: STIM SHOT"
	lbl_tactical_tag.add_theme_font_size_override("font_size", 11)
	eq_grid.add_child(lbl_tactical_tag)

	lbl_lethal_tag = Label.new()
	lbl_lethal_tag.text = "💣 LETAL: SEMTEX"
	lbl_lethal_tag.add_theme_font_size_override("font_size", 11)
	eq_grid.add_child(lbl_lethal_tag)

	# ── CARD 4: PACOTE DE VANTAGENS & ESPECIALIDADE BO6 ───────────────────────
	card_perks = _create_tactical_card("VANTAGENS & ESPECIALIDADE TÁTICA (BO6)", Color(0.85, 0.45, 1.0))
	left_cards_container.add_child(card_perks)
	var p_perks_vbox = card_perks.get_node("VBox")

	box_perk_badges = HBoxContainer.new()
	box_perk_badges.add_theme_constant_override("separation", 8)
	p_perks_vbox.add_child(box_perk_badges)

	lbl_specialty_tag = Label.new()
	lbl_specialty_tag.text = "★ ESPECIALIDADE: ENFORCER (SPEED & REGEN)"
	lbl_specialty_tag.add_theme_font_size_override("font_size", 11)
	lbl_specialty_tag.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	p_perks_vbox.add_child(lbl_specialty_tag)

	# ── CARD 5: OPERADOR & FACÇÃO ─────────────────────────────────────────────
	card_operator = _create_tactical_card("OPERADOR & UNIFORME", Color(0.7, 0.75, 0.85))
	left_cards_container.add_child(card_operator)
	var op_vbox = card_operator.get_node("VBox")

	var fac_hbox = HBoxContainer.new()
	fac_hbox.add_theme_constant_override("separation", 8)
	op_vbox.add_child(fac_hbox)

	btn_faction_ct = Button.new()
	btn_faction_ct.text = "📍 CONTRA-TERRORISTAS"
	btn_faction_ct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_faction_ct.custom_minimum_size = Vector2(0, 30)
	btn_faction_ct.add_theme_font_size_override("font_size", 11)
	btn_faction_ct.pressed.connect(func(): _set_faction(SkinRegistry.Faction.COUNTER_TERRORIST))
	fac_hbox.add_child(btn_faction_ct)

	btn_faction_t = Button.new()
	btn_faction_t.text = "🚩 TERRORISTAS"
	btn_faction_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_faction_t.custom_minimum_size = Vector2(0, 30)
	btn_faction_t.add_theme_font_size_override("font_size", 11)
	btn_faction_t.pressed.connect(func(): _set_faction(SkinRegistry.Faction.TERRORIST))
	fac_hbox.add_child(btn_faction_t)

	lbl_skin_current = Label.new()
	lbl_skin_current.text = "Uniforme: SEAL Team 6 (Urban)"
	lbl_skin_current.add_theme_font_size_override("font_size", 11)
	lbl_skin_current.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95, 0.85))
	op_vbox.add_child(lbl_skin_current)

func _create_tactical_card(title: String, accent_color: Color) -> PanelContainer:
	var pc = PanelContainer.new()
	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.08, 0.12, 0.92)
	st.border_color = Color(accent_color.r * 0.7, accent_color.g * 0.7, accent_color.b * 0.7, 0.45)
	st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	pc.add_theme_stylebox_override("panel", st)

	var vb = VBoxContainer.new()
	vb.name = "VBox"
	vb.add_theme_constant_override("separation", 6)
	pc.add_child(vb)

	var t_lbl = Label.new()
	t_lbl.text = title.to_upper()
	t_lbl.add_theme_font_size_override("font_size", 10)
	t_lbl.add_theme_color_override("font_color", accent_color)
	vb.add_child(t_lbl)

	return pc

# ─────────────────────────────────────────────────────────────────────────────
# CAMADA 2: GUNSMITH 3D DEDICADO (BUILD WEAPON & CUSTOMIZE)
# ─────────────────────────────────────────────────────────────────────────────
func _build_layer2_gunsmith() -> void:
	layer2_container = Control.new()
	layer2_container.name = "Layer2Gunsmith3D"
	layer2_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer2_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer2_container.visible = false
	root_control.add_child(layer2_container)

	# Barra Superior do Gunsmith (Tabs: Montar Arma | Personalizar)
	var top_bar_panel = PanelContainer.new()
	top_bar_panel.anchor_left = 0.03
	top_bar_panel.anchor_right = 0.97
	top_bar_panel.anchor_top = 0.03
	top_bar_panel.anchor_bottom = 0.09
	var tbp_st = StyleBoxFlat.new()
	tbp_st.bg_color = Color(0.04, 0.06, 0.09, 0.88)
	tbp_st.border_color = Color(0.2, 0.35, 0.5, 0.4)
	tbp_st.set_border_width_all(1)
	tbp_st.set_corner_radius_all(6)
	tbp_st.content_margin_left = 16
	tbp_st.content_margin_right = 16
	top_bar_panel.add_theme_stylebox_override("panel", tbp_st)
	layer2_container.add_child(top_bar_panel)

	gunsmith_top_bar = HBoxContainer.new()
	gunsmith_top_bar.add_theme_constant_override("separation", 20)
	top_bar_panel.add_child(gunsmith_top_bar)

	var title_lbl = Label.new()
	title_lbl.text = "GUNSMITH"
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	gunsmith_top_bar.add_child(title_lbl)

	lbl_gunsmith_weapon_name = Label.new()
	lbl_gunsmith_weapon_name.text = "ACR 6.8  |  NÍVEL 30 / 30"
	lbl_gunsmith_weapon_name.add_theme_font_size_override("font_size", 14)
	lbl_gunsmith_weapon_name.add_theme_color_override("font_color", Color(1.0, 0.70, 0.20))
	gunsmith_top_bar.add_child(lbl_gunsmith_weapon_name)

	var tabs_spacer = Control.new()
	tabs_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gunsmith_top_bar.add_child(tabs_spacer)

	btn_tab_build = Button.new()
	btn_tab_build.text = "[Q] MONTAR ARMA (BUILD WEAPON)"
	btn_tab_build.custom_minimum_size = Vector2(200, 34)
	btn_tab_build.focus_mode = Control.FOCUS_NONE
	btn_tab_build.pressed.connect(_set_gunsmith_tab.bind(GunsmithTab.BUILD_WEAPON))
	gunsmith_top_bar.add_child(btn_tab_build)

	btn_tab_customize = Button.new()
	btn_tab_customize.text = "[E] PERSONALIZAR (CUSTOMIZE)"
	btn_tab_customize.custom_minimum_size = Vector2(200, 34)
	btn_tab_customize.focus_mode = Control.FOCUS_NONE
	btn_tab_customize.pressed.connect(_set_gunsmith_tab.bind(GunsmithTab.CUSTOMIZE))
	gunsmith_top_bar.add_child(btn_tab_customize)

	# Carrossel Inferior de Acessórios (Aparece ao clicar em um Socket)
	carousel_container = PanelContainer.new()
	carousel_container.anchor_left = 0.03
	carousel_container.anchor_right = 0.70
	carousel_container.anchor_top = 0.70
	carousel_container.anchor_bottom = 0.92
	var cc_st = StyleBoxFlat.new()
	cc_st.bg_color = Color(0.05, 0.07, 0.11, 0.96)
	cc_st.border_color = Color(1.0, 0.65, 0.15, 0.9)
	cc_st.set_border_width_all(2)
	cc_st.set_corner_radius_all(8)
	cc_st.content_margin_left = 16
	cc_st.content_margin_right = 16
	cc_st.content_margin_top = 10
	cc_st.content_margin_bottom = 10
	carousel_container.add_theme_stylebox_override("panel", cc_st)
	carousel_container.visible = false
	layer2_container.add_child(carousel_container)

	var c_vbox = VBoxContainer.new()
	c_vbox.add_theme_constant_override("separation", 8)
	carousel_container.add_child(c_vbox)

	var c_head_hbox = HBoxContainer.new()
	c_vbox.add_child(c_head_hbox)

	lbl_carousel_socket_title = Label.new()
	lbl_carousel_socket_title.text = "ACESSÓRIOS DISPONÍVEIS: MIRA"
	lbl_carousel_socket_title.add_theme_font_size_override("font_size", 14)
	lbl_carousel_socket_title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
	lbl_carousel_socket_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c_head_hbox.add_child(lbl_carousel_socket_title)

	btn_close_carousel = Button.new()
	btn_close_carousel.text = "✖ FECHAR [ESC]"
	btn_close_carousel.focus_mode = Control.FOCUS_NONE
	btn_close_carousel.pressed.connect(_close_carousel)
	c_head_hbox.add_child(btn_close_carousel)

	carousel_scroll = ScrollContainer.new()
	carousel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	carousel_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	c_vbox.add_child(carousel_scroll)

	carousel_cards_hbox = HBoxContainer.new()
	carousel_cards_hbox.add_theme_constant_override("separation", 12)
	carousel_scroll.add_child(carousel_cards_hbox)

	# Painel de Camuflagens PBR (Aba Personalizar)
	customize_panel = PanelContainer.new()
	customize_panel.anchor_left = 0.03
	customize_panel.anchor_right = 0.65
	customize_panel.anchor_top = 0.68
	customize_panel.anchor_bottom = 0.92
	var cp_st = StyleBoxFlat.new()
	cp_st.bg_color = Color(0.05, 0.07, 0.11, 0.96)
	cp_st.border_color = Color(0.35, 0.55, 0.85, 0.8)
	cp_st.set_border_width_all(2)
	cp_st.set_corner_radius_all(8)
	cp_st.content_margin_left = 16
	cp_st.content_margin_right = 16
	cp_st.content_margin_top = 10
	cp_st.content_margin_bottom = 10
	customize_panel.add_theme_stylebox_override("panel", cp_st)
	customize_panel.visible = false
	layer2_container.add_child(customize_panel)

	var cust_vbox = VBoxContainer.new()
	cust_vbox.add_theme_constant_override("separation", 8)
	customize_panel.add_child(cust_vbox)

	var cust_head = Label.new()
	cust_head.text = "PINTURAS & CAMUFLAGENS MILITARES (PBR)"
	cust_head.add_theme_font_size_override("font_size", 14)
	cust_head.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	cust_vbox.add_child(cust_head)

	camos_grid = GridContainer.new()
	camos_grid.columns = 4
	camos_grid.add_theme_constant_override("h_separation", 12)
	camos_grid.add_theme_constant_override("v_separation", 8)
	cust_vbox.add_child(camos_grid)
	_build_camo_swatches()

# ─────────────────────────────────────────────────────────────────────────────
# HUD DE ATRIBUTOS TÁTICOS E MODIFICAÇÕES (5/5 SLOTS)
# ─────────────────────────────────────────────────────────────────────────────
func _build_weapon_stats_hud() -> void:
	stats_panel = PanelContainer.new()
	stats_panel.name = "StatsPanelHUD"
	stats_panel.anchor_left = 0.72
	stats_panel.anchor_right = 0.97
	stats_panel.anchor_top = 0.60
	stats_panel.anchor_bottom = 0.92
	var sp_st = StyleBoxFlat.new()
	sp_st.bg_color = Color(0.04, 0.06, 0.09, 0.92)
	sp_st.border_color = Color(0.25, 0.35, 0.5, 0.4)
	sp_st.set_border_width_all(1)
	sp_st.set_corner_radius_all(6)
	sp_st.content_margin_left = 16
	sp_st.content_margin_right = 16
	sp_st.content_margin_top = 10
	sp_st.content_margin_bottom = 10
	stats_panel.add_theme_stylebox_override("panel", sp_st)
	root_control.add_child(stats_panel)

	var s_vbox = VBoxContainer.new()
	s_vbox.add_theme_constant_override("separation", 4)
	stats_panel.add_child(s_vbox)

	var mod_hbox = HBoxContainer.new()
	s_vbox.add_child(mod_hbox)

	lbl_modifications_counter = Label.new()
	lbl_modifications_counter.text = "MODIFICAÇÕES 3 / 5"
	lbl_modifications_counter.add_theme_font_size_override("font_size", 12)
	lbl_modifications_counter.add_theme_color_override("font_color", Color(1.0, 0.65, 0.15))
	lbl_modifications_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mod_hbox.add_child(lbl_modifications_counter)

	box_mod_pips = HBoxContainer.new()
	box_mod_pips.add_theme_constant_override("separation", 4)
	mod_hbox.add_child(box_mod_pips)
	_rebuild_mod_pips(3, 5)

	var s_sep = HSeparator.new()
	s_vbox.add_child(s_sep)

	# 6 Barras de Atributos Táticos
	var stat_keys = [
		{"key": "damage", "name": "DANO (DAMAGE)"},
		{"key": "fire_rate", "name": "CADÊNCIA (FIRE RATE)"},
		{"key": "range", "name": "ALCANCE (RANGE)"},
		{"key": "accuracy", "name": "PRECISÃO (ACCURACY)"},
		{"key": "recoil", "name": "CONTROLE DE RECUO"},
		{"key": "mobility", "name": "MOBILIDADE (HANDLING)"}
	]

	for item in stat_keys:
		var k = item["key"]
		var row_hbox = HBoxContainer.new()
		s_vbox.add_child(row_hbox)

		var lbl_n = Label.new()
		lbl_n.text = item["name"]
		lbl_n.custom_minimum_size = Vector2(130, 0)
		lbl_n.add_theme_font_size_override("font_size", 10)
		lbl_n.add_theme_color_override("font_color", Color(0.75, 0.82, 0.90, 0.85))
		row_hbox.add_child(lbl_n)

		var bar = ProgressBar.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size = Vector2(0, 10)
		bar.min_value = 0
		bar.max_value = 100
		bar.value = 65
		bar.show_percentage = false

		var bg_bar = StyleBoxFlat.new()
		bg_bar.bg_color = Color(0.08, 0.10, 0.15, 0.9)
		bg_bar.set_corner_radius_all(2)
		bar.add_theme_stylebox_override("background", bg_bar)

		var fg_bar = StyleBoxFlat.new()
		fg_bar.bg_color = Color(0.95, 0.65, 0.15, 1.0)
		fg_bar.set_corner_radius_all(2)
		bar.add_theme_stylebox_override("fill", fg_bar)
		row_hbox.add_child(bar)

		var lbl_v = Label.new()
		lbl_v.text = "65"
		lbl_v.custom_minimum_size = Vector2(30, 0)
		lbl_v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_v.add_theme_font_size_override("font_size", 10)
		lbl_v.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
		row_hbox.add_child(lbl_v)

		stat_bar_nodes[k] = {"bar": bar, "val_lbl": lbl_v, "fg": fg_bar}

func _rebuild_mod_pips(current: int, total: int = 5) -> void:
	for c in box_mod_pips.get_children():
		c.queue_free()

	for i in range(total):
		var pip = ColorRect.new()
		pip.custom_minimum_size = Vector2(12, 6)
		pip.color = Color(1.0, 0.65, 0.15) if (i < current) else Color(0.2, 0.25, 0.35, 0.6)
		box_mod_pips.add_child(pip)

# ─────────────────────────────────────────────────────────────────────────────
# RODAPÉ DE AÇÕES TÁTICAS
# ─────────────────────────────────────────────────────────────────────────────
func _build_footer_bar() -> void:
	footer_bar = HBoxContainer.new()
	footer_bar.anchor_left = 0.03
	footer_bar.anchor_right = 0.97
	footer_bar.anchor_top = 0.93
	footer_bar.anchor_bottom = 0.98
	footer_bar.add_theme_constant_override("separation", 16)
	root_control.add_child(footer_bar)

	btn_back_button = Button.new()
	btn_back_button.text = "⮌ VOLTAR [ESC]"
	btn_back_button.custom_minimum_size = Vector2(140, 36)
	btn_back_button.pressed.connect(_on_back_pressed)
	footer_bar.add_child(btn_back_button)

	btn_firing_range_shortcut = Button.new()
	btn_firing_range_shortcut.text = "🎯 [ESPAÇO / T] TESTAR NO STAND (FIRING RANGE)"
	btn_firing_range_shortcut.custom_minimum_size = Vector2(280, 36)
	btn_firing_range_shortcut.pressed.connect(_on_firing_range_pressed)
	footer_bar.add_child(btn_firing_range_shortcut)

	var footer_spacer = Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_bar.add_child(footer_spacer)

	btn_confirm_deploy = Button.new()
	btn_confirm_deploy.text = "⚔ CONFIRMAR CLASSE [ENTER]"
	btn_confirm_deploy.custom_minimum_size = Vector2(220, 36)
	btn_confirm_deploy.add_theme_font_size_override("font_size", 13)

	var conf_st = StyleBoxFlat.new()
	conf_st.bg_color = Color(1.0, 0.65, 0.15, 0.95)
	conf_st.set_corner_radius_all(4)
	btn_confirm_deploy.add_theme_stylebox_override("normal", conf_st)
	btn_confirm_deploy.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	btn_confirm_deploy.pressed.connect(_on_confirm_pressed)
	footer_bar.add_child(btn_confirm_deploy)

# =============================================================================
# POP-UP TÁTICO: RECURSO BLOQUEADO (GUNSMITH 3D FUTURA ATUALIZAÇÃO)
# =============================================================================
func _build_gunsmith_locked_popup() -> void:
	if gunsmith_locked_popup:
		return

	gunsmith_locked_popup = PanelContainer.new()
	gunsmith_locked_popup.name = "GunsmithLockedPopup"
	gunsmith_locked_popup.visible = false
	gunsmith_locked_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gunsmith_locked_popup.custom_minimum_size = Vector2(360, 0)

	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.04, 0.06, 0.10, 0.96)
	st.border_color = Color(1.0, 0.65, 0.15, 0.90)
	st.set_border_width_all(2)
	st.set_corner_radius_all(6)
	st.shadow_color = Color(0.0, 0.0, 0.0, 0.85)
	st.shadow_size = 14
	st.shadow_offset = Vector2(0, 4)
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 14
	st.content_margin_bottom = 14
	gunsmith_locked_popup.add_theme_stylebox_override("panel", st)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	gunsmith_locked_popup.add_child(vb)

	# Cabeçalho com ícone de cadeado e tag "EM BREVE"
	var hb_head = HBoxContainer.new()
	hb_head.add_theme_constant_override("separation", 8)
	vb.add_child(hb_head)

	var lbl_title = Label.new()
	lbl_title.text = "🔒 RECURSO EM DESENVOLVIMENTO"
	lbl_title.add_theme_font_size_override("font_size", 12)
	lbl_title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.20))
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb_head.add_child(lbl_title)

	var tag_lbl = Label.new()
	tag_lbl.text = " [ EM BREVE ] "
	tag_lbl.add_theme_font_size_override("font_size", 10)
	tag_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0, 0.95))
	hb_head.add_child(tag_lbl)

	var sep = HSeparator.new()
	var sep_st = StyleBoxLine.new()
	sep_st.color = Color(1.0, 0.65, 0.15, 0.35)
	sep_st.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_st)
	vb.add_child(sep)

	# Mensagem explicativa
	var lbl_body = Label.new()
	lbl_body.text = "A bancada de armamento (Gunsmith 3D) e personalização de acessórios (miras ópticas, carregadores estendidos, canos e supressores) serão implementadas em uma futura grande atualização do jogo!"
	lbl_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_body.add_theme_font_size_override("font_size", 11)
	lbl_body.add_theme_color_override("font_color", Color(0.90, 0.94, 0.98, 0.95))
	vb.add_child(lbl_body)

	# Sub-nota tática
	var lbl_note = Label.new()
	lbl_note.text = "★ Todas as armas permanecem em sua configuração original de fábrica para que novas opções de mira e afins cheguem como novidades."
	lbl_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_note.add_theme_font_size_override("font_size", 10)
	lbl_note.add_theme_color_override("font_color", Color(0.65, 0.75, 0.88, 0.80))
	vb.add_child(lbl_note)

	root_control.add_child(gunsmith_locked_popup)

func _show_gunsmith_locked_popup() -> void:
	if not gunsmith_locked_popup:
		_build_gunsmith_locked_popup()

	if not btn_open_gunsmith or not btn_open_gunsmith.is_inside_tree():
		return

	var btn_rect = btn_open_gunsmith.get_global_rect()
	var vp_rect = get_viewport().get_visible_rect()

	var pos_x = btn_rect.end.x + 16.0
	var pos_y = btn_rect.position.y - 12.0

	# Prevenir estouro de tela à direita
	if pos_x + 370.0 > vp_rect.size.x:
		pos_x = maxf(20.0, btn_rect.position.x)
		pos_y = maxf(40.0, btn_rect.position.y - 140.0)

	gunsmith_locked_popup.global_position = Vector2(pos_x, pos_y)
	gunsmith_locked_popup.visible = true
	gunsmith_locked_popup.modulate.a = 0.0

	var tw = create_tween()
	tw.tween_property(gunsmith_locked_popup, "modulate:a", 1.0, 0.15)

func _hide_gunsmith_locked_popup() -> void:
	if not gunsmith_locked_popup or not gunsmith_locked_popup.visible:
		return
	var tw = create_tween()
	tw.tween_property(gunsmith_locked_popup, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func():
		if not is_hovering_gunsmith_button and locked_popup_held_timer <= 0.0 and gunsmith_locked_popup:
			gunsmith_locked_popup.visible = false
	)

func _on_gunsmith_button_mouse_entered() -> void:
	is_hovering_gunsmith_button = true
	_show_gunsmith_locked_popup()
	_play_ui_tick()

func _on_gunsmith_button_mouse_exited() -> void:
	is_hovering_gunsmith_button = false
	if locked_popup_held_timer <= 0.0:
		_hide_gunsmith_locked_popup()

func _on_gunsmith_locked_triggered() -> void:
	_play_mechanical_click()
	is_hovering_gunsmith_button = true
	locked_popup_held_timer = 2.8
	_show_gunsmith_locked_popup()

	if gunsmith_locked_popup:
		var orig_pos = gunsmith_locked_popup.global_position
		var tw = create_tween()
		tw.tween_property(gunsmith_locked_popup, "global_position:x", orig_pos.x + 6.0, 0.04)
		tw.tween_property(gunsmith_locked_popup, "global_position:x", orig_pos.x - 6.0, 0.04)
		tw.tween_property(gunsmith_locked_popup, "global_position:x", orig_pos.x + 3.0, 0.04)
		tw.tween_property(gunsmith_locked_popup, "global_position:x", orig_pos.x, 0.04)

# =============================================================================
# TRANSIÇÃO ENTRE MODOS (BANCADA vs GUNSMITH 3D)
# =============================================================================
func _switch_to_gunsmith_mode() -> void:
	current_mode = UIMode.GUNSMITH_3D
	layer1_container.visible = false
	layer2_container.visible = true
	socket_overlay_control.visible = true

	# Transição da Câmera: Aproximação Heroic Close-up
	target_cam_pos = Vector3(0.0, 0.02, 0.72)
	target_cam_fov = 30.0

	# Esconder adereços de bancada para focar puramente na arma e nos sockets
	if workbench_stand: workbench_stand.visible = false

	_set_gunsmith_tab(GunsmithTab.BUILD_WEAPON)
	_update_socket_pin_titles()
	_play_ui_tick()

func _switch_to_workbench_mode() -> void:
	current_mode = UIMode.LOADOUT_WORKBENCH
	layer1_container.visible = true
	layer2_container.visible = false
	socket_overlay_control.visible = false
	carousel_container.visible = false
	customize_panel.visible = false

	# Transição da Câmera: Visão de bancada ampla
	target_cam_pos = Vector3(0.0, 0.05, 0.95)
	target_cam_fov = 34.0
	turntable_rot_y = -0.50
	turntable_pitch_x = 0.05

	if workbench_stand: workbench_stand.visible = true

	_refresh_layer1_cards()
	_play_ui_tick()

func _set_gunsmith_tab(tab: GunsmithTab) -> void:
	current_gunsmith_tab = tab

	var active_st = StyleBoxFlat.new()
	active_st.bg_color = Color(1.0, 0.55, 0.12, 0.95)
	active_st.set_corner_radius_all(4)

	var inactive_st = StyleBoxFlat.new()
	inactive_st.bg_color = Color(0.08, 0.11, 0.16, 0.8)
	inactive_st.set_corner_radius_all(4)

	if tab == GunsmithTab.BUILD_WEAPON:
		btn_tab_build.add_theme_stylebox_override("normal", active_st)
		btn_tab_build.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
		btn_tab_customize.add_theme_stylebox_override("normal", inactive_st)
		btn_tab_customize.add_theme_color_override("font_color", Color(0.85, 0.90, 0.96, 0.8))

		socket_overlay_control.visible = true
		customize_panel.visible = false
	else:
		btn_tab_customize.add_theme_stylebox_override("normal", active_st)
		btn_tab_customize.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
		btn_tab_build.add_theme_stylebox_override("normal", inactive_st)
		btn_tab_build.add_theme_color_override("font_color", Color(0.85, 0.90, 0.96, 0.8))

		socket_overlay_control.visible = false
		carousel_container.visible = false
		customize_panel.visible = true

# =============================================================================
# CARROSSEL DE ACESSÓRIOS & PERSONALIZAÇÃO (ABA BUILD WEAPON)
# =============================================================================
func _on_socket_pin_pressed(socket_key: String) -> void:
	active_socket_id = socket_key
	var s_def = SOCKET_DEFINITIONS.get(socket_key, {})
	if s_def.is_empty():
		return

	lbl_carousel_socket_title.text = "ACESSÓRIOS DISPONÍVEIS: %s (%s)" % [s_def["title"], s_def["title_en"]]
	carousel_container.visible = true

	for c in carousel_cards_hbox.get_children():
		c.queue_free()

	var cur_class = classes[selected_class_index]
	var equipped_id = cur_class.get(socket_key, "none")

	for opt in s_def["options"]:
		var card = _create_attachment_carousel_card(socket_key, opt, equipped_id == opt["id"])
		carousel_cards_hbox.add_child(card)

	_play_ui_tick()

func _create_attachment_carousel_card(socket_key: String, opt_data: Dictionary, is_equipped: bool) -> PanelContainer:
	var pc = PanelContainer.new()
	pc.custom_minimum_size = Vector2(210, 110)

	var st = StyleBoxFlat.new()
	if is_equipped:
		st.bg_color = Color(0.12, 0.16, 0.22, 0.95)
		st.border_color = Color(1.0, 0.65, 0.15, 1.0)
		st.set_border_width_all(2)
	else:
		st.bg_color = Color(0.06, 0.08, 0.12, 0.9)
		st.border_color = Color(0.25, 0.35, 0.5, 0.35)
		st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	pc.add_theme_stylebox_override("panel", st)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	pc.add_child(vb)

	var top_h = HBoxContainer.new()
	vb.add_child(top_h)

	var lbl_n = Label.new()
	lbl_n.text = opt_data["name"]
	lbl_n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_n.add_theme_font_size_override("font_size", 12)
	lbl_n.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	top_h.add_child(lbl_n)

	if is_equipped:
		var eq_badge = Label.new()
		eq_badge.text = "✓ EQUIPADO"
		eq_badge.add_theme_font_size_override("font_size", 9)
		eq_badge.add_theme_color_override("font_color", Color(1.0, 0.65, 0.15))
		top_h.add_child(eq_badge)

	var lbl_type = Label.new()
	lbl_type.text = opt_data["type"]
	lbl_type.add_theme_font_size_override("font_size", 10)
	lbl_type.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0, 0.9))
	vb.add_child(lbl_type)

	# Pros
	for pro in opt_data.get("pros", []):
		var lp = Label.new()
		lp.text = "• " + pro
		lp.add_theme_font_size_override("font_size", 9)
		lp.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5, 0.9))
		vb.add_child(lp)

	# Cons
	for con in opt_data.get("cons", []):
		var lc = Label.new()
		lc.text = "• " + con
		lc.add_theme_font_size_override("font_size", 9)
		lc.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4, 0.9))
		vb.add_child(lc)

	var btn_action = Button.new()
	btn_action.text = "DESEQUIPAR" if is_equipped else "EQUIPAR ACESSÓRIO"
	btn_action.custom_minimum_size = Vector2(0, 24)
	btn_action.add_theme_font_size_override("font_size", 10)
	btn_action.pressed.connect(func(): _equip_attachment_from_carousel(socket_key, "none" if is_equipped else opt_data["id"]))
	vb.add_child(btn_action)

	return pc

const MAX_ATTACHMENTS := 5

func _equip_attachment_from_carousel(socket_key: String, att_id: String) -> void:
	var cur_class = classes[selected_class_index]
	# limite de 5 modificações (como mostra a tela): só conta quando o encaixe estava vazio
	if att_id != "none" and cur_class.get(socket_key, "none") in ["none", ""]:
		var used := 0
		for k in ["optic", "muzzle", "barrel", "mag", "underbarrel", "stock", "grip"]:
			if not (cur_class.get(k, "none") in ["none", ""]):
				used += 1
		if used >= MAX_ATTACHMENTS:
			_play_mechanical_click()
			if lbl_carousel_socket_title:
				lbl_carousel_socket_title.text = "LIMITE DE %d MODIFICAÇÕES — REMOVA UM ACESSÓRIO ANTES" % MAX_ATTACHMENTS
			return
	cur_class[socket_key] = att_id

	SaveSystem.save_loadout(selected_class_index, cur_class)
	_apply_and_sync_all()
	_on_socket_pin_pressed(socket_key) # Atualiza o carrossel
	_play_mechanical_click()

func _close_carousel() -> void:
	carousel_container.visible = false
	active_socket_id = ""

# ─────────────────────────────────────────────────────────────────────────────
# ABA PERSONALIZAR (CAMUFLAGENS PBR)
# ─────────────────────────────────────────────────────────────────────────────
func _build_camo_swatches() -> void:
	for c in camos_grid.get_children():
		c.queue_free()

	for camo in CAMO_LIST:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(160, 48)
		btn.focus_mode = Control.FOCUS_NONE

		var st = StyleBoxFlat.new()
		st.bg_color = Color(0.08, 0.10, 0.15, 0.9)
		st.border_color = Color(camo["color"].r * 0.8, camo["color"].g * 0.8, camo["color"].b * 0.8, 0.8)
		st.set_border_width_all(2)
		st.set_corner_radius_all(4)
		st.content_margin_left = 8
		btn.add_theme_stylebox_override("normal", st)

		var hb = HBoxContainer.new()
		hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(hb)

		var color_badge = ColorRect.new()
		color_badge.custom_minimum_size = Vector2(24, 24)
		color_badge.color = camo["color"]
		hb.add_child(color_badge)

		var vb = VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(vb)

		var lbl_cn = Label.new()
		lbl_cn.text = camo["name"]
		lbl_cn.add_theme_font_size_override("font_size", 11)
		vb.add_child(lbl_cn)

		btn.pressed.connect(_on_camo_selected.bind(camo["id"]))
		camos_grid.add_child(btn)

func _on_camo_selected(camo_id: String) -> void:
	var cur_class = classes[selected_class_index]
	cur_class["camo"] = camo_id
	SaveSystem.save_loadout(selected_class_index, cur_class)
	_apply_and_sync_all()
	_play_mechanical_click()

# =============================================================================
# ATUALIZAÇÃO 3D E PROJEÇÃO ESPACIAL DE PINOS (UNPROJECT POSITION)
# =============================================================================
func _process(delta: float) -> void:
	if not is_open:
		return

	# Garantir mouse livre
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Gerenciamento de temporizador do pop-up de bloqueio do Gunsmith
	if locked_popup_held_timer > 0.0:
		locked_popup_held_timer -= delta
		if locked_popup_held_timer <= 0.0 and not is_hovering_gunsmith_button:
			_hide_gunsmith_locked_popup()

	# Interpolação suave de Câmera (Smooth Camera Transition)
	if stage_camera:
		stage_camera.position = stage_camera.position.lerp(target_cam_pos, 8.0 * delta)
		stage_camera.fov = lerpf(stage_camera.fov, target_cam_fov, 8.0 * delta)

	# Rotação suave do Turntable com inércia
	if stage_turntable:
		stage_turntable.rotation.y = lerp_angle(stage_turntable.rotation.y, turntable_rot_y, 10.0 * delta)
		stage_turntable.rotation.x = lerpf(stage_turntable.rotation.x, turntable_pitch_x, 10.0 * delta)

	# Atualização de coordenadas dos Pinos Espaciais na tela (Gunsmith 3D)
	if current_mode == UIMode.GUNSMITH_3D and socket_overlay_control.visible:
		_update_spatial_pins_positions()
		socket_overlay_control.queue_redraw()

func _update_spatial_pins_positions() -> void:
	if not stage_camera or not weapon_model_wrapper or not is_instance_valid(weapon_model_wrapper):
		return

	var cfg = weapon_model_wrapper.get_meta("config", {})
	var pivot = weapon_model_wrapper.get_node_or_null("Pivot")
	var base_tf = pivot.global_transform if pivot else stage_turntable.global_transform

	var vp_size = Vector2(stage_subviewport.size)
	var screen_rect = get_viewport().get_visible_rect()
	var scale_factor_x = screen_rect.size.x / vp_size.x
	var scale_factor_y = screen_rect.size.y / vp_size.y

	for s_key in SOCKET_DEFINITIONS:
		var s_def = SOCKET_DEFINITIONS[s_key]
		var local_offset: Vector3 = s_def["default_offset_3d"]

		if cfg.has("socket_" + s_key):
			local_offset = cfg["socket_" + s_key]
		elif s_key == "barrel":
			var m_sock = cfg.get("socket_muzzle", Vector3(0, 0.02, -0.4))
			var o_sock = cfg.get("socket_optic", Vector3(0, 0.08, 0))
			local_offset = Vector3(0, (m_sock.y + o_sock.y) * 0.45, m_sock.z * 0.55)
		elif s_key == "underbarrel":
			var m_sock = cfg.get("socket_muzzle", Vector3(0, 0.02, -0.4))
			local_offset = Vector3(0, -0.06, m_sock.z * 0.4)
		elif s_key == "stock":
			local_offset = Vector3(0, 0.05, 0.28)
		elif s_key == "grip":
			local_offset = Vector3(0, -0.09, 0.08)

		var world_pos = base_tf * local_offset
		var is_behind = stage_camera.is_position_behind(world_pos)
		var pin_btn = socket_pins.get(s_key, null)

		if not pin_btn:
			continue

		if is_behind:
			pin_btn.visible = false
			socket_screen_coords.erase(s_key)
			continue

		var unprojected_2d = stage_camera.unproject_position(world_pos)
		var screen_pt = Vector2(unprojected_2d.x * scale_factor_x, unprojected_2d.y * scale_factor_y)
		socket_screen_coords[s_key] = screen_pt

		# Posição do botão deslocada radialmente para não encobrir a arma
		var dir: Vector2 = s_def.get("pin_direction", Vector2(0.8, -0.8)).normalized()
		var pin_pos = screen_pt + (dir * 95.0) - (pin_btn.size * 0.5)

		# Clamping para manter os pinos confortavelmente dentro da tela
		pin_pos.x = clampf(pin_pos.x, 20.0, screen_rect.size.x - pin_btn.size.x - 20.0)
		pin_pos.y = clampf(pin_pos.y, 80.0, screen_rect.size.y - pin_btn.size.y - 120.0)

		pin_btn.global_position = pin_pos
		pin_btn.visible = true

func _on_socket_overlay_draw() -> void:
	if current_mode != UIMode.GUNSMITH_3D:
		return

	var amber_glow = Color(1.0, 0.65, 0.15, 0.85)
	var dim_glow = Color(0.4, 0.6, 0.9, 0.4)

	for s_key in socket_screen_coords:
		var pt_gun = socket_screen_coords[s_key]
		var pin_btn = socket_pins.get(s_key)
		if not pin_btn or not pin_btn.visible:
			continue

		var pt_btn = pin_btn.global_position + (pin_btn.size * 0.5)
		var is_active = (active_socket_id == s_key)
		var line_col = amber_glow if is_active else dim_glow
		var line_width = 2.0 if is_active else 1.2

		# Ponto brilhante exatamente no local do acessório na arma
		socket_overlay_control.draw_circle(pt_gun, 4.0, line_col)
		socket_overlay_control.draw_arc(pt_gun, 7.0, 0, TAU, 16, line_col, 1.0, true)

		# Linha tática com cotovelo angular (Estilo HUD Militar COD)
		var elbow = Vector2(pt_btn.x, pt_gun.y)
		socket_overlay_control.draw_line(pt_gun, elbow, line_col, line_width, true)
		socket_overlay_control.draw_line(elbow, pt_btn, line_col, line_width, true)

# ─────────────────────────────────────────────────────────────────────────────
# CONTROLE DO MOUSE PARA ROTAÇÃO 3D LIVRE DA ARMA
# ─────────────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not is_open:
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			if event.keycode == KEY_F1:
				open_screen(false)
				get_viewport().set_input_as_handled()
		return

	# Rotação interativa com o botão esquerdo do mouse
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging_mouse = event.is_pressed()
			last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_cam_fov = clampf(target_cam_fov - 1.5, 20.0, 50.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_cam_fov = clampf(target_cam_fov + 1.5, 20.0, 50.0)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
			# Resetar visão para ângulo canônico
			turntable_rot_y = -0.50
			turntable_pitch_x = 0.05
			target_cam_fov = 34.0 if current_mode == UIMode.LOADOUT_WORKBENCH else 30.0

	elif event is InputEventMouseMotion and is_dragging_mouse:
		var delta_m = event.position - last_mouse_pos
		last_mouse_pos = event.position
		turntable_rot_y += delta_m.x * 0.007
		turntable_pitch_x = clampf(turntable_pitch_x + delta_m.y * 0.005, -0.4, 0.4)

	# Atalhos de Teclado
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if rename_modal_overlay and rename_modal_overlay.visible:
			if event.keycode == KEY_ESCAPE:
				_close_rename_modal()
				get_viewport().set_input_as_handled()
				return

		match event.keycode:
			KEY_ESCAPE:
				_on_back_pressed()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				_on_confirm_pressed()
				get_viewport().set_input_as_handled()
			KEY_SPACE, KEY_T:
				_on_firing_range_pressed()
				get_viewport().set_input_as_handled()
			KEY_G:
				if current_mode == UIMode.GUNSMITH_3D:
					_switch_to_workbench_mode()
				else:
					_switch_to_gunsmith_mode()
				get_viewport().set_input_as_handled()
			KEY_Q:
				if current_mode == UIMode.GUNSMITH_3D:
					_set_gunsmith_tab(GunsmithTab.BUILD_WEAPON)
				else:
					_select_class((selected_class_index - 1 + classes.size()) % classes.size())
				get_viewport().set_input_as_handled()
			KEY_E:
				if current_mode == UIMode.GUNSMITH_3D:
					_set_gunsmith_tab(GunsmithTab.CUSTOMIZE)
				else:
					_select_class((selected_class_index + 1) % classes.size())
				get_viewport().set_input_as_handled()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0:
				var idx = event.keycode - KEY_1 if event.keycode != KEY_0 else 9
				_select_class(idx)
				get_viewport().set_input_as_handled()
			KEY_F2:
				_open_rename_modal()
				get_viewport().set_input_as_handled()

# =============================================================================
# SINCRONIZAÇÃO DE DADOS, SALVAMENTO & ATUALIZAÇÃO DA ARMA 3D
# =============================================================================
func _select_class(index: int) -> void:
	if classes.is_empty():
		classes = PRESET_CLASSES.duplicate(true)

	selected_class_index = clampi(index, 0, classes.size() - 1)
	_rebuild_class_tabs()
	_apply_and_sync_all()

func _apply_and_sync_all() -> void:
	var cur_class = classes[selected_class_index]

	current_primary_path = cur_class.get("primary", "res://resources/weapons/ak47.tres")
	current_secondary_path = cur_class.get("secondary", "res://resources/weapons/pistol.tres")

	# 1. Atualizar Modelo 3D na bancada
	_update_weapon_3d_model(current_primary_path, cur_class.get("camo", "default"))

	# 2. Atualizar Cards da Camada 1
	_refresh_layer1_cards()

	# 3. Atualizar HUD de Estatísticas e Pinos
	_update_stats_display(current_primary_path)
	_update_socket_pin_titles()

	# 4. Sincronizar com GameManager
	var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	if gm:
		gm.primary_weapon_res = current_primary_path
		gm.secondary_weapon_res = current_secondary_path
		gm.set_weapon_customization(
			cur_class.get("camo", "default"),
			cur_class.get("optic", "none"),
			cur_class.get("muzzle", "none"),
			cur_class.get("mag", "none"),
			cur_class.get("underbarrel", "none"),
			cur_class.get("stock", "none"),
			cur_class.get("grip", "none")
		)
		gm.set_equipment_and_perks(
			cur_class.get("lethal", "semtex"),
			cur_class.get("tactical", "stim"),
			cur_class.get("perk1", "flak_jacket"),
			cur_class.get("perk2", "fast_hands"),
			cur_class.get("perk3", "high_alert"),
			cur_class.get("specialty", "enforcer")
		)

func _update_weapon_3d_model(weapon_path: String, camo_key: String) -> void:
	if not weapon_pivot:
		return

	for c in weapon_pivot.get_children():
		if c.is_inside_tree(): c.queue_free()
		else: c.free()

	weapon_model_wrapper = WeaponVisualRegistry.instantiate_weapon_showcase(weapon_path)
	if not weapon_model_wrapper:
		return

	weapon_pivot.add_child(weapon_model_wrapper)

	var cur_class = classes[selected_class_index]
	WeaponVisualRegistry.update_attachments(
		weapon_model_wrapper,
		cur_class.get("optic", "none"),
		cur_class.get("muzzle", "none"),
		cur_class.get("mag", "none"),
		cur_class.get("underbarrel", "none"),
		cur_class.get("stock", "none"),
		cur_class.get("grip", "none"),
		cur_class.get("barrel", "none")
	)
	WeaponVisualRegistry.apply_camo(weapon_model_wrapper, camo_key)

func _refresh_layer1_cards() -> void:
	var cur_class = classes[selected_class_index]
	lbl_loadout_title.text = "CUSTOM LOADOUT %d - %s" % [selected_class_index + 1, cur_class.get("name", "Custom").to_upper()]

	var prim_res: WeaponData = load(current_primary_path) as WeaponData if ResourceLoader.exists(current_primary_path) else null
	if prim_res:
		lbl_card_primary_name.text = prim_res.weapon_name.to_upper()
		lbl_card_primary_cat.text = _get_weapon_category_label(current_primary_path)

	# Atualizar pílulas de acessórios no card primário
	for c in box_card_primary_attachments.get_children():
		c.queue_free()

	var count_atts = 0
	for s_key in ["optic", "muzzle", "barrel", "underbarrel", "mag", "stock", "grip"]:
		var val = cur_class.get(s_key, "none")
		if val != "none" and val != "":
			count_atts += 1
			var tag_btn = Button.new()
			tag_btn.text = val.replace("optic_", "").replace("muzzle_", "").replace("mag_", "").to_upper()
			tag_btn.custom_minimum_size = Vector2(0, 20)
			tag_btn.add_theme_font_size_override("font_size", 9)
			box_card_primary_attachments.add_child(tag_btn)

	if count_atts == 0:
		var stock_tag = Label.new()
		stock_tag.text = "★ PADRÃO DE FÁBRICA"
		stock_tag.add_theme_font_size_override("font_size", 10)
		stock_tag.add_theme_color_override("font_color", Color(0.45, 0.60, 0.80, 0.75))
		box_card_primary_attachments.add_child(stock_tag)

	var sec_res: WeaponData = load(current_secondary_path) as WeaponData if ResourceLoader.exists(current_secondary_path) else null
	if sec_res:
		lbl_card_secondary_name.text = sec_res.weapon_name.to_upper()

	lbl_lethal_tag.text = "💣 LETAL: " + cur_class.get("lethal", "semtex").to_upper()
	lbl_tactical_tag.text = "🧪 TÁTICO: " + cur_class.get("tactical", "stim").to_upper()
	lbl_specialty_tag.text = "★ ESPECIALIDADE: " + cur_class.get("specialty", "enforcer").to_upper()

func _update_socket_pin_titles() -> void:
	var cur_class = classes[selected_class_index]
	var allowed: Array = WeaponVisualRegistry.get_allowed_slots(current_primary_path)
	if lbl_modifications_counter:
		var used := 0
		for k in ["optic", "muzzle", "barrel", "mag", "underbarrel", "stock", "grip"]:
			if not (cur_class.get(k, "none") in ["none", ""]):
				used += 1
		lbl_modifications_counter.text = "MODIFICAÇÕES %d / %d" % [used, MAX_ATTACHMENTS]
	for s_key in socket_pins:
		var pin_btn = socket_pins[s_key]
		# encaixe que essa arma não tem (ex.: pente em escopeta de tubo, luneta sem trilho validado) não aparece
		pin_btn.visible = s_key in allowed
		var sub_lbl = pin_btn.find_child("SubTitle", true, false) as Label
		var val = cur_class.get(s_key, "none")

		if sub_lbl:
			if val == "none" or val == "":
				sub_lbl.text = "PADRÃO"
				sub_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 0.7))
			else:
				var att_name = val.replace("optic_", "").replace("muzzle_", "").replace("mag_", "").replace("_", " ").to_upper()
				sub_lbl.text = "✓ " + att_name
				sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))

func _update_stats_display(prim_path: String) -> void:
	var cur_class = classes[selected_class_index]
	var w: WeaponData = load(prim_path) as WeaponData if ResourceLoader.exists(prim_path) else null
	if not w:
		return

	lbl_gunsmith_weapon_name.text = "%s  |  NÍVEL 30 / 30" % w.weapon_name.to_upper()

	var attachments: Array[AttachmentData] = []
	for s_key in ["optic", "muzzle", "barrel", "mag", "underbarrel", "stock", "grip"]:
		var a_id = cur_class.get(s_key, "none")
		if a_id != "none" and a_id != "":
			var res = WeaponModifier.get_attachment_resource(a_id)
			if res: attachments.append(res)

	var calculated = WeaponModifier.calculate_ui_stats(w, attachments)

	# Atualizar Barras de Atributos
	for k in stat_bar_nodes:
		var val = int(calculated.get(k, 60))
		stat_bar_nodes[k]["bar"].value = val
		stat_bar_nodes[k]["val_lbl"].text = str(val)

	# Contador de Modificações (X / 5)
	var mod_count = 0
	for s_key in ["optic", "muzzle", "barrel", "underbarrel", "mag", "stock", "grip"]:
		if cur_class.get(s_key, "none") != "none":
			mod_count += 1

	lbl_modifications_counter.text = "MODIFICAÇÕES %d / 5" % mod_count
	_rebuild_mod_pips(mod_count, 5)

func _get_weapon_category_label(path: String) -> String:
	for w in WEAPON_REGISTRY:
		if w["path"] == path:
			return w.get("cat", "Armamento").to_upper()
	return "ARMAMENTO TÁTICO"

# =============================================================================
# ABERTURA, FECHAMENTO & NAVEGAÇÃO ENTRE TELAS
# =============================================================================
func open_screen(is_first_spawn: bool = false) -> void:
	is_open = true
	visible = true
	is_initial_spawn = is_first_spawn

	# Congelar jogador local
	var p = _find_local_player()
	if p: p.immobile = true

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_switch_to_workbench_mode()
	_select_class(selected_class_index)

func close_screen() -> void:
	if not is_open: return
	is_open = false
	visible = false

	is_hovering_gunsmith_button = false
	locked_popup_held_timer = 0.0
	if gunsmith_locked_popup:
		gunsmith_locked_popup.visible = false

	var p = _find_local_player()
	if p: p.immobile = false

	var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	if gm and gm.is_match_active:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	screen_closed.emit()

func _on_back_pressed() -> void:
	if current_mode == UIMode.GUNSMITH_3D:
		_switch_to_workbench_mode()
	else:
		close_screen()

func _on_confirm_pressed() -> void:
	var cur_class = classes[selected_class_index]
	var was_initial := is_initial_spawn or not has_chosen_initial_class
	has_chosen_initial_class = true
	class_selected.emit(cur_class)
	# Escolha inicial (ao entrar no mapa): a classe vale na hora, como no CoD.
	# Trocas no meio da partida continuam valendo no próximo renascimento.
	if was_initial:
		var p = _find_local_player()
		if p and is_instance_valid(p) and "weapon_manager" in p and p.weapon_manager and p.weapon_manager.has_method("reset_on_respawn"):
			p.weapon_manager.reset_on_respawn()
	is_initial_spawn = false
	# multiplayer: os outros jogadores passam a ver a arma e os acessórios desta classe
	var nm_c = get_node_or_null("/root/NetworkManager")
	if nm_c and nm_c.has_method("submit_local_loadout"):
		nm_c.submit_local_loadout()
	close_screen()

func _on_firing_range_pressed() -> void:
	SaveSystem.save_loadout(selected_class_index, classes[selected_class_index])
	close_screen()

	if is_inside_tree() and get_tree():
		if get_tree().current_scene and get_tree().current_scene.name == "MapFiringRange":
			return
		get_tree().change_scene_to_file("res://scenes/_world/map_firing_range.tscn")

func _open_bo3_weapon_browser(slot_type: String = "primary") -> void:
	if not bo3_weapon_select_screen:
		var scr = load("res://scripts/ui/bo3_weapon_select_screen.gd")
		if scr:
			bo3_weapon_select_screen = scr.new()
			bo3_weapon_select_screen.weapon_selected_for_slot.connect(_on_weapon_equipped_from_browser)
			add_child(bo3_weapon_select_screen)

	if bo3_weapon_select_screen:
		var target_path = current_primary_path if slot_type == "primary" else current_secondary_path
		var initial_cat = 0 if slot_type == "primary" else 5
		bo3_weapon_select_screen.open_screen(initial_cat, target_path, slot_type)

func _on_weapon_equipped_from_browser(weapon_path: String, _w_data: WeaponData, target_slot: String = "primary") -> void:
	if not ResourceLoader.exists(weapon_path):
		return

	var cur_class = classes[selected_class_index]
	if target_slot == "secondary":
		cur_class["secondary"] = weapon_path
		current_secondary_path = weapon_path
	else:
		cur_class["primary"] = weapon_path
		current_primary_path = weapon_path

	SaveSystem.save_loadout(selected_class_index, cur_class)
	_apply_and_sync_all()

# ─────────────────────────────────────────────────────────────────────────────
# MODAL DE RENOMEAÇÃO DE CLASSE
# ─────────────────────────────────────────────────────────────────────────────
func _open_rename_modal() -> void:
	if not rename_modal_overlay:
		rename_modal_overlay = ColorRect.new()
		rename_modal_overlay.color = Color(0.02, 0.03, 0.06, 0.88)
		rename_modal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root_control.add_child(rename_modal_overlay)

		var rp = PanelContainer.new()
		rp.anchor_left = 0.35
		rp.anchor_right = 0.65
		rp.anchor_top = 0.40
		rp.anchor_bottom = 0.60
		var r_st = StyleBoxFlat.new()
		r_st.bg_color = Color(0.06, 0.08, 0.12, 0.98)
		r_st.border_color = Color(1.0, 0.65, 0.15, 0.9)
		r_st.set_border_width_all(2)
		r_st.set_corner_radius_all(8)
		r_st.content_margin_left = 16
		r_st.content_margin_right = 16
		r_st.content_margin_top = 12
		r_st.content_margin_bottom = 12
		rp.add_theme_stylebox_override("panel", r_st)
		rename_modal_overlay.add_child(rp)

		var vb = VBoxContainer.new()
		vb.add_theme_constant_override("separation", 10)
		rp.add_child(vb)

		var lbl = Label.new()
		lbl.text = "RENOMEAR CLASSE PERSONALIZADA"
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
		vb.add_child(lbl)

		rename_line_edit = LineEdit.new()
		rename_line_edit.max_length = 18
		vb.add_child(rename_line_edit)

		var btn_h = HBoxContainer.new()
		vb.add_child(btn_h)

		var btn_c = Button.new()
		btn_c.text = "SALVAR"
		btn_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_c.pressed.connect(_confirm_rename)
		btn_h.add_child(btn_c)

		var btn_x = Button.new()
		btn_x.text = "CANCELAR"
		btn_x.pressed.connect(_close_rename_modal)
		btn_h.add_child(btn_x)

	rename_line_edit.text = classes[selected_class_index].get("name", "Custom")
	rename_modal_overlay.visible = true
	rename_line_edit.grab_focus()

func _confirm_rename() -> void:
	if rename_line_edit and not rename_line_edit.text.strip_edges().is_empty():
		classes[selected_class_index]["name"] = rename_line_edit.text.strip_edges()
		SaveSystem.save_loadout(selected_class_index, classes[selected_class_index])
		_rebuild_class_tabs()
		_refresh_layer1_cards()
	_close_rename_modal()

func _close_rename_modal() -> void:
	if rename_modal_overlay:
		rename_modal_overlay.visible = false

# ─────────────────────────────────────────────────────────────────────────────
# OPERADOR & FACÇÃO
# ─────────────────────────────────────────────────────────────────────────────
func _set_faction(fac: int) -> void:
	selected_faction = fac
	btn_faction_ct.modulate = Color(1.2, 1.2, 1.2, 1.0) if fac == SkinRegistry.Faction.COUNTER_TERRORIST else Color(0.6, 0.65, 0.7, 0.6)
	btn_faction_t.modulate = Color(1.2, 1.2, 1.2, 1.0) if fac == SkinRegistry.Faction.TERRORIST else Color(0.6, 0.65, 0.7, 0.6)

	var skins = SkinRegistry.get_skins_by_faction(selected_faction)
	if not skins.is_empty():
		selected_skin_id = skins[0]["id"]
		lbl_skin_current.text = "Uniforme: " + skins[0]["name"]
	_play_ui_tick()

func _find_local_player() -> Node:
	if not is_inside_tree() or not get_tree(): return null
	var players = get_tree().get_nodes_in_group("player")
	# Multiplayer: o grupo "player" tem também os jogadores remotos; o local é o que controlamos
	for p in players:
		if p is Node and p.has_method("is_local_player") and p.is_local_player():
			return p
	for p in players:
		if p is Node and not (p.get("is_bot") if "is_bot" in p else false):
			return p
	return null

var sfx_tick: AudioStream = preload("res://assets/audio/weapons/hitmarker.wav") if ResourceLoader.exists("res://assets/audio/weapons/hitmarker.wav") else null
var sfx_click: AudioStream = preload("res://assets/audio/weapons/dry_fire.wav") if ResourceLoader.exists("res://assets/audio/weapons/dry_fire.wav") else null

func _play_ui_tick() -> void:
	if not sfx_tick: return
	var am = get_node_or_null("/root/AudioManager") if is_inside_tree() else null
	if am and am.has_method("play_sfx"):
		am.play_sfx(sfx_tick, -16.0)

func _play_mechanical_click() -> void:
	if not sfx_click: return
	var am = get_node_or_null("/root/AudioManager") if is_inside_tree() else null
	if am and am.has_method("play_sfx"):
		am.play_sfx(sfx_click, -4.0)
