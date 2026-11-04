class_name Alterations
extends RefCounted
## Altérations d'état : malus et bonus temporaires.
##
## Chaque altération est décrite une seule fois dans DEFINITIONS (voir defs()) :
## libellé, nature, durée, cumul maximal, puissance et effets déclaratifs
## (modifs, dot, soin_tour, mana_tour, perte_tour, perte_pa, gain_pa, sortant,
## entrant, soins_recus, bouclier, epines, vol_de_vie, marque, silence, reveil,
## fin, draine, contagion, caracteristiques).
##
## Les altérations sont stockées sur le combattant, dans ``cible.alteration`` :
## {nom: {"duree", "lanceur", "cumul", "puissance", "modifs", "tours", "intensite", ...}}.

const PHYSIQUES := ["tranchant", "perforant", "contondant"]
const ELEMENTAIRES := ["feu", "froid", "foudre", "arcane", "chaos", "ombre"]
const CONTROLES := ["stun", "gel", "pétrification", "terreur", "sommeil", "paralysie"]

const CARACTERISTIQUES := ["force", "dextérité", "endurance", "intelligence", "sagesse"]
const NOMS_CARACTERISTIQUES := {"force": "force", "dextérité": "dextérité", "endurance": "endurance",
	"intelligence": "intelligence", "sagesse": "sagesse"}

const ALIAS := {
	"destruction_résistance": "destruction résistance", "recupe": "régénération", "recupeé": "régénération",
	"aveuglement": "aveugler", "étourdissement": "stun", "brûlure": "brulure", "vulnerabilite": "vulnérabilité",
	"trauma interne": "trauma", "brulure de mana": "brûlure de mana",
}

const TYPES_ALTERATIONS := {
	"feu": ["brulure", "inflammabilité"],
	"froid": ["gel", "engelure", "morsure du givre", "lenteur", "engourdissement", "pétrification"],
	"foudre": ["électrocution", "paralysie", "conductivité"],
	"arcane": ["usure magique", "silence", "brûlure de mana", "esprit embrumé", "destruction résistance", "torpeur",
		"trouble", "dissonance"],
	"chaos": ["corruption", "peste", "vulnérabilité"],
	"ombre": ["terreur", "malédiction", "siphon de vie", "condamnation", "flétrissement", "faiblesse", "maladresse",
		"débilité", "affaiblissement", "décrépitude", "aveugler", "sape", "épuisement vital", "entropie", "épuisement"],
	"poison": ["poison"],
	"tranchant": ["saignement", "désarmement", "usure"],
	"perforant": ["destruction armure", "marque"],
	"contondant": ["stun", "trauma", "déchéance", "sommeil"],
	"lumière": ["régénération", "bouclier", "barrière", "bénédiction", "clarté", "protection", "sérénité",
		"illumination", "transcendance", "robustesse"],
}

## Effets d'un point de caractéristique quand une altération change une caractéristique (null : calculé d'après le
## combattant). Les mêmes que Caracteristiques.PAR_POINT (2026-10-29) ; les dégâts suivent d'eux-mêmes (Formules lit
## la caractéristique). Endurance et Mana : par tranche de 2 points (Caracteristiques.PAR_PALIER, 2026-11-03) ; le
## gain est celui des tranches gagnées ou perdues.
const CONVERSIONS := {
	"force": {},
	"dextérité": {"chance_de_toucher": Caracteristiques.TOUCHER_PAR_DEXTERITE,
		"chance_de_coup_critique": Caracteristiques.CRITIQUE_PAR_DEXTERITE, "chance_esquive": Caracteristiques.ESQUIVE_PAR_DEXTERITE},
	"endurance": {"points_de_vie_max": null, "regen_de_points_de_vie": Caracteristiques.REGEN_PV_PAR_ENDURANCE},
	"intelligence": {"chance_de_coup_critique_magique": Caracteristiques.CRITIQUE_MAGIQUE_PAR_INTELLIGENCE},
	"sagesse": {"chance_de_coup_critique_elementaire": Caracteristiques.CRITIQUE_ELEMENTAIRE_PAR_SAGESSE},
	Caracteristiques.MANA: {"mana_max": Caracteristiques.MANA_PAR_POINT, "regen_de_mana": Caracteristiques.REGEN_MANA_PAR_POINT},
}

static var _definitions := {}
static var _type_alteration := {}


# ---------------------------------------------------------------------------
# Montants des effets de tour
# ---------------------------------------------------------------------------

static func _stat(combattant, nom: String, defaut = 0):
	return U.ga(combattant, nom, defaut) if combattant != null else defaut


## Brûlure : 1d2 dégâts de feu par tour et par cumul (réduits par la résistance élémentaire).
static func _dot_brulure(_porteur, data: Dictionary, _index) -> Array:
	return ["feu", Formules.jet([[int(data.get("cumul", 1)), 2]])]


static func _dot_poison(porteur, data: Dictionary, _index) -> Array:
	return ["poison", 1 + porteur.points_de_vie_max * 0.04 * data.get("cumul", 1) + data.get("puissance", 0)]


static func _dot_saignement(porteur, data: Dictionary, _index) -> Array:
	var lanceur = data.get("lanceur")
	var bonus_pct := 0.0
	if lanceur != null and U.ha(lanceur, "arbre_de_talents"):
		for t in U.ga(lanceur.arbre_de_talents, "talents", []):
			bonus_pct += U.ga(t, "bonus_degats_saignement", 0.0)
	return ["saignement", (1 + porteur.points_de_vie * 0.25 + data.get("puissance", 0)) * (1.0 + bonus_pct)]


