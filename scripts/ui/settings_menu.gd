# =============================================================================
# settings_menu.gd
# Painel Completo de Configurações Gráficas, Resolução, Áudio e Playlist de Músicas
# Estilo Call of Duty MW3 / Black Ops — Permite controle total do jogo e áudio
# =============================================================================
class_name SettingsMenu
extends Control

signal closed

# Gráficos e Tela
@onready var opt_window_mode: OptionButton = find_child("OptWindowMode", true, false)
@onready var opt_resolution: OptionButton  = find_child("OptResolution", true, false)
@onready var opt_vsync: OptionButton       = find_child("OptVsync", true, false)
@onready var opt_fps: OptionButton         = find_child("OptFPS", true, false)
@onready var slider_scale: HSlider         = find_child("SliderScale", true, false)
@onready var lbl_scale_val: Label          = find_child("LblScaleVal", true, false)
@onready var opt_preset: OptionButton      = find_child("OptPreset", true, false)
@onready var opt_shadow: OptionButton      = find_child("OptShadow", true, false)
@onready var opt_aa: OptionButton          = find_child("OptAA", true, false)

@onready var chk_ssao: CheckButton         = find_child("ChkSSAO", true, false)
@onready var chk_ssr: CheckButton          = find_child("ChkSSR", true, false)
@onready var chk_ssil: CheckButton         = find_child("ChkSSIL", true, false)
@onready var chk_glow: CheckButton         = find_child("ChkGlow", true, false)
@onready var chk_fog: CheckButton          = find_child("ChkFog", true, false)

# Controles de Áudio e Volumes
@onready var slider_master: HSlider        = find_child("SliderMaster", true, false)
@onready var lbl_master_val: Label         = find_child("LblMasterVal", true, false)
@onready var slider_sfx: HSlider           = find_child("SliderSFX", true, false)
@onready var lbl_sfx_val: Label            = find_child("LblSFXVal", true, false)
@onready var slider_music: HSlider         = find_child("SliderMusic", true, false)
@onready var lbl_music_val: Label          = find_child("LblMusicVal", true, false)

# Controles de Playlist
@onready var lbl_now_playing: Label        = find_child("LblNowPlaying", true, false)
@onready var btn_music_prev: Button        = find_child("BtnMusicPrev", true, false)
@onready var btn_music_play: Button        = find_child("BtnMusicPlay", true, false)
@onready var btn_music_next: Button        = find_child("BtnMusicNext", true, false)
@onready var btn_music_shuffle: Button     = find_child("BtnMusicShuffle", true, false)
@onready var list_music_tracks: ItemList   = find_child("ListMusicTracks", true, false)
@onready var btn_open_music_folder: Button = find_child("BtnOpenMusicFolder", true, false)
@onready var btn_refresh_playlist: Button  = find_child("BtnRefreshPlaylist", true, false)

# Botões de Ação
@onready var btn_apply: Button             = find_child("BtnApply", true, false)
@onready var btn_close: Button             = find_child("BtnClose", true, false)
@onready var tab_container: TabContainer   = find_child("TabContainer", true, false)

var _is_updating_ui: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_populate_dropdowns()
	_sync_ui_from_settings()
	_connect_signals()
	_hook_audio_manager()

func _populate_dropdowns() -> void:
	if opt_window_mode:
		opt_window_mode.clear()
		opt_window_mode.add_item("Janela", 0)
		opt_window_mode.add_item("Tela Cheia (Sem Bordas)", 1)
		opt_window_mode.add_item("Tela Cheia Exclusiva", 2)

	if opt_resolution:
		opt_resolution.clear()
		opt_resolution.add_item("1920 x 1080 (1080p FHD)", 0)
		opt_resolution.add_item("1600 x 900 (900p HD+)", 1)
		opt_resolution.add_item("1366 x 768 (Notebook HD)", 2)
		opt_resolution.add_item("1280 x 720 (720p HD - iGPU)", 3)
		opt_resolution.add_item("960 x 540 (qHD Desempenho)", 4)

	if opt_vsync:
		opt_vsync.clear()
		opt_vsync.add_item("Desativado (Menor Latência)", 0)
		opt_vsync.add_item("Ativado (60Hz Suave)", 1)
		opt_vsync.add_item("Adaptativo", 2)

	if opt_fps:
		opt_fps.clear()
		opt_fps.add_item("Ilimitado", 0)
		opt_fps.add_item("60 FPS", 60)
		opt_fps.add_item("120 FPS", 120)
		opt_fps.add_item("144 FPS", 144)

	if opt_preset:
		opt_preset.clear()
		opt_preset.add_item("Baixo (Otimizado 60+ FPS iGPU)", 0)
		opt_preset.add_item("Médio (Equilibrado)", 1)
		opt_preset.add_item("Alto (Qualidade Visual)", 2)
		opt_preset.add_item("Ultra (Máximo)", 3)
		opt_preset.add_item("Personalizado", 4)

	if opt_shadow:
		opt_shadow.clear()
		opt_shadow.add_item("Desativado", 0)
		opt_shadow.add_item("Baixo (PCF Rápido)", 1)
		opt_shadow.add_item("Médio (PSSM 2-Splits)", 2)
		opt_shadow.add_item("Alto (PSSM 4-Splits)", 3)

	if opt_aa:
		opt_aa.clear()
		opt_aa.add_item("Desativado", 0)
		opt_aa.add_item("FXAA (Rápido / Leve)", 1)
		opt_aa.add_item("TAA (Temporal Suave)", 2)
		opt_aa.add_item("MSAA 2X (GPU Dedicada)", 3)

