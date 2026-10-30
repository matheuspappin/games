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
