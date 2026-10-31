"""Copie dans le jeu les animations de combat faites avec Grok (dossier « C:\\ia image »).

À lancer depuis ce dossier ``godot`` après une modification des animations sources :

    python outils/importer_animations.py

Écrit :
- ``images/combat_anime/gobelins/<type>/<anim>_NN.png`` (guerrier, archer, sorcier) : copie des
  images préparées pour le banc d'essai ``Salle de donjon/test_salle/gobelins`` ; le chaman vient de
  ``ennemis/gobelin/gobelin chaman`` (chaman.json), réduit à ``ECHELLE_CHAMAN``, et le féticheur de
  ``ennemis/gobelin/gobelin feticheur`` (pas de json : table ``FETICHEUR``), réduit à ``ECHELLE_FETICHEUR`` ;
- ``images/combat_anime/heros/<arme>/garde_NN.png`` et ``attaque_NN.png`` (épée, marteau, lance,
  vue de dos), ``heros/sort/sort_NN.png`` (lancer de sort), ``heros/touche/touche_NN.png`` et
  ``heros/repos/repos_NN.png`` (sans arme), réduites
  à ``ECHELLE_HEROS`` ;
- ``donnees/combat_anime.json`` : pour chaque animation, nombre d'images, durées (ms), image
  d'impact, boucle, et le point des pieds dans l'image (px) ; hauteur du corps de chaque jeu d'images.

Puis lancer un import Godot (``--import``).
"""
import json
import os
import shutil

from PIL import Image

SOURCE = r"C:\ia image"
GOBELINS = os.path.join(SOURCE, "Salle de donjon", "test_salle", "gobelins")
ATTAQUE = os.path.join(SOURCE, "personnage pour donjon", "animation attaque", "frames")
TOUCHE = os.path.join(SOURCE, "personnage pour donjon", "recevoir dégats", "frames", "up")
REPOS = os.path.join(SOURCE, "personnage pour donjon", "respiration", "frames", "up")
CHAMAN = os.path.join(SOURCE, "ennemis", "gobelin", "gobelin chaman")
FETICHEUR = os.path.join(SOURCE, "ennemis", "gobelin", "gobelin feticheur")
ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMAGES = os.path.join(ICI, "images", "combat_anime")
DONNEES = os.path.join(ICI, "donnees", "combat_anime.json")

ECHELLE_HEROS = 0.75
# Images 448 px du héros (marche, respiration, touché) : pieds en (224, 442), corps de 428 px
# (mesures de test_salle.gd). Les planches d'arme placent cette cellule en « idle_up ».
PIEDS_448 = (224, 442)
CORPS_HEROS = 428
ARMES = {
    "epee": {"idle_up": (132, 192), "garde": "idle/av_sword_idle_%02d.png", "n_garde": 12,
             "attaque": "atk/av_sword_atk_%02d.png", "impact": 5,
             "ms": [80, 60, 40, 40, 40, 40, 40, 50, 50, 60, 70, 80, 90, 110]},
    "marteau": {"idle_up": (132, 192), "garde": "hammer_idle/av_hammer_idle_%02d.png", "n_garde": 12,
                "attaque": "hammer_atk/av_hammer_atk_%02d.png", "impact": 8,
                "ms": [90, 80, 70, 60, 60, 50, 40, 40, 120, 90, 80, 80, 80, 100]},
    # pas d'idle lance fourni (avatar_lance.zip absent) : la garde est la 1re image de l'attaque
    "lance": {"idle_up": (264, 192), "garde": None, "n_garde": 1,
              "attaque": "spear_atk_v2/av_spear_atk_v2_%02d.png", "impact": 7,
              "ms": [90, 80, 80, 80, 120, 40, 40, 40, 40, 180, 120, 90, 90, 100]},
}
MS_TOUCHE = [100, 40, 40, 50, 60, 70, 80, 90, 110]
# Sort (avatar_sort_v2.zip, README(3).txt) : boule de feu lancée vers le fond, cellule 952x728 avec la
# cellule 448 en (240, 220). Relâchée à l'image 9 ; les dégâts du sort s'affichent à l'image 11, quand
# la boule s'éloigne (choix d'affichage, voir README du jeu).
SORT = {"images": "cast_v2/av_cast_v2_%02d.png", "idle_up": (240, 220), "impact": 11,
        "ms": [90, 80, 70, 70, 70, 140, 40, 40, 40, 40, 50, 60, 70, 80, 90, 110]}
