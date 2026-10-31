extends SceneTree
## Captures du bloc cuisine dans l'écran d'exploration (2026-10-31) : chaque salle du bloc, le héros arrivé par
## chacune de ses portes, et la mini-carte. Fenêtre hors écran (override.cfg, voir README) :
## godot --path . -s tests/capture_bloc_cuisine.gd  → tests/captures/120_* à 129_*

var racine: Control


func _initialize() -> void:
	racine = Control.new()
	racine.size = Vector2(960, 540)
	root.add_child(racine)
	Ecrans.racine = racine
	lancer()


func attendre(images: int) -> void:
	for _i in images:
		await process_frame


func capturer(nom: String) -> void:
	await attendre(8)
	root.get_viewport().get_texture().get_image().save_png("res://tests/captures/%s.png" % nom)
	print("capture ", nom)


func lancer() -> void:
	seed(4242)
	await attendre(2)
	Sauvegarde.reinitialiser_monde()
	var joueur := Personnage.nouveau()
	joueur.points_de_vie_max = 100000
	joueur.points_de_vie = 100000
	var donjon := Donjon.nouveau(joueur)
	var salles: Dictionary = donjon.plan_donjon[1]
	var ids := {}
	for id in salles:
		if salles[id].get("bloc") == "cuisine":
			ids[salles[id]["bloc_salle"]] = id
			salles[id]["presences"] = []  # personne dans le bloc : on regarde les salles
	Ecrans.menu_navigation(joueur, donjon)
	var ecran = Ecrans.pile[-1]
	var n := 120
	for cle in ["manger", "cuisine", "petite", "cellier_g", "cellier_d"]:
		var id: String = ids[cle]
		var info: Dictionary = salles[id]["salle_peinte"]
		for i in info["sorties"].size():
			if info["sorties"][i] == null:
				continue
			donjon.salle_actuelle = [1, int(id)]
			ecran._afficher_salle(i)
			await capturer("%d_bloc_%s_par_%s" % [n, cle, SallePeinte.lire_salle(info["image"])["noms_sorties"][i].replace(" ", "_")])
			n += 1
	print("fin")
	quit()
