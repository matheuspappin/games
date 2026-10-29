extends Node3D

func _ready():
	var scn = load("res://addons/fps-hands/fps-ak/fps-ak.tscn") as PackedScene
	var inst = scn.instantiate()
	add_child(inst)

	var atree = inst.get_node("AnimationTree") as AnimationTree
	var aplayer = inst.get_node("AnimationPlayer") as AnimationPlayer
	var sm = atree.get("parameters/playback") as AnimationNodeStateMachinePlayback

	var f = FileAccess.open("C:/gemini cli/games/test_anim_tree_out.txt", FileAccess.WRITE)
	f.store_line("atree active: %s, aplayer: %s" % [atree.active, aplayer.name])
	f.store_line("anim list: %s" % str(aplayer.get_animation_list()))
	f.store_line("take anim length: %f" % aplayer.get_animation("take").length)

	# Let's advance 10 steps manually and check
	for i in range(20):
		atree.advance(0.1)
		f.store_line("step %d (t=%.1f): current=%s, pos=%.2f" % [i, i*0.1, sm.get_current_node(), sm.get_current_play_position()])

	f.close()
	get_tree().quit(0)
