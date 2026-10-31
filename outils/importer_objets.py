"""Copie dans le jeu les objets à poser dans les salles peintes (« C:\\ia image\\asset pour salle »).

    python outils/importer_objets.py

Pour chaque image de ``OBJETS`` : détourage du fond uni (JPEG), nettoyage des bords (damier gris et blanc incrusté par le générateur
d'images, halo clair autour des contours), recadrage sur l'objet, réduction à ``HAUTEUR_MAX`` px de haut,
puis ``images/objets_salles/<nom>.png`` (lu à l'exécution, pas importé par Godot). Les sources ne sont
pas modifiées. Où poser les objets : ``donnees/objets_salles.json`` (voir SallePeinte, « objets »).
Dépendances : opencv-python-headless, numpy, Pillow.
"""
import os

import cv2
import numpy as np
from PIL import Image

SOURCE = r"C:\ia image\asset pour salle"
ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SORTIE = os.path.join(ICI, "images", "objets_salles")
# nom dans le jeu : fichier source (JPEG sur fond uni, détouré ici ; 4 variantes par type).
# Coffres et étagères retirés le 2026-10-20 (ils juraient avec le décor peint) : seuls les squelettes restent.
OBJETS = {
    **{"squelette_%d" % i: ("squeltette 04.jpeg" if i == 4 else "squelette 0%d.jpeg" % i) for i in range(1, 5)},
}
# Squelettes sur fond noir : détourés par la luminosité (os clairs, fond noir), plus fiable.
CLE_LUMINANCE = {"squelette_4"}
HAUTEUR_MAX = 400
# Fond incrusté : pixels clairs et gris (damier, halo), reliés à la transparence.
CLAIR = 135
GRIS = 30


def nettoyer(rgba, damier=True):
    rgb = rgba[:, :, :3].astype(np.int32)
    alpha = rgba[:, :, 3].copy()
    lum = rgb.mean(axis=2)
    saturation = rgb.max(axis=2) - rgb.min(axis=2)
    # 1. Damier et halo clairs : on les retire s'ils touchent la transparence (pas l'intérieur de l'objet)
    candidat = ((lum > CLAIR) & (saturation < GRIS)) | (alpha < 250)
    nb, etiquettes = cv2.connectedComponents(candidat.astype(np.uint8), connectivity=8)
    exterieur = set(np.unique(etiquettes[alpha == 0])) - {0}
    fond = np.isin(etiquettes, list(exterieur)) & candidat
    if damier:  # (images PNG du générateur seulement : les os et les pierres claires y ressembleraient)
        alpha[fond & ((lum > CLAIR) & (saturation < GRIS))] = 0
    # 2. Bords semi-transparents : couleur reprise des pixels opaques voisins (plus de liseré clair),
    #    contour resserré d'un pixel
    opaque = (alpha >= 250).astype(np.uint8)
    couleurs = rgba[:, :, :3].copy()
    bord = (alpha > 0) & (alpha < 250)
    voisins = cv2.dilate(couleurs * opaque[:, :, None], np.ones((5, 5), np.uint8))
    poids = cv2.dilate(opaque * 255, np.ones((5, 5), np.uint8)) > 0
    remplacer = bord & poids
    couleurs[remplacer] = voisins[remplacer]
    alpha = cv2.erode(alpha, np.ones((3, 3), np.uint8))
    alpha = (alpha.astype(np.float32) / 255.0) ** 1.3 * 255.0
    return np.dstack([couleurs, alpha.astype(np.uint8)])


def detourer_par_luminance(rgb):
    """Objet clair sur fond noir : opacité selon la luminosité (lierre vert compris)."""
    lum = rgb.astype(np.float32).max(axis=2)
    alpha = np.clip((lum - 28.0) * 9.0, 0, 255)
    objet = (alpha > 0).astype(np.uint8)
    nb, etiquettes = cv2.connectedComponents(objet, connectivity=8)
    if nb > 1:
        tailles = np.bincount(etiquettes.ravel())[1:]
        garder = 1 + np.nonzero(tailles >= max(200, tailles.max() * 0.01))[0]
        alpha[~np.isin(etiquettes, garder)] = 0
    return np.dstack([rgb, alpha.astype(np.uint8)])


