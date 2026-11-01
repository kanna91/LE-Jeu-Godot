class_name GenerationObjets
extends RefCounted
## Génération des armes, armures et bijoux (refonte de l'utilisateur, 2026-10-30).
##
## Fini les objets à 50 attributs : chaque objet donne **une seule option**, dont la force dépend de son rang
## (1-2, 3-4, 5-6) :
##
## - **caractéristique** : +1 / +2 / +3 à une caractéristique de son orientation ;
## - **défense** : 2 × rang points répartis entre l'armure, la résistance magique et la résistance élémentaire
##   (2 points bloquent 1 dégât, Degats) ;
## - **dégâts** : +2 / +4 / +6 aux dégâts de son orientation (physiques, magiques ou élémentaires) ;
## - **pénétration** (armes seulement) : 2 / 4 / 6 points d'armure ou de résistance ignorés.
##
## Orientations : physique (tranchant, perforant, contondant), magique (arcane, ombre, chaos), élémentaire
## (feu, froid, foudre). Les résistances spécifiques (« résistance au feu ») ne viennent que de l'armure anti-boss
## de l'étage (generer_anti_boss). Plus de régénération, d'esquive, de toucher, de critique ni de PV sur les objets
## (la dextérité et l'endurance s'en chargent).

const ORIENTATIONS := {"physique": "Physique", "magique": "Magique", "elementaire": "Élémentaire"}
const POIDS_ORIENTATIONS := {"physique": 1, "magique": 1, "elementaire": 1}
const FAMILLES := {"defensif": "Défensif", "offensif": "Offensif", "hybride": "Hybride"}
## Options possibles selon la famille de l'emplacement.
const OPTIONS_PAR_FAMILLE := {
	"defensif": ["caracteristique", "defense"],
	"hybride": ["caracteristique", "defense", "degats"],
	"offensif": ["caracteristique", "degats"],
}
## Options des armes : {option: poids}. Leurs dés font déjà les dégâts physiques. Caractéristique ajoutée le
## 2026-10-30 à la demande de l'utilisateur (poids choisis par Claude).
const OPTIONS_ARMES := {"degats": 2.0, "caracteristique": 2.0, "penetration": 1.0}

## Valeur de chaque option selon le rang (décision de l'utilisateur, 2026-10-30).
const CARACTERISTIQUE_PAR_RANG := {1: 1, 2: 1, 3: 2, 4: 2, 5: 3, 6: 3}
const DEFENSE_PAR_RANG := 2  # points de défense par rang
const DEGATS_PAR_RANG := {1: 2, 2: 2, 3: 4, 4: 4, 5: 6, 6: 6}
const PENETRATION_PAR_RANG := {1: 2, 2: 2, 3: 4, 4: 4, 5: 6, 6: 6}

## Caractéristiques qu'une orientation peut donner.
const CARACTERISTIQUES_PAR_ORIENTATION := {
	"physique": ["force", "dextérité", "endurance"],
	"magique": ["intelligence", Caracteristiques.MANA, "endurance"],
	"elementaire": ["sagesse", Caracteristiques.MANA, "endurance"],
}
## Défenses générales et poids de tirage de l'option « défense ».
const DEFENSES := {"armure": 2.0, "resistance_magique": 1.0, "resistance_elementaire": 1.0}
## Attribut de dégâts et de pénétration de chaque orientation.
const DEGATS_PAR_ORIENTATION := {"physique": "degats_physique", "magique": "degats_magique", "elementaire": "degats_elementaire"}
const PENETRATION_PAR_ORIENTATION := {"physique": "penetration_armure", "magique": "penetration_resistance",
	"elementaire": "penetration_resistance"}
## Types des dés bonus des armes magiques et élémentaires.
const TYPES_PAR_ORIENTATION := {"magique": ["arcane", "ombre", "chaos"], "elementaire": ["feu", "froid", "foudre"]}

## Armure anti-boss (une par étage, dans un coffre) : défense normale + résistance spécifique au type de dégâts
## principal du boss, en points et en pourcentage. Valeurs provisoires de l'utilisateur (2026-10-30).
const ANTI_BOSS_RESISTANCE := 6
const ANTI_BOSS_RESISTANCE_POURCENT := 0.20

# emplacement -> [famille, nom, genre, facteur de valeur, poids de tirage]
const EMPLACEMENTS := {
	"arme": ["offensif", null, null, 1.5, 3.0],
	"casque": ["defensif", "Casque", "m", 1.0, 2.0],
	"plastron": ["defensif", "Plastron", "m", 1.3, 2.0],
	"jambières": ["defensif", "Jambières", "fp", 1.0, 2.0],
	"bottes": ["hybride", "Bottes", "fp", 0.8, 2.0],
	"ceinture": ["hybride", "Ceinture", "f", 0.8, 2.0],
	"gants": ["hybride", "Gants", "mp", 0.8, 2.0],
	"anneau": ["offensif", "Anneau", "m", 0.7, 2.0],
	"amulette": ["offensif", "Amulette", "f", 1.0, 1.0],
}
const ARMURES := ["casque", "plastron", "jambières", "bottes", "ceinture", "gants"]
const BIJOUX := ["anneau", "amulette"]

