extends SceneTree
## Karma, cadavres et âmes (règles de l'utilisateur, 2026-10-31) : Chevalier de la mort +5 % de vitesse par point
## négatif (2026-11-03 ; avant : un chevalier de plus tous les 5 points) ; capture : la prison la plus proche
## (2026-11-03) ; prix ±5 %, or +5 % (karma positif),
## mensonges des diablotins ±5 % ; pacifiques épargnés (or, karma +1, ils partent) ou tués (karma −1, corps) ;
## corps à fouiller, âmes à siphonner (1 par ennemi, 3 pour une élite, 5 pour le boss), 3 âmes = 1 point.
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
	_capture()
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


## Karma négatif : jamais de Chevalier de la mort de plus ; chacun va 5 % plus vite par point négatif (dans la salle
## comme d'une salle à l'autre), sa vitesse normale au karma positif (règle de l'utilisateur, 2026-11-03).
func _paliers() -> void:
	Sauvegarde.reinitialiser_monde()
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	# Le Chevalier de la mort est dans les cryptes depuis le 2026-11-10 (avant : à l'étage 1) : niveaux préparés d'abord
	for e in [1, Donjon.NIVEAU_CRYPTES]:
		Aventure.preparer_etage(donjon, e)
	var base := {}
	var niveau_chevalier := -1
	for e in donjon.plan_donjon:
		base[e] = _chevaliers(donjon, e).size()
		if base[e] >= 1 and niveau_chevalier < 0:
			niveau_chevalier = int(e)
	verifier(niveau_chevalier >= 0, "au moins un chevalier de base (niveau %d)" % niveau_chevalier)
	if niveau_chevalier < 0:
		return
	var chevalier: Dictionary = _chevaliers(donjon, niveau_chevalier)[0]
	var duree_base := Aventure.duree_salle(chevalier)
	var k := 0
	for v in [-1, -5, -11, -3, 0, 4]:
		var message := Karma.changer(donjon, v - k)
		var avant := k
		k = v
		var attendu := 1.0 + 0.05 * maxi(0, -k)
		verifier(absf(Karma.facteur_vitesse_chevalier(joueur) - attendu) < 1e-6, "karma %d : vitesse ×%.2f" % [k, attendu])
		for e in donjon.plan_donjon:
			verifier(_chevaliers(donjon, e).size() == base[e], "karma %d : pas de chevalier de plus (niveau %d)" % [k, e])
			for c in _chevaliers(donjon, e):
				verifier(absf(float(c.get("facteur_vitesse", 1.0)) - attendu) < 1e-6, "karma %d : chevalier à ×%.2f" % [k, attendu])
		verifier(absf(Aventure.duree_salle(chevalier) - duree_base / attendu) < 1e-6, "karma %d : traverse une salle plus vite" % k)
		if minf(avant, 0) > minf(k, 0):
			verifier("presse le pas" in message, "karma %d : message « presse le pas » (%s)" % [k, message])
	# Ancienne partie : un chevalier venu du karma repart
	var vieux := Aventure.ajouter_menace(donjon, 1, "imbattable")
	vieux["karma"] = true
	Karma.synchroniser(donjon)
	verifier(vieux["etat"] == "parti", "ancien chevalier du karma reparti")


## Capture (règle de l'utilisateur, 2026-11-03) : le geôlier met le héros dans la prison la plus proche de la salle
## où il est pris (la 2e grande salle de cette prison) ; le coffre des confiscations est près d'elle.
func _capture() -> void:
	Sauvegarde.reinitialiser_monde()
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	var salles: Dictionary = donjon.plan_donjon[1]
	var fonds := {}
	var entrees := {}
	for i in salles:
		if salles[i].get("prison_salle", "") == "grande_b":
			fonds[int(salles[i]["prison"])] = i
		if salles[i].get("prison_salle", "") == "grande_a":
			entrees[int(salles[i]["prison"])] = i
	verifier(fonds.size() == 4, "4 prisons")
	var essais := 0
	var ids: Array = salles.keys()
	ids.shuffle()
	for depuis in ids.slice(0, 12):
		var dist := Aventure.distances_depuis(salles, depuis)
		var attendue := ""
		var d_min := 1 << 30
		for k in entrees:
			if int(dist.get(entrees[k], 1 << 29)) < d_min:
				d_min = int(dist[entrees[k]])
				attendue = fonds[k]
		donjon.salle_actuelle = [1, int(depuis)]
		var geolier := {"id": 999, "genre": "geolier", "etat": "actif"}
		salles[depuis]["presences"] = salles[depuis].get("presences", []) + [geolier]
		Aventure.capturer(donjon, geolier)
		verifier(str(donjon.salle_actuelle[1]) == attendue, "pris en %s : réveil dans la prison la plus proche (%s, attendu %s)" % [
			depuis, donjon.salle_actuelle[1], attendue])
		essais += 1
	verifier(essais == 12, "12 captures")


