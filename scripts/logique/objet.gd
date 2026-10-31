class_name Objet
extends Dyn
## Classe de base de tous les objets (objets.py : Objet). Un objet porte des
## bonus de statistiques qui s'ajoutent à celles de son porteur.

## Étage courant, utilisé pour choisir le rang des objets générés.
static var compteur_etage_objet := 1

## Statistiques mises à 0 sur tout objet neuf (refonte du 2026-10-30 : dégâts par groupe, défenses en points).
const STATS_DE_BASE := ["degats_base", "degats_physique", "degats_magique", "degats_elementaire",
	"degats_tranchant", "degats_perforant", "degats_contondant", "degats_feu", "degats_froid", "degats_foudre",
	"degats_arcane", "degats_chaos", "degats_ombre", "degats_lumière",
	"pourcentage_degats_physique", "pourcentage_degats_magique", "pourcentage_degats_elementaire",
	"penetration_resistance", "penetration_armure", "chance_de_coup_critique", "degats_critique",
	"chance_de_coup_critique_magique", "degats_critique_magiques", "chance_esquive", "chance_de_toucher",
	"chance_de_parer", "force", "puissance_magique", "mana_max", "points_de_vie_max", "points_d_action_max",
	"armure", "resistance_magique", "resistance_elementaire", "resistance_tranchant", "resistance_perforant",
	"resistance_contondant", "resistance_feu", "resistance_froid", "resistance_foudre", "resistance_arcane",
	"resistance_chaos", "resistance_ombre"]


## Remplit les attributs communs (``Objet.__init__``).
func initialiser(nom: String, type_objet: String, _description := "", valeur = 0) -> void:
	_d["nom"] = nom
	_d["type_objet"] = type_objet
	_d["valeur"] = int(valeur)
	_d["rang"] = 0
	for stat in STATS_DE_BASE:
		_d[stat] = 0
	_d["afflictions"] = ["usure", "stun", "brulure", "poison", "aveugler", "silencieux"]
	_d["alteration"] = []


static func nouveau(nom: String, type_objet: String, description := "", valeur = 0) -> Objet:
	var o := Objet.new()
	o.initialiser(nom, type_objet, description, valeur)
	return o


## Tire au sort un bonus de critique magique (rang 2 et plus).
static func ajouter_critique_magique(objet, rang) -> void:
	if rang == null or rang < 2:
		return
	var chance := 0.40 if rang >= 4 else 0.30
	if randf() < chance:
		objet.chance_de_coup_critique_magique += U.arrondi(randf_range(0.01, 0.02) * rang, 2)
	if randf() < chance:
		objet.degats_critique_magiques += U.arrondi(randf_range(0.04, 0.06) * rang, 2)


func est_arme() -> bool:
	return self is Arme


func est_armure() -> bool:
	return self is Armure and not est_bijou()


func est_bijou() -> bool:
	return self is Armure and U.ga(self, "type_armure", null) in ["anneau", "amulette"]


func est_consommable() -> bool:
	return U.ga(self, "type_objet", null) == "consommable"


## Attribue un rang : imposé, ou tiré selon l'étage (1-2, 2-3, 3-4, 4-5, puis 5-6).
static func definir_rang(objet, rang = null) -> void:
	if rang != null:
		objet.rang = rang
		return
	var etage := compteur_etage_objet
	if etage == 1:
		objet.rang = [1, 2].pick_random()
	elif etage == 2:
		objet.rang = [2, 3].pick_random()
	elif etage == 3:
		objet.rang = [3, 4].pick_random()
	elif etage == 4:
		objet.rang = [4, 5].pick_random()
	else:
		objet.rang = [5, 6].pick_random()


func equiper() -> void:
	_d["equipee"] = true


func desequiper() -> void:
	_d["equipee"] = false


func _to_string() -> String:
	return str(_d.get("nom", "?"))
