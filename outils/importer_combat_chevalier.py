"""Animations de combat du Chevalier de la mort (faites avec Grok, ``C:\\ia image\\ennemis\\chevalier de la mort``).

- ``attaque/attaque_1_vertical_A`` et ``_B`` : deux coups d'épée de haut en bas → « attaque1 », « attaque2 » ;
- ``recevoir dégats/attaque_2_horizontal_A`` et ``_B`` : il lève l'épée à l'horizontale devant lui (une parade) →
  « touche1 », « touche2 » : la garde monte, tient un instant, puis redescend (les mêmes images à l'envers, par
  la liste ``ordre``), pour revenir à la pose de repos sans saut. ``impact`` = garde levée : le combat la lance assez
  tôt pour qu'elle soit en place quand le coup du héros arrive ;
- « attente » : la première image de l'attaque A (il se tient debout, épée basse), qui respire.

Sources : cellules 1024 × 1016 identiques pour les 4 animations (caméra fixe, mêmes pieds), 24 images/s. **Toutes**
les images sont gardées (2026-10-27 : une sur deux donnait des à-coups), jouées un peu plus vite que l'original
(``MS_ATTAQUE``, ``MS_GARDE``), recadrées sur une même boîte (union des contours) et réduites à ``ECHELLE``.
Point d'ancrage : le milieu du casque dans la pose de repos (le bas de l'image mêle cape et pointe d'épée).
Les .png reçoivent un .import compressé pour la carte graphique (BPTC, sans mipmaps : 4 fois moins de mémoire).
Retours en garde (Grok, 2026-10-27, ``retour/``) : chaque attaque se termine en revenant à la pose de repos
(``retour_A``, ``retour_B`` : leur première image est la dernière de l'attaque, leur dernière la pose de repos) ;
l'attaque B commence par ``retour/bonus_debut_B`` (de la pose de repos au début de l'attaque B). Plus de fondu.
Écrit ``images/combat_anime/gobelins/chevalier/<anim>_NN.png`` et l'entrée « chevalier » de ``donnees/combat_anime.json``.

Usage : ``python outils/importer_combat_chevalier.py`` (aussi appelé par ``importer_animations.py``), puis
``Godot --headless --path . --import``.
"""
import glob
import json
import os

from PIL import Image

SOURCE = r"C:\ia image\ennemis\chevalier de la mort"
ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMAGES = os.path.join(ICI, "images", "combat_anime", "gobelins", "chevalier")
DONNEES = os.path.join(ICI, "donnees", "combat_anime.json")
ECHELLE = 0.5
MS_ATTAQUE = 34     # original : 41,5 ms (24 images/s)
MS_GARDE = 28
TENUE_MS = 300      # garde tenue avant de redescendre
# Repères relevés à l'œil sur les images sources : coup porté (attaques), garde levée (parades). Attaques : [avant,
# attaque, retour] (dossiers ; « avant » et « retour » peuvent manquer), image du coup dans l'attaque.
ATTAQUES = {"attaque1": ([None, "attaque/attaque_1_vertical_A", "retour/retour_A"], 76),
            "attaque2": (["retour/bonus_debut_B", "attaque/attaque_1_vertical_B", "retour/retour_B"], 56)}
