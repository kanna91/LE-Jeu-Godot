"""Détourage automatique du sol de chaque salle peinte (zone où le héros peut marcher).

Demande de l'utilisateur (2026-10-27) : les zones de marche tracées à la main étaient « abominables » : on ne
comprenait pas où l'on pouvait aller. Méthode :
1. **profondeur** : Depth Anything V2 (modèle en cache) donne une profondeur inverse relative de chaque pixel ;
2. **plan du sol** : pour un sol plat, la profondeur inverse est une fonction affine des coordonnées de l'image
   (d = a·x + b·y + c). On l'ajuste (RANSAC) sur le bas de l'image, puis le sol = les pixels qui suivent ce plan,
   reliés au bas de l'image. Tout ce qui se dresse (piliers, marches, braseros, murs, gravats) s'en écarte ;
3. **nettoyage** : petits trous bouchés, bords lissés, puis contours → polygones « marche » ; les trous restants
   dans le sol (bases de piliers, braseros posés au sol) → « obstacles » ;
4. les **sorties** restent atteignables : chaque zone de sortie est reliée au sol (couloir) si besoin.

Résultats : ``outils/detourage/<id>.json`` ({"marche": [...], "obstacles": [...]}, pixels de l'image 768 × 512), lus par
``importer_salles.py`` et ``importer_grandes_salles.py`` (ils remplacent les zones tracées à la main) et appliqués
tout de suite aux ``donnees/salles_peintes/<id>.json``. Planche de contrôle : ``C:\\IA\\pont-blender\\detourage_salles\\planche.png``.

Usage : ``python outils/detourer_sols.py [id ...]`` (toutes les salles sans argument). Réglages par salle : REGLAGES.
"""
import glob
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw

ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DONNEES = os.path.join(ICI, "donnees", "salles_peintes")
SORTIE = os.path.join(ICI, "outils", "detourage")
# Zones retouchées à la main dans l'éditeur du jeu (scenes/outils/editeur_zones.tscn) : elles passent avant tout calcul.
MANUELLES = os.path.join(ICI, "outils", "zones_manuelles")
TRAVAIL = r"C:\IA\pont-blender\detourage_salles"
LARGEUR, HAUTEUR = 768, 512

# Réglages par salle (sinon DEFAUT) : hauteur (en pixels de l'image) au-dessus du sol au-delà de laquelle un pixel
# n'est plus du sol, bande du bas où l'on ajuste la surface du sol, trous bouchés en dessous de cette aire (pixels).
DEFAUT = {"hauteur": 5.0, "bande": 0.25, "trou": 120, "vote": 0.6, "dresse": 8.0, "tours": 3, "plat": 12.0,
          "entoure": 0.66}
# « ajouts » : zones de sol ajoutées à la main (polygones de l'image) là où la profondeur se trompe.
REGLAGES = {
    "culdesac1": {"ajouts": [[(285, 322), (472, 322), (560, 372), (570, 386), (140, 386), (170, 372)]]},  # dalles du fond
    "grande10": {"ajouts": [[(300, 333), (472, 333), (520, 376), (268, 378)]]},  # allée dallée du fond
    "grande3": {"ajouts": [[(448, 330), (545, 330), (575, 362), (505, 402), (412, 402)]]},  # chemin vers la brume
}


