# Feuille de route : le donjon d'aventure

Source : `..\liste des cohse a ajouter.odt` (liste de l'utilisateur, 2026-10-26) : le jeu devient centré
sur l'exploration et l'aventure plutôt que sur le combat.

## Décisions de l'utilisateur (2026-10-26)

- **Les ennemis ne donnent plus rien** (ni expérience, ni or, ni objet), sauf les ennemis rares qui portent un
  équipement. Plus de progression par niveaux : **désactivée, pas supprimée** (l'utilisateur y reviendra peut-être).
- **Deux sortes d'ennemis imbattables** : les **imbattables** (on ne peut pas les vaincre : il faut les fuir) et les
  **geôliers** (s'ils attrapent le héros, il est emmené au cachot).
- **Toute défaite mène à la mort** ; seul le geôlier mène en prison.
- **Fuite de combat** : nouvelle action, avec une chance d'échouer.
- **Ennemis visibles dans les salles, à la Fear & Hunger** : plus de combat automatique en entrant. Les ennemis
  se déplacent dans la salle ; on peut les contourner, les fuir, ou foncer sur eux pour combattre. S'ils voient le
  héros, ils le poursuivent : il faut se cacher. **Formes géométriques simples** en attendant les animations.

Toutes les autres valeurs (chances, nombres, vitesses...) sont **choisies par Claude, à valider** : elles sont
regroupées dans `scripts/logique/aventure.gd` et listées dans le README.

## Étapes

- [x] 1. Socle : `Aventure` (réglages, population des salles), récompenses des ennemis et niveaux désactivés.
- [x] 2. Rôdeurs dans les salles peintes : formes, déplacement, vue, poursuite, cachettes (derrière les piliers),
      contact → combat ; poursuite d'une salle à l'autre.
- [x] 3. Fuite de combat (bouton « Fuir », chance d'échec) ; imbattables invulnérables.
- [x] 4. Boss gardien de sa salle (plus de combat automatique), « Monter » une fois le boss vaincu.
- [x] 5. Geôliers et cachot : capture, objets confisqués (coffre des confiscations, objets perdus, porteurs).
- [x] 6. Personnages à qui parler : écran de dialogue ; diablotins (vrai une fois sur deux : boss, étage, ennemis) ;
      choix moraux (gobelin blessé, prisonnier, autel) ; gobelins pacifiques à ne pas tuer (sinon plus d'imbattables).
- [x] 7. Clés et salles verrouillées (salles bonus de meilleure qualité).
- [x] 8. Sorts et équipement par l'exploration : bibliothèques (pupitre), cachettes secrètes, râteliers, livres.
- [x] 9. Tests (logique + captures) et documentation (README, IDEES_GAMEPLAY).

## Fait le 2026-10-26 (première version, tout est jouable)

Toutes les étapes sont codées et testées (`tests/test_aventure.gd`, `tests/capture_aventure.gd`). Écarts avec le plan :
- **Se cacher** : derrière les piliers c'est presque impossible (les piliers sont des obstacles, on ne passe pas
  derrière : `tests/sonde_cachettes.gd`). Remplacé par : **immobile dans l'ombre** (quart le plus sombre du sol de
  chaque image) et **vue coupée par les piliers et obstacles**.

## Retours de l'utilisateur (2026-10-26)

- Ennemis ralentis de 20 %. Moins de grimoires ; un grimoire = un sort au hasard déjà amélioré ; un seul choix de
  sort, au début. Arme toujours récupérable après une capture. **Salles trop petites pour la poursuite** :
  l'utilisateur réfléchit à des salles plus grandes ou à des images plus grandes.

## Reste à décider ou à faire

- Valider les valeurs (tableau du README) ; animations des ennemis qui rôdent (formes géométriques pour l'instant).
- Compétences (attaques d'arme) gagnées par l'exploration : comment ?
- Conséquences de la clémence et de la cruauté (`donjon.moralite`, comptées mais sans effet).
- Plusieurs bibliothèques par étage, salles cachées sur la carte (aujourd'hui : cachettes dans les salles).
- Les potions ne viennent plus des ennemis : sources de soin, marchand, coffres, squelettes (à surveiller).
