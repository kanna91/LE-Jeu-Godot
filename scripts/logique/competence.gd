class_name Competence
extends Dyn
## Compétence (attaque, sort, soin, renforcement).
##
## Les sous-classes Python (Feu, Coup_d_epee...) ne différaient que par les
## arguments de leur constructeur : ils sont exportés dans donnees/competences.json
## et la compétence est créée par Competences.creer("Coup_d_epee"). Le nom de la
## classe d'origine est gardé dans ``nom_classe`` (``type(comp).__name__``).

const NIVEAU_MAX_COMPETENCE := 100

const TYPES_DEGATS := ["tranchant", "perforant", "contondant", "feu", "froid", "foudre", "arcane", "chaos", "ombre", "lumière"]


## Remplit les attributs (``Compétence.__init__``).
func initialiser(nom_classe: String, a: Dictionary) -> void:
	_d["nom_classe"] = nom_classe
	_d["nom"] = a["nom"]
	_d["description"] = a["description"]
	_d["niveau"] = a.get("niveau", 0)
	_d["cout_mana"] = a["cout_mana"]
	_d["cout_action"] = a.get("cout_action", 1)
	_d["type_competence"] = a["type_competence"]
	_d["type_attaque"] = a["type_attaque"]
	_d["nombre_attaque"] = a["nombre_attaque"]
	_d["nombre_cible"] = a["nombre_cible"]
	_d["type_ciblage"] = a["type_ciblage"]
	var types = a.get("type_degats")
	_d["type_degats"] = types.duplicate() if types is Array else [types]
	for t in TYPES_DEGATS:
		_d["degats_" + t] = a.get("degats_" + t, 0)
	_d["degats_poison"] = 0
	_d["penetration_armure"] = a.get("penetration_armure", 0)
	_d["penetration_resistance"] = a.get("penetration_resistance", 0)
	var alt = a.get("type_alteration", {})
	_d["type_alteration"] = alt.duplicate() if alt != null else {}
	_d["experience_combat"] = 0
	_d["experience"] = 0
	_d["experience_pour_niveau_suivant"] = 100
	_d["multiplicateur_degats"] = 1.0
	_d["bonus_toucher"] = 0.0
	_d["bonus_critique"] = 0.0
	_d["bonus_degats_critique"] = 0.0
	_d["vol_de_vie"] = 0.0
	_d["duree_bonus"] = 0
	_d["puissance_alterations"] = {}
	_d["alterations_lanceur"] = {}
	_d["facteurs_types"] = {}
	_d["pourcentage_types"] = {}
	_d["bonus_execution"] = 0.0
	_d["chance_frappe_bonus"] = 0.0


func gagner_experience(points) -> void:
	_d["experience_combat"] += points


## Encaisse l'expérience du combat et vérifie une montée de niveau.
func recevoir_experience() -> void:
	_d["experience"] += _d["experience_combat"]
	if _d["experience_combat"] > 0:
		print("%s a gagné %d points d'expérience." % [_d["nom"], _d["experience_combat"]])
		_d["experience_combat"] = 0
		verifier_niveau()


## Monte d'autant de niveaux que l'expérience le permet (seuil 20 + 100 × niveau, jusqu'au niveau 100).
## Le niveau ne donne plus rien depuis le 2026-11-03 (amélioration des compétences supprimée, à reforger).
func verifier_niveau() -> void:
	while _d["niveau"] < NIVEAU_MAX_COMPETENCE and _d["experience"] >= 20 + (100 * _d["niveau"]):
		_d["niveau"] += 1
		print("%s est monté au niveau %d !" % [_d["nom"], _d["niveau"]])


func _to_string() -> String:
	return str(_d.get("nom", "?"))