def profondeur(ids):
    """Profondeur inverse (Depth Anything V2 Large) de chaque fond, en cache dans TRAVAIL/<id>/profondeur.npy."""
    a_faire = [i for i in ids if not os.path.exists(os.path.join(TRAVAIL, i, "profondeur.npy"))]
    if not a_faire:
        return
    import torch
    from transformers import AutoImageProcessor, AutoModelForDepthEstimation
    nom = "depth-anything/Depth-Anything-V2-Large-hf"
    pr = AutoImageProcessor.from_pretrained(nom)
    md = AutoModelForDepthEstimation.from_pretrained(nom).to("cuda").eval()
    for i in a_faire:
        d = json.load(open(os.path.join(DONNEES, i + ".json"), encoding="utf8"))
        im = Image.open(os.path.join(ICI, d["fond"])).convert("RGB")
        # Image agrandie ×2 pour plus de détail sur les bords
        grand = im.resize((LARGEUR * 2, HAUTEUR * 2), Image.LANCZOS)
        entree = pr(grand, return_tensors="pt", size={"height": 1022, "width": 1526}, keep_aspect_ratio=False,
                    ensure_multiple_of=14)
        with torch.no_grad():
            p = md(**{k: v.to("cuda") for k, v in entree.items()}).predicted_depth
        p = torch.nn.functional.interpolate(p[None], size=(HAUTEUR, LARGEUR), mode="bicubic")[0, 0].cpu().numpy()
        os.makedirs(os.path.join(TRAVAIL, i), exist_ok=True)
        np.save(os.path.join(TRAVAIL, i, "profondeur.npy"), p)
        v = (p - p.min()) / (p.max() - p.min())
        Image.fromarray((v * 255).astype(np.uint8)).save(os.path.join(TRAVAIL, i, "profondeur.png"))


def _base(xs, ys):
    """Surface du sol : d = a·x + b·y + c + e·y² (le terme en y² absorbe les écarts du modèle de profondeur)."""
    return np.stack([xs, ys, np.ones_like(xs), ys * ys / 512.0], -1)


def surface_du_sol(d, reglage, graine=0):
    """RANSAC sur la bande du bas : écart mesuré en pixels de hauteur au-dessus du sol (écart / pente verticale)."""
    rng = np.random.default_rng(graine)
    h, w = d.shape
    y0 = int(h * (1 - reglage["bande"]))
    ys, xs = np.mgrid[y0:h:2, 0:w:2]
    xs, ys = xs.ravel().astype(float), ys.ravel().astype(float)
    vs = d[ys.astype(int), xs.astype(int)]
    A = _base(xs, ys)
    def ecart(coef):
        pente = coef[1] + 2 * coef[3] * ys / 512.0
        return np.abs(A @ coef - vs) / np.maximum(np.abs(pente), 1e-6)
    meilleur, meilleur_n = None, -1
    for _ in range(600):
        k = rng.choice(len(xs), 4, replace=False)
        try:
            coef = np.linalg.solve(A[k], vs[k])
        except np.linalg.LinAlgError:
            continue
        if coef[1] <= 0:
            continue
        n = int((ecart(coef) < reglage["hauteur"]).sum())
        if n > meilleur_n:
            meilleur, meilleur_n = coef, n
    for _ in range(3):
        ok = ecart(meilleur) < reglage["hauteur"]
        meilleur, *_ = np.linalg.lstsq(A[ok], vs[ok], rcond=None)
    return meilleur


def masque_sol(d, reglage):
    h, w = d.shape
    coef = surface_du_sol(d, reglage)
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    base = _base(xs, ys)
    # Réajustements successifs sur tout le sol trouvé (relié au bas) : la surface suit le sol jusqu'au fond
    for tour in range(reglage["tours"] + 1):
        attendu = base @ coef
        pente = coef[1] + 2 * coef[3] * ys / 512.0
        hauteur = (d - attendu) / np.maximum(pente, 1e-6)  # > 0 : plus près que le sol (ça se dresse)
        sol = (np.abs(hauteur) < reglage["hauteur"]) & (pente > 0)
        m = sol.astype(np.uint8) * 255
        m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
        m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
        # Garder ce qui touche le bas de l'image
        n, lab = cv2.connectedComponents(m)
        garder = set(np.unique(lab[h - 3:, :])) - {0}
        m = np.isin(lab, list(garder)).astype(np.uint8) * 255
        if tour < reglage["tours"]:
            ok = m[::2, ::2] > 0
            A = base[::2, ::2][ok]
            coef, *_ = np.linalg.lstsq(A, d[::2, ::2][ok], rcond=None)
    # Boucher les petits trous (taches du tapis, dalles) : seuls les vrais objets restent des obstacles
    inv = 255 - m
    n, lab, stats, _ = cv2.connectedComponentsWithStats(inv)
    for k in range(1, n):
        x, y, ww, hh, aire = stats[k]
        bord = x == 0 or y == 0 or x + ww >= w or y + hh >= h
        if not bord and aire < reglage["trou"]:
            m[lab == k] = 255
    return m, hauteur


