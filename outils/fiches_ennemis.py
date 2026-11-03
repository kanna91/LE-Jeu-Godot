"""Fiches techniques des ennemis, écrites dans leur dossier (``C:\\ia image\\ennemis\\<ennemi>``).

Demande de l'utilisateur (2026-10-27) : pour chaque ennemi, un document qui décrit tout ce qui le compose
(caractéristiques, défenses, compétences, comportement en combat et dans les salles, progression, images).
Les chiffres viennent du jeu lui-même : ``tests/exporter_fiches_ennemis.gd`` est lancé dans Godot (tirages au premier
étage, compétences de base contre le héros de départ), puis ce script écrit un .odt par ennemi :
« fiche technique - <nom>.odt ». Ces fiches sont **réécrites** à chaque lancement : les notes de l'utilisateur
restent dans ses propres fiches (« fiche squelette.odt », « particularité des loups.odt »...), que ce script lit
pour signaler les écarts entre la fiche et le jeu.

Usage : ``python outils/fiches_ennemis.py`` (depuis le dossier ``godot``), après toute modification d'un ennemi.
"""
import datetime
import html
import json
import os
import re
import subprocess
import zipfile

from odf.opendocument import OpenDocumentText
from odf.style import ParagraphProperties, Style, TableCellProperties, TableColumnProperties, TextProperties
from odf.table import Table, TableCell, TableColumn, TableRow
from odf.text import H, List, ListItem, P, Span

ICI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENNEMIS = r"C:\ia image\ennemis"
GODOT = r"C:\jeux\Godot\Godot_v4.7.2-stable_win64_console.exe"
EXPORT = os.path.expandvars(r"%APPDATA%\Godot\app_userdata\LE Jeu Ultime\fiches_ennemis.json")

NOMS_STATS = {
    "points_de_vie_max": "PV", "endurance": "Endurance", "force": "Force", "dextérité": "Dextérité",
    "intelligence": "Intelligence", "sagesse": "Sagesse", "armure": "Armure", "chance_esquive": "Esquive",
    "chance_de_toucher": "Chance de toucher", "chance_de_coup_critique": "Critique physique (chance)",
    "degats_critique": "Critique physique (dégâts ×)", "chance_de_coup_critique_magique": "Critique magique (chance)",
    "degats_critique_magiques": "Critique magique (dégâts ×)", "chance_de_parer": "Parade",
    "mana_max": "Mana", "regen_de_mana": "Mana récupéré par tour", "puissance_magique": "Puissance magique",
    "resistance_magique": "Résistance magique", "resistance_elementaire": "Résistance élémentaire",
    "points_d_action_max": "Points d'action par tour",
}
POURCENTS = {"chance_esquive", "chance_de_toucher", "chance_de_coup_critique", "chance_de_coup_critique_magique",
             "chance_de_parer"}
D_OU = {
    "points_de_vie_max": "endurance × 2", "armure": "force ÷ 3", "chance_esquive": "dextérité ÷ 3 (%)",
    "chance_de_toucher": "85 % + dextérité", "chance_de_coup_critique": "dextérité ÷ 2 (%)",
    "degats_critique": "1,5 + force × 0,02", "chance_de_coup_critique_magique": "2,5 % + intelligence ÷ 2 × 0,5 %",
    "degats_critique_magiques": "1,25 + intelligence × 0,01", "mana_max": "sagesse × 5",
    "regen_de_mana": "sagesse ÷ 2", "puissance_magique": "3 + intelligence × 0,5",
    "resistance_magique": "intelligence ÷ 3", "resistance_elementaire": "sagesse ÷ 3",
}
NOMS_ALT = {"saignement": "Saignement", "désarmement": "Désarmement", "rage": "Rage", "lenteur": "Lenteur",
            "marque": "Marque", "peste": "Peste", "poison": "Poison", "concentration": "Concentration",
            "précis": "Précis", "brulure": "Brûlure", "brûlure": "Brûlure", "silence": "Silence", "protection": "Protection",
            "stun": "Étourdissement", "usure": "Usure"}


# ---------------------------------------------------------------------------
# Document
# ---------------------------------------------------------------------------

