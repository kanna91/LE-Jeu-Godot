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
	"intelligence": "intelligence", "sagesse": "sagesse", Caracteristiques.MANA: "mana"}
## Une vulnérabilité par élément (2026-11-06, demande de l'utilisateur : plus clair que Inflammabilité, Conductivité...).
const VULNERABILITES_ELEMENTS := {"feu": ["vulnérabilité au feu", "de feu"], "froid": ["vulnérabilité au froid", "de froid"],
	"foudre": ["vulnérabilité à la foudre", "de foudre"], "arcane": ["vulnérabilité à l'arcane", "d'arcane"],
	"chaos": ["vulnérabilité au chaos", "de chaos"], "ombre": ["vulnérabilité à l'ombre", "d'ombre"]}
const VULNERABILITE_ELEMENT := 0.25
## Vulnérabilités par groupe de types (2026-11-06) : physique (tranchant, perforant, contondant), élémentaire (feu,
## froid, foudre), magique (arcane, chaos, ombre) ; « vulnérabilité totale » (ancienne « vulnérabilité ») : tout.
const VULNERABILITES_GROUPES := {"physique": ["vulnérabilité physique", "physiques", ["tranchant", "perforant", "contondant"]],
	"élémentaire": ["vulnérabilité élémentaire", "élémentaires (feu, froid, foudre)", ["feu", "froid", "foudre"]],
	"magique": ["vulnérabilité magique", "magiques (arcane, chaos, ombre)", ["arcane", "chaos", "ombre"]]}
const VULNERABILITE_GROUPE := 0.20
## Réductions de caractéristique (2026-11-06, demande de l'utilisateur) : [nom, caractéristiques, part par cumul].
## Valeurs gardées par l'utilisateur : -7 % +1 par cumul pour une caractéristique, -5 % pour deux ou trois, -4 % pour
## toutes (5 cumuls, 4 tours). Remplacent Sape de force, Engourdissement, Épuisement vital, Torpeur, Trouble de
## l'esprit, Déchéance, Dissonance et Entropie ; Faiblesse, Maladresse et Débilité (doublons) sont supprimées.
const REDUCTIONS_CARACTERISTIQUES := [
	["réduction de force", ["force"], 0.07],
	["réduction de dextérité", ["dextérité"], 0.07],
	["réduction d'endurance", ["endurance"], 0.07],
	["réduction d'intelligence", ["intelligence"], 0.07],
	["réduction de sagesse", ["sagesse"], 0.07],
	["réduction de mana", [Caracteristiques.MANA], 0.07],
	["réduction de force et de dextérité", ["force", "dextérité"], 0.05],
	["réduction d'intelligence et de sagesse", ["intelligence", "sagesse"], 0.05],
	["réduction d'endurance et de force", ["endurance", "force"], 0.05],
	["réduction de dextérité et d'endurance", ["dextérité", "endurance"], 0.05],
	["réduction d'endurance et de mana", ["endurance", Caracteristiques.MANA], 0.05],
	["réduction de sagesse et de mana", ["sagesse", Caracteristiques.MANA], 0.05],
	["réduction d'intelligence et de mana", ["intelligence", Caracteristiques.MANA], 0.05],
	["réduction de force, de dextérité et d'endurance", ["force", "dextérité", "endurance"], 0.05],
	["réduction d'intelligence, de sagesse et de mana", ["intelligence", "sagesse", Caracteristiques.MANA], 0.05],
	["réduction de toutes les caractéristiques", ["endurance", "force", "dextérité", "intelligence", "sagesse",
		Caracteristiques.MANA], 0.04],
]
## Un bonus par caractéristique (2026-11-06 : remplace Vigueur, Agilité, Robustesse, Intellect, Sérénité et les bonus
## combinés).
const BONUS_CARACTERISTIQUES := {"force": "bonus de force", "dextérité": "bonus de dextérité",
	"endurance": "bonus d'endurance", "intelligence": "bonus d'intelligence", "sagesse": "bonus de sagesse",
	Caracteristiques.MANA: "bonus de mana"}

const ALIAS := {
	"destruction_résistance": "destruction résistance", "recupe": "régénération", "recupeé": "régénération",
	"aveuglement": "aveugler", "étourdissement": "stun", "brûlure": "brulure", "vulnerabilite": "vulnérabilité totale",
	"trauma interne": "trauma", "brulure de mana": "brûlure de mana",
	# Anciens noms (2026-11-06)
	"inflammabilité": "vulnérabilité au feu", "morsure du givre": "vulnérabilité au froid",
	"conductivité": "vulnérabilité à la foudre", "vulnérabilité": "vulnérabilité totale", "vigueur": "bonus de force", "agilité": "bonus de dextérité",
	"robustesse": "bonus d'endurance", "intellect": "bonus d'intelligence", "sérénité": "bonus de sagesse",
	"précis": "bonus de chance de toucher", "concentration": "bonus de chance de coup critique", "évasion": "bonus d'esquive",
	"barrière": "résistance magique et élémentaire", "protection": "résistance physique",
	"sape": "réduction de force", "engourdissement": "réduction de dextérité", "épuisement vital": "réduction d'endurance",
	"torpeur": "réduction d'intelligence", "trouble": "réduction de sagesse",
	"déchéance": "réduction d'endurance et de force", "dissonance": "réduction d'intelligence et de sagesse",
	"entropie": "réduction de toutes les caractéristiques",
}

