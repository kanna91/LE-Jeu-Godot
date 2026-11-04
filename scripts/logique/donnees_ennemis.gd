class_name DonneesEnnemis
extends RefCounted
## Données des ennemis modifiables dans l'éditeur (2026-11-04, demande de l'utilisateur : « assigner et façonner les
## compétences et les altérations qui y sont associées, les distribuer aux ennemis ; le gestionnaire de l'IA ; leur
## butin, avec la liste de tous les objets du jeu »). Menu Données › Ennemis de l'éditeur de zones (F4,
## EditeurEnnemis).
##
## ``donnees/ennemis.json`` : pour chaque sorte d'ennemi (SORTES) :
## - « pv » : [min, max] au premier étage (par pas de 10 : Gobelin.bornes_endurance) ;
## - « competences » : noms de classe des compétences qu'il connaît (Competences) ;
## - « ia » : règles jouées dans l'ordre, la première qui passe est jouée : {« competence », « chance » (%),
##   « si » : [[condition, valeur], ...] (toutes vraies), « cible » : « auto » ou « allie_blesse »}. Si aucune ne passe :
##   son attaque de secours (Ennemis.ATTAQUES_DE_SECOURS) ;
## - « butin » : objets lâchés à sa mort, chacun avec sa « chance » (%) : même format que le butin posé dans une
##   salle (Fouille.ramasser : catégorie, objet, potion, quantité, rang).
## ``donnees/competences_editees.json`` : {« competences » : {nom de classe : réglages qui remplacent ceux de la
## compétence, « base » pour une nouvelle compétence copiée d'une autre}, « alterations » : {nom : {« duree »,
## « cumul_max »}}}. Les réglages s'appliquent tels quels, après la normalisation (ValeurCompetences) : ce qui est
## réglé est ce qui est joué. Ils valent aussi pour le héros quand il a la même compétence.
##
## Les valeurs par défaut (defaut()) sont celles du jeu avant l'éditeur : PV du 2026-11-04, compétences des gobelins
## (ancien Gobelin.definir_competence_gobelin) et IA (ancien Ennemis.mecanique_ennemis, traduite en règles).

const FICHIER := "res://donnees/ennemis.json"
const FICHIER_COMPETENCES := "res://donnees/competences_editees.json"
## Sortes réglables : les 7 classes de gobelins, le loup et le squelette.
const SORTES := ["combattant", "lancier", "archer", "defenseur", "sorcier", "feticheur", "chaman", "loup", "squelette"]
const NOMS := {"combattant": "Gobelin combattant", "lancier": "Gobelin lancier", "archer": "Gobelin archer",
	"defenseur": "Gobelin défenseur", "sorcier": "Gobelin sorcier", "feticheur": "Gobelin féticheur",
	"chaman": "Gobelin chaman", "loup": "Loup", "squelette": "Squelette"}
## Conditions des règles d'IA : nom → texte (… : une valeur à choisir).
const CONDITIONS := {
	"toujours": "Toujours",
	"soi_blesse": "Il est sous la moitié de ses PV (et pas encore soigné)",
	"allie_blesse": "Un allié (ou lui) est sous la moitié de ses PV",
	"a_des_allies": "Il a au moins un allié vivant",
	"heros_sans": "Le héros n'a pas l'altération…",
	"heros_avec": "Le héros a l'altération…",
	"soi_sans": "Il n'a pas l'altération…",
	"groupe_sans": "Aucun ennemi n'a l'altération…",
	"groupe_avec": "Un ennemi a l'altération…",
	"heros_sans_ses_alterations": "Le héros n'a pas déjà toutes les altérations de la compétence",
	"mana_au_moins": "Il a au moins … mana",
}
const CONDITIONS_A_ALTERATION := ["heros_sans", "heros_avec", "soi_sans", "groupe_sans", "groupe_avec"]
const CONDITIONS_A_NOMBRE := ["mana_au_moins"]
const CIBLES := {"auto": "Cible automatique", "allie_blesse": "L'allié le plus blessé"}
## Réglages d'une compétence modifiables dans l'éditeur.
const CHAMPS_COMPETENCE := ["nom", "description", "cout_mana", "cout_action", "nombre_cible", "nombre_attaque",
	"type_degats", "multiplicateur_degats", "type_alteration", "duree_bonus"]

