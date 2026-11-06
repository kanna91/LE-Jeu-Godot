"""Importe les « couloirs aux livres » (2026-11-04, 37 images de l'utilisateur) : salles ordinaires de l'étage.

Source : ``C:\\ia image\\Salle de donjon\\couloire\\couloir livre\\*.jpeg`` (triées par nom → couloir_livre01 …
couloir_livre37). Ces images servent dans le reste du donjon, jamais dans les cryptes, les prisons ni les blocs
(bibliothèque, laboratoire, cuisine : salles nommées) : c'est déjà la règle de ``PlanSalles`` (les salles réservées
prennent leurs propres images, et ces images-ci ne sont pas réservées).

Portes relevées par Claude sur les planches ``C:\\IA\\pont-blender\\couloirs_livres\\travail\\quad_NN.png`` :
(direction de l'image, x début, x fin, y du sol au pied du passage). Toutes les portes (fond, gauche, droite) sont des
**sorties potentielles** (``PlanSalles``) : sans salle derrière, elles deviennent un mur invisible, sans malus, ce
qui permet au même couloir de servir à beaucoup de formes de salles. Le retour (bas de l'image) est ajouté. Le sol et
les obstacles viennent du détourage automatique (``outils/detourer_sols.py couloir_livre01 ...``), la perspective est
estimée d'après le fond du sol. Les retouches de l'éditeur de zones passent devant.

Écrit ``images/salles_peintes/couloir_livreNN/fond.jpeg`` et ``fond_hd.png`` (agrandie par IA ; ``--sans-ia`` : ne
la refait pas), ``donnees/salles_peintes/couloir_livreNN.json``.

Usage : ``python outils/importer_couloirs_livres.py [--sans-ia]``
"""
import glob
import json
import os
import sys

from PIL import Image

ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ICI, "outils"))
SOURCE = r"C:\ia image\Salle de donjon\couloire\couloir livre"
IMAGES = os.path.join(ICI, "images", "salles_peintes")
DONNEES = os.path.join(ICI, "donnees", "salles_peintes")
BAS = [[0, 499], [767, 499], [767, 517], [0, 517]]
NOMS = {"gauche": "passage de gauche", "droite": "passage de droite", "devant": "passage du fond"}

PORTES = {
    1: [("devant", 250, 330, 355), ("gauche", 0, 40, 390)],
    2: [("devant", 330, 430, 352)],
    3: [("devant", 300, 420, 375)],
    4: [("devant", 230, 330, 360)],
    5: [("devant", 380, 460, 395), ("gauche", 120, 200, 405)],
    6: [("devant", 560, 650, 390)],
    7: [("devant", 330, 420, 378), ("droite", 530, 600, 365)],
    8: [("devant", 480, 600, 375)],
    9: [("devant", 340, 410, 375)],
    10: [("devant", 280, 380, 385), ("droite", 430, 500, 395)],
    11: [("devant", 400, 490, 370)],
    12: [("devant", 240, 330, 402), ("droite", 560, 640, 392)],
    13: [("devant", 470, 560, 355)],
    14: [("devant", 270, 350, 372), ("gauche", 60, 150, 390)],
    15: [("devant", 130, 200, 372), ("droite", 540, 620, 392)],
    16: [("devant", 360, 440, 385), ("droite", 500, 580, 380)],
    17: [("droite", 560, 660, 398)],
    18: [("devant", 560, 640, 375)],
    19: [("devant", 570, 640, 360)],
    20: [("devant", 440, 490, 395), ("gauche", 100, 180, 400)],
    21: [("devant", 430, 480, 385), ("droite", 540, 610, 388)],
    22: [("devant", 350, 480, 370)],
    23: [("devant", 430, 480, 340)],
    24: [("devant", 360, 430, 330)],
    25: [("devant", 380, 430, 342), ("devant", 520, 580, 340)],
    26: [("devant", 390, 460, 365)],
    27: [("devant", 500, 560, 340), ("gauche", 150, 250, 368)],
    28: [("devant", 440, 520, 380)],
    29: [("gauche", 90, 200, 405), ("devant", 580, 660, 360)],
    30: [("devant", 420, 500, 370), ("gauche", 190, 270, 380), ("droite", 500, 570, 360)],
    31: [("gauche", 130, 210, 370), ("devant", 400, 520, 365)],
    32: [("gauche", 50, 130, 395), ("devant", 350, 430, 395)],
    33: [("gauche", 150, 230, 380), ("droite", 480, 600, 395)],
    34: [("gauche", 140, 200, 360), ("devant", 270, 360, 360), ("droite", 520, 640, 370)],
    35: [("droite", 450, 570, 380)],
    36: [("gauche", 60, 130, 400), ("droite", 500, 640, 395)],
    37: [("gauche", 160, 240, 380), ("devant", 450, 600, 375)],
}


