# =============================================================================
# fps_hands_viewmodel.gd
# Viewmodel Unificado de 1ª Pessoa com Mãos Táticas Compartilhadas
# Baseado no asset FPS Hands (Bytez) integrado ao WeaponManager do projeto
# =============================================================================
class_name FpsHandsViewModel
extends Node3D

const CamoRegistry = preload("res://scripts/weapons/camo_registry.gd")
const WeaponVisualRegistry = preload("res://scripts/weapons/weapon_visual_registry.gd")

@export var camera: Camera3D

var fps_hands: Node3D = null
var current_inventory_idx: int = 0
var is_ads: bool = false

# Mapeamento de categorias/IDs de armas para índices no inventário do FpsHands
# 0 = AK74 (Fuzil Primário)
# 1 = C19 (Pistola Secundária)
# 2 = Knife (Corpo a corpo)
# 3 = SMG45 (Submetralhadora)
# 4 = LMG63 (Metralhadora leve)
# 5 = Sawnoff (Escopeta)
const INV_INDEX_AK      = 0
const INV_INDEX_PISTOL  = 1
const INV_INDEX_KNIFE   = 2
const INV_INDEX_SMG     = 3
const INV_INDEX_LMG     = 4
const INV_INDEX_SHOTGUN = 5

func _ready() -> void:
	if not camera:
		var p = get_parent()
		while p != null:
			if p is Camera3D:
				camera = p
				break
			p = p.get_parent()
		if not camera and get_viewport():
			camera = get_viewport().get_camera_3d()

	process_priority = 1000 # Executar após AnimationTrees dos braços para garantir travamento coaxial sem deriva
	visibility_changed.connect(_sync_fps_hands_visibility)
	if not fps_hands or not is_instance_valid(fps_hands):
		_initialize_fps_hands()
	if current_weapon_data:
		equip_weapon_data(current_weapon_data)

func _sync_fps_hands_visibility() -> void:
	if fps_hands and is_instance_valid(fps_hands):
		fps_hands.visible = is_visible_in_tree()

func _initialize_fps_hands() -> void:
	if fps_hands and is_instance_valid(fps_hands):
		return

	# Destruir quaisquer instâncias órfãs prévias de FpsHandsInstance
	for child in get_children():
		if child.name.begins_with("FpsHands") or "@Node3D@" in child.name:
			remove_child(child)
			child.queue_free()

	var fps_hands_script = load("res://addons/fps-hands/fps-hands.gd")
	if not fps_hands_script:
		push_error("[FpsHandsViewModel] Falha ao carregar addons/fps-hands/fps-hands.gd")
		return

	fps_hands = fps_hands_script.new()
	fps_hands.name = "FpsHandsInstance"
	fps_hands.camera = camera
	fps_hands.sway = false # Sway e bobbing suaves são processados 1:1 pelo WeaponRig da câmera
	fps_hands.shake = false
	fps_hands.recoil = false # Recoil físico controlado pelo Player/WeaponManager
	fps_hands.ads_dynamic_fov = false # FOV controlado unicamente pelo WeaponManager / Player para evitar conflito e tremedeira

	# Desativar processamento autônomo de input para evitar conflitos de tiro/munição e cycling de armas
	fps_hands.action_fire = ""
	fps_hands.action_reload = ""
	fps_hands.action_ads = ""
	fps_hands.action_melee = ""
	fps_hands.action_next_weapon = ""
	fps_hands.action_previous_weapon = ""

	# Configurar inventário modular de armas
	fps_hands.inventory = {
		"weapons": [
			[3, -1], # 0: AK74 (Fuzil)
			[1, -1], # 1: C19 (Pistola)
			[0, -1], # 2: Faca
			[2, -1], # 3: SMG45
			[4, -1], # 4: LMG63
			[5, -1], # 5: Sawnoff Shotgun
		],
		"ammo": {
			"none": 0,
			"rifle": 999,
			"9mm": 999,
			"shell": 999
		}
	}

	add_child(fps_hands)
	fps_hands.rotation = Vector3(0, PI, 0) # Inversão de 180° para alinhar com a frente canônica (-Z) da câmera
	fps_hands.visible = is_visible_in_tree()
	fps_hands.set_process_input(false)
	fps_hands.set_process_unhandled_input(false)
	if not fps_hands.taking_weapon.is_connected(_on_fps_hands_taking_weapon):
		fps_hands.taking_weapon.connect(_on_fps_hands_taking_weapon)
	fps_hands.take_weapon(INV_INDEX_AK, true)
	_configure_weapon_hip_stance("acr68", INV_INDEX_AK)

var current_weapon_data: WeaponData = null
var current_custom_model_instance: Node3D = null
var current_equipped_wid: String = ""
var current_optic_instance: Node3D = null
var current_silencer_instance: Node3D = null
var current_camo_id: String = "default"
var current_optic_id: String = "red_dot"
var current_muzzle_id: String = "none"
var current_ads_amount: float = 0.0

