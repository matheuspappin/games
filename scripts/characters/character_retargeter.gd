# =============================================================================
# character_retargeter.gd
# Sistema de Retargeting Humanoide para Skins de Personagens (Opção A)
# Mapeia as 15 animações de alta fidelidade do X-Bot para qualquer skin Mixamo/CS,
# descartando trilhas de dedos para preservar luvas 'mitten' sem rasgos ou deformações.
# =============================================================================
class_name CharacterRetargeter
extends RefCounted

const XBOT_SOURCE_PATH = "res://assets/models/mixamo/x_bot.glb"
static var _cached_source_anims: Dictionary = {}
static var _is_initialized: bool = false

## Posição e rotação calibradas do fuzil no RightHandAttachment para skins CS (Escala 1.0)
const CS_RIFLE_LOCAL_POS = Vector3(-0.021, -0.011, -0.022)
const CS_RIFLE_LOCAL_ROT = Vector3(81.05, -155.65, 118.90)
const CS_RIFLE_LOCAL_SCALE = Vector3(1.0, 1.0, 1.0)

## Posição e rotação calibradas do fuzil para X-Bot nativo (Armature escala 0.01)
const XBOT_RIFLE_LOCAL_POS = Vector3(0.04, 0.03, -0.01)
const XBOT_RIFLE_LOCAL_ROT = Vector3(90.0, 0.0, -90.0)
const XBOT_RIFLE_LOCAL_SCALE = Vector3(100.0, 100.0, 100.0)

static func _init_source_cache() -> void:
	if _is_initialized:
		return
	var x_scn = load(XBOT_SOURCE_PATH) as PackedScene
	if not x_scn:
		push_error("[CharacterRetargeter] Não foi possível carregar " + XBOT_SOURCE_PATH)
		return
	var x_inst = x_scn.instantiate()
	var x_ap = x_inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if x_ap:
		for anim_name in x_ap.get_animation_list():
			_cached_source_anims[anim_name] = x_ap.get_animation(anim_name)
	_is_initialized = true
	x_inst.free()

static func retarget_model(model_root: Node3D) -> void:
	if not model_root:
		return
	_init_source_cache()

	var skel = model_root.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap = model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not skel or not ap:
		return

	var anim_root_node = ap.get_node_or_null(ap.root_node)
	var skel_node_path: String
	if anim_root_node:
		skel_node_path = str(anim_root_node.get_path_to(skel))
	else:
		skel_node_path = str(model_root.get_path_to(skel))
	var lib = ap.get_animation_library("")
	if not lib:
		lib = AnimationLibrary.new()
		ap.add_animation_library("", lib)

	for anim_name in _cached_source_anims.keys():
		var src_anim = _cached_source_anims[anim_name] as Animation
		if not src_anim:
			continue

		var retargeted = Animation.new()
		retargeted.length = src_anim.length
		var is_loop = anim_name in ["idle", "walk", "run", "walk_backward", "run_backward", "strafe_left", "strafe_right"]
		retargeted.loop_mode = Animation.LOOP_LINEAR if is_loop else Animation.LOOP_NONE

		for i in range(src_anim.get_track_count()):
			var old_path = str(src_anim.track_get_path(i))
			var new_path = old_path.replace("Armature/Skeleton3D", skel_node_path)
			var sub_name = new_path.get_slice(":", 1)

			# Descartar trilhas de dedos em luvas de bloco (mitten CS)
			if "Thumb" in sub_name or "Index" in sub_name or "Mid" in sub_name or "Ring" in sub_name or "Pinky" in sub_name or "Finger" in sub_name:
				continue

			if skel.find_bone(sub_name) >= 0:
				var t_idx = retargeted.add_track(src_anim.track_get_type(i))
				retargeted.track_set_path(t_idx, NodePath(new_path))
				retargeted.track_set_interpolation_type(t_idx, src_anim.track_get_interpolation_type(i))

				for k in range(src_anim.track_get_key_count(i)):
					var time = src_anim.track_get_key_time(i, k)
					var val = src_anim.track_get_key_value(i, k)
					# Escala de raiz/posições de cm para metros
					if src_anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
						val = val * 0.01
					retargeted.track_insert_key(t_idx, time, val)

		if lib.has_animation(anim_name):
			lib.remove_animation(anim_name)
		lib.add_animation(anim_name, retargeted)

	if ap.has_animation("idle"):
		ap.play("idle")
