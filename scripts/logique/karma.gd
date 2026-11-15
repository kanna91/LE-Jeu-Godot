class_name Karma
extends RefCounted
## Karma du héros (règles de l'utilisateur, 2026-10-31) : chaque acte de clémence donne +1, chaque acte de cruauté
## −1 (épargner ou tuer des gobelins pacifiques, soigner ou achever le gobelin blessé, libérer le prisonnier).
## Gardé dans le héros (``karma``), pour la partie.
##
## Karma négatif, par point : diablotins +5 % de mensonges, prix des marchands +5 %, **Chevalier de la mort +5 %
## de vitesse de déplacement** (règle de l'utilisateur, 2026-11-03 : dans la salle comme d'une salle à l'autre ;
## ``facteur_vitesse_chevalier``). Avant (2026-10-31), tous les 5 points, un Chevalier de la mort de plus sur chaque
## étage : supprimé, ceux d'une ancienne partie repartent (``synchroniser``).
## Karma positif, par point : diablotins +5 % de vérité, prix −5 %.
## **Butin** (règle de l'utilisateur, 2026-11-15) : les valeurs réglées (éditeur, code) sont celles du karma 0 ; chaque
## point de karma les change de 5 %, dans les deux sens, comme un multiplicateur de dégâts : karma −5 → × 0,75
## (100 pièces → 75), karma +5 → × 1,25 (``facteur_butin``). Il s'applique à l'or gagné (toutes les sources, sauf ce que
## le marchand rachète et l'or confisqué qu'on récupère) et au nombre d'objets du butin (``quantite_butin`` : arrondi au
## hasard, 1 objet × 0,75 = 75 % de chance de l'avoir). Avant : seulement +5 % d'or par point positif.
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
	"butin": {"negatif": -0.05, "positif": 0.05},
	"vitesse_chevalier": {"negatif": 0.05, "positif": 0.0},
}
## Taille d'un palier de karma.
const PALIER := 5
## Ce qui arrivera aux paliers (documentation, pas encore fait : aucun système de quêtes) : négatifs : des quêtes
## spéciales ; positifs : plus de quêtes, aux récompenses plus intéressantes. (Le Chevalier de la mort de plus par
## palier négatif est supprimé depuis le 2026-11-03 : le karma négatif le rend plus rapide.)
const PALIERS := {"negatif": ["quetes_speciales"], "positif": ["quetes", "meilleures_recompenses"]}
## Les prix ne descendent pas sous ce facteur (karma très positif ; choix de Claude, à valider).
const PRIX_MIN := 0.25
## Butin (décisions de l'utilisateur du 2026-11-15, voir KARMA.md : A + B + C + D) :
## A. multiplicateur borné entre × 0,25 et × 1,75 (2026-11-15) ; B. armes et équipements : chance d'un rang de plus ou de moins par point ;
## C. par palier positif : chance d'un objet en plus (coffres et élites). Pas d'objet maudit pour le moment (décision de
##    l'utilisateur, 2026-11-15 : le karma négatif baisse seulement la qualité des objets, B ; voir KARMA.md) ;
## D. clés, objets de quête, recettes, or confisqué : jamais touchés (ils ne passent pas par ces fonctions).
const BUTIN_MIN := 0.25
const BUTIN_MAX := 1.75
const CHANCE_RANG_PAR_POINT := 0.05
const CHANCE_OBJET_PAR_PALIER := 0.10


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


## Change le karma de ``delta`` et règle la vitesse des Chevaliers de la mort ; renvoie le texte à ajouter au
## message (vide s'il ne se passe rien de visible).
static func changer(donjon, delta: int) -> String:
	var joueur = donjon.personnage
	var avant := facteur_vitesse_chevalier(joueur)
	joueur._d["karma"] = valeur(joueur) + delta
	var apres := facteur_vitesse_chevalier(joueur)
	synchroniser(donjon)
	if apres > avant:
		return "Un frisson glacé parcourt le donjon : le Chevalier de la mort presse le pas (+%d %% de vitesse)." % \
			int(round((apres - 1.0) * 100))
	if apres < avant:
		return "Un poids quitte le donjon : le Chevalier de la mort ralentit."
	return ""


