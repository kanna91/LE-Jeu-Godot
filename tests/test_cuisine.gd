extends SceneTree
## Cuisine (2026-11-03) : le jeu donne exactement la liste complète (outils/cuisine/combinaisons.csv), feu (torche,
## brandon, feu de camp 3 plats / 10 min), eau et marmite, foyer de la cuisine, bouillon, recettes apprises, page de
## livre de cuisine, manger (mana, intoxication), maux persistants (tics, régénération coupée, durées cumulées, mort),
## catalogue (pierres en 3 tailles, PV). « BILAN cuisine : 0 échec(s) ».

var echecs := 0


func verifier(c: bool, cas: String) -> void:
	if not c:
		echecs += 1
	print(("ok " if c else "ÉCHEC ") + cas)


func _initialize() -> void:
	seed(3)
	Sauvegarde.reinitialiser_monde()
	_liste_complete()
	_catalogue()
	_feu_et_eau()
	_cuisine_et_recettes()
	_maux()
	print("BILAN cuisine : %d échec(s)" % echecs)
	quit(1 if echecs else 0)


## Chaque ligne de la liste complète (script Python) : même résultat, mêmes PV et mana dans le jeu.
func _liste_complete() -> void:
	var f := FileAccess.open("res://outils/cuisine/combinaisons.csv", FileAccess.READ)
	if f == null:
		verifier(false, "liste complète introuvable (python outils/cuisine_combinaisons.py)")
		return
	var par_nom := {}
	for id in Cuisine.donnees()["ingredients"]:
		par_nom[String(Cuisine.donnees()["ingredients"][id]["nom"])] = id
	f.get_csv_line(";")  # en-tête
	var lignes := 0
	var differences := 0
	while not f.eof_reached():
		var l := f.get_csv_line(";")
		if l.size() < 18:
			continue
		var ids := []
		for n in l[1].split(" + "):
			ids.append(par_nom[n])
		for k in Cuisine.PREPARATIONS.size():
			var r := Cuisine.evaluer(ids, Cuisine.PREPARATIONS[k])
			var attendu: String = l[2 + k * 4]
			var obtenu: String = r["nom"] if r["classe"] == "recette" else r["classe"]
			if obtenu != attendu or str(r["pv"]) != l[3 + k * 4] or str(r["mana"]) != l[4 + k * 4]:
				differences += 1
				if differences <= 5:
					print("  différence : %s %s : jeu %s %d/%d, liste %s %s/%s" % [l[1], Cuisine.PREPARATIONS[k], obtenu, r["pv"], r["mana"],
						attendu, l[3 + k * 4], l[4 + k * 4]])
		lignes += 1
	verifier(lignes == 14949 and differences == 0, "liste complète : %d mélanges, %d différence(s) entre le jeu et la liste" % [lignes, differences])


func _catalogue() -> void:
	var prix := {"Petit rubis": 80, "Rubis": 160, "Grand rubis": 240, "Petit grenat": 40, "Grenat": 80, "Grand grenat": 120,
		"Petite émeraude": 80, "Grand saphir": 240}
	var ok := true
	for n in prix:
		var o = ObjetsDivers.depuis_catalogue(n)
		ok = ok and o != null and int(o.valeur) == prix[n]
	verifier(ok, "pierres en 3 tailles (petite = prix d'avant, ×2, ×3)")
	var pv := {"Bol de soupe": 35, "Viande grillée": 35, "Viande bouillie": 30, "Viande séchée": 25, "Pomme": 15, "Citron": 15, "Grappe de raisin": 15}
	ok = true
	for n in pv:
		ok = ok and int(U.num(ObjetsDivers.depuis_catalogue(n), "pv")) == pv[n]
	verifier(ok, "PV des plats trouvés : soupe et viande grillée 35, bouillie 30, séchée 25, fruits 15")
	var manquants := []
	for id in Cuisine.donnees()["ingredients"]:
		if ObjetsDivers.depuis_catalogue(String(Cuisine.donnees()["ingredients"][id]["nom"])) == null:
			manquants.append(id)
	verifier(manquants.is_empty(), "chaque ingrédient de cuisine existe comme objet (%s)" % ", ".join(manquants))


func _donner(joueur, noms: Array) -> Array:
	var l := []
	for n in noms:
		var o = ObjetsDivers.depuis_catalogue(n)
		joueur.inventaire.append(o)
		l.append(o)
	return l


