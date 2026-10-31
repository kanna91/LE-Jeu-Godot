"""Détoure les images du diablotin (fond gris uni) et les copie dans le jeu Godot.

Sources : ``C:\\ia image\\ennemis\\diablotin\\*.jpeg`` ; sortie : ``godot/images/pnj/diablotin_N.png`` (PNG transparent,
recadré sur le personnage, hauteur ``HAUTEUR``). Détourage par SAM (``facebook/sam-vit-huge``, déjà en cache) avec
une boîte autour du personnage, puis lissage du bord.

Usage (depuis n'importe où) : ``python importer_diablotin.py``
"""
import os
import glob

import numpy as np
import torch
from PIL import Image, ImageFilter
from transformers import SamModel, SamProcessor

SOURCE = r"C:\ia image\ennemis\diablotin"
DESTINATION = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "images", "pnj")
HAUTEUR = 360
## Boîtes (x0, y0, x1, y1) autour du diablotin, par nom de fichier (images 768×512).
BOITES = {
    "diblotin.jpeg": [150, 25, 665, 500],
    "mvpziq40aywvdj.jpeg": [170, 10, 615, 500],
}
## Fourche (fine, oubliée par le masque du corps) : boîte et points sur le manche et les dents, masque ajouté au corps.
FOURCHES = {
    "diblotin.jpeg": ([455, 35, 660, 375], [[600, 140], [575, 185], [540, 240], [505, 300], [478, 350], [568, 70], [636, 85]]),
    "mvpziq40aywvdj.jpeg": ([485, 25, 610, 495], [[548, 200], [538, 280], [525, 360], [510, 450], [575, 40], [598, 80], [528, 80]]),
}


def _masque(pr, md, image, boite, points=None):
    """Masque SAM (le plus sûr des trois proposés) pour une boîte et des points positifs facultatifs."""
    options = {"input_boxes": [[boite]]}
    if points:
        options["input_points"] = [[points]]
        options["input_labels"] = [[[1] * len(points)]]
    entrees = pr(image, return_tensors="pt", **options).to("cuda")
    with torch.no_grad():
        sortie = md(**entrees, multimask_output=True)
    masques = pr.image_processor.post_process_masks(sortie.pred_masks.cpu(), entrees["original_sizes"].cpu(),
                                                    entrees["reshaped_input_sizes"].cpu())[0][0].numpy()
    scores = sortie.iou_scores.cpu().numpy()[0][0]
    return masques[int(np.argmax(scores))], float(scores.max())


def main():
    """Détoure chaque image source et enregistre les sprites."""
    os.makedirs(DESTINATION, exist_ok=True)
    pr = SamProcessor.from_pretrained("facebook/sam-vit-huge")
    md = SamModel.from_pretrained("facebook/sam-vit-huge").to("cuda")
    fichiers = sorted(glob.glob(os.path.join(SOURCE, "*.jpeg")) + glob.glob(os.path.join(SOURCE, "*.png")))
    for k, chemin in enumerate(fichiers, 1):
        image = Image.open(chemin).convert("RGB")
        boite = BOITES.get(os.path.basename(chemin), [0, 0, image.width, image.height])
        masque, score = _masque(pr, md, image, boite)
        if os.path.basename(chemin) in FOURCHES:
            b, pts = FOURCHES[os.path.basename(chemin)]
            masque = masque | _masque(pr, md, image, b, pts)[0]
        alpha = Image.fromarray((masque * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
        rgba = image.copy()
        rgba.putalpha(alpha)
        cadre = rgba.getbbox()
        rgba = rgba.crop(cadre)
        largeur = round(rgba.width * HAUTEUR / rgba.height)
        rgba = rgba.resize((largeur, HAUTEUR), Image.LANCZOS)
        dst = os.path.join(DESTINATION, "diablotin_%d.png" % k)
        rgba.save(dst)
        print("%s -> %s (%dx%d, score %.3f)" % (os.path.basename(chemin), dst, largeur, HAUTEUR, score))


if __name__ == "__main__":
    main()
