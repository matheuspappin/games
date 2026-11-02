# =============================================================================
# firing_range_manager.gd
# Gerenciador do Estande de Tiro Balístico Tático (Call of Duty Style)
# Responsável por:
# - Spawna e configura o Player local com o armamento atual do Create-a-Class
# - Munição infinita em reserva (para teste contínuo de recoil e recargas)
# - Conexão dos alvos reativos (10m, 25m, 50m) com o HUD de telemetria
# - Abertura instantânea do Gunsmith in-range via [TAB] ou [ESC] para testar anexos
# - Troca rápida de Placas de Colete nos alvos via [1, 2, 3, 4]
# - Retorno ao Menu Principal com [BACKSPACE] ou botão de saída
# =============================================================================
class_name FiringRangeManager
extends Node3D

const ChooseClassScreenScript = preload("res://scripts/ui/choose_class_screen.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")
const HUDScene = preload("res://scenes/ui/hud.tscn")

@export var spawn_point           : Marker3D
@export var target_10m            : FiringRangeTarget
@export var target_25m            : FiringRangeTarget
@export var target_50m            : FiringRangeTarget
@export var firing_range_hud      : FiringRangeHUD

var local_player                  : PlayerCharacter = null
var weapon_manager                : WeaponManager = null
var in_range_class_screen         : ChooseClassScreen = null
var is_gunsmith_open              : bool = false

func _ready() -> void:
	print("[FiringRangeManager] Inicializando Estande de Tiro Tático...")
	# Garantir que o GameManager saiba que estamos no estande, e NÃO em partida ranqueada
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.is_match_active = false
		gm.current_state = GameManager.GameState.MENU

	_setup_hud()
	_setup_targets()
	_spawn_or_find_player()
	_setup_in_range_gunsmith()

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _setup_hud() -> void:
	if not firing_range_hud:
		firing_range_hud = find_child("FiringRangeHUD", true, false) as FiringRangeHUD

	if firing_range_hud:
		firing_range_hud.armor_plates_changed.connect(_on_armor_plates_changed)
		firing_range_hud.reset_targets_requested.connect(reset_all_targets)
		firing_range_hud.refill_ammo_requested.connect(refill_player_ammo)
		firing_range_hud.open_gunsmith_requested.connect(toggle_in_range_gunsmith)
		firing_range_hud.exit_firing_range_requested.connect(exit_to_main_menu)

	# Instanciar HUD clássico de retículo / hitmarker caso não exista
	var basic_hud = find_child("HUD", true, false)
	if not basic_hud:
		var h = HUDScene.instantiate()
		add_child(h)

func _setup_targets() -> void:
	var targets: Array[FiringRangeTarget] = []
	if target_10m: targets.append(target_10m)
	if target_25m: targets.append(target_25m)
	if target_50m: targets.append(target_50m)

	# Se não foram atribuídos via export, buscar na árvore
	if targets.is_empty():
		for ch in find_children("*", "FiringRangeTarget", true, false):
			if ch is FiringRangeTarget:
				targets.append(ch)

	for t in targets:
		if t:
			t.target_hit.connect(_on_target_hit)
			t.target_killed.connect(_on_target_killed)

func _spawn_or_find_player() -> void:
	local_player = find_child("Player*", true, false) as PlayerCharacter
	if not local_player:
		local_player = PlayerScene.instantiate() as PlayerCharacter
		local_player.name = "Player_Local"
		add_child(local_player)

	var spawn_pos = spawn_point.global_position if spawn_point else Vector3(0, 0.1, 0)
	local_player.global_position = spawn_pos
	local_player.immobile = false

	call_deferred("_setup_player_weapons")

func _setup_player_weapons() -> void:
	if not local_player:
		return

	weapon_manager = local_player.get_node_or_null("Head/Camera/WeaponRig/WeaponManager") as WeaponManager
	if not weapon_manager:
		weapon_manager = local_player.find_child("WeaponManager", true, false) as WeaponManager

	if weapon_manager:
		weapon_manager.fire_event.connect(_on_player_fired)
		weapon_manager.ammo_changed.connect(_on_player_ammo_changed)

		# Equipar armas salvas do GameManager / Create-a-Class
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			var prim_res = gm.get_primary_weapon()
			var sec_res = gm.get_secondary_weapon()
			var mel_res = gm.get_melee_weapon()
			if prim_res: weapon_manager.default_weapon = prim_res
			if sec_res: weapon_manager.secondary_weapon = sec_res
			if mel_res: weapon_manager.melee_weapon = mel_res

			if prim_res and weapon_manager.has_method("equip"):
				weapon_manager.equip(prim_res)

			# Aplicar customizações de camuflagem, mira e cano
			var fps_vm = weapon_manager.weapon_rig.get_node_or_null("FpsHandsViewModel") if weapon_manager.weapon_rig else null
			if fps_vm and fps_vm.has_method("set_weapon_customization"):
				fps_vm.set_weapon_customization(gm.primary_camo, gm.primary_optic, gm.primary_muzzle, gm.primary_mag, gm.primary_underbarrel, gm.primary_stock, gm.primary_grip, gm.primary_barrel)

		# Garantir munição infinita na reserva para testes
		_ensure_infinite_ammo()

func _ensure_infinite_ammo() -> void:
	if weapon_manager and weapon_manager.weapon_data:
		weapon_manager.reserve_ammo = weapon_manager.weapon_data.reserve_ammo_max * 10
		weapon_manager.ammo_changed.emit(weapon_manager.current_ammo, weapon_manager.reserve_ammo)

