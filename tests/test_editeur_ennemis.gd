extends SceneTree
## Données des ennemis et leur éditeur (2026-11-04) : IA par défaut (mêmes choix que l'ancienne IA codée en dur),
## réglages d'une compétence, nouvelle compétence copiée, durée d'une altération, règle d'IA, PV et butin réglés ;
## interface de l'éditeur (onglets, nouvelle compétence, règle, butin, compétence donnée), sans rien enregistrer.
## « BILAN éditeur des ennemis : 0 échec(s) »   godot --headless --path . -s tests/test_editeur_ennemis.gd

var echecs := 0


func verifier(condition: bool, cas: String) -> void:
	if not condition:
		echecs += 1
	print(("ok " if condition else "ÉCHEC ") + cas)


## Répartition des compétences choisies par l'IA d'une sorte sur ``n`` tours (héros sans altération).
func repartition(donjon, heros, g, n: int) -> Dictionary:
	var compte := {}
	for _i in n:
		var choix: Array = g.choisir_par_regles(DonneesEnnemis.ia_de(String(g.sous_classe)), heros, donjon)
		var nom := String(choix[0].nom_classe) if choix[0] != null else "secours"
		compte[nom] = int(compte.get(nom, 0)) + 1
	return compte


func _initialize() -> void:
	seed(5)
	Sauvegarde.reinitialiser_monde()
	DonneesEnnemis.recharger()
	var heros := Personnage.nouveau()
	var donjon := Donjon.nouveau(heros)
	# IA par défaut
	for s in DonneesEnnemis.SORTES:
		verifier(not DonneesEnnemis.ia_de(s).is_empty() and not DonneesEnnemis.competences_de(s).is_empty(), "%s : IA et compétences" % s)
	var lancier := Gobelin.nouveau(donjon)._completer("guerrier", "lancier")
	var allie := Gobelin.nouveau(donjon)._completer("guerrier", "combattant")
	donjon.ennemis = [lancier, allie]
	var r := repartition(donjon, heros, lancier, 3000)
	print("lancier : ", r)
	verifier(absf(float(r.get("Coup_de_lance", 0)) / 3000.0 - 0.67) < 0.04, "lancier : Coup de lance 2 fois sur 3")
	verifier(r.get("Perforation", 0) > 800 and not r.has("Rafale_de_lance"), "lancier : Perforation si le héros ne saigne pas")
	heros.alteration["saignement"] = {"duree": 3, "cumul": 1}
	r = repartition(donjon, heros, lancier, 1000)
	verifier(r.get("Rafale_de_lance", 0) > 250 and not r.has("Perforation"), "lancier : Rafale si le héros saigne")
	heros.alteration = {}
	var r2 := repartition(donjon, heros, allie, 200)
	verifier(r2.get("Cri_de_guerre", 0) == 200, "combattant avec un allié et sans rage : Cri de guerre")
	allie.alteration["rage"] = {"duree": 3, "cumul": 1}
	r2 = repartition(donjon, heros, allie, 3000)
	print("combattant en rage : ", r2)
	verifier(not r2.has("Cri_de_guerre") and absf(float(r2.get("Botte_secrete", 0)) / 3000.0 - 0.33) < 0.04, "combattant en rage : Botte 1 fois sur 3")
	# Réglages d'une compétence, nouvelle compétence, durée d'une altération
	DonneesEnnemis._editions = {"competences": {
		"Coup_de_lance": {"nom": "Lance d'essai", "type_alteration": {"stun": 100}, "cout_action": 2, "multiplicateur_degats": 1.5},
		"Tir_99": {"base": "Tir", "nom": "Tir double", "nombre_attaque": 2}},
		"alterations": {"stun": {"duree": 5}}}
	Alterations._definitions = {}
	var c := Competences.creer("Coup_de_lance")
	verifier(c.nom == "Lance d'essai" and c.type_alteration.get("stun", 0) == 100 and c.cout_action == 2 and is_equal_approx(c.multiplicateur_degats, 1.5),
		"compétence réglée : nom, altération, coût, dégâts")
	var n := Competences.creer("Tir_99")
	verifier(n != null and n.nom == "Tir double" and n.nombre_attaque == 2 and n.nom_classe == "Tir_99", "nouvelle compétence copiée de Tir")
	verifier(Alterations.definition("stun")["duree"] == 5, "durée de l'étourdissement réglée à 5")
	verifier(Competences.creer("Coup_de_lance", true).nom != "Lance d'essai", "valeurs d'origine sans les réglages")
	# Règle d'IA, PV, compétence donnée, butin
	var d := DonneesEnnemis.donnees()
	d["sortes"]["lancier"]["ia"] = [{"competence": "Tir_99", "chance": 100}]
	d["sortes"]["lancier"]["competences"] = ["Coup_d_epee", "Tir_99"]
	d["sortes"]["combattant"]["pv"] = [100, 100]
	d["sortes"]["combattant"]["butin"] = [{"categorie": "or", "quantite": 7, "chance": 100}, {"categorie": "potion", "potion": "pv", "quantite": 1, "chance": 0}]
	var l2 := Gobelin.nouveau(donjon)._completer("guerrier", "lancier")
	donjon.ennemis = [l2]
	var choix := l2.choisir_par_regles(DonneesEnnemis.ia_de("lancier"), heros, donjon)
	verifier(choix[0] != null and choix[0].nom_classe == "Tir_99", "règle d'IA : la nouvelle compétence est jouée")
	verifier(l2.competences.any(func(x): return x.nom_classe == "Tir_99"), "compétence donnée au lancier")
	var cb := Gobelin.nouveau(donjon)._completer("guerrier", "combattant")
	verifier(cb.points_de_vie_max == 100, "PV réglés : 100 (%d)" % cb.points_de_vie_max)
	var or_avant: int = heros.piece_or
	var potions_avant: int = heros.inventaire.size()
	cb.points_de_vie = 0
	cb.mort_au_combat(donjon)
	verifier(heros.piece_or == or_avant + 7, "butin : 7 pièces d'or (chance 100 %)")
	verifier(heros.inventaire.size() == potions_avant, "butin : la potion à 0 % n'est pas lâchée")
	# Squelette : sa propre attaque reste la première, une compétence donnée s'ajoute
	d["sortes"]["squelette"]["competences"] = ["Coup_d_epee", "Coup_de_gourdin"]
	var sq := Creatures.creer(donjon, "squelette")
	verifier(sq.competences.size() == 2 and sq.competences[0].nom == "Épée rouillée", "squelette : son attaque puis Coup de gourdin")
	DonneesEnnemis.recharger()
	verifier(Alterations.definition("stun")["duree"] != 5 and Competences.creer("Coup_de_lance").nom != "Lance d'essai", "rechargé : réglages d'essai oubliés")
	# Interface de l'éditeur (sans enregistrer)
	var ed := EditeurEnnemis.new()
	root.add_child(ed)
	await process_frame
	verifier(ed.onglets.get_tab_count() == 5, "5 onglets")
	verifier(ed.liste_competences.item_count >= 34, "liste des compétences (%d)" % ed.liste_competences.item_count)
	# Altérations classées par type (2026-11-06)
	verifier(Alterations.categorie("brulure") == "dégâts" and Alterations.categorie("rage") == "amélioration"
		and Alterations.categorie("stun") == "malus" and Alterations.categorie("condamnation") == "dégâts", "catégories des altérations")
	# Une vulnérabilité par élément et un bonus par caractéristique (2026-11-06) ; anciens noms convertis
	for nom_alt in ["vulnérabilité au feu", "vulnérabilité au froid", "vulnérabilité à la foudre", "vulnérabilité à l'arcane",
			"vulnérabilité au chaos", "vulnérabilité à l'ombre", "bonus de force", "bonus de dextérité", "bonus d'endurance",
			"bonus d'intelligence", "bonus de sagesse", "bonus de mana", "vulnérabilité physique", "vulnérabilité élémentaire",
			"vulnérabilité magique", "vulnérabilité totale"]:
		verifier(not Alterations.definition(nom_alt).is_empty(), "altération %s" % nom_alt)
	for ancien in ["inflammabilité", "conductivité", "morsure du givre", "vigueur", "agilité", "robustesse", "intellect",
			"sérénité", "puissance du titan", "illumination", "transcendance", "vulnérabilité"]:
		verifier(not Alterations.defs().has(ancien), "ancienne altération %s retirée" % ancien)
	verifier(Alterations.nom_canonique("inflammabilité") == "vulnérabilité au feu" and Alterations.libelle("vigueur") == "Bonus de force",
		"anciens noms convertis")
	# Réductions de caractéristique (2026-11-06) : 16, anciennes supprimées ou converties
	for reduc in Alterations.REDUCTIONS_CARACTERISTIQUES:
		verifier(Alterations.definition(reduc[0]).get("nature") == "malus", "réduction %s" % reduc[0])
	for ancien in ["sape", "engourdissement", "épuisement vital", "torpeur", "trouble", "déchéance", "dissonance",
			"entropie", "faiblesse", "maladresse", "débilité"]:
		verifier(not Alterations.defs().has(ancien), "ancienne réduction %s retirée" % ancien)
	verifier(Alterations.nom_canonique("sape") == "réduction de force" and Alterations.nom_canonique("entropie")
		== "réduction de toutes les caractéristiques", "anciens noms des réductions convertis")
	var cible_r := Gobelin.nouveau(donjon)._completer("guerrier", "combattant")
	cible_r.set("intelligence", 10)
	cible_r.set("sagesse", 10)
	cible_r.set("force", 10)
	Alterations.appliquer_alterations(cible_r, "réduction d'intelligence et de sagesse", null, 100)
	verifier(float(U.num(cible_r, "intelligence")) < 10 and float(U.num(cible_r, "sagesse")) < 10 and float(U.num(cible_r, "force")) == 10,
		"réduction d'intelligence et de sagesse : seules ces deux baissent")
	var cible_v := Gobelin.nouveau(donjon)._completer("guerrier", "combattant")
	Alterations.appliquer_alterations(cible_v, "vulnérabilité à l'ombre", null, 100)
	verifier(is_equal_approx(float(U.ga(cible_v, "vulnerabilite_ombre", 0)), 0.25), "vulnérabilité à l'ombre : +25 %% (%s)" % U.ga(cible_v, "vulnerabilite_ombre", 0))
	Alterations.appliquer_alterations(cible_v, "vulnérabilité magique", null, 100)
	verifier(is_equal_approx(Degats.vulnerabilite(cible_v, "ombre"), 0.45) and is_equal_approx(Degats.vulnerabilite(cible_v, "arcane"), 0.20)
		and is_equal_approx(Degats.vulnerabilite(cible_v, "feu"), 0.0), "vulnérabilité magique : arcane, chaos, ombre +20 %%")
	var force_avant := float(U.num(heros, "force"))
	Alterations.appliquer_alterations(heros, "bonus de force", null, 100)
	verifier(float(U.num(heros, "force")) > force_avant, "bonus de force : force augmentée")
	var nb_alterations := ed.liste_alterations.item_count
	ed.classer_par_type = true
	ed._remplir_liste_alterations()
	verifier(ed.liste_alterations.item_count == nb_alterations + 3 and not ed.liste_alterations.is_item_selectable(0),
		"altérations par type : 3 titres (%d / %d)" % [ed.liste_alterations.item_count, nb_alterations])
	ed.classer_par_type = false
	ed._remplir_liste_alterations()
	ed.choisir_competence("Perforation")
	verifier(ed.fiche_competence.get_child_count() > 8, "fiche de Perforation")
	var nouvelle := ed.nouvelle_competence()
	verifier(ed.editions["competences"].has(nouvelle) and ed.editions["competences"][nouvelle]["base"] == "Perforation" and ed.modifie,
		"nouvelle compétence %s (copie de Perforation)" % nouvelle)
	ed._ajouter_alteration(nouvelle, Competences.creer("Perforation", true))
	verifier(ed.editions["competences"][nouvelle]["type_alteration"].size() >= 2, "altération ajoutée à la nouvelle compétence")
	ed.choisir_alteration("poison")
	ed._regler_alteration("poison", "duree", 7)
	verifier(ed.editions["alterations"]["poison"]["duree"] == 7, "durée du poison réglée")
	ed.choisir_sorte("archer")
	ed.onglets.current_tab = 2
	await process_frame
	ed.donner_competence_sorte(nouvelle)
	verifier(nouvelle in ed.sortes["archer"]["competences"], "nouvelle compétence donnée à l'archer")
	ed.onglets.current_tab = 3
	await process_frame
	var nb: int = ed.sortes["archer"]["ia"].size()
	ed.ajouter_regle()
	ed.deplacer_regle(nb, -1)
	verifier(ed.sortes["archer"]["ia"].size() == nb + 1, "règle ajoutée et déplacée")
	ed._regler_condition(ed.sortes["archer"]["ia"][0], 0, "heros_avec", "")
	verifier(ed.sortes["archer"]["ia"][0]["si"][0][0] == "heros_avec", "condition réglée")
	ed.onglets.current_tab = 4
	await process_frame
	ed.ajouter_butin()
	verifier(ed.sortes["archer"]["butin"].size() == 1, "objet ajouté au butin")
	await process_frame
	verifier(ed.boite_butin.get_child_count() >= 3, "lignes du butin affichées")
	verifier(DonneesEnnemis.butin_de("archer").is_empty() and not DonneesEnnemis.editions()["competences"].has(nouvelle),
		"rien n'est appliqué au jeu sans enregistrer")
	ed.modifie = false
	ed.queue_free()
	await process_frame
	print("BILAN éditeur des ennemis : %d échec(s)" % echecs)
	quit()
