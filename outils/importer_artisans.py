"""Détoure les artisans et leurs aides (2026-11-11, images de l'utilisateur) et les copie dans le jeu.

Sources : ``C:\\ia image\\ennemis\\<dossier>\\<fichier>`` (une personne en pied par image, fond blanc ou damier).
Chaque image est détourée par rembg (modèle isnet-general-use, celui de la cuisinière), recadrée, pieds en bas au
milieu, HAUTEUR px de haut → ``images/pnj/artisan_<role>.png``. Dans le jeu, image fixe qui respire doucement
(PresencesSalle, comme la cuisinière). Le forgeron a le rôle « armurier » (il le remplace, décision de l'utilisateur).

    python outils/importer_artisans.py            # toutes
    python outils/importer_artisans.py alchimiste # une seule
"""
import os
import sys

from PIL import Image
from rembg import new_session, remove

DOSSIER = r"C:\ia image\ennemis"
JEU = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SORTIE = os.path.join(JEU, "images", "pnj", "artisan_%s.png")
HAUTEUR = 400
## Morceaux isolés plus petits que ça (pixels) : miettes de fond, retirées.
MIETTES = 300
## Rôle → image source (choix de Claude d'après les dessins, validé par l'utilisateur pour la bibliothèque).
SOURCES = {
    "armurier": r"forgeron et apprentis\jaKYh.jpg",  # le forgeron (barbu, tablier de cuir)
    "apprenti_forgeron": r"forgeron et apprentis\iJuzJ.jpg",  # jeune, marteau
    "alchimiste": r"alchimiste et apprenti\3L5rZ.jpg",  # fiole verte, ceinture de flacons
    "apprenti_alchimiste": r"alchimiste et apprenti\jFCbF.jpg",  # jeune, mortier et pilon
    "bibliothecaire": r"mages et bibliothécaire et assistant\2Y4j9.jpg",  # robe claire, livre à deux mains
    "assistante": r"mages et bibliothécaire et assistant\I7eL4.jpg",  # jeune, livres et lanterne
    "enchanteur": r"mages et bibliothécaire et assistant\CGhsq(1).jpg",  # la mage : cape sombre, bâton
}


def detourer(role, session):
    im = Image.open(os.path.join(DOSSIER, SOURCES[role])).convert("RGB")
    detoure = remove(im, session=session, post_process_mask=True)
    alpha = detoure.getchannel("A")
    try:
        import numpy as np
        from scipy import ndimage
        a = np.array(alpha)
        etiquettes, n = ndimage.label(a > 32)
        tailles = ndimage.sum(np.ones_like(a), etiquettes, range(1, n + 1))
        for k, t in enumerate(tailles, start=1):
            if t < MIETTES:
                a[etiquettes == k] = 0
        detoure.putalpha(Image.fromarray(a))
    except ImportError:
        pass
    cadre = detoure.getchannel("A").point(lambda v: 255 if v > 32 else 0).getbbox()
    # Milieu des pieds : opaque des 8 % du bas
    bas = detoure.getchannel("A").crop((0, int(cadre[3] - 0.08 * (cadre[3] - cadre[1])), detoure.width, cadre[3]))
    b = bas.point(lambda v: 255 if v > 32 else 0).getbbox()
    milieu = (b[0] + b[2]) // 2 if b else (cadre[0] + cadre[2]) // 2
    demi = max(milieu - cadre[0], cadre[2] - milieu) + 2
    carre = Image.new("RGBA", (2 * demi, cadre[3] - cadre[1]), (0, 0, 0, 0))
    carre.paste(detoure.crop((milieu - demi, cadre[1], milieu + demi, cadre[3])), (0, 0))
    carre = carre.resize((round(carre.width * HAUTEUR / carre.height), HAUTEUR), Image.LANCZOS)
    carre.save(SORTIE % role, optimize=True)
    print(role, carre.size, "->", SORTIE % role)


def main():
    roles = sys.argv[1:] or list(SOURCES)
    session = new_session("isnet-general-use")
    for role in roles:
        detourer(role, session)


if __name__ == "__main__":
    main()
