extends SceneTree
## Marches animées des gobelins (2026-10-28, PresencesSalle._gobelin_en_marche) : un gobelin de chaque sorte qui a une
## marche (guerrier, archer, chaman, féticheur) et un groupe mené par un chef, en marche dans la salle de la porte 2.
## Vérifie : chaque sorte a sa marche (pas le sorcier), au rythme de l'animation (2 s de marche = 24 images, même
## en « poursuite »), le groupe va à la vitesse du plus lent, un groupe de squelettes garde sa vitesse d'avant.
## Capture 110_marches_gobelins. Fenêtre hors écran (override.cfg, voir README). « BILAN marches gobelins : 0 échec(s) ».

var racine: Control
var echecs := 0


func _initialize() -> void:
	racine = Control.new()
	racine.size = Vector2(960, 540)
	root.add_child(racine)
	Ecrans.racine = racine
	lancer()


func attendre(n: int) -> void:
	for _i in n:
		await process_frame


func verifier(c: bool, cas: String) -> void:
	if not c:
		echecs += 1
	print(("ok " if c else "ÉCHEC ") + cas)


func membre(sc: String) -> Dictionary:
	return {"classe": "x", "sous_classe": sc, "image": Ennemis.IMAGES_GOBELINS_PAR_SOUS_CLASSE.get(sc, ["gobelin_defaut.png"])[0]}


func lancer() -> void:
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
	var sortes := ["combattant", "archer", "chaman", "feticheur"]
	salle["presences"] = []
	for i in sortes.size():
		salle["presences"].append({"id": 801 + i, "genre": "groupe", "etat": "actif", "nombre": 1, "membres": [membre(sortes[i])]})
	salle["presences"].append({"id": 810, "genre": "groupe", "etat": "actif", "nombre": 3, "chef": true,
		"membres": [membre("combattant"), membre("archer"), membre("sorcier")]})
	salle["presences"].append({"id": 811, "genre": "groupe", "etat": "actif", "nombre": 2,
		"membres": [Creatures.membre("squelette"), Creatures.membre("squelette")], "vitesse_poursuite": Aventure.VITESSE_SQUELETTES})
	Aventure.meta(donjon, 1)["prepare"] = true
	var nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
	Ecrans.pile.append(nav)
	racine.add_child(nav)
	await attendre(40)
	var sp: SallePeinte = nav.salle_peinte
	var pr: PresencesSalle = sp.presences
	pr.geler(1000.0)
	sp.heros.position = Vector2(720, 500)
	verifier(pr.entites.size() == 6, "6 présences affichées")
	for s in ["guerrier", "archer", "chaman", "feticheur"]:
		verifier(PresencesSalle.marche_gobelin(s) == "gobelin_" + s, "%s : marche animée" % s)
	verifier(PresencesSalle.marche_gobelin("sorcier") == "", "sorcier : pas de marche (image de repos)")
	# Au rythme de l'animation : 2 s de « poursuite » → 24 images de chaque marche
	for k in 4:
		var e: Dictionary = pr.entites[k]
		var sorte: String = CombatAnime.TYPES[sortes[k]]
		var nom := "gobelin_" + sorte
		e["pos"] = Vector2(150, 470)
		e["parcouru"] = 0.0
		var depart: Vector2 = e["pos"]
		for _i in 120:
			pr._avancer(e, Vector2(650, 470), 0.58, 1.0 / 60.0)
		var hauteurs: float = (e["pos"] - depart).length() / sp.hauteur(470.0)
		var haut_image := PresencesSalle.TAILLE_GOBELIN * PresencesSalle.rapport_marche_gobelin(nom, sorte)
		var images := hauteurs / (float(PresencesSalle.infos_marche(nom)["foulee"]) * haut_image)
		print("  %s : 2 s → %.2f hauteurs de héros (%.2f/s), %.1f images" % [sorte, hauteurs, hauteurs / 2.0, images])
		verifier(absf(images - 24.0) < 1.5, "%s : au rythme de l'animation (≈ 12 images/s)" % sorte)
	# Poursuite : COURSE_GOBELINS (0,85 hauteur de héros/s, 2026-10-28), l'animation suit la distance
	var c: Dictionary = pr.entites[0]
	c["pos"] = Vector2(150, 470)
	c["parcouru"] = 0.0
	for _i in 120:
		pr._avancer(c, Vector2(800, 470), 0.58, 1.0 / 60.0, true)
	var course: float = (c["pos"].x - 150.0) / sp.hauteur(470.0) / 2.0
	var images_course: float = course * 2.0 / (float(PresencesSalle.infos_marche("gobelin_guerrier")["foulee"])
		* PresencesSalle.TAILLE_GOBELIN * PresencesSalle.rapport_marche_gobelin("gobelin_guerrier", "guerrier")) / 2.0
	print("  guerrier en poursuite : %.2f hauteurs de héros/s, %.0f images/s" % [course, images_course])
	verifier(absf(course - PresencesSalle.COURSE_GOBELINS) < 0.03, "poursuite à 0,85 hauteur de héros par seconde")
	# Groupe avec chef : la vitesse du plus lent de ceux qui marchent (le sorcier suit)
	var g: Dictionary = pr.entites[4]
	var attendu := INF
	for k in 2:
		var sorte: String = CombatAnime.TYPES[["combattant", "archer"][k]]
		var info := PresencesSalle.infos_marche("gobelin_" + sorte)
		attendu = minf(attendu, float(info["foulee"]) * float(info["fps"]) * PresencesSalle.taille_membre(g["p"], k)
			* PresencesSalle.rapport_marche_gobelin("gobelin_" + sorte, sorte))
	verifier(absf(PresencesSalle.vitesse_gobelins(g["p"]) - attendu) < 0.001, "groupe avec chef : vitesse du plus lent (%.2f)" % attendu)
	verifier(PresencesSalle.vitesse_gobelins(pr.entites[5]["p"]) < 0.0, "squelettes : pas de marche, vitesse d'avant")
	# Capture : les gobelins marchent dans plusieurs directions
	var regards := [Vector2(1, 0), Vector2(-1, 0.1), Vector2(0, 1), Vector2(0, -1), Vector2(0.6, 0.6), Vector2(1, 0)]
	var places := [Vector2(140, 440), Vector2(300, 470), Vector2(450, 445), Vector2(600, 480), Vector2(330, 395), Vector2(640, 420)]
	for k in pr.entites.size():
		var e: Dictionary = pr.entites[k]
		e["pos"] = places[k]
		e["noeud"].position = places[k]
		e["regard"] = regards[k]
	for _i in 20:
		for e in pr.entites:
			e["t_bouge"] = pr.temps
			e["parcouru"] = float(e.get("parcouru", 0.0)) + 0.01
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://tests/captures/110_marches_gobelins.png")
	print("capture 110_marches_gobelins")
	print("BILAN marches gobelins : %d échec(s)" % echecs)
	quit()
