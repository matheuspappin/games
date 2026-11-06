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

func set_weapon_customization(p_camo: String, p_optic: String, p_muzzle: String, p_mag: String = "none", p_underbarrel: String = "none", p_stock: String = "none", p_grip: String = "none", p_barrel: String = "none") -> void:
	current_camo_id = p_camo if p_camo != "" else "default"
	current_optic_id = p_optic if p_optic != "" else "none"
	current_muzzle_id = p_muzzle if p_muzzle != "" else "none"
	current_attachments = {"mag": p_mag, "underbarrel": p_underbarrel, "stock": p_stock, "grip": p_grip, "barrel": p_barrel}
	_apply_camo()
	if current_custom_model_instance and is_instance_valid(current_custom_model_instance):
		_apply_attachments()
	else:
		_update_weapon_silencer()
	_update_weapon_optic()

# ── ACESSÓRIOS: MONTADOR ÚNICO (o mesmo da tela de Gunsmith) ──────────────────
var current_attachments := {"mag": "none", "underbarrel": "none", "stock": "none", "grip": "none"}

func _apply_attachments() -> void:
	if not current_custom_model_instance or not is_instance_valid(current_custom_model_instance):
		return
	# cano, pente, empunhadura, coronha e cabo pelo montador único; a mira segue no código de ADS
	WeaponVisualRegistry.update_attachments(current_custom_model_instance, "none", current_muzzle_id,
		current_attachments.get("mag", "none"), current_attachments.get("underbarrel", "none"),
		current_attachments.get("stock", "none"), current_attachments.get("grip", "none"), current_attachments.get("barrel", "none"))
	var cont = current_custom_model_instance.get_node_or_null("Pivot/AttachmentContainer")
	if cont:
		WeaponManager.set_viewmodel_layers(cont, 2)
	if current_silencer_instance and is_instance_valid(current_silencer_instance):
		current_silencer_instance.queue_free()
		current_silencer_instance = null
	_update_integrated_sights_visibility()
	_setup_mag_follower()
	# empunhadura vertical: a mão esquerda vai até ela
	var marker = current_custom_model_instance.get_node_or_null("Pivot/GripL") as Node3D
	var ub = cont.get_node_or_null("Att_underbarrel") if cont else null
	if marker:
		var cfg_l = WeaponVisualRegistry.get_weapon_config(current_equipped_wid)
		if ub and ub is Node3D:
			marker.global_position = _mesh_center(ub)
		elif cfg_l.has("grip_l"):
			marker.position = cfg_l["grip_l"]

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
	if not _optic_allowed() or current_optic_id == "none":
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
			if cfg.has("rig_fit"):
				# encaixe do Blender aplicado depois dos ajustes adiados da cena da arma (escala do Pivot etc.)
				_apply_rig_fit.call_deferred(custom_model, cfg["rig_fit"])
			WeaponManager.set_viewmodel_layers(custom_model, 2) # Camada 1P: fora da mira PiP e do mundo
			current_custom_model_instance = custom_model
			# Pose de mão do Blender já é a correta: sem IK da mão esquerda (só o da recarga)
			_setup_left_hand_ik({} if cfg.has("rig_fit") else cfg)
			_setup_mag_follower()
			_apply_attachments()
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

## Rotação da mão esquerda em volta da empunhadura vertical da família SMG, no espaço do glb da arma
const SMG_FIST_HAND := Quaternion(0.223010, -0.188218, -0.402611, 0.867609)

