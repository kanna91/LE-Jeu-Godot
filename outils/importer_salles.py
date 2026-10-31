"""Copie dans le jeu les salles peintes du banc d'essai « test_salle » (dossier « C:\\ia image »).

À lancer depuis ce dossier ``godot`` après une modification des salles (zones retouchées avec l'éditeur
de test_salle, nouveau décor animé...) :

    python outils/importer_salles.py

Écrit :
- ``donnees/salles_peintes/<id>.json`` (salle1, salle2, porte1 … porte6, culdesac1 … culdesac7) : la description de chaque
  salle (sol, obstacles, premier plan, sorties, perspective...), chemins réécrits vers les copies du
  jeu, plus ``directions_sorties`` (direction de chaque sortie vue du bas de l'image : « devant »,
  « gauche », « droite » ou « bas ») ; une sortie « bas » (retour) est ajoutée aux salles qui n'en ont
  pas (salle 1, salle 2, salle porte 1) ;
- ``images/salles_peintes/<id>/`` : image fixe, décor animé ``decor.ogv`` (la vidéo d'origine de la
  salle convertie en Theora, pleine résolution, sans son ; depuis le 2026-10-19, à la place des centaines
  d'images JPG compressées en DXT1, trop dégradées), masque de premier plan (pas de son : retiré le
  2026-10-18) ;
- ``images/salles_peintes/<id>/portes/<porte>/NNN.png`` : les portes qui s'ouvrent (``PORTES_ANIMEES``),
  décrites dans ``portes_animees`` du .json (cadre en pixels de l'image fixe, sortie, nombre d'images) ;
- ``images/salles_peintes/heros/{marche,course,respiration}/<direction>/`` : le héros en 8 directions.

Pas d'import Godot à faire : ces images sont lues à l'exécution (``.gdignore`` dans le dossier).
"""
import json
import os
import shutil

SOURCE = r"C:\ia image"
TEST_SALLE = os.path.join(SOURCE, "Salle de donjon", "test_salle")
HEROS = os.path.join(SOURCE, "personnage pour donjon")
ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMAGES = os.path.join(ICI, "images", "salles_peintes")
DONNEES = os.path.join(ICI, "donnees", "salles_peintes")

