class_name Cuisine
extends RefCounted
## Cuisine (conception avec l'utilisateur : CUISINE.md ; règles et valeurs cachées : donnees/cuisine.json).
##
## Un plat = 1 à 4 ingrédients (+ un bouillon facultatif) et une préparation : sans feu, grillé, bouilli, mijoté / four.
## Recette faite avec sa préparation : somme des valeurs cachées × multiplicateur (+0,1 par ingrédient au-delà de 2) ;
## sinon mixture (×0,5) ou plat immonde (×0,25). Mêmes règles que outils/cuisine_combinaisons.py (liste complète).
##
## Feu : la torche de la salle ne sert qu'à allumer du bois (on ne cuit pas à même la torche, règle de l'utilisateur
## du 2026-11-03) ; feu de camp (griller et bouillir : 3 plats, 10 minutes, allumé avec un brandon pris à une torche
## ou avec amadou + silex, 1 morceau de bois ou planche) ; foyer de la cuisine (tout, mijoté et four compris, eau
## infinie). Bouillir hors de la cuisine : marmite + 1 L d'eau du seau (10 L), rempli à la cuisine ou à un point d'eau
## marqué dans l'éditeur (onglet « Eau »).
## Recettes connues : ``joueur.recettes_connues`` (celles « connue » au départ) ; les autres s'apprennent en les
## réussissant, par une page de livre de cuisine, ou plus tard par les prisonniers (``apprendre``).
## Horloge de la cuisine (feux, brandons) : ``joueur.horloge`` en secondes d'exploration (``avancer``).

const PREPARATIONS := ["sans_feu", "grille", "bouilli", "mijote"]
const COMBUSTIBLES := ["Morceau de bois", "Planche en bois"]
const MAX_INGREDIENTS := 4

static var _d := {}


static func donnees() -> Dictionary:
	if _d.is_empty():
		var f := FileAccess.open("res://donnees/cuisine.json", FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text()) if f != null else null
		_d = d if d is Dictionary else {"ingredients": {}, "recettes": [], "preparations": {}, "immondes": []}
	return _d


static func nom_preparation(prep: String) -> String:
	return String(donnees()["preparations"].get(prep, {}).get("nom", prep))


## Identifiant d'ingrédient de cuisine d'un objet (par son nom), ou « ».
static func ingredient_de(objet) -> String:
	if objet == null:
		return ""
	var nom := String(objet.nom)
	for id in donnees()["ingredients"]:
		if String(donnees()["ingredients"][id]["nom"]) == nom:
			return id
	return ""


# ---------------------------------------------------------------------------
# Évaluation d'un mélange (comme outils/cuisine_combinaisons.py)
# ---------------------------------------------------------------------------

static func _accepte(motif: String, id: String) -> bool:
	if motif.begins_with("famille:"):
		return String(donnees()["ingredients"][id]["famille"]) == motif.substr(8)
	if motif.begins_with("un_de:"):
		return id in motif.substr(6).split("|")
	return motif == id


## Les ingrédients ``ids`` remplissent-ils les motifs (un ingrédient par motif) ?
static func _correspond(motifs: Array, ids: Array) -> bool:
	if motifs.is_empty():
		return ids.is_empty()
	for k in ids.size():
		if _accepte(String(motifs[0]), String(ids[k])):
			var reste := ids.duplicate()
			reste.remove_at(k)
			if _correspond(motifs.slice(1), reste):
				return true
	return false


## Première recette (ordre du fichier) faite exactement de ``ids``, ou {}.
static func recette(ids: Array) -> Dictionary:
	for r in donnees()["recettes"]:
		if r["ingredients"].size() == ids.size() and _correspond(r["ingredients"], ids):
			return r
	return {}


