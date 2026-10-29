# =============================================================================
# main_menu.gd
# Menu Principal Moderno e Visual - Call of Duty Style (BO3 / BO1 Experience)
# - Seletor visual em Cards com imagens em alta definicao para Nuketown 2065 (BO3) e Nuketown Classica (BO1)
# - Alternador agil entre Bots (Treino/Solo) e Multiplayer Online
# - Seletor instantaneo de quantidade de bots (1 a 15) com presets (1v1 a 6v6)
# - Seletor de dificuldade calibrada (Recruta, Regular, Veterano)
# - Painel tatico Gunsmith (armamento primario/secundario, skins, faccoes CT/T)
# - Sistema de configuracoes e audio
# =============================================================================
class_name MainMenu
extends Control

const SkinRegistry = preload("res://scripts/characters/skin_registry.gd")
const RoomCodeHelper = preload("res://scripts/network/room_code_helper.gd")
const WeaponModifier = preload("res://scripts/weapons/weapon_modifier.gd")
const CamoRegistryHelper = preload("res://scripts/weapons/camo_registry.gd")

# HERO STAGE 3D
@onready var hero_stage            : MenuHeroStage = get_node_or_null("HeroViewportContainer/HeroSubViewport/MenuHeroStage")

# CARDS DE SELECAO DE MODOS DE JOGO (LISTA TATICA VERTICAL)
@onready var card_mode_tdm         : Button        = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/CardsHBox/CardModeTDM
@onready var card_mode_duel        : Button        = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/CardsHBox/CardModeDuel
@onready var card_mode_pve         : Button        = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/CardsHBox/CardModePVE
@onready var card_mode_tournament  : Button        = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/CardsHBox.get_node_or_null("CardModeTournament")
@onready var lbl_status_tdm        : Label         = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/CardsHBox/CardModeTDM/Margin/VBox/LblStatusTDM
@onready var lbl_status_duel       : Label         = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/CardsHBox/CardModeDuel/Margin/VBox/LblStatusDuel
@onready var lbl_status_pve        : Label         = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/CardsHBox/CardModePVE/Margin/VBox/LblStatusPVE

# ALIASES DE COMPATIBILIDADE PARA TESTES HISTORICOS
var card_nuk3town: Button:
	get: return card_mode_tdm
var card_classic: Button:
	get: return card_mode_duel

# MODO DE COMBATE
@onready var btn_mode_bots         : Button        = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/CategorySection/BtnModeBots
@onready var btn_mode_online       : Button        = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/CategorySection/BtnModeOnline

# CONTROLES DE BOTS
@onready var box_bots_config       : Control       = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/BoxBotsConfig
@onready var btn_preset_1v1        : Button        = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/BoxBotsConfig/PresetsRow/BtnPreset1v1
@onready var btn_preset_2v2        : Button        = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/BoxBotsConfig/PresetsRow/BtnPreset2v2
@onready var btn_preset_3v3        : Button        = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/BoxBotsConfig/PresetsRow/BtnPreset3v3
@onready var btn_preset_4v4        : Button        = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/BoxBotsConfig/PresetsRow/BtnPreset4v4
@onready var btn_preset_5v5        : Button        = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/BoxBotsConfig/PresetsRow/BtnPreset5v5
@onready var btn_preset_6v6        : Button        = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/BoxBotsConfig/PresetsRow/BtnPreset6v6

@onready var btn_bot_minus         : Button        = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/BoxBotsConfig/StepperRow/BtnBotMinus
@onready var lbl_bot_count         : Label         = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/BoxBotsConfig/StepperRow/LblBotCount
@onready var btn_bot_plus          : Button        = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/BoxBotsConfig/StepperRow/BtnBotPlus

@onready var btn_diff_recruit      : Button        = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/BoxBotsConfig/StepperRow.get_node_or_null("BtnDiffRecruit")
@onready var btn_diff_novice       : Button        = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/BoxBotsConfig/StepperRow.get_node_or_null("BtnDiffNovice")
@onready var btn_diff_regular      : Button        = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/BoxBotsConfig/StepperRow.get_node_or_null("BtnDiffRegular")
@onready var btn_diff_veteran      : Button        = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/BoxBotsConfig/StepperRow.get_node_or_null("BtnDiffVeteran")
@onready var btn_diff_expert       : Button        = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/BoxBotsConfig/StepperRow.get_node_or_null("BtnDiffExpert")