# Fichier de test_salle → identifiant dans le jeu, et direction de chaque sortie (dans l'ordre du .json,
# puis « bas » ajouté si la salle n'a pas de retour par le bas de l'image).
SALLES = {
    "salle.json": ("salle1", ["devant"]),
    "salle2.json": ("salle2", ["devant"]),
    "porte1.json": ("porte1", ["devant"]),
    "porte2.json": ("porte2", ["devant", "bas", "gauche", "gauche"]),
    "porte3.json": ("porte3", ["droite", "devant", "bas", "gauche"]),
    "porte4.json": ("porte4", ["devant", "bas", "devant"]),
    "porte5.json": ("porte5", ["devant", "gauche", "bas"]),
    "porte6.json": ("porte6", ["devant", "gauche", "bas", "gauche"]),
    # Cul-de-sac (2026-10-18) : le passage finit sur un précipice, seule sortie le bas de l'image
    **{"culdesac%d.json" % i: ("culdesac%d" % i, ["bas"]) for i in range(1, 8)},
}
# Sorties de test_salle qui ne deviennent pas des sorties du jeu : porte trop peu visible sur l'image
# (salle porte 1 : la porte de gauche est cachée dans l'ombre derrière le pilier ; utilisée pour un
# virage, la salle ressemblait à un couloir fermé). Leurs directions ne figurent pas dans SALLES.
SORTIES_CACHEES = {
    "porte1.json": ["porte de gauche"],
}
# Vidéo d'origine du décor animé de chaque salle (même cadrage que l'image fixe, vérifié le 2026-10-19).
# Convertie en Theora (seul format vidéo que Godot lit), qualité QUALITE_VIDEO (0 à 10).
SALLES_DE_DONJON = os.path.join(SOURCE, "Salle de donjon")
VIDEOS = {
    "salle.json": os.path.join("salle 1", "decor_anime_v2.mp4"),
    "salle2.json": os.path.join("salle 2", "decor_feu.mp4"),
    **{"porte%d.json" % i: os.path.join("salle porte %d" % i, "salle%d_boucle.mp4" % i) for i in range(1, 7)},
    **{"culdesac%d.json" % i: os.path.join("salle cul de sac %d" % i, "couloir%d_boucle.mp4" % i) for i in range(1, 8)},
}
QUALITE_VIDEO = 9
# Portes qui s'ouvrent (2026-10-20) : animations découpées sur la vidéo de la salle
# (« salle porte N/portes_animees/<id>/ » : <id>.json donne le cadre x, y, w, h en pixels de la vidéo
# 1088 × 720, rgba/<id>_###.png les images, transparentes là où rien ne bouge). Fichier de test_salle →
# {id de l'animation : nom de la sortie}. La porte de gauche de la salle porte 1 (porte1_gauche) n'est
# pas une sortie du jeu (SORTIES_CACHEES).
PORTES_ANIMEES = {
    "porte1.json": {"porte1": "grande porte"},
    "porte2.json": {"P2-1": "porte du fond", "P2-2": "porte de gauche"},
    "porte3.json": {"P3-2": "couloir du fond"},
    "porte4.json": {"P4-1": "porte du mur"},
    "porte5.json": {"P5-1": "grande porte", "P5-2": "porte de gauche"},
}
# Les images des portes sont réduites à l'échelle de l'affichage (la vidéo 1088 × 720 est montrée en
# 810 × 540) : deux fois moins de pixels, sans perte visible.
ECHELLE_PORTES = 0.75
HEROS_DOSSIERS = {
    "course": os.path.join(HEROS, "animation de course", "frames"),
    "marche": os.path.join(HEROS, "marche", "frames"),
    "respiration": os.path.join(HEROS, "respiration", "frames"),
}
# Hauteur de la bande de sortie « bas » ajoutée (px de l'image de fond) : le bas du sol praticable.
BANDE_BAS = 12


def source(relatif):
    """Chemin d'un fichier cité par un .json de test_salle (relatif à ce dossier).

    Si le fichier a été rangé ailleurs depuis (l'image de la salle 1 est passée du dossier « Salle de donjon »
    à son sous-dossier « salle 1 »), il est cherché par son nom dans les dossiers des salles.
    """
    chemin = os.path.normpath(os.path.join(TEST_SALLE, relatif))
    if os.path.isfile(chemin):
        return chemin
    nom = os.path.basename(chemin)
    for dossier in sorted(os.listdir(SALLES_DE_DONJON)):
        candidat = os.path.join(SALLES_DE_DONJON, dossier, nom)
        if os.path.isfile(candidat):
            return candidat
    return chemin


def copier(depuis, vers):
    os.makedirs(os.path.dirname(vers), exist_ok=True)
    shutil.copy2(depuis, vers)


def copier_dossier(depuis, vers):
    if os.path.isdir(vers):
        shutil.rmtree(vers)
    shutil.copytree(depuis, vers)


def ajouter_sortie_bas(salle):
    """Bande de sortie au bas du sol praticable, sous la position de départ."""
    points = [p for poly in salle["marche"] for p in poly]
    bas = max(p[1] for p in points)
    haut = max(bas - BANDE_BAS, salle["depart"][1] + 8)
    gauche = min(p[0] for p in points)
    droite = max(p[0] for p in points)
    salle["sorties"].append([[gauche, haut], [droite, haut], [droite, bas + 6], [gauche, bas + 6]])
    noms = salle.get("noms_sorties") or [salle.get("nom_sortie", "porte du fond")] * (len(salle["sorties"]) - 1)
    salle["noms_sorties"] = noms + ["retour"]


