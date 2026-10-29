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