func _connect_signals() -> void:
	if btn_apply: btn_apply.pressed.connect(_on_apply_pressed)
	if btn_close: btn_close.pressed.connect(_on_close_pressed)

	if opt_preset:
		opt_preset.item_selected.connect(_on_preset_selected)

	if slider_scale:
		slider_scale.value_changed.connect(_on_scale_slider_changed)

	# Sliders de Volume
	if slider_master:
		slider_master.value_changed.connect(func(v): _on_volume_slider_changed("Master", v))
	if slider_sfx:
		slider_sfx.value_changed.connect(func(v): _on_volume_slider_changed("SFX", v))
	if slider_music:
		slider_music.value_changed.connect(func(v): _on_volume_slider_changed("Music", v))

	# Controles de Playlist
	if btn_music_prev:
		btn_music_prev.pressed.connect(_on_music_prev_pressed)
	if btn_music_play:
		btn_music_play.pressed.connect(_on_music_play_pressed)
	if btn_music_next:
		btn_music_next.pressed.connect(_on_music_next_pressed)
	if btn_music_shuffle:
		btn_music_shuffle.pressed.connect(_on_music_shuffle_pressed)
	if btn_open_music_folder:
		btn_open_music_folder.pressed.connect(_on_open_music_folder_pressed)
	if btn_refresh_playlist:
		btn_refresh_playlist.pressed.connect(_on_refresh_playlist_pressed)
	if list_music_tracks:
		list_music_tracks.item_activated.connect(_on_track_item_activated)

func _hook_audio_manager() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if not am: return

	if not am.track_changed.is_connected(_on_am_track_changed):
		am.track_changed.connect(_on_am_track_changed)
	if not am.playback_state_changed.is_connected(_on_am_playback_state_changed):
		am.playback_state_changed.connect(_on_am_playback_state_changed)
	if not am.playlist_updated.is_connected(_on_am_playlist_updated):
		am.playlist_updated.connect(_on_am_playlist_updated)

func _get_gm() -> Node:
	if has_node("/root/GraphicsManager"):
		return get_node("/root/GraphicsManager")
	return null

func _sync_ui_from_settings() -> void:
	_is_updating_ui = true

	# Sincronizar Gráficos
	var gm = _get_gm()
	if gm:
		var s: Dictionary = gm.get("settings") if "settings" in gm else {}
		if opt_window_mode: opt_window_mode.select(s.get("window_mode", 0))
		if opt_resolution:  opt_resolution.select(s.get("resolution_idx", 0))
		if opt_vsync:       opt_vsync.select(s.get("vsync_mode", 0))

		if opt_fps:
			var target_fps = s.get("max_fps", 0)
			for i in range(opt_fps.item_count):
				if opt_fps.get_item_id(i) == target_fps:
					opt_fps.select(i)
					break

		if slider_scale:
			slider_scale.value = s.get("resolution_scale", 1.0) * 100.0
			if lbl_scale_val:
				lbl_scale_val.text = "%d%%" % int(slider_scale.value)

		if opt_preset: opt_preset.select(s.get("quality_preset", 0))
		if opt_shadow: opt_shadow.select(s.get("shadow_quality", 1))
		if opt_aa:     opt_aa.select(s.get("aa_mode", 1))

		if chk_ssao: chk_ssao.button_pressed = s.get("ssao", false)
		if chk_ssr:  chk_ssr.button_pressed  = s.get("ssr", false)
		if chk_ssil: chk_ssil.button_pressed = s.get("ssil", false)
		if chk_glow: chk_glow.button_pressed = s.get("glow", true)
		if chk_fog:  chk_fog.button_pressed  = s.get("volumetric_fog", false)

	# Sincronizar Áudio & Sliders
	var am = get_node_or_null("/root/AudioManager")
	if am:
		if slider_master:
			slider_master.value = am.master_volume * 100.0
			if lbl_master_val: lbl_master_val.text = "%d%%" % int(slider_master.value)
		if slider_sfx:
			slider_sfx.value = am.sfx_volume * 100.0
			if lbl_sfx_val: lbl_sfx_val.text = "%d%%" % int(slider_sfx.value)
		if slider_music:
			slider_music.value = am.music_volume * 100.0
			if lbl_music_val: lbl_music_val.text = "%d%%" % int(slider_music.value)

		_refresh_playlist_ui()

	_is_updating_ui = false

