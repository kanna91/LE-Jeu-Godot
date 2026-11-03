# Objets : inventaire complet des règles

État du jeu au 2026-11-02, relevé dans le code pour être repris **point par point** avec l'utilisateur.
Chaque point est numéroté (O1, O2...) ; les cases « À revoir » notent ce qui pose question ou ce que l'utilisateur
a déjà demandé de changer. Les fichiers entre crochets disent où se trouve la règle.

---

## 1. Les familles d'objets

**O1 — Sortes d'objets** [`objet.gd`, `arme.gd`, `armure.gd`, `consommable.gd`, `objets_divers.gd`]

| Sorte | Exemples | S'équipe | S'utilise |
|---|---|---|---|
| Arme | Épée, Lance, Marteau | oui (emplacement arme) | non |
| Armure | Casque, Plastron, Jambières, Bottes, Ceinture, Gants | oui | non |
| Bijou | Anneau (2 emplacements), Amulette | oui | non |
| Consommable | Potions de soin, de mana, de régénération | non | oui |
| Divers | Clé de la cellule, Bol de soupe de quête ; vaisselle, argenterie, gemmes, objets cassés (`donnees/objets_divers.json`) | non | non |
| Nourriture (2026-11-03) | Bol de soupe et viande grillée 35 PV, viande bouillie 30, séchée 25, fruits 15 ; bouillon ; plats cuisinés | non | oui : se mange hors combat, rend PV (et mana) |
| Ingrédient (2026-11-03) | Légumes, viandes, œuf, lait, farine, miel, champignon, herbes, ail | non | non : se cuisine (`CUISINE.md`) |

Les clés rouillées et les clés de boss ne sont pas de vrais objets : un compteur, montré dans la catégorie « Divers »
de l'inventaire.

**O2 — Dix emplacements d'équipement** [`objets.gd`] : arme, anneau 1, anneau 2, amulette, gants, casque, plastron,
ceinture, jambières, bottes. Un objet reçu **s'équipe tout seul** si son emplacement est libre (un anneau va dans
l'emplacement libre, sinon il remplace le moins bon des deux, comparé par ses « points »). Pas de limite de place
dans le sac.

---

## 2. Les rangs (qualité)

**O3 — Six rangs** [`generation_objets.gd` QUALITES]

| Rang | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| Nom | médiocre | commun | précieux | rare | unique | légendaire |

Le nom de l'objet porte son type puis sa qualité : « Gants physiques médiocres », « Anneau magique rare ».

**O4 — Rang selon l'étage** [`objet.gd` definir_rang] : quand rien n'impose le rang, il est tiré entre deux
valeurs :

| Étage | 1 | 2 | 3 | 4 | 5 et plus |
|---|---|---|---|---|---|
| Rang | 1 ou 2 | 2 ou 3 | 3 ou 4 | 4 ou 5 | 5 ou 6 |

> À revoir : beaucoup de sources imposent **le rang = numéro de l'étage** au lieu de ce tirage (fouilles,
> râtelier, corps, pacifiques : voir O20). À l'étage 1, elles ne donnent donc jamais de « commun ». Incohérence à
> trancher.

> À revoir : le rang 5 s'appelle « unique », alors qu'un « effet unique » (O13) est une autre chose. Risque de
> confusion.

---

## 3. Ce que donne un objet (une seule option)

Depuis la refonte du 2026-10-30, **chaque arme, armure ou bijou généré donne une seule option**, dont la force
dépend du rang. [`generation_objets.gd`]

**O5 — Orientation** : chaque objet est **physique**, **magique** ou **élémentaire** (un tiers de chances chacun ;
le butin d'un élite suit sa classe : guerrier → physique, mage → magique, soutien → élémentaire). L'orientation
choisit les caractéristiques, dégâts et pénétrations possibles.

**O6 — Options possibles selon l'emplacement (famille)**

| Famille | Emplacements | Options possibles |
|---|---|---|
| Défensif | casque, plastron, jambières | caractéristique, défense |
| Hybride | bottes, ceinture, gants | caractéristique, défense, dégâts |
| Offensif | anneau, amulette | caractéristique, dégâts |
| Arme | épée, lance, marteau | dégâts (poids 2), caractéristique (2), pénétration (1) |

**O7 — Option « caractéristique »** : une caractéristique de l'orientation, au hasard.

| Orientation | Caractéristiques possibles |
|---|---|
| Physique | force, dextérité, endurance |
| Magique | intelligence, Mana, endurance |
| Élémentaire | sagesse, Mana, endurance |

| Rang | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| Points | +1 | +1 | +2 | +2 | +3 | +3 |

Rappel de ce que vaut un point : endurance +10 PV max ; force, intelligence, sagesse **+1d2 de dégâts** par coup ;
dextérité +2 % critique physique, +1 % toucher, +1 % esquive ; Mana +5 mana max (+2 mana par minute).

**O8 — Option « défense »** : 2 points par rang (rang 1 = 2 points, rang 6 = 12 points), répartis par paires
entre deux défenses au plus : armure (poids 2), résistance magique (1), résistance élémentaire (1).
Rappel : **2 points de défense bloquent 1 dégât** par coup (O17).

**O9 — Option « dégâts »** : des dégâts **plats** ajoutés à chaque coup du groupe de l'orientation (physiques,
magiques ou élémentaires).

