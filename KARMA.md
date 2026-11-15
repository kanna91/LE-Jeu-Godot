# Karma — règles et idées

Note demandée par l'utilisateur le 2026-11-15 : tout ce qui a été décidé sur le karma, et les idées pour le butin.
Code : `scripts/logique/karma.gd` (tables `ACTES`, `EFFETS`, `PALIER`, `PALIERS`, réglables sans toucher au reste).

**Principe (utilisateur, 2026-11-15)** : le karma se gagne et se perd **rarement et lentement** ; un score de ±20 n'est
pas prévu. L'unité de base : **+1 karma = +5 %, −1 karma = −5 %**.

## Ce qui fait bouger le karma (2026-10-31)

| Clémence (+1) | Cruauté (−1) |
|---|---|
| Épargner des gobelins pacifiques | Tuer des pacifiques |
| Soigner le gobelin blessé | Achever le gobelin blessé |
| L'épargner | Tuer un prisonnier dans sa cellule |
| Libérer un prisonnier | |
| Quête du vieux magicien : soupe apportée (+1) | Quête du vieux magicien : malédiction (−2) |

Les actes sont aussi comptés dans la moralité de la partie (clémence, cruauté).

## Effets par point

| Effet | Karma négatif | Karma positif |
|---|---|---|
| Diablotins | +5 % de mensonges | +5 % de vérité |
| Prix du marchand (ce qu'il vend) | +5 % | −5 % (plancher 25 % : choix de Claude, à valider) |
| Ce que le marchand rachète | même prix | même prix (décision de l'utilisateur) |
| Chevalier de la mort | +5 % de vitesse (salle et entre les salles ; −10 : +50 %) | rien |
| Butin : or et objets qu'on compte | −5 % | +5 % |
| Butin : armes et équipements | 5 % de chance d'un rang de moins | 5 % de chance d'un rang de plus |
| Butin : bornes du multiplicateur | × 0,25 au plus bas | × 1,75 au plus haut |

Historique : avant le 2026-11-03, un Chevalier de la mort de plus tous les 5 points négatifs (remplacé par la vitesse).
Avant le 2026-11-15, seulement +5 % d'or par point positif.

## Le butin (décidé le 2026-11-15 : A + B + C + D)

Les valeurs réglées (éditeur des ennemis, éditeur des salles, code) sont celles du **karma 0**.

- **A. Bornes** : le multiplicateur suit ±5 % par point mais reste entre **× 0,25 et × 1,75** (`Karma.BUTIN_MIN`,
  `BUTIN_MAX` ; × 0,5 à × 1,5 d'abord, élargi par l'utilisateur le 2026-11-15). Karma −5 : 100 pièces → 75 ;
  karma +5 : → 125.
- **B. Qualité plutôt que nombre pour les objets uniques** : l'or et les objets qu'on compte (viande, potions,
  nourriture, ingrédients…) suivent le multiplicateur (nombre d'objets : la partie décimale est tirée au hasard,
  1 objet × 0,75 = 75 % de chance de l'avoir). Les **armes et équipements** gardent leur nombre, mais chaque point de
  karma donne **5 % de chance d'un rang de plus** (positif) **ou de moins** (négatif), entre 1 et 6
  (`Karma.rang_butin`). Karma +5 : une épée de rang 2 a 25 % de chance d'être de rang 3.
- **C. Paliers de 5 points** (`Karma.PALIER`) :
  - **positif** : à chaque palier, **+10 % de chance d'un objet en plus** dans les **coffres** et sur les **élites**
    (`Karma.chance_objet_en_plus`) ;
  - **négatif** : **pas d'objet maudit pour le moment** (décision de l'utilisateur, 2026-11-15) : le mauvais karma
    baisse seulement la qualité des objets (B). Un premier essai (une affliction infligée au début de chaque combat :
    usure, étourdissement, brûlure, poison…) a été retiré : « bien trop pénible ».
- **D. Jamais touchés par le karma** : clés, objets de quête, recettes, et l'or confisqué qu'on récupère (ce sont
  les affaires du héros), ventes au marchand.

## Pas encore fait (en attente d'un système de quêtes)

- Paliers négatifs : des **quêtes spéciales**.
- Paliers positifs : **plus de quêtes**, aux **meilleures récompenses**.
- Habitants plus froids ou plus chaleureux selon le karma : seul l'accueil des diablotins le fait aujourd'hui.

## Objets maudits : à concevoir plus tard (consignes de l'utilisateur, 2026-11-15)

- Ils doivent être **identifiés chez la bibliothécaire ou l'alchimiste** (on ne sait pas qu'ils sont maudits avant).
- Leur **malus est passif et permanent**, mais ne doit **pas rendre l'objet complètement inutilisable**.
- Ils peuvent avoir un **effet bonus qui compense un peu le malus**.
- Pas d'afflictions de combat pénibles (étourdissement, poison… au début de chaque combat : trop brutal).
- À voir avec l'utilisateur avant de coder : la nature des malus et des bonus, leurs valeurs.

## Idées à garder

- Objets maudits : les « purifier » (autel, prêtre) contre de l'or ou du karma.
- Récompenses de palier positif autres que le butin : un pnj qui n'apparaît qu'à +5, une porte qui ne s'ouvre qu'aux
  âmes clémentes.
- Le karma très négatif pourrait attirer d'autres chasseurs que le Chevalier de la mort.
