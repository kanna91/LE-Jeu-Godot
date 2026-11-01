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
## Karma positif, par point : diablotins +5 % de vérité, prix −5 %, or gagné +5 % (toutes les sources, sauf ce que le
## marchand rachète : il vend moins cher mais rachète toujours au même prix).
## Pas encore fait (aucun système de quêtes) : les habitants qui donnent plus ou moins de quêtes ; ils sont déjà plus
## froids ou plus chaleureux (accueil des diablotins).

## Tout est réglé par les tables ci-dessous, faites pour être nuancées sans toucher au reste du code
## (demande de l'utilisateur : « ne fige pas trop tout ça ») :
## - ACTES : ce que vaut chaque acte (un acte plus ou moins grave, de nouveaux actes...) ;
## - EFFETS : effet de chaque point de karma, séparément pour le karma négatif et le karma positif ;
## - PALIER, PALIERS : ce qui arrive à chaque palier (aujourd'hui les Chevaliers de la mort ; demain les quêtes
##   spéciales du karma négatif, les meilleures récompenses du karma positif) : ``palier`` et ``paliers_franchis``
##   servent de point d'entrée aux futurs systèmes.

## Valeur de chaque acte : {nom : [points de karma, « clemence » ou « cruaute »]}.
const ACTES := {
	"epargner_pacifiques": [1, "clemence"],
	"tuer_pacifiques": [-1, "cruaute"],
	"soigner_gobelin_blesse": [1, "clemence"],
	"epargner_gobelin_blesse": [1, "clemence"],
	"achever_gobelin_blesse": [-1, "cruaute"],
	"liberer_prisonnier": [1, "clemence"],
	"tuer_prisonnier_cellule": [-1, "cruaute"],
}
## Effet par point de karma : {effet : {"negatif": par point négatif, "positif": par point positif}}, en part
## (0.05 = 5 %), signe compris : + augmente, − diminue.
const EFFETS := {
	"mensonges_diablotins": {"negatif": 0.05, "positif": -0.05},
	"prix_marchands": {"negatif": 0.05, "positif": -0.05},
	"or_gagne": {"negatif": 0.0, "positif": 0.05},
}
## Taille d'un palier de karma.
const PALIER := 5
## Ce qui arrive aux paliers (documentation ; le code des chevaliers lit ``chevaliers``) :
## négatifs : un Chevalier de la mort de plus par palier (et, plus tard, des quêtes spéciales) ; positifs : plus de
## quêtes, aux récompenses plus intéressantes (pas encore fait : aucun système de quêtes).
const PALIERS := {"negatif": ["chevalier_de_la_mort", "quetes_speciales"], "positif": ["quetes", "meilleures_recompenses"]}
## Les prix ne descendent pas sous ce facteur (karma très positif ; choix de Claude, à valider).
const PRIX_MIN := 0.25


static func valeur(joueur) -> int:
	return int(U.num(joueur, "karma"))


## Le héros fait l'acte ``nom`` (ACTES) : le karma change d'autant (× ``nombre``, ex. plusieurs gobelins), la
## moralité de la partie le compte. Renvoie le texte à ajouter au message (vide s'il ne se passe rien de visible).
static func acte(donjon, nom: String, nombre := 1) -> String:
	var a: Array = ACTES.get(nom, [0, ""])
	if a[1] != "":
		var m = U.ga(donjon, "moralite", null)
		if not (m is Dictionary):
			m = {"clemence": 0, "cruaute": 0}
			donjon._d["moralite"] = m
		m[a[1]] = int(m.get(a[1], 0)) + 1
	return changer(donjon, int(a[0]) * nombre) if int(a[0]) != 0 else ""


## Palier de karma actuel, signé (−11 → −2 ; +7 → +1) : point d'entrée des futurs effets (quêtes...).
static func palier(joueur) -> int:
	var k := valeur(joueur)
	return -((-k) / PALIER) if k < 0 else k / PALIER


## Effet d'un point de karma pour ``effet`` (EFFETS) : la part totale à ajouter (0.15 = +15 %).
static func modificateur(joueur, effet: String) -> float:
	if joueur == null:
		return 0.0
	var k := valeur(joueur)
	var e: Dictionary = EFFETS.get(effet, {})
	return (-k) * float(e.get("negatif", 0.0)) if k < 0 else k * float(e.get("positif", 0.0))


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


## Chance qu'un diablotin mente sur l'étage : ``base`` + EFFETS « mensonges_diablotins ».
static func chance_mensonge(joueur, base: float) -> float:
	return clampf(base + modificateur(joueur, "mensonges_diablotins"), 0.0, 1.0)


## Facteur des prix de ce que vendent les marchands (EFFETS « prix_marchands »). Ce qu'ils rachètent ne change pas.
static func facteur_prix(joueur) -> float:
	return maxf(PRIX_MIN, 1.0 + modificateur(joueur, "prix_marchands"))


## Facteur de l'or gagné (EFFETS « or_gagne » : +5 % par point positif). Pas les ventes au marchand.
static func facteur_or(joueur) -> float:
	return maxf(0.0, 1.0 + modificateur(joueur, "or_gagne"))


## Or réellement gagné pour ``montant`` (karma positif : +5 % par point), compté dans les statistiques.
static func or_gagne(joueur, montant: int) -> int:
	var gain := int(round(montant * facteur_or(joueur)))
	Statistiques.noter(joueur, "or_gagne", gain)
	return gain


## Texte lisible : « Karma +3 ».
static func texte(joueur) -> String:
	var k := valeur(joueur)
	return "Karma %s%d" % ["+" if k > 0 else "", k]
