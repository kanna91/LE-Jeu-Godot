class_name BriquesAlterations
extends RefCounted
## Briques primaires des altérations (2026-11-06, demande de l'utilisateur : « décomposer toutes les altérations pour
## avoir toutes les briques séparées les unes des autres », puis un créateur d'altérations).
##
## Une **brique** est un effet unique et réglable (BRIQUES) : une statistique (chance de toucher, esquive, vulnérabilité
## à un type...), un effet de chaque tour (dégâts, soin, mana, perte de tour...) ou un effet en combat (dégâts infligés,
## bouclier, épines...). Une **altération** (« brute ») est une liste de morceaux : des briques avec leurs valeurs, ou
## d'autres altérations avec une puissance en % ({"alteration": nom, "puissance": 70} = ses effets à 70 %) :
##   {"libelle", "nature" (« malus » / « bonus »), "duree", "cumul_max", "puissance" (facultatif), "briques": [...]}
## Les altérations composées du jeu sont dans COMPOSEES ; celles de l'éditeur (personnalisées, réglages des
## composées) dans ``donnees/competences_editees.json`` (DonneesEnnemis). ``construire`` en fait la définition jouée
## par Alterations (modifs, dots, fins, perte_tour...), ``decrire`` sa description (toujours tirée des briques).
##
## Valeurs en pourcentage : fractions (0.25 = 25 %). Les statistiques se multiplient par le cumul.

const FAMILLES := ["Statistiques", "Effets de chaque tour", "Effets en combat"]
## Types de dégâts (dégâts par tour, dégâts à la fin) et cibles des vulnérabilités / résistances.
const TYPES := ["tranchant", "perforant", "contondant", "feu", "froid", "foudre", "arcane", "chaos", "ombre", "lumière",
	"poison", "saignement"]
const TYPES_DEFENSE := ["tranchant", "perforant", "contondant", "feu", "froid", "foudre", "arcane", "chaos", "ombre",
	"physique", "elementaire", "magique"]
const NOMS_TYPES := {"tranchant": "tranchants", "perforant": "perforants", "contondant": "contondants", "feu": "de feu",
	"froid": "de froid", "foudre": "de foudre", "arcane": "d'arcane", "chaos": "de chaos", "ombre": "d'ombre",
	"lumière": "de lumière", "poison": "de poison", "saignement": "de saignement", "physique": "physiques (tranchant, perforant, contondant)",
	"elementaire": "élémentaires (feu, froid, foudre)", "magique": "magiques (arcane, chaos, ombre)"}
## Statistiques qu'une brique « baisse » réduit d'une part de leur valeur positive.
const STATS_BAISSE := {
	"armure": ["Armure", ["armure"]],
	"resistance_magique": ["Résistance magique", ["resistance_magique"]],
	"resistance_elementaire": ["Résistance élémentaire", ["resistance_elementaire"]],
	"resistances_physiques": ["Résistances physiques", ["resistance_tranchant", "resistance_perforant", "resistance_contondant"]],
	"resistances_elementaires": ["Résistances élémentaires", ["resistance_feu", "resistance_froid", "resistance_foudre",
		"resistance_arcane", "resistance_chaos", "resistance_ombre"]],
	"pv_max": ["PV max", ["points_de_vie_max"]],
	"degats_physiques": ["Dégâts physiques infligés", ["pourcentage_degats_physique"]],
	"degats_magiques": ["Dégâts magiques infligés", ["pourcentage_degats_magique"]],
	"degats_elementaires": ["Dégâts élémentaires infligés", ["pourcentage_degats_elementaire"]],
}
const CUMULS := {"aucun": "aucun effet", "multiplie": "× le cumul", "demi": "+50 % / cumul"}

