"""Maquette 3D invisible sous une salle peinte (idée de l'utilisateur, 2026-10-27, essai sur la grande salle 5).

Le joueur voit l'image de Grok ; dessous, une maquette en formes simples (sol, cylindres pour les piliers, blocs
pour les rochers, marches et murs) vue par la **même caméra** que l'image. Le héros marche sur cette maquette :
son sol praticable, ses obstacles, les piliers qui le cachent quand il passe derrière et sa taille selon la distance
viennent tous de la 3D, plus d'un détourage de l'image.

1. **Caméra** (sténopé, image 768 × 512) : horizon (ligne où le sol rejoint l'infini, trouvé par la profondeur de
   l'image), champ de vision horizontal CHAMP, hauteur de l'œil calculée pour qu'un héros de 1,80 m ait au bas de
   l'image la taille qu'il a déjà dans le jeu.
2. **Formes posées sur l'image** : chaque forme est donnée par des points de l'image *sur le sol* (pied d'un pilier,
   coins d'un bloc) ; ils sont ramenés en 3D sur le sol (Y = 0), puis la forme monte à sa hauteur en mètres.
3. **Contrôle** : les arêtes de la maquette dessinées sur l'image (``C:\\IA\\pont-blender\\carte3d\\<id>_maquette.png``).
4. **Jeu** : la maquette projetée donne « marche » (le sol), « obstacles » (emprise au sol des formes),
   « premier_plan » (silhouette des formes hautes : le héros passe derrière) et la perspective (taille du héros à
   chaque ligne). Écrit dans ``outils/detourage/<id>.json`` (relu par les importeurs) et dans les données du jeu.

Repère : X à droite, Y vers le haut, Z vers le fond, en mètres ; la caméra est en (0, h, 0).
Usage : ``python outils/carte3d.py grande5``.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DONNEES = os.path.join(ICI, "donnees", "salles_peintes")
DETOURAGE = os.path.join(ICI, "outils", "detourage")
TRAVAIL = r"C:\IA\pont-blender\carte3d"
L, H = 768, 512
HEROS = 1.8  # mètres

# Maquettes : horizon (ligne de l'image), champ de vision horizontal (degrés), taille du héros (pixels) au bas de
# l'image, sol (polygone de l'image, sur le sol), formes. Cylindre : « pied » = point de l'image au pied du
# pilier, devant (le plus bas) ; « rayon » en pixels à cette distance ; « cache » : il cache le héros (premier plan).
CARTES = {
    "grande5": {
        "horizon": 302.0, "champ": 65.0, "heros_bas": 180.0,
        "sol": [(0, 511), (767, 511), (767, 345), (0, 345)],
        "formes": [
            {"nom": "pilier gauche", "type": "cylindre", "pied": (118, 392), "rayon": 34, "hauteur": 14.0, "cache": True},
            {"nom": "socle du pilier gauche", "type": "cylindre", "pied": (122, 398), "rayon": 60, "hauteur": 0.6},
            {"nom": "pilier droit", "type": "cylindre", "pied": (640, 399), "rayon": 44, "hauteur": 14.0, "cache": True},
            {"nom": "rebord de gauche", "type": "bloc", "coins": [(0, 345), (62, 345), (62, 396), (0, 399)], "hauteur": 0.8},
            {"nom": "gravats du fond", "type": "bloc", "coins": [(160, 336), (262, 336), (262, 357), (160, 357)], "hauteur": 0.6},
            {"nom": "rocher", "type": "bloc", "coins": [(492, 363), (540, 363), (540, 380), (492, 380)], "hauteur": 0.4},
            {"nom": "masse du bord droit", "type": "bloc", "coins": [(716, 360), (767, 360), (767, 472), (716, 472)],
             "hauteur": 1.3, "cache": True},
        ],
    },
}


class Camera:
    def __init__(self, horizon, champ, heros_bas):
        self.cx, self.cy = L / 2.0, H / 2.0
        self.f = (L / 2.0) / math.tan(math.radians(champ) / 2.0)
        self.phi = math.atan((horizon - self.cy) / self.f)  # > 0 : la caméra regarde un peu vers le haut
        self.h = 1.0
        # Hauteur de l'œil : le héros de 1,80 m mesure ``heros_bas`` pixels au bas de l'image
        # (la taille à l'écran est inversement proportionnelle à la hauteur de l'œil)
        self.h = self.taille_heros(H - 1) / heros_bas

    def axes(self):
        p = self.phi
        avant = np.array([0.0, math.sin(p), math.cos(p)])
        haut = np.array([0.0, math.cos(p), -math.sin(p)])
        return np.array([1.0, 0.0, 0.0]), haut, avant

    def projeter(self, P):
        """Point 3D → (u, v, profondeur)."""
        droite, haut, avant = self.axes()
        d = np.asarray(P, float) - np.array([0.0, self.h, 0.0])
        z = d @ avant
        return self.cx + self.f * (d @ droite) / z, self.cy - self.f * (d @ haut) / z, z

    def au_sol(self, u, v):
        """Point de l'image → point du sol (Y = 0)."""
        droite, haut, avant = self.axes()
        r = droite * (u - self.cx) - haut * (v - self.cy) + avant * self.f
        t = -self.h / r[1]
        return np.array([0.0, self.h, 0.0]) + t * r

    def taille_heros(self, v):
        """Hauteur en pixels du héros dont les pieds sont à la ligne ``v`` (au milieu de l'image)."""
        pied = self.au_sol(self.cx, v)
        tete = pied + np.array([0.0, HEROS, 0.0])
        return self.projeter(pied)[1] - self.projeter(tete)[1]


