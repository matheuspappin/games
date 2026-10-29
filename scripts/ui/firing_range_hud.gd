# =============================================================================
# firing_range_hud.gd
# HUD de Telemetria do Estande de Tiro — Estilo Call of Duty (MWII / MWIII / BO6)
# Exibe:
# - Cartão de Telemetria Balística (Dano do tiro, STK, TTK em ms, Dano Acumulado)
# - Seletor Rápido de Placas de Armadura (0, 1, 2, 3 Placas)
# - Barra de Atalhos Táticos: [TAB] Gunsmith, [R] Reset, [F] Munição, [ESC] Menu
# - Precisão em tempo real (% de acerto de projéteis)
# =============================================================================
class_name FiringRangeHUD
extends CanvasLayer

signal armor_plates_changed(count: int)
signal reset_targets_requested
signal refill_ammo_requested
signal open_gunsmith_requested
signal exit_firing_range_requested

# UI Elements
var telemetry_panel          : PanelContainer
var lbl_telemetry_title      : Label
var lbl_active_target        : Label
var lbl_last_hit             : Label
var lbl_stk                  : Label
var lbl_ttk                  : Label
var lbl_accuracy             : Label
var lbl_total_damage         : Label

var plate_buttons            : Array[Button] = []
var selected_plate_index     : int = 0

# Telemetria Global de Disparos
var total_shots_fired        : int = 0
var total_shots_hit          : int = 0

func _ready() -> void:
	layer = 15
	_build_hud()
	_update_plate_buttons_visual(0)

