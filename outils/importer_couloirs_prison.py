"""Importe les couloirs de prison menant aux cryptes (2026-11-03, images de l'utilisateur).

Source : ``C:\\ia image\\Salle de donjon\\prison\\couloir de prison menant au crypte\\*.jpeg`` (4 images 768 x 512,
triées par nom : couloir_prison1 … couloir_prison4). Chaque prison de l'étage finit par un de ces couloirs : sa
sortie du fond mène à l'entrée du niveau des cryptes (GenerateurEtage, Donjon.NIVEAU_CRYPTES).

Deux sorties, dans cet ordre : **devant** (le fond du couloir, vers les cryptes) et **bas** (retour). Les zones
(sol, sortie du fond, perspective) sont relevées par Claude sur une grille : approximatives, à affiner dans
l'éditeur de zones (``editeur_zones.bat couloir_prison1``). Un couloir déjà retouché dans l'éditeur garde ses
zones (``outils/zones_manuelles/<id>.json`` : ce script ne réécrit alors pas son .json).

Écrit ``images/salles_peintes/couloir_prisonN/fond.jpeg`` et ``fond_hd.png`` (agrandie par IA comme les grandes
salles, ``importer_grandes_salles.agrandir``) et ``donnees/salles_peintes/couloir_prisonN.json``.

Usage : ``python outils/importer_couloirs_prison.py [--sans-ia]``.
"""
import glob
import json
import os
import sys

from PIL import Image

SOURCE = r"C:\ia image\Salle de donjon\prison\couloir de prison menant au crypte"
ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMAGES = os.path.join(ICI, "images", "salles_peintes")
DONNEES = os.path.join(ICI, "donnees", "salles_peintes")
MANUELLES = os.path.join(ICI, "outils", "zones_manuelles")

# Sol (bord du fond, de gauche à droite), sortie du fond (x0, x1, y), perspective (hauteur du héros à deux
# profondeurs), nom de la sortie du fond.
ZONES = {
    1: {"fond": [(0, 400), (100, 380), (180, 350), (260, 322), (330, 302), (400, 298), (470, 300), (540, 320),
                 (600, 345), (700, 372), (767, 400)],
        "devant": (380, 470, 299), "hauteurs": ((300, 40), (511, 175)), "nom_devant": "fond du couloir"},
    2: {"fond": [(0, 400), (100, 380), (180, 350), (260, 322), (330, 302), (400, 298), (470, 300), (540, 320),
                 (600, 345), (700, 372), (767, 400)],
        "devant": (380, 470, 299), "hauteurs": ((300, 40), (511, 175)), "nom_devant": "fond du couloir"},
    3: {"fond": [(0, 440), (140, 400), (240, 350), (320, 304), (420, 300), (470, 304), (560, 350), (650, 400),
                 (767, 440)],
        "devant": (330, 420, 301), "hauteurs": ((300, 35), (511, 175)), "nom_devant": "fond du couloir"},
    4: {"fond": [(0, 460), (150, 440), (300, 400), (470, 360), (560, 345), (640, 335), (720, 345), (767, 380)],
        "devant": (600, 700, 336), "hauteurs": ((335, 30), (511, 175)), "nom_devant": "couloir de droite"},
}


def donnees_salle(n, z):
    (y_a, h_a), (y_b, h_b) = z["hauteurs"]
    pente = (h_b - h_a) / (y_b - y_a)
    x0, x1, y = z["devant"]
    ident = "couloir_prison%d" % n
    return {
        "fond": "images/salles_peintes/%s/fond.jpeg" % ident,
        "fond_hd": "images/salles_peintes/%s/fond_hd.png" % ident,
        "perspective": {"y_horizon": round(y_a - h_a / pente), "hauteur_par_pixel": round(pente, 3), "vitesse": 1.8,
                        "compression_profondeur": 0.6, "table_hauteur": [[y_a, h_a], [y_b, h_b]]},
        "depart": [384, 470],
        "marche": [[[0, 511], [767, 511]] + [list(p) for p in reversed(z["fond"])]],
        "obstacles": [],
        "premier_plan": [],
        "sorties": [
            [[x0, y - 3], [x1, y - 3], [x1, y + 12], [x0, y + 12]],
            [[0, 499], [767, 499], [767, 517], [0, 517]],
        ],
        "noms_sorties": [z["nom_devant"], "retour"],
        "directions_sorties": ["devant", "bas"],
        "types_sorties": ["passage", "passage"],
        "sorties_potentielles": [False, False],
        "arrivees": {z["nom_devant"]: [(x0 + x1) // 2, y + 30, "down"]},
        "ips": 24,
        "source": "prison/couloir de prison menant au crypte/%d" % n,
        "prisonniers": [],
        "cachettes": [],
    }


def main():
    fichiers = sorted(glob.glob(os.path.join(SOURCE, "*.jpeg")))
    assert len(fichiers) == len(ZONES), "une entrée de ZONES par image"
    sources = {k + 1: Image.open(f).convert("RGB") for k, f in enumerate(fichiers)}
    for n, z in ZONES.items():
        ident = "couloir_prison%d" % n
        dossier = os.path.join(IMAGES, ident)
        os.makedirs(dossier, exist_ok=True)
        sources[n].save(os.path.join(dossier, "fond.jpeg"), quality=95)
        chemin = os.path.join(DONNEES, ident + ".json")
        if os.path.exists(os.path.join(MANUELLES, ident + ".json")) and os.path.exists(chemin):
            print(ident, ": zones retouchées dans l'éditeur, .json gardé")
            continue
        with open(chemin, "w", encoding="utf8") as f:
            from detourer_sols import avec_perspective  # perspective mesurée (outils/mesurer_perspective.py)
            json.dump(avec_perspective(ident, donnees_salle(n, z)), f, ensure_ascii=False, indent=1)
    if "--sans-ia" not in sys.argv:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from importer_grandes_salles import agrandir
        for n, hd in zip(sources, agrandir([sources[n] for n in sources])):
            hd.save(os.path.join(IMAGES, "couloir_prison%d" % n, "fond_hd.png"), optimize=True)
    print("Couloirs de prison importés :", len(ZONES))


if __name__ == "__main__":
    main()
