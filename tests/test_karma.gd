extends SceneTree
## Karma, cadavres et âmes (règles de l'utilisateur, 2026-10-31) : paliers des Chevaliers de la mort du karma (un de
## plus tous les 5 points négatifs, repart en remontant de 5), un par étage ; prix ±5 %, or +5 % (karma positif),
## mensonges des diablotins ±5 % ; pacifiques épargnés (or, karma +1, ils partent) ou tués (karma −1, corps) ;
## corps à fouiller, âmes à siphonner (1 par ennemi, 3 pour un chef, 5 pour le gardien), 3 âmes = 1 point.
## godot --headless --path . -s tests/test_karma.gd

var echecs := 0


func verifier(condition: bool, cas: String) -> void:
	if not condition:
		echecs += 1
		print("ÉCHEC ", cas)


func _initialize() -> void:
	seed(31)
	Ecrans.auto = true
	_paliers()
	_effets()
	_pacifiques()
	_cadavres()
	print("BILAN karma : %d échec(s)" % echecs)
	quit(1 if echecs else 0)


func _chevaliers(donjon, etage: int) -> Array:
	var liste := []
	for i in donjon.plan_donjon[etage]:
		for p in donjon.plan_donjon[etage][i].get("presences", []):
			if p["genre"] == "imbattable" and p.get("etat", "actif") == "actif":
				liste.append(p)
	return liste


## Paliers : exemples de l'utilisateur (−5 → un chevalier, reparti à 0 ; −11 → deux, un repart à −5 ; au pire +9).
func _paliers() -> void:
	Sauvegarde.reinitialiser_monde()
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	var base := {}
	for e in donjon.plan_donjon:
		base[e] = _chevaliers(donjon, e).size()
	verifier(base[1] >= 1, "au moins un chevalier de base")
	var attendus := [[-4, 0], [-5, 1], [-9, 1], [-10, 2], [-11, 2], [-6, 2], [-5, 1], [-1, 1], [0, 0], [-5, 1], [-14, 2],
		[-6, 2], [-5, 1]]
	var k := 0
	for a in attendus:
		Karma.changer(donjon, a[0] - k)
		k = a[0]
		verifier(Karma.chevaliers(joueur) == a[1], "karma %d : %d chevalier(s) du karma (%d)" % [k, a[1], Karma.chevaliers(joueur)])
		for e in donjon.plan_donjon:
			verifier(_chevaliers(donjon, e).size() == base[e] + a[1], "étage %d, karma %d : %d chevaliers" % [e, k, base[e] + a[1]])
	Karma.changer(donjon, 20 - k)
	verifier(Karma.chevaliers(joueur) == 0, "karma positif : aucun chevalier du karma")
	for e in donjon.plan_donjon:
		verifier(_chevaliers(donjon, e).size() == base[e], "étage %d : jamais moins que le chevalier de base" % e)


## Prix, or et mensonges.
func _effets() -> void:
	var joueur := Personnage.nouveau()
	joueur._d["karma"] = -3
	verifier(is_equal_approx(Karma.facteur_prix(joueur), 1.15), "karma −3 : prix +15 %")
	verifier(is_equal_approx(Karma.facteur_or(joueur), 1.0), "karma négatif : or inchangé")
	verifier(is_equal_approx(Karma.chance_mensonge(joueur, 1.0 / 3.0), 1.0 / 3.0 + 0.15), "karma −3 : +15 % de mensonges")
	joueur._d["karma"] = 4
	verifier(is_equal_approx(Karma.facteur_prix(joueur), 0.80), "karma +4 : prix −20 %")
	verifier(is_equal_approx(Karma.facteur_or(joueur), 1.20), "karma +4 : or +20 %")
	verifier(is_equal_approx(Karma.chance_mensonge(joueur, 1.0 / 3.0), 1.0 / 3.0 - 0.20), "karma +4 : +20 % de vérité")
	verifier(Karma.or_gagne(joueur, 100) == 120, "or gagné +20 %")
	var objet := Objet.nouveau("Essai", "divers", "", 100)
	verifier(Marchand.prix_vente(objet, joueur) == 120, "vente au marchand : +20 % d'or")
	verifier(Marchand.prix_rachat(objet, joueur) == 80, "rachat : −20 %")
	joueur._d["karma"] = -40
	verifier(Karma.chance_mensonge(joueur, 1.0 / 3.0) == 1.0, "mensonges plafonnés à 100 %")
	joueur._d["karma"] = 40
	verifier(Karma.facteur_prix(joueur) == Karma.PRIX_MIN, "prix jamais sous %d %%" % int(Karma.PRIX_MIN * 100))


