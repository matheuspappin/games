# =============================================================================
# audio_manager.gd
# Autoload Singleton — Gerencia todos os sons, barramentos de áudio e Playlist
# Estilo Call of Duty: suporte a músicas personalizadas, crossfade e persistência
# =============================================================================
extends Node

signal music_changed(track_name: String)
signal track_changed(track_data: Dictionary)
signal playlist_updated(playlist: Array[Dictionary])
signal volume_changed(bus_name: String, linear_value: float)
signal playback_state_changed(is_playing: bool, is_paused: bool)

# Barramentos de áudio configurados
const BUS_MASTER = "Master"
const BUS_SFX    = "SFX"
const BUS_MUSIC  = "Music"
const BUS_UI     = "UI"
const BUS_VOICE  = "Voice"

# Pastas de músicas
const DIR_PROJECT_MUSIC = "res://audio/music/"
const DIR_USER_MUSIC    = "user://music/"

# Pool de AudioStreamPlayers para SFX
const SFX_POOL_SIZE = 16
var _sfx_pool   : Array[AudioStreamPlayer] = []
var _sfx_index  : int = 0

# Players de música com crossfade duplo
var _music_player_a : AudioStreamPlayer
var _music_player_b : AudioStreamPlayer
var _active_music_player : int = 0
var _current_tween : Tween

# Configurações de volume (0.0 a 1.0)
var master_volume : float = 1.0 : set = _set_master_vol
var sfx_volume    : float = 1.0 : set = _set_sfx_vol
var music_volume  : float = 0.7 : set = _set_music_vol
var voice_volume  : float = 1.0 : set = _set_voice_vol

# Estado da Playlist
var playlist: Array[Dictionary] = []
var current_track_index: int = -1
var is_playing: bool = false
var is_paused: bool = false
var is_shuffle: bool = false

# Toast / Notificação de música na tela estilo Call of Duty
var _toast_layer: CanvasLayer
var _toast_panel: PanelContainer
var _toast_tag: Label
var _toast_title: Label
var _toast_artist: Label
var _toast_hotkeys: Label
var _toast_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	_build_sfx_pool()
	_build_music_players()
	_build_toast_ui()
	_ensure_user_music_directory()
	load_saved_settings()
	scan_playlist()

func _ensure_audio_buses() -> void:
	var required_buses = [BUS_SFX, BUS_MUSIC, BUS_UI, BUS_VOICE]
	for b_name in required_buses:
		var idx = AudioServer.get_bus_index(b_name)
		if idx == -1:
			var new_idx = AudioServer.bus_count
			AudioServer.add_bus(new_idx)
			AudioServer.set_bus_name(new_idx, b_name)
			AudioServer.set_bus_send(new_idx, BUS_MASTER)

func _build_sfx_pool() -> void:
	for i in SFX_POOL_SIZE:
		var p = AudioStreamPlayer.new()
		p.bus = BUS_SFX
		p.name = "SFX_%02d" % i
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_sfx_pool.append(p)

func _build_music_players() -> void:
	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.bus = BUS_MUSIC
	_music_player_a.name = "MusicA"
	_music_player_a.process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player_a.finished.connect(_on_music_finished)
	add_child(_music_player_a)

	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.bus = BUS_MUSIC
	_music_player_b.name = "MusicB"
	_music_player_b.process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player_b.finished.connect(_on_music_finished)
	add_child(_music_player_b)

func _ensure_user_music_directory() -> void:
	var global_user_dir = ProjectSettings.globalize_path(DIR_USER_MUSIC)
	DirAccess.make_dir_recursive_absolute(global_user_dir)

# ── SISTEMA DE PLAYLIST & SCANNER ─────────────────────────────────────────────

