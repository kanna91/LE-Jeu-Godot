class_name Equilibrage
extends RefCounted
## Équilibrage des améliorations : valeur d'une compétence en « dégâts
## équivalents » contre un adversaire de référence.

const NB_ENNEMIS := 2.5
const PART_SOUS_MOITIE := 0.15
const EFFICACITE_SOIN := 0.8
const EFFICACITE_VOL := 0.35
const VALEUR_MANA := 1.5
const PART_CONTAGION := 0.5

const BUDGETS := {1: 0.28, 2: 0.30, 3: 0.32, 4: 0.35, 5: 0.70, 6: 0.38, 7: 0.40, 8: 0.42, 9: 0.45, 10: 0.90}
const BUDGET_VOIE := {"puissance": 1.4, "technique": 1.0, "affliction": 1.0}
const COMPETENCES_DU_JOUEUR := ["Coup_d_epee", "Frenesie", "Coup_de_marteau", "Fracasser", "Coup_de_poing", "Enchainement",
	"Coup_de_lance", "Balayage", "Boule_de_feu", "Soin", "Tempete_de_feu", "Eclair"]

static var _coefficients = null
static var _joueur_ref: Reference = null
static var _ennemi_ref: Reference = null
static var _attaque_ref: Dyn = null
static var _attaques_type := {}


static func coefficients() -> Dictionary:
	if _coefficients == null:
		_coefficients = U.charger_json("coefficients_equilibrage.json")
		if _coefficients == null:
			_coefficients = {}
	return _coefficients


## Coefficient d'efficacité réelle d'un effet (1.0 si non mesuré ou en mode « brut »).
static func coefficient(cle: String, nom = null, brut := false) -> float:
	if brut:
		return 1.0
	var valeur_cle = coefficients().get(cle, 1.0)
	var mesure := 1.0
	if nom != null:
		mesure = valeur_cle.get(Alterations.nom_canonique(nom), 1.0) if valeur_cle is Dictionary else 1.0
	else:
		mesure = float(valeur_cle) if (valeur_cle is float or valeur_cle is int) else 1.0
	return pow(maxf(0.2, minf(3.0, mesure)), 0.75)


static func _resistances(physiques: float, elementaires: float) -> Dictionary:
	var r := {}
	for t in ["tranchant", "perforant", "contondant"]:
		r["resistance_" + t] = physiques
	for t in ["feu", "froid", "foudre", "arcane", "chaos", "ombre"]:
		r["resistance_" + t] = elementaires
	return r


static func joueur_ref() -> Reference:
	if _joueur_ref == null:
		var stats := {"nom": "Héros (référence)", "points_de_vie_max": 440, "points_de_vie": 350, "mana_max": 24, "mana": 24,
			"points_d_action_max": 3, "chance_de_toucher": 0.96, "chance_esquive": 0.08, "chance_de_coup_critique": 0.10,
			"degats_critique": 1.78, "force": 3.1, "puissance_magique": 5.7, "degats_base": 5, "armure": 2.5, "resistance_magique": 2.2,
			"coefficient_reduction_armure": 0.02, "coefficient_reduction_magique": 0.02,
			"chance_de_coup_critique_magique": 0.075, "degats_critique_magiques": 1.91,
			"penetration_armure": 2.1, "penetration_resistance": 0.8}
		stats.merge(_resistances(2.2, 1.4))
		_joueur_ref = Reference.nouvelle(stats)
	return _joueur_ref


static func ennemi_ref() -> Reference:
	if _ennemi_ref == null:
		var stats := {"nom": "Gobelin (référence)", "points_de_vie_max": 214, "points_de_vie": 170, "mana_max": 36, "mana": 36,
			"points_d_action_max": 1.2, "chance_de_toucher": 0.97, "chance_esquive": 0.03, "chance_de_coup_critique": 0.09,
			"degats_critique": 1.6, "force": 1.5, "puissance_magique": 8.3, "degats_base": 3, "armure": 1.4, "resistance_magique": 3.7,
			"coefficient_reduction_armure": 0.02, "coefficient_reduction_magique": 0.02,
			"chance_de_coup_critique_magique": 0.185, "degats_critique_magiques": 1.72,
			"penetration_armure": 2.1, "penetration_resistance": 1.8}
		stats.merge(_resistances(0.8, 2.4))
		_ennemi_ref = Reference.nouvelle(stats)
	return _ennemi_ref


## Attaque de base de référence : moitié tranchante, moitié d'ombre (_AttaqueRef).
static func attaque_ref() -> Dyn:
	if _attaque_ref == null:
		_attaque_ref = Dyn.new()
		_attaque_ref._d = {"type_degats": ["tranchant", "ombre"], "degats_tranchant": 4, "degats_ombre": 4,
			"penetration_armure": 0, "penetration_resistance": 0, "multiplicateur_degats": 1.0,
			"facteurs_types": {"tranchant": 0.5, "ombre": 0.5}, "bonus_toucher": 0.0, "bonus_critique": 0.0,
			"bonus_degats_critique": 0.0}
	return _attaque_ref