# Deslocamentos calibrados do centro do retículo (lente/vidro) em relação à base do acessório óptico
const OPTIC_RETICLE_OFFSETS: Dictionary = {
	"optic_red_dot": Vector3(0.0, 0.027023, -0.010408),
	"red_dot":       Vector3(0.0, 0.027023, -0.010408),
	"optic_holo":    Vector3(0.0, 0.028389, -0.007019),
	"holo":          Vector3(0.0, 0.028389, -0.007019),
	"optic_acog":    Vector3(0.0, 0.018445, -0.031155),
	"acog":          Vector3(0.0, 0.018445, -0.031155),
	"optic_sniper":  Vector3(0.0, 0.018116, -0.008204),
	"sniper":        Vector3(0.0, 0.018116, -0.008204)
}

func _configure_weapon_hip_stance(wid: String, inv_idx: int) -> void:
	if not fps_hands or not is_instance_valid(fps_hands.weapon):
		return
	
	# Posição de empunhadura CoD Hip-Fire (em espaço local do fps_hands, rotacionado em Y=PI):
	# Com rotation.y = PI:
	# Local X = -Camera X (negativo no fps_hands = lado direito da tela)
	# Local Y = Camera Y (altura da arma na tela rebaixada para visão e mira desobstruídas)
	# Local Z = -Camera Z (positivo no fps_hands = à frente da câmera)
	var cfg = WeaponVisualRegistry.get_weapon_config(wid)
	var hip_pos: Vector3
	if cfg.has("hip_offset"):
		hip_pos = cfg["hip_offset"]
	else:
		# Fallback seguro por categoria caso a arma não defina hip_offset
		match inv_idx:
			INV_INDEX_PISTOL:
				hip_pos = Vector3(-0.060, -0.250, 0.320) # Pistolas mais próximas do centro/peito
			INV_INDEX_SMG:
				hip_pos = Vector3(-0.075, -0.280, 0.345) # Submetralhadoras compactas
			INV_INDEX_SHOTGUN:
				hip_pos = Vector3(-0.085, -0.300, 0.365) # Escopetas
			INV_INDEX_LMG:
				hip_pos = Vector3(-0.095, -0.315, 0.370) # LMGs pesadas empunhadas firmes
			INV_INDEX_KNIFE:
				hip_pos = Vector3(-0.055, -0.220, 0.300) # Faca de combate
			_:
				hip_pos = Vector3(-0.092, -0.315, 0.360) # Rifles de assalto padrão CoD
	
	fps_hands.weapon.position = hip_pos
	fps_hands.start_pos = hip_pos

func _on_fps_hands_taking_weapon() -> void:
	if current_weapon_data:
		var wid = current_weapon_data.weapon_id.to_lower()
		_configure_weapon_hip_stance(wid, current_inventory_idx)
		_update_custom_weapon_visual(wid)
		_apply_camo.call_deferred()
		_update_weapon_silencer.call_deferred()
		_update_weapon_optic.call_deferred()
		update_ads_alignment.call_deferred()

func set_weapon_customization(p_camo: String, p_optic: String, p_muzzle: String) -> void:
	current_camo_id = p_camo if p_camo != "" else "default"
	current_optic_id = p_optic if p_optic != "" else "none"
	current_muzzle_id = p_muzzle if p_muzzle != "" else "none"
	_apply_camo()
	_update_weapon_silencer()
	_update_weapon_optic()

func equip_weapon_data(data: WeaponData) -> void:
	current_weapon_data = data
	if not fps_hands or not is_instance_valid(fps_hands):
		_initialize_fps_hands()
	if not fps_hands or not is_instance_valid(fps_hands):
		return

	var target_idx = INV_INDEX_AK
	var wid = ""
	if data:
		wid = data.weapon_id.to_lower()
		var cat = data.category
		if wid == "knife" or wid == "melee" or wid == "faca" or cat == WeaponData.WeaponCategory.MELEE:
			target_idx = INV_INDEX_KNIFE
		elif wid == "pistol" or wid == "m1911" or wid == "beretta" or wid == "c19" or wid == "pistol_m9" or wid == "deagle" or cat == WeaponData.WeaponCategory.PISTOL:
			target_idx = INV_INDEX_PISTOL
		elif wid == "shotgun" or wid == "sawnoff" or wid == "spas12" or wid == "krm262" or cat == WeaponData.WeaponCategory.SHOTGUN:
			target_idx = INV_INDEX_SHOTGUN
		elif wid == "smg" or wid == "smg45" or wid == "mp7" or wid == "pp90m1" or wid == "vmp" or cat == WeaponData.WeaponCategory.SMG:
			target_idx = INV_INDEX_SMG
		elif wid == "rpk":
			target_idx = INV_INDEX_AK
		elif wid == "lmg" or wid == "lmg63" or cat == WeaponData.WeaponCategory.LMG:
			target_idx = INV_INDEX_AK
		elif cat == WeaponData.WeaponCategory.SNIPER:
			target_idx = INV_INDEX_AK # Snipers usam a animação e pose de fuzil bifacial tático
		else:
			target_idx = INV_INDEX_AK

	if current_inventory_idx != target_idx:
		current_inventory_idx = target_idx
		fps_hands.take_weapon(current_inventory_idx, true)

	_configure_weapon_hip_stance(wid, current_inventory_idx)

	# Atualizar modelo 3D exclusivo da arma nas mãos
	_update_custom_weapon_visual(wid)

	# Se a arma NÃO possui mira óptica, destruir a mira e calcular ADS de ferro
	if not current_weapon_data or not current_weapon_data.has_optic or current_optic_id == "none":
		if current_optic_instance and is_instance_valid(current_optic_instance):
			current_optic_instance.queue_free()
			current_optic_instance = null
		update_ads_alignment.call_deferred()
	else:
		_update_weapon_optic.call_deferred()

	_apply_camo.call_deferred()
	_update_weapon_silencer.call_deferred()

