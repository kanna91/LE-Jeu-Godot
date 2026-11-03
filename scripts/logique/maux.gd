class_name Maux
extends RefCounted
## Maux persistants (règle de l'utilisateur, 2026-11-03) : une seule mécanique pour l'intoxication alimentaire et,
## plus tard, la maladie. Un mal fait perdre des PV par « tics » réguliers pendant une durée, et peut couper la
## régénération des PV. Il **peut tuer**. Le temps compte en exploration et en combat, pas dans les menus
## (``avancer`` est appelé par l'écran de navigation et par l'écran de combat).
## Un mal du même type déjà en cours **reçoit la durée** du nouveau (elle s'ajoute).
## Maux du héros : ``joueur.maux`` = [{type, restant (s), tic (s écoulées depuis le dernier tic)}, ...].
## Remède : ``guerir`` (aucun objet ne guérit encore : potion anti-maladie, herbes, établi d'alchimie à venir).

## Types de maux : pv_par_minute, duree (s), tic (s), coupe_regen.
const TYPES := {
	"intoxication": {"nom": "Intoxication alimentaire", "pv_par_minute": 4.0, "duree": 480.0, "tic": 15.0, "coupe_regen": true,
		"debut": "Votre ventre se tord : intoxication alimentaire !"},
}


static func liste(joueur) -> Array:
	var l = U.ga(joueur, "maux", null)
	if not (l is Array):
		l = []
		joueur._d["maux"] = l
	return l


## Inflige le mal ``type`` (sa durée s'ajoute à un mal du même type en cours) ; renvoie le message.
static func infliger(joueur, type: String) -> String:
	var t: Dictionary = TYPES[type]
	for m in liste(joueur):
		if m["type"] == type:
			m["restant"] = float(m["restant"]) + float(t["duree"])
			return "%s : ça empire (encore %s)." % [t["nom"], duree_lisible(m["restant"])]
	liste(joueur).append({"type": type, "restant": float(t["duree"]), "tic": 0.0})
	return String(t["debut"])


static func a(joueur, type: String) -> bool:
	for m in liste(joueur):
		if m["type"] == type:
			return true
	return false


## Guérit le mal ``type`` (vrai s'il y en avait un).
static func guerir(joueur, type: String) -> bool:
	var l := liste(joueur)
	for m in l.duplicate():
		if m["type"] == type:
			l.erase(m)
			return true
	return false


## Vrai si un mal en cours coupe la régénération des PV.
static func coupe_regen(joueur) -> bool:
	for m in liste(joueur):
		if bool(TYPES.get(m["type"], {}).get("coupe_regen", false)):
			return true
	return false


## Fait passer ``secondes`` : tics de perte de PV, fin des maux écoulés. Le héros peut en mourir
## (``Statistiques.lever_mort`` avec la cause du mal). Renvoie les PV perdus.
static func avancer(joueur, secondes: float) -> int:
	var l := liste(joueur)
	if l.is_empty() or secondes <= 0:
		return 0
	var perdus := 0
	for m in l.duplicate():
		var t: Dictionary = TYPES.get(m["type"], {})
		if t.is_empty():
			l.erase(m)
			continue
		var dt := minf(secondes, float(m["restant"]))
		m["tic"] = float(m["tic"]) + dt
		m["restant"] = float(m["restant"]) - dt
		var tic := float(t["tic"])
		while float(m["tic"]) >= tic - 1e-6:
			m["tic"] = float(m["tic"]) - tic
			var perte := int(round(float(t["pv_par_minute"]) * tic / 60.0))
			joueur.points_de_vie = joueur.points_de_vie - perte
			perdus += perte
		if float(m["restant"]) <= 1e-6:
			l.erase(m)
		if joueur.points_de_vie <= 0:
			joueur.points_de_vie = 0
			Statistiques.lever_mort(String(m["type"]))
			break
	return perdus


static func duree_lisible(secondes: float) -> String:
	var s := int(ceil(secondes))
	return "%d:%02d" % [s / 60, s % 60]


## Texte court des maux en cours (« Intoxication alimentaire 5:12 »), vide s'il n'y en a pas.
static func resume(joueur) -> String:
	var morceaux := []
	for m in liste(joueur):
		morceaux.append("%s %s" % [TYPES.get(m["type"], {}).get("nom", m["type"]), duree_lisible(float(m["restant"]))])
	return " · ".join(morceaux)
