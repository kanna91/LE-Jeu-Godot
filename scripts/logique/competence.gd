class_name Competence
extends Dyn
## Compétence (attaque, sort, soin, renforcement).
##
## Les sous-classes Python (Feu, Coup_d_epee...) ne différaient que par les
## arguments de leur constructeur : ils sont exportés dans donnees/competences.json
## et la compétence est créée par Competences.creer("Coup_d_epee"). Le nom de la
## classe d'origine est gardé dans ``nom_classe`` (``type(comp).__name__``).

const HAUSSE_COUT_FIXE := 2
const HAUSSE_COUT_PROPORTION := 0.15
const POINTS_PAR_OPTION := 10
const POINTS_DEBLOCAGE_NIVEAU := 10
const POINTS_PAR_NIVEAU := 1
const NIVEAU_MAX_COMPETENCE := 100
const VERSION_AMELIORATIONS := 2

const TYPES_DEGATS := ["tranchant", "perforant", "contondant", "feu", "froid", "foudre", "arcane", "chaos", "ombre", "lumière"]


## Points investis dans une option d'amélioration (une option débloquée d'une ancienne version compte comme remplie).
static func points_investis(amel: Dictionary) -> int:
	return int(amel.get("investi", POINTS_PAR_OPTION if amel.get("debloquee") else 0))


## Remplit les attributs (``Compétence.__init__``).
func initialiser(nom_classe: String, a: Dictionary) -> void:
	_d["nom_classe"] = nom_classe
	_d["nom"] = a["nom"]
	_d["description"] = a["description"]
	_d["niveau"] = a.get("niveau", 0)
	_d["points_amélioration"] = a.get("points_amélioration", 0)
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
	_d["ameliorations_possibles"] = []
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
	_d["version_ameliorations"] = VERSION_AMELIORATIONS


## Hausse du coût en mana de la prochaine amélioration : 2 + 15 % (0 pour une compétence gratuite).
func hausse_cout_amelioration() -> int:
	if _d["cout_mana"] <= 0:
		return 0
	return HAUSSE_COUT_FIXE + int(_d["cout_mana"] * HAUSSE_COUT_PROPORTION + 0.5)


## Points investis dans les options d'un niveau d'amélioration.
func points_niveau(index: int) -> int:
	var total := 0
	for a in _d["ameliorations_possibles"][index]:
		total += points_investis(a)
	return total


## Indice du niveau d'amélioration le plus avancé accessible (-1 si l'arbre est vide).
func dernier_niveau_ouvert() -> int:
	var niveaux: Array = _d["ameliorations_possibles"]
	if niveaux.is_empty():
		return -1
	var dernier := 0
	while dernier + 1 < niveaux.size() and points_niveau(dernier) >= POINTS_DEBLOCAGE_NIVEAU:
		dernier += 1
	return dernier


## Investit des points d'amélioration dans une option d'un niveau accessible.
func améliorer_compétence(choix, niveau = null, points := 1, augmenter_cout := true) -> bool:
	if not (str(choix) in ["0", "1", "2"]):
		return false
	choix = int(choix)
	if niveau == null:
		niveau = dernier_niveau_ouvert()
	if not (0 <= niveau and niveau <= dernier_niveau_ouvert()):
		return false
	if choix >= _d["ameliorations_possibles"][niveau].size():
		return false
	points = mini(int(points), int(_d["points_amélioration"]))
	if points <= 0:
		return false
	if augmenter_cout and points_niveau(niveau) == 0:
		Ameliorations.recalibrer_niveau(self, niveau)
	var amel: Dictionary = _d["ameliorations_possibles"][niveau][choix]
	var deja := points_investis(amel)
	points = mini(points, POINTS_PAR_OPTION - deja)
	if points <= 0:
		return false
	amel["investi"] = deja + points
	_d["points_amélioration"] -= points
	var remplie: bool = amel["investi"] >= POINTS_PAR_OPTION
	Ameliorations.appliquer_fraction(self, amel, float(points) / POINTS_PAR_OPTION, remplie)
	if augmenter_cout:
		if not amel.has("hausse_prevue"):
			amel["hausse_prevue"] = hausse_cout_amelioration()
		var c := int(amel["hausse_prevue"] * float(amel["investi"]) / POINTS_PAR_OPTION + 0.5)
		_d["cout_mana"] += c - amel.get("cout_ajoute", 0)
		amel["cout_ajoute"] = c
	if remplie:
		amel["debloquee"] = true
	return true


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
func verifier_niveau() -> void:
	while _d["niveau"] < NIVEAU_MAX_COMPETENCE and _d["experience"] >= 20 + (100 * _d["niveau"]):
		_d["niveau"] += 1
		_d["points_amélioration"] += POINTS_PAR_NIVEAU
		print("%s est monté au niveau %d !" % [_d["nom"], _d["niveau"]])


func _to_string() -> String:
	return str(_d.get("nom", "?"))
