# =============================================================================
# optic_sight.gd
# Sistema de Mira Óptica 3D See-Through (Estilo Call of Duty)
# Fornece lente transparente, retículo holográfico/red dot iluminado e
# máscara de luneta telescópica.
# =============================================================================
class_name OpticSight
extends Node3D

enum Type { RED_DOT, HOLOGRAPHIC, SNIPER_SCOPE }

@export var optic_type: Type = Type.RED_DOT
@export var reticle_color: Color = Color(1.0, 0.15, 0.15, 1.0) # Vermelho tático COD
@export var reticle_size: float = 0.012
@export var glass_tint: Color = Color(0.85, 0.95, 1.0, 0.12)  # Vidro ótico transparente anti-reflexo
@export var lens_radius: float = 0.035

var glass_mesh: MeshInstance3D = null
var reticle_mesh: MeshInstance3D = null
var housing_mesh: MeshInstance3D = null
var scope_overlay: CanvasLayer = null

func _ready() -> void:
	_build_optic_mesh()
	if optic_type == Type.SNIPER_SCOPE:
		_setup_sniper_overlay()

func _build_optic_mesh() -> void:
	# 1. Base e Armação de Metal Tático (Housing / Anel da Mira)
	# 1. Base e Armação de Metal Tático (Housing / Anel da Mira)
	housing_mesh = MeshInstance3D.new()
	housing_mesh.name = "OpticHousing"
	
	var housing_mat = StandardMaterial3D.new()
	housing_mat.albedo_color = Color(0.08, 0.08, 0.09, 1.0)
	housing_mat.metallic = 0.85
	housing_mat.roughness = 0.35
	housing_mat.render_priority = 0
	
	# Anel vazado da moldura (TorusMesh vazado no centro para ver através)
	var ring_frame = TorusMesh.new()
	ring_frame.inner_radius = lens_radius
	ring_frame.outer_radius = lens_radius * 1.15
	ring_frame.rings = 32
	ring_frame.ring_segments = 24
	
	housing_mesh.mesh = ring_frame
	housing_mesh.material_override = housing_mat
	housing_mesh.rotation_degrees = Vector3(90, 0, 0) # Alinhado perpendicular ao olhar do jogador
	add_child(housing_mesh)
	
	# Base de montagem (Mount Clamp / Trilho Picatinny)
	var mount_mesh = MeshInstance3D.new()
	mount_mesh.name = "MountBase"
	var box = BoxMesh.new()
	box.size = Vector3(lens_radius * 1.2, 0.012, 0.04)
	mount_mesh.mesh = box
	mount_mesh.material_override = housing_mat
	mount_mesh.position = Vector3(0, -lens_radius * 1.05, 0)
	add_child(mount_mesh)

	# 2. Vidro Ótico Transparente (See-Through Glass)
	glass_mesh = MeshInstance3D.new()
	glass_mesh.name = "OpticalGlass"
	
	var glass_mat = StandardMaterial3D.new()
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.albedo_color = glass_tint
	glass_mat.metallic = 0.15
	glass_mat.roughness = 0.08
	glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	glass_mat.render_priority = 1
	
	var disc = CylinderMesh.new()
	disc.top_radius = lens_radius
	disc.bottom_radius = lens_radius
	disc.height = 0.002
	disc.radial_segments = 32
	
	glass_mesh.mesh = disc
	glass_mesh.material_override = glass_mat
	glass_mesh.rotation_degrees = Vector3(90, 0, 0)
	glass_mesh.position = Vector3(0, 0, 0)
	add_child(glass_mesh)

	# 3. Retículo Iluminado (Red Dot / Holo) no centro do vidro
	reticle_mesh = MeshInstance3D.new()
	reticle_mesh.name = "Reticle"
	
	var ret_mat = StandardMaterial3D.new()
	ret_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ret_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ret_mat.albedo_color = reticle_color
	ret_mat.emission_enabled = true
	ret_mat.emission = reticle_color
	ret_mat.emission_energy_multiplier = 4.5
	ret_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ret_mat.render_priority = 2
	
	if optic_type == Type.RED_DOT:
		var dot = SphereMesh.new()
		dot.radius = reticle_size * 0.4
		dot.height = reticle_size * 0.8
		reticle_mesh.mesh = dot
	elif optic_type == Type.HOLOGRAPHIC:
		var ring = TorusMesh.new()
		ring.inner_radius = reticle_size * 0.7
		ring.outer_radius = reticle_size * 0.95
		ring.rings = 16
		reticle_mesh.mesh = ring
		reticle_mesh.rotation_degrees = Vector3(90, 0, 0)
	else:
		# Crosshair fino de luneta
		var dot = SphereMesh.new()
		dot.radius = reticle_size * 0.25
		dot.height = reticle_size * 0.5
		reticle_mesh.mesh = dot
		
	reticle_mesh.material_override = ret_mat
	reticle_mesh.position = Vector3(0, 0, -0.001)
	add_child(reticle_mesh)

