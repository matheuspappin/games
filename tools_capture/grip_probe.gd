extends Node3D
# Calcula o ponto de apoio da mão esquerda (GripL) de cada arma customizada:
# posição do punho esquerdo relativa à arma nativa da família, transferida para a caixa do modelo.
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
@onready var cam: Camera3D = $Camera
var lines := []
var ref_t := {}
const REF := {"rifle": "ak47", "smg": "smg", "shotgun": "shotgun", "pistol": "pistol"}
const ORDER := ["ak47", "smg", "shotgun", "pistol"]

func _ready() -> void:
	_run.call_deferred()

func _box(nodes: Array) -> AABB:
	var box := AABB()
	var first := true
	for m in nodes:
		var b: AABB = m.global_transform * m.get_aabb()
		b = AABB(cam.to_local(b.position), b.size)
		box = b if first else box.merge(b)
		first = false
	return box

func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	var all := []
	for f in DirAccess.get_files_at("res://resources/weapons"):
		if f.ends_with(".tres") and not (f.get_basename() in ORDER):
			all.append(f.get_basename())
	for wid in ORDER + all:
		var f: String = wid + ".tres"
		var cfg = WeaponVisualRegistry.get_weapon_config(wid)
		if cfg.get("has_arms", true):
			continue
		vm.equip_weapon_data(load("res://resources/weapons/" + f))
		vm.set_ads(false)
		await get_tree().create_timer(1.8).timeout
		var model: Node3D = vm.current_custom_model_instance
		var pivot: Node3D = model.get_node("Pivot")
		var nat_nodes := []
		var cus_nodes := []
		for m in vm.fps_hands.weapon.find_children("*", "MeshInstance3D", true, false):
			var low: String = m.name.to_lower()
			if m.name == "Object_7" or low.contains("bullet") or low.contains("casing") or low.contains("shell"):
				continue
			if model.is_ancestor_of(m):
				if m.is_visible_in_tree():
					cus_nodes.append(m)
			else:
				nat_nodes.append(m)
		var cus := _box(cus_nodes)
		var skel: Skeleton3D = vm.fps_hands.weapon.find_children("*", "Skeleton3D", true, false).front()
		var lw := Vector3.ZERO
		for i in skel.get_bone_count():
			if skel.get_bone_name(i).to_lower().begins_with("l_wrist"):
				lw = cam.to_local(skel.global_transform * skel.get_bone_global_pose(i).origin)
		var fam := "rifle"
		var idx: int = vm.current_inventory_idx
		if idx == vm.INV_INDEX_SMG: fam = "smg"
		elif idx == vm.INV_INDEX_SHOTGUN: fam = "shotgun"
		elif idx == vm.INV_INDEX_PISTOL: fam = "pistol"
		if wid == REF[fam]:
			ref_t[fam] = (lw - cus.position) / cus.size
		var t: Vector3 = ref_t.get(fam, (lw - cus.position) / cus.size)
		var target_cam := cus.position + t * cus.size
		var grip_l := pivot.to_local(cam.to_global(target_cam))
		lines.append('%s|%s|"grip_l": Vector3(%.4f, %.4f, %.4f),|desloc_cm=%.1f' % [wid, fam, grip_l.x, grip_l.y, grip_l.z, (target_cam - lw).length() * 100.0])
	FileAccess.open("res://_prints/grip_probe.txt", FileAccess.WRITE).store_string("\n".join(lines))
	get_tree().quit()
