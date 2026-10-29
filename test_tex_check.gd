extends Node3D

func _ready():
	var tex = load("res://assets/models/weapons/attachments/downloads/free_accessories_extracted/textures/material_baseColor.png") as Texture2D
	var f = FileAccess.open("C:/gemini cli/games/test_tex_check_out.txt", FileAccess.WRITE)
	if tex:
		f.store_line("Texture: size=%s, has_alpha=%s" % [str(tex.get_size()), tex.has_alpha()])
		var img = tex.get_image()
		f.store_line("Image format: %d" % img.get_format())
		# check center pixel
		f.store_line("Center pixel: %s" % str(img.get_pixel(img.get_width() / 2, img.get_height() / 2)))
		f.store_line("Corner pixel: %s" % str(img.get_pixel(0, 0)))
	else:
		f.store_line("Cannot load texture")
	f.close()
	get_tree().quit(0)