## Briques : id → {libelle, famille, params : {nom : genre}, stat (statistiques simples), aide}.
## Genres de réglage : « pct » (pourcentage), « nombre », « type », « defense », « baisse », « carac », « des »,
## « cumul », « oui » (case à cocher).
const BRIQUES := {
	"toucher": {"libelle": "Chance de toucher", "famille": "Statistiques", "params": {"valeur": "pct"}, "stat": "chance_de_toucher"},
	"esquive": {"libelle": "Esquive", "famille": "Statistiques", "params": {"valeur": "pct"}, "stat": "chance_esquive"},
	"critique": {"libelle": "Chance de coup critique", "famille": "Statistiques", "params": {"valeur": "pct"},
		"stat": "chance_de_coup_critique"},
	"critique_magique": {"libelle": "Chance de critique magique", "famille": "Statistiques", "params": {"valeur": "pct"},
		"stat": "chance_de_coup_critique_magique"},
	"degats_critiques": {"libelle": "Dégâts critiques", "famille": "Statistiques", "params": {"valeur": "pct"}, "stat": "degats_critique"},
	"parade": {"libelle": "Chance de parer", "famille": "Statistiques", "params": {"valeur": "pct"}, "stat": "chance_de_parer",
		"aide": "Chance de parer les attaques physiques."},
	"vulnerabilite": {"libelle": "Vulnérabilité", "famille": "Statistiques", "params": {"type": "defense", "valeur": "pct"},
		"aide": "Dégâts reçus d'un type ou d'un groupe de types en plus."},
	"resistance": {"libelle": "Résistance en pourcentage", "famille": "Statistiques",
		"params": {"type": "defense", "valeur": "pct", "selon_puissance": "oui"},
		"aide": "Dégâts reçus d'un type ou d'un groupe en moins (75 % au plus). « Selon la puissance » : la valeur est donnée par la compétence (ex. Protection)."},
	"baisse": {"libelle": "Baisse d'une statistique", "famille": "Statistiques", "params": {"stat": "baisse", "valeur": "pct"},
		"aide": "Retire une part de la valeur positive (armure, résistances, PV max, dégâts infligés)."},
	"caracteristique": {"libelle": "Caractéristique", "famille": "Statistiques", "params": {"carac": "carac", "part": "pct", "fixe": "nombre"},
		"aide": "Change une caractéristique de part % + fixe par cumul, avec ses effets (négatif = réduction)."},
	"degats_par_tour": {"libelle": "Dégâts à chaque tour", "famille": "Effets de chaque tour",
		"params": {"type": "type", "fixe": "nombre", "pv_max": "pct", "pv_actuels": "pct", "des": "des", "cumul": "cumul", "croissant": "oui"},
		"aide": "Fixe + part des PV max + part des PV actuels + dés. « Croissant » : × le numéro du tour."},
	"soin_par_tour": {"libelle": "Soin à chaque tour", "famille": "Effets de chaque tour", "params": {"pv_max": "pct"}},
	"mana_par_tour": {"libelle": "Mana à chaque tour", "famille": "Effets de chaque tour", "params": {"mana_max": "pct"},
		"aide": "Part du mana max rendue (positif) ou perdue (négatif), 1 au moins."},
	"fuite_de_mana": {"libelle": "Fuite de mana", "famille": "Effets de chaque tour",
		"params": {"mana_max": "pct", "fixe": "nombre", "degats_par_mana": "nombre", "type": "type"},
		"aide": "Perd une part de son mana et subit des dégâts par point de mana perdu."},
	"perte_tour": {"libelle": "Perte de tour", "famille": "Effets de chaque tour", "params": {"chance": "pct"}},
	"perte_pa": {"libelle": "Perte de PA", "famille": "Effets de chaque tour", "params": {"chance": "pct"},
		"aide": "100 % = perd 1 PA à chaque tour (le héros n'en a qu'un : il perd son tour)."},
	"gain_pa": {"libelle": "Gain de PA", "famille": "Effets de chaque tour", "params": {"nombre": "nombre"}},
	"degats_infliges": {"libelle": "Dégâts infligés", "famille": "Effets en combat", "params": {"valeur": "pct"}},
	"degats_recus": {"libelle": "Dégâts reçus", "famille": "Effets en combat", "params": {"valeur": "pct"}},
	"soins_recus": {"libelle": "Soins reçus", "famille": "Effets en combat", "params": {"valeur": "pct"}},
	"bouclier": {"libelle": "Bouclier", "famille": "Effets en combat", "params": {"points": "nombre", "selon_puissance": "oui"}},
	"epines": {"libelle": "Épines", "famille": "Effets en combat", "params": {"valeur": "pct"}},
	"vol_de_vie": {"libelle": "Vol de vie", "famille": "Effets en combat", "params": {"valeur": "pct"}},
	"marque": {"libelle": "Marque (critiques reçus)", "famille": "Effets en combat", "params": {"valeur": "pct"}},
	"silence": {"libelle": "Silence", "famille": "Effets en combat", "params": {}},
	"reveil": {"libelle": "Réveil au premier coup", "famille": "Effets en combat", "params": {},
		"aide": "L'altération s'arrête dès qu'un coup le blesse (avec une perte de tour : sommeil)."},
	"degats_fin": {"libelle": "Dégâts à la fin", "famille": "Effets en combat", "params": {"type": "type", "pv_max": "pct"},
		"aide": "Si l'altération dure jusqu'au bout."},
	"drain": {"libelle": "Drain", "famille": "Effets en combat", "params": {"valeur": "pct"},
		"aide": "Le lanceur récupère cette part des PV retirés par les dégâts à chaque tour."},
	"contagion": {"libelle": "Contagion", "famille": "Effets en combat", "params": {"chance": "pct"},
		"aide": "Chance par tour de contaminer un allié du porteur."},
}
## Valeurs proposées quand on ajoute une brique dans le créateur.
const VALEURS_NOUVELLE_BRIQUE := {"valeur": 0.10, "type": "feu", "stat": "armure", "carac": "force", "part": 0.05,
	"fixe": 1, "pv_max": 0.03, "pv_actuels": 0.0, "des": [1, 2], "cumul": "aucun", "croissant": false,
	"mana_max": 0.10, "degats_par_mana": 2, "chance": 0.25, "nombre": 1, "points": 30, "selon_puissance": false}