class Doc:
    def __init__(self, titre, sous_titre):
        self.d = OpenDocumentText()
        s = self.d.styles
        self.st = {}
        for nom, taille, gras, couleur in [("Titre", "20pt", True, "#5a1d1d"), ("H1", "14pt", True, "#7a2a2a"),
                                            ("H2", "12pt", True, "#333333")]:
            st = Style(name=nom, family="paragraph")
            st.addElement(TextProperties(fontsize=taille, fontweight="bold" if gras else "normal", color=couleur))
            st.addElement(ParagraphProperties(margintop="0.35cm", marginbottom="0.15cm"))
            s.addElement(st)
            self.st[nom] = st
        corps = Style(name="Corps", family="paragraph")
        corps.addElement(TextProperties(fontsize="10.5pt"))
        corps.addElement(ParagraphProperties(marginbottom="0.12cm"))
        s.addElement(corps)
        self.st["Corps"] = corps
        note = Style(name="Note", family="paragraph")
        note.addElement(TextProperties(fontsize="9pt", fontstyle="italic", color="#666666"))
        s.addElement(note)
        self.st["Note"] = note
        alerte = Style(name="Alerte", family="paragraph")
        alerte.addElement(TextProperties(fontsize="10.5pt", fontweight="bold", color="#a03000"))
        s.addElement(alerte)
        self.st["Alerte"] = alerte
        gras = Style(name="Gras", family="text")
        gras.addElement(TextProperties(fontweight="bold"))
        s.addElement(gras)
        self.st["Gras"] = gras
        cel = Style(name="Cellule", family="table-cell")
        cel.addElement(TableCellProperties(border="0.5pt solid #999999", padding="0.08cm"))
        self.d.automaticstyles.addElement(cel)
        self.st["Cellule"] = cel
        ent = Style(name="Entete", family="table-cell")
        ent.addElement(TableCellProperties(border="0.5pt solid #999999", padding="0.08cm", backgroundcolor="#e8dcdc"))
        self.d.automaticstyles.addElement(ent)
        self.st["Entete"] = ent
        petit = Style(name="Petit", family="paragraph")
        petit.addElement(TextProperties(fontsize="9.5pt"))
        s.addElement(petit)
        self.st["Petit"] = petit
        self.d.text.addElement(P(stylename=self.st["Titre"], text=titre))
        self.note(sous_titre)
        self.note("Fiche générée le %s depuis le code du jeu par outils/fiches_ennemis.py : elle est réécrite à chaque "
                  "mise à jour, ne pas la modifier à la main (tes notes vont dans ta propre fiche)."
                  % datetime.date.today().strftime("%d/%m/%Y"))

    def h1(self, t):
        self.d.text.addElement(H(outlinelevel=1, stylename=self.st["H1"], text=t))

    def h2(self, t):
        self.d.text.addElement(H(outlinelevel=2, stylename=self.st["H2"], text=t))

    def p(self, t, style="Corps"):
        par = P(stylename=self.st[style])
        # **gras**
        for i, morceau in enumerate(re.split(r"\*\*", t)):
            if i % 2:
                par.addElement(Span(stylename=self.st["Gras"], text=morceau))
            elif morceau:
                par.addText(morceau)
        self.d.text.addElement(par)

    def note(self, t):
        self.p(t, "Note")

    def alerte(self, t):
        self.p(t, "Alerte")

    def liste(self, lignes):
        lst = List()
        for l in lignes:
            it = ListItem()
            par = P(stylename=self.st["Corps"])
            for i, morceau in enumerate(re.split(r"\*\*", l)):
                if i % 2:
                    par.addElement(Span(stylename=self.st["Gras"], text=morceau))
                elif morceau:
                    par.addText(morceau)
            it.addElement(par)
            lst.addElement(it)
        self.d.text.addElement(lst)

    def tableau(self, entetes, lignes):
        t = Table()
        for _ in entetes:
            t.addElement(TableColumn())
        r = TableRow()
        for e in entetes:
            c = TableCell(stylename=self.st["Entete"])
            c.addElement(P(stylename=self.st["Petit"], text=str(e)))
            r.addElement(c)
        t.addElement(r)
        for ligne in lignes:
            r = TableRow()
            for v in ligne:
                c = TableCell(stylename=self.st["Cellule"])
                c.addElement(P(stylename=self.st["Petit"], text=str(v)))
                r.addElement(c)
            t.addElement(r)
        self.d.text.addElement(t)

    def enregistrer(self, chemin):
        self.d.save(chemin)
        print("écrit :", chemin)


# ---------------------------------------------------------------------------
# Outils
# ---------------------------------------------------------------------------

def nombre(v, pourcent=False):
    if pourcent:
        v = v * 100
        return ("%.1f" % v).rstrip("0").rstrip(".").replace(".", ",") + " %"
    if abs(v - round(v)) < 1e-6:
        return str(int(round(v)))
    return ("%.2f" % v).rstrip("0").rstrip(".").replace(".", ",")


def bornes(b, cle):
    pc = cle in POURCENTS
    a, z = b
    return nombre(a, pc) if abs(a - z) < 1e-9 else "%s à %s" % (nombre(a, pc), nombre(z, pc))


def lire_fiche_utilisateur(dossier):
    """Texte des fiches .odt de l'utilisateur (hors fiches techniques) dans ``dossier``."""
    textes = []
    for f in sorted(os.listdir(dossier)) if os.path.isdir(dossier) else []:
        if f.endswith(".odt") and not f.startswith("fiche technique"):
            x = zipfile.ZipFile(os.path.join(dossier, f)).read("content.xml").decode("utf8")
            x = re.sub(r"</text:(p|h)>", "\n", x)
            x = html.unescape(re.sub(r"<[^>]+>", "", x)).strip()
            textes.append((f, x))
    return textes


