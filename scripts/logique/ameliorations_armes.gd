class_name AmeliorationsArmes
extends RefCounted
## Améliorations des armes chez trois PNJ (règles de l'utilisateur, 2026-11-09).
##
## - **Armurier** : dés du type de l'arme (contondant au marteau, perforant à la lance, tranchant à l'épée), lancés
##   seulement par les attaques de l'arme (Coup d'épée, Frénésie...).
## - **Alchimiste** : dés de poison, feu, froid, foudre, arcane, chaos ou ombre, lancés par les attaques de l'arme.
##   Poison limité à 1d4.
## - **Enchanteur** : dés de feu, froid, foudre, arcane, chaos ou ombre, lancés par les **sorts** offensifs du héros
##   (Boule de feu, Souffle du chaos...), jamais par les attaques de l'arme.
## Dés possibles : 1d2, 1d3, 1d4, 1d6 (FACES). Une arme reçoit au plus 3 améliorations de l'armurier, et au plus 3
## en tout chez l'alchimiste et l'enchanteur (2 + 1, 3 + 0... au choix du joueur, précision de l'utilisateur).
## Les dés identiques s'additionnent : deux fois feu 1d3 chez l'enchanteur = 2d3 de feu sur les sorts.
##
## Un dé déjà lancé par la compétence (feu de Souffle du chaos, tranchant de Coup d'épée) s'ajoute à ses dés
## (Formules.des_type : caractéristique, dégâts plats et % du type comptent une fois) ; un type que la compétence
## ne fait pas (feu sur Coup d'épée) devient un coup à part de ce type (types_en_plus, comme le dé bonus d'arme :
## jet × % du type).
##
## **Recettes** : chaque amélioration demande une recette trouvée dans le donjon (butin « Recette » de l'éditeur de
## zones). Lue au ramassage, elle est connue pour toute la partie (``joueur.recettes``) et sert autant de fois qu'on
## veut. Armurier : une recette par dé ; alchimiste et enchanteur : une par élément et par dé.
## **Prix** : or + ingrédients, réglés dans ``donnees/ameliorations_armes.json`` (ingrédients vides pour l'instant).
##
## Données d'une arme : ``ameliorations_armurier`` [faces, ...] et ``ameliorations_magiques``
## [{pnj, type, faces}, ...].

const FACES := [2, 3, 4, 6]
const MAX_ARMURIER := 3
const MAX_MAGIE := 3
const PNJ := ["armurier", "alchimiste", "enchanteur"]
const NOMS_PNJ := {"armurier": "Armurier", "alchimiste": "Alchimiste", "enchanteur": "Enchanteur"}
const TYPES_ALCHIMIE := ["poison", "feu", "froid", "foudre", "arcane", "chaos", "ombre"]
const TYPES_ENCHANTEMENT := ["feu", "froid", "foudre", "arcane", "chaos", "ombre"]
## Plus gros dé permis par type (poison : 1d4, règle de l'utilisateur).
const FACES_MAX := {"poison": 4}
const NOMS_TYPES := {"poison": "poison", "feu": "feu", "froid": "froid", "foudre": "foudre", "arcane": "arcane",
	"chaos": "chaos", "ombre": "ombre", "tranchant": "tranchant", "perforant": "perforant", "contondant": "contondant"}

static var _reglages := {}


# ---------------------------------------------------------------------------
# Réglages (prix)
# ---------------------------------------------------------------------------

static func reglages() -> Dictionary:
	if _reglages.is_empty():
		var d = U.charger_json("ameliorations_armes.json")
		_reglages = d if d is Dictionary else {}
		_reglages["_charge"] = true
	return _reglages


## Or demandé pour une amélioration de ``faces`` chez ``pnj``.
static func prix(pnj: String, faces: int) -> int:
	var table = reglages().get("prix", {})
	var par_pnj = table.get(pnj, table) if table is Dictionary else {}
	return int(par_pnj.get(str(faces), 0)) if par_pnj is Dictionary else 0


