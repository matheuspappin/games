# =============================================================================
# bo3_weapon_select_screen.gd
# Seletor de Armas com Showcase 3D Estilo Call of Duty: Black Ops 3
# - Baseado na interface exata de seleção de armas do BO3 / MW3
# - Abas por categoria no topo: ASSAULT RIFLES, SMGS, SHOTGUNS, LMGS, SNIPERS, PISTOLS
# - Lista de cards de armas na esquerda com thumbnail, nome e level badge
# - Showcase 3D interativo no centro com iluminação de estúdio, pedestal e rotação 360°
# - Barras de atributos segmentadas estilo Black Ops 3 (Damage, Range, Fire Rate, Accuracy)
# =============================================================================
class_name BO3WeaponSelectScreen
extends CanvasLayer

const CamoRegistry = preload("res://scripts/weapons/camo_registry.gd")
const WeaponModifier = preload("res://scripts/weapons/weapon_modifier.gd")
const WeaponVisualRegistry = preload("res://scripts/weapons/weapon_visual_registry.gd")

signal weapon_selected(weapon_path: String, weapon_data: WeaponData)
signal weapon_selected_for_slot(weapon_path: String, weapon_data: WeaponData, target_slot: String)
signal screen_closed

# ── CATEGORIAS DE ARMAS ───────────────────────────────────────────────────────
const CATEGORIES: Array[Dictionary] = [
	{
		"id": "ar",
		"name": "ASSAULT RIFLES",
		"icon": "🎯",
		"weapons": [
			{
				"name": "ACR 6.8",
				"full_name": "ACR 6.8 TACTICAL RIFLE",
				"desc": "Fuzil de assalto modular de alta cadência e precisão cirúrgica. Recuo extremamente controlável para médias e longas distâncias.",
				"path": "res://resources/weapons/ak47.tres",
				"model_type": "rifle",
				"level": "MAX ★",
				"damage": 55, "range": 75, "fire_rate": 75, "accuracy": 82
			},
			{
				"name": "M4A1",
				"full_name": "M4A1 SPECIAL FORCES",
				"desc": "Plataforma americana clássica 5.56mm. Equilíbrio absoluto entre cadência, alcance e velocidade de mira rápida (ADS).",
				"path": "res://resources/weapons/m4a1.tres",
				"model_type": "rifle",
				"level": "MAX ★",
				"damage": 45, "range": 68, "fire_rate": 80, "accuracy": 78
			},
			{
				"name": "SCAR-H",
				"full_name": "SCAR-H 7.62 BATTLE RIFLE",
				"desc": "Fuzil de batalha calibre pesado 7.62x51mm. Alto impacto por disparo capaz de eliminar alvos em 3 tiros a qualquer distância.",
				"path": "res://resources/weapons/scar_h.tres",
				"model_type": "ak",
				"level": "LVL 48",
				"damage": 58, "range": 85, "fire_rate": 60, "accuracy": 72
			},
			{
				"name": "Man-O-War",
				"full_name": "MAN-O-WAR HEAVY ASSAULT",
				"desc": "Fuzil futurista BO3 de alta penetração. Cadência cadenciada de 517 RPM com máximo dano de parada.",
				"path": "res://resources/weapons/man_o_war.tres",
				"model_type": "ak",
				"level": "LVL 55",
				"damage": 62, "range": 88, "fire_rate": 52, "accuracy": 74
			}
		]
	},
	{
		"id": "smg",
		"name": "SUBMACHINE GUNS",
		"icon": "⚡",
		"weapons": [
			{
				"name": "MP7",
				"full_name": "MP7 SUBMACHINE GUN",
				"desc": "Submetralhadora alemã ultracompacta 4.6mm. Incríveis 950 RPM com recuo mínimo e velocidade de sprint superior.",
				"path": "res://resources/weapons/mp7.tres",
				"model_type": "smg",
				"level": "MAX ★",
				"damage": 34, "range": 50, "fire_rate": 95, "accuracy": 85
			},
			{
				"name": "PP90M1",
				"full_name": "PP90M1 HELICAL MAG",
				"desc": "Submetralhadora russa com carregador helicoidal de 64 munições. Cadência devastadora para invasões CQB sem recarregar.",
				"path": "res://resources/weapons/pp90m1.tres",
				"model_type": "smg",
				"level": "LVL 42",
				"damage": 33, "range": 44, "fire_rate": 99, "accuracy": 70
			},
			{
				"name": "VMP",
				"full_name": "VMP COMPACT CQB",
				"desc": "Submetralhadora mais popular do Black Ops 3. Disparo contínuo ágil e excelente dispersão de tiro livre (hipfire).",
				"path": "res://resources/weapons/vmp.tres",
				"model_type": "smg",
				"level": "MAX ★",
				"damage": 36, "range": 48, "fire_rate": 90, "accuracy": 76
			},
			{
				"name": "SMG-45",
				"full_name": "SMG-45 TACTICAL",
				"desc": "Arma tática compacta calibre .45 ACP com silenciador integrado e alta letalidade a curta distância.",
				"path": "res://resources/weapons/smg.tres",
				"model_type": "smg",
				"level": "LVL 35",
				"damage": 38, "range": 46, "fire_rate": 85, "accuracy": 78
			}
		]
	},
	{
		"id": "shotgun",
		"name": "SHOTGUNS",
		"icon": "💥",
		"weapons": [
			{
				"name": "SPAS-12",
				"full_name": "SPAS-12 COMBAT SHOTGUN",
				"desc": "Escopeta de combate calibre 12 pump-action. Dispersão de 8 balotes de chumbo para eliminação instantânea corpo a corpo.",
				"path": "res://resources/weapons/spas12.tres",
				"model_type": "shotgun",
				"level": "MAX ★",
				"damage": 120, "range": 30, "fire_rate": 35, "accuracy": 40
			},
			{
				"name": "KRM-262",
				"full_name": "KRM-262 BO3 PUMP",
				"desc": "Escopeta tática pesada do Black Ops 3. Arco de chumbo concentrado e capacidade de One-Shot-Kill a até 10 metros.",
				"path": "res://resources/weapons/krm262.tres",
				"model_type": "shotgun",
				"level": "LVL 50",
				"damage": 130, "range": 32, "fire_rate": 32, "accuracy": 42
			},
			{
				"name": "Sawnoff",
				"full_name": "SAWN-OFF DOUBLE BARREL",
				"desc": "Cano serrado duplo com dispersão brutal e peso levíssimo para mobilidade máxima de rusher.",
				"path": "res://resources/weapons/shotgun.tres",
				"model_type": "shotgun",
				"level": "LVL 20",
				"damage": 140, "range": 22, "fire_rate": 45, "accuracy": 30
			}
		]
	},
	{
		"id": "lmg",
		"name": "LIGHT MACHINE GUNS",
		"icon": "🛡️",
		"weapons": [
			{
				"name": "LMG-63",
				"full_name": "LMG-63 SQUAD SUPPORT",
				"desc": "Arma pesada de apoio em pelotão com fita de munição estendida de 100 tiros para fogo contínuo sem pausas.",
				"path": "res://resources/weapons/lmg.tres",
				"model_type": "lmg",
				"level": "LVL 40",
				"damage": 50, "range": 85, "fire_rate": 65, "accuracy": 65
			}
		]
	},
	{
		"id": "sniper",
		"name": "SNIPER RIFLES",
		"icon": "🔭",
		"weapons": [
			{
				"name": "Nova Sniper (Em Breve)",
				"full_name": "NOVA SNIPER RIFLE (EM BREVE)",
				"desc": "Espaço reservado para a nova sniper do arsenal.",
				"path": "res://resources/weapons/acr68.tres",
				"model_type": "rifle",
				"level": "MAX ★",
				"damage": 120, "range": 100, "fire_rate": 20, "accuracy": 98
			}
		]
	},
	{
		"id": "secondary",
		"name": "SECONDARY & PISTOLS",
		"icon": "🔫",
		"weapons": [
			{
				"name": ".50 GS Deagle",
				"full_name": "DESERT EAGLE .50 ACTION EXPRESS",
				"desc": "Pistola magnum pesada de mão. Disparo potente que causa 75 de dano corporal e elimina com 1 tiro na cabeça.",
				"path": "res://resources/weapons/deagle.tres",
				"model_type": "pistol",
				"level": "MAX ★",
				"damage": 75, "range": 52, "fire_rate": 45, "accuracy": 80
			},
			{
				"name": "Pistola C19",
				"full_name": "C19 TACTICAL SIDEARM",
				"desc": "Pistola de serviço semiautomática 9mm. Saque ultrarrápido para finalizar adversários quando a munição primária acabar.",
				"path": "res://resources/weapons/pistol.tres",
				"model_type": "pistol",
				"level": "LVL 18",
				"damage": 35, "range": 40, "fire_rate": 60, "accuracy": 78
			},
			{
				"name": "Combat Knife",
				"full_name": "FACA DE COMBATE TÁTICA",
				"desc": "Lâmina militar de carbono fosco para combate corpo a corpo silencioso. Eliminação instakill garantida.",
				"path": "res://resources/weapons/knife.tres",
				"model_type": "knife",
				"level": "MAX ★",
				"damage": 100, "range": 10, "fire_rate": 70, "accuracy": 100
			}
		]
	}
]