def section_fiche_utilisateur(doc, dossier, ecarts):
    fiches = lire_fiche_utilisateur(dossier)
    doc.h1("Ta fiche et le jeu")
    if not fiches:
        doc.p("Pas de fiche de ta main dans ce dossier.")
    for nom, texte in fiches:
        doc.p("**%s** :" % nom)
        for ligne in texte.splitlines():
            if ligne.strip():
                doc.p("« %s »" % ligne.strip(), "Petit")
    if ecarts:
        doc.alerte("Écarts entre ta fiche et le jeu :")
        doc.liste(ecarts)
    elif fiches:
        doc.p("Tout ce qu'elle dit est dans le jeu.")


def tableau_stats(doc, stats, sauf=()):
    lignes = []
    for cle, nom in NOMS_STATS.items():
        if cle in stats and cle not in sauf:
            lignes.append([nom, bornes(stats[cle], cle) if isinstance(stats[cle], list) else nombre(stats[cle], cle in POURCENTS),
                           D_OU.get(cle, "")])
    doc.tableau(["Caractéristique", "Valeur", "D'où elle vient"], lignes)


def tableau_competences(doc, comps, seulement_ia=False):
    lignes = []
    for c in comps:
        if seulement_ia and not c.get("ia", True):
            continue
        des = ", ".join("%s %s" % (v, t) for t, v in c["des"].items()) or "—"
        degats = ", ".join("%s %s" % (nombre(x[2]), x[0]) for x in c["degats"]) or "—"
        alt = ", ".join("%s %s %%" % (NOMS_ALT.get(n, n), nombre(v)) for n, v in c["alterations"].items()) or "—"
        coups = int(c.get("coups") or 1)
        cible = {"choix": "une cible", "aléatoire": "au hasard", "tous_les_ennemis": "tout son camp",
                 "self": "lui-même"}.get(c["ciblage"], c["ciblage"])
        if coups > 1:
            cible += ", %d coups" % coups
        lignes.append([c["nom"], c["pa"], c["mana"] or "—", des, degats, alt, cible])
    doc.tableau(["Compétence", "PA", "Mana", "Dés", "Dégâts moyens subis par le héros", "Altérations (chance)", "Cible"],
                lignes)


def descriptions(doc, comps):
    for c in comps:
        if c.get("description"):
            doc.p("**%s** : %s" % (c["nom"], c["description"]), "Petit")


# ---------------------------------------------------------------------------
# Gobelins
# ---------------------------------------------------------------------------

IA_GOBELINS = {
    "combattant": "Il frappe toujours avec **Coup d'épée**.",
    "lancier": "2 fois sur 3 **Coup de lance** ; sinon **Perforation** si le héros ne saigne pas encore, "
               "**Rafale de lance** s'il saigne.",
    "archer": "D'abord **Précision** (sur lui ou un allié) s'il a assez de mana et n'est pas déjà « précis » ; ensuite "
              "2 fois sur 3 **Tir à l'arc**, sinon une fois sur deux **Tir précis** ou **Tir empoisonné**.",
    "defenseur": "2 fois sur 3 **Coup de gourdin** ; sinon **Protection** si aucun allié n'est protégé, "
                 "**Grand coup de gourdin** s'il y en a un.",
    "sorcier": "Tant qu'il a plus de 5 de mana : un sort au hasard parmi **Boule de feu, Blizzard, Éclair, Trait de "
               "l'ombre, Projectile de l'ombre, Enflammer** (il évite Projectile de l'ombre si le héros brûle déjà). "
               "Sans mana : **Projectile de l'ombre**. S'il ne peut plus faire de magie : **Coup de bâton**.",
    "feticheur": "Blessé (moitié de ses PV ou moins) et pas encore soigné : une chance sur 3 de se soigner "
                 "(**Soin** ou **Soin mineur**). Sinon un sort au hasard parmi **Caresse des ombres, Enflammer, "
                 "Silence** (ceux dont le héros n'a pas déjà toutes les altérations) et **Projectile de l'ombre**.",
    "chaman": "Si un allié est à la moitié de ses PV ou moins et n'a pas encore été soigné : une chance sur 3 de "
              "soigner le plus blessé (**Soin, Soin mineur, Soin majeur** ou **Récupe**). Sinon **Boule de feu**.",
}
NOMS_SOUS = {"combattant": "Gobelin combattant", "lancier": "Gobelin lancier", "defenseur": "Gobelin défenseur",
             "archer": "Gobelin archer", "sorcier": "Gobelin sorcier", "feticheur": "Gobelin féticheur",
             "chaman": "Gobelin chaman"}
DOSSIERS_GOBELINS = {"gobelin guerrier": ["combattant", "lancier", "defenseur"], "gobelin archer": ["archer"],
                     "gobelin sorcier": ["sorcier"], "gobelin feticheur": ["feticheur"], "gobelin chaman": ["chaman"]}
ANIMS = {"guerrier": "attente, touché, 3 attaques, mort", "archer": "attente, touché, 3 tirs, mort",
         "sorcier": "attente, touché, lancer de sort, mort", "chaman": "attente, touché, 2 lancers, mort",
         "feticheur": "attente, touché, 2 lancers, mort"}


