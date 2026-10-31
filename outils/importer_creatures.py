"""Détoure les images de créatures (fond gris uni) et les copie dans le jeu Godot.

Une entrée par créature dans ``CREATURES`` : dossier source, nom des sprites, hauteur, et pour chaque image une boîte
(x0, y0, x1, y1) autour du personnage avec des points posés sur lui (tête, corps), et éventuellement des objets
tenus (lanternes...) détourés à part : [boîte, points], masques ajoutés au corps. Sortie :
``godot/images/pnj/<nom>_N.png`` (PNG transparent, recadré) ; ``combat`` : copie de la première image dans
``images/gobelins/`` (sprite fixe du combat, lu par ``Ui.texture("gobelins/" + image)``).
Même méthode que ``importer_diablotin.py`` (SAM, puis retrait des miettes de fond isolées).

Usage : ``python importer_creatures.py [nom ...]`` (sans nom : toutes).
"""
import os
import sys

import cv2
import numpy as np
import torch
from PIL import Image, ImageFilter
from transformers import SamModel, SamProcessor

from importer_diablotin import _masque

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DESTINATION = os.path.join(RACINE, "images", "pnj")
## Morceaux isolés plus petits que ça (pixels de l'image source) : miettes de fond, retirées.
MIETTES = 400

CREATURES = {
    "chevalier": {
        "source": r"C:\ia image\ennemis\chevalier de la mort",
        "hauteur": 520,
        "combat": "chevalier_de_la_mort.png",
        "images": {
            "mvq28kybtnj0zg.jpeg": ([35, 20, 735, 745], [[385, 80], [390, 250], [380, 480], [380, 690], [150, 520], [75, 680], [600, 600]]),
        },
    },
    "geolier": {
        "source": r"C:\ia image\ennemis\geolier",
        "hauteur": 480,
        "images": {
            "mvq1dbtmok9jrs.jpeg": ([60, 0, 710, 768], [[365, 77], [365, 384], [365, 700]],
                                    [([90, 400, 190, 590], [[140, 500], [140, 420]]), ([580, 400, 670, 590], [[625, 500], [625, 420]])]),
            "mvq1ei64r7iein.jpeg": ([60, 0, 710, 768], [[384, 77], [384, 384], [384, 700]],
                                    [([110, 470, 230, 768], [[165, 640], [165, 520]])]),
            "mvq1ept8rw7aw9.jpeg": ([60, 0, 710, 768], [[403, 77], [403, 480], [403, 720]],
                                    [([60, 470, 170, 690], [[115, 600], [115, 500]])]),
            "mvq1sj99g66ntp.jpeg": ([60, 0, 710, 768], [[442, 77], [442, 442], [442, 720]],
                                    [([125, 480, 260, 650], [[190, 590], [190, 510]]), ([490, 500, 615, 670], [[550, 610], [550, 530]])]),
        },
    },
}


def detourer(pr, md, chemin, boite, points, hauteur, objets=()):
    """Image RGBA détourée (corps et objets tenus), recadrée et mise à ``hauteur`` pixels."""
    image = Image.open(chemin).convert("RGB")
    masque, score = _masque(pr, md, image, boite, points)
    for b, pts in objets:
        masque = masque | _masque(pr, md, image, b, pts)[0]
    n, etiquettes, stats, _ = cv2.connectedComponentsWithStats(masque.astype(np.uint8), connectivity=8)
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_AREA] < MIETTES:
            masque[etiquettes == i] = False
    alpha = Image.fromarray((masque * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
    rgba = image.copy()
    rgba.putalpha(alpha)
    rgba = rgba.crop(rgba.getbbox())
    largeur = round(rgba.width * hauteur / rgba.height)
    return rgba.resize((largeur, hauteur), Image.LANCZOS), score


def main():
    """Détoure les créatures demandées (toutes par défaut)."""
    noms = sys.argv[1:] or list(CREATURES)
    os.makedirs(DESTINATION, exist_ok=True)
    pr = SamProcessor.from_pretrained("facebook/sam-vit-huge")
    md = SamModel.from_pretrained("facebook/sam-vit-huge").to("cuda")
    for nom in noms:
        c = CREATURES[nom]
        for k, (fichier, reglage) in enumerate(sorted(c["images"].items()), 1):
            boite, points = reglage[0], reglage[1]
            objets = reglage[2] if len(reglage) > 2 else ()
            rgba, score = detourer(pr, md, os.path.join(c["source"], fichier), boite, points, c["hauteur"], objets)
            dst = os.path.join(DESTINATION, "%s_%d.png" % (nom, k))
            rgba.save(dst)
            print("%s -> %s (%dx%d, score %.3f)" % (fichier, dst, rgba.width, rgba.height, score))
            if k == 1 and c.get("combat"):
                rgba.save(os.path.join(RACINE, "images", "gobelins", c["combat"]))


if __name__ == "__main__":
    main()
