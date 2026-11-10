"""Détourer une salle « comme à la main » (méthode tirée des couloirs aux livres retouchés par l'utilisateur).

La méthode de l'utilisateur (couloir_livre05 à 27, 2026-11-06), appliquée ici en 3 étapes :
  1. Sol : un seul grand contour simple (10 à 25 points) qui couvre tout le sol visible, pieds des piliers et
     petits débris compris, sans trous ; il descend jusqu'au bas de l'image.
     -> on part du sol détouré automatiquement, on bouche ses trous et ses creux (fermeture), on lisse et on
        simplifie le contour.
  2. Sorties : posées sur le vrai passage peint (haut d'un escalier, arche du fond, ouverture de côté), pas sur
     une bande au bord du sol. Seule la sortie « retour » (bas) ne bouge pas.
  3. Chemin : le sol est prolongé jusqu'à chaque sortie déplacée (marches d'un escalier, allée vers l'arche).
     -> par défaut, l'enveloppe entre le bas de la sortie et le haut du sol en dessous ; on peut aussi donner le
        chemin à la main.

Le choix des sorties demande de regarder l'image : c'est la part « à l'œil » (faite par Claude ou l'utilisateur),
le reste est automatique.

Commandes (``python outils/detourer_comme_main.py <commande> ...``) :
  regler                          compare le sol simplifié aux salles faites à la main (score par salle)
  voir <salle> [fichier.json]     image avant / après dans C:\\IA\\pont-blender\\zones\\<salle>_main.png
  appliquer <salle> [fichier.json] écrit la salle (données du jeu + zones_manuelles, historique pour annuler :
                                  python outils/zones.py annuler <salle>)

Le fichier .json (facultatif) décrit les sorties à déplacer :
  {"sorties": {"0": [[x,y],[x,y],[x,y],[x,y]], ...},      n° de sortie -> nouveau polygone
   "chemins": {"0": [[x,y], ...]},                         facultatif : chemin tracé à la main pour cette sortie
   "sans_chemin": ["1"],                                   facultatif : ne pas prolonger le sol vers ces sorties
   "ajouts_sol": [[[x,y], ...]],                           facultatif : morceaux de sol en plus
   "retraits_sol": [[[x,y], ...]]}                         facultatif : morceaux à retirer du sol (un mur...)
"""
import json
import os
import subprocess
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zones  # noqa: E402  (mêmes fichiers et même historique que l'outil en ligne de commande)

L, H = 768, 512
FERMETURE = 61      # taille (px) des creux bouchés dans le sol (pieds de piliers, débris)
LISSAGE = 9         # flou du bord avant simplification
TOLERANCE = 0.006   # simplification du contour (part du périmètre)
SURFACE_MINI = 1500  # morceaux de sol plus petits : ignorés
BAS_PLEIN = 450     # sous cette ligne, le sol va d'un bord à l'autre de l'image (comme les salles faites main)
# Salles faites à la main par l'utilisateur, qui servent de modèle (commande regler).
MODELES = ["couloir_livre%02d" % i for i in (5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 21, 23, 24, 25, 26, 27)]
COMMIT_AUTO = "a5b8f21"  # import des couloirs aux livres, zones encore automatiques


def masque(polys):
    m = np.zeros((H, L), np.uint8)
    for p in polys:
        if len(p) >= 3:
            cv2.fillPoly(m, [np.array(p, np.int32)], 255)
    return m


def remplir_rangees(m, part=0.0):
    """Chaque rangée remplie d'un bord à l'autre du sol (l'utilisateur couvre coins sombres et pieds de piliers)."""
    sortie = m.copy()
    for y in range(H):
        xs = np.nonzero(m[y])[0]
        if len(xs) > part * L:
            sortie[y, xs[0]:xs[-1] + 1] = 255
    return sortie