# CONTROLES ONLINE
@onready var box_online_config     : Control       = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/BoxOnlineConfig
@onready var btn_online_host       : Button        = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/BoxOnlineConfig/OnlineRow1/BtnOnlineHost
@onready var btn_online_join       : Button        = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/BoxOnlineConfig/OnlineRow1/BtnOnlineJoin
@onready var input_online_ip       : LineEdit      = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/BoxOnlineConfig/OnlineRow2/InputOnlineIP
@onready var input_online_port     : LineEdit      = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/BoxOnlineConfig.get_node_or_null("InputOnlinePort")
@onready var check_fill_bots       : CheckBox      = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/BoxOnlineConfig.get_node_or_null("CheckFillBots")
@onready var btn_paste_code        : Button        = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/BoxOnlineConfig/OnlineRow2.get_node_or_null("BtnPasteCode")
@onready var btn_dedicated_server  : Button        = $MainLayout/VBox/LeftPanel/LeftMargin/LeftVBox/BoxOnlineConfig.get_node_or_null("BtnDedicatedServer")

# FOOTER DE ACAO PRINCIPAL
@onready var btn_deploy_main       : Button        = $BottomBar/BottomMargin/ActionFooter/BtnDeploy
@onready var btn_gunsmith          : Button        = $BottomBar/BottomMargin/ActionFooter/BtnGunsmith
@onready var btn_social            : Button        = $BottomBar/BottomMargin/ActionFooter.get_node_or_null("BtnSocial")
@onready var btn_settings          : Button        = $BottomBar/BottomMargin/ActionFooter/BtnSettings
@onready var btn_quit              : Button        = $BottomBar/BottomMargin/ActionFooter/BtnQuit
@onready var social_modal          : Control       = get_node_or_null("SocialModal")

# MODAL GUNSMITH / LOADOUT
@onready var panel_class_select    : PanelContainer= $PanelClassSelect
@onready var lbl_phase_name        : Label         = $PanelClassSelect/Margin/VBox/Header/LblPhaseName
@onready var btn_class_assault     : Button        = $PanelClassSelect/Margin/VBox/Content/Left/BtnClassAssault
@onready var btn_class_cqb         : Button        = $PanelClassSelect/Margin/VBox/Content/Left/BtnClassCQB
@onready var btn_class_support     : Button        = $PanelClassSelect/Margin/VBox/Content/Left/BtnClassSupport
@onready var btn_class_breacher    : Button        = $PanelClassSelect/Margin/VBox/Content/Left/BtnClassBreacher
@onready var btn_class_sniper      : Button        = $PanelClassSelect/Margin/VBox/Content/Left.get_node_or_null("BtnClassSniper")
@onready var btn_faction_ct        : Button        = $PanelClassSelect/Margin/VBox/Content/Left/FactionHBox/BtnFactionCT
@onready var btn_faction_t         : Button        = $PanelClassSelect/Margin/VBox/Content/Left/FactionHBox/BtnFactionT
@onready var opt_skin              : OptionButton  = $PanelClassSelect/Margin/VBox/Content/Left/OptSkin
@onready var opt_primary           : OptionButton  = $PanelClassSelect/Margin/VBox/Content/Left/OptPrimary

@onready var lbl_class_title       : Label         = $PanelClassSelect/Margin/VBox/Content/Right/LblClassTitle
@onready var lbl_primary_info      : Label         = $PanelClassSelect/Margin/VBox/Content/Right/Slot1Panel/Margin1/VBox1/LblPrimaryInfo
@onready var lbl_secondary_info    : Label         = $PanelClassSelect/Margin/VBox/Content/Right/Slot2Panel/Margin2/VBox2/LblSecondaryInfo
@onready var lbl_melee_info        : Label         = $PanelClassSelect/Margin/VBox/Content/Right/Slot3Panel/Margin3/VBox3/LblMeleeInfo
@onready var lbl_skin_info         : Label         = $PanelClassSelect/Margin/VBox/Content/Right/SlotSkinPanel/MarginSkin/VBoxSkin/LblSkinInfo
@onready var btn_deploy_modal      : Button        = $PanelClassSelect/Margin/VBox/Footer/BtnDeploy
@onready var btn_back_modal        : Button        = $PanelClassSelect/Margin/VBox/Footer/BtnBack

@onready var settings_menu         : Control       = $SettingsMenu

# ESTADO DA PARTIDA
var play_mode_bots                 : bool   = true
var selected_game_mode             : String = "6v6"  # "6v6", "1v1", "pve"
var target_map_scene               : String = "res://scenes/_world/map_nuk3town_bo3.tscn"
var target_map_name                : String = "NUKETOWN 2065 (BO3 FUTURISTA)"
var selected_bot_count             : int    = 11
var selected_distribution          : int    = 0  # 0 = BALANCED, 1 = ALL_ENEMIES
var selected_difficulty            : int    = 2  # 0=RECRUIT, 1=NOVICE, 2=REGULAR, 3=VETERAN, 4=EXPERT
var is_online_host                 : bool   = true

