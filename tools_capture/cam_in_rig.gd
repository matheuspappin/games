extends Node3D
# Pose da câmera do jogo no espaço do modelo do addon (nó raiz do glb), para reproduzir a visão no Blender.
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
@onready var cam: Camera3D = $Camera
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	vm.equip_weapon_data(load("res://resources/weapons/ak47.tres"))
	vm.set_ads(false)
	await get_tree().create_timer(2.0).timeout
	var root: Node3D = vm.fps_hands.weapon.find_child("Sketchfab_model", true, false)
	var out := []
	if root:
		var rel: Transform3D = root.global_transform.affine_inverse() * cam.global_transform
		out.append("cam_no_glb origem=%s" % str(rel.origin))
		out.append("cam_no_glb frente(-Z)=%s cima(+Y)=%s" % [str(-rel.basis.z.normalized()), str(rel.basis.y.normalized())])
		out.append("fov=%.1f aspect=%s" % [cam.fov, str(get_viewport().get_visible_rect().size)])
	FileAccess.open("res://_prints/cam_in_rig.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
