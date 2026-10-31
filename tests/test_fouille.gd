extends SceneTree
## Règles de la fouille (Fouille) : tirage des objets d'une salle, résultats et leurs effets.
## godot --headless --path godot -s tests/test_fouille.gd

var echecs := 0


func verifier(condition: bool, cas: String) -> void:
	if not condition:
		echecs += 1
		print("ÉCHEC ", cas)


func _initialize() -> void:
	seed(7)
	Sauvegarde.reinitialiser_monde()
	_tirage()
	_resultats()
	print("BILAN fouille : %d échec(s)" % echecs)
	quit(1 if echecs else 0)


## 0 à 2 objets par salle (30 / 45 / 25 %), types permis par l'emplacement, tirage gardé.
func _tirage() -> void:
	var compte := {0: 0, 1: 0, 2: 0}
	for i in 4000:
		var salle := {}
		var objets := Fouille.objets_salle(salle, "porte5")
		compte[objets.size()] += 1
		var places := Fouille.emplacements("porte5")
		var vus := []
		for o in objets:
			verifier(o["type"] in places[o["emplacement"]]["types"], "type permis par l'emplacement")
			verifier(o["variante"] >= 1 and o["variante"] <= 4, "variante 1 à 4")
			verifier(not (o["emplacement"] in vus), "un objet par emplacement")
			vus.append(o["emplacement"])
		if i == 0:
			salle["objets"] = [{"emplacement": 0, "type": "squelette", "variante": 2, "retourne": false, "fouille": true}]
			verifier(Fouille.objets_salle(salle, "porte5")[0]["fouille"], "tirage gardé pour la même image")
	print("Objets par salle sur 4000 : %s" % compte)
	for n in Fouille.NOMBRE_OBJETS:
		verifier(absf(compte[n] / 4000.0 - Fouille.NOMBRE_OBJETS[n] / 100.0) < 0.03, "fréquence de %d objet(s)" % n)


func _resultats() -> void:
	var donjon = Donjon.nouveau(Personnage.nouveau())
	donjon.salle_actuelle = [3, donjon.salle_actuelle[1]]
	if not donjon.plan_donjon.has(3):
		donjon.generer_etage(3)
	var joueur = Personnage.nouveau()
	var inventaire_depart: Array = joueur.inventaire.duplicate()
	var equipements_depart: Dictionary = joueur.equipements.duplicate()
	for genre in Fouille.RESULTATS:
		var compte := {}
		for i in 3000:
			joueur.piece_or = 0
			joueur.points_de_vie = joueur.points_de_vie_max
			joueur.inventaire = inventaire_depart.duplicate()
			joueur.equipements = equipements_depart.duplicate()
			var avant_pv = joueur.points_de_vie
			var avant_inventaire: int = joueur.inventaire.size()
			for id in donjon.plan_donjon[3]:
				donjon.plan_donjon[3][id].erase("revelee")
			var objet := {"type": genre, "fouille": false}
			var message := Fouille.fouiller(objet, joueur, donjon)
			var resultat := "rien"
			if message.begins_with("Le squelette portait"):
				resultat = "objet"  # équipé d'office s'il n'y a rien à sa place : il quitte alors l'inventaire
			elif joueur.piece_or > 0:
				resultat = "or"
				var bornes: Array = Fouille.OR[genre]
				verifier(joueur.piece_or >= bornes[0] * 3 and joueur.piece_or <= bornes[1] * 3, "or × étage (%d)" % joueur.piece_or)
			elif joueur.points_de_vie < avant_pv:
				resultat = "piege"
				verifier(joueur.points_de_vie >= 1, "le piège ne tue pas")
			elif "(rangé dans Divers)" in message:
				resultat = "divers"
				verifier(joueur.inventaire[-1].est_divers(), "objet divers rangé dans le sac")
			elif joueur.inventaire.size() > avant_inventaire:
				resultat = "potion"
			elif message.begins_with("Un vieux plan"):
				resultat = "indice"
			compte[resultat] = compte.get(resultat, 0) + 1
			verifier(objet["fouille"], "objet marqué fouillé")
			if i == 0:
				verifier(Fouille.fouiller(objet, joueur, donjon).begins_with("Vous avez déjà fouillé"), "un objet ne se fouille qu'une fois")
		print("%s : %s" % [genre, compte])
		for ligne in Fouille.RESULTATS[genre]:
			verifier(absf(compte.get(ligne[0], 0) / 3000.0 - ligne[1] / 100.0) < 0.035, "%s : fréquence de « %s »" % [genre, ligne[0]])
	# Plus de coffres ni d'étagères : seuls les squelettes se tirent, chaque emplacement les accepte
	verifier(Fouille.RESULTATS.keys() == ["squelette"], "seul le squelette se fouille")
	for image in SallePeinte.salles_disponibles():
		for place in Fouille.emplacements(image):
			verifier(place["types"] == ["squelette"] and not place.get("mur", false), "%s : emplacement de squelette" % image)
