"""Importe les animations du diablotin faites par Grok (images déjà détourées) dans le jeu Godot.

Source : ``C:\\ia image\\ennemis\\diablotin\\diablotin 01\\<animation>\\frame_NNN.png`` (838 x 708, fond
transparent, caméra fixe : les pieds restent à la même hauteur) et ``frames.json``.
Sortie : ``images/pnj/diablotin_anim/<animation>_NNN.png``, recadrées sur une **même boîte** pour toutes les images
des deux animations (le diablotin ne saute pas d'une image à l'autre), réduites à HAUTEUR pixels de haut, et
``images/pnj/diablotin_anim/animations.json`` (nombre d'images, cadence, boucle).

Usage : ``python outils/importer_animations_diablotin.py`` puis ``godot --headless --path . --import``.
"""
import json
import os

from PIL import Image

SOURCE = r"C:\ia image\ennemis\diablotin\diablotin 01"
ANIMATIONS = ["respiration", "rire"]
HAUTEUR = 320
ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SORTIE = os.path.join(ICI, "images", "pnj", "diablotin_anim")


def main():
    os.makedirs(SORTIE, exist_ok=True)
    infos, images = {}, {}
    boite = None
    for nom in ANIMATIONS:
        dossier = os.path.join(SOURCE, nom)
        with open(os.path.join(dossier, "frames.json"), encoding="utf8") as f:
            meta = json.load(f)
        liste = [Image.open(os.path.join(dossier, "frame_%03d.png" % k)).convert("RGBA") for k in range(meta["frame_count"])]
        images[nom] = liste
        infos[nom] = {"images": len(liste), "fps": meta["fps"], "boucle": bool(meta.get("loop", nom == "respiration"))}
        for im in liste:
            b = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
            if b:
                boite = b if boite is None else (min(boite[0], b[0]), min(boite[1], b[1]), max(boite[2], b[2]), max(boite[3], b[3]))
    largeur = round((boite[2] - boite[0]) * HAUTEUR / (boite[3] - boite[1]))
    for nom, liste in images.items():
        for k, im in enumerate(liste):
            im.crop(boite).resize((largeur, HAUTEUR), Image.LANCZOS).save(os.path.join(SORTIE, "%s_%03d.png" % (nom, k)), optimize=True)
    with open(os.path.join(SORTIE, "animations.json"), "w", encoding="utf8") as f:
        json.dump({"taille": [largeur, HAUTEUR], "animations": infos}, f, ensure_ascii=False, indent=1)
    print("Boîte commune", boite, "->", largeur, "x", HAUTEUR, ";", {n: i["images"] for n, i in infos.items()})


if __name__ == "__main__":
    main()
