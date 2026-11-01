extends Node3D
# Pose da câmera do jogo no espaço do modelo do addon (nó raiz do glb), para reproduzir a visão no Blender.
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
@onready var cam: Camera3D = $Camera
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	var out := []
	for wid in ["smg", "lmg", "pistol", "shotgun"]:
		vm.equip_weapon_data(load("res://resources/weapons/%s.tres" % wid))
		vm.set_ads(false)
		await get_tree().create_timer(2.0).timeout
		var root: Node3D = vm.fps_hands.weapon.find_child("Sketchfab_model", true, false)
		if root:
			var rel: Transform3D = root.global_transform.affine_inverse() * cam.global_transform
			out.append("%s | origem=%s frente=%s cima=%s | base=%s" % [wid, str(rel.origin), str(-rel.basis.z.normalized()), str(rel.basis.y.normalized()), str(vm.fps_hands.weapon.find_child("base", true, false) != null)])
		else:
			out.append("%s | sem Sketchfab_model; filhos=%s" % [wid, str(vm.fps_hands.weapon.get_children().map(func(c): return c.name))])
	FileAccess.open("res://_prints/cam_in_rig.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
