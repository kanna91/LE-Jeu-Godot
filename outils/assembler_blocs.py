"""Assemblage automatique des blocs de salles (Claude, 2026-11-10).

Après une retouche des portes des salles de blocs :
  1. godot --headless --path . -s outils/exporter_portes_blocs.gd -- C:/chemin/portes.json
  2. python outils/assembler_blocs.py C:/chemin/portes.json 4000 23   (essais, graine ; écrit plan23.json à côté)
  3. python outils/ecrire_plans_blocs.py C:/chemin/portes.json C:/chemin/plan23.json   (réécrit blocs_salles.gd)
  4. tests/test_liens_blocs.gd puis tests/test_blocs.gd
Essaie des milliers d'assemblages porte à porte (gauche ↔ droite, fond ↔ bas, miroir permis) et garde celui qui a
le moins de liens « par le bas », les ailes groupées et une emprise de 7 × 9 cases au plus. Lancer plusieurs graines
en parallèle et garder le meilleur score.
"""
import json, random, sys
VEC = {'gauche': (-1, 0), 'droite': (1, 0), 'devant': (0, 1), 'bas': (0, -1)}
OPP = {'gauche': 'droite', 'droite': 'gauche', 'devant': 'bas', 'bas': 'devant'}
D = json.load(open(sys.argv[1], encoding='utf-8'))


def groupe(bloc, cle):
    if bloc == 'cuisine':
        return 'cuisine' if cle in ('manger', 'cuisine', 'petite', 'cellier_g', 'cellier_d') else cle.split('_')[0]
    if bloc == 'laboratoire':
        p = cle.split('_')[0]
        return 'centre' if p in ('salle', 'grande', 'reserve', 'couloir') else p
    return 'b'


BOITE = {'laboratoire': (7, 9), 'cuisine': (7, 9), 'bibliotheque': (7, 7)}


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def resoudre(bloc, fixe, nb_entrees, essais, prefs_entree=(), graine=0):
    R = D[bloc]
    meilleur = None
    rnd = random.Random(graine)
    record = 0
    for essai in range(essais):
        seuil = rnd.choice([1.0, 0.99, 0.97, 0.9, 0.8])
        pos = {k: tuple(v[0]) for k, v in fixe['pos'].items()}
        mir = {k: v[1] for k, v in fixe['pos'].items()}
        occ = {v: k for k, v in pos.items()}
        prises = set(tuple(p) for p in fixe['prises'])
        liens = [list(l) for l in fixe['liens']]
        reste = [k for k in R if k not in pos]

        def dirs(k):
            return R[k]['m'] if mir[k] else R[k]['n']
        ok = True
        exceptions = [[l[0], l[2]] for l in fixe['liens'] if l[2].startswith('cellier')]
        while reste:
            xs = [q[0] for q in pos.values()]
            ys = [q[1] for q in pos.values()]
            W, H = BOITE.get(bloc, (99, 99))

            def hors(t):
                return t in occ or (t[0] == 0 and t[1] < 0) or max(max(xs), t[0]) - min(min(xs), t[0]) >= W                     or max(max(ys), t[1]) - min(min(ys), t[1]) >= H
            opts_par = {}
            for k in reste:
                o = []
                for m in (False, True):
                    dk = R[k]['m'] if m else R[k]['n']
                    for j, d in enumerate(dk):
                        for a in pos:
                            for i, da in enumerate(dirs(a)):
                                if (a, i) in prises or da != OPP[d]:
                                    continue
                                t = add(pos[a], VEC[da])
                                if hors(t):
                                    continue
                                o.append((a, i, k, j, m, t, 0))
                        # exception des celliers : une porte de côté mène à une salle où l'on entre par le bas
                        if d == 'bas':
                            for a in pos:
                                for i, da in enumerate(dirs(a)):
                                    if (a, i) in prises or da not in ('gauche', 'droite', 'bas'):
                                        continue
                                    t = add(pos[a], VEC[da])
                                    if not hors(t):
                                        o.append((a, i, k, j, m, t, 1))
                opts_par[k] = o
            if any(not opts_par[x] for x in reste) and all(not opts_par[x] for x in reste):
                ok = False
                break
            coh = {x: [o for o in opts_par[x] if o[6] == 0] for x in reste}
            avec = [x for x in reste if coh[x]]
            if avec and rnd.random() < seuil:
                k = min(avec, key=lambda x: (-(any(groupe(bloc, o[0]) == groupe(bloc, x) for o in coh[x])), len(coh[x]), rnd.random()))
                o = coh[k]
            else:
                pleins = [x for x in reste if opts_par[x]]
                k = min(pleins, key=lambda x: (len(opts_par[x]), rnd.random()))
                o = opts_par[k]
            meme = [x for x in o if groupe(bloc, x[0]) == groupe(bloc, k)]
            if meme and rnd.random() < 0.9:
                o = meme
            a, i, k, j, m, t, exc = rnd.choice(o)
            if exc:
                exceptions.append([a, k])
            pos[k] = t
            mir[k] = m
            occ[t] = k
            prises.add((a, i))
            prises.add((k, j))
            liens.append([a, i, k, j])
            reste.remove(k)
        if not ok:
            record = max(record, len(pos))
            continue
        # boucles : deux portes libres qui se font face
        for a in list(pos):
            for i, da in enumerate(dirs(a)):
                if (a, i) in prises:
                    continue
                b = occ.get(add(pos[a], VEC[da]))
                if b is None:
                    continue
                for j, db in enumerate(dirs(b)):
                    if (b, j) not in prises and db == OPP[da]:
                        prises.add((a, i))
                        prises.add((b, j))
                        liens.append([a, i, b, j])
                        break
        # entrées : nord ou sud, vers l'extérieur (aucune salle du bloc plus loin dans la colonne)
        cand = []
        for a in pos:
            for i, da in enumerate(dirs(a)):
                if (a, i) in prises or da not in ('devant', 'bas'):
                    continue
                x, y = pos[a]
                if da == 'devant' and any(p[0] == x and p[1] > y for p in pos.values()):
                    continue
                if da == 'bas' and any(p[0] == x and p[1] < y for p in pos.values()):
                    continue
                cand.append((a, i, VEC[da]))
        entrees = [list(e) for e in fixe['entrees']]
        cases_ext = {add(pos[e[0]], tuple(e[2])) for e in entrees}
        cand.sort(key=lambda c: (-(c[0] in prefs_entree), -(c[2] == (0, 1)), rnd.random()))
        for c in cand:
            if len(entrees) >= nb_entrees:
                break
            ce = add(pos[c[0]], c[2])
            if any(abs(ce[0] - e[0]) + abs(ce[1] - e[1]) < 3 for e in cases_ext):
                continue
            entrees.append([c[0], c[1], c[2]])
            cases_ext.add(ce)
        if len(entrees) < nb_entrees:
            continue
        xs = [p[0] for p in pos.values()]
        ys = [p[1] for p in pos.values()]
        aire = (max(xs) - min(xs) + 1) * (max(ys) - min(ys) + 1)
        intra = sum(groupe(bloc, l[0]) == groupe(bloc, l[2]) for l in liens)
        boucles = len(liens) - (len(R) - 1)
        nord = sum(tuple(e[2]) == (0, 1) for e in entrees)
        score = -1000 * len(exceptions) + 25 * intra - aire + 3 * boucles + 5 * sum(e[0] in prefs_entree for e in entrees) + 8 * min(nord, 1)
        if meilleur is None or score > meilleur[0]:
            meilleur = (score, dict(pos), dict(mir), liens, entrees, aire, intra, boucles, exceptions)
    if meilleur is None:
        print(bloc, 'au mieux', record, 'salles posées sur', len(R))
    return meilleur