| Rang | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| Dégâts | +2 | +2 | +4 | +4 | +6 | +6 |

> À revoir (demande de l'utilisateur, 2026-11-02) : trop fort et pas assez progressif (« une longue quête pour +4
> de dégâts »). Idée : des **dés** à la place, par exemple 1d2 → 1d3 → 1d4 → 2d2 → ..., à fixer ensemble.

**O10 — Option « pénétration »** (armes seulement) : points d'armure (arme physique) ou de résistance (magique,
élémentaire) que les coups ignorent.

| Rang | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| Pénétration | 2 | 2 | 4 | 4 | 6 | 6 |

---

## 4. Les armes

**O11 — Les dés viennent des attaques, plus des armes** [`formules.gd` DES_HEROS] : depuis la revue des dégâts du
2026-11-01, chaque attaque du héros a ses propres dés (Coup d'épée 6d2, Fracasser 8d2...). L'arme ne donne plus que :
- son **type de dégâts** : Épée → tranchant, Lance → perforant, Marteau → contondant ;
- les **deux attaques** du menu de combat : Épée → Coup d'épée et Frénésie ; Lance → Coup de lance et Balayage ;
  Marteau → Coup de marteau et Fracasser ; sans arme → Coup de poing et Enchaînement ;
- son option (O6) et, parfois, un **dé bonus** (O12).

> Les anciens dés par type (épée 2d6, lance 1d12, marteau 1d10 + 1d2) ne servent plus qu'aux ennemis et aux
> attaques sans dés propres ; ils ne sont plus affichés sur les armes depuis le 2026-11-02.

**O12 — Dé bonus des armes** (rare) : un dé en plus, lancé **seulement avec les deux attaques de l'arme**.

| Rang | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| Chance | 6 % | 7 % | 8 % | 9 % | 10 % | 12 % |
| Dé | 1d2 | 1d4 | 1d6 | 1d8 | 1d10 | 1d12 |

Type du dé : arme physique → son propre type ; magique → arcane, ombre ou chaos ; élémentaire → feu, froid ou
foudre. Un dé d'un autre type que l'arme s'ajoute comme dégâts de ce type.

> À revoir : avec les nouvelles attaques en d2 (6d2 ≈ 9), un dé bonus de 1d12 (6,5 en moyenne) devient énorme.
> À remettre à l'échelle avec O9.

**O13 — Arme de départ** : une arme physique de rang 1, **sans aucune option** (Épée, Lance ou Marteau au hasard).
Le sac contient aussi la **lance de test** (« god mode » de l'utilisateur : 100 partout), jamais confisquée.

> À revoir : la lance de test est-elle encore voulue dans l'inventaire de départ ?

---

## 5. Effets uniques

**O14 — Effets uniques** [`generation_objets.gd` UNIQUES] : parfois, en plus de son option, un objet reçoit un
effet spécial et un suffixe dans son nom (« Gants physiques communs du vampire »). Son prix en or est × 1,5.

| Rang | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| Chance | 4 % | 6 % | 8 % | 10 % | 12 % | 15 % |

Valeur = valeur au rang 1 + gain par rang × (rang − 1). Ce sont les mêmes effets que ceux des talents.

Effets offensifs (armes, bijoux, bottes, ceinture, gants) :

| Effet | Suffixe | Rang 1 | + par rang | Orientation |
|---|---|---|---|---|
| Chance de saignement | de l'hémorragie | 3 % | 1 % | physique |
| Chance d'aveuglement | de l'aveuglement | 2 % | 1 % | toutes |
| Chance de poison | du venin | 3 % | 1 % | toutes |
| Chance de brûlure | des braises | 3 % | 1 % | magique / élém. |
| Chance d'étourdir | du tonnerre | 2 % | 0,5 % | physique |
| Chance de terreur | de l'effroi | 2 % | 1 % | magique / élém. |
| Chance de vulnérabilité | de la brèche | 3 % | 1 % | toutes |
| Chance de malédiction | du maléfice | 3 % | 1 % | magique / élém. |
| Part des dégâts physiques ajoutée en feu | du brasier | 4 % | 2 % | physique |
| ... en foudre | de l'orage | 4 % | 2 % | physique |
| ... en brut | du bourreau | 3 % | 1 % | physique |
| Part des dégâts magiques ajoutée en froid | du givre | 4 % | 2 % | magique / élém. |
| ... en ombre | des ténèbres | 4 % | 2 % | magique / élém. |
| ... en foudre | de la tempête | 4 % | 2 % | magique / élém. |
| Vol de vie physique | du vampire | 2 % | 1 % | physique |
| Frappe supplémentaire | de la frénésie | 2 % | 1 % | toutes |
| Mana rendu sur critique magique | de la source | 5 % | 2 % | magique / élém. |
| Réduction du coût en mana | de l'économe | 3 % | 1 % | magique / élém. |

Effets défensifs (casque, plastron, jambières, bottes, ceinture, gants) :

| Effet | Suffixe | Rang 1 | + par rang |
|---|---|---|---|
| Résistance aux altérations | de la pureté | 3 % | 1 % |
| Épines (renvoi des dégâts) | des épines | 4 % | 2 % |
| Réduction des dégâts | du rempart | 1 % | 0,5 % |
| Régénération par tour | du troll | 0,4 % | 0,2 % |
| Soins reçus | de la grâce | 4 % | 1,5 % |
| Efficacité des potions | de l'alchimiste | 5 % | 2 % |

> À revoir : liste héritée de l'ancien jeu, jamais revue depuis la refonte. « Chance d'étourdir » existe encore
> alors que l'étourdissement a été retiré de plusieurs compétences.

---

## 6. Objets spéciaux

**O15 — Armure anti-boss** (une par étage, dans le **coffre ancien**) : une pièce d'armure à option « défense », plus
**6 points et 20 %** de résistance au type de dégâts principal du boss de l'étage (« Plastron physique commun
anti-feu »). Prix × 1,5. Valeurs provisoires de l'utilisateur (2026-10-30).

**O16 — Objets de quête** (2026-11-02, `donnees/prisonniers.json`) : Bol de soupe (nourriture), Clé de la cellule
(objet de quête), **Amulette de Mariane** (intelligence +2, Mana +1, sagesse −1, équipable). Récompense de Mariane :
un anneau **rare** à l'étage 1 (meilleur rang de l'étage + 2).