# ESTADO DO LOADOUT
var selected_primary_res           : String = "res://resources/weapons/ak47.tres"
var selected_secondary_res         : String = "res://resources/weapons/pistol.tres"
var selected_melee_res             : String = "res://resources/weapons/knife.tres"
var selected_class_name            : String = "Assalto"
var selected_faction               : int    = SkinRegistry.Faction.COUNTER_TERRORIST
var selected_skin_id               : String = "ct_urban"

var style_card_selected            : StyleBox
var style_card_unselected          : StyleBox
var style_diff_active              : StyleBox
var style_diff_normal              : StyleBox

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_apply_web_menu_profile()

	if card_mode_tdm:
		style_card_selected = card_mode_tdm.get_theme_stylebox("normal")
	if card_mode_duel:
		style_card_unselected = card_mode_duel.get_theme_stylebox("normal")
	if btn_diff_regular:
		style_diff_active = btn_diff_regular.get_theme_stylebox("normal")
	if btn_diff_recruit:
		style_diff_normal = btn_diff_recruit.get_theme_stylebox("normal")

	# 1. Selecao de Modos de Jogo (Cards visuais estilo CoD)
	if card_mode_tdm:
		card_mode_tdm.pressed.connect(func(): _select_game_mode("6v6"))
	if card_mode_duel:
		card_mode_duel.pressed.connect(func(): _select_game_mode("1v1"))
	if card_mode_pve:
		card_mode_pve.pressed.connect(func(): _select_game_mode("pve"))
	if card_mode_tournament:
		card_mode_tournament.pressed.connect(func(): _select_game_mode("wager"))

	# 2. Modo de Jogo (Bots vs Online)
	if btn_mode_bots:
		btn_mode_bots.pressed.connect(func(): _set_play_mode(true))
	if btn_mode_online:
		btn_mode_online.pressed.connect(func(): _set_play_mode(false))

	# 3. Presets de Bots (Configuracao tatica balanceada Alpha vs Bravo)
	if btn_preset_1v1: btn_preset_1v1.pressed.connect(func(): _set_bot_count(1))
	if btn_preset_2v2: btn_preset_2v2.pressed.connect(func(): _set_bot_count(3))
	if btn_preset_3v3: btn_preset_3v3.pressed.connect(func(): _set_bot_count(5))
	if btn_preset_4v4: btn_preset_4v4.pressed.connect(func(): _set_bot_count(7))
	if btn_preset_5v5: btn_preset_5v5.pressed.connect(func(): _set_bot_count(9))
	if btn_preset_6v6: btn_preset_6v6.pressed.connect(func(): _set_bot_count(11))

	# 4. Stepper de Bots
	if btn_bot_minus: btn_bot_minus.pressed.connect(func(): _set_bot_count(selected_bot_count - 1))
	if btn_bot_plus:  btn_bot_plus.pressed.connect(func(): _set_bot_count(selected_bot_count + 1))

	# 5. Dificuldade dos Bots (5 Níveis)
	if btn_diff_recruit: btn_diff_recruit.pressed.connect(func(): _set_difficulty(0))
	if btn_diff_novice:  btn_diff_novice.pressed.connect(func(): _set_difficulty(1))
	if btn_diff_regular: btn_diff_regular.pressed.connect(func(): _set_difficulty(2))
	if btn_diff_veteran: btn_diff_veteran.pressed.connect(func(): _set_difficulty(3))
	if btn_diff_expert:  btn_diff_expert.pressed.connect(func(): _set_difficulty(4))

	# 6. Modo Online
	if btn_online_host: btn_online_host.pressed.connect(func(): _set_online_role(true))
	if btn_online_join: btn_online_join.pressed.connect(func(): _set_online_role(false))
	if btn_paste_code: btn_paste_code.pressed.connect(_on_paste_code_pressed)
	if btn_dedicated_server: btn_dedicated_server.pressed.connect(_on_dedicated_server_pressed)

	# 7. Acoes Principais
	if btn_deploy_main:  btn_deploy_main.pressed.connect(_on_deploy_pressed)
	if btn_gunsmith:     btn_gunsmith.pressed.connect(_open_gunsmith)
	if btn_social:       btn_social.pressed.connect(_open_social)
	if btn_settings:     btn_settings.pressed.connect(_open_settings)
	if btn_quit:         btn_quit.pressed.connect(_on_quit)

	# 8. Modal de Gunsmith
	if btn_faction_ct: btn_faction_ct.pressed.connect(func(): _set_faction(SkinRegistry.Faction.COUNTER_TERRORIST))
	if btn_faction_t:  btn_faction_t.pressed.connect(func(): _set_faction(SkinRegistry.Faction.TERRORIST))
	if btn_class_assault:  btn_class_assault.pressed.connect(func(): _select_preset_class("Assalto"))
	if btn_class_cqb:      btn_class_cqb.pressed.connect(func(): _select_preset_class("CQB"))
	if btn_class_support:  btn_class_support.pressed.connect(func(): _select_preset_class("Suporte"))
	if btn_class_breacher: btn_class_breacher.pressed.connect(func(): _select_preset_class("Breacher"))
	if btn_class_sniper:   btn_class_sniper.pressed.connect(func(): _select_preset_class("Sniper"))
	if opt_skin:    opt_skin.item_selected.connect(_on_opt_skin_selected)
	if opt_primary:
		opt_primary.item_selected.connect(_on_opt_primary_selected)
		var btn_browse = Button.new()
		btn_browse.text = "🔍 NAVEGAR ARMAS EM 3D (ESTILO BO3)"
		btn_browse.custom_minimum_size = Vector2(0, 36)
		var b_st = StyleBoxFlat.new()
		b_st.bg_color = Color(0.12, 0.18, 0.28, 0.95)
		b_st.border_color = Color(0.3, 0.75, 1.0, 0.85)
		b_st.set_border_width_all(1)
		b_st.set_corner_radius_all(4)
		btn_browse.add_theme_stylebox_override("normal", b_st)
		btn_browse.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0, 1.0))
		btn_browse.add_theme_font_size_override("font_size", 14)
		btn_browse.pressed.connect(_open_bo3_browser)
		if opt_primary.get_parent():
			opt_primary.get_parent().add_child(btn_browse)
	if btn_deploy_modal: btn_deploy_modal.pressed.connect(_on_deploy_pressed)
	if btn_back_modal:   btn_back_modal.pressed.connect(func(): panel_class_select.visible = false)

	_init_primary_options()
	_set_faction(SkinRegistry.Faction.COUNTER_TERRORIST)
	_select_game_mode("6v6")
	_set_play_mode(true)
	_set_bot_count(11)
	_set_difficulty(2)

	# Carregar personalizações de armas persistidas
	var p_data = SaveSystem.load_player_data()
	if p_data.has("loadouts") and not p_data["loadouts"].is_empty():
		var l0 = p_data["loadouts"][0]
		if has_node("/root/GameManager"):
			var gm = get_node("/root/GameManager")
			gm.set_weapon_customization(
				l0.get("primary_camo", "default"),
				l0.get("primary_optic", "optic_red_dot"),
				l0.get("primary_muzzle", "none"),
				l0.get("primary_mag", "none")
			)
	_update_class_ui()

	# 9. Iniciar trilha sonora tema ao entrar no game
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		am.play_intro_theme()