def segments_sam(ids):
    """Découpe automatique SAM (vit-huge, « tout segmenter ») de chaque fond, en cache dans TRAVAIL/<id>/segments.npz."""
    a_faire = [i for i in ids if not os.path.exists(os.path.join(TRAVAIL, i, "segments.npz"))]
    if not a_faire:
        return
    from transformers import pipeline
    gen = pipeline("mask-generation", model="facebook/sam-vit-huge", device=0)
    for i in a_faire:
        info = json.load(open(os.path.join(DONNEES, i + ".json"), encoding="utf8"))
        im = Image.open(os.path.join(ICI, info["fond"])).convert("RGB")
        sortie = gen(im, points_per_batch=64, pred_iou_thresh=0.8, stability_score_thresh=0.85)
        masques = np.stack([np.asarray(m, dtype=bool) for m in sortie["masks"]]) if sortie["masks"] else np.zeros((0, HAUTEUR, LARGEUR), bool)
        np.savez_compressed(os.path.join(TRAVAIL, i, "segments.npz"), masques=masques)
        print("%-10s %d segments" % (i, len(masques)))


def voter(sol_profondeur, masques, seuil):
    """Chaque pixel prend la décision du plus petit segment SAM qui le contient : sol si la majorité (``seuil``) du
    segment suit le plan du sol. Pixels hors de tout segment : la profondeur décide."""
    ref = sol_profondeur > 0
    res = ref.copy()
    aires = masques.reshape(len(masques), -1).sum(1)
    for k in np.argsort(-aires):  # du plus grand au plus petit : le plus petit l'emporte
        m = masques[k]
        if aires[k] < 30:
            continue
        res[m] = ref[m].mean() >= seuil
    return res.astype(np.uint8) * 255


def recuperer_plats(m, masques, hauteur, plat, entoure):
    """Morceaux SAM exclus mais presque à plat (hauteur médiane < ``plat`` px) et entourés de sol (part de leur
    bordure sur le sol >= ``entoure``) : tapis, dalles claires, flaques de lumière. Ils redeviennent du sol."""
    for _ in range(2):
        for k in range(len(masques)):
            seg = masques[k]
            if seg.sum() < 30 or (m[seg] > 0).mean() > 0.5:
                continue
            anneau = (cv2.dilate(seg.astype(np.uint8), np.ones((7, 7), np.uint8)) > 0) & ~seg
            if anneau.sum() == 0:
                continue
            if (m[anneau] > 0).mean() >= entoure and np.median(np.abs(hauteur[seg])) < plat:
                m[seg] = 255
    return m


def nettoyer(m, trou, hauteur, dresse):
    """Garde le sol relié au bas de l'image ; bouche les trous intérieurs, sauf ceux qui se dressent vraiment
    (hauteur médiane au-dessus du sol > ``dresse`` pixels) et assez grands (> ``trou`` pixels) : vrais obstacles."""
    h, w = m.shape
    m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    n, lab = cv2.connectedComponents(m)
    garder = set(np.unique(lab[h - 3:, :])) - {0}
    m = np.isin(lab, list(garder)).astype(np.uint8) * 255
    inv = 255 - m
    n, lab, stats, _ = cv2.connectedComponentsWithStats(inv)
    for k in range(1, n):
        x, y, ww, hh, aire = stats[k]
        if x == 0 or y == 0 or x + ww >= w or y + hh >= h:
            continue
        if aire < trou or np.median(hauteur[lab == k]) < dresse:
            m[lab == k] = 255
    return m


