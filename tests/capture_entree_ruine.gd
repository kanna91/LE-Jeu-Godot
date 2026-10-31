extends SceneTree
## Charge la scène 3D « entrée en ruine » (scenes/3d/entree_ruine.tscn, générée depuis Blender)
## et enregistre une capture dans tests/captures/70_entree_ruine_3d.png.
## À lancer dans une fenêtre hors écran (override.cfg, voir README), après `--import` :
##   Godot_v4.7.2-stable_win64_console.exe --path . -s tests/capture_entree_ruine.gd

func _initialize() -> void:
	var paquet: PackedScene = load("res://scenes/3d/entree_ruine.tscn")
	if paquet == null:
		print("ECHEC : scène introuvable")
		quit(1)
		return
	root.size = Vector2i(1536, 1024)
	root.add_child(paquet.instantiate())
	lancer()


func lancer() -> void:
	for _i in 30:   # laisse le temps aux ombres, au brouillard volumétrique et à l'exposition de se stabiliser
		await process_frame
	var image := root.get_viewport().get_texture().get_image()
	image.save_png("res://tests/captures/70_entree_ruine_3d.png")
	print("capture 70_entree_ruine_3d (%d x %d)" % [image.get_width(), image.get_height()])
	quit()