func _feu_et_eau() -> void:
	var joueur := Personnage.nouveau()
	var salle := {}
	var ctx := {"torche": false, "cuisine": false, "salle": salle, "pos": [100, 400]}
	var p := Cuisine.possibilites(joueur, ctx)
	verifier(p["sans_feu"] == "" and p["grille"] != "" and p["bouilli"] != "" and p["mijote"] != "", "sans feu ni torche : seulement « sans feu »")
	ctx["torche"] = true
	p = Cuisine.possibilites(joueur, ctx)
	verifier(p["grille"].contains("allumer du bois") and p["bouilli"] != "", "torche : ni griller ni bouillir (elle allume seulement le bois)")
	# Brandon : bois allumé à la torche, s'éteint après 3 minutes
	_donner(joueur, ["Planche en bois"])
	var m := Cuisine.allumer_brandon(joueur, ctx)
	verifier(Cuisine.objet(joueur, "Brandon allumé") != null and Cuisine.objet(joueur, "Planche en bois") == null, "brandon allumé : " + m)
	Cuisine.avancer(joueur, 181)
	verifier(Cuisine.objet(joueur, "Brandon allumé") == null, "le brandon s'éteint après 3 minutes")
	_donner(joueur, ["Morceau de bois"])
	Cuisine.allumer_brandon(joueur, ctx)
	ctx["torche"] = false  # on s'éloigne de la torche pour poser le feu ailleurs
	m = Cuisine.faire_feu(joueur, ctx)
	verifier(not Cuisine.feu(joueur, salle).is_empty() and Cuisine.objet(joueur, "Brandon allumé") == null, "feu de camp posé avec le brandon : " + m)
	p = Cuisine.possibilites(joueur, ctx)
	verifier(p["grille"] == "" and p["bouilli"].contains("marmite"), "feu de camp : griller oui ; bouillir : il faut une marmite")
	var brochette := _donner(joueur, ["Viande crue", "Oignon", "Tomate"])
	var r := Cuisine.cuisiner(joueur, ctx, brochette, null, "grille")
	verifier(r[1] != null and r[1].nom == "Brochette" and int(r[1].pv) == 46 and int(r[1].mana) == 15, "brochette grillée au feu de camp : 46 PV, 15 mana (%s)" % r[0])
	verifier(not brochette.any(func(o): return o in joueur.inventaire), "ingrédients consommés")
	_donner(joueur, ["Marmite", "Seau en bois"])
	verifier(Cuisine.possibilites(joueur, ctx)["bouilli"].contains("eau"), "seau trouvé vide : il faut de l'eau")
	verifier(Cuisine.remplir_seau(joueur, ctx).contains("pas d'eau") and Cuisine.eau(joueur) == 0, "sans point d'eau : pas de seau rempli")
	ctx["eau"] = true
	var m_eau := Cuisine.remplir_seau(joueur, ctx)
	verifier(Cuisine.eau(joueur) == 10, "près d'un point d'eau : seau rempli (%s)" % m_eau)
	ctx["eau"] = false
	var vb := _donner(joueur, ["Viande crue", "Carotte"])
	r = Cuisine.cuisiner(joueur, ctx, vb, null, "bouilli")
	verifier(r[1] != null and r[1].nom == "Viande bouillie" and int(r[1].pv) == 45, "viande bouillie (viande + carotte) : 45 PV (%s)" % r[0])
	verifier(Cuisine.eau(joueur) == 9, "1 litre d'eau consommé")
	var bouillon = Cuisine.objet(joueur, "Bouillon")
	verifier(bouillon != null, "il reste un bouillon")
	verifier(int(Cuisine.feu(joueur, salle).get("plats", 0)) == 2, "le feu de camp a servi 2 plats sur 3 (brochette, viande bouillie)")
	var soupe := _donner(joueur, ["Pomme de terre", "Chou"])
	r = Cuisine.cuisiner(joueur, ctx, soupe, bouillon, "bouilli")
	verifier(r[1] != null and r[1].nom == "Soupe de légumes" and int(r[1].pv) == 27 + 5 and int(r[1].mana) == 3 + 5 and Cuisine.eau(joueur) == 8,
		"le bouillon ajoute sa valeur (+5/+5) sans remplacer l'eau (8 L restants)")
	verifier(Cuisine.feu(joueur, salle).is_empty(), "le feu de camp s'éteint après 3 plats")
	# Feu avec amadou + silex, éteint après 10 minutes
	_donner(joueur, ["Morceau de bois", "Amadou", "Silex"])
	m = Cuisine.faire_feu(joueur, ctx)
	verifier(not Cuisine.feu(joueur, salle).is_empty() and Cuisine.objet(joueur, "Amadou") == null and Cuisine.objet(joueur, "Silex") != null,
		"feu avec amadou et silex (le silex reste) : " + m)
	Cuisine.avancer(joueur, 601)
	verifier(Cuisine.feu(joueur, salle).is_empty(), "le feu de camp s'éteint après 10 minutes")


