extends SkeletonModifier3D
## Fecha os dedos da mão esquerda em volta de uma empunhadura vertical/angular.
## Pose copiada da animação de repouso da família SMG (punho na empunhadura vertical da UMP);
## os braços são o mesmo modelo em todas as famílias, então os ossos têm os mesmos nomes.
## Roda depois da animação e antes do IK; a força vem de `influence` (0 = pose da animação).

const FIST := {
	"L_thumb1_04": Quaternion(0.170867, 0.122367, -0.195800, 0.957859),
	"L_thumb2_05": Quaternion(0.177482, -0.068810, -0.192891, 0.962579),
	"L_thumb3_00": Quaternion(-0.046863, -0.327781, -0.115290, 0.936521),
	"L_point1_07": Quaternion(0.143768, -0.567221, 0.357235, 0.727993),
	"L_point2_08": Quaternion(0.017802, -0.332885, 0.016818, 0.942649),
	"L_point3_09": Quaternion(-0.030322, -0.558470, 0.009635, 0.828915),
	"L_middle1_011": Quaternion(0.207694, -0.653216, 0.366181, 0.629352),
	"L_middle2_012": Quaternion(0.022582, -0.280313, 0.002448, 0.959640),
	"L_middle3_013": Quaternion(-0.005593, -0.661444, 0.024092, 0.749586),
	"L_ring1_016": Quaternion(0.078678, 0.715133, 0.037432, 0.693537),
	"L_ring2_017": Quaternion(0.032068, -0.426429, 0.061451, 0.901861),
	"L_ring3_018": Quaternion(-0.054407, -0.511689, 0.029956, 0.856923),
	"L_pink1_020": Quaternion(0.177301, 0.774586, 0.073746, 0.602613),
	"L_pink2_021": Quaternion(-0.023101, -0.387212, 0.006500, 0.921678),
	"L_pink3_022": Quaternion(0.025864, -0.549872, -0.001076, 0.834848),
}

var _ids := {}

func _process_modification() -> void:
	var sk := get_skeleton()
	if not sk:
		return
	if _ids.is_empty():
		for n in FIST:
			var i := sk.find_bone(n)
			if i >= 0:
				_ids[n] = i
	for n in _ids:
		sk.set_bone_pose_rotation(_ids[n], FIST[n])