GARDES = {"touche1": ("recevoir dégats/attaque_2_horizontal_A", 36), "touche2": ("recevoir dégats/attaque_2_horizontal_B", 42)}
# Hauteur du corps (casque → pieds) dans la pose de repos, en pixels sources.
CORPS_SOURCE = 621
IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/high_quality=true
mipmaps/generate=false
process/fix_alpha_border=true
"""


def images(dossier):
    return sorted(glob.glob(os.path.join(SOURCE, dossier, "frame_*.png")))


def main_ajout(donnees):
    toutes = {nom: images(d) for nom, (d, _r) in GARDES.items()}
    debut_attaque = {}
    for nom, (dossiers, _coup) in ATTAQUES.items():
        avant, attaque, retour = [images(d) if d else [] for d in dossiers]
        # La première image d'un retour est la dernière de l'attaque : pas de doublon
        toutes[nom] = avant + attaque + retour[1:]
        debut_attaque[nom] = len(avant)
    gardes = {nom: toutes[nom][:levee + 1] for nom, (_d, levee) in GARDES.items()}
    # Boîte commune : union des contours de toutes les images utilisées
    boite = None
    for nom, liste in toutes.items():
        for f in (gardes[nom] if nom in gardes else liste):
            b = Image.open(f).getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
            if b:
                boite = b if boite is None else (min(boite[0], b[0]), min(boite[1], b[1]), max(boite[2], b[2]), max(boite[3], b[3]))
    x0, y0, x1, y1 = boite
    # Ancrage : milieu du casque (60 lignes sous le haut de la silhouette) et bas des pieds, pose de repos
    repos = Image.open(toutes["attaque1"][0]).getchannel("A")
    haut, bas = repos.getbbox()[1], repos.getbbox()[3]
    xs = [x for y in range(haut + 10, haut + 70) for x in range(repos.width) if repos.getpixel((x, y)) > 128]
    pieds = [((sum(xs) / len(xs)) - x0) * ECHELLE, (bas - y0) * ECHELLE]
    os.makedirs(IMAGES, exist_ok=True)
    for f in glob.glob(os.path.join(IMAGES, "*.png")) + glob.glob(os.path.join(IMAGES, "*.png.import")):
        os.remove(f)

    def ecrire(nom, sources):
        for i, f in enumerate(sources):
            im = Image.open(f).convert("RGBA").crop((x0, y0, x1, y1))
            im = im.resize((round(im.width * ECHELLE), round(im.height * ECHELLE)), Image.LANCZOS)
            chemin = os.path.join(IMAGES, "%s_%02d.png" % (nom, i))
            im.save(chemin, optimize=True)
            with open(chemin + ".import", "w", encoding="utf-8") as g:
                g.write(IMPORT)

    anims = {}
    ecrire("attente", [toutes["attaque1"][0]])
    anims["attente"] = {"images": 1, "ms": [1000], "pieds": pieds, "impact": -1, "boucle": True, "garder": False}
    for nom, (_d, coup) in ATTAQUES.items():
        sources = toutes[nom]
        ecrire(nom, sources)
        anims[nom] = {"images": len(sources), "ms": [MS_ATTAQUE] * len(sources), "pieds": pieds,
                      "impact": debut_attaque[nom] + coup, "boucle": False, "garder": False}
    for nom, (_d, levee) in GARDES.items():
        montee = gardes[nom]
        ecrire(nom, montee)
        ordre = list(range(len(montee))) + list(range(len(montee) - 2, -1, -1))
        ms = [MS_GARDE] * len(ordre)
        ms[len(montee) - 1] = TENUE_MS
        anims[nom] = {"images": len(ordre), "ms": ms, "ordre": ordre, "pieds": pieds, "impact": levee,
                      "boucle": False, "garder": False}
    donnees["gobelins"]["chevalier"] = {"corps": CORPS_SOURCE * ECHELLE, "anims": anims}
    fichiers = 1 + sum(len(toutes[n]) for n in ATTAQUES) + sum(len(g) for g in gardes.values())
    print("Attaques : %s images (coup à l'image %s)" % ({n: anims[n]["images"] for n in ATTAQUES},
                                                        {n: anims[n]["impact"] for n in ATTAQUES}))
    print("Chevalier : %d fichiers, boîte %s, pieds %s" % (fichiers, boite, [round(v, 1) for v in pieds]))


def main():
    donnees = json.load(open(DONNEES, encoding="utf-8"))
    main_ajout(donnees)
    with open(DONNEES, "w", encoding="utf-8") as f:
        json.dump(donnees, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
