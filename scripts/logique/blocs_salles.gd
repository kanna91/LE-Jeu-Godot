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
	## Bloc « bibliothèque » (2026-11-04, images de l'utilisateur) : un **complexe fermé** de 14 salles, deux entrées
	## seulement (le bas du vestibule, au sud ; l'allée du fond de la salle au globe, au nord) ; c'est un **refuge**
	## (zone « bibliotheque » de zones.json : ni ennemis, ni geôlier, ni Chevalier de la mort). Plan de Claude d'après
	## les portes peintes : vestibule → (fond) nef → (fond) allée → (fond) salle au globe → étage ; la nef ouvre à gauche
	## sur la galerie des balcons (→ salle des globes, → galerie haute → cabinet des cartes, archives) et à droite sur
	## la salle aux vitraux (→ galerie aux tapis) ; le vestibule ouvre à gauche sur la galerie ouest (→ salle de
	## lecture) et à droite sur la salle des piles de livres. On entre dans chaque salle par le bas de son image.
	"bibliotheque": {
		"salles": {
			"vestibule": {"image": "bloc_bibliotheque_vestibule", "position": Vector2i(0, 0), "nom": "Vestibule de la bibliothèque"},
			"nef": {"image": "bloc_bibliotheque_nef", "position": Vector2i(0, 1), "nom": "Nef de la bibliothèque"},
			"allee": {"image": "bloc_bibliotheque_allee", "position": Vector2i(0, 2), "nom": "Allée des lecteurs"},
			"globe": {"image": "bloc_bibliotheque_globe", "position": Vector2i(0, 3), "nom": "Salle au globe"},
			"galerie_ouest": {"image": "bloc_bibliotheque_galerie_ouest", "position": Vector2i(-1, 0), "nom": "Galerie ouest"},
			"lecture": {"image": "bloc_bibliotheque_lecture", "position": Vector2i(-2, 0), "nom": "Salle de lecture"},
			"piles": {"image": "bloc_bibliotheque_piles", "position": Vector2i(1, 0), "nom": "Salle des piles de livres"},
			"balcons": {"image": "bloc_bibliotheque_balcons", "position": Vector2i(-1, 1), "nom": "Galerie des balcons"},
			"globes": {"image": "bloc_bibliotheque_globes", "position": Vector2i(-2, 1), "nom": "Salle des globes"},
			"galerie_haute": {"image": "bloc_bibliotheque_galerie_haute", "position": Vector2i(-1, 2), "nom": "Galerie haute"},
			"cartes": {"image": "bloc_bibliotheque_cartes", "position": Vector2i(-2, 2), "nom": "Cabinet des cartes"},
			"archives": {"image": "bloc_bibliotheque_archives", "position": Vector2i(-1, 3), "nom": "Archives"},
			"vitraux": {"image": "bloc_bibliotheque_vitraux", "position": Vector2i(1, 1), "nom": "Salle aux vitraux"},
			"tapis": {"image": "bloc_bibliotheque_tapis", "position": Vector2i(1, 2), "nom": "Galerie aux tapis"},
		},
		"liens": [
			["vestibule", 0, "galerie_ouest", 1],
			["vestibule", 1, "nef", 3],
			["vestibule", 2, "piles", 0],
			["nef", 0, "allee", 1],
			["nef", 1, "balcons", 2],
			["nef", 2, "vitraux", 1],
			["allee", 0, "globe", 1],
			["galerie_ouest", 0, "lecture", 0],
			["balcons", 0, "globes", 0],
			["balcons", 1, "galerie_haute", 2],
			["galerie_haute", 0, "cartes", 0],
			["galerie_haute", 1, "archives", 0],
			["vitraux", 0, "tapis", 0],
		],
		"entrees": [
			["vestibule", 3, Vector2i(0, -1)],
			["globe", 0, Vector2i(0, 1)],
		],
		"par_etage": 1,
		## Ses salles s'ajoutent à la taille de l'étage (GenerateurEtage : elles ne prennent pas la place des cercles).
		"en_plus": true,
	},
	## Bloc « laboratoire » d'alchimie (2026-11-04, 36 images de l'utilisateur) : complexe fermé, **refuge** (zone
	## « laboratoire » de zones.json), **trois entrées** (couloir des fioles au sud, couloir de l'ouest, fond de l'étude à
	## l'escalier au nord). Structure cohérente (demande de l'utilisateur) : une porte de gauche mène à la porte de
	## droite de la salle voisine et inversement, le fond d'une salle au bas de la suivante ; des images en miroir
	## (« miroir ») pour que les portes tombent du bon côté. Ailes : salle principale au centre (deux colonnes), distillation
	## à l'ouest, fourneaux à l'est, étude au nord ; quelques boucles là où deux portes se font face. Plan de Claude.
	"laboratoire": {
		"salles": {
			"couloir_sud": {"image": "bloc_laboratoire_couloir_sud", "position": Vector2i(0, -1), "nom": "Couloir des fioles"},
			"couloir_entree": {"image": "bloc_laboratoire_couloir_entree", "position": Vector2i(0, 0), "nom": "Couloir de l'apothicaire", "miroir": true},
			"reserve": {"image": "bloc_laboratoire_reserve", "position": Vector2i(1, 0), "nom": "Réserve de l'apothicaire"},
			"grande_salle": {"image": "bloc_laboratoire_grande_salle", "position": Vector2i(0, 1), "nom": "Grande salle du laboratoire"},
			"salle_balcons": {"image": "bloc_laboratoire_salle_balcons", "position": Vector2i(0, 2), "nom": "Salle aux balcons"},
			"salle_piliers": {"image": "bloc_laboratoire_salle_piliers", "position": Vector2i(0, 3), "nom": "Salle aux piliers"},
			"salle_escaliers": {"image": "bloc_laboratoire_salle_escaliers", "position": Vector2i(0, 4), "nom": "Salle aux escaliers"},
			"couloir_nord": {"image": "bloc_laboratoire_couloir_nord", "position": Vector2i(0, 5), "nom": "Couloir du nord"},
			"salle_est": {"image": "bloc_laboratoire_salle_est", "position": Vector2i(1, 1), "nom": "Laboratoire de l'est"},
			"salle_tables": {"image": "bloc_laboratoire_salle_tables", "position": Vector2i(1, 2), "nom": "Salle des grandes tables"},
			"salle_vitraux": {"image": "bloc_laboratoire_salle_vitraux", "position": Vector2i(1, 3), "nom": "Salle aux vitraux verts"},
			"salle_manuscrits": {"image": "bloc_laboratoire_salle_manuscrits", "position": Vector2i(1, 4), "nom": "Salle des manuscrits"},
			"salle_couleurs": {"image": "bloc_laboratoire_salle_couleurs", "position": Vector2i(1, 5), "nom": "Salle aux vitraux de couleur"},
			"etude_entree": {"image": "bloc_laboratoire_etude_entree", "position": Vector2i(0, 6), "nom": "Cabinet d'étude"},
			"etude_escalier": {"image": "bloc_laboratoire_etude_escalier", "position": Vector2i(0, 7), "nom": "Étude à l'escalier"},
			"etude_cartes": {"image": "bloc_laboratoire_etude_cartes", "position": Vector2i(-1, 6), "nom": "Étude des parchemins"},
			"etude_vitrail": {"image": "bloc_laboratoire_etude_vitrail", "position": Vector2i(-2, 6), "nom": "Étude au grand vitrail"},
			"couloir_reserve": {"image": "bloc_laboratoire_couloir_reserve", "position": Vector2i(-3, 6), "nom": "Couloir des réserves", "miroir": true},
			"etude_haute": {"image": "bloc_laboratoire_etude_haute", "position": Vector2i(-1, 7), "nom": "Étude haute", "miroir": true},
			"distillation_entree": {"image": "bloc_laboratoire_distillation_entree", "position": Vector2i(-1, 1), "nom": "Salle de distillation"},
			"distillation_cuves": {"image": "bloc_laboratoire_distillation_cuves", "position": Vector2i(-1, 2), "nom": "Salle des cuves"},
			"distillation_balcon": {"image": "bloc_laboratoire_distillation_balcon", "position": Vector2i(-1, 3), "nom": "Distillerie au balcon"},
			"distillation_ballons": {"image": "bloc_laboratoire_distillation_ballons", "position": Vector2i(-1, 4), "nom": "Salle des ballons"},
			"distillation_lustre": {"image": "bloc_laboratoire_distillation_lustre", "position": Vector2i(-2, 4), "nom": "Distillerie au lustre", "miroir": true},
			"distillation_verte": {"image": "bloc_laboratoire_distillation_verte", "position": Vector2i(-2, 5), "nom": "Distillerie verte"},
			"distillation_cornues": {"image": "bloc_laboratoire_distillation_cornues", "position": Vector2i(-2, 1), "nom": "Salle des cornues", "miroir": true},
			"distillation_piliers": {"image": "bloc_laboratoire_distillation_piliers", "position": Vector2i(-2, 2), "nom": "Distillerie aux piliers"},
			"couloir_ouest": {"image": "bloc_laboratoire_couloir_ouest", "position": Vector2i(-3, 2), "nom": "Couloir de l'ouest", "miroir": true},
			"fourneaux_entree": {"image": "bloc_laboratoire_fourneaux_entree", "position": Vector2i(2, 3), "nom": "Salle du grand fourneau"},
			"fourneaux_forge": {"image": "bloc_laboratoire_fourneaux_forge", "position": Vector2i(3, 3), "nom": "Forge alchimique"},
			"fourneaux_cheminees": {"image": "bloc_laboratoire_fourneaux_cheminees", "position": Vector2i(3, 4), "nom": "Salle des cheminées"},
			"fourneaux_chaudron": {"image": "bloc_laboratoire_fourneaux_chaudron", "position": Vector2i(3, 5), "nom": "Salle du chaudron"},
			"fourneaux_escalier": {"image": "bloc_laboratoire_fourneaux_escalier", "position": Vector2i(3, 6), "nom": "Fourneau à l'escalier"},
			"fourneaux_creusets": {"image": "bloc_laboratoire_fourneaux_creusets", "position": Vector2i(2, 4), "nom": "Salle des creusets", "miroir": true},
			"fourneaux_cuisson": {"image": "bloc_laboratoire_fourneaux_cuisson", "position": Vector2i(2, 5), "nom": "Salle des fours"},
			"fourneaux_brasier": {"image": "bloc_laboratoire_fourneaux_brasier", "position": Vector2i(2, 6), "nom": "Salle du brasier", "miroir": true},
		},
		"liens": [
			["couloir_sud", 0, "couloir_entree", 2],
			["couloir_entree", 0, "reserve", 0],
			["couloir_entree", 1, "grande_salle", 3],
			["grande_salle", 0, "distillation_entree", 2],
			["grande_salle", 2, "salle_est", 0],
			["grande_salle", 1, "salle_balcons", 1],
			["salle_balcons", 0, "salle_piliers", 1],
			["salle_piliers", 0, "salle_escaliers", 2],
			["salle_escaliers", 0, "couloir_nord", 1],
			["salle_escaliers", 1, "salle_manuscrits", 0],
			["salle_est", 1, "salle_tables", 1],
			["salle_tables", 0, "salle_vitraux", 2],
			["salle_vitraux", 0, "salle_manuscrits", 2],
			["salle_vitraux", 1, "fourneaux_entree", 0],
			["salle_manuscrits", 1, "salle_couleurs", 0],
			["couloir_nord", 0, "etude_entree", 2],
			["etude_entree", 0, "etude_cartes", 1],
			["etude_entree", 1, "etude_escalier", 2],
			["etude_escalier", 0, "etude_haute", 0],
			["etude_cartes", 0, "etude_vitrail", 1],
			["etude_vitrail", 0, "couloir_reserve", 0],
			["distillation_entree", 0, "distillation_cornues", 0],
			["distillation_entree", 1, "distillation_cuves", 2],
			["distillation_cornues", 1, "distillation_piliers", 2],
			["distillation_piliers", 0, "couloir_ouest", 0],
			["distillation_piliers", 1, "distillation_cuves", 0],
			["distillation_cuves", 1, "distillation_balcon", 1],
			["distillation_balcon", 0, "distillation_ballons", 1],
			["distillation_ballons", 0, "distillation_lustre", 0],
			["distillation_lustre", 1, "distillation_verte", 0],
			["fourneaux_entree", 1, "fourneaux_forge", 0],
			["fourneaux_forge", 1, "fourneaux_cheminees", 2],
			["fourneaux_cheminees", 0, "fourneaux_creusets", 0],
			["fourneaux_cheminees", 1, "fourneaux_chaudron", 1],
			["fourneaux_chaudron", 0, "fourneaux_escalier", 1],
			["fourneaux_creusets", 1, "fourneaux_cuisson", 1],
			["fourneaux_cuisson", 0, "fourneaux_brasier", 1],
			["fourneaux_brasier", 0, "fourneaux_escalier", 0],
		],
		"entrees": [
			["couloir_sud", 1, Vector2i(0, -1)],
			["etude_escalier", 1, Vector2i(0, 1)],
			["couloir_ouest", 1, Vector2i(0, -1)],
		],
		"par_etage": 1,
		"en_plus": true,
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
		var n: int = PlanSalles.directions(image, bool(b["salles"][cle].get("miroir", false))).size()
		var sorties := []
		sorties.resize(n)
		resultat[cle] = {"v": PlanSalles.VERSION, "image": image, "miroir": bool(b["salles"][cle].get("miroir", false)),
			"face": [PlanSalles.FACE.x, PlanSalles.FACE.y], "sorties": sorties, "sans_porte": [], "bloc": nom}
	for l in b["liens"]:
		resultat[l[0]]["sorties"][l[1]] = str(ids[l[2]])
		resultat[l[2]]["sorties"][l[3]] = str(ids[l[0]])
	for e in b["entrees"]:
		if exterieurs.has(e[0]):
			resultat[e[0]]["sorties"][e[1]] = str(exterieurs[e[0]])
	return resultat
