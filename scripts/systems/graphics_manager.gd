# =============================================================================
# graphics_manager.gd
# Gerenciador Global de Configurações Gráficas, Resolução, Vídeo e Desempenho
# Permite controle total de qualidade (Alto, Médio, Baixo/iGPU, Ultra e Custom)
# =============================================================================
extends Node

signal settings_changed

const CONFIG_PATH = "user://graphics_settings.cfg"

# Configurações Atuais com Padrão Otimizado para Alta Fidelidade e Alto FPS (FSR 1.0)
var settings: Dictionary = {
	"window_mode": 1,           # 0: Janela, 1: Tela Cheia, 2: Tela Cheia Exclusiva
	"resolution_idx": 0,        # 0: 1920x1080, 1: 1600x900, 2: 1366x768, 3: 1280x720, 4: 960x540
	"vsync_mode": 0,            # 0: Desativado, 1: Ativado, 2: Adaptativo
	"max_fps": 120,             # 120 FPS estável por padrão (elimina oscilações e microstutters)
	"resolution_scale": 0.88,   # FSR FidelityFX Super Resolution a 88% (~1080p nítido com +30% FPS)
	"quality_preset": 2,        # 0: Baixo, 1: Médio, 2: Alto (Recomendado), 3: Ultra, 4: Personalizado
	"shadow_quality": 2,        # 0: Desativado, 1: Baixo, 2: Médio, 3: Alto
	"aa_mode": 2,               # 0: Desativado, 1: FXAA, 2: TAA, 3: MSAA 2X
	"ssao": true,
	"ssil": false,
	"ssr": true,
	"glow": true,
	"volumetric_fog": false
}

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1366, 768),
	Vector2i(1280, 720),
	Vector2i(960, 540)
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_all_settings()
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is WorldEnvironment or node is DirectionalLight3D:
		call_deferred("apply_environment_settings")

func load_settings() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(CONFIG_PATH)
	if err == OK:
		for key in settings.keys():
			if cfg.has_section_key("graphics", key):
				settings[key] = cfg.get_value("graphics", key, settings[key])
	else:
		# Primeira execução: detecta tela cheia ou resolução nativa
		var screen_res = DisplayServer.screen_get_size()
		if screen_res.x <= 1280:
			settings["resolution_idx"] = 3
		elif screen_res.x <= 1600:
			settings["resolution_idx"] = 1
		else:
			settings["resolution_idx"] = 0
		save_settings()

func save_settings() -> void:
	var cfg = ConfigFile.new()
	for key in settings.keys():
		cfg.set_value("graphics", key, settings[key])
	cfg.save(CONFIG_PATH)

func set_preset(preset_idx: int) -> void:
	settings["quality_preset"] = preset_idx
	match preset_idx:
		0: # BAIXO (iGPU 60+ FPS Competitivo - AMD Vega / Intel Iris)
			settings["resolution_scale"] = 0.80
			settings["shadow_quality"] = 1
			settings["aa_mode"] = 1 # FXAA
			settings["ssao"] = false
			settings["ssil"] = false
			settings["ssr"] = false
			settings["glow"] = true
			settings["volumetric_fog"] = false
		1: # MÉDIO (Equilibrado FSR 85%)
			settings["resolution_scale"] = 0.85
			settings["shadow_quality"] = 2
			settings["aa_mode"] = 1
			settings["ssao"] = false
			settings["ssil"] = false
			settings["ssr"] = false
			settings["glow"] = true
			settings["volumetric_fog"] = false
		2: # ALTO (Alta Fidelidade FSR 88% + TAA + SSAO)
			settings["resolution_scale"] = 0.88
			settings["shadow_quality"] = 2
			settings["aa_mode"] = 2 # TAA
			settings["ssao"] = true
			settings["ssil"] = false
			settings["ssr"] = true
			settings["glow"] = true
			settings["volumetric_fog"] = false
		3: # ULTRA
			settings["resolution_scale"] = 1.0
			settings["shadow_quality"] = 3
			settings["aa_mode"] = 2
			settings["ssao"] = true
			settings["ssil"] = true
			settings["ssr"] = true
			settings["glow"] = true
			settings["volumetric_fog"] = true
	apply_all_settings()
	save_settings()