def regles_communes_gobelins(doc, c, renvoi=True):
    if renvoi:
        doc.note("Règles communes à tous les gobelins (rappel ; détail dans « gobelin\\fiche technique - gobelins.odt »).")
    e = c["ennemis_par_etage"]
    doc.h1("Où on les rencontre (donjon d'aventure)")
    doc.liste([
        "Ils rôdent **en groupes** dans les salles ordinaires : %s."
        % ", ".join("%s groupe(s) : %s %%" % (k, v) for k, v in c["groupes_par_salle"].items()),
        "Taille d'un groupe selon l'étage (1, 2 ou 3 tirés, puis **2 au plus, loup compris**, depuis le 30/10/2026) : %s."
        % " ; ".join("étage %s : %s %%" % (k, " / ".join(str(x) for x in v)) for k, v in e.items()),
        "La sorte de chaque gobelin est tirée au hasard : guerrier (moitié archer/combattant/lancier, moitié défenseur), "
        "mage (sorcier ou féticheur) ou soutien (chaman), une chance sur trois chacun.",
        "**Élite** (%d %% des groupes) : un gobelin plus fort en tête, PV × %s, dégâts × %s, plus grand ; il porte un "
        "objet qu'il lâche à coup sûr et vaut 3 âmes." % (round(c["chance_elite"] * 100), nombre(c["mini_boss"]["pv"]), nombre(c["mini_boss"]["degats"])),
        "**Pacifiques** (%d %% des groupes sans élite) : ils ne veulent pas se battre. Les épargner rapporte un peu d'or "
        "(karma +1) ; les tuer coûte du karma (−1) mais donne leur âme." % round(c["chance_pacifique"] * 100),
        "**Porteur** : après une capture par un geôlier, un gobelin mini-boss (PV encore × 1,5) peut porter jusqu'à %d "
        "objets confisqués au héros ; les vaincre les rend." % c["objets_par_porteur"],
        "**Boss de l'étage** : un gobelin PV × %s, dégâts × %s, très grand ; une faiblesse (%d %%) et une force "
        "(+%d %%) tirées au hasard parmi feu, froid, foudre, tranchant, perforant, contondant, que les diablotins "
        "révèlent (vrai ou faux)." % (nombre(c["boss"]["pv"]), nombre(c["boss"]["degats"]), c["faiblesse_boss"],
                                       c["force_boss"]),
        "**Loups** : un groupe qui compte un archer ou un chaman est accompagné d'un loup %d %% du temps (jamais de loup "
        "seul). **Squelettes** : %d %% des groupes sans élite ni pacifiques sont des squelettes (1 à 3, seuls possible), "
        "menés par un féticheur gobelin %d %% du temps à partir de 2." % (round(c["chance_loup"] * 100),
                                                                         round(c["chance_groupe_squelettes"] * 100),
                                                                         round(c["chance_feticheur_squelettes"] * 100)),
        "Les ennemis ne donnent **ni expérience ni or** directement : leur corps se fouille (comme un squelette) et leur "
        "âme se siphonne (1 par ennemi, 3 par élite, 5 par boss ; 3 âmes = 1 point de caractéristique). Les élites "
        "et les porteurs lâchent aussi leurs objets.",
    ])
    doc.h1("Comportement dans les salles")
    doc.liste([
        "Ronde : vitesse %s × la course du héros (il marche à 0,45). Poursuite : %s."
        % (nombre(c["vitesse_ronde"]), nombre(c["vitesse_poursuite"]["groupe"])),
        "Vue : %s hauteurs de héros devant eux, dans un cône de %s°. Ouïe : %s hauteurs si le héros court, %s s'il "
        "marche, %s s'il est caché dans l'ombre." % (nombre(c["vue"]["groupe"]), nombre(c["angle_vue"]),
                                                     nombre(c["ouie"][0]), nombre(c["ouie"][1]), nombre(c["ouie"][2])),
        "Repéré : « ! » puis poursuite ; ils perdent le héros après %s s sans le voir, le cherchent %s s, puis reprennent "
        "leur ronde." % (nombre(c["perte"]["groupe"]), nombre(c["duree_recherche"])),
        "Ils le suivent dans la salle suivante une fois sur deux (%d %%), sauf dans la salle d'un diablotin ou d'une "
        "succube, où ils ne sont jamais. Le contact lance le combat."
        % round(c["chance_suivre"]["groupe"] * 100),
        "Fuite d'un combat : %d %% + %d %% par point de dextérité − %d %% par ennemi en plus du premier (entre %d et %d %%)."
        % (round(c["fuite"][0] * 100), round(c["fuite"][1] * 100), round(c["fuite"][2] * 100),
           round(c["fuite"][3][0] * 100), round(c["fuite"][3][1] * 100)),
    ])
    doc.h1("En combat : règles communes")
    doc.liste([
        "1 point d'action par tour : une action par tour.",
        "Les dés des gobelins sont lancés **un cran plus bas** que ceux du héros (1d12 → 1d10, 1d10 → 1d6, 1d8 → 1d6, "
        "1d6 → 1d4, 1d4 → 1d2) ; les soins ne sont pas réduits. C'est un réglage fait à la main pour les gobelins, pas "
        "une règle pour tous les ennemis (loups, squelettes et Chevalier frappent avec leurs propres dés).",
        "Dégâts : dés + caractéristique ÷ 2 (force pour le physique, sagesse pour feu/froid/foudre, intelligence pour "
        "arcane/ombre/chaos), puis armure et résistances du héros. Réduction commune des dégâts : × %s."
        % nombre(c["multiplicateur_degats"]),
        "Potion : 30 % des gobelins en ont une ; à la moitié de ses PV, une chance sur 3 de la boire (une fois par "
        "combat, comme tout soin).",
        "Si la compétence choisie n'est pas utilisable (mana, silence), il prend son attaque de secours, sinon Coup de bâton.",
        "Ses compétences ne s'améliorent plus avec l'étage (amélioration des compétences supprimée le 2026-11-03, "
        "à reforger) : les chiffres ci-dessous valent à tous les étages.",
    ])