func _setup_sniper_overlay() -> void:
	scope_overlay = CanvasLayer.new()
	scope_overlay.layer = 10
	add_child(scope_overlay)
	
	var ctrl = Control.new()
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.visible = false
	ctrl.name = "ScopeOverlayControl"
	scope_overlay.add_child(ctrl)
	
	# Retículo customizado desenhado proceduralmente
	var drawer = SniperScopeDrawer.new()
	drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.add_child(drawer)

func set_ads_state(is_aiming: bool, ads_amount: float) -> void:
	# Ajustar brilho do retículo no ADS
	if reticle_mesh and reticle_mesh.material_override is StandardMaterial3D:
		var mat = reticle_mesh.material_override as StandardMaterial3D
		mat.emission_energy_multiplier = lerpf(2.5, 5.0, ads_amount)
	
	# No caso de luneta sniper, ativar overlay quando mira estiver profunda (> 0.75)
	if scope_overlay:
		var ctrl = scope_overlay.get_node_or_null("ScopeOverlayControl")
		if ctrl:
			ctrl.visible = ads_amount > 0.75
			ctrl.modulate.a = clampf((ads_amount - 0.75) * 4.0, 0.0, 1.0)

# ── DESENHADOR PROCEDURAL DA MÁSCARA DE LUNETA (COD SNIPER SCOPE) ─────────────
class SniperScopeDrawer extends Control:
	func _draw() -> void:
		var center = size * 0.5
		var radius = min(size.x, size.y) * 0.38
		
		# Anel preto externo (Scope Bezel / Vignette)
		var bg_color = Color(0.02, 0.02, 0.03, 0.98)
		# 4 retângulos cobrindo as bordas fora da lente circular
		draw_rect(Rect2(0, 0, size.x, center.y - radius), bg_color)
		draw_rect(Rect2(0, center.y + radius, size.x, size.y - (center.y + radius)), bg_color)
		draw_rect(Rect2(0, center.y - radius, center.x - radius, radius * 2.0), bg_color)
		draw_rect(Rect2(center.x + radius, center.y - radius, size.x - (center.x + radius), radius * 2.0), bg_color)
		
		# Borda chanfrada escura da luneta
		draw_arc(center, radius, 0, TAU, 64, Color(0.05, 0.05, 0.06, 1.0), 12.0)
		draw_arc(center, radius - 6.0, 0, TAU, 64, Color(0.12, 0.15, 0.18, 0.8), 2.0)
		
		# Retículo Mil-Dot fino preto
		var line_color = Color(0.08, 0.08, 0.08, 0.9)
		# Linha horizontal
		draw_line(Vector2(center.x - radius + 10, center.y), Vector2(center.x + radius - 10, center.y), line_color, 1.5)
		# Linha vertical
		draw_line(Vector2(center.x, center.y - radius + 10), Vector2(center.x, center.y + radius - 10), line_color, 1.5)
		
		# Ponto central vermelho de precisão
		draw_circle(center, 2.5, Color(1.0, 0.1, 0.1, 1.0))
		
		# Traços mil-dot de distância
		for d in [30, 60, 90, 120]:
			draw_line(Vector2(center.x - d, center.y - 4), Vector2(center.x - d, center.y + 4), line_color, 1.0)
			draw_line(Vector2(center.x + d, center.y - 4), Vector2(center.x + d, center.y + 4), line_color, 1.0)
			draw_line(Vector2(center.x - 4, center.y + d), Vector2(center.x + 4, center.y + d), line_color, 1.0)