# Durée (ms) de chaque image de l'attente, par gobelin, à la place de celle de gobelins.json :
# le guerrier respirait trop vite (110 ms, cycle de 1,3 s) ; 250 ms comme l'archer (cycle de 3 s).
MS_ATTENTE = {"guerrier": 250}
# Chaman (README_chaman_1/2.md) : images 2 fois plus grandes que celles des autres gobelins (corps de
# ~471 px) ; réduites de moitié. Pieds de chaque cellule = (243, 581) + décalage de la cellule idle.
# Lancers : cast1 (boule de feu) relâchée à l'image 10, cast2 (cercle de feu au sol) apparu à
# l'image 8 et au plus large de 11 à 13 : dégâts à l'image 10 pour les deux.
ECHELLE_CHAMAN = 0.5
CHAMAN_ANIMS = {"attente": ("idle", {"boucle": True}), "touche": ("hit", {}), "mort": ("death", {"garder": True}),
                "attaque1": ("cast1", {"impact": 10}), "attaque2": ("cast2", {"impact": 10})}
# Féticheur (README_feticheur_1/2.md, mort/LISEZMOI_mort.txt) : corps de 343 px, réduit à ~240 comme
# les autres gobelins. Pour chaque animation : images (motif relatif au dossier), durées (ms), pieds
# dans la cellule, options. Mort = « death_lift » (relevée pour ne pas passer sous la ligne des pieds),
# dernière image gardée. cast1 (orbe vaudou) lâché à l'image 9, dégâts à 10 ; cast2 (fumée de
# malédiction puis coup au sol) : impact à l'image 10, nuage au plus large à 13 : dégâts à 11.
ECHELLE_FETICHEUR = 0.7
# Taille à l'écran par rapport au cadre du sprite fixe (1 = taille de base) : guerrier un peu plus
# grand, archer et chaman un peu plus petits, féticheur accroupi nettement plus petit.
TAILLES = {"guerrier": 1.1, "archer": 0.8, "sorcier": 1.0, "chaman": 0.92, "feticheur": 0.65}
CORPS_FETICHEUR = 343
FETICHEUR_ANIMS = {
    "attente": ("frames/idle/gf_idle_%02d.png", [250] * 12, (185, 454), {"boucle": True}),
    "touche": ("frames/hit/gf_hit_%02d.png", [80, 40, 40, 50, 60, 70, 80, 90, 90, 100, 100, 110], (185, 454), {}),
    "mort": ("mort/frames/death_lift/gf_death_lift_%02d.png",
             [120, 100, 90, 80, 80, 80, 90, 90, 80, 70, 60, 60, 60, 70, 90, 120, 1500], (276, 496), {"garder": True}),
    "attaque1": ("frames/cast1/gf_cast1_%02d.png",
                 [90, 80, 80, 70, 70, 80, 90, 80, 60, 40, 40, 50, 60, 70, 80, 90, 110], (262, 454), {"impact": 10}),
    "attaque2": ("frames/cast2/gf_cast2_%02d.png",
                 [90, 80, 80, 70, 70, 80, 80, 90, 50, 40, 40, 40, 50, 60, 70, 80, 90, 110], (640, 620), {"impact": 11}),
}


def reduire(src, dst, echelle=ECHELLE_HEROS):
    im = Image.open(src).convert("RGBA")
    im = im.resize((round(im.width * echelle), round(im.height * echelle)), Image.LANCZOS)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    im.save(dst, optimize=True)


