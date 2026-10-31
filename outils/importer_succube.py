"""Détoure les images de la succube (fond gris uni) et les copie dans le jeu Godot.

Sources : ``C:\\ia image\\ennemis\\succube\\*.jpeg`` ; sortie : ``godot/images/pnj/succube_N.png`` (PNG transparent,
recadré, hauteur ``HAUTEUR``). Même méthode que ``importer_diablotin.py`` (SAM avec une boîte autour du
personnage) ; la queue, fine, a son propre masque (boîte et points), ajouté au corps.

Usage : ``python importer_succube.py``
"""
import os
import glob

import cv2
import numpy as np
import torch
from PIL import Image, ImageFilter
from transformers import SamModel, SamProcessor

from importer_diablotin import _masque

SOURCE = r"C:\ia image\ennemis\succube"
DESTINATION = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "images", "pnj")
HAUTEUR = 480
## Corps, par fichier (images 768×768) : boîte (x0, y0, x1, y1) et points sur le personnage (visage, robe, ailes).
CORPS = {
    "mvq0gvr9v5cnvn.jpeg": ([100, 5, 670, 740], None),
    "mvq0iirewz3s9n.jpeg": ([50, 0, 715, 760], [[385, 110], [400, 400], [400, 640], [130, 330], [660, 330], [380, 30]]),
    "mvq0j10b7rt47o.jpeg": ([75, 0, 695, 750], [[385, 110], [390, 300], [390, 470], [380, 650], [150, 250], [620, 250], [380, 25]]),
}
## Morceaux isolés plus petits que ça (pixels de l'image source) : miettes de fond, retirées.
MIETTES = 400
## Queue (fine, souvent oubliée) : une ou plusieurs [boîte, points], masques ajoutés au corps.
QUEUES = {
    "mvq0gvr9v5cnvn.jpeg": [([105, 450, 580, 700], [[205, 565], [165, 610], [175, 680], [545, 520], [520, 610]])],
    # (le bout droit de la queue sortait en morceau isolé : laissé de côté)
    "mvq0iirewz3s9n.jpeg": [([110, 440, 200, 700], [[150, 470], [175, 560], [150, 650]])],
    "mvq0j10b7rt47o.jpeg": [([215, 560, 520, 745], [[250, 640], [300, 722], [470, 702]])],
}


def main():
    """Détoure chaque image source et enregistre les sprites."""
    os.makedirs(DESTINATION, exist_ok=True)
    pr = SamProcessor.from_pretrained("facebook/sam-vit-huge")
    md = SamModel.from_pretrained("facebook/sam-vit-huge").to("cuda")
    fichiers = sorted(glob.glob(os.path.join(SOURCE, "*.jpeg")) + glob.glob(os.path.join(SOURCE, "*.png")))
    for k, chemin in enumerate(fichiers, 1):
        nom = os.path.basename(chemin)
        image = Image.open(chemin).convert("RGB")
        boite, points = CORPS.get(nom, ([0, 0, image.width, image.height], None))
        masque, score = _masque(pr, md, image, boite, points)
        for b, pts in QUEUES.get(nom, []):
            masque = masque | _masque(pr, md, image, b, pts)[0]
        n, etiquettes, stats, _ = cv2.connectedComponentsWithStats(masque.astype(np.uint8), connectivity=8)
        for i in range(1, n):
            if stats[i, cv2.CC_STAT_AREA] < MIETTES:
                masque[etiquettes == i] = False
        alpha = Image.fromarray((masque * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
        rgba = image.copy()
        rgba.putalpha(alpha)
        rgba = rgba.crop(rgba.getbbox())
        largeur = round(rgba.width * HAUTEUR / rgba.height)
        rgba = rgba.resize((largeur, HAUTEUR), Image.LANCZOS)
        dst = os.path.join(DESTINATION, "succube_%d.png" % k)
        rgba.save(dst)
        print("%s -> %s (%dx%d, score %.3f)" % (nom, dst, largeur, HAUTEUR, score))


if __name__ == "__main__":
    main()
