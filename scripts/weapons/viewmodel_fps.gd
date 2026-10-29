# =============================================================================
# viewmodel_fps.gd
# Controlador de Viewmodel em 1ª Pessoa com braços táticos e fuzil animado
# MS-2 & MS-6: Viewmodel com braços e animações realistas (estilo MW3 / BO1)
# =============================================================================
class_name ViewModelFPS
extends Node3D

@onready var anim_player: AnimationPlayer = $Model/AnimationPlayer if has_node("Model/AnimationPlayer") else find_child("AnimationPlayer", true, false)
@onready var muzzle: Marker3D = $Muzzle

const ANIM_IDLE     = "Armature|Arms_FPS_Anim_Idle"
const ANIM_SHOOT    = "Armature|Arms_FPS_Anim_Shoot"
const ANIM_RELOAD   = "Armature|Arms_FPS_Anim_Reload_Fast"
const ANIM_RUN      = "Armature|Arms_FPS_Anim_Run"
const ANIM_WALK     = "Armature|Arms_FPS_Anim_Walk"
const ANIM_DRAW     = "Armature|Arms_FPS_Anim_Draw"
const ANIM_INSPECT  = "Armature|Arms_FPS_Anim_rifle_inspect"

var is_reloading: bool = false
var is_inspecting: bool = false

# Offset calibrado para a posição de repouso (Hip-fire) e mira (ADS)
# No espaço da câmera:
# Hip-fire: arma empunhada na direita, cotovelo visível, fuzil apontando pro centro
var hip_transform: Transform3D
var ads_transform: Transform3D

func _ready() -> void:
	# Corrigir binds de todos os ossos e skins do modelo
	ModelFixer.fix_skins(self)

	for mesh_node in find_children("*", "MeshInstance3D", true, false):
		var mi = mesh_node as MeshInstance3D
		if mi:
			for s in range(mi.get_surface_override_material_count()):
				var mat = mi.get_active_material(s)
				if mat is BaseMaterial3D:
					mat.cull_mode = BaseMaterial3D.CULL_BACK
			if mi.mesh:
				for s in range(mi.mesh.get_surface_count()):
					var mat = mi.mesh.surface_get_material(s)
					if mat is BaseMaterial3D:
						mat.cull_mode = BaseMaterial3D.CULL_BACK
	
	# Garantir loop continuo para idle, walk e run
	for loop_anim in [ANIM_IDLE, ANIM_WALK, ANIM_RUN]:
		if anim_player and anim_player.has_animation(loop_anim):
			var anim = anim_player.get_animation(loop_anim)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
	
	if anim_player and not anim_player.animation_finished.is_connected(_on_anim_finished):
		anim_player.animation_finished.connect(_on_anim_finished)
	play_draw()

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
		anim_player.play(ANIM_SHOOT)
		anim_player.seek(0.0, true)

func play_reload() -> void:
	is_reloading = true
	is_inspecting = false
	if anim_player and anim_player.has_animation(ANIM_RELOAD):
		anim_player.stop()
		anim_player.play(ANIM_RELOAD, 0.1)

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
		anim_player.play(ANIM_DRAW, 0.1)
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