def fiche_sous_classe(doc, sc, g, c):
    doc.h1(NOMS_SOUS[sc])
    doc.p("Classe : **%s** ; orientation : %s ; images : %s ; animations de combat : %s." % (
        g["classe"], g["orientation"], ", ".join(g["images"]),
        ANIMS.get(g["anime"], "aucune (image fixe qui respire)")))
    doc.h2("Caractéristiques (premier étage, %d tirages)" % 300)
    tableau_stats(doc, g["stats"])
    doc.h2("Défenses")
    res = g["resistances"]
    doc.p("Armure, esquive et parade : voir le tableau. Vulnérabilités et résistances en pourcentage (négatif = faiblesse : "
          "il prend plus de dégâts de ce type) : %s."
          % (", ".join("%s %s %%" % (t, nombre(v)) for t, v in res.items()) if res else "**aucune** (0 % partout)"))
    doc.h2("Compétences jouées par l'IA")
    tableau_competences(doc, g["competences"], seulement_ia=True)
    doc.note("Dégâts moyens contre le héros de départ (%d PV, armure %s), avant critique."
             % (c["heros_pv"], nombre(c["heros_armure"])))
    autres = [x["nom"] for x in g["competences"] if not x["ia"]]
    if autres:
        doc.p("Il possède aussi, sans jamais les utiliser : %s." % ", ".join(autres))
    doc.h2("Comment il se bat")
    doc.p(IA_GOBELINS[sc])
    doc.h2("Ce que font ses compétences")
    descriptions(doc, [x for x in g["competences"] if x["ia"]])


def fiches_gobelins(d):
    c = d["communs"]
    doc = Doc("Gobelins — règles communes", "Tout ce qui vaut pour tous les gobelins ; chaque sorte a sa fiche dans "
                                           "son dossier.")
    regles_communes_gobelins(doc, c, renvoi=False)
    doc.h1("Les sortes de gobelins")
    lignes = []
    for sc in ["combattant", "lancier", "defenseur", "archer", "sorcier", "feticheur", "chaman"]:
        g = d["gobelins"][sc]
        att = [x["nom"] for x in g["competences"] if x["ia"]]
        lignes.append([NOMS_SOUS[sc], bornes(g["stats"]["points_de_vie_max"], ""), ", ".join(att)])
    doc.tableau(["Sorte", "PV", "Compétences jouées"], lignes)
    doc.enregistrer(os.path.join(ENNEMIS, "gobelin", "fiche technique - gobelins.odt"))
    for dossier, sous in DOSSIERS_GOBELINS.items():
        noms = ", ".join(NOMS_SOUS[s] for s in sous)
        doc = Doc(noms if len(sous) == 1 else "Gobelins guerriers", "Fiche technique : " + noms + ".")
        for sc in sous:
            fiche_sous_classe(doc, sc, d["gobelins"][sc], c)
        ecarts = []
        if dossier == "gobelin chaman":
            r = d["gobelins"]["chaman"]["resistances"]
            if not r:
                ecarts = ["Résistance de 15 % au feu, au froid et à la foudre : **pas dans le jeu** (0 %).",
                          "Faiblesse de 40 % à l'ombre : **pas dans le jeu** (0 %)."]
        section_fiche_utilisateur(doc, os.path.join(ENNEMIS, "gobelin", dossier), ecarts)
        regles_communes_gobelins(doc, c)
        doc.enregistrer(os.path.join(ENNEMIS, "gobelin", dossier, "fiche technique - %s.odt" % dossier))


# ---------------------------------------------------------------------------
# Chevalier, geôlier, diablotin, succube
# ---------------------------------------------------------------------------

