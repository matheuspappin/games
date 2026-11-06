extends Node
# Teste de rede: servidor dedicado + 2 clientes. "target" só registra a própria vida.
# "shooter" tenta trapacear (manda dano direto) e depois atira de verdade pelo servidor.
var role := "target"
var out := []
var t0 := 0
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="): role = a.trim_prefix("--role=")
	t0 = Time.get_ticks_msec()
	_run.call_deferred()
func _log(s: String) -> void:
	out.append("[%5.1fs] %s" % [(Time.get_ticks_msec() - t0) / 1000.0, s])
	FileAccess.open("res://_prints/net_%s.txt" % role, FileAccess.WRITE).store_string("\n".join(out))
func _players() -> Array:
	return get_tree().get_nodes_in_group("player")
func _run() -> void:
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	var nm = root.get_node("NetworkManager")
	if not ("--client" in OS.get_cmdline_user_args()):
		nm.connect_to_dedicated_server("127.0.0.1", 7778)
	_log("conectando")
	var me = null; var other = null
	for i in 120:
		await get_tree().create_timer(0.5).timeout
		var my_id := multiplayer.get_unique_id()
		me = root.find_child("Player_%d" % my_id, true, false)
		for p in _players():
			if p != me and p.name.begins_with("Player_") and p.name.trim_prefix("Player_").is_valid_int(): other = p
		if me and other: break
	if not me or not other:
		_log("FALHA: jogadores não apareceram (eu=%s outro=%s)" % [str(me), str(other)]); get_tree().quit(); return
	_log("na partida: eu=%s outro=%s" % [me.name, other.name])
	if role == "target":
		for i in 120:
			await get_tree().create_timer(0.5).timeout
			_log("minha vida=%d morto=%s" % [me.health_component.current_health, str(me.is_dead)])
		get_tree().quit(); return
	# shooter
	await get_tree().create_timer(6.0).timeout
	_log("TRAPAÇA: mandando 500 de dano direto no alvo")
	other.rpc("take_damage_rpc", 500, true, Vector3.FORWARD, multiplayer.get_unique_id())
	nm.report_kill(multiplayer.get_unique_id(), int(other.peer_id))
	await get_tree().create_timer(2.0).timeout
	_log("vida do alvo (minha cópia) após trapaça=%d" % other.health_component.current_health)
	# encosta no alvo e atira pelo servidor
	var space = me.get_world_3d().direct_space_state
	var tchest: Vector3 = other.global_position + Vector3.UP * 1.1
	for ang in range(0, 360, 30):
		var cand: Vector3 = other.global_position + Vector3(4, 0, 0).rotated(Vector3.UP, deg_to_rad(ang))
		var q := PhysicsRayQueryParameters3D.create(cand + Vector3.UP * 1.5, tchest, 1, [me.get_rid(), other.get_rid()])
		if space.intersect_ray(q).is_empty():
			me.global_position = cand
			_log("posição livre a %d graus" % ang)
			break
	await get_tree().create_timer(1.5).timeout
	var gmw = root.get_node("GameManager")
	var wpath := str(gmw.primary_weapon_res)
	_log("arma da classe: " + wpath)
	# arma fora da classe: deve ser recusada
	nm.rpc_id(1, "rpc_server_shot", me.HEAD.global_position, (other.global_position + Vector3.UP - me.HEAD.global_position).normalized(), "res://resources/weapons/lmg.tres" if wpath != "res://resources/weapons/lmg.tres" else "res://resources/weapons/rpk.tres", false)
	await get_tree().create_timer(0.3).timeout
	for i in 10:
		var hb = other.get_node_or_null("Hitbox_Chest")
		var tgt: Vector3 = hb.get_child(0).global_position if hb else other.global_position + Vector3.UP * 1.1
		var origin: Vector3 = me.HEAD.global_position
		nm.rpc_id(1, "rpc_server_shot", origin, (tgt - origin).normalized(), wpath, false)
		await get_tree().create_timer(0.25).timeout
	await get_tree().create_timer(1.0).timeout
	_log("vida do alvo após 10 tiros pelo servidor=%d morto=%s" % [other.health_component.current_health, str(other.is_dead)])
	_log("placar alpha=%d bravo=%d" % [nm.score_alpha, nm.score_bravo])
	# trapaça 2: cliente tenta mandar kill direto para o servidor (não é mais RPC)
	nm.rpc_id(1, "report_kill", multiplayer.get_unique_id(), int(other.peer_id))
	await get_tree().create_timer(1.0).timeout
	_log("placar após tentar mandar kill falso=%d x %d" % [nm.score_alpha, nm.score_bravo])
	await get_tree().create_timer(3.0).timeout
	get_tree().quit()
