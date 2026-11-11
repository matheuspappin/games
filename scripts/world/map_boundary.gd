extends RefCounted
## Limite do mapa medido no próprio chão: rasteriza (vista de cima, células de CELL m) todo triângulo
## caminhável do modelo (normal para cima, perto do nível do solo), descobre o "lado de fora" por
## preenchimento a partir da borda da grade e ergue paredes invisíveis exatamente na divisa entre chão e
## fora. Ninguém sai do mapa por nenhum canto, e nada fica bloqueado dentro da área jogável.

const CELL := 0.5          # tamanho da célula (m)
const WALL_H := 14.0       # altura da parede a partir do solo
const WALL_T := 0.4        # espessura
const MIN_NORMAL_Y := 0.7  # triângulo caminhável
const GROUND_MIN_Y := -0.6
const GROUND_MAX_Y := 0.9

static func build(model: Node3D, parent: Node3D) -> Dictionary:
	var tris := PackedVector3Array()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var xf: Transform3D = m.global_transform
		for si in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(si)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx = arr[Mesh.ARRAY_INDEX]
			var n: int = idx.size() if idx != null and idx.size() > 0 else v.size()
			for i in range(0, n - 2, 3):
				var a: Vector3 = xf * v[idx[i] if idx != null and idx.size() > 0 else i]
				var b: Vector3 = xf * v[idx[i + 1] if idx != null and idx.size() > 0 else i + 1]
				var c: Vector3 = xf * v[idx[i + 2] if idx != null and idx.size() > 0 else i + 2]
				var cy := (a.y + b.y + c.y) / 3.0
				if cy < GROUND_MIN_Y or cy > GROUND_MAX_Y:
					continue
				var nrm := (b - a).cross(c - a)
				if nrm.length() < 1e-6 or absf(nrm.normalized().y) < MIN_NORMAL_Y:
					continue
				tris.append(a); tris.append(b); tris.append(c)
	if tris.is_empty():
		return {}
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in tris:
		lo = lo.min(Vector2(p.x, p.z)); hi = hi.max(Vector2(p.x, p.z))
	lo -= Vector2.ONE * CELL * 2.0
	hi += Vector2.ONE * CELL * 2.0
	var w := int(ceil((hi.x - lo.x) / CELL)) + 1
	var h := int(ceil((hi.y - lo.y) / CELL)) + 1
	var ground := PackedByteArray(); ground.resize(w * h)
	var floor_y := PackedFloat32Array(); floor_y.resize(w * h)
	for t in range(0, tris.size(), 3):
		var a := Vector2(tris[t].x, tris[t].z)
		var b := Vector2(tris[t + 1].x, tris[t + 1].z)
		var c := Vector2(tris[t + 2].x, tris[t + 2].z)
		var y := (tris[t].y + tris[t + 1].y + tris[t + 2].y) / 3.0
		var x0 := int(floor((minf(a.x, minf(b.x, c.x)) - lo.x) / CELL))
		var x1 := int(floor((maxf(a.x, maxf(b.x, c.x)) - lo.x) / CELL))
		var z0 := int(floor((minf(a.y, minf(b.y, c.y)) - lo.y) / CELL))
		var z1 := int(floor((maxf(a.y, maxf(b.y, c.y)) - lo.y) / CELL))
		for gz in range(maxi(z0, 0), mini(z1, h - 1) + 1):
			for gx in range(maxi(x0, 0), mini(x1, w - 1) + 1):
				var pc := lo + Vector2(gx + 0.5, gz + 0.5) * CELL
				if Geometry2D.point_is_inside_triangle(pc, a, b, c):
					ground[gz * w + gx] = 1
					floor_y[gz * w + gx] = y
	# lado de fora: vazio alcançável a partir da borda da grade
	var outside := PackedByteArray(); outside.resize(w * h)
	var stack: Array[int] = []
	for gx in w:
		stack.append(gx); stack.append((h - 1) * w + gx)
	for gz in h:
		stack.append(gz * w); stack.append(gz * w + w - 1)
	while not stack.is_empty():
		var i: int = stack.pop_back()
		if outside[i] == 1 or ground[i] == 1:
			continue
		outside[i] = 1
		var gx := i % w
		var gz := i / w
		if gx > 0: stack.append(i - 1)
		if gx < w - 1: stack.append(i + 1)
		if gz > 0: stack.append(i - w)
		if gz < h - 1: stack.append(i + w)
	var body := StaticBody3D.new()
	body.name = "MapBoundaryWalls"
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	var walls := 0
	# divisas verticais (entre colunas gx e gx+1) agrupadas em trechos contínuos ao longo de z
	for gx in range(w - 1):
		var run_start := -1
		var run_y := 0.0
		for gz in range(h + 1):
			var edge := false
			if gz < h:
				var l := gz * w + gx
				var r := l + 1
				edge = (ground[l] == 1 and outside[r] == 1) or (ground[r] == 1 and outside[l] == 1)
				if edge:
					run_y = minf(run_y, floor_y[l] if ground[l] == 1 else floor_y[r]) if run_start >= 0 else (floor_y[l] if ground[l] == 1 else floor_y[r])
			if edge and run_start < 0:
				run_start = gz
			elif not edge and run_start >= 0:
				var x := lo.x + (gx + 1) * CELL
				var za := lo.y + run_start * CELL
				var zb := lo.y + gz * CELL
				_add_box(body, Vector3(x, run_y + WALL_H * 0.5 - 0.5, (za + zb) * 0.5), Vector3(WALL_T, WALL_H, zb - za + WALL_T))
				walls += 1
				run_start = -1
	# divisas horizontais (entre linhas gz e gz+1) agrupadas ao longo de x
	for gz in range(h - 1):
		var run_start := -1
		var run_y := 0.0
		for gx in range(w + 1):
			var edge := false
			if gx < w:
				var u := gz * w + gx
				var d := u + w
				edge = (ground[u] == 1 and outside[d] == 1) or (ground[d] == 1 and outside[u] == 1)
				if edge:
					run_y = minf(run_y, floor_y[u] if ground[u] == 1 else floor_y[d]) if run_start >= 0 else (floor_y[u] if ground[u] == 1 else floor_y[d])
			if edge and run_start < 0:
				run_start = gx
			elif not edge and run_start >= 0:
				var z := lo.y + (gz + 1) * CELL
				var xa := lo.x + run_start * CELL
				var xb := lo.x + gx * CELL
				_add_box(body, Vector3((xa + xb) * 0.5, run_y + WALL_H * 0.5 - 0.5, z), Vector3(xb - xa + WALL_T, WALL_H, WALL_T))
				walls += 1
				run_start = -1
	var cells := 0
	for g in ground: cells += g
	return {"walls": walls, "ground_m2": cells * CELL * CELL, "grid": Vector2i(w, h), "tris": tris.size() / 3}

static func _add_box(body: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = center
	body.add_child(cs)