func _update_left_hand_ik(delta: float) -> void:
	if not left_hand_ik or not is_instance_valid(left_hand_ik):
		return
	if _reload_hand_target and is_instance_valid(_reload_hand_target) and _reload_hand_target.has_meta("hand_basis"):
		_reload_hand_target.remove_meta("hand_basis")
	var want := 1.0
	var st := ""
	if fps_hands and fps_hands.state_machine:
		st = str(fps_hands.state_machine.get_current_node())
		if st in LEFT_IK_OFF_STATES:
			want = 0.0
	var grip_marker = current_custom_model_instance.get_node_or_null("Pivot/GripL") if current_custom_model_instance and is_instance_valid(current_custom_model_instance) else null
	# Encaixe do Blender com correção da mão de apoio (ex.: punho na empunhadura vertical do modelo):
	# alvo = punho animado + deslocamento fixo no espaço da arma; liberado na recarga/troca/faca
	if _is_one_handed() and not st.begins_with("reload"):
		left_hand_ik_weight = move_toward(left_hand_ik_weight, 0.0, delta * 8.0)
		left_hand_ik.influence = left_hand_ik_weight
		return
	if _current_has_rig_fit() and not (st in LEFT_IK_OFF_STATES) and not st.begins_with("reload"):
		var cfg_s = WeaponVisualRegistry.get_weapon_config(current_weapon_data.weapon_id.to_lower())
		# empunhadura montada pelo Gunsmith: a mão esquerda vai até ela (como no CoD)
		var ub: Node3D = current_custom_model_instance.find_child("Att_underbarrel", true, false) as Node3D
		if ub and ub.is_visible_in_tree() and camera:
			var skel_g := left_hand_ik.get_parent() as Skeleton3D
			var ref_g := _rig_ref_mesh()
			if skel_g and ref_g:
				var wi_g := -1
				var pi_g := -1
				for i3 in skel_g.get_bone_count():
					var bn := skel_g.get_bone_name(i3)
					if wi_g < 0 and bn.begins_with("L_wrist"):
						wi_g = i3
					if pi_g < 0 and bn.begins_with("L_palm"):
						pi_g = i3
				if wi_g >= 0 and pi_g >= 0:
					if not _reload_hand_target or not is_instance_valid(_reload_hand_target):
						_reload_hand_target = Node3D.new()
						_reload_hand_target.name = "ReloadHandTarget"
						add_child(_reload_hand_target)
					var wpm_g: float = ref_g.global_basis.get_scale().x
					var wrist_gg := skel_g.global_transform * skel_g.get_bone_global_pose(wi_g).origin
					var palm_gg := skel_g.global_transform * skel_g.get_bone_global_pose(pi_g).origin
					# palma no terço superior da empunhadura, encostada pelo lado esquerdo
					var palm_tgt: Vector3 = ub.global_position - camera.global_basis.y.normalized() * 0.03 * wpm_g - camera.global_basis.x.normalized() * 0.025 * wpm_g
					_reload_hand_target.global_position = palm_tgt - (palm_gg - wrist_gg)
					left_hand_ik.target = _reload_hand_target
					left_hand_ik_weight = move_toward(left_hand_ik_weight, 1.0, delta * 6.0)
					left_hand_ik.influence = left_hand_ik_weight
					return
		if cfg_s.has("support_delta") or cfg_s.has("support_point"):
			var skel_s := left_hand_ik.get_parent() as Skeleton3D
			var ref_s: Node3D = null
			for m in current_custom_model_instance.find_children("*", "MeshInstance3D", true, false):
				if String(m.name).to_lower().begins_with("receiver"):
					ref_s = m
					break
			if skel_s and ref_s:
				var wi := -1
				for i in skel_s.get_bone_count():
					if skel_s.get_bone_name(i).begins_with("L_wrist"):
						wi = i
						break
				if wi >= 0:
					if not _reload_hand_target or not is_instance_valid(_reload_hand_target):
						_reload_hand_target = Node3D.new()
						_reload_hand_target.name = "ReloadHandTarget"
						add_child(_reload_hand_target)
					var wrist_g := skel_s.global_transform * skel_s.get_bone_global_pose(wi).origin
					if cfg_s.has("support_point"):
						# ponto fixo da arma para a PALMA (ex.: pistola com duas mãos); o alvo do IK é o punho
						var pi_s := -1
						for i2 in skel_s.get_bone_count():
							if skel_s.get_bone_name(i2).begins_with("L_palm"):
								pi_s = i2
								break
						var palm_g := skel_s.global_transform * skel_s.get_bone_global_pose(pi_s).origin if pi_s >= 0 else wrist_g
						var off: Vector3 = palm_g - wrist_g
						if String(cfg_s.get("support_hand", "")) == "pump":
							# pegada de bomba: o punho da empunhadura vertical girado 90° (eixo deitado ao longo do cano, palma para cima)
							var flip: Basis = Basis(Vector3.BACK, PI) if bool(cfg_s.get("model_inverted", false)) else Basis.IDENTITY
							var hb: Basis = ref_s.global_basis.orthonormalized() * flip * Basis(Vector3.RIGHT, PI / 2.0) * Basis(SMG_FIST_HAND)
							var wb_anim: Basis = (skel_s.global_transform * skel_s.get_bone_global_pose(wi)).basis.orthonormalized()
							off = hb * (wb_anim.inverse() * off)
							_reload_hand_target.set_meta("hand_basis", hb)
						_reload_hand_target.global_position = ref_s.global_transform * (cfg_s["support_point"] as Vector3) - off
					else:
						_reload_hand_target.global_position = wrist_g + ref_s.global_basis * (cfg_s["support_delta"] as Vector3)
					left_hand_ik.target = _reload_hand_target
					left_hand_ik_weight = move_toward(left_hand_ik_weight, 1.0, delta * 6.0)
					left_hand_ik.influence = left_hand_ik_weight
					return
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
const NATIVE_MAG_NAMES := ["mag", "clip", "slug1"] # slug1: cartucho da escopeta
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
	var att_mag = current_custom_model_instance.get_node_or_null("Pivot/AttachmentContainer/Att_mag")
	if att_mag and att_mag is Node3D:
		# pente estendido/rápido (acessório) substitui o pente do modelo e segue a recarga
		_mag_custom.append({"node": att_mag, "rest": att_mag.transform})
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
	# Escopetas: o cartucho do modelo fica escondido e, na recarga, vai na palma da mão esquerda
	if String(_mag_native.name) == "slug1":
		_update_shell_in_hand(st.begins_with("reload"))
		return
	# repouso registrado na primeira vez que a arma fica parada (idle)
	if not _mag_rest_ok:
		if st == "idle":
			_mag_native_rest = _mag_native.transform
			_mag_rest_ok = true
		return
	var reloading := st.begins_with("reload")
	var p_parent := _mag_native.get_parent() as Node3D
	if not p_parent:
		return
	var delta_local: Transform3D = _mag_native.transform * _mag_native_rest.affine_inverse()
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

