# =============================================================================
# ak47_viewmodel.gd
# Controlador de animação e eventos do viewmodel da AK-47
# =============================================================================
class_name AK47ViewModel
extends Node3D

@onready var anim_player: AnimationPlayer = $Model/AnimationPlayer if has_node("Model/AnimationPlayer") else find_child("AnimationPlayer", true, false)
@onready var muzzle: Node3D = $Muzzle

const ANIM_IDLE     = "Armature.003|idle"
const ANIM_SHOOT    = "Armature.003|shooting"
const ANIM_RELOAD   = "Armature.003|reload"
const ANIM_RUN      = "Armature.003|run cycle"
const ANIM_WALK     = "Armature.003|walk"
const ANIM_DRAW     = "Armature.003|draw"

var is_reloading: bool = false

func _ready() -> void:
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
	if is_reloading:
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

func play_reload() -> void:
	is_reloading = true
	if anim_player and anim_player.has_animation(ANIM_RELOAD):
		anim_player.stop()
		anim_player.play(ANIM_RELOAD, 0.15)

func play_walk() -> void:
	if is_reloading:
		return
	if anim_player and (anim_player.current_animation == ANIM_SHOOT or anim_player.current_animation == ANIM_DRAW) and anim_player.is_playing():
		return
	if anim_player and anim_player.has_animation(ANIM_WALK):
		if anim_player.current_animation != ANIM_WALK or not anim_player.is_playing():
			anim_player.play(ANIM_WALK, 0.2)

func play_sprint() -> void:
	if is_reloading:
		return
	if anim_player and (anim_player.current_animation == ANIM_SHOOT or anim_player.current_animation == ANIM_DRAW) and anim_player.is_playing():
		return
	if anim_player and anim_player.has_animation(ANIM_RUN):
		if anim_player.current_animation != ANIM_RUN or not anim_player.is_playing():
			anim_player.play(ANIM_RUN, 0.2)

func play_draw() -> void:
	is_reloading = false
	if anim_player and anim_player.has_animation(ANIM_DRAW):
		anim_player.stop()
		anim_player.play(ANIM_DRAW, 0.1)
	else:
		play_idle()

func _on_anim_finished(anim_name: StringName) -> void:
	if anim_name == ANIM_RELOAD:
		is_reloading = false
		play_idle()
	elif anim_name == ANIM_SHOOT:
		play_idle()
	elif anim_name == ANIM_DRAW:
		play_idle()