# ---------------------------------------------------------------------------
# Altérations composées du jeu (valeurs d'avant le 2026-11-06, mêmes effets)
# ---------------------------------------------------------------------------

static func _maj(texte: String) -> String:
	return texte.substr(0, 1).to_upper() + texte.substr(1)


static func _b(id: String, params := {}) -> Dictionary:
	var b := {"brique": id}
	b.merge(params)
	return b


static func _alt(libelle: String, nature: String, duree: int, briques: Array, cumul_max := 1, puissance = null) -> Dictionary:
	var a := {"libelle": libelle, "nature": nature, "duree": duree, "cumul_max": cumul_max, "briques": briques}
	if puissance != null:
		a["puissance"] = puissance
	return a


static func _caracs(caracs: Array, part: float, fixe: float) -> Array:
	var liste := []
	for c in caracs:
		liste.append(_b("caracteristique", {"carac": c, "part": part, "fixe": fixe}))
	return liste


static var _composees := {}


## Altérations composées d'origine (sans les réglages de l'éditeur).
static func composees() -> Dictionary:
	if not _composees.is_empty():
		return _composees
	var d := {
		# ---------------------------- Malus ----------------------------
		"stun": _alt("Étourdissement", "malus", 1, [_b("perte_tour", {"chance": 1.0})]),
		"pétrification": _alt("Pétrification", "malus", 2, [_b("perte_tour", {"chance": 1.0}),
			_b("resistance", {"type": "physique", "valeur": 0.20})]),
		"gel": _alt("Gel", "malus", 2, [_b("perte_pa", {"chance": 1.0}), _b("esquive", {"valeur": -0.10})]),
		"brulure": _alt("Brûlure", "malus", 3, [_b("degats_par_tour", {"type": "feu", "des": [1, 2], "cumul": "multiplie"})], 3),
		"poison": _alt("Poison", "malus", 4, [_b("degats_par_tour", {"type": "poison", "fixe": 1, "pv_max": 0.04, "cumul": "multiplie"})], 3),
		"saignement": _alt("Saignement", "malus", 3, [_b("degats_par_tour", {"type": "saignement", "fixe": 1, "pv_actuels": 0.25})]),
		"électrocution": _alt("Électrocution", "malus", 3, [_b("degats_par_tour", {"type": "foudre", "fixe": 1, "pv_max": 0.03}),
			_b("perte_pa", {"chance": 0.25}), _b("vulnerabilite", {"type": "foudre", "valeur": 0.20})]),
		"corruption": _alt("Corruption", "malus", 4, [_b("degats_par_tour", {"type": "chaos", "fixe": 2, "pv_max": 0.03, "croissant": true}),
			_b("vulnerabilite", {"type": "physique", "valeur": 0.10}), _b("vulnerabilite", {"type": "elementaire", "valeur": 0.10}),
			_b("vulnerabilite", {"type": "magique", "valeur": 0.10})]),
		"aveugler": _alt("Aveuglement", "malus", 3, [_b("toucher", {"valeur": -0.40})]),
		"silence": _alt("Silence", "malus", 3, [_b("silence")]),
		"terreur": _alt("Terreur", "malus", 3, [_b("perte_tour", {"chance": 0.35}), _b("degats_infliges", {"valeur": -0.15})]),
		"affaiblissement": _alt("Affaiblissement", "malus", 3, [_b("degats_infliges", {"valeur": -0.25})]),
		"vulnérabilité totale": _alt("Vulnérabilité totale", "malus", 3, [_b("degats_recus", {"valeur": 0.25})]),
		"destruction armure": _alt("Armure brisée", "malus", 4, [_b("baisse", {"stat": "armure", "valeur": 0.40}),
			_b("baisse", {"stat": "resistances_physiques", "valeur": 0.40})]),
		"destruction résistance": _alt("Résistances brisées", "malus", 4, [_b("baisse", {"stat": "resistance_magique", "valeur": 0.40}),
			_b("baisse", {"stat": "resistances_elementaires", "valeur": 0.40})]),
		"usure": _alt("Usure", "malus", 6, [_b("vulnerabilite", {"type": "physique", "valeur": 0.08})], 5),
		"usure magique": _alt("Usure magique", "malus", 6, [_b("vulnerabilite", {"type": "elementaire", "valeur": 0.06}),
			_b("vulnerabilite", {"type": "magique", "valeur": 0.06})], 5),
		"malédiction": _alt("Malédiction", "malus", 4, [_b("soins_recus", {"valeur": -0.50})]),
		"épuisement": _alt("Épuisement", "malus", 3, [_b("mana_par_tour", {"mana_max": -0.10})]),
		"marque": _alt("Marque du chasseur", "malus", 3, [_b("marque", {"valeur": 0.20})]),
		"lenteur": _alt("Lenteur", "malus", 4, [_b("perte_pa", {"chance": 0.50}), _b("esquive", {"valeur": -0.05})]),
		"paralysie": _alt("Paralysie", "malus", 3, [_b("perte_tour", {"chance": 0.25}), _b("esquive", {"valeur": -0.10})]),
		"sommeil": _alt("Sommeil", "malus", 3, [_b("perte_tour", {"chance": 1.0}), _b("reveil")]),
		"condamnation": _alt("Condamnation", "malus", 4, [_b("degats_fin", {"type": "ombre", "pv_max": 0.30})]),
		"peste": _alt("Peste", "malus", 4, [_b("degats_par_tour", {"type": "chaos", "fixe": 1, "pv_max": 0.03}),
			_b("contagion", {"chance": 0.35})]),
		"engelure": _alt("Engelure", "malus", 3, [_b("degats_par_tour", {"type": "froid", "fixe": 1, "pv_max": 0.025, "cumul": "demi"}),
			_b("esquive", {"valeur": -0.05})], 3),
		"trauma": _alt("Trauma interne", "malus", 3, [_b("degats_par_tour", {"type": "contondant", "fixe": 1, "pv_max": 0.02})]),
		"siphon de vie": _alt("Siphon de vie", "malus", 3, [_b("degats_par_tour", {"type": "ombre", "fixe": 1, "pv_max": 0.02}),
			_b("drain", {"valeur": 0.50})]),
		"brûlure de mana": _alt("Brûlure de mana", "malus", 3, [_b("fuite_de_mana", {"mana_max": 0.12, "fixe": 1,
			"degats_par_mana": 2, "type": "arcane"})]),
		"désarmement": _alt("Désarmement", "malus", 2, [_b("baisse", {"stat": "degats_physiques", "valeur": 0.40})]),
		"esprit embrumé": _alt("Esprit embrumé", "malus", 3, [_b("baisse", {"stat": "degats_magiques", "valeur": 0.40}),
			_b("baisse", {"stat": "degats_elementaires", "valeur": 0.40}), _b("critique_magique", {"valeur": -0.05})]),
		"décrépitude": _alt("Décrépitude", "malus", 3, [_b("degats_infliges", {"valeur": -0.15}),
			_b("degats_recus", {"valeur": 0.15}), _b("perte_pa", {"chance": 0.25})]),
		"flétrissement": _alt("Flétrissement", "malus", 4, [_b("baisse", {"stat": "pv_max", "valeur": 0.15})]),
		# ---------------------------- Bonus ----------------------------
		"bonus de chance de toucher": _alt("Bonus de chance de toucher", "bonus", 3, [_b("toucher", {"valeur": 0.35})]),
		"résistance physique": _alt("Résistance physique", "bonus", 3,
			[_b("resistance", {"type": "physique", "valeur": 0.40, "selon_puissance": true})], 1, 40),
		"résistance magique et élémentaire": _alt("Résistance magique et élémentaire", "bonus", 3,
			[_b("resistance", {"type": "magique", "valeur": 0.30, "selon_puissance": true}),
			_b("resistance", {"type": "elementaire", "valeur": 0.30, "selon_puissance": true})], 1, 30),
		"rage": _alt("Rage", "bonus", 3, [_b("degats_infliges", {"valeur": 0.25}), _b("degats_critiques", {"valeur": 0.25})]),
		"hâte": _alt("Hâte", "bonus", 2, [_b("gain_pa", {"nombre": 1})]),
		"régénération": _alt("Régénération", "bonus", 3, [_b("soin_par_tour", {"pv_max": 0.06})]),
		"bouclier": _alt("Bouclier", "bonus", 3, [_b("bouclier", {"points": 30, "selon_puissance": true})], 1, 30),
		"bonus de chance de coup critique": _alt("Bonus de chance de coup critique", "bonus", 3, [_b("critique", {"valeur": 0.15})]),
		"bonus d'esquive": _alt("Bonus d'esquive", "bonus", 2, [_b("esquive", {"valeur": 0.20})]),
		"bonus de parade": _alt("Bonus de parade", "bonus", 3, [_b("parade", {"valeur": 0.15})]),
		"épines": _alt("Épines", "bonus", 3, [_b("epines", {"valeur": 0.25})]),
		"bénédiction": _alt("Bénédiction", "bonus", 3, [_b("toucher", {"valeur": 0.10}), _b("degats_infliges", {"valeur": 0.10}),
			_b("resistance", {"type": "magique", "valeur": 0.10})]),
		"soif de sang": _alt("Soif de sang", "bonus", 3, [_b("vol_de_vie", {"valeur": 0.20})]),
		"clarté": _alt("Clarté", "bonus", 3, [_b("mana_par_tour", {"mana_max": 0.10})]),
	}
	for element in Alterations.VULNERABILITES_ELEMENTS:
		var nom: String = Alterations.VULNERABILITES_ELEMENTS[element][0]
		d[nom] = _alt(_maj(nom), "malus", 4, [_b("vulnerabilite", {"type": element, "valeur": Alterations.VULNERABILITE_ELEMENT})])
	for groupe in Alterations.VULNERABILITES_GROUPES:
		var g: Array = Alterations.VULNERABILITES_GROUPES[groupe]
		var stat_g: String = "elementaire" if groupe == "élémentaire" else groupe
		d[g[0]] = _alt(_maj(g[0]), "malus", 4, [_b("vulnerabilite", {"type": stat_g, "valeur": Alterations.VULNERABILITE_GROUPE})])
	for r in Alterations.REDUCTIONS_CARACTERISTIQUES:
		d[r[0]] = _alt(_maj(r[0]), "malus", 4, _caracs(r[1], -float(r[2]), -1.0), 5)
	for carac in Alterations.BONUS_CARACTERISTIQUES:
		var nom_b: String = Alterations.BONUS_CARACTERISTIQUES[carac]
		d[nom_b] = _alt(_maj(nom_b), "bonus", 4, _caracs([carac], 0.07, 1.0), 5)
	_composees = d
	return _composees


