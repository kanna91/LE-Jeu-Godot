class_name Formules
extends RefCounted
## Formules de dégâts du combat, partagées par la fiche des ennemis et l'équilibrage.

const TYPES_PHYSIQUES := ["tranchant", "perforant", "contondant"]
const TYPES_MAGIQUES := ["feu", "froid", "foudre", "arcane", "chaos", "ombre", "lumière"]
const TYPES_SPECIAUX := ["poison"]

const PLAFOND_CRITIQUE := 0.75
const PLAFOND_ESQUIVE := 0.60
const PLAFOND_PARADE := 0.75
const DEGATS_MAGIE_ESQUIVEE := 0.35

## Dés de chaque type de dégâts, les mêmes pour toutes les compétences et tous les sorts
## (les paliers des sorts n'y changent rien pour l'instant) : type -> [[nombre, faces], ...].
const DES_TYPES := {
	"tranchant": [[2, 6]], "perforant": [[1, 12]], "contondant": [[1, 10], [1, 2]],
	"feu": [[2, 6]], "froid": [[3, 4]], "foudre": [[1, 12]],
	"arcane": [[2, 6]], "chaos": [[3, 4]], "ombre": [[2, 6]],
	"lumière": [[3, 6]], "poison": [[1, 2]],
}
## Type de dégâts de chaque type d'arme (ses dés sont ceux du type).
const DES_ARMES := {"Lance": "perforant", "Epée": "tranchant", "Marteau": "contondant"}
## Caractéristique qui ajoute Caracteristiques.DEGATS_PAR_POINT dégâts par point, par type de dégâts
## (lumière : la plus forte de l'intelligence et de la sagesse ; poison : aucune).
const ELEMENTAIRES := ["feu", "froid", "foudre"]
const MAGIQUES_PURS := ["arcane", "ombre", "chaos"]


static func _arme(lanceur):
	return U.ga(lanceur, "arme_equipee", null) if lanceur != null else null


## Attaques liées à chaque type d'arme : seules elles profitent du dé bonus de l'arme
## (les sorts et les autres compétences gardent leurs propres dés).
const ATTAQUES_ARMES := {
	"Epée": ["Coup_d_epee", "Frénésie"],
	"Lance": ["Coup_de_lance", "Balayage"],
	"Marteau": ["Coup_de_marteau", "Fracasser"],
}


## Vrai si la compétence est une attaque de l'arme que tient le lanceur (Coup d'épée, Frénésie...).
## Sans compétence (affichage des dés d'une arme), on considère que c'est une attaque de l'arme.
static func est_attaque_arme(lanceur, competence) -> bool:
	if competence == null:
		return true
	var type_arme = U.ga(_arme(lanceur), "type_arme", "")
	return U.ga(competence, "nom_classe", "") in ATTAQUES_ARMES.get(type_arme, [])


## Type de dégâts physiques de l'arme du lanceur ("" sans arme).
static func type_degats_arme(lanceur) -> String:
	return DES_ARMES.get(U.ga(_arme(lanceur), "type_arme", ""), "")


## Dé bonus d'une arme ({"faces", "type"}, ou {} si elle n'en a pas).
static func de_bonus(arme) -> Dictionary:
	var bonus = U.ga(arme, "de_bonus", null)
	return bonus if bonus is Dictionary and not bonus.is_empty() else {}


## Compétences à coups multiples (nombre_attaque > 1, comme Rafale de lance) : chaque coup lance
## DES_COUP_MULTIPLE au lieu des dés du type, avec MALUS_COUP_MULTIPLE dégâts en moins.
const DES_COUP_MULTIPLE := [[1, 6]]
const MALUS_COUP_MULTIPLE := 2

