# =============================================================================
# pip_scope_attachment.gd
# Script para Lunetas e Miras Ópticas com suporte a Picture-in-Picture (Dual Render)
# Trata miras que possuem malha de lente ou que são totalmente "fechadas"
# (gerando proceduralmente o disco ocular frontal que projeta a visão ampliada).
# =============================================================================
class_name PipScopeAttachment
extends Node3D

@export var scope_name: String = "TacticalScope"
@export var magnification_fov: float = 16.0       # FOV da luneta (16° ~4.5x, 22° ~3x)
@export var reticle_texture: Texture2D = null
@export var reticle_color: Color = Color(1.0, 0.15, 0.15, 1.0)
@export var reticle_scale: float = 1.0
@export var reticle_energy: float = 2.5
@export var vignette_radius: float = 0.485
@export var vignette_feather: float = 0.04
@export var edge_distortion: float = 0.12

# Configuração para miras fechadas sem malha de lente original
@export var auto_create_lens_if_missing: bool = true
@export var procedural_lens_radius: float = 0.028
@export var procedural_lens_offset: Vector3 = Vector3(0, 0.005, 0.045) # Ocular traseira

var lens_mesh_instance: MeshInstance3D = null
var lens_material: ShaderMaterial = null
var scope_viewport: PipScopeViewport = null
var is_aiming: bool = false
var current_ads_amount: float = 0.0

const SCOPE_SHADER = preload("res://assets/shaders/pip_scope_lens.gdshader")

func _ready() -> void:
	if not reticle_texture:
		reticle_texture = load("res://assets/textures/optics/reticle_acog.png") as Texture2D

	_find_or_create_lens_mesh()
	_setup_lens_material()

func _exit_tree() -> void:
	if scope_viewport:
		scope_viewport.deactivate_scope(self)

## Localiza a malha de lente existente ou cria o disco ocular caso a mira seja fechada
func _find_or_create_lens_mesh() -> void:
	# 1. Tentar encontrar malha de lente existente (ex: GlassLens nos .tscn)
	lens_mesh_instance = find_child("GlassLens", true, false) as MeshInstance3D
	if not lens_mesh_instance:
		lens_mesh_instance = find_child("*Lens*", true, false) as MeshInstance3D
	if not lens_mesh_instance:
		lens_mesh_instance = find_child("*Glass*", true, false) as MeshInstance3D

	# 2. Caso a mira seja um modelo fechado (sem interior vazado e sem lente):
	if not lens_mesh_instance and auto_create_lens_if_missing:
		lens_mesh_instance = MeshInstance3D.new()
		lens_mesh_instance.name = "ProceduralPipLens"
		
		var quad = QuadMesh.new()
		quad.size = Vector2(procedural_lens_radius * 2.0, procedural_lens_radius * 2.0)
		lens_mesh_instance.mesh = quad
		
		# Anexar ao Mount se existir, ou à raiz do acessório
		var mount = find_child("Mount", true, false)
		if mount:
			mount.add_child(lens_mesh_instance)
			lens_mesh_instance.position = procedural_lens_offset
		else:
			add_child(lens_mesh_instance)
			lens_mesh_instance.position = procedural_lens_offset

## Configura o material com o Shader PiP e associa o SubViewport
func _setup_lens_material() -> void:
	if not lens_mesh_instance:
		return

	# Obter ou aguardar o PipScopeViewport
	_resolve_scope_viewport()

	lens_material = ShaderMaterial.new()
	lens_material.shader = SCOPE_SHADER
	lens_material.set_shader_parameter("reticle_texture", reticle_texture)
	lens_material.set_shader_parameter("reticle_color", reticle_color)
	lens_material.set_shader_parameter("reticle_scale", reticle_scale)
	lens_material.set_shader_parameter("reticle_energy", reticle_energy)
	lens_material.set_shader_parameter("vignette_radius", vignette_radius)
	lens_material.set_shader_parameter("vignette_feather", vignette_feather)
	lens_material.set_shader_parameter("edge_distortion", edge_distortion)
	lens_material.set_shader_parameter("ads_blend", 0.0)

	if scope_viewport:
		lens_material.set_shader_parameter("scope_texture", scope_viewport.get_scope_texture())

	lens_mesh_instance.material_override = lens_material

## Busca o nó PipScopeViewport na árvore da câmera do jogador
func _resolve_scope_viewport() -> void:
	if scope_viewport:
		return

	# 1. Tentar encontrar na cena do jogador
	var cam = get_viewport().get_camera_3d() if get_viewport() else null
	if cam:
		scope_viewport = cam.get_node_or_null("PipScopeViewport") as PipScopeViewport
		if not scope_viewport:
			var p = cam.get_parent()
			if p:
				scope_viewport = p.find_child("PipScopeViewport", true, false) as PipScopeViewport

	# 2. Tentar via grupo
	if not scope_viewport and is_inside_tree():
		var nodes = get_tree().get_nodes_in_group("pip_scope_viewport")
		if nodes.size() > 0:
			scope_viewport = nodes[0] as PipScopeViewport

	if scope_viewport and lens_material:
		lens_material.set_shader_parameter("scope_texture", scope_viewport.get_scope_texture())

## Chamado pelo weapon_manager / fps_hands_viewmodel durante a transição ADS
func set_ads_state(aiming: bool, ads_amount: float) -> void:
	is_aiming = aiming
	current_ads_amount = ads_amount

	if not scope_viewport:
		_resolve_scope_viewport()

	if scope_viewport:
		if ads_amount > 0.02:
			scope_viewport.activate_scope(self, magnification_fov)
			scope_viewport.set_ads_amount(ads_amount)
		else:
			scope_viewport.deactivate_scope(self)

	# Atualizar parâmetros dinâmicos no shader
	if lens_material:
		lens_material.set_shader_parameter("ads_blend", clampf(ads_amount, 0.0, 1.0))
		# Aumentar emissão do retículo com profundidade de ADS
		lens_material.set_shader_parameter("reticle_energy", lerpf(1.5, reticle_energy, ads_amount))