static func _dot_electrocution(porteur, data: Dictionary, _index) -> Array:
	return ["foudre", 1 + porteur.points_de_vie_max * 0.03 + data.get("puissance", 0) + _stat(data.get("lanceur"), "puissance_magique")]


static func _dot_corruption(porteur, data: Dictionary, index) -> Array:
	return ["chaos", (2 + porteur.points_de_vie_max * 0.03 + data.get("puissance", 0)) * index]


static func _soin_regeneration(porteur, data: Dictionary, _index) -> float:
	return porteur.points_de_vie_max * 0.06 + data.get("puissance", 0)


static func _mana_clarte(porteur, _data, _index) -> int:
	return maxi(1, int(porteur.mana_max * 0.10))


static func _mana_epuisement(porteur, _data, _index) -> int:
	return -maxi(1, int(porteur.mana_max * 0.10))


static func _dot_engelure(porteur, data: Dictionary, _index) -> Array:
	var lanceur = data.get("lanceur")
	var base = 1 + porteur.points_de_vie_max * 0.025 + data.get("puissance", 0)
	base += _stat(lanceur, "puissance_magique") + _stat(lanceur, "degats_froid")
	base *= _stat(lanceur, "pourcentage_degats_elementaire", 1) * _stat(lanceur, "pourcentage_degats_froid", 1)
	return ["froid", base * (1 + 0.5 * (data.get("cumul", 1) - 1))]


static func _dot_peste(porteur, data: Dictionary, _index) -> Array:
	return ["chaos", 1 + porteur.points_de_vie_max * 0.03 + data.get("puissance", 0) + 0.5 * _stat(data.get("lanceur"), "puissance_magique")]


static func _dot_trauma(porteur, data: Dictionary, _index) -> Array:
	var lanceur = data.get("lanceur")
	var base = 1 + porteur.points_de_vie_max * 0.02 + data.get("puissance", 0)
	base += _stat(lanceur, "degats_base") + 3 * _stat(lanceur, "force")
	return ["contondant", base * _stat(lanceur, "pourcentage_degats_physique", 1) * _stat(lanceur, "pourcentage_degats_contondant", 1)]


static func _dot_siphon(porteur, data: Dictionary, _index) -> Array:
	var lanceur = data.get("lanceur")
	var base = 1 + porteur.points_de_vie_max * 0.02 + data.get("puissance", 0) + _stat(lanceur, "puissance_magique")
	return ["ombre", base * _stat(lanceur, "pourcentage_degats_magique", 1) * _stat(lanceur, "pourcentage_degats_ombre", 1)]


static func _mana_brule(porteur) -> int:
	return maxi(0, mini(int(porteur.mana), maxi(1, int(porteur.mana_max * 0.12))))


static func _dot_brulure_mana(porteur, data: Dictionary, _index) -> Array:
	return ["arcane", 1 + 2 * _mana_brule(porteur) + data.get("puissance", 0)]


static func _mana_brulure_mana(porteur, _data, _index) -> int:
	return -_mana_brule(porteur)


static func _fin_condamnation(porteur, data: Dictionary) -> Array:
	return ["ombre", porteur.points_de_vie_max * 0.30 + data.get("puissance", 0) + _stat(data.get("lanceur"), "puissance_magique")]


static func _conversion(combattant, statistique: String, coefficient) -> float:
	if coefficient != null:
		return float(coefficient)
	if statistique == "armure":
		return _stat(combattant, "mult_bonus_armure_par_force", 1) / 3.0
	if statistique == "resistance_magique":
		return _stat(combattant, "mult_bonus_resmag_par_intel", 1) / 3.0
	return _stat(combattant, "bonus_pv_par_endurance", Ennemis.PV_PAR_ENDURANCE) * _stat(combattant, "multiplicateur_pv_max", 1)


static func _caracteristiques(cible, attributs: Array, part: float, fixe: float, cumul, signe: int) -> Dictionary:
	var modifs := {}
	for attribut in attributs:
		var base := maxf(0.0, U.num(cible, attribut))
		var delta: float = signe * (base * part + fixe) * cumul
		if signe < 0:
			delta = maxf(delta, -base)
		modifs[attribut] = modifs.get(attribut, 0) + delta
		var conversions: Dictionary = CONVERSIONS[attribut]
		var quantite: float = delta
		if Caracteristiques.PAR_PALIER.has(attribut):
			quantite = Caracteristiques.paliers(base + delta) - Caracteristiques.paliers(base)
		for statistique in conversions:
			modifs[statistique] = modifs.get(statistique, 0) + quantite * _conversion(cible, statistique, conversions[statistique])
	return modifs


static func _alteration_caracteristiques(libelle_alt: String, nature: String, attributs: Array, part: float, fixe: float,
		cumul_max := 5, duree := 4) -> Dictionary:
	var signe := -1 if nature == "malus" else 1
	var noms: String
	if attributs.size() < 5:
		var liste := []
		for a in attributs:
			liste.append(NOMS_CARACTERISTIQUES[a])
		noms = ", ".join(liste)
	else:
		noms = "toutes les caractéristiques"
	var sens := "-" if signe < 0 else "+"
	var texte := "%s %s%s %% %s%s par cumul, avec leurs effets (cumulable %d fois)." % [
		U.majuscule(noms), sens, U.g(part * 100), sens, U.g(fixe), cumul_max]
	return {"libelle": libelle_alt, "nature": nature, "duree": duree, "cumul_max": cumul_max, "description": texte,
		"caracteristiques": attributs,
		"modifs": func(c, _p, n, i): return _caracteristiques(c, attributs, part * i, fixe * i, n, signe)}


