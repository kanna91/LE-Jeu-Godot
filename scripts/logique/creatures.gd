class_name Creatures
extends RefCounted
## Créatures qui ne sont pas des gobelins : loups et squelettes (ajoutés le 2026-10-27, fiches de l'utilisateur dans
## ``C:\ia image\ennemis\loup`` et ``...\squelette``).
##
## Décidé par l'utilisateur : loup **faible au feu (40 %)**, frappe **perforant**, toujours avec un archer ou un
## chaman gobelin (jamais seul) ; squelette **résiste au perforant (20 %)**, **faible au contondant (40 %)**, frappe
## **1d10 tranchant**, avec d'autres squelettes, morts-vivants, animaux ou féticheurs, et peut être seul ; tous deux
## dès le premier étage. Leurs dés comptent tels quels (``des_fixes``) : le « dé un cran plus bas » des gobelins
## était un réglage fait à la main pour eux, pas une règle (précision de l'utilisateur, 2026-10-27).
## **Proposé par Claude, validé par l'utilisateur le 2026-10-27** : caractéristiques, dé du loup (1d8), fréquences des rencontres
## (zone « defaut » de donnees/zones.json depuis le 2026-11-02 : Zones), vitesse des squelettes.
##
## Un loup ou un squelette est un ``Gobelin`` (comme le Chevalier de la mort) de classe « creature » : l'IA joue sa
## seule attaque (Ennemis.mecanique_ennemis). Image fixe qui respire, en salle comme en combat (``images/gobelins``,
## ``outils/importer_loup_squelette.py``).

## PV relevés le 2026-11-04 (au moins 4 coups du héros de départ, voir Gobelin.ENDURANCE_PAR_SOUS_CLASSE) :
## loup 50-60 (10-20 avant), squelette 60 (20 avant).
## Sorte → réglages. Caractéristiques : [min, max] (bornes comprises) ; PV = endurance × 10 (l'endurance est
## multipliée par Ennemis.ENDURANCE_PAR_POINT_ENNEMI à la création depuis le 2026-11-03, mêmes PV) ; depuis le 2026-10-29,
## endurance divisée par 5 (mêmes PV : loup 10-20, squelette 20) et autres caractéristiques à 0 (décision de
## l'utilisateur, en attendant la refonte ; avant : loup endurance 7-9, force 1-3, dextérité 2-4 ; squelette 9-11,
## 2-4, 1-2 ; intelligence et sagesse 0-1). Vulnérabilités et résistances en pourcentage (0,40 = 40 %, Degats.multiplicateur),
## séparées de l'armure et des résistances en points depuis le 2026-10-30.
const SORTES := {
	"loup": {"nom": "Loup", "type_ennemi": "bête", "image": "loup01.png",
		"endurance": [5, 6], "force": [0, 0], "dextérité": [0, 0], "intelligence": [0, 0], "sagesse": [0, 0],
		"attaque": "Morsure", "description": "Morsure : des crocs qui percent la chair.",
		"des": {"perforant": [[4, 2]]}, "vulnerabilites": {"feu": 0.40}, "resistances_pct": {}},
	"squelette": {"nom": "Squelette", "type_ennemi": "mort-vivant", "image": "squelette01.png",
		"endurance": [6, 6], "force": [0, 0], "dextérité": [0, 0], "intelligence": [0, 0], "sagesse": [0, 0],
		"attaque": "Épée rouillée", "description": "Un coup d'épée rouillée, lent mais lourd.",
		"des": {"tranchant": [[4, 2]]}, "vulnerabilites": {"contondant": 0.40}, "resistances_pct": {"perforant": 0.20}},
	# Squelettes refaits par l'utilisateur (2026-11-06, sous-dossiers de « C:/ia image/ennemis/squelette ») : mêmes
	# défenses que le squelette. Guerrier : une sorte de plus (décision de l'utilisateur), mêmes règles que le squelette
	# en attendant ses réglages. Mage (ombre, invoque) et élémentaliste (feu, froid, foudre) : seulement dans les
	# cryptes. Squelette invoqué : appelé en combat par le mage (Invocation_squelette, Combat.invoquer), faible, tombe
	# en poussière si son invocateur meurt. PV, compétences et IA réglables dans l'éditeur des ennemis.
	"guerrier_squelette": {"nom": "Guerrier squelette", "type_ennemi": "mort-vivant", "image": "guerrier_squelette01.png",
		"endurance": [6, 6], "force": [0, 0], "dextérité": [0, 0], "intelligence": [0, 0], "sagesse": [0, 0],
		"attaque": "Épée longue rouillée", "description": "Un coup d'épée longue rouillée.",
		"des": {"tranchant": [[4, 2]]}, "vulnerabilites": {"contondant": 0.40}, "resistances_pct": {"perforant": 0.20}},
	"mage_squelette": {"nom": "Mage squelette", "type_ennemi": "mort-vivant", "image": "mage_squelette01.png",
		"endurance": [5, 6], "force": [0, 0], "dextérité": [0, 0], "intelligence": [0, 0], "sagesse": [0, 0],
		"attaque": "Coup de bâton", "description": "Un coup de son bâton noueux.",
		"des": {"contondant": [[2, 2]]}, "vulnerabilites": {"contondant": 0.40}, "resistances_pct": {"perforant": 0.20}},
	"elementaliste_squelette": {"nom": "Élémentaliste squelette", "type_ennemi": "mort-vivant",
		"image": "elementaliste_squelette01.png",
		"endurance": [5, 6], "force": [0, 0], "dextérité": [0, 0], "intelligence": [0, 0], "sagesse": [0, 0],
		"attaque": "Coup de bâton", "description": "Un coup de son bâton gravé.",
		"des": {"contondant": [[2, 2]]}, "vulnerabilites": {"contondant": 0.40}, "resistances_pct": {"perforant": 0.20}},
	"squelette_invoque": {"nom": "Squelette invoqué", "type_ennemi": "mort-vivant", "image": "squelette_invoque01.png",
		"endurance": [3, 3], "force": [0, 0], "dextérité": [0, 0], "intelligence": [0, 0], "sagesse": [0, 0],
		"attaque": "Lame ébréchée", "description": "Un coup de lame ébréchée.",
		"des": {"tranchant": [[3, 2]]}, "vulnerabilites": {"contondant": 0.40}, "resistances_pct": {"perforant": 0.20}},
}
## Squelettes qui forment des groupes (le féticheur, le mage et l'élémentaliste peuvent s'y joindre).
const SQUELETTES_DE_GROUPE := ["squelette", "guerrier_squelette"]
## Squelettes lents (vitesse de poursuite Aventure.VITESSE_SQUELETTES).
const SQUELETTES := ["squelette", "guerrier_squelette", "mage_squelette", "elementaliste_squelette", "squelette_invoque"]


