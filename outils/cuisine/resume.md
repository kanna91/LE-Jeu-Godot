# Cuisine : toutes les combinaisons (résumé)

Produit par `outils/cuisine_combinaisons.py` depuis `donnees/cuisine.json`. Liste complète :
`outils/cuisine/combinaisons.csv` (une ligne par mélange, 4 préparations en colonnes).

**14949 mélanges** de 1 à 4 ingrédients parmi 22 (répétitions permises), × 4 préparations = 59796 plats.

| Préparation | Recettes | Mixtures | Immondes |
|---|---|---|---|
| Sans feu | 55 | 2956 | 11918 |
| Grillé | 8 | 5685 | 9256 |
| Bouilli | 54 | 6627 | 8268 |
| Mijoté / four (cuisine) | 33 | 6669 | 8247 |

## Recettes (toutes les variantes)

- **Viande grillée** : 1 variante(s), 35 PV, 0 mana
- **Pomme de terre grillée** : 1 variante(s), 14 PV, 0 mana
- **Lait chaud** : 1 variante(s), 12 PV, 3 mana
- **Viande bouillie** : 2 variante(s), 40 à 45 PV, 4 à 9 mana
- **Tomates farcies** : 1 variante(s), 41 PV, 6 mana
- **Purée** : 1 variante(s), 30 PV, 0 mana
- **Soupe de légumes** : 27 variante(s), 6 à 27 PV, 3 à 18 mana
- **Compote** : 20 variante(s), 22 à 45 PV, 0 à 22 mana
- **Omelette** : 1 variante(s), 34 PV, 0 mana
- **Pain** : 1 variante(s), 25 PV, 4 mana
- **Ragoût** : 1 variante(s), 76 PV, 6 mana
- **Brochette** : 1 variante(s), 46 PV, 15 mana
- **Viande marinée au citron** : 1 variante(s), 48 PV, 24 mana
- **Ragoût douteux** : 21 variante(s), 63 à 86 PV, 0 à 15 mana
- **Soupe au chou** : 1 variante(s), 38 PV, 15 mana
- **Gratin** : 1 variante(s), 57 PV, 4 mana
- **Soupe à l'oignon** : 1 variante(s), 10 PV, 29 mana
- **Champignons à l'ail** : 1 variante(s), 12 PV, 32 mana
- **Salade de fruits** : 55 variante(s), 24 à 54 PV, 0 à 30 mana
- **Tarte aux fruits** : 4 variante(s), 53 à 63 PV, 0 à 10 mana
- **Omelette aux champignons** : 1 variante(s), 40 PV, 12 mana
- **Galette au miel** : 1 variante(s), 49 PV, 11 mana
- **Bouillie au miel** : 1 variante(s), 35 PV, 13 mana
- **Soupe aux champignons** : 1 variante(s), 10 PV, 35 mana
- **Pot-au-feu** : 1 variante(s), 80 PV, 18 mana
- **Civet aux champignons** : 1 variante(s), 60 PV, 40 mana
- **Légumes mijotés aux herbes** : 1 variante(s), 16 PV, 42 mana

## Pourquoi c'est immonde (nombre de plats)

- viande avariée : immangeable (et intoxication 1 fois sur 2) : 9179
- sucré (fruit, miel) avec de l'ail ou des champignons : 7960
- dessert et potage mélangés (sucré avec 2 légumes ou plus) : 5880
- farine sans œuf ni lait : de la colle ou de la farine brûlée : 4727
- oignon dans un plat sucré (sans viande pour le justifier) : 3040
- sans feu : viande, œuf, pomme de terre ou farine crus : 2211
- le lait caille avec le citron ou l'orange : 1936
- viande crue mangée sans cuisson (intoxication 1 fois sur 4) : 1443
- grillé : on ne grille pas du lait (sans œuf pour le lier) : 988
- 3 fois ou plus le même ingrédient fort (ail, citron, herbes) : 192
- seulement de l'ail, des herbes ou du citron : immangeable : 133

## Exemples