# ── ESTADO DA TELA ────────────────────────────────────────────────────────────
var is_open: bool = false
var current_category_idx: int = 0
var current_weapon_idx: int = 0
var selected_weapon_data: Dictionary = {}
var target_slot: String = "primary"
var on_equip_callback: Callable = Callable()

# ── NÓS DA UI ─────────────────────────────────────────────────────────────────
var overlay: ColorRect
var title_lbl: Label = null
var btn_equip: Button = null
var tab_buttons: Array[Button] = []
var weapon_cards: Array[Button] = []
var weapon_list_vbox: VBoxContainer

# Showcase Labels
var lbl_weapon_name: Label
var lbl_weapon_desc: Label
var lbl_weapon_level_badge: Label
var lbl_stats_summary: Label
var segmented_bars: Dictionary = {}

# 3D SubViewport
var subviewport: SubViewport
var turntable_node: Node3D
var active_3d_model: Node3D = null
var showcase_camera: Camera3D = null
var current_zoom: float = 0.88
var turntable_tween: Tween = null
var is_mouse_dragging: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO
var turntable_rot_y: float = -0.55
var auto_rotate_speed: float = 0.28

# Controles Gunsmith de Acessórios & Camuflagem (Trancados para Futura Atualização)
var gunsmith_panel: PanelContainer = null
var gunsmith_locked_popup: PanelContainer = null
var is_hovering_gunsmith_panel: bool = false
var locked_popup_held_timer: float = 0.0

var opt_optic: Button
var opt_muzzle: Button
var opt_mag: Button
var opt_camo: Button
var selected_optic: String = "none"
var selected_muzzle: String = "none"
var selected_mag: String = "none"
var selected_camo: String = "default"

var sfx_click: AudioStream = preload("res://assets/audio/weapons/dry_fire.wav") if ResourceLoader.exists("res://assets/audio/weapons/dry_fire.wav") else null
var sfx_tick: AudioStream = preload("res://assets/audio/weapons/hitmarker.wav") if ResourceLoader.exists("res://assets/audio/weapons/hitmarker.wav") else null

func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not overlay:
		_build_ui()
	visible = false