# SELECAO DE MODOS DE JOGO ESTILO COD
func _select_game_mode(mode_id: String) -> void:
	selected_game_mode = mode_id
	var is_tdm = (mode_id == "6v6")
	var is_duel = (mode_id == "1v1")
	var is_pve = (mode_id == "pve")
	var is_tourn = (mode_id == "wager")

	if card_mode_tdm and style_card_selected and style_card_unselected:
		card_mode_tdm.add_theme_stylebox_override("normal", style_card_selected if is_tdm else style_card_unselected)
		card_mode_tdm.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_tdm else Color(0.85, 0.88, 0.94, 0.88)
		if lbl_status_tdm:
			lbl_status_tdm.text = "▸ SELECIONADO" if is_tdm else "  SELECIONAR"
			lbl_status_tdm.modulate = Color(1, 0.8, 0.2, 1) if is_tdm else Color(0.72, 0.78, 0.88, 0.85)

	if card_mode_duel and style_card_selected and style_card_unselected:
		card_mode_duel.add_theme_stylebox_override("normal", style_card_selected if is_duel else style_card_unselected)
		card_mode_duel.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_duel else Color(0.85, 0.88, 0.94, 0.88)
		if lbl_status_duel:
			lbl_status_duel.text = "▸ SELECIONADO" if is_duel else "  SELECIONAR"
			lbl_status_duel.modulate = Color(1, 0.8, 0.2, 1) if is_duel else Color(0.72, 0.78, 0.88, 0.85)

	if card_mode_pve and style_card_selected and style_card_unselected:
		card_mode_pve.add_theme_stylebox_override("normal", style_card_selected if is_pve else style_card_unselected)
		card_mode_pve.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_pve else Color(0.85, 0.88, 0.94, 0.88)
		if lbl_status_pve:
			lbl_status_pve.text = "▸ SELECIONADO" if is_pve else "  SELECIONAR"
			lbl_status_pve.modulate = Color(1, 0.8, 0.2, 1) if is_pve else Color(0.72, 0.78, 0.88, 0.85)

	if card_mode_tournament and style_card_selected and style_card_unselected:
		card_mode_tournament.add_theme_stylebox_override("normal", style_card_selected if is_tourn else style_card_unselected)
		card_mode_tournament.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_tourn else Color(0.85, 0.88, 0.94, 0.88)

	# Ajustar presets de bots de forma conveniente
	if play_mode_bots:
		if is_duel:
			_set_bot_count(1)
		elif is_tdm:
			_set_bot_count(11)
		elif is_pve:
			_set_bot_count(5)