func _update_shell_in_hand(reloading: bool) -> void:
	_reload_ik_weight = 0.0
	var skel: Skeleton3D = null
	if fps_hands and is_instance_valid(fps_hands.weapon):
		var sk = fps_hands.weapon.find_children("*", "Skeleton3D", true, false)
		if not sk.is_empty(): skel = sk.front()
	for e in _mag_custom:
		var node: Node3D = e["node"]
		if not is_instance_valid(node):
			continue
		node.transform = e["rest"]
		node.visible = reloading and skel != null
		if not node.visible:
			continue
		var pi := -1
		for i in skel.get_bone_count():
			if skel.get_bone_name(i).begins_with("L_palm"):
				pi = i
				break
		if pi < 0:
			node.visible = false
			continue
		# centro do cartucho na palma, mantendo a orientação do cartucho
		var palm: Transform3D = skel.global_transform * skel.get_bone_global_pose(pi)
		var c := _mesh_center(node)
		node.global_position += palm.origin - c

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

func _snap_optic_next_frame(optic: Node3D) -> void:
	await get_tree().process_frame
	if not is_instance_valid(optic) or optic != current_optic_instance:
		return
	var pivot = optic.get_parent() as Node3D
	if not pivot:
		return
	_update_integrated_sights_visibility()
	WeaponVisualRegistry.snap_optic_to_rail(pivot, optic)
	update_ads_alignment()

## Encaixe do Blender: a peça Receiver da arma vai exatamente para rig_fit (relativo ao nó "base"),
## descontando escalas intermediárias da cena da arma (Pivot, cena .tscn, nós do glb)
var _ads_sight_rot: Quaternion = Quaternion.IDENTITY

## Ótica nas armas encaixadas no Blender: assenta no ponto real do topo (optic_rail), alinhada ao cano
## e com o "para cima" real da arma (modelos invertidos usam optic_basis_fix)
func _place_rig_optic() -> void:
	if not current_optic_instance or not is_instance_valid(current_optic_instance) or current_optic_id == "none":
		return
	if not current_weapon_data or not _current_has_rig_fit():
		return
	var cfg_o = WeaponVisualRegistry.get_weapon_config(current_weapon_data.weapon_id.to_lower())
	var ref_o := _rig_ref_mesh()
	if not ref_o:
		return
	if not cfg_o.has("optic_rail"):
		# sem assento medido: mantém a altura/posição do encaixe no trilho, mas centraliza a ótica
		# na linha central do trilho e alinha ao cano
		if not cfg_o.has("ads_front"):
			return
		var lp: Vector3 = ref_o.to_local(current_optic_instance.global_position)
		lp.x = (cfg_o["ads_front"] as Vector3).x
		var b2 := ref_o.global_basis.orthonormalized()
		var sc2 := current_optic_instance.global_basis.get_scale()
		current_optic_instance.global_transform = Transform3D(Basis(b2.x * sc2.x, b2.y * sc2.y, b2.z * sc2.z), ref_o.global_transform * lp)
		return
	var b := ref_o.global_basis.orthonormalized()
	match String(cfg_o.get("optic_basis_fix", "")):
		"x180":
			b = b * Basis(Vector3.RIGHT, PI)
		"z180":
			b = b * Basis(Vector3.BACK, PI)
	var sc := current_optic_instance.global_basis.get_scale()
	current_optic_instance.global_transform = Transform3D(Basis(b.x * sc.x, b.y * sc.y, b.z * sc.z), ref_o.global_transform * (cfg_o["optic_rail"] as Vector3))

## Centro real do retículo da ótica montada: a peça de retículo do próprio modelo
## (RedDotReticle / HoloReticle; lente nas lunetas). Tabela de deslocamentos só como reserva.
func optic_reticle_world() -> Vector3:
	if not current_optic_instance or not is_instance_valid(current_optic_instance) or not current_optic_instance.is_inside_tree():
		return Vector3.ZERO
	for m in current_optic_instance.find_children("*", "MeshInstance3D", true, false):
		var n := String(m.name).to_lower()
		if "reticle" in n or "lens" in n:
			return m.global_transform * m.get_aabb().get_center()
	var ret_o: Vector3 = OPTIC_RETICLE_OFFSETS.get(current_optic_id, Vector3(0.0, 0.027023, -0.010408))
	var o_s: Vector3 = current_optic_instance.scale
	return current_optic_instance.global_transform * Vector3(ret_o.x / max(o_s.x, 1e-5), ret_o.y / max(o_s.y, 1e-5), ret_o.z / max(o_s.z, 1e-5))

const FINGER_GRIP_SCRIPT := preload("res://scripts/weapons/finger_grip_modifier.gd")
const LEFT_ARM_HIDE_SCRIPT := preload("res://scripts/weapons/left_arm_hide_modifier.gd")

## A arma aceita ótica: de fábrica (has_optic) ou liberada no registro por ter trilho (allow_optic)
func _optic_allowed() -> bool:
	if not current_weapon_data:
		return false
	return current_weapon_data.has_optic or bool(WeaponVisualRegistry.get_weapon_config(current_weapon_data.weapon_id.to_lower()).get("allow_optic", false))

func _is_one_handed() -> bool:
	return current_weapon_data != null and bool(WeaponVisualRegistry.get_weapon_config(current_weapon_data.weapon_id.to_lower()).get("one_handed", false))

