class_name Degats
extends RefCounted
## Réduction et application des dégâts (règles de l'utilisateur, 2026-10-30).
##
## Trois grands types de dégâts : physique (tranchant, perforant, contondant), magique (arcane, ombre, chaos),
## élémentaire (feu, froid, foudre).
##
## 1. **Pourcentages** (d'abord, sur les dégâts du coup) : les vulnérabilités (``vulnerabilite_<type>`` ou
##    ``vulnerabilite_<groupe>``, 0,40 = +40 %) augmentent les dégâts subis ; les résistances en pourcentage
##    (``resistance_pct_<type>`` ou ``resistance_pct_<groupe>``) les diminuent, 75 % au plus. Elles s'additionnent
##    entre elles : +50 % de faiblesse et 40 % de résistance = +10 %. Elles ne touchent ni l'armure ni les résistances.
## 2. **Blocage en points** (ensuite) : 2 points bloquent 1 dégât. Défense générale du groupe (armure, résistance
##    magique, résistance élémentaire) ou résistance spécifique du type (``resistance_<type>``) : elles **ne se
##    cumulent pas**, la meilleure des deux compte (3 d'armure et 1 de résistance tranchant = −1). La pénétration
##    (d'armure contre le physique, de résistance sinon) retire des points aux deux avant le calcul.
##
## Lumière (soins), brut, saignement et poison ne sont ni bloqués ni modifiés (plus de résistance au poison).
##
## Chaque fonction ``recevoir_degats_*`` est observée par EffetsCombat (PV avant
## et après), comme l'enveloppe de effets_combat.py.

const PHYSIQUES := ["tranchant", "perforant", "contondant"]
const MAGIQUES := ["arcane", "ombre", "chaos"]
const ELEMENTAIRES := ["feu", "froid", "foudre"]
const TYPES := PHYSIQUES + MAGIQUES + ELEMENTAIRES
const GROUPES := {"physique": PHYSIQUES, "magique": MAGIQUES, "elementaire": ELEMENTAIRES}
## Défense générale de chaque groupe.
const DEFENSES := {"physique": "armure", "magique": "resistance_magique", "elementaire": "resistance_elementaire"}
const NOMS_GROUPES := {"physique": "physiques", "magique": "magiques", "elementaire": "élémentaires"}
## Points de défense pour bloquer 1 dégât.
const POINTS_PAR_DEGAT := 2
const PLAFOND_RESISTANCE_POURCENT := 0.75
const NON_REDUITS := ["brut", "saignement", "lumière", "poison", null]


## Groupe d'un type de dégâts : « physique », « magique », « elementaire » ou "" (lumière, poison, brut...).
static func groupe(type_degats) -> String:
	for g in GROUPES:
		if type_degats in GROUPES[g]:
			return g
	return ""


## Défense générale opposée à un type de dégâts : [nom de l'attribut, valeur] (["", 0] sans défense).
static func defense(cible, type_degats) -> Array:
	var g := groupe(type_degats)
	if g == "":
		return ["", 0.0]
	return [DEFENSES[g], U.num(cible, DEFENSES[g])]


## Dégâts bloqués : la meilleure entre la défense générale et la résistance spécifique, 1 dégât par
## POINTS_PAR_DEGAT points, après pénétration.
static func reduction_fixe(cible, type_degats, penetration_armure = 0, penetration_resistance = 0) -> int:
	var d := defense(cible, type_degats)
	if d[0] == "":
		return 0
	var pen = penetration_armure if type_degats in PHYSIQUES else penetration_resistance
	var p := maxf(0, 0.0 if pen == null else float(pen))
	var generale := maxf(0, float(d[1]) - p)
	var specifique := maxf(0, U.num(cible, "resistance_" + type_degats) - p)
	return maxi(floori(generale / POINTS_PAR_DEGAT), floori(specifique / POINTS_PAR_DEGAT))


## Total des vulnérabilités (type et groupe) d'une cible pour un type de dégâts (0,40 = +40 %).
static func vulnerabilite(cible, type_degats) -> float:
	var g := groupe(type_degats)
	if g == "":
		return 0.0
	return U.num(cible, "vulnerabilite_" + type_degats) + U.num(cible, "vulnerabilite_" + g)


