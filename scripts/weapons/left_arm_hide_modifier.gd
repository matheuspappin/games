extends SkeletonModifier3D
## Armas de uma mão (ex.: MP7): recolhe o braço esquerdo no ombro, fora da tela.
## Roda depois da animação e do IK; a força vem de `influence` (0 = braço normal).

var _arm := -1

func _process_modification() -> void:
	var sk := get_skeleton()
	if not sk:
		return
	if _arm < 0:
		_arm = sk.find_bone("L_arm_01")
		if _arm < 0:
			return
	sk.set_bone_pose_scale(_arm, Vector3.ONE * 0.001)
