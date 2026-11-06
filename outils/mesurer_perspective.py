"""Perspective de chaque salle peinte mesurée sur l'image (taille du héros selon la profondeur).

Demande de l'utilisateur (2026-11-05) : dans certaines salles le héros devenait minuscule alors qu'il n'était pas
censé être si loin. Les tables de hauteur étaient posées à l'œil (2 points, souvent copiés d'une salle à l'autre),
avec un horizon souvent trop bas : le héros rétrécissait trop vite.

Méthode :
1. **profondeur métrique** : Depth Anything V2 Metric Indoor donne une distance (pas une profondeur relative à
   décalage inconnu) de chaque pixel ; cache dans ``TRAVAIL/<id>.npy`` ;
2. **plan du sol** : sur un sol plat, l'inverse de la distance est affine dans l'image (1/Z = a·x + b·y + c), quel
   que soit le champ de la caméra. Ajustement (RANSAC) sur la zone de marche de la salle (moins les obstacles) ;
3. **horizon** : la ligne où 1/Z = 0 (là où le sol part à l'infini). La taille d'un personnage debout est
   proportionnelle à la distance de ses pieds à cette ligne : ``h(y) = h_bas · (y − y_h) / (511 − y_h)`` ;
4. **taille de près** (``h_bas``, à y = 511) : celle choisie jusqu'ici pour la salle (le héros de près n'a jamais
   posé de problème), bornée à [BAS_MIN, BAS_MAX] ;
5. **taille au fond** : la mesure donne souvent un fond très lointain (salles immenses) où le héros ferait 5 à 10 %
   de sa taille de près ; pour le jeu, la taille au haut du sol est bornée entre ``R_MIN`` et ``R_MAX`` fois la taille
   de près (l'horizon est déplacé en conséquence, la taille reste proportionnelle à la distance à l'horizon, sans
   palier) ; réglages à la main dans ``REGLAGES``.

Résultat : ``perspective`` des ``donnees/salles_peintes/<id>.json`` (y_horizon, hauteur_par_pixel, table_hauteur ;
l'ancienne est gardée dans ``perspective_origine``) et ``outils/perspective/<id>.json``, relu par les importeurs
pour ne pas revenir aux anciennes valeurs lors d'un réimport.
Planche de contrôle (héros en haut, au milieu et en bas du sol, avant/après) : ``TRAVAIL/planche_NN.png``.

Usage : ``python outils/mesurer_perspective.py [--planche] [--appliquer] [id ...]`` (toutes les salles sans id).
"""
import glob
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from matplotlib.path import Path

ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DONNEES = os.path.join(ICI, "donnees", "salles_peintes")
SORTIE = os.path.join(ICI, "outils", "perspective")
TRAVAIL = r"C:\IA\pont-blender\perspective_salles"
LARGEUR, HAUTEUR = 768, 512
MODELE = "depth-anything/Depth-Anything-V2-Metric-Indoor-Large-hf"

BAS_MIN, BAS_MAX = 160.0, 215.0
LARGEUR_HAUT = 0.12         # voir haut_du_sol
R_MIN, R_MAX = 0.30, 0.55   # taille du héros au haut du sol, en fraction de sa taille de près
# Réglages à la main par salle : {"r_haut": ...} impose la fraction au haut du sol, {"h_bas": ...} la taille de près.
REGLAGES = {
    # Passage du fond très étroit : avec 30 %, le héros (et son encombrement au sol) ne passait plus
    "bloc_jardin_potager_arcades": {"r_haut": 0.22},
    "bloc_laboratoire_grande_salle": {"r_haut": 0.24},
}


def lire(ident):
    return json.load(open(os.path.join(DONNEES, ident + ".json"), encoding="utf8"))


def fond(d):
    return Image.open(os.path.join(ICI, d["fond"])).convert("RGB").resize((LARGEUR, HAUTEUR), Image.LANCZOS)