## Total des résistances en pourcentage (type et groupe), plafonné à PLAFOND_RESISTANCE_POURCENT.
static func resistance_pourcent(cible, type_degats) -> float:
	var g := groupe(type_degats)
	if g == "":
		return 0.0
	return minf(PLAFOND_RESISTANCE_POURCENT, U.num(cible, "resistance_pct_" + type_degats) + U.num(cible, "resistance_pct_" + g))


## Multiplicateur des dégâts subis : 1 + vulnérabilités − résistances en pourcentage (jamais négatif).
static func multiplicateur(cible, type_degats) -> float:
	return maxf(0.0, 1.0 + vulnerabilite(cible, type_degats) - resistance_pourcent(cible, type_degats))


## Vulnérabilités et résistances en pourcentage non nulles d'un combattant, par type ou groupe :
## {"vulnerabilites": {type: 0,40...}, "resistances": {type: 0,20...}} (fiches et écrans).
static func pourcentages(combattant) -> Dictionary:
	var v := {}
	var r := {}
	for t in TYPES + GROUPES.keys():
		var a := U.num(combattant, "vulnerabilite_" + t)
		var b := U.num(combattant, "resistance_pct_" + t)
		if a != 0:
			v[t] = a
		if b != 0:
			r[t] = b
	return {"vulnerabilites": v, "resistances": r}


## Ajoute des vulnérabilités et des résistances en pourcentage ({type: fraction}) à un combattant.
static func ajouter_pourcentages(combattant, vulnerabilites: Dictionary, resistances: Dictionary) -> void:
	for t in vulnerabilites:
		combattant._d["vulnerabilite_" + t] = U.num(combattant, "vulnerabilite_" + t) + float(vulnerabilites[t])
	for t in resistances:
		combattant._d["resistance_pct_" + t] = U.num(combattant, "resistance_pct_" + t) + float(resistances[t])


## Part des dégâts retirée par les pourcentages (négative pour une faiblesse) : 1 − multiplicateur.
static func reduction_degats(cible, type_degats, _penetration_armure = 0, _penetration_resistance = 0, _etage = null) -> float:
	return 1.0 - multiplicateur(cible, type_degats)


## Dégâts subis : pourcentages d'abord, puis blocage en points.
static func degats_subis(cible, type_degats, degats, penetration_armure = 0, penetration_resistance = 0) -> float:
	var modifies := maxf(0, float(degats) * multiplicateur(cible, type_degats))
	return maxf(0, modifies - reduction_fixe(cible, type_degats, penetration_armure, penetration_resistance))


# ---------------------------------------------------------------------------
# Recevoir_degats
# ---------------------------------------------------------------------------

## « Esprit sur la matière » : le mana absorbe des dégâts avant les PV.
static func absorber_par_mana(cible, degats) -> int:
	var restant := Talents.absorber_par_mana(cible, degats)
	Statistiques.noter(cible, "degats_absorbes_mana", degats - restant)
	Statistiques.noter(cible, "degats_subis", maxi(0, restant))
	return restant


## « Dernier rempart » : un coup mortel laisse la cible à 1 PV (une fois par combat).
static func dernier_rempart(cible) -> bool:
	return Talents.dernier_rempart(cible)


## Retire des PV déjà arrondis, puis gère la mort de la cible et la fin éventuelle du combat.
static func _encaisser(cible, montant: int, message: String, combat, maj_liste: bool) -> void:
	if U.ga(cible, "invulnerable", false):
		montant = 0
		message = "%s ne semble rien sentir." % cible.nom
	var plafond = U.ga(cible, "plafond_degats", null)
	if plafond is Array and montant > 0:
		# Chevalier de la mort : chaque coup est ramené à 1 ou 2 dégâts, 3 sur un coup critique
		var limite: int = int(U.ga(cible, "plafond_degats_critique", 3)) if EffetsCombat.critique else randi_range(int(plafond[0]), int(plafond[1]))
		if montant > limite:
			montant = limite
			message = "%s encaisse le coup sans broncher (%d)." % [cible.nom, montant]
	cible.points_de_vie -= absorber_par_mana(cible, montant)
	print(message)
	dernier_rempart(cible)
	if cible.points_de_vie <= 0:
		if cible in combat.ennemis:
			cible.mort_au_combat(combat.donjon)
			if maj_liste:
				combat.maj_liste_ennemis()
		elif cible == combat.personnage:
			print("Vous êtes mort.")
			combat.condition_defaite()
	combat.verification_des_vivants()


