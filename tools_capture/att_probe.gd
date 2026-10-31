extends Node3D
# Mede o encaixe de cada acessório contra a arma (no espaço do Pivot): folgas e tamanhos.
@onready var vm = $Camera/WeaponRig/FpsHandsViewModel
var lines := []

func _ready() -> void:
	_run.call_deferred()

func _box(nodes: Array, inv: Transform3D) -> AABB:
	var box := AABB(); var first := true
	for m in nodes:
		if not m.is_visible_in_tree() or m.mesh == null: continue
		var b: AABB = inv * m.global_transform * m.get_aabb()
		box = b if first else box.merge(b); first = false
	return box

func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	for wid in ["m4a1", "ak47", "smg", "scar_h", "acr68", "rpk", "mp7", "vmp"]:
		vm.equip_weapon_data(load("res://resources/weapons/%s.tres" % wid))
		await get_tree().create_timer(1.6).timeout
		vm.set_weapon_customization("default", "none", "muzzle_suppressor", "mag_extended", "grip_vertical", "stock_heavy", "none")
		await get_tree().create_timer(0.5).timeout
		var model: Node3D = vm.current_custom_model_instance
		var pivot: Node3D = model.get_node("Pivot")
		var inv := pivot.global_transform.affine_inverse()
		var cont: Node3D = pivot.get_node_or_null("AttachmentContainer")
		var gun_nodes := []
		for m in pivot.find_children("*", "MeshInstance3D", true, false):
			if cont and cont.is_ancestor_of(m): continue
			gun_nodes.append(m)
		var gun := _box(gun_nodes, inv)
		var cfg = WeaponVisualRegistry.get_weapon_config(wid)
		var front := -1.0 if float(cfg.get("socket_muzzle", Vector3(0, 0, -1)).z) < 0.0 else 1.0
		var gun_front: float = gun.position.z if front < 0 else gun.end.z
		var gun_rear: float = gun.end.z if front < 0 else gun.position.z
		var out := "%s | arma comp=%.0fcm alt=%.0fcm" % [wid, gun.size.z * 100, gun.size.y * 100]
		for a in cont.get_children():
			var b := _box(a.find_children("*", "MeshInstance3D", true, false), inv)
			var slot := String(a.get_meta("slot", a.name))
			var a_rear: float = b.end.z if front < 0 else b.position.z
			var a_front: float = b.position.z if front < 0 else b.end.z
			var info := ""
			match slot:
				"muzzle": info = "folga_cano=%.1fcm" % ((a_rear - gun_front) * -front * 100.0)
				"stock": info = "folga_coronha=%.1fcm" % ((gun_rear - a_front) * -front * 100.0)
				_: info = "topo_vs_fundo_arma=%.1fcm" % ((b.end.y - gun.position.y) * 100.0)
			out += " | %s comp=%.0fcm %s" % [slot, b.size.z * 100, info]
		lines.append(out)
	FileAccess.open("res://_prints/att_probe.txt", FileAccess.WRITE).store_string("\n".join(lines))
	get_tree().quit()
