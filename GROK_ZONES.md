# Notice pour Grok Bot : retoucher les zones des salles du jeu

Tu vas corriger les **zones** des salles peintes du jeu (où le héros peut marcher, ce qui l'arrête, ce qui passe
devant lui). Tout se fait avec **un seul outil en ligne de commande**, à lancer sur le PC local depuis ce dossier :

```
cd "C:\Users\Geoffrey\Documents\LE_Jeu\LE jeu\version Claude\version Godot\godot"
python outils/zones.py <commande> ...
```

Ne modifie **aucun autre fichier** du jeu. N'édite pas les .json à la main : passe toujours par `outils/zones.py`.

## Ce que sont les zones

Chaque salle est une image de **768 × 512 pixels** (origine en haut à gauche, y vers le bas). Les zones sont des
polygones en pixels de cette image :

| Couche | Couleur | Étiquette | Rôle dans le jeu |
|---|---|---|---|
| `marche` | vert | S0, S1… | le **sol** où le héros peut poser les pieds |
| `obstacles` | rouge | O0, O1… | ce qui **arrête** le héros (rochers, gravats, **pied** des piliers, braseros) |
| `premier_plan` | bleu | P0, P1… | ce qui **passe devant** le héros quand il est derrière (piliers entiers) ; coupe aussi la vue des ennemis |
| `sorties` | jaune | X0, X1… | passages vers la salle voisine |

Règles à respecter :
- **Vert** : seulement le sol plat praticable. Pas les marches d'un escalier qui ne mène nulle part, pas le haut des murs.
  Plusieurs zones vertes se cumulent.
- **Rouge** : seulement l'**emprise au sol** de l'objet (là où il touche le sol). Pour un pilier : un ovale aplati à son
  pied, pas le pilier entier.
- **Bleu** : l'objet **entier**, de son pied jusqu'en haut. Le **point le plus bas** de la zone bleue doit être au pied
  de l'objet : le héros n'est caché que s'il est plus haut que ce point dans l'image (plus loin).
- **Jaune** : on ne peut **ni créer ni retirer** de sortie (le plan du donjon compte sur leur nombre et leur ordre) ;
  seulement déplacer leurs points ou remplacer leur forme. Une sortie doit toucher le vert, sinon on ne peut pas l'atteindre.
- Les zones ont au moins 3 points ; tous les points restent dans l'image (0–768, 0–512).

## Méthode

1. **Regarder** : `python outils/zones.py voir <salle>` écrit une image (chemin affiché) : l'image de la salle,
   les zones colorées avec leurs points et leur étiquette, et un quadrillage chiffré tous les 32 px. Ouvre-la.
2. **Zoomer** sur un endroit précis : `python outils/zones.py voir <salle> x0 y0 x1 y1` (par exemple
   `voir grande5 80 330 240 420`) : quadrillage tous les 16 px.
3. **Lire les coordonnées exactes** : `python outils/zones.py lister <salle> [couche]`.
4. **Corriger** (chaque commande enregistre aussitôt) :
   - `ajouter <salle> <couche> "x,y x,y x,y ..."` : nouvelle zone (pas pour `sorties`) ;
   - `remplacer <salle> <couche> <n°> "x,y x,y ..."` : redessine la zone n° (par exemple O3 → `obstacles 3`) ;
   - `deplacer <salle> <couche> <n°> <point> <x> <y>` : déplace un seul point (n° de point dans `lister`) ;
   - `retirer <salle> <couche> <n°>` : supprime la zone (pas pour `sorties`) ; attention, les numéros suivants
     diminuent de 1 : relance `lister` avant la commande suivante ;
   - `couche <salle> <couche> <fichier.json>` : remplace toute une couche (`[[[x,y],[x,y],...], ...]`) ;
   - `annuler <salle>` : revient en arrière d'une modification (autant de fois que nécessaire).
5. **Vérifier visuellement** : relance `voir` après chaque correction.
6. **Vérifier dans le jeu** : `python outils/zones.py verifier <salle>` (1 à 3 minutes) : le héros court dans
   toutes les directions ; il faut lire `BILAN collisions : 0 échec(s)`. Sinon, corriger (souvent : un trou dans
   le vert, ou une sortie qui ne touche pas le vert).

`python outils/zones.py salles` donne la liste des salles (culdesac1–7, grande1–10, porte1–6, salle1, salle2).
`python outils/zones.py` sans argument affiche l'aide.

## À la fin

Donne la liste des salles modifiées et, pour chacune, ce qui a été changé (en une ligne) et le BILAN de
`verifier`. L'utilisateur peut aussi tout revoir dans l'éditeur du jeu (`editeur_zones.bat`).
