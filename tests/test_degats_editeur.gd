extends SceneTree
## Dégâts réglés dans l'éditeur des compétences (2026-11-06) : dés (1d2 à 1d20), dégâts fixes, part des PV max de la
## cible, multiplicateur qui agit vraiment ; aperçu des dégâts dans la fiche de compétence.
## « BILAN dégâts éditeur : 0 échec(s) ».   godot --headless --path . -s tests/test_degats_editeur.gd

var echecs := 0


func verifier(c: bool, cas: String) -> void:
	if not c:
		echecs += 1
	print(("ok " if c else "ÉCHEC ") + cas)


func _initialize() -> void:
	lancer()


func lancer() -> void:
	seed(3)
	Sauvegarde.reinitialiser_monde()
	var heros := Personnage.nouveau()
	heros.set("force", 0)
	var gobelin = Gobelin.nouveau(null)._completer("guerrier", "combattant")
	var comp := Competences.creer("Coup_de_lance")
	var avant := Formules.degats_bruts(heros, comp, "perforant")
	# Une compétence est la même pour tout le monde (2026-11-15) : mêmes dés pour le héros et les ennemis
	verifier(Formules.des_type(gobelin, "perforant", comp) == Formules.des_competence(heros, comp, "perforant"),
		"Coup de lance : mêmes dés pour le héros et un gobelin")
	verifier(Formules.des_type(gobelin, "perforant", Competences.creer("Coup_de_lance_mineur")) == [[4, 2]],
		"Coup de lance mineur (copie des ennemis) : 4d2")
	comp._d["des_degats"] = {"perforant": [2, 6]}
	verifier(Formules.des_competence(heros, comp, "perforant") == [[2, 6]], "dés réglés : 2d6 (héros)")
	verifier(Formules.des_type(gobelin, "perforant", comp) == [[2, 6]], "dés réglés : 2d6 (ennemi, pas réduits)")
	var avec_des := Formules.degats_bruts(heros, comp, "perforant")
	print("Coup de lance : %.1f → %.1f avec 2d6" % [avant, avec_des])
	# Dégâts fixes
	comp._d["degats_fixes"] = {"perforant": 5}
	verifier(absf(Formules.degats_bruts(heros, comp, "perforant") - (avec_des + 5 * Formules.pourcentage(heros, "perforant"))) < 0.01,
		"dégâts fixes : +5")
	# Multiplicateur
	var sans_facteur := Formules.degats_bruts(heros, comp, "perforant")
	comp._d["facteur_degats"] = 2.0
	verifier(absf(Formules.degats_bruts(heros, comp, "perforant") - 2.0 * sans_facteur) < 0.01, "multiplicateur ×2")
	comp._d["facteur_degats"] = 1.0
	# Part des PV max de la cible
	comp._d["pv_max_cible"] = {"perforant": 0.10}
	verifier(absf(Formules.bonus_pv_cible(heros, comp, gobelin, "perforant") - 0.10 * gobelin.points_de_vie_max) < 0.01,
		"10 % des PV max de la cible")
	# Les réglages passent par l'éditeur (DonneesEnnemis.appliquer_competence)
	var ed := {"competences": {"Coup_de_lance": {"des_degats": {"perforant": [1, 8]}, "degats_fixes": {"perforant": 3},
		"pv_max_cible": {"perforant": 0.05}, "facteur_degats": 1.5}}}
	var c2 := Competences.creer("Coup_de_lance", true)
	DonneesEnnemis.appliquer_competence(c2, "Coup_de_lance", ed)
	verifier(c2.des_degats == {"perforant": [1, 8]} and is_equal_approx(float(c2.facteur_degats), 1.5)
		and float(c2.degats_fixes["perforant"]) == 3.0, "réglages appliqués à la compétence")
	# Éditeur : fiche et aperçu
	var editeur := EditeurEnnemis.new()
	root.add_child(editeur)
	await process_frame
	editeur.choisir_competence("Coup_de_lance")
	var apercu = editeur.fiche_competence.get_node_or_null("Apercu")
	verifier(apercu != null and "≈" in String(apercu.text), "aperçu des dégâts : %s" % (apercu.text if apercu != null else "absent"))
	var texte_avant: String = apercu.text
	editeur._regler_competence("Coup_de_lance", "facteur_degats", 3.0)
	editeur._maj_apercu("Coup_de_lance")
	verifier(String(apercu.text) != texte_avant, "l'aperçu suit le multiplicateur")
	# Les dés sont affichés tels qu'ils sont joués, et les régler change ce que lance un ennemi comme le héros
	editeur.choisir_competence("Epee_longue_rouillee")
	var ed_g = editeur.competence_travail("Epee_longue_rouillee")
	verifier(editeur.des_joues("Epee_longue_rouillee", Competences.creer("Epee_longue_rouillee", true), "tranchant")
		== [[6, 2]], "éditeur : guerrier squelette affiché à 6d2 (dés joués)")
	verifier(editeur.des_joues("Coup_d_epee", Competences.creer("Coup_d_epee", true), "tranchant") == [[6, 2]]
		and editeur.des_joues("Coup_d_epee_mineur", Competences.creer("Coup_d_epee_mineur", true), "tranchant") == [[4, 2]],
		"éditeur : Coup d'épée 6d2, Coup d'épée mineur 4d2")
	editeur._regler_competence("Epee_longue_rouillee", "des_degats", {"tranchant": [5, 4]})
	ed_g = editeur.competence_travail("Epee_longue_rouillee")
	verifier(Formules.des_type(editeur._references()[1], "tranchant", ed_g) == [[5, 4]]
		and Formules.des_type(editeur._references()[0], "tranchant", ed_g).slice(0, 1) == [[5, 4]], "éditeur : dés réglés à 5d4, joués par tous")
	verifier("5d4 tranchant" in editeur.des_ennemi_texte("Epee_longue_rouillee"), "onglet Ennemis : %s" % editeur.des_ennemi_texte("Epee_longue_rouillee"))
	editeur.choisir_competence("Cri_de_guerre")
	verifier("soutien" in String(editeur.fiche_competence.get_node("Apercu").text), "compétence sans dégâts : pas d'aperçu chiffré")
	editeur.queue_free()
	print("BILAN dégâts éditeur : %d échec(s)" % echecs)
	quit()