# ---------------------------------------------------------------------------
# Développer : morceaux → briques (les altérations citées, à leur puissance)
# ---------------------------------------------------------------------------

## Briques d'une altération brute, les altérations citées remplacées par leurs briques mises à l'échelle.
static func developper(brute: Dictionary, brutes: Dictionary, facteur := 1.0, pile := []) -> Array:
	var liste := []
	for m in brute.get("briques", []):
		if not (m is Dictionary):
			continue
		if m.has("alteration"):
			var nom := String(m["alteration"])
			if nom in pile or not brutes.has(nom):
				continue  # boucle (une altération qui se cite elle-même) ou altération disparue
			liste.append_array(developper(brutes[nom], brutes, facteur * float(m.get("puissance", 100)) / 100.0, pile + [nom]))
		elif BRIQUES.has(String(m.get("brique", ""))):
			liste.append(_a_l_echelle(m, facteur))
	return liste


## Copie d'une brique, valeurs multipliées par ``facteur`` (dés : facteur appliqué aux dégâts).
static func _a_l_echelle(b: Dictionary, facteur: float) -> Dictionary:
	var c := b.duplicate(true)
	if is_equal_approx(facteur, 1.0):
		return c
	var params: Dictionary = BRIQUES[String(b["brique"])]["params"]
	for p in params:
		if params[p] in ["pct", "nombre"] and c.has(p):
			c[p] = float(c[p]) * facteur
	if c.has("des"):
		c["facteur"] = float(c.get("facteur", 1.0)) * facteur
	return c