## Attaque de référence d'un seul type de dégâts (8 dégâts de ce type).
static func _attaque_de(type_degats: String) -> Dyn:
	if not _attaques_type.has(type_degats):
		var a := Dyn.new()
		a._d = attaque_ref()._d.duplicate()
		a._d["type_degats"] = [type_degats]
		a._d["degats_tranchant"] = 0
		a._d["degats_ombre"] = 0
		a._d["degats_" + type_degats] = 8
		a._d["facteurs_types"] = {type_degats: 1.0}
		_attaques_type[type_degats] = a
	return _attaques_type[type_degats]


# ---------------------------------------------------------------------------
# Dégâts attendus
# ---------------------------------------------------------------------------

static func chance_toucher(lanceur, competence, cible) -> float:
	return Formules.chance_toucher(lanceur, competence, cible)


static func facteur_critique(lanceur, competence, cible, type_degats = null) -> float:
	if type_degats == null:
		var types = U.ga(competence, "type_degats", null)
		type_degats = types[0] if U.vrai(types) else "tranchant"
	var s := Formules.stats_critique(lanceur, type_degats)
	var chance := minf(Formules.PLAFOND_CRITIQUE, maxf(0.0, s[0] + U.ga(competence, "bonus_critique", 0)
		+ Alterations.chance_critique_contre(cible)))
	return 1 + chance * maxf(0.0, s[1] + U.ga(competence, "bonus_degats_critique", 0) - 1)


static func degats_coup(lanceur, competence, cible) -> float:
	var secondaires = U.ga(competence, "facteurs_types", null)
	if secondaires == null:
		secondaires = {}
	var subis := 0.0
	for r in Formules.estimer_degats(lanceur, competence, cible, false):
		if r[2] > 0:
			subis += r[2] * (coefficient("second") if secondaires.has(r[0]) else 1.0) * facteur_critique(lanceur, competence, cible, r[0])
	return subis * Formules.facteur_toucher(lanceur, competence, cible)


static func degats_par_tour(attaquant, defenseur) -> float:
	return maxf(1, attaquant.points_d_action_max) * degats_coup(attaquant, attaque_ref(), defenseur)


# ---------------------------------------------------------------------------
# Valeur d'une altération
# ---------------------------------------------------------------------------

static func _porter(combattant: Reference, nom: String, puissance, duree) -> Reference:
	var copie_c := combattant.copie()
	var d: Dictionary = Alterations.defs()[nom]
	var p = d.get("puissance", 0) if puissance == null else puissance
	var data := {"duree": duree, "lanceur": null, "cumul": 1, "puissance": p, "modifs": {}}
	copie_c.alteration[nom] = data
	if d.has("modifs"):
		Alterations._appliquer_modifs(copie_c, data, Alterations.appeler_modifs(d, copie_c, p, 1))
	return copie_c


static func _reduction(resultat: Array, porteur, lanceur) -> float:
	var reduction := Degats.reduction_degats(porteur, resultat[0], 0, U.ga(lanceur, "penetration_resistance", 0), 1)
	return maxf(0.0, resultat[1] * (1 - reduction))


static func esperance_de_vie(porteur, adversaire) -> float:
	return maxf(1.0, porteur.points_de_vie / maxf(1.0, degats_par_tour(adversaire, porteur)))


static func _gain_resistances_hors_reference(porteur, modifie, adversaire) -> float:
	var baisses := []
	for a in modifie.attributs():
		var nom := String(a)
		if nom.begins_with("resistance_") and nom != "resistance_magique" and U.ga(modifie, nom) < U.ga(porteur, nom):
			baisses.append(nom.substr("resistance_".length()))
	if baisses.is_empty():
		return 0.0
	for t in baisses:
		if t in attaque_ref().type_degats:
			return 0.0
	var actions := maxf(1, adversaire.points_d_action_max)
	var gain := 0.0
	for t in baisses:
		gain += degats_coup(adversaire, _attaque_de(t), modifie) - degats_coup(adversaire, _attaque_de(t), porteur)
	return 0.5 * actions * gain / baisses.size()