func _on_player_fired() -> void:
	if firing_range_hud:
		firing_range_hud.record_shot_fired()

func _on_player_ammo_changed(current: int, _reserve: int) -> void:
	# Manter reserva sempre abundante para testes balísticos sem frustração
	if weapon_manager and weapon_manager.weapon_data:
		if weapon_manager.reserve_ammo < weapon_manager.weapon_data.magazine_capacity * 2:
			weapon_manager.reserve_ammo = weapon_manager.weapon_data.reserve_ammo_max * 10

func refill_player_ammo() -> void:
	if weapon_manager and weapon_manager.weapon_data:
		weapon_manager.current_ammo = weapon_manager.weapon_data.magazine_capacity
		weapon_manager.reserve_ammo = weapon_manager.weapon_data.reserve_ammo_max * 10
		weapon_manager.ammo_changed.emit(weapon_manager.current_ammo, weapon_manager.reserve_ammo)

# ── SINCRONIZAÇÃO DE ALVOS COM HUD ─────────────────────────────────────────────
func _on_target_hit(t_name: String, hit_zone: String, damage: int, is_crit: bool, remaining_hp: int, max_hp: int, distance: float) -> void:
	if firing_range_hud:
		firing_range_hud.record_target_hit(t_name, hit_zone, damage, is_crit, remaining_hp, max_hp, distance)

func _on_target_killed(t_name: String, distance: float, shots: int, ttk_ms: float, total_dmg: int) -> void:
	if firing_range_hud:
		firing_range_hud.record_target_killed(t_name, distance, shots, ttk_ms, total_dmg)

func _on_armor_plates_changed(count: int) -> void:
	for t in [target_10m, target_25m, target_50m]:
		if t and is_instance_valid(t):
			t.set_armor_plates(count as FiringRangeTarget.ArmorPlateCount)

func reset_all_targets() -> void:
	for t in [target_10m, target_25m, target_50m]:
		if t and is_instance_valid(t):
			t.reset_target()

# ── GUNSMITH IN-RANGE (ABERTURA INSTANTÂNEA NO ESTANDE) ─────────────────────────
func _setup_in_range_gunsmith() -> void:
	in_range_class_screen = ChooseClassScreenScript.new()
	in_range_class_screen.name = "InRangeGunsmith"
	add_child(in_range_class_screen)
	in_range_class_screen.class_selected.connect(_on_gunsmith_class_changed)
	in_range_class_screen.screen_closed.connect(_on_gunsmith_closed)

func toggle_in_range_gunsmith() -> void:
	if not in_range_class_screen:
		return

	if in_range_class_screen.is_open:
		in_range_class_screen.close_screen()
	else:
		in_range_class_screen.open_screen(false)
		is_gunsmith_open = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_gunsmith_class_changed(class_data: Dictionary) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.primary_camo = class_data.get("camo", "default")
		gm.primary_optic = class_data.get("optic", "optic_red_dot")
		gm.primary_muzzle = class_data.get("muzzle", "none")
		gm.primary_mag = class_data.get("mag", "none")

	# Reaplicar arma e anexos no jogador local imediatamente
	call_deferred("_setup_player_weapons")

func _on_gunsmith_closed() -> void:
	is_gunsmith_open = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	call_deferred("_setup_player_weapons")

# ── CONTROLES E ENTRADAS DO ESTANDE ───────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		# Se a tela do Gunsmith estiver aberta, deixa ela processar seus próprios inputs
		if in_range_class_screen and in_range_class_screen.is_open:
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_TAB:
				in_range_class_screen.close_screen()
				get_viewport().set_input_as_handled()
			return

		# Tecla TAB ou ESC: Abre Gunsmith dentro do estande
		if event.keycode == KEY_TAB or event.keycode == KEY_ESCAPE:
			toggle_in_range_gunsmith()
			get_viewport().set_input_as_handled()
			return

		# Teclas 1, 2, 3, 4: Alternar Placas de Colete
		if event.keycode == KEY_1:
			if firing_range_hud: firing_range_hud.cycle_armor_plates(0)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_2:
			if firing_range_hud: firing_range_hud.cycle_armor_plates(1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_3:
			if firing_range_hud: firing_range_hud.cycle_armor_plates(2)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_4:
			if firing_range_hud: firing_range_hud.cycle_armor_plates(3)
			get_viewport().set_input_as_handled()

		# Tecla R: Resetar Alvos
		elif event.keycode == KEY_R and Input.is_key_pressed(KEY_ALT):
			# Se ALT+R, reseta alvos (pois R normal recarrega arma)
			reset_all_targets()
			get_viewport().set_input_as_handled()

		# Tecla F5: Resetar Alvos imediato
		elif event.keycode == KEY_F5:
			reset_all_targets()
			get_viewport().set_input_as_handled()

		# Tecla F: Reabastecimento rápido de munição se segurar CTRL ou F6
		elif event.keycode == KEY_F6:
			refill_player_ammo()
			get_viewport().set_input_as_handled()

		# Tecla BACKSPACE ou DELETE: Sair do estande e retornar ao Menu
		elif event.keycode == KEY_BACKSPACE:
			exit_to_main_menu()
			get_viewport().set_input_as_handled()

func exit_to_main_menu() -> void:
	print("[FiringRangeManager] Saindo do Estande de Tiro. Retornando ao Menu Principal...")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.is_match_active = false
		gm.current_state = GameManager.GameState.MENU
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