---

## 7. Défenses et résistances (comment les objets protègent)

**O17 — Calcul des dégâts subis** [`degats.gd`]
1. **Pourcentages d'abord** : vulnérabilités (+) et résistances en % (−) s'additionnent ; résistance plafonnée à
   **75 %**.
2. **Blocage en points ensuite** : **2 points bloquent 1 dégât**. Défense du groupe (armure contre le physique,
   résistance magique contre arcane/ombre/chaos, résistance élémentaire contre feu/froid/foudre) **ou** résistance
   spécifique du type : la **meilleure des deux** compte, elles ne s'additionnent pas.
3. La **pénétration** de l'attaquant retire des points de défense avant le calcul.
4. Ni bloqués ni modifiés : lumière (soins), brut, saignement, poison.

---

## 8. Consommables

**O18 — Potions** [`consommable.gd`]

| Potion | Niveau 1 | Niveau 2 | Niveau 3 |
|---|---|---|---|
| Soin | **40 PV** (fixe), 60 or | 45 % des PV max, 150 or | 65 %, 400 or |
| Mana | **40 mana** (fixe), 60 or | 45 % du mana max, 150 or | 65 %, 400 or |
| Régénération (mixte) | 25 % PV et mana, 700 or | 35 %, 1 400 or | 45 %, 3 800 or |

Niveau trouvé selon l'étage : 1 (étages 1 à 3), 2 (4 à 6), 3 ensuite. En combat, boire coûte **1 PA** ; hors
combat, c'est gratuit. Le talent « efficacité des potions » et l'effet unique « de l'alchimiste » augmentent ce
qu'elles rendent.

> À revoir : niveau 1 en points fixes, niveaux 2 et 3 en pourcentage. Le saut 40 PV → 45 % dépend beaucoup des PV
> du héros.

**O19 — Potions des ennemis** : un ennemi a 30 % de chances d'avoir une potion de soin (le boss toujours), qu'il peut
boire en combat. Il ne la laisse pas en mourant.

