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
    from detourer_sols import zones_manuelles
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
            donnees[nom].update(zones_manuelles(i))  # retouches de l'éditeur de zones
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
