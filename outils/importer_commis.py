"""Importe les animations de repos des deux commis (2026-11-04, images de l'utilisateur).

Source : ``C:\\ia image\\ennemis\\cuisinière et commits\\commit 0X\\idle_front`` (frame_000.png ..., frames.json :
« anchor » = bas des pieds). Chaque image est recadrée autour du milieu des deux pieds (même cadre pour toutes les
images : les pieds restent au milieu du bas), réduite à HAUTEUR px de haut, et écrite dans
``images/pnj/<nom>_anim/repos_000.png`` ... avec ``animations.json`` ({images, fps}).

    python outils/importer_commis.py
"""
import json
import os
import sys

from PIL import Image

SOURCE = r"C:\ia image\ennemis\cuisinière et commits"
# commis 02 (louche à la main) : cuisine ; commis 01 : cellier
COMMIS = {"commis_cuisine": "commit 02", "commis_cellier": "commit 01"}
HAUTEUR = 320
ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def importer(nom: str, dossier: str) -> None:
    src = os.path.join(SOURCE, dossier, "idle_front")
    info = json.load(open(os.path.join(src, "frames.json"), encoding="utf8"))
    ax, ay = info["anchor"]
    n = int(info["frame_count"])
    images = [Image.open(os.path.join(src, "frame_%03d.png" % k)).convert("RGBA") for k in range(n)]
    # Cadre commun : tout ce qui n'est pas transparent, symétrique autour des pieds
    gauche, haut, droite = 10 ** 6, 10 ** 6, 0
    for im in images:
        a = im.getchannel("A").point(lambda v: 255 if v > 24 else 0)
        b = a.getbbox()
        if b:
            gauche, haut, droite = min(gauche, b[0]), min(haut, b[1]), max(droite, b[2])
    # Milieu des deux pieds (l'« anchor » de frames.json est sur un pied) : opaque des 12 % du bas, en moyenne
    centres = []
    for im in images:
        bas = im.crop((0, int(ay - 0.12 * (ay - haut)), im.width, ay)).getchannel("A").point(lambda v: 255 if v > 24 else 0)
        b = bas.getbbox()
        if b:
            centres.append((b[0] + b[2]) / 2)
    ax = round(sum(centres) / len(centres)) if centres else ax
    demi = max(ax - gauche, droite - ax) + 2
    cadre = (ax - demi, haut, ax + demi, ay)
    h = ay - haut
    echelle = HAUTEUR / h
    taille = (max(1, round(2 * demi * echelle)), HAUTEUR)
    sortie = os.path.join(ICI, "images", "pnj", nom + "_anim")
    os.makedirs(sortie, exist_ok=True)
    for k, im in enumerate(images):
        fond = Image.new("RGBA", (2 * demi, h), (0, 0, 0, 0))
        fond.paste(im.crop((max(0, cadre[0]), cadre[1], min(im.width, cadre[2]), cadre[3])),
                   (max(0, -cadre[0]), 0))
        fond.resize(taille, Image.LANCZOS).save(os.path.join(sortie, "repos_%03d.png" % k), optimize=True)
    json.dump({"images": n, "fps": int(info.get("fps", 24)), "taille": list(taille), "source": src},
              open(os.path.join(sortie, "animations.json"), "w", encoding="utf8"), ensure_ascii=False, indent=1)
    print(nom, n, "images", taille)


if __name__ == "__main__":
    for nom, dossier in COMMIS.items():
        if len(sys.argv) < 2 or nom in sys.argv[1:]:
            importer(nom, dossier)
