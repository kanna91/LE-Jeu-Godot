"""Détourage au pixel du premier plan des salles peintes (piliers, murs, éboulis qui passent devant le héros).

Les polygones « premier_plan » d'une salle de test_salle sont grossiers (souvent des rectangles) : quand
le héros passe derrière, des morceaux de décor rectangulaires le coupent. Ce script affine chaque
polygone en masque au pixel sur une image de la vidéo de la salle (GrabCut d'OpenCV : le polygone sert
de départ, le contour suit les couleurs), puis l'installe au format de la salle 1 :

- « <dossier de salle>/masque_piliers.png » (une couleur unie par élément, 1088 × 720) et
  « piliers.json » (couleur et base de chaque élément, en pixels de l'image fixe 768 × 512) ;
- leurs copies miroir (« _miroir », comme ``test_salle/outils/creer_miroirs.py``) ;
- les clés « masque_piliers » et « piliers » du .json de test_salle et de son miroir.

Usage, depuis le dossier ``godot`` (après avoir retouché les polygones dans test_salle) :

    python outils/affiner_premier_plan.py porte1 porte3 culdesac2 ...
    python outils/importer_salles.py

Un élément que l'affinage perd (moins de 40 % de son polygone : élément fin, couleurs proches du fond)
garde son polygone. Un aperçu par salle est écrit dans ``tests/captures/premier_plan_<id>.png`` (masque
teinté, polygones d'origine en blanc) : le vérifier à l'œil.
Dépendances : opencv-python-headless, numpy, Pillow, imageio-ffmpeg.
"""
import json
import os
import subprocess
import sys

import cv2
import numpy as np
from PIL import Image

ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEST_SALLE = r"C:\ia image\Salle de donjon\test_salle"
sys.path.insert(0, os.path.join(TEST_SALLE, "outils"))
import creer_miroirs  # noqa: E402  (retournement des images et des piliers, json miroir)

COULEURS = ["#FF0000", "#00FF00", "#0000FF", "#FFFF00", "#FF00FF", "#00FFFF", "#FF8000", "#8000FF",
            "#0080FF", "#FF0080"]
# Marges de GrabCut (pixels de la vidéo) : bande autour du polygone où le contour peut aller, cœur sûr.
BANDE = 25
COEUR = 31
PART_MINIMALE = 0.4


def image_video(ident):
    """Une image (à 2 s) de la vidéo de la salle importée dans le jeu, en pleine résolution."""
    infos = json.load(open(os.path.join(ICI, "donnees", "salles_peintes", ident + ".json"), encoding="utf-8"))
    sortie = os.path.join(ICI, "tests", "captures", "_video_%s.png" % ident)
    import imageio_ffmpeg
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-loglevel", "error", "-ss", "2", "-i",
                    os.path.join(ICI, infos["decor_video"]), "-frames:v", "1", sortie], check=True)
    img = cv2.imread(sortie)
    os.remove(sortie)
    return img


