class_name Auto
extends RefCounted
## Joueur automatique, pour tester la logique sans affichage (Ecrans.auto).


## Une action de combat : potion si les PV sont bas, sinon une attaque ou un sort sur un ennemi au hasard.
## Actions de combat jouées depuis le lancement (mesure du testeur d'étage, tests/testeur_etage.gd).
static var actions_combat := 0
## Combats joués (testeur d'étage) : [{"ennemis": noms, "actions": n, "combat": objet}].
static var journal_combats := []


static func action_combat(personnage, combat) -> void:
	actions_combat += 1
	if journal_combats.is_empty() or journal_combats[-1]["combat"] != combat:
		journal_combats.append({"ennemis": combat.ennemis.map(func(e): return String(e.nom)), "actions": 0, "combat": combat,
			"boss": combat.ennemis.any(func(e): return U.ga(e, "est_boss", false))})
	journal_combats[-1]["actions"] += 1
	if combat.ennemis.is_empty():
		return
	# Donjon d'aventure : contre un Chevalier de la mort (coups plafonnés), le joueur automatique tente de fuir
	for e in combat.ennemis:
		if U.ga(e, "invulnerable", false) or U.ga(e, "plafond_degats", null) is Array:
			if not combat.tenter_fuite():
				combat.passer_son_tour()
			return
	if personnage.points_de_vie < personnage.points_de_vie_max * 0.35:
		for objet in personnage.inventaire:
			if objet is Consommable and objet.effet["type"] in ["pv", "mixte"] and personnage.points_d_action >= 1:
				personnage.utiliser_objet_inventaire(objet.nom)
				combat.verification_des_vivants()
				combat.epuise()
				return
	var choix := []
	var attaques: Array = combat.attaques_de_base()
	choix.append(attaques[1])
	choix.append(attaques[3])
	for m in personnage.magies_apprises:
		choix.append(m)
	choix.shuffle()
	for competence in choix:
		if combat.logique_menu_combat(null, competence) == true:
			var cibles := [combat.ennemis.pick_random()]
			if competence.type_ciblage == "self":
				cibles = [personnage]
			combat.logique_menu_combat(null, competence, cibles)
			return
	combat.logique_menu_combat("5")


static func coffre(personnage, _donjon, salle) -> void:
	SallesBonus.prendre_coffre(personnage, salle)


static func bonus(personnage, salle) -> void:
	SallesBonus.appliquer_bonus(personnage, salle, SallesBonus.choix_bonus(salle)[0])


static func soin(personnage, salle) -> void:
	SallesBonus.boire_source(personnage, salle)