static func _part_positive(cible, attributs: Array, part: float) -> Dictionary:
	var modifs := {}
	for a in attributs:
		modifs[a] = -maxf(0, U.num(cible, a)) * part
	return modifs


## Vulnérabilités en pourcentage (0,10 = +10 % de dégâts subis de ces types, Degats.multiplicateur).
static func _vulnerabilites(types: Array, valeur: float) -> Dictionary:
	var modifs := {}
	for t in types:
		modifs["vulnerabilite_" + t] = valeur
	return modifs


## Table DEFINITIONS (construite une fois).
static func defs() -> Dictionary:
	if not _definitions.is_empty():
		return _definitions
	var res_phys := []
	var res_elem := []
	for t in PHYSIQUES:
		res_phys.append("resistance_" + t)
	for t in ELEMENTAIRES:
		res_elem.append("resistance_" + t)
	var d := {
		# ---------------------------- Malus ----------------------------
		"stun": {"libelle": "Étourdissement", "nature": "malus", "duree": 1,
			"description": "Perd son prochain tour.", "perte_tour": 1.0},
		"pétrification": {"libelle": "Pétrification", "nature": "malus", "duree": 2,
			"description": "Changé en pierre : perd ses tours, mais dégâts physiques reçus -20 %.",
			"perte_tour": 1.0, "modifs": func(_c, _p, _n): return {"resistance_pct_physique": 0.20}},
		"gel": {"libelle": "Gel", "nature": "malus", "duree": 2,
			"description": "Perd 1 PA par tour et 10 % d'esquive.", "perte_pa": 1.0,
			"modifs": func(_c, _p, _n): return {"chance_esquive": -0.10}},
		"brulure": {"libelle": "Brûlure", "nature": "malus", "duree": 3, "cumul_max": 3,
			"description": "Dégâts de feu à chaque tour : 1d2 par cumul (cumulable 3 fois).",
			"dot": _dot_brulure},
		"poison": {"libelle": "Poison", "nature": "malus", "duree": 4, "cumul_max": 3,
			"description": "Perd 4 % de ses PV max par cumul à chaque tour, sans réduction (cumulable 3 fois).",
			"dot": _dot_poison},
		"saignement": {"libelle": "Saignement", "nature": "malus", "duree": 3,
			"description": "Perd 25 % de ses PV actuels à chaque tour.", "dot": _dot_saignement},
		"électrocution": {"libelle": "Électrocution", "nature": "malus", "duree": 3,
			"description": "Dégâts de foudre chaque tour, 25 % de chance de perdre 1 PA, dégâts de foudre reçus +20 %.",
			"dot": _dot_electrocution, "perte_pa": 0.25, "modifs": func(_c, _p, _n): return {"vulnerabilite_foudre": 0.20}},
		"corruption": {"libelle": "Corruption", "nature": "malus", "duree": 4,
			"description": "Dégâts de chaos qui augmentent à chaque tour ; dégâts physiques, magiques et élémentaires reçus +10 %.",
			"dot": _dot_corruption,
			"modifs": func(_c, _p, _n): return _vulnerabilites(PHYSIQUES + ELEMENTAIRES, 0.10)},
		"aveugler": {"libelle": "Aveuglement", "nature": "malus", "duree": 3,
			"description": "Chance de toucher -40 %.", "modifs": func(_c, _p, _n): return {"chance_de_toucher": -0.40}},
		"silence": {"libelle": "Silence", "nature": "malus", "duree": 3,
			"description": "Ne peut plus lancer de sort offensif ni de soin.", "silence": true},
		"terreur": {"libelle": "Terreur", "nature": "malus", "duree": 3,
			"description": "35 % de chance de perdre son tour ; dégâts infligés -15 %.",
			"perte_tour": 0.35, "sortant": 0.85},
		"affaiblissement": {"libelle": "Affaiblissement", "nature": "malus", "duree": 3,
			"description": "Dégâts infligés -25 %.", "sortant": 0.75},
		"vulnérabilité": {"libelle": "Vulnérabilité", "nature": "malus", "duree": 3,
			"description": "Dégâts reçus +25 %.", "entrant": 1.25},
		"destruction armure": {"libelle": "Armure brisée", "nature": "malus", "duree": 4,
			"description": "Armure et résistances physiques -40 %.",
			"modifs": func(c, _p, _n): return _part_positive(c, ["armure"] + res_phys, 0.4)},
		"destruction résistance": {"libelle": "Résistances brisées", "nature": "malus", "duree": 4,
			"description": "Résistance magique et résistances élémentaires -40 %.",
			"modifs": func(c, _p, _n): return _part_positive(c, ["resistance_magique"] + res_elem, 0.4)},
		"usure": {"libelle": "Usure", "nature": "malus", "duree": 6, "cumul_max": 5,
			"description": "Dégâts physiques reçus +8 % par cumul (cumulable 5 fois).",
			"modifs": func(_c, _p, n): return _vulnerabilites(PHYSIQUES, 0.08 * n)},
		"usure magique": {"libelle": "Usure magique", "nature": "malus", "duree": 6, "cumul_max": 5,
			"description": "Dégâts magiques et élémentaires reçus +6 % par cumul (cumulable 5 fois).",
			"modifs": func(_c, _p, n): return _vulnerabilites(ELEMENTAIRES, 0.06 * n)},
		"malédiction": {"libelle": "Malédiction", "nature": "malus", "duree": 4,
			"description": "Soins reçus -50 %.", "soins_recus": 0.5},
		"épuisement": {"libelle": "Épuisement", "nature": "malus", "duree": 3,
			"description": "Perd 10 % de son mana max à chaque tour.", "mana_tour": _mana_epuisement},
		"marque": {"libelle": "Marque du chasseur", "nature": "malus", "duree": 3,
			"description": "Les coups qu'il reçoit ont +20 % de chance d'être critiques.", "marque": 0.20},
		"lenteur": {"libelle": "Lenteur", "nature": "malus", "duree": 4,
			"description": "50 % de chance de perdre 1 PA à chaque tour ; esquive -5 %.",
			"perte_pa": 0.5, "modifs": func(_c, _p, _n): return {"chance_esquive": -0.05}},
		"paralysie": {"libelle": "Paralysie", "nature": "malus", "duree": 3,
			"description": "25 % de chance de perdre son tour ; esquive -10 %.",
			"perte_tour": 0.25, "modifs": func(_c, _p, _n): return {"chance_esquive": -0.10}},
		"sommeil": {"libelle": "Sommeil", "nature": "malus", "duree": 3,
			"description": "Endormi : perd ses tours, mais le premier coup qui le blesse le réveille.",
			"perte_tour": 1.0, "reveil": true},
		"condamnation": {"libelle": "Condamnation", "nature": "malus", "duree": 4,
			"description": "Compte à rebours : s'il dure jusqu'au bout, subit 30 % de ses PV max en dégâts d'ombre.",
			"fin": _fin_condamnation},
		"peste": {"libelle": "Peste", "nature": "malus", "duree": 4,
			"description": "Dégâts de chaos à chaque tour (3 % des PV max) ; 35 % de chance par tour de contaminer un allié.",
			"dot": _dot_peste, "contagion": 0.35},
		"engelure": {"libelle": "Engelure", "nature": "malus", "duree": 3, "cumul_max": 3,
			"description": "Dégâts de froid à chaque tour (2,5 % des PV max + magie du lanceur), +50 % par cumul ; esquive -5 % (cumulable 3 fois).",
			"dot": _dot_engelure, "modifs": func(_c, _p, _n): return {"chance_esquive": -0.05}},
		"trauma": {"libelle": "Trauma interne", "nature": "malus", "duree": 3,
			"description": "Dégâts contondants à chaque tour (2 % des PV max + force du lanceur), réduits par l'armure.",
			"dot": _dot_trauma},
		"siphon de vie": {"libelle": "Siphon de vie", "nature": "malus", "duree": 3,
			"description": "Dégâts d'ombre à chaque tour (2 % des PV max + magie du lanceur) ; le lanceur récupère la moitié des PV retirés.",
			"dot": _dot_siphon, "draine": 0.5},
		"brûlure de mana": {"libelle": "Brûlure de mana", "nature": "malus", "duree": 3,
			"description": "Perd 12 % de son mana max à chaque tour et subit 2 dégâts d'arcane par point de mana brûlé.",
			"dot": _dot_brulure_mana, "mana_tour": _mana_brulure_mana},
		"désarmement": {"libelle": "Désarmement", "nature": "malus", "duree": 2,
			"description": "Dégâts physiques infligés -40 %.",
			"modifs": func(c, _p, _n): return _part_positive(c, ["pourcentage_degats_physique"], 0.4)},
		"esprit embrumé": {"libelle": "Esprit embrumé", "nature": "malus", "duree": 3,
			"description": "Dégâts magiques et élémentaires infligés -40 % ; chance de critique magique -5 %.",
			"modifs": func(c, _p, _n):
				var m := _part_positive(c, ["pourcentage_degats_magique", "pourcentage_degats_elementaire"], 0.4)
				m["chance_de_coup_critique_magique"] = -0.05
				return m},
		"inflammabilité": {"libelle": "Inflammabilité", "nature": "malus", "duree": 4,
			"description": "Dégâts de feu reçus +25 %.", "modifs": func(_c, _p, _n): return {"vulnerabilite_feu": 0.25}},
		"morsure du givre": {"libelle": "Morsure du givre", "nature": "malus", "duree": 4,
			"description": "Dégâts de froid reçus +25 %.", "modifs": func(_c, _p, _n): return {"vulnerabilite_froid": 0.25}},
		"conductivité": {"libelle": "Conductivité", "nature": "malus", "duree": 4,
			"description": "Dégâts de foudre reçus +25 %.", "modifs": func(_c, _p, _n): return {"vulnerabilite_foudre": 0.25}},
		"décrépitude": {"libelle": "Décrépitude", "nature": "malus", "duree": 3,
			"description": "Dégâts infligés -15 %, dégâts reçus +15 %, 25 % de chance de perdre 1 PA par tour.",
			"sortant": 0.85, "entrant": 1.15, "perte_pa": 0.25},
		"flétrissement": {"libelle": "Flétrissement", "nature": "malus", "duree": 4,
			"description": "PV max -15 % (les PV en trop sont perdus).",
			"modifs": func(c, _p, _n): return _part_positive(c, ["points_de_vie_max"], 0.15)},
		"faiblesse": {"libelle": "Faiblesse", "nature": "malus", "duree": 4,
			"description": "Force -40 % (dégâts physiques réduits d'autant).",
			"modifs": func(c, _p, _n): return _part_positive(c, ["force"], 0.4)},
		"maladresse": {"libelle": "Maladresse", "nature": "malus", "duree": 4,
			"description": "Dextérité amoindrie : toucher -15 %, esquive -10 %, critique -5 %.",
			"modifs": func(_c, _p, _n): return {"chance_de_toucher": -0.15, "chance_esquive": -0.10,
				"chance_de_coup_critique": -0.05}},
		"débilité": {"libelle": "Débilité", "nature": "malus", "duree": 4,
			"description": "Intelligence amoindrie : puissance magique -40 %, critique magique -5 %.",
			"modifs": func(c, _p, _n):
				var m := _part_positive(c, ["puissance_magique"], 0.4)
				m["chance_de_coup_critique_magique"] = -0.05
				return m},
		"sape": _alteration_caracteristiques("Sape de force", "malus", ["force"], 0.07, 1),
		"engourdissement": _alteration_caracteristiques("Engourdissement", "malus", ["dextérité"], 0.07, 1),
		"épuisement vital": _alteration_caracteristiques("Épuisement vital", "malus", ["endurance"], 0.07, 1),
		"torpeur": _alteration_caracteristiques("Torpeur", "malus", ["intelligence"], 0.07, 1),
		"trouble": _alteration_caracteristiques("Trouble de l'esprit", "malus", ["sagesse"], 0.07, 1),
		"déchéance": _alteration_caracteristiques("Déchéance", "malus", ["force", "endurance"], 0.05, 1),
		"dissonance": _alteration_caracteristiques("Dissonance", "malus", ["intelligence", "sagesse"], 0.05, 1),
		"entropie": _alteration_caracteristiques("Entropie", "malus", CARACTERISTIQUES, 0.04, 1),
		# ---------------------------- Bonus ----------------------------
		"précis": {"libelle": "Précision", "nature": "bonus", "duree": 3,
			"description": "Chance de toucher +35 %.", "modifs": func(_c, _p, _n): return {"chance_de_toucher": 0.35}},
		"protection": {"libelle": "Protection", "nature": "bonus", "duree": 3, "puissance": 40,
			"description": "Dégâts physiques reçus -{p} %.", "modifs": func(_c, p, _n): return {"resistance_pct_physique": p / 100.0}},
		"barrière": {"libelle": "Barrière", "nature": "bonus", "duree": 3, "puissance": 30,
			"description": "Dégâts magiques (arcane, ombre, chaos) reçus -{p} %.",
			"modifs": func(_c, p, _n): return {"resistance_pct_magique": p / 100.0}},
		"rage": {"libelle": "Rage", "nature": "bonus", "duree": 3,
			"description": "Dégâts infligés +25 % et dégâts critiques +25 %.", "sortant": 1.25,
			"modifs": func(_c, _p, _n): return {"degats_critique": 0.25}},
		"hâte": {"libelle": "Hâte", "nature": "bonus", "duree": 2,
			"description": "+1 PA à chaque tour.", "gain_pa": 1},
		"régénération": {"libelle": "Régénération", "nature": "bonus", "duree": 3,
			"description": "Rend 6 % des PV max à chaque tour.", "soin_tour": _soin_regeneration},
		"bouclier": {"libelle": "Bouclier", "nature": "bonus", "duree": 3, "puissance": 30,
			"description": "Absorbe {p} dégâts avant de se briser.", "bouclier": true},
		"concentration": {"libelle": "Concentration", "nature": "bonus", "duree": 3,
			"description": "Chance de coup critique +15 %.",
			"modifs": func(_c, _p, _n): return {"chance_de_coup_critique": 0.15}},
		"évasion": {"libelle": "Évasion", "nature": "bonus", "duree": 2,
			"description": "Esquive +20 %.", "modifs": func(_c, _p, _n): return {"chance_esquive": 0.20}},
		"épines": {"libelle": "Épines", "nature": "bonus", "duree": 3,
			"description": "Renvoie 25 % des dégâts physiques reçus à l'attaquant.", "epines": 0.25},
		"bénédiction": {"libelle": "Bénédiction", "nature": "bonus", "duree": 3,
			"description": "Toucher +10 %, dégâts infligés +10 %, dégâts magiques reçus -10 %.", "sortant": 1.10,
			"modifs": func(_c, _p, _n): return {"chance_de_toucher": 0.10, "resistance_pct_magique": 0.10}},
		"soif de sang": {"libelle": "Soif de sang", "nature": "bonus", "duree": 3,
			"description": "Rend 20 % des dégâts infligés en PV.", "vol_de_vie": 0.20},
		"clarté": {"libelle": "Clarté", "nature": "bonus", "duree": 3,
			"description": "Rend 10 % du mana max à chaque tour.", "mana_tour": _mana_clarte},
		"vigueur": _alteration_caracteristiques("Vigueur", "bonus", ["force"], 0.07, 1),
		"agilité": _alteration_caracteristiques("Agilité", "bonus", ["dextérité"], 0.07, 1),
		"robustesse": _alteration_caracteristiques("Robustesse", "bonus", ["endurance"], 0.07, 1),
		"intellect": _alteration_caracteristiques("Intellect", "bonus", ["intelligence"], 0.07, 1),
		"sérénité": _alteration_caracteristiques("Sérénité", "bonus", ["sagesse"], 0.07, 1),
		"puissance du titan": _alteration_caracteristiques("Puissance du titan", "bonus", ["force", "endurance"], 0.05, 1),
		"illumination": _alteration_caracteristiques("Illumination", "bonus", ["intelligence", "sagesse"], 0.05, 1),
		"transcendance": _alteration_caracteristiques("Transcendance", "bonus", CARACTERISTIQUES, 0.04, 1),
	}
	DonneesEnnemis.appliquer_alterations(d)  # durées et cumuls réglés dans l'éditeur (2026-11-04)
	_definitions = d
	for element in TYPES_ALTERATIONS:
		for nom in TYPES_ALTERATIONS[element]:
			_type_alteration[nom] = element
	return _definitions


