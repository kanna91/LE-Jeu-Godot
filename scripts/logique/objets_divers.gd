class_name ObjetsDivers
extends RefCounted
## Objets à ramasser hors équipement et potions (demande de l'utilisateur, 2026-10-31, catalogue fourni le 2026-11-03).
## Trois catégories, chacune avec son onglet dans l'inventaire et chez le marchand :
## - « divers » : objets neutres, sans effet (vaisselle, argenterie, gemmes, objets cassés) : quêtes, revente ;
## - « nourriture » : se mange (double-clic dans l'inventaire) et rend ``pv`` PV ;
## - « ingredient » : ne se mange pas, servira à cuisiner (à venir).
## Un objet : un ``Objet`` de ``type_objet`` égal à sa catégorie, avec ``sorte`` (clé de SORTES), ``description``
## et ``pv`` (nourriture). Les objets identiques (même nom) s'empilent dans les listes.
## Catalogue : ``donnees/objets_divers.json`` (ajouter un objet = une ligne dans ce fichier).

const CATEGORIES := ["divers", "nourriture", "ingredient"]
const NOMS_CATEGORIES := {"divers": "Divers", "nourriture": "Nourriture", "ingredient": "Ingrédient"}
## Sortes d'objets : {clé : nom lisible}.
const SORTES := {"argenterie": "Argenterie", "nourriture": "Nourriture", "casse": "Objet cassé", "quete": "Objet de quête",
	"vaisselle": "Vaisselle", "objet": "Objet", "tresor": "Trésor", "gemme": "Pierre précieuse", "materiau": "Matériau",
	"plat": "Plat", "fruit": "Fruit", "legume": "Légume", "viande": "Viande"}
## Catalogue lu dans donnees/objets_divers.json : [{nom, categorie, sorte, valeur, description, pv?}, ...].
static var _catalogue: Array = []


static func catalogue() -> Array:
	if _catalogue.is_empty():
		var f := FileAccess.open("res://donnees/objets_divers.json", FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text()) if f != null else null
		if d is Dictionary:
			_catalogue = d.get("objets", [])
	return _catalogue


## Noms des objets du catalogue d'une catégorie (toutes si ``categorie`` est vide).
static func noms(categorie := "") -> Array:
	var liste := []
	for l in catalogue():
		if categorie == "" or l.get("categorie", "divers") == categorie:
			liste.append(String(l["nom"]))
	return liste


## Clés rouillées du héros, montrées dans la catégorie « Divers » de l'inventaire (elles restent un simple
## compteur, ``joueur.cles`` : cet objet ne sert qu'à l'affichage).
const NOM_CLE := "Clé rouillée"


## Crée un objet divers : ``nom``, ``sorte`` (clé de SORTES), prix de revente ``valeur``, ``description``.
static func creer(nom: String, sorte: String, valeur: int, description: String) -> Objet:
	var o := Objet.nouveau(nom, "divers", description, valeur)
	o._d["sorte"] = sorte
	o._d["description"] = description
	return o


## Crée l'objet du catalogue nommé ``nom`` (null s'il n'y est pas).
static func depuis_catalogue(nom: String):
	for l in catalogue():
		if String(l["nom"]) == nom:
			var o := creer(String(l["nom"]), String(l.get("sorte", "objet")), int(l.get("valeur", 0)), String(l.get("description", "")))
			o._d["type_objet"] = String(l.get("categorie", "divers"))
			if l.has("pv"):
				o._d["pv"] = int(l["pv"])
			return o
	return null


## Un objet au hasard du catalogue d'une catégorie (null si elle est vide).
static func au_hasard(categorie: String):
	var liste := noms(categorie)
	return depuis_catalogue(liste.pick_random()) if not liste.is_empty() else null


## Mange un objet de nourriture : rend ses PV (sans dépasser le maximum) ; renvoie les PV gagnés.
static func manger(joueur, objet) -> int:
	var avant := int(joueur.points_de_vie)
	joueur.points_de_vie = mini(int(joueur.points_de_vie) + int(U.num(objet, "pv")), int(joueur.points_de_vie_max))
	if objet in joueur.inventaire:
		joueur.inventaire.erase(objet)
	return int(joueur.points_de_vie) - avant


## Objet d'affichage de la clé du boss de l'étage ``etage`` (jamais rangé dans l'inventaire).
static func objet_cle_boss(etage: int) -> Objet:
	var o := Objet.nouveau("Clé du boss (étage %d)" % etage, "cle", "", 0)
	o._d["description"] = "Ouvre la salle du boss de l'étage %d, et elle seule." % etage
	return o


## Objet d'affichage des clés du héros (jamais rangé dans l'inventaire).
static func objet_cles() -> Objet:
	var o := Objet.nouveau(NOM_CLE, "cle", "", 0)
	o._d["description"] = "Ouvre une salle fermée à clé (une clé par porte)."
	return o