## Observe un coup pour les animations : PV avant l'application, signalé après.
static func _observer(cible, type_anim: String, combat, application: Callable) -> void:
	if combat == null:
		application.call()
		return
	var vivant: bool = cible.est_vivant()
	var avant = cible.points_de_vie
	var est_joueur: bool = cible == combat.personnage
	var mortel_avant: bool = U.ga(cible, "points_de_vie", 1) <= 0
	application.call()
	if vivant and not mortel_avant:
		var perdus = avant - cible.points_de_vie
		var mortel: bool = not est_joueur and cible.points_de_vie <= 0
		EffetsCombat.signaler(cible, type_anim, perdus, est_joueur, mortel)


static func recevoir_degats_brut(cible, degats_brut, combat) -> void:
	_observer(cible, "poison", combat, func():
		if cible.est_vivant():
			var arrondi := ceili(degats_brut)
			_encaisser(cible, arrondi, "%s subit %d points de dégâts directs." % [cible.nom, arrondi], combat, true))


static func recevoir_degats_saignement(cible, degats, combat) -> void:
	_observer(cible, "saignement", combat, func():
		if cible.est_vivant():
			var arrondi := ceili(degats)
			_encaisser(cible, arrondi, "%s subit %d points de dégâts de saignement." % [cible.nom, arrondi], combat, true))


## Dégâts physiques (tranchant, perforant, contondant) : pourcentages, puis armure ou résistance du type.
static func recevoir_degats_physique(type_degats: String, cible, degats, penetration_armure, penetration_resistance, combat, _lanceur = null) -> void:
	_observer(cible, type_degats, combat, func():
		if cible.est_vivant():
			var reduits := degats_subis(cible, type_degats, degats, penetration_armure, penetration_resistance)
			var arrondi := ceili(reduits)
			_encaisser(cible, arrondi, "%s subit %d points de dégâts %s." % [cible.nom, arrondi, type_degats], combat, false))


## Dégâts magiques et élémentaires : pourcentages, puis résistance du groupe ou du type.
static func recevoir_degats_element(type_degats: String, cible, degats, penetration_resistance, combat) -> void:
	_observer(cible, type_degats, combat, func():
		if cible.est_vivant():
			var reduits := degats_subis(cible, type_degats, degats, 0, penetration_resistance)
			var arrondi := ceili(reduits)
			_encaisser(cible, arrondi, "%s subit %d points de dégâts %s." % [cible.nom, arrondi, type_degats], combat, false))


static func recevoir_degats_poison(cible, degats, penetration_resistance, combat) -> void:
	_observer(cible, "poison", combat, func():
		if cible.est_vivant():
			var subis := ceili(degats_subis(cible, "poison", degats, 0, penetration_resistance))
			_encaisser(cible, subis, "%s subit %d points de dégâts de poison." % [cible.nom, subis], combat, true))


## « Dégâts » de lumière : soignent la cible (PV × (1 + pénétration × 0,02), plafonnés).
static func recevoir_degats_lumiere(cible, degats, penetration_resistance, combat) -> void:
	_observer(cible, "lumière", combat, func():
		if cible.est_vivant():
			var recuperes = degats + degats * float(penetration_resistance) * 0.02
			cible.points_de_vie += recuperes
			if cible.points_de_vie > cible.points_de_vie_max:
				cible.points_de_vie = cible.points_de_vie_max
			print("%s récupère %s points de vie." % [cible.nom, U.g(recuperes)]))


## Applique des dégâts d'un type quelconque (aiguillage vers la bonne fonction).
static func recevoir(type_degats: String, cible, degats, penetration_armure, penetration_resistance, combat, lanceur = null) -> void:
	if type_degats == "brut":
		recevoir_degats_brut(cible, degats, combat)
	elif type_degats == "saignement":
		recevoir_degats_saignement(cible, degats, combat)
	elif type_degats in PHYSIQUES:
		recevoir_degats_physique(type_degats, cible, degats, penetration_armure, penetration_resistance, combat, lanceur)
	elif type_degats == "poison":
		recevoir_degats_poison(cible, degats, penetration_resistance, combat)
	elif type_degats == "lumière":
		recevoir_degats_lumiere(cible, degats, penetration_resistance, combat)
	else:
		recevoir_degats_element(type_degats, cible, degats, penetration_resistance, combat)