## Armas de uma mão: braço esquerdo fora de cena (volta só na recarga, que precisa dele para o pente)
func _update_one_handed(delta: float) -> void:
	if not left_hand_ik or not is_instance_valid(left_hand_ik):
		return
	var sk := left_hand_ik.get_parent() as Skeleton3D
	if not sk:
		return
	var mod: SkeletonModifier3D = sk.get_node_or_null("LeftArmHide") as SkeletonModifier3D
	if not mod:
		mod = LEFT_ARM_HIDE_SCRIPT.new()
		mod.name = "LeftArmHide"
		mod.influence = 0.0
		sk.add_child(mod)  # por último: depois do IK
	var st := ""
	if fps_hands and fps_hands.state_machine:
		st = str(fps_hands.state_machine.get_current_node())
	var want := 1.0 if (_is_one_handed() and not st.begins_with("reload")) else 0.0
	want *= 1.0 - _swing_amount   # corrida tática: o braço esquerdo aparece balançando
	# troca de arma e recarga: sem transição lenta para o braço não "crescer" na frente da câmera
	mod.influence = want if want == 0.0 and st.begins_with("reload") else move_toward(mod.influence, want, delta * 8.0)
	mod.active = mod.influence > 0.001

## Punho fechado na empunhadura montada pelo Gunsmith (armas encaixadas no Blender)
func _update_finger_grip(delta: float) -> void:
	if not left_hand_ik or not is_instance_valid(left_hand_ik):
		return
	var sk := left_hand_ik.get_parent() as Skeleton3D
	if not sk:
		return
	var mod: SkeletonModifier3D = sk.get_node_or_null("FingerGrip") as SkeletonModifier3D
	if not mod:
		mod = FINGER_GRIP_SCRIPT.new()
		mod.name = "FingerGrip"
		mod.influence = 0.0
		sk.add_child(mod)
		sk.move_child(mod, left_hand_ik.get_index())  # antes do IK: dedos fecham, depois o IK posiciona a mão
	var want := 0.0
	var st := ""
	if fps_hands and fps_hands.state_machine:
		st = str(fps_hands.state_machine.get_current_node())
	if _current_has_rig_fit() and current_custom_model_instance and is_instance_valid(current_custom_model_instance) \
			and not (st in LEFT_IK_OFF_STATES) and not st.begins_with("reload"):
		var ub: Node3D = current_custom_model_instance.find_child("Att_underbarrel", true, false) as Node3D
		if ub and ub.is_visible_in_tree():
			want = 1.0
		elif current_weapon_data:
			# fechamento próprio da arma (ex.: punho em volta da bomba das escopetas)
			want = float(WeaponVisualRegistry.get_weapon_config(current_weapon_data.weapon_id.to_lower()).get("support_fist", 0.0))
		if _is_one_handed():
			want = 0.0
	want *= 1.0 - _swing_amount
	mod.influence = move_toward(mod.influence, want, delta * 6.0)
	mod.active = mod.influence > 0.001

# ── CORRIDA TÁTICA: MÃO ESQUERDA SOLTA, BOMBEANDO NO RITMO DA PASSADA (estilo CoD MW/Warzone) ──
# Um segundo IK do braço esquerdo roda depois do IK de apoio; a força dele acompanha a pose
# (com mola) do jogador, então a mão sai da arma e volta para ela sem salto.
# A mão é posicionada a partir do OMBRO (osso L_arm), a uma fração do comprimento do braço:
# o cotovelo fica sempre dobrado (nada de braço esticado) e o pulso segue o antebraço (sem torção).
# Direções no espaço da câmera: frente = mão sobe na frente do peito; trás = desce e sai pela parte de baixo da tela.
const SWING_DIR_FRONT := Vector3(-0.22, 0.22, -1.0)
const SWING_DIR_BACK  := Vector3(-0.12, -1.0, -0.12)
const SWING_REACH_FRONT := 0.70   # fração do comprimento do braço
const SWING_REACH_BACK  := 0.82
var _swing_amount: float = 0.0
var _swing_target: Node3D = null
var _player_ref: Node = null

func _find_player() -> Node:
	if _player_ref and is_instance_valid(_player_ref):
		return _player_ref
	var p := get_parent()
	while p:
		if "tac_visual" in p:
			_player_ref = p
			return p
		p = p.get_parent()
	return null