## Vitesse de déplacement des Chevaliers de la mort (× sa vitesse normale) : +5 % par point de karma négatif
## (EFFETS « vitesse_chevalier »).
static func facteur_vitesse_chevalier(joueur) -> float:
	return 1.0 + modificateur(joueur, "vitesse_chevalier")


## Sur chaque étage déjà peuplé : la vitesse de chaque Chevalier de la mort suit le karma (« facteur_vitesse » de la
## présence, lu par PresencesSalle et Aventure.duree_salle) ; les chevaliers venus du karma (anciennes parties,
## présences « karma ») repartent.
static func synchroniser(donjon) -> void:
	var facteur := facteur_vitesse_chevalier(donjon.personnage)
	donjon.personnage._d["chevaliers_karma"] = 0
	for etage in donjon.plan_donjon:
		if not Aventure.meta(donjon, int(etage)).get("prepare", false):
			continue
		for i in donjon.plan_donjon[etage]:
			for p in donjon.plan_donjon[etage][i].get("presences", []):
				if p["genre"] != "imbattable" or p.get("etat", "actif") != "actif":
					continue
				if p.get("karma", false):
					p["etat"] = "parti"
				else:
					p["facteur_vitesse"] = facteur


## Chance qu'un diablotin mente sur l'étage : ``base`` + EFFETS « mensonges_diablotins ».
static func chance_mensonge(joueur, base: float) -> float:
	return clampf(base + modificateur(joueur, "mensonges_diablotins"), 0.0, 1.0)


## Facteur des prix de ce que vendent les marchands (EFFETS « prix_marchands »). Ce qu'ils rachètent ne change pas.
static func facteur_prix(joueur) -> float:
	return maxf(PRIX_MIN, 1.0 + modificateur(joueur, "prix_marchands"))


## Multiplicateur du butin (EFFETS « butin ») : 1 au karma 0, ±5 % par point, borné entre BUTIN_MIN et BUTIN_MAX (A).
static func facteur_butin(joueur) -> float:
	return clampf(1.0 + modificateur(joueur, "butin"), BUTIN_MIN, BUTIN_MAX)


## Rang d'une arme ou d'un équipement de butin (B) : ``rang`` (karma 0), avec |karma| × 5 % de chance d'un rang de plus
## (karma positif) ou de moins (négatif), entre 1 et 6.
static func rang_butin(joueur, rang: int) -> int:
	var k := valeur(joueur) if joueur != null else 0
	if k != 0 and randf() < absf(k) * CHANCE_RANG_PAR_POINT:
		rang += 1 if k > 0 else -1
	return clampi(rang, 1, 6)


## Chance d'un objet en plus dans un coffre ou sur une élite (C) : +10 % par palier de karma positif.
static func chance_objet_en_plus(joueur) -> float:
	return maxf(0.0, float(palier(joueur))) * CHANCE_OBJET_PAR_PALIER if joueur != null else 0.0


## Arme ou équipement de butin, karma compris : rang plus ou moins haut (B). ``fabrique`` : Callable(rang) -> objet.
## ``rang`` : celui du karma 0. Renvoie l'objet.
static func objet_butin(joueur, fabrique: Callable, rang: int):
	return fabrique.call(rang_butin(joueur, rang))


## Facteur de l'or gagné : celui du butin. Pas les ventes au marchand.
static func facteur_or(joueur) -> float:
	return facteur_butin(joueur)


## Nombre d'objets réellement reçus pour ``n`` objets de butin réglés au karma 0 : ``n`` × facteur_butin, la partie
## décimale tirée au hasard (1,25 → 1, plus 1 une fois sur 4 ; 0,75 → 1 trois fois sur 4).
static func quantite_butin(joueur, n: int) -> int:
	var v := float(n) * facteur_butin(joueur)
	var entier := floori(v)
	return entier + (1 if randf() < v - entier else 0)


## Or réellement gagné pour ``montant`` (réglé au karma 0 : × facteur_butin), compté dans les statistiques.
static func or_gagne(joueur, montant: int) -> int:
	var gain := int(round(montant * facteur_or(joueur)))
	Statistiques.noter(joueur, "or_gagne", gain)
	return gain


## Texte lisible : « Karma +3 ».
static func texte(joueur) -> String:
	var k := valeur(joueur)
	return "Karma %s%d" % ["+" if k > 0 else "", k]
