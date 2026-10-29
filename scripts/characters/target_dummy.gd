# =============================================================================
# target_dummy.gd
# Manequim de teste com HealthComponent e HitboxComponent (Head, Chest, Limbs)
# Mostra popup de dano 3D flutuante e animação de tombo ao morrer
# =============================================================================
class_name TargetDummy
extends Node3D

@onready var health_component : HealthComponent = $HealthComponent
@onready var label_damage     : Label3D         = $DamageLabel3D
@onready var mesh_root         : Node3D          = $VisualMesh

var initial_transform : Transform3D
var respawn_timer     : float = 0.0

func _ready() -> void:
	initial_transform = global_transform
	if health_component:
		health_component.damage_taken.connect(_on_damage_taken)
		health_component.died.connect(_on_died)
	if label_damage:
		label_damage.text = ""

func _process(delta: float) -> void:
	if health_component and health_component.is_dead:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_respawn()

func _on_damage_taken(amount: int, direction: Vector3) -> void:
	if label_damage:
		label_damage.text = "-%d HP" % amount
		label_damage.modulate = Color(1.0, 0.3, 0.2, 1.0)
		label_damage.position.y = 2.2
		var tween = create_tween()
		tween.tween_property(label_damage, "position:y", 2.6, 0.4)
		tween.parallel().tween_property(label_damage, "modulate:a", 0.0, 0.6)

	# Pequeno recuo no impacto
	if mesh_root:
		mesh_root.rotation.x = -0.15
		var t = create_tween()
		t.tween_property(mesh_root, "rotation:x", 0.0, 0.25)

func _on_died(death_direction: Vector3, hit_bone: String) -> void:
	if label_damage:
		label_damage.text = "ELIMINADO! (%s)" % hit_bone
		label_damage.modulate = Color(1.0, 0.85, 0.1, 1.0)
		var tween = create_tween()
		tween.tween_property(label_damage, "position:y", 2.7, 0.5)

	# Tombar para trás
	if mesh_root:
		var t = create_tween()
		t.tween_property(mesh_root, "rotation:x", deg_to_rad(-80), 0.3)
	respawn_timer = 2.0

func _respawn() -> void:
	if health_component:
		health_component.revive()
	if mesh_root:
		var t = create_tween()
		t.tween_property(mesh_root, "rotation:x", 0.0, 0.3)
	if label_damage:
		label_damage.text = ""
