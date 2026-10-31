class_name ObjetsDivers
extends RefCounted
## Objets « divers » (demande de l'utilisateur, 2026-10-31) : objets neutres, sans effet, qui ne s'équipent ni ne
## s'utilisent — argenterie, nourriture, objets cassés et inutilisables. Ils serviront parfois pour des quêtes, ou
## à la revente chez le marchand (``valeur`` = prix de rachat). Catégorie « Divers » de l'inventaire et du marchand.
## Un objet divers : un ``Objet`` de ``type_objet`` « divers », avec ``sorte`` (clé de SORTES) et ``description``.
## Les objets identiques (même nom) s'empilent dans les listes.
## **Noms, descriptions et prix choisis par Claude, à valider par l'utilisateur.**

## Sortes d'objets divers : {clé : nom lisible}.
const SORTES := {"argenterie": "Argenterie", "nourriture": "Nourriture", "casse": "Objet cassé"}
## Catalogue : [nom, sorte, prix de revente en or, description].
const CATALOGUE := [
	["Cuillère en argent", "argenterie", 25, "Une petite cuillère ternie, gravée d'un blason effacé."],
	["Gobelet d'argent terni", "argenterie", 40, "Il a dû servir à de grands banquets, il y a longtemps."],
	["Chandelier en argent", "argenterie", 60, "Lourd, cabossé, mais c'est bien de l'argent."],
	["Croûton de pain rassis", "nourriture", 2, "Dur comme la pierre. Mieux vaut ne pas y goûter."],
	["Morceau de fromage moisi", "nourriture", 3, "L'odeur suffit à faire fuir les rats."],
	["Pomme ridée", "nourriture", 2, "Elle a connu des jours meilleurs."],
	["Lame brisée", "casse", 8, "La moitié d'une épée. L'autre moitié est sans doute dans quelqu'un."],
	["Bouclier fendu", "casse", 6, "Il ne protégerait plus personne."],
	["Fiole fêlée", "casse", 1, "Vide, et elle fuirait de toute façon."],
	["Os gravé", "casse", 5, "Des signes étranges y sont taillés."],
]
## Clés rouillées du héros, montrées dans la catégorie « Divers » de l'inventaire (elles restent un simple
## compteur, ``joueur.cles`` : cet objet ne sert qu'à l'affichage).
const NOM_CLE := "Clé rouillée"


## Crée l'objet divers du catalogue nommé ``nom`` (un objet du catalogue au hasard si ``nom`` est vide).
static func creer(nom := "") -> Objet:
	var ligne: Array = CATALOGUE.pick_random()
	for l in CATALOGUE:
		if l[0] == nom:
			ligne = l
	var o := Objet.nouveau(ligne[0], "divers", ligne[3], ligne[2])
	o._d["sorte"] = ligne[1]
	o._d["description"] = ligne[3]
	return o


## Objet d'affichage des clés du héros (jamais rangé dans l'inventaire).
static func objet_cles() -> Objet:
	var o := Objet.nouveau(NOM_CLE, "cle", "", 0)
	o._d["description"] = "Ouvre une salle fermée à clé (une clé par porte)."
	return o
