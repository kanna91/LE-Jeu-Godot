class_name Caracteristiques
extends RefCounted
## Effets des caractéristiques, les mêmes pour le héros et les ennemis (règles de l'utilisateur, 2026-10-29) :
##
## - Endurance : +10 PV max, +2 PV régénérés par minute ;
## - Force : +2 dégâts physiques (tranchant, perforant, contondant) ;
## - Dextérité : +2 % de critique physique, +1 % de toucher, +1 % d'esquive ;
## - Intelligence : +2 dégâts d'arcane, d'ombre et de chaos, +1 % de critique magique ;
## - Sagesse : +2 dégâts de feu, de froid et de foudre, +1 % de critique élémentaire ;
## - Mana : +10 mana max, +2 mana régénérés par minute.
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

const PV_PAR_ENDURANCE := 10
const REGEN_PV_PAR_ENDURANCE := 2.0  # par minute
const DEGATS_PAR_POINT := 2
const CRITIQUE_PAR_DEXTERITE := 0.02
const TOUCHER_PAR_DEXTERITE := 0.01
const ESQUIVE_PAR_DEXTERITE := 0.01
const CRITIQUE_MAGIQUE_PAR_INTELLIGENCE := 0.01
const CRITIQUE_ELEMENTAIRE_PAR_SAGESSE := 0.01
const MANA_PAR_POINT := 10
const REGEN_MANA_PAR_POINT := 2.0  # par minute

## Effet d'un point de chaque caractéristique sur les statistiques calculées (les dégâts sont lus directement
## par Formules.bonus_caracteristique). Sert aussi aux altérations qui changent une caractéristique.
const PAR_POINT := {
	"endurance": {"points_de_vie_max": PV_PAR_ENDURANCE, "regen_de_points_de_vie": REGEN_PV_PAR_ENDURANCE},
	"force": {},
	"dextérité": {"chance_de_coup_critique": CRITIQUE_PAR_DEXTERITE, "chance_de_toucher": TOUCHER_PAR_DEXTERITE,
		"chance_esquive": ESQUIVE_PAR_DEXTERITE},
	"intelligence": {"chance_de_coup_critique_magique": CRITIQUE_MAGIQUE_PAR_INTELLIGENCE},
	"sagesse": {"chance_de_coup_critique_elementaire": CRITIQUE_ELEMENTAIRE_PAR_SAGESSE},
	MANA: {"mana_max": MANA_PAR_POINT, "regen_de_mana": REGEN_MANA_PAR_POINT},
}

## Texte « par point » de chaque caractéristique (écran des caractéristiques).
const TEXTES := {
	"endurance": "+10 PV max, +2 PV régénérés par minute",
	"force": "+2 dégâts physiques (tranchant, perforant, contondant)",
	"dextérité": "+2 % critique physique, +1 % toucher, +1 % esquive",
	"intelligence": "+2 dégâts arcane, ombre, chaos, +1 % critique magique",
	"sagesse": "+2 dégâts feu, froid, foudre, +1 % critique élémentaire",
	MANA: "+10 mana max, +2 mana régénérés par minute",
}


## Bonus apportés par les caractéristiques d'un combattant : {statistique: valeur}. Les PV et le mana restants
## suivent leur maximum (clés « points_de_vie » et « mana »). ``pv_par_endurance`` : PV par point d'endurance
## (le héros peut l'augmenter par les talents).
static func bonus(combattant, pv_par_endurance := float(PV_PAR_ENDURANCE)) -> Dictionary:
	var b := {}
	for c in LISTE:
		var points := float(U.num(combattant, c))
		var effets: Dictionary = PAR_POINT[c]
		for stat in effets:
			var par_point: float = pv_par_endurance if stat == "points_de_vie_max" else float(effets[stat])
			b[stat] = b.get(stat, 0.0) + points * par_point
	b["points_de_vie_max"] = int(b["points_de_vie_max"])
	b["points_de_vie"] = b["points_de_vie_max"]
	b["mana_max"] = int(b["mana_max"])
	b["mana"] = b["mana_max"]
	return b
