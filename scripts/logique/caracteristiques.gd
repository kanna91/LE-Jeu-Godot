class_name Caracteristiques
extends RefCounted
## Effets des caractéristiques, les mêmes pour le héros et les ennemis (règles de l'utilisateur, 2026-10-29) :
##
## - Endurance : +5 PV max et +2 PV régénérés par minute **tous les 2 points** (2026-11-03 ; +10 PV et +2 PV/min
##   par point avant) ;
## - Force : +1d2 dégâts physiques **tous les 2 points** (tranchant, perforant, contondant ; 1d2 par point le
##   2026-11-02 matin, +2 fixes par point avant) ;
## - Dextérité : +2 % de critique physique, +1 % de toucher, +1 % d'esquive ;
## - Intelligence : +1d2 dégâts d'arcane, d'ombre et de chaos tous les 2 points, +1 % de critique magique ;
## - Sagesse : +1d2 dégâts de feu, de froid et de foudre tous les 2 points, +1 % de critique élémentaire ;
## - Mana : +5 mana max et +2 mana régénérés par minute **tous les 2 points** (2026-11-03 ; +5 et +2 par point
##   le 2026-11-02, +10 mana par point avant).
##
## Lumière (soins) : la plus forte entre intelligence et sagesse, pour les dégâts comme pour le critique.
## Poison : aucune caractéristique, jamais de critique. La régénération ne tourne que pendant l'exploration
## (pas en combat ni dans les menus), en minutes réelles (``Personnage.regenerer``).

## Clé de la caractéristique Mana (« mana » est déjà le mana restant).
const MANA := "caracteristique_mana"
## Toutes les caractéristiques, dans l'ordre d'affichage.
const LISTE := ["endurance", "force", "dextérité", "intelligence", "sagesse", MANA]
const NOMS := {"endurance": "Endurance", "force": "Force", "dextérité": "Dextérité", "intelligence": "Intelligence",
	"sagesse": "Sagesse", MANA: "Mana"}

## Endurance et Mana comptent par tranche de POINTS_PAR_PALIER points (règle de l'utilisateur, 2026-11-03 :
## 1 point = rien, 2-3 points = une tranche, 4-5 = deux...). Valeurs ci-dessous : par tranche.
const POINTS_PAR_PALIER := 2
const PV_PAR_ENDURANCE := 5
const REGEN_PV_PAR_ENDURANCE := 2.0  # par minute
## Dé de dégâts ajouté par la force, l'intelligence ou la sagesse : 1d2 (FACES_PAR_POINT faces) tous les
## POINTS_PAR_DE points (règle de l'utilisateur, 2026-11-02 : 1 point = rien, 2-3 points = 1d2, 4-5 = 2d2...).
const FACES_PAR_POINT := 2
const POINTS_PAR_DE := 2
const CRITIQUE_PAR_DEXTERITE := 0.02
const TOUCHER_PAR_DEXTERITE := 0.01
const ESQUIVE_PAR_DEXTERITE := 0.01
const CRITIQUE_MAGIQUE_PAR_INTELLIGENCE := 0.01
const CRITIQUE_ELEMENTAIRE_PAR_SAGESSE := 0.01
const MANA_PAR_POINT := 5  # par tranche de 2 points
const REGEN_MANA_PAR_POINT := 2.0  # par minute, par tranche de 2 points

## Effet d'un point (PAR_POINT) ou d'une tranche de 2 points (PAR_PALIER) de chaque caractéristique sur les
## statistiques calculées (les dégâts sont lus directement par Formules.bonus_caracteristique). Sert aussi aux
## altérations qui changent une caractéristique.
const PAR_PALIER := {
	"endurance": {"points_de_vie_max": PV_PAR_ENDURANCE, "regen_de_points_de_vie": REGEN_PV_PAR_ENDURANCE},
	MANA: {"mana_max": MANA_PAR_POINT, "regen_de_mana": REGEN_MANA_PAR_POINT},
}
const PAR_POINT := {
	"endurance": {},
	"force": {},
	"dextérité": {"chance_de_coup_critique": CRITIQUE_PAR_DEXTERITE, "chance_de_toucher": TOUCHER_PAR_DEXTERITE,
		"chance_esquive": ESQUIVE_PAR_DEXTERITE},
	"intelligence": {"chance_de_coup_critique_magique": CRITIQUE_MAGIQUE_PAR_INTELLIGENCE},
	"sagesse": {"chance_de_coup_critique_elementaire": CRITIQUE_ELEMENTAIRE_PAR_SAGESSE},
	MANA: {},
}

## Texte de l'effet de chaque caractéristique (écran des caractéristiques).
const TEXTES := {
	"endurance": "+5 PV max, +2 PV régénérés par minute tous les 2 points",
	"force": "+1d2 dégâts physiques tous les 2 points (tranchant, perforant, contondant)",
	"dextérité": "+2 % critique physique, +1 % toucher, +1 % esquive par point",
	"intelligence": "+1d2 dégâts arcane, ombre, chaos tous les 2 points, +1 % critique magique par point",
	"sagesse": "+1d2 dégâts feu, froid, foudre tous les 2 points, +1 % critique élémentaire par point",
	MANA: "+5 mana max, +2 mana régénérés par minute tous les 2 points",
}


## Nombre de tranches de POINTS_PAR_PALIER points (endurance, mana) : 1 → 0, 2-3 → 1, 4-5 → 2...
static func paliers(points: float) -> int:
	return floori(maxf(0.0, points) / POINTS_PAR_PALIER)


## Bonus apportés par les caractéristiques d'un combattant : {statistique: valeur}. Les PV et le mana restants
## suivent leur maximum (clés « points_de_vie » et « mana »). ``pv_par_endurance`` : PV par tranche de 2 points
## d'endurance (le héros peut l'augmenter par les talents).
static func bonus(combattant, pv_par_endurance := float(PV_PAR_ENDURANCE)) -> Dictionary:
	var b := {}
	for c in LISTE:
		var points := float(U.num(combattant, c))
		var effets: Dictionary = PAR_POINT[c]
		for stat in effets:
			b[stat] = b.get(stat, 0.0) + points * float(effets[stat])
		effets = PAR_PALIER.get(c, {})
		for stat in effets:
			var par_palier: float = pv_par_endurance if stat == "points_de_vie_max" else float(effets[stat])
			b[stat] = b.get(stat, 0.0) + paliers(points) * par_palier
	b["points_de_vie_max"] = int(b["points_de_vie_max"])
	b["points_de_vie"] = b["points_de_vie_max"]
	b["mana_max"] = int(b["mana_max"])
	b["mana"] = b["mana_max"]
	return b
