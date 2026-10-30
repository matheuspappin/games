extends Node
# Dispara no Windows o .bat indicado em _prints/run_bat.txt e fecha (ferramenta de automação).
func _ready() -> void:
	var bat := FileAccess.get_file_as_string("res://_prints/run_bat.txt").strip_edges()
	if bat != "":
		OS.create_process("cmd.exe", ["/c", ProjectSettings.globalize_path("res://tools_capture/" + bat)])
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()
