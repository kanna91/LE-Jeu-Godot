"""Écrit les plans trouvés par assembler.py dans scripts/logique/blocs_salles.gd (positions, miroirs, liens, entrées)."""
import json, re, sys

portes = json.load(open(sys.argv[1], encoding='utf-8'))
plan = json.load(open(sys.argv[2], encoding='utf-8'))
p = 'scripts/logique/blocs_salles.gd'
s = open(p, encoding='utf-8').read()

for bloc, pl in plan.items():
    R = portes[bloc]
    # Miroir d'origine gardé quand il ne change aucune porte utilisée
    utilisees = {}
    for l in pl['liens']:
        utilisees.setdefault(l[0], set()).add(l[1])
        utilisees.setdefault(l[2], set()).add(l[3])
    for e in pl['entrees']:
        utilisees.setdefault(e[0], set()).add(e[1])
    mir = dict(pl['mir'])
    for k in R:
        orig = R[k]['miroir']
        if mir[k] != orig:
            d_new = R[k]['m'] if mir[k] else R[k]['n']
            d_old = R[k]['m'] if orig else R[k]['n']
            if all(d_new[i] == d_old[i] for i in utilisees.get(k, ())):
                mir[k] = orig
    # Le plan commence à la case (0, 0) du départ : décaler pour que tout soit en y >= 0 n'est pas nécessaire
    debut = s.index('\t"%s": {' % bloc)
    fin_salles = s.index('\t\t},\n', s.index('"salles": {', debut))
    bloc_salles = s[debut:fin_salles]
    def remplacer_salle(m):
        cle = m.group(1)
        ligne = m.group(0)
        x, y = plan[bloc]['pos'][cle]
        ligne = re.sub(r'"position": Vector2i\([-0-9]+, [-0-9]+\)', '"position": Vector2i(%d, %d)' % (x, y), ligne)
        ligne = ligne.replace(', "miroir": true', '')
        if mir[cle]:
            ligne = ligne[:ligne.rindex('}')] + ', "miroir": true}' + ligne[ligne.rindex('}') + 1:]
        return ligne
    nouveau = re.sub(r'^\t\t\t"([a-z_]+)": \{"image".*$', remplacer_salle, bloc_salles, flags=re.M)
    s = s[:debut] + nouveau + s[fin_salles:]
    # Liens
    exceptions = {(a, b) for a, b in pl['exceptions']}
    debut = s.index('\t"%s": {' % bloc)
    i_liens = s.index('"liens": [\n', debut) + len('"liens": [\n')
    j_liens = s.index('\t\t],\n', i_liens)
    lignes = []
    for l in pl['liens']:
        exc = (l[0], l[2]) in exceptions
        lignes.append('\t\t\t["%s", %d, "%s", %d%s],\n' % (l[0], l[1], l[2], l[3], ', "par le bas"' if exc else ''))
    s = s[:i_liens] + ''.join(lignes) + s[j_liens:]
    # Entrées
    debut = s.index('\t"%s": {' % bloc)
    i_e = s.index('"entrees": [\n', debut) + len('"entrees": [\n')
    j_e = s.index('\t\t],\n', i_e)
    s = s[:i_e] + ''.join('\t\t\t["%s", %d, Vector2i(%d, %d)],\n' % (e[0], e[1], e[2][0], e[2][1]) for e in pl['entrees']) + s[j_e:]
    print(bloc, 'miroirs :', sorted(k for k in mir if mir[k]), '| exceptions :', len(exceptions))

open(p, 'w', encoding='utf-8', newline='').write(s)
