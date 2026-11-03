# Cuisine — document de conception (codé le 2026-11-03)

Code : `scripts/logique/cuisine.gd` (Cuisine), `scripts/logique/maux.gd` (Maux, mal persistant),
`scripts/ecrans/menu_cuisine.gd` (écran, touche **K** en exploration), onglet « Feux » de l'éditeur de zones (touche 8).
Test : `tests/test_cuisine.gd` (le jeu redonne exactement la liste complète). Choix faits par Claude en codant (§8).

Base de référence de la cuisine de LE Jeu, construite avec l'utilisateur le 2026-11-03.
**[Décidé]** = décision de l'utilisateur. **[Proposé]** = proposition de Claude, à valider.
Les valeurs des ingrédients et des plats sont **cachées au joueur** [Décidé].

## 1. Règles décidées

- **[Décidé]** Les plats ne s'utilisent **pas en combat** (déjà le cas : le combat ne propose que les potions).
- **[Décidé]** Plats trouvés tout faits : soupe et viande grillée 35 PV, viande bouillie 30, viande séchée 25,
  fruits crus 15.
- **[Décidé]** Pierres en 3 tailles : petite = prix actuel, normale ×2, grande ×3
  (rubis, émeraude, saphir 80 / 160 / 240 ; grenat 40 / 80 / 120).
- **[Décidé]** Plats complexes (mijotés, four) : seulement dans **la cuisine** ou dans un lieu dédié.
- **[Décidé]** Recettes connues dès le début : viande grillée, viande bouillie, brochette, compote. Les autres
  s'apprennent par des **essais**, des **pages de livre de cuisine** ou des **prisonniers**.
- **[Décidé]** Une recette respectée réussit toujours.
- **[Décidé]** Valeurs de mana gardées telles quelles : les plats ne servent pas en combat et ne seront pas
  abondants.
- **[Décidé]** Mélange qui n'est pas une recette : **mixture** = la moitié des valeurs des ingrédients. Mélange
  **incohérent (immonde)** = un quart.
