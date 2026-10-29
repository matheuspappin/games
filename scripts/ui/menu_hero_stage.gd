# =============================================================================
# menu_hero_stage.gd
# 3D Hero Viewport Stage for NukeFPS Main Menu
# Renders the animated 3D Operator with dynamic lighting, retargeted idle animation,
# bone-anchored tactical weapon, and subtle mouse parallax for AAA tactical aesthetic.
# =============================================================================
class_name MenuHeroStage
extends Node3D

const SkinRegistry = preload("res://scripts/characters/skin_registry.gd")
const CharacterRetargeter = preload("res://scripts/characters/character_retargeter.gd")

const BASE_OPERATOR_Y_ROT: float = deg_to_rad(210.0) # ~3.665 rad (heroic 3/4 front stance)

@onready var camera: Camera3D = $Camera3D
@onready var operator_anchor: Node3D = $OperatorAnchor
@onready var key_light: DirectionalLight3D = $KeyLight
@onready var rim_light: DirectionalLight3D = $RimLight
@onready var ground_light: OmniLight3D = $GroundLight

var current_skin_instance: Node3D = null
var current_anim_player: AnimationPlayer = null
var target_cam_offset: Vector2 = Vector2.ZERO
var current_cam_offset: Vector2 = Vector2.ZERO
var base_cam_pos: Vector3 = Vector3(0.38, 1.05, 2.15)
var base_cam_rot: Vector3 = Vector3(-0.02, 0.12, 0.0)

func _ready() -> void:
	if camera:
		camera.position = base_cam_pos
		camera.rotation = base_cam_rot
	if operator_anchor:
		operator_anchor.rotation.y = BASE_OPERATOR_Y_ROT
	load_skin("ct_urban")

func _process(delta: float) -> void:
	# Smooth camera parallax transition towards mouse
	current_cam_offset = current_cam_offset.lerp(target_cam_offset, delta * 3.5)
	if camera:
		camera.position = base_cam_pos + Vector3(current_cam_offset.x * 0.15, current_cam_offset.y * 0.08, 0.0)
		camera.rotation.y = base_cam_rot.y - current_cam_offset.x * 0.06
		camera.rotation.x = base_cam_rot.x + current_cam_offset.y * 0.04
	
	# Subtle breathing rotation on operator (faces player in heroic 3/4 stance)
	if operator_anchor:
		var breath = sin(Time.get_ticks_msec() * 0.0012) * 0.02
		operator_anchor.rotation.y = BASE_OPERATOR_Y_ROT + breath + (current_cam_offset.x * 0.04)

func update_mouse_parallax(normalized_pos: Vector2) -> void:
	# normalized_pos in [-1.0, 1.0]
	target_cam_offset = normalized_pos

func load_skin(skin_id: String) -> void:
	if current_skin_instance:
		current_skin_instance.queue_free()
		current_skin_instance = null
		current_anim_player = null

	var skin_info = SkinRegistry.get_skin_info(skin_id)
	var scene_path = skin_info.get("scene_path", "res://scenes/characters/skins/ct_urban.tscn")
	var scn = load(scene_path) as PackedScene
	if not scn:
		scn = load("res://scenes/characters/skins/ct_urban.tscn") as PackedScene
	
	if scn:
		var inst = scn.instantiate() as Node3D
		operator_anchor.add_child(inst)
		current_skin_instance = inst
		inst.position = Vector3.ZERO
		inst.rotation = Vector3.ZERO
		
		# Retarget to high-fidelity humanoid skeleton with finger filtering
		CharacterRetargeter.retarget_model(inst)
		
		# Look for AnimationPlayer in model and ensure looping idle
		var ap = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			current_anim_player = ap
			if ap.has_animation("idle"):
				ap.play("idle")
				var anim = ap.get_animation("idle")
				if anim:
					anim.loop_mode = Animation.LOOP_LINEAR
			elif ap.get_animation_list().size() > 0:
				ap.play(ap.get_animation_list()[0])

		# Attach tactical weapon directly to operator hand skeleton bone
		_setup_operator_weapon()

func _setup_operator_weapon() -> void:
	if not current_skin_instance:
		return
		
	var skel = current_skin_instance.find_child("Skeleton3D", true, false) as Skeleton3D
	if not skel:
		return
		
	var r_hand_idx = skel.find_bone("mixamorig_RightHand")
	if r_hand_idx < 0:
		return

	var bone_att = skel.get_node_or_null("RightHandAttachment") as BoneAttachment3D
	if not bone_att:
		bone_att = BoneAttachment3D.new()
		bone_att.name = "RightHandAttachment"
		bone_att.bone_name = "mixamorig_RightHand"
		bone_att.bone_idx = r_hand_idx
		skel.add_child(bone_att)

	var old_weapon = bone_att.get_node_or_null("MenuTacticalWeapon")
	if old_weapon:
		old_weapon.queue_free()
		
	var rifle_scn = load("res://scenes/weapons/bot_rifle_3d.tscn") as PackedScene
	if not rifle_scn:
		return
		
	var rifle = rifle_scn.instantiate() as Node3D
	rifle.name = "MenuTacticalWeapon"
	bone_att.add_child(rifle)
	
	# Calibrated CS rifle transform directly attached to right hand bone
	rifle.scale = CharacterRetargeter.CS_RIFLE_LOCAL_SCALE
	rifle.position = CharacterRetargeter.CS_RIFLE_LOCAL_POS
	rifle.rotation_degrees = CharacterRetargeter.CS_RIFLE_LOCAL_ROT
	rifle.visible = true
	
	var has_silencer = false
	var has_optic = true
	var camo_id = "default"
	
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if "primary_muzzle" in gm:
			has_silencer = (gm.primary_muzzle == "muzzle_suppressor")
		if "primary_optic" in gm:
			has_optic = (gm.primary_optic != "none")
		if "primary_camo" in gm and gm.primary_camo != "none" and gm.primary_camo != "gold":
			camo_id = gm.primary_camo

	if rifle.has_method("apply_customization"):
		rifle.apply_customization(has_silencer, has_optic, camo_id)

