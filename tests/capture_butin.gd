extends SceneTree
## Captures du 2026-11-03 : onglet « Butin » de l'éditeur (160), butin dans une salle du jeu et « Ramasser (E) »
## (161-162), onglets Nourriture et Ingrédients de l'inventaire (163-164) et du marchand (165).
## Pose temporairement du butin dans porte5.json (remis comme avant à la fin). Fenêtre hors écran (override.cfg,
## voir README) : godot --path . -s tests/capture_butin.gd

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
	await attendre(4)
	root.get_viewport().get_texture().get_image().save_png("res://tests/captures/%s.png" % nom)
	print("capture ", nom)


func lancer() -> void:
	seed(5)
	Sauvegarde.reinitialiser_monde()
	Compte.vider()
	var chemin := "res://donnees/salles_peintes/porte5.json"
	var original := FileAccess.get_file_as_string(chemin)
	var donnees = JSON.parse_string(original)
	donnees["butins"] = [{"x": 300, "y": 430, "categorie": "or", "quantite": 75},
		{"x": 420, "y": 470, "categorie": "nourriture", "objet": "Bol de soupe", "quantite": 1},
		{"x": 520, "y": 420, "categorie": "potion", "potion": "pv", "quantite": 1}]
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string(JSON.stringify(donnees, " ", false, true))
	f.close()
	# Éditeur, onglet Butin
	var ed = load("res://scenes/outils/editeur_zones.tscn").instantiate()
	root.add_child(ed)
	await attendre(2)
	ed.numero = ed.salles.find("porte5")
	ed._charger()
	ed.choisir_onglet(true)
	ed.butin_choisi = 1
	ed._remplir_module()
	await capturer("160_editeur_butin")
	ed.queue_free()
	await attendre(2)
	# Jeu : la salle de départ affichée avec porte5
	Ecrans.auto = true
	var joueur = Personnage.nouveau()
	var donjon = Donjon.nouveau(joueur)
	PlanSalles.attribuer(donjon, 1)
	var salle: Dictionary = donjon.salle_courante()
	salle["salle_peinte"]["image"] = "porte5"
	salle["salle_peinte"]["miroir"] = false
	salle["salle_peinte"]["sorties"] = [null, null, null]
	salle["objets_image"] = "porte5"
	salle["objets"] = []
	var nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
	Ecrans.pile.append(nav)
	racine.add_child(nav)
	await attendre(40)
	var sp: SallePeinte = nav.salle_peinte
	sp.heros.position = sp.pied_objet(1) + Vector2(-25, 8)
	await capturer("161_butin_salle")
	nav._fouiller()
	await capturer("162_butin_ramasse")
	nav.fermer()
	Ecrans.pile.clear()
	await attendre(2)
	# Inventaire : nourriture et ingrédients
	for n in ["Pomme", "Pomme", "Viande grillée", "Bol de soupe", "Carotte", "Oignon", "Oignon", "Viande crue", "Rubis"]:
		joueur.recevoir_objet(ObjetsDivers.depuis_catalogue(n))
	var MI := load("res://scripts/ecrans/menu_inventaire.gd")
	MI.categorie_active = "Nourriture"
	Ecrans.menu_inventaire(joueur)
	var ecran = Ecrans.pile[-1]
	await attendre(3)
	Manette.mode_manette = true  # curseur virtuel : la vraie souris n'est jamais déplacée
	Manette.pos = ecran.objets_visuels[0][1].get_center()
	await capturer("163_inventaire_nourriture")
	Manette.mode_manette = false
	MI.categorie_active = "Ingrédients"
	await capturer("164_inventaire_ingredients")
	ecran.fermer()
	await attendre(2)
	var marchand := Marchand.nouveau("marchand", donjon)
	marchand.generer_inventaire()
	var ecran_m = load("res://scripts/ecrans/menu_marchand.gd").new().preparer(marchand, joueur)
	ecran_m.categories["Acheter"] = "Nourriture"
	Ecrans.ouvrir(ecran_m)
	await capturer("165_marchand_nourriture")
	ecran_m.fermer()
	await attendre(2)
	f = FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string(original)
	f.close()
	print("porte5 remise : ", FileAccess.get_file_as_string(chemin) == original)
	Compte.vider()
	quit()