## Type (élément) de chaque altération (TYPE_ALTERATION).
static func type_alteration() -> Dictionary:
	defs()
	return _type_alteration


static func definition(nom) -> Dictionary:
	return defs().get(nom, {})


static func nom_canonique(nom: String) -> String:
	return ALIAS.get(nom, nom)


static func libelle(nom: String) -> String:
	return definition(nom_canonique(nom)).get("libelle", nom)


static func description(nom: String, puissance = null) -> String:
	var d := definition(nom_canonique(nom))
	var p = d.get("puissance", 0) if puissance == null else puissance
	return String(d.get("description", "")).replace("{p}", U.g(p))


static func est_bonus(nom: String) -> bool:
	return definition(nom_canonique(nom)).get("nature") == "bonus"


static func _appliquer_modifs(cible, data: Dictionary, nouvelles: Dictionary) -> void:
	var anciennes: Dictionary = data.get("modifs", {})
	for attribut in anciennes:
		cible.set(attribut, U.ga(cible, attribut, 0) - anciennes[attribut])
	for attribut in nouvelles:
		cible.set(attribut, U.ga(cible, attribut, 0) + nouvelles[attribut])
	data["modifs"] = nouvelles.duplicate()


## Modifications d'une définition (``definition["modifs"](cible, p, n[, i])``).
static func appeler_modifs(d: Dictionary, cible, puissance, cumul, intensite = 1.0) -> Dictionary:
	if d.get("caracteristiques"):
		return d["modifs"].call(cible, puissance, cumul, intensite)
	return d["modifs"].call(cible, puissance, cumul)