func apply_all_settings() -> void:
	apply_display_settings()
	apply_viewport_settings()
	apply_environment_settings()
	settings_changed.emit()

func apply_display_settings() -> void:
	# 1. Modo de Janela
	match settings["window_mode"]:
		0: # Janela
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1: # Tela Cheia (Borderless)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2: # Tela Cheia Exclusiva
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

	# 2. Resolução da Janela (apenas em modo janela)
	if settings["window_mode"] == 0:
		var target_res = RESOLUTIONS[clampi(settings["resolution_idx"], 0, RESOLUTIONS.size() - 1)]
		DisplayServer.window_set_size(target_res)
		var screen_size = DisplayServer.screen_get_size()
		var center_pos = (screen_size - target_res) / 2
		center_pos.x = maxi(0, center_pos.x)
		center_pos.y = maxi(30, center_pos.y)
		DisplayServer.window_set_position(center_pos)

	# 3. VSync
	match settings["vsync_mode"]:
		0: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		1: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		2: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)

	# 4. Limite de FPS
	Engine.max_fps = settings["max_fps"]

func apply_viewport_settings() -> void:
	var vp = get_viewport()
	if not vp:
		return

	# Não tentar configurar FSR ou compute scaling se o viewport tiver tamanho zero ou nulo
	var vp_size = vp.get_visible_rect().size
	if vp_size.x < 16 or vp_size.y < 16:
		return

	# Escala de Renderização 3D (FSR 1.0 se < 1.0 e suportado pelo backend)
	vp.scaling_3d_scale = clampf(settings["resolution_scale"], 0.5, 1.0)
	var has_rd = RenderingServer.get_rendering_device() != null
	if settings["resolution_scale"] < 1.0 and has_rd:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		vp.fsr_sharpness = 0.2
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR

	# Anti-Aliasing
	match settings["aa_mode"]:
		0: # Desativado
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.use_taa = false
			vp.msaa_3d = Viewport.MSAA_DISABLED
		1: # FXAA (Super leve)
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.use_taa = false
			vp.msaa_3d = Viewport.MSAA_DISABLED
		2: # TAA (Suave)
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.use_taa = true
			vp.msaa_3d = Viewport.MSAA_DISABLED
		3: # MSAA 2X (GPU dedicada)
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.use_taa = false
			vp.msaa_3d = Viewport.MSAA_2X

func apply_environment_settings() -> void:
	var root = get_tree().current_scene
	if not root:
		return

	# Configurar Environment
	var env_node = root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if env_node and env_node.environment:
		var env = env_node.environment
		env.ssao_enabled = settings["ssao"]
		env.ssil_enabled = settings["ssil"]
		env.ssr_enabled = settings["ssr"]
		env.glow_enabled = settings["glow"]
		env.volumetric_fog_enabled = settings["volumetric_fog"]
		if env.volumetric_fog_enabled:
			env.volumetric_fog_temporal_reprojection_amount = 0.9

	# Configurar Sombras
	var dir_lights = root.find_children("*", "DirectionalLight3D", true, false)
	for light in dir_lights:
		var dl = light as DirectionalLight3D
		if dl:
			match settings["shadow_quality"]:
				0: # Desativado
					dl.shadow_enabled = false
				1: # Baixo (PCF leve 1024)
					dl.shadow_enabled = true
					dl.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
					dl.directional_shadow_max_distance = 50.0
				2: # Médio (2 splits PSSM)
					dl.shadow_enabled = true
					dl.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
					dl.directional_shadow_max_distance = 65.0
				3: # Alto (4 splits PSSM)
					dl.shadow_enabled = true
					dl.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
					dl.directional_shadow_max_distance = 80.0