# ── CONSTRUÇÃO DA UI (ESTILO BLACK OPS 3) ──────────────────────────────────────
func _build_ui() -> void:
	# 1. Overlay Escuro
	overlay = ColorRect.new()
	overlay.name = "DarkOverlay"
	overlay.color = Color(0.04, 0.05, 0.08, 0.96)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# 2. Layout Raiz
	var root_margin = MarginContainer.new()
	root_margin.name = "RootMargin"
	root_margin.anchor_right = 1.0
	root_margin.anchor_bottom = 1.0
	root_margin.add_theme_constant_override("margin_left", 32)
	root_margin.add_theme_constant_override("margin_right", 32)
	root_margin.add_theme_constant_override("margin_top", 20)
	root_margin.add_theme_constant_override("margin_bottom", 20)
	add_child(root_margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.add_theme_constant_override("separation", 14)
	root_margin.add_child(main_vbox)

	# ── CABEÇALHO COM TÍTULO E ABAS BO3 ───────────────────────────────────────
	var header_vbox = VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(header_vbox)

	# Título principal estilo BO3
	var top_hbox = HBoxContainer.new()
	header_vbox.add_child(top_hbox)

	title_lbl = Label.new()
	title_lbl.text = "︻╦デ═— PRIMARY WEAPONS"
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(title_lbl)

	var pick10_badge = Label.new()
	pick10_badge.text = "CLASS LOADOUT: 10 / 10 ▌▌▌▌▌▌▌▌▌▌"
	pick10_badge.add_theme_font_size_override("font_size", 14)
	pick10_badge.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0, 0.9))
	top_hbox.add_child(pick10_badge)

	# Barra de Abas das Categorias
	var tabs_hbox = HBoxContainer.new()
	tabs_hbox.name = "TabsHBox"
	tabs_hbox.add_theme_constant_override("separation", 4)
	header_vbox.add_child(tabs_hbox)

	for i in range(CATEGORIES.size()):
		var cat = CATEGORIES[i]
		var btn = Button.new()
		btn.name = "TabBtn_%d" % i
		btn.text = "%s  %s" % [cat["icon"], cat["name"]]
		btn.custom_minimum_size = Vector2(170, 38)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(func(): _select_category(i))
		tabs_hbox.add_child(btn)
		tab_buttons.append(btn)

	# Linha divisória fina com gradiente
	var sep = HSeparator.new()
	var sep_st = StyleBoxFlat.new()
	sep_st.bg_color = Color(0.95, 0.45, 0.1, 0.6)
	sep_st.content_margin_top = 1
	sep_st.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", sep_st)
	main_vbox.add_child(sep)

	# ── CORPO: LISTA NA ESQUERDA & SHOWCASE 3D NA DIREITA ──────────────────────
	var body_hbox = HBoxContainer.new()
	body_hbox.name = "BodyHBox"
	body_hbox.add_theme_constant_override("separation", 24)
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(body_hbox)

	# Coluna Esquerda: Lista de Cards de Armas (340px)
	var left_panel = PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(330, 0)
	var left_st = StyleBoxFlat.new()
	left_st.bg_color = Color(0.06, 0.08, 0.12, 0.85)
	left_st.border_color = Color(0.2, 0.28, 0.40, 0.4)
	left_st.set_border_width_all(1)
	left_st.set_corner_radius_all(6)
	left_panel.add_theme_stylebox_override("panel", left_st)
	body_hbox.add_child(left_panel)

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(scroll)

	weapon_list_vbox = VBoxContainer.new()
	weapon_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_list_vbox.add_theme_constant_override("separation", 8)
	var list_margin = MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 8)
	list_margin.add_theme_constant_override("margin_right", 8)
	list_margin.add_theme_constant_override("margin_top", 10)
	list_margin.add_theme_constant_override("margin_bottom", 10)
	list_margin.add_child(weapon_list_vbox)
	scroll.add_child(list_margin)

	# Coluna Direita: Showcase 3D, Nome, Descrição e Barras Segmentadas
	var right_vbox = VBoxContainer.new()
	right_vbox.name = "RightShowcase"
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 10)
	body_hbox.add_child(right_vbox)

	# Título e Descrição da Arma Selecionada
	var title_panel = VBoxContainer.new()
	title_panel.add_theme_constant_override("separation", 4)
	right_vbox.add_child(title_panel)

	var name_hbox = HBoxContainer.new()
	title_panel.add_child(name_hbox)

	lbl_weapon_name = Label.new()
	lbl_weapon_name.text = "ACR 6.8"
	lbl_weapon_name.add_theme_font_size_override("font_size", 34)
	lbl_weapon_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	lbl_weapon_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_hbox.add_child(lbl_weapon_name)

	lbl_weapon_level_badge = Label.new()
	lbl_weapon_level_badge.text = "WEAPON LEVEL  MAX ★"
	lbl_weapon_level_badge.add_theme_font_size_override("font_size", 14)
	lbl_weapon_level_badge.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2, 1.0))
	name_hbox.add_child(lbl_weapon_level_badge)

	lbl_weapon_desc = Label.new()
	lbl_weapon_desc.text = "Fuzil de assalto modular de alta cadência e precisão cirúrgica."
	lbl_weapon_desc.add_theme_font_size_override("font_size", 13)
	lbl_weapon_desc.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85, 0.85))
	lbl_weapon_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_panel.add_child(lbl_weapon_desc)

	# Área do SubViewport 3D da Arma
	var vp_panel = PanelContainer.new()
	vp_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vp_panel.custom_minimum_size = Vector2(0, 320)
	var vp_st = StyleBoxFlat.new()
	vp_st.bg_color = Color(0.03, 0.04, 0.06, 0.9)
	vp_st.border_color = Color(0.18, 0.26, 0.38, 0.5)
	vp_st.set_border_width_all(1)
	vp_st.set_corner_radius_all(8)
	vp_panel.add_theme_stylebox_override("panel", vp_st)
	right_vbox.add_child(vp_panel)

	# SubViewportContainer e SubViewport
	var vp_container = SubViewportContainer.new()
	vp_container.stretch = true
	vp_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vp_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vp_panel.add_child(vp_container)

	subviewport = SubViewport.new()
	subviewport.transparent_bg = true
	subviewport.own_world_3d = true
	subviewport.handle_input_locally = true
	vp_container.add_child(subviewport)

	_setup_3d_viewport_scene()

	# Manipulação de clique e arraste para girar a arma 3D
	vp_container.gui_input.connect(_on_viewport_gui_input)

	# ── PAINEL DE ACESSÓRIOS GUNSMITH (TRANCA TÁTICA / FUTURA ATUALIZAÇÃO) ────
	gunsmith_panel = PanelContainer.new()
	gunsmith_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var g_st = StyleBoxFlat.new()
	g_st.bg_color = Color(0.06, 0.08, 0.12, 0.92)
	g_st.border_color = Color(0.3, 0.4, 0.55, 0.5)
	g_st.set_border_width_all(1)
	g_st.set_corner_radius_all(6)
	g_st.content_margin_left = 12
	g_st.content_margin_right = 12
	g_st.content_margin_top = 8
	g_st.content_margin_bottom = 8
	gunsmith_panel.add_theme_stylebox_override("panel", g_st)
	gunsmith_panel.mouse_entered.connect(_on_gunsmith_panel_mouse_entered)
	gunsmith_panel.mouse_exited.connect(_on_gunsmith_panel_mouse_exited)
	gunsmith_panel.gui_input.connect(_on_gunsmith_panel_gui_input)
	right_vbox.add_child(gunsmith_panel)

	var gs_vbox = VBoxContainer.new()
	gs_vbox.add_theme_constant_override("separation", 6)
	gunsmith_panel.add_child(gs_vbox)

	var gs_header = HBoxContainer.new()
	gs_vbox.add_child(gs_header)

	var lbl_gs = Label.new()
	lbl_gs.text = "🔒 ACESSÓRIOS TÁTICOS & CAMUFLAGEM (GUNSMITH 3D):"
	lbl_gs.add_theme_font_size_override("font_size", 12)
	lbl_gs.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2, 1.0))
	lbl_gs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gs_header.add_child(lbl_gs)

	var badge_locked = Label.new()
	badge_locked.text = "[ BLOQUEADO — FUTURA ATUALIZAÇÃO ]"
	badge_locked.add_theme_font_size_override("font_size", 10)
	badge_locked.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0, 0.90))
	gs_header.add_child(badge_locked)

	var gs_slots_grid = GridContainer.new()
	gs_slots_grid.columns = 4
	gs_slots_grid.add_theme_constant_override("h_separation", 10)
	gs_slots_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gs_vbox.add_child(gs_slots_grid)

	var slot_st_norm = StyleBoxFlat.new()
	slot_st_norm.bg_color = Color(0.08, 0.10, 0.15, 0.90)
	slot_st_norm.border_color = Color(0.28, 0.35, 0.45, 0.6)
	slot_st_norm.set_border_width_all(1)
	slot_st_norm.set_corner_radius_all(4)

	var slot_st_hov = slot_st_norm.duplicate()
	slot_st_hov.bg_color = Color(0.12, 0.15, 0.22, 0.95)
	slot_st_hov.border_color = Color(1.0, 0.65, 0.15, 0.85)

	# Slot 1: Mira
	opt_optic = Button.new()
	opt_optic.text = "🔒 🔭 Mira Ferro"
	opt_optic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_optic.focus_mode = Control.FOCUS_NONE
	opt_optic.add_theme_stylebox_override("normal", slot_st_norm)
	opt_optic.add_theme_stylebox_override("hover", slot_st_hov)
	opt_optic.add_theme_color_override("font_color", Color(0.70, 0.75, 0.85, 0.85))
	opt_optic.add_theme_color_override("font_hover_color", Color(1.0, 0.78, 0.30, 1.0))
	opt_optic.mouse_entered.connect(_on_gunsmith_panel_mouse_entered)
	opt_optic.mouse_exited.connect(_on_gunsmith_panel_mouse_exited)
	opt_optic.pressed.connect(_on_gunsmith_locked_triggered)
	gs_slots_grid.add_child(opt_optic)

	# Slot 2: Boca
	opt_muzzle = Button.new()
	opt_muzzle.text = "🔒 🔇 Boca Padrão"
	opt_muzzle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_muzzle.focus_mode = Control.FOCUS_NONE
	opt_muzzle.add_theme_stylebox_override("normal", slot_st_norm)
	opt_muzzle.add_theme_stylebox_override("hover", slot_st_hov)
	opt_muzzle.add_theme_color_override("font_color", Color(0.70, 0.75, 0.85, 0.85))
	opt_muzzle.add_theme_color_override("font_hover_color", Color(1.0, 0.78, 0.30, 1.0))
	opt_muzzle.mouse_entered.connect(_on_gunsmith_panel_mouse_entered)
	opt_muzzle.mouse_exited.connect(_on_gunsmith_panel_mouse_exited)
	opt_muzzle.pressed.connect(_on_gunsmith_locked_triggered)
	gs_slots_grid.add_child(opt_muzzle)

	# Slot 3: Carregador
	opt_mag = Button.new()
	opt_mag.text = "🔒 🔋 Pente Padrão"
	opt_mag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_mag.focus_mode = Control.FOCUS_NONE
	opt_mag.add_theme_stylebox_override("normal", slot_st_norm)
	opt_mag.add_theme_stylebox_override("hover", slot_st_hov)
	opt_mag.add_theme_color_override("font_color", Color(0.70, 0.75, 0.85, 0.85))
	opt_mag.add_theme_color_override("font_hover_color", Color(1.0, 0.78, 0.30, 1.0))
	opt_mag.mouse_entered.connect(_on_gunsmith_panel_mouse_entered)
	opt_mag.mouse_exited.connect(_on_gunsmith_panel_mouse_exited)
	opt_mag.pressed.connect(_on_gunsmith_locked_triggered)
	gs_slots_grid.add_child(opt_mag)

	# Slot 4: Camuflagem
	opt_camo = Button.new()
	opt_camo.text = "🔒 🎨 Militar Padrão"
	opt_camo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_camo.focus_mode = Control.FOCUS_NONE
	opt_camo.add_theme_stylebox_override("normal", slot_st_norm)
	opt_camo.add_theme_stylebox_override("hover", slot_st_hov)
	opt_camo.add_theme_color_override("font_color", Color(0.70, 0.75, 0.85, 0.85))
	opt_camo.add_theme_color_override("font_hover_color", Color(1.0, 0.78, 0.30, 1.0))
	opt_camo.mouse_entered.connect(_on_gunsmith_panel_mouse_entered)
	opt_camo.mouse_exited.connect(_on_gunsmith_panel_mouse_exited)
	opt_camo.pressed.connect(_on_gunsmith_locked_triggered)
	gs_slots_grid.add_child(opt_camo)

	# Painel de Estatísticas Segmentadas (Black Ops 3 Style)
	var stats_panel = PanelContainer.new()
	var stat_st = StyleBoxFlat.new()
	stat_st.bg_color = Color(0.06, 0.08, 0.12, 0.85)
	stat_st.border_color = Color(0.2, 0.3, 0.45, 0.4)
	stat_st.set_border_width_all(1)
	stat_st.set_corner_radius_all(6)
	stat_st.content_margin_left = 16
	stat_st.content_margin_right = 16
	stat_st.content_margin_top = 10
	stat_st.content_margin_bottom = 10
	stats_panel.add_theme_stylebox_override("panel", stat_st)
	right_vbox.add_child(stats_panel)

	var stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 6)
	stats_panel.add_child(stats_vbox)

	var bars_grid = GridContainer.new()
	bars_grid.columns = 2
	bars_grid.add_theme_constant_override("h_separation", 32)
	bars_grid.add_theme_constant_override("v_separation", 6)
	stats_vbox.add_child(bars_grid)

	_create_segmented_stat_bar(bars_grid, "DAMAGE", "damage")
	_create_segmented_stat_bar(bars_grid, "RANGE", "range")
	_create_segmented_stat_bar(bars_grid, "FIRE RATE", "fire_rate")
	_create_segmented_stat_bar(bars_grid, "ACCURACY", "accuracy")

	lbl_stats_summary = Label.new()
	lbl_stats_summary.text = "Dano: 55 | Cadência: 750 RPM | Pente: 30 / 120"
	lbl_stats_summary.add_theme_font_size_override("font_size", 11)
	lbl_stats_summary.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85, 0.8))
	stats_vbox.add_child(lbl_stats_summary)

	# ── RODAPÉ DE AÇÕES ────────────────────────────────────────────────────────
	var footer_hbox = HBoxContainer.new()
	footer_hbox.name = "FooterHBox"
	footer_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(footer_hbox)

	var btn_back = Button.new()
	btn_back.text = "• VOLTAR [ESC]"
	btn_back.custom_minimum_size = Vector2(160, 42)
	btn_back.pressed.connect(close_screen)
	footer_hbox.add_child(btn_back)

	var hint_lbl = Label.new()
	hint_lbl.text = "🔄 Clique e arraste na área 3D para girar e inspecionar a arma em 360°"
	hint_lbl.add_theme_font_size_override("font_size", 12)
	hint_lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75, 0.8))
	hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_hbox.add_child(hint_lbl)

	btn_equip = Button.new()
	btn_equip.text = "✔ EQUIPAR ESTA ARMA [ENTER]"
	btn_equip.custom_minimum_size = Vector2(240, 42)
	var equip_st = StyleBoxFlat.new()
	equip_st.bg_color = Color(0.95, 0.45, 0.1, 1.0)
	equip_st.border_color = Color(1.0, 0.75, 0.3, 1.0)
	equip_st.set_border_width_all(2)
	equip_st.set_corner_radius_all(6)
	btn_equip.add_theme_stylebox_override("normal", equip_st)
	btn_equip.add_theme_font_size_override("font_size", 14)
	btn_equip.add_theme_color_override("font_color", Color(0.04, 0.04, 0.06, 1.0))
	btn_equip.pressed.connect(_on_equip_pressed)
	footer_hbox.add_child(btn_equip)

	_select_category(0)