def sol_simplifie(marche, fermeture=FERMETURE, rangees=True, bas_plein=BAS_PLEIN):
    """Le sol automatique (détaillé, troué) -> un contour simple à la façon de l'utilisateur."""
    m = masque(marche)
    if rangees:
        m = remplir_rangees(m)
    m[H - 14:, :] = np.maximum(m[H - 14:, :], m[H - 30:H - 16, :].max(axis=0))  # jusqu'au bas de l'image
    if bas_plein:
        m[bas_plein:, :] = 255
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (fermeture, fermeture))
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, k)
    m = cv2.GaussianBlur(m, (LISSAGE, LISSAGE), 0)
    m = np.where(m > 127, 255, 0).astype(np.uint8)
    contours, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)  # externes : sans trous
    sortie = []
    for c in sorted(contours, key=cv2.contourArea, reverse=True):
        if cv2.contourArea(c) < SURFACE_MINI:
            continue
        a = cv2.approxPolyDP(c, TOLERANCE * cv2.arcLength(c, True), True)
        pts = [[int(min(max(x, 0), L - 1)), int(min(max(y, 0), H - 1))] for [[x, y]] in a]
        # les points posés à 1-2 px d'un bord de l'image vont sur le bord (comme dans l'éditeur)
        pts = [[0 if x <= 2 else (L - 1 if x >= L - 3 else x), H - 1 if y >= H - 3 else y] for x, y in pts]
        sortie.append(pts)
    return sortie