def donnees(ident, portes, fichier):
    sorties, noms, directions, types, arrivees = [], [], [], [], {}
    vus = {}
    for direction, x0, x1, y in portes:
        vus[direction] = vus.get(direction, 0) + 1
        nom = NOMS[direction] + ("" if vus[direction] == 1 else " %d" % vus[direction])
        sorties.append([[x0, y - 6], [x1, y - 6], [min(767, x1 + 2), y + 6], [max(0, x0 - 2), y + 6]])
        noms.append(nom)
        directions.append(direction)
        types.append("passage")
        if direction == "gauche":
            arrivees[nom] = [min(767, x1 + 20), y + 22, "right"]
        elif direction == "droite":
            arrivees[nom] = [max(0, x0 - 20), y + 22, "left"]
        else:
            arrivees[nom] = [(x0 + x1) // 2, y + 22, "down"]
    sorties.append(BAS)
    noms.append("retour")
    directions.append("bas")
    types.append("passage")
    fond = min([p[3] for p in portes] + [360])
    h_fond = round(210 * 70 / (511 - fond + 70))
    pente = (210 - h_fond) / (511 - fond)
    return {
        "fond": "images/salles_peintes/%s/fond.jpeg" % ident,
        "fond_hd": "images/salles_peintes/%s/fond_hd.png" % ident,
        "perspective": {"y_horizon": round(fond - h_fond / pente), "hauteur_par_pixel": round(pente, 3), "vitesse": 1.8,
                        "compression_profondeur": 0.6, "table_hauteur": [[fond, h_fond], [511, 210]]},
        "depart": [384, 480],
        "marche": [[[0, 511], [767, 511], [767, fond + 10], [0, fond + 10]]],
        "obstacles": [],
        "premier_plan": [],
        "sorties": sorties,
        "noms_sorties": noms,
        "directions_sorties": directions,
        "types_sorties": types,
        "sorties_potentielles": [d != "bas" for d in directions],
        "arrivees": arrivees,
        "ips": 24,
        "source": "couloir livre/%s" % os.path.basename(fichier),
    }


def main():
    from detourer_sols import detourage, avec_perspective
    fichiers = sorted(glob.glob(os.path.join(SOURCE, "*.jpeg")))
    assert len(fichiers) == len(PORTES), (len(fichiers), len(PORTES))
    sources = []
    for k, f in enumerate(fichiers, start=1):
        ident = "couloir_livre%02d" % k
        im = Image.open(f).convert("RGB")
        assert im.size == (768, 512), (f, im.size)
        dossier = os.path.join(IMAGES, ident)
        os.makedirs(dossier, exist_ok=True)
        im.save(os.path.join(dossier, "fond.jpeg"), quality=95)
        d = donnees(ident, PORTES[k], f)
        d.update(detourage(ident))  # sol détouré, puis retouches de l'éditeur de zones
        avec_perspective(ident, d)  # perspective mesurée (outils/mesurer_perspective.py)
        with open(os.path.join(DONNEES, ident + ".json"), "w", encoding="utf8") as fj:
            json.dump(d, fj, ensure_ascii=False, indent=1)
        sources.append((ident, im))
    if "--sans-ia" not in sys.argv:
        from importer_grandes_salles import agrandir
        for (ident, _im), hd in zip(sources, agrandir([s[1] for s in sources])):
            hd.save(os.path.join(IMAGES, ident, "fond_hd.png"), optimize=True)
    print("Couloirs aux livres importés : %d" % len(sources))


if __name__ == "__main__":
    main()