## Compétences par défaut de chaque sorte (ancien Gobelin.definir_competence_gobelin ; loup et squelette : leur attaque,
## une copie renommée de Coup_d_epee faite par Creatures).
const COMPETENCES_DEFAUT := {
	"combattant": ["Coup_d_epee", "Botte_secrete", "Cri_de_guerre"],
	"lancier": ["Coup_d_epee", "Botte_secrete", "Cri_de_guerre", "Coup_de_lance", "Rafale_de_lance", "Perforation"],
	"archer": ["Coup_d_epee", "Botte_secrete", "Cri_de_guerre", "Tir", "Tir_precis", "Tir_empoisonne", "Précision"],
	"defenseur": ["Coup_d_epee", "Botte_secrete", "Cri_de_guerre", "Coup_de_gourdin", "Grand_coup_de_gourdin", "Protection"],
	"sorcier": ["Coup_de_baton", "Boule_de_feu", "Trait_des_Ombres", "Projectile_des_ombres"],
	"feticheur": ["Coup_de_baton", "Boule_de_feu", "Projectile_des_ombres", "Caresse_des_ombres", "Enflammer", "Silence", "Soin_mineur"],
	"chaman": ["Coup_de_baton", "Boule_de_feu", "Projectile_des_ombres", "Silence", "Soin_mineur", "Recupe"],
	"loup": ["Coup_d_epee"],
	"squelette": ["Coup_d_epee"],
}
## IA par défaut : l'ancienne IA codée en dur, traduite en règles (mêmes chances).
const IA_DEFAUT := {
	"combattant": [
		{"competence": "Cri_de_guerre", "chance": 100, "si": [["a_des_allies", ""], ["groupe_sans", "rage"]]},
		{"competence": "Botte_secrete", "chance": 33},
		{"competence": "Coup_d_epee", "chance": 100}],
	"lancier": [
		{"competence": "Coup_de_lance", "chance": 67},
		{"competence": "Perforation", "chance": 100, "si": [["heros_sans", "saignement"]]},
		{"competence": "Rafale_de_lance", "chance": 100}],
	"archer": [
		{"competence": "Précision", "chance": 100, "si": [["soi_sans", "précis"]]},
		{"competence": "Tir", "chance": 67},
		{"competence": "Tir_precis", "chance": 50},
		{"competence": "Tir_empoisonne", "chance": 100}],
	"defenseur": [
		{"competence": "Coup_de_gourdin", "chance": 67},
		{"competence": "Grand_coup_de_gourdin", "chance": 100, "si": [["groupe_avec", "protection"]]},
		{"competence": "Protection", "chance": 100}],
	"sorcier": [
		{"competence": "Boule_de_feu", "chance": 33, "si": [["mana_au_moins", "6"]]},
		{"competence": "Trait_des_Ombres", "chance": 50, "si": [["mana_au_moins", "6"]]},
		{"competence": "Projectile_des_ombres", "chance": 100, "si": [["heros_sans", "brulure"]]},
		{"competence": "Boule_de_feu", "chance": 50},
		{"competence": "Trait_des_Ombres", "chance": 100},
		{"competence": "Coup_de_baton", "chance": 100}],
	"feticheur": [
		{"competence": "Soin_mineur", "chance": 33, "si": [["soi_blesse", ""]]},
		{"competence": "Caresse_des_ombres", "chance": 25, "si": [["heros_sans_ses_alterations", ""]]},
		{"competence": "Enflammer", "chance": 33, "si": [["heros_sans_ses_alterations", ""]]},
		{"competence": "Silence", "chance": 50, "si": [["heros_sans_ses_alterations", ""]]},
		{"competence": "Projectile_des_ombres", "chance": 100}],
	"chaman": [
		{"competence": "Soin_mineur", "chance": 17, "si": [["allie_blesse", ""]], "cible": "allie_blesse"},
		{"competence": "Recupe", "chance": 20, "si": [["allie_blesse", ""]], "cible": "allie_blesse"},
		{"competence": "Boule_de_feu", "chance": 100}],
	"loup": [{"competence": "Coup_d_epee", "chance": 100}],
	"squelette": [{"competence": "Coup_d_epee", "chance": 100}],
}

static var _donnees := {}
static var _editions := {}


## Valeurs par défaut (le jeu sans fichier).
static func defaut() -> Dictionary:
	var sortes := {}
	for s in SORTES:
		var bornes: Array
		if Creatures.SORTES.has(s):
			bornes = Creatures.SORTES[s]["endurance"]
		else:
			bornes = Gobelin.ENDURANCE_PAR_SOUS_CLASSE.get(s, [5, 6])
		sortes[s] = {"pv": [int(bornes[0]) * 10, int(bornes[1]) * 10], "competences": COMPETENCES_DEFAUT[s].duplicate(),
			"ia": IA_DEFAUT[s].duplicate(true), "butin": []}
	return {"sortes": sortes}