## Dés propres à chaque compétence (revue des dégâts de l'utilisateur, 2026-11-01) : nom de classe -> {type: dés}.
## Ils remplacent les dés du type (DES_TYPES), sans le malus des coups multiples (les dés sont ceux d'un coup ;
## Frénésie frappe 2 fois 4d2, Balayage 3d2 sur chaque cible) ni le palier plus bas des ennemis.
## Le dé bonus d'une arme s'ajoute toujours aux attaques de l'arme.
const DES_HEROS := {
	"Coup_d_epee": {"tranchant": [[6, 2]]}, "Frenesie": {"tranchant": [[4, 2]]},
	"Coup_de_marteau": {"contondant": [[6, 2]]}, "Fracasser": {"contondant": [[8, 2]]},
	"Coup_de_poing": {"contondant": [[4, 2]]},
	"Coup_de_lance": {"perforant": [[6, 2]]}, "Balayage": {"perforant": [[3, 2]]},
	"Soin": {"lumière": [[20, 2]]},
	"Boule_de_feu": {"feu": [[8, 2]]}, "Givre": {"froid": [[8, 2]]}, "Eclair": {"foudre": [[6, 3]]},
	"Trait_arcanique": {"arcane": [[8, 2]]}, "Souffle_du_chaos": {"chaos": [[4, 2]], "ombre": [[4, 2]]},
	"Murmure_des_ombres": {"ombre": [[8, 2]]}, "Estafilade": {"tranchant": [[8, 2]]},
	"Dard_empoisonne": {"perforant": [[6, 2]], "poison": [[2, 2]]}, "Bourrade": {"contondant": [[8, 2]]},
}
const DES_ENNEMIS := {
	"Tir": {"perforant": [[4, 2]]}, "Tir_precis": {"perforant": [[3, 2]]}, "Tir_empoisonne": {"perforant": [[3, 2]]},
	"Boule_de_feu": {"feu": [[5, 2]]}, "Soin_mineur": {"lumière": [[7, 2]]},
	"Coup_d_epee": {"tranchant": [[4, 2]]},
	"Coup_de_gourdin": {"contondant": [[3, 2]]}, "Grand_coup_de_gourdin": {"contondant": [[5, 2]]},
	"Projectile_des_ombres": {"ombre": [[5, 2]]}, "Caresse_des_ombres": {"ombre": [[2, 2]]},
	"Enflammer": {"feu": [[5, 2]]}, "Silence": {"ombre": [[2, 2]]},
	"Coup_de_lance": {"perforant": [[4, 2]]}, "Rafale_de_lance": {"perforant": [[2, 2]]},
	"Perforation": {"perforant": [[3, 2]]},
	"Coup_de_baton": {"contondant": [[2, 2]]}, "Trait_des_Ombres": {"ombre": [[5, 2]]},
}
## Part des PV max de la cible ajoutée aux dégâts (ou aux soins) d'une compétence d'ennemi : nom -> {type: part}.
## Soin mineur des gobelins : 7d2 + 15 % des PV max de la cible (2026-11-01). Un lanceur peut aussi avoir sa
## propre table ``pourcentage_pv_cible`` (Chevalier de la mort : +15 % en tranchant).
const PV_CIBLE_ENNEMIS := {"Soin_mineur": {"lumière": 0.15}}


## Dés propres de la compétence pour ce type ([] : ceux du type).
static func des_competence(lanceur, competence, type_degats: String) -> Array:
	if competence == null:
		return []
	var table: Dictionary = DES_ENNEMIS if lanceur is Ennemis else DES_HEROS
	var par_type = table.get(U.ga(competence, "nom_classe", ""), null)
	if par_type is Dictionary and par_type.has(type_degats):
		return par_type[type_degats]
	return []


## Part des PV max de la cible ajoutée à ce type de dégâts (0 : aucune).
static func part_pv_cible(lanceur, competence, type_degats: String) -> float:
	var part := 0.0
	var propre = U.ga(lanceur, "pourcentage_pv_cible", null) if lanceur != null else null
	if propre is Dictionary:
		part += float(propre.get(type_degats, 0.0))
	if lanceur is Ennemis and competence != null:
		part += float(PV_CIBLE_ENNEMIS.get(U.ga(competence, "nom_classe", ""), {}).get(type_degats, 0.0))
	return part


## Dégâts (ou soins) en plus, en part des PV max de la cible.
static func bonus_pv_cible(lanceur, competence, cible, type_degats: String) -> float:
	if cible == null:
		return 0.0
	return part_pv_cible(lanceur, competence, type_degats) * U.num(cible, "points_de_vie_max")


static func est_coup_multiple(competence) -> bool:
	return competence != null and U.num(competence, "nombre_attaque") > 1


