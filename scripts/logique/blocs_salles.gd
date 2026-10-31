class_name BlocsSalles
extends RefCounted
## Blocs de salles (demande de l'utilisateur, 2026-10-31 : « plutôt que des salles aléatoires, des blocs de salles
## connectés les uns aux autres ») : un lot d'images de l'utilisateur qui forment des salles reliées dans un ordre
## fixé, posé tel quel dans l'étage. On remplacera petit à petit les salles tirées au hasard par des blocs.
##
## Un bloc : ses salles (image, position relative sur la carte), ses **liens** porte à porte (sortie de l'image →
## salle du bloc) et ses **entrées** (sortie d'une salle du bloc qui mène au reste de l'étage, et direction de la
## carte où se trouve la salle extérieure). Les images d'un bloc (``"bloc"`` dans leur .json, outil
## ``outils/importer_blocs.py``) ne servent jamais ailleurs.
##
## Orientation : comme partout, le haut de l'image est le haut de la carte, avec une exception voulue par
## l'utilisateur pour ce lot : on entre dans un cellier par le bas de son image, alors qu'il est à l'ouest (ou à
## l'est) de la salle de la petite porte. Les liens étant donnés porte à porte, rien n'est déduit des directions.

## Bloc « cuisine » (images « cuisine et salle a manger ») : salle à manger → (porte du fond) cuisine → (porte du fond
## à gauche, qui mène vers l'avant) salle de la petite porte → (gauche) cellier gauche, (droite) cellier droit.
## Deux entrées (décision de l'utilisateur) : le bas de la salle à manger et l'arche du fond de la petite porte.
## Un bloc cuisine par étage.
const BLOCS := {
	"cuisine": {
		"salles": {
			"manger": {"image": "bloc_cuisine_manger", "position": Vector2i(0, 0), "nom": "Salle à manger"},
			"cuisine": {"image": "bloc_cuisine_cuisine", "position": Vector2i(0, 1), "nom": "Cuisine"},
			"petite": {"image": "bloc_cuisine_petite", "position": Vector2i(0, 2), "nom": "Réserve de la cuisine"},
			"cellier_g": {"image": "bloc_cuisine_cellier_g", "position": Vector2i(-1, 2), "nom": "Cellier"},
			"cellier_d": {"image": "bloc_cuisine_cellier_d", "position": Vector2i(1, 2), "nom": "Cellier"},
		},
		## [salle, index de sortie de son image, salle reliée, index de sortie de l'image de celle-ci]
		"liens": [
			["manger", 0, "cuisine", 1],
			["cuisine", 0, "petite", 3],
			["petite", 1, "cellier_g", 0],
			["petite", 2, "cellier_d", 0],
		],
		## [salle, index de sortie, direction de la carte de la salle extérieure]
		"entrees": [
			["manger", 1, Vector2i(0, -1)],
			["petite", 0, Vector2i(0, 1)],
		],
		"par_etage": 1,
	},
}


## Vrai si l'image ``image`` appartient à un bloc (elle n'est pas tirée au hasard pour les autres salles).
static func image_de_bloc(image: String) -> bool:
	return image.begins_with("bloc_")


## Cases occupées par le bloc posé en ``origine`` : {clé de salle : case}.
static func cases(nom: String, origine: Vector2i) -> Dictionary:
	var resultat := {}
	var salles: Dictionary = BLOCS[nom]["salles"]
	for cle in salles:
		resultat[cle] = origine + salles[cle]["position"]
	return resultat


## Cases extérieures auxquelles le bloc posé en ``origine`` se raccorde : [[clé de salle, case extérieure], ...].
static func raccords(nom: String, origine: Vector2i) -> Array:
	var liste := []
	var c := cases(nom, origine)
	for e in BLOCS[nom]["entrees"]:
		liste.append([e[0], c[e[0]] + e[2]])
	return liste


## Informations « salle_peinte » des salles d'un bloc posé : ``ids`` {clé de salle : id du plan}, ``exterieurs``
## {clé de salle : id de la salle extérieure reliée par son entrée}. Les sorties suivent les liens du bloc.
static func salles_peintes(nom: String, ids: Dictionary, exterieurs: Dictionary) -> Dictionary:
	var b: Dictionary = BLOCS[nom]
	var resultat := {}
	for cle in b["salles"]:
		var image: String = b["salles"][cle]["image"]
		var n: int = PlanSalles.directions(image, false).size()
		var sorties := []
		sorties.resize(n)
		resultat[cle] = {"v": PlanSalles.VERSION, "image": image, "miroir": false,
			"face": [PlanSalles.FACE.x, PlanSalles.FACE.y], "sorties": sorties, "sans_porte": [], "bloc": nom}
	for l in b["liens"]:
		resultat[l[0]]["sorties"][l[1]] = str(ids[l[2]])
		resultat[l[2]]["sorties"][l[3]] = str(ids[l[0]])
	for e in b["entrees"]:
		if exterieurs.has(e[0]):
			resultat[e[0]]["sorties"][e[1]] = str(exterieurs[e[0]])
	return resultat