def fiche_chevalier(d):
    c = d["communs"]
    k = d["chevalier"]
    doc = Doc("Chevalier de la mort", "L'« imbattable » : il traque le héros dans tout l'étage ; il faut le fuir.")
    doc.h1("Caractéristiques")
    tableau_stats(doc, k["stats"])
    doc.p("**300 PV**. Chaque coup qu'il reçoit est ramené à **1 ou 2 dégâts** (3 sur un coup critique), quels que "
          "soient le type et la force du coup.")
    doc.h1("Attaque")
    tableau_competences(doc, k["competences"])
    des = c["chevalier_des"]
    texte = " + ".join("%dd%d %s" % (x[0][0], x[0][1], t) for t, x in des.items())
    mini = sum(x[0][0] for x in des.values())
    maxi = sum(x[0][0] * x[0][1] for x in des.values())
    moy = sum(x[0][0] * (x[0][1] + 1) / 2 for x in des.values())
    doc.p("**Lame de la mort** : %s (27/10/2026 : « que le joueur réalise que c'est un combat "
          "ingagnable »), dés fixes, puis armure et résistances du héros. Il l'utilise à chaque tour : %d à %d dégâts "
          "avant armure, %s en moyenne (le héros de départ a %d PV)." % (texte, mini, maxi, nombre(moy), c["heros_pv"]))
    vm = c["chevalier_vol_mana"][0]
    doc.p("Chaque coup qui touche : **une chance sur %d de poser Usure** (dégâts physiques reçus +8 %% par cumul, jusqu'à "
          "5 fois, 6 tours) et **%dd%d de mana retirés** au héros (%d à %d), affichés au-dessus de son orbe de mana."
          % (round(100 / c["chevalier_usure"]), vm[0], vm[1], vm[0], vm[0] * vm[1]))
    doc.note("Comme toute attaque : environ 18 % de coups ratés, parade possible du héros, Saignement ou Usure parfois "
             "posés par le tranchant, rare critique magique sur l'ombre (× 1,25).")
    doc.h1("Dans l'étage")
    doc.liste([
        "%d par étage, plus un par gobelin pacifique tué (la colère)." % c["chevaliers"],
        "Il part du **milieu de l'étage** et va de salle en salle au hasard à la recherche du héros, même dans les salles "
        "où il n'est pas (environ %s s par salle)." % nombre(c["traversee"] / (c["vitesse_poursuite"]["imbattable"] * c["vitesse_salle"])),
        "Un **combat** l'attire : il apprend où est le héros et s'y rend.",
        "Une **action bruyante** (chaînes brisées) : s'il est à plus de %d salles, il se téléporte à %d salles du héros "
        "et sait où il est." % (c["ecart_vacarme"], c["ecart_vacarme"]),
        "Courir n'alerte que les ennemis de la salle.",
        "Dans la salle, il avance **au rythme de sa marche animée** (ses pieds ne glissent pas), en ronde comme en "
        "poursuite : %s hauteur de héros par seconde (le héros marche à 0,81). Vue %s hauteurs de héros, perd le héros "
        "après %s s ; une fois lancé, il le suit sur au moins %d salles (%d %% de chances de le suivre)."
        % (nombre(round(c["marche_chevalier"], 2)), nombre(c["vue"]["imbattable"]), nombre(c["perte"]["imbattable"]),
           c["traque"], round(c["chance_suivre"]["imbattable"] * 100)),
        "Pacte « Apaisement » de la succube : un chevalier de l'étage disparaît.",
    ])
    doc.h1("Images et animations")
    doc.liste([
        "Salles : marche animée (images de Grok, 4 vues : dos 55, face 31, profil 37, trois quarts 36 images, 12 images/s, "
        "miroir pour la gauche) ; immobile, il garde la première image.",
        "Combat : attente (respire), 2 attaques (épée abattue de haut en bas, toutes les images, 34 ms ; chacune finit "
        "par le retour en garde de Grok, l'attaque B commence par sa petite transition), 2 parades (il lève l'épée à "
        "l'horizontale juste avant le coup du héros). Placé au milieu, face au héros.",
    ])
    section_fiche_utilisateur(doc, os.path.join(ENNEMIS, "chevalier de la mort"), [])
    doc.enregistrer(os.path.join(ENNEMIS, "chevalier de la mort", "fiche technique - chevalier de la mort.odt"))