## Clé de la première règle immonde qui s'applique, ou « ».
static func immonde(ids: Array, prep: String) -> String:
	var ing: Dictionary = donnees()["ingredients"]
	var a := func(cle: String) -> bool:
		for i in ids:
			if ing[i].get(cle, false):
				return true
		return false
	var fam := func(nom: String) -> int:
		var n := 0
		for i in ids:
			if ing[i]["famille"] == nom:
				n += 1
		return n
	if a.call("perime"):
		return "perime"
	if "lait" in ids and a.call("acide"):
		return "lait_acide"
	var sucre: bool = a.call("sucre")
	if sucre and ("ail" in ids or "champignon" in ids):
		return "sucre_ail_champignon"
	if sucre and "oignon" in ids and fam.call("viande") == 0:
		return "sucre_oignon_sans_viande"
	if sucre and fam.call("legume") + ids.count("oignon") >= 2:
		return "sucre_et_legumes"
	var que_fort := true
	for i in ids:
		if not i in ["ail", "herbes", "citron"]:
			que_fort = false
	if que_fort:
		return "rien_de_nourrissant"
	for i in ["ail", "citron", "herbes"]:
		if ids.count(i) >= 3:
			return "trop_fort"
	if "farine" in ids and not "oeuf" in ids and not "lait" in ids:
		return "farine_crue"
	if prep == "sans_feu" and "viande_crue" in ids:
		return "viande_crue"
	if prep == "sans_feu" and a.call("cru_immangeable"):
		return "cru"
	if prep == "grille" and "lait" in ids and not "oeuf" in ids:
		return "grille_liquide"
	return ""


static func _regle(cle: String) -> Dictionary:
	for r in donnees()["immondes"]:
		if r["cle"] == cle:
			return r
	return {}


## Résultat d'un mélange : {classe (« recette », « mixture », « immonde », « pas un plat »), nom, pv, mana,
## intoxication (chance), raison, recette (dictionnaire ou {})}.
static func evaluer(ids: Array, prep: String) -> Dictionary:
	var ing: Dictionary = donnees()["ingredients"]
	var pv := 0
	var mana := 0
	for i in ids:
		pv += int(ing[i]["pv"])
		mana += int(ing[i]["mana"])
	if ids.size() == 1 and prep == "sans_feu" and ing[ids[0]]["famille"] != "viande":
		return {"classe": "pas un plat", "nom": "", "pv": pv, "mana": mana, "intoxication": 0.0, "raison": "", "recette": {}}
	var r := recette(ids)
	var regle := immonde(ids, prep)
	var intox := 0.0
	if regle != "":
		intox = float(_regle(regle).get("intoxication", 0.0))
		if regle == "perime":
			intox = 0.5
	if not r.is_empty() and r["preparation"] == prep and regle in ["", "perime", "cru", "viande_crue"]:
		var k: float = float(donnees()["preparations"][prep]["multiplicateur"]) \
			+ float(donnees()["bonus_par_ingredient_au_dela_de_2"]) * maxi(0, ids.size() - 2)
		return {"classe": "recette", "nom": r["nom"], "pv": _arrondi(pv * k), "mana": _arrondi(mana * k),
			"intoxication": float(r.get("intoxication", 0.0)), "raison": "", "recette": r}
	if regle != "":
		var q: float = donnees()["immonde"]
		return {"classe": "immonde", "nom": "Plat immonde", "pv": _arrondi(pv * q), "mana": _arrondi(mana * q),
			"intoxication": intox, "raison": String(_regle(regle).get("texte", "")), "recette": {}}
	var m: float = donnees()["mixture"]
	return {"classe": "mixture", "nom": "Mixture", "pv": _arrondi(pv * m), "mana": _arrondi(mana * m), "intoxication": 0.0,
		"raison": "", "recette": r}


## Arrondi comme Python (au pair le plus proche pour les demis), pour que le jeu et la liste disent pareil.
static func _arrondi(x: float) -> int:
	var b := floorf(x)
	var reste := x - b
	if absf(reste - 0.5) < 1e-9:
		return int(b) if int(b) % 2 == 0 else int(b) + 1
	return int(roundf(x))


# ---------------------------------------------------------------------------
# Recettes connues
# ---------------------------------------------------------------------------

static func connues(joueur) -> Array:
	var l = U.ga(joueur, "recettes_connues", null)
	if not (l is Array):
		l = []
		for r in donnees()["recettes"]:
			if r.get("connue", false):
				l.append(String(r["nom"]))
		joueur._d["recettes_connues"] = l
	return l


