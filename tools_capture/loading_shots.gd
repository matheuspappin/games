extends Node
# Prints para a tela de entrada web: vistas aéreas (drone) do Nuketown 2065, closes dos bots e um grupo.
# Saída: _prints/loading/*.png (1920x1080). Uso: loading_shots.bat
const MAP := "res://scenes/_world/map_nuk3town_bo3.tscn"
const OUT := "res://_prints/loading"
var map: Node
var cam: Camera3D
var n_shot := 0

func _ready() -> void:
	if get_tree().current_scene == self:
		var r = Node.new(); r.set_script(get_script()); r.name = "LoadingShots"
		get_tree().root.add_child.call_deferred(r)
		return
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_window().size = Vector2i(1920, 1080)
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.bot_count = 8
	get_tree().change_scene_to_file(MAP)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(14.0).timeout # bots espalham pelo mapa
	map = get_tree().current_scene
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		c.visible = false
	for p in get_tree().get_nodes_in_group("player"):
		p.visible = false
		p.process_mode = Node.PROCESS_MODE_DISABLED
	for l in get_tree().root.find_children("*", "Label3D", true, false):
		l.visible = false # sem nomes [ALIADO]/[INIMIGO] nos prints
	var bots: Array = get_tree().get_nodes_in_group("enemies")
	for b in bots:
		b.process_mode = Node.PROCESS_MODE_DISABLED # congela a pose atual
	# visual de cinema (só nos prints)
	var we = map.find_child("WorldEnvironment", true, false)
	if we and we.environment:
		var env: Environment = we.environment.duplicate()
		env.tonemap_exposure = 0.68
		env.adjustment_enabled = true
		env.adjustment_contrast = 1.12
		env.adjustment_saturation = 1.18
		env.glow_intensity = 0.35
		we.environment = env
	cam = Camera3D.new()
	cam.far = 800.0
	map.add_child(cam)
	cam.make_current()

	# centro e raio do mapa a partir dos spawns
	var pts: Array = []
	for n in map.find_children("Spawn_*", "Node3D", true, false):
		pts.append(n.global_position)
	var c := Vector3.ZERO
	for p in pts: c += p
	c /= max(1, pts.size())
	var r := 10.0
	for p in pts: r = max(r, Vector3(p.x - c.x, 0, p.z - c.z).length())
	var log := "centro=%s raio=%.1f bots=%d\n" % [c, r, bots.size()]

	# drone: 6 ângulos em volta + 1 alto
	cam.fov = 50.0
	for i in 6:
		var a := TAU * i / 6.0 + 0.4
		var pos := c + Vector3(cos(a), 0, sin(a)) * r * 1.35 + Vector3.UP * r * 0.75
		await _shot("drone_%d" % i, pos, c + Vector3.UP * 1.0)
	await _shot("drone_alto", c + Vector3(0.01, r * 2.2, r * 0.9), c)

	# esquadrão montado: bots posicionados num ponto aberto, de frente para a câmera e com o sol atrás dela
	var space := cam.get_world_3d().direct_space_state
	# acha um ponto aberto: céu livre em cima e o maior corredor livre para a câmera
	var melhor := -1.0
	var spot := c
	var aproximar := Vector3.FORWARD
	var cands: Array = []
	for sp in pts:
		for gx in range(-2, 3):
			for gz in range(-2, 3):
				cands.append(sp + Vector3(gx, 0, gz) * 2.5)
	for gx in range(-4, 5):
		for gz in range(-4, 5):
			cands.append(c + Vector3(gx, 0, gz) * 2.5)
	for cand in cands:
		if true:
			var p0 := _chao(space, cand)
			if absf(p0.y - cand.y) > 1.5: continue
			var o := p0 + Vector3.UP * 1.2
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + Vector3.UP * 25.0)).is_empty(): continue
			var minimo := 99.0
			var maior := 0.0
			var dir_maior := Vector3.FORWARD
			for k in 8:
				var d := Vector3(cos(TAU * k / 8.0), 0, sin(TAU * k / 8.0))
				var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + d * 20.0))
				var dist := 20.0 if h.is_empty() else o.distance_to(h.position)
				minimo = minf(minimo, dist)
				if dist > maior: maior = dist; dir_maior = d
			var nota: float = minf(minimo, 6.0) + minf(maior, 14.0)
			if nota > melhor: melhor = nota; spot = p0; aproximar = dir_maior
	log += "spot=%s nota=%.1f\n" % [spot, melhor]
	# luz de estúdio acompanhando a câmera (só nos prints)
	var key := SpotLight3D.new()
	key.light_energy = 3.0; key.spot_range = 25.0; key.spot_angle = 35.0; key.light_color = Color(1.0, 0.93, 0.85)
	cam.add_child(key)
	key.position = Vector3(0.8, 0.6, 0)
	var lado := aproximar.cross(Vector3.UP).normalized()
	var formacao := [Vector3.ZERO, lado * 1.4 - aproximar * 1.2, -lado * 1.4 - aproximar * 1.2, lado * 2.6 - aproximar * 2.6, -lado * 2.6 - aproximar * 2.6]
	var squad: Array = []
	for i in min(bots.size(), formacao.size()):
		var b = bots[i]
		b.global_position = _chao(space, spot + formacao[i])
		squad.append(b)
	for modo in [false]:
		for b in squad:
			var vr = b.get_node_or_null("VisualRoot")
			if vr:
				var d: Vector3 = (spot + aproximar * 8.0) - b.global_position; d.y = 0
				vr.global_basis = Basis.looking_at(d.normalized(), Vector3.UP, modo).scaled(vr.global_basis.get_scale())
		var tag := "A" if modo else "B"
		cam.fov = 38.0
		await _shot("esq%s_largo" % tag, spot + aproximar * 8.5 + lado * 1.5 + Vector3.UP * 0.9, spot + Vector3.UP * 1.1 - aproximar * 1.2)
		await _shot("esq%s_baixo" % tag, spot + aproximar * 5.0 - lado * 1.2 + Vector3.UP * 0.35, spot + Vector3.UP * 1.5 - aproximar * 1.0)
		cam.fov = 28.0
		for i in min(3, squad.size()):
			var t: Vector3 = squad[i].global_position + Vector3.UP * 1.3
			await _shot("esq%s_heroi%d" % [tag, i], t + aproximar * 2.6 + lado * (0.9 if i % 2 == 0 else -0.9) + Vector3.DOWN * 0.5, t)
	log += "fotos=%d\n" % n_shot
	var f := FileAccess.open(OUT + "/log.txt", FileAccess.WRITE)
	f.store_string(log); f.close()
	get_tree().quit()

func _chao(space: PhysicsDirectSpaceState3D, p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5, p + Vector3.DOWN * 6.0)
	var h := space.intersect_ray(q)
	return h.position if not h.is_empty() else p

func _shot(nome: String, pos: Vector3, alvo: Vector3) -> void:
	cam.global_position = pos
	cam.look_at(alvo, Vector3.UP)
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, nome])
	n_shot += 1