## Bénéfice par tour d'une altération active, en dégâts équivalents : [bénéfice, durée].
static func benefice_alteration(nom: String, porteur, adversaire, puissance = null, duree_bonus = 0, lanceur = null) -> Array:
	nom = Alterations.nom_canonique(nom)
	var d = Alterations.defs().get(nom)
	if d == null:
		return [0.0, 1]
	var duree := int(d["duree"] + duree_bonus)
	if d["nature"] == "malus":
		duree = maxi(1, mini(duree, int(round(esperance_de_vie(porteur, adversaire)))))
	var modifie := _porter(porteur, nom, puissance, duree)
	var sortie := degats_par_tour(porteur, adversaire)
	var sortie_mod := degats_par_tour(modifie, adversaire)
	var entree := degats_par_tour(adversaire, porteur)
	var entree_mod := degats_par_tour(adversaire, modifie)
	var actions := maxf(1, porteur.points_d_action_max)
	var p = d.get("puissance", 0) if puissance == null else puissance
	var data := {"duree": duree, "lanceur": lanceur, "cumul": 1, "puissance": p}
	var tour := 0.0
	if d["nature"] == "malus":
		tour = (entree_mod - entree) + (sortie - sortie_mod)
		tour += _gain_resistances_hors_reference(porteur, modifie, adversaire)
		tour += maxf(0.0, porteur.points_de_vie_max - modifie.points_de_vie_max) * 0.5 / duree
		var source = lanceur if lanceur != null else adversaire
		if d.has("dot"):
			var dot := 0.0
			for t in range(1, duree + 1):
				dot += _reduction(d["dot"].call(porteur, data, t), porteur, source)
			dot /= duree
			dot *= 1 + d.get("draine", 0) * EFFICACITE_VOL + d.get("contagion", 0) * PART_CONTAGION
			tour += dot
		if d.has("fin"):
			tour += _reduction(d["fin"].call(porteur, data), porteur, source) / duree * (1.0 if duree == d["duree"] + duree_bonus else 0.0)
		if d.get("reveil"):
			tour += d.get("perte_tour", 0) * sortie / duree
		else:
			tour += d.get("perte_tour", 0) * sortie
		tour += d.get("perte_pa", 0) / actions * sortie
		if d.get("silence"):
			tour += 0.3 * sortie
		tour += (1 - d.get("soins_recus", 1)) * 0.1 * sortie
		if d.has("mana_tour"):
			tour += -d["mana_tour"].call(porteur, data, 1) * VALEUR_MANA * 0.3
	else:
		tour = (sortie_mod - sortie) + (entree - entree_mod)
		if d.has("soin_tour"):
			tour += d["soin_tour"].call(porteur, data, 1) * EFFICACITE_VOL
		if d.get("bouclier"):
			tour += minf(p, entree * duree) / duree
		tour += d.get("gain_pa", 0) / actions * sortie
		tour += d.get("vol_de_vie", 0) * sortie * EFFICACITE_VOL
		tour += d.get("epines", 0) * entree
		if d.has("mana_tour"):
			tour += d["mana_tour"].call(porteur, data, 1) * VALEUR_MANA
	return [maxf(0.0, tour), duree]


static func valeur_par_utilisation(nom: String, probabilite: float, porteur, adversaire, utilisations: float,
		puissance = null, duree_bonus = 0, lanceur = null) -> float:
	if probabilite <= 0:
		return 0.0
	var b := benefice_alteration(nom, porteur, adversaire, puissance, duree_bonus, lanceur)
	var tour: float = b[0]
	var duree: float = b[1]
	var applications := probabilite * utilisations * duree
	var couverture := 1 - pow(1 - minf(1.0, probabilite), utilisations * duree)
	var cumul_max = Alterations.definition(Alterations.nom_canonique(nom)).get("cumul_max", 1)
	var cumul := pow(minf(cumul_max, maxf(1.0, applications)), 0.7)
	return couverture * tour * cumul / utilisations


# ---------------------------------------------------------------------------
# Valeur d'une compétence
# ---------------------------------------------------------------------------

## [lanceur, adversaire] de référence : le héros contre le gobelin pour une compétence du joueur.
static func camp(competence) -> Array:
	if U.ga(competence, "nom_classe", "") in COMPETENCES_DU_JOUEUR or U.vrai(U.ga(competence, "JOUEUR", false)):
		return [joueur_ref(), ennemi_ref()]
	return [ennemi_ref(), joueur_ref()]


static func nombre_cibles(competence) -> float:
	if competence.type_ciblage in ["toute", "all", "tous_les_ennemis"]:
		return NB_ENNEMIS
	if competence.type_ciblage == "aléatoire":
		return minf(competence.nombre_cible, NB_ENNEMIS)
	return maxf(1, competence.nombre_cible)