- Bouilli, immonde — 3 fois ou plus le même ingrédient fort (ail, citron, herbes) : Viande crue + Ail + Ail + Ail → 8 PV, 4 mana ; Viande crue + Citron + Citron + Citron → 10 PV, 8 mana ; Viande crue + Herbes + Herbes + Herbes → 6 PV, 4 mana
- Bouilli, immonde — dessert et potage mélangés (sucré avec 2 légumes ou plus) : Pomme de terre + Pomme de terre + Pomme → 9 PV, 0 mana ; Pomme de terre + Pomme de terre + Poire → 9 PV, 0 mana ; Pomme de terre + Pomme de terre + Prune → 8 PV, 1 mana
- Bouilli, immonde — farine sans œuf ni lait : de la colle ou de la farine brûlée : Farine → 2 PV, 0 mana ; Viande crue + Farine → 8 PV, 0 mana ; Pomme de terre + Farine → 4 PV, 0 mana
- Bouilli, immonde — le lait caille avec le citron ou l'orange : Orange + Lait → 5 PV, 1 mana ; Citron + Lait → 3 PV, 3 mana ; Viande crue + Orange + Lait → 11 PV, 1 mana
- Bouilli, immonde — oignon dans un plat sucré (sans viande pour le justifier) : Oignon + Pomme → 4 PV, 2 mana ; Oignon + Poire → 4 PV, 2 mana ; Oignon + Prune → 4 PV, 2 mana
- Bouilli, immonde — seulement de l'ail, des herbes ou du citron : immangeable : Ail → 0 PV, 1 mana ; Citron → 1 PV, 2 mana ; Herbes → 0 PV, 2 mana
- Bouilli, immonde — sucré (fruit, miel) avec de l'ail ou des champignons : Ail + Pomme → 4 PV, 1 mana ; Ail + Poire → 4 PV, 1 mana ; Ail + Prune → 4 PV, 2 mana
- Bouilli, immonde — viande avariée : immangeable (et intoxication 1 fois sur 2) : Viande périmée → 6 PV, 0 mana ; Viande crue + Viande périmée → 12 PV, 0 mana ; Viande périmée + Viande périmée → 12 PV, 0 mana
- Bouilli, mixture : Chou → 4 PV, 1 mana ; Navet → 3 PV, 1 mana ; Carotte → 2 PV, 2 mana
- Bouilli, mixture — presque : Brochette (grillé) : Viande crue + Tomate + Oignon → 16 PV, 5 mana
- Bouilli, mixture — presque : Champignons à l'ail (grillé) : Ail + Champignon + Champignon → 4 PV, 10 mana
- Bouilli, mixture — presque : Civet aux champignons (mijoté / four (cuisine)) : Viande crue + Oignon + Champignon + Herbes → 15 PV, 10 mana
- Bouilli, mixture — presque : Galette au miel (mijoté / four (cuisine)) : Œuf + Farine + Miel → 13 PV, 3 mana
- Bouilli, mixture — presque : Gratin (mijoté / four (cuisine)) : Pomme de terre + Œuf + Lait → 15 PV, 1 mana
- Bouilli, mixture — presque : Légumes mijotés aux herbes (mijoté / four (cuisine)) : Tomate + Oignon + Ail + Herbes → 4 PV, 10 mana
- Bouilli, mixture — presque : Omelette (grillé) : Œuf + Œuf → 12 PV, 0 mana
- Bouilli, mixture — presque : Omelette aux champignons (grillé) : Œuf + Œuf + Champignon → 14 PV, 4 mana
- Bouilli, mixture — presque : Pain (mijoté / four (cuisine)) : Lait + Farine → 7 PV, 1 mana
- Bouilli, mixture — presque : Pomme de terre grillée (grillé) : Pomme de terre → 5 PV, 0 mana
- Bouilli, mixture — presque : Pot-au-feu (mijoté / four (cuisine)) : Viande crue + Navet + Carotte + Poireau → 20 PV, 4 mana
- Bouilli, mixture — presque : Ragoût (mijoté / four (cuisine)) : Viande crue + Pomme de terre + Carotte → 20 PV, 2 mana
- Bouilli, mixture — presque : Salade de fruits (sans feu) : Pomme + Pomme + Pomme → 22 PV, 0 mana ; Pomme + Pomme + Poire → 22 PV, 0 mana ; Pomme + Pomme + Prune → 21 PV, 2 mana
- Bouilli, mixture — presque : Soupe au chou (mijoté / four (cuisine)) : Pomme de terre + Chou + Oignon → 10 PV, 4 mana
- Bouilli, mixture — presque : Tarte aux fruits (mijoté / four (cuisine)) : Pomme + Œuf + Farine → 16 PV, 0 mana ; Poire + Œuf + Farine → 16 PV, 0 mana ; Prune + Œuf + Farine → 15 PV, 2 mana
- Bouilli, mixture — presque : Tomates farcies (grillé) : Viande crue + Tomate → 14 PV, 2 mana
- Bouilli, mixture — presque : Viande grillée (grillé) : Viande crue → 12 PV, 0 mana
- Bouilli, mixture — presque : Viande marinée au citron (grillé) : Viande crue + Oignon + Citron → 16 PV, 8 mana
- Grillé, immonde — 3 fois ou plus le même ingrédient fort (ail, citron, herbes) : Viande crue + Ail + Ail + Ail → 8 PV, 4 mana ; Viande crue + Citron + Citron + Citron → 10 PV, 8 mana ; Viande crue + Herbes + Herbes + Herbes → 6 PV, 4 mana
- Grillé, immonde — dessert et potage mélangés (sucré avec 2 légumes ou plus) : Pomme de terre + Pomme de terre + Pomme → 9 PV, 0 mana ; Pomme de terre + Pomme de terre + Poire → 9 PV, 0 mana ; Pomme de terre + Pomme de terre + Prune → 8 PV, 1 mana
- Grillé, immonde — farine sans œuf ni lait : de la colle ou de la farine brûlée : Farine → 2 PV, 0 mana ; Viande crue + Farine → 8 PV, 0 mana ; Pomme de terre + Farine → 4 PV, 0 mana
- Grillé, immonde — grillé : on ne grille pas du lait (sans œuf pour le lier) : Lait → 2 PV, 0 mana ; Viande crue + Lait → 8 PV, 0 mana ; Pomme de terre + Lait → 4 PV, 0 mana
- Grillé, immonde — le lait caille avec le citron ou l'orange : Orange + Lait → 5 PV, 1 mana ; Citron + Lait → 3 PV, 3 mana ; Viande crue + Orange + Lait → 11 PV, 1 mana
- Grillé, immonde — oignon dans un plat sucré (sans viande pour le justifier) : Oignon + Pomme → 4 PV, 2 mana ; Oignon + Poire → 4 PV, 2 mana ; Oignon + Prune → 4 PV, 2 mana
- Grillé, immonde — seulement de l'ail, des herbes ou du citron : immangeable : Ail → 0 PV, 1 mana ; Citron → 1 PV, 2 mana ; Herbes → 0 PV, 2 mana
- Grillé, immonde — sucré (fruit, miel) avec de l'ail ou des champignons : Ail + Pomme → 4 PV, 1 mana ; Ail + Poire → 4 PV, 1 mana ; Ail + Prune → 4 PV, 2 mana
- Grillé, immonde — viande avariée : immangeable (et intoxication 1 fois sur 2) : Viande périmée → 6 PV, 0 mana ; Viande crue + Viande périmée → 12 PV, 0 mana ; Viande périmée + Viande périmée → 12 PV, 0 mana
- Grillé, mixture : Chou → 4 PV, 1 mana ; Navet → 3 PV, 1 mana ; Carotte → 2 PV, 2 mana
- Grillé, mixture — presque : Civet aux champignons (mijoté / four (cuisine)) : Viande crue + Oignon + Champignon + Herbes → 15 PV, 10 mana
- Grillé, mixture — presque : Compote (bouilli) : Pomme + Pomme → 15 PV, 0 mana ; Pomme + Poire → 15 PV, 0 mana ; Pomme + Prune → 14 PV, 2 mana
- Grillé, mixture — presque : Galette au miel (mijoté / four (cuisine)) : Œuf + Farine + Miel → 13 PV, 3 mana
- Grillé, mixture — presque : Gratin (mijoté / four (cuisine)) : Pomme de terre + Œuf + Lait → 15 PV, 1 mana
- Grillé, mixture — presque : Légumes mijotés aux herbes (mijoté / four (cuisine)) : Tomate + Oignon + Ail + Herbes → 4 PV, 10 mana
- Grillé, mixture — presque : Pot-au-feu (mijoté / four (cuisine)) : Viande crue + Navet + Carotte + Poireau → 20 PV, 4 mana
- Grillé, mixture — presque : Purée (bouilli) : Pomme de terre + Pomme de terre → 10 PV, 0 mana
- Grillé, mixture — presque : Ragoût (mijoté / four (cuisine)) : Viande crue + Pomme de terre + Carotte → 20 PV, 2 mana
- Grillé, mixture — presque : Salade de fruits (sans feu) : Pomme + Pomme + Pomme → 22 PV, 0 mana ; Pomme + Pomme + Poire → 22 PV, 0 mana ; Pomme + Pomme + Prune → 21 PV, 2 mana
- Grillé, mixture — presque : Soupe au chou (mijoté / four (cuisine)) : Pomme de terre + Chou + Oignon → 10 PV, 4 mana
- Grillé, mixture — presque : Soupe aux champignons (bouilli) : Champignon + Champignon + Herbes → 3 PV, 11 mana
- Grillé, mixture — presque : Soupe de légumes (bouilli) : Pomme de terre + Chou → 9 PV, 1 mana ; Pomme de terre + Navet → 8 PV, 1 mana ; Pomme de terre + Carotte → 8 PV, 2 mana
- Grillé, mixture — presque : Soupe à l'oignon (bouilli) : Oignon + Oignon + Oignon → 3 PV, 9 mana
- Grillé, mixture — presque : Tarte aux fruits (mijoté / four (cuisine)) : Pomme + Œuf + Farine → 16 PV, 0 mana ; Poire + Œuf + Farine → 16 PV, 0 mana ; Prune + Œuf + Farine → 15 PV, 2 mana
- Grillé, mixture — presque : Viande bouillie (bouilli) : Viande crue + Carotte → 15 PV, 2 mana ; Viande crue + Oignon → 14 PV, 3 mana
- Mijoté / four (cuisine), immonde — 3 fois ou plus le même ingrédient fort (ail, citron, herbes) : Viande crue + Ail + Ail + Ail → 8 PV, 4 mana ; Viande crue + Citron + Citron + Citron → 10 PV, 8 mana ; Viande crue + Herbes + Herbes + Herbes → 6 PV, 4 mana
- Mijoté / four (cuisine), immonde — dessert et potage mélangés (sucré avec 2 légumes ou plus) : Pomme de terre + Pomme de terre + Pomme → 9 PV, 0 mana ; Pomme de terre + Pomme de terre + Poire → 9 PV, 0 mana ; Pomme de terre + Pomme de terre + Prune → 8 PV, 1 mana
- Mijoté / four (cuisine), immonde — farine sans œuf ni lait : de la colle ou de la farine brûlée : Farine → 2 PV, 0 mana ; Viande crue + Farine → 8 PV, 0 mana ; Pomme de terre + Farine → 4 PV, 0 mana
- Mijoté / four (cuisine), immonde — le lait caille avec le citron ou l'orange : Orange + Lait → 5 PV, 1 mana ; Citron + Lait → 3 PV, 3 mana ; Viande crue + Orange + Lait → 11 PV, 1 mana
- Mijoté / four (cuisine), immonde — oignon dans un plat sucré (sans viande pour le justifier) : Oignon + Pomme → 4 PV, 2 mana ; Oignon + Poire → 4 PV, 2 mana ; Oignon + Prune → 4 PV, 2 mana
- Mijoté / four (cuisine), immonde — seulement de l'ail, des herbes ou du citron : immangeable : Ail → 0 PV, 1 mana ; Citron → 1 PV, 2 mana ; Herbes → 0 PV, 2 mana
- Mijoté / four (cuisine), immonde — sucré (fruit, miel) avec de l'ail ou des champignons : Ail + Pomme → 4 PV, 1 mana ; Ail + Poire → 4 PV, 1 mana ; Ail + Prune → 4 PV, 2 mana
- Mijoté / four (cuisine), immonde — viande avariée : immangeable (et intoxication 1 fois sur 2) : Viande périmée → 6 PV, 0 mana ; Viande crue + Viande périmée → 12 PV, 0 mana ; Viande périmée + Viande périmée → 12 PV, 0 mana
- Mijoté / four (cuisine), mixture : Chou → 4 PV, 1 mana ; Navet → 3 PV, 1 mana ; Carotte → 2 PV, 2 mana
- Mijoté / four (cuisine), mixture — presque : Bouillie au miel (bouilli) : Lait + Farine + Miel → 11 PV, 4 mana
- Mijoté / four (cuisine), mixture — presque : Brochette (grillé) : Viande crue + Tomate + Oignon → 16 PV, 5 mana
- Mijoté / four (cuisine), mixture — presque : Champignons à l'ail (grillé) : Ail + Champignon + Champignon → 4 PV, 10 mana
- Mijoté / four (cuisine), mixture — presque : Compote (bouilli) : Pomme + Pomme → 15 PV, 0 mana ; Pomme + Poire → 15 PV, 0 mana ; Pomme + Prune → 14 PV, 2 mana
- Mijoté / four (cuisine), mixture — presque : Lait chaud (bouilli) : Lait → 4 PV, 1 mana
- Mijoté / four (cuisine), mixture — presque : Omelette (grillé) : Œuf + Œuf → 12 PV, 0 mana
- Mijoté / four (cuisine), mixture — presque : Omelette aux champignons (grillé) : Œuf + Œuf + Champignon → 14 PV, 4 mana
- Mijoté / four (cuisine), mixture — presque : Pomme de terre grillée (grillé) : Pomme de terre → 5 PV, 0 mana
- Mijoté / four (cuisine), mixture — presque : Purée (bouilli) : Pomme de terre + Pomme de terre → 10 PV, 0 mana
- Mijoté / four (cuisine), mixture — presque : Salade de fruits (sans feu) : Pomme + Pomme + Pomme → 22 PV, 0 mana ; Pomme + Pomme + Poire → 22 PV, 0 mana ; Pomme + Pomme + Prune → 21 PV, 2 mana
- Mijoté / four (cuisine), mixture — presque : Soupe aux champignons (bouilli) : Champignon + Champignon + Herbes → 3 PV, 11 mana
- Mijoté / four (cuisine), mixture — presque : Soupe de légumes (bouilli) : Pomme de terre + Chou → 9 PV, 1 mana ; Pomme de terre + Navet → 8 PV, 1 mana ; Pomme de terre + Carotte → 8 PV, 2 mana
- Mijoté / four (cuisine), mixture — presque : Soupe à l'oignon (bouilli) : Oignon + Oignon + Oignon → 3 PV, 9 mana
- Mijoté / four (cuisine), mixture — presque : Tomates farcies (grillé) : Viande crue + Tomate → 14 PV, 2 mana
- Mijoté / four (cuisine), mixture — presque : Viande bouillie (bouilli) : Viande crue + Carotte → 15 PV, 2 mana ; Viande crue + Oignon → 14 PV, 3 mana
- Mijoté / four (cuisine), mixture — presque : Viande grillée (grillé) : Viande crue → 12 PV, 0 mana
- Mijoté / four (cuisine), mixture — presque : Viande marinée au citron (grillé) : Viande crue + Oignon + Citron → 16 PV, 8 mana
- Sans feu, immonde — 3 fois ou plus le même ingrédient fort (ail, citron, herbes) : Viande crue + Ail + Ail + Ail → 8 PV, 4 mana ; Viande crue + Citron + Citron + Citron → 10 PV, 8 mana ; Viande crue + Herbes + Herbes + Herbes → 6 PV, 4 mana
- Sans feu, immonde — dessert et potage mélangés (sucré avec 2 légumes ou plus) : Pomme de terre + Pomme de terre + Pomme → 9 PV, 0 mana ; Pomme de terre + Pomme de terre + Poire → 9 PV, 0 mana ; Pomme de terre + Pomme de terre + Prune → 8 PV, 1 mana
- Sans feu, immonde — farine sans œuf ni lait : de la colle ou de la farine brûlée : Viande crue + Farine → 8 PV, 0 mana ; Pomme de terre + Farine → 4 PV, 0 mana ; Chou + Farine → 4 PV, 0 mana
- Sans feu, immonde — le lait caille avec le citron ou l'orange : Orange + Lait → 5 PV, 1 mana ; Citron + Lait → 3 PV, 3 mana ; Viande crue + Orange + Lait → 11 PV, 1 mana
- Sans feu, immonde — oignon dans un plat sucré (sans viande pour le justifier) : Oignon + Pomme → 4 PV, 2 mana ; Oignon + Poire → 4 PV, 2 mana ; Oignon + Prune → 4 PV, 2 mana
- Sans feu, immonde — sans feu : viande, œuf, pomme de terre ou farine crus : Pomme de terre + Pomme de terre → 5 PV, 0 mana ; Pomme de terre + Chou → 4 PV, 0 mana ; Pomme de terre + Navet → 4 PV, 0 mana
- Sans feu, immonde — seulement de l'ail, des herbes ou du citron : immangeable : Ail + Ail → 1 PV, 2 mana ; Ail + Citron → 2 PV, 4 mana ; Ail + Herbes → 0 PV, 3 mana
- Sans feu, immonde — sucré (fruit, miel) avec de l'ail ou des champignons : Ail + Pomme → 4 PV, 1 mana ; Ail + Poire → 4 PV, 1 mana ; Ail + Prune → 4 PV, 2 mana
- Sans feu, immonde — viande avariée : immangeable (et intoxication 1 fois sur 2) : Viande périmée → 6 PV, 0 mana ; Viande crue + Viande périmée → 12 PV, 0 mana ; Viande périmée + Viande périmée → 12 PV, 0 mana
- Sans feu, immonde — viande crue mangée sans cuisson (intoxication 1 fois sur 4) : Viande crue → 6 PV, 0 mana ; Viande crue + Viande crue → 12 PV, 0 mana ; Viande crue + Pomme de terre → 9 PV, 0 mana
- Sans feu, mixture : Chou + Ail → 5 PV, 4 mana ; Chou + Pomme → 12 PV, 1 mana ; Chou + Poire → 12 PV, 1 mana
- Sans feu, mixture — presque : Champignons à l'ail (grillé) : Ail + Champignon + Champignon → 4 PV, 10 mana
- Sans feu, mixture — presque : Compote (bouilli) : Pomme + Pomme → 15 PV, 0 mana ; Pomme + Poire → 15 PV, 0 mana ; Pomme + Prune → 14 PV, 2 mana
- Sans feu, mixture — presque : Légumes mijotés aux herbes (mijoté / four (cuisine)) : Tomate + Oignon + Ail + Herbes → 4 PV, 10 mana
- Sans feu, mixture — presque : Soupe aux champignons (bouilli) : Champignon + Champignon + Herbes → 3 PV, 11 mana
- Sans feu, mixture — presque : Soupe de légumes (bouilli) : Chou + Chou → 8 PV, 2 mana ; Chou + Navet → 7 PV, 2 mana ; Chou + Carotte → 6 PV, 2 mana
- Sans feu, mixture — presque : Soupe à l'oignon (bouilli) : Oignon + Oignon + Oignon → 3 PV, 9 mana
- Sans feu, pas un plat — un seul ingrédient sans feu : on ne cuisine rien (les fruits se mangent tels quels) : Pomme de terre → 10 PV, 0 mana ; Chou → 8 PV, 2 mana ; Navet → 6 PV, 2 mana