def convertir_video(depuis, vers):
    """mp4 → ogv (Theora, sans son), seulement si la source est plus récente que la copie."""
    if os.path.isfile(vers) and os.path.getmtime(vers) >= os.path.getmtime(depuis):
        return
    import subprocess
    import imageio_ffmpeg
    os.makedirs(os.path.dirname(vers), exist_ok=True)
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-loglevel", "error", "-i", depuis, "-an",
                    "-c:v", "libtheora", "-q:v", str(QUALITE_VIDEO), vers], check=True)


def retirer_sorties(salle, noms):
    """Retire les sorties nommées ``noms`` (zone, nom, destination, point d'arrivée)."""
    for nom in noms:
        liste = [n.split(" → ")[0] for n in salle.get("noms_sorties", [])]
        if nom not in liste:
            raise ValueError(f"sortie « {nom} » introuvable")
        i = liste.index(nom)
        for cle in ("sorties", "noms_sorties", "destinations"):
            if cle in salle and i < len(salle[cle]):
                del salle[cle][i]
        salle.get("arrivees", {}).pop(nom, None)


def importer_salle(fichier, ident, directions):
    with open(os.path.join(TEST_SALLE, fichier), encoding="utf-8") as f:
        salle = json.load(f)
    retirer_sorties(salle, SORTIES_CACHEES.get(fichier, []))
    dossier = os.path.join(IMAGES, ident)
    os.makedirs(dossier, exist_ok=True)
    relatif = "images/salles_peintes/" + ident + "/"
    extension = os.path.splitext(salle["fond"])[1]
    copier(source(salle["fond"]), os.path.join(dossier, "fond" + extension))
    salle["fond"] = relatif + "fond" + extension
    # Décor animé : la vidéo d'origine (les images JPG de test_salle ne sont plus copiées)
    salle.pop("decor_anime", None)
    if os.path.isdir(os.path.join(dossier, "decor")):
        shutil.rmtree(os.path.join(dossier, "decor"))
    if fichier in VIDEOS:
        convertir_video(os.path.join(SALLES_DE_DONJON, VIDEOS[fichier]), os.path.join(dossier, "decor.ogv"))
        salle["decor_video"] = relatif + "decor.ogv"
    # Pas de son dans les salles (demande de l'utilisateur, 2026-10-18 : le feu de la salle 2 agaçait)
    salle.pop("son", None)
    if os.path.isfile(os.path.join(dossier, "son.wav")):
        os.remove(os.path.join(dossier, "son.wav"))
    if salle.get("masque_piliers") and os.path.isfile(source(salle["masque_piliers"])):
        copier(source(salle["masque_piliers"]), os.path.join(dossier, "masque.png"))
        copier(source(salle["piliers"]), os.path.join(dossier, "piliers.json"))
        salle["masque_piliers"] = relatif + "masque.png"
        salle["piliers"] = relatif + "piliers.json"
    else:
        salle.pop("masque_piliers", None)
        salle.pop("piliers", None)
    directions = list(directions)
    if "bas" not in directions:
        ajouter_sortie_bas(salle)
        directions.append("bas")
    if len(directions) != len(salle["sorties"]):
        raise ValueError(f"{fichier} : {len(salle['sorties'])} sorties pour {len(directions)} directions")
    salle["directions_sorties"] = directions
    importer_portes(fichier, salle, dossier, relatif)
    salle["types_sorties"] = types_sorties(fichier, salle)
    # Les liaisons entre salles viennent du plan du donjon, pas du banc d'essai
    salle.pop("destinations", None)
    salle["source"] = "test_salle/" + fichier
    # Sol détouré automatiquement (outils/detourer_sols.py, 2026-10-27) : remplace les zones tracées à la main
    from detourer_sols import detourage
    salle.update(detourage(ident))
    os.makedirs(DONNEES, exist_ok=True)
    with open(os.path.join(DONNEES, ident + ".json"), "w", encoding="utf-8") as f:
        json.dump(salle, f, ensure_ascii=False, indent=1)
    print(f"{ident} : {len(salle['sorties'])} sorties {directions}")