static func _v(b: Dictionary, cle: String, defaut = 0.0) -> float:
	return float(b.get(cle, defaut))


## Valeur d'une brique « selon la puissance » : celle donnée par la compétence (en %, ou en points pour un bouclier).
static func _valeur(b: Dictionary, p, points := false) -> float:
	if bool(b.get("selon_puissance", false)) and p != null and float(p) > 0:
		var facteur := float(b.get("facteur_puissance", 1.0))
		return float(p) * facteur if points else float(p) / 100.0 * facteur
	return _v(b, "points" if points else "valeur")


# ---------------------------------------------------------------------------
# Construire la définition jouée (Alterations)
# ---------------------------------------------------------------------------

## Définition jouée d'une altération brute : libellé, nature, durée, cumul, description, briques développées et effets
## (modifs, dots, fins, soin_tour, mana_tour, perte_tour, perte_pa, gain_pa, sortant, entrant, soins_recus, bouclier,
## epines, vol_de_vie, marque, silence, reveil, draine, contagion).
static func construire(brute: Dictionary, brutes: Dictionary, nom := "") -> Dictionary:
	var briques := developper(brute, brutes, 1.0, [nom])
	# Une brique « selon la puissance » dans une altération citée garde sa part de la puissance (ex. 70 %)
	var d := {"libelle": String(brute.get("libelle", nom)), "nature": String(brute.get("nature", "malus")),
		"duree": int(brute.get("duree", 3)), "cumul_max": int(brute.get("cumul_max", 1)), "briques": briques}
	if brute.has("puissance"):
		d["puissance"] = brute["puissance"]
	var stats := []
	var dots := []
	var fins := []
	var soins := []
	var manas := []
	var garde_tour := 1.0
	var perte_pa := 0.0
	var gain_pa := 0.0
	var sortant := 1.0
	var entrant := 1.0
	var soins_recus := 1.0
	var epines := 0.0
	var vol := 0.0
	var marque := 0.0
	var draine := 0.0
	var contagion := 0.0
	for b in briques:
		match String(b["brique"]):
			"degats_par_tour":
				dots.append(_dot.bind(b))
			"fuite_de_mana":
				dots.append(_dot_fuite_mana.bind(b))
				manas.append(func(porteur, _data, _i): return -_mana_brule(porteur, b))
			"degats_fin":
				fins.append(func(porteur, data): return [String(b.get("type", "ombre")),
					porteur.points_de_vie_max * _v(b, "pv_max") + float(data.get("puissance", 0))])
			"soin_par_tour":
				soins.append(b)
			"mana_par_tour":
				manas.append(func(porteur, _data, _i):
					var part := _v(b, "mana_max")
					var montant: int = maxi(1, int(porteur.mana_max * absf(part)))
					return montant if part >= 0 else -montant)
			"perte_tour":
				garde_tour *= 1.0 - clampf(_v(b, "chance"), 0.0, 1.0)
			"perte_pa":
				perte_pa += _v(b, "chance")
			"gain_pa":
				gain_pa += _v(b, "nombre")
			"degats_infliges":
				sortant *= 1.0 + _v(b, "valeur")
			"degats_recus":
				entrant *= 1.0 + _v(b, "valeur")
			"soins_recus":
				soins_recus *= 1.0 + _v(b, "valeur")
			"bouclier":
				d["bouclier"] = true
				if not bool(b.get("selon_puissance", false)) or not d.has("puissance"):
					d["puissance"] = _v(b, "points")
			"epines":
				epines += _v(b, "valeur")
			"vol_de_vie":
				vol += _v(b, "valeur")
			"marque":
				marque += _v(b, "valeur")
			"silence":
				d["silence"] = true
			"reveil":
				d["reveil"] = true
			"drain":
				draine += _v(b, "valeur")
			"contagion":
				contagion = maxf(contagion, _v(b, "chance"))
			_:
				stats.append(b)
	if not stats.is_empty():
		d["modifs"] = func(c, p, n, i): return _modifs(stats, c, p, n, i)
		d["caracteristiques"] = stats.any(func(b): return b["brique"] == "caracteristique")
	if not dots.is_empty():
		d["dots"] = dots
	if not fins.is_empty():
		d["fins"] = fins
	if not soins.is_empty():
		d["soin_tour"] = func(porteur, data, _i):
			var total := float(data.get("puissance", 0))
			for s in soins:
				total += porteur.points_de_vie_max * _v(s, "pv_max")
			return total
	if not manas.is_empty():
		d["mana_tour"] = func(porteur, data, i):
			var total := 0
			for m in manas:
				total += int(m.call(porteur, data, i))
			return total
	if garde_tour < 1.0:
		d["perte_tour"] = 1.0 - garde_tour
	if perte_pa > 0:
		d["perte_pa"] = perte_pa
	if gain_pa > 0:
		d["gain_pa"] = int(round(gain_pa))
	for paire in [["sortant", sortant], ["entrant", entrant], ["soins_recus", soins_recus]]:
		if not is_equal_approx(paire[1], 1.0):
			d[paire[0]] = paire[1]
	for paire in [["epines", epines], ["vol_de_vie", vol], ["marque", marque], ["draine", draine], ["contagion", contagion]]:
		if paire[1] > 0:
			d[paire[0]] = paire[1]
	d["description"] = decrire(d, d.get("puissance", null))
	return d


