class_name Gobelin
extends Ennemis
## Ennemi gobelin, décliné en classes et sous-classes.

static var compteur := 0

const PREFIXES := ["Gor", "Grom", "Gruk", "Guz", "Grog", "Zog", "Kruk", "Grib", "Skrak", "Nog", "Blik", "Snag", "Murg",
	"Vrog", "Kog", "Drub", "Skab", "Frug", "Krag", "Brak", "Slub", "Dreg", "Glub", "Thog", "Zruk", "Narg", "Fleb",
	"Kriz", "Grub", "Drak"]


## Gobelin de base (1 PA, caractéristiques à 0), à compléter par un ``generer_*``.
static func nouveau(donjon, _niveau = 0) -> Gobelin:
	compteur += 1
	var g := Gobelin.new()
	g.initialiser_ennemi({
		"nom": "Gobelin", "type_ennemi": "humanoïde", "niveau": 0, "points_de_vie_max": 0,
		"regen_de_points_de_vie": 0, "regen_de_points_de_vie_combat": 0, "mana_max": 0, "regen_de_mana": 0,
		"points_d_action_max": 1, "force": 0, "dextérité": 0, "endurance": 0, "intelligence": 0, "sagesse": 0,
		"puissance_magique": 3, "degats_base": 3, "armure": 0, "coefficient_reduction_armure": 0.02,
		"chance_esquive": 0, "chance_de_toucher": 0.85, "chance_de_parer": 0,
		"chance_de_coup_critique": 0, "degats_critique": 1.5,
		"arme": null, "competences": [], "magies_apprises": [],
	}, donjon)
	g._d["chance_de_coup_critique_magique"] = 0.0
	g._d["classe"] = null
	g._d["sous_classe"] = null
	g._d["alteration"] = {}
	g._d["alterations_actives"] = {}
	g._d["arme_equipee"] = null
	g._d["armures_equipees"] = []
	return g


func _completer(classe: String, sous_classe: String) -> Gobelin:
	_d["classe"] = classe
	_d["sous_classe"] = sous_classe
	_d["nom"] = definir_nom_gobelin(sous_classe)
	_d["competences"] = definir_competence_gobelin(classe, sous_classe)
	definir_attribut_gobelin(self, classe, sous_classe)
	generer_inventaire_gobelin(self)
	equiper_item()
	_d["image"] = IMAGES_GOBELINS_PAR_SOUS_CLASSE.get(sous_classe, ["gobelin_defaut.png"]).pick_random()
	return self


## Classe et sous-classe tirées au hasard, ou imposées par ``cs`` ([classe, sous-classe]).
func generer_gobelin(_donjon = null, _niveau = 0, cs: Array = []) -> Gobelin:
	if cs.is_empty():
		cs = definir_classe_gobelin()
	return _completer(cs[0], cs[1])


## Boss : PV × 14, dégâts × 0,8, 1 PA (2 avant le 2026-10-20), sprite bien plus grand.
func generer_boss_gobelin(_donjon = null, _niveau = 0, cs: Array = []) -> Gobelin:
	if cs.is_empty():
		cs = definir_classe_gobelin()
	_d["classe"] = cs[0]
	_d["sous_classe"] = cs[1]
	_d["nom"] = definir_nom_gobelin(cs[1])
	_d["competences"] = definir_competence_gobelin(cs[0], cs[1])
	_d["est_boss"] = true
	definir_attribut_gobelin(self, cs[0], cs[1])
	generer_inventaire_gobelin(self)
	equiper_item()
	_d["image"] = IMAGES_GOBELINS_PAR_SOUS_CLASSE.get(cs[1], ["gobelin_defaut.png"]).pick_random()
	appliquer_rang_special(BOSS)
	return self


## Élite (ancien mini-boss) : un gobelin normal, « Élite », PV × 6, dégâts × 0,8.
func generer_mini_boss_gobelin(donjon = null, niveau = 0, cs: Array = []) -> Gobelin:
	generer_gobelin(donjon, niveau, cs)
	_d["est_mini_boss"] = true
	_d["nom"] = "Élite " + _d["nom"]
	appliquer_rang_special(MINI_BOSS)
	return self


