extends SceneTree
## Captures de la cuisine (2026-11-03) : onglet « Feux » de l'éditeur (170), écran de cuisine (171-172), feu de camp
## dans une salle et intoxication affichée (173). Rien n'est enregistré dans les salles. Fenêtre hors écran
## (override.cfg, voir README) : godot --path . -s tests/capture_cuisine.gd

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
	seed(9)
	Sauvegarde.reinitialiser_monde()
	Compte.vider()
	# Éditeur, onglet Feux (deux torches marquées, non enregistrées)
	var ed = load("res://scenes/outils/editeur_zones.tscn").instantiate()
	root.add_child(ed)
	await attendre(2)
	ed.numero = ed.salles.find("porte5")
	ed._charger()
	ed.choisir_feux()
	ed.salle.donnees["feux"] = [[150, 470], [626, 470]]
	await capturer("170_editeur_feux")
	ed.queue_free()
	await attendre(2)
	# Écran de cuisine : torche à portée et feu de camp
	var joueur = Personnage.nouveau()
	var donjon = Donjon.nouveau(joueur)
	for n in ["Viande crue", "Viande crue", "Oignon", "Tomate", "Carotte", "Pomme", "Pomme", "Œuf", "Œuf", "Champignon", "Marmite", "Seau en bois", "Planche en bois"]:
		joueur.inventaire.append(ObjetsDivers.depuis_catalogue(n))
	Cuisine.seau(joueur)._d["eau"] = 7
	var salle := {}
	var ctx := {"torche": true, "cuisine": false, "salle": salle, "pos": [380, 470]}
	salle["feu_de_camp"] = {"debut": 0.0, "plats": 1, "x": 380, "y": 470}
	var ecran = Ecrans._ecran("menu_cuisine").preparer(joueur, ctx)
	Ecrans.ouvrir(ecran)
	await attendre(3)
	ecran.ajouter("Viande crue")
	ecran.ajouter("Oignon")
	ecran.ajouter("Tomate")
	await capturer("171_cuisine")
	ecran.lancer_cuisson()
	await capturer("172_cuisine_brochette")
	ecran.fermer()
	await attendre(2)
	# Salle avec un feu de camp, héros intoxiqué
	Ecrans.auto = true
	PlanSalles.attribuer(donjon, 1)
	var s: Dictionary = donjon.salle_courante()
	s["salle_peinte"]["image"] = "porte5"
	s["salle_peinte"]["miroir"] = false
	s["salle_peinte"]["sorties"] = [null, null, null]
	s["feu_de_camp"] = {"debut": 0.0, "plats": 0, "x": 470, "y": 440}
	Maux.infliger(joueur, "intoxication")
	var nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
	Ecrans.pile.append(nav)
	racine.add_child(nav)
	await attendre(40)
	await capturer("173_feu_de_camp")
	print("fin")
	Compte.vider()
	quit()