## Modifications des statistiques (× cumul, × intensité des talents).
static func _modifs(stats: Array, c, p, n, i) -> Dictionary:
	var m := {}
	var cumul := float(n)
	var intensite := float(i)
	for b in stats:
		var id := String(b["brique"])
		if BRIQUES[id].has("stat"):
			var s: String = BRIQUES[id]["stat"]
			m[s] = m.get(s, 0.0) + _valeur(b, p) * cumul * intensite
		elif id == "vulnerabilite":
			var s := "vulnerabilite_" + String(b.get("type", "feu"))
			m[s] = m.get(s, 0.0) + _valeur(b, p) * cumul * intensite
		elif id == "resistance":
			var s := "resistance_pct_" + String(b.get("type", "physique"))
			m[s] = m.get(s, 0.0) + _valeur(b, p) * cumul * intensite
		elif id == "baisse":
			var part := clampf(_v(b, "valeur") * intensite, 0.0, 1.0)
			for s in STATS_BAISSE.get(String(b.get("stat", "armure")), ["", []])[1]:
				m[s] = m.get(s, 0.0) - maxf(0.0, U.num(c, s)) * part
		elif id == "caracteristique":
			var part := _v(b, "part")
			var fixe := _v(b, "fixe")
			var signe := -1 if (part < 0 or (part == 0 and fixe < 0)) else 1
			var carac := String(b.get("carac", "force"))
			if Alterations.CONVERSIONS.has(carac):
				var r := Alterations._caracteristiques(c, [carac], absf(part) * intensite, absf(fixe) * intensite, cumul, signe)
				for s in r:
					m[s] = m.get(s, 0.0) + r[s]
	return m