func appliquer_rang_special(regles: Dictionary) -> void:
	_d["points_de_vie_max"] = int(_d["points_de_vie_max"] * regles["pv"])
	_d["points_de_vie"] = _d["points_de_vie_max"]
	_d["pourcentage_degats_physique"] *= regles["degats"]
	_d["pourcentage_degats_magique"] *= regles["degats"]
	_d["pourcentage_degats_elementaire"] *= regles["degats"]
	_d["pourcentage_degats_lumière"] /= regles["degats"]
	_d["points_d_action_max"] = max(_d["points_d_action_max"], regles["pa"])
	_d["points_d_action"] = _d["points_d_action_max"]
	_d["taille_affichage"] = regles["taille"]


func generer_archer_gobelin(_donjon = null, _niveau = 0) -> Gobelin:
	return _completer("guerrier", "archer")


func generer_lancier_gobelin(_donjon = null, _niveau = 0) -> Gobelin:
	return _completer("guerrier", "lancier")


func generer_combattant_gobelin(_donjon = null, _niveau = 0) -> Gobelin:
	return _completer("guerrier", "combattant")


func generer_defenseur_gobelin(_donjon = null, _niveau = 0) -> Gobelin:
	return _completer("guerrier", "defenseur")


func generer_sorcier_gobelin(_donjon = null, _niveau = 0) -> Gobelin:
	return _completer("mage", "sorcier")


func generer_feticheur_gobelin(_donjon = null, _niveau = 0) -> Gobelin:
	return _completer("mage", "feticheur")


## Classe « soutient » (avec un « t ») comme dans le jeu d'origine : ni compétences ni attributs de soutien.
func generer_chaman_gobelin(_donjon = null, _niveau = 0) -> Gobelin:
	return _completer("soutient", "chaman")


## [classe, sous-classe] : guerrier (archer, combattant, lancier ou défenseur), mage (sorcier, féticheur), soutien (chaman).
static func definir_classe_gobelin() -> Array:
	var classe = ["guerrier", "mage", "soutien"].pick_random()
	var sous_classe := ""
	if classe == "guerrier":
		if ["offensif", "defensif"].pick_random() == "offensif":
			sous_classe = ["archer", "combattant", "lancier"].pick_random()
		else:
			sous_classe = "defenseur"
	elif classe == "mage":
		sous_classe = ["sorcier", "feticheur"].pick_random()
	else:
		sous_classe = "chaman"
	return [classe, sous_classe]


## Type de dégâts principal d'une sous-classe : le plus fréquent parmi ses compétences (physique, magique ou
## élémentaire ; ni soin, ni poison), à égalité le plus fort (dés moyens). Sert à l'armure anti-boss de l'étage,
## en attendant la refonte des ennemis.
static func type_degats_principal(classe: String, sous_classe: String) -> String:
	var nombre := {}
	var force := {}
	for c in definir_competence_gobelin(classe, sous_classe):
		for t in U.ga(c, "type_degats", []):
			if not t in Degats.TYPES:
				continue
			nombre[t] = nombre.get(t, 0) + 1
			force[t] = force.get(t, 0.0) + Formules.moyenne(Formules.DES_TYPES.get(t, []))
	if nombre.is_empty():
		return "tranchant"
	var meilleur: String = nombre.keys()[0]
	for t in nombre:
		if nombre[t] > nombre[meilleur] or (nombre[t] == nombre[meilleur] and force[t] > force[meilleur]):
			meilleur = t
	return meilleur


static func definir_nom_gobelin(sous_classe: String) -> String:
	return PREFIXES.pick_random() + " " + sous_classe


static func definir_competence_gobelin(classe: String, sous_classe: String) -> Array:
	var noms := []
	if classe == "guerrier":
		noms = ["Coup_d_epee", "Botte_secrete", "Cri_de_guerre"]
		if sous_classe == "lancier":
			noms += ["Coup_de_lance", "Rafale_de_lance", "Perforation"]
		elif sous_classe == "archer":
			noms += ["Tir", "Tir_precis", "Tir_empoisonne", "Précision"]
		elif sous_classe == "defenseur":
			noms += ["Coup_de_gourdin", "Grand_coup_de_gourdin", "Protection"]
	elif classe == "mage":
		noms = ["Coup_de_baton", "Boule_de_feu"]
		if sous_classe == "sorcier":
			noms += ["Eclair", "Trait_des_Ombres", "Projectile_des_ombres", "Enflammer"]
		elif sous_classe == "feticheur":
			noms += ["Projectile_des_ombres", "Caresse_des_ombres", "Enflammer", "Silence", "Soin_mineur", "Soin"]
	elif classe == "soutien":
		noms = ["Coup_de_baton", "Boule_de_feu", "Projectile_des_ombres", "Silence", "Soin_mineur", "Soin",
			"Soin_majeur", "Recupe"]
	var competences := []
	for nom in noms:
		competences.append(Competences.creer(nom))
	return competences