def fiche_geolier(d):
    c = d["communs"]
    doc = Doc("Geôlier", "Il ne se bat pas : il capture le héros et l'emmène au cachot.")
    doc.h1("Ce qu'il fait")
    doc.liste([
        "%d par étage, placés loin du départ." % c["geoliers"],
        "Au contact, **pas de combat** : il capture le héros. Tout l'équipement et l'or sont confisqués : %s %% dans le "
        "coffre des confiscations, %s %% perdus, %s %% portés par un gobelin « porteur » (%d objets au plus par porteur). "
        "L'arme portée va toujours dans le coffre." % (c["confiscation"]["coffre"], c["confiscation"]["perdu"],
                                                      c["confiscation"]["porteur"], c["objets_par_porteur"]),
        "Le héros se réveille au **cachot** : le cul-de-sac le plus loin de la salle du boss, à au moins 3 salles du "
        "départ (une capture ne rapproche pas du boss).",
        "Pacte « Baiser du geôlier » de la succube : la prochaine capture échoue, le geôlier s'enfuit dans une autre salle.",
    ])
    doc.h1("Dans l'étage")
    doc.liste([
        "Il va de salle en salle au hasard, **%s s par salle** (décision du 2026-10-27), même hors de la vue du héros."
        % nombre(c["duree_salle"]["geolier"]),
        "Un combat l'attire vers le héros. Une action bruyante : il se dirige vers la salle du bruit (sans se téléporter).",
        "Dans la salle, il avance **au rythme de sa marche animée** (ses pieds ne glissent pas ; décision du 27/10/2026), "
        "en ronde comme en poursuite : %s hauteur de héros par seconde, environ 4 fois moins vite que le héros qui marche "
        "(0,81). Vue %s hauteurs de héros, perd le héros après %s s, le suit dans la salle suivante %d %% du temps."
        % (nombre(round(c["marche_geolier"], 2)), nombre(c["vue"]["geolier"]), nombre(c["perte"]["geolier"]),
           round(c["chance_suivre"]["geolier"] * 100)),
    ])
    doc.h1("Caractéristiques de combat")
    doc.p("Aucune : il n'entre jamais en combat.")
    doc.h1("Images et animations")
    doc.p("Salles : marche animée de Grok (4 vues : dos 46, face 53, profil 52, trois quarts 29 images, 12 images/s, "
          "miroir pour la gauche ; outils/importer_animations_marche.py → images/pnj/geolier_anim) ; immobile, il garde "
          "la première image de sa vue. Il ne se bat pas : pas d'animation de combat.")
    section_fiche_utilisateur(doc, os.path.join(ENNEMIS, "geollier"), [])
    doc.enregistrer(os.path.join(ENNEMIS, "geollier", "fiche technique - geolier.odt"))


def fiche_diablotin(d):
    c = d["communs"]
    doc = Doc("Diablotin", "Personnage à qui parler : il renseigne le héros (parfois en mentant) et nourrit son journal.")
    doc.h1("Ce qu'il fait")
    doc.liste([
        "**%d par étage**. Il ne se bat pas et ne bouge pas." % c["diablotins"][0],
        "**Salle paisible** : aucun autre ennemi dans sa salle (ni groupe, ni porteur ; ceux qui poursuivent le héros "
        "ne l'y suivent pas), sauf le Chevalier de la mort et les geôliers, qui vont partout.",
        "Le héros lui parle avec E : « Le boss de l'étage ? », « Et cet étage ? », « Les ennemis ? ».",
        "Boss : sa faiblesse et sa force (vraies ou fausses). Ennemis : les règles du Chevalier de la mort, petit à "
        "petit (il résiste à tout, frappe tranchant et ombre, il vaut mieux fuir, le bruit l'attire).",
        "Étage : une réponse sur %d est un **mensonge**, seulement sur le donjon (fausse direction du pupitre ou d'une "
        "cachette, fausse salle secrète, faux coffre, lame bénie « qui blesse le Chevalier de la mort »). Jamais sur les "
        "ennemis. Il peut dire où se trouve l'équipement confisqué." % round(1 / c["mensonge"]),
        "Il ne dit jamais deux fois la même chose dans une partie. Tout va au **journal** du héros (J).",
    ])
    doc.h1("Caractéristiques de combat")
    doc.p("Aucune.")
    doc.h1("Images et animations")
    doc.p("Animations de Grok : respiration en boucle (48 images) et **rire** (73 images), 12 images/s ; il rit quand le "
          "héros approche (1,5 hauteur de héros) puis toutes les 8 à 16 s. 320 px de haut, pieds fixes.")
    section_fiche_utilisateur(doc, os.path.join(ENNEMIS, "diablotin"), [])
    doc.enregistrer(os.path.join(ENNEMIS, "diablotin", "fiche technique - diablotin.odt"))


def fiche_succube(d):
    c = d["communs"]
    effets = {"voile": "les ennemis voient 2 fois moins loin et le héros reste caché dans l'ombre même en marchant, "
                       "jusqu'à la fin de l'étage",
              "carte": "tout l'étage révélé (salles, cachettes, geôliers, chevaliers), jusqu'à la fin de l'étage",
              "baiser": "la prochaine capture par un geôlier échoue",
              "apaisement": "un Chevalier de la mort de l'étage disparaît",
              "mort": "la prochaine mort est annulée (réveil au cachot, 1 PV, sans rien perdre)"}
    doc = Doc("Succube", "Personnage à qui parler : elle propose des pactes payés en PV max.")
    doc.h1("Ce qu'elle fait")
    doc.p("Une succube **un étage sur %d** (étages 1, 3, 5...). Elle ne se bat pas. **Salle paisible** : aucun autre "
          "ennemi dans sa salle (ni groupe, ni porteur ; ceux qui poursuivent le héros ne l'y suivent pas), sauf le "
          "Chevalier de la mort et les geôliers." % c["etages_succube"])
    doc.tableau(["Pacte", "Prix (part des PV max du moment, perdus pour toujours)", "Effet"],
                [[c["noms_pactes"][k], "%d %%" % round(v * 100), effets[k]] for k, v in c["pactes"].items()])
    doc.h1("Images")
    doc.p("Images fixes (images/pnj/succube_1 à 3).")
    section_fiche_utilisateur(doc, os.path.join(ENNEMIS, "succube"), [])
    doc.enregistrer(os.path.join(ENNEMIS, "succube", "fiche technique - succube.odt"))


