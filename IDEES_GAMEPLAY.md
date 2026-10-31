# Idées pour varier la boucle de jeu

> 2026-10-26 : l'utilisateur a fixé la direction (jeu d'exploration et d'aventure) : voir
> `FEUILLE_DE_ROUTE_AVENTURE.md` et la section « Donjon d'aventure » du README.

Recommandations faites le 2026-10-20 (rien n'est codé). Constat : aujourd'hui une salle = un combat,
parfois un coffre, une source de soin, un bonus, un marchand ou un piège subi sans rien faire. Le grand
atout du jeu, ce sont les **salles peintes où l'on marche** : elles permettent autre chose que du combat.

Les règles et les chiffres restent à décider par l'utilisateur : pour chaque idée retenue, proposer des
règles chiffrées et attendre sa validation avant de coder.

## Par ordre de priorité

1. **Objets à fouiller dans les salles** — points à examiner sur l'image (squelette, étagère, fissure,
   tas de gravats). Résultat : or, potion, indice, ou parfois un piège ou un ennemi caché. Raison de
   marcher dans la salle ; réutilise le moteur des salles peintes (zones comme les sorties).
2. **Choix avant le combat** — en entrant, on voit les gobelins et on choisit : attaquer, passer
   discrètement (jet de dextérité), parlementer ou payer (charisme, or), ou reculer. Le combat devient
   une décision.
3. **Événements à choix** — autel qui demande du sang (PV contre un bonus), prisonnier à libérer
   (allié ou traître), fontaine maudite, gobelin blessé qui supplie. Textes à 2 ou 3 choix avec
   conséquences : peu coûteux à faire, beaucoup de variété. S'appuie sur les événements de salle
   existants (`Donjon.action_salle`, `evenement` du plan).
4. **Portes et clés** — certaines portes (maintenant animées) verrouillées : clé sur un mini-boss,
   crochetage, ou forcer la porte (bruit → combat). Petits objectifs dans chaque étage.
5. **Pièges à éviter** — au lieu d'un piège subi en entrant : dalles suspectes ou fils visibles au sol,
   à contourner en marchant. Utilise directement le déplacement.
6. **Un objectif par étage en plus du boss** — 3 fragments à trouver, quelqu'un à sauver, ou sortir
   avant que l'alarme ne monte. Plus on explore, plus on gagne, mais les ennemis se renforcent
   (risque contre récompense).
7. **Ennemis variés** — il n'y a que des gobelins. Ajouter les morts-vivants (déjà prévus dans le code)
   avec d'autres faiblesses (lumière, contondant) : les types de dégâts aux dés prennent leur sens.
8. **Progression entre deux parties** — à la mort, garder une partie de quelque chose (âmes,
   réputation) qui débloque classes, sorts de départ ou un camp de base. À penser avec le futur
   sphérier, qui doit être reforgé de toute façon.

## Conseil de départ

Commencer par **1, 2 et 3** : ensemble, ils changent le plus la sensation de jeu, et ils s'appuient sur
ce qui existe déjà (salles où l'on marche, caractéristiques, événements du donjon).

## Suivi

| Idée | État | Décisions de l'utilisateur |
|---|---|---|
| 1. Objets à fouiller | **codée** le 2026-10-20 ; coffres et étagères retirés le même jour (juraient avec le décor) : squelettes seuls, 0 à 2 par salle, touche E | squelette 50 rien / 35 or / 15 objet ; une fois par objet. Pour d'autres objets : il faut des assets qui se fondent mieux dans le décor peint |
| 2. Choix avant le combat | **remplacée** le 2026-10-26 par les ennemis visibles qui rôdent (contourner, se cacher, fuir, foncer) | ennemis visibles à la Fear & Hunger, fuite de combat avec chance d'échec |
| 3. Événements à choix | **codée** le 2026-10-26 (`Rencontres` : gobelin blessé, prisonnier, autel, diablotins) | choix moraux, diablotins vrais une fois sur deux (liste de l'utilisateur) ; textes et valeurs de Claude, à valider |
| 4. Portes et clés | **codée** le 2026-10-26 (salles bonus verrouillées, clés dans les cachettes) | clés pour des salles bonus meilleures (liste de l'utilisateur) |
| 5. Pièges à éviter | proposée | — |
| 6. Objectif par étage | proposée | — |
| 7. Ennemis variés | proposée | — |
| 8. Progression entre parties | proposée | les ennemis ne donnent plus rien, plus de niveaux (2026-10-26) : à repenser avec le sphérier |
