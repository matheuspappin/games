# =============================================================================
# loading_screen.gd
# Tela de Carregamento Assincrono com Feedback Visual e Dicas Taticas
# Call of Duty / Tactical Warfare Experience - Godot 4 Forward+
# Usa ResourceLoader.load_threaded_request nativo do Godot 4 com barra de progresso suave
# =============================================================================
class_name LoadingScreen
extends Control

@export_group("UI References")
@export var lbl_title: Label
@export var lbl_subtitle: Label
@export var lbl_operator_info: Label
@export var lbl_weapon_info: Label
@export var lbl_status: Label
@export var lbl_percent: Label
@export var progress_bar: ProgressBar
@export var lbl_tip: Label
@export var tip_timer: Timer
@export var bg_texture: TextureRect

var target_scene_path: String = "res://scenes/_world/map_nuk3town_bo3.tscn"
var target_scene_name: String = "NUKETOWN 2065 (BO3 FUTURISTA)"

var display_progress: float = 0.0
var is_loading_finished: bool = false
var transition_cooldown: float = 0.35
var current_tip_index: int = 0
var load_requested: bool = false
var cached_scene: PackedScene = null

const TACTICAL_TIPS: Array[String] = [
	"💡 DICA TÁTICA: Disparos na cabeça e no tronco superior causam dano crítico substancial.",
	"💡 DICA TÁTICA: Trocar para a arma secundária ou faca de combate aumenta sua velocidade de corrida.",
	"💡 DICA TÁTICA: As janelas do 2º andar das casas oferecem linhas de visão superiores sobre o pátio central.",
	"💡 DICA TÁTICA: O áudio posicional 3D permite rastrear os passos dos inimigos no chão e nas escadas.",
	"💡 DICA TÁTICA: Mantenha sua mira na altura da cabeça dos inimigos ao contornar esquinas (Crosshair Placement).",
	"💡 DICA TÁTICA: Recarregue sempre sob cobertura para não ser pego desprevenido em campo aberto.",
	"💡 DICA TÁTICA: Use o recuo inicial do fuzil para acertar os primeiros 3 a 5 tiros com precisão cirúrgica."
]

func _ready() -> void:
	_init_game_manager_info()
	_update_ui_headers()
	_update_tip_text()
	
	if tip_timer:
		tip_timer.timeout.connect(_on_tip_timer_timeout)
		tip_timer.start(3.0)

	# Atualizar fundo com arte do mapa selecionado
	if bg_texture:
		var is_bo3 = target_scene_path.contains("bo3") or target_scene_path.contains("2065")
		var tex_path = "res://web/public/assets/nuketown_2065.jpg" if is_bo3 else "res://web/public/assets/nuketown_bo1.jpg"
		if ResourceLoader.exists(tex_path):
			bg_texture.texture = load(tex_path)

	# Checar se a cena já está no cache global do GameManager
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.has_method("has_cached_scene") and gm.has_cached_scene(target_scene_path):
			cached_scene = gm.get_cached_scene(target_scene_path)
			print("[LoadingScreen] Cenário encontrado em cache de memória! Deploy ágil.")
			return

	# Navegador: o BO3 vem num pacote separado (maps_bo3.pck), baixado só quando o mapa é escolhido
	if OS.has_feature("web") and target_scene_path.contains("bo3"):
		_waiting_pack = true
		var ok := await _ensure_web_pack("maps_bo3.pck")
		_waiting_pack = false
		if not ok:
			push_error("[LoadingScreen] Falha ao baixar o pacote do mapa BO3.")

	# Iniciar carregamento via ResourceLoader thread-safe
	var err = ResourceLoader.load_threaded_request(target_scene_path)
	if err == OK:
		load_requested = true
		print("[LoadingScreen] Carregamento thread-safe iniciado para: ", target_scene_path)
	else:
		push_warning("[LoadingScreen] Erro ao iniciar load_threaded_request: %d" % err)

func _init_game_manager_info() -> void:
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.target_map_path != "":
			target_scene_path = gm.target_map_path
		if gm.target_map_display_name != "":
			target_scene_name = gm.target_map_display_name

func _update_ui_headers() -> void:
	if lbl_title:
		lbl_title.text = target_scene_name.to_upper()
	if lbl_subtitle:
		lbl_subtitle.text = "DEPLOY OPERACIONAL EM ANDAMENTO // CALL OF DUTY TACTICAL WARFARE"
	
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		var fac_str = "🛡️ CONTRA-TERRORISTAS (CT)" if gm.selected_faction == 1 else "💣 TERRORISTAS (T)"
		var skin_str = gm.selected_skin_id.to_upper().replace("_", " ")
		if lbl_operator_info:
			lbl_operator_info.text = "OPERADOR: %s [%s]  |  CLASSE: %s" % [skin_str, fac_str, gm.selected_class_name.to_upper()]
		if lbl_weapon_info:
			var w_name = gm.primary_weapon_res.get_file().get_basename().to_upper()
			lbl_weapon_info.text = "CARGA BÉLICA: %s  |  SECUNDÁRIA: PISTOLA C19  |  CORPO A CORPO: FACA" % w_name

# ── PACOTES DE MAPA NO NAVEGADOR ───────────────────────────────────────────────
var _pack_downloading := false
var _pack_progress := 0.0
var _waiting_pack := false
static var _loaded_packs := {}