## Apprend la recette ``nom`` ; vrai si elle était inconnue.
static func apprendre(joueur, nom: String) -> bool:
	var l := connues(joueur)
	if nom in l:
		return false
	l.append(nom)
	return true


static func inconnues(joueur) -> Array:
	var l := []
	for r in donnees()["recettes"]:
		if not String(r["nom"]) in connues(joueur):
			l.append(String(r["nom"]))
	return l


static func recette_nommee(nom: String) -> Dictionary:
	for r in donnees()["recettes"]:
		if r["nom"] == nom:
			return r
	return {}


## Ingrédients lisibles d'une recette (« Viande crue + 1 fruit au choix… »).
static func texte_recette(r: Dictionary) -> String:
	var morceaux := []
	for m in r["ingredients"]:
		var t := String(m)
		if t.begins_with("famille:"):
			morceaux.append({"fruit": "un fruit", "legume": "un légume"}.get(t.substr(8), t.substr(8)))
		elif t.begins_with("un_de:"):
			var noms := []
			for i in t.substr(6).split("|"):
				noms.append(String(donnees()["ingredients"][i]["nom"]).to_lower())
			morceaux.append(" ou ".join(noms) if noms.size() <= 2 else "un légume")
		else:
			morceaux.append(String(donnees()["ingredients"][t]["nom"]))
	return " + ".join(morceaux)


## Page de livre de cuisine lue : apprend une recette inconnue au hasard ; renvoie le message (« » si aucune).
static func lire_page(joueur, page) -> String:
	var l := inconnues(joueur)
	if l.is_empty():
		return "Vous connaissez déjà toutes les recettes de cette page."
	var nom: String = l.pick_random()
	apprendre(joueur, nom)
	if page in joueur.inventaire:
		joueur.inventaire.erase(page)
	return "Nouvelle recette : %s (%s, %s)." % [nom, texte_recette(recette_nommee(nom)), nom_preparation(recette_nommee(nom)["preparation"]).to_lower()]


# ---------------------------------------------------------------------------
# Horloge, feux, eau
# ---------------------------------------------------------------------------

static func horloge(joueur) -> float:
	return float(U.ga(joueur, "horloge", 0.0))


## Fait passer ``secondes`` d'exploration : brandons qui s'éteignent. Renvoie un message (« » si rien).
static func avancer(joueur, secondes: float) -> String:
	joueur._d["horloge"] = horloge(joueur) + secondes
	var message := ""
	for o in joueur.inventaire.duplicate():
		if String(o.nom) == "Brandon allumé" and float(U.ga(o, "eteint_a", 0.0)) <= horloge(joueur):
			joueur.inventaire.erase(o)
			message = "Votre brandon s'est éteint : le bois est consumé."
	return message


## Feu de camp encore allumé dans la salle du plan ``salle`` ({} sinon ; un feu éteint est retiré).
static func feu(joueur, salle: Dictionary) -> Dictionary:
	var f = salle.get("feu_de_camp", {})
	if not (f is Dictionary) or f.is_empty():
		return {}
	var reglage: Dictionary = donnees()["feu_de_camp"]
	if int(f.get("plats", 0)) >= int(reglage["plats"]) or horloge(joueur) - float(f.get("debut", 0.0)) >= float(reglage["duree"]):
		salle.erase("feu_de_camp")
		return {}
	return f


## Secondes avant que le feu de camp s'éteigne.
static func feu_restant(joueur, f: Dictionary) -> float:
	return maxf(0.0, float(donnees()["feu_de_camp"]["duree"]) - (horloge(joueur) - float(f.get("debut", 0.0))))


static func objet(joueur, nom: String):
	for o in joueur.inventaire:
		if String(o.nom) == nom:
			return o
	return null


static func combustible(joueur):
	for nom in COMBUSTIBLES:
		var o = objet(joueur, nom)
		if o != null:
			return o
	return null


## Seau qui contient le plus d'eau (null s'il n'y en a pas).
static func seau(joueur):
	var meilleur = null
	for o in joueur.inventaire:
		if String(o.nom) == "Seau en bois" and (meilleur == null or int(U.num(o, "eau")) > int(U.num(meilleur, "eau"))):
			meilleur = o
	return meilleur