## Ingrédients demandés : [{nom, nombre}, ...] ([] si aucun).
static func ingredients(pnj: String, faces: int) -> Array:
	var table = reglages().get("ingredients", {})
	var par_pnj = table.get(pnj, {}) if table is Dictionary else {}
	var liste = par_pnj.get(str(faces), []) if par_pnj is Dictionary else []
	return liste if liste is Array else []


# ---------------------------------------------------------------------------
# Recettes
# ---------------------------------------------------------------------------

## Identifiant d'une recette : « armurier:4 », « alchimiste:feu:3 », « enchanteur:ombre:6 ».
static func id_recette(pnj: String, type_degats: String, faces: int) -> String:
	return "%s:%d" % [pnj, faces] if pnj == "armurier" else "%s:%s:%d" % [pnj, type_degats, faces]


## [pnj, type ("" pour l'armurier), faces] d'un identifiant de recette ([] s'il est invalide).
static func lire_recette(id: String) -> Array:
	var morceaux := id.split(":")
	if morceaux.size() == 2 and morceaux[0] == "armurier" and int(morceaux[1]) in FACES:
		return ["armurier", "", int(morceaux[1])]
	if morceaux.size() == 3 and morceaux[0] in ["alchimiste", "enchanteur"] and int(morceaux[2]) in FACES \
			and morceaux[1] in types_du_pnj(morceaux[0]) and int(morceaux[2]) <= FACES_MAX.get(morceaux[1], 99):
		return [morceaux[0], morceaux[1], int(morceaux[2])]
	return []


static func types_du_pnj(pnj: String) -> Array:
	return TYPES_ALCHIMIE if pnj == "alchimiste" else (TYPES_ENCHANTEMENT if pnj == "enchanteur" else [""])


## Toutes les recettes du jeu (4 d'armurier, 27 d'alchimie, 24 d'enchantement).
static func toutes_les_recettes() -> Array:
	var liste := []
	for pnj in PNJ:
		for t in types_du_pnj(pnj):
			for f in FACES:
				if f <= FACES_MAX.get(t, 99):
					liste.append(id_recette(pnj, t, f))
	return liste


## Nom lisible : « Recette d'armurier (1d4) », « Recette d'alchimie (feu 1d3) », « Recette d'enchantement (ombre 1d6) ».
static func nom_recette(id: String) -> String:
	var r := lire_recette(id)
	if r.is_empty():
		return id
	match r[0]:
		"armurier":
			return "Recette d'armurier (1d%d)" % r[2]
		"alchimiste":
			return "Recette d'alchimie (%s 1d%d)" % [r[1], r[2]]
	return "Recette d'enchantement (%s 1d%d)" % [r[1], r[2]]


## Identifiant d'après le nom lisible (butin posé dans l'éditeur) ; « » s'il n'existe pas.
static func id_depuis_nom(nom: String) -> String:
	for id in toutes_les_recettes():
		if nom_recette(id) == nom or id == nom:
			return id
	return ""


static func noms_recettes() -> Array:
	return toutes_les_recettes().map(func(id): return nom_recette(id))


static func recettes_connues(joueur) -> Array:
	var r = U.ga(joueur, "recettes", null)
	return r if r is Array else []


static func connait(joueur, id: String) -> bool:
	return id in recettes_connues(joueur)


## Le héros lit une recette (``nom`` : nom lisible ou identifiant ; « » : une qu'il ne connaît pas, au hasard).
## Renvoie le message.
static func apprendre(joueur, nom := "") -> String:
	var id := id_depuis_nom(nom) if nom != "" else ""
	if id == "":
		var inconnues := toutes_les_recettes().filter(func(x): return not connait(joueur, x))
		if inconnues.is_empty():
			return "Une recette… que vous connaissez déjà par cœur."
		id = inconnues.pick_random()
	if connait(joueur, id):
		return "%s : vous la connaissez déjà." % nom_recette(id)
	var liste := recettes_connues(joueur).duplicate()
	liste.append(id)
	joueur._d["recettes"] = liste
	return "Vous apprenez : %s. L'%s saura s'en servir." % [nom_recette(id), lire_recette(id)[0]]