func _build_hud() -> void:
	# ── 1. CARTÃO SUPERIOR DIREITO: TELEMETRIA BALÍSTICA ───────────────────────
	telemetry_panel = PanelContainer.new()
	telemetry_panel.name = "TelemetryCard"
	telemetry_panel.anchor_left = 0.70
	telemetry_panel.anchor_right = 0.98
	telemetry_panel.anchor_top = 0.04
	telemetry_panel.anchor_bottom = 0.28
	telemetry_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel_st = StyleBoxFlat.new()
	panel_st.bg_color = Color(0.04, 0.07, 0.12, 0.88)
	panel_st.border_color = Color(0.92, 0.72, 0.15, 0.95) # Dourado CoD
	panel_st.set_border_width_all(2)
	panel_st.set_corner_radius_all(6)
	panel_st.content_margin_left = 14
	panel_st.content_margin_right = 14
	panel_st.content_margin_top = 10
	panel_st.content_margin_bottom = 10
	telemetry_panel.add_theme_stylebox_override("panel", panel_st)
	add_child(telemetry_panel)

	var t_vbox = VBoxContainer.new()
	t_vbox.add_theme_constant_override("separation", 3)
	t_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	telemetry_panel.add_child(t_vbox)

	lbl_telemetry_title = Label.new()
	lbl_telemetry_title.text = "🎯 ESTANDE DE TIRO // TELEMETRIA TÁTICA"
	lbl_telemetry_title.add_theme_font_size_override("font_size", 12)
	lbl_telemetry_title.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2, 1.0))
	t_vbox.add_child(lbl_telemetry_title)

	var div = HSeparator.new()
	var div_st = StyleBoxLine.new()
	div_st.color = Color(0.3, 0.45, 0.65, 0.5)
	div.add_theme_stylebox_override("separator", div_st)
	t_vbox.add_child(div)

	lbl_active_target = Label.new()
	lbl_active_target.text = "ALVO: NENHUM ACERTO RECENTE"
	lbl_active_target.add_theme_font_size_override("font_size", 13)
	lbl_active_target.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 0.9))
	t_vbox.add_child(lbl_active_target)

	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 14)
	stats_grid.add_theme_constant_override("v_separation", 3)
	stats_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t_vbox.add_child(stats_grid)

	lbl_last_hit = Label.new()
	lbl_last_hit.text = "ÚLTIMO TIRO: --"
	lbl_last_hit.add_theme_font_size_override("font_size", 12)
	lbl_last_hit.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0, 0.95))
	stats_grid.add_child(lbl_last_hit)

	lbl_total_damage = Label.new()
	lbl_total_damage.text = "DANO ACUMULADO: 0 HP"
	lbl_total_damage.add_theme_font_size_override("font_size", 12)
	lbl_total_damage.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 0.95))
	stats_grid.add_child(lbl_total_damage)

	lbl_stk = Label.new()
	lbl_stk.text = "DISPAROS (STK): --"
	lbl_stk.add_theme_font_size_override("font_size", 12)
	lbl_stk.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 0.85))
	stats_grid.add_child(lbl_stk)

	lbl_ttk = Label.new()
	lbl_ttk.text = "TTK (TEMPO PARA ABATER): --"
	lbl_ttk.add_theme_font_size_override("font_size", 12)
	lbl_ttk.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35, 0.95))
	stats_grid.add_child(lbl_ttk)

	lbl_accuracy = Label.new()
	lbl_accuracy.text = "PRECISÃO: 100.0% (0/0)"
	lbl_accuracy.add_theme_font_size_override("font_size", 11)
	lbl_accuracy.add_theme_color_override("font_color", Color(0.7, 0.85, 0.75, 0.85))
	t_vbox.add_child(lbl_accuracy)

	# ── 2. BARRA INFERIOR CENTRAL: SELETOR DE PLACAS DE BLINDAGEM ──────────────
	var plate_container = HBoxContainer.new()
	plate_container.name = "ArmorPlateBar"
	plate_container.anchor_left = 0.30
	plate_container.anchor_right = 0.70
	plate_container.anchor_top = 0.92
	plate_container.anchor_bottom = 0.97
	plate_container.alignment = BoxContainer.ALIGNMENT_CENTER
	plate_container.add_theme_constant_override("separation", 10)
	add_child(plate_container)

	var plate_configs = [
		{"name": "[1] SEM COLETE (100 HP)", "plates": 0},
		{"name": "[2] 1 PLACA (150 HP)", "plates": 1},
		{"name": "[3] 2 PLACAS (200 HP)", "plates": 2},
		{"name": "[4] 3 PLACAS (250 HP)", "plates": 3}
	]

	for i in range(plate_configs.size()):
		var cfg = plate_configs[i]
		var btn = Button.new()
		btn.text = cfg["name"]
		btn.custom_minimum_size = Vector2(130, 32)
		btn.add_theme_font_size_override("font_size", 11)
		var p_idx = cfg["plates"]
		btn.pressed.connect(func(): _on_plate_button_clicked(p_idx))
		plate_buttons.append(btn)
		plate_container.add_child(btn)

	# ── 3. BARRA LATERAL ESQUERDA: ATALHOS RÁPIDOS (HUD GUIA) ──────────────────
	var shortcuts_panel = PanelContainer.new()
	shortcuts_panel.name = "ShortcutsPanel"
	shortcuts_panel.anchor_left = 0.02
	shortcuts_panel.anchor_right = 0.28
	shortcuts_panel.anchor_top = 0.25
	shortcuts_panel.anchor_bottom = 0.41
	shortcuts_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sc_st = StyleBoxFlat.new()
	sc_st.bg_color = Color(0.04, 0.06, 0.10, 0.78)
	sc_st.border_color = Color(0.25, 0.4, 0.6, 0.45)
	sc_st.set_border_width_all(1)
	sc_st.set_corner_radius_all(6)
	sc_st.content_margin_left = 12
	sc_st.content_margin_right = 12
	sc_st.content_margin_top = 8
	sc_st.content_margin_bottom = 8
	shortcuts_panel.add_theme_stylebox_override("panel", sc_st)
	add_child(shortcuts_panel)

	var sc_vbox = VBoxContainer.new()
	sc_vbox.add_theme_constant_override("separation", 2)
	sc_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shortcuts_panel.add_child(sc_vbox)

	var lbl_sc_title = Label.new()
	lbl_sc_title.text = "⚡ CONTROLES DO ESTANDE (ESTILO COD)"
	lbl_sc_title.add_theme_font_size_override("font_size", 11)
	lbl_sc_title.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0, 0.95))
	sc_vbox.add_child(lbl_sc_title)

	var lbl_sc_1 = Label.new()
	lbl_sc_1.text = "• [TAB / ESC] ABRIR GUNSMITH / TROCAR ACESSÓRIOS"
	lbl_sc_1.add_theme_font_size_override("font_size", 10)
	lbl_sc_1.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 0.8))
	sc_vbox.add_child(lbl_sc_1)

	var lbl_sc_2 = Label.new()
	lbl_sc_2.text = "• [1, 2, 3, 4] ALTERNAR PLACAS DE COLETE NO DUMMY"
	lbl_sc_2.add_theme_font_size_override("font_size", 10)
	lbl_sc_2.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 0.8))
	sc_vbox.add_child(lbl_sc_2)

	var lbl_sc_3 = Label.new()
	lbl_sc_3.text = "• [R] RESETAR ALVOS  |  [F] RECARREGAR PENTE IMEDIATO"
	lbl_sc_3.add_theme_font_size_override("font_size", 10)
	lbl_sc_3.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 0.8))
	sc_vbox.add_child(lbl_sc_3)

	var lbl_sc_4 = Label.new()
	lbl_sc_4.text = "• [BACKSPACE] SAIR DO ESTANDE (MENU PRINCIPAL)"
	lbl_sc_4.add_theme_font_size_override("font_size", 10)
	lbl_sc_4.add_theme_color_override("font_color", Color(1.0, 0.65, 0.35, 0.9))
	sc_vbox.add_child(lbl_sc_4)