## Paliers des dés de dégâts. Les ennemis lancent chaque dé un palier plus bas que le héros
## (2026-10-20, demande de l'utilisateur) : 1d12 → 1d10, 1d10 → 1d6, 1d8 → 1d6, 1d6 → 1d4, 1d4 → 1d2 ;
## 1d2 reste 1d2 (pas de palier plus bas). Les soins (lumière) ne sont pas réduits.
const PALIERS_DES := [2, 4, 6, 10, 12]


## Faces du dé un palier plus bas (1d2 reste 1d2).
static func palier_inferieur(faces: int) -> int:
	var resultat := PALIERS_DES[0]
	for p in PALIERS_DES:
		if p < faces:
			resultat = p
	return resultat


## Dés réduits d'un palier ([[nombre, faces], ...]).
static func des_reduits(des: Array) -> Array:
	var liste := []
	for d in des:
		liste.append([d[0], palier_inferieur(d[1])])
	return liste


## Dés lancés pour un type de dégâts d'une compétence : ceux du type (1d6 pour un coup multiple), plus
## le dé bonus de l'arme quand il est du même type que l'arme, que le coup fait ce type et que c'est
## une attaque de l'arme (est_attaque_arme). Un ennemi lance ses dés un palier plus bas (PALIERS_DES).
static func des_type(lanceur, type_degats: String, competence = null) -> Array:
	var fixes = U.ga(lanceur, "des_fixes", null) if lanceur != null else null
	if fixes is Dictionary and fixes.has(type_degats):
		return fixes[type_degats]  # dés imposés (Chevalier de la mort), ni dé d'arme ni palier ennemi
	var propres := des_competence(lanceur, competence, type_degats)
	var des: Array = propres
	if propres.is_empty():
		des = DES_COUP_MULTIPLE if est_coup_multiple(competence) else DES_TYPES.get(type_degats, [])
	var bonus := de_bonus(_arme(lanceur))
	if (not bonus.is_empty() and bonus["type"] == type_degats and type_degats_arme(lanceur) == type_degats
			and est_attaque_arme(lanceur, competence)):
		des = des + [[1, bonus["faces"]]]
	if lanceur is Ennemis and type_degats != "lumière" and propres.is_empty():
		return des_reduits(des)
	return des


## Dé bonus d'un autre type que l'arme, déclenché par une attaque de l'arme :
## [type, faces], ou [] (pas de dé bonus, ou dé du même type, déjà compté dans des_type).
static func de_bonus_autre_type(lanceur, types_competence: Array, competence = null) -> Array:
	if lanceur != null and U.ga(lanceur, "des_fixes", null) is Dictionary:
		return []
	var type_arme := type_degats_arme(lanceur)
	if type_arme == "" or not (type_arme in types_competence) or not est_attaque_arme(lanceur, competence):
		return []
	var bonus := de_bonus(_arme(lanceur))
	if bonus.is_empty() or bonus["type"] == type_arme:
		return []
	return [bonus["type"], palier_inferieur(bonus["faces"]) if lanceur is Ennemis else bonus["faces"]]


static func jet(des: Array) -> int:
	var total := 0
	for d in des:
		for i in d[0]:
			total += randi_range(1, d[1])
	return total


static func moyenne(des: Array) -> float:
	var total := 0.0
	for d in des:
		total += d[0] * (d[1] + 1) / 2.0
	return total


## « 1d10 + 1d2 » pour une liste de dés.
static func texte(des: Array) -> String:
	var morceaux := []
	for d in des:
		morceaux.append("%dd%d" % [d[0], d[1]])
	return " + ".join(morceaux)


## Dés d'un type d'arme en texte (chaîne vide pour un type inconnu).
static func texte_des(type_arme) -> String:
	return texte(DES_TYPES.get(DES_ARMES.get(type_arme, ""), []))


## +2 dégâts par point de la caractéristique du type (2026-10-29 ; +1 tous les 2 points avant) : force (physique),
## sagesse (feu, froid, foudre), intelligence (arcane, ombre, chaos), la plus forte des deux (lumière).
## Arrondi en dessous (une altération peut donner une caractéristique non entière).
static func bonus_caracteristique(lanceur, type_degats: String) -> int:
	var valeur := 0.0
	if type_degats in TYPES_PHYSIQUES:
		valeur = U.num(lanceur, "force")
	elif type_degats in ELEMENTAIRES:
		valeur = U.num(lanceur, "sagesse")
	elif type_degats in MAGIQUES_PURS:
		valeur = U.num(lanceur, "intelligence")
	elif type_degats == "lumière":
		valeur = maxf(U.num(lanceur, "intelligence"), U.num(lanceur, "sagesse"))
	return floori(valeur * Caracteristiques.DEGATS_PAR_POINT)