## Données des sortes (fichier, complété par les valeurs par défaut).
static func donnees() -> Dictionary:
	if _donnees.is_empty():
		_donnees = defaut()
		var lu = U.charger_json("ennemis.json")
		if lu is Dictionary and lu.get("sortes") is Dictionary:
			for s in lu["sortes"]:
				if _donnees["sortes"].has(s) and lu["sortes"][s] is Dictionary:
					_donnees["sortes"][s].merge(lu["sortes"][s], true)
	return _donnees


## Éditions des compétences et des altérations.
static func editions() -> Dictionary:
	if _editions.is_empty():
		var lu = U.charger_json("competences_editees.json")
		_editions = lu if lu is Dictionary else {}
		for cle in ["competences", "alterations"]:
			if not (_editions.get(cle) is Dictionary):
				_editions[cle] = {}
	return _editions


## Relit les deux fichiers (après un enregistrement de l'éditeur).
static func recharger() -> void:
	_donnees = {}
	_editions = {}
	Alterations._definitions = {}


static func sorte(s: String) -> Dictionary:
	return donnees()["sortes"].get(s, {})


static func competences_de(s: String) -> Array:
	return sorte(s).get("competences", COMPETENCES_DEFAUT.get(s, []))


static func ia_de(s: String) -> Array:
	return sorte(s).get("ia", [])


static func butin_de(s: String) -> Array:
	return sorte(s).get("butin", [])


## PV [min, max] de la sorte au premier étage.
static func pv_de(s: String) -> Array:
	var pv = sorte(s).get("pv", [50, 60])
	return pv if pv is Array and pv.size() == 2 else [50, 60]


## Toutes les compétences connues : celles du jeu, les sorts et les nouvelles de l'éditeur (noms de classe, triés).
static func toutes_les_competences() -> Array:
	var noms: Array = Competences.classes_de_competences().duplicate() + Competences.classes_de_sorts()
	for n in editions()["competences"]:
		if not n in noms:
			noms.append(n)
	noms.sort()
	return noms


## Applique les réglages de l'éditeur à une compétence qui vient d'être créée (Competences.creer).
static func appliquer_competence(comp, nom_classe: String) -> void:
	var e = editions()["competences"].get(nom_classe)
	if not (e is Dictionary):
		return
	comp.nom_classe = nom_classe
	for champ in CHAMPS_COMPETENCE:
		if not e.has(champ):
			continue
		var v = e[champ]
		if champ in ["cout_mana", "cout_action", "nombre_cible", "nombre_attaque", "duree_bonus"]:
			v = int(v)
		elif champ == "multiplicateur_degats":
			v = float(v)
		elif v is Array or v is Dictionary:
			v = v.duplicate(true)
		comp.set(champ, v)
	if e.has("type_alteration"):
		var alt := {}
		for nom in e["type_alteration"]:
			if float(e["type_alteration"][nom]) > 0:
				alt[nom] = float(e["type_alteration"][nom])
		comp.type_alteration = alt


## Nom de classe de base d'une nouvelle compétence (copie d'une autre), ou "".
static func base_de(nom_classe: String) -> String:
	var e = editions()["competences"].get(nom_classe)
	return String(e.get("base", "")) if e is Dictionary else ""


## Applique les durées et cumuls réglés dans l'éditeur aux définitions des altérations (Alterations.defs).
static func appliquer_alterations(defs: Dictionary) -> void:
	var e: Dictionary = editions()["alterations"]
	for nom in e:
		if not defs.has(nom) or not (e[nom] is Dictionary):
			continue
		if e[nom].has("duree"):
			defs[nom]["duree"] = int(e[nom]["duree"])
		if e[nom].has("cumul_max"):
			defs[nom]["cumul_max"] = int(e[nom]["cumul_max"])


## Écrit les deux fichiers ; renvoie "" ou un message d'erreur.
static func enregistrer(sortes_d: Dictionary, editions_d: Dictionary) -> String:
	for paire in [[FICHIER, sortes_d], [FICHIER_COMPETENCES, editions_d]]:
		var f := FileAccess.open(paire[0], FileAccess.WRITE)
		if f == null:
			return "impossible d'écrire " + String(paire[0]).trim_prefix("res://")
		f.store_string(JSON.stringify(paire[1], " ", false))
		f.close()
	recharger()
	return ""
