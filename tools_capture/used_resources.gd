extends Node
# Calcula o conjunto de recursos realmente usados: cenas do jogo + caminhos citados em scripts/cenas
# + autoloads, expandindo dependencias. Gera _prints/used.txt para o filtro de export.
var seen := {}

func _ready() -> void:
	var seeds: Array[String] = []
	seeds.append(ProjectSettings.get_setting("application/run/main_scene"))
	for p in ProjectSettings.get_property_list():
		var n: String = p.name
		if n.begins_with("autoload/"):
			seeds.append(str(ProjectSettings.get_setting(n)).trim_prefix("*"))
	var re := RegEx.new()
	re.compile("res://[A-Za-z0-9_./\\- ]+\\.(tscn|scn|tres|res|gd|glb|gltf|png|jpg|jpeg|webp|ogg|wav|mp3|gdshader|ttf|otf)")
	for root in ["res://scenes", "res://scripts", "res://resources", "res://shaders", "res://addons/fpc", "res://addons/phantom_camera/scripts", "res://addons/profily"]:
		_scan_dir(root, re, seeds)
	for s in seeds:
		_add(s)
	var out := seen.keys()
	out.sort()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints"))
	var f := FileAccess.open("res://_prints/used.txt", FileAccess.WRITE)
	f.store_string("\n".join(out))
	f.close()
	print("[USED] ", out.size(), " recursos")
	get_tree().quit()

func _scan_dir(dir: String, re: RegEx, seeds: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		var path := dir.path_join(f)
		if f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".tres"):
			seeds.append(path)
			var txt := FileAccess.get_file_as_string(path)
			for m in re.search_all(txt):
				seeds.append(m.get_string())
	for d in DirAccess.get_directories_at(dir):
		if d != "tests":
			_scan_dir(dir.path_join(d), re, seeds)

func _add(path: String) -> void:
	if path.begins_with("uid://"):
		var id := ResourceUID.text_to_id(path)
		if not ResourceUID.has_id(id):
			return
		path = ResourceUID.get_id_path(id)
	if path == "" or seen.has(path) or not ResourceLoader.exists(path):
		return
	seen[path] = true
	for d in ResourceLoader.get_dependencies(path):
		var parts := d.split("::")
		var dep: String = parts[parts.size() - 1]
		if parts.size() >= 3 and parts[0].begins_with("uid://") and dep == "":
			dep = parts[0]
		_add(dep)
