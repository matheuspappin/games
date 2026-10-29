# =============================================================================
# pip_scope_viewport.gd
# Gerenciador de SubViewport para Lunetas Picture-in-Picture (Dual Render)
# Fornece renderização secundária com FOV reduzido (zoom ótico), sincronizada
# com a câmera principal do jogador e otimizada (desligada fora do ADS).
# =============================================================================
class_name PipScopeViewport
extends SubViewport

@export var resolution: Vector2i = Vector2i(512, 512)
@export var default_scope_fov: float = 16.0 # FOV ampliado (ex: 16° = ~4.5x zoom)
@export var viewmodel_layer: int = 2        # Camada visual do viewmodel a ser excluída

var main_camera: Camera3D = null
var scope_camera: Camera3D = null
var current_optic: Node = null
var is_active: bool = false

func _ready() -> void:
	size = resolution
	own_world_3d = false
	transparent_bg = false
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	
	# Criar ou obter Camera3D da luneta
	scope_camera = get_node_or_null("ScopeCamera3D") as Camera3D
	if not scope_camera:
		scope_camera = Camera3D.new()
		scope_camera.name = "ScopeCamera3D"
		add_child(scope_camera)
	
	scope_camera.fov = default_scope_fov
	scope_camera.near = 0.05
	scope_camera.far = 1000.0
	
	# Configurar Cull Mask: Renderizar tudo EXCETO a camada do viewmodel da arma/mãos
	# (Camada 2 excluída para que a luneta não renderize a si mesma ou a arma)
	scope_camera.cull_mask = ~(1 << (viewmodel_layer - 1))
	
	# Descobrir a câmera principal automaticamente se não estiver configurada
	if not main_camera:
		var p = get_parent()
		if p is Camera3D:
			main_camera = p
		elif get_viewport():
			main_camera = get_viewport().get_camera_3d()

func _process(_delta: float) -> void:
	if render_target_update_mode == SubViewport.UPDATE_DISABLED:
		return

	if not main_camera and get_viewport():
		main_camera = get_viewport().get_camera_3d()

	if main_camera and scope_camera:
		# Copia orientação e posição da câmera principal
		scope_camera.global_transform = main_camera.global_transform

## Ativa a renderização da luneta para o acessório especificado
func activate_scope(optic: Node, target_fov: float = 16.0) -> void:
	current_optic = optic
	is_active = true
	if scope_camera:
		scope_camera.fov = target_fov
	render_target_update_mode = SubViewport.UPDATE_ALWAYS

## Desativa a renderização do SubViewport (Zero custo de GPU no Hip-Fire)
func deactivate_scope(optic: Node = null) -> void:
	if optic == null or current_optic == optic:
		current_optic = null
		is_active = false
		render_target_update_mode = SubViewport.UPDATE_DISABLED

## Ajusta a intensidade de ADS (permite desativar quando ads_amount cai a 0)
func set_ads_amount(ads_amount: float) -> void:
	if ads_amount > 0.02:
		if render_target_update_mode != SubViewport.UPDATE_ALWAYS:
			render_target_update_mode = SubViewport.UPDATE_ALWAYS
			is_active = true
	else:
		if render_target_update_mode != SubViewport.UPDATE_DISABLED:
			render_target_update_mode = SubViewport.UPDATE_DISABLED
			is_active = false

## Retorna a textura de renderização da luneta
func get_scope_texture() -> ViewportTexture:
	return get_texture()