- **[Décidé]** Bonus pour les recettes longues (+0,1 au multiplicateur par ingrédient au-delà de 2).
- **[Décidé]** Nouveaux ingrédients d'accord (œuf, lait, farine, miel, champignon, herbes, ail).
- **[Décidé]** Jardin et potager de plusieurs salles à venir (sources d'ingrédients).

## 2. Mal persistant (intoxication, et plus tard la maladie)

**[Décidé]**, à coder comme **une seule fonction réutilisable** : la viande périmée l'utilise, la maladie
l'utilisera aussi. Réglages par cause :

| Réglage | Intoxication (viande périmée) |
|---|---|
| Régénération de PV par minute | **arrêtée** pendant toute la durée |
| Perte | **4 PV par minute** |
| Durée | **8 minutes** |
| Rythme | un tic **toutes les 15 secondes** (1 PV par tic, soit 32 PV en tout) |

- **[Décidé]** Il **peut tuer**.
- **[Décidé]** Une 2ᵉ intoxication **ajoute sa durée** à celle en cours (8 min de plus).
- **[Décidé]** Remède : pas encore défini (potion anti-maladie, mélange d'herbes… l'**établi d'alchimie** viendra
  plus tard). Prévoir dans la fonction un moyen de guérir.
- **[Décidé]** Le temps compte **en exploration et en combat**, **pas dans les menus**.

## 3. Le feu et l'eau

**Où trouver du feu [Décidé] :**
1. **Torche murale de la salle** : elle sert **seulement à allumer du bois** ; on ne cuit **rien** à même la torche
   (décision de l'utilisateur, 2026-11-03, qui remplace « griller à la torche »). Les torches sont marquées dans
   l'éditeur (onglet « Feux » ; l'utilisateur les place lui-même).
2. **Feu de camp** (n'importe quelle salle) : griller **et** bouillir. Il consomme **1 combustible** (morceau de bois
   ou planche), allumé :
   - **à une torche** (on allume son bois à la torche, puis on va poser le feu où l'on veut) ;
   - **ou avec amadou + silex** : pas besoin d'aller jusqu'à une torche.
   - Pas de sort de feu (inutile dans un donjon rempli de torches).
   - Durée limitée : **3 plats maximum et 10 minutes maximum**, puis il s'éteint ; le bois est entièrement consommé.
   - Pas de risque lié au feu (bruit, lumière) pour le moment.
3. **Le foyer de la cuisine** (et des lieux dédiés) : feu permanent, gratuit, le seul qui permet le **mijoté** et le
   **four**.

**L'eau et la marmite :**
- **[Décidé]** **Marmite** : ustensile jamais consommé, obligatoire pour bouillir et mijoter.
- **[Décidé]** **Seau en bois** de **10 litres** : 1 L par plat bouilli, 2 L par plat mijoté.
- **[Décidé]** Dans **la cuisine, l'eau est infinie** (pour le moment, l'utilisateur y reviendra peut-être).
- **[Décidé]** **Points d'eau** : marqués dans l'éditeur (onglet « Eau », touche 9) ; près d'un point d'eau, on
  remplit son seau (10 L). L'utilisateur choisit où il y en a (puits, fontaines, salles générées exprès).
  **[En attente]** Les eaux croupies (1 chance sur 4 d'intoxication) : pas codées.
- **[Décidé]** Le bouilli rapporte plus que le grillé (×1,5 contre ×1,4) ; la viande bouillie est une vraie recette
  (viande + oignon ou carotte).
- **[Décidé]** **Bouillon** : une recette bouillie avec de la viande laisse un objet « Bouillon ». Il se **boit**
  (5 PV, 5 mana) ou s'ajoute à **un seul plat** : il y ajoute sa valeur (5/5) **sans jamais remplacer l'eau** (le
  plat consomme toujours son eau : 1 L bouilli, 2 L mijoté hors de la cuisine).

## 4. Assemblage d'un plat

**Valeur du plat = (somme des valeurs des ingrédients) × multiplicateur**, arrondi.

| Préparation | Multiplicateur | Il faut |
|---|---|---|
| Recette sans feu (salade, assemblage) | ×1,1 | rien |
| Grillé | ×1,4 | un feu de camp ou la cuisine (pas à même une torche) |
| Bouilli | ×1,5 | marmite + 1 L d'eau + feu de camp ou cuisine |
| Mijoté, four | ×1,8 | la cuisine ou un lieu dédié (+ 2 L d'eau pour le mijoté) |
| Bonus des recettes longues | +0,1 par ingrédient au-delà de 2 | — |
| **Mixture** (mélange cohérent, pas une recette) | **×0,5** (sans multiplicateur de cuisson) | — |
| **Immonde** (mélange incohérent) | **×0,25** | — |

## 5. Valeurs des ingrédients (cachées)

| Ingrédient | Famille | PV | Mana |
|---|---|---|---|
| Viande crue | viande | 25 | 0 |
| Viande périmée | viande | 25 | 0 (intoxication 1 fois sur 2) |
| Pomme de terre | légume | 10 | 0 |
| Chou | légume | 8 | 2 |
| Navet | légume | 6 | 2 |
| Carotte | légume | 5 | 3 |
| Poireau | légume | 4 | 4 |
| Tomate | légume | 4 | 4 |
| Oignon | légume fort | 2 | 6 |
| Ail | légume fort | 2 | 5 |
| Pomme, poire | fruit doux | 15 | 0 |
| Orange, prune | fruit | 12 | 3 |
| Raisin | fruit | 10 | 5 |
| Citron | fruit acide | 5 | 10 |
| Œuf | œuf | 12 | 0 |
| Lait | laitage | 8 | 2 |
| Farine | céréale | 6 | 0 |
| Miel | sucré | 8 | 6 |
| Champignon | champignon | 3 | 8 |
| Herbes | aromate | 0 | 6 |

## 6. Toutes les recettes, classées

Avec 20 ingrédients et jusqu'à 4 par plat, il y a des milliers de mélanges possibles. Le classement complet se fait
donc avec **trois listes** : les recettes (A), les mélanges immondes (C) et, pour tout le reste, la mixture (B).
Un mélange qui contient une paire immonde est immonde, même s'il ressemble à une recette.

### A. Recettes correctes (multiplicateur de leur préparation)

| # | Plat | Recette | Préparation | PV | Mana | Connue au départ |
|---|---|---|---|---|---|---|
| 1 | Viande grillée | viande | grillé | 35 | 0 | oui |
| 2 | Pomme de terre grillée | pomme de terre | grillé | 14 | 0 | |
| 3 | Tomates farcies | tomate + viande | grillé | 41 | 6 | |
| 4 | Omelette | 2 œufs | grillé | 34 | 0 | |
| 5 | Brochette | viande + oignon + tomate | grillé | 47 | 15 | oui |
| 6 | Viande marinée au citron | viande + citron + oignon | grillé | 48 | 24 | |
| 7 | Omelette aux champignons | 2 œufs + champignon | grillé | 41 | 12 | |
| 8 | Champignons à l'ail | 2 champignons + ail | grillé | 12 | 32 | |
| 9 | Viande bouillie | viande + oignon (ou carotte) | bouilli | 40 | 9 | oui |
| 10 | Compote | 2 fruits au choix | bouilli | 23 à 45 | 0 à 23 | oui |
| 11 | Purée | 2 pommes de terre | bouilli | 30 | 0 | |
| 12 | Œufs durs | 2 œufs | bouilli | 36 | 0 | |
| 13 | Soupe de légumes | 2 légumes au choix (pas d'ail seul) | bouilli | 9 à 27 | 0 à 15 | |
| 14 | Soupe à l'oignon | 3 oignons | bouilli | 10 | 29 | |
| 15 | Soupe aux champignons | 2 champignons + herbes | bouilli | 10 | 35 | |
| 16 | Bouillie au miel | farine + lait + miel | bouilli | 35 | 13 | |
| 17 | Ragoût | viande + pomme de terre + carotte | mijoté | 76 | 6 | |
| 18 | Soupe au chou | chou + pomme de terre + oignon | mijoté | 38 | 15 | |
| 19 | Pot-au-feu | viande + carotte + navet + poireau | mijoté | 80 | 18 | |
| 20 | Civet aux champignons | viande + champignon + oignon + herbes | mijoté | 60 | 40 | |
| 21 | Légumes mijotés aux herbes | tomate + oignon + ail + herbes | mijoté | 16 | 42 | |
| 22 | Pain | farine + lait | four | 25 | 4 | |
| 23 | Galette au miel | farine + œuf + miel | four | 49 | 11 | |
| 24 | Gratin | pomme de terre + lait + œuf | four | 57 | 4 | |
| 25 | Tarte aux fruits | farine + œuf + 1 fruit doux | four | 63 | 0 | |
| 26 | Salade de fruits | 3 fruits | sans feu | 32 à 54 | 0 à 22 | |
| 27 | Ragoût douteux | viande périmée + 2 légumes | mijoté | ≈ 76 | ≈ 6 | intoxication 1 fois sur 2 |
| 28 | Lait chaud **[Décidé]** | lait | bouilli | 12 | 3 | |

### B et C. Mixtures et plats immondes : la liste complète

**Liste complète générée** : `outils/cuisine/combinaisons.csv` (s'ouvre dans LibreOffice ou Excel), résumé dans
`outils/cuisine/resume.md`. Elle est produite par `python outils/cuisine_combinaisons.py` à partir de
`donnees/cuisine.json`, que le jeu lira aussi : changer une règle ou une valeur dans ce fichier, puis relancer le
script, met la liste à jour.

**Combien de mélanges ?** 22 ingrédients (pomme et poire, orange et prune sont distincts), de 1 à 4 dans un plat, le
même ingrédient pouvant revenir (« 2 œufs », « 3 oignons ») : **14 949 mélanges**, soit 22 + 253 + 2 024 + 12 650
(de 1, 2, 3, 4 ingrédients). Sans répétition : 9 108. Avec les 4 préparations (sans feu, grillé, bouilli,
mijoté / four) : 59 796 plats. L'utilisateur avait compté 336 en ne prenant que des ingrédients différents ; les
recettes à ingrédient répété (2 œufs, 3 oignons) en ajoutent beaucoup.

**Mixture (×0,5)** : tout mélange qui n'est pas une recette et qu'aucune règle immonde ne touche. Exemples : viande
et pomme grillées (comme le porc aux pommes : ça se mange), carotte et navet grillés, une recette faite
avec la mauvaise préparation (une brochette bouillie). Quand un mélange contient les ingrédients d'une recette avec la
mauvaise préparation, la liste le signale (« presque : … ») : de quoi donner un indice au joueur.

**Immonde (×0,25)** : règles, dans l'ordre (la 1ʳᵉ qui s'applique donne la raison) :

| Règle | Exemple |
|---|---|
| viande avariée : immangeable, et intoxication 1 fois sur 2 (sauf dans sa recette, le ragoût douteux, qui intoxique quand même) | viande périmée grillée |
| le lait caille avec le citron ou l'orange | lait + citron |
| sucré (fruit, miel) avec de l'ail ou des champignons | pomme + ail |
| oignon dans un plat sucré, sans viande pour le justifier | miel + oignon (avec de la viande : passe, comme un chutney) |
| dessert et potage mélangés : sucré avec 2 légumes ou plus | poire + carotte + chou |
| seulement de l'ail, des herbes ou du citron | ail + herbes |
| 3 fois ou plus le même ingrédient fort (ail, citron, herbes) | 3 citrons |
| farine sans œuf ni lait : de la colle, ou de la farine brûlée | farine + carotte |
| **[Décidé]** viande crue mangée sans cuisson : immonde, et **intoxication 1 fois sur 4** | viande crue sans feu |
| sans feu : œuf, pomme de terre ou farine crus | pomme de terre crue |
| grillé : on ne grille pas du lait (sans œuf pour le lier) | lait grillé |

Changement par rapport à la 1ʳᵉ version : **viande + fruit** et **viande + miel** ne sont plus immondes, ça existe en
vrai (porc aux pommes, canard à l'orange, viande au miel).

**Résultat** :

| Préparation | Recettes | Mixtures | Immondes |
|---|---|---|---|
| Sans feu (hors les 20 ingrédients seuls non carnés, qui ne sont pas des plats) | 55 | 2 956 | 11 918 |
| Grillé | 8 | 5 685 | 9 256 |
| Bouilli | 54 | 6 627 | 8 268 |
| Mijoté / four | 33 | 6 669 | 8 247 |

Environ 60 % des mélanges sont immondes, surtout à cause de la viande périmée (un mélange sur trois en contient) et du
sucré mélangé à l'ail, aux champignons ou aux légumes. Les recettes « au choix » ont plusieurs variantes : 27 soupes
de légumes, 20 compotes, 55 salades de fruits, 4 tartes, 21 ragoûts douteux.

## 7. Questions ouvertes

1. Le **bouillon** (§3) : il s'ajoute en plus de l'eau, ou il coûte 1 L de plus à faire ?
2. Les **règles immondes** (§6) : à retirer, ajouter, nuancer ? (Vérifier sur la liste complète.)
3. Les **points d'eau** hors de la cuisine : salles avec puits, eaux croupies ? (l'utilisateur regarde les salles)

## 8. Choix faits par Claude en codant (à revoir si besoin)

- **Brandon** : le bois allumé à une torche brûle **3 minutes** ; il faut le poser en feu de camp avant
  (`brandon_duree` de `donnees/cuisine.json`). Le feu de camp se pose à l'endroit du héros.
- **Torche ou point d'eau à portée** : le héros à moins d'une hauteur de héros du point marqué (posé au sol).
- **Seau trouvé vide** : il se remplit à la cuisine (bouton « Remplir le seau », 10 L).
- **Valeur d'un plat cuisiné** (revente) : (PV + mana) / 8, au moins 1 or.
- **Noms** : « Mixture » et « Plat immonde » pour ce qui n'est pas une recette. Une mixture faite avec les ingrédients
  d'une recette connue mais la mauvaise préparation le dit (« Brochette se fait grillé »).
- **Les PV et le mana des plats cuisinés s'affichent** dans le sac (seules les valeurs des ingrédients sont cachées).
- **Marchand** : 1 à 3 amadous, et parfois un silex (1 fois sur 2), une marmite ou une page de recette (3 fois sur 10).
- **Horloge** des feux et des brandons : le temps d'exploration seulement ; celle des maux : exploration et combat.
- **Feu de camp dessiné** par le jeu (bûches et flammes animées), en attendant une vraie image.
- Pas de touche de manette pour la cuisine pour l'instant (clavier : **K**).