func scan_playlist() -> void:
	playlist.clear()
	var seen_paths = {}

	# 1. Escanear pasta do projeto (res://audio/music/)
	_scan_directory(DIR_PROJECT_MUSIC, seen_paths)

	# 2. Escanear pasta do usuário (user://music/)
	_scan_directory(DIR_USER_MUSIC, seen_paths)

	# Se a playlist estiver vazia e tivermos o arquivo padrão Killing In The Name, adiciona diretamente
	var default_path = "res://audio/music/killing_in_the_name.mp3"
	if not seen_paths.has(default_path) and FileAccess.file_exists(default_path):
		var info = _create_track_info(default_path, "killing_in_the_name.mp3")
		playlist.insert(0, info)
		seen_paths[default_path] = true

	# Colocar a música tema no topo da lista se ela existir
	for i in range(playlist.size()):
		if "killing_in_the_name" in playlist[i]["filename"].to_lower():
			if i != 0:
				var theme_item = playlist.pop_at(i)
				playlist.insert(0, theme_item)
			break

	playlist_updated.emit(playlist)
	print("[AudioManager] Playlist escaneada com sucesso. Músicas encontradas: %d" % playlist.size())

func _scan_directory(dir_path: String, seen: Dictionary) -> void:
	var dir = DirAccess.open(dir_path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and not file_name.ends_with(".import") and not file_name.ends_with(".uid"):
			var ext = file_name.get_extension().to_lower()
			if ext in ["mp3", "ogg", "wav"]:
				var full_path = dir_path.path_join(file_name)
				if not seen.has(full_path):
					seen[full_path] = true
					playlist.append(_create_track_info(full_path, file_name))
		file_name = dir.get_next()
	dir.list_dir_end()

func _create_track_info(full_path: String, file_name: String) -> Dictionary:
	var base_name = file_name.get_basename()
	var artist = "Desconhecido"
	var title = base_name

	if "killing_in_the_name" in base_name.to_lower():
		artist = "Rage Against The Machine"
		title = "Killing In The Name"
	elif " - " in base_name:
		var parts = base_name.split(" - ", false, 2)
		artist = parts[0].strip_edges()
		title = parts[1].strip_edges()
	else:
		title = base_name.replace("_", " ").capitalize()

	return {
		"path": full_path,
		"filename": file_name,
		"artist": artist,
		"title": title,
		"display": "%s - %s" % [artist, title] if artist != "Desconhecido" else title
	}

func play_intro_theme() -> void:
	# Toca Killing in the Name ao entrar no game
	if is_playing and current_track_index >= 0 and current_track_index < playlist.size():
		if "killing_in_the_name" in playlist[current_track_index]["filename"].to_lower():
			return # Já está tocando a música tema

	var theme_idx = -1
	for i in range(playlist.size()):
		if "killing_in_the_name" in playlist[i]["filename"].to_lower():
			theme_idx = i
			break

	if theme_idx != -1:
		play_track(theme_idx)
	elif not playlist.is_empty():
		play_track(0)

func play_track(index: int, crossfade_time: float = 1.0) -> void:
	if playlist.is_empty():
		scan_playlist()
		if playlist.is_empty():
			push_warning("[AudioManager] Nenhuma música na playlist para tocar.")
			return

	if index < 0 or index >= playlist.size():
		index = 0

	current_track_index = index
	var track = playlist[index]
	var stream = load_audio_file(track["path"])
	if not stream:
		push_error("[AudioManager] Falha ao carregar áudio de: " + track["path"])
		return

	# Crossfade suave entre os dois players
	var next_player = _music_player_a if _active_music_player == 1 else _music_player_b
	var curr_player = _music_player_b if _active_music_player == 1 else _music_player_a

	next_player.stream = stream
	next_player.volume_db = linear_to_db(0.0001)
	next_player.play()

	if _current_tween:
		_current_tween.kill()
	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	var target_db = linear_to_db(music_volume) if music_volume > 0.001 else -80.0
	_current_tween.tween_property(next_player, "volume_db", target_db, crossfade_time)
	_current_tween.tween_property(curr_player, "volume_db", -80.0, crossfade_time)
	_current_tween.tween_callback(curr_player.stop).set_delay(crossfade_time)

	_active_music_player = 1 - _active_music_player
	is_playing = true
	is_paused = false

	music_changed.emit(track["display"])
	track_changed.emit(track)
	playback_state_changed.emit(is_playing, is_paused)
	show_now_playing_toast(track)

func next_track() -> void:
	if playlist.is_empty(): return
	var next_idx = 0
	if is_shuffle:
		if playlist.size() > 1:
			var rand_idx = randi() % playlist.size()
			while rand_idx == current_track_index:
				rand_idx = randi() % playlist.size()
			next_idx = rand_idx
		else:
			next_idx = 0
	else:
		next_idx = (current_track_index + 1) % playlist.size()
	play_track(next_idx)

func previous_track() -> void:
	if playlist.is_empty(): return
	var prev_idx = current_track_index - 1
	if prev_idx < 0:
		prev_idx = playlist.size() - 1
	play_track(prev_idx)

func toggle_pause() -> void:
	if not is_playing:
		if current_track_index >= 0:
			play_track(current_track_index)
		else:
			play_intro_theme()
		return

	var active_player = _music_player_a if _active_music_player == 0 else _music_player_b
	if is_paused:
		active_player.stream_paused = false
		is_paused = false
		playback_state_changed.emit(is_playing, is_paused)
		if current_track_index >= 0 and current_track_index < playlist.size():
			show_now_playing_toast(playlist[current_track_index], "▶ TRILHA SONORA • REPRODUZINDO")
	else:
		active_player.stream_paused = true
		is_paused = true
		playback_state_changed.emit(is_playing, is_paused)
		if current_track_index >= 0 and current_track_index < playlist.size():
			show_now_playing_toast(playlist[current_track_index], "⏸ TRILHA SONORA • PAUSADA")

func pause_music() -> void:
	if is_playing and not is_paused:
		toggle_pause()

func resume_music() -> void:
	if is_playing and is_paused:
		toggle_pause()

func stop_music(fade_time: float = 0.8) -> void:
	if _current_tween:
		_current_tween.kill()
	_current_tween = create_tween()
	_current_tween.tween_property(_music_player_a, "volume_db", -80.0, fade_time)
	_current_tween.tween_property(_music_player_b, "volume_db", -80.0, fade_time)
	_current_tween.tween_callback(func():
		_music_player_a.stop()
		_music_player_b.stop()
		is_playing = false
		is_paused = false
		playback_state_changed.emit(is_playing, is_paused)
	).set_delay(fade_time)

func set_shuffle(enabled: bool) -> void:
	is_shuffle = enabled

func get_current_track() -> Dictionary:
	if current_track_index >= 0 and current_track_index < playlist.size():
		return playlist[current_track_index]
	return {}

func _on_music_finished() -> void:
	if is_playing and not is_paused:
		next_track()

func open_music_folder() -> void:
	_ensure_user_music_directory()
	var global_path = ProjectSettings.globalize_path(DIR_USER_MUSIC)
	OS.shell_open(global_path)

# Carregador dinâmico de arquivos de áudio (MP3, OGG, WAV)
func load_audio_file(path: String) -> AudioStream:
	if not FileAccess.file_exists(path):
		return null

	var ext = path.get_extension().to_lower()
	if ext == "mp3":
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var stream = AudioStreamMP3.new()
			stream.data = file.get_buffer(file.get_length())
			return stream
	elif ext == "ogg":
		if ResourceLoader.exists(path):
			return load(path)
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			return AudioStreamOggVorbis.load_from_buffer(file.get_buffer(file.get_length()))
	elif ext == "wav":
		if ResourceLoader.exists(path):
			return load(path)
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var stream = AudioStreamWAV.new()
			stream.data = file.get_buffer(file.get_length())
			return stream

	if ResourceLoader.exists(path):
		return load(path)
	return null

# ── CONTROLE DE VOLUME & SALVAMENTO ──────────────────────────────────────────

func set_volume(bus_name: String, linear_val: float) -> void:
	linear_val = clampf(linear_val, 0.0, 1.0)
	match bus_name:
		BUS_MASTER:
			master_volume = linear_val
		BUS_SFX:
			sfx_volume = linear_val
		BUS_MUSIC:
			music_volume = linear_val
		BUS_VOICE:
			voice_volume = linear_val

	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		if linear_val <= 0.001:
			AudioServer.set_bus_mute(bus_idx, true)
			AudioServer.set_bus_volume_db(bus_idx, -80.0)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_val))

	volume_changed.emit(bus_name, linear_val)