static func _combat_actif(combat) -> bool:
	return combat != null and U.ha(combat, "ennemis")


## Soigne un combattant, en tenant compte des malus de soins (malédiction).
static func soigner(cible, montant, combat = null) -> int:
	if not cible.est_vivant():
		return 0
	montant = maxf(0, montant * multiplicateur_soins(cible))
	var avant = cible.points_de_vie
	if _combat_actif(combat):
		Degats.recevoir_degats_lumiere(cible, montant, 0, combat)
	else:
		cible.points_de_vie = minf(cible.points_de_vie_max, cible.points_de_vie + montant)
	return int(cible.points_de_vie - avant)


static func _infliger_dot(cible, type_degats: String, montant, data: Dictionary, combat) -> float:
	if not _combat_actif(combat):
		return 0.0
	var lanceur = data.get("lanceur")
	var pen = _stat(lanceur, "penetration_resistance")
	var pv_avant = cible.points_de_vie
	Degats.recevoir(type_degats, cible, montant, _stat(lanceur, "penetration_armure"), pen, combat, lanceur)
	var perdus = pv_avant - maxf(0, cible.points_de_vie)
	if lanceur != cible:
		Statistiques.noter(lanceur, "degats_infliges", perdus)
	return perdus


static func _allies(cible, combat) -> Array:
	if not _combat_actif(combat) or not (cible in combat.ennemis):
		return []
	var allies := []
	for e in combat.ennemis:
		if e != cible and e.est_vivant():
			allies.append(e)
	return allies