def relier_sorties(m, info):
    """Chaque sortie (sauf le bas, que le sol touche toujours) devient du sol, reliée au cœur du sol (sol rogné de
    10 pixels : assez large pour le héros) par un passage aussi large que 60 % de la sortie (18 pixels au moins)."""
    coeur = cv2.erode(m, np.ones((21, 21), np.uint8))
    ys, xs = np.nonzero(coeur if coeur.any() else m)
    for k, poly in enumerate(info["sorties"]):
        if info.get("directions_sorties", [""] * 99)[k] == "bas":
            continue
        pts = np.array(poly, np.int32)
        zone = np.zeros_like(m)
        cv2.fillPoly(zone, [pts], 255)
        m |= cv2.dilate(zone, np.ones((7, 7), np.uint8))
        if len(xs) == 0:
            continue
        c = pts.mean(0)
        j = int(np.argmin((xs - c[0]) ** 2 + ((ys - c[1]) * 1.5) ** 2))
        largeur = max(18, int(abs(pts[:, 0].max() - pts[:, 0].min()) * 0.6))
        cv2.line(m, (int(c[0]), int(c[1])), (int(xs[j]), int(ys[j])), 255, largeur)
    return m


def polygones(m, mini=60):
    """Contours extérieurs → marche, trous → obstacles (pixels de l'image)."""
    cs, hier = cv2.findContours(m, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_SIMPLE)
    marche, obstacles = [], []
    if hier is None:
        return marche, obstacles
    for k, c in enumerate(cs):
        if cv2.contourArea(c) < mini:
            continue
        c = cv2.approxPolyDP(c, 1.5, True)[:, 0, :].tolist()
        if len(c) < 3:
            continue
        (marche if hier[0][k][3] < 0 else obstacles).append(c)
    return marche, obstacles


