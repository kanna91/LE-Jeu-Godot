"""Zones des salles peintes en ligne de commande (pour Grok Bot ou tout autre assistant ; notice : GROK_ZONES.md).

Même effet que l'éditeur du jeu (scenes/outils/editeur_zones.tscn) : chaque modification écrit
``donnees/salles_peintes/<id>.json`` et ``outils/zones_manuelles/<id>.json`` (prioritaire sur le détourage
automatique et la maquette 3D). Avant chaque modification, l'état précédent est gardé dans
``outils/zones_manuelles/historique/`` (commande ``annuler``).

Coordonnées : pixels de l'image de fond de la salle (768 × 512, origine en haut à gauche, y vers le bas).

Commandes (``python outils/zones.py <commande> ...``) :
  salles                                  liste des salles
  voir <salle> [x0 y0 x1 y1]              image des zones (+ quadrillage chiffré) ; une zone précise si donnée
  lister <salle> [couche]                 les polygones, numérotés, en JSON
  ajouter <salle> <couche> "x,y x,y ..."  nouvelle zone (au moins 3 points ; pas pour « sorties »)
  remplacer <salle> <couche> <i> "x,y ..."  remplace la zone n° i par ces points
  retirer <salle> <couche> <i>            retire la zone n° i (pas pour « sorties »)
  deplacer <salle> <couche> <i> <j> <x> <y>  déplace le point j de la zone i
  couche <salle> <couche> <fichier.json>  remplace toute la couche ([[[x,y],...], ...])
  annuler <salle>                         revient à l'état d'avant la dernière modification
  verifier <salle>                        le héros court partout dans la salle (Godot) : « BILAN ... 0 échec(s) »
Couches : marche (sol, vert), obstacles (rouge), premier_plan (bleu), sorties (jaune).
"""
import datetime
import glob
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DONNEES = os.path.join(ICI, "donnees", "salles_peintes")
MANUELLES = os.path.join(ICI, "outils", "zones_manuelles")
HISTORIQUE = os.path.join(MANUELLES, "historique")
IMAGES = r"C:\IA\pont-blender\zones"
GODOT = r"C:\jeux\Godot\Godot_v4.7.2-stable_win64_console.exe"
COUCHES = ["marche", "obstacles", "premier_plan", "sorties"]
COULEURS = {"marche": (60, 255, 90), "obstacles": (255, 60, 50), "premier_plan": (70, 150, 255), "sorties": (255, 225, 40)}
OVERRIDE = "[display]\nwindow/size/no_focus=true\nwindow/size/initial_position_type=0\n" \
           "window/size/initial_position=Vector2i(-4000, -4000)\n"


def erreur(texte):
    print("ERREUR : " + texte)
    sys.exit(1)


def lire(salle):
    chemin = os.path.join(DONNEES, salle + ".json")
    if not os.path.exists(chemin):
        erreur("salle inconnue « %s » (voir : python outils/zones.py salles)" % salle)
    return json.load(open(chemin, encoding="utf8"))


def ecrire(salle, info, avant):
    os.makedirs(HISTORIQUE, exist_ok=True)
    horodatage = datetime.datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    with open(os.path.join(HISTORIQUE, "%s_%s.json" % (salle, horodatage)), "w", encoding="utf8") as f:
        json.dump({c: avant.get(c, []) for c in COUCHES}, f)
    with open(os.path.join(DONNEES, salle + ".json"), "w", encoding="utf8") as f:
        json.dump(info, f, ensure_ascii=False, indent=1)
    with open(os.path.join(MANUELLES, salle + ".json"), "w", encoding="utf8") as f:
        json.dump({c: info.get(c, []) for c in COUCHES}, f)


def points(texte):
    pts = []
    for morceau in texte.replace(";", " ").split():
        try:
            x, y = morceau.split(",")
            pts.append([int(round(float(x))), int(round(float(y)))])
        except ValueError:
            erreur("point illisible « %s » (attendu : x,y)" % morceau)
    return pts


def couche_valide(c):
    if c not in COUCHES:
        erreur("couche inconnue « %s » (couches : %s)" % (c, ", ".join(COUCHES)))
    return c


