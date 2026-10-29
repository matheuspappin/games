# =============================================================================
# firing_range_target.gd
# Alvo Reativo Tático para Estande de Tiro — Estilo Call of Duty (MWII/MWIII/BO6)
# Suporta:
# - Zonas de acerto com multiplicadores (Headshot, Chest, Limbs)
# - Sistema de Placas de Blindagem CoD (0, 1, 2, 3 Placas -> 100, 150, 200, 250 HP)
# - Feedback visual de impacto, recuo reativo e tombamento balístico
# - Auto-reset pós-abate (1.2s) e reset manual
# - Telemetria em tempo real: STK (Shots to Kill), Dano por tiro e TTK (ms)
# =============================================================================
class_name FiringRangeTarget
extends Node3D

signal target_hit(target_name: String, hit_zone: String, damage: int, is_crit: bool, remaining_hp: int, max_hp: int, distance: float)
signal target_killed(target_name: String, distance: float, shots_to_kill: int, ttk_ms: float, total_damage: int)
signal target_reset(target_name: String)

enum ArmorPlateCount { NONE = 0, ONE = 1, TWO = 2, THREE = 3 }

@export var target_display_name : String = "ALVO"
@export var distance_meters     : float = 10.0
@export var current_plates      : ArmorPlateCount = ArmorPlateCount.NONE

# Nós internos
@onready var visual_root        : Node3D           = $VisualRoot
@onready var swivel_pivot      : Node3D           = $VisualRoot/SwivelPivot
@onready var plate_mesh        : MeshInstance3D   = $VisualRoot/SwivelPivot/PlateMesh
@onready var head_mesh         : MeshInstance3D   = $VisualRoot/SwivelPivot/HeadMesh
@onready var chest_mesh        : MeshInstance3D   = $VisualRoot/SwivelPivot/ChestMesh
@onready var label_damage      : Label3D          = $LabelDamage
@onready var label_stats       : Label3D          = $LabelStats
@onready var health_comp       : HealthComponent  = $HealthComponent

# Hitboxes
@onready var hitbox_head       : HitboxComponent  = $Hitbox_Head
@onready var hitbox_chest      : HitboxComponent  = $Hitbox_Chest
@onready var hitbox_limbs      : HitboxComponent  = $Hitbox_Limbs

# Estado Balístico
var max_health           : int = 100
var current_armor        : int = 0
var max_armor            : int = 0
var is_down              : bool = false
var auto_reset_timer     : float = 0.0

# Telemetria de rajada (TTK)
var shots_taken          : int = 0
var total_damage_dealt   : int = 0
var first_hit_time_ms    : int = 0
var last_hit_time_ms     : int = 0

# Materiais dinâmicos para placas
var plate_mat            : StandardMaterial3D = null

func _ready() -> void:
	if plate_mesh:
		plate_mat = StandardMaterial3D.new()
		plate_mesh.set_surface_override_material(0, plate_mat)

	if health_comp:
		health_comp.damage_taken.connect(_on_health_damage_taken)
		health_comp.died.connect(_on_health_died)

	_setup_hitboxes()
	set_armor_plates(current_plates)
	_update_stats_label()

func _setup_hitboxes() -> void:
	for hb in [hitbox_head, hitbox_chest, hitbox_limbs]:
		if hb and is_instance_valid(hb):
			hb.set_meta("firing_target", self)


func _process(delta: float) -> void:
	if is_down:
		auto_reset_timer -= delta
		if auto_reset_timer <= 0.0:
			reset_target()

# ── CONFIGURAÇÃO DE PLACAS DE BLINDAGEM (ESTILO COD) ──────────────────────────
func set_armor_plates(count: ArmorPlateCount) -> void:
	current_plates = count
	match count:
		ArmorPlateCount.NONE:
			max_health = 100
			max_armor = 0
			current_armor = 0
			if plate_mesh: plate_mesh.visible = false
		ArmorPlateCount.ONE:
			max_health = 100
			max_armor = 50
			current_armor = 50
			_setup_plate_visual(Color(0.2, 0.6, 1.0, 0.9), "1 PLACA (150 HP)")
		ArmorPlateCount.TWO:
			max_health = 100
			max_armor = 100
			current_armor = 100
			_setup_plate_visual(Color(0.7, 0.3, 1.0, 0.95), "2 PLACAS (200 HP)")
		ArmorPlateCount.THREE:
			max_health = 100
			max_armor = 150
			current_armor = 150
			_setup_plate_visual(Color(1.0, 0.75, 0.15, 1.0), "3 PLACAS (250 HP)")

	if health_comp:
		health_comp.max_health = max_health
		health_comp.current_health = max_health
		health_comp.is_dead = false

	is_down = false
	shots_taken = 0
	total_damage_dealt = 0
	first_hit_time_ms = 0

	if swivel_pivot:
		swivel_pivot.rotation.x = 0.0

	_update_stats_label()

func _setup_plate_visual(color: Color, _desc: String) -> void:
	if not plate_mesh or not plate_mat:
		return
	plate_mesh.visible = true
	plate_mat.albedo_color = color
	plate_mat.emission_enabled = true
	plate_mat.emission = color * 0.45
	plate_mat.roughness = 0.35
	plate_mat.metallic = 0.6

