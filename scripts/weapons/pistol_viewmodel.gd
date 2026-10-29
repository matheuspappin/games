# =============================================================================
# pistol_viewmodel.gd
# Controlador de Viewmodel em 1ª Pessoa da Arma Secundária (Beretta M9)
# Utiliza o mesmo modelo de personagem/braços táticos da arma primária
# MS-2: Sistema de Armas — Arma Secundária com braços táticos e Beretta M9 realista
# =============================================================================
class_name PistolViewModel
extends Node3D

@onready var anim_player: AnimationPlayer = $Model/AnimationPlayer if has_node("Model/AnimationPlayer") else find_child("AnimationPlayer", true, false)
@onready var muzzle: Marker3D = $Muzzle
@onready var muzzle_flash: OmniLight3D = $Muzzle/FlashLight if has_node("Muzzle/FlashLight") else find_child("FlashLight", true, false)

const ANIM_IDLE     = "Armature|Arms_FPS_Anim_Idle"
const ANIM_SHOOT    = "Armature|Arms_FPS_Anim_Shoot"
const ANIM_RELOAD   = "Armature|Arms_FPS_Anim_Reload_Fast"
const ANIM_RUN      = "Armature|Arms_FPS_Anim_Run"
const ANIM_WALK     = "Armature|Arms_FPS_Anim_Walk"
const ANIM_DRAW     = "Armature|Arms_FPS_Anim_Draw"
const ANIM_INSPECT  = "Armature|Arms_FPS_Anim_rifle_inspect"

var is_reloading: bool = false
var is_inspecting: bool = false

var m9_model: Node3D = null
var slide_mesh: Node3D = null
var slide_offset: float = 0.0
var flash_timer: float = 0.0

var left_arm_bone_idx: int = -1
var skel: Skeleton3D = null

func _ready() -> void:
	# 1. Corrigir binds de todos os ossos e skins do modelo de braços do personagem
	ModelFixer.fix_skins(self)

	# 2. CULL_DISABLED para garantir que luva, braço e pistola nunca fiquem invisíveis
	for mesh_node in find_children("*", "MeshInstance3D", true, false):
		var mi = mesh_node as MeshInstance3D
		if mi:
			for s in range(mi.get_surface_override_material_count()):
				var mat = mi.get_active_material(s)
				if mat is BaseMaterial3D:
					mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			if mi.mesh:
				for s in range(mi.mesh.get_surface_count()):
					var mat = mi.mesh.surface_get_material(s)
					if mat is BaseMaterial3D:
						mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# 3. Ocultar malhas do fuzil ACR para exibir exclusivamente a empunhadura do personagem
	for rifle_mesh_name in ["Object_12", "Object_13", "Object_14", "Object_15"]:
		var rifle_part = find_child(rifle_mesh_name, true, false)
		if rifle_part:
			rifle_part.visible = false

	# 4. Localizar Skeleton e ocultar o braço esquerdo (que seguraria o cano longo do fuzil)
	skel = find_child("Skeleton3D", true, false) as Skeleton3D
	if skel:
		left_arm_bone_idx = skel.find_bone("Arm_L_02")
		if left_arm_bone_idx >= 0:
			skel.set_bone_pose_scale(left_arm_bone_idx, Vector3.ZERO)

	# 5. Anexar o modelo 3D realista da Beretta M9
	_setup_pistol_model()

	# 6. Configurar loops de animação
	for loop_anim in [ANIM_IDLE, ANIM_WALK, ANIM_RUN]:
		if anim_player and anim_player.has_animation(loop_anim):
			var anim = anim_player.get_animation(loop_anim)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR

	if anim_player and not anim_player.animation_finished.is_connected(_on_anim_finished):
		anim_player.animation_finished.connect(_on_anim_finished)

	if muzzle_flash:
		muzzle_flash.visible = false

	play_draw()

