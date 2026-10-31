r"""Importe dans le jeu les marches animées faites par Grok (images déjà détourées), 4 vues par personnage.

Personnages (``MARCHES``) : Chevalier de la mort, geôlier et, depuis le 2026-10-28, quatre gobelins (guerrier, archer,
chaman, féticheur : ``gobelin_<sorte>``, images de 256 px de haut, ``HAUTEURS``). Source : ``<dossier>\<vue>\frame_NNN.png`` (fond
transparent, pieds sur la même ligne, cellule identique pour les 4 vues) et ``frames.json``. Vues : dos, face, profil
(tourné vers la droite), trois_quarts (vers la droite) ; la gauche = miroir dans le moteur (profil et trois-quarts).
Sortie : ``images/pnj/<nom>_anim/<vue>_NNN.png``, recadrées sur une **même boîte** pour toutes les vues (les pieds ne
sautent pas d'une vue à l'autre), réduites à ``HAUTEUR`` pixels, et ``animations.json`` (taille, nombre d'images et
cadence par vue, et ``foulee``), lu par le jeu (``PresencesSalle.images_marche``).

**Foulée** (2026-10-27, pour que les pieds ne glissent plus) : Grok a stabilisé la marche sur place, donc dans la vue
de profil le pied posé au sol recule dans l'image à la vitesse où le personnage devrait avancer. On mesure ce recul
(décalage d'une image à l'autre de la bande des pieds, médiane) en hauteurs de corps par image. Le jeu fait avancer le
personnage de ``foulee`` × images/s hauteurs d'image (cadre affiché) par seconde, et fait défiler l'animation selon la distance.

Usage : ``python outils/importer_animations_marche.py [chevalier|geolier ...]`` (sans nom : tous), puis
``godot --headless --path . --import``. (Remplace ``importer_animations_chevalier.py``, qui l'appelle.)
"""
import json
import os
import statistics
import sys

import numpy as np
from PIL import Image

MARCHES = {
    "chevalier": r"C:\ia image\ennemis\chevalier de la mort\marche",
    "geolier": r"C:\ia image\ennemis\geollier\marche",
    # Gobelins (Grok, 2026-10-28 ; pas encore de sorcier). Nom « gobelin_<sorte> » (sorte de CombatAnime.TYPES).
    "gobelin_guerrier": r"C:\ia image\ennemis\gobelin\gobelin guerrier\marche",
    "gobelin_archer": r"C:\ia image\ennemis\gobelin\gobelin archer\marche",
    "gobelin_chaman": r"C:\ia image\ennemis\gobelin\gobelin chaman\marche",
    "gobelin_feticheur": r"C:\ia image\ennemis\gobelin\gobelin feticheur\marche",
}
# Les gobelins sont plus petits à l'écran : images moins hautes (mémoire).
HAUTEURS = {"gobelin_guerrier": 256, "gobelin_archer": 256, "gobelin_chaman": 256, "gobelin_feticheur": 256}
VUES = ["dos", "face", "profil", "trois_quarts"]
HAUTEUR = 360
ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def foulee(images_profil):
    """Pixels (de l'image source) parcourus par image : recul médian du pied posé dans la vue de profil."""
    alphas = [np.array(im.getchannel("A")) > 128 for im in images_profil]
    boites = [im.getchannel("A").getbbox() for im in images_profil]
    bas = int(statistics.median(b[3] for b in boites))
    haut = int(statistics.median(b[1] for b in boites))
    corps = bas - haut
    b0 = bas - int(corps * 0.04)
    largeur = alphas[0].shape[1]
    reculs = []
    for a, b in zip(alphas, alphas[1:]):
        p, q = a[b0:bas].sum(axis=0).astype(float), b[b0:bas].sum(axis=0).astype(float)
        meilleur = max(range(-40, 41), key=lambda s: (p[s:] * q[:largeur - s]).sum() if s >= 0 else (p[:largeur + s] * q[-s:]).sum())
        if meilleur > 0:
            reculs.append(meilleur)
    return statistics.median(reculs)


def importer(nom):
    source = MARCHES[nom]
    sortie = os.path.join(ICI, "images", "pnj", "%s_anim" % nom)
    hauteur = HAUTEURS.get(nom, HAUTEUR)
    os.makedirs(sortie, exist_ok=True)
    infos, images, boite = {}, {}, None
    for vue in VUES:
        dossier = os.path.join(source, vue)
        with open(os.path.join(dossier, "frames.json"), encoding="utf8") as f:
            meta = json.load(f)
        liste = [Image.open(os.path.join(dossier, "frame_%03d.png" % k)).convert("RGBA") for k in range(meta["frame_count"])]
        images[vue] = liste
        infos[vue] = {"images": len(liste), "fps": meta["fps"]}
        for im in liste:
            b = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
            if b:
                boite = b if boite is None else (min(boite[0], b[0]), min(boite[1], b[1]), max(boite[2], b[2]), max(boite[3], b[3]))
    largeur = round((boite[2] - boite[0]) * hauteur / (boite[3] - boite[1]))
    # Part de la boîte occupée par le personnage (médiane des silhouettes, arme comprise) : le jeu s'en sert pour
    # dessiner les gobelins à la même taille que leur image de combat
    hauts = sorted((b[3] - b[1]) for liste in images.values() for im in liste
                   for b in [im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()] if b)
    visible = hauts[len(hauts) // 2] / (boite[3] - boite[1])
    f = foulee(images["profil"]) / (boite[3] - boite[1])  # en hauteurs de l'image affichée (le jeu la dessine à hf)
    for vue, liste in images.items():
        for k, im in enumerate(liste):
            im.crop(boite).resize((largeur, hauteur), Image.LANCZOS).save(os.path.join(sortie, "%s_%03d.png" % (vue, k)), optimize=True)
    with open(os.path.join(sortie, "animations.json"), "w", encoding="utf8") as fichier:
        json.dump({"taille": [largeur, hauteur], "vues": infos, "fps": infos["profil"]["fps"], "foulee": round(f, 5),
                   "visible": round(visible, 4)},
                  fichier, ensure_ascii=False, indent=1)
    print(nom, ": boîte commune", boite, "->", largeur, "x", hauteur, "visible %.3f" % visible, "; foulée %.4f hauteur/image ;" % f,
          {v: i["images"] for v, i in infos.items()})


def main():
    for nom in sys.argv[1:] or list(MARCHES):
        importer(nom)


if __name__ == "__main__":
    main()
