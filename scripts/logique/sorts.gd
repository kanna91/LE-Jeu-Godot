class_name Sorts
extends RefCounted
## Sorts du grimoire : prérequis par palier, sorts de départ, catalogue (sorts.py).

const TYPES := ["tranchant", "perforant", "contondant", "feu", "froid", "foudre", "arcane", "chaos", "ombre", "lumière"]
const ORDRE_ELEMENTS := ["feu", "froid", "foudre", "arcane", "chaos", "ombre", "lumière", "tranchant", "perforant", "contondant"]
const NOMS_ELEMENTS := {"feu": "Feu", "froid": "Froid", "foudre": "Foudre", "arcane": "Arcane", "chaos": "Chaos",
	"ombre": "Ombre", "lumière": "Lumière", "tranchant": "Tranchant", "perforant": "Perforant",
	"contondant": "Contondant"}
## Caractéristique demandée par les paliers de sorts : celle qui donne leurs dégâts (corrigé le 2026-10-29 : feu,
## froid et foudre demandaient l'intelligence, perforant la dextérité) ; lumière : la plus forte des deux.
const ATTRIBUT_ELEMENT := {"feu": "sagesse", "froid": "sagesse", "foudre": "sagesse", "arcane": "intelligence",
	"chaos": "intelligence", "ombre": "intelligence", "lumière": "intelligence_ou_sagesse",
	"tranchant": "force", "perforant": "force", "contondant": "force"}
const NOMS_ATTRIBUTS := {"intelligence": "Intelligence", "sagesse": "Sagesse", "force": "Force", "dextérité": "Dextérité",
	"intelligence_ou_sagesse": "Intelligence ou sagesse"}
## Palier -> [niveau du héros, valeur de l'attribut, sorts du même élément déjà connus]
const PALIERS := {0: [1, 0, 0], 1: [3, 4, 0], 2: [6, 7, 0], 3: [10, 10, 1], 4: [15, 14, 2], 5: [20, 18, 3]}
const SORTS_DE_DEPART := ["Boule_de_feu", "Givre", "Eclair", "Trait_arcanique", "Souffle_du_chaos", "Murmure_des_ombres",
	"Estafilade", "Dard_empoisonne", "Bourrade"]


## Élément d'un sort (ELEMENT, sinon son premier type de dégâts).
static func element_de(sort):
	var e = U.ga(sort, "ELEMENT", null)
	if U.vrai(e):
		return e
	var types = U.ga(sort, "type_degats", null)
	if types == null:
		return null
	for t in types:
		if U.vrai(t):
			return t
	return null


static func sorts_connus(joueur, element) -> int:
	var n := 0
	for m in U.ga(joueur, "magies_apprises", []):
		if element_de(m) == element:
			n += 1
	return n


## Prérequis d'un sort : [[genre, clé, valeur], ...] (« niveau », « attribut », « sorts »).
static func prerequis(sort) -> Array:
	if not (sort is Sort):
		return []
	var p: Array = PALIERS[int(sort.PALIER)]
	var liste := [["niveau", "niveau", p[0]]]
	if p[1]:
		liste.append(["attribut", ATTRIBUT_ELEMENT[sort.ELEMENT], p[1]])
	if p[2]:
		liste.append(["sorts", sort.ELEMENT, p[2]])
	return liste


static func _rempli(joueur, genre: String, cle: String, valeur) -> bool:
	if genre == "sorts":
		return sorts_connus(joueur, cle) >= valeur
	if cle == "intelligence_ou_sagesse":
		return maxf(U.num(joueur, "intelligence"), U.num(joueur, "sagesse")) >= valeur
	return U.num(joueur, cle) >= valeur


static func libelle_prerequis(genre: String, cle: String, valeur) -> String:
	if genre == "niveau":
		return "Niveau %d" % valeur
	if genre == "attribut":
		return "%s %d" % [NOMS_ATTRIBUTS.get(cle, cle), valeur]
	var pluriel := "s" if valeur > 1 else ""
	return "%d sort%s %s connu%s" % [valeur, pluriel, String(NOMS_ELEMENTS.get(cle, cle)).to_lower(), pluriel]


## [[libellé, rempli], ...] pour chaque prérequis.
static func etat_prerequis(joueur, sort) -> Array:
	var liste := []
	for p in prerequis(sort):
		liste.append([libelle_prerequis(p[0], p[1], p[2]), _rempli(joueur, p[0], p[1], p[2])])
	return liste


static func peut_apprendre(joueur, sort) -> bool:
	for e in etat_prerequis(joueur, sort):
		if not e[1]:
			return false
	return true


## Sorts offensifs de départ que le joueur peut encore apprendre, dans l'ordre de SORTS_DE_DEPART.
static func sorts_de_depart(joueur) -> Array:
	var par_nom := {}
	for m in joueur.magies_disponibles:
		par_nom[m.nom_classe] = m
	var liste := []
	for nom in SORTS_DE_DEPART:
		if par_nom.has(nom):
			liste.append(par_nom[nom])
	return liste


## Ajoute aux magies disponibles les sorts que le joueur n'a ni appris ni à disposition.
static func completer_catalogue(joueur) -> int:
	var connus := {}
	for m in U.ga(joueur, "magies_apprises", []) + U.ga(joueur, "magies_disponibles", []):
		connus[m.nom_classe] = true
	var ajoutes := []
	for nom in Competences.classes_de_sorts():
		if not connus.has(nom):
			ajoutes.append(Competences.creer(nom))
	joueur.magies_disponibles.append_array(ajoutes)
	return ajoutes.size()