func _update_custom_weapon_visual(wid: String) -> void:
	if not fps_hands or not is_instance_valid(fps_hands):
		return
	if not fps_hands.weapon or not is_instance_valid(fps_hands.weapon):
		call_deferred("_update_custom_weapon_visual", wid)
		return

	current_equipped_wid = wid
	var cfg = WeaponVisualRegistry.get_weapon_config(wid)
	var has_arms = cfg.get("has_arms", true)

	var mount_node = _get_optic_mount_node()
	if not mount_node:
		return

	# Destruir modelo customizado prévio se houver
	if current_custom_model_instance and is_instance_valid(current_custom_model_instance):
		var old = current_custom_model_instance
		current_custom_model_instance = null
		if old.get_parent():
			old.get_parent().remove_child(old)
		old.queue_free()

	# Garantir que nenhum resíduo de CustomWeaponModel permaneça no mount_node
	for c in mount_node.get_children():
		if c.name.begins_with("CustomWeaponModel"):
			mount_node.remove_child(c)
			c.queue_free()

	# Se for uma arma com modelo clean 3D exclusivo (Snipers, M4A1, SCAR-H, Man-O-War, Deagle, MP7, PP90M1, VMP, SPAS-12, KRM-262, RPK)
	if not has_arms:
		var custom_model = WeaponVisualRegistry.instantiate_weapon_for_hand(wid)
		if custom_model:
			# 1. Ocultar malhas e nós originais da arma base do Bytez, mantendo as mãos (Object_7) sempre visíveis
			var ak_node = fps_hands.find_child("ak", true, false)
			if ak_node:
				for ak_child in ak_node.get_children():
					if ak_child.name != "base":
						ak_child.visible = false

			for child in fps_hands.find_children("*", "MeshInstance3D", true, false):
				var mesh_inst = child as MeshInstance3D
				if mesh_inst and mesh_inst.name != "Object_7" and not mesh_inst.name.begins_with("Custom"):
					mesh_inst.visible = false
					mesh_inst.layers = 0 # Camada 0: Impede que qualquer câmera renderize o carregador/peças nativas da AK
				elif mesh_inst and mesh_inst.name == "Object_7":
					mesh_inst.visible = true
					mesh_inst.layers = 2 # Camada 2: Viewmodel 1P

			custom_model.name = "CustomWeaponModel"
			# Compensar a escala de 0.015 do nó raiz do Bytez
			var ws = fps_hands.weapon.scale.x if absf(fps_hands.weapon.scale.x) > 0.001 else 0.015
			var inv_ws = 1.0 / absf(ws)
			custom_model.scale = Vector3.ONE * inv_ws * float(cfg.get("vm_fit_scale", 1.0))
			
			# Posicionamento perfeitamente calibrado nas palmas das mãos
			var vm_pos = cfg.get("vm_offset", Vector3(0.0, 2.2, 3.5))
			custom_model.position = vm_pos
			mount_node.add_child(custom_model)
			WeaponManager.set_viewmodel_layers(custom_model, 2) # Camada 1P: fora da mira PiP e do mundo
			current_custom_model_instance = custom_model
			_setup_left_hand_ik(cfg)
			_setup_mag_follower()
		else:
			# Failsafe: se falhar o carregamento do modelo customizado, mantém a arma original visível
			for child in fps_hands.find_children("*", "MeshInstance3D", true, false):
				var mesh_inst = child as MeshInstance3D
				if mesh_inst and not mesh_inst.name.begins_with("Custom"):
					mesh_inst.visible = true
					mesh_inst.layers = 2 # Restaura a camada do viewmodel (antes ficava 0 e a arma sumia)
	else:
		_setup_left_hand_ik({})
		_mag_native = null
		_mag_custom.clear()
		# Arma padrão Bytez com braços nativos: reexibir as malhas da arma
		for child in fps_hands.find_children("*", "MeshInstance3D", true, false):
			var mesh_inst = child as MeshInstance3D
			if mesh_inst and not mesh_inst.name.begins_with("Custom"):
				mesh_inst.visible = true
				mesh_inst.layers = 2 # Restaura a camada do viewmodel (antes ficava 0 e a arma sumia)

	update_ads_alignment.call_deferred()

# ── MÃO ESQUERDA: IK DE DOIS OSSOS (braço → antebraço → punho) ATÉ O PONTO GripL DA ARMA ──
# A animação base é da arma nativa da família; o IK leva o punho esquerdo até o guarda-mão
# do modelo customizado. Desliga suavemente em recarga, troca de arma e golpe de faca.
const LEFT_IK_OFF_STATES := ["reload", "reload_full", "take", "hide", "melee"]
var left_hand_ik: SkeletonModifier3D = null
var left_hand_ik_weight: float = 0.0

func _find_bone_prefix(skel: Skeleton3D, prefix: String) -> String:
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).begins_with(prefix):
			return skel.get_bone_name(i)
	return ""

