"""Détoure la cuisinière (2026-11-04, image de l'utilisateur) et la copie dans le jeu.

Source : ``C:\\ia image\\ennemis\\cuisinière et commits\\cuisinière.jpeg`` (planche 768×512 : face à gauche, dos à
droite). On garde la vue de face (moitié gauche), détourée par rembg (modèle isnet-general-use, celui des commis),
recadrée, pieds en bas au milieu, HAUTEUR px de haut → ``images/pnj/cuisiniere.png``. Dans le jeu, image fixe qui
respire doucement (comme la succube).

    python outils/importer_cuisiniere.py
"""
import os

from PIL import Image
from rembg import new_session, remove

SOURCE = r"C:\ia image\ennemis\cuisinière et commits\cuisinière.jpeg"
SORTIE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "images", "pnj", "cuisiniere.png")
HAUTEUR = 400
## Vue de face : moitié gauche de la planche.
VUE_FACE = (0, 0, 400, 512)
## Morceaux isolés plus petits que ça (pixels) : miettes de fond, retirées.
MIETTES = 300


def main():
    im = Image.open(SOURCE).convert("RGB").crop(VUE_FACE)
    detoure = remove(im, session=new_session("isnet-general-use"), post_process_mask=True)
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
    h = HAUTEUR
    carre = carre.resize((round(carre.width * h / carre.height), h), Image.LANCZOS)
    carre.save(SORTIE, optimize=True)
    print("cuisinière :", carre.size, "->", SORTIE)


if __name__ == "__main__":
    main()