static func eau(joueur) -> int:
	var s = seau(joueur)
	return int(U.num(s, "eau")) if s != null else 0


## Contexte : {torche (vrai si une torche est à portée : allumer du bois), eau (point d'eau à portée : remplir le
## seau), cuisine (foyer de cuisine), salle (salle du plan), pos ([x, y] du héros, pour poser un feu)}.
## Préparations possibles : {prep : « » si possible, sinon la raison}.
static func possibilites(joueur, ctx: Dictionary) -> Dictionary:
	var cuisine := bool(ctx.get("cuisine", false))
	var f := feu(joueur, ctx.get("salle", {}))
	var res := {"sans_feu": ""}
	if cuisine or not f.is_empty():
		res["grille"] = ""
	elif bool(ctx.get("torche", false)):
		res["grille"] = "une torche sert seulement à allumer du bois : faites un feu de camp"
	else:
		res["grille"] = "il faut un feu de camp"
	if not cuisine and f.is_empty():
		res["bouilli"] = "il faut un feu de camp (une torche ne suffit pas)"
	elif not cuisine and objet(joueur, "Marmite") == null:
		res["bouilli"] = "il faut une marmite"
	elif not cuisine and eau(joueur) < int(donnees()["eau_par_preparation"]["bouilli"]):
		res["bouilli"] = "il faut 1 litre d'eau dans un seau"
	else:
		res["bouilli"] = ""
	res["mijote"] = "" if cuisine else "seulement au foyer de la cuisine"
	return res


## Allume un morceau de bois à une torche : il devient un brandon, à poser en feu de camp avant qu'il s'éteigne.
static func allumer_brandon(joueur, ctx: Dictionary) -> String:
	if not bool(ctx.get("torche", false)):
		return "Il faut être près d'une torche."
	var bois = combustible(joueur)
	if bois == null:
		return "Il vous faut un morceau de bois ou une planche."
	joueur.inventaire.erase(bois)
	var b := ObjetsDivers.creer("Brandon allumé", "outil", 0, "Du bois allumé à une torche : posez-le vite en feu de camp.")
	b._d["eteint_a"] = horloge(joueur) + float(donnees()["brandon_duree"])
	joueur.inventaire.append(b)
	return "Vous allumez %s à la torche (il brûlera %s)." % [String(bois.nom).to_lower(), Maux.duree_lisible(float(donnees()["brandon_duree"]))]


## Fait un feu de camp à l'endroit du héros : avec un brandon, sinon avec amadou + silex + bois.
static func faire_feu(joueur, ctx: Dictionary) -> String:
	var salle: Dictionary = ctx.get("salle", {})
	if not feu(joueur, salle).is_empty():
		return "Un feu de camp brûle déjà ici."
	var brandon = objet(joueur, "Brandon allumé")
	var comment := ""
	if brandon != null:
		joueur.inventaire.erase(brandon)
		comment = "avec votre brandon"
	else:
		var bois = combustible(joueur)
		var amadou = objet(joueur, "Amadou")
		if bois == null or amadou == null or objet(joueur, "Silex") == null:
			return "Il faut un brandon (bois allumé à une torche), ou du bois, de l'amadou et un silex."
		joueur.inventaire.erase(bois)
		joueur.inventaire.erase(amadou)
		comment = "avec l'amadou et le silex"
	var pos: Array = ctx.get("pos", [0, 0])
	salle["feu_de_camp"] = {"debut": horloge(joueur), "plats": 0, "x": pos[0], "y": pos[1]}
	var r: Dictionary = donnees()["feu_de_camp"]
	return "Vous allumez un feu de camp %s : %d plats ou %d minutes au plus." % [comment, int(r["plats"]), int(r["duree"]) / 60]


## Remplit le seau à ras bord : dans la cuisine ou près d'un point d'eau (onglet « Eau » de l'éditeur).
static func remplir_seau(joueur, ctx: Dictionary) -> String:
	if not bool(ctx.get("cuisine", false)) and not bool(ctx.get("eau", false)):
		return "Il n'y a pas d'eau ici."
	var s = seau(joueur)
	if s == null:
		return "Vous n'avez pas de seau."
	s._d["eau"] = 10
	return "Seau rempli : 10 litres."


