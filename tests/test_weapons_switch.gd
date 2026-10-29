extends SceneTree

func _init():
	print("\n==========================================")
	print("TEST: VERIFICAÇÃO DE TROCA DE ARMAS E MODELOS")
	print("==========================================")

	var player_scene = load("res://scenes/player/player.tscn")
	if not player_scene:
		print("❌ FALHA: Cena player.tscn não encontrada!")
		quit(1)
		return

	var player = player_scene.instantiate()
	root.add_child(player)

	# Processar um frame para garantir que _ready() execute em todos os nós
	await process_frame
	await process_frame

	var wm = player.find_child("WeaponManager", true, false) as WeaponManager
	if not wm:
		print("❌ FALHA: WeaponManager não encontrado no Player!")
		quit(1)
		return

	var primary_vm = wm.primary_viewmodel
	var secondary_vm = wm.secondary_viewmodel

	if not primary_vm:
		print("❌ FALHA: Primary ViewModel não encontrado!")
		quit(1)
		return

	if not secondary_vm:
		print("❌ FALHA: Secondary ViewModel não encontrado!")
		quit(1)
		return

	print("✅ Primary ViewModel encontrado: ", primary_vm.name, " (", primary_vm.get_class(), ")")
	print("✅ Secondary ViewModel encontrado: ", secondary_vm.name, " (", secondary_vm.get_class(), ")")

	# 1. Testar estado inicial (Arma Primária equipada)
	print("\n--- 1. ESTADO INICIAL (ARMA PRIMÁRIA) ---")
	print("Primary visível: ", primary_vm.visible)
	print("Secondary visível: ", secondary_vm.visible)
	assert(primary_vm.visible == true, "Primary deve estar visível")
	assert(secondary_vm.visible == false, "Secondary deve estar oculta")

	# Verificar braços da arma primária
	var prim_arms = primary_vm.find_child("Object_10", true, false)
	var prim_rifle = primary_vm.find_child("Object_12", true, false)
	print("Braços do personagem na primária (Object_10): ", "Visível" if (prim_arms and prim_arms.visible) else "Invisível")
	print("Fuzil ACR na primária (Object_12): ", "Visível" if (prim_rifle and prim_rifle.visible) else "Invisível")

	# 2. Trocar para Arma Secundária
	print("\n--- 2. TROCA PARA ARMA SECUNDÁRIA ---")
	wm.equip(wm.secondary_weapon)
	await process_frame

	print("Primary visível: ", primary_vm.visible)
	print("Secondary visível: ", secondary_vm.visible)
	assert(primary_vm.visible == false, "Primary deve estar oculta")
	assert(secondary_vm.visible == true, "Secondary deve estar visível")

	# Verificar se a secundária utiliza o MESMO personagem (braços táticos)
	var sec_arms = secondary_vm.find_child("Object_10", true, false)
	var sec_rifle = secondary_vm.find_child("Object_12", true, false)
	var sec_m9 = secondary_vm.find_child("BerettaM9", true, false)

	print("Braços do personagem na secundária (Object_10): ", "PRESENTE e VISÍVEL" if (sec_arms and sec_arms.visible) else "AUSENTE/INVISÍVEL")
	print("Fuzil ACR na secundária (Object_12 oculto): ", "OCULTO CORRETAMENTE" if (sec_rifle and not sec_rifle.visible) else "ERRO")
	print("Beretta M9 na secundária (modelo HD): ", "PRESENTE e ANEXADO" if (sec_m9 != null) else "AUSENTE")

	assert(sec_arms != null and sec_arms.visible == true, "Secundária DEVE usar os mesmos braços do personagem")
	assert(sec_rifle != null and sec_rifle.visible == false, "Fuzil ACR DEVE estar oculto na secundária")
	assert(sec_m9 != null, "Beretta M9 DEVE estar presente na secundária")

	# 3. Testar disparo e animações na secundária
	print("\n--- 3. TESTE DE ANIMAÇÕES E DISPARO NA SECUNDÁRIA ---")
	if secondary_vm.has_method("play_shoot"):
		secondary_vm.play_shoot()
		print("Disparo executado com sucesso (slide animado)")
	if secondary_vm.has_method("play_walk"):
		secondary_vm.play_walk()
		print("Caminhada executada com sucesso")
	if secondary_vm.has_method("play_sprint"):
		secondary_vm.play_sprint()
		print("Corrida executada com sucesso")

	# 4. Voltar para Primária
	print("\n--- 4. RETORNO PARA ARMA PRIMÁRIA ---")
	wm.equip(wm.default_weapon)
	await process_frame

	print("Primary visível: ", primary_vm.visible)
	print("Secondary visível: ", secondary_vm.visible)
	assert(primary_vm.visible == true, "Primary deve voltar a ficar visível")
	assert(secondary_vm.visible == false, "Secondary deve voltar a ficar oculta")

	print("\n==========================================")
	print("🎉 TODOS OS TESTES PASSARAM COM SUCESSO!")
	print("==========================================")

	quit(0)