def affiner(img, poly, kx, ky):
    """Masque (0/1) affiné d'un polygone (coordonnées de l'image fixe)."""
    hauteur, largeur = img.shape[:2]
    pts = np.array([[x * kx, y * ky] for x, y in poly], np.int32)
    zone = np.zeros((hauteur, largeur), np.uint8)
    cv2.fillPoly(zone, [pts], 1)
    m = np.full((hauteur, largeur), cv2.GC_BGD, np.uint8)
    bande = cv2.dilate(zone, np.ones((BANDE, BANDE), np.uint8))
    m[bande == 1] = cv2.GC_PR_BGD
    m[zone == 1] = cv2.GC_PR_FGD
    m[cv2.erode(zone, np.ones((COEUR, COEUR), np.uint8)) == 1] = cv2.GC_FGD
    x, y, w, h = cv2.boundingRect(bande)
    x0, y0, x1, y1 = max(0, x - 20), max(0, y - 20), min(largeur, x + w + 20), min(hauteur, y + h + 20)
    sous = m[y0:y1, x0:x1].copy()
    cv2.grabCut(img[y0:y1, x0:x1], sous, None, np.zeros((1, 65)), np.zeros((1, 65)), 6, cv2.GC_INIT_WITH_MASK)
    res = np.zeros((hauteur, largeur), np.uint8)
    res[y0:y1, x0:x1] = np.where((sous == cv2.GC_FGD) | (sous == cv2.GC_PR_FGD), 1, 0)
    nb, etiquettes = cv2.connectedComponents(res)
    if nb > 1:  # la plus grande partie d'un seul tenant
        tailles = [(etiquettes == i).sum() for i in range(1, nb)]
        res = (etiquettes == 1 + int(np.argmax(tailles))).astype(np.uint8)
    res = cv2.morphologyEx(res, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    if res.sum() < PART_MINIMALE * zone.sum():
        print("  affinage raté (%d %% du polygone) : polygone gardé" % (100 * res.sum() // max(1, zone.sum())))
        return zone
    return res


def dossier_de_salle(salle):
    """« salle porte 1 »... : dossier de l'image de fond (« ../salle porte 1/xxx.jpeg »)."""
    return os.path.basename(os.path.dirname(os.path.normpath(os.path.join(TEST_SALLE, salle["fond"]))))


def traiter(ident):
    fichier = os.path.join(TEST_SALLE, ident + ".json")
    salle = json.load(open(fichier, encoding="utf-8"))
    dossier = dossier_de_salle(salle)
    racine = os.path.join(TEST_SALLE, "..", dossier)
    img = image_video(ident)
    hauteur, largeur = img.shape[:2]
    largeur_fond, hauteur_fond = Image.open(os.path.normpath(os.path.join(TEST_SALLE, salle["fond"]))).size
    kx, ky = largeur / largeur_fond, hauteur / hauteur_fond
    masque = np.zeros((hauteur, largeur, 4), np.uint8)
    piliers = []
    for n, poly in enumerate(salle.get("premier_plan", [])):
        res = affiner(img, poly, kx, ky)
        couleur = COULEURS[n % len(COULEURS)]
        rgb = [int(couleur[i:i + 2], 16) for i in (1, 3, 5)]
        masque[(res == 1) & (masque[:, :, 3] == 0)] = rgb + [255]
        xs = [x for x, _ in poly]
        piliers.append({"couleur": couleur, "pilier": "premier_plan_%d" % n,
                        "base": {"x": round(sum(xs) / len(xs)), "y": max(y for _, y in poly)}})
    # Installation (format de la salle 1) et copies miroir
    Image.fromarray(masque).save(os.path.join(racine, "masque_piliers.png"))
    with open(os.path.join(racine, "piliers.json"), "w", encoding="utf-8") as f:
        json.dump(piliers, f, ensure_ascii=False, indent=1)
    creer_miroirs.retourner_image(os.path.join(racine, "masque_piliers.png"), os.path.join(racine, "masque_piliers_miroir.png"))
    with open(os.path.join(racine, "piliers_miroir.json"), "w", encoding="utf-8") as f:
        json.dump(creer_miroirs.miroir_piliers(json.loads(json.dumps(piliers)), largeur_fond), f, ensure_ascii=False, indent=1)
    salle["masque_piliers"] = "../%s/masque_piliers.png" % dossier
    salle["piliers"] = "../%s/piliers.json" % dossier
    with open(fichier, "w", encoding="utf-8") as f:
        f.write(json.dumps(salle, ensure_ascii=False, indent=1))
    ecrire_miroir(ident, salle)
    # Aperçu à vérifier
    apercu = img.copy()
    couche = img.copy()
    for p in piliers:
        c = p["couleur"]
        rgb = [int(c[i:i + 2], 16) for i in (1, 3, 5)]
        sel = np.all(masque[:, :, :3] == rgb, axis=2) & (masque[:, :, 3] > 0)
        couche[sel] = rgb[::-1]
    apercu = cv2.addWeighted(couche, 0.45, apercu, 0.55, 0)
    for poly in salle.get("premier_plan", []):
        cv2.polylines(apercu, [np.array([[x * kx, y * ky] for x, y in poly], np.int32)], True, (255, 255, 255), 1)
    cv2.imwrite(os.path.join(ICI, "tests", "captures", "premier_plan_%s.png" % ident), apercu)
    print(ident, ":", len(piliers), "éléments détourés")


def ecrire_miroir(ident, salle):
    """<id>_miroir.json mis à jour (zones, masque) sans retourner à nouveau le décor animé."""
    temporaire = os.path.join(TEST_SALLE, "_tmp_%s.json" % ident)
    d = dict(salle)
    decor = d.pop("decor_anime", None)
    with open(temporaire, "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False)
    creer_miroirs.salle_miroir(os.path.basename(temporaire), None)
    produit = os.path.splitext(temporaire)[0] + "_miroir.json"
    m = json.load(open(produit, encoding="utf-8"))
    os.remove(temporaire)
    os.remove(produit)
    if decor:
        m["decor_anime"] = decor + "_miroir"
    m["miroir_de"] = ident + ".json"
    chemin = os.path.join(TEST_SALLE, ident + "_miroir.json")
    if os.path.isfile(chemin):
        for cle, valeur in json.load(open(chemin, encoding="utf-8")).items():
            m.setdefault(cle, valeur)  # garder les clés propres à l'ancien miroir
    with open(chemin, "w", encoding="utf-8") as f:
        f.write(json.dumps(m, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    for ident in sys.argv[1:]:
        traiter(ident)