# SELECAO DE MODO DE JOGO
func _set_play_mode(bots: bool) -> void:
	play_mode_bots = bots

	if btn_mode_bots:
		btn_mode_bots.modulate = Color(1.2, 1.2, 1.2, 1.0) if bots else Color(0.78, 0.82, 0.90, 0.85)
	if btn_mode_online:
		btn_mode_online.modulate = Color(1.2, 1.2, 1.2, 1.0) if not bots else Color(0.78, 0.82, 0.90, 0.85)

	if box_bots_config:
		box_bots_config.visible = bots
	if box_online_config:
		box_online_config.visible = not bots

# CONFIGURACAO DE BOTS
func _set_bot_count(count: int) -> void:
	selected_bot_count = clamp(count, 1, 15)
	if lbl_bot_count:
		var mode_desc = ""
		match selected_bot_count:
			1: mode_desc = " (1v1)"
			3: mode_desc = " (2v2)"
			5: mode_desc = " (3v3)"
			7: mode_desc = " (4v4)"
			9: mode_desc = " (5v5)"
			11: mode_desc = " (6v6)"
		lbl_bot_count.text = "%d BOTS%s" % [selected_bot_count, mode_desc]

	# Atualizar botoes de preset
	if btn_preset_1v1: btn_preset_1v1.modulate = Color(1.2, 1.2, 1.2, 1.0) if selected_bot_count == 1 else Color(0.7, 0.7, 0.7, 0.7)
	if btn_preset_2v2: btn_preset_2v2.modulate = Color(1.2, 1.2, 1.2, 1.0) if selected_bot_count == 3 else Color(0.7, 0.7, 0.7, 0.7)
	if btn_preset_3v3: btn_preset_3v3.modulate = Color(1.2, 1.2, 1.2, 1.0) if selected_bot_count == 5 else Color(0.7, 0.7, 0.7, 0.7)
	if btn_preset_4v4: btn_preset_4v4.modulate = Color(1.2, 1.2, 1.2, 1.0) if selected_bot_count == 7 else Color(0.7, 0.7, 0.7, 0.7)
	if btn_preset_5v5: btn_preset_5v5.modulate = Color(1.2, 1.2, 1.2, 1.0) if selected_bot_count == 9 else Color(0.7, 0.7, 0.7, 0.7)
	if btn_preset_6v6: btn_preset_6v6.modulate = Color(1.2, 1.2, 1.2, 1.0) if selected_bot_count == 11 else Color(0.7, 0.7, 0.7, 0.7)

func _set_difficulty(diff: int) -> void:
	selected_difficulty = diff
	var diff_buttons = [
		btn_diff_recruit,
		btn_diff_novice,
		btn_diff_regular,
		btn_diff_veteran,
		btn_diff_expert
	]
	for i in range(diff_buttons.size()):
		var btn = diff_buttons[i]
		if btn:
			var is_sel = (i == diff)
			if style_diff_active and style_diff_normal:
				btn.add_theme_stylebox_override("normal", style_diff_active if is_sel else style_diff_normal)
			btn.modulate = Color(1.25, 1.25, 1.25, 1.0) if is_sel else Color(0.65, 0.65, 0.65, 0.7)

func _set_online_role(is_host: bool) -> void:
	is_online_host = is_host
	if btn_online_host: btn_online_host.modulate = Color(1.2, 1.2, 1.2, 1.0) if is_host else Color(0.65, 0.65, 0.65, 0.7)
	if btn_online_join: btn_online_join.modulate = Color(1.2, 1.2, 1.2, 1.0) if not is_host else Color(0.65, 0.65, 0.65, 0.7)
	if input_online_ip: input_online_ip.editable = not is_host

# INICIAR COMBATE (DEPLOY)
func _on_deploy_pressed() -> void:
	if panel_class_select:
		panel_class_select.visible = false

	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.set_character_skin(selected_faction, selected_skin_id)
		gm.set_loadout(selected_primary_res, selected_secondary_res, selected_melee_res, selected_class_name)

		# Mapa inicial padrao (o lobby sorteara/votara o mapa)
		var initial_map_scene = "res://scenes/_world/map_nuk3town_bo3.tscn"
		var initial_map_name = "NUKETOWN 2065 (BO3 FUTURISTA)"

		if play_mode_bots:
			var dist_enum = gm.BotDistribution.BALANCED if selected_distribution == 0 else gm.BotDistribution.ALL_ENEMIES
			var diff_enum = gm.BotDifficulty.REGULAR
			match selected_difficulty:
				0: diff_enum = gm.BotDifficulty.RECRUIT
				1: diff_enum = gm.BotDifficulty.NOVICE
				2: diff_enum = gm.BotDifficulty.REGULAR
				3: diff_enum = gm.BotDifficulty.VETERAN
				4: diff_enum = gm.BotDifficulty.EXPERT
			gm.configure_bot_match(initial_map_scene, initial_map_name, selected_bot_count, dist_enum, diff_enum, selected_game_mode)
		else:
			var raw_code_or_ip = input_online_ip.text.strip_edges() if input_online_ip and input_online_ip.text != "" else "127.0.0.1"
			var port_val = 7777
			var is_host = is_online_host

			if not is_host:
				var decoded = RoomCodeHelper.decode_room_code(raw_code_or_ip)
				if decoded.get("valid", false):
					raw_code_or_ip = decoded.get("ip", "127.0.0.1")
					port_val = decoded.get("port", 7777)

			var fill_flag = check_fill_bots.button_pressed if check_fill_bots else false
			gm.configure_online_match(initial_map_scene, initial_map_name, is_host, raw_code_or_ip, port_val, fill_flag, selected_bot_count, selected_game_mode)

		get_tree().change_scene_to_file("res://scenes/ui/lobby_screen.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/lobby_screen.tscn")