def planche(ids, resultats, nom="planche.png"):
    cases = []
    for i in ids:
        d = json.load(open(os.path.join(DONNEES, i + ".json"), encoding="utf8"))
        im = Image.open(os.path.join(ICI, d["fond"])).convert("RGBA")
        cal = Image.new("RGBA", im.size)
        dr = ImageDraw.Draw(cal)
        marche, obstacles = resultats[i]
        for p in marche:
            dr.polygon([tuple(q) for q in p], fill=(0, 255, 0, 75), outline=(0, 255, 0, 255))
        for p in obstacles:
            dr.polygon([tuple(q) for q in p], fill=(255, 0, 0, 140))
        for p in d["sorties"]:
            dr.polygon([tuple(q) for q in p], fill=(255, 220, 0, 160))
        im = Image.alpha_composite(im, cal)
        ImageDraw.Draw(im).text((5, 5), i, fill=(255, 255, 0, 255))
        # Contrôle en pleine taille (×2) : TRAVAIL/controle/<id>.png
        os.makedirs(os.path.join(TRAVAIL, "controle"), exist_ok=True)
        im.convert("RGB").resize((LARGEUR * 2, HAUTEUR * 2), Image.LANCZOS).save(os.path.join(TRAVAIL, "controle", i + ".png"))
        cases.append(im.convert("RGB").resize((384, 256)))
    col = 5
    pl = Image.new("RGB", (384 * col, 256 * ((len(cases) + col - 1) // col)))
    for k, c in enumerate(cases):
        pl.paste(c, ((k % col) * 384, (k // col) * 256))
    pl.save(os.path.join(TRAVAIL, nom))


def main():
    ids = sys.argv[1:] or sorted(os.path.basename(f)[:-5] for f in glob.glob(os.path.join(DONNEES, "*.json")))
    os.makedirs(TRAVAIL, exist_ok=True)
    profondeur(ids)
    segments_sam(ids)
    resultats = {}
    for i in ids:
        reglage = {**DEFAUT, **REGLAGES.get(i, {})}
        d = np.load(os.path.join(TRAVAIL, i, "profondeur.npy"))
        brut, hauteur = masque_sol(d, {**reglage, "trou": 0})
        Image.fromarray(brut).save(os.path.join(TRAVAIL, i, "sol_profondeur.png"))
        masques = np.load(os.path.join(TRAVAIL, i, "segments.npz"))["masques"]
        info = json.load(open(os.path.join(DONNEES, i + ".json"), encoding="utf8"))
        m = voter(brut, masques, reglage["vote"])
        m = recuperer_plats(m, masques, hauteur, reglage["plat"], reglage["entoure"])
        m = nettoyer(m, reglage["trou"], hauteur, reglage["dresse"])
        for poly in reglage.get("ajouts", []):
            cv2.fillPoly(m, [np.array(poly, np.int32)], 255)
        m = relier_sorties(m, info)
        Image.fromarray(m).save(os.path.join(TRAVAIL, i, "sol.png"))
        resultats[i] = polygones(m)
    planche(ids, resultats)
    appliquer(resultats)
    print("ok", len(ids))


def appliquer(resultats):
    """Écrit ``outils/detourage/<id>.json`` et remplace « marche » et « obstacles » dans les données du jeu (les zones
    tracées à la main sont gardées une fois dans ``outils/detourage/ancien/<id>.json``)."""
    os.makedirs(os.path.join(SORTIE, "ancien"), exist_ok=True)
    for i, (marche, obstacles) in resultats.items():
        chemin = os.path.join(DONNEES, i + ".json")
        info = json.load(open(chemin, encoding="utf8"))
        ancien = os.path.join(SORTIE, "ancien", i + ".json")
        if not os.path.exists(ancien):
            with open(ancien, "w", encoding="utf8") as f:
                json.dump({"marche": info["marche"], "obstacles": info["obstacles"]}, f)
        with open(os.path.join(SORTIE, i + ".json"), "w", encoding="utf8") as f:
            json.dump({"marche": marche, "obstacles": obstacles}, f)
        info["marche"], info["obstacles"] = marche, obstacles
        info.update(zones_manuelles(i))
        with open(chemin, "w", encoding="utf8") as f:
            json.dump(info, f, ensure_ascii=False, indent=1)


def zones_manuelles(ident):
    """Zones de la salle ``ident`` retouchées dans l'éditeur du jeu (``outils/zones_manuelles/<id>.json``), ou {}."""
    chemin = os.path.join(MANUELLES, ident + ".json")
    return json.load(open(chemin, encoding="utf8")) if os.path.exists(chemin) else {}


def detourage(ident):
    """Zones détourées de la salle ``ident`` (vide si elle n'a pas été détourée), puis les zones retouchées à la main
    dans l'éditeur, qui passent devant : pour les importeurs."""
    chemin = os.path.join(SORTIE, ident + ".json")
    zones = json.load(open(chemin, encoding="utf8")) if os.path.exists(chemin) else {}
    zones.update(zones_manuelles(ident))
    return zones


def avec_perspective(ident, d):
    """Applique à ``d`` (données de salle) la perspective mesurée par ``outils/mesurer_perspective.py``
    (``outils/perspective/<id>.json``), si elle existe ; l'ancienne reste dans ``perspective_origine``."""
    chemin = os.path.join(ICI, "outils", "perspective", ident + ".json")
    if os.path.exists(chemin):
        m = json.load(open(chemin, encoding="utf8"))
        d.setdefault("perspective_origine", dict(d["perspective"]))
        d["perspective"] = dict(d["perspective"], y_horizon=m["y_horizon"], table_hauteur=m["table"],
                                hauteur_par_pixel=round(m["table"][1][1] / (511 - m["y_horizon"]), 3))
    return d


if __name__ == "__main__":
    main()
