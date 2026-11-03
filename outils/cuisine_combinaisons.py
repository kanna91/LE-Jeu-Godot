"""Liste complète des plats possibles (cuisine, conception : CUISINE.md), d'après donnees/cuisine.json.

    python outils/cuisine_combinaisons.py

Tous les mélanges de 1 à 4 ingrédients (le même ingrédient peut revenir), avec les 4 préparations (sans feu,
grillé, bouilli, mijoté / four). Chaque case : recette, mixture (×0,5) ou immonde (×0,25), avec PV et mana.
Écrit outils/cuisine/combinaisons.csv (séparateur « ; », s'ouvre dans LibreOffice ou Excel) et
outils/cuisine/resume.md (comptes et exemples). Le dossier a un .gdignore (Godot n'importe pas le .csv).
"""
import collections
import csv
import itertools
import json
import os

ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SORTIE = os.path.join(ICI, "outils", "cuisine")
D = json.load(open(os.path.join(ICI, "donnees", "cuisine.json"), encoding="utf8"))
ING = D["ingredients"]
PREPS = list(D["preparations"])
TEXTES = {r["cle"]: r["texte"] for r in D["immondes"]}


def accepte(motif, ident):
    if motif.startswith("famille:"):
        return ING[ident]["famille"] == motif[8:]
    if motif.startswith("un_de:"):
        return ident in motif[6:].split("|")
    return motif == ident


def recette(melange):
    """Première recette (ordre du fichier) dont les ingrédients sont exactement ``melange``, ou None."""
    for r in D["recettes"]:
        motifs = r["ingredients"]
        if len(motifs) != len(melange):
            continue
        for ordre in set(itertools.permutations(melange)):
            if all(accepte(m, i) for m, i in zip(motifs, ordre)):
                return r
    return None


def immonde(melange, prep):
    """Clé de la première règle immonde qui s'applique (ou None)."""
    f = [ING[i] for i in melange]
    a = lambda cle: any(x.get(cle) for x in f)
    fam = lambda nom: sum(1 for x in f if x["famille"] == nom)
    if a("perime"):
        return "perime"
    if "lait" in melange and a("acide"):
        return "lait_acide"
    sucre = a("sucre")
    if sucre and ("ail" in melange or "champignon" in melange):
        return "sucre_ail_champignon"
    if sucre and "oignon" in melange and fam("viande") == 0:
        return "sucre_oignon_sans_viande"
    if sucre and fam("legume") + melange.count("oignon") >= 2:
        return "sucre_et_legumes"
    if all(i in ("ail", "herbes", "citron") for i in melange):
        return "rien_de_nourrissant"
    if any(melange.count(i) >= 3 for i in ("ail", "citron", "herbes")):
        return "trop_fort"
    if "farine" in melange and "oeuf" not in melange and "lait" not in melange:
        return "farine_crue"
    if prep == "sans_feu" and "viande_crue" in melange:
        return "viande_crue"
    if prep == "sans_feu" and a("cru_immangeable"):
        return "cru"
    if prep == "grille" and "lait" in melange and "oeuf" not in melange:
        return "grille_liquide"
    return None


def evaluer(melange, prep):
    """[classe, nom, pv, mana, raison] : classe « recette », « mixture » ou « immonde »."""
    pv = sum(ING[i]["pv"] for i in melange)
    mana = sum(ING[i]["mana"] for i in melange)
    if len(melange) == 1 and prep == "sans_feu" and ING[melange[0]]["famille"] != "viande":
        return ["pas un plat", "", pv, mana, "un seul ingrédient sans feu : on ne cuisine rien (les fruits se mangent tels quels)"]
    r = recette(melange)
    regle = immonde(melange, prep)
    if r is not None and r["preparation"] == prep and regle in (None, "perime", "cru", "viande_crue"):
        k = D["preparations"][prep]["multiplicateur"] + D["bonus_par_ingredient_au_dela_de_2"] * max(0, len(melange) - 2)
        note = "intoxication 1 fois sur 2" if r.get("intoxication") else ""
        return ["recette", r["nom"], round(pv * k), round(mana * k), note]
    if regle is not None:
        return ["immonde", "", round(pv * D["immonde"]), round(mana * D["immonde"]), TEXTES[regle]]
    indice = ("presque : %s (%s)" % (r["nom"], D["preparations"][r["preparation"]]["nom"].lower())) if r else ""
    return ["mixture", "", round(pv * D["mixture"]), round(mana * D["mixture"]), indice]