# ── CONFIGURAÇÃO DO MUNDO 3D NO SUBVIEWPORT ───────────────────────────────────
func _setup_3d_viewport_scene() -> void:
	if not subviewport:
		return

	subviewport.own_world_3d = true
	var world_3d = subviewport.find_world_3d()
	if not world_3d:
		world_3d = World3D.new()
		subviewport.world_3d = world_3d

	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.06, 0.09, 0.0)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.25
	world_3d.environment = env

	var cam = Camera3D.new()
	cam.position = Vector3(0, 0.02, 0.88)
	cam.fov = 36.0
	subviewport.add_child(cam)
	showcase_camera = cam

	# Luz chave principal (iluminação cinematográfica suave sem estouro)
	var key_light = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-30, 45, 0)
	key_light.light_color = Color(1.0, 0.96, 0.92)
	key_light.light_energy = 1.15
	subviewport.add_child(key_light)

	# Luz rim lateral ciano estilo sci-fi BO3 (realce sutil de contorno)
	var rim_light = DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(20, -140, 0)
	rim_light.light_color = Color(0.25, 0.75, 1.0)
	rim_light.light_energy = 0.85
	subviewport.add_child(rim_light)

	# Luz de preenchimento suave
	var fill_light = OmniLight3D.new()
	fill_light.position = Vector3(0, -0.2, 0.5)
	fill_light.light_color = Color(0.8, 0.85, 0.95)
	fill_light.light_energy = 0.40
	fill_light.omni_range = 3.0
	subviewport.add_child(fill_light)

	# Pedestal metálico escuro com anel de neon estilo Black Ops 3
	var pedestal = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.52
	cyl.bottom_radius = 0.58
	cyl.height = 0.04
	pedestal.mesh = cyl
	var ped_mat = StandardMaterial3D.new()
	ped_mat.albedo_color = Color(0.08, 0.11, 0.16)
	ped_mat.metallic = 0.85
	ped_mat.roughness = 0.25
	pedestal.material_override = ped_mat
	pedestal.position = Vector3(0, -0.20, 0)
	subviewport.add_child(pedestal)

	var neon_ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.51
	torus.outer_radius = 0.54
	neon_ring.mesh = torus
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.95, 0.45, 0.1)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.95, 0.45, 0.1)
	ring_mat.emission_energy_multiplier = 2.0
	neon_ring.material_override = ring_mat
	neon_ring.position = Vector3(0, -0.18, 0)
	subviewport.add_child(neon_ring)

	# Nó rotatório da arma
	turntable_node = Node3D.new()
	turntable_node.name = "Turntable"
	subviewport.add_child(turntable_node)

