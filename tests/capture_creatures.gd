extends SceneTree
## Loups et squelettes à l'écran : en combat (chaman + loup, puis deux squelettes) et dans une salle (un groupe avec
## loup, un groupe de squelettes). Captures 105 à 107. Fenêtre hors écran (override.cfg, voir README).

var racine: Control


func _initialize() -> void:
	racine = Control.new()
	racine.size = Vector2(960, 540)
	root.add_child(racine)
	Ecrans.racine = racine
	lancer()


func attendre(n: int) -> void:
	for _i in n:
		await process_frame


func capturer(nom: String) -> void:
	await attendre(3)
	root.get_viewport().get_texture().get_image().save_png("res://tests/captures/%s.png" % nom)
	print("capture ", nom)


func lancer() -> void:
	seed(4)
	Sauvegarde.reinitialiser_monde()
	Statistiques.mort = false
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	PlanSalles.attribuer(donjon, 1)
	var salle: Dictionary = donjon.salle_courante()
	salle["salle_peinte"]["image"] = "porte2"
	salle["salle_peinte"]["miroir"] = false
	salle["salle_peinte"]["sorties"] = [null, null, null, null]
	salle["objets"] = []
	salle["objets_image"] = "porte2"
	salle["presences"] = [
		{"id": 801, "genre": "groupe", "etat": "actif", "nombre": 2, "chef": false, "pacifique": false,
			"membres": [{"classe": "soutien", "sous_classe": "chaman", "image": "chaman01.png"}, Creatures.membre("loup")]},
		{"id": 802, "genre": "groupe", "etat": "actif", "nombre": 2, "chef": false, "pacifique": false,
			"membres": [Creatures.membre("squelette"), Creatures.membre("squelette")], "vitesse_poursuite": 0.45},
	]
	Aventure.meta(donjon, 1)["prepare"] = true
	var nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
	Ecrans.pile.append(nav)
	racine.add_child(nav)
	await attendre(40)
	var sp: SallePeinte = nav.salle_peinte
	sp.presences.geler(1000.0)
	var x := 250.0
	for e in sp.presences.entites:
		e["pos"] = Vector2(x, 450)
		e["noeud"].position = e["pos"]
		x += 260
	await capturer("105_creatures_salle")
	joueur.points_de_vie_max = 999
	joueur.points_de_vie = 999
	var groupes := [[Gobelin.nouveau(donjon)._completer("soutien", "chaman"), Creatures.creer(donjon, "loup")],
		[Creatures.creer(donjon, "squelette"), Creatures.creer(donjon, "squelette")]]
	for i in groupes.size():
		var combat := Combat.nouveau(joueur, null, groupes[i], donjon)
		combat.mener_combat()
		await attendre(40)
		await capturer("%d_creatures_combat" % (106 + i))
		Ecrans.pile[-1].queue_free()
		Ecrans.pile.pop_back()
		await attendre(5)
	quit()