def main():
    os.makedirs(SORTIE, exist_ok=True)
    open(os.path.join(SORTIE, ".gdignore"), "w").close()
    ids = list(ING)
    comptes = collections.Counter()
    raisons = collections.Counter()
    exemples = collections.defaultdict(list)
    recettes_trouvees = collections.defaultdict(list)
    chemin = os.path.join(SORTIE, "combinaisons.csv")
    with open(chemin, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f, delimiter=";")
        entete = ["n", "ingrédients"]
        for p in PREPS:
            nom = D["preparations"][p]["nom"]
            entete += [nom + " : résultat", nom + " : PV", nom + " : mana", nom + " : remarque"]
        w.writerow(entete)
        for n in range(1, 5):
            for melange in itertools.combinations_with_replacement(ids, n):
                noms = " + ".join(ING[i]["nom"] for i in melange)
                ligne = [n, noms]
                for p in PREPS:
                    c, nom, pv, mana, note = evaluer(melange, p)
                    comptes[(p, c)] += 1
                    if c == "immonde":
                        raisons[note] += 1
                    if c == "recette":
                        recettes_trouvees[nom].append((noms, p, pv, mana))
                    elif len(exemples[(p, c, note)]) < 3:
                        exemples[(p, c, note)].append("%s → %d PV, %d mana" % (noms, pv, mana))
                    ligne += [nom if c == "recette" else c, pv, mana, note]
                w.writerow(ligne)
    total = sum(1 for n in range(1, 5) for _ in itertools.combinations_with_replacement(ids, n))
    lignes = ["# Cuisine : toutes les combinaisons (résumé)", "",
              "Produit par `outils/cuisine_combinaisons.py` depuis `donnees/cuisine.json`. Liste complète :",
              "`outils/cuisine/combinaisons.csv` (une ligne par mélange, 4 préparations en colonnes).", "",
              "**%d mélanges** de 1 à 4 ingrédients parmi %d (répétitions permises), × 4 préparations = %d plats." % (total, len(ids), total * 4), "",
              "| Préparation | Recettes | Mixtures | Immondes |", "|---|---|---|---|"]
    for p in PREPS:
        lignes.append("| %s | %d | %d | %d |" % (D["preparations"][p]["nom"], comptes[(p, "recette")], comptes[(p, "mixture")], comptes[(p, "immonde")]))
    lignes += ["", "## Recettes (toutes les variantes)", ""]
    for nom, vs in recettes_trouvees.items():
        pvs = [v[2] for v in vs]
        manas = [v[3] for v in vs]
        lignes.append("- **%s** : %d variante(s), %s PV, %s mana" % (nom, len(vs),
                      ("%d" % pvs[0]) if min(pvs) == max(pvs) else "%d à %d" % (min(pvs), max(pvs)),
                      ("%d" % manas[0]) if min(manas) == max(manas) else "%d à %d" % (min(manas), max(manas))))
    lignes += ["", "## Pourquoi c'est immonde (nombre de plats)", ""]
    for texte, n in raisons.most_common():
        lignes.append("- %s : %d" % (texte, n))
    lignes += ["", "## Exemples", ""]
    for (p, c, note), ex in sorted(exemples.items()):
        lignes.append("- %s, %s%s : %s" % (D["preparations"][p]["nom"], c, (" — " + note) if note else "", " ; ".join(ex)))
    open(os.path.join(SORTIE, "resume.md"), "w", encoding="utf8").write("\n".join(lignes) + "\n")
    print("%d mélanges ; écrit %s et resume.md" % (total, chemin))
    for p in PREPS:
        print(p, comptes[(p, "recette")], comptes[(p, "mixture")], comptes[(p, "immonde")])


if __name__ == "__main__":
    main()