# ── BARRAS DE ATRIBUTOS SEGMENTADAS ESTILO COD BO3 ────────────────────────────
func _create_segmented_stat_bar(parent: Container, label_text: String, stat_key: String) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	parent.add_child(hbox)

	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(85, 0)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9, 0.9))
	hbox.add_child(lbl)

	# Container dos blocos segmentados (15 blocos horizontais)
	var blocks_hbox = HBoxContainer.new()
	blocks_hbox.add_theme_constant_override("separation", 2)
	blocks_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(blocks_hbox)

	var blocks: Array[ColorRect] = []
	for i in range(15):
		var rect = ColorRect.new()
		rect.custom_minimum_size = Vector2(14, 12)
		rect.color = Color(0.12, 0.16, 0.22, 0.75)
		blocks_hbox.add_child(rect)
		blocks.append(rect)

	var val_lbl = Label.new()
	val_lbl.text = "0"
	val_lbl.custom_minimum_size = Vector2(30, 0)
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.9))
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(val_lbl)

	segmented_bars[stat_key] = {"blocks": blocks, "val_lbl": val_lbl}

func _update_segmented_bar(stat_key: String, value_pct: int) -> void:
	if not segmented_bars.has(stat_key):
		return

	var bar_data = segmented_bars[stat_key]
	var blocks: Array[ColorRect] = bar_data["blocks"]
	var val_lbl: Label = bar_data["val_lbl"]

	val_lbl.text = str(value_pct)
	var active_blocks_count = int(round((float(value_pct) / 100.0) * 15.0))

	for i in range(blocks.size()):
		var rect = blocks[i]
		if i < active_blocks_count:
			# Cores vivas: verde para atributos altos, laranja para médios
			if value_pct >= 75:
				rect.color = Color(0.3, 0.88, 0.42, 1.0)
			elif value_pct >= 50:
				rect.color = Color(0.95, 0.65, 0.15, 1.0)
			else:
				rect.color = Color(0.95, 0.35, 0.25, 1.0)
		else:
			rect.color = Color(0.12, 0.16, 0.22, 0.7)