def detourer(rgb):
    """Fond uni (noir, gris ou blanc) → transparent.

    1. Remplissage depuis les bords de l'image (tolérance flottante : suit les dégradés du fond, s'arrête
       au contour de l'objet) ; 2. GrabCut d'OpenCV dans une bande autour de ce contour ; 3. les trous de
       la couleur du fond enfermés dans l'objet (entre les côtes) sont retirés, sur fond clair seulement
       (sur fond sombre, le bois et les ombres de l'objet lui ressemblent ; voir CLE_LUMINANCE).
    """
    h, w = rgb.shape[:2]
    bgr = np.ascontiguousarray(cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR))
    bord = np.concatenate([rgb[:3].reshape(-1, 3), rgb[-3:].reshape(-1, 3), rgb[:, :3].reshape(-1, 3), rgb[:, -3:].reshape(-1, 3)])
    couleur_fond = np.median(bord, axis=0)
    clair = couleur_fond.mean() > 170
    fond = np.zeros((h + 2, w + 2), np.uint8)
    tolerance = (5, 5, 5) if not clair else (7, 7, 7)
    graines = [(x, y) for x in range(0, w, 16) for y in (0, h - 1)] + [(x, y) for y in range(0, h, 16) for x in (0, w - 1)]
    for x, y in graines:
        if fond[y + 1, x + 1] == 0 and np.abs(rgb[y, x].astype(int) - couleur_fond).max() < 40:
            cv2.floodFill(bgr.copy(), fond, (x, y), 0, tolerance, tolerance, 4 | cv2.FLOODFILL_MASK_ONLY | (255 << 8))
    fond = fond[1:-1, 1:-1] > 0
    objet = (~fond).astype(np.uint8)
    # contour affiné par GrabCut dans une bande de quelques pixels
    m = np.where(objet == 1, cv2.GC_PR_FGD, cv2.GC_PR_BGD).astype(np.uint8)
    m[cv2.erode(objet, np.ones((9, 9), np.uint8)) == 1] = cv2.GC_FGD
    m[cv2.erode(1 - objet, np.ones((9, 9), np.uint8)) == 1] = cv2.GC_BGD
    cv2.grabCut(bgr, m, None, np.zeros((1, 65)), np.zeros((1, 65)), 4, cv2.GC_INIT_WITH_MASK)
    objet = ((m == cv2.GC_FGD) | (m == cv2.GC_PR_FGD)).astype(np.uint8)
    # trous enfermés de la couleur du fond (entre les côtes, entre les bras et les jambes)
    ecart = np.abs(rgb.astype(np.int32) - couleur_fond).max(axis=2)
    trous = ((ecart < 14) & (objet == 1)).astype(np.uint8)
    nb, etiquettes = cv2.connectedComponents(trous, connectivity=4)
    if clair and nb > 1:
        tailles = np.bincount(etiquettes.ravel())
        grands = np.nonzero(tailles >= 25)[0]
        objet[np.isin(etiquettes, grands[grands > 0])] = 0
    nb, etiquettes = cv2.connectedComponents(objet, connectivity=8)
    if nb > 1:  # miettes isolées retirées
        tailles = np.bincount(etiquettes.ravel())[1:]
        garder = 1 + np.nonzero(tailles >= max(300, tailles.max() * 0.01))[0]
        objet = np.isin(etiquettes, garder).astype(np.uint8)
    alpha = cv2.GaussianBlur(objet.astype(np.float32) * 255, (3, 3), 0)
    return np.dstack([rgb, alpha.clip(0, 255).astype(np.uint8)])


def importer(nom, fichier):
    source = Image.open(os.path.join(SOURCE, fichier))
    if nom in CLE_LUMINANCE:
        im = detourer_par_luminance(np.array(source.convert("RGB")))
    elif source.mode == "RGB":
        im = detourer(np.array(source))
    else:
        im = np.array(source.convert("RGBA"))
    propre = nettoyer(im, damier=source.mode != "RGB")
    ys, xs = np.nonzero(propre[:, :, 3] > 8)
    propre = propre[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    image = Image.fromarray(propre)
    if image.height > HAUTEUR_MAX:
        image = image.resize((round(image.width * HAUTEUR_MAX / image.height), HAUTEUR_MAX), Image.LANCZOS)
    os.makedirs(SORTIE, exist_ok=True)
    image.save(os.path.join(SORTIE, nom + ".png"), optimize=True)
    print(nom, image.size)


if __name__ == "__main__":
    os.makedirs(SORTIE, exist_ok=True)
    for ancien in os.listdir(SORTIE):  # images qui ne sont plus dans OBJETS (anciens assets)
        if ancien.endswith(".png") and ancien[:-4] not in OBJETS:
            os.remove(os.path.join(SORTIE, ancien))
    for nom, fichier in OBJETS.items():
        importer(nom, fichier)
    open(os.path.join(ICI, "images", "objets_salles", ".gdignore"), "w").close()