def construire(carte, cam):
    """Formes en 3D : liste de {nom, base (polygone du sol en 3D), hauteur, cache}."""
    formes = []
    for f in carte["formes"]:
        if f["type"] == "cylindre":
            pied = cam.au_sol(*f["pied"])
            z = cam.projeter(pied)[2]
            r = f["rayon"] * z / cam.f
            centre = pied + np.array([0.0, 0.0, r])
            base = [centre + np.array([r * math.cos(a), 0.0, r * math.sin(a)]) for a in np.linspace(0, 2 * math.pi, 24, endpoint=False)]
        else:
            base = [cam.au_sol(u, v) for u, v in f["coins"]]
        formes.append({"nom": f["nom"], "base": base, "hauteur": f["hauteur"], "cache": f.get("cache", False),
                       "type": f["type"]})
    return formes


def silhouette(forme, cam):
    """Contour (image) d'une forme : enveloppe convexe des sommets de sa base et de son sommet projetés."""
    pts = []
    for p in forme["base"]:
        for y in (0.0, forme["hauteur"]):
            u, v, z = cam.projeter(p + np.array([0.0, y, 0.0]))
            if z > 0.05:
                pts.append((u, max(-2000.0, v)))
    return enveloppe(pts)


def enveloppe(pts):
    pts = sorted(set((round(x, 1), round(y, 1)) for x, y in pts))
    if len(pts) < 3:
        return pts
    def croix(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    bas, haut = [], []
    for p in pts:
        while len(bas) >= 2 and croix(bas[-2], bas[-1], p) <= 0:
            bas.pop()
        bas.append(p)
    for p in reversed(pts):
        while len(haut) >= 2 and croix(haut[-2], haut[-1], p) <= 0:
            haut.pop()
        haut.append(p)
    return bas[:-1] + haut[:-1]


def projeter_base(forme, cam):
    return [tuple(round(c, 1) for c in cam.projeter(p)[:2]) for p in forme["base"]]


def compiler(ident):
    carte = CARTES[ident]
    cam = Camera(carte["horizon"], carte["champ"], carte["heros_bas"])
    formes = construire(carte, cam)
    sol = [cam.au_sol(u, v) for u, v in carte["sol"]]
    marche = [[list(q) for q in [tuple(round(c, 1) for c in cam.projeter(p)[:2]) for p in sol]]]
    obstacles = [[list(q) for q in projeter_base(f, cam)] for f in formes]
    premier_plan = []
    for f in formes:
        if f["cache"]:
            s = silhouette(f, cam)
            premier_plan.append([[round(x, 1), round(min(y, H + 50), 1)] for x, y in s])
    lignes = list(range(int(carte["horizon"]) + 20, H, 15)) + [H - 1]
    table = [[v, round(float(cam.taille_heros(v)), 1)] for v in lignes]
    resultat = {"marche": marche, "obstacles": obstacles, "premier_plan": premier_plan,
                "perspective_table": table,
                "carte3d": {"camera": {"focale": round(cam.f, 1), "inclinaison_degres": round(math.degrees(cam.phi), 2),
                                        "hauteur_oeil": round(float(cam.h), 3), "horizon": carte["horizon"]},
                            "formes": [{"nom": f["nom"], "type": f["type"], "hauteur": f["hauteur"],
                                        "base": [[round(c, 3) for c in p] for p in f["base"]]} for f in formes],
                            "sol": [[round(c, 3) for c in p] for p in sol]}}
    return cam, formes, resultat


def dessiner(ident, cam, formes, resultat):
    info = json.load(open(os.path.join(DONNEES, ident + ".json"), encoding="utf8"))
    im = Image.open(os.path.join(ICI, info["fond"])).convert("RGBA")
    cal = Image.new("RGBA", im.size)
    dr = ImageDraw.Draw(cal)
    dr.polygon([tuple(p) for p in resultat["marche"][0]], fill=(0, 255, 0, 45))
    for o in resultat["obstacles"]:
        dr.polygon([tuple(p) for p in o], fill=(255, 0, 0, 120))
    # Arêtes 3D : base, sommet et montants
    for f in formes:
        haut = [p + np.array([0.0, f["hauteur"], 0.0]) for p in f["base"]]
        pb = [cam.projeter(p)[:2] for p in f["base"]]
        ph = [cam.projeter(p)[:2] for p in haut]
        couleur = (255, 200, 0, 255) if f["cache"] else (0, 220, 255, 255)
        n = len(pb)
        for k in range(n):
            dr.line([pb[k], pb[(k + 1) % n]], fill=couleur, width=1)
            dr.line([ph[k], ph[(k + 1) % n]], fill=couleur, width=1)
            if f["type"] == "bloc" or k % 6 == 0:
                dr.line([pb[k], ph[k]], fill=couleur, width=1)
    # Quadrillage du sol tous les mètres
    for x in range(-20, 21):
        a, b = cam.projeter((x, 0, 1.0)), cam.projeter((x, 0, 60.0))
        dr.line([a[:2], b[:2]], fill=(255, 255, 255, 50))
    for z in range(2, 60):
        a, b = cam.projeter((-30, 0, z)), cam.projeter((30, 0, z))
        dr.line([a[:2], b[:2]], fill=(255, 255, 255, 50))
    # Héros de 1,80 m à quelques endroits
    for u, v in [(250, 500), (384, 420), (384, 360), (560, 440), (300, 352)]:
        p = cam.au_sol(u, v)
        a, b = cam.projeter(p), cam.projeter(p + np.array([0.0, HEROS, 0.0]))
        dr.line([a[:2], b[:2]], fill=(255, 60, 255, 255), width=3)
    im = Image.alpha_composite(im, cal).convert("RGB").resize((L * 2, H * 2), Image.LANCZOS)
    os.makedirs(TRAVAIL, exist_ok=True)
    im.save(os.path.join(TRAVAIL, ident + "_maquette.png"))


def appliquer(ident, resultat):
    os.makedirs(DETOURAGE, exist_ok=True)
    chemin = os.path.join(DONNEES, ident + ".json")
    info = json.load(open(chemin, encoding="utf8"))
    persp = dict(info["perspective"])
    persp["table_hauteur"] = resultat["perspective_table"]
    zones = {"marche": resultat["marche"], "obstacles": resultat["obstacles"], "premier_plan": resultat["premier_plan"],
             "perspective": persp, "carte3d": resultat["carte3d"]}
    with open(os.path.join(DETOURAGE, ident + ".json"), "w", encoding="utf8") as f:
        json.dump(zones, f, ensure_ascii=False)
    info.update(zones)
    manuelles = os.path.join(ICI, "outils", "zones_manuelles", ident + ".json")
    if os.path.exists(manuelles):  # retouches faites dans l'éditeur du jeu : elles passent devant la maquette
        info.update(json.load(open(manuelles, encoding="utf8")))
    with open(chemin, "w", encoding="utf8") as f:
        json.dump(info, f, ensure_ascii=False, indent=1)


def main():
    for ident in [a for a in sys.argv[1:] if not a.startswith("--")] or list(CARTES):
        cam, formes, resultat = compiler(ident)
        dessiner(ident, cam, formes, resultat)
        if "--sans-appliquer" not in sys.argv:
            appliquer(ident, resultat)
        print(ident, resultat["carte3d"]["camera"], "héros :", resultat["perspective_table"][0], resultat["perspective_table"][-1])


if __name__ == "__main__":
    main()
