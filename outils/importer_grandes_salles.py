"""Importe les grandes salles (carrefours des grands étages) dans le jeu Godot.

Source : ``C:\\ia image\\Salle de donjon\\grande salle\\*.jpeg`` (10 images 768 x 512 de l'utilisateur, triées par
nom : grande1 … grande10). Les zones (sol, obstacles, piliers devant le héros, sorties, perspective) sont
relevées à la main par Claude sur une grille (``C:\\IA\\pont-blender\\grandes_salles\\travail\\grilleN.png``) et
écrites dans ZONES ci-dessous, en pixels de l'image 768 x 512.

Chaque grande salle a 4 sorties, dans cet ordre : **devant** (arche, escalier ou couloir du fond), **gauche** et
**droite** (passages sur les bords du sol, type « bord » : sans salle derrière, ils deviennent un mur invisible,
comme le bas de l'image), **bas** (retour, derrière le spectateur).

Écrit :
- ``images/salles_peintes/grandeN/fond.jpeg`` (image d'origine, sert aux zones et à l'ombre) et ``fond_hd.png``
  (agrandie par IA, Swin2SR × 4 puis réduite à 1152 x 768 : c'est elle qu'on voit) ;
- ``donnees/salles_peintes/grandeN.json`` (même format que les salles de test_salle) ;
- ``C:\\IA\\pont-blender\\grandes_salles\\planche_zones.png`` : planche de contrôle (sol en vert, obstacles en
  rouge, sorties en couleur, héros à plusieurs profondeurs).

Usage : ``python outils/importer_grandes_salles.py [--sans-ia]`` (``--sans-ia`` : ne refait pas l'agrandissement).
"""
import glob
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

SOURCE = r"C:\ia image\Salle de donjon\grande salle"
TRAVAIL = r"C:\IA\pont-blender\grandes_salles"
ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMAGES = os.path.join(ICI, "images", "salles_peintes")
DONNEES = os.path.join(ICI, "donnees", "salles_peintes")
HEROS = os.path.join(IMAGES, "heros", "respiration", "up", "idle_up_0.png")
TAILLE_HD = (1152, 768)

# Pour chaque image : sol (bord du fond, de gauche à droite, entre les bords x=0 et x=767), obstacles, premier
# plan (piliers devant lesquels le héros passe derrière), sortie du fond (rectangle x0, x1, y), hauteurs des
# bords gauche et droit où l'on sort, perspective (hauteur du héros en pixels à deux profondeurs), noms.
ZONES = {
    1: {"fond": [(0, 398), (40, 392), (70, 365), (90, 345), (160, 338), (250, 330), (380, 322), (470, 318),
                 (560, 318), (600, 322), (640, 330), (680, 345), (720, 372), (767, 385)],
        "devant": (470, 585, 318), "nom_devant": "escalier du fond",
        "bords": ((400, 498), (390, 498)), "hauteurs": ((318, 48), (511, 175))},
    2: {"fond": [(0, 430), (90, 425), (150, 385), (220, 378), (300, 368), (415, 365), (430, 360), (520, 358),
                 (560, 352), (640, 355), (680, 370), (690, 430), (767, 445)],
        "devant": (300, 410, 366), "nom_devant": "escalier du fond",
        "bords": ((435, 498), (450, 498)), "hauteurs": ((360, 70), (511, 180))},
    3: {"fond": [(0, 470), (60, 455), (110, 470), (150, 480), (200, 455), (260, 425), (330, 400), (400, 378),
                 (440, 340), (470, 335), (545, 340), (580, 395), (640, 420), (690, 440), (767, 470)],
        "devant": (450, 540, 337), "nom_devant": "chemin dans la brume",
        "bords": ((475, 498), (475, 498)), "hauteurs": ((340, 52), (511, 175))},
    4: {"fond": [(0, 380), (60, 370), (150, 360), (300, 356), (520, 358), (540, 368), (600, 372), (680, 378),
                 (720, 390), (767, 400)],
        "devant": (200, 285, 357), "nom_devant": "arches du fond",
        "obstacles": [[(65, 360), (100, 360), (100, 374), (65, 374)], [(712, 394), (756, 394), (756, 412), (712, 412)]],
        "bords": ((385, 498), (415, 498)), "hauteurs": ((356, 55), (511, 175))},
    5: {"fond": [(0, 395), (80, 390), (170, 375), (240, 350), (330, 345), (520, 352), (560, 360), (590, 380),
                 (680, 385), (700, 410), (767, 420)],
        "devant": (430, 510, 349), "nom_devant": "escalier du fond",
        "obstacles": [[(585, 372), (680, 372), (680, 392), (585, 392)]],
        "bords": ((400, 498), (425, 498)), "hauteurs": ((348, 52), (511, 180))},
    6: {"fond": [(0, 345), (60, 340), (110, 320), (170, 300), (250, 285), (330, 278), (500, 278), (560, 285),
                 (600, 300), (640, 325), (700, 345), (767, 360)],
        "devant": (340, 500, 279), "nom_devant": "allée du fond",
        "bords": ((350, 498), (365, 498)), "hauteurs": ((280, 35), (511, 185))},
    7: {"fond": [(0, 440), (40, 430), (120, 420), (200, 410), (300, 405), (400, 398), (560, 402), (640, 420),
                 (700, 445), (767, 470)],
        "devant": (380, 500, 399), "nom_devant": "arches du fond",
        "bords": ((445, 498), (475, 498)), "hauteurs": ((400, 55), (511, 165))},
    8: {"fond": [(0, 400), (80, 385), (160, 370), (220, 340), (300, 322), (470, 322), (560, 345), (640, 375),
                 (720, 395), (767, 410)],
        "devant": (340, 430, 323), "nom_devant": "porte du fond",
        "bords": ((405, 498), (415, 498)), "hauteurs": ((322, 40), (511, 190))},
    9: {"fond": [(0, 410), (100, 400), (180, 395), (240, 392), (300, 388), (520, 388), (560, 395), (640, 400),
                 (700, 420), (767, 440)],
        "devant": (300, 520, 389), "nom_devant": "marches du fond",
        "obstacles": [[(188, 385), (278, 385), (280, 400), (186, 400)], [(550, 390), (640, 390), (642, 405), (548, 405)]],
        "premier_plan": [[(193, 0), (273, 0), (278, 392), (188, 392)], [(553, 0), (633, 0), (640, 398), (550, 398)]],
        "bords": ((415, 498), (445, 498)), "hauteurs": ((388, 60), (511, 170))},
    10: {"fond": [(0, 410), (60, 405), (150, 395), (220, 380), (270, 345), (330, 318), (480, 320), (540, 350),
                  (600, 385), (680, 405), (767, 420)],
         "devant": (340, 420, 319), "nom_devant": "porte du fond",
         "bords": ((415, 498), (425, 498)), "hauteurs": ((318, 35), (511, 190))},
}