# ── CONTROLE DE PLACAS ────────────────────────────────────────────────────────
func _on_plate_button_clicked(idx: int) -> void:
	selected_plate_index = idx
	_update_plate_buttons_visual(idx)
	armor_plates_changed.emit(idx)

func _update_plate_buttons_visual(active_idx: int) -> void:
	for i in range(plate_buttons.size()):
		var btn = plate_buttons[i]
		var is_active = (i == active_idx)
		var st = StyleBoxFlat.new()
		if is_active:
			st.bg_color = Color(0.12, 0.22, 0.38, 0.95)
			st.border_color = Color(0.3, 0.8, 1.0, 1.0)
			st.set_border_width_all(2)
			btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		else:
			st.bg_color = Color(0.06, 0.09, 0.14, 0.8)
			st.border_color = Color(0.2, 0.3, 0.45, 0.4)
			st.set_border_width_all(1)
			btn.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85, 0.75))
		st.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", st)
		btn.add_theme_stylebox_override("hover", st)

func cycle_armor_plates(idx: int) -> void:
	if idx >= 0 and idx < plate_buttons.size():
		_on_plate_button_clicked(idx)

# ── ATUALIZAÇÃO DE TELEMETRIA POR EVENTOS ──────────────────────────────────────
func record_shot_fired() -> void:
	total_shots_fired += 1
	_update_accuracy()

func record_target_hit(t_name: String, hit_zone: String, damage: int, is_crit: bool, remaining_hp: int, max_hp: int, distance: float) -> void:
	total_shots_hit += 1
	_update_accuracy()

	if lbl_active_target:
		lbl_active_target.text = "ALVO: %s (%.0fm) — HP: %d / %d" % [t_name.to_upper(), distance, remaining_hp, max_hp]

	if lbl_last_hit:
		var zone_str = "HEADSHOT [CRIT!]" if is_crit else ("TRONCO" if hit_zone == "Chest" else "MEMBROS")
		lbl_last_hit.text = "ÚLTIMO TIRO: %d HP (%s)" % [damage, zone_str]
		lbl_last_hit.modulate = Color(1.0, 0.2, 0.2, 1.0) if is_crit else Color(0.35, 0.85, 1.0, 1.0)
		var t = create_tween()
		t.tween_property(lbl_last_hit, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.35)

func record_target_killed(t_name: String, distance: float, shots: int, ttk_ms: float, total_dmg: int) -> void:
	if lbl_active_target:
		lbl_active_target.text = "ALVO: %s (%.0fm) — ★ ELIMINADO!" % [t_name.to_upper(), distance]

	if lbl_stk:
		lbl_stk.text = "DISPAROS (STK): %d TIROS" % shots
		lbl_stk.modulate = Color(1.0, 0.9, 0.2, 1.0)

	if lbl_ttk:
		lbl_ttk.text = "TTK: %.0f ms" % ttk_ms
		lbl_ttk.modulate = Color(1.0, 0.3, 0.3, 1.0)

	if lbl_total_damage:
		lbl_total_damage.text = "DANO ACUMULADO: %d HP" % total_dmg

func _update_accuracy() -> void:
	if not lbl_accuracy:
		return
	var pct = 100.0 if total_shots_fired == 0 else (float(total_shots_hit) / float(total_shots_fired)) * 100.0
	lbl_accuracy.text = "PRECISÃO: %.1f%% (%d/%d)" % [pct, total_shots_hit, total_shots_fired]
