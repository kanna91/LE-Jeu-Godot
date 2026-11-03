class_name BasesCompetences
extends RefCounted
## Corrections de base des compétences, appliquées à leur création (Competences.creer) : altérations et réglages
## qui remplacent ceux de donnees/competences.json, puis normalisation (ValeurCompetences.normaliser).
##
## Tiré de l'ancien fichier des améliorations de compétences, supprimé le 2026-11-03 (l'utilisateur va reforger
## l'amélioration entièrement) : seules les corrections de base et les plafonds d'altérations sont gardés.

const BASES := {
	"Perforation": {"alterations": {"saignement": 60}},
	"Tir_empoisonne": {"alterations": {"poison": 70, "peste": 20}},
	"Enflammer": {"alterations": {"brulure": 75, "inflammabilité": 40}},
	"Caresse_des_ombres": {"alterations": {"destruction armure": 50, "destruction résistance": 50,
		"décrépitude": 25, "esprit embrumé": 25}},
	"Silence": {"alterations": {"silence": 60, "brûlure de mana": 30}},
	"Recupe": {"alterations": {"régénération": 100}, "degats_lumière": 12},  # « +5 % des PV max » retiré (2026-11-02) : jamais appliqué
	# Soins : leur part des PV max de la cible est dans Formules.PV_CIBLE_ENNEMIS (2026-11-01)
	"Soin_mineur": {"degats_lumière": 15},
	"Soin": {"degats_lumière": 50},
	"Soin_majeur": {"degats_lumière": 60},
	# Coup de poing : plus d'étourdissement (2026-11-01)
	"Fracasser": {"alterations": {"stun": 15}},
	"Grand_coup_de_gourdin": {"alterations": {"stun": 20, "affaiblissement": 25, "trauma": 25}},
	"Coup_de_gourdin": {"alterations": {"trauma": 20}},
	"Botte_secrete": {"alterations": {"saignement": 20, "désarmement": 15}},
	"Laceration": {"alterations": {"saignement": 25}},
	"Tir_precis": {"alterations": {"marque": 30, "lenteur": 20}},
	"Rafale_de_lance": {"alterations": {"lenteur": 15}},
	"Blizzard": {"alterations": {"gel": 15, "engelure": 20, "morsure du givre": 20}},
	"Eclair": {"alterations": {"électrocution": 15, "conductivité": 20, "paralysie": 10}},
	"Tempete_de_feu": {"alterations": {"brulure": 20}},
	"Trait_des_Ombres": {"alterations": {"terreur": 15, "siphon de vie": 20}},
	"Projectile_des_ombres": {"alterations": {"corruption": 15, "condamnation": 10}},
	"Coup_de_baton": {"alterations": {"aveugler": 20, "sommeil": 10}},
	"Tir_rapide": {"alterations": {"aveugler": 15}},
	"Cri_de_guerre": {"alterations": {"rage": 100}, "nombre_attaque": 1, "nombre_cible": 6,
		"description": "Pousse un cri qui met tous les alliés en rage (+25 % de dégâts, +25 % de dégâts critiques)."},
	"Protection": {"alterations": {"protection": 100}, "nombre_attaque": 1,
		"description": "Protège un allié : dégâts physiques reçus -40 % pendant 3 tours."},
	"Précision": {"alterations": {"précis": 100, "concentration": 100}, "nombre_attaque": 1, "type_degats": [], "degats_lumière": 0,
		"description": "Aiguise la visée d'un allié : chance de toucher +35 % et de critique +15 % pendant 3 tours."},
}
## Plafonds des chances d'altération utilisés par ValeurCompetences (palier des compétences).
const PLAFOND_SPECIALITE := 60
const CONTROLES_PLAFONNES := {"stun": {"plafond": 35}}


## Termine la création d'une compétence : corrections de base, puis normalisation.
static func preparer(comp) -> void:
	var base: Dictionary = BASES.get(comp.nom_classe, {})
	var alterations: Dictionary = base.get("alterations", {})
	for nom in alterations:
		comp.type_alteration[nom] = alterations[nom]
	for attribut in ["nombre_attaque", "nombre_cible", "type_degats", "degats_lumière", "soin_pourcentage_pv", "description"]:
		if base.has(attribut):
			comp.set(attribut, base[attribut].duplicate() if base[attribut] is Array else base[attribut])
	var nettoyees := {}
	for k in comp.type_alteration:
		if U.vrai(comp.type_alteration[k]):
			nettoyees[k] = comp.type_alteration[k]
	comp.type_alteration = nettoyees
	ValeurCompetences.normaliser(comp)