const TYPES_ALTERATIONS := {
	"feu": ["brulure", "vulnérabilité au feu"],
	"froid": ["gel", "engelure", "vulnérabilité au froid", "lenteur", "réduction de dextérité", "pétrification"],
	"foudre": ["électrocution", "paralysie", "vulnérabilité à la foudre", "vulnérabilité élémentaire"],
	"arcane": ["usure magique", "silence", "brûlure de mana", "esprit embrumé", "destruction résistance",
		"vulnérabilité à l'arcane", "réduction d'intelligence", "réduction de sagesse", "réduction de mana",
		"réduction d'intelligence et de sagesse", "réduction d'endurance et de mana", "réduction de sagesse et de mana",
		"réduction d'intelligence et de mana", "réduction d'intelligence, de sagesse et de mana"],
	"chaos": ["corruption", "peste", "vulnérabilité totale", "vulnérabilité au chaos", "vulnérabilité magique"],
	"ombre": ["terreur", "malédiction", "siphon de vie", "condamnation", "flétrissement", "affaiblissement",
		"décrépitude", "aveugler", "réduction de force", "réduction d'endurance", "réduction de force et de dextérité",
		"réduction de dextérité et d'endurance", "réduction de force, de dextérité et d'endurance",
		"réduction de toutes les caractéristiques", "épuisement",
		"vulnérabilité à l'ombre"],
	"poison": ["poison"],
	"tranchant": ["saignement", "désarmement", "usure"],
	"perforant": ["destruction armure", "marque", "vulnérabilité physique"],
	"contondant": ["stun", "trauma", "réduction d'endurance et de force", "sommeil"],
	"lumière": ["régénération", "bouclier", "résistance magique et élémentaire", "bénédiction", "clarté",
		"résistance physique", "bonus de parade", "bonus de force",
		"bonus de dextérité", "bonus d'endurance", "bonus d'intelligence", "bonus de sagesse", "bonus de mana"],
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


## Altérations brutes (BriquesAlterations) : composées du jeu, réglages de l'éditeur (durée, cumul, briques), puis
## altérations personnalisées de l'éditeur (2026-11-06).
static func brutes() -> Dictionary:
	var b := {}
	var composees := BriquesAlterations.composees()
	for nom in composees:
		b[nom] = composees[nom].duplicate(true)
	DonneesEnnemis.appliquer_alterations(b)
	return b


## Définitions jouées (construites une fois depuis les briques : BriquesAlterations.construire).
static func defs() -> Dictionary:
	if not _definitions.is_empty():
		return _definitions
	var b := brutes()
	var d := {}
	for nom in b:
		d[nom] = BriquesAlterations.construire(b[nom], b, nom)
		d[nom]["personnalisee"] = not BriquesAlterations.composees().has(nom)
	_definitions = d
	_type_alteration.clear()
	for element in TYPES_ALTERATIONS:
		for nom in TYPES_ALTERATIONS[element]:
			_type_alteration[nom] = element
	return _definitions


## Oublie les définitions (après un enregistrement de l'éditeur).
static func recharger() -> void:
	_definitions = {}


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
	if d.is_empty():
		return ""
	return BriquesAlterations.decrire(d, d.get("puissance", null) if puissance == null else puissance)


## Catégories de l'éditeur (2026-11-06) : améliorations (bonus), dégâts (blessent à chaque tour ou à la fin), malus.
const CATEGORIES := ["amélioration", "malus", "dégâts"]
const NOMS_CATEGORIES := {"amélioration": "Améliorations", "malus": "Malus", "dégâts": "Dégâts"}


static func categorie(nom: String) -> String:
	var d := definition(nom_canonique(nom))
	if d.get("nature") == "bonus":
		return "amélioration"
	if d.has("dots") or d.has("fins"):
		return "dégâts"
	return "malus"


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
	return d["modifs"].call(cible, puissance, cumul, intensite)


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
	for dot in d.get("dots", []):
		if not cible.est_vivant():
			break
		var resultat: Array = dot.call(cible, data, data["tours"])
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
		_appliquer_modifs(cible, data, appeler_modifs(d, cible, data["puissance"], data["cumul"], data["intensite"]))
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
				if d.has("fins") and cible.est_vivant():
					print("%s : le compte à rebours de %s est écoulé !" % [d["libelle"], cible.nom])
					for fin_tour in d["fins"]:
						var fin: Array = fin_tour.call(cible, data)
						_infliger_dot(cible, fin[0], fin[1] * data.get("intensite", 1.0), data, combat)
	return passe_son_tour


## Altérations actives, prêtes à afficher : [[nom, libellé, durée, cumul, est_bonus], ...].
static func resume(cible) -> Array:
	var liste := []
	for a in _actives(cible):
		liste.append([a[0], a[2]["libelle"], a[1].get("duree", 0), a[1].get("cumul", 1), a[2].get("nature") == "bonus"])
	return liste