func get_volume(bus_name: String) -> float:
	match bus_name:
		BUS_MASTER: return master_volume
		BUS_SFX:    return sfx_volume
		BUS_MUSIC:  return music_volume
		BUS_VOICE:  return voice_volume
		_: return 1.0

func _set_master_vol(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	var idx = AudioServer.get_bus_index(BUS_MASTER)
	if idx != -1:
		AudioServer.set_bus_mute(idx, master_volume <= 0.001)
		AudioServer.set_bus_volume_db(idx, linear_to_db(master_volume) if master_volume > 0.001 else -80.0)

func _set_sfx_vol(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	var idx = AudioServer.get_bus_index(BUS_SFX)
	if idx != -1:
		AudioServer.set_bus_mute(idx, sfx_volume <= 0.001)
		AudioServer.set_bus_volume_db(idx, linear_to_db(sfx_volume) if sfx_volume > 0.001 else -80.0)

func _set_music_vol(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	var idx = AudioServer.get_bus_index(BUS_MUSIC)
	if idx != -1:
		AudioServer.set_bus_mute(idx, music_volume <= 0.001)
		AudioServer.set_bus_volume_db(idx, linear_to_db(music_volume) if music_volume > 0.001 else -80.0)

func _set_voice_vol(v: float) -> void:
	voice_volume = clampf(v, 0.0, 1.0)
	var idx = AudioServer.get_bus_index(BUS_VOICE)
	if idx != -1:
		AudioServer.set_bus_mute(idx, voice_volume <= 0.001)
		AudioServer.set_bus_volume_db(idx, linear_to_db(voice_volume) if voice_volume > 0.001 else -80.0)

func load_saved_settings() -> void:
	if ClassDB.class_exists("SaveSystem") or ResourceLoader.exists("res://scripts/systems/save_system.gd"):
		var ss = load("res://scripts/systems/save_system.gd")
		if ss and ss.has_method("load_player_data"):
			var p_data = ss.load_player_data()
			var s = p_data.get("settings", {})
			set_volume(BUS_MASTER, s.get("volume_master", 1.0))
			set_volume(BUS_SFX,    s.get("volume_sfx", 1.0))
			set_volume(BUS_MUSIC,  s.get("volume_music", 0.7))
			return

	set_volume(BUS_MASTER, master_volume)
	set_volume(BUS_SFX, sfx_volume)
	set_volume(BUS_MUSIC, music_volume)

func save_settings() -> void:
	if ResourceLoader.exists("res://scripts/systems/save_system.gd"):
		var ss = load("res://scripts/systems/save_system.gd")
		if ss and ss.has_method("load_player_data") and ss.has_method("save_player_data"):
			var p_data = ss.load_player_data()
			if not p_data.has("settings"):
				p_data["settings"] = {}
			p_data["settings"]["volume_master"] = master_volume
			p_data["settings"]["volume_sfx"]    = sfx_volume
			p_data["settings"]["volume_music"]  = music_volume
			ss.save_player_data(p_data)

func load_settings(data: Dictionary) -> void:
	set_volume(BUS_MASTER, data.get("master_volume", 1.0))
	set_volume(BUS_SFX,    data.get("sfx_volume", 1.0))
	set_volume(BUS_MUSIC,  data.get("music_volume", 0.7))
	set_volume(BUS_VOICE,  data.get("voice_volume", 1.0))

# ── PLAY SFX ─────────────────────────────────────────────────────────────────

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if stream == null:
		return
	var player = _sfx_pool[_sfx_index % SFX_POOL_SIZE]
	_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch + randf_range(-0.03, 0.03)
	player.play()

func play_sfx_3d_at(stream: AudioStream, world_pos: Vector3, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var p = AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = BUS_SFX
	p.volume_db = volume_db
	p.max_distance = 80.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	get_tree().current_scene.add_child(p)
	p.global_position = world_pos
	p.play()
	p.finished.connect(p.queue_free)

# ── NOTIFICAÇÃO TOAST NA TELA ("NOW PLAYING") ─────────────────────────────────

func _build_toast_ui() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 120
	add_child(_toast_layer)

	_toast_panel = PanelContainer.new()
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.11, 0.95)
	style.border_color = Color(1.0, 0.75, 0.2, 1.0)
	style.border_width_left = 5
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(4)
	style.content_margin_left = 16
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_toast_panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 14)
	_toast_panel.add_child(hbox)

	# Ícone / Badge de Áudio
	var icon_box = PanelContainer.new()
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.custom_minimum_size = Vector2(40, 40)
	var icon_style = StyleBoxFlat.new()
	icon_style.bg_color = Color(0.12, 0.16, 0.22, 0.95)
	icon_style.border_color = Color(1.0, 0.75, 0.2, 0.8)
	icon_style.set_border_width_all(1)
	icon_style.set_corner_radius_all(4)
	icon_box.add_theme_stylebox_override("panel", icon_style)
	var icon_lbl = Label.new()
	icon_lbl.text = "📻"
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(icon_lbl)
	hbox.add_child(icon_box)

	# VBox de textos informativos
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	# Tag de cabeçalho
	_toast_tag = Label.new()
	_toast_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_tag.text = "TRILHA SONORA • REPRODUZINDO AGORA"
	_toast_tag.add_theme_color_override("font_color", Color(1.0, 0.78, 0.25, 1.0))
	_toast_tag.add_theme_font_size_override("font_size", 10)
	vbox.add_child(_toast_tag)

	# Título da Música
	_toast_title = Label.new()
	_toast_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_toast_title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_toast_title)

	# Artista
	_toast_artist = Label.new()
	_toast_artist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_artist.add_theme_color_override("font_color", Color(0.65, 0.75, 0.9, 0.9))
	_toast_artist.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_toast_artist)

	# Rodapé de atalhos em jogo
	_toast_hotkeys = Label.new()
	_toast_hotkeys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_hotkeys.text = "Atalhos: F3 (Anterior) | F4 (Play/Pausa) | F5 (Próxima)"
	_toast_hotkeys.add_theme_color_override("font_color", Color(0.45, 0.5, 0.6, 0.8))
	_toast_hotkeys.add_theme_font_size_override("font_size", 9)
	vbox.add_child(_toast_hotkeys)

	_toast_layer.add_child(_toast_panel)

