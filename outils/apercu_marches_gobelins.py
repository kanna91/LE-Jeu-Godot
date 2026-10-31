r"""Aperçu des marches des gobelins faites par Grok (2026-10-28), AVANT de les brancher dans le jeu.

Source : ``C:\ia image\ennemis\gobelin\gobelin <sorte>\marche\<vue>\frame_NNN.png`` + ``frames.json`` (même format
que les marches du geôlier et du Chevalier). Prépare, avec le même traitement que ``importer_animations_marche.py``
(boîte commune aux 4 vues, hauteur réduite, foulée mesurée sur le profil), un dossier d'aperçu HORS du jeu :
``C:\IA\pont-blender\apercu_gobelins\<sorte>\<vue>_NNN.png`` + ``animations.json``. Rien n'est écrit dans ``godot/``.
La scène ``tests/voir_marches_gobelins.tscn`` (``voir_marches_gobelins.bat``) lit ce dossier.

Usage : ``python outils/apercu_marches_gobelins.py``
"""
import glob
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from importer_animations_marche import VUES, foulee  # noqa: E402

SOURCE = r"C:\ia image\ennemis\gobelin"
SORTIE = r"C:\IA\pont-blender\apercu_gobelins"
HAUTEUR = 300


def preparer(sorte, dossier):
    infos, images, boite = {}, {}, None
    for vue in VUES:
        d = os.path.join(dossier, vue)
        fichiers = sorted(glob.glob(os.path.join(d, "frame_*.png")))
        if not fichiers:
            continue
        fps = 12
        if os.path.exists(os.path.join(d, "frames.json")):
            fps = json.load(open(os.path.join(d, "frames.json"), encoding="utf8")).get("fps", 12)
        liste = [Image.open(f).convert("RGBA") for f in fichiers]
        images[vue] = liste
        infos[vue] = {"images": len(liste), "fps": fps}
        for im in liste:
            b = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
            if b:
                boite = b if boite is None else (min(boite[0], b[0]), min(boite[1], b[1]), max(boite[2], b[2]), max(boite[3], b[3]))
    if not images:
        return None
    largeur = round((boite[2] - boite[0]) * HAUTEUR / (boite[3] - boite[1]))
    f = foulee(images["profil"]) / (boite[3] - boite[1]) if "profil" in images else 0.012
    sortie = os.path.join(SORTIE, sorte)
    os.makedirs(sortie, exist_ok=True)
    for vieux in glob.glob(os.path.join(sortie, "*.png")):
        os.remove(vieux)
    for vue, liste in images.items():
        for k, im in enumerate(liste):
            im.crop(boite).resize((largeur, HAUTEUR), Image.LANCZOS).save(os.path.join(sortie, "%s_%03d.png" % (vue, k)))
    fps = infos.get("profil", next(iter(infos.values())))["fps"]
    with open(os.path.join(sortie, "animations.json"), "w", encoding="utf8") as fichier:
        json.dump({"taille": [largeur, HAUTEUR], "vues": infos, "fps": fps, "foulee": round(f, 5)}, fichier, indent=1)
    print(sorte, ":", {v: i["images"] for v, i in infos.items()}, "%s img/s, foulée %.4f" % (fps, f))
    return sorte


def main():
    sortes = []
    for dossier in sorted(glob.glob(os.path.join(SOURCE, "gobelin *", "marche"))):
        sorte = os.path.basename(os.path.dirname(dossier)).replace("gobelin ", "")
        if preparer(sorte, dossier):
            sortes.append(sorte)
    os.makedirs(SORTIE, exist_ok=True)
    with open(os.path.join(SORTIE, "sortes.json"), "w", encoding="utf8") as f:
        json.dump(sortes, f)
    print("Aperçu prêt :", SORTIE, sortes)


if __name__ == "__main__":
    main()
