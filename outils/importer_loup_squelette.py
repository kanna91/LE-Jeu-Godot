"""Images fixes des nouvelles créatures (loup, squelette) pour le jeu : détourage puis cadrage comme les gobelins.

Sources : une image de Grok par créature dans ``C:\\ia image\\ennemis\\<créature>``. Le fond est retiré par BiRefNet
(module ``rembg``, comme Grok pour le Chevalier), le sol et l'ombre aussi, puis la créature est posée en bas d'un
cadre 1024 × 1536 (même format que les images des gobelins, ``images/gobelins``) : le jeu dessine le corps à 90 % de
la hauteur du cadre (``CombatAnime.PROPORTION_CORPS``), on règle donc sa taille par la part du cadre qu'elle occupe
(``HAUTEUR`` : un loup est plus bas qu'un gobelin debout).

Écrit ``images/gobelins/<nom>01.png`` et une planche de contrôle dans ``C:\\IA\\pont-blender\\creatures``.
Usage : ``python outils/importer_loup_squelette.py [créature...]`` (toutes sans argument) puis
``Godot --headless --path . --import``.

2026-11-06 : guerrier squelette, mage squelette, élémentaliste squelette et squelette invoqué (sous-dossiers de
``squelette``, images refaites par l'utilisateur).
"""
import glob
import os
import sys

from PIL import Image
from rembg import new_session, remove

SOURCE = r"C:\ia image\ennemis"
ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SORTIE = os.path.join(ICI, "images", "gobelins")
CONTROLE = r"C:\IA\pont-blender\creatures"
# Créature → (dossier, part de la hauteur du cadre occupée par son corps)
CREATURES = {"loup": ("loup", 0.62), "squelette": ("squelette", 0.92),
             "guerrier_squelette": (os.path.join("squelette", "guerrier squelette"), 0.92),
             "mage_squelette": (os.path.join("squelette", "mage squelette"), 0.92),
             "elementaliste_squelette": (os.path.join("squelette", "élémentaliste squelette"), 0.92),
             "squelette_invoque": (os.path.join("squelette", "squeltte invoqué"), 0.88)}
CADRE = (1024, 1536)


def main():
    choisies = {n: v for n, v in CREATURES.items() if len(sys.argv) < 2 or n in sys.argv[1:]}
    session = new_session("birefnet-general")
    os.makedirs(CONTROLE, exist_ok=True)
    planche = Image.new("RGBA", (CADRE[0] * len(choisies) // 2, CADRE[1] // 2), (60, 60, 70, 255))
    for i, (nom, (dossier, hauteur)) in enumerate(choisies.items()):
        src = sorted(glob.glob(os.path.join(SOURCE, dossier, "*.jpeg")) + glob.glob(os.path.join(SOURCE, dossier, "*.jpg")))[0]
        im = remove(Image.open(src).convert("RGB"), session=session, post_process_mask=True)
        # Alpha resserré : les pixels presque transparents (sol, halo) disparaissent
        a = im.getchannel("A").point(lambda v: 0 if v < 40 else v)
        im.putalpha(a)
        im = im.crop(a.getbbox())
        h_cible = round(CADRE[1] * 0.9 * hauteur)
        im = im.resize((round(im.width * h_cible / im.height), h_cible), Image.LANCZOS)
        if im.width > CADRE[0]:
            im = im.resize((CADRE[0], round(im.height * CADRE[0] / im.width)), Image.LANCZOS)
        cadre = Image.new("RGBA", CADRE, (0, 0, 0, 0))
        cadre.paste(im, ((CADRE[0] - im.width) // 2, CADRE[1] - im.height), im)
        chemin = os.path.join(SORTIE, "%s01.png" % nom)
        cadre.save(chemin)
        print("écrit :", chemin, im.size)
        petit = cadre.resize((CADRE[0] // 2, CADRE[1] // 2))
        planche.alpha_composite(petit, (i * CADRE[0] // 2, 0))
    planche.save(os.path.join(CONTROLE, "creatures.png"))


if __name__ == "__main__":
    main()