def profondeurs(ids):
    a_faire = [i for i in ids if not os.path.exists(os.path.join(TRAVAIL, i + ".npy"))]
    if not a_faire:
        return
    import torch
    from transformers import AutoImageProcessor, AutoModelForDepthEstimation
    pr = AutoImageProcessor.from_pretrained(MODELE)
    md = AutoModelForDepthEstimation.from_pretrained(MODELE).to("cuda").eval()
    for i in a_faire:
        im = fond(lire(i)).resize((LARGEUR * 2, HAUTEUR * 2), Image.LANCZOS)
        entree = pr(im, return_tensors="pt", size={"height": 1022, "width": 1526}, keep_aspect_ratio=False,
                    ensure_multiple_of=14)
        with torch.no_grad():
            p = md(**{k: v.to("cuda") for k, v in entree.items()}).predicted_depth
        p = torch.nn.functional.interpolate(p[None], size=(HAUTEUR, LARGEUR), mode="bicubic")[0, 0].cpu().numpy()
        np.save(os.path.join(TRAVAIL, i + ".npy"), p.astype(np.float32))
        print("profondeur", i)


def masque_marche(d):
    """Points (pas de 2 pixels) de la zone de marche, moins les obstacles et le premier plan."""
    ys, xs = np.mgrid[0:HAUTEUR:2, 0:LARGEUR:2]
    pts = np.stack([xs.ravel(), ys.ravel()], -1)
    dedans = np.zeros(len(pts), bool)
    for poly in d["marche"]:
        dedans |= Path(poly).contains_points(pts)
    for poly in d.get("obstacles", []) + d.get("premier_plan", []):
        if len(poly) >= 3:
            dedans &= ~Path(poly).contains_points(pts)
    return pts[dedans]


def haut_du_sol(pts):
    """Haut du sol principal : rangée la plus haute dont la largeur atteint LARGEUR_HAUT de la plus large.
    Les escaliers et balcons étroits au-dessus n'en font pas partie (le héros y garde la taille du haut du sol)."""
    ys, n = np.unique(pts[:, 1], return_counts=True)
    return float(ys[n >= LARGEUR_HAUT * n.max()].min())


def plan_du_sol(z, pts, graine=0):
    """RANSAC de 1/Z = a·x + b·y + c sur les points du sol ; écart relatif toléré 6 %."""
    rng = np.random.default_rng(graine)
    x, y = pts[:, 0].astype(float), pts[:, 1].astype(float)
    v = 1.0 / np.maximum(z[pts[:, 1], pts[:, 0]], 0.05)
    A = np.stack([x, y, np.ones_like(x)], -1)
    meilleur, meilleur_n = None, -1
    for _ in range(800):
        k = rng.choice(len(x), 3, replace=False)
        try:
            c = np.linalg.solve(A[k], v[k])
        except np.linalg.LinAlgError:
            continue
        if c[1] <= 0:
            continue
        n = int((np.abs(A @ c - v) < 0.06 * v).sum())
        if n > meilleur_n:
            meilleur, meilleur_n = c, n
    for _ in range(3):
        ok = np.abs(A @ meilleur - v) < 0.06 * v
        meilleur, *_ = np.linalg.lstsq(A[ok], v[ok], rcond=None)
    return meilleur, ok.mean()


def ancienne_hauteur(p):
    """Même calcul que SallePeinte.hauteur (table interpolée, prolongée en bas, plafonnée en haut)."""
    t = p.get("table_hauteur", [])

    def h(y):
        if not t:
            return max(8.0, (y - p["y_horizon"]) * p["hauteur_par_pixel"])
        if y <= t[0][0]:
            return t[0][1]
        for i in range(1, len(t)):
            if y <= t[i][0]:
                a, b = t[i - 1], t[i]
                return a[1] + (b[1] - a[1]) * (y - a[0]) / (b[0] - a[0])
        a, b = t[-2], t[-1]
        return b[1] + (y - b[0]) * (b[1] - a[1]) / (b[0] - a[0])
    return h


def mesurer(ident):
    d = lire(ident)
    reg = REGLAGES.get(ident, {})
    origine = d.get("perspective_origine") or d["perspective"]
    h_bas = float(reg.get("h_bas", min(BAS_MAX, max(BAS_MIN, ancienne_hauteur(origine)(511)))))
    pts = masque_marche(d)
    haut_sol = haut_du_sol(pts)
    z = np.load(os.path.join(TRAVAIL, ident + ".npy"))
    coef, part = plan_du_sol(z, pts)
    a, b, c = coef
    y_mesure = -(a * LARGEUR / 2 + c) / b
    r_mesure = (haut_sol - y_mesure) / (511 - y_mesure) if y_mesure < haut_sol else 0.0
    r_haut = float(reg.get("r_haut", min(R_MAX, max(R_MIN, r_mesure))))
    # Horizon tel que h(haut_sol) = r_haut · h_bas, h linéaire en y
    y_h = (haut_sol - r_haut * 511) / (1 - r_haut)
    pente = h_bas / (511 - y_h)
    table = [[round(haut_sol), round(r_haut * h_bas, 1)], [511, round(h_bas, 1)]]
    return {"id": ident, "y_mesure": round(float(y_mesure), 1), "y_horizon": round(y_h), "part_sol": round(float(part), 2),
            "haut_sol": haut_sol, "h_bas": h_bas, "pente": pente, "table": table, "r_mesure": round(r_mesure, 2),
            "r_haut": r_haut}