# type d'arme -> [nom affiché, genre]
const ARMES := {"Epée": ["Épée", "f"], "Lance": ["Lance", "f"], "Marteau": ["Marteau", "m"]}
## Type de l'objet écrit dans son nom (« Épée magique commune », « Bottes élémentaires communes ») pour s'y
## retrouver (demande de l'utilisateur, 2026-10-30) : [singulier, pluriel].
const ADJECTIFS_ORIENTATION := {"physique": ["physique", "physiques"], "magique": ["magique", "magiques"],
	"elementaire": ["élémentaire", "élémentaires"]}

const _OFF := ["offensif", "hybride"]
const _DEF := ["defensif", "hybride"]
# attribut -> [suffixe du nom, valeur au rang 1, gain par rang, orientation, familles]
const UNIQUES := {
	"talent_attaque_saignement": ["de l'hémorragie", 0.03, 0.01, "p", _OFF],
	"talent_attaque_aveuglement": ["de l'aveuglement", 0.02, 0.01, "n", _OFF],
	"talent_chance_poison": ["du venin", 0.03, 0.01, "n", _OFF],
	"talent_attaque_brulure": ["des braises", 0.03, 0.01, "m", _OFF],
	"talent_attaque_stun": ["du tonnerre", 0.02, 0.005, "p", _OFF],
	"talent_attaque_terreur": ["de l'effroi", 0.02, 0.01, "m", _OFF],
	"talent_attaque_vulnerabilite": ["de la brèche", 0.03, 0.01, "n", _OFF],
	"talent_attaque_malediction": ["du maléfice", 0.03, 0.01, "m", _OFF],
	"talent_ajout__physique__feu": ["du brasier", 0.04, 0.02, "p", _OFF],
	"talent_ajout__physique__foudre": ["de l'orage", 0.04, 0.02, "p", _OFF],
	"talent_ajout__physique__brut": ["du bourreau", 0.03, 0.01, "p", _OFF],
	"talent_ajout__magique__froid": ["du givre", 0.04, 0.02, "m", _OFF],
	"talent_ajout__magique__ombre": ["des ténèbres", 0.04, 0.02, "m", _OFF],
	"talent_ajout__magique__foudre": ["de la tempête", 0.04, 0.02, "m", _OFF],
	"talent_vol_de_vie_physique": ["du vampire", 0.02, 0.01, "p", _OFF],
	"talent_frappe_supplementaire": ["de la frénésie", 0.02, 0.01, "n", _OFF],
	"talent_mana_critique_magique": ["de la source", 0.05, 0.02, "m", _OFF],
	"talent_reduction_mana": ["de l'économe", 0.03, 0.01, "m", _OFF],
	"talent_resistance_alterations": ["de la pureté", 0.03, 0.01, "n", _DEF],
	"talent_epines": ["des épines", 0.04, 0.02, "n", _DEF],
	"talent_reduction_degats": ["du rempart", 0.01, 0.005, "n", _DEF],
	"talent_regen_tour": ["du troll", 0.004, 0.002, "n", _DEF],
	"talent_soins_recus": ["de la grâce", 0.04, 0.015, "n", _DEF],
	"talent_efficacite_potions": ["de l'alchimiste", 0.05, 0.02, "n", _DEF],
}
# Dé bonus des armes (rare) : chance et taille selon le rang. Arme physique : dé de son propre type ;
# magique : arcane, ombre ou chaos ; élémentaire : feu, froid ou foudre.
const CHANCES_DE_BONUS := {1: 0.06, 2: 0.07, 3: 0.08, 4: 0.09, 5: 0.10, 6: 0.12}
const FACES_DE_BONUS := {1: 2, 2: 4, 3: 6, 4: 8, 5: 10, 6: 12}
const CHANCES_UNIQUE := {1: 0.04, 2: 0.06, 3: 0.08, 4: 0.10, 5: 0.12, 6: 0.15}
const MULTIPLICATEUR_OR_UNIQUE := 1.5

## Valeur en points d'un objet selon son rang (sert à l'or et à comparer deux anneaux), × facteur de l'emplacement.
const BUDGETS := {1: [24, 36], 2: [40, 56], 3: [60, 80], 4: [84, 112], 5: [116, 152], 6: [160, 208]}