def indice(info, c, i):
    i = int(i)
    if not 0 <= i < len(info.get(c, [])):
        erreur("pas de zone n° %d dans « %s » (0 à %d)" % (i, c, len(info.get(c, [])) - 1))
    return i


def modifier(salle, action):
    info = lire(salle)
    avant = json.loads(json.dumps({c: info.get(c, []) for c in COUCHES}))
    action(info)
    L, H = Image.open(os.path.join(ICI, info["fond"])).size
    for c in COUCHES:
        for poly in info.get(c, []):
            if len(poly) < 3:
                erreur("une zone de « %s » aurait moins de 3 points : rien n'est changé" % c)
            for x, y in poly:
                if not (0 <= x <= L and 0 <= y <= H):
                    erreur("point %d,%d hors de l'image (%d × %d) : rien n'est changé" % (x, y, L, H))
    if len(info["sorties"]) != len(avant["sorties"]):
        erreur("le nombre de sorties ne peut pas changer : rien n'est changé")
    ecrire(salle, info, avant)
    print("OK : %s enregistrée. Regarder le résultat : python outils/zones.py voir %s" % (salle, salle))


def voir(salle, cadre=None):
    info = lire(salle)
    fond = Image.open(os.path.join(ICI, info["fond"])).convert("RGBA")
    L, H = fond.size
    x0, y0, x1, y1 = cadre or (0, 0, L, H)
    k = max(1, round(1536 / max(1, x1 - x0)))  # image finale d'environ 1536 px de large
    calque = Image.new("RGBA", fond.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(calque)
    for c in COUCHES:
        for poly in info.get(c, []):
            pts = [tuple(p) for p in poly]
            d.polygon(pts, fill=COULEURS[c] + (55,))
    im = Image.alpha_composite(fond, calque).crop((x0, y0, x1, y1)).resize(((x1 - x0) * k, (y1 - y0) * k), Image.LANCZOS)
    d = ImageDraw.Draw(im)
    try:
        police = ImageFont.truetype("arial.ttf", 13)
        police_n = ImageFont.truetype("arialbd.ttf", 15)
    except OSError:
        police = police_n = ImageFont.load_default()
    pas = 16 if (x1 - x0) <= 256 else 32
    for x in range((x0 // pas + 1) * pas, x1, pas):
        d.line([((x - x0) * k, 0), ((x - x0) * k, im.height)], fill=(255, 255, 255, 60 if x % 128 else 140), width=1)
        d.text(((x - x0) * k + 2, 2), str(x), fill=(255, 255, 255), font=police, stroke_width=2, stroke_fill=(0, 0, 0))
    for y in range((y0 // pas + 1) * pas, y1, pas):
        d.line([(0, (y - y0) * k), (im.width, (y - y0) * k)], fill=(255, 255, 255, 60 if y % 128 else 140), width=1)
        d.text((2, (y - y0) * k + 2), str(y), fill=(255, 255, 255), font=police, stroke_width=2, stroke_fill=(0, 0, 0))
    for c in COUCHES:
        for i, poly in enumerate(info.get(c, [])):
            pts = [((p[0] - x0) * k, (p[1] - y0) * k) for p in poly]
            d.line(pts + [pts[0]], fill=COULEURS[c], width=2)
            for p in pts:
                d.ellipse([p[0] - 3, p[1] - 3, p[0] + 3, p[1] + 3], fill=COULEURS[c], outline=(0, 0, 0))
            cx = sum(p[0] for p in pts) / len(pts)
            cy = sum(p[1] for p in pts) / len(pts)
            nom = {"marche": "S", "obstacles": "O", "premier_plan": "P", "sorties": "X"}[c] + str(i)
            d.text((cx, cy), nom, fill=COULEURS[c], font=police_n, stroke_width=3, stroke_fill=(0, 0, 0), anchor="mm")
    os.makedirs(IMAGES, exist_ok=True)
    nom = salle + ("" if cadre is None else "_%d_%d_%d_%d" % tuple(cadre)) + ".png"
    chemin = os.path.join(IMAGES, nom)
    im.convert("RGB").save(chemin)
    print("Image : " + chemin)
    print("Étiquettes : S = sol (marche), O = obstacle, P = premier plan, X = sortie, suivies du n° de la zone.")
    print("Quadrillage : coordonnées de l'image de fond (%d × %d)." % (L, H))


def lister(salle, c=None):
    info = lire(salle)
    for couche in ([couche_valide(c)] if c else COUCHES):
        print("== %s (%d zone(s))" % (couche, len(info.get(couche, []))))
        for i, poly in enumerate(info.get(couche, [])):
            print("  %d : %s" % (i, " ".join("%d,%d" % (p[0], p[1]) for p in poly)))


def annuler(salle):
    lire(salle)
    copies = sorted(glob.glob(os.path.join(HISTORIQUE, salle + "_*.json")))
    if not copies:
        erreur("rien à annuler pour " + salle)
    dernier = copies[-1]
    info = lire(salle)
    info.update(json.load(open(dernier, encoding="utf8")))
    with open(os.path.join(DONNEES, salle + ".json"), "w", encoding="utf8") as f:
        json.dump(info, f, ensure_ascii=False, indent=1)
    with open(os.path.join(MANUELLES, salle + ".json"), "w", encoding="utf8") as f:
        json.dump({c: info.get(c, []) for c in COUCHES}, f)
    os.remove(dernier)
    print("OK : dernière modification de %s annulée (%d annulation(s) encore possible(s))" % (salle, len(copies) - 1))


def verifier(salle):
    lire(salle)
    cfg = os.path.join(ICI, "override.cfg")
    deja = os.path.exists(cfg)
    if not deja:
        with open(cfg, "w") as f:
            f.write(OVERRIDE)
    try:
        r = subprocess.run([GODOT, "--path", ICI, "-s", "tests/test_collisions_salles.gd", "--", salle],
                           capture_output=True, text=True, encoding="utf8", errors="replace", timeout=900)
    finally:
        if not deja:
            os.remove(cfg)
    for ligne in r.stdout.splitlines():
        if ligne.startswith(("ÉCHEC", "BILAN", "ok", "  ")) or salle in ligne:
            print(ligne)


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        return
    cmd = a[0]
    if cmd == "salles":
        print(" ".join(sorted(os.path.splitext(f)[0] for f in os.listdir(DONNEES) if f.endswith(".json"))))
    elif cmd == "voir" and len(a) in (2, 6):
        voir(a[1], tuple(int(v) for v in a[2:6]) if len(a) == 6 else None)
    elif cmd == "lister" and len(a) in (2, 3):
        lister(a[1], a[2] if len(a) == 3 else None)
    elif cmd == "ajouter" and len(a) == 4:
        c = couche_valide(a[2])
        if c == "sorties":
            erreur("on ne crée pas de sortie (leur nombre compte pour le plan du donjon) ; utiliser remplacer ou deplacer")
        pts = points(a[3])
        modifier(a[1], lambda info: info.setdefault(c, []).append(pts))
    elif cmd == "remplacer" and len(a) == 5:
        c = couche_valide(a[2])
        pts = points(a[4])

        def f(info):
            info[c][indice(info, c, a[3])] = pts
        modifier(a[1], f)
    elif cmd == "retirer" and len(a) == 4:
        c = couche_valide(a[2])
        if c == "sorties":
            erreur("on ne retire pas de sortie (leur nombre compte pour le plan du donjon)")
        modifier(a[1], lambda info: info[c].pop(indice(info, c, a[3])))
    elif cmd == "deplacer" and len(a) == 7:
        c = couche_valide(a[2])

        def f(info):
            poly = info[c][indice(info, c, a[3])]
            j = int(a[4])
            if not 0 <= j < len(poly):
                erreur("pas de point n° %d dans cette zone (0 à %d)" % (j, len(poly) - 1))
            poly[j] = [int(round(float(a[5]))), int(round(float(a[6])))]
        modifier(a[1], f)
    elif cmd == "couche" and len(a) == 4:
        c = couche_valide(a[2])
        polys = json.load(open(a[3], encoding="utf8"))
        polys = [[[int(round(p[0])), int(round(p[1]))] for p in poly] for poly in polys]

        def f(info):
            info[c] = polys
        modifier(a[1], f)
    elif cmd == "annuler" and len(a) == 2:
        annuler(a[1])
    elif cmd == "verifier" and len(a) == 2:
        verifier(a[1])
    else:
        print(__doc__)
        erreur("commande ou nombre d'arguments incorrect")


if __name__ == "__main__":
    main()
