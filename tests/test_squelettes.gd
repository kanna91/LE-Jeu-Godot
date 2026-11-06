extends SceneTree
## Squelettes refaits (2026-11-06) : guerrier, mage, élémentaliste et squelette invoqué. Création (PV, dés, défenses,
## compétences), groupes des cryptes (guerriers, mages et élémentalistes seulement là), invocation en combat (2 au plus
## par invocateur, poussière à la mort de l'invocateur, ni tué compté ni butin), sorts de l'élémentaliste.
## « BILAN squelettes : 0 échec(s) ».   godot --headless --path . -s tests/test_squelettes.gd

var echecs := 0


func verifier(c: bool, cas: String) -> void:
	if not c:
		echecs += 1
	print(("ok " if c else "ÉCHEC ") + cas)


func _initialize() -> void:
	seed(11)
	Sauvegarde.reinitialiser_monde()
	var heros := Personnage.nouveau()
	var donjon := Donjon.nouveau(heros)
	# Création
	for sorte in ["guerrier_squelette", "mage_squelette", "elementaliste_squelette", "squelette_invoque"]:
		var e := Creatures.creer(donjon, sorte)
		print("%s : PV %d, compétences %s" % [e.nom, e.points_de_vie_max, e.competences.map(func(c): return c.nom_classe)])
		verifier(Degats.degats_subis(e, "contondant", 20.0) > 27.0 and Degats.degats_subis(e, "perforant", 20.0) < 17.0,
			"%s : faible au contondant, résiste au perforant" % e.nom)
		verifier(ResourceLoader.exists("res://images/gobelins/" + str(e.image)), "%s : image %s" % [e.nom, e.image])
	var g := Creatures.creer(donjon, "guerrier_squelette")
	var pv_g: Array = DonneesEnnemis.sorte("guerrier_squelette")["pv"]  # réglés dans l'éditeur (80 depuis le 2026-11-06)
	verifier(g.points_de_vie_max >= float(pv_g[0]) - 2 and g.points_de_vie_max <= float(pv_g[1]) + 2
		and Formules.des_type(g, "tranchant", g.competences[0]) == [[4, 2]], "guerrier squelette : PV de l'éditeur %s, 4d2 tranchant" % [pv_g])
	var inv := Creatures.creer(donjon, "squelette_invoque")
	verifier(inv.points_de_vie_max <= 32 and Formules.des_type(inv, "tranchant", inv.competences[0]) == [[3, 2]],
		"squelette invoqué : 30 PV, 3d2 tranchant")
	var mage := Creatures.creer(donjon, "mage_squelette")
	verifier(mage.competences.any(func(c): return c.nom_classe == "Invocation_squelette")
		and mage.competences.any(func(c): return c.nom_classe == "Trait_des_Ombres"), "mage squelette : invocation et sorts d'ombre")
	var elem := Creatures.creer(donjon, "elementaliste_squelette")
	var noms_elem: Array = elem.competences.map(func(c): return c.nom_classe)
	verifier("Boule_de_feu" in noms_elem and "Givre" in noms_elem and "Eclair" in noms_elem, "élémentaliste : Boule de feu, Givre, Éclair")
	var givre = elem.competences.filter(func(c): return c.nom_classe == "Givre")[0]
	verifier(Formules.des_type(elem, "froid", givre) == [[5, 2]], "élémentaliste : Givre à 5d2 (dés d'ennemi)")
	# Groupes : cryptes (guerriers, mages, élémentalistes) et reste de l'étage (aucun)
	var m := {"prochain_id": 1}
	var vus := {}
	var hors_cryptes := {}
	var mages_par_groupe_max := 0
	for i in 2000:
		var gr := Aventure.nouveau_groupe(donjon, m, 2, "crypte")
		gr["nombre"] = 3
		gr["elite"] = false
		var mb := Aventure.membres(gr)
		var n_mages := 0
		for x in mb:
			vus[x["sous_classe"]] = vus.get(x["sous_classe"], 0) + 1
			if x["sous_classe"] in ["mage_squelette", "elementaliste_squelette"]:
				n_mages += 1
		mages_par_groupe_max = maxi(mages_par_groupe_max, n_mages)
		if i == 0:
			verifier(gr.get("vitesse_poursuite", 0.0) == Aventure.VITESSE_SQUELETTES, "groupe des cryptes lent")
		var dehors := Aventure.nouveau_groupe(donjon, m, 2)
		for x in Aventure.membres(dehors):
			hors_cryptes[x["sous_classe"]] = true
	print("cryptes (2000 groupes de 3) : %s ; hors cryptes : %s" % [vus, hors_cryptes.keys()])
	verifier(vus.get("guerrier_squelette", 0) > 1000 and vus.get("squelette", 0) > 1000, "cryptes : squelettes et guerriers squelettes")
	verifier(vus.get("mage_squelette", 0) > 350 and vus.get("mage_squelette", 0) < 650, "cryptes : un mage dans ≈ 25 % des groupes")
	verifier(vus.get("elementaliste_squelette", 0) > 350 and vus.get("elementaliste_squelette", 0) < 650, "cryptes : un élémentaliste dans ≈ 25 % des groupes")
	verifier(mages_par_groupe_max <= 2 and not vus.has("squelette_invoque"), "au plus un mage et un élémentaliste, jamais d'invoqué posé")
	for s in ["guerrier_squelette", "mage_squelette", "elementaliste_squelette", "squelette_invoque"]:
		verifier(not hors_cryptes.has(s), "%s : jamais hors des cryptes" % s)
	# Invocation en combat
	heros.points_de_vie_max = 9999
	heros.points_de_vie = 9999
	var mage2 := Creatures.creer(donjon, "mage_squelette")
	mage2.mana = 999
	var combat := Combat.nouveau(heros, null, [mage2], donjon)
	var invocation = mage2.competences.filter(func(c): return c.nom_classe == "Invocation_squelette")[0]
	for k in 3:
		mage2.points_d_action = 1
		combat.lancer(invocation, mage2, donjon, heros)
	var invoques: Array = combat.ennemis.filter(func(e): return U.ga(e, "invocateur", null) == mage2)
	verifier(invoques.size() == 2 and combat.ennemis.size() == 3, "invocation : 2 squelettes au plus (%d)" % invoques.size())
	verifier(invoques.all(func(e): return e.sous_classe == "squelette_invoque" and e.est_vivant()), "invocation : squelettes invoqués en vie")
	verifier(mage2.mana < 999, "invocation : mana payé")
	var ia := mage2.choisir_par_regles(DonneesEnnemis.ia_de("mage_squelette"), heros, donjon)
	verifier(ia[0] == null or ia[0].nom_classe != "Invocation_squelette", "IA : pas d'invocation avec déjà 2 squelettes")
	mage2.points_de_vie = 0
	combat.verification_des_vivants()
	verifier(invoques.all(func(e): return not e.est_vivant()), "mort du mage : ses squelettes tombent en poussière")
	verifier(combat.ennemis.is_empty(), "combat gagné (plus personne)")
	# Un tour entier d'IA : le mage invoque (règle à 60 %) sur plusieurs essais
	var a_invoque := false
	for essai in 20:
		var m3 := Creatures.creer(donjon, "mage_squelette")
		m3.mana = 50
		var c3 := Combat.nouveau(heros, null, [m3], donjon)
		m3.points_d_action = 1
		m3.mecanique_ennemis(heros, donjon, c3)
		if c3.ennemis.size() > 1:
			a_invoque = true
			break
	verifier(a_invoque, "IA : le mage squelette invoque pendant son tour")
	print("BILAN squelettes : %d échec(s)" % echecs)
	quit()