func _update_left_swing(_delta: float) -> void:
	_swing_amount = 0.0
	if not left_hand_ik or not is_instance_valid(left_hand_ik) or not camera:
		return
	var sk := left_hand_ik.get_parent() as Skeleton3D
	if not sk:
		return
	var pl := _find_player()
	var amt: float = clampf(float(pl.tac_visual), 0.0, 1.0) if pl else 0.0
	var st := ""
	if fps_hands and fps_hands.state_machine:
		st = str(fps_hands.state_machine.get_current_node())
	if st in LEFT_IK_OFF_STATES or st.begins_with("reload"):
		amt = 0.0
	var ik = sk.get_node_or_null("LeftSwingIK")
	if not ik:
		if amt <= 0.001:
			return
		ik = LeftHandIK.new()
		ik.name = "LeftSwingIK"
		sk.add_child(ik)
		sk.move_child(ik, left_hand_ik.get_index() + 1)  # depois do IK de apoio, antes do LeftArmHide
		ik.root_idx = left_hand_ik.root_idx
		ik.mid_idx = left_hand_ik.mid_idx
		ik.end_idx = left_hand_ik.end_idx
	if not _swing_target or not is_instance_valid(_swing_target):
		_swing_target = Node3D.new()
		_swing_target.name = "LeftSwingTarget"
		add_child(_swing_target)
	var phase: float = float(pl._bob_phase) if pl else 0.0
	# 0 = mão atrás/embaixo, 1 = mão na frente/alto; curva suavizada para "bombear" como na corrida
	var u := 0.5 + 0.5 * sin(phase * 0.5)
	u = u * u * (3.0 - 2.0 * u)
	var sh_i: int = left_hand_ik.root_idx
	var el_i: int = left_hand_ik.mid_idx
	var wr_i: int = left_hand_ik.end_idx
	var sh: Vector3 = sk.global_transform * sk.get_bone_global_pose(sh_i).origin
	# a pose de corrida gira o rig inteiro (e o ombro junto): usa o ombro na posição sem essa rotação,
	# senão no fuzil a mão esquerda cairia no meio da tela, embaixo da arma
	var rig := get_parent() as Node3D
	var is_pistol := current_weapon_data != null and current_weapon_data.category == WeaponData.WeaponCategory.PISTOL
	if rig and rig.get_parent() == camera and not is_pistol:
		var sh_cam: Vector3 = camera.global_transform.affine_inverse() * sh
		sh = camera.global_transform * (rig.transform.affine_inverse() * sh_cam)
	var arm_len: float = sk.get_bone_global_pose(sh_i).origin.distance_to(sk.get_bone_global_pose(el_i).origin) \
			+ sk.get_bone_global_pose(el_i).origin.distance_to(sk.get_bone_global_pose(wr_i).origin)
	arm_len *= sk.global_basis.get_scale().x
	var cb: Basis = camera.global_basis.orthonormalized()
	var dir_cam: Vector3 = SWING_DIR_BACK.normalized().lerp(SWING_DIR_FRONT.normalized(), u).normalized()
	var reach: float = lerpf(SWING_REACH_BACK, SWING_REACH_FRONT, u) * arm_len
	_swing_target.global_position = sh + cb * dir_cam * reach
	# mão "de faca": palma virada para dentro (direita da câmera) e um pouco para cima; o pulso fica reto
	_swing_target.set_meta("palm_dir", cb * Vector3(1.0, 0.25, 0.0).normalized())
	_swing_target.set_meta("elbow_down", cb * Vector3(-0.3, -1.0, 0.0).normalized())
	ik.target = _swing_target
	ik.influence = amt
	ik.active = amt > 0.001
	_swing_amount = amt

# ── MIRA DE FERRO REBATÍVEL (BUIS) ───────────────────────────────────────────
# Armas cujo modelo só tem trilho (ex.: ACR): alça de anel e massa com orelhas montadas no trilho,
# visíveis só sem ótica. Medidas no espaço do mesh "receiver" (o mesmo de ads_rear/ads_front).
func _update_buis() -> void:
	if not current_custom_model_instance or not is_instance_valid(current_custom_model_instance) or current_weapon_data == null:
		return
	var cfg = WeaponVisualRegistry.get_weapon_config(current_weapon_data.weapon_id.to_lower())
	if not cfg.has("buis") and not cfg.has("sight_dot"):
		return
	var ref := _rig_ref_mesh()
	if not ref:
		return
	if cfg.has("sight_glass") and not ref.has_meta("_glass_done"):
		ref.set_meta("_glass_done", true)
		_make_sight_glass(ref, cfg["sight_glass"])
	if cfg.has("sight_dot"):
		# mira embutida (ex.: janela da Man-o-War): ponto vermelho no centro, só sem ótica
		var dot := ref.get_node_or_null("SightDot") as MeshInstance3D
		if not dot:
			dot = MeshInstance3D.new()
			dot.name = "SightDot"
			var sm := SphereMesh.new()
			sm.radius = 0.0011
			sm.height = 0.0022
			dot.mesh = sm
			var dm := StandardMaterial3D.new()
			dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			dm.albedo_color = Color(1.0, 0.12, 0.08)
			dm.emission_enabled = true
			dm.emission = Color(1.0, 0.1, 0.05)
			dm.no_depth_test = true          # sempre por cima do vidro
			dm.render_priority = 10
			dot.material_override = dm
			dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			dot.position = cfg["sight_dot"]
			ref.add_child(dot)
			WeaponManager.set_viewmodel_layers(dot, 2)
		dot.visible = current_optic_id == "none" or current_optic_id == ""
	if not cfg.has("buis"):
		return
	var root := ref.get_node_or_null("BUIS") as Node3D
	if not root:
		root = _build_buis(cfg["buis"])
		ref.add_child(root)
		WeaponManager.set_viewmodel_layers(root, 2)
	root.visible = current_optic_id == "none" or current_optic_id == ""