# ---------------------------------------------------------------------------
# Améliorations d'une arme
# ---------------------------------------------------------------------------

static func armurier_de(arme) -> Array:
	var l = U.ga(arme, "ameliorations_armurier", null) if arme != null else null
	return l if l is Array else []


static func magiques_de(arme) -> Array:
	var l = U.ga(arme, "ameliorations_magiques", null) if arme != null else null
	return l if l is Array else []


## Type de dégâts que l'armurier ajoute à cette arme ("" si ce n'est pas une arme connue).
static func type_armurier(arme) -> String:
	return Formules.DES_ARMES.get(U.ga(arme, "type_arme", ""), "")


## Pourquoi on ne peut pas faire cette amélioration (« » si on peut), sans compter l'or ni les ingrédients.
static func refus(arme, pnj: String, type_degats: String, faces: int) -> String:
	if arme == null or not (arme is Arme) or type_armurier(arme) == "":
		return "Ce n'est pas une arme qu'on peut améliorer."
	if not (faces in FACES) or faces > FACES_MAX.get(type_degats, 99):
		return "Ce dé n'existe pas."
	if pnj == "armurier":
		if armurier_de(arme).size() >= MAX_ARMURIER:
			return "L'arme a déjà %d améliorations d'armurier." % MAX_ARMURIER
	elif magiques_de(arme).size() >= MAX_MAGIE:
		return "L'arme a déjà %d améliorations d'alchimie ou d'enchantement." % MAX_MAGIE
	return ""


## Applique l'amélioration (sans rien payer) ; renvoie vrai si elle est faite.
static func ameliorer(arme, pnj: String, type_degats: String, faces: int) -> bool:
	if refus(arme, pnj, type_degats, faces) != "":
		return false
	if pnj == "armurier":
		var l := armurier_de(arme).duplicate()
		l.append(faces)
		arme._d["ameliorations_armurier"] = l
	else:
		var l := magiques_de(arme).duplicate()
		l.append({"pnj": pnj, "type": type_degats, "faces": faces})
		arme._d["ameliorations_magiques"] = l
	return true


## Le héros a-t-il l'or et les ingrédients ? « » si oui, sinon ce qui manque.
static func manque(joueur, pnj: String, faces: int) -> String:
	var manques := []
	var p := prix(pnj, faces)
	if int(U.ga(joueur, "piece_or", 0)) < p:
		manques.append("%d or" % p)
	for ing in ingredients(pnj, faces):
		var n := int(ing.get("nombre", 1))
		if _compter(joueur, String(ing.get("nom", ""))) < n:
			manques.append("%d × %s" % [n, ing.get("nom", "")])
	return ", ".join(manques)


static func _compter(joueur, nom: String) -> int:
	var n := 0
	for o in U.ga(joueur, "inventaire", []):
		if U.ga(o, "nom", "") == nom:
			n += 1
	return n


## Paie et applique l'amélioration ; renvoie « » si c'est fait, sinon la raison du refus.
static func acheter(joueur, arme, pnj: String, type_degats: String, faces: int) -> String:
	if not connait(joueur, id_recette(pnj, type_degats, faces)):
		return "Vous ne connaissez pas cette recette."
	var r := refus(arme, pnj, type_degats, faces)
	if r == "":
		r = manque(joueur, pnj, faces)
		if r != "":
			r = "Il vous manque : " + r + "."
	if r != "":
		return r
	joueur.piece_or -= prix(pnj, faces)
	for ing in ingredients(pnj, faces):
		for _k in int(ing.get("nombre", 1)):
			for o in U.ga(joueur, "inventaire", []):
				if U.ga(o, "nom", "") == String(ing.get("nom", "")):
					joueur.retirer_objet_inventaire(o)
					break
	ameliorer(arme, pnj, type_degats, faces)
	return ""