def appliquer(r):
    chemin = os.path.join(DONNEES, r["id"] + ".json")
    d = json.load(open(chemin, encoding="utf8"))
    if "perspective_origine" not in d:
        d["perspective_origine"] = dict(d["perspective"])
    p = d["perspective"]
    p["y_horizon"] = r["y_horizon"]
    p["hauteur_par_pixel"] = round(r["pente"], 3)
    p["table_hauteur"] = r["table"]
    json.dump(d, open(chemin, "w", encoding="utf8"), ensure_ascii=False, indent=1)
    os.makedirs(SORTIE, exist_ok=True)
    json.dump({k: r[k] for k in ("y_mesure", "r_mesure", "r_haut", "y_horizon", "h_bas", "table")},
              open(os.path.join(SORTIE, r["id"] + ".json"), "w", encoding="utf8"), indent=1)


# ---------------------------------------------------------------------------
# Planche de contrôle
# ---------------------------------------------------------------------------

HEROS = None


def rendu(d, h, titre):
    global HEROS
    if HEROS is None:
        HEROS = Image.open(os.path.join(ICI, "images/salles_peintes/heros/respiration/up/idle_up_0.png")).convert("RGBA")
    im = fond(d).convert("RGBA")
    pts = masque_marche(d)
    y0, y1 = pts[:, 1].min(), min(pts[:, 1].max(), 505)
    poses = []
    for f in (0.02, 0.2, 0.45, 0.85):
        y = int(y0 + (y1 - y0) * f) // 2 * 2
        xs = np.sort(pts[pts[:, 1] == y][:, 0])
        if len(xs):
            poses.append((xs[len(xs) // 2], y))
            if f < 0.5 and len(xs) > 12:
                poses.append((xs[len(xs) // 6], y))
    for x, y in sorted(poses, key=lambda p: p[1]):
        k = h(y) / 428.0
        s = HEROS.resize((max(1, int(448 * k)), max(1, int(448 * k))))
        im.alpha_composite(s, (int(x - s.width / 2), int(y - 442 * k)))
    ImageDraw.Draw(im).text((6, 4), titre, fill=(255, 255, 0, 255))
    return im


def planche(resultats):
    cases = []
    for r in resultats:
        d = lire(r["id"])
        avant = ancienne_hauteur(d.get("perspective_origine") or d["perspective"])
        apres = ancienne_hauteur({"table_hauteur": r["table"]})
        cases.append(rendu(d, avant, r["id"] + " AVANT").resize((384, 256)))
        im = rendu(d, apres, "APRES  fond %.0f %%  (mesure %.0f %%)" % (100 * r["r_haut"], 100 * r["r_mesure"]))
        cases.append(im.resize((384, 256)))
    for n in range(0, len(cases), 16):
        pl = Image.new("RGB", (4 * 384, 4 * 256))
        for k, im in enumerate(cases[n:n + 16]):
            pl.paste(im, ((k % 4) * 384, (k // 4) * 256))
        pl.save(os.path.join(TRAVAIL, "planche_%02d.png" % (n // 16)))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    ids = args or sorted(os.path.basename(f)[:-5] for f in glob.glob(os.path.join(DONNEES, "*.json")))
    os.makedirs(TRAVAIL, exist_ok=True)
    profondeurs(ids)
    resultats = [mesurer(i) for i in ids]
    for r in resultats:
        print("%-40s fond %3.0f %% (mesure %3.0f %%) horizon %4d  haut du sol %4d  pres %3d" % (
            r["id"], 100 * r["r_haut"], 100 * r["r_mesure"], r["y_horizon"], r["haut_sol"], r["h_bas"]))
    if "--planche" in sys.argv:
        planche(resultats)
    if "--appliquer" in sys.argv:
        for r in resultats:
            appliquer(r)


if __name__ == "__main__":
    main()