func _setup_left_hand_ik(cfg: Dictionary) -> void:
	if left_hand_ik and is_instance_valid(left_hand_ik):
		left_hand_ik.queue_free()
	left_hand_ik = null
	left_hand_ik_weight = 0.0
	if not current_custom_model_instance or not is_instance_valid(current_custom_model_instance):
		return
	var pivot: Node3D = current_custom_model_instance.get_node_or_null("Pivot")
	if not pivot or not fps_hands or not is_instance_valid(fps_hands.weapon):
		return
	var sk_list = fps_hands.weapon.find_children("*", "Skeleton3D", true, false)
	if sk_list.is_empty():
		return
	var skel: Skeleton3D = sk_list.front()
	var root_bone := _find_bone_prefix(skel, "L_arm")
	var mid_bone := _find_bone_prefix(skel, "L_elbow")
	var end_bone := _find_bone_prefix(skel, "L_wrist")
	if root_bone == "" or mid_bone == "" or end_bone == "":
		return
	# Sem "grip_l" (pistolas): o IK existe só para a recarga e fica desligado no resto do tempo
	var marker := pivot.get_node_or_null("GripL") as Marker3D
	if cfg.has("grip_l"):
		if not marker:
			marker = Marker3D.new()
			marker.name = "GripL"
			pivot.add_child(marker)
		marker.position = cfg["grip_l"]
	var ik = LeftHandIK.new()
	ik.name = "LeftHandIK"
	skel.add_child(ik)
	ik.setup(skel, root_bone, mid_bone, end_bone, marker)
	ik.influence = 0.0
	left_hand_ik = ik

func _update_left_hand_ik(delta: float) -> void:
	if not left_hand_ik or not is_instance_valid(left_hand_ik):
		return
	var want := 1.0
	var st := ""
	if fps_hands and fps_hands.state_machine:
		st = str(fps_hands.state_machine.get_current_node())
		if st in LEFT_IK_OFF_STATES:
			want = 0.0
	var grip_marker = current_custom_model_instance.get_node_or_null("Pivot/GripL") if current_custom_model_instance and is_instance_valid(current_custom_model_instance) else null
	if st.begins_with("reload") and _reload_ik_weight > 0.0 and _reload_hand_target:
		# recarga: leva a mão do pente original (invisível) até o pente do modelo
		left_hand_ik.target = _reload_hand_target
		left_hand_ik.influence = _reload_ik_weight
		left_hand_ik_weight = 0.0
		return
	if grip_marker:
		left_hand_ik.target = grip_marker
	else:
		want = 0.0
	left_hand_ik_weight = move_toward(left_hand_ik_weight, want, delta * 6.0)
	left_hand_ik.influence = left_hand_ik_weight

# ── RECARGA: PENTE DO MODELO CUSTOMIZADO SEGUE O PENTE DA ANIMAÇÃO ORIGINAL ──
# As animações do addon movem o pente da arma nativa (escondida): "mag" (AK, LMG) ou "clip"
# (SMG, pistola). Antes, a mão ia até esse pente invisível e "pegava o ar". Agora o pente do
# modelo customizado copia, a cada frame, o deslocamento do pente nativo em relação ao repouso.
const NATIVE_MAG_NAMES := ["mag", "clip"]
var _mag_native: Node3D = null
var _mag_native_rest := Transform3D()
var _mag_rest_ok := false
var _mag_custom: Array = []        # [{node, rest_local}]
var _reload_hand_target: Node3D = null
var _reload_ik_weight := 0.0       # 0..1: quanto o IK leva a mão do pente original ao pente do modelo

func _mesh_center(n: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	var list: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		list.append(n)
	for m in list:
		var b: AABB = m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box.get_center() if not first else n.global_position

func _setup_mag_follower() -> void:
	_mag_native = null
	_mag_rest_ok = false
	_mag_custom.clear()
	if not fps_hands or not is_instance_valid(fps_hands.weapon) or not current_custom_model_instance:
		return
	for nm in NATIVE_MAG_NAMES:
		var n = fps_hands.weapon.find_child(nm, true, false)
		if n is Node3D:
			_mag_native = n
			break
	if not _mag_native:
		return
	for c in current_custom_model_instance.find_children("*", "Node3D", true, false):
		var low := String(c.name).to_lower()
		if low.begins_with("magazine") and not (c.get_parent() and String(c.get_parent().name).to_lower().begins_with("magazine")):
			_mag_custom.append({"node": c, "rest": c.transform})

func _update_mag_follower() -> void:
	if not _mag_native or not is_instance_valid(_mag_native) or _mag_custom.is_empty():
		return
	var st := ""
	if fps_hands and fps_hands.state_machine:
		st = str(fps_hands.state_machine.get_current_node())
	# repouso registrado na primeira vez que a arma fica parada (idle)
	if not _mag_rest_ok:
		if st == "idle":
			_mag_native_rest = _mag_native.transform
			_mag_rest_ok = true
		return
	var p_parent := _mag_native.get_parent() as Node3D
	if not p_parent:
		return
	var delta_local: Transform3D = _mag_native.transform * _mag_native_rest.affine_inverse()
	var reloading := st.begins_with("reload")
	var pg := p_parent.global_transform
	var delta_world: Transform3D = pg * delta_local * pg.affine_inverse()
	for e in _mag_custom:
		var node: Node3D = e["node"]
		if not is_instance_valid(node):
			continue
		node.transform = e["rest"]
		if reloading:
			node.global_transform = delta_world * node.global_transform
	_update_reload_hand_target(reloading)

func _update_reload_hand_target(reloading: bool) -> void:
	_reload_ik_weight = 0.0
	if not reloading or _mag_custom.is_empty() or not left_hand_ik or not is_instance_valid(left_hand_ik):
		return
	var skel := left_hand_ik.get_parent() as Skeleton3D
	if not skel:
		return
	var wi := -1
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).begins_with("L_wrist"):
			wi = i
			break
	if wi < 0:
		return
	var wrist := skel.global_transform * skel.get_bone_global_pose(wi).origin
	var nat := _mesh_center(_mag_native)
	var cus := _mesh_center(_mag_custom[0]["node"])
	# só quando a mão está segurando o pente original; solta suavemente quando ela se afasta.
	# Pistolas: a mão empurra o pente por baixo do cabo, então o alcance é maior.
	var d := wrist.distance_to(nat)
	var is_pistol := current_inventory_idx == INV_INDEX_PISTOL
	var full_at := 0.18 if is_pistol else 0.10
	var fade := 0.12 if is_pistol else 0.15
	_reload_ik_weight = clampf(1.0 - (d - full_at) / fade, 0.0, 1.0)
	if _reload_ik_weight <= 0.0:
		return
	if not _reload_hand_target or not is_instance_valid(_reload_hand_target):
		_reload_hand_target = Node3D.new()
		_reload_hand_target.name = "ReloadHandTarget"
		add_child(_reload_hand_target)
	_reload_hand_target.global_position = wrist + (cus - nat)

