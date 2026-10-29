extends Node3D

func _ready():
	var scn = load("res://addons/fps-hands/fps-ak/fps-ak.tscn") as PackedScene
	var inst = scn.instantiate()
	add_child(inst)

	var obj7 = inst.find_child("Object_7", true, false) as MeshInstance3D
	var f = FileAccess.open("C:/gemini cli/games/test_arms_shader_out.txt", FileAccess.WRITE)
	f.store_line("Object_7 active material: %s" % str(obj7.get_active_material(0)))

	# Check shader parameters
	var sm = obj7.get_active_material(0) as ShaderMaterial
	if sm:
		f.store_line("fov parameter: %s" % str(sm.get_shader_parameter("fov")))
		f.store_line("albedo parameter: %s" % str(sm.get_shader_parameter("albedo")))
		f.store_line("texture_albedo: %s" % str(sm.get_shader_parameter("texture_albedo")))

	# Let's inspect AABB of Object_7
	f.store_line("Object_7 AABB: %s" % str(obj7.get_aabb()))

	# Let's test if we set material_override = StandardMaterial3D
	f.close()
	get_tree().quit(0)
