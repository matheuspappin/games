extends SkeletonModifier3D
## Pegada da arma em 3ª pessoa (bots e outros jogadores): roda depois das animações Mixamo.
## - Mão esquerda vai ao guarda-mão (ou ao cabo, na pistola) da arma que está na mão direita.
## - Pistola: braço direito estendido na frente do peito, segurando com as duas mãos (padrão CoD).
## IK analítico de dois ossos; mantém o plano do cotovelo da animação e a orientação global da mão.

var rifle: Node3D = null          ## BotRifle3D preso no RightHandAttachment
var facing: Node3D = null         ## nó cujo -Z é a frente do personagem
var weight := 1.0
var last_error := 0.0

var _ids := {}
var _palm := {}
## centro da palma por malha (as skins CS não têm ossos de dedo: a mão é uma "luva" inteira no osso Hand)
static var _palm_cache := {}

func _bone(sk: Skeleton3D, key: String, names: Array) -> int:
	if _ids.has(key):
		return _ids[key]
	var idx := -1
	for n in names:
		idx = sk.find_bone(n)
		if idx >= 0:
			break
	_ids[key] = idx
	return idx

func _process_modification() -> void:
	var sk := get_skeleton()
	if not sk or not is_instance_valid(rifle) or weight <= 0.001 or not rifle.is_visible_in_tree():
		return
	if is_instance_valid(facing) and "is_dead" in facing and facing.is_dead:
		return
	var l_up := _bone(sk, "lu", ["mixamorig_LeftArm", "LeftArm"])
	var l_fo := _bone(sk, "lf", ["mixamorig_LeftForeArm", "LeftForeArm"])
	var l_ha := _bone(sk, "lh", ["mixamorig_LeftHand", "LeftHand"])
	var r_up := _bone(sk, "ru", ["mixamorig_RightArm", "RightArm"])
	var r_fo := _bone(sk, "rf", ["mixamorig_RightForeArm", "RightForeArm"])
	var r_ha := _bone(sk, "rh", ["mixamorig_RightHand", "RightHand"])
	var neck := _bone(sk, "nk", ["mixamorig_Neck", "Neck"])
	if l_ha < 0 or r_ha < 0:
		return
	var inv := sk.global_transform.affine_inverse()
	# cabo da arma no centro da mão direita (a arma fica presa ao osso da mão: espaço da arma = mão * transform)
	if rifle.has_method("set_palm_anchor"):
		rifle.set_palm_anchor(rifle.transform.affine_inverse() * _palm_local(sk, r_ha))
	var pistol: bool = rifle.has_method("is_pistol") and rifle.is_pistol()
	if pistol and r_up >= 0 and r_fo >= 0 and neck >= 0 and is_instance_valid(facing):
		# braços estendidos: a mão direita fica na frente do peito, um pouco abaixo da linha dos olhos
		var nk: Vector3 = sk.global_transform * sk.get_bone_global_pose(neck).origin
		var fw: Vector3 = -facing.global_basis.z
		fw.y = 0.0
		fw = fw.normalized()
		var rt: Vector3 = fw.cross(Vector3.UP).normalized()
		var tgt: Vector3 = nk + fw * 0.44 + rt * 0.05 - Vector3.UP * 0.10
		_solve(sk, r_up, r_fo, r_ha, inv * tgt, weight)
	# ponto de apoio da mão esquerda no espaço da arma, levado para o espaço do esqueleto pela mão direita
	var sup: Vector3 = rifle.get_support_point() if rifle.has_method("get_support_point") else Vector3(0, -0.06, -0.55)
	# o BoneAttachment3D fica exatamente na pose do osso da mão: arma = pose da mão * transform local da arma
	var hand_g: Transform3D = sk.get_bone_global_pose(r_ha)
	var sup_sk: Vector3 = hand_g * (rifle.transform * sup)
	# o ponto de apoio é a PALMA, o IK move o PUNHO (origem do osso): desconta o centro da palma medido na
	# malha da própria skin (a orientação da mão não muda no IK, então o desconto vale depois dele)
	var palm_off: Vector3 = sk.get_bone_global_pose(l_ha).basis * _palm_local(sk, l_ha)
	sup_sk -= palm_off
	if l_up >= 0 and l_fo >= 0 and rifle.has_method("get_support_rear"):
		# alcance real do braço da skin: se a ponta do guarda-mão estiver longe demais, a mão desliza para
		# trás ao longo do guarda-mão até o primeiro ponto alcançável (como um atirador de braço curto)
		var sh: Vector3 = sk.get_bone_global_pose(l_up).origin
		var reach: float = (sk.get_bone_global_pose(l_fo).origin.distance_to(sh) \
				+ sk.get_bone_global_pose(l_ha).origin.distance_to(sk.get_bone_global_pose(l_fo).origin)) * 0.97
		var rear_sk: Vector3 = hand_g * (rifle.transform * rifle.get_support_rear()) - palm_off
		for i in 11:
			var cand: Vector3 = sup_sk.lerp(rear_sk, i / 10.0)
			if cand.distance_to(sh) <= reach or i == 10:
				sup_sk = cand
				break
	if l_up >= 0 and l_fo >= 0:
		_solve(sk, l_up, l_fo, l_ha, sup_sk, weight)
		# erro restante (punho alcançado x pedido), em metros: lido pela sonda tools_capture/bot_grip_lab
		last_error = sk.get_bone_global_pose(l_ha).origin.distance_to(sup_sk) * sk.global_basis.get_scale().x

