@tool
extends EditorScenePostImport
## Pós-import do Nuketown 2065 (BO3): reduz SÓ a geometria excessiva de props decorativos
## (manequins da vitrine e similares). Paredes, casas, ruas, estruturas e árvores ficam intactas.
## O arquivo original (.glb) não é alterado; a redução é refeita a cada reimportação.

const PROP_PREFIX := "BO3_StreetProps"
const SURFACE_MIN_TRIS := 30000   # só superfícies acima disso são reduzidas
const KEEP_RATIO := 0.08          # mantém ~8% dos triângulos
const MIN_KEEP := 6000

func _post_import(scene: Node) -> Object:
	var before := 0
	var after := 0
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		if not String(mi.name).begins_with(PROP_PREFIX) or mi.mesh == null:
			continue
		var res := _reduce(mi.mesh)
		before += res[1]
		after += res[2]
		mi.mesh = res[0]
	print("[BO3 PostImport] props decorativos: %d -> %d triângulos" % [before, after])
	# _split_by_sector(scene)  # testado em 30/10: sem ganho (o mapa é visto quase inteiro de qualquer ponto)
	return scene

func _tris(arr: Array) -> int:
	var idx = arr[Mesh.ARRAY_INDEX]
	return (idx.size() if idx != null and idx.size() > 0 else arr[Mesh.ARRAY_VERTEX].size()) / 3

func _reduce(mesh: Mesh) -> Array:
	var out := ArrayMesh.new()
	var t_before := 0
	var t_after := 0
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var mat := mesh.surface_get_material(s)
		var n := _tris(arr)
		t_before += n
		if n > SURFACE_MIN_TRIS and arr[Mesh.ARRAY_INDEX] != null:
			var im := ImporterMesh.new()
			im.add_surface(mesh.surface_get_primitive_type(s), arr, [], {}, mat)
			im.generate_lods(25.0, 60.0, [])
			var target := maxi(MIN_KEEP, int(n * KEEP_RATIO))
			var best: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			for l in im.get_surface_lod_count(0):
				var li := im.get_surface_lod_indices(0, l)
				if li.size() / 3 >= target:
					best = li
			arr[Mesh.ARRAY_INDEX] = best
			# compacta vértices não usados
			var st := SurfaceTool.new()
			st.create_from_arrays(arr, mesh.surface_get_primitive_type(s))
			st.deindex()
			st.index()
			st.generate_tangents()
			arr = st.commit_to_arrays()
		t_after += _tris(arr)
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arr)
		out.surface_set_material(out.get_surface_count() - 1, mat)
	return [out, t_before, t_after]


# ── SETORES: corta cada bloco grande em pedaços por região do mapa ───────────
# O .glb agrupa objetos em blocos que atravessam o mapa inteiro, então nada era
# descartado fora da vista. Cada pedaço mantém material, malha de sombra e o nome
# original + "__sN" (a colisão do mapa lê o nome sem o sufixo).
const GRID := 3

func _split_by_sector(scene: Node) -> void:
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	var bounds := AABB()
	var first := true
	for mi in meshes:
		if mi.mesh == null: continue
		var b: AABB = mi.global_transform * mi.mesh.get_aabb() if mi.is_inside_tree() else _xf(mi) * mi.mesh.get_aabb()
		bounds = b if first else bounds.merge(b)
		first = false
	var created := 0
	for mi in meshes:
		if mi.mesh == null or mi.mesh.get_surface_count() == 0: continue
		var xf := _xf(mi)
		var cells := {}  # cell -> Array de surfaces (arrays, material, prim)
		for s in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			if idx == null or idx.size() == 0 or mi.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				_add_cell(cells, -1, arr, mi.mesh.surface_get_material(s))
				continue
			var per_cell := {}
			for t in range(0, idx.size(), 3):
				var c: Vector3 = xf * ((verts[idx[t]] + verts[idx[t + 1]] + verts[idx[t + 2]]) / 3.0)
				var cx := clampi(int((c.x - bounds.position.x) / bounds.size.x * GRID), 0, GRID - 1)
				var cz := clampi(int((c.z - bounds.position.z) / bounds.size.z * GRID), 0, GRID - 1)
				var cell := cz * GRID + cx
				if not per_cell.has(cell): per_cell[cell] = PackedInt32Array()
				var pi: PackedInt32Array = per_cell[cell]
				pi.append(idx[t]); pi.append(idx[t + 1]); pi.append(idx[t + 2])
				per_cell[cell] = pi
			for cell in per_cell:
				var sub := arr.duplicate()
				sub[Mesh.ARRAY_INDEX] = per_cell[cell]
				_add_cell(cells, cell, sub, mi.mesh.surface_get_material(s))
		if cells.size() <= 1:
			continue
		var keys := cells.keys()
		keys.sort()
		var base_name := String(mi.name)
		var parent := mi.get_parent()
		for k_i in keys.size():
			var mesh := _build(cells[keys[k_i]])
			if k_i == 0:
				mi.mesh = mesh
				mi.name = base_name + "__s%d" % k_i
			else:
				var n := MeshInstance3D.new()
				n.name = base_name + "__s%d" % k_i
				n.mesh = mesh
				n.transform = mi.transform
				n.cast_shadow = mi.cast_shadow
				parent.add_child(n)
				n.owner = scene
				created += 1
	print("[BO3 PostImport] setores: %d pedaços novos criados (grade %dx%d)" % [created, GRID, GRID])

func _xf(n: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p is Node3D:
		t = p.transform * t
		p = p.get_parent()
	return t

func _add_cell(cells: Dictionary, cell: int, arr: Array, mat: Material) -> void:
	if not cells.has(cell): cells[cell] = []
	cells[cell].append([arr, mat])

func _build(surfs: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var shadow := ArrayMesh.new()  # mesma geometria, só posições (o que o Godot usa para sombras)
	for e in surfs:
		var arr: Array = e[0]
		# compacta: só os vértices usados por este pedaço
		var st := SurfaceTool.new()
		st.create_from_arrays(arr, Mesh.PRIMITIVE_TRIANGLES)
		st.deindex()
		st.index()
		var out := st.commit_to_arrays()
		var mat: Material = e[1]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
		if mat: mesh.surface_set_name(mesh.get_surface_count() - 1, mat.resource_name)
		var sh := []
		sh.resize(Mesh.ARRAY_MAX)
		sh[Mesh.ARRAY_VERTEX] = out[Mesh.ARRAY_VERTEX]
		sh[Mesh.ARRAY_INDEX] = out[Mesh.ARRAY_INDEX]
		shadow.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sh)
	mesh.shadow_mesh = shadow
	return mesh