func _refresh_playlist_ui() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if not am: return

	# Atualizar Nome da Faixa Atual
	var cur = am.get_current_track()
	if lbl_now_playing:
		if cur.is_empty():
			lbl_now_playing.text = "🎵 TOCANDO: Nenhuma música selecionada"
		else:
			lbl_now_playing.text = "🎵 TOCANDO: %s" % cur.get("display", cur.get("title", "Música"))

	# Atualizar Botão Play/Pause
	if btn_music_play:
		if am.is_playing and not am.is_paused:
			btn_music_play.text = "⏸ PAUSAR"
		else:
			btn_music_play.text = "▶ TOCAR"

	# Atualizar Botão Shuffle
	if btn_music_shuffle:
		btn_music_shuffle.text = "🔀 ALEATÓRIO: SIM" if am.is_shuffle else "🔀 ALEATÓRIO: NÃO"
		btn_music_shuffle.modulate = Color(1.2, 1.2, 0.8, 1.0) if am.is_shuffle else Color(1, 1, 1, 1)

	# Atualizar Lista de Faixas
	if list_music_tracks:
		list_music_tracks.clear()
		for i in range(am.playlist.size()):
			var t = am.playlist[i]
			var is_cur = (i == am.current_track_index)
			var prefix = "▶ " if (is_cur and am.is_playing and not am.is_paused) else "   "
			var item_text = "%s%d. %s" % [prefix, i + 1, t.get("display", t.get("title", ""))]
			list_music_tracks.add_item(item_text)
			if is_cur:
				list_music_tracks.select(i)

func _on_volume_slider_changed(bus_name: String, val: float) -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("set_volume"):
		am.set_volume(bus_name, val / 100.0)

	match bus_name:
		"Master":
			if lbl_master_val: lbl_master_val.text = "%d%%" % int(val)
		"SFX":
			if lbl_sfx_val: lbl_sfx_val.text = "%d%%" % int(val)
		"Music":
			if lbl_music_val: lbl_music_val.text = "%d%%" % int(val)

func _on_music_prev_pressed() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.previous_track()

func _on_music_play_pressed() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.toggle_pause()

func _on_music_next_pressed() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.next_track()

func _on_music_shuffle_pressed() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.set_shuffle(not am.is_shuffle)
		_refresh_playlist_ui()

func _on_open_music_folder_pressed() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.open_music_folder()

func _on_refresh_playlist_pressed() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.scan_playlist()
		_refresh_playlist_ui()

func _on_track_item_activated(index: int) -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_track(index)

func _on_am_track_changed(_track_info: Dictionary) -> void:
	_refresh_playlist_ui()

func _on_am_playback_state_changed(_is_playing: bool, _is_paused: bool) -> void:
	_refresh_playlist_ui()

func _on_am_playlist_updated(_pl: Array) -> void:
	_refresh_playlist_ui()

func _on_preset_selected(idx: int) -> void:
	if _is_updating_ui: return
	var gm = _get_gm()
	if idx < 4 and gm and gm.has_method("set_preset"):
		gm.set_preset(idx)
		_sync_ui_from_settings()

func _on_scale_slider_changed(val: float) -> void:
	if lbl_scale_val:
		lbl_scale_val.text = "%d%%" % int(val)
	if not _is_updating_ui and opt_preset:
		opt_preset.select(4) # Custom

func _on_apply_pressed() -> void:
	var gm = _get_gm()
	if gm:
		var s: Dictionary = gm.get("settings") if "settings" in gm else {}
		if opt_window_mode: s["window_mode"] = opt_window_mode.get_selected_id()
		if opt_resolution:  s["resolution_idx"] = opt_resolution.get_selected_id()
		if opt_vsync:       s["vsync_mode"] = opt_vsync.get_selected_id()
		if opt_fps:         s["max_fps"] = opt_fps.get_selected_id()
		if slider_scale:    s["resolution_scale"] = slider_scale.value / 100.0
		if opt_preset:      s["quality_preset"] = opt_preset.get_selected_id()
		if opt_shadow:      s["shadow_quality"] = opt_shadow.get_selected_id()
		if opt_aa:          s["aa_mode"] = opt_aa.get_selected_id()

		if chk_ssao: s["ssao"] = chk_ssao.button_pressed
		if chk_ssr:  s["ssr"]  = chk_ssr.button_pressed
		if chk_ssil: s["ssil"] = chk_ssil.button_pressed
		if chk_glow: s["glow"] = chk_glow.button_pressed
		if chk_fog:  s["volumetric_fog"] = chk_fog.button_pressed

		if gm.has_method("apply_all_settings"):
			gm.apply_all_settings()
		if gm.has_method("save_settings"):
			gm.save_settings()

	# Salvar Volumes de Áudio
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("save_settings"):
		am.save_settings()

func _on_close_pressed() -> void:
	visible = false
	closed.emit()

func open_menu() -> void:
	_sync_ui_from_settings()
	visible = true