func _setup_pistol_model() -> void:
	if not skel:
		push_error("[PistolViewModel] Skeleton3D não encontrado nos braços do personagem!")
		return

	# Criar BoneAttachment3D anexado ao osso da empunhadura
	var bone_att = BoneAttachment3D.new()
	bone_att.name = "PistolAttachment"
	bone_att.bone_name = "ACRRifle_058"
	skel.add_child(bone_att)

	# Instanciar a Beretta M9 realista (alta definição)
	var m9_scene = load("res://assets/models/weapons/m9/scene.gltf")
	if m9_scene:
		m9_model = m9_scene.instantiate()
		m9_model.name = "BerettaM9"
		# Escala de 21.7cm (compensando importação) e rotação alinhando o cano para frente (+Z) e miras para cima (+Y)
		var align_basis = Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 1, 0))
		m9_model.transform.basis = align_basis * Basis.from_scale(Vector3(6.535, 6.535, 6.535))
		m9_model.position = Vector3(0.0, -0.015, 0.035)
		bone_att.add_child(m9_model)

		# Localizar o mesh do ferrolho (slide) para recuo mecânico animado
		slide_mesh = m9_model.find_child("Gun001_BerettaM9_0", true, false) as Node3D

		# Configurar materiais do modelo M9 sem culling
		for m in m9_model.find_children("*", "MeshInstance3D", true, false):
			var mi = m as MeshInstance3D
			if mi and mi.mesh:
				for s in range(mi.mesh.get_surface_count()):
					var mat = mi.mesh.surface_get_material(s)
					if mat is BaseMaterial3D:
						mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	else:
		push_error("[PistolViewModel] Falha ao carregar modelo da Beretta M9!")

func _process(delta: float) -> void:
	# Manter braço esquerdo oculto para a postura tática de empunhadura limpa de pistola
	if skel and left_arm_bone_idx >= 0:
		skel.set_bone_pose_scale(left_arm_bone_idx, Vector3.ZERO)

	# Flash do disparo
	if flash_timer > 0.0:
		flash_timer -= delta
		if muzzle_flash:
			muzzle_flash.visible = flash_timer > 0.0
	elif muzzle_flash and muzzle_flash.visible:
		muzzle_flash.visible = false

	# Recuo do ferrolho/slide da pistola (blowback mecânico)
	if slide_mesh:
		slide_offset = move_toward(slide_offset, 0.0, delta * 30.0)
		slide_mesh.position.x = slide_offset

func play_idle() -> void:
	if is_reloading or is_inspecting:
		return
	if anim_player and (anim_player.current_animation == ANIM_SHOOT or anim_player.current_animation == ANIM_DRAW) and anim_player.is_playing():
		return
	if anim_player and anim_player.has_animation(ANIM_IDLE):
		if anim_player.current_animation != ANIM_IDLE or not anim_player.is_playing():
			anim_player.play(ANIM_IDLE, 0.2)

func play_shoot() -> void:
	if is_reloading:
		return
	if anim_player and anim_player.has_animation(ANIM_SHOOT):
		anim_player.stop()
		anim_player.play(ANIM_SHOOT, -1, 1.4)
		anim_player.seek(0.0, true)

	# Animação mecânica do ferrolho e muzzle flash
	slide_offset = 2.2 # ~1.4mm de deslocamento no ferrolho em escala local
	flash_timer = 0.05
	if muzzle_flash:
		muzzle_flash.visible = true

func play_reload() -> void:
	is_reloading = true
	is_inspecting = false
	if anim_player and anim_player.has_animation(ANIM_RELOAD):
		anim_player.stop()
		anim_player.play(ANIM_RELOAD, 0.1, 1.2)

func play_walk() -> void:
	if is_reloading or is_inspecting:
		return
	if anim_player and (anim_player.current_animation == ANIM_SHOOT or anim_player.current_animation == ANIM_DRAW) and anim_player.is_playing():
		return
	if anim_player and anim_player.has_animation(ANIM_WALK):
		if anim_player.current_animation != ANIM_WALK or not anim_player.is_playing():
			anim_player.play(ANIM_WALK, 0.25)

func play_sprint() -> void:
	if is_reloading or is_inspecting:
		return
	if anim_player and (anim_player.current_animation == ANIM_SHOOT or anim_player.current_animation == ANIM_DRAW) and anim_player.is_playing():
		return
	if anim_player and anim_player.has_animation(ANIM_RUN):
		if anim_player.current_animation != ANIM_RUN or not anim_player.is_playing():
			anim_player.play(ANIM_RUN, 0.2)

func play_draw() -> void:
	is_reloading = false
	is_inspecting = false
	if anim_player and anim_player.has_animation(ANIM_DRAW):
		anim_player.stop()
		anim_player.play(ANIM_DRAW, 0.1, 1.3)
	else:
		play_idle()

func play_inspect() -> void:
	if is_reloading or is_inspecting:
		return
	is_inspecting = true
	if anim_player and anim_player.has_animation(ANIM_INSPECT):
		anim_player.play(ANIM_INSPECT, 0.2)

func _on_anim_finished(anim_name: StringName) -> void:
	if anim_name == ANIM_RELOAD:
		is_reloading = false
		play_idle()
	elif anim_name == ANIM_SHOOT:
		play_idle()
	elif anim_name == ANIM_DRAW:
		play_idle()
	elif anim_name == ANIM_INSPECT:
		is_inspecting = false
		play_idle()