static func _effet_de_tour(cible, data: Dictionary, d: Dictionary, combat, nom = null) -> bool:
	data["tours"] = data.get("tours", 0) + 1
	var passe := false
	if d.has("dot"):
		var resultat: Array = d["dot"].call(cible, data, data["tours"])
		var type_degats: String = resultat[0]
		var montant = resultat[1] * Talents.multiplicateur_dot(data.get("lanceur"), nom, type_degats) * data.get("intensite", 1.0)
		var perdus := _infliger_dot(cible, type_degats, montant, data, combat)
		var lanceur = data.get("lanceur")
		if d.get("draine") and perdus > 0 and lanceur != null and lanceur != cible and lanceur.est_vivant():
			lanceur.points_de_vie = minf(lanceur.points_de_vie_max, lanceur.points_de_vie + perdus * d["draine"])
	if d.get("contagion") and nom and cible.est_vivant() and randf() < d["contagion"]:
		var sains := []
		for a in _allies(cible, combat):
			var alt = U.ga(a, "alteration", null)
			if alt == null or not (nom in alt):
				sains.append(a)
		if not sains.is_empty():
			var voisin = sains.pick_random()
			print("%s : %s contamine %s." % [d["libelle"], cible.nom, voisin.nom])
			appliquer_alterations(voisin, nom, data.get("lanceur"), 100, data.get("puissance"))
	if d.has("soin_tour"):
		soigner(cible, d["soin_tour"].call(cible, data, data["tours"]) * data.get("intensite", 1.0), combat)
	if d.has("mana_tour"):
		var gain = d["mana_tour"].call(cible, data, data["tours"]) * data.get("intensite", 1.0)
		cible.mana = max(0, min(cible.mana_max, cible.mana + int(gain)))
	if d.get("perte_tour") and randf() < d["perte_tour"]:
		print("%s perd son tour (%s)." % [cible.nom, d["libelle"]])
		cible.points_d_action = 0
		cible.set("cause_tour_perdu", d["libelle"])
		passe = true
	var perte = d.get("perte_pa", 0)
	if perte:
		var perdus_pa := int(perte) + (1 if randf() < perte - int(perte) else 0)
		var avant_pa = cible.points_d_action
		cible.points_d_action = max(0, cible.points_d_action - perdus_pa)
		if perdus_pa > 0 and avant_pa > 0 and cible.points_d_action == 0:
			print("%s perd son tour (%s)." % [cible.nom, d["libelle"]])
			cible.set("cause_tour_perdu", d["libelle"])
	if d.get("gain_pa"):
		cible.points_d_action += d["gain_pa"]
	return passe


