extends SceneTree
## Marches animées des chasseurs (PresencesSalle._marche_animee) : quatre geôliers tournés vers le fond, la droite,
## la gauche et le spectateur, et un Chevalier de la mort, en marche. Capture 108_marches. Vérifie la vue choisie
## pour chaque direction. Fenêtre hors écran (override.cfg, voir README). « BILAN marches : 0 échec(s) ».

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
	salle["presences"] = []
	for i in 4:
		salle["presences"].append({"id": 701 + i, "genre": "geolier", "etat": "actif"})
	salle["presences"].append({"id": 710, "genre": "imbattable", "etat": "actif"})
	Aventure.meta(donjon, 1)["prepare"] = true
	var nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
	Ecrans.pile.append(nav)
	racine.add_child(nav)
	await attendre(40)
	var sp: SallePeinte = nav.salle_peinte
	sp.presences.geler(1000.0)
	sp.heros.position = Vector2(700, 500)
	var regards := [Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0.2), Vector2(0, 1), Vector2(0.6, 0.6)]
	var attendu := [["dos", false], ["profil", false], ["profil", true], ["face", false], ["trois_quarts", false]]
	var x := 120.0
	for k in sp.presences.entites.size():
		var e: Dictionary = sp.presences.entites[k]
		e["pos"] = Vector2(x, 455)
		e["noeud"].position = e["pos"]
		e["regard"] = regards[k]
		verifier(PresencesSalle.vue_marche(regards[k]) == attendu[k], "%s : vue %s" % [e["p"]["genre"], attendu[k]])
		x += 125
	for k in 30:
		for e in sp.presences.entites:
			e["t_bouge"] = sp.presences.temps
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://tests/captures/108_marches.png")
	print("capture 108_marches")
	verifier(PresencesSalle.images_marche("geolier", "face").size() == 53, "geôlier : 53 images de face")
	# Au rythme de l'animation : 2 s de marche (même pour une « poursuite » à 0,64) → ≈ 12 images par seconde, et
	# la distance qui correspond à la foulée mesurée
	for k in [0, 4]:
		var e: Dictionary = sp.presences.entites[k]
		e["pos"] = Vector2(150, 470)
		e["parcouru"] = 0.0
		var depart: Vector2 = e["pos"]
		for _i in 120:
			sp.presences._avancer(e, Vector2(650, 470), 0.64, 1.0 / 60.0)
		var nom: String = PresencesSalle.MARCHES[e["p"]["genre"]]
		var images: float = e["parcouru"] / float(PresencesSalle.infos_marche(nom)["foulee"])
		var hauteurs: float = (e["pos"] - depart).length() / sp.hauteur(470.0)
		print("  %s : 2 s → %.1f images d'animation, %.2f hauteurs de héros (vitesse %.2f/s ; le héros marche à 0,81)" % [
			nom, images, hauteurs, PresencesSalle.vitesse_marche(nom, e["p"])])
		verifier(absf(images - 24.0) < 1.5, "%s : l'animation suit la distance (≈ 12 images/s)" % nom)
	print("BILAN marches : %d échec(s)" % echecs)
	quit()
