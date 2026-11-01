extends SceneTree
## Relève les compétences et sorts du héros au niveau 1 (revue des dégâts demandée par l'utilisateur, 2026-11-01) :
## compétences de base, sorts connus, sorts de départ au choix et sorts apprenables tout de suite ; pour chacun :
## coût (PA, mana), dés par type, dégâts moyens contre un gobelin combattant moyen, altérations, ciblage.
## Écrit user://revue_heros.json. Lancer : Godot --headless --path . -s tests/exporter_revue_heros.gd

func _fiche(lanceur, c, cible) -> Dictionary:
	var des := {}
	for t in c.type_degats:
		var d := Formules.des_type(lanceur, t, c)
		if not d.is_empty():
			des[t] = Formules.texte(d)
	var degats := []
	for e in Formules.estimer_degats(lanceur, c, cible, false):
		degats.append([e[0], snappedf(e[1], 0.1), snappedf(e[2], 0.1)])
	var alt := {}
	var ta = U.ga(c, "type_alteration", {})
	if ta is Dictionary:
		for nom in ta:
			if float(ta[nom]) > 0:
				alt[nom] = ta[nom]
	return {"nom": c.nom, "classe": c.nom_classe, "pa": c.cout_action, "mana": c.cout_mana, "type": c.type_competence,
		"types_degats": c.type_degats, "des": des, "degats": degats, "ciblage": c.type_ciblage, "cibles": c.nombre_cible,
		"coups": U.num(c, "nombre_attaque"), "alterations": alt, "palier": U.ga(c, "PALIER", null),
		"element": U.ga(c, "ELEMENT", null)}


func _initialize() -> void:
	seed(12345)
	Sauvegarde.reinitialiser_monde()
	Objet.compteur_etage_objet = 1
	var heros := Personnage.nouveau()
	var donjon := Donjon.nouveau(heros)
	var cible := Gobelin.nouveau(donjon).generer_gobelin(donjon, 0, ["guerrier", "combattant"])
	var arme = U.ga(heros, "arme_equipee", null)
	var sortie := {"heros": {"pv": heros.points_de_vie_max, "mana": heros.mana_max, "pa": heros.points_d_action_max,
		"arme": arme.nom if arme != null else "aucune", "des_arme": DescriptionObjet.ligne_des(arme) if arme != null else "",
		"force": U.num(heros, "force"), "intelligence": U.num(heros, "intelligence"), "sagesse": U.num(heros, "sagesse"),
		"dexterite": U.num(heros, "dextérité")},
		"cible": {"nom": cible.nom, "pv": cible.points_de_vie_max, "armure": cible.armure,
			"resistance_magique": U.num(cible, "resistance_magique"), "resistance_elementaire": U.num(cible, "resistance_elementaire")},
		"competences": [], "sorts_connus": [], "sorts_depart": [], "sorts_apprenables": []}
	for nom in heros.competence_de_base:
		sortie["competences"].append(_fiche(heros, heros.competence_de_base[nom], cible))
	for m in heros.magies_apprises:
		sortie["sorts_connus"].append(_fiche(heros, m, cible))
	var depart := {}
	for m in Sorts.sorts_de_depart(heros):
		depart[m.nom_classe] = true
		sortie["sorts_depart"].append(_fiche(heros, m, cible))
	for m in heros.magies_disponibles:
		if not depart.has(m.nom_classe) and Sorts.peut_apprendre(heros, m):
			sortie["sorts_apprenables"].append(_fiche(heros, m, cible))
	var f := FileAccess.open("user://revue_heros.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(sortie, " "))
	f.close()
	print("REVUE ", ProjectSettings.globalize_path("user://revue_heros.json"))
	quit()