## Pacifiques : épargnés (or × étage, karma +1, ils partent), tués (karma −1, pas de chevalier immédiat, un corps).
func _pacifiques() -> void:
	Sauvegarde.reinitialiser_monde()
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	var avant := _chevaliers(donjon, 1).size()
	var p := {"id": 9001, "genre": "groupe", "etat": "actif", "nombre": 2, "chef": false, "pacifique": true}
	var message := Rencontres.epargner_pacifiques(donjon, p)
	verifier(p["etat"] == "parti", "pacifiques épargnés : ils partent")
	verifier(Karma.valeur(joueur) == 1, "épargner : karma +1")
	verifier(joueur.piece_or >= 5 and joueur.piece_or <= 16, "épargner : 5 à 15 or au 1er étage (%d)" % joueur.piece_or)
	verifier("pièces d'or" in message, "message du cadeau : %s" % message)
	var q := {"id": 9002, "genre": "groupe", "etat": "actif", "nombre": 1, "chef": false, "pacifique": true}
	donjon.salle_courante()["presences"] = []
	Aventure.apres_victoire(donjon, q)
	verifier(Karma.valeur(joueur) == 0, "tuer : karma −1")
	verifier(_chevaliers(donjon, 1).size() == avant, "tuer un pacifique ne fait plus venir de chevalier d'office")
	var corps := Aventure.laisser_cadavre(donjon, q)
	verifier(corps.get("pacifique", false) and corps["ames"] == Aventure.membres(q).size(), "corps du pacifique : 1 âme par membre")
	var or_avant: int = joueur.piece_or
	Fouille.fouiller_corps(joueur, donjon, true)
	verifier(joueur.piece_or - or_avant >= 2 and joueur.piece_or - or_avant <= 6, "corps d'un pacifique : 2 à 6 or")
	# Statistiques sur beaucoup de pacifiques épargnés : potions ~20 %, équipements ~5 %
	var potions := 0
	var equipements := 0
	for k in 2000:
		var j := Personnage.nouveau()
		var depart: Array = j.inventaire.duplicate() + j.equipements.values()  # arme de départ
		var d := Donjon.nouveau(j) if k == 0 else donjon
		d._d["personnage"] = j
		Rencontres.epargner_pacifiques(d, {"id": 1, "genre": "groupe", "nombre": 1, "pacifique": true, "etat": "actif"})
		for o in j.inventaire:
			if o is Consommable:
				potions += 1
			elif not (o in depart):
				equipements += 1
		for o in j.equipements.values():
			if o != null and not (o in depart) and not (o in j.inventaire):
				equipements += 1
	print("Pacifiques épargnés (2000) : %d potions, %d équipements" % [potions, equipements])
	verifier(absf(potions / 2000.0 - 0.20) < 0.04, "épargnés : ~20 % de potions")
	verifier(absf(equipements / 2000.0 - 0.05) < 0.03, "épargnés : ~5 % d'équipements")


## Corps et âmes : 1 âme par ennemi, chef 3, gardien 5 ; siphonner fait disparaître le corps ; 3 âmes = 1 point.
func _cadavres() -> void:
	Sauvegarde.reinitialiser_monde()
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	donjon.salle_courante()["presences"] = []
	verifier(Aventure.ames_de({"genre": "groupe", "nombre": 2, "chef": false, "membres": [{}, {}]}) == 2, "groupe de 2 : 2 âmes")
	verifier(Aventure.ames_de({"genre": "groupe", "nombre": 2, "chef": true, "membres": [{}, {}]}) == 4, "chef + 1 : 4 âmes")
	verifier(Aventure.ames_de({"genre": "boss", "membres": [{}]}) == 5, "gardien : 5 âmes")
	var corps := Aventure.laisser_cadavre(donjon, {"genre": "groupe", "nombre": 1, "membres": [{}], "etat": "vaincu"})
	verifier(corps["sous"] == "cadavre" and corps["etat"] == "actif", "un corps reste dans la salle")
	verifier(corps in Aventure.presences(donjon, donjon.salle_courante()), "le corps est affiché")
	verifier(Aventure.laisser_cadavre(donjon, {"genre": "geolier", "etat": "vaincu"}).is_empty(), "pas de corps de geôlier")
	verifier(joueur.gagner_ames(2) == 0 and int(joueur.ames) == 2, "2 âmes : pas encore de point")
	verifier(joueur.gagner_ames(5) == 2 and int(joueur.ames) == 1, "7 âmes : 2 points, 1 âme en réserve")
	verifier(int(joueur.points_a_distribuer) == 2, "2 points à répartir")
	var force := int(joueur.force)
	joueur.distribuer_points("2")
	verifier(int(joueur.force) == force + 1 and int(joueur.points_a_distribuer) == 1, "un point dépensé en force")
	# Le corps se fouille une fois puis se siphonne (dialogue en mode auto : on boucle jusqu'au siphon)
	for k in 20:
		if corps["etat"] != "actif":
			break
		await Aventure.cadavre(donjon, corps)
	verifier(corps["etat"] == "siphonne", "corps siphonné")
	verifier(not (corps in Aventure.presences(donjon, donjon.salle_courante())), "corps siphonné : il disparaît")
	verifier(int(U.num(joueur, "ames")) == 2, "âme du corps ajoutée (%d)" % int(U.num(joueur, "ames")))