## Prix, or et mensonges.
func _effets() -> void:
	var joueur := Personnage.nouveau()
	joueur._d["karma"] = -3
	verifier(is_equal_approx(Karma.facteur_prix(joueur), 1.15), "karma −3 : prix +15 %")
	verifier(is_equal_approx(Karma.facteur_or(joueur), 0.85), "karma −3 : butin −15 %")
	verifier(is_equal_approx(Karma.chance_mensonge(joueur, 1.0 / 3.0), 1.0 / 3.0 + 0.15), "karma −3 : +15 % de mensonges")
	joueur._d["karma"] = 4
	verifier(is_equal_approx(Karma.facteur_prix(joueur), 0.80), "karma +4 : prix −20 %")
	verifier(is_equal_approx(Karma.facteur_or(joueur), 1.20), "karma +4 : or +20 %")
	verifier(is_equal_approx(Karma.chance_mensonge(joueur, 1.0 / 3.0), 1.0 / 3.0 - 0.20), "karma +4 : +20 % de vérité")
	verifier(Karma.or_gagne(joueur, 100) == 120, "or gagné +20 %")
	# Butin réglé au karma 0, ±5 % par point (règle de l'utilisateur, 2026-11-15) : karma −5 → 100 pièces = 75
	joueur._d["karma"] = -5
	verifier(Karma.or_gagne(joueur, 100) == 75, "karma −5 : 100 pièces d'or → 75")
	var total := 0
	for _i in 4000:
		total += Karma.quantite_butin(joueur, 1)
	verifier(absf(total / 4000.0 - 0.75) < 0.03, "karma −5 : 1 objet → 0,75 en moyenne (%.3f)" % (total / 4000.0))
	joueur._d["karma"] = 0
	verifier(Karma.or_gagne(joueur, 100) == 100 and Karma.quantite_butin(joueur, 3) == 3, "karma 0 : valeurs de base")
	# A : bornes × 0,25 à × 1,75 (2026-11-15)
	joueur._d["karma"] = -20
	verifier(is_equal_approx(Karma.facteur_butin(joueur), 0.25), "A : karma −20 → × 0,25 (borne)")
	joueur._d["karma"] = 20
	verifier(is_equal_approx(Karma.facteur_butin(joueur), 1.75), "A : karma +20 → × 1,75 (borne)")
	joueur._d["karma"] = -10
	verifier(is_equal_approx(Karma.facteur_butin(joueur), 0.5), "A : karma −10 → × 0,5 (sous la borne)")
	# B : armes et équipements : rang ±1 avec 5 % par point, nombre inchangé
	joueur._d["karma"] = 5
	var plus := 0
	for _i in 4000:
		plus += 1 if Karma.rang_butin(joueur, 2) == 3 else 0
	verifier(absf(plus / 4000.0 - 0.25) < 0.03, "B : karma +5 → 25 %% de rang en plus (%.3f)" % (plus / 4000.0))
	joueur._d["karma"] = -5
	verifier(Karma.rang_butin(joueur, 1) == 1, "B : jamais sous le rang 1")
	var moins := 0
	for _i in 4000:
		moins += 1 if Karma.rang_butin(joueur, 3) == 2 else 0
	verifier(absf(moins / 4000.0 - 0.25) < 0.03, "B : karma −5 → 25 %% de rang en moins (%.3f)" % (moins / 4000.0))
	var avant: int = joueur.inventaire.size() + joueur.equipements.values().filter(func(o): return o != null).size()
	for _i in 20:
		Fouille.ramasser({"categorie": "arme", "quantite": 1, "rang": 2}, joueur, 1)
	var apres: int = joueur.inventaire.size() + joueur.equipements.values().filter(func(o): return o != null).size()
	verifier(apres - avant == 20, "B : 20 armes ramassées à karma −5 = 20 armes (%d)" % (apres - avant))
	# C : paliers
	joueur._d["karma"] = 10
	verifier(is_equal_approx(Karma.chance_objet_en_plus(joueur), 0.20), "C : karma +10 → 20 % d'objet en plus")
	joueur._d["karma"] = -5
	verifier(is_equal_approx(Karma.chance_objet_en_plus(joueur), 0.0), "C : karma négatif : pas d'objet en plus")
	# Pas d'objet maudit pour le moment (décision de l'utilisateur, 2026-11-15) : seulement la qualité (B)
	verifier(not Karma.new().has_method("maudire"), "pas d'objet maudit")
	# D : l'or confisqué qu'on récupère ne passe pas par le karma (coffre_confisque) ; recettes : pas de multiplicateur
	joueur._d["karma"] = -10
	var or_avant: int = joueur.piece_or
	joueur.piece_or += 40  # même code que le coffre des affaires confisquées : montant exact
	verifier(joueur.piece_or - or_avant == 40, "D : or confisqué rendu tel quel")
	joueur._d["karma"] = 4
	var objet := Objet.nouveau("Essai", "divers", "", 100)
	verifier(Marchand.prix_vente(objet, joueur) == 100, "vente au marchand : toujours le même prix (karma sans effet)")
	joueur._d["karma"] = -4
	verifier(Marchand.prix_vente(objet, joueur) == 100, "vente au marchand : même prix en karma négatif")
	verifier(Karma.palier(joueur) == 0 and is_equal_approx(Karma.modificateur(joueur, "prix_marchands"), 0.20), "karma −4 : palier 0, prix +20 %")
	joueur._d["karma"] = -11
	verifier(Karma.palier(joueur) == -2, "karma −11 : palier −2")
	joueur._d["karma"] = 7
	verifier(Karma.palier(joueur) == 1, "karma +7 : palier +1")
	joueur._d["karma"] = 4
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
	var p := {"id": 9001, "genre": "groupe", "etat": "actif", "nombre": 2, "elite": false, "pacifique": true}
	var message := Rencontres.epargner_pacifiques(donjon, p)
	verifier(p["etat"] == "parti", "pacifiques épargnés : ils partent")
	verifier(Karma.valeur(joueur) == 1, "épargner : karma +1")
	verifier(int(donjon.moralite["clemence"]) == 1, "épargner : compté comme clémence")
	for nom in Karma.ACTES:
		verifier(int(Karma.ACTES[nom][0]) != 0 and Karma.ACTES[nom][1] in ["clemence", "cruaute"], "acte %s bien décrit" % nom)
	verifier(joueur.piece_or >= 5 and joueur.piece_or <= 16, "épargner : 5 à 15 or au 1er étage (%d)" % joueur.piece_or)
	verifier("pièces d'or" in message, "message du cadeau : %s" % message)
	var q := {"id": 9002, "genre": "groupe", "etat": "actif", "nombre": 1, "elite": false, "pacifique": true}
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


## Corps et âmes : 1 âme par ennemi, élite 3, boss 5 ; siphonner fait disparaître le corps ; 3 âmes = 1 point.
func _cadavres() -> void:
	Sauvegarde.reinitialiser_monde()
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	donjon.salle_courante()["presences"] = []
	verifier(Aventure.ames_de({"genre": "groupe", "nombre": 2, "elite": false, "membres": [{}, {}]}) == 2, "groupe de 2 : 2 âmes")
	verifier(Aventure.ames_de({"genre": "groupe", "nombre": 2, "elite": true, "membres": [{}, {}]}) == 4, "élite + 1 : 4 âmes")
	verifier(Aventure.ames_de({"genre": "boss", "membres": [{}]}) == 5, "boss : 5 âmes")
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