static func _dot(porteur, data: Dictionary, index, b: Dictionary) -> Array:
	var cumul := int(data.get("cumul", 1))
	var mode := String(b.get("cumul", "aucun"))
	var cm := cumul if mode == "multiplie" else 1
	var montant: float = _v(b, "fixe") + porteur.points_de_vie_max * _v(b, "pv_max") * cm \
		+ porteur.points_de_vie * _v(b, "pv_actuels") + float(data.get("puissance", 0))
	var des = b.get("des", null)
	if des is Array and des.size() == 2 and int(des[0]) > 0:
		montant += Formules.jet([[int(des[0]) * cm, int(des[1])]]) * float(b.get("facteur", 1.0))
	if mode == "demi":
		montant *= 1 + 0.5 * (cumul - 1)
	if bool(b.get("croissant", false)):
		montant *= float(index)
	return [String(b.get("type", "feu")), montant]


static func _mana_brule(porteur, b: Dictionary) -> int:
	return maxi(0, mini(int(porteur.mana), maxi(1, int(porteur.mana_max * _v(b, "mana_max")))))


static func _dot_fuite_mana(porteur, data: Dictionary, _index, b: Dictionary) -> Array:
	return [String(b.get("type", "arcane")), _v(b, "fixe") + _v(b, "degats_par_mana") * _mana_brule(porteur, b)
		+ float(data.get("puissance", 0))]


# ---------------------------------------------------------------------------
# Descriptions (toujours tirées des briques)
# ---------------------------------------------------------------------------

static func _pct(v: float, signe := true) -> String:
	var t := U.g(snappedf(v * 100.0, 0.1)).replace(".", ",")
	return ("+" if signe and v > 0 else "") + t + " %"


static func _signe(v: float) -> String:
	return ("+" if v > 0 else "") + U.g(snappedf(v, 0.01)).replace(".", ",")


