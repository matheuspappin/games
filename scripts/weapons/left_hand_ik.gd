
extends SkeletonModifier3D
## IK analítico de dois ossos (braço -> antebraço -> punho) que roda depois da animação.
## Mantém o plano do cotovelo da pose animada e leva o punho até `target`.

var target: Node3D
var root_idx := -1
var mid_idx := -1
var end_idx := -1

func setup(skel: Skeleton3D, root_name: String, mid_name: String, end_name: String, target_node: Node3D) -> void:
	root_idx = skel.find_bone(root_name)
	mid_idx = skel.find_bone(mid_name)
	end_idx = skel.find_bone(end_name)
	target = target_node

func _process_modification_with_delta(_delta: float) -> void:
	_solve()

func _process_modification() -> void:
	_solve()

func _solve() -> void:
	var skel := get_skeleton()
	if not skel or root_idx < 0 or mid_idx < 0 or end_idx < 0 or not is_instance_valid(target):
		return
	var ra := skel.get_bone_global_pose(root_idx)
	var rb := skel.get_bone_global_pose(mid_idx)
	var rc := skel.get_bone_global_pose(end_idx)
	var a := ra.origin
	var b := rb.origin
	var c := rc.origin
	var t: Vector3 = skel.global_transform.affine_inverse() * target.global_position
	var lab := a.distance_to(b)
	var lcb := b.distance_to(c)
	if lab < 0.0001 or lcb < 0.0001:
		return
	var lat := clampf(a.distance_to(t), 0.001, (lab + lcb) * 0.999)
	var ac_ab_0 := acos(clampf((c - a).normalized().dot((b - a).normalized()), -1.0, 1.0))
	var ba_bc_0 := acos(clampf((a - b).normalized().dot((c - b).normalized()), -1.0, 1.0))
	var ac_at_0 := acos(clampf((c - a).normalized().dot((t - a).normalized()), -1.0, 1.0))
	var ac_ab_1 := acos(clampf((lcb * lcb - lab * lab - lat * lat) / (-2.0 * lab * lat), -1.0, 1.0))
	var ba_bc_1 := acos(clampf((lat * lat - lab * lab - lcb * lcb) / (-2.0 * lab * lcb), -1.0, 1.0))
	var axis0 := (c - a).cross(b - a)
	var axis1 := (c - a).cross(t - a)
	if axis0.length() < 0.000001:
		return
	axis0 = axis0.normalized()
	var a_gr := ra.basis.get_rotation_quaternion()
	var b_gr := rb.basis.get_rotation_quaternion()
	var a_local := skel.get_bone_pose_rotation(root_idx)
	var b_local := skel.get_bone_pose_rotation(mid_idx)
	a_local = a_local * Quaternion((a_gr.inverse() * axis0).normalized(), ac_ab_1 - ac_ab_0)
	b_local = b_local * Quaternion((b_gr.inverse() * axis0).normalized(), ba_bc_1 - ba_bc_0)
	if axis1.length() > 0.000001:
		a_local = a_local * Quaternion((a_gr.inverse() * axis1.normalized()).normalized(), ac_at_0)
	skel.set_bone_pose_rotation(root_idx, a_local)
	skel.set_bone_pose_rotation(mid_idx, b_local)