---

## 9. Où trouver des objets

**O20 — Sources d'objets**

| Source | Ce qu'on y trouve | Rang |
|---|---|---|
| Squelette fouillé (objet du décor) | 50 % rien, 35 % or (10 à 30 × étage), **15 % un équipement** | = étage |
| Corps d'un ennemi vaincu (fouille) | comme un squelette | = étage |
| Corps d'un gobelin pacifique tué | 2 à 6 or × étage, 10 % potion de soin, 2 % équipement | = étage |
| Gobelins pacifiques épargnés | 5 à 15 or × étage, 20 % potion, 5 % équipement | = étage |
| **Élite** vaincu | **un équipement garanti** (emplacement au hasard, orienté selon sa classe) | tirage O4 |
| Râtelier d'armes (un par étage) | une arme | = étage |
| Cachette secrète (« objet ») | un équipement | étage + 1 |
| Coffre des salles bonus (2 à 3 par étage) | or (200 à 500 × étage), un équipement, 60 % potion de soin | étage + 1 (+1 si salle verrouillée) |
| Coffre ancien (un par étage) | l'armure anti-boss | = étage |
| Marchand | 2 à 4 armes, 2 à 4 armures, 1 à 3 bijoux, potion de soin et de mana niv. 1, 1 à 3 potions au hasard (niv. 1 à 3) | tirage O4 |
| Quêtes des prisonniers | objets de quête, anneau rare (Mariane) | voir O16 |
| Grimoire (pupitre), cachette « livre » | un sort, pas un objet | — |

Les ennemis ordinaires ne donnent **ni or ni butin** (décision du 2026-10-26) : seulement ce qu'on trouve en
fouillant leur corps.

> À revoir : les rangs « = étage » ne suivent pas le tirage O4 (voir O4).

---

## 10. Argent

**O21 — Valeur d'un objet** [`generation_objets.gd`] : chaque rang a un budget de « points » (milieu de la
fourchette × facteur de l'emplacement) ; valeur en or = points² / 3, arrondie à 5, au moins 15.

| Rang | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| Points (fourchette) | 24–36 | 40–56 | 60–80 | 84–112 | 116–152 | 160–208 |

Facteurs : arme 1,5 ; plastron 1,3 ; casque, jambières, amulette 1,0 ; bottes, ceinture, gants 0,8 ; anneau 0,7.
Effet unique × 1,5 ; anti-boss × 1,5.

**O22 — Marchand** [`marchand.gd`]
- **Il vend** à la valeur + 35 %, moins les talents de marchandage, ± 5 % par point de karma (jamais moins de 25 %).
- **Il achète** à la valeur, toujours (le karma ne change pas ce qu'il paie).
- **Racheter** un objet vendu : sa valeur, ± 5 % par point de karma.
- **Vente en lot** : tous les équipements jusqu'à un rang choisi (5 au plus), jamais les potions.

**O23 — Or gagné** : +5 % par point de karma positif (fouilles, cachettes, coffres ; pas les ventes).

---

## 11. Perdre ses objets

**O24 — Capture par un geôlier** [`aventure.gd` capturer] : tout l'équipement est retiré puis tout le sac et l'or
sont confisqués. Chaque objet : **50 %** dans le coffre des confiscations (au cachot), **25 %** perdu, **25 %** porté
par un **porteur** (gobelin qui rôde, à battre pour le récupérer). L'arme portée va toujours dans le coffre. La lance
de test n'est jamais confisquée.

---

## 12. À trancher ensemble (résumé)

1. **O9** : dégâts plats des objets (+2/+4/+6) → des dés progressifs (1d2, 1d3, 1d4, 2d2...) : quelle échelle ?
2. **O12** : dé bonus des armes (1d2 à 1d12) : même échelle que O9 ?
3. **O7 / O8 / O10** : caractéristiques (+1 à +3), défense (2 points par rang), pénétration (2 à 6) : à garder ?
4. **O4 / O20** : rang des objets trouvés : tirage selon l'étage partout, ou « = étage » ?
5. **O3** : nom du rang 5 « unique » (confusion avec les effets uniques) ?
6. **O14** : liste des effets uniques à revoir (étourdissement...).
7. **O18** : potions de niveau 1 en points fixes, niveaux 2 et 3 en pourcentage.
8. **O13** : lance de test dans l'inventaire de départ.
9. **O1** : catalogue rempli le 2026-11-03 (liste de l'utilisateur) ; prix, PV de la nourriture et classement nourriture / ingrédient proposés par Claude, à valider.
