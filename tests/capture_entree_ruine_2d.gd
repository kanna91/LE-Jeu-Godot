extends SceneTree
## Captures des décors 2D en calques (scenes/2d/*.tscn), rendus dans un SubViewport de taille fixe :
##   71 / 73 : entrée en ruine / salle porte 2 à la taille de l'image (1536 x 1024), sans animation : doivent redonner
##             l'image de référence (comparer avec travail/hd.png du décor)
##   72 / 74 / 75 : entrée en ruine, salle porte 2, assemblage de la salle porte 2, en 960 x 540 avec animations
## À lancer dans une fenêtre hors écran (override.cfg, voir README), après `--import` :
##   Godot_v4.7.2-stable_win64_console.exe --path . -s tests/capture_entree_ruine_2d.gd

func _initialize() -> void:
	lancer()


func capturer(scene: String, taille: Vector2i, anime: bool, fichier: String) -> void:
	var paquet: PackedScene = load("res://scenes/2d/" + scene + ".tscn")
	if paquet == null:
		print("ECHEC : scène introuvable : " + scene)
		quit(1)
		return
	var vue := SubViewport.new()          # taille exacte, indépendante de la fenêtre
	vue.size = taille
	vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vue)
	var decor := paquet.instantiate()
	decor.anime = anime
	vue.add_child(decor)
	for _i in 20:
		await process_frame
	var image := vue.get_texture().get_image()
	image.save_png("res://tests/captures/" + fichier)
	print("capture %s (%d x %d)" % [fichier, image.get_width(), image.get_height()])
	vue.queue_free()
	await process_frame


func lancer() -> void:
	await capturer("entree_ruine_2d", Vector2i(1536, 1024), false, "71_entree_ruine_2d.png")
	await capturer("entree_ruine_2d", Vector2i(960, 540), true, "72_entree_ruine_2d_anime.png")
	await capturer("salle_porte_2_2d", Vector2i(1536, 1024), false, "73_salle_porte_2_2d.png")
	await capturer("salle_porte_2_2d", Vector2i(960, 540), true, "74_salle_porte_2_2d_anime.png")
	await capturer("assemblage_salle_porte_2", Vector2i(960, 540), true, "75_assemblage_salle_porte_2.png")
	quit()