def donnees_salle(n, z):
    (y_a, h_a), (y_b, h_b) = z["hauteurs"]
    pente = (h_b - h_a) / (y_b - y_a)
    x0, x1, y = z["devant"]
    (g0, g1), (d0, d1) = z["bords"]
    marche = [[0, 511], [767, 511]] + [list(p) for p in reversed(z["fond"])]
    sorties = [
        [[x0, y - 3], [x1, y - 3], [x1, y + 12], [x0, y + 12]],
        [[-4, g0], [30, g0], [30, g1], [-4, g1]],
        [[737, d0], [771, d0], [771, d1], [737, d1]],
        [[0, 499], [767, 499], [767, 517], [0, 517]],
    ]
    return {
        "fond": "images/salles_peintes/grande%d/fond.jpeg" % n,
        "fond_hd": "images/salles_peintes/grande%d/fond_hd.png" % n,
        "perspective": {"y_horizon": round(y_a - h_a / pente), "hauteur_par_pixel": round(pente, 3), "vitesse": 1.8,
                        "compression_profondeur": 0.6, "table_hauteur": [[y_a, h_a], [y_b, h_b]]},
        "depart": [384, 470],
        "marche": [marche],
        "obstacles": [[list(p) for p in o] for o in z.get("obstacles", [])],
        "premier_plan": [[list(p) for p in o] for o in z.get("premier_plan", [])],
        "sorties": sorties,
        "noms_sorties": [z["nom_devant"], "passage de gauche", "passage de droite", "retour"],
        "directions_sorties": ["devant", "gauche", "droite", "bas"],
        "types_sorties": ["passage", "bord", "bord", "passage"],
        "arrivees": {z["nom_devant"]: [(x0 + x1) // 2, y + 30, "down"],
                     "passage de gauche": [48, (g0 + g1) // 2, "right"],
                     "passage de droite": [719, (d0 + d1) // 2, "left"]},
        "grande_salle": True,
        "ips": 24,
        "source": "grande salle/%s" % n,
    }


def agrandir(images):
    """Swin2SR × 4 (modèle en cache), par tuiles, puis réduction à TAILLE_HD."""
    import numpy as np
    import torch
    from transformers import Swin2SRForImageSuperResolution
    modele = Swin2SRForImageSuperResolution.from_pretrained("caidas/swin2SR-realworld-sr-x4-64-bsrgan-psnr").cuda().eval().half()
    resultats = []
    for im in images:
        a = np.asarray(im.convert("RGB"), dtype=np.float32) / 255.0
        h, w, _ = a.shape
        sortie = np.zeros((h * 4, w * 4, 3), dtype=np.float32)
        tuile, marge = 192, 16
        for y in range(0, h, tuile):
            for x in range(0, w, tuile):
                ya, yb = max(0, y - marge), min(h, y + tuile + marge)
                xa, xb = max(0, x - marge), min(w, x + tuile + marge)
                t = torch.from_numpy(a[ya:yb, xa:xb]).permute(2, 0, 1)[None].cuda().half()
                with torch.no_grad():
                    r = modele(pixel_values=t).reconstruction.float().clamp(0, 1)[0].permute(1, 2, 0).cpu().numpy()
                cy, cx = (y - ya) * 4, (x - xa) * 4
                hh, ww = min(tuile, h - y) * 4, min(tuile, w - x) * 4
                sortie[y * 4:y * 4 + hh, x * 4:x * 4 + ww] = r[cy:cy + hh, cx:cx + ww]
        grand = Image.fromarray((sortie * 255).round().astype("uint8"))
        resultats.append(grand.resize(TAILLE_HD, Image.LANCZOS))
    return resultats


def planche(donnees, sources):
    heros = Image.open(HEROS).convert("RGBA")
    hb = heros.getchannel("A").getbbox()
    heros = heros.crop(hb)
    police = ImageFont.load_default()
    cases = []
    for n, d in donnees.items():
        im = sources[n].convert("RGBA")
        calque = Image.new("RGBA", im.size)
        dr = ImageDraw.Draw(calque)
        dr.polygon([tuple(p) for p in d["marche"][0]], fill=(0, 255, 0, 55), outline=(0, 255, 0, 255))
        for o in d["obstacles"]:
            dr.polygon([tuple(p) for p in o], fill=(255, 0, 0, 110))
        for o in d["premier_plan"]:
            dr.polygon([tuple(p) for p in o], outline=(255, 128, 0, 255))
        couleurs = [(255, 220, 0, 170), (0, 200, 255, 170), (255, 0, 255, 170), (255, 255, 255, 120)]
        for i, s in enumerate(d["sorties"]):
            dr.polygon([tuple(p) for p in s], fill=couleurs[i])
        im = Image.alpha_composite(im, calque)
        # Héros à trois profondeurs (pieds sur le sol)
        (ya, ha), (yb, hb2) = d["perspective"]["table_hauteur"]
        for x, y in [((d["sorties"][0][0][0] + d["sorties"][0][1][0]) // 2, d["sorties"][0][2][1] + 6), (200, (ya + 511) // 2), (560, 490)]:
            h = ha + (y - ya) * (hb2 - ha) / (yb - ya)
            # le héros dessiné fait ~ 1/0.9 de sa boîte : on prend la boîte = hauteur
            hh = max(4, int(h))
            ww = max(2, int(heros.width * hh / heros.height))
            im.alpha_composite(heros.resize((ww, hh)), (int(x - ww / 2), int(y - hh)))
        dr2 = ImageDraw.Draw(im)
        dr2.text((6, 4), "grande%d : %s" % (n, d["noms_sorties"][0]), fill=(255, 255, 0, 255), font=police)
        cases.append(im.convert("RGB").resize((576, 384)))
    pl = Image.new("RGB", (576 * 2, 384 * 5), "black")
    for k, c in enumerate(cases):
        pl.paste(c, ((k % 2) * 576, (k // 2) * 384))
    pl.save(os.path.join(TRAVAIL, "planche_zones.png"))


def main():
    fichiers = sorted(glob.glob(os.path.join(SOURCE, "*.jpeg")))
    sources = {k + 1: Image.open(f).convert("RGB") for k, f in enumerate(fichiers)}
    assert len(sources) == len(ZONES), "une entrée de ZONES par image"
    donnees = {}
    for n, z in ZONES.items():
        dossier = os.path.join(IMAGES, "grande%d" % n)
        os.makedirs(dossier, exist_ok=True)
        sources[n].save(os.path.join(dossier, "fond.jpeg"), quality=95)
        donnees[n] = donnees_salle(n, z)
        # Sol détouré automatiquement (outils/detourer_sols.py) : remplace le sol relevé à la main
        from detourer_sols import detourage
        donnees[n].update(detourage("grande%d" % n))
        with open(os.path.join(DONNEES, "grande%d.json" % n), "w", encoding="utf8") as f:
            json.dump(donnees[n], f, ensure_ascii=False, indent=1)
    if "--sans-ia" not in sys.argv:
        for n, hd in zip(sources, agrandir([sources[n] for n in sources])):
            hd.save(os.path.join(IMAGES, "grande%d" % n, "fond_hd.png"), optimize=True)
    os.makedirs(TRAVAIL, exist_ok=True)
    planche(donnees, sources)
    print("Grandes salles importées :", len(donnees))


if __name__ == "__main__":
    main()
