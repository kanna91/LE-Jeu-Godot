class_name Objets
extends RefCounted
## Emplacements d'équipement et bonus des équipements.

const EMPLACEMENTS_EQUIPEMENT := ["arme", "anneau_1", "anneau_2", "amulette", "gants",
	"casque", "plastron", "ceinture", "jambières", "bottes"]

static var _attributs_bonus := []


## Statistiques qu'un équipement ajoute à son porteur (ATTRIBUTS_BONUS).
## Depuis la refonte des objets (2026-10-30), un objet généré ne donne qu'une option (GenerationObjets) ; la liste
## garde aussi les anciens attributs pour les objets spéciaux (lance de test, effets des talents).
static func attributs_bonus() -> Array:
	if _attributs_bonus.is_empty():
		var a := ["degats_base", "degats_physique", "degats_magique", "degats_elementaire"]
		for t in Degats.TYPES + ["lumière"]:
			a.append("degats_" + t)
		for t in ["physique", "magique", "elementaire"] + Degats.TYPES + ["lumière"]:
			a.append("pourcentage_degats_" + t)
		a += ["penetration_resistance", "penetration_armure", "chance_de_coup_critique", "degats_critique",
			"chance_de_coup_critique_magique", "chance_de_coup_critique_elementaire", "degats_critique_magiques",
			"chance_esquive", "chance_de_toucher", "chance_de_parer", "puissance_magique",
			"mana_max", "regen_de_mana", "points_de_vie_max", "regen_de_points_de_vie", "points_d_action_max",
			"armure", "resistance_magique", "resistance_elementaire"]
		a += Caracteristiques.LISTE
		for t in Degats.TYPES:
			a += ["resistance_" + t, "resistance_pct_" + t, "vulnerabilite_" + t]
		for g in Degats.GROUPES:
			a += ["resistance_pct_" + g, "vulnerabilite_" + g]
		_attributs_bonus = a
	return _attributs_bonus


## Type d'emplacement d'un objet : « arme », « anneau », « amulette », « casque »... (null sinon).
static func type_emplacement(objet):
	if objet is Arme:
		return "arme"
	if objet is Armure:
		return U.ga(objet, "type_armure", null)
	return null


## Emplacement où irait un objet dans un équipement donné (anneau : libre, sinon le moins bon).
static func emplacement_pour(equipements: Dictionary, objet):
	var genre = type_emplacement(objet)
	if genre == "anneau":
		for cle in ["anneau_1", "anneau_2"]:
			if equipements.has(cle) and equipements[cle] == null:
				return cle
		var portes := []
		for c in ["anneau_1", "anneau_2"]:
			if equipements.has(c):
				portes.append(c)
		if portes.is_empty():
			return null
		return U.min_par(portes, func(c): return U.num(equipements[c], "points"))
	return genre if genre != null and equipements.has(genre) else null


## Ajoute (signe 1) ou retire (signe -1) les bonus d'un équipement, effets uniques ``talent_*`` compris.
static func ajouter_bonus(porteur, objet, signe := 1) -> void:
	var effets := []
	for a in objet.attributs():
		if String(a).begins_with("talent_"):
			effets.append(a)
	for attribut in attributs_bonus() + effets:
		var valeur = U.ga(objet, attribut, 0)
		if valeur == null or valeur is bool:
			continue
		if (valeur is int or valeur is float) and valeur != 0:
			var total = U.ga(porteur, attribut, 0) + signe * valeur
			porteur.set(attribut, 0 if absf(total) < 1e-9 else total)