func _open_social() -> void:
	if social_modal and social_modal.has_method("toggle"):
		social_modal.toggle()

func _on_paste_code_pressed() -> void:
	var clip = DisplayServer.clipboard_get().strip_edges()
	if not clip.is_empty() and input_online_ip:
		input_online_ip.text = clip
		_set_online_role(false)

func _on_dedicated_server_pressed() -> void:
	_set_online_role(false)
	var nm = get_node_or_null("/root/NetworkManager")
	var s_ip = nm.dedicated_server_ip if nm else "127.0.0.1"
	if input_online_ip:
		input_online_ip.text = s_ip

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_F2 or event.keycode == KEY_O:
			_open_social()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and hero_stage:
		var vp_rect = get_viewport_rect()
		if vp_rect.size.x > 0 and vp_rect.size.y > 0:
			var norm = Vector2(
				(event.position.x / vp_rect.size.x) * 2.0 - 1.0,
				(event.position.y / vp_rect.size.y) * 2.0 - 1.0
			)
			hero_stage.update_mouse_parallax(norm)

# GUNSMITH / LOADOUT MODAL (CREATE-A-CLASS)
var choose_class_screen: Node = null

func _open_gunsmith() -> void:
	if not choose_class_screen:
		var scr = load("res://scripts/ui/choose_class_screen.gd")
		if scr:
			choose_class_screen = scr.new()
			choose_class_screen.class_selected.connect(_on_class_screen_class_selected)
			add_child(choose_class_screen)
			choose_class_screen.visibility_changed.connect(_refresh_hero_rendering)
	if choose_class_screen:
		choose_class_screen.open_screen(false)

func _on_class_screen_class_selected(class_data: Dictionary) -> void:
	if class_data.has("name"):
		selected_class_name = class_data["name"]
	if class_data.has("primary"):
		selected_primary_res = class_data["primary"]
		_sync_primary_dropdown(selected_primary_res)
	if class_data.has("secondary"):
		selected_secondary_res = class_data["secondary"]
	if class_data.has("melee"):
		selected_melee_res = class_data["melee"]
	if class_data.has("faction"):
		selected_faction = class_data["faction"]
	if class_data.has("skin_id"):
		selected_skin_id = class_data["skin_id"]
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.set_weapon_customization(
			class_data.get("camo", "default"),
			class_data.get("optic", "optic_red_dot"),
			class_data.get("muzzle", "none"),
			class_data.get("mag", "none")
		)
		gm.set_equipment_and_perks(
			class_data.get("lethal", "semtex"),
			class_data.get("tactical", "stim"),
			class_data.get("perk1", "flak_jacket"),
			class_data.get("perk2", "tracker"),
			class_data.get("perk3", "high_alert"),
			class_data.get("specialty", "recon")
		)
	_update_class_ui()


func _set_faction(f_id: int) -> void:
	selected_faction = f_id
	if btn_faction_ct:
		btn_faction_ct.modulate = Color(1.2, 1.2, 1.2, 1.0) if f_id == SkinRegistry.Faction.COUNTER_TERRORIST else Color(0.65, 0.65, 0.65, 0.7)
	if btn_faction_t:
		btn_faction_t.modulate = Color(1.2, 1.2, 1.2, 1.0) if f_id == SkinRegistry.Faction.TERRORIST else Color(0.65, 0.65, 0.65, 0.7)

	_refresh_skin_options()
	selected_skin_id = SkinRegistry.get_default_skin_for_class(selected_faction, selected_class_name)
	_sync_skin_dropdown()
	_update_class_ui()

func _refresh_skin_options() -> void:
	if not opt_skin: return
	opt_skin.clear()
	var skins = SkinRegistry.get_skins_by_faction(selected_faction)
	for i in range(skins.size()):
		var s = skins[i]
		opt_skin.add_item(s["name"], i)
		opt_skin.set_item_metadata(i, s["id"])

