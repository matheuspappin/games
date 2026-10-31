# =============================================================================
# bot_rifle_3d.gd
# Modelo 3D de fuzil de assalto tático para Bots IA e visão em 3ª pessoa
# Exibe o fuzil ACR com silenciador e mira ótica, ocultando os braços 1P.
# =============================================================================
class_name BotRifle3D
extends Node3D

const CamoRegistry = preload("res://scripts/weapons/camo_registry.gd")

@onready var muzzle_flash: OmniLight3D = $MuzzleFlash
@onready var model_root: Node3D = $RifleModel

var _flash_timer: float = 0.0
var has_silencer: bool = false
var has_optic: bool = false
var camo_id: String = "default"

func apply_customization(p_has_silencer: bool, p_has_optic: bool, p_camo_id: String) -> void:
	has_silencer = p_has_silencer
	has_optic = p_has_optic
	camo_id = p_camo_id
	_update_visuals()

func _update_visuals() -> void:
	if not model_root:
		return
	var silencer = model_root.find_child("Object_13", true, false)
	if silencer:
		silencer.visible = has_silencer
	var scope = model_root.find_child("Object_14", true, false)
	if scope:
		scope.visible = has_optic
	
	var camo_info = CamoRegistry.get_camo(camo_id)
	for child in model_root.find_children("*", "MeshInstance3D", true, false):
		var mesh = child as MeshInstance3D
		if mesh and mesh.name != "Object_10":
			var mat = mesh.get_active_material(0)
			if mat is StandardMaterial3D:
				var m_dup = mat.duplicate() as StandardMaterial3D
				m_dup.albedo_color = camo_info["albedo"]
				m_dup.metallic = camo_info["metallic"]
				m_dup.roughness = camo_info["roughness"]
				mesh.set_surface_override_material(0, m_dup)

func _ready() -> void:
	if model_root:
		# Ocultar braços em primeira pessoa para deixar apenas o fuzil
		var arms = model_root.find_child("Object_10", true, false)
		if arms:
			arms.visible = false
		# Escala 3ª pessoa compacta: ~78cm total (proporcional ao CS)
		model_root.scale = Vector3(0.78, 0.78, 0.78)
		_update_visuals()
	
	if muzzle_flash:
		muzzle_flash.visible = false

func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and muzzle_flash:
			muzzle_flash.visible = false

func play_shoot_effect() -> void:
	# Flash de cano tático
	if muzzle_flash:
		muzzle_flash.visible = true
		_flash_timer = 0.06
		
	# Recoil visual suave da arma
	if model_root:
		var orig_z = model_root.position.z
		var tween = create_tween()
		tween.tween_property(model_root, "position:z", orig_z + 0.08, 0.04)
		tween.tween_property(model_root, "position:z", orig_z, 0.12)

# ── ARMA DA CLASSE EM 3ª PESSOA (outros jogadores) ────────────────────────────
# O fuzil genérico continua como suporte calibrado na mão do personagem; o modelo dele é
# escondido e entra a arma escolhida, montada pelo mesmo montador da 1ª pessoa e do Gunsmith.
# Alinhamento: traseira e topo iguais aos do fuzil de referência e comprimento proporcional
# ao tamanho real (em armas longas o cabo fica ~30 cm da traseira, então cai na mão).
const REF_VM_SCALE := 0.98  # tamanho real relativo do fuzil de referência (ACR)
var _loadout_key := ""
var _loadout_model: Node3D = null

func set_weapon_loadout(weapon_path: String, attachments: Dictionary = {}, p_camo: String = "default") -> void:
	var key := "%s|%s|%s" % [weapon_path, str(attachments), p_camo]
	if key == _loadout_key:
		return
	_loadout_key = key
	if _loadout_model and is_instance_valid(_loadout_model):
		_loadout_model.queue_free()
		_loadout_model = null
	if weapon_path == "" or not ResourceLoader.exists(weapon_path):
		if model_root: model_root.visible = true
		return
	var wrapper := WeaponVisualRegistry.instantiate_weapon_showcase(weapon_path)
	if not wrapper:
		if model_root: model_root.visible = true
		return
	add_child(wrapper)
	WeaponVisualRegistry.update_attachments(wrapper, attachments.get("optic", "none"), attachments.get("muzzle", "none"),
		attachments.get("mag", "none"), attachments.get("underbarrel", "none"), attachments.get("stock", "none"), attachments.get("grip", "none"))
	if p_camo != "default":
		WeaponVisualRegistry.apply_camo(wrapper, p_camo)
	var frame := _reference_frame()
	wrapper.transform = Transform3D.IDENTITY
	var wf := _frame_from_points(_points_local(wrapper))
	if not frame.is_empty() and not wf.is_empty():
		var cfg = WeaponVisualRegistry.get_weapon_config(weapon_path)
		var ratio: float = float(cfg.get("vm_scale", REF_VM_SCALE)) / REF_VM_SCALE
		var s: float = (float(frame["length"]) * ratio) / maxf(float(wf["length"]), 0.0001)
		# giro que leva frente/cima da arma nova na frente/cima do fuzil de referência
		var b_ref := Basis(frame["right"], frame["up"], -frame["front"])
		var b_new := Basis(wf["right"], wf["up"], -wf["front"])
		wrapper.transform = Transform3D((b_ref * b_new.inverse()) * Basis.from_scale(Vector3.ONE * s), Vector3.ZERO)
		var f: Vector3 = frame["front"]
		var u: Vector3 = frame["up"]
		var r: Vector3 = frame["right"]
		var e_f := _extent(wrapper, f)
		var e_u := _extent(wrapper, u)
		var e_r := _extent(wrapper, r)
		var rr: Vector2 = frame["right_range"]
		var rear_target: float = float(frame["rear"])
		if String(cfg.get("category", "")) == "secondary":
			# pistola não tem coronha: o cabo (~25% do comprimento a partir da traseira) vai onde fica
			# o cabo do fuzil de referência, ~29 cm da traseira
			rear_target += REF_GRIP_FROM_REAR - 0.25 * (e_f.y - e_f.x)
		wrapper.position += f * (rear_target - e_f.x) + u * (float(frame["top"]) - e_u.y) + r * ((rr.x + rr.y) * 0.5 - (e_r.x + e_r.y) * 0.5)
		if muzzle_flash:
			muzzle_flash.position = muzzle_flash.position - f * muzzle_flash.position.dot(f) + f * _extent(wrapper, f).y
	model_root.visible = false
	_loadout_model = wrapper