func _ensure_web_pack(file_name: String) -> bool:
	if _loaded_packs.has(file_name):
		return true
	var dst := "/tmp/" + file_name
	if FileAccess.file_exists(dst) and ProjectSettings.load_resource_pack(dst):
		_loaded_packs[file_name] = true
		return true
	# Download feito pelo próprio navegador (fetch): chega em pedaços, informa o progresso
	# e é copiado para o disco virtual do Godot com engine.copyToFS. O HTTPRequest guardava
	# tudo na memória, não mostrava progresso e falhava sem dizer o motivo.
	var js := """
	window.__packDL = {state: 'baixando', loaded: 0, total: 0, err: ''};
	(async () => {
		try {
			const url = location.href.replace(/[^/]*$/, '') + '%s';
			const r = await fetch(url);
			if (!r.ok) throw new Error('HTTP ' + r.status);
			const total = +r.headers.get('Content-Length') || 0;
			window.__packDL.total = total;
			const reader = r.body.getReader();
			let data = total ? new Uint8Array(total) : null;
			const chunks = [];
			let off = 0;
			while (true) {
				const {done, value} = await reader.read();
				if (done) break;
				if (data) { data.set(value, off); } else { chunks.push(value); }
				off += value.length;
				window.__packDL.loaded = off;
			}
			if (!data) { data = new Uint8Array(off); let o = 0; for (const c of chunks) { data.set(c, o); o += c.length; } }
			engine.copyToFS('%s', data.buffer);
			window.__packDL.state = 'ok';
		} catch (e) {
			window.__packDL.state = 'erro';
			window.__packDL.err = String(e);
		}
	})();
	""" % [file_name, dst]
	JavaScriptBridge.eval(js, true)
	_pack_downloading = true
	while is_inside_tree():
		await get_tree().process_frame
		var st = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.__packDL)", true)))
		if typeof(st) != TYPE_DICTIONARY:
			continue
		if float(st.get("total", 0)) > 0:
			_pack_progress = float(st.get("loaded", 0)) / float(st.get("total", 1))
		if st.get("state") == "ok":
			break
		if st.get("state") == "erro":
			push_error("[LoadingScreen] Download do mapa falhou: %s" % st.get("err", ""))
			_pack_downloading = false
			return false
	_pack_downloading = false
	if ProjectSettings.load_resource_pack(dst):
		_loaded_packs[file_name] = true
		return true
	push_error("[LoadingScreen] Pacote baixado, mas não abriu: " + dst)
	return false

func _process(delta: float) -> void:
	var is_loaded: bool = false
	var real_progress: float = 0.0
	if _pack_downloading:
		real_progress = 0.5 * _pack_progress
	if _waiting_pack:
		display_progress = move_toward(display_progress, real_progress, delta)
		_update_progress_display()
		if lbl_status:
			lbl_status.text = "Baixando o mapa... %d%%" % int(_pack_progress * 100.0)
		return

	if cached_scene != null:
		is_loaded = true
		real_progress = 1.0
	elif load_requested:
		var p_arr: Array = []
		var status = ResourceLoader.load_threaded_get_status(target_scene_path, p_arr)
		if p_arr.size() > 0:
			real_progress = p_arr[0]
		
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			is_loaded = true
			real_progress = 1.0
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("[LoadingScreen] Falha no carregamento assíncrono! Tentando fallback direto...")
			is_loaded = true
			real_progress = 1.0
	else:
		is_loaded = true
		real_progress = 1.0

	# Suavizar o avanço visual da barra de progresso
	var target_display = real_progress if is_loaded else maxf(real_progress, minf(0.95, display_progress + delta * 0.15))
	var lerp_speed = 3.5 if is_loaded else 1.2
	display_progress = move_toward(display_progress, target_display, delta * lerp_speed)

	_update_progress_display()

	if is_loaded and display_progress >= 0.999:
		if not is_loading_finished:
			is_loading_finished = true
			if lbl_status:
				lbl_status.text = "✔ CENÁRIO CARREGADO COM SUCESSO! DEPLOY IMINENTE..."
			if lbl_percent:
				lbl_percent.text = "100%"
			if progress_bar:
				progress_bar.value = 100.0

		transition_cooldown -= delta
		if transition_cooldown <= 0.0:
			set_process(false)
			_finish_load_and_deploy()

func _update_progress_display() -> void:
	var percent_val = int(display_progress * 100.0)
	if progress_bar:
		progress_bar.value = percent_val
	if lbl_percent:
		lbl_percent.text = "%d%%" % percent_val
		
	if lbl_status and not is_loading_finished:
		if percent_val < 25:
			lbl_status.text = "Carregando modelos 3D e malhas de alta definição..."
		elif percent_val < 50:
			lbl_status.text = "Compilando texturas PBR, materiais e iluminação Vulkan..."
		elif percent_val < 75:
			lbl_status.text = "Configurando geometria física, colisões e rotas de bots IA..."
		elif percent_val < 95:
			lbl_status.text = "Instanciando operadores de combate e armamentos táticos..."
		else:
			lbl_status.text = "Finalizando inicialização do combate..."

func _finish_load_and_deploy() -> void:
	print("[LoadingScreen] Realizando transição para cena: ", target_scene_path)
	
	var scn: PackedScene = cached_scene
	if scn == null and load_requested:
		scn = ResourceLoader.load_threaded_get(target_scene_path) as PackedScene
	
	if scn == null:
		scn = load(target_scene_path) as PackedScene
	
	var nm = get_node_or_null("/root/NetworkManager")
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm and gm.has_method("cache_scene") and scn:
			gm.cache_scene(target_scene_path, scn)

	if scn:
		get_tree().change_scene_to_packed(scn)
	else:
		get_tree().change_scene_to_file(target_scene_path)

	if nm and nm.has_method("on_map_scene_ready"):
		nm.call_deferred("on_map_scene_ready")

func _on_tip_timer_timeout() -> void:
	current_tip_index = (current_tip_index + 1) % TACTICAL_TIPS.size()
	_update_tip_text()

func _update_tip_text() -> void:
	if lbl_tip:
		lbl_tip.text = TACTICAL_TIPS[current_tip_index]