## Phrase d'une brique (``p`` : puissance donnée par la compétence).
static func phrase(b: Dictionary, p = null) -> String:
	var id := String(b.get("brique", ""))
	if not BRIQUES.has(id):
		return ""
	var spec: Dictionary = BRIQUES[id]
	match id:
		"vulnerabilite":
			return "Dégâts %s reçus %s" % [NOMS_TYPES.get(String(b.get("type", "")), b.get("type", "")), _pct(_valeur(b, p))]
		"resistance":
			return "Dégâts %s reçus %s" % [NOMS_TYPES.get(String(b.get("type", "")), b.get("type", "")), _pct(-_valeur(b, p))]
		"baisse":
			return "%s -%s" % [STATS_BAISSE.get(String(b.get("stat", "")), [b.get("stat", "")])[0], _pct(_v(b, "valeur"), false)]
		"caracteristique":
			var nom := String(Caracteristiques.NOMS.get(String(b.get("carac", "")), b.get("carac", "")))
			var part := _v(b, "part")
			var fixe := _v(b, "fixe")
			var morceaux := []
			if part != 0:
				morceaux.append(_pct(part))
			if fixe != 0:
				morceaux.append(_signe(fixe))
			return "%s %s par cumul, avec ses effets" % [nom, " ".join(morceaux)]
		"degats_par_tour":
			var parts := []
			if _v(b, "fixe") != 0:
				parts.append(U.g(snappedf(_v(b, "fixe"), 0.1)).replace(".", ","))
			if _v(b, "pv_max") != 0:
				parts.append("%s des PV max" % _pct(_v(b, "pv_max"), false))
			if _v(b, "pv_actuels") != 0:
				parts.append("%s des PV actuels" % _pct(_v(b, "pv_actuels"), false))
			var des = b.get("des", null)
			if des is Array and des.size() == 2 and int(des[0]) > 0:
				parts.append("%dd%d" % [int(des[0]), int(des[1])] + ("" if is_equal_approx(float(b.get("facteur", 1.0)), 1.0)
					else " × %s" % U.g(snappedf(float(b.get("facteur", 1.0)), 0.01)).replace(".", ",")))
			var t := "Dégâts %s à chaque tour : %s" % [NOMS_TYPES.get(String(b.get("type", "")), "de " + String(b.get("type", ""))),
				" + ".join(parts) if not parts.is_empty() else "0"]
			match String(b.get("cumul", "aucun")):
				"multiplie":
					t += " (× le cumul)"
				"demi":
					t += " (+50 % par cumul)"
			if bool(b.get("croissant", false)):
				t += ", × le numéro du tour"
			return t
		"soin_par_tour":
			return "Rend %s des PV max à chaque tour" % _pct(_v(b, "pv_max"), false)
		"mana_par_tour":
			var v := _v(b, "mana_max")
			return "%s %s du mana max à chaque tour" % ["Rend" if v >= 0 else "Perd", _pct(absf(v), false)]
		"fuite_de_mana":
			return "Perd %s de son mana max à chaque tour et subit %s + %s dégâts %s par point de mana perdu" % [
				_pct(_v(b, "mana_max"), false), U.g(_v(b, "fixe")), U.g(_v(b, "degats_par_mana")),
				NOMS_TYPES.get(String(b.get("type", "arcane")), "")]
		"perte_tour":
			var c := _v(b, "chance")
			return "Perd son tour" if c >= 1.0 else "%s de chance de perdre son tour" % _pct(c, false)
		"perte_pa":
			var c := _v(b, "chance")
			return "Perd 1 PA à chaque tour" if is_equal_approx(c, 1.0) else "%s de chance de perdre 1 PA à chaque tour" % _pct(c, false)
		"gain_pa":
			return "%s PA à chaque tour" % _signe(_v(b, "nombre"))
		"degats_infliges":
			return "Dégâts infligés %s" % _pct(_v(b, "valeur"))
		"degats_recus":
			return "Dégâts reçus %s" % _pct(_v(b, "valeur"))
		"soins_recus":
			return "Soins reçus %s" % _pct(_v(b, "valeur"))
		"bouclier":
			return "Absorbe %s dégâts avant de se briser" % U.g(snappedf(_valeur(b, p, true), 0.1))
		"epines":
			return "Renvoie %s des dégâts physiques reçus à l'attaquant" % _pct(_v(b, "valeur"), false)
		"vol_de_vie":
			return "Rend %s des dégâts infligés en PV" % _pct(_v(b, "valeur"), false)
		"marque":
			return "Les coups qu'il reçoit ont %s de chance d'être critiques" % _pct(_v(b, "valeur"))
		"silence":
			return "Ne peut plus lancer de sort offensif ni de soin"
		"reveil":
			return "Le premier coup qui le blesse met fin à l'altération"
		"degats_fin":
			return "S'il dure jusqu'au bout : %s de ses PV max en dégâts %s" % [_pct(_v(b, "pv_max"), false),
				NOMS_TYPES.get(String(b.get("type", "")), "")]
		"drain":
			return "Le lanceur récupère %s des PV retirés" % _pct(_v(b, "valeur"), false)
		"contagion":
			return "%s de chance par tour de contaminer un allié" % _pct(_v(b, "chance"), false)
	if spec.has("stat"):
		return "%s %s" % [spec["libelle"], _pct(_valeur(b, p))]
	return String(spec["libelle"])


## Description d'une définition (ou d'une brute développée) : ses briques, puis le cumul.
static func decrire(d: Dictionary, p = null) -> String:
	var phrases := []
	for b in d.get("briques", []):
		var t := phrase(b, p)
		if t != "":
			# Après la première phrase : minuscule, sauf sigle (« PV max »)
			if not phrases.is_empty() and t.length() > 1 and t.substr(1, 1) == t.substr(1, 1).to_lower():
				t = t.substr(0, 1).to_lower() + t.substr(1)
			phrases.append(t)
	var texte := " ; ".join(phrases) + "." if not phrases.is_empty() else "Aucun effet."
	if int(d.get("cumul_max", 1)) > 1:
		texte += " Cumulable %d fois." % int(d["cumul_max"])
	return texte.substr(0, 1).to_upper() + texte.substr(1)


## Briques primaires par famille : [[famille, [id...]], ...].
static func par_famille() -> Array:
	var liste := []
	for f in FAMILLES:
		var ids := []
		for id in BRIQUES:
			if BRIQUES[id]["famille"] == f:
				ids.append(id)
		liste.append([f, ids])
	return liste