func _box_local(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var inv := global_transform.affine_inverse() if is_inside_tree() else Transform3D.IDENTITY
	for m in root.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null or not m.visible:
			continue
		var xf: Transform3D
		if is_inside_tree() and m.is_inside_tree():
			xf = inv * m.global_transform
		else:
			xf = Transform3D.IDENTITY
			var n: Node = m
			while n and n != self:
				if n is Node3D: xf = (n as Node3D).transform * xf
				n = n.get_parent()
		var b: AABB = xf * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

## Pontos (vértices) visíveis de um nó, no espaço deste suporte
func _points_local(root: Node3D) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for m in root.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null or not m.visible:
			continue
		var xf := Transform3D.IDENTITY
		var n: Node = m
		while n and n != self:
			if n is Node3D: xf = (n as Node3D).transform * xf
			n = n.get_parent()
		for sidx in m.mesh.get_surface_count():
			for v in m.mesh.surface_get_arrays(sidx)[Mesh.ARRAY_VERTEX]:
				pts.append(xf * v)
	return pts

## Menor e maior projeção dos pontos de um nó numa direção
func _extent(root: Node3D, dir: Vector3) -> Vector2:
	var lo := INF
	var hi := -INF
	for p in _points_local(root):
		var d := p.dot(dir)
		lo = minf(lo, d); hi = maxf(hi, d)
	return Vector2(lo, hi)

## Orientação descoberta pela geometria: comprimento = maior eixo, frente = ponta mais fina
## (cano), cima = lado do cano (pente e cabo ficam pendurados embaixo)
func _frame_from_points(pts: PackedVector3Array) -> Dictionary:
	if pts.size() < 10:
		return {}
	var bb := AABB(pts[0], Vector3.ZERO)
	for p in pts: bb = bb.expand(p)
	var ax := 0
	for i in 3:
		if bb.size[i] > bb.size[ax]: ax = i
	var axis := Vector3.ZERO
	axis[ax] = 1.0
	var others := [0, 1, 2]
	others.erase(ax)
	var lo: float = bb.position[ax]
	var hi: float = bb.end[ax]
	var cut := (hi - lo) * 0.06
	var lo_box := AABB(); var hi_box := AABB(); var lo_first := true; var hi_first := true
	for p in pts:
		if p[ax] < lo + cut:
			lo_box = AABB(p, Vector3.ZERO) if lo_first else lo_box.expand(p); lo_first = false
		elif p[ax] > hi - cut:
			hi_box = AABB(p, Vector3.ZERO) if hi_first else hi_box.expand(p); hi_first = false
	var lo_area := lo_box.size[others[0]] * lo_box.size[others[1]]
	var hi_area := hi_box.size[others[0]] * hi_box.size[others[1]]
	var front := axis if hi_area < lo_area else -axis
	var muzzle_box := hi_box if hi_area < lo_area else lo_box
	var up_ax: int = others[0] if bb.size[others[0]] > bb.size[others[1]] else others[1]
	var up := Vector3.ZERO
	up[up_ax] = 1.0 if muzzle_box.get_center()[up_ax] > bb.get_center()[up_ax] else -1.0
	var right := up.cross(-front).normalized()
	var ef := Vector2(INF, -INF); var eu := Vector2(INF, -INF); var er := Vector2(INF, -INF)
	for p in pts:
		var df := p.dot(front); var du := p.dot(up); var dr := p.dot(right)
		ef = Vector2(minf(ef.x, df), maxf(ef.y, df))
		eu = Vector2(minf(eu.x, du), maxf(eu.y, du))
		er = Vector2(minf(er.x, dr), maxf(er.y, dr))
	return {"front": front, "up": up, "right": right, "length": ef.y - ef.x, "rear": ef.x, "top": eu.y, "right_range": er}

var _ref_frame_cache := {}

## O fuzil de referência é uma malha com esqueleto (Sketchfab): os vértices crus estão em cm e o
## esqueleto reduz na hora de desenhar, então medir vértices engana (~100x). Usa as medidas reais
## documentadas: ~78 cm, frente para -Z com o cano em z = -0,75 (onde fica o clarão), cima +Y.
const REF_FRONT_Z := -0.75
const REF_LENGTH := 0.78
const REF_TOP_Y := 0.11
const REF_GRIP_FROM_REAR := 0.29  # cabo da ACR de referência, medido na sonda de pegada
func _reference_frame() -> Dictionary:
	if _ref_frame_cache.is_empty():
		var f := Vector3(0, 0, -1)
		_ref_frame_cache = {"front": f, "up": Vector3.UP, "right": Vector3.RIGHT, "length": REF_LENGTH,
			"rear": (REF_FRONT_Z + REF_LENGTH) * -1.0, "top": REF_TOP_Y, "right_range": Vector2(-0.02, 0.02)}
	return _ref_frame_cache