## Valeur d'une utilisation, attribut par attribut : [[genre, clé, valeur], ...].
static func composantes(competence, brut := false) -> Array:
	var c := camp(competence)
	var lanceur = c[0]
	var adversaire = c[1]
	var n := maxi(1, int(competence.nombre_attaque))
	var cibles := nombre_cibles(competence)
	var utilisations: float = maxf(1, lanceur.points_d_action_max) / maxf(1, competence.cout_action)
	var parts := []
	var puissances: Dictionary = competence.puissance_alterations
	if competence.type_competence == "offensif":
		var h := chance_toucher(lanceur, competence, adversaire)
		var f_toucher := Formules.facteur_toucher(lanceur, competence, adversaire)
		var secondaires = U.ga(competence, "facteurs_types", null)
		if secondaires == null:
			secondaires = {}
		var coups: float = n * cibles + competence.chance_frappe_bonus
		var par_type := []
		for r in Formules.estimer_degats(lanceur, competence, adversaire, false):
			if r[2] > 0:
				par_type.append([r[0], r[2] * (coefficient("second", null, brut) if secondaires.has(r[0]) else 1.0)
					* facteur_critique(lanceur, competence, adversaire, r[0]) * f_toucher])
		var coup := 0.0
		for p in par_type:
			coup += p[1]
		var execution: float = PART_SOUS_MOITIE * competence.bonus_execution * coefficient("execution", null, brut)
		var vol: float = competence.vol_de_vie * EFFICACITE_VOL * coefficient("vol_de_vie", null, brut)
		for p in par_type:
			parts.append(["degats", p[0], p[1] * n * cibles])
		parts.append(["frappe", "", coup * competence.chance_frappe_bonus])
		parts.append(["execution", "", coup * execution * coups])
		parts.append(["vol", "", coup * (1 + execution) * coups * vol])
		for nom in competence.type_alteration:
			var chance = competence.type_alteration[nom]
			var p := 1 - pow(1 - h * chance / 100.0, n)
			parts.append(["alteration", nom, cibles * coefficient("alterations", nom, brut) * valeur_par_utilisation(
				nom, p, adversaire, lanceur, utilisations, puissances.get(nom), competence.duree_bonus, lanceur)])
		for nom in competence.alterations_lanceur:
			var chance = competence.alterations_lanceur[nom]
			var p := 1 - pow(1 - h * chance / 100.0, n)
			parts.append(["lanceur", nom, coefficient("alterations", nom, brut) * valeur_par_utilisation(
				nom, p, lanceur, adversaire, utilisations, puissances.get(nom), competence.duree_bonus, lanceur)])
	else:
		var allie = lanceur
		if competence.type_competence == "heal":
			var soin := 0.0
			for r in Formules.estimer_degats(lanceur, competence, allie, false):
				if r[2] < 0:
					soin -= r[2]
			soin *= facteur_critique(lanceur, competence, adversaire) * (1 + PART_SOUS_MOITIE * competence.bonus_execution)
			parts.append(["soin", "", soin * EFFICACITE_SOIN * n * cibles])
		for nom in competence.type_alteration:
			var chance = competence.type_alteration[nom]
			parts.append(["alteration", nom, cibles * coefficient("alterations", nom, brut) * valeur_par_utilisation(
				nom, chance / 100.0, allie, adversaire, 1, puissances.get(nom), competence.duree_bonus, lanceur)])
	var resultat := []
	for part in parts:
		if part[2]:
			resultat.append(part)
	return resultat


static func valeur(competence, brut := false) -> float:
	var total := 0.0
	for part in composantes(competence, brut):
		total += part[2]
	return total


## Copie des données utiles à l'évaluation (dictionnaires et listes dupliqués).
static func copie_competence(competence):
	var copie_c = competence.copie_superficielle()
	for attribut in ["type_alteration", "alterations_lanceur", "puissance_alterations", "facteurs_types",
			"pourcentage_types", "bonus_evolutifs", "_evolutif_applique"]:
		var v = U.ga(competence, attribut, {})
		copie_c.set(attribut, v.duplicate() if v != null else {})
	var types = U.ga(competence, "type_degats", null)
	copie_c.type_degats = types.duplicate() if types != null else []
	return copie_c


## Intensité d'une option qui apporte un gain de valeur égal au budget : [intensité, gain].
static func calibrer(competence, fabrique: Callable, budget: float, minimum: float, maximum: float, pas: float) -> Array:
	var bas := minimum
	var haut := maximum
	var x: float
	var base := valeur(competence)
	var gain_de := func(intensite: float) -> float:
		var copie_c = copie_competence(competence)
		fabrique.call(intensite).call(copie_c)
		return valeur(copie_c) - base
	if gain_de.call(haut) <= budget:
		x = haut
	else:
		for _i in 40:
			var milieu := (bas + haut) / 2
			if gain_de.call(milieu) < budget:
				bas = milieu
			else:
				haut = milieu
		x = (bas + haut) / 2
	var candidats := []
	for k in [-1, 0, 1]:
		var c := maxf(minimum, minf(maximum, round(x / pas) * pas + k * pas))
		if not (c in candidats):
			candidats.append(c)
	var meilleur = U.min_par(candidats, func(c): return absf(gain_de.call(c) - budget))
	meilleur = U.arrondi(meilleur, 4)
	return [meilleur, gain_de.call(meilleur)]