func _get_optic_mount_node() -> Node3D:
	if not fps_hands or not is_instance_valid(fps_hands.weapon):
		return null
	var base_node = fps_hands.weapon.find_child("base", true, false)
	if base_node and base_node is Node3D:
		return base_node
	return fps_hands.weapon

func _apply_camo() -> void:
	if not fps_hands or not is_instance_valid(fps_hands.weapon):
		return
	var camo_info = CamoRegistry.get_camo(current_camo_id)
	var is_factory: bool = camo_info.get("id", "default") == "default"

	# Se temos modelo customizado, aplicar camo nele prioritariamente
	var target_root: Node = fps_hands.weapon
	if current_custom_model_instance and is_instance_valid(current_custom_model_instance):
		target_root = current_custom_model_instance

	# Percorrer partes da arma sem alterar os braços do operador
	for child in target_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst = child as MeshInstance3D
		if mesh_inst and mesh_inst.mesh and not mesh_inst.name.to_lower().contains("arm") and not mesh_inst.name.to_lower().contains("hand") and mesh_inst.name != "Object_7":
			var surf_count = mesh_inst.mesh.get_surface_count()
			for s in range(surf_count):
				# Padrão de fábrica: mantém o material original (cor, metal e rugosidade do modelo).
				# Antes a cor era trocada por branco e armas sem textura (M4A1, RPK) ficavam brancas.
				var meta_key := "_orig_override_%d" % s
				if not mesh_inst.has_meta(meta_key):
					mesh_inst.set_meta(meta_key, mesh_inst.get_surface_override_material(s))
				var orig_ovr = mesh_inst.get_meta(meta_key)
				if is_factory:
					mesh_inst.set_surface_override_material(s, orig_ovr)
					continue
				var mat = orig_ovr if orig_ovr else mesh_inst.mesh.surface_get_material(s)
				if mat is ShaderMaterial:
					var m_dup = mat.duplicate() as ShaderMaterial
					m_dup.set_shader_parameter("albedo", camo_info["albedo"])
					m_dup.set_shader_parameter("metallic", camo_info["metallic"])
					m_dup.set_shader_parameter("roughness", camo_info["roughness"])
					mesh_inst.set_surface_override_material(s, m_dup)
				elif mat is StandardMaterial3D:
					var m_dup = mat.duplicate() as StandardMaterial3D
					# Com textura a cor multiplica a textura; sem textura a cor da camo substitui a do material
					m_dup.albedo_color = camo_info["albedo"]
					m_dup.metallic = camo_info["metallic"]
					m_dup.roughness = camo_info["roughness"]
					mesh_inst.set_surface_override_material(s, m_dup)

func _update_weapon_silencer() -> void:
	var muzzle_scene_path = ""
	if current_muzzle_id != "none" and WeaponVisualRegistry.ATTACHMENT_SCENES.has(current_muzzle_id):
		muzzle_scene_path = WeaponVisualRegistry.ATTACHMENT_SCENES[current_muzzle_id]
	elif current_muzzle_id == "muzzle_suppressor" or current_muzzle_id == "silencer":
		muzzle_scene_path = "res://scenes/weapons/attachments/muzzle_silencer.tscn"
	elif current_muzzle_id == "muzzle_compensator" or current_muzzle_id == "compensator":
		muzzle_scene_path = "res://scenes/weapons/attachments/muzzle_compensator.tscn"

	if muzzle_scene_path == "" or not ResourceLoader.exists(muzzle_scene_path):
		if current_silencer_instance and is_instance_valid(current_silencer_instance):
			current_silencer_instance.queue_free()
			current_silencer_instance = null
		_update_integrated_sights_visibility()
		return

	if not fps_hands or not is_instance_valid(fps_hands.weapon):
		return

	var muzzle = fps_hands.weapon.find_child("MuzzlePoint", true, false)
	if not muzzle:
		return

	if current_silencer_instance and is_instance_valid(current_silencer_instance) and current_silencer_instance.get_parent() == muzzle:
		return

	if current_silencer_instance and is_instance_valid(current_silencer_instance):
		current_silencer_instance.queue_free()
		current_silencer_instance = null

	var sc = load(muzzle_scene_path) as PackedScene
	if sc:
		var inst = sc.instantiate()
		var ws = fps_hands.weapon.scale.x if absf(fps_hands.weapon.scale.x) > 0.001 else 0.015
		inst.scale = Vector3.ONE / absf(ws)
		muzzle.add_child(inst)
		WeaponManager.set_viewmodel_layers(inst, 2)
		current_silencer_instance = inst
	_update_integrated_sights_visibility()

