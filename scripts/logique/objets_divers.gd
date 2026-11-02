class_name ObjetsDivers
extends RefCounted
## Objets « divers » (demande de l'utilisateur, 2026-10-31) : objets neutres, sans effet, qui ne s'équipent ni ne
## s'utilisent — argenterie, nourriture, objets cassés et inutilisables. Ils serviront parfois pour des quêtes, ou
## à la revente chez le marchand (``valeur`` = prix de rachat). Catégorie « Divers » de l'inventaire et du marchand.
## Un objet divers : un ``Objet`` de ``type_objet`` « divers », avec ``sorte`` (clé de SORTES) et ``description``.
## Les objets identiques (même nom) s'empilent dans les listes.
## **Le catalogue est vide** : l'utilisateur fournira lui-même la liste des objets (2026-10-31). Rien n'en donne
## encore dans le jeu (ni fouille, ni marchand).

## Sortes d'objets divers : {clé : nom lisible} (les exemples de l'utilisateur).
const SORTES := {"argenterie": "Argenterie", "nourriture": "Nourriture", "casse": "Objet cassé", "quete": "Objet de quête"}
## Catalogue : [nom, sorte, prix de revente en or, description] — à remplir avec la liste de l'utilisateur.
const CATALOGUE := []
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
	for l in CATALOGUE:
		if l[0] == nom:
			return creer(l[0], l[1], l[2], l[3])
	return null


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