def chemin_auto(sortie, sol):
    """Enveloppe entre le bas de la sortie et le haut du sol juste en dessous (marches, allée)."""
    s = np.array(sortie)
    bas = s[s[:, 1] >= np.median(s[:, 1])]          # bord bas de la sortie
    x0, x1 = int(bas[:, 0].min()), int(bas[:, 0].max())
    y_bas = int(bas[:, 1].max())
    m = masque(sol)
    pts = [p.tolist() for p in bas]
    for x in (x0, (x0 + x1) // 2, x1):
        col = np.nonzero(m[y_bas:, min(max(x, 0), L - 1)])[0]
        if len(col):
            pts.append([x, y_bas + int(col[0]) + 6])     # un peu dans le sol, pour bien les relier
    if len(pts) < 3:
        return None
    hull = cv2.convexHull(np.array(pts, np.int32))
    return [[int(x), int(y)] for [[x, y]] in hull]


def construire(info, reglage):
    sol = sol_simplifie(info["marche"])
    sorties = [list(map(list, p)) for p in info["sorties"]]
    for i, poly in reglage.get("sorties", {}).items():
        sorties[int(i)] = poly
    ajouts = list(reglage.get("ajouts_sol", []))
    for i in reglage.get("sorties", {}):
        if i in reglage.get("sans_chemin", []):
            continue
        ch = reglage.get("chemins", {}).get(i) or chemin_auto(sorties[int(i)], sol)
        if ch:
            ajouts.append(ch)
            ajouts.append(sorties[int(i)])  # le héros doit pouvoir entrer dans la sortie
    if ajouts or reglage.get("retraits_sol"):
        m = masque(sol)
        m = cv2.bitwise_or(m, masque(ajouts))
        m = cv2.bitwise_and(m, cv2.bitwise_not(masque(reglage.get("retraits_sol", []))))
        contours, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
        sol = []
        for c in sorted(contours, key=cv2.contourArea, reverse=True):
            if cv2.contourArea(c) >= SURFACE_MINI:
                a = cv2.approxPolyDP(c, 1.5, True)  # déjà simple : on garde la forme
                sol.append([[int(x), int(y)] for [[x, y]] in a])
    return sol, sorties


def lire_reglage(chemin):
    if not chemin:
        return {}
    return json.load(open(chemin, encoding="utf8"))


def dessiner(info, sol, sorties, titre):
    im = Image.open(os.path.join(zones.ICI, info["fond"])).convert("RGBA").resize((L, H))
    ov = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    for p in sol:
        d.polygon([tuple(x) for x in p], fill=(60, 255, 90, 70), outline=(60, 255, 90, 255))
    for i, p in enumerate(sorties):
        d.polygon([tuple(x) for x in p], fill=(255, 225, 40, 110), outline=(255, 225, 40, 255))
        d.text(tuple(p[0]), str(i), fill=(255, 255, 255, 255))
    for x in range(0, L, 64):
        d.line([(x, 0), (x, H)], fill=(255, 255, 255, 40))
        d.text((x + 2, 2), str(x), fill=(255, 255, 255, 200))
    for y in range(0, H, 64):
        d.line([(0, y), (L, y)], fill=(255, 255, 255, 40))
        d.text((2, y + 2), str(y), fill=(255, 255, 255, 200))
    im = Image.alpha_composite(im, ov).convert("RGB")
    ImageDraw.Draw(im).text((300, 4), titre, fill=(255, 255, 255))
    return im


def voir(salle, reglage_chemin=None):
    info = zones.lire(salle)
    sol, sorties = construire(info, lire_reglage(reglage_chemin))
    avant = dessiner(info, info["marche"], info["sorties"], salle + " : avant")
    apres = dessiner(info, sol, sorties, salle + " : après (%s points)" % [len(p) for p in sol])
    planche = Image.new("RGB", (L, 2 * H))
    planche.paste(avant, (0, 0))
    planche.paste(apres, (0, H))
    os.makedirs(zones.IMAGES, exist_ok=True)
    chemin = os.path.join(zones.IMAGES, salle + "_main.png")
    planche.save(chemin)
    print(chemin)


def appliquer(salle, reglage_chemin=None):
    """Écrit comme zones.py (historique pour annuler), sans son garde-fou « point hors de l'image » : la sortie
    « retour » dépasse volontairement sous l'image (y = 517). On vérifie seulement ce qu'on a changé."""
    info = zones.lire(salle)
    avant = json.loads(json.dumps({c: info.get(c, []) for c in zones.COUCHES}))
    sol, sorties = construire(info, lire_reglage(reglage_chemin))
    for i, poly in list(enumerate(sol)) + [(i, sorties[int(i)]) for i in lire_reglage(reglage_chemin).get("sorties", {})]:
        if len(poly) < 3 or any(not (0 <= x <= L and 0 <= y <= H) for x, y in poly):
            zones.erreur("zone %s incorrecte (moins de 3 points ou hors de l'image) : rien n'est changé" % i)
    if len(sorties) != len(avant["sorties"]):
        zones.erreur("le nombre de sorties ne peut pas changer : rien n'est changé")
    info["marche"] = sol
    info["sorties"] = sorties
    zones.ecrire(salle, info, avant)
    print("OK : %s enregistrée (%d zone(s) de sol, %s points)" % (salle, len(sol), [len(p) for p in sol]))


def regler():
    """Score (recouvrement, 1 = identique) du sol simplifié face au sol tracé à la main, hors chemins."""
    # Mesuré le 2026-11-06 : 0,792 sans remplissage (fermeture 31) ; 0,823 avec les réglages actuels.
    for fermeture, rangees, bas in ((31, False, None), (FERMETURE, True, BAS_PLEIN)):
        scores = []
        for s in MODELES:
            rel = "donnees/salles_peintes/%s.json" % s
            brut = subprocess.run(["git", "show", "%s:godot/%s" % (COMMIT_AUTO, rel)], cwd=zones.ICI,
                                  capture_output=True, text=True, encoding="utf8").stdout
            auto = json.loads(brut)
            main = json.load(open(os.path.join(zones.ICI, rel), encoding="utf8"))
            a = masque(sol_simplifie(auto["marche"], fermeture, rangees, bas)) > 0
            b = masque(main["marche"]) > 0
            zone = np.zeros_like(a)
            zone[int(min(p[1] for p in sum(auto["marche"], []))):, :] = True  # sans les chemins (escaliers)
            a, b = a & zone, b & zone
            scores.append((a & b).sum() / max((a | b).sum(), 1))
        print("rangées %d, fermeture %2d, bas plein %s : moyenne %.3f  (pire %.3f)" % (rangees, fermeture, bas, np.mean(scores), min(scores)))


def main():
    a = sys.argv[1:]
    if a[:1] == ["regler"]:
        regler()
    elif a[:1] == ["voir"] and len(a) in (2, 3):
        voir(a[1], a[2] if len(a) == 3 else None)
    elif a[:1] == ["appliquer"] and len(a) in (2, 3):
        appliquer(a[1], a[2] if len(a) == 3 else None)
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
