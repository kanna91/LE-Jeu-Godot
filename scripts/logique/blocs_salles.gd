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
## Orientation : comme partout, le haut de l'image est le haut de la carte. Règle de l'utilisateur (2026-11-04) : une
## porte de gauche mène à la porte de droite de la salle voisine (à l'ouest) et inversement, le fond d'une salle au bas
## de la suivante (au nord) ; des images en miroir (« miroir ») pour que les portes tombent du bon côté.
## Exceptions marquées « par le bas » (5e élément du lien) : la porte mène bien vers la salle voisine, mais on y entre
## par sa porte du bas. Les celliers (voulu par l'utilisateur, 2026-10-31) ; et, depuis le 2026-11-10, 3 liens de la
## bibliothèque et 7 du laboratoire : avec les portes retracées par l'utilisateur, ces blocs n'ont pas assez de portes
## du fond et de côté pour tout relier autrement (13 liens nécessaires pour 10 cohérents au plus dans la bibliothèque,
## 35 pour 28 dans le laboratoire). Ces liens relient deux portes du bas, la seconde salle juste au sud de la première.
##
## Plans du 2026-11-10 (portes retracées par l'utilisateur dans toutes les salles) : trouvés par un programme de Claude
## qui essaie des milliers d'assemblages et garde celui qui a le moins d'exceptions, les ailes groupées et une emprise
## d'au plus 7 × 9 cases (place d'un bloc contre un côté de l'étage). Toute retouche de portes décale les numéros des
## sorties : relancer ``tests/test_liens_blocs.gd`` et refaire les liens.

