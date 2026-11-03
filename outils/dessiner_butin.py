"""Dessine les images du butin posé au sol (onglet « Butin » de l'éditeur de zones, 2026-11-03).

    python outils/dessiner_butin.py

Écrit images/objets_salles/butin_or.png (tas de pièces), butin_potion.png (fiole) et butin_sac.png (sac de toile,
pour les autres catégories). Images provisoires dessinées par programme, à remplacer par de vraies images si
l'utilisateur le souhaite (même nom de fichier, fond transparent, pied de l'objet en bas de l'image).
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SORTIE = os.path.join(ICI, "images", "objets_salles")
T = 256  # dessin en 256 px, réduit de moitié (bords lissés)


def finir(im, nom):
    im = im.resize((T // 2, T // 2), Image.LANCZOS)
    boite = im.getbbox()
    if boite:  # le pied de l'objet touche le bas de l'image
        im = im.crop((0, boite[1] - 2, im.width, boite[3]))
    im.save(os.path.join(SORTIE, nom))
    print("écrit", nom, im.size)


def tas_or():
    random.seed(4)
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pieces = []
    for rangee, (n, y, largeur) in enumerate([(7, 220, 170), (5, 200, 130), (3, 182, 80), (1, 166, 0)]):
        for k in range(n):
            x = T / 2 - largeur / 2 + (largeur * k / max(1, n - 1) if n > 1 else 0) + random.uniform(-6, 6)
            pieces.append((x, y + random.uniform(-4, 4)))
    for x, y in pieces:
        d.ellipse((x - 26, y - 11, x + 26, y + 11), fill=(120, 80, 10, 255))
        d.ellipse((x - 26, y - 15, x + 26, y + 7), fill=(225, 175, 45, 255), outline=(150, 100, 15, 255), width=3)
        d.ellipse((x - 15, y - 10, x + 9, y + 1), outline=(255, 230, 130, 255), width=3)
    finir(im, "butin_or.png")


def fiole():
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx = T / 2
    d.ellipse((cx - 58, 120, cx + 58, 236), fill=(150, 25, 40, 235), outline=(60, 20, 25, 255), width=5)
    d.rectangle((cx - 16, 66, cx + 16, 128), fill=(170, 190, 200, 160), outline=(60, 70, 80, 255), width=4)
    d.rectangle((cx - 20, 48, cx + 20, 70), fill=(120, 80, 40, 255), outline=(60, 40, 20, 255), width=3)
    d.ellipse((cx - 34, 140, cx - 8, 180), fill=(255, 180, 180, 150))
    finir(im, "butin_potion.png")


def sac():
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx = T / 2
    corps = []
    for k in range(40):
        a = math.pi * 2 * k / 40
        r = 78 + 6 * math.sin(a * 3)
        corps.append((cx + math.cos(a) * r, 170 + math.sin(a) * r * 0.72))
    d.polygon(corps, fill=(135, 105, 70, 255), outline=(70, 50, 30, 255))
    d.polygon([(cx - 26, 118), (cx + 26, 118), (cx + 40, 80), (cx + 10, 92), (cx - 8, 76), (cx - 38, 86)],
              fill=(150, 118, 80, 255), outline=(70, 50, 30, 255))
    d.line([(cx - 30, 120), (cx + 30, 120)], fill=(80, 55, 30, 255), width=8)
    d.arc((cx - 60, 130, cx + 20, 210), 200, 280, fill=(170, 140, 100, 255), width=5)
    im = im.filter(ImageFilter.SMOOTH)
    finir(im, "butin_sac.png")


if __name__ == "__main__":
    tas_or()
    fiole()
    sac()