static func est_creature(sous_classe) -> bool:
	return SORTES.has(str(sous_classe))


## Membre de groupe (Aventure.membres) pour la sorte ``sorte``.
static func membre(sorte: String) -> Dictionary:
	return {"classe": "creature", "sous_classe": sorte, "image": SORTES[sorte]["image"]}


## Un loup ou un squelette prêt à combattre.
static func creer(donjon, sorte: String) -> Gobelin:
	var r: Dictionary = SORTES[sorte]
	var e := Gobelin.nouveau(donjon)
	e._d["nom"] = String(r["nom"])
	e._d["classe"] = "creature"
	e._d["sous_classe"] = sorte
	e._d["type_ennemi"] = r["type_ennemi"]
	for c in ["endurance", "force", "dextérité", "intelligence", "sagesse"]:
		var b: Array = r[c] if c != "endurance" else Gobelin.bornes_endurance(sorte)  # PV de l'éditeur (2026-11-04)
		var points := randi_range(b[0], b[1])
		if c == "endurance":
			points *= Ennemis.ENDURANCE_PAR_POINT_ENNEMI  # « 1 point = 10 PV » (2026-11-03)
		e.set(c, U.ga(e, c, 0) + points)
	e.calculer_stats()
	e.points_de_vie = e.points_de_vie_max
	e.mana = e.mana_max
	var attaque = Competences.creer("Coup_d_epee")
	attaque._d["nom"] = r["attaque"]
	attaque._d["description"] = r["description"]
	attaque._d["type_degats"] = r["des"].keys()
	attaque._d["cout_mana"] = 0
	e._d["competences"] = [attaque]
	for nom in DonneesEnnemis.competences_de(sorte):  # compétences données dans l'éditeur des ennemis
		if String(nom) != "Coup_d_epee":
			var c := Competences.creer(String(nom))
			if c != null:
				e._d["competences"].append(c)
	e._d["des_fixes"] = r["des"].duplicate(true)
	Degats.ajouter_pourcentages(e, r["vulnerabilites"], r["resistances_pct"])
	e._d["image"] = r["image"]
	e._d["sans_animation"] = true
	return e
