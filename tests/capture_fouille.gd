extends SceneTree
## Fouille dans l'écran d'exploration : la salle de départ (salle porte 5 en essai) a un squelette, plus
## un coffre et une étagère d'une ancienne sauvegarde, qui doivent disparaître ; le héros marche vers le
## squelette, « Fouiller (E) » apparaît, E le fouille (message, objet assombri, enregistré dans le plan) ;
## captures 74 à 76. Objets de toutes les images : captures 77 à 91.
## À lancer dans une fenêtre hors écran (override.cfg, voir README). « BILAN fouille écran : 0 échec(s) ».

var racine: Control
var echecs := 0


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
	await attendre(3)
	root.get_viewport().get_texture().get_image().save_png("res://tests/captures/%s.png" % nom)
	print("capture ", nom)


func verifier(condition: bool, cas: String) -> void:
	if condition:
		print("ok ", cas)
	else:
		echecs += 1
		print("ÉCHEC ", cas)


func touche(code: int) -> void:
	var t := InputEventKey.new()
	t.keycode = code
	t.physical_keycode = code
	t.pressed = true
	Ecrans.pile[-1]._traiter([{"type": "touche", "touche": code, "texte": ""}])


func lancer() -> void:
	Sauvegarde.reinitialiser_monde()
	Statistiques.mort = false
	Ecrans.auto = true
	var joueur = Personnage.nouveau()
	joueur.piece_or = 0
	var donjon = Donjon.nouveau(joueur)
	PlanSalles.attribuer(donjon, 1)
	# Salle de départ affichée avec l'image porte5 : un squelette, un coffre et une étagère (retirés du jeu)
	var salle: Dictionary = donjon.salle_courante()
	salle["salle_peinte"]["image"] = "porte5"
	salle["salle_peinte"]["miroir"] = false
	salle["salle_peinte"]["sorties"] = [null, null, null]
	salle["objets_image"] = "porte5"
	salle["objets"] = [{"emplacement": 0, "type": "coffre", "variante": 3, "retourne": false, "fouille": false},
		{"emplacement": 1, "type": "squelette", "variante": 3, "retourne": false, "fouille": false},
		{"emplacement": 2, "type": "etagere", "variante": 2, "retourne": false, "fouille": false}]
	var nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
	Ecrans.pile.append(nav)
	racine.add_child(nav)
	await attendre(40)
	var sp: SallePeinte = nav.salle_peinte
	verifier(sp.objets.size() == 1, "coffre et étagère d'une ancienne sauvegarde retirés : 1 squelette affiché")
	verifier(salle["objets"].size() == 1 and salle["objets"][0]["type"] == "squelette", "plan nettoyé : seul le squelette reste")
	verifier(sp.objet_proche() == -1, "au départ, aucun objet à portée")
	await capturer("74_fouille_salle")
	# Le héros va devant le squelette
	sp.heros.position = sp.pied_objet(0) + Vector2(-30, 10)
	await attendre(5)
	verifier(sp.objet_proche() == 0, "devant le squelette : il est à portée")
	await capturer("75_fouille_invite")
	touche(KEY_E)
	await attendre(5)
	verifier(salle["objets"][0]["fouille"], "E : squelette fouillé (enregistré dans le plan)")
	verifier(nav.message_nav != "", "message : %s" % nav.message_nav)
	verifier(sp.objet_proche() == -1, "squelette fouillé : plus proposé")
	await capturer("76_fouille_resultat")
	# Toutes les images : chaque emplacement occupé (types et variantes alternés)
	var n := 77
	for image in SallePeinte.salles_disponibles():
		var places := Fouille.emplacements(image)
		var objets := []
		for i in places.size():
			objets.append({"emplacement": i, "type": places[i]["types"][(n + i) % places[i]["types"].size()],
				"variante": 1 + (n + i) % 4, "retourne": (n + i) % 2 == 0, "fouille": false})
		sp.charger(image, -1, false, Fouille.a_afficher(objets, image))
		sp.actif = false
		await attendre(45)
		await capturer("%d_objets_%s" % [n, image])
		n += 1
	print("BILAN fouille écran : %d échec(s)" % echecs)
	quit(1 if echecs else 0)
