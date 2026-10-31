class_name Sort
extends Competence
## Sort du grimoire décrit par une fiche (sorts.py : Sort). Les fiches sont
## exportées dans donnees/sorts.json ; ELEMENT, PALIER, JOUEUR et
## renforcer_propres sont gardés comme attributs de l'instance.

const BONUS := ["bonus_critique", "bonus_toucher", "bonus_degats_critique", "bonus_execution", "chance_frappe_bonus",
	"vol_de_vie", "facteurs_types", "alterations_lanceur", "puissance_alterations", "purification",
	"soin_pourcentage_pv", "multiplicateur_degats"]


## Construit le sort d'après sa fiche (sans le préparer : voir Competences.creer).
func initialiser_sort(nom_classe: String, element, palier: int, f: Dictionary) -> void:
	var degats: Dictionary = f.get("degats", {})
	var args := {
		"nom": f["nom"], "description": f["description"], "niveau": 0, "points_amélioration": 0,
		"cout_mana": U.entiers(f["mana"]), "cout_action": U.entiers(f.get("pa", 1)),
		"type_competence": f.get("genre", "offensif"), "type_attaque": f.get("attaque", "magique"),
		"nombre_attaque": U.entiers(f.get("frappes", 1)), "nombre_cible": U.entiers(f.get("cibles", 1)),
		"type_ciblage": f.get("ciblage", "choix"), "type_degats": f["types"].duplicate(),
		"penetration_armure": U.entiers(f.get("pen_armure", 0)), "penetration_resistance": U.entiers(f.get("pen_resistance", 0)),
		"type_alteration": U.entiers(f.get("alterations", {})),
	}
	for t in Competence.TYPES_DEGATS:
		args["degats_" + t] = U.entiers(degats.get(t, 0))
	initialiser(nom_classe, args)
	_d["degats_poison"] = U.entiers(degats.get("poison", 0))
	_d["purification"] = 0
	for cle in BONUS:
		if f.has(cle):
			var valeur = U.entiers(f[cle])
			_d[cle] = valeur.duplicate() if valeur is Dictionary else valeur
	_d["ELEMENT"] = element
	_d["PALIER"] = palier
	_d["JOUEUR"] = true
	_d["renforcer_propres"] = true