func _process(_delta: float) -> void:
	if fps_hands and is_instance_valid(fps_hands):
		fps_hands.rotation = Vector3(0, PI, 0)
	_update_left_hand_ik(_delta)
	_update_mag_follower()

	# ── SINCRONIZAÇÃO E ALINHAMENTO COAXIAL DE MIRA ADS ESTILO CALL OF DUTY ───
	# (sem arma equipada ainda: nada a alinhar; antes isso gerava um aviso por frame)
	if fps_hands and is_instance_valid(fps_hands.weapon) and current_equipped_wid != "":
		var cfg = WeaponVisualRegistry.get_weapon_config(current_equipped_wid)
		var rot_y = cfg.get("vm_rot_y", 180.0)
		var vm_rot = cfg.get("vm_rotation", Vector3.ZERO)

		var smooth_t = smoothstep(0.0, 1.0, current_ads_amount)

		# 1. Interpolação suave e sincronizada de posição 1:1 com a mira (sem chicoteio)
		if is_ads or current_ads_amount > 0.001:
			update_ads_alignment()
			fps_hands.weapon.position = fps_hands.start_pos.lerp(fps_hands.ads_pos, smooth_t)
		else:
			fps_hands.weapon.position = fps_hands.start_pos

		# 2. Rotação do modelo da arma: Hipfire angular -> ADS 100% reto coaxial com o centro da tela
		if current_custom_model_instance and is_instance_valid(current_custom_model_instance):
			var pivot = current_custom_model_instance.get_node_or_null("Pivot")
			if pivot and camera:
				if smooth_t >= 0.999:
					pivot.global_basis = camera.global_basis
				elif smooth_t <= 0.001:
					pivot.rotation_degrees = Vector3(0, rot_y, 0) + vm_rot
				else:
					pivot.rotation_degrees = Vector3(0, rot_y, 0) + vm_rot
					var hip_g_basis = pivot.global_basis.orthonormalized()
					var ads_g_basis = camera.global_basis.orthonormalized()
					pivot.global_basis = hip_g_basis.slerp(ads_g_basis, smooth_t)

	# Failsafe para garantir que o modelo 3D exclusivo permaneça anexado após troca de arma
	if current_weapon_data and fps_hands and is_instance_valid(fps_hands.weapon):
		var wid = current_weapon_data.weapon_id.to_lower()
		var cfg = WeaponVisualRegistry.get_weapon_config(wid)
		if not cfg.get("has_arms", true):
			if not current_custom_model_instance or not is_instance_valid(current_custom_model_instance) or current_custom_model_instance.get_parent() == null:
				_update_custom_weapon_visual(wid)
				_apply_camo()
		elif current_custom_model_instance and is_instance_valid(current_custom_model_instance):
			var old = current_custom_model_instance
			current_custom_model_instance = null
			if old.get_parent():
				old.get_parent().remove_child(old)
			old.queue_free()

	if current_weapon_data and current_weapon_data.has_optic and current_optic_id != "none":
		if fps_hands and is_instance_valid(fps_hands.weapon):
			if not is_instance_valid(current_optic_instance) or current_optic_instance.get_parent() == null:
				_update_weapon_optic()
	else:
		if current_optic_instance and is_instance_valid(current_optic_instance):
			current_optic_instance.queue_free()
			current_optic_instance = null
			update_ads_alignment()