## Dés groupés ([[nombre, faces], ...], gros dés d'abord) d'une liste de faces.
static func grouper(faces: Array) -> Array:
	var comptes := {}
	for f in faces:
		comptes[int(f)] = comptes.get(int(f), 0) + 1
	var cles := comptes.keys()
	cles.sort()
	cles.reverse()
	return cles.map(func(f): return [comptes[f], f])


## Résumé d'une arme : « Armurier : +2d2 + 1d4 contondant · Alchimie : +1d3 poison · Sorts : +2d3 feu ».
static func resume(arme) -> String:
	var morceaux := []
	if not armurier_de(arme).is_empty():
		morceaux.append("Armurier : +%s %s" % [Formules.texte(grouper(armurier_de(arme))), type_armurier(arme)])
	for pnj in ["alchimiste", "enchanteur"]:
		var par_type := {}
		for a in magiques_de(arme):
			if a.get("pnj") == pnj:
				if not par_type.has(a["type"]):
					par_type[a["type"]] = []
				par_type[a["type"]].append(int(a["faces"]))
		var textes := []
		for t in par_type:
			textes.append("+%s %s" % [Formules.texte(grouper(par_type[t])), t])
		if not textes.is_empty():
			morceaux.append("%s : %s" % ["Alchimie (armes)" if pnj == "alchimiste" else "Enchantement (sorts)", ", ".join(textes)])
	return " · ".join(morceaux)


# ---------------------------------------------------------------------------
# Combat : dés ajoutés
# ---------------------------------------------------------------------------

static func _arme(lanceur):
	if lanceur == null or lanceur is Ennemis:
		return null
	return U.ga(lanceur, "arme_equipee", null)


## Vrai pour un sort offensif du héros (enchantements de l'enchanteur) : un Sort du grimoire, un sort de départ
## (Boule de feu, Givre... sont des compétences, pas des Sort) ou une magie apprise.
static func est_sort(lanceur, competence) -> bool:
	if competence == null or U.ga(competence, "type_competence", "") != "offensif":
		return false
	if competence is Sort or String(U.ga(competence, "nom_classe", "")) in Sorts.SORTS_DE_DEPART:
		return true
	var apprises = U.ga(lanceur, "magies_apprises", []) if lanceur != null else []
	return apprises is Array and apprises.has(competence)


## Dés ajoutés par les améliorations de l'arme du lanceur à ce type de dégâts pour cette compétence ([] : aucun).
## Sans compétence (affichage de l'arme) : ceux des attaques de l'arme.
static func des(lanceur, competence, type_degats: String) -> Array:
	var arme = _arme(lanceur)
	if arme == null:
		return []
	var faces := []
	if competence == null or Formules.est_attaque_arme(lanceur, competence):
		if type_degats == type_armurier(arme):
			faces += armurier_de(arme)
		for a in magiques_de(arme):
			if a.get("pnj") == "alchimiste" and a.get("type") == type_degats:
				faces.append(int(a["faces"]))
	elif est_sort(lanceur, competence):
		for a in magiques_de(arme):
			if a.get("pnj") == "enchanteur" and a.get("type") == type_degats:
				faces.append(int(a["faces"]))
	return grouper(faces)


## Types que les améliorations ajoutent à la compétence alors qu'elle ne les fait pas (feu sur Coup d'épée) :
## [[type, dés], ...], à lancer comme des coups à part.
static func types_en_plus(lanceur, competence) -> Array:
	var arme = _arme(lanceur)
	if arme == null or competence == null:
		return []
	var deja: Array = U.ga(competence, "type_degats", [])
	var liste := []
	for t in TYPES_ALCHIMIE:
		if t in deja:
			continue
		var d := des(lanceur, competence, t)
		if not d.is_empty():
			liste.append([t, d])
	return liste