func _cuisine_et_recettes() -> void:
	var joueur := Personnage.nouveau()
	var ctx := {"torche": false, "cuisine": true, "salle": {}, "pos": [0, 0]}
	verifier(Cuisine.connues(joueur) == ["Viande grillée", "Brochette", "Viande bouillie", "Compote"], "recettes connues au départ : " + str(Cuisine.connues(joueur)))
	var p := Cuisine.possibilites(joueur, ctx)
	verifier(p.values().all(func(x): return x == ""), "cuisine : toutes les préparations, sans marmite ni seau")
	var ragout := _donner(joueur, ["Viande crue", "Pomme de terre", "Carotte"])
	var r := Cuisine.cuisiner(joueur, ctx, ragout, null, "mijote")
	verifier(r[1] != null and r[1].nom == "Ragoût" and int(r[1].pv) == 76 and "Ragoût" in Cuisine.connues(joueur), "ragoût mijoté : 76 PV, recette apprise (%s)" % r[0])
	var mx := _donner(joueur, ["Viande crue", "Pomme de terre"])
	r = Cuisine.cuisiner(joueur, ctx, mx, null, "grille")
	verifier(r[1] != null and r[1].nom == "Mixture" and int(r[1].pv) == 18, "viande + pomme de terre grillées : mixture, 18 PV")
	var im := _donner(joueur, ["Pomme", "Ail"])
	r = Cuisine.cuisiner(joueur, ctx, im, null, "bouilli")
	verifier(r[1] != null and r[1].nom == "Plat immonde" and r[0].contains("Beurk"), "pomme + ail : plat immonde (%s)" % r[0])
	var cru := _donner(joueur, ["Viande crue"])
	r = Cuisine.cuisiner(joueur, ctx, cru, null, "sans_feu")
	verifier(r[1] != null and is_equal_approx(float(U.num(r[1], "intoxication")), 0.25), "viande crue sans feu : immonde, intoxication 1 fois sur 4")
	var seul := _donner(joueur, ["Pomme"])
	r = Cuisine.cuisiner(joueur, ctx, seul, null, "sans_feu")
	verifier(r[1] == null and seul[0] in joueur.inventaire, "un fruit seul sans feu n'est pas un plat")
	# Page de livre de cuisine
	var page = _donner(joueur, ["Page de livre de cuisine"])[0]
	var avant := Cuisine.connues(joueur).size()
	var msg: String = load("res://scripts/ecrans/menu_inventaire.gd").utiliser_ou_equiper(joueur, page)
	verifier(Cuisine.connues(joueur).size() == avant + 1 and not page in joueur.inventaire, "page lue : " + msg)
	# Manger : PV et mana
	joueur.points_de_vie = 10
	joueur.mana = 0
	var plat := ObjetsDivers.creer("Essai", "plat", 1, "")
	plat._d["type_objet"] = "nourriture"
	plat._d["pv"] = 20
	plat._d["mana"] = 4
	joueur.inventaire.append(plat)
	msg = ObjetsDivers.manger(joueur, plat)
	verifier(int(joueur.points_de_vie) == 30 and int(joueur.mana) == 4, "manger : +20 PV, +4 mana (%s)" % msg)
	var avarie := ObjetsDivers.creer("Essai avarié", "plat", 1, "")
	avarie._d["type_objet"] = "nourriture"
	avarie._d["intoxication"] = 1.0
	joueur.inventaire.append(avarie)
	msg = ObjetsDivers.manger(joueur, avarie)
	verifier(Maux.a(joueur, "intoxication"), "plat à risque (toujours) : intoxication (%s)" % msg)


func _maux() -> void:
	var joueur := Personnage.nouveau()
	joueur.points_de_vie_max = 300
	joueur.points_de_vie = 50
	Maux.infliger(joueur, "intoxication")
	Maux.avancer(joueur, 60)
	verifier(int(joueur.points_de_vie) == 46, "intoxication : 4 PV par minute (tics de 15 s)")
	joueur._d["regen_de_points_de_vie"] = 60
	joueur.regenerer(60)
	verifier(int(joueur.points_de_vie) == 46, "pas de régénération des PV pendant l'intoxication")
	Maux.infliger(joueur, "intoxication")
	verifier(Maux.liste(joueur).size() == 1 and is_equal_approx(float(Maux.liste(joueur)[0]["restant"]), 420 + 480), "2e intoxication : la durée s'ajoute (15:00)")
	joueur.points_de_vie = 200
	Maux.avancer(joueur, 900)
	verifier(not Maux.a(joueur, "intoxication") and int(joueur.points_de_vie) == 200 - 60, "fin après la durée : 60 PV perdus en 15 minutes")
	joueur.regenerer(60)
	verifier(int(joueur.points_de_vie) > 200 - 60, "la régénération reprend")
	joueur.points_de_vie = 3
	Statistiques.mort = false
	Maux.infliger(joueur, "intoxication")
	Maux.avancer(joueur, 60)
	verifier(Statistiques.mort and Statistiques.cause_mort == "intoxication", "l'intoxication peut tuer (cause : intoxication)")
	Statistiques.mort = false
	Statistiques.cause_mort = ""