func _update_weapon_optic() -> void:
	if not current_weapon_data or not current_weapon_data.has_optic or current_optic_id == "none":
		if current_optic_instance and is_instance_valid(current_optic_instance):
			current_optic_instance.queue_free()
			current_optic_instance = null
		update_ads_alignment()
		return

	if not fps_hands or not is_instance_valid(fps_hands.weapon):
		return

	# Destruir instância anterior se houver
	if current_optic_instance and is_instance_valid(current_optic_instance):
		current_optic_instance.queue_free()
		current_optic_instance = null

	var optic_scene_to_use: PackedScene = null
	if WeaponVisualRegistry.ATTACHMENT_SCENES.has(current_optic_id):
		var p = WeaponVisualRegistry.ATTACHMENT_SCENES[current_optic_id]
		if ResourceLoader.exists(p):
			optic_scene_to_use = load(p) as PackedScene
	if not optic_scene_to_use and current_weapon_data:
		optic_scene_to_use = current_weapon_data.optic_scene
	if not optic_scene_to_use:
		optic_scene_to_use = preload("res://scenes/weapons/attachments/optic_red_dot.tscn")
	
	var optic = optic_scene_to_use.instantiate()
	current_optic_instance = optic
	
	var cfg = WeaponVisualRegistry.get_weapon_config(current_equipped_wid)
	
	# Anexar mira diretamente ao nó Pivot do modelo da arma (para compartilhar escala, posição e recoil)
	if current_custom_model_instance and is_instance_valid(current_custom_model_instance):
		var pivot = current_custom_model_instance.get_node_or_null("Pivot")
		if pivot:
			pivot.add_child(optic)
			optic.scale = Vector3.ONE
			optic.rotation = Vector3.ZERO
			optic.position = cfg.get("socket_optic", Vector3(0, 0.065, 0))
		else:
			current_custom_model_instance.add_child(optic)
			optic.position = cfg.get("socket_optic", Vector3(0, 0.065, 0))
	else:
		var mount_node = _get_optic_mount_node()
		if mount_node:
			mount_node.add_child(optic)
			var ws = fps_hands.weapon.scale.x if absf(fps_hands.weapon.scale.x) > 0.001 else 0.015
			optic.scale = Vector3.ONE / absf(ws)
			optic.rotation = Vector3.ZERO
			optic.position = cfg.get("socket_optic", Vector3(0, 16.0, 20.0))
	
	# Controle anatômico: ocultar lunetas e miras de ferro conflitantes na presença de acessório óptico
	_update_integrated_sights_visibility()

	# Definir tipo de retículo conforme acessório
	if "optic_type" in optic:
		if current_optic_id == "optic_holo":
			optic.optic_type = OpticSight.Type.HOLOGRAPHIC
		elif current_optic_id == "optic_sniper":
			optic.optic_type = OpticSight.Type.SNIPER_SCOPE
		else:
			optic.optic_type = OpticSight.Type.RED_DOT

	# Garantir isolamento de camada visual (Camada 2 = Viewmodel) para câmeras PiP
	WeaponManager.set_viewmodel_layers(optic, 2)

	update_ads_alignment()

func _update_integrated_sights_visibility() -> void:
	if current_custom_model_instance and is_instance_valid(current_custom_model_instance):
		var pivot = current_custom_model_instance.get_node_or_null("Pivot")
		if pivot:
			WeaponVisualRegistry.update_integrated_sights_and_muzzle(pivot, current_optic_id, current_muzzle_id)

func update_ads_alignment() -> void:
	if not is_inside_tree():
		return
	if not fps_hands or not is_instance_valid(fps_hands.weapon):
		return

	var cam = camera
	if not cam and get_viewport():
		cam = get_viewport().get_camera_3d()
	if not cam:
		return

	var cfg = WeaponVisualRegistry.get_weapon_config(current_equipped_wid)
	var has_arms = cfg.get("has_arms", true)

	var has_optic = (current_optic_instance and is_instance_valid(current_optic_instance) and current_optic_id != "none")
	var target_depth: float = cfg.get("ads_depth", -0.36)
	if has_optic:
		if cfg.has("ads_depth_optic"):
			target_depth = cfg["ads_depth_optic"]
		elif current_optic_id in ["optic_sniper", "optic_acog"]:
			target_depth = -0.42
		else:
			target_depth = -0.34

	# Ponto focal no espaço da câmera: centralizado em X=0, Y=0
	var target_world = cam.to_global(Vector3(0.0, 0.0, target_depth))
	var target_sight_in_fps_hands = fps_hands.to_local(target_world)

	if not has_arms and current_custom_model_instance and is_instance_valid(current_custom_model_instance):
		var pivot = current_custom_model_instance.get_node_or_null("Pivot")
		if not pivot or not pivot.get_parent():
			return

		var sight_pivot_pos: Vector3 = Vector3.ZERO
		if has_optic:
			var opt_sock = cfg.get("socket_optic", Vector3(0, 0.065, 0))
			var ret_off = OPTIC_RETICLE_OFFSETS.get(current_optic_id, Vector3(0.0, 0.027023, -0.010408))
			sight_pivot_pos = opt_sock + ret_off
		else:
			sight_pivot_pos = cfg.get("socket_iron_ads", Vector3(0, 0.12, 0))

		# Rotação canônica de ADS: alinhamento 100% coaxial reto com a câmera
		var prev_global_basis = pivot.global_basis
		pivot.global_basis = cam.global_basis

		var sight_global_pos = pivot.to_global(sight_pivot_pos)
		var s_local = fps_hands.to_local(sight_global_pos)
		var sight_rel_weapon = s_local - fps_hands.weapon.position
		fps_hands.ads_pos = target_sight_in_fps_hands - sight_rel_weapon

		# Restaurar rotação interpolada de acordo com o estado e amount atual de ADS
		var smooth_t = smoothstep(0.0, 1.0, current_ads_amount)
		var rot_y = cfg.get("vm_rot_y", 180.0)
		var vm_rot = cfg.get("vm_rotation", Vector3.ZERO)
		if smooth_t >= 0.999:
			pivot.global_basis = cam.global_basis
		elif smooth_t <= 0.001:
			pivot.rotation_degrees = Vector3(0, rot_y, 0) + vm_rot
		else:
			pivot.rotation_degrees = Vector3(0, rot_y, 0) + vm_rot
			var hip_g_basis = pivot.global_basis.orthonormalized()
			var ads_g_basis = cam.global_basis.orthonormalized()
			pivot.global_basis = hip_g_basis.slerp(ads_g_basis, smooth_t)
	else:
		# Armas nativas do pack Bytez (com braços)
		var base_node = _get_optic_mount_node()
		if base_node:
			var sight_base_pos: Vector3 = Vector3.ZERO
			if has_optic:
				var opt_sock = cfg.get("socket_optic", Vector3(0, 16.0, 20.0))
				var ws = fps_hands.weapon.scale.x if absf(fps_hands.weapon.scale.x) > 0.001 else 0.015
				var ret_off = OPTIC_RETICLE_OFFSETS.get(current_optic_id, Vector3(0.0, 0.027023, -0.010408)) / absf(ws)
				sight_base_pos = opt_sock + ret_off
			else:
				sight_base_pos = cfg.get("socket_iron_ads", Vector3(0, 16.0, 30.0))

			var sight_global_pos = base_node.to_global(sight_base_pos)
			var s_local = fps_hands.to_local(sight_global_pos)
			var sight_rel_weapon = s_local - fps_hands.weapon.position
			fps_hands.ads_pos = target_sight_in_fps_hands - sight_rel_weapon
		elif fps_hands.weapon.has_meta("ads_pos"):
			fps_hands.ads_pos = fps_hands.weapon.get_meta("ads_pos")

