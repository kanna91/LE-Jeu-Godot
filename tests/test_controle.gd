extends SceneTree
## Compare les calculs du portage à ceux du jeu Python (tests/controle.json, outils/exporter_controle.py).


func _initialize() -> void:
	var donnees: Array = JSON.parse_string(FileAccess.open("res://tests/controle.json", FileAccess.READ).get_as_text())
	var erreurs := 0
	for entree in donnees:
		var a: Dictionary = U.entiers(entree["attributs"])
		var comp: Competence = Sort.new() if a.has("ELEMENT") else Competence.new()
		comp._d = a
		comp._d["nom_classe"] = entree["classe"]
		comp._d["ameliorations_possibles"] = []
		var nom: String = entree["classe"]
		erreurs += _comparer(nom + " valeur", Equilibrage.valeur(comp), entree["valeur"])
		erreurs += _comparer(nom + " points", ValeurCompetences.points(comp), entree["points"])
		var compo := Equilibrage.composantes(comp)
		if compo.size() != entree["composantes"].size():
			print("ÉCART %s composantes : %s / %s" % [nom, compo, entree["composantes"]])
			erreurs += 1
		else:
			for i in compo.size():
				erreurs += _comparer("%s composante %s %s" % [nom, compo[i][0], compo[i][1]], compo[i][2], entree["composantes"][i][2])
		var camp := Equilibrage.camp(comp)
		var est := Formules.estimer_degats(camp[0], comp, camp[1], false)
		for i in est.size():
			erreurs += _comparer("%s estimation %s" % [nom, est[i][0]], est[i][2], entree["estimation"][i][2])
		var contexte := Ameliorations._contexte(comp)
		var base := maxf(0.5 * Equilibrage.degats_par_tour(camp[0], camp[1]), Equilibrage.valeur(comp))
		var t0 := Time.get_ticks_msec()
		var options := Ameliorations._options_niveau(comp, 1, Equilibrage.BUDGETS[1] * base, contexte, {}, comp)
		var duree := Time.get_ticks_msec() - t0
		for i in options.size():
			var attendu: Dictionary = entree["options_1"][i]
			var o: Dictionary = options[i]
			if o["genre"] != attendu["genre"] or o.get("nom") != attendu.get("nom"):
				print("ÉCART %s option %d : %s / %s" % [nom, i, o, attendu])
				erreurs += 1
				continue
			erreurs += _comparer("%s option %d valeur" % [nom, i], o["valeur"], attendu["valeur"])
			erreurs += _comparer("%s option %d gain" % [nom, i], o["gain"], attendu["gain"])
			erreurs += _comparer("%s option %d complément" % [nom, i], o.get("complement", 0), attendu.get("complement", 0))
			var texte := Ameliorations.decrire_spec(o, Ameliorations.profil(comp) == "soin", comp)
			if texte != entree["descriptions_1"][i]:
				print("ÉCART %s description %d :\n  %s\n  %s" % [nom, i, texte, entree["descriptions_1"][i]])
				erreurs += 1
		print("%s : niveau 1 recalculé en %d ms" % [nom, duree])
	print("Contrôle terminé : %d écart(s)" % erreurs)
	quit()


func _comparer(quoi: String, obtenu, attendu) -> int:
	var a := float(obtenu)
	var b := float(attendu)
	if absf(a - b) > 1e-6 * maxf(1.0, absf(b)):
		print("ÉCART %s : %s au lieu de %s" % [quoi, a, b])
		return 1
	return 0
