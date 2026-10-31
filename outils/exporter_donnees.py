"""Exporte les données du jeu Python (racine de « version Godot ») en JSON pour le portage Godot.

À lancer depuis la racine du jeu Python, après toute modification des talents,
sorts, compétences ou équilibrages :

    python godot/outils/exporter_donnees.py

Écrit dans ``godot/donnees/`` : talents.json, sorts.json, competences.json,
divers.json, et recopie ameliorations.json, valeurs_competences.json et
coefficients_equilibrage.json.
"""
import ast
import json
import os
import shutil
import sys

RACINE = os.getcwd()
sys.path.insert(0, RACINE)
SORTIE = os.path.join(RACINE, "godot", "donnees")
os.makedirs(SORTIE, exist_ok=True)


def ecrire(nom, donnees):
    with open(os.path.join(SORTIE, nom), "w", encoding="utf-8") as f:
        json.dump(donnees, f, ensure_ascii=False, indent=1)


# --- Talents : sphérier complet et libellés ---------------------------------
import talent  # noqa: E402

s = talent.SPHERIER
noeuds = []
for t in s.noeuds.values():
    noeuds.append({"ident": t.ident, "nom": t.nom, "stats": t.stats, "genre": t.genre, "branche": t.branche,
                   "sous_branche": t.sous_branche, "x": t.x, "y": t.y, "description": t.description})
amas = []
for a in s.amas:
    amas.append({k: v for k, v in a.items()})
ecrire("talents.json", {
    "noeuds": noeuds,
    "liens": [list(l) for l in s.liens],
    "amas": amas,
    "parties": s.parties,
    "libelles": {k: [g, e] for k, (g, e) in talent.LIBELLES.items()},
})

# --- Sorts du grimoire -------------------------------------------------------
import sorts  # noqa: E402

ecrire("sorts.json", [{"classe": c.__name__, "element": c.ELEMENT, "palier": c.PALIER, "fiche": c.FICHE}
                      for c in sorts.classes_de_sorts()])

# --- Compétences de competence.py (arguments du constructeur, tirages au hasard) ----
src = open(os.path.join(RACINE, "competence.py"), encoding="utf-8").read()
arbre = ast.parse(src)


def valeur(noeud):
    if isinstance(noeud, ast.Call) and ast.unparse(noeud.func) == "random.randint":
        return {"alea": [ast.literal_eval(noeud.args[0]), ast.literal_eval(noeud.args[1])]}
    return ast.literal_eval(noeud)


competences = []
for noeud in arbre.body:
    if isinstance(noeud, ast.ClassDef) and noeud.name != "Compétence":
        init = next(f for f in noeud.body if isinstance(f, ast.FunctionDef) and f.name == "__init__")
        appel = next(st.value for st in init.body if isinstance(st, ast.Expr) and isinstance(st.value, ast.Call)
                     and ast.unparse(st.value.func) == "super().__init__")
        args = {k.arg: valeur(k.value) for k in appel.keywords}
        competences.append({"classe": noeud.name, "args": args})
ecrire("competences.json", competences)

# --- Divers : noms de salles, lance de test ---------------------------------
src = open(os.path.join(RACINE, "donjon.py"), encoding="utf-8").read()
noms = None
for n in ast.walk(ast.parse(src)):
    if isinstance(n, ast.Assign) and ast.unparse(n.targets[0]) == "self.noms_possibles":
        noms = ast.literal_eval(n.value)
        break
from objets import Lance  # noqa: E402

lance = {k: v for k, v in vars(Lance()).items() if isinstance(v, (int, float, str, list)) and not isinstance(v, bool)}
ecrire("divers.json", {"noms_salles": noms, "lance_test": lance})

for nom in ("ameliorations.json", "valeurs_competences.json", "coefficients_equilibrage.json"):
    shutil.copy(os.path.join(RACINE, "donnees", nom), os.path.join(SORTIE, nom))
print("Données exportées dans", SORTIE)

# --- Foyers de feu des images de fond (particules d'animations.py) ----------
import glob  # noqa: E402

import pygame  # noqa: E402

import animations  # noqa: E402

foyers = {}
fonds = glob.glob(os.path.join(RACINE, "images", "salles", "*.png")) + glob.glob(os.path.join(RACINE, "images", "*.png"))
for chemin in fonds:
    try:
        image = pygame.transform.smoothscale(pygame.image.load(chemin), (960, 540))
    except pygame.error:
        continue
    relatif = os.path.relpath(chemin, os.path.join(RACINE, "images")).replace("\\", "/")
    foyers[relatif] = [{"rect": [s.rect.x, s.rect.y, s.rect.w, s.rect.h], "couleur": list(s.couleur)}
                       for s in animations.detecter_flammes(image)]
ecrire("foyers.json", foyers)
print("Foyers exportés :", sum(len(v) for v in foyers.values()), "dans", len(foyers), "images")
