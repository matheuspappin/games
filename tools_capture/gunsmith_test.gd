extends Node
# Teste da tela de Gunsmith: abre, entra em MONTAR ARMA, equipa acessórios pelo carrossel e tira prints.
func _ready() -> void:
	_run.call_deferred()

func _shot(name: String) -> void:
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("res://_prints/gunsmith/%s.png" % name)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_prints/gunsmith"))
	var ccs = load("res://scripts/ui/choose_class_screen.gd").new()
	ccs.name = "ChooseClassScreen"
	add_child(ccs)
	await get_tree().create_timer(1.5).timeout
	ccs.open_screen(false)
	await _shot("1_bancada")
	ccs._switch_to_gunsmith_mode()
	await _shot("2_gunsmith")
	var original: Dictionary = ccs.classes[ccs.selected_class_index].duplicate()
	for k in ["optic", "muzzle", "barrel", "underbarrel", "mag", "stock", "grip"]:
		ccs.classes[ccs.selected_class_index][k] = "none"
	var log := []
	for pair in [["optic", "optic_holo"], ["muzzle", "muzzle_suppressor"], ["underbarrel", "grip_vertical"], ["mag", "mag_extended"], ["stock", "stock_heavy"], ["grip", "grip_stippled"]]:
		ccs._on_socket_pin_pressed(pair[0])
		ccs._equip_attachment_from_carousel(pair[0], pair[1])
		log.append("%s=%s" % [pair[0], ccs.classes[ccs.selected_class_index].get(pair[0], "?")])
	await _shot("3_montada")
	log.append("contador: " + ccs.lbl_modifications_counter.text)
	log.append("titulo carrossel: " + ccs.lbl_carousel_socket_title.text)
	var vis := []
	for k in ccs.socket_pins: vis.append("%s:%s" % [k, ccs.socket_pins[k].visible])
	log.append("pinos visiveis: " + ", ".join(vis))
	# restaura a classe do jogador exatamente como estava
	ccs.classes[ccs.selected_class_index] = original
	SaveSystem.save_loadout(ccs.selected_class_index, original)
	FileAccess.open("res://_prints/gunsmith_test.txt", FileAccess.WRITE).store_string("\n".join(log))
	get_tree().quit()
