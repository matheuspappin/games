# =============================================================================
# web_bridge.gd
# Ponte de Integração Web3 / WebAssembly entre Godot 4 e a Landing Page (React)
# Permite controle bidirecional do jogo pelo navegador (Lobby, Modos, Wagers)
# =============================================================================
extends Node

signal web_event_received(event_name: String, data: Dictionary)

var is_web: bool = false
var js_callback: JavaScriptObject = null

func _ready() -> void:
	is_web = OS.has_feature("web")
	print("[WebBridge] Inicializado. Plataforma Web detectada: %s" % str(is_web))
	
	if is_web:
		_setup_javascript_interface()
	else:
		_parse_desktop_arguments()

func _setup_javascript_interface() -> void:
	if not Engine.has_singleton("JavaScriptBridge"):
		return
		
	var bridge = Engine.get_singleton("JavaScriptBridge")
	js_callback = bridge.create_callback(_on_js_message)
	
	# Expor a função global no objeto window do navegador
	var js_code = """
		window.nukeGameBridge = {
			sendToGodot: null,
			isReady: true,
			dispatch: function(eventName, data) {
				if (this.sendToGodot) {
					this.sendToGodot(eventName, JSON.stringify(data || {}));
				}
			}
		};
	"""
	bridge.eval(js_code)
	
	# Conectar o callback do Godot à janela global
	var window = bridge.get_interface("window")
	if window:
		var nuke_bridge = window.nukeGameBridge
		if nuke_bridge:
			nuke_bridge.sendToGodot = js_callback

	# Notificar a página que o motor Godot WebGL carregou
	notify_web("engine_ready", {
		"status": "ready",
		"version": "Godot 4.7 WebGL",
		"anti_cheat": "active"
	})
	
	_parse_web_url_arguments()

func _parse_web_url_arguments() -> void:
	if not Engine.has_singleton("JavaScriptBridge"):
		return
	var bridge = Engine.get_singleton("JavaScriptBridge")
	var js_eval = """
	(function() {
		try {
			var params = new URLSearchParams(window.location.search);
			var hasAuto = params.get('autostart') === '1' || params.has('mode');
			return JSON.stringify({
				autostart: hasAuto,
				mode: params.get('mode') || '1v1',
				map: params.get('map') || 'nuketown_2065',
				stake: params.get('stake') || '10',
				player: params.get('player') || 'Operador_Alpha'
			});
		} catch(e) {
			return '{}';
		}
	})()
	"""
	var res_str = bridge.eval(js_eval)
	if res_str and typeof(res_str) == TYPE_STRING:
		var json = JSON.new()
		if json.parse(res_str) == OK and json.data is Dictionary:
			var cfg = json.data
			if cfg.get("autostart", false):
				var gm = get_node_or_null("/root/GameManager")
				if gm:
					print("[WebBridge] Auto-iniciando partida via URL da Web: ", cfg)
					call_deferred("_launch_from_args", gm, str(cfg.get("mode", "1v1")), str(cfg.get("map", "nuketown_2065")), float(cfg.get("stake", 10.0)), str(cfg.get("player", "Operador_Alpha")))

func _on_js_message(args: Array) -> void:
	if args.size() < 2:
		return
	var event_name = str(args[0])
	var json_str = str(args[1])
	
	var json = JSON.new()
	var error = json.parse(json_str)
	var data: Dictionary = {}
	if error == OK and json.data is Dictionary:
		data = json.data
		
	print("[WebBridge] Mensagem recebida da Web: %s | Dados: %s" % [event_name, str(data)])
	web_event_received.emit(event_name, data)
	_handle_web_event(event_name, data)

func _handle_web_event(event_name: String, data: Dictionary) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		return
		
	match event_name:
		"start_game":
			var mode_str = data.get("mode", "1v1")
			var map_str = data.get("map", "nuketown_2065")
			var stake = float(data.get("stake", 10.0))
			var player_name = str(data.get("player", "Operador_Alpha"))
			gm.configure_and_launch_game(mode_str, map_str, stake, player_name)
			
		"request_rematch":
			var stake = float(data.get("stake", 20.0))
			gm.restart_match_rematch(stake)

func _parse_desktop_arguments() -> void:
	var args = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	var mode_arg = "1v1"
	var map_arg = "nuketown_2065"
	var stake_arg = 10.0
	var player_arg = "Operador_Desktop"
	
	for a in args:
		if a.begins_with("--mode="):
			mode_arg = a.replace("--mode=", "")
		elif a.begins_with("--map="):
			map_arg = a.replace("--map=", "")
		elif a.begins_with("--stake="):
			stake_arg = float(a.replace("--stake=", ""))
		elif a.begins_with("--player="):
			player_arg = a.replace("--player=", "")
			
	var gm = get_node_or_null("/root/GameManager")
	if gm and ("--auto-launch" in args):
		call_deferred("_launch_from_args", gm, mode_arg, map_arg, stake_arg, player_arg)

func _launch_from_args(gm: Node, mode_arg: String, map_arg: String, stake_arg: float, player_arg: String) -> void:
	gm.configure_and_launch_game(mode_arg, map_arg, stake_arg, player_arg)

func notify_web(event_name: String, data: Dictionary) -> void:
	if not is_web:
		print("[WebBridge Desktop] Evento simulado para Web: %s | %s" % [event_name, str(data)])
		return
		
	if Engine.has_singleton("JavaScriptBridge"):
		var bridge = Engine.get_singleton("JavaScriptBridge")
		var json_str = JSON.stringify(data)
		var js_call = "if (window.onNukeGameEvent) { window.onNukeGameEvent('%s', %s); }" % [event_name, json_str]
		bridge.eval(js_call)