# ---------------------------------------------------------------------------
# Cuisiner, manger
# ---------------------------------------------------------------------------

## Cuisine ``objets`` (objets d'ingrédients de l'inventaire) avec la préparation ``prep``, plus le bouillon
## ``bouillon`` (ou null) qui ajoute sa valeur sans remplacer l'eau. Renvoie [message, plat ou null].
static func cuisiner(joueur, ctx: Dictionary, objets: Array, bouillon, prep: String) -> Array:
	if objets.is_empty() or objets.size() > MAX_INGREDIENTS:
		return ["Choisissez de 1 à %d ingrédients." % MAX_INGREDIENTS, null]
	var raison: String = possibilites(joueur, ctx).get(prep, "?")
	if raison != "":
		return ["%s impossible : %s." % [nom_preparation(prep), raison], null]
	var ids := []
	for o in objets:
		var id := ingredient_de(o)
		if id == "" or not o in joueur.inventaire:
			return ["%s ne se cuisine pas." % o.nom, null]
		ids.append(id)
	var res := evaluer(ids, prep)
	if res["classe"] == "pas un plat":
		return ["Un seul ingrédient sans feu, ce n'est pas un plat : mangez-le tel quel.", null]
	# Dépenses : ingrédients, bouillon, eau (hors cuisine), une place du feu de camp (sans torche ni cuisine)
	for o in objets:
		joueur.inventaire.erase(o)
	var pv: int = res["pv"]
	var mana: int = res["mana"]
	if bouillon != null and bouillon in joueur.inventaire:
		joueur.inventaire.erase(bouillon)
		pv += int(donnees()["bouillon"]["pv"])
		mana += int(donnees()["bouillon"]["mana"])
	var cuisine := bool(ctx.get("cuisine", false))
	if not cuisine and donnees()["eau_par_preparation"].has(prep):
		var s = seau(joueur)
		s._d["eau"] = int(U.num(s, "eau")) - int(donnees()["eau_par_preparation"][prep])
	var f := feu(joueur, ctx.get("salle", {}))
	if not cuisine and not f.is_empty() and prep in ["bouilli", "grille"]:
		f["plats"] = int(f.get("plats", 0)) + 1
	var noms := []
	for o in objets:
		noms.append(String(o.nom).to_lower())
	var plat := ObjetsDivers.creer(String(res["nom"]), "plat", maxi(1, (pv + mana) / 8),
		"%s. Cuisiné avec : %s." % [nom_preparation(prep), ", ".join(noms)])
	plat._d["type_objet"] = "nourriture"
	plat._d["pv"] = pv
	plat._d["mana"] = mana
	if float(res["intoxication"]) > 0:
		plat._d["intoxication"] = float(res["intoxication"])
	joueur.inventaire.append(plat)
	var messages := []
	match res["classe"]:
		"recette":
			messages.append("Vous préparez : %s." % res["nom"])
			if apprendre(joueur, String(res["nom"])):
				messages.append("Nouvelle recette apprise !")
		"mixture":
			messages.append("Ce n'est pas une recette : vous obtenez une mixture.")
			if not res["recette"].is_empty() and String(res["recette"]["nom"]) in connues(joueur):
				messages.append("(%s se fait %s.)" % [res["recette"]["nom"], nom_preparation(res["recette"]["preparation"]).to_lower()])
		"immonde":
			messages.append("Beurk… %s." % res["raison"])
	# Bouillon : l'eau de cuisson d'une recette bouillie avec de la viande
	if res["classe"] == "recette" and prep == "bouilli" and "viande_crue" in ids:
		var b = ObjetsDivers.depuis_catalogue("Bouillon")
		if b != null:
			joueur.inventaire.append(b)
			messages.append("Il vous reste un bouillon.")
	if not f.is_empty() and feu(joueur, ctx.get("salle", {})).is_empty():
		messages.append("Le feu de camp s'éteint.")
	return [" ".join(messages), plat]