const QUALITES := {1: ["médiocre", "médiocre", "médiocres", "médiocres"], 2: ["commun", "commune", "communs", "communes"],
	3: ["précieux", "précieuse", "précieux", "précieuses"], 4: ["rare", "rare", "rares", "rares"],
	5: ["unique", "unique", "uniques", "uniques"], 6: ["légendaire", "légendaire", "légendaires", "légendaires"]}
const _GENRES := {"m": 0, "f": 1, "mp": 2, "fp": 3}


## Nom suivi de la qualité accordée (« Bottes communes »).
static func nom_objet(nom: String, genre, rang: int) -> String:
	if not QUALITES.has(rang):
		return nom
	return "%s %s" % [nom, QUALITES[rang][_GENRES.get(genre, 0)]]


## Valeur en or : points² / 3, arrondie à 5, au moins 15.
static func valeur_en_or(points: float) -> int:
	return maxi(15, int(round(points * points / 3.0 / 5.0)) * 5)


static func _rang(rang) -> int:
	var temoin := Objet.nouveau("", "")
	Objet.definir_rang(temoin, rang)
	return clampi(int(temoin.rang), 1, 6)


## Effets uniques compatibles avec une famille et une orientation (« p » physique, « m » magique, « n » neutre).
static func effets_uniques_possibles(famille: String, orient: String) -> Array:
	var interdit = {"physique": "m", "magique": "p", "elementaire": "p"}.get(orient)
	var liste := []
	for a in UNIQUES:
		if famille in UNIQUES[a][4] and UNIQUES[a][3] != interdit:
			liste.append(a)
	return liste


## Donne un effet unique à un objet (valeur selon son rang, suffixe du nom, or ×1,5).
static func ajouter_effet_unique(objet, attribut = null):
	if attribut == null:
		var possibles := effets_uniques_possibles(objet.famille, objet.orientation)
		if possibles.is_empty():
			return null
		attribut = possibles.pick_random()
	var u: Array = UNIQUES[attribut]
	objet.set(attribut, U.arrondi(u[1] + u[2] * (objet.rang - 1), 4))
	objet.unique = attribut
	objet.nom = "%s %s" % [objet.nom, u[0]]
	objet.valeur = int(objet.valeur * MULTIPLICATEUR_OR_UNIQUE)
	return attribut


static func _ajouter(objet, attribut: String, valeur) -> void:
	objet.set(attribut, U.ga(objet, attribut, 0) + valeur)


## Applique une option à un objet (CARACTERISTIQUE_PAR_RANG, DEFENSE_PAR_RANG...) ; renvoie l'option.
static func appliquer_option(objet, option: String, orient: String, rang: int) -> String:
	match option:
		"caracteristique":
			_ajouter(objet, CARACTERISTIQUES_PAR_ORIENTATION[orient].pick_random(), CARACTERISTIQUE_PAR_RANG[rang])
		"defense":
			# rang × 2 points, par paires : la première dans la défense principale, les autres moitié-moitié avec
			# une seconde défense (deux défenses au plus)
			var principale = U.choix_pondere(DEFENSES.keys(), DEFENSES.values())
			var seconde = U.choix_pondere(DEFENSES.keys(), DEFENSES.values())
			for k in rang:
				_ajouter(objet, principale if (k == 0 or randf() < 0.5) else seconde, DEFENSE_PAR_RANG)
		"degats":
			_ajouter(objet, DEGATS_PAR_ORIENTATION[orient], DEGATS_PAR_RANG[rang])
		"penetration":
			_ajouter(objet, PENETRATION_PAR_ORIENTATION[orient], PENETRATION_PAR_RANG[rang])
	objet.option = option
	return option


## Nom suivi du type puis de la qualité (« Gants physiques médiocres »).
static func nom_avec_type(nom: String, genre, orient: String, rang: int) -> String:
	var adj: Array = ADJECTIFS_ORIENTATION.get(orient, ["", ""])
	var avec := ("%s %s" % [nom, adj[1 if genre in ["mp", "fp"] else 0]]).strip_edges()
	return nom_objet(avec, genre, rang)


static func _finir(objet, nom: String, genre, rang: int, facteur: float) -> void:
	var bornes: Array = BUDGETS[rang]
	objet.points = U.arrondi((bornes[0] + bornes[1]) / 2.0 * facteur, 1)
	objet.nom = nom_avec_type(nom, genre, String(U.ga(objet, "orientation", "")), rang)
	objet.valeur = valeur_en_or(objet.points)
	objet.unique = null