## Pourcentages de dégâts (les « modificateurs ») : celui du groupe (physique ; magique pour l'arcane, l'ombre, le chaos
## et la lumière ; élémentaire pour le feu, le froid et la foudre, séparé du magique depuis le 2026-10-30), puis celui du type.
static func pourcentage(lanceur, type_degats: String) -> float:
	var p: float = U.ga(lanceur, "pourcentage_degats_" + type_degats, 1)
	if type_degats in TYPES_PHYSIQUES:
		p *= U.ga(lanceur, "pourcentage_degats_physique", 1)
	elif type_degats in ELEMENTAIRES:
		p *= U.ga(lanceur, "pourcentage_degats_elementaire", 1)
	elif type_degats != "poison":
		p *= U.ga(lanceur, "pourcentage_degats_magique", 1)
	return p


## Dégâts plats d'un type : ceux du type plus ceux de son groupe (physiques, magiques ou élémentaires).
static func degats_plats(lanceur, type_degats: String) -> float:
	var plats := U.num(lanceur, "degats_" + type_degats)
	if type_degats in TYPES_PHYSIQUES:
		plats += U.num(lanceur, "degats_physique")
	elif type_degats in ELEMENTAIRES:
		plats += U.num(lanceur, "degats_elementaire")
	elif type_degats in MAGIQUES_PURS:
		plats += U.num(lanceur, "degats_magique")
	return plats


## Dégâts d'un type pour un jet donné : (jet + caractéristique + dégâts plats du lanceur) × pourcentages.
## Dégâts plats : ceux du type, plus ceux de son groupe (dégâts physiques, magiques ou élémentaires des objets).
static func base_degats(lanceur, type_degats: String, valeur_jet: float) -> float:
	var plats := degats_plats(lanceur, type_degats)
	return maxf(0, (valeur_jet + bonus_caracteristique(lanceur, type_degats) + plats) * pourcentage(lanceur, type_degats))


## Jet (ou sa moyenne) d'un type de dégâts pour une compétence, malus des coups multiples compris.
static func valeur_jet(lanceur, competence, type_degats: String, en_moyenne := false) -> float:
	var des := des_type(lanceur, type_degats, competence)
	var valeur: float = moyenne(des) if en_moyenne else float(jet(des))
	var malus := est_coup_multiple(competence) and des_competence(lanceur, competence, type_degats).is_empty()
	return valeur - (MALUS_COUP_MULTIPLE if malus else 0)


## Dégâts d'un dé bonus d'un autre type : le jet × pourcentages du type.
static func base_de_bonus(lanceur, type_degats: String, valeur_jet: float) -> float:
	return valeur_jet * pourcentage(lanceur, type_degats)


static func esquive(cible) -> float:
	return minf(U.num(cible, "chance_esquive"), PLAFOND_ESQUIVE)


static func parade(cible) -> float:
	return minf(U.num(cible, "chance_de_parer"), PLAFOND_PARADE)


## Chance de toucher, bornée entre 0,10 et 1.
static func chance_toucher(lanceur, competence, cible) -> float:
	var bonus = U.ga(competence, "bonus_toucher", 0) if competence != null else 0
	return minf(1.0, maxf(0.10, lanceur.chance_de_toucher + bonus - esquive(cible) / 2.0))


## Part moyenne des dégâts infligés, compte tenu des coups ratés (la magie ne s'esquive pas).
static func facteur_toucher(lanceur, competence, cible) -> float:
	var p := chance_toucher(lanceur, competence, cible)
	if U.ga(competence, "type_attaque", null) == "magique":
		return p + (1 - p) * DEGATS_MAGIE_ESQUIVEE
	return p