def main():
    if os.path.isdir(IMAGES):
        shutil.rmtree(IMAGES)
    donnees = {"gobelins": {}, "heros": {"corps": CORPS_HEROS * ECHELLE_HEROS, "armes": {}}}

    # Gobelins : copie telle quelle ; gobelins.json donne le décalage (x, y) de l'image par rapport
    # aux pieds (Sprite2D non centré) : les pieds sont donc en (-x, -y) dans l'image.
    gob = json.load(open(os.path.join(GOBELINS, "gobelins.json"), encoding="utf-8"))
    for type_, d in gob.items():
        anims = {}
        for nom, a in d["anims"].items():
            for i in range(a["images"]):
                f = "%s_%02d.png" % (nom, i)
                dst = os.path.join(IMAGES, "gobelins", type_, f)
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.copy2(os.path.join(GOBELINS, type_, f), dst)
            ms = a["ms"]
            if nom == "attente" and type_ in MS_ATTENTE:
                ms = [MS_ATTENTE[type_]] * a["images"]
            anims[nom] = {"images": a["images"], "ms": ms, "pieds": [-a["x"], -a["y"]],
                          "impact": a.get("impact", -1), "boucle": a.get("boucle", False),
                          "garder": a.get("garder", False)}
        donnees["gobelins"][type_] = {"corps": d["hauteur_corps"], "anims": anims}

    # Chaman : planches de Grok (frames/<anim>/gs_<anim>_NN.png), réduites.
    cham = json.load(open(os.path.join(CHAMAN, "chaman.json"), encoding="utf-8"))
    anims = {}
    for nom, (src, opts) in CHAMAN_ANIMS.items():
        a = cham["anims"][src]
        for i in range(a["frames"]):
            reduire(os.path.join(CHAMAN, "frames", src, "gs_%s_%02d.png" % (src, i)),
                    os.path.join(IMAGES, "gobelins", "chaman", "%s_%02d.png" % (nom, i)), ECHELLE_CHAMAN)
        pieds = [(243 + a["idle_offset"][0]) * ECHELLE_CHAMAN, (581 + a["idle_offset"][1]) * ECHELLE_CHAMAN]
        anims[nom] = {"images": a["frames"], "ms": a["ms"], "pieds": pieds, "impact": opts.get("impact", -1),
                      "boucle": opts.get("boucle", False), "garder": opts.get("garder", False)}
    corps = sorted(cham["anims"]["idle"]["body_h"])[len(cham["anims"]["idle"]["body_h"]) // 2]
    donnees["gobelins"]["chaman"] = {"corps": corps * ECHELLE_CHAMAN, "anims": anims}

    # Féticheur : images de Grok par animation, réduites.
    anims = {}
    for nom, (motif, ms, pieds, opts) in FETICHEUR_ANIMS.items():
        for i in range(len(ms)):
            reduire(os.path.join(FETICHEUR, motif % i),
                    os.path.join(IMAGES, "gobelins", "feticheur", "%s_%02d.png" % (nom, i)), ECHELLE_FETICHEUR)
        anims[nom] = {"images": len(ms), "ms": ms, "pieds": [pieds[0] * ECHELLE_FETICHEUR, pieds[1] * ECHELLE_FETICHEUR],
                      "impact": opts.get("impact", -1), "boucle": opts.get("boucle", False),
                      "garder": opts.get("garder", False)}
    donnees["gobelins"]["feticheur"] = {"corps": CORPS_FETICHEUR * ECHELLE_FETICHEUR, "anims": anims}

    # Taille à l'écran de chaque gobelin (réglage à l'œil) : la hauteur de corps de référence est
    # divisée d'autant (le jeu dessine le corps à 90 % du cadre du sprite fixe).
    for type_, taille in TAILLES.items():
        donnees["gobelins"][type_]["corps"] /= taille

    # Héros, vue de dos : pieds de la cellule 448 placée en idle_up dans la planche d'arme.
    for arme, d in ARMES.items():
        pieds = [(d["idle_up"][0] + PIEDS_448[0]) * ECHELLE_HEROS, (d["idle_up"][1] + PIEDS_448[1]) * ECHELLE_HEROS]
        for i in range(len(d["ms"])):
            reduire(os.path.join(ATTAQUE, d["attaque"] % i), os.path.join(IMAGES, "heros", arme, "attaque_%02d.png" % i))
        for i in range(d["n_garde"]):
            src = os.path.join(ATTAQUE, d["garde"] % i) if d["garde"] else os.path.join(ATTAQUE, d["attaque"] % 0)
            reduire(src, os.path.join(IMAGES, "heros", arme, "garde_%02d.png" % i))
        donnees["heros"]["armes"][arme] = {
            "garde": {"images": d["n_garde"], "ms": [250] * d["n_garde"], "pieds": pieds, "boucle": True},
            "attaque": {"images": len(d["ms"]), "ms": d["ms"], "pieds": pieds, "impact": d["impact"]},
        }
    pieds_448 = [PIEDS_448[0] * ECHELLE_HEROS, PIEDS_448[1] * ECHELLE_HEROS]
    for i in range(len(MS_TOUCHE)):
        reduire(os.path.join(TOUCHE, "hit_up_%d.png" % i), os.path.join(IMAGES, "heros", "touche", "touche_%02d.png" % i))
    for i in range(12):
        reduire(os.path.join(REPOS, "idle_up_%d.png" % i), os.path.join(IMAGES, "heros", "repos", "repos_%02d.png" % i))
    for i in range(len(SORT["ms"])):
        reduire(os.path.join(ATTAQUE, SORT["images"] % i), os.path.join(IMAGES, "heros", "sort", "sort_%02d.png" % i))
    donnees["heros"]["sort"] = {"images": len(SORT["ms"]), "ms": SORT["ms"], "impact": SORT["impact"],
                                "pieds": [(SORT["idle_up"][0] + PIEDS_448[0]) * ECHELLE_HEROS,
                                          (SORT["idle_up"][1] + PIEDS_448[1]) * ECHELLE_HEROS]}
    donnees["heros"]["touche"] = {"images": len(MS_TOUCHE), "ms": MS_TOUCHE, "pieds": pieds_448}
    donnees["heros"]["repos"] = {"images": 12, "ms": [300] * 12, "pieds": pieds_448, "boucle": True}

    # Chevalier de la mort (ses propres réglages : importer_combat_chevalier.py)
    import importer_combat_chevalier
    importer_combat_chevalier.main_ajout(donnees)

    with open(DONNEES, "w", encoding="utf-8") as f:
        json.dump(donnees, f, ensure_ascii=False, indent=1)
    print("Animations importées dans", IMAGES)


if __name__ == "__main__":
    main()