func _sync_skin_dropdown() -> void:
	if not opt_skin: return
	for i in range(opt_skin.item_count):
		if opt_skin.get_item_metadata(i) == selected_skin_id:
			opt_skin.selected = i
			break

func _on_opt_skin_selected(index: int) -> void:
	var s_id = opt_skin.get_item_metadata(index)
	if s_id:
		selected_skin_id = s_id
	_update_class_ui()

const MENU_WEAPONS: Array[Dictionary] = [
	{"name": "ACR 6.8 (Fuzil de Assalto)", "path": "res://resources/weapons/ak47.tres", "cls": "Assalto"},
	{"name": "M4A1 (Fuzil Tático)", "path": "res://resources/weapons/m4a1.tres", "cls": "Assalto"},
	{"name": "SCAR-H (Fuzil Pesado 7.62)", "path": "res://resources/weapons/scar_h.tres", "cls": "Assalto"},
	{"name": "Man-O-War (Fuzil BO3)", "path": "res://resources/weapons/man_o_war.tres", "cls": "Assalto"},
	{"name": "MP7 (Submetralhadora Ágil)", "path": "res://resources/weapons/mp7.tres", "cls": "CQB"},
	{"name": "PP90M1 (Tambor 64 Tiros)", "path": "res://resources/weapons/pp90m1.tres", "cls": "CQB"},
	{"name": "VMP (Submetralhadora BO3)", "path": "res://resources/weapons/vmp.tres", "cls": "CQB"},
	{"name": "SMG-45 (Submetralhadora Tática)", "path": "res://resources/weapons/smg.tres", "cls": "CQB"},
	{"name": "LMG-63 (Metralhadora de Apoio)", "path": "res://resources/weapons/lmg.tres", "cls": "Suporte"},
	{"name": "SPAS-12 (Escopeta Tática Pump)", "path": "res://resources/weapons/spas12.tres", "cls": "Breacher"},
	{"name": "KRM-262 (Escopeta BO3 Devastadora)", "path": "res://resources/weapons/krm262.tres", "cls": "Breacher"},
	{"name": "Sawnoff Shotgun (Cano Serrado)", "path": "res://resources/weapons/shotgun.tres", "cls": "Breacher"}
]

func _init_primary_options() -> void:
	if not opt_primary: return
	opt_primary.clear()
	for i in range(MENU_WEAPONS.size()):
		opt_primary.add_item(MENU_WEAPONS[i]["name"], i)
		opt_primary.set_item_metadata(i, MENU_WEAPONS[i]["path"])

func _select_preset_class(c_name: String) -> void:
	selected_class_name = c_name
	selected_secondary_res = "res://resources/weapons/pistol.tres"
	selected_melee_res = "res://resources/weapons/knife.tres"
	selected_skin_id = SkinRegistry.get_default_skin_for_class(selected_faction, c_name)
	_sync_skin_dropdown()

	match c_name:
		"Assalto":
			selected_primary_res = "res://resources/weapons/ak47.tres"
			_sync_primary_dropdown("res://resources/weapons/ak47.tres")
		"CQB":
			selected_primary_res = "res://resources/weapons/mp7.tres"
			_sync_primary_dropdown("res://resources/weapons/mp7.tres")
		"Suporte":
			selected_primary_res = "res://resources/weapons/lmg.tres"
			_sync_primary_dropdown("res://resources/weapons/lmg.tres")
		"Breacher":
			selected_primary_res = "res://resources/weapons/spas12.tres"
			_sync_primary_dropdown("res://resources/weapons/spas12.tres")
		"Sniper":
			selected_primary_res = "res://resources/weapons/acr68.tres"
			_sync_primary_dropdown("res://resources/weapons/acr68.tres")
		_:
			var found_weapon = false
			for mw in MENU_WEAPONS:
				if mw.get("cls", "").to_lower() in c_name.to_lower():
					selected_primary_res = mw["path"]
					_sync_primary_dropdown(mw["path"])
					found_weapon = true
					break
			if not found_weapon and not selected_primary_res.is_empty():
				_sync_primary_dropdown(selected_primary_res)

	_update_class_ui()

func _sync_primary_dropdown(path: String) -> void:
	if not opt_primary: return
	for i in range(opt_primary.item_count):
		if opt_primary.get_item_metadata(i) == path:
			opt_primary.selected = i
			break

func _on_opt_primary_selected(index: int) -> void:
	if index >= 0 and index < MENU_WEAPONS.size():
		selected_primary_res = MENU_WEAPONS[index]["path"]
		selected_class_name = "%s Personalizado" % MENU_WEAPONS[index]["cls"]
	_update_class_ui()