## Génère une arme, une armure ou un bijou. ``orient`` : « physique », « magique » ou « elementaire » (au hasard sinon).
static func generer_objet(emplacement = null, rang = null, type_arme = null, orient = null, chance_unique = null):
	if emplacement == null:
		var cles := EMPLACEMENTS.keys()
		var poids := []
		for c in cles:
			poids.append(EMPLACEMENTS[c][4])
		emplacement = U.choix_pondere(cles, poids)
	if orient == null or not ORIENTATIONS.has(orient):
		orient = U.choix_pondere(POIDS_ORIENTATIONS.keys(), POIDS_ORIENTATIONS.values())
	var e: Array = EMPLACEMENTS[emplacement]
	var famille: String = e[0]
	var nom = e[1]
	var genre = e[2]
	var rang_final := _rang(rang)
	var objet
	var option: String
	if emplacement == "arme":
		if type_arme == null or not ARMES.has(type_arme):
			type_arme = ARMES.keys().pick_random()
		nom = ARMES[type_arme][0]
		genre = ARMES[type_arme][1]
		objet = Arme.nouvelle(nom, "arme", type_arme)
		option = U.choix_pondere(OPTIONS_ARMES.keys(), OPTIONS_ARMES.values())
	else:
		objet = Armure.nouvelle(nom, "armure", emplacement)
		option = OPTIONS_PAR_FAMILLE[famille].pick_random()
	objet.rang = rang_final
	objet.famille = famille
	objet.orientation = orient
	for c in Caracteristiques.LISTE:
		objet.set(c, 0)
	appliquer_option(objet, option, orient, rang_final)
	if emplacement == "arme" and randf() < CHANCES_DE_BONUS[rang_final]:
		ajouter_de_bonus(objet, rang_final)
	_finir(objet, nom, genre, rang_final, e[3])
	if randf() < (CHANCES_UNIQUE[rang_final] if chance_unique == null else chance_unique):
		ajouter_effet_unique(objet)
	return objet


## Donne à une arme son dé bonus (taille selon le rang ; type selon son orientation).
static func ajouter_de_bonus(arme, rang: int) -> void:
	var orient = U.ga(arme, "orientation", "physique")
	var type: String = Formules.DES_ARMES.get(U.ga(arme, "type_arme", ""), "tranchant")
	if TYPES_PAR_ORIENTATION.has(orient):
		type = TYPES_PAR_ORIENTATION[orient].pick_random()
	arme.set("de_bonus", {"faces": FACES_DE_BONUS[rang], "type": type})


## Arme de départ du héros : physique, rang 1, sans aucun bonus (décision de l'utilisateur, 2026-10-30).
static func generer_arme_nue(type_arme = null):
	if type_arme == null or not ARMES.has(type_arme):
		type_arme = ARMES.keys().pick_random()
	var objet := Arme.nouvelle(ARMES[type_arme][0], "arme", type_arme)
	objet.rang = 1
	objet.famille = "offensif"
	objet.orientation = "physique"
	for c in Caracteristiques.LISTE:
		objet.set(c, 0)
	objet.option = "aucune"
	_finir(objet, ARMES[type_arme][0], ARMES[type_arme][1], 1, EMPLACEMENTS["arme"][3])
	return objet


static func generer_armure(rang = null, orient = null):
	return generer_objet(ARMURES.pick_random(), rang, null, orient)


## Un anneau (deux chances sur trois) ou une amulette.
static func generer_bijou(rang = null, orient = null):
	return generer_objet(U.choix_pondere(BIJOUX, [2, 1]), rang, null, orient)


## Armure anti-boss : une pièce d'armure à option « défense », plus ANTI_BOSS_RESISTANCE points et
## ANTI_BOSS_RESISTANCE_POURCENT de résistance au type de dégâts ``type_degats`` (celui du boss de l'étage).
## Nom : « Plastron élémentaire commun anti-foudre ».
static func generer_anti_boss(type_degats: String, rang = null):
	var emplacement: String = ARMURES.pick_random()
	var e: Array = EMPLACEMENTS[emplacement]
	var rang_final := _rang(rang)
	var objet := Armure.nouvelle(e[1], "armure", emplacement)
	objet.rang = rang_final
	objet.famille = e[0]
	var g := Degats.groupe(type_degats)
	objet.orientation = g if ORIENTATIONS.has(g) else "physique"
	for c in Caracteristiques.LISTE:
		objet.set(c, 0)
	appliquer_option(objet, "defense", objet.orientation, rang_final)
	_ajouter(objet, "resistance_" + type_degats, ANTI_BOSS_RESISTANCE)
	_ajouter(objet, "resistance_pct_" + type_degats, ANTI_BOSS_RESISTANCE_POURCENT)
	objet.anti_boss = type_degats
	_finir(objet, e[1], e[2], rang_final, e[3] * 1.5)
	objet.nom = "%s anti-%s" % [objet.nom, type_degats]
	return objet