# ---------------------------------------------------------------------------
# Loups, squelettes (pas encore dans le jeu)
# ---------------------------------------------------------------------------

def fiche_a_venir(d, dossier, titre, connu, fichier):
    doc = Doc(titre, "Pas encore dans le jeu : ce que l'on sait, d'après ta fiche.")
    doc.alerte("Cet ennemi n'est pas encore dans le jeu : ses caractéristiques restent à définir.")
    doc.h1("Ce qui est décidé")
    doc.liste(connu)
    doc.h1("À définir")
    doc.liste(["PV et caractéristiques", "Compétences et comportement en combat", "Où et à quel étage il apparaît",
               "Comportement dans les salles (vitesse, vue)", "Images de combat et animations"])
    section_fiche_utilisateur(doc, os.path.join(ENNEMIS, dossier), [])
    doc.enregistrer(os.path.join(ENNEMIS, dossier, fichier))


def fiche_creature(d, sorte, dossier, titre, sous_titre, rencontre, salles):
    c = d["communs"]
    k = d["creatures"][sorte]
    doc = Doc(titre, sous_titre)
    doc.note("Dans le jeu depuis le 27/10/2026. Faiblesses, résistances, type et dé d'attaque, compagnons : décidés par "
             "toi. Caractéristiques, dé du loup, fréquences et vitesse : proposés par Claude, validés par toi le 27/10/2026.")
    doc.h1("Caractéristiques (300 tirages)")
    tableau_stats(doc, k["stats"])
    doc.h1("Défenses")
    doc.p("Résistances : %s (négatif = faiblesse : il prend plus de dégâts de ce type)."
          % ", ".join("%s %s %%" % (t, nombre(v)) for t, v in k["resistances"].items()))
    doc.h1("Attaque")
    tableau_competences(doc, k["competences"])
    doc.note("Dégâts moyens contre le héros de départ (%d PV, armure %s). Ses dés comptent tels quels (pas un cran "
             "plus bas comme ceux des gobelins)." % (c["heros_pv"], nombre(c["heros_armure"])))
    doc.p("Il frappe avec cette attaque à chaque tour (1 point d'action). Comme les gobelins, il peut boire une potion "
          "s'il en a une (30 %) quand il tombe à la moitié de ses PV.")
    doc.h1("Où on le rencontre")
    doc.liste(rencontre)
    doc.h1("Dans les salles")
    doc.liste(salles)
    doc.h1("Images")
    doc.p("Image fixe détourée (images/gobelins/%s, outils/importer_loup_squelette.py) qui respire, en salle comme en "
          "combat ; pas encore d'animations." % k["image"])
    section_fiche_utilisateur(doc, os.path.join(ENNEMIS, dossier), [])
    doc.enregistrer(os.path.join(ENNEMIS, dossier, "fiche technique - %s.odt" % sorte))


def main():
    r = subprocess.run([GODOT, "--headless", "--path", ICI, "-s", "tests/exporter_fiches_ennemis.gd"],
                       capture_output=True, text=True, encoding="utf8", errors="replace", timeout=600)
    if "FICHES" not in r.stdout:
        print(r.stdout[-3000:], r.stderr[-3000:])
        raise SystemExit("export Godot raté")
    d = json.load(open(EXPORT, encoding="utf8"))
    fiches_gobelins(d)
    fiche_chevalier(d)
    fiche_geolier(d)
    fiche_diablotin(d)
    fiche_succube(d)
    c = d["communs"]
    fiche_creature(d, "loup", "loup", "Loup", "Bête qui accompagne les archers et les chamans gobelins.", [
        "Dès le premier étage, dans les groupes de gobelins qui comptent un archer ou un chaman : un loup les "
        "accompagne %d %% du temps. Jamais seul, jamais sans humanoïde." % round(c["chance_loup"] * 100),
        "Il partage le sort du groupe : pacifique si le groupe l'est."],
        ["Il se déplace avec son groupe de gobelins (mêmes vitesse, vue et ouïe que les gobelins)."])
    fiche_creature(d, "squelette", "squelette", "Squelette", "Mort-vivant à l'épée rouillée.", [
        "Dès le premier étage : %d %% des groupes sans élite ni pacifiques sont des squelettes, 1 à 3 selon l'étage "
        "(un squelette peut être seul)." % round(c["chance_groupe_squelettes"] * 100),
        "Seul compagnon possible pour l'instant : un féticheur gobelin, qui mène les groupes de 2 squelettes ou plus "
        "%d %% du temps (ta fiche permet aussi animaux, autres morts-vivants et nécromanciens, qui n'existent pas "
        "encore)." % round(c["chance_feticheur_squelettes"] * 100)],
        ["Groupe plus lent que les gobelins : poursuite %s × la course du héros (gobelins %s)."
         % (nombre(c["vitesse_squelettes"]), nombre(c["vitesse_poursuite"]["groupe"])),
         "Vue, ouïe et perte de la trace : comme les gobelins."])


if __name__ == "__main__":
    main()
