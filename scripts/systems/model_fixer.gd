# =============================================================================
# model_fixer.gd
# Utilitário para corrigir binds de esqueleto/skin em modelos GLTF/GLB importados
# =============================================================================
class_name ModelFixer
extends RefCounted

static func fix_skins(root_node: Node) -> void:
	if root_node == null:
		return
	
	# Centralizar offsets de modelos importados do CS (ex: ct_urban_ARM, t_phoenix_ARM)
	var arm_nodes = root_node.find_children("*_ARM", "Node3D", true, false)
	for arm in arm_nodes:
		var arm_3d = arm as Node3D
		if arm_3d:
			arm_3d.position.x = 0.0
			arm_3d.position.z = 0.0

	var mesh_instances = root_node.find_children("*", "MeshInstance3D", true, false)
	for mi_node in mesh_instances:
		var mi = mi_node as MeshInstance3D
		if mi.skin:
			# Duplica skin para não compartilhar binds corrompidos entre instâncias
			mi.skin = mi.skin.duplicate()
			var skel = mi.get_node_or_null(mi.skeleton) as Skeleton3D
			if not skel:
				skel = root_node.find_child("Skeleton3D", true, false) as Skeleton3D
			if skel:
				# Mixamo rigs import with correct native skin binds; do not overwrite
				if skel.find_bone("mixamorig_Hips") >= 0 or skel.find_bone("mixamorig_Spine") >= 0:
					continue
				var bind_count = mi.skin.get_bind_count()
				for b in range(bind_count):
					var b_name = mi.skin.get_bind_name(b)
					if b_name != "":
						var idx = skel.find_bone(b_name)
						if idx >= 0:
							mi.skin.set_bind_bone(b, idx)
					elif b < skel.get_bone_count():
						mi.skin.set_bind_bone(b, b)