# ---------------------------------------------------------------------------
# Lecture des effets par le combat
# ---------------------------------------------------------------------------

## Altérations actives d'un combattant : [[nom, données, définition], ...].
static func _actives(combattant) -> Array:
	var alterations = U.ga(combattant, "alteration", null)
	if not (alterations is Dictionary):
		return []
	var liste := []
	for nom in alterations.keys():
		var data = alterations[nom]
		var d = defs().get(nom)
		if d != null and data is Dictionary:
			liste.append([nom, data, d])
	return liste


static func attribut_intensite(cle: String) -> String:
	return "talent_intensite__" + cle.replace(" ", "_")


static func intensite_de(lanceur, nature: String, nom = null) -> float:
	var attribut := "talent_puissance_malus" if nature == "malus" else "talent_puissance_bonus"
	var total := U.num(lanceur, attribut) if lanceur != null else 0.0
	if nom != null:
		var cles := []
		for c in [type_alteration().get(nom), nom]:
			if c and not (c in cles):
				cles.append(c)
		for cle in cles:
			if lanceur != null:
				total += U.num(lanceur, attribut_intensite(cle))
	return maxf(0.0, 1.0 + total)


static func cumul_maximal(d: Dictionary, lanceur) -> int:
	var maximum := int(d.get("cumul_max", 1))
	if maximum > 1 and d.get("nature") == "malus":
		maximum += int(U.num(lanceur, "talent_cumul_malus")) if lanceur != null else 0
	return maximum


static func _ajuste(multiplicateur: float, data: Dictionary) -> float:
	return maxf(0.0, 1 + (multiplicateur - 1) * data.get("intensite", 1.0))


static func modificateur_degats(lanceur, cible) -> float:
	var mult := 1.0
	for a in _actives(lanceur):
		mult *= _ajuste(a[2].get("sortant", 1.0), a[1])
	for a in _actives(cible):
		mult *= _ajuste(a[2].get("entrant", 1.0), a[1])
	return mult


static func multiplicateur_soins(cible) -> float:
	var mult := maxf(0.0, 1.0 + U.num(cible, "talent_soins_recus"))
	for a in _actives(cible):
		mult *= _ajuste(a[2].get("soins_recus", 1.0), a[1])
	return mult


static func chance_critique_contre(cible) -> float:
	var total := 0.0
	for a in _actives(cible):
		total += a[2].get("marque", 0) * a[1].get("intensite", 1.0)
	return total


## Fait absorber des dégâts par le bouclier de la cible.
static func absorber(cible, degats: float) -> float:
	for a in _actives(cible):
		var nom = a[0]
		var data: Dictionary = a[1]
		if a[2].get("bouclier") and degats > 0:
			var absorbe := minf(data.get("reserve", 0), degats)
			data["reserve"] = data.get("reserve", 0) - absorbe
			degats -= absorbe
			if absorbe:
				print("Le bouclier de %s absorbe %s dégâts." % [cible.nom, U.f(absorbe)])
			if data["reserve"] <= 0:
				retirer(cible, nom)
	return degats


## Réveil de la cible endormie, épines de la cible, vol de vie du lanceur.
static func apres_coup(lanceur, cible, type_degats: String, pv_perdus, combat, vol_de_vie_competence = 0.0) -> void:
	if pv_perdus <= 0:
		return
	for a in _actives(cible):
		if a[2].get("reveil") and lanceur != cible:
			print("%s se réveille (%s)." % [cible.nom, a[2]["libelle"]])
			retirer(cible, a[0])
	if type_degats in PHYSIQUES and lanceur != cible and lanceur.est_vivant():
		var epines := 0.0
		for a in _actives(cible):
			epines += a[2].get("epines", 0) * a[1].get("intensite", 1.0)
		var renvoi: float = (epines + U.num(cible, "talent_epines")) * pv_perdus
		if renvoi >= 1:
			print("Les épines de %s renvoient %s dégâts à %s." % [cible.nom, U.f(renvoi), lanceur.nom])
			Degats.recevoir_degats_brut(lanceur, renvoi, combat)
	var vol: float = vol_de_vie_competence + Talents.vol_de_vie_talents(lanceur, type_degats)
	for a in _actives(lanceur):
		vol += a[2].get("vol_de_vie", 0) * a[1].get("intensite", 1.0)
	if vol > 0 and lanceur.est_vivant():
		lanceur.points_de_vie = minf(lanceur.points_de_vie_max, lanceur.points_de_vie + pv_perdus * vol)


# ---------------------------------------------------------------------------
# Classe Alteration (méthodes statiques)
# ---------------------------------------------------------------------------

## Applique une altération à une cible, avec une probabilité donnée (en %).
static func appliquer_alterations(cible, type_alteration_nom: String, lanceur, pourcentage_appliquer = 100,
		puissance = null, duree_bonus = 0) -> bool:
	var applique := _appliquer_alterations(cible, type_alteration_nom, lanceur, pourcentage_appliquer, puissance, duree_bonus)
	if applique:
		EffetsCombat.signaler_alteration(cible, type_alteration_nom)
	return applique


