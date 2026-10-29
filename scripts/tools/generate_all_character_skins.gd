@tool
extends SceneTree

const SOURCE_SCALE = 0.0232  # Scales ~77.5 Source units to ~1.80m tall

const CT_SKINS = [
	{
		"id": "ct_urban",
		"name": "SEAL Team 6 (Urban)",
		"node_name": "ct_urban_ARM",
		"center_offset": Vector3(89.988, 0.0, -0.376),
		"output_path": "res://scenes/characters/skins/ct_urban.tscn",
		"root_name": "CT_Urban"
	},
	{
		"id": "ct_sas",
		"name": "SAS (Special Air Service)",
		"node_name": "ct_sas_ARM",
		"center_offset": Vector3(30.546, 0.0, 0.882),
		"output_path": "res://scenes/characters/skins/ct_sas.tscn",
		"root_name": "CT_SAS"
	},
	{
		"id": "ct_gsg9",
		"name": "GSG-9 (Grenzschutzgruppe 9)",
		"node_name": "ct_gsg9_ARM",
		"center_offset": Vector3(-28.695, 0.0, 0.602),
		"output_path": "res://scenes/characters/skins/ct_gsg9.tscn",
		"root_name": "CT_GSG9"
	},
	{
		"id": "ct_gign",
		"name": "GIGN (Gendarmerie Nationale)",
		"node_name": "ct_gign_ARM",
		"center_offset": Vector3(-87.998, 0.0, 0.344),
		"output_path": "res://scenes/characters/skins/ct_gign.tscn",
		"root_name": "CT_GIGN"
	}
]

const T_SKINS = [
	{
		"id": "t_phoenix",
		"name": "Phoenix Connexion",
		"node_name": "t_phoenix_ARM",
		"center_offset": Vector3(90.929, 0.0, -0.329),
		"output_path": "res://scenes/characters/skins/t_phoenix.tscn",
		"root_name": "T_Phoenix"
	},
	{
		"id": "t_leet",
		"name": "Elite Crew (1337 Krew)",
		"node_name": "t_leet_ARM",
		"center_offset": Vector3(30.527, 0.0, -0.591),
		"output_path": "res://scenes/characters/skins/t_leet.tscn",
		"root_name": "T_Leet"
	},
	{
		"id": "t_guerilla",
		"name": "Guerilla Warfare",
		"node_name": "t_guerilla_ARM",
		"center_offset": Vector3(-29.078, 0.0, -0.481),
		"output_path": "res://scenes/characters/skins/t_guerilla.tscn",
		"root_name": "T_Guerilla"
	},
	{
		"id": "t_arctic",
		"name": "Arctic Avengers",
		"node_name": "t_arctic_ARM",
		"center_offset": Vector3(-90.757, 0.0, 1.368),
		"output_path": "res://scenes/characters/skins/t_arctic.tscn",
		"root_name": "T_Arctic"
	}
]

func _initialize():
	print("=== STARTING GENERATION OF ALL 8 CS CHARACTER SKINS ===")
	DirAccess.make_dir_recursive_absolute("res://scenes/characters/skins")
	
	_generate_skins_from_glb("res://assets/models/characters/counter_terrorist.glb", CT_SKINS)
	_generate_skins_from_glb("res://assets/models/characters/terrorist.glb", T_SKINS)
	
	print("=== ALL CHARACTER SKINS GENERATED SUCCESSFULLY ===")
	quit(0)

func _generate_skins_from_glb(glb_path: String, skin_defs: Array):
	print("Processing: ", glb_path)
	var doc = GLTFDocument.new()
	var state = GLTFState.new()
	var err = doc.append_from_file(glb_path, state)
	if err != OK:
		printerr("Failed to load: ", glb_path)
		return
	
	var root_scene = doc.generate_scene(state)
	if not root_scene:
		printerr("Failed to generate scene from: ", glb_path)
		return
		
	for def in skin_defs:
		var arm_node = root_scene.find_child(def["node_name"], true, false)
		if not arm_node:
			printerr("Could not find arm node: ", def["node_name"])
			continue
		
		# Detach arm_node from root_scene
		if arm_node.get_parent():
			arm_node.get_parent().remove_child(arm_node)
			
		var char_root = Node3D.new()
		char_root.name = def["root_name"]
		char_root.add_child(arm_node)
		
		# Apply scaling and centering offset
		arm_node.position = def["center_offset"] * SOURCE_SCALE
		arm_node.scale = Vector3(SOURCE_SCALE, SOURCE_SCALE, SOURCE_SCALE)
		
		_set_owner_recursive(char_root, char_root)
		
		var packed = PackedScene.new()
		var pack_err = packed.pack(char_root)
		if pack_err != OK:
			printerr("Error packing: ", def["id"], " err: ", pack_err)
			continue
			
		var save_err = ResourceSaver.save(packed, def["output_path"])
		if save_err == OK:
			print("  [OK] Saved: ", def["output_path"], " (", def["name"], ")")
		else:
			printerr("  [ERROR] Failed to save: ", def["output_path"], " err: ", save_err)

func _set_owner_recursive(node: Node, target_owner: Node):
	for c in node.get_children():
		c.owner = target_owner
		_set_owner_recursive(c, target_owner)