# ── SELEÇÃO DE CATEGORIA E CARDS ──────────────────────────────────────────────
func _select_category(cat_idx: int) -> void:
	current_category_idx = clampi(cat_idx, 0, CATEGORIES.size() - 1)

	# Atualizar visual das abas
	for i in range(tab_buttons.size()):
		var btn = tab_buttons[i]
		var is_sel = (i == current_category_idx)

		var st = StyleBoxFlat.new()
		if is_sel:
			st.bg_color = Color(0.95, 0.45, 0.1, 0.95)
			st.border_color = Color(1.0, 0.8, 0.3, 1.0)
			st.set_border_width_all(2)
			btn.add_theme_color_override("font_color", Color(0.04, 0.04, 0.06, 1.0))
		else:
			st.bg_color = Color(0.09, 0.12, 0.18, 0.85)
			st.border_color = Color(0.25, 0.35, 0.48, 0.4)
			st.set_border_width_all(1)
			btn.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9, 0.9))
		st.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", st)

	# Reconstruir lista de armas da categoria
	_rebuild_weapon_list()
	_select_weapon(0)

func _rebuild_weapon_list() -> void:
	if not weapon_list_vbox:
		return
	# Limpar lista anterior
	for child in weapon_list_vbox.get_children():
		if child.is_inside_tree():
			child.queue_free()
		else:
			child.free()
	weapon_cards.clear()

	var cat = CATEGORIES[current_category_idx]
	var weapons = cat["weapons"]

	for i in range(weapons.size()):
		var w = weapons[i]
		var card = _create_weapon_card(w, i)
		weapon_list_vbox.add_child(card)
		weapon_cards.append(card)

func _create_weapon_card(w: Dictionary, index: int) -> Button:
	var btn = Button.new()
	btn.name = "WeaponCard_%d" % index
	btn.custom_minimum_size = Vector2(0, 52)

	var st = StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.12, 0.18, 0.9)
	st.border_color = Color(0.25, 0.35, 0.50, 0.4)
	st.set_border_width_all(1)
	st.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("normal", st)

	# Layout interno do card
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 12)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_child(hbox)
	btn.add_child(margin)

	# Thumbnail box com ícone estilizado estilo BO3
	var thumb_box = PanelContainer.new()
	thumb_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb_box.custom_minimum_size = Vector2(56, 38)
	var tb_st = StyleBoxFlat.new()
	tb_st.bg_color = Color(0.04, 0.06, 0.09, 0.95)
	tb_st.border_color = Color(0.3, 0.4, 0.55, 0.5)
	tb_st.set_border_width_all(1)
	tb_st.set_corner_radius_all(3)
	thumb_box.add_theme_stylebox_override("panel", tb_st)
	hbox.add_child(thumb_box)

	var icon_lbl = Label.new()
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_lbl.text = _get_weapon_glyph(w.get("model_type", "rifle"))
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 13)
	icon_lbl.modulate = Color(0.95, 0.75, 0.25, 0.95)
	thumb_box.add_child(icon_lbl)

	# Nome da arma
	var name_lbl = Label.new()
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.text = w["name"]
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_lbl)

	# Badge de nível estilo BO3
	var badge_lbl = Label.new()
	badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_lbl.text = w.get("level", "1 ▶")
	badge_lbl.add_theme_font_size_override("font_size", 11)
	badge_lbl.modulate = Color(0.95, 0.75, 0.2, 0.9)
	hbox.add_child(badge_lbl)

	_set_mouse_filter_recursive(btn, Control.MOUSE_FILTER_IGNORE)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_select_weapon.bind(index))
	return btn

func _set_mouse_filter_recursive(node: Node, filter_mode: int) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = filter_mode
		_set_mouse_filter_recursive(child, filter_mode)

func _get_weapon_glyph(model_type: String) -> String:
	match model_type:
		"rifle", "ak":
			return "︻╦デ═—"
		"smg":
			return "▄︻デ══━"
		"shotgun":
			return "︻┳═一"
		"lmg":
			return "︻╦╤─"
		"pistol":
			return "⌐╦╦═─"
		"knife":
			return "🗡️"
		_:
			return "︻╦デ═—"

# ── SELEÇÃO DE ARMA & ATUALIZAÇÃO DO SHOWCASE 3D ──────────────────────────────
func _select_weapon(index: int) -> void:
	var weapons = CATEGORIES[current_category_idx]["weapons"]
	current_weapon_idx = clampi(index, 0, weapons.size() - 1)
	selected_weapon_data = weapons[current_weapon_idx]

	# Atualizar bordas brilhantes no card selecionado estilo Black Ops 3
	for i in range(weapon_cards.size()):
		var card = weapon_cards[i]
		var is_sel = (i == current_weapon_idx)

		var st = StyleBoxFlat.new()
		if is_sel:
			st.bg_color = Color(0.18, 0.12, 0.05, 0.95)
			st.border_color = Color(0.95, 0.45, 0.1, 1.0)
			st.set_border_width_all(2)
			st.shadow_color = Color(0.95, 0.45, 0.1, 0.3)
			st.shadow_size = 6
		else:
			st.bg_color = Color(0.09, 0.12, 0.18, 0.85)
			st.border_color = Color(0.25, 0.35, 0.50, 0.4)
			st.set_border_width_all(1)
		st.set_corner_radius_all(5)
		card.add_theme_stylebox_override("normal", st)

	# Atualizar textos e dados da arma
	if lbl_weapon_name:
		lbl_weapon_name.text = selected_weapon_data["name"]
	if lbl_weapon_desc:
		lbl_weapon_desc.text = selected_weapon_data["desc"]
	if lbl_weapon_level_badge:
		lbl_weapon_level_badge.text = "WEAPON LEVEL  %s" % selected_weapon_data.get("level", "MAX ★")

	# Atualizar barras de estatísticas segmentadas
	_update_segmented_bar("damage", selected_weapon_data.get("damage", 60))
	_update_segmented_bar("range", selected_weapon_data.get("range", 60))
	_update_segmented_bar("fire_rate", selected_weapon_data.get("fire_rate", 60))
	_update_segmented_bar("accuracy", selected_weapon_data.get("accuracy", 60))

	# Atualizar resumo numérico
	var w_res: WeaponData = load(selected_weapon_data["path"]) as WeaponData if ResourceLoader.exists(selected_weapon_data["path"]) else null
	if w_res and lbl_stats_summary:
		lbl_stats_summary.text = "Dano: %d-%d  |  Cadência: %.0f RPM  |  Pente: %d/%d  |  Recarga: %.1fs  |  ADS: %.2fs" % [
			w_res.damage_close, w_res.damage_long, w_res.fire_rate_rpm,
			w_res.magazine_capacity, w_res.reserve_ammo_max,
			w_res.reload_tactical_time, w_res.ads_time
		]

	# Suavizar rotação e restaurar o ângulo tático 3/4
	_smooth_reset_turntable()

	# Atualizar modelo 3D dedicado no turntable
	_load_3d_weapon_model(selected_weapon_data.get("model_type", "rifle"), selected_weapon_data["path"])