## Separa o vidro de uma mira embutida (mesma malha da carcaça): triângulos virados para o eixo do cano
## e totalmente dentro da janela vão para uma superfície própria, translúcida.
func _make_sight_glass(ref: Node3D, g: Dictionary) -> void:
	var host: Node = ref.get_parent() if ref.get_parent() else ref
	var mi := host.find_child(String(g["mesh"]), true, false) as MeshInstance3D
	if not mi or not mi.mesh:
		return
	var to_ref: Transform3D = ref.global_transform.affine_inverse() * mi.global_transform
	var x0: float = g["x0"]; var x1: float = g["x1"]; var y0: float = g["y0"]; var y1: float = g["y1"]
	var out := ArrayMesh.new()
	for s in mi.mesh.get_surface_count():
		var mdt := MeshDataTool.new()
		if mdt.create_from_surface(mi.mesh, s) != OK:
			return
		var keep := SurfaceTool.new(); keep.begin(Mesh.PRIMITIVE_TRIANGLES)
		var glass := SurfaceTool.new(); glass.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n_glass := 0
		for f in mdt.get_face_count():
			var inside := true
			var pts: Array[Vector3] = []
			for k in 3:
				var vi := mdt.get_face_vertex(f, k)
				var pr: Vector3 = to_ref * mdt.get_vertex(vi)
				pts.append(pr)
				if pr.x < x0 or pr.x > x1 or pr.y < y0 or pr.y > y1:
					inside = false
			var nrm: Vector3 = (to_ref.basis * mdt.get_face_normal(f)).normalized()
			var is_glass: bool = inside and absf(nrm.z) > 0.85
			var st: SurfaceTool = glass if is_glass else keep
			if is_glass:
				n_glass += 1
			for k in 3:
				var vi := mdt.get_face_vertex(f, k)
				st.set_normal(mdt.get_vertex_normal(vi))
				st.set_uv(mdt.get_vertex_uv(vi))
				st.add_vertex(mdt.get_vertex(vi))
		keep.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, mi.get_active_material(s))
		if n_glass > 0:
			glass.commit(out)
			var gm := StandardMaterial3D.new()
			gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			gm.albedo_color = Color(0.55, 0.75, 0.85, 0.10)
			gm.metallic = 0.0
			gm.roughness = 0.05
			gm.cull_mode = BaseMaterial3D.CULL_DISABLED
			out.surface_set_material(out.get_surface_count() - 1, gm)
	mi.mesh = out