func _update_class_ui() -> void:
	if lbl_class_title:
		lbl_class_title.text = "CLASSE: %s" % selected_class_name.to_upper()
	if lbl_primary_info:
		var p_data: WeaponData = load(selected_primary_res) if ResourceLoader.exists(selected_primary_res) else null
		if p_data:
			var gm = get_node_or_null("/root/GameManager")
			var camo_str = "Padrão"
			var optic_str = "Mira Red Dot"
			var muzzle_str = "Cano Padrão"
			if gm and "primary_camo" in gm:
				var c_info = CamoRegistryHelper.get_camo(gm.primary_camo)
				camo_str = c_info["name"]
				if gm.primary_optic == "none": optic_str = "Miras Mecânicas de Ferro"
				elif gm.primary_optic == "optic_holo": optic_str = "Holográfica EOTech"
				elif gm.primary_optic == "optic_sniper": optic_str = "Luneta Tática 4x"
				if gm.primary_muzzle == "muzzle_suppressor": muzzle_str = "Silenciador Tático"
				elif gm.primary_muzzle == "muzzle_compensator": muzzle_str = "Compensador"

			lbl_primary_info.text = "• Arma: %s\n• %s | %s\n• Camuflagem: %s\n• Dano: %d | Cadência: %.0f RPM" % [
				p_data.weapon_name, optic_str, muzzle_str, camo_str, p_data.damage_close, p_data.fire_rate_rpm
			]
		else:
			lbl_primary_info.text = "Arma primaria selecionada."

	if lbl_secondary_info:
		lbl_secondary_info.text = "• Arma: Pistola Tatica C19\n• Miras Mecanicas de Ferro\n• 15 / 60 projeteis"
	if lbl_melee_info:
		lbl_melee_info.text = "• Faca de Combate Tatica\n• Dano: 100 Instakill"
	if lbl_skin_info:
		var s_info = SkinRegistry.get_skin_info(selected_skin_id)
		var fac_str = "Contra-Terroristas (CT)" if selected_faction == SkinRegistry.Faction.COUNTER_TERRORIST else "Terroristas (T)"
		lbl_skin_info.text = "• Operador: %s\n• Faccao: %s" % [
			s_info.get("name", "Operador"),
			fac_str
		]

	if hero_stage and not selected_skin_id.is_empty():
		hero_stage.load_skin(selected_skin_id)

# CONFIGURACOES E SAIDA
func _open_settings() -> void:
	if settings_menu:
		if not settings_menu.visibility_changed.is_connected(_refresh_hero_rendering):
			settings_menu.visibility_changed.connect(_refresh_hero_rendering)
		settings_menu.open_menu()

# ── PERFORMANCE NO NAVEGADOR: palco 3D a 50% e sem o shader de scanline (lê a tela inteira todo frame) ──
func _apply_web_menu_profile() -> void:
	if not OS.has_feature("web"):
		return
	var vp := get_node_or_null("HeroViewportContainer/HeroSubViewport") as SubViewport
	if vp:
		vp.scaling_3d_scale = 0.5
	var scan := get_node_or_null("FxLayer/ScanlineOverlay") as CanvasItem
	if scan:
		scan.visible = false

# ── PERFORMANCE: pausa o palco 3D do operador quando uma tela cheia o cobre ──
func _refresh_hero_rendering() -> void:
	var covered := false
	for n in [choose_class_screen, bo3_weapon_browser, settings_menu]:
		if n and is_instance_valid(n) and n.get("visible") == true:
			covered = true
	var vp := get_node_or_null("HeroViewportContainer/HeroSubViewport") as SubViewport
	if vp:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED if covered else SubViewport.UPDATE_ALWAYS
	if hero_stage:
		hero_stage.process_mode = Node.PROCESS_MODE_DISABLED if covered else Node.PROCESS_MODE_INHERIT

func _on_quit() -> void:
	get_tree().quit()

# ── NAVEGADOR 3D BO3 ──────────────────────────────────────────────────────────
var bo3_weapon_browser: CanvasLayer = null

func _open_bo3_browser() -> void:
	if not bo3_weapon_browser:
		var scr = load("res://scripts/ui/bo3_weapon_select_screen.gd")
		if scr:
			bo3_weapon_browser = scr.new()
			bo3_weapon_browser.weapon_selected.connect(_on_bo3_weapon_selected_main_menu)
			add_child(bo3_weapon_browser)
			bo3_weapon_browser.visibility_changed.connect(_refresh_hero_rendering)
	if bo3_weapon_browser:
		bo3_weapon_browser.open_screen(0, selected_primary_res)

func _on_bo3_weapon_selected_main_menu(w_path: String, _w_data: WeaponData) -> void:
	if w_path and ResourceLoader.exists(w_path):
		selected_primary_res = w_path
		_sync_primary_dropdown(w_path)
		selected_class_name = "Personalizado"
		_update_class_ui()
