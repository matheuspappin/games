@tool
extends RefCounted
# Otimiza acessórios com malha/texturas embutidas: simplifica malhas acima de 20 mil triângulos
# e extrai texturas para PNG de no máximo 1024 px (importadas como VRAM comprimido).
const SCENES := ["grip_angled", "stock_light", "stock_heavy", "grip_vertical"]
const OPT_DIR := "res://assets/models/weapons/attachments/opt"
const TEX_PROPS := ["albedo_texture", "normal_texture", "orm_texture", "metallic_texture", "roughness_texture", "emission_texture", "ao_texture"]

func run() -> Dictionary:
	var report := {}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OPT_DIR))
	var pending := []  # [material, prop, png_path]
	var roots := {}
	for n in SCENES:
		var path := "res://scenes/weapons/attachments/%s.tscn" % n
		var root: Node = load(path).instantiate()
		roots[n] = root
		var info := {}
		var k := 0
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = mi.mesh
			var tris := _tris(mesh)
			info["tris_antes"] = tris
			if tris > 20000:
				mesh = _simplify(mesh, 15000.0 / tris)
				mi.mesh = mesh
				info["tris_depois"] = _tris(mesh)
			for s in mesh.get_surface_count():
				var mat = mi.get_surface_override_material(s)
				if mat == null:
					mat = mesh.surface_get_material(s)
				if not (mat is BaseMaterial3D):
					continue
				for p in TEX_PROPS:
					var t: Texture2D = mat.get(p)
					if t == null or (t.resource_path != "" and not t.resource_path.contains("::")):
						continue
					var img := t.get_image()
					if img == null:
						continue
					if img.is_compressed():
						img.decompress()
					var m := maxi(img.get_width(), img.get_height())
					if m > 1024:
						img.resize(int(img.get_width() * 1024.0 / m), int(img.get_height() * 1024.0 / m), Image.INTERPOLATE_LANCZOS)
					var png := "%s/%s_%d_%s.png" % [OPT_DIR, n, k, p.trim_suffix("_texture")]
					if not FileAccess.file_exists(png):
						img.save_png(ProjectSettings.globalize_path(png))
					pending.append([mat, p, png])
				k += 1
		report[n] = info
	# importar os PNGs (normal map com compressão de normal) e reatribuir
	var pngs := PackedStringArray()
	for e in pending:
		pngs.append(e[2])
	for e in pending:
		var tex = load(e[2])
		if tex:
			e[0].set(e[1], tex)
	for n in SCENES:
		var ps := PackedScene.new()
		ps.pack(roots[n])
		var err := ResourceSaver.save(ps, "res://scenes/weapons/attachments/%s.tscn" % n)
		report[n]["salvo"] = err == OK
		roots[n].free()
	report["pngs"] = pngs.size()
	return report

func _tris(mesh: Mesh) -> int:
	var t := 0
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var idx = a[Mesh.ARRAY_INDEX]
		t += (idx.size() if idx != null and idx.size() > 0 else a[Mesh.ARRAY_VERTEX].size()) / 3
	return t

func _simplify(mesh: Mesh, ratio: float) -> ArrayMesh:
	var im := ImporterMesh.new()
	for s in mesh.get_surface_count():
		im.add_surface(mesh.surface_get_primitive_type(s), mesh.surface_get_arrays(s), [], {}, mesh.surface_get_material(s), mesh.surface_get_name(s))
	im.generate_lods(25.0, 60.0, [])
	var out := ArrayMesh.new()
	for s in im.get_surface_count():
		var arr := im.get_surface_arrays(s)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var target := int(idx.size() / 3 * ratio)
		var best := idx
		for l in im.get_surface_lod_count(s):
			var li := im.get_surface_lod_indices(s, l)
			if li.size() / 3 >= target:
				best = li
		arr[Mesh.ARRAY_INDEX] = best
		out.add_surface_from_arrays(im.get_surface_primitive_type(s), arr)
		out.surface_set_material(s, im.get_surface_material(s))
		out.surface_set_name(s, im.get_surface_name(s))
	return out

func run_one(n: String) -> String:
	var path := "res://scenes/weapons/attachments/%s.tscn" % n
	var root: Node = load(path).instantiate()
	var log := ""
	var k := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		var tris := _tris(mesh)
		log += "tris %d " % tris
		if tris > 20000:
			mesh = _simplify(mesh, 15000.0 / tris)
			mi.mesh = mesh
			log += "-> %d " % _tris(mesh)
		for s in mesh.get_surface_count():
			var mat = mi.get_surface_override_material(s)
			if mat == null:
				mat = mesh.surface_get_material(s)
			if not (mat is BaseMaterial3D):
				continue
			for p in TEX_PROPS:
				if not (p in mat):
					continue
				var png := "%s/%s_%d_%s.png" % [OPT_DIR, n, k, p.trim_suffix("_texture")]
				if mat.get(p) != null and ResourceLoader.exists(png):
					mat.set(p, load(png))
					log += "tex "
			k += 1
	var ps := PackedScene.new()
	ps.pack(root)
	var err := ResourceSaver.save(ps, path)
	root.free()
	return log + "salvo=%d" % err

func compact_one(n: String) -> String:
	var path := "res://scenes/weapons/attachments/%s.tscn" % n
	var root: Node = load(path).instantiate()
	var log := ""
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		var out := ArrayMesh.new()
		for s in mesh.get_surface_count():
			var st := SurfaceTool.new()
			st.create_from_arrays(mesh.surface_get_arrays(s), mesh.surface_get_primitive_type(s))
			st.deindex()
			st.index()
			st.set_material(mesh.surface_get_material(s))
			st.commit(out)
			out.surface_set_name(s, mesh.surface_get_name(s))
		log += "verts %d->%d " % [mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(), out.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()]
		for s in mesh.get_surface_count():
			var ov = mi.get_surface_override_material(s)
			if ov:
				mi.set_surface_override_material(s, ov)
		mi.mesh = out
	var ps := PackedScene.new()
	ps.pack(root)
	var err := ResourceSaver.save(ps, path)
	root.free()
	return log + "salvo=%d" % err