## Bloc « cuisine » (images « cuisine et salle a manger ») : salle à manger → (porte du fond) cuisine → (porte du fond
## à gauche, qui mène vers l'avant) salle de la petite porte → (gauche) cellier gauche, (droite) cellier droit.
## Entrées : le bas de la salle à manger ; l'arche du fond de la réserve mène depuis le 2026-11-04 au **jardin**
## (potager puis verger, 18 salles, demande de l'utilisateur), qui ouvre sur l'étage à deux endroits (depuis le
## 2026-11-10 : le fond du verger de l'est au nord, le bas du cœur du verger au sud). Le jardin n'est pas un refuge : les ennemis
## ordinaires peuvent y être et y entrer, mais **ni le geôlier ni le Chevalier de la mort** (zone « jardin » de
## zones.json, « sans_chasseurs »). Portes cohérentes (gauche ↔ droite, fond ↔ bas, miroir si besoin). Un bloc par étage.
const BLOCS := {
	"cuisine": {
		"salles": {
			"manger": {"image": "bloc_cuisine_manger", "position": Vector2i(0, 0), "nom": "Salle à manger"},
			"cuisine": {"image": "bloc_cuisine_cuisine", "position": Vector2i(0, 1), "nom": "Cuisine"},
			"petite": {"image": "bloc_cuisine_petite", "position": Vector2i(0, 2), "nom": "Réserve de la cuisine"},
			"cellier_g": {"image": "bloc_cuisine_cellier_g", "position": Vector2i(-1, 2), "nom": "Cellier"},
			"cellier_d": {"image": "bloc_cuisine_cellier_d", "position": Vector2i(1, 2), "nom": "Cellier"},
			# Jardin : potager et verger (2026-11-04), derrière l'arche du fond de la réserve
			"potager_entree": {"image": "bloc_jardin_potager_entree", "position": Vector2i(0, 3), "nom": "Entrée du potager"},
			"potager_ouest": {"image": "bloc_jardin_potager_ouest", "position": Vector2i(-1, 3), "nom": "Potager de l'ouest", "miroir": true},
			"potager_est": {"image": "bloc_jardin_potager_est", "position": Vector2i(-2, 4), "nom": "Potager de l'est"},
			"potager_allee": {"image": "bloc_jardin_potager_allee", "position": Vector2i(0, 5), "nom": "Allée du potager"},
			"potager_haut": {"image": "bloc_jardin_potager_haut", "position": Vector2i(-1, 5), "nom": "Potager haut"},
			"potager_arcades": {"image": "bloc_jardin_potager_arcades", "position": Vector2i(-1, 4), "nom": "Potager aux arcades"},
			"verger_entree": {"image": "bloc_jardin_verger_entree", "position": Vector2i(-4, 1), "nom": "Entrée du verger"},
			"verger_ouest": {"image": "bloc_jardin_verger_ouest", "position": Vector2i(-3, 4), "nom": "Verger de l'ouest", "miroir": true},
			"verger_est": {"image": "bloc_jardin_verger_est", "position": Vector2i(-4, 4), "nom": "Verger de l'est", "miroir": true},
			"verger_centre": {"image": "bloc_jardin_verger_centre", "position": Vector2i(-3, 0), "nom": "Cœur du verger", "miroir": true},
			"verger_vieux_murs": {"image": "bloc_jardin_verger_vieux_murs", "position": Vector2i(-4, 3), "nom": "Verger des vieux murs", "miroir": true},
			"verger_colonnes": {"image": "bloc_jardin_verger_colonnes", "position": Vector2i(-4, 0), "nom": "Verger aux colonnes"},
			"verger_escaliers": {"image": "bloc_jardin_verger_escaliers", "position": Vector2i(-1, 6), "nom": "Verger aux escaliers"},
			"verger_terrasse": {"image": "bloc_jardin_verger_terrasse", "position": Vector2i(-3, 1), "nom": "Terrasse du verger"},
			"verger_ruines": {"image": "bloc_jardin_verger_ruines", "position": Vector2i(-3, 3), "nom": "Verger en ruine"},
			"verger_clos": {"image": "bloc_jardin_verger_clos", "position": Vector2i(-4, 2), "nom": "Clos du verger"},
			"verger_nord": {"image": "bloc_jardin_verger_nord", "position": Vector2i(-3, 2), "nom": "Sortie du verger", "miroir": true},
			"potager_cache": {"image": "bloc_jardin_potager_cache", "position": Vector2i(0, 4), "nom": "Potager caché"},
		},
		## [salle, index de sortie de son image, salle reliée, index de sortie de l'image de celle-ci]
		"liens": [
			["manger", 0, "cuisine", 1],
			["cuisine", 0, "petite", 3],
			["petite", 1, "cellier_g", 0, "par le bas"],
			["petite", 2, "cellier_d", 0, "par le bas"],
			["petite", 0, "potager_entree", 2],
			["potager_entree", 0, "potager_cache", 0],
			["potager_cache", 1, "potager_allee", 1],
			["potager_entree", 1, "potager_ouest", 1],
			["potager_ouest", 0, "potager_arcades", 1],
			["potager_arcades", 0, "potager_haut", 1],
			["potager_arcades", 2, "potager_est", 2],
			["potager_haut", 0, "verger_escaliers", 0],
			["potager_est", 0, "verger_ouest", 0],
			["verger_ouest", 1, "verger_ruines", 0],
			["verger_ruines", 1, "verger_nord", 0],
			["verger_nord", 1, "verger_terrasse", 2],
			["verger_ouest", 2, "verger_est", 0],
			["verger_terrasse", 0, "verger_entree", 1],
			["verger_nord", 2, "verger_clos", 1],
			["verger_entree", 2, "verger_colonnes", 0],
			["verger_est", 2, "verger_vieux_murs", 3],
			["verger_colonnes", 3, "verger_centre", 1],
			["verger_terrasse", 1, "verger_centre", 0],
			["verger_entree", 0, "verger_clos", 2],
			["verger_clos", 0, "verger_vieux_murs", 2],
		],
		## [salle, index de sortie, direction de la carte de la salle extérieure]
		"entrees": [
			["manger", 1, Vector2i(0, -1)],
			["verger_est", 1, Vector2i(0, 1)],
			["verger_centre", 2, Vector2i(0, -1)],
		],
		"par_etage": 1,
		"en_plus": true,
	},
	## Bloc « bibliothèque » (2026-11-04, images de l'utilisateur) : un **complexe fermé** de 14 salles, deux entrées,
	## et un **refuge** (zone « bibliotheque » de zones.json : ni ennemis, ni geôlier, ni Chevalier de la mort).
	## Plan du 2026-11-10 (portes retracées par l'utilisateur) : vestibule → (gauche) salle aux vitraux → (fond) nef →
	## (fond) salle au globe ; vestibule → (droite) galerie des balcons → (fond) archives → galerie aux tapis → salle des
	## piles → galerie haute (→ salle des globes) et galerie ouest. Par le bas : vitraux → cabinet des cartes, balcons →
	## allée des lecteurs, galerie haute → salle de lecture. Entrées au sud : le bas du vestibule et de la galerie ouest.
	"bibliotheque": {
		"salles": {
			"vestibule": {"image": "bloc_bibliotheque_vestibule", "position": Vector2i(0, 0), "nom": "Vestibule de la bibliothèque"},
			"nef": {"image": "bloc_bibliotheque_nef", "position": Vector2i(-1, 1), "nom": "Nef de la bibliothèque"},
			"allee": {"image": "bloc_bibliotheque_allee", "position": Vector2i(1, -1), "nom": "Allée des lecteurs"},
			"globe": {"image": "bloc_bibliotheque_globe", "position": Vector2i(-1, 2), "nom": "Salle au globe"},
			"galerie_ouest": {"image": "bloc_bibliotheque_galerie_ouest", "position": Vector2i(2, -1), "nom": "Galerie ouest", "miroir": true},
			"lecture": {"image": "bloc_bibliotheque_lecture", "position": Vector2i(3, -1), "nom": "Salle de lecture"},
			"piles": {"image": "bloc_bibliotheque_piles", "position": Vector2i(2, 0), "nom": "Salle des piles de livres", "miroir": true},
			"balcons": {"image": "bloc_bibliotheque_balcons", "position": Vector2i(1, 0), "nom": "Galerie des balcons"},
			"globes": {"image": "bloc_bibliotheque_globes", "position": Vector2i(3, 1), "nom": "Salle des globes"},
			"galerie_haute": {"image": "bloc_bibliotheque_galerie_haute", "position": Vector2i(3, 0), "nom": "Galerie haute"},
			"cartes": {"image": "bloc_bibliotheque_cartes", "position": Vector2i(-1, -1), "nom": "Cabinet des cartes"},
			"archives": {"image": "bloc_bibliotheque_archives", "position": Vector2i(1, 1), "nom": "Archives", "miroir": true},
			"vitraux": {"image": "bloc_bibliotheque_vitraux", "position": Vector2i(-1, 0), "nom": "Salle aux vitraux", "miroir": true},
			"tapis": {"image": "bloc_bibliotheque_tapis", "position": Vector2i(2, 1), "nom": "Galerie aux tapis"},
		},
		"liens": [
			["vestibule", 0, "vitraux", 0],
			["vitraux", 2, "cartes", 0, "par le bas"],
			["vitraux", 1, "nef", 1],
			["nef", 0, "globe", 0],
			["vestibule", 1, "balcons", 0],
			["balcons", 1, "archives", 1],
			["archives", 0, "tapis", 1],
			["tapis", 0, "piles", 2],
			["balcons", 2, "allee", 0, "par le bas"],
			["piles", 1, "galerie_haute", 2],
			["galerie_haute", 0, "globes", 0],
			["galerie_haute", 1, "lecture", 0, "par le bas"],
			["piles", 0, "galerie_ouest", 4],
		],
		"entrees": [
			["vestibule", 2, Vector2i(0, -1)],
			["galerie_ouest", 1, Vector2i(0, -1)],
		],
		"niveau": 102,  # niveau à part (2026-11-10), voir niveau_a_part
		"par_etage": 1,
		## Ses salles s'ajoutent à la taille de l'étage (GenerateurEtage : elles ne prennent pas la place des cercles).
		"en_plus": true,
	},
	## Bloc « laboratoire » d'alchimie (2026-11-04, 36 images de l'utilisateur) : complexe fermé, **refuge** (zone
	## « laboratoire » de zones.json), **trois entrées**, toutes au sud depuis le 2026-11-10 (couloir des fioles, haut de
	## l'étude, salle de cuisson). Structure cohérente (demande de l'utilisateur), sauf 7 liens « par le bas » (portes
	## retracées le 2026-11-10, voir l'en-tête) ; ailes groupées autant que possible (salles et couloirs, distillation,
	## fourneaux, étude). Plan de Claude (programme d'assemblage).
	"laboratoire": {
		"salles": {
			"couloir_sud": {"image": "bloc_laboratoire_couloir_sud", "position": Vector2i(0, 0), "nom": "Couloir des fioles"},
			"couloir_entree": {"image": "bloc_laboratoire_couloir_entree", "position": Vector2i(-2, -2), "nom": "Couloir de l'apothicaire", "miroir": true},
			"reserve": {"image": "bloc_laboratoire_reserve", "position": Vector2i(-3, -4), "nom": "Réserve de l'apothicaire", "miroir": true},
			"grande_salle": {"image": "bloc_laboratoire_grande_salle", "position": Vector2i(-2, -4), "nom": "Grande salle du laboratoire", "miroir": true},
			"salle_balcons": {"image": "bloc_laboratoire_salle_balcons", "position": Vector2i(-1, -3), "nom": "Salle aux balcons"},
			"salle_piliers": {"image": "bloc_laboratoire_salle_piliers", "position": Vector2i(-2, -1), "nom": "Salle aux piliers"},
			"salle_escaliers": {"image": "bloc_laboratoire_salle_escaliers", "position": Vector2i(-2, -3), "nom": "Salle aux escaliers", "miroir": true},
			"couloir_nord": {"image": "bloc_laboratoire_couloir_nord", "position": Vector2i(-2, 0), "nom": "Couloir du nord"},
			"salle_est": {"image": "bloc_laboratoire_salle_est", "position": Vector2i(-1, -2), "nom": "Laboratoire de l'est"},
			"salle_tables": {"image": "bloc_laboratoire_salle_tables", "position": Vector2i(-1, -1), "nom": "Salle des grandes tables"},
			"salle_vitraux": {"image": "bloc_laboratoire_salle_vitraux", "position": Vector2i(-1, 0), "nom": "Salle aux vitraux verts"},
			"salle_manuscrits": {"image": "bloc_laboratoire_salle_manuscrits", "position": Vector2i(-2, 1), "nom": "Salle des manuscrits", "miroir": true},
			"salle_couleurs": {"image": "bloc_laboratoire_salle_couleurs", "position": Vector2i(-1, 1), "nom": "Salle aux vitraux de couleur"},
			"etude_entree": {"image": "bloc_laboratoire_etude_entree", "position": Vector2i(-4, -4), "nom": "Cabinet d'étude"},
			"etude_escalier": {"image": "bloc_laboratoire_etude_escalier", "position": Vector2i(-3, -7), "nom": "Étude à l'escalier"},
			"etude_cartes": {"image": "bloc_laboratoire_etude_cartes", "position": Vector2i(-5, -4), "nom": "Étude des parchemins", "miroir": true},
			"etude_vitrail": {"image": "bloc_laboratoire_etude_vitrail", "position": Vector2i(-5, -5), "nom": "Étude au grand vitrail"},
			"couloir_reserve": {"image": "bloc_laboratoire_couloir_reserve", "position": Vector2i(-3, 0), "nom": "Couloir des réserves", "miroir": true},
			"etude_haute": {"image": "bloc_laboratoire_etude_haute", "position": Vector2i(-4, -7), "nom": "Étude haute", "miroir": true},
			"distillation_entree": {"image": "bloc_laboratoire_distillation_entree", "position": Vector2i(-3, -6), "nom": "Salle de distillation", "miroir": true},
			"distillation_cuves": {"image": "bloc_laboratoire_distillation_cuves", "position": Vector2i(-3, -1), "nom": "Salle des cuves"},
			"distillation_balcon": {"image": "bloc_laboratoire_distillation_balcon", "position": Vector2i(-1, -4), "nom": "Distillerie au balcon"},
			"distillation_ballons": {"image": "bloc_laboratoire_distillation_ballons", "position": Vector2i(-4, -1), "nom": "Salle des ballons", "miroir": true},
			"distillation_lustre": {"image": "bloc_laboratoire_distillation_lustre", "position": Vector2i(-1, -5), "nom": "Distillerie au lustre", "miroir": true},
			"distillation_verte": {"image": "bloc_laboratoire_distillation_verte", "position": Vector2i(-3, -5), "nom": "Distillerie verte", "miroir": true},
			"distillation_cornues": {"image": "bloc_laboratoire_distillation_cornues", "position": Vector2i(-2, -5), "nom": "Salle des cornues"},
			"distillation_piliers": {"image": "bloc_laboratoire_distillation_piliers", "position": Vector2i(-2, -6), "nom": "Distillerie aux piliers"},
			"couloir_ouest": {"image": "bloc_laboratoire_couloir_ouest", "position": Vector2i(-3, -3), "nom": "Couloir de l'ouest", "miroir": true},
			"fourneaux_entree": {"image": "bloc_laboratoire_fourneaux_entree", "position": Vector2i(-5, -2), "nom": "Salle du grand fourneau", "miroir": true},
			"fourneaux_forge": {"image": "bloc_laboratoire_fourneaux_forge", "position": Vector2i(-4, -3), "nom": "Forge alchimique"},
			"fourneaux_cheminees": {"image": "bloc_laboratoire_fourneaux_cheminees", "position": Vector2i(-4, -6), "nom": "Salle des cheminées"},
			"fourneaux_chaudron": {"image": "bloc_laboratoire_fourneaux_chaudron", "position": Vector2i(-3, -2), "nom": "Salle du chaudron"},
			"fourneaux_escalier": {"image": "bloc_laboratoire_fourneaux_escalier", "position": Vector2i(-4, -5), "nom": "Fourneau à l'escalier"},
			"fourneaux_creusets": {"image": "bloc_laboratoire_fourneaux_creusets", "position": Vector2i(-4, -2), "nom": "Salle des creusets"},
			"fourneaux_cuisson": {"image": "bloc_laboratoire_fourneaux_cuisson", "position": Vector2i(-6, -5), "nom": "Salle des fours", "miroir": true},
			"fourneaux_brasier": {"image": "bloc_laboratoire_fourneaux_brasier", "position": Vector2i(-5, -3), "nom": "Salle du brasier", "miroir": true},
		},
		"liens": [
			["couloir_sud", 1, "salle_vitraux", 1],
			["salle_vitraux", 0, "salle_couleurs", 0],
			["salle_couleurs", 1, "salle_manuscrits", 0],
			["salle_manuscrits", 1, "couloir_nord", 0],
			["couloir_nord", 2, "couloir_reserve", 0],
			["couloir_nord", 1, "salle_piliers", 0],
			["salle_vitraux", 2, "salle_tables", 0],
			["salle_piliers", 1, "couloir_entree", 1],
			["couloir_entree", 0, "salle_est", 0],
			["salle_est", 1, "salle_balcons", 2],
			["couloir_entree", 2, "salle_escaliers", 3],
			["salle_escaliers", 1, "couloir_ouest", 0],
			["salle_escaliers", 2, "grande_salle", 1],
			["grande_salle", 2, "reserve", 0],
			["grande_salle", 0, "distillation_balcon", 1],
			["reserve", 1, "distillation_verte", 1],
			["distillation_verte", 2, "distillation_cornues", 0],
			["couloir_reserve", 1, "distillation_cuves", 1],
			["distillation_cuves", 0, "distillation_ballons", 0],
			["distillation_cuves", 2, "fourneaux_chaudron", 1],
			["distillation_ballons", 1, "fourneaux_creusets", 1],
			["fourneaux_creusets", 0, "fourneaux_entree", 0],
			["fourneaux_entree", 1, "fourneaux_brasier", 1, "par le bas"],
			["fourneaux_brasier", 0, "fourneaux_forge", 0],
			["distillation_cornues", 1, "distillation_piliers", 1, "par le bas"],
			["distillation_piliers", 0, "distillation_entree", 0],
			["distillation_entree", 1, "etude_escalier", 1, "par le bas"],
			["etude_escalier", 0, "etude_haute", 0],
			["fourneaux_forge", 1, "etude_entree", 1, "par le bas"],
			["etude_entree", 0, "etude_cartes", 0],
			["etude_cartes", 1, "etude_vitrail", 2, "par le bas"],
			["etude_vitrail", 1, "fourneaux_escalier", 0],
			["etude_vitrail", 0, "fourneaux_cuisson", 1],
			["fourneaux_escalier", 1, "fourneaux_cheminees", 0, "par le bas"],
			["distillation_balcon", 0, "distillation_lustre", 0, "par le bas"],
		],
		"entrees": [
			["couloir_sud", 0, Vector2i(0, -1)],
			["etude_haute", 1, Vector2i(0, -1)],
			["fourneaux_cuisson", 0, Vector2i(0, -1)],
		],
		"niveau": 103,  # niveau à part (2026-11-10), voir niveau_a_part
		"par_etage": 1,
		"en_plus": true,
	},
}


## Niveau à part d'un bloc (2026-11-10, demande de l'utilisateur : « on va tricher un peu ») : la bibliothèque (102)
## et le laboratoire d'alchimie (103) ne sont plus posés sur l'étage ; chacun est un **niveau unique** séparé, comme
## les cryptes (Donjon.generer_niveaux_blocs). Chacune de ses entrées est un passage (escalier) vers une salle
## ordinaire de l'étage, dont une porte est marquée comme celle qui mène aux cryptes. 0 : bloc posé sur l'étage.
static func niveau_a_part(nom: String) -> int:
	return int(BLOCS[nom].get("niveau", 0))


## Blocs posés sur l'étage (ceux qui ne sont pas un niveau à part).
static func blocs_de_l_etage() -> Array:
	return BLOCS.keys().filter(func(n): return niveau_a_part(n) == 0)


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