func show_now_playing_toast(track: Dictionary, status_tag: String = "TRILHA SONORA • REPRODUZINDO AGORA") -> void:
	if not _toast_panel or not _toast_title or not _toast_artist: return

	var s_title = track.get("title", "Música")
	var s_artist = track.get("artist", "Desconhecido")

	_toast_tag.text = status_tag
	_toast_title.text = "🎵 %s" % s_title
	_toast_artist.text = "👤 Artista: %s" % s_artist

	var vp_size = get_viewport().get_visible_rect().size
	_toast_panel.reset_size()

	var target_x = (vp_size.x - _toast_panel.size.x) * 0.5
	var target_y = 24.0
	var start_y = -70.0

	_toast_panel.position = Vector2(target_x, start_y)
	_toast_panel.visible = true
	_toast_panel.modulate = Color(1, 1, 1, 0)

	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast_panel, "position:y", target_y, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.3)

	_toast_tween.chain().tween_interval(4.2)

	_toast_tween.chain().set_parallel(true)
	_toast_tween.tween_property(_toast_panel, "position:y", start_y, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.3)
	_toast_tween.chain().tween_callback(func(): _toast_panel.visible = false)

# ── ATALHOS DE TECLADO IN-GAME ────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_F3:
			previous_track()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F4:
			toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F5:
			next_track()
			get_viewport().set_input_as_handled()