def types_sorties(fichier, salle):
    """Type de chaque sortie (« porte » ou « passage »), d'après l'inventaire des portes
    (``Salle de donjon/portes/portes.json``, clé ``sortie_jeu``) ; « retour » (bas de l'image) : passage.
    Le jeu fait arriver le héros par une porte plutôt que par un passage quand les deux mènent à la
    même salle (salle porte 6 : porte de gauche et passage de gauche)."""
    with open(os.path.join(SALLES_DE_DONJON, "portes", "portes.json"), encoding="utf-8") as f:
        inventaire = json.load(f)
    types = {}
    for s in inventaire["salles"]:
        if s["json"] == fichier:
            for p in s["portes"]:
                if p.get("sortie_jeu"):
                    types[p["sortie_jeu"]] = "passage" if p["type"] == "passage" else "porte"
    noms = [n.split(" → ")[0] for n in salle["noms_sorties"]]
    return [types.get(n, "passage" if n == "retour" or n.startswith("retour") else "porte") for n in noms]


def importer_portes(fichier, salle, dossier, relatif):
    """Copie les animations des portes de la salle (réduites) et les décrit dans ``portes_animees``."""
    from PIL import Image
    salle.pop("portes_animees", None)
    table = PORTES_ANIMEES.get(fichier, {})
    if os.path.isdir(os.path.join(dossier, "portes")):
        for ancien in os.listdir(os.path.join(dossier, "portes")):
            if ancien not in table:
                shutil.rmtree(os.path.join(dossier, "portes", ancien))
    if not table:
        return
    with Image.open(os.path.join(dossier, "fond" + os.path.splitext(salle["fond"])[1])) as im:
        largeur_fond, hauteur_fond = im.size
    noms = [n.split(" → ")[0] for n in salle["noms_sorties"]]
    portes = []
    for ident_porte, nom_sortie in table.items():
        dossier_source = os.path.join(SALLES_DE_DONJON, os.path.dirname(VIDEOS[fichier]), "portes_animees", ident_porte)
        with open(os.path.join(dossier_source, ident_porte + ".json"), encoding="utf-8") as f:
            info = json.load(f)
        largeur_video, hauteur_video = 1088, 720  # « source_loop » : vidéo de la salle, 1088 × 720
        kx, ky = largeur_fond / largeur_video, hauteur_fond / hauteur_video
        vers = os.path.join(dossier, "portes", ident_porte)
        os.makedirs(vers, exist_ok=True)
        taille = (round(info["w"] * ECHELLE_PORTES), round(info["h"] * ECHELLE_PORTES))
        for k in range(info["frames"]):
            src = os.path.join(dossier_source, info["rgba"].replace("###", "%03d" % k))
            dst = os.path.join(vers, "%03d.png" % k)
            if os.path.isfile(dst) and os.path.getmtime(dst) >= os.path.getmtime(src):
                continue
            with Image.open(src) as im:
                im.convert("RGBA").resize(taille, Image.LANCZOS).save(dst, optimize=True)
        portes.append({
            "nom": ident_porte, "sortie": noms.index(nom_sortie),
            "x": info["x"] * kx, "y": info["y"] * ky, "w": info["w"] * kx, "h": info["h"] * ky,
            "images": relatif + "portes/" + ident_porte + "/%03d.png", "nombre": info["frames"],
            "ips": info.get("fps", 24),
        })
    salle["portes_animees"] = portes


def importer_heros():
    for nom, dossier in HEROS_DOSSIERS.items():
        copier_dossier(dossier, os.path.join(IMAGES, "heros", nom))
    print("héros : marche, course, respiration")


if __name__ == "__main__":
    os.makedirs(IMAGES, exist_ok=True)
    # Le moteur charge ces images lui-même : l'éditeur Godot ne doit pas les importer
    open(os.path.join(IMAGES, ".gdignore"), "w").close()
    for fichier, (ident, directions) in SALLES.items():
        importer_salle(fichier, ident, directions)
    importer_heros()