# ── RESET SUAVE DO TURNTABLE (BEAUTY ANGLE) ──────────────────────────────────
func _smooth_reset_turntable() -> void:
	if turntable_tween and turntable_tween.is_valid():
		turntable_tween.kill()

	if not is_inside_tree():
		turntable_rot_y = -0.55
		if turntable_node:
			turntable_node.rotation.y = -0.55
		return

	var tw = create_tween()
	if not tw:
		turntable_rot_y = -0.55
		if turntable_node:
			turntable_node.rotation.y = -0.55
		return

	turntable_tween = tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	turntable_tween.tween_property(self, "turntable_rot_y", -0.55, 0.35)
	if turntable_node:
		turntable_tween.parallel().tween_property(turntable_node, "rotation:y", -0.55, 0.35)

# ── CARREGAMENTO DO MODELO 3D DEDICADO VIA WEAPON VISUAL REGISTRY ─────────────
func _load_3d_weapon_model(_model_type: String, weapon_path: String) -> void:
	if not turntable_node:
		return

	# Limpar modelo e pivôs anteriores
	for child in turntable_node.get_children():
		if child.is_inside_tree():
			child.queue_free()
		else:
			child.free()

	active_3d_model = null

	# Instanciar modelo exclusivo calibrado
	var wrapper = WeaponVisualRegistry.instantiate_weapon_showcase(weapon_path)
	if not wrapper:
		return

	turntable_node.add_child(wrapper)
	active_3d_model = wrapper

	# Anexar acessórios 3D do Gunsmith e camuflagem ativa (Padrão de fábrica / Stock)
	selected_optic = "none"
	selected_muzzle = "none"
	selected_mag = "none"
	selected_camo = "default"
	WeaponVisualRegistry.update_attachments(active_3d_model, "none", "none", "none")
	WeaponVisualRegistry.apply_camo(active_3d_model, "default")

# ── CONTROLE DO VIEWPORT 3D (MOUSE DRAG / ROTATE / ZOOM) ──────────────────────
func _on_viewport_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_mouse_dragging = event.pressed
			last_mouse_pos = event.position
			if is_mouse_dragging and turntable_tween and turntable_tween.is_valid():
				turntable_tween.kill()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			current_zoom = clampf(current_zoom - 0.05, 0.45, 1.30)
			_update_camera_zoom()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			current_zoom = clampf(current_zoom + 0.05, 0.45, 1.30)
			_update_camera_zoom()
	elif event is InputEventMouseMotion and is_mouse_dragging:
		var delta_x = event.position.x - last_mouse_pos.x
		turntable_rot_y += delta_x * 0.012
		last_mouse_pos = event.position
		if turntable_node:
			turntable_node.rotation.y = turntable_rot_y

func _update_camera_zoom() -> void:
	if showcase_camera:
		showcase_camera.position.z = current_zoom

func _process(delta: float) -> void:
	if not is_open:
		return

	# Gerenciamento do temporizador do pop-up de bloqueio do Gunsmith
	if locked_popup_held_timer > 0.0:
		locked_popup_held_timer -= delta
		if locked_popup_held_timer <= 0.0 and not is_hovering_gunsmith_panel:
			_hide_gunsmith_locked_popup()

	# Rotação suave contínua quando não estiver arrastando com mouse
	if not is_mouse_dragging and turntable_node:
		turntable_rot_y += auto_rotate_speed * delta
		turntable_node.rotation.y = turntable_rot_y

# ── CONFIRMAÇÃO & EQUIPAR ─────────────────────────────────────────────────────
func _on_equip_pressed() -> void:
	if selected_weapon_data.is_empty():
		return

	var w_path = selected_weapon_data["path"]
	var w_data = load(w_path) as WeaponData if ResourceLoader.exists(w_path) else null

	var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	if gm:
		if target_slot == "secondary":
			gm.secondary_weapon_res = w_path
		else:
			gm.primary_weapon_res = w_path
			gm.set_weapon_customization("default", "none", "none", "none")

	if on_equip_callback.is_valid():
		var argc = on_equip_callback.get_argument_count()
		match argc:
			0:
				on_equip_callback.call()
			1:
				on_equip_callback.call(w_path)
			2:
				on_equip_callback.call(w_path, w_data)
			_:
				on_equip_callback.call(w_path, w_data, target_slot)

	weapon_selected.emit(w_path, w_data)
	weapon_selected_for_slot.emit(w_path, w_data, target_slot)
	close_screen()

# ── SISTEMA DE POP-UP BLOQUEADO (GUNSMITH 3D FUTURA ATUALIZAÇÃO) ──────────────
func _build_gunsmith_locked_popup() -> void:
	if gunsmith_locked_popup:
		return

	gunsmith_locked_popup = PanelContainer.new()
	gunsmith_locked_popup.name = "BO3GunsmithLockedPopup"
	gunsmith_locked_popup.visible = false
	gunsmith_locked_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gunsmith_locked_popup.custom_minimum_size = Vector2(380, 0)

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
	lbl_body.text = "A bancada de armamento (Gunsmith 3D) e personalização de acessórios (miras ópticas, bocas, pentes e camuflagens) serão implementadas em uma futura grande atualização do jogo!"
	lbl_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_body.add_theme_font_size_override("font_size", 11)
	lbl_body.add_theme_color_override("font_color", Color(0.90, 0.94, 0.98, 0.95))
	vb.add_child(lbl_body)

	# Sub-nota tática
	var lbl_note = Label.new()
	lbl_note.text = "★ Todas as armas operam em seu padrão de fábrica original para que novas miras e afins cheguem como novidades."
	lbl_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_note.add_theme_font_size_override("font_size", 10)
	lbl_note.add_theme_color_override("font_color", Color(0.65, 0.75, 0.88, 0.80))
	vb.add_child(lbl_note)

	add_child(gunsmith_locked_popup)

