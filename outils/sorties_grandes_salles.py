"""Grandes salles refaites à la main (2026-10-28) : sorties sur les ouvertures visibles et sol simple.

Retour de l'utilisateur : les grandes salles étaient « un cauchemar à naviguer » (sorties posées au milieu du sol ou
dans les coins, sans rien de visible ; bord du sol très dentelé). Pour chaque salle, relevé à l'œil sur l'image
(``C:\\IA\\pont-blender\\zones\\vues``, quadrillage en pixels de l'image 768 × 512) :
- **devant** : au pied de l'ouverture du fond (arche, porte, escalier, allée dans la brume) ;
- **gauche** / **droite** : une ouverture visible de ce côté (escalier, arche, porte) ; à défaut, le bord de l'image ;
- **bas** : la bande du bas (retour), inchangée ;
- **sol** : un contour lisse (bord du fond de gauche à droite, puis le bas de l'image) qui contient les sorties ;
- **arrivées** : le héros arrive un peu devant la sortie par laquelle il entre.
Les obstacles et le premier plan existants sont gardés (piliers des salles 5 et 9). Le jeu fait luire les sorties
praticables (``SallePeinte``), ce qui guide le joueur.

Écrit ``donnees/salles_peintes/<id>.json`` et ``outils/zones_manuelles/<id>.json`` (avec historique, comme
``outils/zones.py`` : ``python outils/zones.py annuler <id>`` revient en arrière).
Usage : ``python outils/sorties_grandes_salles.py [id ...]`` (sans argument : les 10).
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zones  # noqa: E402

# Salle → bord du fond du sol (de gauche à droite), sorties [devant, gauche, droite] (quadrilatères) et sens d'arrivée.
SALLES = {
    "grande1": {
        "fond": [(0, 342), (92, 340), (98, 322), (200, 320), (330, 318), (496, 318), (500, 314), (592, 314), (598, 312),
                 (686, 312), (702, 330), (767, 340)],
        "devant": [(502, 318), (586, 318), (590, 332), (498, 332)],
        "gauche": [(104, 324), (192, 324), (196, 338), (100, 338)],
        "droite": [(604, 316), (680, 316), (684, 330), (600, 330)],
    },
    "grande2": {
        "fond": [(0, 370), (60, 366), (134, 358), (138, 344), (258, 344), (300, 350), (470, 350), (560, 348), (564, 334),
                 (658, 334), (696, 334), (767, 334)],
        "devant": [(568, 338), (652, 338), (656, 350), (564, 350)],
        "gauche": [(142, 348), (252, 348), (256, 360), (138, 360)],
        "droite": [(702, 338), (767, 338), (767, 356), (698, 356)],
    },
    "grande3": {
        "fond": [(100, 512), (128, 470), (200, 430), (226, 412), (230, 396), (294, 396), (300, 380), (318, 340),
                 (462, 340), (482, 360), (540, 380), (600, 408), (666, 428), (732, 428), (750, 470), (742, 512)],
        "devant": [(330, 342), (450, 342), (458, 356), (322, 356)],
        "gauche": [(234, 400), (290, 400), (292, 412), (228, 412)],
        "droite": [(670, 432), (728, 432), (736, 452), (676, 452)],
    },
    "grande4": {
        "fond": [(0, 380), (60, 374), (140, 368), (200, 358), (204, 344), (268, 344), (292, 350), (296, 350), (426, 350),
                 (458, 354), (462, 352), (538, 352), (600, 370), (700, 384), (767, 388)],
        "devant": [(300, 354), (420, 354), (426, 366), (294, 366)],
        "gauche": [(208, 348), (264, 348), (268, 360), (204, 360)],
        "droite": [(464, 356), (536, 356), (540, 370), (460, 370)],
        "obstacles_en_plus": [[(696, 404), (712, 398), (732, 398), (746, 404), (746, 414), (730, 420), (712, 420), (696, 414)]],
    },
    "grande5": {
        "fond": [(0, 408), (80, 396), (160, 370), (188, 340), (194, 324), (298, 324), (330, 334), (446, 340), (450, 328),
                 (554, 328), (600, 342), (662, 348), (666, 334), (762, 334), (767, 344)],
        "devant": [(454, 332), (548, 332), (552, 344), (450, 344)],
        "gauche": [(198, 328), (292, 328), (296, 340), (194, 340)],
        "droite": [(670, 338), (756, 338), (760, 352), (666, 352)],
    },
    "grande6": {
        "fond": [(0, 350), (100, 330), (150, 308), (310, 300), (314, 290), (428, 290), (432, 300), (560, 304), (620, 320),
                 (634, 334), (728, 334), (767, 340)],
        "devant": [(318, 294), (424, 294), (428, 306), (314, 306)],
        "gauche": [(0, 358), (20, 356), (20, 422), (0, 424)],
        "droite": [(640, 338), (722, 338), (726, 352), (636, 352)],
    },
    "grande7": {
        "fond": [(0, 440), (40, 424), (72, 408), (78, 394), (178, 394), (220, 398), (372, 398), (378, 386), (488, 386),
                 (552, 392), (558, 390), (648, 390), (700, 408), (767, 418)],
        "devant": [(382, 390), (482, 390), (486, 402), (378, 402)],
        "gauche": [(82, 398), (172, 398), (176, 412), (78, 412)],
        "droite": [(562, 394), (642, 394), (646, 408), (558, 408)],
    },
    "grande8": {
        "fond": [(0, 410), (60, 400), (112, 380), (118, 366), (208, 366), (260, 344), (332, 332), (338, 320), (408, 320),
                 (470, 328), (580, 348), (612, 358), (708, 358), (767, 366)],
        "devant": [(342, 324), (402, 324), (406, 336), (338, 336)],
        "gauche": [(122, 370), (202, 370), (206, 384), (118, 384)],
        "droite": [(618, 362), (702, 362), (706, 376), (614, 376)],
    },
    "grande9": {
        "fond": [(0, 392), (102, 388), (108, 374), (192, 374), (200, 386), (262, 382), (292, 376), (298, 364), (508, 364),
                 (514, 376), (546, 380), (632, 386), (738, 386), (767, 392)],
        "devant": [(302, 368), (502, 368), (506, 380), (296, 380)],
        "gauche": [(112, 378), (186, 378), (190, 390), (106, 390)],
        "droite": [(640, 390), (730, 390), (736, 402), (634, 402)],
    },
    "grande10": {
        "fond": [(0, 428), (80, 418), (170, 398), (240, 360), (270, 322), (332, 310), (338, 298), (418, 298), (480, 314),
                 (520, 340), (600, 388), (690, 418), (767, 428)],
        "devant": [(342, 302), (412, 302), (416, 314), (338, 314)],
        "gauche": [(0, 436), (24, 434), (24, 492), (0, 494)],
        "droite": [(744, 434), (767, 436), (767, 494), (744, 492)],
    },
}


def centre_bas(quad):
    xs = [p[0] for p in quad]
    return round(sum(xs) / len(xs)), max(p[1] for p in quad)


def refaire(ident):
    s = SALLES[ident]
    info = zones.lire(ident)
    avant = json.loads(json.dumps({c: info.get(c, []) for c in zones.COUCHES}))
    sol = [list(p) for p in s["fond"]] + [[767, 512], [0, 512]]
    if s["fond"][0][1] >= 512 or s["fond"][0][0] > 0:  # sol qui ne touche pas le bord gauche (grande3)
        sol = [list(p) for p in s["fond"]]
    sorties = info["sorties"]
    noms = info["noms_sorties"]
    nouvelles = [s["devant"], s["gauche"], s["droite"]]
    for k, quad in enumerate(nouvelles):
        sorties[k] = [list(p) for p in quad]
    info["marche"] = [sol]
    info["sorties"] = sorties
    if s.get("obstacles_en_plus"):
        info["obstacles"] = info.get("obstacles", []) + [[list(p) for p in q] for q in s["obstacles_en_plus"]]
    # Arrivées : un peu devant la sortie (le héros regarde vers la salle)
    arrivees = dict(info.get("arrivees", {}))
    sens = ["down", "down_right", "down_left"]
    for k, quad in enumerate(nouvelles):
        x, y = centre_bas(quad)
        bord = min(p[0] for p in quad) <= 0 or max(p[0] for p in quad) >= 767
        if bord:
            x = 44 if k == 1 else 723
        arrivees[noms[k]] = [x, y + (6 if bord else 22), ["down", "right", "left"][k] if bord else sens[k]]
    info["arrivees"] = arrivees
    zones.ecrire(ident, info, avant)
    # Les arrivées vont aussi dans les zones manuelles (relues par les importeurs)
    chemin = os.path.join(zones.MANUELLES, ident + ".json")
    manuelles = json.load(open(chemin, encoding="utf8"))
    manuelles["arrivees"] = arrivees
    with open(chemin, "w", encoding="utf8") as f:
        json.dump(manuelles, f)
    print("refaite :", ident)


if __name__ == "__main__":
    for ident in sys.argv[1:] or list(SALLES):
        refaire(ident)
