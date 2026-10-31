class_name Karma
extends RefCounted
## Karma du héros (règles de l'utilisateur, 2026-10-31) : chaque acte de clémence donne +1, chaque acte de cruauté
## −1 (épargner ou tuer des gobelins pacifiques, soigner ou achever le gobelin blessé, libérer le prisonnier).
## Gardé dans le héros (``karma``), pour la partie.
##
## Karma négatif, par point : diablotins +5 % de mensonges, prix des marchands +5 %. Tous les 5 points
## (palier), un **Chevalier de la mort de plus** sur chaque étage ; il ne repart qu'en remontant de 5 points depuis
## le palier qui l'a fait venir (créé à −10, il repart à −5 ; créé à −5, il repart à 0) : ``chevaliers_karma``.
## Il reste toujours au moins le chevalier de base de chaque étage.
## Karma positif, par point : diablotins +5 % de vérité, prix −5 %, or gagné +5 % (toutes les sources).
## Pas encore fait (aucun système de quêtes) : les habitants qui donnent plus ou moins de quêtes ; ils sont déjà plus
## froids ou plus chaleureux (accueil des diablotins).

const PALIER := 5
const PAR_POINT := 0.05
## Les prix ne descendent pas sous ce facteur (karma très positif ; choix de Claude, à valider).
const PRIX_MIN := 0.25


static func valeur(joueur) -> int:
	return int(U.num(joueur, "karma"))


## Change le karma de ``delta`` et fait venir ou repartir les Chevaliers de la mort du karma ; renvoie le texte à
## ajouter au message (vide s'il ne se passe rien de visible).
static func changer(donjon, delta: int) -> String:
	var joueur = donjon.personnage
	var avant := chevaliers(joueur)
	joueur._d["karma"] = valeur(joueur) + delta
	_mettre_a_jour_paliers(joueur)
	var apres := chevaliers(joueur)
	synchroniser(donjon)
	if apres > avant:
		return "Un frisson glacé parcourt le donjon : un Chevalier de la mort de plus erre dans les étages."
	if apres < avant:
		return "Un poids quitte le donjon : un Chevalier de la mort s'est retiré."
	return ""


## Chevaliers de la mort ajoutés par le karma (par étage).
static func chevaliers(joueur) -> int:
	return int(U.num(joueur, "chevaliers_karma"))


## Paliers : un chevalier de plus à chaque palier franchi vers le bas (−5, −10...), un de moins en remontant à
## 5 points au-dessus du palier qui l'a fait venir.
static func _mettre_a_jour_paliers(joueur) -> void:
	var k := valeur(joueur)
	var n := chevaliers(joueur)
	while k <= -PALIER * (n + 1):
		n += 1
	while n > 0 and k >= -PALIER * (n - 1):
		n -= 1
	joueur._d["chevaliers_karma"] = n


## Sur chaque étage déjà peuplé : autant de chevaliers du karma (présences « karma ») que ``chevaliers``.
static func synchroniser(donjon) -> void:
	var voulu := chevaliers(donjon.personnage)
	for etage in donjon.plan_donjon:
		if not Aventure.meta(donjon, int(etage)).get("prepare", false):
			continue
		var presents := []
		for i in donjon.plan_donjon[etage]:
			for p in donjon.plan_donjon[etage][i].get("presences", []):
				if p.get("karma", false) and p["genre"] == "imbattable" and p.get("etat", "actif") == "actif":
					presents.append(p)
		while presents.size() < voulu:
			var p := Aventure.ajouter_menace(donjon, int(etage), "imbattable")
			if p.is_empty():
				break
			p["karma"] = true
			presents.append(p)
		while presents.size() > voulu:
			presents.pop_back()["etat"] = "parti"


## Chance qu'un diablotin mente sur l'étage : ``base`` ± 5 % par point de karma (négatif : plus de mensonges).
static func chance_mensonge(joueur, base: float) -> float:
	return clampf(base - PAR_POINT * valeur(joueur), 0.0, 1.0)


## Facteur des prix des marchands : +5 % par point de karma négatif, −5 % par point positif.
static func facteur_prix(joueur) -> float:
	if joueur == null:
		return 1.0
	return maxf(PRIX_MIN, 1.0 - PAR_POINT * valeur(joueur))


## Facteur de l'or gagné : +5 % par point de karma positif (le karma négatif ne le réduit pas).
static func facteur_or(joueur) -> float:
	if joueur == null:
		return 1.0
	return 1.0 + PAR_POINT * maxi(0, valeur(joueur))


## Or réellement gagné pour ``montant`` (karma positif : +5 % par point), compté dans les statistiques.
static func or_gagne(joueur, montant: int) -> int:
	var gain := int(round(montant * facteur_or(joueur)))
	Statistiques.noter(joueur, "or_gagne", gain)
	return gain


## Texte lisible : « Karma +3 ».
static func texte(joueur) -> String:
	var k := valeur(joueur)
	return "Karma %s%d" % ["+" if k > 0 else "", k]