func _show_gunsmith_locked_popup() -> void:
	if not gunsmith_locked_popup:
		_build_gunsmith_locked_popup()

	if not gunsmith_panel or not gunsmith_panel.is_inside_tree():
		return

	var rect = gunsmith_panel.get_global_rect()
	var vp_rect = get_viewport().get_visible_rect()

	var pos_x = rect.position.x + (rect.size.x - 380.0) * 0.5
	var pos_y = rect.position.y - 130.0

	# Clamping dentro da tela
	pos_x = clampf(pos_x, 20.0, vp_rect.size.x - 400.0)
	pos_y = clampf(pos_y, 40.0, vp_rect.size.y - 150.0)

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
		if not is_hovering_gunsmith_panel and locked_popup_held_timer <= 0.0 and gunsmith_locked_popup:
			gunsmith_locked_popup.visible = false
	)

func _on_gunsmith_panel_mouse_entered() -> void:
	is_hovering_gunsmith_panel = true
	_show_gunsmith_locked_popup()
	_play_ui_tick()

func _on_gunsmith_panel_mouse_exited() -> void:
	is_hovering_gunsmith_panel = false
	if locked_popup_held_timer <= 0.0:
		_hide_gunsmith_locked_popup()

func _on_gunsmith_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_gunsmith_locked_triggered()

func _on_gunsmith_locked_triggered() -> void:
	_play_mechanical_click()
	is_hovering_gunsmith_panel = true
	locked_popup_held_timer = 2.8
	_show_gunsmith_locked_popup()

	if gunsmith_locked_popup:
		var orig_pos = gunsmith_locked_popup.global_position
		var tw = create_tween()
		tw.tween_property(gunsmith_locked_popup, "global_position:y", orig_pos.y - 6.0, 0.04)
		tw.tween_property(gunsmith_locked_popup, "global_position:y", orig_pos.y + 4.0, 0.04)
		tw.tween_property(gunsmith_locked_popup, "global_position:y", orig_pos.y - 2.0, 0.04)
		tw.tween_property(gunsmith_locked_popup, "global_position:y", orig_pos.y, 0.04)

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

func _recalc_stats_display() -> void:
	if selected_weapon_data.is_empty(): return
	var base_dmg = selected_weapon_data.get("damage", 50)
	var base_rng = selected_weapon_data.get("range", 60)
	var base_fr = selected_weapon_data.get("fire_rate", 70)
	var base_acc = selected_weapon_data.get("accuracy", 75)

	_update_segmented_bar("damage", clampi(base_dmg, 10, 100))
	_update_segmented_bar("range", clampi(base_rng, 10, 100))
	_update_segmented_bar("fire_rate", clampi(base_fr, 10, 100))
	_update_segmented_bar("accuracy", clampi(base_acc, 10, 100))

func _apply_camo_to_active_model(camo_key: String) -> void:
	if not active_3d_model:
		return
	
	var mat: StandardMaterial3D = null
	match camo_key:
		"gold":
			mat = StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.82, 0.25)
			mat.metallic = 0.95
			mat.roughness = 0.18
			mat.emission_enabled = true
			mat.emission = Color(0.4, 0.3, 0.05)
		"dark_matter":
			mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.18, 0.05, 0.32)
			mat.metallic = 0.8
			mat.roughness = 0.2
			mat.emission_enabled = true
			mat.emission = Color(0.65, 0.1, 0.85)
			mat.emission_energy_multiplier = 1.6
		"carbon":
			mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.14, 0.15, 0.18)
			mat.metallic = 0.5
			mat.roughness = 0.35
		_:
			mat = null

	_apply_material_recursive(active_3d_model, mat)

func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D and node.visible:
		node.material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)

# ── ENTRADA & ATALHOS ─────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not is_open:
		return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				_on_equip_pressed()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				close_screen()
				get_viewport().set_input_as_handled()
			KEY_LEFT:
				var next_cat = (current_category_idx - 1 + CATEGORIES.size()) % CATEGORIES.size()
				_select_category(next_cat)
				get_viewport().set_input_as_handled()
			KEY_RIGHT:
				var next_cat = (current_category_idx + 1) % CATEGORIES.size()
				_select_category(next_cat)
				get_viewport().set_input_as_handled()
			KEY_UP:
				_select_weapon(current_weapon_idx - 1)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_select_weapon(current_weapon_idx + 1)
				get_viewport().set_input_as_handled()
			KEY_R:
				current_zoom = 0.88
				_update_camera_zoom()
				_smooth_reset_turntable()
				get_viewport().set_input_as_handled()

# ── ABERTURA E FECHAMENTO ─────────────────────────────────────────────────────
func open_screen(initial_cat_idx: int = 0, target_weapon_path: String = "", target_slot_name: String = "primary", equip_callback: Callable = Callable()) -> void:
	if not overlay:
		_build_ui()
	is_open = true
	visible = true
	target_slot = target_slot_name
	on_equip_callback = equip_callback
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if target_slot == "secondary":
		if title_lbl:
			title_lbl.text = "🔫 SECONDARY WEAPONS & SIDEARMS"
		if btn_equip:
			btn_equip.text = "✔ EQUIPAR NO SLOT SECUNDÁRIO [ENTER]"
		if initial_cat_idx == 0 and target_weapon_path.is_empty():
			initial_cat_idx = 5  # Secondary / Pistols
	else:
		if title_lbl:
			title_lbl.text = "︻╦デ═— PRIMARY WEAPONS"
		if btn_equip:
			btn_equip.text = "✔ EQUIPAR NO SLOT PRIMÁRIO [ENTER]"

	_select_category(initial_cat_idx)

	# Se foi especificado um caminho de arma, encontrar e selecionar diretamente
	if not target_weapon_path.is_empty():
		for c_idx in range(CATEGORIES.size()):
			var cat = CATEGORIES[c_idx]
			for w_idx in range(cat["weapons"].size()):
				if cat["weapons"][w_idx]["path"] == target_weapon_path:
					_select_category(c_idx)
					_select_weapon(w_idx)
					return

func close_screen() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	is_hovering_gunsmith_panel = false
	locked_popup_held_timer = 0.0
	if gunsmith_locked_popup:
		gunsmith_locked_popup.visible = false
	on_equip_callback = Callable()
	screen_closed.emit()