def afficher(bloc, m):
    if m is None:
        print(bloc, 'AUCUNE SOLUTION')
        return
    score, pos, mir, liens, entrees, aire, intra, boucles, exceptions = m
    print('  exceptions', exceptions)
    print('==', bloc, 'score', score, 'aire', aire, 'liens internes', intra, '/', len(liens), 'boucles', boucles)
    xs = [p[0] for p in pos.values()]
    ys = [p[1] for p in pos.values()]
    inv = {v: k for k, v in pos.items()}
    for y in range(max(ys), min(ys) - 1, -1):
        print('  ' + ' '.join((inv.get((x, y), '.')[:14]).ljust(14) for x in range(min(xs), max(xs) + 1)))
    print('  entrees', entrees)


if __name__ == '__main__':
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 1500
    res = {}
    bib = {'pos': {'vestibule': ((0, 0), False)}, 'prises': [('vestibule', 2)], 'liens': [],
           'entrees': [['vestibule', 2, (0, -1)]]}
    res['bibliotheque'] = resoudre('bibliotheque', bib, 2, n, graine=1)
    cui = {'pos': {'manger': ((0, 0), False), 'cuisine': ((0, 1), False), 'petite': ((0, 2), False),
                   'cellier_g': ((-1, 2), False), 'cellier_d': ((1, 2), False), 'potager_entree': ((0, 3), False)},
           'prises': [('manger', 1), ('manger', 0), ('cuisine', 1), ('cuisine', 0), ('petite', 3), ('petite', 1),
                      ('petite', 2), ('cellier_g', 0), ('cellier_d', 0), ('petite', 0), ('potager_entree', 2)],
           'liens': [['manger', 0, 'cuisine', 1], ['cuisine', 0, 'petite', 3], ['petite', 1, 'cellier_g', 0],
                     ['petite', 2, 'cellier_d', 0], ['petite', 0, 'potager_entree', 2]],
           'entrees': [['manger', 1, (0, -1)]]}
    res['cuisine'] = resoudre('cuisine', cui, 3, n, prefs_entree=[k for k in D['cuisine'] if k.startswith('verger')], graine=2)
    dl = D['laboratoire']['couloir_sud']['n']
    lab = {'pos': {'couloir_sud': ((0, 0), False)}, 'prises': [('couloir_sud', dl.index('bas'))], 'liens': [],
           'entrees': [['couloir_sud', dl.index('bas'), (0, -1)]]}
    res['laboratoire'] = resoudre('laboratoire', lab, 3, n,
                                  prefs_entree=['couloir_ouest', 'couloir_nord', 'couloir_entree', 'couloir_reserve'], graine=int(sys.argv[3]) if len(sys.argv) > 3 else 3)
    for b, m in res.items():
        afficher(b, m)
    json.dump({b: {'pos': {k: list(v) for k, v in m[1].items()}, 'mir': m[2], 'liens': m[3],
                   'entrees': [[e[0], e[1], list(e[2])] for e in m[4]], 'exceptions': m[8]} for b, m in res.items() if m},
              open(sys.argv[1].replace('portes.json', 'plan%s.json' % (sys.argv[3] if len(sys.argv) > 3 else '')), 'w', encoding='utf-8'), ensure_ascii=False)
