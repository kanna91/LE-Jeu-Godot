# Refonte des altérations : proposition (2026-11-06)

> **Déjà fait le 2026-11-06 (demande de l'utilisateur)** : une vulnérabilité par élément (au feu, au froid, à la
> foudre, à l'arcane, au chaos, à l'ombre, +25 %), par groupe (physique, élémentaire, magique, +20 %) et
> « vulnérabilité totale » (l'ancienne Vulnérabilité) ; un bonus par caractéristique (bonus de force, de dextérité,
> d'endurance, d'intelligence, de sagesse, de mana) ; plus aucun « + magie / force du lanceur ». Inflammabilité,
> Morsure du givre, Conductivité, Vigueur, Agilité, Robustesse, Intellect, Sérénité, Puissance du titan,
> Illumination et Transcendance n'existent plus : les lignes qui en parlent ci-dessous sont dépassées. Le reste de
> la proposition attend toujours une décision.
>
> **Aussi fait le 2026-11-06** : 16 réductions de caractéristique (une, deux, trois ou toutes) à la place de Sape de
> force, Engourdissement, Épuisement vital, Torpeur, Trouble de l'esprit, Déchéance, Dissonance, Entropie ; Faiblesse,
> Maladresse et Débilité supprimées. Les lignes « Force / Dextérité / Intelligence diminuée » ci-dessous sont
> dépassées.
>
> **Et le 2026-11-06 encore** : toutes les altérations sont faites de **briques primaires** (créateur dans l'éditeur) ;
> Évasion, Précision, Concentration, Barrière et Protection renommées (Bonus d'esquive, Bonus de chance de toucher,
> Bonus de chance de coup critique, Résistance magique et élémentaire, Résistance physique) ; Bonus de parade ajouté.

Proposition à valider par l'utilisateur : **rien n'est encore appliqué**. Il y a aujourd'hui **68 altérations**
(`scripts/logique/alterations.gd`, `Alterations.defs`). L'inventaire ci-dessous indique, pour chacune, ce qui
l'inflige encore après l'épuration des compétences (compétences, 4 sorts, talents, geôlier).

Trois problèmes :

1. **29 altérations ne servent plus** : aucune compétence, aucun sort, aucun talent ni objet ne les inflige.
2. **Des noms prêtent à confusion** : nom interne anglais ou différent du nom affiché (`stun`, `précis`, `sape`...),
   doublons de sens (Faiblesse / Sape de force / Affaiblissement, Épuisement / Épuisement vital, Brûlure / Brûlure
   de mana, Usure / Usure magique / Vulnérabilité...).
3. **Des règles ne sont plus à jour** : formules qui comptent la « magie du lanceur » (la puissance magique ne vient
   plus de rien, elle vaut toujours 0), Trauma calculé avec l'ancienne force, et pertes de PA pensées pour plusieurs
   PA alors que le héros n'en a plus qu'**1** (perdre 1 PA = perdre son tour).

---

## 1. Supprimer les 29 altérations inutilisées

| Type | Altérations |
|---|---|
| Malus (13) | Pétrification, Épuisement, Engelure, Morsure du givre, Flétrissement, Faiblesse, Maladresse, Débilité, Épuisement vital, Trouble de l'esprit, Déchéance, Dissonance, Entropie |
| Améliorations (16) | Barrière, Hâte, Bouclier, Évasion, Épines, Bénédiction, Soif de sang, Clarté, Vigueur, Agilité, Robustesse, Intellect, Sérénité, Puissance du titan, Illumination, Transcendance |

Il en resterait **39**. Supprimer aussi le champ mort `afflictions` des objets (`Objet`, il cite même
« silencieux », qui n'existe pas).

## 2. Renommer : un nom clair, le même partout

Le nom interne devient le nom affiché (les anciennes parties, les réglages de l'éditeur, l'IA des ennemis et les
talents seront convertis).

| Aujourd'hui (interne → affiché) | Proposé | Pourquoi |
|---|---|---|
| `stun` → Étourdissement | **Étourdissement** | nom interne anglais |
| `aveugler` → Aveuglement | **Aveuglement** | verbe au lieu du nom |
| `précis` → Précision | **Visée** | même nom que la compétence Précision, qui donne aussi Concentration |
| `destruction armure` → Armure brisée | **Armure brisée** | deux noms pour la même chose |
| `destruction résistance` → Résistances brisées | **Résistances brisées** | idem |
| `usure` → Usure | **Usure physique** | ne se distingue pas d'Usure magique |
| `inflammabilité` → Inflammabilité | **Vulnérabilité au feu** | dit ce que ça fait |
| `conductivité` → Conductivité | **Vulnérabilité à la foudre** | idem |
| `marque` → Marque du chasseur | **Marque du chasseur** | deux noms |
| `trauma` → Trauma interne | **Contusion** | deux noms ; « trauma » est vague |
| `brûlure de mana` → Brûlure de mana | **Fuite de mana** | se confond avec Brûlure (feu) |
| `sape` → Sape de force | **Force diminuée** | se confondait avec Faiblesse et Affaiblissement |
| `engourdissement` → Engourdissement | **Dextérité diminuée** | idem avec Maladresse |
| `torpeur` → Torpeur | **Intelligence diminuée** | idem avec Débilité |
| `régénération` (compétence « Récupe ») | **Régénération** ; compétence renommée **Récupération** | « Récupe » est une abréviation |

Inchangés : Brûlure, Poison, Saignement, Électrocution, Corruption, Peste, Siphon de vie, Condamnation, Gel,
Sommeil, Paralysie, Lenteur, Terreur, Silence, Affaiblissement, Désarmement, Esprit embrumé, Décrépitude,
Vulnérabilité, Usure magique, Malédiction, Concentration, Rage, Protection.

## 3. Mettre les règles à jour

| Altération | Aujourd'hui | Proposé |
|---|---|---|
| Électrocution, Siphon de vie, Peste, Condamnation | « + magie du lanceur » (toujours 0) | retirer ce morceau des formules et des descriptions (**aucun changement de dégâts**) |
| Contusion (Trauma) | 1 + 2 % PV max + 5 + 3 × force du lanceur (ancienne règle de force) | **2d2 + 2 % des PV max** par tour, réduits par l'armure |
| Saignement | **25 % des PV actuels** par tour pendant 3 tours (≈ 58 % de la vie ; Perforation l'inflige à 60 %) | **10 %** des PV actuels par tour (≈ 27 %) |
| Gel | perd 1 PA par tour pendant 2 tours = **2 tours perdus à coup sûr** (plus fort qu'Étourdissement) | **50 %** de chance de perdre son tour, esquive -10 % |
| Lenteur | 50 % de perdre 1 PA = **50 % de perdre son tour** (Givre l'inflige) | esquive -10 % et toucher -10 %, **plus de perte de tour** |
| Électrocution | 25 % de perdre 1 PA (= 25 % de perdre son tour) | inchangé, mais écrit « 25 % de chance de perdre son tour » |
| Décrépitude | 25 % de perdre 1 PA | idem : « 25 % de chance de perdre son tour » |

Après la refonte, les altérations qui font perdre un tour seraient rangées de la plus forte à la plus faible :

- Étourdissement : 100 %, 1 tour ;
- Sommeil : 100 %, réveillé par un coup ;
- Gel : 50 % ;
- Terreur : 35 % ;
- Paralysie, Électrocution, Décrépitude : 25 %.

## Les 39 altérations gardées, par type (classement de l'éditeur)

- **Dégâts (10)** : Brûlure, Poison, Saignement, Électrocution, Corruption, Peste, Contusion, Siphon de vie, Fuite
  de mana, Condamnation.
- **Malus (24)** : Étourdissement, Gel, Sommeil, Paralysie, Lenteur, Terreur, Silence, Aveuglement, Affaiblissement,
  Désarmement, Esprit embrumé, Décrépitude, Vulnérabilité, Usure physique, Usure magique, Vulnérabilité au feu,
  Vulnérabilité à la foudre, Armure brisée, Résistances brisées, Marque du chasseur, Malédiction, Force diminuée,
  Dextérité diminuée, Intelligence diminuée.
- **Améliorations (5)** : Visée, Concentration, Rage, Protection, Régénération.

## À trancher

1. Supprimer les 29 altérations inutilisées ? (on pourra en recréer quand une compétence en aura besoin)
2. Les nouveaux noms : tous, ou lesquels changer ?
3. Les nouvelles valeurs : Saignement 10 %, Gel 50 %, Lenteur sans perte de tour, Contusion 2d2 + 2 % ?