func _buis_box(parent: Node3D, mat: Material, size: Vector3, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

func _build_buis(d: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "BUIS"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.09, 0.09, 0.1)
	mat.metallic = 0.5
	mat.roughness = 0.55
	var x: float = d["x"]
	var rail: float = d["rail_y"]
	var line: float = d["line_y"]
	var rz: float = d["rear_z"]
	var fz: float = d["front_z"]
	# alça: base no trilho, haste e anel (o centro do anel fica na linha de mira)
	_buis_box(root, mat, Vector3(0.022, 0.010, 0.022), Vector3(x, rail + 0.005, rz))
	_buis_box(root, mat, Vector3(0.008, line - rail - 0.012, 0.006), Vector3(x, rail + 0.010 + (line - rail - 0.012) * 0.5 - 0.004, rz))
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.0034
	tm.outer_radius = 0.0068
	tm.rings = 24
	tm.ring_segments = 8
	ring.mesh = tm
	ring.material_override = mat
	ring.rotation = Vector3(PI * 0.5, 0, 0)   # furo voltado para o olho (eixo do cano)
	ring.position = Vector3(x, line, rz)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	# massa: base, poste (ponta exatamente na linha de mira) e orelhas de proteção
	_buis_box(root, mat, Vector3(0.020, 0.010, 0.016), Vector3(x, rail + 0.005, fz))
	var post_h: float = line - rail - 0.010
	_buis_box(root, mat, Vector3(0.0026, post_h, 0.004), Vector3(x, rail + 0.010 + post_h * 0.5, fz))
	for side in [-1.0, 1.0]:
		_buis_box(root, mat, Vector3(0.0025, post_h + 0.004, 0.006), Vector3(x + side * 0.0075, rail + 0.010 + (post_h + 0.004) * 0.5, fz))
	return root

func _rig_ref_mesh() -> Node3D:
	if not current_custom_model_instance or not is_instance_valid(current_custom_model_instance):
		return null
	for m in current_custom_model_instance.find_children("*", "MeshInstance3D", true, false):
		if String(m.name).to_lower().begins_with("receiver"):
			return m
	return null

func _current_has_rig_fit() -> bool:
	if not current_weapon_data:
		return false
	return WeaponVisualRegistry.get_weapon_config(current_weapon_data.weapon_id.to_lower()).has("rig_fit")

func _apply_rig_fit(custom_model: Node3D, fit: Transform3D) -> void:
	for pass_i in 2:
		if pass_i == 1:
			await get_tree().process_frame
		if not is_instance_valid(custom_model):
			return
		var ref_mesh: Node3D = null
		for m in custom_model.find_children("*", "MeshInstance3D", true, false):
			if String(m.name).to_lower().begins_with("receiver"):
				ref_mesh = m
				break
		if not ref_mesh:
			return
		var chain := Transform3D.IDENTITY
		var n: Node = ref_mesh
		while n and n != custom_model:
			if n is Node3D:
				chain = (n as Node3D).transform * chain
			n = n.get_parent()
		custom_model.transform = fit * chain.affine_inverse()

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
	_place_rig_optic()
	_update_finger_grip(_delta)
	_update_left_swing(_delta)
	_update_buis()
	_update_one_handed(_delta)

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
			_ads_sight_rot = Quaternion.IDENTITY
		# mira de ferro das armas encaixadas no Blender: gira o conjunto braços+arma até alça e massa ficarem em linha com o olho
		if fps_hands.weapon.has_meta("_vm_base_basis"):
			var b0r: Basis = fps_hands.weapon.get_meta("_vm_base_basis")
			fps_hands.weapon.basis = Basis(Quaternion.IDENTITY.slerp(_ads_sight_rot, smooth_t)) * b0r

		# 2. Rotação do modelo da arma: Hipfire angular -> ADS 100% reto coaxial com o centro da tela
		if current_custom_model_instance and is_instance_valid(current_custom_model_instance) and not _current_has_rig_fit():
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

	if _optic_allowed() and current_optic_id != "none":
		if fps_hands and is_instance_valid(fps_hands.weapon):
			if not is_instance_valid(current_optic_instance) or current_optic_instance.get_parent() == null:
				_update_weapon_optic()
	else:
		if current_optic_instance and is_instance_valid(current_optic_instance):
			current_optic_instance.queue_free()
			current_optic_instance = null
			update_ads_alignment()

func _update_weapon_optic() -> void:
	if not _optic_allowed() or current_optic_id == "none":
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
			# assenta no topo real da arma no frame seguinte (com a mira de ferro original já escondida)
			_snap_optic_next_frame.call_deferred(optic)
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
			# só o modelo da arma (não os acessórios nem a mira) e com TODOS os encaixes: antes, mira e cano
			# sozinhos faziam reaparecer o pente e a coronha originais por baixo do pente estendido/coronha tática
			var model_root: Node3D = null
			for c in pivot.get_children():
				if c is Node3D and c.name != "AttachmentContainer" and c != current_optic_instance and c.name != "GripL":
					model_root = c
					break
			if model_root:
				# cano curto tira o quebra-chamas do modelo, como um acessório de boca
				var muzzle_eff: String = current_muzzle_id
				if (muzzle_eff == "none" or muzzle_eff == "") and current_attachments.get("barrel", "none") == "barrel_short":
					muzzle_eff = "barrel_short"
				WeaponVisualRegistry.update_integrated_weapon_parts(model_root, current_optic_id, muzzle_eff,
					current_attachments.get("mag", "none"), current_attachments.get("underbarrel", "none"),
					current_attachments.get("stock", "none"), current_attachments.get("grip", "none"))

func update_ads_alignment() -> void:
	_ads_sight_rot = Quaternion.IDENTITY
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
			# posição real da mira (depois de assentada no trilho), quando ela está no Pivot
			if current_optic_instance and is_instance_valid(current_optic_instance) and current_optic_instance.get_parent() == pivot:
				opt_sock = current_optic_instance.position
			var ret_off = OPTIC_RETICLE_OFFSETS.get(current_optic_id, Vector3(0.0, 0.027023, -0.010408))
			sight_pivot_pos = opt_sock + ret_off
		else:
			sight_pivot_pos = cfg.get("socket_iron_ads", Vector3(0, 0.12, 0))

		if _current_has_rig_fit() and cfg.has("ads_front"):
			# mira de ferro real: massa de mira no centro da tela, olho a ads_eye metros (reais) da alça
			var ref_a := _rig_ref_mesh()
			if ref_a:
				var wpn: Node3D = fps_hands.weapon
				if not wpn.has_meta("_vm_base_basis"):
					wpn.set_meta("_vm_base_basis", wpn.basis)
				var b0: Basis = wpn.get_meta("_vm_base_basis")
				var rear_w: Vector3 = ref_a.global_transform * (cfg["ads_rear"] as Vector3)
				var front_w: Vector3 = ref_a.global_transform * (cfg["ads_front"] as Vector3)
				# pontos no espaço do nó da arma (independe da rotação de mira já aplicada)
				var p_f: Vector3 = wpn.to_local(front_w)
				var p_r: Vector3 = wpn.to_local(rear_w)
				var wpm: float = ref_a.global_basis.get_scale().x
				var depth: float = float(cfg.get("ads_eye", 0.09)) * wpm + rear_w.distance_to(front_w)
				if has_optic and (not current_optic_instance.is_inside_tree() or current_optic_instance.is_queued_for_deletion()):
					return  # ótica sendo trocada: alinha no quadro seguinte
				if has_optic:
					# mira ótica: o centro do retículo vai ao centro da tela, olho à distância real de uso da mira
					var ret_w: Vector3 = optic_reticle_world()
					p_f = wpn.to_local(ret_w)
					# olho 5 cm atrás da ponta traseira real da ótica (vale para red dot, holo, ACOG e luneta de qualquer tamanho)
					var axis_w: Vector3 = (front_w - ref_a.global_transform * Vector3((cfg["ads_front"] as Vector3).x, (cfg["ads_front"] as Vector3).y, (cfg["ads_rear"] as Vector3).z)).normalized()
					var back := 0.0
					for om in current_optic_instance.find_children("*", "MeshInstance3D", true, false):
						if not om.is_visible_in_tree():
							continue
						var ab: AABB = om.get_aabb()
						for ci in 8:
							back = maxf(back, -(om.global_transform * ab.get_endpoint(ci) - ret_w).dot(axis_w))
					depth = back + 0.05 * wpm
				var tgt_l: Vector3 = fps_hands.to_local(cam.to_global(Vector3(0.0, 0.0, -depth)))
				# rotação que põe a linha alça->massa no eixo da câmera (como no CoD)
				# direção do cano = alça -> massa de ferro (mesmo quando a referência de mira é o retículo da ótica)
				# eixo do cano = eixo longitudinal do próprio modelo (todos estão alinhados ao comprimento no glb);
				# a alça só define a distância do olho, nunca a direção
				var fl: Vector3 = cfg["ads_front"]
				var rl: Vector3 = cfg["ads_rear"]
				var rear_axis_w: Vector3 = ref_a.global_transform * Vector3(fl.x, fl.y, rl.z)
				var d: Vector3 = (b0 * (wpn.to_local(front_w) - wpn.to_local(rear_axis_w))).normalized()
				var c: Vector3 = (fps_hands.global_basis.inverse() * (-cam.global_basis.z)).normalized()
				_ads_sight_rot = Quaternion(d, c) if d.length() > 0.5 and c.length() > 0.5 else Quaternion.IDENTITY
				fps_hands.ads_pos = tgt_l - (Basis(_ads_sight_rot) * b0) * p_f
				return
		if _current_has_rig_fit():
			# encaixe do Blender: cano paralelo ao da arma original, a mira se alinha como a dela
			var sg: Vector3 = pivot.to_global(sight_pivot_pos)
			fps_hands.ads_pos = target_sight_in_fps_hands - (fps_hands.to_local(sg) - fps_hands.weapon.position)
			return

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
		# mantém a orientação da mão da animação (palma para cima segurando por baixo): sem isso a mão
		# gira junto com o antebraço e fica em pé atravessando a arma
		var root_parent := skel.get_bone_parent(root_idx)
		var parent_g := skel.get_bone_global_pose(root_parent) if root_parent >= 0 else Transform3D.IDENTITY
		var a_pose := Transform3D(Basis(a_local), skel.get_bone_pose_position(root_idx))
		var b_pose := Transform3D(Basis(b_local), skel.get_bone_pose_position(mid_idx))
		var mid_g_new := parent_g * a_pose * b_pose
		if target.has_meta("palm_dir"):
			# braço livre (corrida tática): pulso reto em relação ao antebraço (sem torção, que amassa a malha)
			# e a palma é virada girando o braço inteiro em volta da linha ombro->mão (a mão não sai do lugar)
			var end_rest := skel.get_bone_rest(end_idx).basis.get_rotation_quaternion()
			var c_pose := Transform3D(Basis(end_rest), skel.get_bone_pose_position(end_idx))
			var sh_g := parent_g * a_pose
			var wr_g := sh_g * b_pose * c_pose
			var axis := wr_g.origin - sh_g.origin
			if axis.length() > 0.0001:
				axis = axis.normalized()
				var want_palm: Vector3 = skel.global_basis.orthonormalized().inverse() * (target.get_meta("palm_dir") as Vector3)
				var cur_palm: Vector3 = wr_g.basis.y.normalized()
				var pc := (cur_palm - axis * cur_palm.dot(axis))
				var pw := (want_palm - axis * want_palm.dot(axis))
				if pc.length() > 0.001 and pw.length() > 0.001:
					var ang := pc.normalized().signed_angle_to(pw.normalized(), axis)
					ang = clampf(ang, -0.9, 0.9)   # giro limitado: virar demais leva o cotovelo para cima, na frente da câmera
					var pb := parent_g.basis.orthonormalized()
					# o cotovelo não pode subir acima da linha ombro->mão (sempre "para baixo", como num braço correndo)
					var down: Vector3 = skel.global_basis.orthonormalized().inverse() * (target.get_meta("elbow_down", Vector3.DOWN) as Vector3)
					for _i in 3:
						var trial := Basis(axis, ang)
						var el_try: Vector3 = sh_g.origin + trial * ((sh_g * b_pose).origin - sh_g.origin)
						var mid_line: Vector3 = sh_g.origin + axis * (el_try - sh_g.origin).dot(axis)
						if (el_try - mid_line).dot(down) >= 0.0:
							break
						ang *= 0.5
					var rot_g := Basis(axis, ang)
					a_local = (pb.inverse() * rot_g * pb * Basis(a_local)).get_rotation_quaternion()
					skel.set_bone_pose_rotation(root_idx, a_local)
			skel.set_bone_pose_rotation(end_idx, end_rest)
			return
		var hand_g: Basis = rc.basis.orthonormalized()
		if target.has_meta("hand_basis"):
			# rotação de mão pedida pelo alvo (ex.: pegada de bomba de escopeta), em espaço do mundo
			hand_g = skel.global_basis.orthonormalized().inverse() * (target.get_meta("hand_basis") as Basis)
		var end_rot := (mid_g_new.basis.orthonormalized().inverse() * hand_g).get_rotation_quaternion()
		skel.set_bone_pose_rotation(end_idx, end_rot)
