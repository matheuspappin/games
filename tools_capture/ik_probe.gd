extends Node3D
# Mede a distância punho esquerdo -> GripL DEPOIS dos modificadores (sinal skeleton_updated).
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
var dist := -1.0
var info := ""

func _ready() -> void:
	_run.call_deferred()

func _on_skel_updated(skel: Skeleton3D, marker: Node3D) -> void:
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).begins_with("L_wrist"):
			var p := skel.global_transform * skel.get_bone_global_pose(i).origin
			dist = p.distance_to(marker.global_position) * 100.0

func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	var out := []
	for wid in ["m4a1", "scar_h", "krm262", "rpk", "mp7", "ak47"]:
		vm.equip_weapon_data(load("res://resources/weapons/%s.tres" % wid))
		vm.set_ads(false)
		await get_tree().create_timer(2.0).timeout
		var ik = vm.left_hand_ik
		var marker = vm.current_custom_model_instance.get_node_or_null("Pivot/GripL")
		if ik and marker:
			var skel: Skeleton3D = ik.get_parent()
			dist = -1.0
			skel.skeleton_updated.connect(_on_skel_updated.bind(skel, marker), CONNECT_ONE_SHOT)
			await get_tree().process_frame
			await get_tree().process_frame
			out.append("%s ik=sim influence=%.2f ativo=%s alvo_ok=%s dist_cm=%.1f" % [wid, ik.influence, ik.active, ik.get_target_node(0) != NodePath(), dist])
		else:
			out.append("%s ik=%s marker=%s" % [wid, ik != null, marker != null])
	FileAccess.open("res://_prints/ik_probe.txt", FileAccess.WRITE).store_string("\n".join(out))
	get_tree().quit()