## [chance, multiplicateur] de coup critique d'un lanceur pour un type de dégâts (2026-10-29) :
## physique (et brut) : critique physique (dextérité) ; arcane, ombre, chaos : critique magique (intelligence) ;
## feu, froid, foudre : critique élémentaire (sagesse) ; lumière : celui de la plus forte des deux ; poison : jamais.
## Magique et élémentaire ont le même multiplicateur (``degats_critique_magiques``).
static func stats_critique(lanceur, type_degats) -> Array:
	if type_degats == "poison":
		return [0.0, 1.0]
	if type_degats in TYPES_PHYSIQUES + ["brut"] or not U.ha(lanceur, "degats_critique_magiques"):
		return [lanceur.chance_de_coup_critique, lanceur.degats_critique]
	var elementaire: bool = type_degats in ELEMENTAIRES
	if type_degats == "lumière":
		elementaire = U.num(lanceur, "sagesse") > U.num(lanceur, "intelligence")
	var chance := U.num(lanceur, "chance_de_coup_critique_elementaire" if elementaire else "chance_de_coup_critique_magique")
	return [chance, lanceur.degats_critique_magiques]


## Bonus en pourcentage de la compétence pour un type de dégâts (améliorations « +x % de dégâts de
## foudre ») : ne joue que sur les dégâts de ce type que la compétence inflige déjà.
static func pourcentage_competence(competence, type_degats: String) -> float:
	var table = U.ga(competence, "pourcentage_types", null) if competence != null else null
	return 1.0 + (float(table.get(type_degats, 0.0)) if table is Dictionary else 0.0)


## Dégâts d'un type de la compétence pour un jet donné (bonus en pourcentage de la compétence compris).
static func degats_competence(lanceur, competence, type_degats: String, valeur_jet: float) -> float:
	return base_degats(lanceur, type_degats, valeur_jet) * pourcentage_competence(competence, type_degats)


## Dégâts moyens d'un type de la compétence, avant réduction.
static func degats_bruts(lanceur, competence, type_degats: String) -> float:
	return degats_competence(lanceur, competence, type_degats, valeur_jet(lanceur, competence, type_degats, true))


## Estimation des dégâts d'une compétence sur une cible, type par type :
## [[type, dégâts avant réduction, dégâts subis], ...] (soins : subis négatifs).
static func estimer_degats(lanceur, competence, cible, arrondi := true) -> Array:
	var resultats := []
	var mult_alterations := (Alterations.modificateur_degats(lanceur, cible)
		* Talents.multiplicateur_degats(lanceur, cible) * Talents.facteur_reduction(cible))
	var pen_res = U.ga(lanceur, "penetration_resistance", 0) + U.ga(competence, "penetration_resistance", 0)
	var pen_arm = U.ga(lanceur, "penetration_armure", 0) + U.ga(competence, "penetration_armure", 0)
	var types = U.ga(competence, "type_degats", null)
	if types == null:
		types = []
	var bonus := de_bonus_autre_type(lanceur, types, competence)
	var a_estimer := []
	for t in types + ([bonus[0]] if not bonus.is_empty() else []):
		if not (t in a_estimer):
			a_estimer.append(t)  # chaque type une seule fois (le dé bonus s'ajoute au même type)
	for type_degats in a_estimer:
		if not (type_degats in TYPES_PHYSIQUES + TYPES_MAGIQUES + TYPES_SPECIAUX):
			continue
		var brut := degats_bruts(lanceur, competence, type_degats) if type_degats in types else 0.0
		if type_degats in types:
			brut += bonus_pv_cible(lanceur, competence, cible, type_degats)
		if not bonus.is_empty() and type_degats == bonus[0]:
			brut += base_de_bonus(lanceur, type_degats, (bonus[1] + 1) / 2.0)
		if type_degats == "lumière":
			brut *= Alterations.multiplicateur_soins(cible)
			var soin = brut + brut * pen_res * 0.02
			resultats.append([type_degats, brut, -(ceilf(soin) if arrondi else soin)])
			continue
		brut *= mult_alterations
		var pen_arm_type = pen_arm + Talents.ignore_armure(lanceur, cible) if type_degats in TYPES_PHYSIQUES else 0
		var subis := Degats.degats_subis(cible, type_degats, brut, pen_arm_type, pen_res)
		resultats.append([type_degats, brut, ceilf(subis) if arrondi else subis])
	return resultats
