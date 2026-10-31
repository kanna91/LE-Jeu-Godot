"""Exporte des résultats de calcul du jeu Python pour contrôler le portage Godot.

    python godot/outils/exporter_controle.py      (depuis la racine du jeu Python)

Écrit godot/tests/controle.json : pour chaque compétence et sort, ses attributs
et les résultats de l'équilibrage (valeur, composantes, estimation des dégâts,
options recalculées du premier niveau).
"""
import json
import os
import random
import sys

sys.path.insert(0, os.getcwd())
import ameliorations  # noqa: E402
import equilibrage  # noqa: E402
import formules  # noqa: E402
import sorts  # noqa: E402
import valeur_competences  # noqa: E402
import competence as module_competence  # noqa: E402

random.seed(7)
NOMS = ["Coup_d_epee", "Fracasser", "Boule_de_feu", "Soin", "Eclair", "Balayage", "Tir_empoisonne", "Protection",
        "Cri_de_guerre", "Recupe", "Projectile_des_ombres", "Grand_coup_de_gourdin"]
classes = [getattr(module_competence, n) for n in NOMS] + list(sorts.classes_de_sorts())[::4]


def propre(v):
    if isinstance(v, dict):
        return {k: propre(x) for k, x in v.items() if not callable(x)}
    if isinstance(v, (list, tuple)):
        return [propre(x) for x in v]
    if isinstance(v, (int, float, str, bool)) or v is None:
        return v
    return None


resultats = []
for classe in classes:
    comp = classe()
    attributs = {k: propre(v) for k, v in vars(comp).items() if k not in ("ameliorations_possibles", "ameliorations_anciennes")}
    for cle in ("ELEMENT", "PALIER", "JOUEUR", "renforcer_propres"):
        if hasattr(type(comp), cle):
            attributs[cle] = getattr(type(comp), cle)
    j, e = equilibrage.camp(comp)
    contexte = ameliorations._contexte(comp)
    base = max(0.5 * equilibrage.degats_par_tour(j, e), equilibrage.valeur(comp))
    options = ameliorations._options_niveau(comp, 1, equilibrage.BUDGETS[1] * base, contexte, {}, comp)
    resultats.append({
        "classe": classe.__name__, "attributs": attributs,
        "valeur": equilibrage.valeur(comp), "points": valeur_competences.points(comp),
        "composantes": [list(c) for c in equilibrage.composantes(comp)],
        "estimation": [list(x) for x in formules.estimer_degats(j, comp, e, arrondi=False)],
        "options_1": options,
        "descriptions_1": [ameliorations.decrire_spec(o, ameliorations.profil(comp) == "soin", comp) for o in options],
    })
os.makedirs(os.path.join("godot", "tests"), exist_ok=True)
with open(os.path.join("godot", "tests", "controle.json"), "w", encoding="utf-8") as f:
    json.dump(resultats, f, ensure_ascii=False, indent=1)
print(len(resultats), "compétences exportées")
