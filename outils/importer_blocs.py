"""Importe les **blocs de salles** dans le jeu Godot (demande de l'utilisateur, 2026-10-31).

Un bloc est un lot d'images de l'utilisateur qui forment des salles reliées entre elles dans un ordre fixé
(au lieu de salles tirées au hasard). Le plan du bloc (positions sur la carte, quelle porte mène où, entrées
depuis le reste de l'étage) est dans le jeu : ``scripts/logique/blocs_salles.gd``. Ici : les zones de chaque image
(sol, obstacles, sorties, perspective), relevées à la main par Claude sur des grilles
(``C:\\IA\\pont-blender\\bloc_<nom>\\travail\\grille_*.png``), en pixels de l'image 768 x 512.

Bloc « cuisine » (``C:\\ia image\\Salle de donjon\\cuisine et salle a manger``) : salle à manger → (porte du fond)
cuisine → (porte du fond à gauche) salle de la petite porte → (porte de gauche) cellier gauche, (porte de
droite) cellier droit ; l'arche du fond de la petite porte ressort sur l'étage.

Écrit, pour chaque salle ``bloc_<bloc>_<salle>`` :
- ``images/salles_peintes/<id>/fond.jpeg`` (image d'origine) et ``fond_hd.png`` (agrandie par IA, Swin2SR, comme
  les grandes salles ; ``--sans-ia`` : ne la refait pas) ;
- ``donnees/salles_peintes/<id>.json`` (format habituel, plus ``"bloc"`` : ces images ne servent qu'au bloc) ;
- ``C:\\IA\\pont-blender\\bloc_<bloc>\\planche_zones.png`` : planche de contrôle (sol vert, obstacles rouges,
  sorties en couleur, héros à plusieurs profondeurs).
Les retouches faites dans l'éditeur de zones (``outils/zones_manuelles/<id>.json``) passent devant.

Bloc « bibliothèque » (2026-11-04, ``C:\\ia image\\Salle de donjon\\bibliothèque\\bibliothèque``) : 14 salles, plan dans
``BlocsSalles`` (complexe fermé, deux entrées).

Usage : ``python outils/importer_blocs.py [--sans-ia] [bloc ...]`` (sans nom de bloc : tous les blocs)
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ICI, "outils"))
IMAGES = os.path.join(ICI, "images", "salles_peintes")
DONNEES = os.path.join(ICI, "donnees", "salles_peintes")
HEROS = os.path.join(IMAGES, "heros", "respiration", "up", "idle_up_0.png")
TRAVAIL = r"C:\IA\pont-blender"

BAS = [[0, 499], [767, 499], [767, 517], [0, 517]]

# Chaque salle : image source, sol (polygone), obstacles, sorties [nom, direction, type, rectangle, arrivée],
# perspective (hauteur du héros en pixels à deux profondeurs), départ.
BLOCS = {
    "cuisine": {
        "source": r"C:\ia image\Salle de donjon\cuisine et salle a manger",
        "salles": {
            "manger": {
                "image": "salle a manger.jpeg",
                "marche": [(0, 511), (767, 511), (767, 430), (735, 425), (720, 380), (690, 365), (640, 350), (610, 335),
                           (560, 312), (480, 309), (435, 305), (378, 305), (330, 310), (290, 320), (200, 332), (130, 342),
                           (60, 360), (30, 385), (0, 395)],
                "obstacles": [
                    [(25, 345), (150, 335), (280, 322), (292, 352), (270, 368), (185, 398), (60, 398), (25, 390)],
                    [(240, 316), (345, 300), (368, 318), (300, 330), (245, 330)],
                    [(430, 350), (470, 330), (600, 325), (625, 345), (620, 398), (450, 400), (425, 385)],
                    [(470, 300), (575, 296), (580, 312), (470, 316)],
                    [(0, 410), (60, 412), (70, 440), (0, 450)],
                ],
                "sorties": [
                    ["porte du fond", "devant", "porte", [(378, 302), (432, 302), (434, 314), (376, 314)], [405, 330, "down"]],
                    ["retour", "bas", "passage", BAS, None],
                ],
                "hauteurs": ((305, 75), (511, 215)), "depart": [400, 470],
            },
            "cuisine": {
                "image": "cuisine.jpeg",
                "marche": [(0, 511), (767, 511), (767, 320), (560, 305), (420, 300), (330, 298), (240, 300), (130, 298),
                           (40, 300), (30, 330), (0, 340)],
                "obstacles": [
                    [(30, 322), (150, 325), (320, 322), (325, 345), (300, 410), (270, 415), (300, 440), (290, 480),
                     (150, 490), (60, 480), (0, 470), (0, 340)],
                    [(240, 288), (405, 288), (410, 297), (240, 297)],
                    [(505, 320), (767, 315), (767, 400), (700, 405), (560, 400), (505, 365)],
                ],
                "sorties": [
                    ["porte de la cuisine", "devant", "porte", [(38, 300), (125, 300), (125, 316), (38, 316)], [140, 310, "right"]],
                    ["retour", "bas", "passage", BAS, None],
                ],
                "hauteurs": ((300, 85), (511, 215)), "depart": [430, 470],
            },
            "petite": {
                "image": "petite porte de la cuisine.jpeg",
                "marche": [(0, 511), (767, 511), (767, 430), (760, 425), (690, 418), (640, 410), (470, 405), (460, 385),
                           (445, 368), (355, 368), (345, 380), (330, 402), (180, 405), (130, 412), (40, 418), (0, 420)],
                "obstacles": [
                    [(0, 418), (48, 416), (50, 445), (0, 448)],
                    [(740, 425), (767, 425), (767, 458), (742, 458)],
                ],
                "sorties": [
                    ["arche du fond", "devant", "passage", [(358, 365), (442, 365), (444, 378), (356, 378)], [400, 395, "down"]],
                    ["porte de gauche", "gauche", "porte", [(55, 410), (128, 410), (130, 424), (52, 424)], [100, 440, "right"]],
                    ["porte de droite", "droite", "porte", [(686, 414), (742, 414), (745, 428), (683, 428)], [705, 445, "left"]],
                    ["retour", "bas", "passage", BAS, None],
                ],
                "hauteurs": ((365, 95), (511, 215)), "depart": [400, 480],
            },
            "cellier_g": {
                "image": "cellier gauche.jpeg",
                "marche": [(0, 511), (767, 511), (767, 450), (730, 420), (690, 412), (600, 400), (560, 375), (360, 372),
                           (320, 368), (280, 380), (210, 395), (160, 430), (60, 445), (0, 450)],
                "obstacles": [
                    [(60, 410), (210, 398), (215, 432), (120, 447), (60, 444)],
                    [(612, 375), (672, 372), (676, 392), (614, 396)],
                    [(680, 395), (740, 390), (745, 415), (690, 417)],
                ],
                "sorties": [["retour", "bas", "passage", BAS, None]],
                "hauteurs": ((370, 100), (511, 210)), "depart": [400, 470],
            },
            "cellier_d": {
                "image": "cellier droit.jpeg",
                "marche": [(0, 511), (767, 511), (767, 485), (690, 472), (660, 432), (660, 398), (610, 378), (560, 357),
                           (450, 347), (400, 350), (330, 366), (270, 382), (205, 388), (205, 450), (60, 462), (0, 470)],
                "obstacles": [
                    [(595, 415), (660, 410), (665, 452), (600, 457)],
                ],
                "sorties": [["retour", "bas", "passage", BAS, None]],
                "hauteurs": ((345, 95), (511, 210)), "depart": [420, 480],
            },
        },
    },
    # Bibliothèque (2026-11-04, images de l'utilisateur ; mw1ek603udghcz.jpeg est un doublon de mw1eih830p44dn.jpeg,
    # écarté) : 14 salles relevées par Claude sur les grilles C:\IA\pont-blender\bloc_bibliotheque\travail\grille_NN.png.
    # Seules les sorties utilisées par le plan du bloc (BlocsSalles) sont tracées ; les autres portes peintes restent
    # du décor. Hauteur du héros estimée d'après les portes peintes (une porte ≈ 1,35 héros).
    "bibliotheque": {
        "source": r"C:\ia image\Salle de donjon\bibliothèque\bibliothèque",
        "salles": {
            "vestibule": {
                "image": "mw1ejzc3g9nx1v.jpeg",
                "marche": [(0, 511), (767, 511), (767, 400), (700, 380), (660, 360), (600, 350), (460, 345), (330, 345),
                           (200, 350), (120, 355), (40, 355), (0, 360)],
                "obstacles": [[(240, 395), (460, 390), (465, 470), (250, 475)], [(0, 395), (120, 395), (125, 440), (0, 445)],
                              [(705, 390), (767, 385), (767, 511), (715, 511)]],
                "sorties": [
                    ["porte de gauche", "gauche", "porte", [(30, 345), (85, 345), (87, 358), (28, 358)], [70, 375, "right"]],
                    ["escalier du fond", "devant", "passage", [(368, 342), (420, 342), (422, 354), (366, 354)], [395, 365, "down"]],
                    ["porte de droite", "droite", "porte", [(605, 346), (650, 346), (652, 358), (603, 358)], [615, 372, "left"]],
                    ["retour", "bas", "passage", BAS, None],
                ],
                "hauteurs": ((345, 60), (511, 210)), "depart": [560, 480],
            },
            "nef": {
                "image": "mw1duol2zx22rv.jpeg",
                "marche": [(0, 511), (767, 511), (767, 440), (700, 430), (640, 390), (560, 375), (470, 365), (420, 358),
                           (350, 358), (300, 365), (230, 375), (130, 395), (60, 430), (0, 440)],
                "obstacles": [[(105, 405), (250, 395), (255, 445), (115, 450)], [(490, 395), (640, 395), (645, 450), (500, 455)],
                              [(625, 380), (700, 380), (700, 415), (625, 415)]],
                "sorties": [
                    ["arche du fond", "devant", "passage", [(355, 356), (415, 356), (417, 368), (353, 368)], [385, 378, "down"]],
                    ["allée de gauche", "gauche", "passage", [(225, 370), (280, 366), (283, 380), (222, 384)], [275, 398, "right"]],
                    ["allée de droite", "droite", "passage", [(490, 366), (545, 370), (548, 384), (487, 380)], [495, 398, "left"]],
                    ["retour", "bas", "passage", BAS, None],
                ],
                "hauteurs": ((440, 130), (511, 210)), "depart": [385, 480],
            },
            "allee": {
                "image": "mw1dv2exfay7o5.jpeg",
                "marche": [(0, 511), (767, 511), (767, 420), (700, 400), (600, 370), (470, 350), (410, 343), (360, 343),
                           (290, 350), (180, 362), (80, 390), (0, 410)],
                "obstacles": [[(185, 375), (330, 372), (325, 425), (195, 430)], [(600, 365), (720, 368), (725, 395), (605, 395)],
                              [(135, 345), (185, 345), (185, 370), (135, 370)], [(510, 340), (580, 340), (580, 365), (510, 365)]],
                "sorties": [
                    ["porte du fond", "devant", "porte", [(358, 340), (410, 340), (412, 350), (356, 350)], [385, 360, "down"]],
                    ["retour", "bas", "passage", BAS, None],
                ],
                "hauteurs": ((410, 100), (511, 210)), "depart": [400, 480],
            },
            "globe": {
                "image": "mw1ds6i1fsydis.jpeg",
                "marche": [(0, 511), (767, 511), (767, 400), (690, 385), (640, 345), (560, 330), (380, 325), (250, 330),
                           (150, 340), (100, 360), (0, 380)],
                "obstacles": [[(30, 350), (120, 345), (125, 420), (40, 425)], [(440, 335), (560, 335), (565, 380), (450, 385)],
                              [(228, 345), (272, 345), (272, 380), (228, 380)]],
                "sorties": [
                    ["allée du fond", "devant", "passage", [(380, 322), (440, 322), (442, 334), (378, 334)], [410, 345, "down"]],
                    ["retour", "bas", "passage", BAS, None],
                ],
                "hauteurs": ((380, 110), (511, 210)), "depart": [330, 480],
            },
            "galerie_ouest": {
                "image": "mw1ejy6ztjoyk6.jpeg",
                "marche": [(0, 511), (767, 511), (767, 470), (690, 440), (640, 380), (600, 350), (500, 335), (380, 330),
                           (260, 335), (150, 345), (60, 345), (0, 345)],
                "obstacles": [[(0, 385), (245, 380), (240, 445), (0, 450)], [(40, 345), (100, 345), (105, 385), (45, 385)],
                              [(280, 368), (380, 368), (380, 410), (285, 412)], [(452, 335), (560, 335), (560, 370), (455, 372)],
                              [(560, 365), (640, 355), (767, 375), (767, 511), (650, 511), (570, 420)]],
                "sorties": [
                    ["porte de gauche", "gauche", "porte", [(10, 333), (50, 333), (52, 345), (8, 345)], [25, 360, "right"]],
                    ["retour", "bas", "passage", BAS, None],
                ],
                "hauteurs": ((335, 52), (511, 210)), "depart": [400, 480],
            },
            "lecture": {
                "image": "mw1dru3cijqhd1.jpeg",
                "marche": [(0, 511), (767, 511), (767, 400), (700, 395), (660, 340), (560, 335), (450, 330), (300, 330),
                           (230, 335), (150, 345), (110, 390), (0, 400)],
                "obstacles": [[(130, 335), (225, 330), (228, 360), (135, 365)], [(455, 345), (665, 345), (670, 395), (470, 400)],
                              [(0, 400), (120, 400), (125, 450), (0, 455)]],
                "sorties": [["retour", "bas", "passage", BAS, None]],
                "hauteurs": ((350, 90), (511, 210)), "depart": [400, 480],
            },
            "piles": {
                "image": "mw1eih830p44dn.jpeg",
                "marche": [(0, 511), (767, 511), (767, 420), (720, 370), (640, 345), (560, 340), (400, 340), (250, 345),
                           (130, 350), (60, 350), (0, 355)],
                "obstacles": [[(330, 350), (440, 348), (445, 380), (335, 383)], [(615, 375), (720, 370), (725, 440), (620, 445)],
                              [(490, 455), (600, 450), (605, 511), (490, 511)]],
                "sorties": [["retour", "bas", "passage", BAS, None]],
                "hauteurs": ((345, 72), (511, 210)), "depart": [330, 480],
            },
            "balcons": {
                "image": "mw1ejmqrh9b1qy.jpeg",
                "marche": [(0, 511), (767, 511), (767, 400), (700, 385), (620, 365), (500, 358), (380, 352), (250, 355),
                           (140, 350), (80, 355), (0, 370)],
                "obstacles": [[(25, 395), (110, 390), (115, 450), (30, 455)], [(395, 365), (470, 365), (470, 400), (395, 402)],
                              [(265, 465), (385, 460), (390, 511), (270, 511)], [(560, 375), (625, 375), (625, 400), (560, 400)],
                              [(690, 385), (767, 380), (767, 511), (700, 511)]],
                "sorties": [
                    ["porte de gauche", "gauche", "porte", [(82, 345), (130, 345), (132, 358), (80, 358)], [125, 372, "right"]],
                    ["escalier du fond", "devant", "passage", [(322, 352), (372, 352), (374, 364), (320, 364)], [345, 375, "down"]],
                    ["retour", "bas", "passage", BAS, None],
                ],
                "hauteurs": ((345, 85), (511, 210)), "depart": [500, 480],
            },
            "globes": {
                "image": "mw1duxzcisvl4r.jpeg",
                "marche": [(0, 511), (767, 511), (767, 420), (700, 380), (620, 365), (520, 358), (400, 355), (260, 358),
                           (200, 365), (60, 380), (0, 400)],
                "obstacles": [[(60, 365), (200, 360), (205, 435), (70, 440)], [(335, 352), (480, 350), (485, 395), (340, 398)],
                              [(565, 415), (767, 412), (767, 511), (575, 511)]],
                "sorties": [["retour", "bas", "passage", BAS, None]],
                "hauteurs": ((395, 100), (511, 210)), "depart": [330, 480],
            },
            "galerie_haute": {
                "image": "mw1ej4oaigb5f4.jpeg",
                "marche": [(0, 511), (767, 511), (767, 470), (720, 440), (700, 420), (560, 400), (450, 392), (300, 395),
                           (200, 400), (130, 400), (60, 410), (0, 420)],
                "obstacles": [[(470, 392), (540, 392), (540, 432), (472, 435)], [(550, 405), (705, 405), (710, 450), (560, 455)],
                              [(205, 388), (280, 388), (280, 420), (205, 420)]],
                "sorties": [
                    ["porte de gauche", "gauche", "porte", [(75, 395), (130, 395), (132, 408), (72, 408)], [110, 425, "right"]],
                    ["porte du fond", "devant", "porte", [(408, 388), (458, 388), (460, 400), (406, 400)], [432, 412, "down"]],
                    ["retour", "bas", "passage", BAS, None],
                ],
                "hauteurs": ((395, 66), (511, 210)), "depart": [380, 480],
            },
            "cartes": {
                "image": "mw1e6yfvzq4q69.jpeg",
                "marche": [(0, 511), (767, 511), (767, 400), (720, 385), (560, 345), (400, 335), (260, 340), (200, 345),
                           (100, 360), (0, 380)],
                "obstacles": [[(90, 330), (225, 325), (235, 511), (120, 511), (95, 420)], [(360, 330), (530, 330), (530, 380), (365, 383)],
                              [(560, 325), (720, 325), (725, 380), (565, 385)], [(565, 405), (767, 400), (767, 511), (570, 511)]],
                "sorties": [["retour", "bas", "passage", BAS, None]],
                "hauteurs": ((380, 110), (511, 210)), "depart": [400, 480],
            },
            "archives": {
                "image": "mw1ejnjt0hclmn.jpeg",
                "marche": [(0, 511), (767, 511), (767, 420), (700, 400), (620, 370), (560, 345), (400, 338), (300, 340),
                           (200, 345), (120, 360), (0, 380)],
                "obstacles": [[(0, 340), (120, 340), (125, 420), (0, 425)], [(410, 340), (570, 330), (580, 410), (400, 410)],
                              [(600, 355), (767, 360), (767, 430), (610, 425)], [(265, 335), (312, 335), (312, 370), (265, 370)]],
                "sorties": [["retour", "bas", "passage", BAS, None]],
                "hauteurs": ((340, 65), (511, 210)), "depart": [300, 480],
            },
            "vitraux": {
                "image": "mw1ejs2jlrszfn.jpeg",
                "marche": [(0, 511), (767, 511), (767, 390), (640, 370), (560, 355), (470, 340), (400, 335), (340, 335),
                           (280, 340), (180, 355), (80, 380), (0, 395)],
                "obstacles": [[(0, 330), (140, 335), (170, 390), (0, 400)], [(440, 345), (560, 345), (565, 375), (450, 375)],
                              [(620, 340), (767, 335), (767, 380), (625, 380)]],
                "sorties": [
                    ["porte du fond", "devant", "porte", [(355, 330), (395, 330), (397, 342), (353, 342)], [375, 352, "down"]],
                    ["retour", "bas", "passage", BAS, None],
                ],
                "hauteurs": ((338, 65), (511, 210)), "depart": [380, 480],
            },
            "tapis": {
                "image": "mw1ej5wr82tej2.jpeg",
                "marche": [(0, 511), (767, 511), (767, 470), (700, 420), (640, 390), (560, 380), (460, 378), (330, 380),
                           (200, 385), (100, 400), (0, 420)],
                "obstacles": [[(60, 390), (130, 385), (175, 435), (80, 440)], [(395, 365), (470, 365), (475, 400), (400, 402)],
                              [(500, 375), (565, 375), (565, 410), (500, 410)], [(680, 465), (767, 455), (767, 511), (690, 511)]],
                "sorties": [["retour", "bas", "passage", BAS, None]],
                "hauteurs": ((360, 52), (511, 210)), "depart": [380, 480],
            },
        },
    },
}


# ---------------------------------------------------------------------------
# Laboratoire d'alchimie (2026-11-04, 36 images de l'utilisateur, en 5 sous-dossiers). Plan dans BlocsSalles (complexe
# fermé, 3 entrées). Ici, pour chaque salle : image et portes **de l'image** (sans miroir) utilisées par le plan,
# relevées par Claude sur les planches C:\IA\pont-blender\bloc_laboratoire\travail\quad_NN.png :
# (direction de l'image, x début, x fin, y du sol au pied de la porte). Le sol et les obstacles viennent du détourage
# automatique (outils/detourer_sols.py bloc_laboratoire_...), la perspective est estimée d'après le fond du sol.
# ---------------------------------------------------------------------------
LABO_SOURCE = r"C:\ia image\Salle de donjon\laboratoire d'alchimie"
LABO = {
    "couloir_sud": ("couloir/mw1fosrrn52a2m.jpeg", [("devant", 300, 380, 348)]),
    "couloir_entree": ("couloir/mw1fo5l2mhsmij.jpeg", [("gauche", 0, 55, 398), ("devant", 480, 550, 355)]),
    "reserve": ("salle principale/mw1fes1df0f669.jpeg", [("gauche", 40, 100, 348)]),
    "grande_salle": ("salle principale/mw1fdnle5hanaq.jpeg", [("gauche", 60, 120, 348), ("devant", 300, 340, 332),
                                                              ("droite", 600, 660, 332)]),
    "salle_balcons": ("salle principale/mw1fazl08cmw6s.jpeg", [("devant", 510, 570, 362)]),
    "salle_piliers": ("salle principale/mw1fcuscwplys7.jpeg", [("devant", 560, 620, 332)]),
    "salle_escaliers": ("salle principale/mw1fax6lr8xlgs.jpeg", [("devant", 230, 280, 348), ("droite", 500, 560, 362)]),
    "couloir_nord": ("couloir/mw1fo8fgcx50k3.jpeg", [("devant", 310, 365, 335)]),
    "salle_est": ("salle principale/mw1ffa5wt98ykq.jpeg", [("gauche", 90, 150, 345), ("devant", 380, 440, 302)]),
    "salle_tables": ("salle principale/mw1ffdde1fr2fh.jpeg", [("devant", 300, 350, 332)]),
    "salle_vitraux": ("salle principale/mw1fcs6j93w39q.jpeg", [("devant", 500, 560, 362), ("droite", 700, 767, 362)]),
    "salle_manuscrits": ("salle principale/mw1feovnoajwin.jpeg", [("gauche", 0, 50, 382), ("devant", 200, 270, 338)]),
    "salle_couleurs": ("salle principale/mw1few377clq7e.jpeg", []),
    "etude_entree": ("étude/mw1fru764bass6.jpeg", [("gauche", 0, 60, 342), ("devant", 260, 320, 302)]),
    "etude_escalier": ("étude/mw1fr818r0x30u.jpeg", [("gauche", 10, 80, 332), ("devant", 150, 220, 322)]),
    "etude_cartes": ("étude/mw1fq8klnkk6dj.jpeg", [("gauche", 10, 130, 332), ("droite", 450, 510, 332)]),
    "etude_vitrail": ("étude/mw1fqck52ytny8.jpeg", [("gauche", 60, 180, 345), ("droite", 600, 680, 342)]),
    "couloir_reserve": ("couloir/mw1fpa4ehzt0ly.jpeg", [("gauche", 55, 120, 380)]),
    "etude_haute": ("étude/mw1frqg2pqsq42.jpeg", [("gauche", 0, 50, 362)]),
    "distillation_entree": ("distillation/mw1fih5kxqobol.jpeg", [("gauche", 70, 150, 332), ("devant", 330, 400, 342),
                                                                 ("droite", 470, 560, 348)]),
    "distillation_cuves": ("distillation/mw1fi1tlsvs6fv.jpeg", [("gauche", 0, 55, 312), ("devant", 480, 560, 332)]),
    "distillation_balcon": ("distillation/mw1fi2yfopnqm1.jpeg", [("devant", 320, 440, 378)]),
    "distillation_ballons": ("distillation/mw1fi449igklwe.jpeg", [("gauche", 60, 130, 358)]),
    "distillation_lustre": ("distillation/mw1fi920bu3sgn.jpeg", [("gauche", 60, 150, 348), ("devant", 250, 330, 332)]),
    "distillation_verte": ("distillation/mw1fifptu0c0gb.jpeg", []),
    "distillation_cornues": ("distillation/mw1fipap8rnbh0.jpeg", [("gauche", 20, 120, 358), ("devant", 560, 640, 348)]),
    "distillation_piliers": ("distillation/mw1fhz8ioq56n1.jpeg", [("gauche", 20, 90, 345), ("droite", 560, 630, 345)]),
    "couloir_ouest": ("couloir/mw1foop3eva15a.jpeg", [("gauche", 50, 130, 362)]),
    "fourneaux_entree": ("fourneaux/mw1fjx5z0gnln0.jpeg", [("gauche", 60, 120, 368), ("droite", 560, 640, 342)]),
    "fourneaux_forge": ("fourneaux/mw1fkuavtkvfq4.jpeg", [("gauche", 30, 100, 348), ("devant", 440, 500, 362)]),
    "fourneaux_cheminees": ("fourneaux/mw1flbyugckx7p.jpeg", [("gauche", 0, 50, 332), ("devant", 300, 360, 340)]),
    "fourneaux_chaudron": ("fourneaux/mw1fm6w8igm1wp.jpeg", [("devant", 270, 330, 312)]),
    "fourneaux_escalier": ("fourneaux/mw1fjstrvhrloz.jpeg", [("gauche", 10, 90, 325)]),
    "fourneaux_creusets": ("fourneaux/mw1fju4w2pd25r.jpeg", [("gauche", 40, 100, 338), ("devant", 225, 275, 332)]),
    "fourneaux_cuisson": ("fourneaux/mw1fk0zr0khby5.jpeg", [("devant", 400, 470, 342)]),
    "fourneaux_brasier": ("fourneaux/mw1fkhfju0hhae.jpeg", [("gauche", 0, 60, 332)]),
}
NOMS_PORTES = {"gauche": "porte de gauche", "droite": "porte de droite", "devant": "passage du fond"}


def _salle_labo(image, portes):
    """Zones d'une salle du laboratoire : sorties de ``portes`` puis le retour (bas) ; sol provisoire (remplacé par le
    détourage automatique), perspective d'après le fond du sol (héros ≈ 210 px en bas de l'image)."""
    sorties = []
    for direction, x0, x1, y in portes:
        rect = [(x0, y - 6), (x1, y - 6), (min(767, x1 + 2), y + 6), (max(0, x0 - 2), y + 6)]
        if direction == "gauche":
            arrivee = [min(767, x1 + 20), y + 22, "right"]
        elif direction == "droite":
            arrivee = [max(0, x0 - 20), y + 22, "left"]
        else:
            arrivee = [(x0 + x1) // 2, y + 22, "down"]
        sorties.append([NOMS_PORTES[direction], direction, "porte", rect, arrivee])
    sorties.append(["retour", "bas", "passage", BAS, None])
    fond = min([p[3] for p in portes] + [345])
    h_fond = round(210 * 70 / (511 - fond + 70))
    return {"image": image, "marche": [(0, 511), (767, 511), (767, fond + 10), (0, fond + 10)], "obstacles": [],
            "sorties": sorties, "hauteurs": ((fond, h_fond), (511, 210)), "depart": [384, 480]}


BLOCS["laboratoire"] = {"source": LABO_SOURCE, "salles": {cle: _salle_labo(*v) for cle, v in LABO.items()}}


# ---------------------------------------------------------------------------
# Jardin : potager et verger (2026-11-04, 19 images de l'utilisateur dont un doublon : vergé/mw1h1g3hyh225o.jpeg =
# mw1h0nd9vsdaek.jpeg, écarté). Rattaché au bloc cuisine dans BlocsSalles (arche du fond de la réserve). Mêmes
# conventions que le laboratoire : portes de l'image (sans miroir) utilisées par le plan, sol détouré automatiquement.
# ---------------------------------------------------------------------------
JARDIN_SOURCE = r"C:\ia image\Salle de donjon"
JARDIN = {
    "potager_entree": ("potager/mw1hab008xu7cs.jpeg", [('devant', 390, 470, 262), ('gauche', 150, 230, 300), ('droite', 580, 650, 285)]),
    "potager_ouest": ("potager/mw1haehsc0i0cw.jpeg", [('devant', 360, 430, 268), ('gauche', 50, 130, 300)]),
    "potager_est": ("potager/mw1hbcnbg9kjkd.jpeg", [('devant', 350, 420, 298), ('gauche', 20, 90, 290)]),
    "potager_allee": ("potager/mw1havpk56f2ze.jpeg", [('devant', 310, 370, 250)]),
    "potager_haut": ("potager/mw1hb6djg6eb0j.jpeg", [('devant', 400, 520, 275)]),
    "potager_arcades": ("potager/mw1h9zdc1z0rba.jpeg", [('devant', 500, 580, 262)]),
    "verger_entree": ("vergé/mw1h0a6b9fhe8p.jpeg", [('gauche', 80, 200, 360), ('devant', 380, 460, 335), ('droite', 600, 700, 330)]),
    "verger_ouest": ("vergé/mw1h0ftqtbghg8.jpeg", [('devant', 300, 420, 335), ('gauche', 30, 120, 340)]),
    "verger_est": ("vergé/mw1h0tv9uv4uwu.jpeg", [('gauche', 150, 260, 300), ('devant', 380, 460, 310)]),
    "verger_centre": ("vergé/mw1h0nd9vsdaek.jpeg", [('devant', 280, 360, 330), ('gauche', 40, 160, 365), ('droite', 620, 720, 380)]),
    "verger_vieux_murs": ("vergé/mw1h1qli7qbccw.jpeg", [('devant', 320, 440, 345), ('gauche', 130, 220, 355)]),
    "verger_colonnes": ("vergé/mw1h1bh0isspgt.jpeg", [('devant', 380, 460, 335), ('gauche', 170, 260, 350)]),
    "verger_escaliers": ("vergé/mw1ghmzxd7ixxi.jpeg", [('devant', 330, 440, 300), ('droite', 640, 740, 320)]),
    "verger_terrasse": ("vergé/mw1h0blhs8w6s3.jpeg", [('gauche', 140, 250, 370)]),
    "verger_ruines": ("vergé/mw1h0vjxu7a8he.jpeg", [('devant', 380, 460, 322), ('gauche', 80, 180, 310)]),
    "verger_clos": ("vergé/mw1h1zqj7p08zq.jpeg", [('devant', 380, 460, 300), ('droite', 470, 560, 330)]),
    "verger_nord": ("vergé/mw1h0cvpn8rjaa.jpeg", [('devant', 230, 320, 282)]),
    "potager_cache": ("potager/mw1hc07pcvqdob.jpeg", []),
}

BLOCS["jardin"] = {"source": JARDIN_SOURCE, "salles": {cle: _salle_labo(*v) for cle, v in JARDIN.items()}}

# Bibliothèque refaite le 2026-11-04 (demande de l'utilisateur : même cohérence que le laboratoire, une porte de côté
# mène à la porte d'en face de la salle voisine) : portes utilisées par le nouveau plan (sans miroir), qui remplacent
# celles du relevé du 2026-11-04 ; le sol, les obstacles et la perspective restent ceux du relevé.
BIBLIO_PORTES = {
    "vestibule": [('gauche', 30, 85, 352), ('devant', 368, 420, 348), ('droite', 605, 650, 352)],
    "nef": [('devant', 355, 415, 362), ('gauche', 225, 280, 376), ('droite', 490, 545, 376)],
    "allee": [('devant', 358, 410, 345)],
    "globe": [('devant', 380, 440, 328)],
    "galerie_ouest": [('gauche', 10, 50, 339)],
    "archives": [('gauche', 20, 80, 345)],
    "balcons": [('gauche', 82, 130, 352), ('devant', 322, 372, 358)],
    "globes": [('devant', 270, 330, 332)],
    "lecture": [('devant', 300, 380, 335)],
    "piles": [],
    "vitraux": [('gauche', 10, 60, 340), ('devant', 355, 395, 336)],
    "galerie_haute": [('devant', 408, 458, 394)],
    "cartes": [('devant', 300, 380, 338)],
    "tapis": [],
}

for _cle, _portes in BIBLIO_PORTES.items():
    _s = _salle_labo(BLOCS["bibliotheque"]["salles"][_cle]["image"], _portes)
    BLOCS["bibliotheque"]["salles"][_cle]["sorties"] = _s["sorties"]


def ident(bloc, salle):
    return "bloc_%s_%s" % (bloc, salle)


def donnees_salle(bloc, nom, z):
    (y_a, h_a), (y_b, h_b) = z["hauteurs"]
    pente = (h_b - h_a) / (y_b - y_a)
    i = ident(bloc, nom)
    arrivees = {}
    for s in z["sorties"]:
        if s[4] is not None:
            arrivees[s[0]] = s[4]
    return {
        "fond": "images/salles_peintes/%s/fond.jpeg" % i,
        "fond_hd": "images/salles_peintes/%s/fond_hd.png" % i,
        "perspective": {"y_horizon": round(y_a - h_a / pente), "hauteur_par_pixel": round(pente, 3), "vitesse": 1.8,
                        "compression_profondeur": 0.6, "table_hauteur": [[y_a, h_a], [y_b, h_b]]},
        "depart": z["depart"],
        "marche": [[list(p) for p in z["marche"]]],
        "obstacles": [[list(p) for p in o] for o in z.get("obstacles", [])],
        "premier_plan": [[list(p) for p in o] for o in z.get("premier_plan", [])],
        "sorties": [[list(p) for p in s[3]] for s in z["sorties"]],
        "noms_sorties": [s[0] for s in z["sorties"]],
        "directions_sorties": [s[1] for s in z["sorties"]],
        "types_sorties": [s[2] for s in z["sorties"]],
        "arrivees": arrivees,
        "bloc": bloc,
        "ips": 24,
        "source": "%s/%s" % (os.path.basename(BLOCS[bloc]["source"]), z["image"]),
    }


def planche(bloc, donnees, sources):
    heros = Image.open(HEROS).convert("RGBA")
    heros = heros.crop(heros.getchannel("A").getbbox())
    police = ImageFont.load_default()
    cases = []
    for nom, d in donnees.items():
        im = sources[nom].convert("RGBA")
        calque = Image.new("RGBA", im.size)
        dr = ImageDraw.Draw(calque)
        dr.polygon([tuple(p) for p in d["marche"][0]], fill=(0, 255, 0, 55), outline=(0, 255, 0, 255))
        for o in d["obstacles"]:
            dr.polygon([tuple(p) for p in o], fill=(255, 0, 0, 110))
        couleurs = [(255, 220, 0, 170), (0, 200, 255, 170), (255, 0, 255, 170), (255, 255, 255, 120)]
        for i, s in enumerate(d["sorties"]):
            dr.polygon([tuple(p) for p in s], fill=couleurs[i % 4])
        im = Image.alpha_composite(im, calque)
        (ya, ha), (yb, hb) = d["perspective"]["table_hauteur"]
        points = [tuple(a[:2]) for a in d["arrivees"].values()] + [tuple(d["depart"])]
        for x, y in points:
            h = max(4, int(ha + (y - ya) * (hb - ha) / (yb - ya)))
            w = max(2, int(heros.width * h / heros.height))
            im.alpha_composite(heros.resize((w, h)), (int(x - w / 2), int(y - h)))
        ImageDraw.Draw(im).text((6, 4), "%s : %s" % (ident(bloc, nom), ", ".join(d["noms_sorties"])),
                                fill=(255, 255, 0, 255), font=police)
        cases.append(im.convert("RGB").resize((576, 384)))
    pl = Image.new("RGB", (576 * 2, 384 * ((len(cases) + 1) // 2)), "black")
    for k, c in enumerate(cases):
        pl.paste(c, ((k % 2) * 576, (k // 2) * 384))
    dossier = os.path.join(TRAVAIL, "bloc_" + bloc)
    os.makedirs(dossier, exist_ok=True)
    pl.save(os.path.join(dossier, "planche_zones.png"))


def main():
    from detourer_sols import detourage
    choisis = [x for x in sys.argv[1:] if not x.startswith("--")]
    for bloc, b in BLOCS.items():
        if choisis and bloc not in choisis:
            continue
        sources = {}
        donnees = {}
        for nom, z in b["salles"].items():
            i = ident(bloc, nom)
            sources[nom] = Image.open(os.path.join(b["source"], z["image"])).convert("RGB")
            assert sources[nom].size == (768, 512), (i, sources[nom].size)
            dossier = os.path.join(IMAGES, i)
            os.makedirs(dossier, exist_ok=True)
            sources[nom].save(os.path.join(dossier, "fond.jpeg"), quality=95)
            donnees[nom] = donnees_salle(bloc, nom, z)
            donnees[nom].update(detourage(i))  # sol détouré (laboratoire), puis retouches de l'éditeur de zones
            with open(os.path.join(DONNEES, i + ".json"), "w", encoding="utf8") as f:
                json.dump(donnees[nom], f, ensure_ascii=False, indent=1)
        if "--sans-ia" not in sys.argv:
            from importer_grandes_salles import agrandir
            noms = list(sources)
            for nom, hd in zip(noms, agrandir([sources[n] for n in noms])):
                hd.save(os.path.join(IMAGES, ident(bloc, nom), "fond_hd.png"), optimize=True)
        planche(bloc, donnees, sources)
        print("Bloc %s importé : %d salles" % (bloc, len(donnees)))


if __name__ == "__main__":
    main()
