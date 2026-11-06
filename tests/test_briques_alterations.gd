extends SceneTree
## Briques primaires des altérations (2026-11-06) : les composées gardent leurs effets, une altération personnalisée
## (briques + altération citée à 50 %) se joue en combat, le réglage d'une composée change ses effets, les noms
## renommés (Protection → Résistance physique...) restent compris, le créateur de l'éditeur fabrique une altération.
## « BILAN briques : 0 échec(s) ».   godot --headless --path . -s tests/test_briques_alterations.gd

var echecs := 0


func verifier(c: bool, cas: String) -> void:
	if not c:
		echecs += 1
	print(("ok " if c else "ÉCHEC ") + cas)


func _initialize() -> void:
	lancer()


func lancer() -> void:
	seed(5)
	Sauvegarde.reinitialiser_monde()
	var heros := Personnage.nouveau()
	var donjon := Donjon.nouveau(heros)
	# Catalogue
	verifier(BriquesAlterations.BRIQUES.size() >= 25, "%d briques primaires" % BriquesAlterations.BRIQUES.size())
	for nom in Alterations.defs():
		var d := Alterations.definition(nom)
		if d.get("briques", []).is_empty() or Alterations.description(nom) == "":
			verifier(false, "%s : faite de briques, avec une description" % nom)
	# Renommages
	for paire in [["précis", "bonus de chance de toucher"], ["protection", "résistance physique"], ["évasion", "bonus d'esquive"],
			["barrière", "résistance magique et élémentaire"], ["concentration", "bonus de chance de coup critique"]]:
		verifier(Alterations.nom_canonique(paire[0]) == paire[1] and Alterations.defs().has(paire[1]) and not Alterations.defs().has(paire[0]),
			"%s → %s" % paire)
	verifier(Alterations.defs().has("bonus de parade"), "bonus de parade")
	# Effets inchangés : gel (1 PA, esquive -10 %), brûlure (1d2 × cumul), protection selon la puissance (60 = -60 %)
	var g := Gobelin.nouveau(donjon)._completer("guerrier", "combattant")
	var esquive := float(g.chance_esquive)
	Alterations.appliquer_alterations(g, "gel", null, 100)
	verifier(is_equal_approx(float(g.chance_esquive), esquive - 0.10) and Alterations.definition("gel")["perte_pa"] == 1.0, "gel : esquive -10 %, 1 PA")
	Alterations.retirer(g, "gel")
	verifier(is_equal_approx(float(g.chance_esquive), esquive), "gel retiré : esquive rendue")
	Alterations.appliquer_alterations(g, "protection", null, 100, 60)
	verifier(is_equal_approx(Degats.resistance_pourcent(g, "tranchant"), 0.60), "résistance physique selon la puissance (60 %%) : %s" % Degats.resistance_pourcent(g, "tranchant"))
	Alterations.appliquer_alterations(g, "bonus de parade", null, 100)
	verifier(float(U.num(g, "chance_de_parer")) >= 0.15, "bonus de parade : +15 % de chance de parer")
	var parer_g := Gobelin.nouveau(donjon)._completer("guerrier", "combattant")
	Alterations.appliquer_alterations(parer_g, "barrière", null, 100)
	verifier(is_equal_approx(Degats.resistance_pourcent(parer_g, "feu"), 0.30) and is_equal_approx(Degats.resistance_pourcent(parer_g, "ombre"), 0.30),
		"résistance magique et élémentaire : feu et ombre -30 %")
	# Altération personnalisée : toucher -20 % + brûlure à 50 %, et réglage de la composée Gel (esquive -30 %)
	var ed := DonneesEnnemis.editions()
	ed["alterations_personnalisees"]["brume ardente"] = {"libelle": "Brume ardente", "nature": "malus", "duree": 2, "cumul_max": 1,
		"briques": [{"brique": "toucher", "valeur": -0.20}, {"alteration": "brulure", "puissance": 50}]}
	ed["alterations"]["gel"] = {"briques": [{"brique": "perte_pa", "chance": 1.0}, {"brique": "esquive", "valeur": -0.30}]}
	Alterations.recharger()
	var d := Alterations.definition("brume ardente")
	verifier(not d.is_empty() and d.has("dots") and d.has("modifs"), "personnalisée construite (dégâts et statistique)")
	verifier(Alterations.categorie("brume ardente") == "dégâts", "personnalisée classée en dégâts")
	print("Brume ardente : ", Alterations.description("brume ardente"))
	var cible := Gobelin.nouveau(donjon)._completer("guerrier", "combattant")
	var toucher := float(cible.chance_de_toucher)
	Alterations.appliquer_alterations(cible, "brume ardente", null, 100)
	verifier(is_equal_approx(float(cible.chance_de_toucher), toucher - 0.20), "personnalisée : toucher -20 %")
	var combat := Combat.nouveau(heros, null, [cible], donjon)
	var pv := float(cible.points_de_vie)
	Alterations.mise_a_jour(cible, combat)
	verifier(float(cible.points_de_vie) < pv, "personnalisée : la brûlure à 50 %% blesse (%s → %s)" % [pv, cible.points_de_vie])
	var g2 := Gobelin.nouveau(donjon)._completer("guerrier", "combattant")
	var e2 := float(g2.chance_esquive)
	Alterations.appliquer_alterations(g2, "gel", null, 100)
	verifier(is_equal_approx(float(g2.chance_esquive), e2 - 0.30), "composée réglée : gel à esquive -30 %")
	ed["alterations_personnalisees"].erase("brume ardente")
	ed["alterations"].erase("gel")
	Alterations.recharger()
	verifier(not Alterations.defs().has("brume ardente"), "personnalisée retirée")
	# Boucle : une altération qui se cite elle-même ne plante pas
	ed["alterations_personnalisees"]["boucle"] = {"libelle": "Boucle", "nature": "malus", "duree": 1, "briques": [{"alteration": "boucle", "puissance": 100}]}
	Alterations.recharger()
	verifier(Alterations.defs().has("boucle"), "boucle : construite sans planter")
	ed["alterations_personnalisees"].erase("boucle")
	Alterations.recharger()
	# Créateur de l'éditeur (sans enregistrer)
	var editeur := EditeurEnnemis.new()
	root.add_child(editeur)
	await process_frame
	var nom := editeur.creer_alteration()
	verifier(editeur.editions["alterations_personnalisees"].has(nom) and editeur.vue_alterations == 2, "créateur : %s créée" % nom)
	verifier(editeur.liste_alterations.item_count >= 1 and editeur.fiche_alteration.get_child_count() > 6, "créateur : fiche ouverte")
	var copie := editeur.creer_alteration("poison")
	verifier(editeur.editions["alterations_personnalisees"][copie]["briques"][0]["brique"] == "degats_par_tour", "copie de Poison")
	editeur.renommer_alteration(copie, "Venin lent")
	verifier(editeur.editions["alterations_personnalisees"].has("venin lent"), "renommée en « venin lent »")
	editeur.vue_alterations = 0
	editeur._remplir_liste_alterations()
	verifier(editeur.liste_alterations.item_count == BriquesAlterations.BRIQUES.size() + BriquesAlterations.FAMILLES.size(), "vue des briques : %d lignes" % editeur.liste_alterations.item_count)
	editeur.choisir_brique("degats_par_tour")
	verifier(editeur.fiche_alteration.get_child_count() >= 4, "fiche d'une brique")
	editeur.queue_free()
	DonneesEnnemis.recharger()
	print("BILAN briques : %d échec(s)" % echecs)
	quit()