## Endurance de départ selon la sous-classe (PV = endurance × Ennemis.PV_PAR_ENDURANCE), bornes comprises.
## Divisée par 5 le 2026-10-29 (10-12 et 6-8 avant) quand un point est passé de 2 à 10 PV, pour garder à peu près
## les mêmes PV (choix de l'utilisateur) : 20 PV pour combattant et défenseur, 10 ou 20 pour les autres.
const ENDURANCE_PAR_SOUS_CLASSE := {
	"combattant": [2, 2], "defenseur": [2, 2],
	"lancier": [1, 2], "archer": [1, 2],
	"sorcier": [1, 2], "feticheur": [1, 2], "chaman": [1, 2],
}


## Caractéristiques tirées selon la sous-classe : [principale, secondaire] ; bornes comprises.
## Principale 1 à 4, secondaire et toutes les autres 1 à 2 (endurance : ENDURANCE_PAR_SOUS_CLASSE).
const STATS_PAR_SOUS_CLASSE := {
	"combattant": ["force", "dextérité"], "lancier": ["force", "dextérité"],
	"archer": ["dextérité", "force"], "defenseur": ["force", "sagesse"],
	"sorcier": ["intelligence", "sagesse"], "feticheur": ["intelligence", "sagesse"],
	"chaman": ["sagesse", "intelligence"],
}
## Toutes à 0 depuis le 2026-10-29 (décision de l'utilisateur, en attendant la refonte des ennemis) ; avant :
## principale 1 à 4, secondaire 1 à 2, autres 1 à 2.
const POINTS_STAT_PRINCIPALE := [0, 0]
const POINTS_STAT_SECONDAIRE := [0, 0]
const POINTS_AUTRES_STATS := [0, 0]
## Résistances et vulnérabilités en pourcentage par sous-classe (Degats.multiplicateur). Chaman : fiche de l'utilisateur
## (« particularité des chamans.odt », appliquée le 2026-10-27) : 15 % au feu, au froid et à la foudre, faible à l'ombre (40 %).
const RESISTANCES_PAR_SOUS_CLASSE := {"chaman": {"feu": 0.15, "froid": 0.15, "foudre": 0.15}}
const VULNERABILITES_PAR_SOUS_CLASSE := {"chaman": {"ombre": 0.40}}
## Parade (bornes en %) des sous-classes qui parent ; les autres ont 0.
const PARADE_PAR_SOUS_CLASSE := {"combattant": [2, 4], "lancier": [2, 4], "defenseur": [2, 4]}


## Le critique ne vient que des caractéristiques (Ennemis.calculer_stats : dextérité, intelligence).
static func definir_attribut_gobelin(g, classe: String, sous_classe: String) -> void:
	var bornes: Array = ENDURANCE_PAR_SOUS_CLASSE.get(sous_classe, [6, 8])
	g.endurance = randi_range(bornes[0], bornes[1]) + Ennemis.bonus_globaux["endurance"]
	var stats: Array = STATS_PAR_SOUS_CLASSE.get(sous_classe, ["force", "dextérité"])
	for c in ["force", "dextérité", "intelligence", "sagesse"]:
		var b: Array = POINTS_AUTRES_STATS
		if c == stats[0]:
			b = POINTS_STAT_PRINCIPALE
		elif c == stats[1]:
			b = POINTS_STAT_SECONDAIRE
		g.set(c, U.ga(g, c, 0) + randi_range(b[0], b[1]))
	Degats.ajouter_pourcentages(g, VULNERABILITES_PAR_SOUS_CLASSE.get(sous_classe, {}), RESISTANCES_PAR_SOUS_CLASSE.get(sous_classe, {}))
	var parade: Array = PARADE_PAR_SOUS_CLASSE.get(sous_classe, [0, 0])
	g.chance_de_parer = randi_range(parade[0], parade[1]) / 100.0
	g.points_de_vie = g.points_de_vie_max
	g.mana = g.mana_max
	g.calculer_stats()


## Les gobelins ne portent aucun équipement : rien n'est lâché à leur mort.
static func generer_inventaire_gobelin(g) -> void:
	g.inventaire = []