static func _appliquer_alterations(cible, type_alteration_nom: String, lanceur, pourcentage_appliquer,
		puissance, duree_bonus) -> bool:
	if not U.ha(cible, "alteration") or cible.alteration == null:
		cible.alteration = {}
	if pourcentage_appliquer <= 0 or randf_range(0, 100) > pourcentage_appliquer:
		return false
	var nom := nom_canonique(type_alteration_nom)
	var d = defs().get(nom)
	if d == null or not cible.est_vivant():
		return false
	if U.num(cible, "talent_immunite_controle") and nom in CONTROLES:
		print("%s est immunisé à %s." % [cible.nom, d["libelle"]])
		return false
	var resistance := U.num(cible, "talent_resistance_alterations")
	if resistance and cible != lanceur and not est_bonus(nom) and randf() < resistance:
		print("%s résiste à %s." % [cible.nom, d["libelle"]])
		return false
	var p = d.get("puissance", 0) if puissance == null else puissance
	var duree = d["duree"] + duree_bonus
	var intensite := intensite_de(lanceur, d["nature"], nom)
	var data = cible.alteration.get(nom)
	if data == null:
		data = {"duree": duree, "lanceur": lanceur, "cumul": 1, "puissance": p, "modifs": {}, "intensite": intensite}
		cible.alteration[nom] = data
	else:
		data["duree"] = max(data["duree"], duree)
		data["cumul"] = mini(cumul_maximal(d, lanceur), data.get("cumul", 1) + 1)
		data["puissance"] = max(data.get("puissance", 0), p)
		data["intensite"] = maxf(data.get("intensite", 1.0), intensite)
		data["lanceur"] = lanceur
	if d.has("modifs"):
		_appliquer_modifs(cible, data, {})
		var modifs: Dictionary
		if d.get("caracteristiques"):
			modifs = appeler_modifs(d, cible, data["puissance"], data["cumul"], data["intensite"])
		else:
			modifs = {}
			var brutes: Dictionary = appeler_modifs(d, cible, data["puissance"], data["cumul"])
			for a in brutes:
				modifs[a] = brutes[a] * data["intensite"]
		_appliquer_modifs(cible, data, modifs)
		if cible.points_de_vie > cible.points_de_vie_max:
			cible.points_de_vie = cible.points_de_vie_max
		if U.ga(cible, "mana", 0) > U.ga(cible, "mana_max", 0):
			cible.mana = cible.mana_max
	if d.get("silence"):
		cible.magie = false
	if d.get("bouclier"):
		data["reserve"] = data["puissance"] * data["intensite"]
	var cumul := " (×%d)" % data["cumul"] if data["cumul"] > 1 else ""
	print("%s est affecté par %s%s." % [cible.nom, d["libelle"], cumul])
	return true


## Retire une altération et annule exactement ses modifications de statistiques.
static func retirer(cible, type_alteration_nom: String) -> void:
	var alterations = U.ga(cible, "alteration", null)
	if alterations == null:
		alterations = {}
	var data = alterations.get(type_alteration_nom)
	alterations.erase(type_alteration_nom)
	if not (data is Dictionary):
		return
	_appliquer_modifs(cible, data, {})
	if definition(type_alteration_nom).get("silence"):
		var reste_silence := false
		for n in alterations:
			if definition(n).get("silence"):
				reste_silence = true
		if not reste_silence:
			cible.magie = true


## Retire jusqu'à ``nombre`` malus, les plus longs d'abord (sorts de lumière).
static func purifier(cible, nombre) -> Array:
	var malus := []
	for a in _actives(cible):
		if a[2].get("nature") == "malus":
			malus.append([a[1].get("duree", 0), a[0], a[2]["libelle"]])
	malus.sort_custom(func(x, y):
		if x[0] != y[0]:
			return x[0] > y[0]
		if x[1] != y[1]:
			return x[1] > y[1]
		return x[2] > y[2])
	var retires := []
	for m in malus.slice(0, maxi(0, int(nombre))):
		retirer(cible, m[1])
		retires.append(m[2])
	if not retires.is_empty():
		print("%s est purifié : %s." % [cible.nom, ", ".join(retires)])
	return retires


## Retire toutes les altérations (fin de combat), statistiques restaurées.
static func retirer_tout(cible) -> void:
	var alterations = U.ga(cible, "alteration", null)
	if alterations != null:
		for nom in alterations.keys():
			retirer(cible, nom)
	cible.alteration = {}


## Effets de début de tour des altérations, puis avancée de leur durée.
## Renvoie true si le porteur perd son tour.
static func mise_a_jour(cible, combat) -> bool:
	if not U.ha(cible, "alteration") or not U.vrai(cible.alteration):
		return false
	var passe_son_tour := false
	for nom in cible.alteration.keys():
		if not cible.alteration.has(nom):
			continue
		var data = cible.alteration[nom]
		if not (data is Dictionary):
			cible.alteration.erase(nom)
			continue
		var d = defs().get(nom)
		if d == null:
			retirer(cible, nom)
			continue
		if cible.est_vivant():
			passe_son_tour = _effet_de_tour(cible, data, d, combat, nom) or passe_son_tour
		if cible.alteration.has(nom):
			data["duree"] -= 1
			if data["duree"] <= 0:
				retirer(cible, nom)
				if d.has("fin") and cible.est_vivant():
					print("%s : le compte à rebours de %s est écoulé !" % [d["libelle"], cible.nom])
					var fin: Array = d["fin"].call(cible, data)
					_infliger_dot(cible, fin[0], fin[1] * data.get("intensite", 1.0), data, combat)
	return passe_son_tour


## Altérations actives, prêtes à afficher : [[nom, libellé, durée, cumul, est_bonus], ...].
static func resume(cible) -> Array:
	var liste := []
	for a in _actives(cible):
		liste.append([a[0], a[2]["libelle"], a[1].get("duree", 0), a[1].get("cumul", 1), a[2].get("nature") == "bonus"])
	return liste