func play_shoot() -> void:
	if fps_hands and is_instance_valid(fps_hands) and fps_hands.state_machine:
		fps_hands.state_machine.start("fire")

func play_reload() -> void:
	if fps_hands and is_instance_valid(fps_hands):
		fps_hands.reload()

func play_draw() -> void:
	if fps_hands and is_instance_valid(fps_hands) and fps_hands.state_machine:
		fps_hands.state_machine.travel("take")

func play_idle() -> void:
	if fps_hands and is_instance_valid(fps_hands) and fps_hands.state_machine:
		var curr = fps_hands.state_machine.get_current_node()
		if curr != "fire" and curr != "reload" and curr != "reload_full" and curr != "take" and curr != "hide" and curr != "melee":
			fps_hands.state_machine.travel("idle")

func play_walk() -> void:
	play_idle()

func play_sprint() -> void:
	play_idle()

func play_inspect() -> void:
	play_idle()

func play_melee() -> void:
	if fps_hands and is_instance_valid(fps_hands) and fps_hands.state_machine:
		fps_hands.state_machine.travel("melee")

func set_ads(aiming: bool, amount: float = -1.0) -> void:
	var amt: float = amount if amount >= 0.0 else (1.0 if aiming else 0.0)
	current_ads_amount = clampf(amt, 0.0, 1.0)
	var state_changed = (is_ads != aiming)
	is_ads = aiming

	if state_changed:
		update_ads_alignment()
		if fps_hands and is_instance_valid(fps_hands):
			if fps_hands.has_method("set_aim"):
				fps_hands.set_aim(aiming)
			else:
				fps_hands.aim(aiming)

	if current_optic_instance and current_optic_instance.has_method("set_ads_state"):
		current_optic_instance.set_ads_state(aiming, current_ads_amount)

# IK analítico de dois ossos da mão esquerda (classe interna: vai junto com este script no export)
class LeftHandIK extends SkeletonModifier3D:
	## IK analítico de dois ossos (braço -> antebraço -> punho) que roda depois da animação.
	## Mantém o plano do cotovelo da pose animada e leva o punho até `target`.

	var target: Node3D
	var root_idx := -1
	var mid_idx := -1
	var end_idx := -1

	func setup(skel: Skeleton3D, root_name: String, mid_name: String, end_name: String, target_node: Node3D) -> void:
		root_idx = skel.find_bone(root_name)
		mid_idx = skel.find_bone(mid_name)
		end_idx = skel.find_bone(end_name)
		target = target_node

	func _process_modification_with_delta(_delta: float) -> void:
		_solve()

	func _process_modification() -> void:
		_solve()

	func _solve() -> void:
		var skel := get_skeleton()
		if not skel or root_idx < 0 or mid_idx < 0 or end_idx < 0 or not is_instance_valid(target):
			return
		if not skel.is_inside_tree() or not target.is_inside_tree():
			return
		var ra := skel.get_bone_global_pose(root_idx)
		var rb := skel.get_bone_global_pose(mid_idx)
		var rc := skel.get_bone_global_pose(end_idx)
		var a := ra.origin
		var b := rb.origin
		var c := rc.origin
		var t: Vector3 = skel.global_transform.affine_inverse() * target.global_position
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
		var a_local := skel.get_bone_pose_rotation(root_idx)
		var b_local := skel.get_bone_pose_rotation(mid_idx)
		a_local = a_local * Quaternion((a_gr.inverse() * axis0).normalized(), ac_ab_1 - ac_ab_0)
		b_local = b_local * Quaternion((b_gr.inverse() * axis0).normalized(), ba_bc_1 - ba_bc_0)
		if axis1.length() > 0.000001:
			a_local = a_local * Quaternion((a_gr.inverse() * axis1.normalized()).normalized(), ac_at_0)
		skel.set_bone_pose_rotation(root_idx, a_local)
		skel.set_bone_pose_rotation(mid_idx, b_local)