# ── RECEBIMENTO DE DISPARO BALÍSTICO ──────────────────────────────────────────
func receive_bullet_hit(hit_zone: String, weapon_data: WeaponData, distance: float, is_crit: bool, attacker: Node = null) -> void:
	if is_down:
		return

	var now = Time.get_ticks_msec()
	if shots_taken == 0:
		first_hit_time_ms = now
	shots_taken += 1
	last_hit_time_ms = now

	# Cálculo de dano pelo WeaponData
	var base_dmg = weapon_data.get_damage_at_distance(distance) if weapon_data else 35.0
	var mult = 1.0
	if is_crit:
		mult = weapon_data.headshot_multiplier if weapon_data else 1.75
	elif hit_zone == "Chest":
		mult = weapon_data.chest_multiplier if weapon_data else 1.0
	else:
		mult = 0.85

	var final_dmg = int(base_dmg * mult)
	total_damage_dealt += final_dmg

	# 1. Absorção por Placa de Armadura
	var absorbed_by_armor = 0
	if current_armor > 0:
		if current_armor >= final_dmg:
			current_armor -= final_dmg
			absorbed_by_armor = final_dmg
			_play_armor_hit_effect(false)
		else:
			absorbed_by_armor = current_armor
			current_armor = 0
			_play_armor_hit_effect(true) # Quebrou a placa

	var health_damage = final_dmg - absorbed_by_armor
	if health_damage > 0 and health_comp:
		health_comp.take_damage(health_damage, Vector3.ZERO, hit_zone, attacker)
	else:
		_show_damage_popup(final_dmg, is_crit, true)

	var total_remaining = (health_comp.current_health if health_comp else 0) + current_armor
	var total_max = max_health + max_armor

	target_hit.emit(target_display_name, hit_zone, final_dmg, is_crit, total_remaining, total_max, distance_meters)
	_update_stats_label()

	# Impacto físico / recuo balístico
	if swivel_pivot and not is_down:
		swivel_pivot.rotation.x = -0.12
		var t = create_tween()
		t.tween_property(swivel_pivot, "rotation:x", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_health_damage_taken(amount: int, _dir: Vector3) -> void:
	_show_damage_popup(amount, false, false)

func _on_health_died(_dir: Vector3, _bone: String) -> void:
	if is_down:
		return
	is_down = true
	auto_reset_timer = 1.25

	var ttk_ms = float(last_hit_time_ms - first_hit_time_ms)
	if shots_taken <= 1:
		ttk_ms = 0.0

	target_killed.emit(target_display_name, distance_meters, shots_taken, ttk_ms, total_damage_dealt)

	if label_damage:
		label_damage.text = "ABATIDO! [TTK: %.0f ms]" % ttk_ms
		label_damage.modulate = Color(1.0, 0.85, 0.15, 1.0)
		label_damage.position.y = 2.45
		var t_lbl = create_tween()
		t_lbl.tween_property(label_damage, "position:y", 2.8, 0.45)

	# Tombar para trás (-85 graus)
	if swivel_pivot:
		var t = create_tween()
		t.tween_property(swivel_pivot, "rotation:x", deg_to_rad(-85.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

func reset_target() -> void:
	set_armor_plates(current_plates)
	if swivel_pivot:
		var t = create_tween()
		t.tween_property(swivel_pivot, "rotation:x", 0.0, 0.25).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	if label_damage:
		label_damage.text = ""
	target_reset.emit(target_display_name)

# ── POPUPS E FEEDBACK VISUAL ──────────────────────────────────────────────────
func _show_damage_popup(amount: int, is_crit: bool, hit_armor: bool) -> void:
	if not label_damage:
		return

	if hit_armor and current_armor > 0:
		label_damage.text = "🛡️ -%d" % amount
		label_damage.modulate = Color(0.3, 0.75, 1.0, 1.0)
	elif is_crit:
		label_damage.text = "💥 CRIT -%d" % amount
		label_damage.modulate = Color(1.0, 0.2, 0.2, 1.0)
	else:
		label_damage.text = "-%d" % amount
		label_damage.modulate = Color(1.0, 0.85, 0.3, 1.0)

	label_damage.position.y = 2.15
	label_damage.scale = Vector3(1.3, 1.3, 1.3)
	var t = create_tween()
	t.tween_property(label_damage, "position:y", 2.55, 0.35)
	t.parallel().tween_property(label_damage, "scale", Vector3.ONE, 0.2)
	t.parallel().tween_property(label_damage, "modulate:a", 0.0, 0.55).set_delay(0.2)

func _play_armor_hit_effect(broken: bool) -> void:
	if plate_mesh and plate_mat:
		var flash_col = Color(1.5, 0.2, 0.2, 1.0) if broken else Color(2.0, 2.0, 2.0, 1.0)
		plate_mat.emission = flash_col
		var t = create_tween()
		var orig = Color(0.2, 0.6, 1.0, 0.9) if current_plates == ArmorPlateCount.ONE else Color(1.0, 0.75, 0.15, 1.0)
		t.tween_property(plate_mat, "emission", orig * 0.45, 0.25)

func _update_stats_label() -> void:
	if not label_stats:
		return
	var cur_hp = health_comp.current_health if health_comp else 100
	var total_cur = cur_hp + current_armor
	var total_m = max_health + max_armor

	var plate_icons = ""
	for i in range(current_plates):
		plate_icons += "■ "

	var plate_str = " (SEM PLACAS)" if current_plates == ArmorPlateCount.NONE else " [%s]" % plate_icons.strip_edges()
	label_stats.text = "%s  •  %.0fm\nHP: %d / %d%s" % [
		target_display_name,
		distance_meters,
		total_cur,
		total_m,
		plate_str
	]
