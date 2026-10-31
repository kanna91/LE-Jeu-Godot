"""Importe les **blocs de salles** dans le jeu Godot (demande de l'utilisateur, 2026-10-31).

Un bloc est un lot d'images de l'utilisateur qui forment des salles reliées entre elles dans un ordre fixé
(au lieu de salles tirées au hasard). Le plan du bloc (positions sur la carte, quelle porte mène où, entrées
depuis le reste de l'étage) est dans le jeu : ``scripts/logique/blocs_salles.gd``. Ici : les zones de chaque image
(sol, obstacles, sorties, perspective), relevées à la main par Claude sur des grilles
(``C:\\IA\\pont-blender\\bloc_<nom>\\travail\\grille_*.png``), en pixels de l'image 768 x 512.

Bloc « cuisine » (``C:\\ia image\\Salle de donjon\\cuisine et salle a manger``) : salle à manger → (porte du fond)
cuisine → (porte du fond à gauche) salle de la petite porte → (porte de gauche) cellier gauche, (porte de
droite) cellier droit ; l'arche du fond de la petite porte ressort sur l'étage.

Écrit, pour chaque salle ``bloc_<bloc>_<salle>`` :
- ``images/salles_peintes/<id>/fond.jpeg`` (image d'origine) et ``fond_hd.png`` (agrandie par IA, Swin2SR, comme
  les grandes salles ; ``--sans-ia`` : ne la refait pas) ;
- ``donnees/salles_peintes/<id>.json`` (format habituel, plus ``"bloc"`` : ces images ne servent qu'au bloc) ;
- ``C:\\IA\\pont-blender\\bloc_<bloc>\\planche_zones.png`` : planche de contrôle (sol vert, obstacles rouges,
  sorties en couleur, héros à plusieurs profondeurs).
Les retouches faites dans l'éditeur de zones (``outils/zones_manuelles/<id>.json``) passent devant.

Usage : ``python outils/importer_blocs.py [--sans-ia]``
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ICI, "outils"))
IMAGES = os.path.join(ICI, "images", "salles_peintes")
DONNEES = os.path.join(ICI, "donnees", "salles_peintes")
HEROS = os.path.join(IMAGES, "heros", "respiration", "up", "idle_up_0.png")
TRAVAIL = r"C:\IA\pont-blender"

BAS = [[0, 499], [767, 499], [767, 517], [0, 517]]

# Chaque salle : image source, sol (polygone), obstacles, sorties [nom, direction, type, rectangle, arrivée],
# perspective (hauteur du héros en pixels à deux profondeurs), départ.
BLOCS = {
    "cuisine": {
        "source": r"C:\ia image\Salle de donjon\cuisine et salle a manger",
        "salles": {
            "manger": {
                "image": "salle a manger.jpeg",
                "marche": [(0, 511), (767, 511), (767, 430), (735, 425), (720, 380), (690, 365), (640, 350), (610, 335),
                           (560, 312), (480, 309), (435, 305), (378, 305), (330, 310), (290, 320), (200, 332), (130, 342),
                           (60, 360), (30, 385), (0, 395)],
                "obstacles": [
                    [(25, 345), (150, 335), (280, 322), (292, 352), (270, 368), (185, 398), (60, 398), (25, 390)],
                    [(240, 316), (345, 300), (368, 318), (300, 330), (245, 330)],
                    [(430, 350), (470, 330), (600, 325), (625, 345), (620, 398), (450, 400), (425, 385)],
                    [(470, 300), (575, 296), (580, 312), (470, 316)],
                    [(0, 410), (60, 412), (70, 440), (0, 450)],
                ],
                "sorties": [
                    ["porte du fond", "devant", "porte", [(378, 302), (432, 302), (434, 314), (376, 314)], [405, 330, "down"]],
                    ["retour", "bas", "passage", BAS, None],
                ],
                "hauteurs": ((305, 75), (511, 215)), "depart": [400, 470],
            },
            "cuisine": {
                "image": "cuisine.jpeg",
                "marche": [(0, 511), (767, 511), (767, 320), (560, 305), (420, 300), (330, 298), (240, 300), (130, 298),
                           (40, 300), (30, 330), (0, 340)],
                "obstacles": [
                    [(30, 322), (150, 325), (320, 322), (325, 345), (300, 410), (270, 415), (300, 440), (290, 480),
                     (150, 490), (60, 480), (0, 470), (0, 340)],
                    [(240, 288), (405, 288), (410, 297), (240, 297)],
                    [(505, 320), (767, 315), (767, 400), (700, 405), (560, 400), (505, 365)],
                ],
                "sorties": [
                    ["porte de la cuisine", "devant", "porte", [(38, 300), (125, 300), (125, 316), (38, 316)], [140, 310, "right"]],
                    ["retour", "bas", "passage", BAS, None],
                ],
                "hauteurs": ((300, 85), (511, 215)), "depart": [430, 470],
            },
            "petite": {
                "image": "petite porte de la cuisine.jpeg",
                "marche": [(0, 511), (767, 511), (767, 430), (760, 425), (690, 418), (640, 410), (470, 405), (460, 385),
                           (445, 368), (355, 368), (345, 380), (330, 402), (180, 405), (130, 412), (40, 418), (0, 420)],
                "obstacles": [
                    [(0, 418), (48, 416), (50, 445), (0, 448)],
                    [(740, 425), (767, 425), (767, 458), (742, 458)],
                ],
                "sorties": [
                    ["arche du fond", "devant", "passage", [(358, 365), (442, 365), (444, 378), (356, 378)], [400, 395, "down"]],
                    ["porte de gauche", "gauche", "porte", [(55, 410), (128, 410), (130, 424), (52, 424)], [100, 440, "right"]],
                    ["porte de droite", "droite", "porte", [(686, 414), (742, 414), (745, 428), (683, 428)], [705, 445, "left"]],
                    ["retour", "bas", "passage", BAS, None],
                ],
                "hauteurs": ((365, 95), (511, 215)), "depart": [400, 480],
            },
            "cellier_g": {
                "image": "cellier gauche.jpeg",
                "marche": [(0, 511), (767, 511), (767, 450), (730, 420), (690, 412), (600, 400), (560, 375), (360, 372),
                           (320, 368), (280, 380), (210, 395), (160, 430), (60, 445), (0, 450)],
                "obstacles": [
                    [(60, 410), (210, 398), (215, 432), (120, 447), (60, 444)],
                    [(612, 375), (672, 372), (676, 392), (614, 396)],
                    [(680, 395), (740, 390), (745, 415), (690, 417)],
                ],
                "sorties": [["retour", "bas", "passage", BAS, None]],
                "hauteurs": ((370, 100), (511, 210)), "depart": [400, 470],
            },
            "cellier_d": {
                "image": "cellier droit.jpeg",
                "marche": [(0, 511), (767, 511), (767, 485), (690, 472), (660, 432), (660, 398), (610, 378), (560, 357),
                           (450, 347), (400, 350), (330, 366), (270, 382), (205, 388), (205, 450), (60, 462), (0, 470)],
                "obstacles": [
                    [(595, 415), (660, 410), (665, 452), (600, 457)],
                ],
                "sorties": [["retour", "bas", "passage", BAS, None]],
                "hauteurs": ((345, 95), (511, 210)), "depart": [420, 480],
            },
        },
    },
}


def ident(bloc, salle):
    return "bloc_%s_%s" % (bloc, salle)


def donnees_salle(bloc, nom, z):
    (y_a, h_a), (y_b, h_b) = z["hauteurs"]
    pente = (h_b - h_a) / (y_b - y_a)
    i = ident(bloc, nom)
    arrivees = {}
    for s in z["sorties"]:
        if s[4] is not None:
            arrivees[s[0]] = s[4]
    return {
        "fond": "images/salles_peintes/%s/fond.jpeg" % i,
        "fond_hd": "images/salles_peintes/%s/fond_hd.png" % i,
        "perspective": {"y_horizon": round(y_a - h_a / pente), "hauteur_par_pixel": round(pente, 3), "vitesse": 1.8,
                        "compression_profondeur": 0.6, "table_hauteur": [[y_a, h_a], [y_b, h_b]]},
        "depart": z["depart"],
        "marche": [[list(p) for p in z["marche"]]],
        "obstacles": [[list(p) for p in o] for o in z.get("obstacles", [])],
        "premier_plan": [[list(p) for p in o] for o in z.get("premier_plan", [])],
        "sorties": [[list(p) for p in s[3]] for s in z["sorties"]],
        "noms_sorties": [s[0] for s in z["sorties"]],
        "directions_sorties": [s[1] for s in z["sorties"]],
        "types_sorties": [s[2] for s in z["sorties"]],
        "arrivees": arrivees,
        "bloc": bloc,
        "ips": 24,
        "source": "%s/%s" % (os.path.basename(BLOCS[bloc]["source"]), z["image"]),
    }


def planche(bloc, donnees, sources):
    heros = Image.open(HEROS).convert("RGBA")
    heros = heros.crop(heros.getchannel("A").getbbox())
    police = ImageFont.load_default()
    cases = []
    for nom, d in donnees.items():
        im = sources[nom].convert("RGBA")
        calque = Image.new("RGBA", im.size)
        dr = ImageDraw.Draw(calque)
        dr.polygon([tuple(p) for p in d["marche"][0]], fill=(0, 255, 0, 55), outline=(0, 255, 0, 255))
        for o in d["obstacles"]:
            dr.polygon([tuple(p) for p in o], fill=(255, 0, 0, 110))
        couleurs = [(255, 220, 0, 170), (0, 200, 255, 170), (255, 0, 255, 170), (255, 255, 255, 120)]
        for i, s in enumerate(d["sorties"]):
            dr.polygon([tuple(p) for p in s], fill=couleurs[i % 4])
        im = Image.alpha_composite(im, calque)
        (ya, ha), (yb, hb) = d["perspective"]["table_hauteur"]
        points = [tuple(a[:2]) for a in d["arrivees"].values()] + [tuple(d["depart"])]
        for x, y in points:
            h = max(4, int(ha + (y - ya) * (hb - ha) / (yb - ya)))
            w = max(2, int(heros.width * h / heros.height))
            im.alpha_composite(heros.resize((w, h)), (int(x - w / 2), int(y - h)))
        ImageDraw.Draw(im).text((6, 4), "%s : %s" % (ident(bloc, nom), ", ".join(d["noms_sorties"])),
                                fill=(255, 255, 0, 255), font=police)
        cases.append(im.convert("RGB").resize((576, 384)))
    pl = Image.new("RGB", (576 * 2, 384 * ((len(cases) + 1) // 2)), "black")
    for k, c in enumerate(cases):
        pl.paste(c, ((k % 2) * 576, (k // 2) * 384))
    dossier = os.path.join(TRAVAIL, "bloc_" + bloc)
    os.makedirs(dossier, exist_ok=True)
    pl.save(os.path.join(dossier, "planche_zones.png"))


def main():
    from detourer_sols import zones_manuelles
    for bloc, b in BLOCS.items():
        sources = {}
        donnees = {}
        for nom, z in b["salles"].items():
            i = ident(bloc, nom)
            sources[nom] = Image.open(os.path.join(b["source"], z["image"])).convert("RGB")
            assert sources[nom].size == (768, 512), (i, sources[nom].size)
            dossier = os.path.join(IMAGES, i)
            os.makedirs(dossier, exist_ok=True)
            sources[nom].save(os.path.join(dossier, "fond.jpeg"), quality=95)
            donnees[nom] = donnees_salle(bloc, nom, z)
            donnees[nom].update(zones_manuelles(i))  # retouches de l'éditeur de zones
            with open(os.path.join(DONNEES, i + ".json"), "w", encoding="utf8") as f:
                json.dump(donnees[nom], f, ensure_ascii=False, indent=1)
        if "--sans-ia" not in sys.argv:
            from importer_grandes_salles import agrandir
            noms = list(sources)
            for nom, hd in zip(noms, agrandir([sources[n] for n in noms])):
                hd.save(os.path.join(IMAGES, ident(bloc, nom), "fond_hd.png"), optimize=True)
        planche(bloc, donnees, sources)
        print("Bloc %s importé : %d salles" % (bloc, len(donnees)))


if __name__ == "__main__":
    main()