## leva o punho (end) até t (espaço do esqueleto); a mão mantém a orientação global anterior
func _solve(sk: Skeleton3D, root_idx: int, mid_idx: int, end_idx: int, t: Vector3, w: float) -> void:
	var ra := sk.get_bone_global_pose(root_idx)
	var rb := sk.get_bone_global_pose(mid_idx)
	var rc := sk.get_bone_global_pose(end_idx)
	var a := ra.origin
	var b := rb.origin
	var c := rc.origin
	t = c.lerp(t, w)
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
	var a_local := sk.get_bone_pose_rotation(root_idx)
	var b_local := sk.get_bone_pose_rotation(mid_idx)
	a_local = a_local * Quaternion((a_gr.inverse() * axis0).normalized(), ac_ab_1 - ac_ab_0)
	b_local = b_local * Quaternion((b_gr.inverse() * axis0).normalized(), ba_bc_1 - ba_bc_0)
	if axis1.length() > 0.000001:
		a_local = a_local * Quaternion((a_gr.inverse() * axis1.normalized()).normalized(), ac_at_0)
	sk.set_bone_pose_rotation(root_idx, a_local)
	sk.set_bone_pose_rotation(mid_idx, b_local)
	# mão com a mesma orientação global de antes do IK (a arma presa nela não gira)
	var root_parent := sk.get_bone_parent(root_idx)
	var parent_g := sk.get_bone_global_pose(root_parent) if root_parent >= 0 else Transform3D.IDENTITY
	var mid_g := parent_g * Transform3D(Basis(a_local), sk.get_bone_pose_position(root_idx)) * Transform3D(Basis(b_local), sk.get_bone_pose_position(mid_idx))
	var want: Basis = rc.basis.orthonormalized()
	sk.set_bone_pose_rotation(end_idx, (mid_g.basis.orthonormalized().inverse() * want).get_rotation_quaternion())

## Centro da mão no espaço do osso: média dos vértices cuja maior parte do peso é desse osso, levados à
## pose de repouso pelo skin (mesmo cálculo da medição no Blender: tools_capture/blender_hands.py).
func _palm_local(sk: Skeleton3D, bone: int) -> Vector3:
	if _palm.has(bone):
		return _palm[bone]
	var bname := sk.get_bone_name(bone)
	var sum := Vector3.ZERO
	var n := 0
	for mi in sk.get_parent().find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.skin == null or m.get_node_or_null(m.skeleton) != sk:
			continue
		var key := "%s|%s" % [m.mesh.resource_path if m.mesh.resource_path != "" else str(m.mesh.get_instance_id()), bname]
		var cached = _palm_cache.get(key)
		if cached == null:
			cached = _measure(sk, m, bname)
			_palm_cache[key] = cached
		sum += cached[0] * cached[1]
		n += cached[1]
	var rest_g := sk.get_bone_global_rest(bone)
	var local := Vector3(0, 0.1, 0)   # sem malha: ~10 cm ao longo do osso
	if n > 0:
		local = rest_g.affine_inverse() * (sum / n)
	_palm[bone] = local
	return local

func _measure(sk: Skeleton3D, m: MeshInstance3D, bname: String) -> Array:
	var skin := m.skin
	var binds := {}   # índice do bind -> transform (repouso do osso * bind)
	var target_bind := -1
	for bi in skin.get_bind_count():
		var bn := skin.get_bind_name(bi)
		var bidx := sk.find_bone(bn) if bn != "" else skin.get_bind_bone(bi)
		if bidx < 0:
			continue
		binds[bi] = sk.get_bone_global_rest(bidx) * skin.get_bind_pose(bi)
		if sk.get_bone_name(bidx) == bname:
			target_bind = bi
	if target_bind < 0:
		return [Vector3.ZERO, 0]
	var acc := Vector3.ZERO
	var cnt := 0
	for si in m.mesh.get_surface_count():
		var arr := m.mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones = arr[Mesh.ARRAY_BONES]
		var weights = arr[Mesh.ARRAY_WEIGHTS]
		if bones == null or weights == null or verts.is_empty():
			continue
		var per: int = int(bones.size() / verts.size())
		for vi in verts.size():
			var w_t := 0.0
			var p := Vector3.ZERO
			for k in per:
				var w: float = weights[vi * per + k]
				if w <= 0.0:
					continue
				var b: int = bones[vi * per + k]
				if b == target_bind:
					w_t += w
				if binds.has(b):
					p += (binds[b] as Transform3D) * verts[vi] * w
			if w_t > 0.5:
				acc += p
				cnt += 1
	return [acc / maxf(cnt, 1), cnt]
