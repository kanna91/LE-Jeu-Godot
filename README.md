# LE Jeu — portage Godot

## ⬇️ Télécharger le jeu (Windows)

**[Télécharger LE_Jeu_Ultime_Windows.zip](https://github.com/kanna91/LE-Jeu-Godot/releases/latest/download/LE_Jeu_Ultime_Windows.zip)**
(environ 650 Mo, dernière version) — [toutes les versions](https://github.com/kanna91/LE-Jeu-Godot/releases)

1. Dézipper le fichier (clic droit > Extraire tout).
2. Double-cliquer sur `LE_Jeu_Ultime.exe`. Rien à installer ; garder le dossier `images` à côté du .exe.
3. Si Windows affiche « Windows a protégé votre ordinateur » : « Informations complémentaires » puis « Exécuter quand même ».

Jeu en **Godot 4.7**, en GDScript (fenêtre logique 960×540). Il est né d'un portage 2D du RPG
pygame, dont il s'est ensuite écarté (donjon d'aventure). **La version Python a été supprimée le
2026-10-31** (récupérable dans l'historique git, commit `60efa0c` et avant) : ce dossier est
désormais la seule version du jeu.

## Lancer le jeu

- **Éditeur :** ouvrir `project.godot` avec Godot 4.7 (`C:\jeux\Godot\Godot_v4.7.2-stable_win64.exe`), puis F5.
- **En ligne de commande :**
  ```powershell
  & "C:\jeux\Godot\Godot_v4.7.2-stable_win64_console.exe" --path .
  ```
- **Essayer la grande salle 5 et sa maquette 3D cachée :** double-cliquer `essai_grande5.bat` (ou
  `Godot_v4.7.2-stable_win64.exe --path . res://tests/essai_grande5.tscn`). Le héros est seul dans la salle, sorties
  murées ; **F1** montre ou cache la maquette (vert = sol, rouge = obstacles, bleu = ce qui passe devant le héros,
  jaune = sorties, cercle blanc = l'emprise des pieds).
- **Définir soi-même les zones d'une salle :** double-cliquer `editeur_zones.bat` (ou `editeur_zones.bat grande5`
  pour ouvrir une salle précise). Voir « Éditeur de zones » ci-dessous.
- La fenêtre s'ouvre en 1280×720 et s'adapte (canvas_items, proportions conservées).
- Sauvegardes : `user://sauvegardes` (sous Windows : `%APPDATA%\Godot\app_userdata\LE Jeu Ultime\sauvegardes`).
- **Version jouable Windows (.exe) :** double-cliquer `exporter_windows.bat`. Il produit
  `..\export\windows\` (`LE_Jeu_Ultime.exe` + `images\salles_peintes` et `images\objets_salles`) et
  `..\export\LE_Jeu_Ultime_Windows.zip` à distribuer (dézipper puis lancer le .exe). Réglage : `export_presets.cfg`
  (préréglage « Windows », pck intégré à l'exe, `tests/` et `outils/` exclus, `*.json` inclus). Il faut les modèles
  d'export 4.7.2 dans `%APPDATA%\Godot\export_templates\4.7.2.stable\`.

Commandes identiques à la version pygame (souris, clavier, manette : A = clic,
B = Échap, X = clic droit, Y = I, LB/RB = molette, Back = Tab, Start = C), sauf dans
l'exploration (salles peintes, voir plus bas) : flèches ou ZQSD (stick gauche ou croix) pour
marcher, Maj pour passer de la marche à la course, **H** pour le soin hors combat (au lieu de S),
stick droit pour choisir un bouton de l'interface.

## Règles du jeu

> **Sphérier des talents supprimé le 2026-10-31** (il sera refait) : ses 791 talents, son écran
> (`menu_talents.gd`, tuile « Talents », touche T) et son test de captures. `donnees/talents.json` ne garde que
> les libellés des bonus (descriptions des effets uniques des objets). **Les fonctions sont gardées** pour le
> futur sphérier : effets en combat (`Talents.multiplicateur_degats`, `reagir`, `debut_tour`... lus aussi pour
> les effets uniques des objets), fonctions de l'arbre (`Talents.spherier`, `accessible`, `partie`,
> `cle_a_malus`, vides pour l'instant), `Talent`, `ArbreDeTalent`, `Personnage.debloquer_talent`.
>
> **Supprimée le 2026-11-03, à reforger entièrement par l'utilisateur : l'amélioration des compétences.** Plus
> d'arbre d'amélioration, de points d'amélioration, de menu « Améliorer » ni de sort « déjà amélioré » par les
> grimoires ; les ennemis n'améliorent plus leurs compétences. Restent : le niveau et l'expérience des compétences
> (sans effet pour l'instant), les champs de bonus des compétences lus par le combat (`multiplicateur_degats`,
> `bonus_toucher`, `bonus_critique`, `vol_de_vie`, `bonus_execution`, `pourcentage_types`...), tous à leur valeur
> neutre, prêts pour le nouveau système, et l'image `images/menu_améliorer_compétence.png`. Les corrections de base des
> compétences sont dans `scripts/logique/bases_competences.gd` (`BasesCompetences`).

- **Donjon d'aventure** (2026-10-26, liste de l'utilisateur `..\liste des cohse a ajouter.odt`, feuille de route
  `FEUILLE_DE_ROUTE_AVENTURE.md`) : le jeu est centré sur l'exploration plutôt que sur le combat (l'ancien mode,
  un combat en entrant dans chaque salle, et son interrupteur `Aventure.ACTIF` ont été supprimés le 2026-10-31).
  **Décisions de l'utilisateur** :
  - **Les ennemis ne donnent plus rien** (ni expérience, ni or, ni butin ; code supprimé le
    2026-10-31), sauf les rares qui portent un équipement : une **élite** (gobelin plus fort en tête d'un groupe) lâche un objet, un
    **porteur** rend les objets confisqués qu'il porte.
  - **Plus de montée de niveau** (supprimée le 2026-10-31, avec l'expérience du héros, les points de caractéristique
    et les points passifs ; le héros reste au niveau 1). Le bandeau du haut montre l'or, les clés, les PA et les repos (plus le niveau ni l'expérience).
  - **Plus de combat en entrant dans une salle : les ennemis y rôdent, visibles** (à la Fear & Hunger), en
    **formes géométriques** en attendant leurs animations (`PresencesSalle`). Ils patrouillent ; s'ils voient le héros
    (cône de vue devant eux, **coupé par les piliers et obstacles**) ou l'entendent (il **court**, ou marche tout
    près), ils s'arrêtent (« ! ») puis le **poursuivent** ; perdu de vue, ils le cherchent (« ? ») puis reprennent
    leur ronde. **Se cacher** : rester **immobile dans l'ombre** (les zones les plus sombres du sol de l'image :
    `SallePeinte.dans_ombre`, le quart le plus sombre de chaque salle) ou derrière le premier plan ; marcher dans
    l'ombre divise leur vue par deux. Bandeau « Repéré ! », « Caché » ou « Dans l'ombre ». Un poursuivant peut
    **suivre le héros dans la salle suivante** (il entre par la même porte peu après). **Toucher un ennemi = combat**
    (on peut foncer sur eux) ; après une fuite réussie, il est repoussé et les rôdeurs se figent un instant.
  - **Fuite de combat** : nouveau bouton « Fuir » (`Combat.tenter_fuite`) : réussie, le combat s'arrête ; ratée, le
    tour est perdu. L'infobulle donne la chance.
  - **Deux sortes d'imbattables** : le **Chevalier de la mort** (« imbattable », ex-Chevalier de la mort ; fiche de
    l'utilisateur : 300 PV, chaque coup subi ramené à 1 ou 2 dégâts, 3 sur un critique ; frappe 2d6 tranchant +
    1d6 ombre ; plus lent que le héros qui marche ; une fois lancé à sa poursuite, il le **traque sur au moins
    2 salles** sans perdre sa trace ; mieux vaut le fuir) et le **geôlier** (s'il touche le héros, il l'emmène au
    cachot). **1 chevalier et 2 geôliers par étage** (décision de l'utilisateur, 2026-10-27 ; le karma négatif en
    ajoute un tous les 5 points, voir « Karma »).
  - **L'étage vit** (règles de l'utilisateur, 2026-10-27 ; `Aventure` « chasseurs », `menu_navigation._faire_vivre_l_etage`) :
    le chevalier part du **milieu de l'étage** (`Aventure.centre_etage` : la salle d'où la plus lointaine est la plus
    proche), les geôliers loin du départ. Ensuite tous vont de salle en salle **au hasard** (jamais dans la salle du
    boss, sans revenir sur leurs pas sauf impasse) à leur vitesse, **même dans les salles où le héros n'est pas** :
    seul l'affichage est réservé à sa salle. Traverser une salle prend 6 hauteurs de héros à leur vitesse de
    poursuite (`Aventure.duree_salle` : chevalier ≈ 9 s ; geôlier 6 s, fixé par l'utilisateur dans `DUREE_SALLE`). Un chasseur qui entre dans la salle du
    héros apparaît devant la porte de la salle d'où il vient ; dans la salle du héros, il fait sa ronde puis repart
    par une porte. **Un combat** les attire tous : ils apprennent dans quelle salle est le héros et y vont (à leur
    vitesse ; en entrant, ils savent où il est). **Une action bruyante** (chaînes du prisonnier brisées) : le
    chevalier, s'il est à plus de 3 salles, **se téléporte à 3 salles** du héros, et il se dirige vers lui ; les
    geôliers ne se téléportent pas, ils se dirigent vers la salle du bruit. **Courir n'alerte que les ennemis de la
    salle** (ils l'entendent de plus loin), pas le reste de l'étage (décision de l'utilisateur). **Toute défaite est
    la mort** ; seul le geôlier mène en prison.
  - **Capture** (`Aventure.capturer`) : depuis le 2026-11-03 (règle de l'utilisateur), le geôlier met le héros dans la
    **prison la plus proche** de la salle où il est pris (des 4 prisons des coins, la plus proche par le chemin ; il se
    réveille dans sa 2e grande salle, au fond, à côté du couloir des cryptes : `Aventure.cellule_la_plus_proche`) ; le
    coffre des confiscations est près de cette prison. Sans prison (ancienne partie) : le **cachot** de l'étage (une
    salle à image « prison » la plus loin du boss, à au moins 3 salles du départ, qui sert aussi au Pacte de mort ;
    repli : le cul-de-sac le plus loin du boss). Le héros se réveille sans rien : équipement, sac et or confisqués. Chaque objet va dans le **coffre des
    confiscations** (dans une autre salle, avec tout l'or), est **perdu**, ou est **porté par un porteur**
    (gobelin rare, PV × 1,5 d'une élite, à vaincre pour le récupérer). **L'arme portée n'est jamais perdue** : elle
    est toujours dans le coffre des confiscations (rééquipée en l'ouvrant). Le geôlier repart dans une autre salle.
  - **Le boss garde sa salle** (on va à lui pour le combattre) ; « Monter » n'apparaît qu'une fois le boss vaincu.
  - **Un seul étage pour l'instant** (2026-11-03, demande de l'utilisateur : « on construit un niveau » ;
    `Donjon.NOMBRE_ETAGES` = 1, 5 avant), plus le **niveau des cryptes**, un monde à part (voir « Prisons et niveau des
    cryptes »). Vaincre le boss de l'étage puis « Monter » termine la partie.
  - **Donjon de 5 étages, généré en entier au lancement** (décisions de l'utilisateur, 2026-10-30 ; 1 étage depuis le 2026-11-03) :
    `Donjon.nouveau` crée les `Donjon.NOMBRE_ETAGES` étages d'un coup (plan, images des salles, population ;
    ≈ 400 salles en 0,6 s). Vaincre le boss du 5e étage puis « Monter » termine la partie : **écran de victoire**
    (l'écran de fin, titre « VICTOIRE », `principal.gd` résultat `["victoire"]`). Avant, le donjon était sans fin et
    chaque étage était créé à la montée. Taille d'un étage : environ 80 salles (`GenerateurEtage.TAILLE_ETAGE`).

  **Ce que contient un étage** (`Aventure.preparer_etage`, une fois, enregistré dans la partie : clé « presences »
  de chaque salle, réglages de l'étage dans `donjon.aventure`) :
  - **zones d'ennemis** (2026-11-02, `donnees/zones.json`, `Zones`) : chaque zone (les salles dont l'image commence
    par un préfixe) a ses propres ennemis, modifiables sans toucher au code (mode d'emploi dans « _lisez_moi ») :
    sortes des groupes et leurs poids (« gobelin », une classe de gobelin, « squelette », « loup »), sortes des élites
    et de leur escorte,
    nombre d'élites fixe ou chance par groupe, chances de pacifiques, de loup, de féticheur menant des squelettes.
    Hors zone : « defaut » (75 % gobelins, 25 % squelettes, élite 12 %, pacifique 15 %, loup 50 %, féticheur 20 % :
    les anciennes constantes `Aventure.CHANCE_*`). **Cryptes** (décision de l'utilisateur) : **seulement des
    squelettes**, et **une seule élite, un féticheur**, dans tout le quartier. Un groupe retient sa zone
    (`zone_ennemis`) ; il en tire ses ennemis même s'il en sort pour poursuivre le héros. Pas d'élite de plus dans
    les cryptes : ni la clé du boss ni l'amulette de Mariane n'en créent (s'il le faut, un squelette porte
    l'amulette). Chevaliers de la mort et geôliers ne partent jamais d'une zone, mais ils y passent ;
  - **geôliers jamais dans les cryptes** (2026-11-03, règle de l'utilisateur ; `Aventure.HORS_CRYPTES`,
    `Aventure.fermee_a`) : aucun geôlier n'est posé dans les cryptes, n'y entre en marchant, n'y est déplacé
    (capture, pacte, vacarme) ni n'y suit le héros par un passage ; un geôlier trouvé dans une crypte (ancienne
    partie) disparaît. Les cryptes sont donc sûres face à la capture (le Chevalier de la mort n'est pas concerné) ;
  - **cuisine = refuge** (2026-11-02, décision de l'utilisateur ; zone « cuisine » de zones.json, `"sans_ennemis": true`,
    `Zones.refuge`) : **aucun ennemi** n'est posé dans les 5 salles du bloc cuisine, et **aucun n'y entre** : ni
    gobelin, ni squelette, ni geôlier, ni Chevalier de la mort (`Aventure.prochaine_salle` ne choisit jamais un refuge ;
    attirés par le héros qui s'y trouve, les chasseurs renoncent à la porte ; personne ne l'y suit ; le vacarme ne
    téléporte pas le chevalier dedans ; capture, clé du boss, objets de quête et porteurs jamais dedans). Seuls les
    personnages neutres y vont (pas le gobelin blessé, `Aventure.PNJ_HORS_REFUGE`) ; l'utilisateur prépare ceux de la
    cuisine. Un ennemi qui s'y trouverait (ancienne partie) est déplacé ailleurs à la lecture de la salle ;
  - groupes de gobelins qui rôdent (salles ordinaires), parfois menés par une **élite** (appelée « chef » avant le 2026-10-31), parfois **pacifiques** (ils
    s'écartent ; au contact ils demandent grâce : les **épargner** (un peu d'or, parfois un objet, ils partent ;
    karma +1) ou les **attaquer** (karma −1 ; leur corps se fouille et leur âme se siphonne) : voir « Karma ») ;
  - Chevaliers de la mort et geôliers loin du départ ; le cachot (une grande salle d'une des **prisons des coins**, voir
    « Prisons et niveau des cryptes ») ; le boss, dont la classe est tirée dès la création de l'étage ;
  - un **coffre ancien** (cerclé de fer, sceau rouge) : l'**armure anti-boss** de l'étage (voir « Armure anti-boss ») ;
  - **diablotins** (`Rencontres.diablotin`, fiche de l'utilisateur) : ils transmettent les informations **au
    compte-gouttes** et **jamais deux fois la même dans une partie** : le **Chevalier de la mort** (14 informations,
    dans l'ordre, **un élément à la fois** depuis le 2026-10-31 : une résistance, sa lame... ; sa limite de dégâts subis reste
    secrète, aucun diablotin n'en parle), **l'étage** (faiblesse puis force du boss, direction du geôlier, du pupitre, d'une cachette,
    d'un chevalier, de la succube, d'une salle verrouillée), **« Mes affaires ? »** après une capture (où sont le
    coffre des confiscations et les porteurs) et **« Autre chose ? »** (conseils sur les mécaniques ; le lore viendra
    dans `Rencontres.LORE`). Les lieux sont donnés **depuis la salle du diablotin** (2026-10-30) : « à 3 salles d'ici,
    en partant par la sortie de gauche (ouest) » (plus court chemin, `Rencontres.direction`). Ils **peuvent mentir, mais seulement sur le donjon, jamais sur les ennemis** : une réponse
    à « Cet étage ? » sur trois (`Rencontres.CHANCE_MENSONGE`) est un mensonge (fausse direction de la cachette ou du
    pupitre, salle secrète ou coffre qui n'existent pas, lame « capable de blesser le Chevalier de la mort »), noté au
    journal comme une vraie information ; le diablotin ne se contredit jamais ensuite. Chacun répond à 2 questions puis disparaît. Chaque réponse va dans le
    **journal** du joueur (touche **J**, ou bouton « Journal » du menu Pause) ;
  - **Glossaire du compte** (2026-10-31) : les informations **générales sur les ennemis** (Chevalier de la mort,
    et les conseils qui parlent du geôlier ou des gobelins : `Rencontres.ASTUCES`, 3e champ) vont aussi dans l'onglet
    **« Glossaire »** du journal (clic, ← → ou G). Il est lié au **compte** (`Compte`, fichier `user://compte.json`) :
    il **reste quand le joueur meurt et recommence**, et un diablotin ne redit **jamais** une information sur un
    ennemi déjà apprise, même dans une autre partie. Le reste (étage, affaires, conseils généraux) ne vaut que pour
    la partie. Pendant les tests (`-s`), le compte reste en mémoire et n'écrit rien ;
  - **Statistiques du Chevalier de la mort cachées** (2026-10-31) : sa fiche détaillée et son info-bulle de combat
    affichent « ??? » à la place de chaque valeur (PV, caractéristiques, attaque, défense, compétences ; jauges
    pleines). Drapeau `stats_cachees` (posé par `Aventure.creer_imbattable`), lu par `FicheEnnemi.stats_cachees` ;
  - **Salles pièges désactivées** (2026-10-31) : `Donjon.CHANCE_PIEGE` = 0 (1 sur 15 avant ; `salle_piege` gardée) ;
  - **Potions de niveau 1** (2026-10-31) : la potion de soin rend **40 PV**, celle de mana **40 points de mana**
    (valeur fixe : `"fixe": true` dans l'effet, `Consommable.POINTS_NIVEAU_1`) ; niveaux 2 et 3 inchangés (% du
    maximum). Les potions que boivent les ennemis en combat gardent l'ancienne règle (40 PV soigneraient un gobelin
    en entier) ;
  - **Coffre des confiscations près du cachot** (2026-10-31) : le coffre (objets et or) est à **3 salles au plus** de
    la salle où le héros se réveille (`Aventure.salle_du_coffre`, `COFFRE_PRES_DU_CACHOT`), jamais dans une salle
    fermée à clé ;
  - **Blocs de salles** (2026-10-31, demande de l'utilisateur : on va remplacer petit à petit les salles tirées au
    hasard par des **blocs de salles connectés les uns aux autres**) : un lot d'images de l'utilisateur forme des
    salles reliées dans un ordre fixé (`BlocsSalles.BLOCS` : position de chaque salle sur la carte, liens **porte à
    porte**, entrées vers le reste de l'étage). Le générateur pose chaque bloc après les branches, sur des cases
    libres, ses entrées raccordées à des salles existantes (`GenerateurEtage._poser_bloc`) ; ses salles reçoivent leur
    image et leurs sorties dès la création de l'étage (`Donjon._habiller_blocs`) ; ses images (`bloc_*`) ne servent
    jamais ailleurs. Premier bloc, **cuisine** (un par étage) : **salle à manger** (entrée par le bas, depuis l'étage)
    → porte du fond → **cuisine** → porte du fond à gauche (elle mène vers l'avant, le nord) → **réserve de la
    cuisine** (image « petite porte de la cuisine ») → porte de gauche → **cellier gauche** (ouest), porte de droite →
    **cellier droit** (est) ; l'**arche du fond** de la réserve ressort sur l'étage (deuxième entrée). Exception
    d'orientation voulue : on entre dans un cellier par le bas de son image. Zones relevées à la main
    (`outils/importer_blocs.py`, planche `C:\IA\pont-blender\bloc_cuisine\planche_zones.png`, retouchables dans
    l'éditeur de zones) ;
  - **Cachettes** (règle de l'utilisateur, 2026-11-01) : zones « cachettes » tracées avec l'éditeur de zones (couche 6).
    Le héros qui s'y trouve n'est **ni vu ni entendu** (bandeau « Caché ») ; les ennemis **ne l'y poursuivent pas** :
    ils n'entrent pas dans la zone, perdent sa trace et ne lancent pas de combat (même le Chevalier de la mort qui le
    traque). Exception : un ennemi qui le poursuivait à moins de `PresencesSalle.PROCHE_CACHETTE` (0,6 hauteur de
    héros, choix de Claude, à valider) quand il y est entré l'a **vu entrer** et peut l'y suivre. En sortant, ce
    privilège disparaît. (À ne pas confondre avec les cachettes secrètes dans les murs, qui cachent des objets.)
  - **Prisonniers des cellules** (ébauche, 2026-11-01 ; l'utilisateur fournira dialogues, informations et quêtes) :
    un prisonnier par **zone de dialogue** « prisonniers » tracée avec l'éditeur de zones (`Aventure._poser_prisonniers`) ;
    il est peint dans l'image (rien n'est dessiné par-dessus) et on lui parle quand le héros est dans sa zone. On
    peut lui **parler** (une petite information de `donnees/prisonniers.json`, jamais deux fois, notée au journal),
    le **tuer** (karma −1, `Karma.ACTES` « tuer_prisonnier_cellule » ; son corps reste, 1 âme à siphonner) ou partir.
    Accueil et informations des prisonniers ordinaires : encore vides dans `donnees/prisonniers.json`.
  - **Quêtes des prisonniers** (2026-11-02, textes de l'utilisateur ; `scripts/logique/quetes_prisonniers.gd`) : tout
    le contenu est dans `donnees/prisonniers.json` (« quetes », « objets » ; mode d'emploi dans « _lisez_moi ») pour
    pouvoir les changer sans toucher au code. Chaque quête est posée **une fois par partie**, dans une cellule d'une
    prison d'un des étages de sa liste « etages » (les trois : étage 1, pour les essayer). Une quête est une suite
    d'**étapes** : texte (une bulle par ligne) et actions la première fois, répliques répétées ensuite, objet à
    donner (bouton « Donner : ... »), événement attendu (élite vaincu). Actions : karma, sort au hasard, objet posé
    au sol (cuisine du bloc cuisine, à ramasser avec E), objet confié à un élite (sur son corps ; « {direction} »
    dans un texte dit où il est : « vers le nord-est, à 5 salles d'ici »), élite (ou élite+, PV × 1,5) qui entre par
    une porte et attaque, Chevalier de la mort de l'étage qui entre ou attaque tout de suite, bijou de récompense,
    départ du prisonnier. On peut toujours tuer un prisonnier à quête (karma −1).
    | Prisonnier | Déroulé |
    |---|---|
    | Vieux magicien | soupe à la cuisine → karma +1 et un sort au hasard ; ensuite il dort : trois réveils, puis « GARDE ! » (un élite attaque) ; élite vaincu et on l'embête encore → malédiction, karma −2, le Chevalier de la mort entre ; puis à chaque fois « AHAHAHAHA ! » et combat direct contre le chevalier |
    | Prisonnier malade | une potion de soin → de la nourriture (soupe posée à la cuisine, ou toute nourriture) → la clé de sa cellule, sur un élite loin de lui (il dit où) → **le prisonnier était l'élite** : un élite+ « Faux prisonnier+ » surgit à sa place et attaque |
    | Mariane | son amulette, sur un élite des catacombes (salles « crypte ») : **Amulette de Mariane** (intelligence +2, Mana +1, sagesse −1, équipable : on peut la garder) → un anneau **rare** (meilleur rang de l'étage + 2 : rang 4 à l'étage 1), elle disparaît |
    Validé par l'utilisateur : élite+ = élite aux PV × 1,5 ; « bague de niveau +2 » = **rare** à l'étage 1 (meilleur
    rang de l'étage + 2 ; précieux avant, corrigé le 2026-11-02) ; les catacombes sont les salles « crypte ». Limite : le prisonnier est peint dans l'image, il y reste après son départ (on ne peut
    simplement plus lui parler) ;
  - **Commis** (2026-11-04, animations de l'utilisateur) : un **commis dans la cuisine** du bloc cuisine (celui à la
    louche) explique la cuisine (touche K, préparations, feu de camp, eau, recettes, bouillon, viande crue) ; un
    **commis dans le cellier droit** dit où trouver des ingrédients (marchand, loups, provisions au sol). Place fixe
    dans l'image (`Aventure.COMMIS`, choix de Claude), animation de repos en boucle (`images/pnj/commis_<rôle>_anim`,
    `outils/importer_commis.py`) ; on leur parle avec E, autant qu'on veut (une bulle par explication). La
    **cuisinière** (image fixe de l'utilisateur, détourée par `outils/importer_cuisiniere.py`, qui respire doucement)
    est aussi dans la cuisine, devant la table des fours ; elle bougonne et renvoie au commis pour apprendre à cuisiner.
  - **Dialogues** (2026-11-04) : les textes des personnages (commis, diablotin, succube, gobelin blessé, prisonnier
    enchaîné, autel, gobelins pacifiques, rumeurs, prisonnier des cellules sans quête) sont dans
    `donnees/dialogues.json` (`Dialogues`) ; ceux des prisonniers et de leurs quêtes restent dans
    `donnees/prisonniers.json`. Les deux se modifient dans l'éditeur de zones, menu **Dialogues** ;
  - **Viande des loups** (règle de l'utilisateur, 2026-11-04) : chaque loup d'un corps fouillé donne **1 viande crue**
    (ingrédient) en plus du reste (`Fouille.VIANDE_PAR_LOUP`) ;
  - **Catégorie « Divers »** (2026-10-31) dans l'inventaire et chez le marchand : objets neutres qui ne s'équipent ni
    ne s'utilisent (vaisselle, argenterie, gemmes, objets cassés), pour de futures quêtes ou la revente. Les **clés**
    du héros s'y affichent en tête (« Clé rouillée ×N ») ;
  - **Catégories « Nourriture » et « Ingrédients »** (2026-11-03, demande de l'utilisateur) dans l'inventaire (deux
    rangées d'onglets) et chez le marchand. La **nourriture se mange** (double-clic, hors combat) et rend des PV ; les
    **ingrédients** ne se mangent pas (ils serviront à cuisiner). Le marchand vend 2 à 4 nourritures et 1 à 3
    ingrédients. **Catalogue** (liste de l'utilisateur) : `donnees/objets_divers.json` — objets divers (gobelets,
    assiettes, chandeliers, couteaux, seau, pépite et dent en or, **pierres en 3 tailles** : petit / normal / grand
    rubis, émeraude, saphir à 80 / 160 / 240 or, grenat 40 / 80 / 120, décision de l'utilisateur), tissu, métal,
    bois, planche ; matériel de cuisine : marmite, silex, amadou, page de livre de cuisine), nourritures (**bol de
    soupe et viande grillée 35 PV, viande bouillie 30, viande séchée 25, fruits 15**, décision de l'utilisateur ;
    bouillon), ingrédients (légumes, viande crue, viande périmée, œuf, lait, farine, miel, champignon, herbes, ail).
    La nourriture ne se mange **jamais en combat** ;
  - **Cuisine** (2026-11-03, règles de l'utilisateur, conception complète dans `CUISINE.md`) : touche **K** en
    exploration. 1 à 4 ingrédients (+ un bouillon) et une préparation : sans feu, **grillé** (feu de camp ou cuisine ;
    **on ne cuit jamais à même une torche**, elle sert seulement à allumer du bois), **bouilli** (feu de camp ou
    cuisine ; hors de la cuisine : marmite + 1 L d'eau du seau de 10 L, rempli à la cuisine ou à un **point d'eau**),
    **mijoté / four** (seulement au foyer de la cuisine, eau à volonté). **Feu de camp** : bois allumé à une torche
    (brandon) ou amadou + silex ; 3 plats ou 10 minutes, puis le bois est consumé. Valeurs cachées des ingrédients
    (`donnees/cuisine.json`) ; recette = somme × multiplicateur, sinon **mixture** (½) ou **plat immonde** (¼). Recettes
    connues au départ : viande grillée, brochette, viande bouillie, compote ; les autres s'apprennent en les réussissant
    ou par une **page de livre de cuisine** (plus tard : les prisonniers). Une recette bouillie avec viande laisse un
    **bouillon** (se boit, ou s'ajoute à un plat sans remplacer l'eau). Liste complète des 14 949 mélanges :
    `python outils/cuisine_combinaisons.py` → `outils/cuisine/combinaisons.csv` ;
  - **Maux persistants** (`Maux`, règle de l'utilisateur, servira aussi à la maladie) : **intoxication alimentaire**
    (viande périmée 1 fois sur 2, viande crue 1 fois sur 4) : régénération des PV coupée, −4 PV par minute en tics de
    15 s pendant 8 minutes ; une 2ᵉ ajoute sa durée ; **peut tuer** ; compte en exploration et en combat, pas dans
    les menus. Affichée en rouge sous le bandeau du haut. Pas encore de remède (établi d'alchimie à venir) ;
  - **Butin posé à la main** (2026-11-03) : onglet « Butin » de l'éditeur de zones (voir plus bas). Le butin est sur
    le sol de chaque salle qui utilise l'image (or en tas, potion en fiole, le reste en sac ; images provisoires de
    `outils/dessiner_butin.py`), ne bloque pas le passage, se ramasse avec **E** (« Ramasser (E) ») une fois par salle
    du plan, puis disparaît (`Fouille.ramasser`). Or au hasard = comme un squelette (10-30 × étage) ; or fixé = le
    montant exact (sans le karma) ; potion du niveau de l'étage ; arme / équipement du rang choisi ou de l'étage ;
  - **choix moraux** (`Rencontres`) : gobelin blessé (le soigner avec une potion : clé ou grimoire ; l'épargner : un
    secret vrai ; l'achever : son corps reste, à fouiller et à siphonner), prisonnier (briser ses chaînes : bruyant, les ennemis de la
    salle accourent, il donne une clé ; lui demander ce qu'il sait : il dit vrai), autel de sang (offrir des PV contre
    +1 dans une caractéristique). Clémence (+1) et cruauté (−1) changent le **karma** (`donjon.moralite` les compte) ;
  - **Karma** (règles de l'utilisateur, 2026-10-31 ; `Karma`, gardé dans le héros, affiché dans le bandeau et l'écran
    des caractéristiques) : épargner des pacifiques, soigner ou épargner le gobelin blessé, libérer le prisonnier
    donnent +1 ; tuer des pacifiques ou achever le gobelin blessé −1. **Négatif**, par point : diablotins +5 % de
    mensonges, prix des marchands +5 %, **Chevalier de la mort +5 % de vitesse de déplacement** (dans la salle comme
    d'une salle à l'autre ; règle de l'utilisateur du 2026-11-03 : `Karma.facteur_vitesse_chevalier`, « facteur_vitesse »
    de la présence ; à −10, il va 50 % plus vite). Avant le 2026-11-03 : un Chevalier de la mort de plus tous les
    5 points ; ceux d'une ancienne partie repartent. **Positif**, par point : diablotins +5 % de vérité,
    prix −5 % (jamais sous 25 %, choix de Claude), **or gagné +5 % de toutes les sources** (fouilles, cachettes,
    coffres, pacifiques). **Le marchand vend plus ou moins cher, mais rachète toujours au même prix** (décision de
    l'utilisateur). Tout est réglé par trois tables de `Karma`, faites pour être nuancées facilement (l'utilisateur
    ajoutera des quêtes spéciales au karma négatif) : `ACTES` (ce que vaut chaque acte), `EFFETS` (effet d'un point,
    séparément en négatif et en positif), `PALIER` / `PALIERS` (ce qui arrive aux paliers ; `Karma.palier` sert de
    point d'entrée aux futurs systèmes). Habitants plus froids ou plus chaleureux selon le karma (accueil des
    diablotins). **Pas encore fait** : les quêtes (plus ou moins nombreuses, meilleures récompenses tous les +5),
    faute de système de quêtes ;
  - **Corps et âmes** (règles de l'utilisateur, 2026-10-31) : un ennemi vaincu (groupe, porteur, boss) laisse son
    **corps** dans la salle (`Aventure.laisser_cadavre`, enregistré avec la salle) : la dernière image de son
    animation de mort, ou, pour une sorte sans animation de mort (squelette, loup...), son image de base couchée sur
    le dos. Le gobelin blessé est dessiné en train de s'effondrer (milieu de son animation de mort) ; achevé, son
    animation va jusqu'au bout et son corps reste. Touche E : le **fouiller** (une
    fois : comme un squelette, 50 % rien, 35 % or, 15 % équipement ; corps d'un pacifique : 2 à 6 or × étage, 10 %
    potion, 2 % équipement) ou **siphonner son âme** (il disparaît alors). **1 âme par ennemi, 3 pour une élite, 5
    pour le boss de l'étage** ; **3 âmes = 1 point de caractéristique** à répartir dans l'écran
    des caractéristiques (triangles rouges, touche C). Pacifiques épargnés : 5 à 15 or × étage, 20 % une potion, 5 %
    un équipement (valeurs validées par l'utilisateur) ;
  - **succube** (`Rencontres.succube`, un étage sur deux : étages 1, 3, 5…) : pas de combat, elle propose un
    **pacte** contre une part des **PV max, perdus pour toujours** (`Aventure.PACTES`, `sceller_pacte`), puis
    disparaît (on peut refuser et revenir). Petits pactes (25 % des PV max) : **Voile** (jusqu'à la fin de
    l'étage, les ennemis voient 2 fois moins loin et le héros reste caché dans l'ombre en marchant, pas en
    courant), **Carte de chair** (tout l'étage sur la carte, avec cachettes, geôliers et Chevalier de la mort, jusqu'à la
    fin de l'étage), **Baiser du geôlier** (la prochaine capture échoue, le geôlier part dans une autre salle).
    Grands pactes (50 %) : **Apaisement** (un Chevalier de la mort de l'étage disparaît), **Pacte de mort** (la prochaine
    mort est annulée : réveil au cachot avec 1 PV, sans rien perdre). Un pacte déjà actif ne se reprend pas ;
    refusé s'il ne laisse pas au moins 1 PV max ;
  - **pupitre** (bibliothèque, un étage sur deux : un **grimoire**), **râtelier
    d'armes** (une arme), **cachettes secrètes** invisibles (une lueur quand on passe tout près, « Examiner (E) » :
    clé, grimoire, objet d'un rang de plus, ou or) ;
  - **salles verrouillées** : une partie des salles bonus (coffre, choix de bonus) ; il faut une **clé** (cachettes,
    prisonnier, gobelin soigné) ; leur coffre a un rang de plus et 50 % d'or en plus. Cadenas sur la carte.
  - **Salle du boss fermée** (décision de l'utilisateur, 2026-11-01) : elle ne s'ouvre qu'avec la **clé du boss** de
    l'étage, unique, portée par une **élite** loin du départ (au moins `Aventure.DISTANCE_CLE_BOSS` = 8 salles) : il
    faut la vaincre puis fouiller son corps (siphonner son âme fait aussi tomber la clé). Les clés rouillées n'y font
    rien. Les **diablotins** peuvent dire où rôde l'élite qui la porte (vrai : elle touche un ennemi). La clé du boss
    s'affiche dans la catégorie « Divers » de l'inventaire ;
  - **Boss loin du départ** (décision de l'utilisateur, 2026-11-01) : **35 salles à l'étage 1 à 40 au dernier**, par
    le plus court chemin (`GenerateurEtage.DISTANCE_BOSS`, `distance_boss`) ; aucune boucle ni entrée de bloc ne
    peut raccourcir ce chemin (`_raccourcit`) ;
  - **Ennemis isolés** (décision de l'utilisateur, 2026-11-01 : plus d'ennemis, pas plus de groupes) : dans une salle
    ordinaire sans groupe, un ennemi rôde seul une fois sur six (`Aventure.CHANCE_ISOLE` ; jamais élite, pacifique
    ni loup). Mesure : ≈ 9 ennemis isolés et ≈ 30 ennemis hostiles par étage (≈ 19 avant) ;
  - **Sorts et équipement viennent de l'exploration** : le joueur ne choisit un sort **qu'au tout début** de la
    partie ; ensuite, chaque **grimoire** (pupitre, cachettes, gobelin soigné) lui apprend un **sort tiré au hasard**
    (palier 0 jusqu'à l'étage, 5 au plus, sans prérequis ; `Aventure.lire_livre`) ; s'il connaît déjà tout, le
    grimoire ne lui apprend rien (il n'est plus « déjà amélioré » depuis le 2026-11-03 : amélioration supprimée) ;
    équipement des coffres, du râtelier, des cachettes, des élites et des squelettes. Les **compétences** (attaques
    d'arme) ne s'apprennent pas encore ainsi : à décider.
  - **Touche E** : parler, lire, fouiller le râtelier, examiner, ouvrir (la présence à portée passe avant le
    squelette).

  **Valeurs choisies par Claude, à valider** (`scripts/logique/aventure.gd`, `presences_salle.gd`, `rencontres.gd`) :

  | Réglage | Valeur |
  |---|---|
  | Groupes par salle ordinaire | 0 : 80 %, 1 : 20 % (« très peu », décision de l'utilisateur du 2026-10-30 ; 35/50/15 avant) ; 2 ennemis au plus par groupe, loup compris (`Aventure.MAX_PAR_GROUPE`) ; ≈ 8 groupes par étage de 50 salles, ≈ 13 depuis les étages de 80 |
  | Élite / pacifique | 12 % / 15 % des groupes |
  | Chevalier de la mort par étage | 1 de base, + 1 par palier de 5 points de karma négatif |
  | Chevaliers / geôliers / diablotins / choix moraux par étage | 1 (+ karma) / 2 / 7 (utilisateur) / 2 |
  | Pupitre, râtelier | pupitre un étage sur deux (50 %), râtelier 1 par étage |
  | Cachettes | 2 à 3 par étage, au moins une clé par salle verrouillée ; le reste : or 45, objet 40, grimoire 15 (poids) |
  | Grimoire | sort de palier 0 à l'étage (5 au plus) ; gobelin soigné : grimoire 25 %, clé 75 % |
  | Salles bonus verrouillées | la moitié (au moins une) des coffres et choix de bonus |
  | Fuite | 45 % + 3 % par point de dextérité − 10 % par ennemi au-delà du premier, entre 15 et 90 % ; boss 15 % |
  | Confiscation | 50 % coffre, 25 % perdu, 25 % porteur (3 objets par porteur) |
  | Vitesse des rôdeurs (× la course du héros, qui marche à 0,45) | ronde 0,22 ; poursuite : gobelins 0,58, porteur 0,5, Chevalier de la mort 0,36, geôlier 0,64, boss 0,48 (ralenties de 20 % le 2026-10-26) |
  | Vue (hauteurs du héros), cône | gobelins 2,4, Chevalier de la mort 3, geôlier 2,8, boss 1,6 ; 120° |
  | Ouïe | course 1,8 ; marche 0,7 ; caché (s'il bouge) 0,45 |
  | Perte de vue avant la recherche | 2,5 s (Chevalier de la mort 5 s, geôlier 3,5 s) ; recherche 4 s |
  | Suivre dans la salle suivante | gobelins 50 %, porteur 40 %, Chevalier de la mort 100 %, geôlier 80 % |
  | Faiblesse / force du boss | résistance −50 / +60 dans deux types tirés pour l'étage |
  | Diablotin | ment sur le donjon 1 réponse « Cet étage ? » sur 3 (utilisateur), jamais sur les ennemis ; jamais deux fois la même chose dans la partie ; 2 réponses puis disparaît (choix de Claude) ; rit quand le héros approche à 1,5 hauteur de héros, puis toutes les 8 à 16 s (choix de Claude) |
  | Chevalier de la mort (fiche de l'utilisateur) | 300 PV ; coups subis ramenés à 1-2 (3 en critique) ; **13d2 tranchant + 15 % des PV max de la cible** (2026-11-01 ; 12d2 tranchant + 6d2 ombre avant) ; chaque coup qui touche retire **6d2 + 15 % du mana max** de la cible, et **la moitié du mana retiré** (arrondie en dessous) inflige autant de dégâts d'ombre ; dés (dés fixes, pas réduits d'un cran ; l'armure et les résistances du héros s'appliquent) ; traque sur 2 salles ; vitesse 0,36 (choix de Claude : « plus lent que la marche ») ; part du milieu de l'étage, erre de salle en salle (≈ 9 s par salle, choix de Claude), attiré par les combats, téléporté à 3 salles par une action bruyante (utilisateur) |
  | Autel | 40 % des PV max contre +1 dans une caractéristique au hasard |
  | Succube (décidé par l'utilisateur) | taille 1,3 hauteur de héros ; un étage sur deux ; Voile, Carte de chair, Baiser du geôlier : 25 % des PV max ; Apaisement, Pacte de mort : 50 % (arrondi au-dessus, pour toujours) ; étages impairs (choix de Claude) |

- **Exploration dans des salles peintes où l'on marche** (au lieu d'une image fixe et de flèches) :
  les salles du banc d'essai `C:\ia image\Salle de donjon\test_salle` (salle 1, salle 2, salles
  porte 1 à 6), avec leur moteur (sol, obstacles, perspective, premier plan, décor animé — la vidéo de la salle en pleine résolution depuis le 2026-10-19 (le son a été retiré le 2026-10-18), héros
  qui marche, court et respire en 8 directions) et leur chargement rapide.
  - **Salles orientées comme la mini-carte** (`PlanSalles.attribuer`, une fois par étage, enregistrée
    dans chaque salle du plan sous `"salle_peinte"`). Orientation **fixe** depuis le 2026-10-18 : le haut
    de l'image est toujours le haut de la mini-carte. Aller vers le fond de l'image = monter sur la
    carte ; reculer (bas de l'image) = descendre ; la porte de gauche = la salle de gauche ; la porte de
    droite = la salle de droite. Une image peut être affichée **en miroir** (gauche et droite échangées :
    image, sol, obstacles, premier plan, sorties ; aussi en combat). Pour chaque salle du plan, toutes
    les images × miroir sont essayées, et l'on garde celle dont **chaque porte mène à la salle qui est
    dans sa direction sur la carte**. Critères dans l'ordre : aucun passage sans porte, le moins de
    portes visibles sans salle derrière, puis la salle 1 pour le départ et la salle 2 pour le boss
    (tirage stable ensuite, miroir compris).
    **Chaque apparence une seule fois par étage** (2026-10-30, demande de l'utilisateur) : les 98 apparences
    (49 images × miroir) sont réparties sur tout l'étage d'un coup (affectation au meilleur total, méthode
    hongroise `PlanSalles._affectation`), sans perte de qualité mesurable (`test_cartographie_salles`).
    **Prisons et niveau des cryptes (2026-11-03)** : remplacent le quartier des prisons et le quartier des cryptes
    décrits ci-dessous (voir la section « Prisons et niveau des cryptes »).
    **Sorties potentielles (2026-11-03)** : voir « Éditeur de zones » (touche O) ; une seule des sorties potentielles
    d'un côté est ouverte s'il faut une salle de ce côté, les autres deviennent des murs invisibles, sans malus.
    *Ancien* **quartier des prisons** (2026-10-30) : les images « prison » ne vont que dans le quart de l'étage le plus loin
    du boss par le chemin (`PlanSalles.quartier_prisons`, `PART_QUARTIER_PRISONS` = 0,25 ; bonus 25 dans le
    quartier, malus 60 ailleurs) ; le cachot est pris parmi elles.
    *Ancien* **quartier des cryptes** (2026-11-02, demande de l'utilisateur) : les 14 images « crypte » servent **toutes, une
    fois chacune, sans miroir** (choix de l'utilisateur), sur chaque étage, dans **un seul groupe de salles reliées
    entre elles** (`PlanSalles.quartier_cryptes` : 14 salles, hors départ, boss, blocs et quartier des prisons ; le groupe
    prend surtout des salles qui ont une voisine à gauche ou à droite, car les cryptes ont des sorties de côté et ces
    images manquent ailleurs ; un des 4 meilleurs groupes). Aucune crypte ailleurs. Une nouvelle image `crypteN`
    agrandit le quartier d'elle-même. Vaut pour les nouvelles parties (les étages déjà créés gardent leurs images).
    **Conséquence mesurée** (100 étages) : il manque d'images à sorties de côté ailleurs, d'où **~3,6 passages sans
    porte peinte par étage** (flèche de secours ; 0 avant) et ~1,4 prison hors de son quartier par étage. Avec les
    miroirs (quartier de 28 salles), tout était parfait ; l'utilisateur a préféré 14 salles. De nouvelles images avec
    des portes à gauche et à droite résoudront le manque. Forcer les prisons dans leur quartier (pénalité 2000) coûte
    1,3 passage sans porte de plus par étage : pénalité laissée à 60.
    **Le bas de l'image peut toujours être fermé** : il est hors de l'image (derrière le spectateur).
    Sans salle en dessous, la sortie du bas devient un mur invisible (`SallePeinte.murer`) : le héros
    s'arrête, sans message. Une porte **visible** sans salle derrière est condamnée (message, le héros
    recule).
    Sorties de chaque image (dans l'ordre du .json) : salle 1, salle 2 et porte 1 (devant, bas) ; porte 2
    (devant, bas, gauche, gauche) ; porte 3 (droite, devant, bas, gauche) ; porte 4 (devant, bas,
    devant) ; porte 5 (devant, gauche, bas) ; porte 6 (devant, gauche, bas, gauche) ; cul-de-sac 1 à 7
    (bas) ; et leurs miroirs. **Deux portes du même côté** (porte 2, porte 4, porte 6) mènent à la même
    salle voisine. **Arrivée quand deux ouvertures mènent à la même salle** (2026-10-20,
    `PlanSalles.sortie_vers`) : devant celle par laquelle le héros était sorti vers cette salle
    (`"sortie_prise"` de la salle du plan, enregistrée), sinon une vraie porte plutôt qu'un passage
    (`types_sorties` du .json, tiré de l'inventaire `portes.json` par `importer_salles.py` : salle porte 6,
    porte de gauche plutôt que passage de gauche). Point d'arrivée devant une porte : `arrivee_porte` (première sortie) ou
    `arrivees[nom de la sortie]` du .json (retournés en miroir), sinon un point libre devant la sortie.
  - **Objets à fouiller** (2026-10-20, idée 1 de `IDEES_GAMEPLAY.md`, règles validées par l'utilisateur) :
    des **squelettes** (4 variantes d'image, `images/objets_salles/`, détourés par
    `outils/importer_objets.py` depuis `C:\ia image\asset pour salle`). Les coffres et les étagères ont été
    retirés le même jour à la demande de l'utilisateur (ils juraient avec le décor) ; ceux d'une ancienne
    sauvegarde disparaissent à l'entrée dans la salle. Chaque image de salle a des emplacements prévus
    (`donnees/objets_salles.json`, clé « emplacements » : sol contre un mur ou un pilier ; 30 au total). À sa
    première visite, chaque salle du plan tire **0 à 2 squelettes** (30 / 45 / 25 %, valeurs choisies par
    Claude) parmi ses emplacements (`Fouille.objets_salle`, enregistré dans la salle : clés « objets » et
    « objets_image »). Taille selon la perspective (`SallePeinte.TAILLES` : 0,5 × la hauteur du héros), triés
    avec le héros, ombre au sol, emprise qui arrête le héros, teinte assombrie, retournés au hasard, miroir géré.
    **Fouiller** : à portée d'un squelette (`PORTEE_FOUILLE` = 0,55 hauteur du héros), « Fouiller (E) »
    s'affiche au-dessus ; touche **E** (bouton X de la manette). Une seule fois (il s'assombrit ensuite).
    Résultats (`Fouille.RESULTATS`) : 50 % rien, 35 % or (10 à 30 × l'étage, montant choisi par Claude),
    15 % équipement qu'il portait (rang = l'étage, 6 au plus). Compteur « Objets fouillés » dans le bilan.
  - **Portes qui s'ouvrent** (2026-10-20) : 8 portes ont leur animation d'ouverture (salle porte 1 :
    grande porte ; porte 2 : porte du fond, porte de gauche ; porte 3 : couloir du fond ; porte 4 : porte
    du mur ; porte 5 : grande porte, porte de gauche). Une porte fermée s'ouvre **seulement quand le
    joueur marche vers elle pour la franchir** (`SallePeinte._pousser_porte` : en marchant vers la porte,
    la zone de sa sortie est à moins de `PORTEE_POUSSEE` = 0,15 hauteur du héros devant ses pieds) : rester
    près d'elle, passer à côté ou arriver par une porte voisine ne l'ouvre pas. Ses battants s'ouvrent (97 images posées sur la vidéo de la salle, `VITESSE_PORTES` = × 1,5 → 2,7 s) ;
    tant qu'elle n'est pas ouverte, sa sortie l'arrête comme un mur. La porte par laquelle on arrive est
    déjà ouverte ; les portes ouvertes le restent (retenues dans `"portes_ouvertes"` de la salle du
    plan, donc enregistrées). Une porte condamnée ne s'ouvre pas (message « Cette porte est
    condamnée. », comme avant). Images chargées en arrière-plan à l'entrée dans la salle, libérées une
    fois la porte ouverte (seule la dernière reste affichée). Données : `portes_animees` du .json
    (cadre en pixels de l'image fixe, sortie, images), écrites par `outils/importer_salles.py`
    (`PORTES_ANIMEES`) depuis `C:\ia image\Salle de donjon\salle porte N\portes_animees\`. Les
    autres portes (salle porte 6, porte de droite de la salle porte 3...) n'ont pas encore
    d'animation : elles restent sans ouverture.
  - **Répertoire des salles par direction de la carte** (contrôle : `tests/test_cartographie_salles.gd`,
    12 donjons × 5 étages, environ 3 050 salles depuis les grands étages du 2026-10-27 ; aussi dans `C:\ia image\Salle de donjon\portes\portes.json`,
    clé `directions_carte`). Le test vérifie aussi que chaque porte mène à la salle qui est dans sa
    direction sur la carte (0 erreur).

    | Passages sur la carte | Part des salles | Images exactes (haut de l'image = haut de la carte) |
    |---|---|---|
    | haut | 4 % | salle 1, salle 2, porte 1, porte 4 (bas fermé), et miroirs |
    | bas | 4 % | cul-de-sac 1 à 7, et miroirs |
    | haut + bas | 14 % | salle 1, salle 2, porte 1, porte 4, et miroirs |
    | haut + gauche | 7 % | porte 2, porte 5, porte 6 (bas fermé) |
    | haut + droite | 7 % | miroirs de porte 2, porte 5, porte 6 (bas fermé) |
    | haut + gauche + bas | 4 % | **grandes salles 1 à 10** (passage de droite muré), et miroirs |
    | haut + droite + bas | 4 % | **grandes salles** (passage de gauche muré), et miroirs |
    | haut + gauche + droite | 5 % | **grandes salles** (bas fermé), et miroirs |
    | haut + gauche + droite + bas | 9 % | **grandes salles**, et miroirs |
    | gauche, droite, gauche + bas, droite + bas | 23 % | **aucune** (virages à venir) : porte 2, 5 ou 6, porte du fond condamnée |
    | gauche + droite | 15 % | **aucune** : porte 3, porte du fond condamnée |
    | gauche + droite + bas | 4 % | **aucune** : grande salle, sortie du fond condamnée |

    (Parts mesurées sur les grands étages du 2026-10-27. Avant, les carrefours prenaient porte 2, 5, 6 ou 3.)

    Images à générer pour que tout soit exact : **virage** (porte sur un côté, pas de porte au fond ; le
    miroir donne l'autre côté ; avec ou sans retour par le bas, c'est la même image) ; **salle à deux
    portes de côté** (une porte à gauche, une à droite, pas de porte au fond).
    **Une porte ne compte que si on la voit bien** : la porte de gauche de la salle porte 1, cachée dans
    l'ombre derrière le pilier, n'est pas une sortie du jeu (`SORTIES_CACHEES` de
    `outils/importer_salles.py`). Le test de cartographie ne voit que les sorties, pas l'image :
    `tests/voir_directions.gd` capture une salle par combinaison avec la mini-carte (captures 58) et
    fait de vrais passages vers le haut, le bas, la gauche et la droite.
    Si aucune image n'avait assez de portes, le passage restant garderait une **flèche** cliquable
    (n'arrive pas : la salle porte 3 a des portes des 4 côtés).
  - **Grandes salles = carrefours** (2026-10-27, images de l'utilisateur `C:\ia image\Salle de donjon\grande
    salle`, décisions de l'utilisateur : carrefours, sorties « arches + bords », image agrandie par IA). 10 grands
    halls (`grande1` à `grande10`, triés par nom de fichier) à 4 sorties : **au fond** (arche, escalier, couloir ou
    porte de l'image), **passage de gauche** et **passage de droite** (bords du sol, type « bord » : sans salle
    derrière, ils deviennent un mur invisible sans message, comme le bas de l'image ; pas de malus au choix de
    l'image), **retour** (bas). `PlanSalles` les réserve aux salles à 3 ou 4 passages (`BONUS_CARREFOUR` = 20 ;
    `PENALITE_GRANDE_HORS_CARREFOUR` = 40 ailleurs) : tout carrefour reçoit une grande salle, miroir compris.
    Zones (sol, obstacles, piliers, sorties, perspective) relevées à la main par Claude sur une grille, dans
    `ZONES` de `outils/importer_grandes_salles.py` (planche de contrôle `C:\IA\pont-blender\grandes_salles\planche_zones.png`).
    Image fixe, sans vidéo ni portes animées ; ce qu'on voit est `fond_hd.png` (Swin2SR × 4 puis 1152 × 768 ;
    clé `fond_hd` du .json, lue par `SallePeinte.charger`) ; les zones restent en pixels du fond 768 × 512. Pas
    encore d'emplacements d'objets à fouiller (squelettes) dans ces salles. Nouvelle grande salle : déposer l'image
    dans le dossier, ajouter son entrée à `ZONES`, `python outils/importer_grandes_salles.py`.
  - **Sol détouré automatiquement** (2026-10-27, demande de l'utilisateur : les zones tracées à la main ne
    correspondaient pas à l'image, on ne comprenait pas où l'on pouvait aller). `outils/detourer_sols.py` calcule
    pour chaque salle (les 25) la zone de marche et les obstacles : profondeur de l'image (Depth Anything V2), surface
    du sol ajustée sur le bas de l'image (un sol plat suit une loi simple en profondeur ; tout ce qui se dresse de
    plus de 5 pixels au-dessus n'est pas du sol), puis découpage de l'image en morceaux par SAM (dalles, tapis,
    piliers, marches) : chaque morceau est du sol si la majorité de ses pixels suit le sol. Trous dans le sol bouchés
    sauf s'ils se dressent vraiment (bases de piliers, braseros) ; chaque sortie est reliée au sol (passage tracé si
    besoin, par exemple l'escalier de la salle 2). Résultat dans `outils/detourage/<id>.json`, appliqué aux
    `donnees/salles_peintes/<id>.json` et relu par `importer_salles.py` et `importer_grandes_salles.py` (une
    réimportation ne l'écrase pas). Anciennes zones gardées dans `outils/detourage/ancien/`. Contrôle :
    `C:\IA\pont-blender\detourage_salles\planche.png` et `controle\<id>.png` (sol vert, obstacles rouges,
    sorties jaunes). Réglages par salle (`REGLAGES`) si une salle pose problème. Les points d'arrivée relevés à la
    main qui tombent à côté du nouveau sol sont ramenés au point de sol le plus proche (`SallePeinte.sur_le_sol`) ;
    13 emplacements de squelettes ont été ramenés sur le sol dans `donnees/objets_salles.json`.
  - **Éditeur de zones** (2026-10-27, pour que l'utilisateur trace lui-même les zones) : `editeur_zones.bat`
    → `scenes/outils/editeur_zones.tscn` (script `scripts/outils/editeur_zones.gd`), dans le moteur du jeu (même
    salle, même héros, mêmes collisions). Couches : **1** sol où l'on marche (vert), **2** obstacles (rouge),
    **3** premier plan qui passe devant le héros (bleu), **4** sorties (jaune), **5 prisonniers** (violet,
    2026-11-01 : **zones de dialogue** — le héros qui entre dans une zone peut parler au prisonnier peint dans
    l'image ; clé « prisonniers » du .json de la salle), **6 cachettes** (turquoise, 2026-11-01 : zones où le héros
    n'est ni vu ni entendu ; clé « cachettes »). **Sorties** (2026-11-01) : glisser l'intérieur les déplace
    d'un bloc, clic droit dedans les supprime, tracer une forme en crée une (direction devinée d'après sa place),
    **D** sur une sortie change sa direction ; chacune est étiquetée (« 1 : fond »...). **O** sur une sortie la rend
    **potentielle** (orange, « (potentielle) ») ou ordinaire (2026-11-03, demande de l'utilisateur) : on peut tracer
    plusieurs sorties possibles à gauche, à droite ou au fond ; à la génération de l'étage, **une seule** d'un même côté
    est ouverte s'il faut une salle de ce côté (tirage stable), les autres et toutes s'il n'en faut pas deviennent des
    murs invisibles, sans malus (`PlanSalles._evaluer`, clé « sorties_potentielles » du .json) ; une sortie ordinaire
    du même côté passe avant. Une même image sert ainsi à bien plus de formes de salles. Un point d'arrivée resté à
    plus de 120 px d'une sortie déplacée n'est plus utilisé : le héros arrive devant la sortie
    (`SallePeinte.ECART_ARRIVEE_MAX`, 2026-11-03 ; ≈ 40 arrivées de cryptes, grandes salles et prisons étaient restées
    à l'ancienne place). **Changer de salle sans
    quitter** : boutons ◀ ▶ et liste en haut à droite (la salle quittée est enregistrée si elle a été modifiée).
    Une salle dont le nombre de sorties change est réattribuée dans les parties en cours (`PlanSalles.attribuer`).
    | Commande | Effet |
    |---|---|
    | Tab | passer de l'édition à la marche (essayer la salle avec le héros, sorties murées) |
    | 1 à 4 | choisir la couche |
    | 5 | couche des prisonniers (zones de dialogue, tracées comme le sol) |
    | 6 | couche des cachettes (zones où le héros est invisible) |
    | 8 ou onglet « Feux » | **onglet Feux** (2026-11-03) : des **zones** tracées au sol près des torches, comme les autres zones (clic : point ; Entrée ou 1er point : fermer ; glisser un point ou l'intérieur ; Maj+clic sur un bord : nouveau point ; clic droit : retirer). Dans le jeu, le héros dans une zone voit « Torche : allumer du bois (K) » (pas de cuisson à la torche). Clé « feux » du .json (polygones ; un ancien point devient une petite zone) |
    | 9 ou onglet « Eau » | **onglet Eau** (2026-11-04) : des **zones** tracées au sol au bord des points d'eau (puits, fontaine, bassin), mêmes gestes que l'onglet Feux. Dans le jeu, le héros dans une zone voit « Point d'eau : remplir le seau (K) » (« Point d'eau » sans seau). Clé « eaux » du .json (polygones ; un ancien point devient une petite zone) |
    | 7 ou onglet « Butin » | **onglet Butin** (2026-11-03) : clic = poser un butin, clic dessus = le choisir, glisser = le déplacer, clic droit = le retirer ; le **module** à droite règle le butin choisi (et les suivants) : type (or, potion, arme, équipement, objet divers, nourriture, ingrédient), objet précis du catalogue ou au hasard, sorte de potion, armure ou bijou, montant d'or (0 = au hasard), nombre, rang (0 = selon l'étage). Clé « butins » du .json |
    | D | sur une sortie : changer sa direction (fond, gauche, droite, retour) |
    | ◀ ▶, liste, Page préc./suiv. | changer de salle (la salle quittée est enregistrée si elle a été modifiée) |
    | R | en marchant : héros remis au départ (un héros posé hors du sol est aussi remis sur le sol) |
    | F1 | replier / afficher l'aide |
    | clic gauche | ajouter un point ; Entrée ou clic sur le premier point : fermer la zone ; Échap : abandonner |
    | glisser un point | le déplacer |
    | Maj + clic sur un bord | ajouter un point sur ce bord (et le glisser) |
    | clic droit | retirer le dernier point tracé, sinon le point visé, sinon la zone sous la souris |
    | molette / clic du milieu / 0 | zoom sur la souris / déplacer la vue / vue entière |
    | H | montrer ou cacher le héros pendant l'édition (caché par défaut, il revient en marchant) |
    | P | poser le héros sous la souris (et le montrer) |
    | Ctrl+Z / Ctrl+S | annuler (100 pas) / enregistrer |
    | Page préc. / Page suiv. | salle précédente / suivante (deux appuis si rien n'est enregistré) |
    | F2 | zones visibles ou non en marchant |
    | F3 ou bouton « Dialogues » | **menu Dialogues** (2026-11-04) : à gauche les personnages (ceux de `donnees/dialogues.json` et, de `donnees/prisonniers.json`, les prisonniers ordinaires, chaque quête et les objets des quêtes), au milieu leurs textes, à droite le texte choisi, modifiable. Dans une liste (bulles d'un commis, répliques d'une étape, lore...) : « Ajouter une ligne » / « Supprimer la ligne ». Les mots entre accolades ({direction}, {pv}...) sont remplacés dans le jeu. Ctrl+S ou « Enregistrer » ; « Fermer » (Échap) enregistre aussi |
    Sorties : on peut seulement déplacer ou ajouter des points (leur nombre et leur ordre servent au plan du
    donjon). Salles avec un masque de premier plan au pixel (portes, salles, culs-de-sac) : la couche bleue ne
    change pas l'affichage, seulement la vue des ennemis (un message le rappelle). **Ctrl+S** écrit
    `donnees/salles_peintes/<id>.json` (les autres données de la salle sont gardées telles quelles) et
    `outils/zones_manuelles/<id>.json` : ce second fichier passe devant le détourage automatique et la maquette 3D
    (`detourer_sols.detourage`, `detourer_sols.appliquer`, `carte3d.appliquer`), donc une réimportation ou un
    nouveau détourage n'écrase plus les zones retouchées à la main.
  - **Zones en ligne de commande** (2026-10-27, pour confier les retouches à Grok Bot) : `outils/zones.py`
    (`voir` : image des zones numérotées + quadrillage chiffré dans `C:\IA\pont-blender\zones\`, zoom possible ;
    `lister`, `ajouter`, `remplacer`, `deplacer`, `retirer`, `couche`, `annuler`, `verifier` = test des collisions
    de la salle). Mêmes fichiers que l'éditeur (données du jeu + `outils/zones_manuelles/`), historique pour
    annuler dans `outils/zones_manuelles/historique/`. Garde-fous : pas de création ni de retrait de sortie, au
    moins 3 points, points dans l'image. Notice à donner à l'assistant : `GROK_ZONES.md`. Ne pas laisser l'éditeur
    ouvert pendant ce temps (un Ctrl+S y réécrirait la salle avec son état à lui).
  - **Passage** : marcher dans une sortie → fondu au noir (0,35 s), `donjon.avancer` (combat, coffre,
    piège... comme avant), puis la nouvelle salle, le héros **devant la porte par laquelle il est
    entré** (ou en bas de l'image, de dos, pour une entrée par le bas). **Retour dans une salle déjà quittée**
    (2026-11-02) : le héros réapparaît **là où il avait franchi la sortie** pour en partir (`lieu_sortie`, retenu
    par `menu_navigation._franchir`), juste assez avancé pour ne plus être dans la sortie
    (`SallePeinte.placer_au_retour`).
  - Monter, descendre, charger une partie : on arrive en bas de l'image de la salle.
  - Les images des salles spéciales (coffre, source, bonus, piège, marchand, boss) ne sont plus
    affichées en fond ; les boutons d'action de la salle restent (en bas au centre).
  - **Combat** : le fond est la salle peinte de la salle où il a lieu (la même que dans l'exploration),
    recadrée en 16:9 sur toute la largeur (le haut de l'image est coupé, le sol gardé), animée si son
    décor est déjà prêt. `salle_combat.png` et `image_boss.png` ne servent plus qu'en secours (pas de
    salle peinte attribuée).
  - Sorties « bas » ajoutées par l'import aux salles 1, salle 2 et porte 1 (qui n'en avaient pas).

- **Mini-carte plus petite** (`menu_navigation.gd`, `RECT_CARTE` = 210×165 au lieu de
  300×236). `Carte.dessiner_mini_carte` met l'échelle des salles à la taille de la zone
  (24 px par case et salles de 16 px pour 300 px de large).
- **Boutons de droite seulement quand ils servent** (`menu_navigation.actions_visibles`,
  empilés sous la mini-carte) :
  - **Monter** : uniquement dans la salle du boss (`donjon.est_salle_boss`).
  - **Descendre** : uniquement dans la salle de départ (première salle) d'un étage,
    hors premier étage (`donjon.peut_descendre`, `donjon.est_salle_depart` : clé
    `"depart"` de la salle, ou nom `salle_debut` pour les étages d'anciennes sauvegardes).
    On arrive dans la salle du boss de l'étage inférieur.
  - **Se reposer** : uniquement dans une salle qui contient un lit
    (`donjon.peut_se_reposer` : clé `"lit": true` de la salle). **Aucun lit n'est encore
    placé dans le donjon** : le bouton n'apparaît donc jamais pour l'instant. Pour
    ajouter les lits, il suffira de mettre `"lit": true` sur les salles choisies dans
    `Donjon.generer_etage`.
  - Les fonctions de la logique (`monter_etage`, `descendre_etage`, `se_reposer`)
    appliquent les mêmes conditions et ne font rien sinon.
- **Dégâts aux dés** (refonte du combat, `Formules`) : chaque type de dégâts d'une
  compétence ou d'un sort lance ses dés (`DES_TYPES`), les mêmes pour tous, quel que soit
  le palier du sort :

  | Type | Dés | Caractéristique (+2 par point depuis le 2026-10-29 ; +1 tous les 2 points avant) |
  |---|---|---|
  | tranchant / perforant / contondant | 2d6 / 1d12 / 1d10 + 1d2 | force |
  | feu / froid / foudre (élémentaires) | 2d6 / 3d4 / 1d12 | sagesse |
  | arcane / chaos / ombre (magiques) | 2d6 / 3d4 / 2d6 | intelligence |
  | lumière (soin) | 3d6 | la plus forte des deux |
  | poison | 1d2 | aucune |

  - **Dés propres à chaque compétence** (revue des dégâts de l'utilisateur, 2026-11-01 ; `Formules.DES_HEROS`,
    `DES_ENNEMIS`) : ils remplacent les dés du type ci-dessus, sans malus des coups multiples ni palier plus bas.
    Le dé bonus d'une arme s'ajoute toujours aux attaques de l'arme. Les dés d'un coup multiple sont ceux d'un coup.

    | Héros | Dés | Ennemis | Dés |
    |---|---|---|---|
    | Coup d'épée, Coup de marteau, Coup de lance | 6d2 | Tir à l'arc ; Coup d'épée, Coup de lance (gobelins) ; morsure du loup, épée rouillée du squelette | 4d2 |
    | Frénésie (2 coups) ; Coup de poing (sans étourdissement) | 4d2 | Tir précis, Tir empoisonné, Coup de gourdin, Perforation | 3d2 |
    | Fracasser, Boule de feu, Givre, Trait arcanique, Trait de l'ombre, Estafilade, Bourrade | 8d2 | Boule de feu, Grand coup de gourdin, Projectile de l'ombre, Enflammer, Trait de l'ombre | 5d2 |
    | Balayage (chaque cible) | 3d2 | Rafale de lance (3 coups), Caresse des ombres, Silence, Coup de bâton | 2d2 |
    | Éclair | 6d3 | Soin mineur | 7d2 + 15 % des PV max de la cible (`PV_CIBLE_ENNEMIS`) |
    | Souffle du chaos (chaos + feu) ; Enchaînement (2 coups, sans étourdissement) | 4d2 + 4d2 ; 3d2 | Botte secrète | 3d2 |
    | Dard empoisonné | 6d2 perforant + 2d2 poison | | |
    | Soin | 20d2 | | |

    Coup de poing et Enchaînement : leurs options d'amélioration « étourdissement » sont devenues « trauma »
    (validé par l'utilisateur, pour garder trois choix par niveau). Gobelin combattant : **Cri de guerre** quand il a
    au moins un allié vivant et que personne n'est déjà en rage (validé par l'utilisateur : pas de cri tant que la
    rage dure) ; sinon **Botte secrète une fois sur trois** (validé par l'utilisateur, comme le lancier), Coup d'épée
    le reste du temps.
    **Tempête de feu est retirée** des sorts du héros. Murmure des ombres s'appelle **Trait de l'ombre**.
    Compétences retirées des gobelins : Soin et Soin majeur (chaman), Soin (féticheur), Éclair, Enflammer et
    Blizzard (sorcier). Élites : dégâts × 1,4 ; boss : × 1,6 (× 0,8 avant).
  - **Ennemis : chaque dé un palier plus bas** (2026-10-20, `Formules.PALIERS_DES` : 1d2, 1d4, 1d6,
    1d10, 1d12 ; `des_type`) : 1d12 → 1d10, 1d10 → 1d6, 1d8 → 1d6, 1d6 → 1d4, 1d4 → 1d2 ; 1d2 reste 1d2.
    Un gobelin fait donc 2d4 tranchants, 1d10 perforants, 1d6 + 1d2 contondants, 2d4 de feu, 3d2 de
    froid, 1d10 de foudre ; ses coups multiples 1d4 − 2. Ses soins (lumière, 3d6) ne sont pas réduits.
    Ces trois points (1d2 inchangé, 1d8 → 1d6, soins non réduits) sont validés par l'utilisateur.

  - `Formules.base_degats` : `(dés + caractéristique × 2 arrondi en dessous + dégâts plats
    du lanceur pour ce type, + dégâts physiques pour les types physiques) × pourcentages`
    (physique ou magique, puis celui du type ; poison : seulement le sien). Les
    pourcentages sont les « modificateurs » pour l'instant (à revoir).
  - Plus de dégâts de base (`degats_base`), de puissance magique, de dégâts propres
    des compétences ni de leur multiplicateur (`multiplicateur_degats`,
    `facteurs_types`, `soin_pourcentage_pv` ne sont plus lus par le combat). Les
    **améliorations de compétences ne changeaient donc plus les dégâts** (supprimées le
    2026-11-03, à reforger). Exception : l'ancienne option « +x % de dégâts d'un élément »
    (genre `second`, `pourcentage_types` de la compétence, `Formules.pourcentage_competence`)
    multiplie les dégâts de cet élément, **seulement si la compétence en inflige déjà** ; elle
    n'ajoute plus de type de dégâts (avant le 2026-10-20, un seul point ajoutait les dés
    complets de l'élément et doublait les dégâts).
  - Sorts à plusieurs types (Apocalypse...) : chaque type lance ses dés (à revoir).
  - Les armes ne donnent pas de dés en propre : une lance fait des coups perforants, dont
    les dés sont ceux du type (`DES_ARMES` : type d'arme -> type de dégâts, pour l'affichage
    « Dégâts 1d12 perforants » et le dé bonus). Depuis le 2026-10-30, une arme a une seule famille : normale
    (physique), magique ou élémentaire — voir « Objets ».
  - **Dé bonus des armes** (rare) : `GenerationObjets.CHANCES_DE_BONUS` (6 % au rang 1 à
    12 % au rang 6) ; 1d2, 1d4, 1d6, 1d8, 1d10, 1d12 du rang 1 au rang 6
    (`FACES_DE_BONUS`). Depuis le 2026-10-30 : arme physique → dé de son propre type (ajouté aux dés des
    coups de ce type, `des_type`) ; magique → arcane, ombre ou chaos ; élémentaire → feu, froid ou foudre (sur tout
    coup qui fait le type de l'arme, un coup de plus de cet élément, `de_bonus_autre_type`). Attribut
    `de_bonus` = `{"faces", "type"}`.
    **Seules les attaques de l'arme en profitent** (`Formules.ATTAQUES_ARMES`,
    `est_attaque_arme`) : Coup d'épée et Frénésie (épée), Coup de lance et Balayage (lance),
    Coup de marteau et Fracasser (marteau). Les sorts et les autres compétences gardent leurs
    propres dés, même s'ils font le type de l'arme (Marteau de givre avec un marteau).
  - **Brûlure** : 1d2 de feu par tour et par cumul (`Alterations._dot_brulure`). Les
    autres effets sur la durée (poison, saignement, gel...) n'ont pas encore été revus.
- **Défense** (règles de l'utilisateur, 2026-10-30 ; `Degats`). Trois grands types de dégâts : **physique**
  (tranchant, perforant, contondant), **magique** (arcane, ombre, chaos), **élémentaire** (feu, froid, foudre).
  Deux mécanismes distincts :
  1. **Pourcentages, d'abord** : vulnérabilités (`vulnerabilite_<type ou groupe>`, 0,40 = +40 % de dégâts reçus)
     et résistances en pourcentage (`resistance_pct_<type ou groupe>`, 75 % au plus). Elles s'additionnent
     (`Degats.multiplicateur` = 1 + vulnérabilités − résistances %) et ne touchent pas l'armure. Exemples :
     Protection −40 % physiques, Électrocution +20 % foudre, faiblesse du loup au feu +40 %.
  2. **Blocage en points, ensuite** : **2 points = 1 dégât bloqué** par coup. Défense générale (armure contre le
     physique, résistance magique, résistance élémentaire) **ou** résistance spécifique du type
     (`resistance_<type>`) : **pas de cumul**, la meilleure compte (3 d'armure + 1 de résistance tranchant = −1).
     La pénétration (d'armure contre le physique, de résistance sinon) retire ses points aux deux.
  Poison, saignement, brut et lumière ne sont ni bloqués ni modifiés (**résistance au poison supprimée**).
  Validé par l'utilisateur : ordre « pourcentages puis blocage » (« jets de dés + 40 % »), addition des
  pourcentages entre eux, plafond de 75 % gardé pour les résistances en %.
  Altérations passées en pourcentages (mêmes chiffres qu'avant) : Pétrification −20 % physiques, Électrocution
  +20 % foudre, Corruption +10 % à tout, Usure +8 % physiques par cumul, Usure magique +6 % magiques et
  élémentaires par cumul, Inflammabilité / Morsure du givre / Conductivité +25 %, Protection −40 % physiques,
  Barrière −30 % magiques, Bénédiction −10 % magiques. Armure brisée et Résistances brisées (−40 % de la défense
  en points) inchangées. Salles bonus : +4 d'armure, +4 de résistance magique, +4 de pénétration d'armure ou de
  résistance (10, 5, 15 et 20 avant ; proposé par Claude, validé par l'utilisateur).
- **Prisons et niveau des cryptes** (2026-11-03, demande de l'utilisateur) :
  - **4 prisons aux 4 coins de l'étage** (`GenerateurEtage._poser_prisons`) : chacune = **2 grandes salles de prison**
    (les 8 images « prison » du dossier `C:\ia image\Salle de donjon\prison\grande salle`, chacune une fois par étage,
    seulement là) puis un **couloir de prison** (4 images `couloir_prison1` à `4`, importées par
    `outils/importer_couloirs_prison.py`, sol détouré automatiquement, zones à affiner dans l'éditeur). Le couloir est
    au-dessus de la 2e grande salle sur la carte (on y entre par le bas de son image) ; son **fond mène aux cryptes**.
    L'étage pousse vers le haut depuis le départ : ses coins sont souvent loin de toute salle ; si besoin un **chemin
    d'accès** de salles ordinaires (au plus 12, `ACCES_PRISON_MAX`) part de la salle la plus proche et mène la prison
    à 4 cases au plus de son coin (mesuré sur 20 étages). Salles : clés « prison » (coin 0 à 3), « prison_salle »
    (« grande_a », « grande_b », « couloir »), « coin » ; « acces_prison » pour le chemin d'accès. Les 12 salles des
    prisons sont prises sur `TAILLE_ETAGE` (80) ; avec les chemins d'accès, un étage fait 79 à 99 salles (moyenne
    89 sur 30 étages), avec 3,9 boucles en moyenne (4 avant).
    **prison6** (doublon de prison3) et **prison8** (absente du dossier) sont retirées du jeu : leurs .json sont dans
    `donnees/salles_retirees/` (remettre un .json dans `donnees/salles_peintes` pour la remettre en jeu).
  - **Niveau des cryptes** (`Donjon.NIVEAU_CRYPTES` = 101, un **niveau unique** dans son monde à part :
    `Donjon.est_niveau_unique`, numéros au-delà de 100, pas de départ, de boss ni de cachot) : **14 salles** d'un seul
    tenant dans un cadre de 5 × 4 cases (`GenerateurEtage.generer_cryptes`), les 14 images « crypte » une fois chacune ;
    30 plans essayés, on garde celui que les images habillent le mieux (mesuré : aucun passage sans porte peinte).
    **4 entrées**, une par coin, chacune reliée au couloir de la prison du même coin : une sortie de l'entrée (côté
    extérieur, sans salle) ramène au couloir. Ennemis : la zone « crypte » (squelettes, une seule élite : le
    féticheur), en nombre comme au premier étage ; ni chevalier, ni geôlier, ni personnages, ni objets pour l'instant.
    Les ennemis ne suivent pas le héros d'un niveau à l'autre. Les cryptes ne sont plus sur l'étage.
  - **Passage d'un niveau à l'autre** : clé « passage_niveau » de la salle ({niveau, salle, direction}) ; pendant
    l'habillage, il compte comme une salle voisine dans sa direction (une sortie de l'image y mène), puis cette sortie
    est notée « passage » dans « salle_peinte » (`PlanSalles.PASSAGE`). Dans l'exploration, entrer dans cette sortie
    fait changer de niveau (`menu_navigation._changer_de_niveau`) : le héros arrive devant le passage de l'autre côté.
  - Plus de place pour les autres salles : sans les cryptes ni les prisons, l'étage a plus de salles que d'apparences
    (image × miroir) libres ; chaque apparence peut alors resservir (`PlanSalles.attribuer_salles`).
  - Tests : `test_prisons_cryptes.gd` (prisons, cryptes, sorties potentielles), `test_passage_cryptes.gd` (passage
    dans l'écran d'exploration, aller et retour pour les 4 prisons). Outil : `tests/sonde_plan_prisons.gd` écrit les
    plans de 4 donjons dans `user://sonde_plans.json`.
- **Caractéristiques** (règles de l'utilisateur, 2026-10-29 ; `scripts/logique/caracteristiques.gd`, les mêmes pour
  le héros et les ennemis) :

  | Caractéristique | Effet |
  |---|---|
  | Endurance | **+5 PV max et +2 PV régénérés par minute tous les 2 points** (2026-11-03 ; +10 PV et +2 PV/min par point avant) |
  | Force | **+1d2 tous les 2 points** de dégâts physiques (tranchant, perforant, contondant ; 1d2 par point le 2026-11-02 au matin, +2 fixes avant) |
  | Dextérité | par point : +2 % de critique **physique seulement**, +1 % de toucher, +1 % d'esquive |
  | Intelligence | **+1d2 tous les 2 points** de dégâts d'arcane, d'ombre et de chaos ; +1 % de critique magique par point |
  | Sagesse | **+1d2 tous les 2 points** de dégâts de feu, de froid et de foudre ; +1 % de critique élémentaire par point (nouveau) |
  | Mana (nouvelle, clé `caracteristique_mana`) | **+5 mana max et +2 mana régénérés par minute tous les 2 points** (2026-11-03 ; +5 et +2 par point le 2026-11-02, +10 mana par point avant) |

  Endurance et Mana comptent par tranche de 2 points comme les dés (1 point = rien, 2-3 = une tranche, 4-5 = deux ;
  `Caracteristiques.POINTS_PAR_PALIER`, `PAR_PALIER`, `paliers`) ; une altération qui change l'une d'elles donne
  les tranches gagnées ou perdues. Talent « +x PV par point d'endurance » : désormais par tranche de 2 points.
  Les 1d2 (un par paire de points : 1 point = rien, 2-3 = 1d2, 4-5 = 2d2 ; `Caracteristiques.POINTS_PAR_DE`,
  règle de l'utilisateur du 2026-11-02) sont lancés avec les dés de la compétence, à chaque coup (`Formules.des_caracteristique`,
  `Formules.valeur_jet`), puis passent par les pourcentages comme eux.
  Lumière (soins) : la plus forte entre intelligence et sagesse, pour les dégâts comme pour le critique. Poison :
  aucune caractéristique, **jamais de critique**. Critique magique et élémentaire : même multiplicateur
  (`degats_critique_magiques`). Les caractéristiques ne donnent plus ni armure, ni résistances, ni dégâts critiques,
  ni puissance magique.
- **Régénération** : en **minutes réelles pendant l'exploration** seulement (`Personnage.regenerer`, appelée par
  l'écran de navigation, en pause pendant les combats et les menus). Plus de régénération en fin de combat. Base du
  héros gardée : 5 PV et 2 mana par minute.
- **PV et mana** : héros **toutes caractéristiques à 0** : 70 PV de base (`Personnage.PV_BASE_HEROS`) et 10 mana de
  base, toucher 85 %, esquive 5 %, critique 5 % (magique et élémentaire 2,5 %), parade 2 % (valeurs de base gardées
  par l'utilisateur). Ennemis : endurance divisée par 5 pour garder leurs PV (`Gobelin.ENDURANCE_PAR_SOUS_CLASSE`,
  `Creatures.SORTES`, écrites « 1 point = 10 PV » et multipliées par 4 à la création depuis le 2026-11-03,
  `Ennemis.ENDURANCE_PAR_POINT_ENNEMI`, de même que le bonus d'endurance des repos : mêmes PV qu'avant),
  **8 à 12 points de Mana** (`Ennemis.MANA_ENNEMIS` ; 2 ou 3 avant le 2026-11-02, doublés quand un point est passé à
  5 mana, validé par l'utilisateur, puis redoublés le 2026-11-03 quand il faut 2 points pour 5 mana : ils gardent
  leurs 20 à 30 mana), le reste à 0, à reforger.
- **Coût des sorts** : au moins 2 mana. Estafilade, Dard empoisonné et Bourrade (sorts d'arme de départ) passent de 1
  à 2 mana (2026-11-02, `donnees/sorts.json`). Les compétences physiques (Enchaînement, Fracasser, Frénésie,
  Balayage...) restent à 1 mana (décision de l'utilisateur).
- **Dégâts des ennemis** : en entier depuis le 2026-10-27 (`Ennemis.MULTIPLICATEUR_DEGATS_ENNEMIS` = 1 ; ×0,68 avant).
  Leurs dés restent lancés un cran plus bas que ceux du héros (`Formules.des_reduits`).
- **Caractéristiques des gobelins** (`Gobelin.definir_attribut_gobelin`) : tout part de 0
  (armure, critique et parade compris). **Depuis le 2026-10-29, force, dextérité, intelligence et sagesse restent à
  0** (`POINTS_STAT_*` = [0, 0], à reforger) ; avant : principale 1 à 4, secondaire 1 à 2,
  les autres 1 à 2 (`STATS_PAR_SOUS_CLASSE`) : combattant et lancier
  force / dextérité, archer dextérité / force, défenseur force / sagesse, sorcier et
  féticheur intelligence / sagesse, chaman sagesse / intelligence. Parade 2 à 4 % pour
  combattant, lancier et défenseur, 0 pour les autres (`PARADE_PAR_SOUS_CLASSE`). Le
  critique ne vient que des caractéristiques (+1 % tous les 2 de dextérité, +0,5 % de
  critique magique tous les 2 d'intelligence). Les objets portés s'ajoutent.
- **Objets des gobelins** : les gobelins ne portent aucun équipement (leurs dégâts
  viennent des dés de leurs compétences) et ne lâchent rien à leur mort, sauf l'élite d'un
  groupe (objet généré à ce moment, orienté selon sa classe — `Ennemis.generer_objet_butin`).
- **Coups multiples** (compétences avec `nombre_attaque` > 1 : Rafale de lance, Frénésie,
  Enchaînement, Lacération, Tir rapide, Blizzard, Projectiles arcaniques) : chaque coup
  lance 1d6 au lieu des dés du type, avec −2 dégâts (`Formules.DES_COUP_MULTIPLE`,
  `MALUS_COUP_MULTIPLE`, `valeur_jet`) ; caractéristique, dégâts plats et pourcentages
  s'ajoutent comme d'habitude ; jamais moins de 0.
- **Nombre d'ennemis par rencontre** (`Donjon.ENNEMIS_PAR_ETAGE`, `tirer_nombre_ennemis`) :

  | Étage | 1 ennemi | 2 ennemis | 3 ennemis |
  |---|---|---|---|
  | 1 | 75 % | 25 % | — |
  | 2 | 50 % | 40 % | 10 % |
  | 3 | 25 % | 50 % | 25 % |
  | 4 et suivants | 20 % | 45 % | 35 % |

  Le mini-boss (une rencontre sur cinq au plus) remplace ce tirage : seul ou avec un gobelin.
  Boss et mini-boss ont **1 point d'action** (`Ennemis.BOSS` / `MINI_BOSS`, « pa » ; le boss en avait 2
  avant le 2026-10-20).
- **Objets** (refonte de l'utilisateur, 2026-10-30 ; `GenerationObjets`) : fini les budgets à 50 attributs,
  **chaque objet donne une seule option** (`objet.option`), selon son rang :

  | Option | Rangs 1-2 | 3-4 | 5-6 | Qui peut l'avoir |
  |---|---|---|---|---|
  | Caractéristique de son orientation | +1 | +2 | +3 | armures, bijoux, armes |
  | Défense (armure, rés. magique, rés. élémentaire ; une ou deux) | 2 × rang points | | | casque, plastron, jambières, bottes, ceinture, gants |
  | Dégâts de son orientation (`degats_physique` / `degats_magique` / `degats_elementaire`) | +2 | +4 | +6 | bottes, ceinture, gants, bijoux, armes |
  | Pénétration (armure ou résistance) | 2 | 4 | 6 | armes |

  Orientations : physique (force, dextérité, endurance), magique (intelligence, Mana, endurance), élémentaire
  (sagesse, Mana, endurance). **Le type est écrit dans le nom** (« Épée magique commune », « Bottes élémentaires
  communes », « Plastron physique médiocre » ; plus de « runique » ni d'« enchantée »). Une arme a l'option dégâts
  2 fois sur 5, caractéristique 2 fois sur 5, pénétration 1 fois sur 5 (`OPTIONS_ARMES`, poids choisis par Claude). Défensif : caractéristique ou
  défense ; hybride (bottes, ceinture, gants) : les trois ; bijoux : caractéristique ou dégâts (validé).
  Retirés des objets : régénérations, esquive, toucher, critique, PV, pourcentages de dégâts, dégâts d'un type
  précis, résistances spécifiques. Les **résistances spécifiques** ne viennent que de l'**armure anti-boss**.
  Les effets uniques (`UNIQUES`) sont gardés tels quels en attendant le tri de l'utilisateur. Le % de dégâts
  magiques est séparé de l'élémentaire (`pourcentage_degats_elementaire`). La valeur en or suit le rang.
  À venir (idées de l'utilisateur) : armes spéciales à gros dégâts critiques (+100 %, critique plafonné à 5 %),
  armes qui infligent une vulnérabilité, arme anti-boss portée par un élite.
- **Armure anti-boss** (2026-10-30) : la classe du boss est tirée **à la création de l'étage** (présence
  « boss », `membres`), son type de dégâts principal calculé sur ses compétences (`Gobelin.type_degats_principal` :
  le plus fréquent, à égalité le plus fort ; provisoire, en attendant la refonte des ennemis) et noté
  `boss_type_degats` dans les réglages de l'étage. Un **coffre ancien** (présence « objet » / `coffre_gardien`, cerclé
  de fer, sceau rouge) est posé dans une salle ordinaire : il donne une armure à option défense **+ 6 points et
  20 % de résistance** à ce type (`GenerationObjets.generer_anti_boss`, « Plastron commun anti-foudre » ; valeurs
  provisoires de l'utilisateur ; « Ceinture élémentaire commune anti-foudre »). Si le geôlier la confisque, elle part avec le reste des affaires.
- **Faiblesse et force du boss** : toujours tirées au hasard (feu, froid, foudre, tranchant, perforant,
  contondant), désormais en pourcentage : **+50 %** de dégâts reçus et **60 %** de résistance (`Aventure.FAIBLESSE_BOSS`,
  `FORCE_BOSS`), en attendant la refonte des ennemis.
- **Points d'action** : le héros n'a plus qu'**1 PA** (`Personnage`, `points_d_action_max`).
  Les sorts à 2 PA (Météore, Embrasement, Zéro absolu, Jugement du tonnerre, Singularité,
  Apocalypse, Anathème, Miracle, Mille entailles, Perce-cœur, Séisme, Colère du titan)
  ne peuvent donc plus être lancés par le héros (à revoir avec les paliers).
- **Soins des ennemis** : un ennemi n'est soigné qu'une fois par combat, par une
  compétence de soin ou une potion (`Ennemis.peut_etre_soigne`, marque `deja_soigne` ;
  vérifiée par l'IA et par `Combat.lancer`).
- **Tour perdu affiché** : quand une altération retire le tour ou le dernier PA d'un
  combattant (étourdissement, gel, lenteur, électrocution, terreur, paralysie, sommeil,
  pétrification, décrépitude), « Tour perdu (Gel) » s'affiche au-dessus de lui
  (`Combat._signaler_tour_perdu`, `EffetsCombat.signaler_texte`, attribut `cause_tour_perdu`).
  Avec 1 PA partout, un effet qui retire 1 PA fait perdre tout le tour (à revoir).
- **Combat contre un ennemi seul** : il est centré à l'écran (`menu_combat.placer_ennemis`).
- **Initiative** : le héros joue toujours en premier (`Combat.tour_de_combat`) ; les
  talents d'initiative (`Talents.chance_initiative`) n'ont donc plus d'effet.
- **Combat animé** (`scripts/interface/combat_anime.gd`, classe `CombatAnime`) : animations image
  par image faites avec Grok (banc d'essai `C:\ia image\Salle de donjon\test_salle`). Les règles
  ne changent pas, seulement l'affichage de l'écran de combat :
  - **Héros vu de dos au premier plan** (en bas, au milieu de l'écran, assez bas pour laisser voir l'ennemi du milieu, `PIEDS_HEROS`, `HAUTEUR_HEROS`) : garde
    de son arme (épée, lance, marteau ; sans arme : respiration), attaque de l'arme quand il lance
    une des deux compétences d'arme (premier et deuxième bouton), « touché » quand un coup l'atteint.
    Pas d'idle fourni pour la lance : sa garde est la 1re image de l'attaque, qui respire comme les
    images fixes (`Animations.dessiner_respirant`, ancrée aux pieds). **Magies** : lancer de sort
    (`avatar_sort_v2`, boule de feu bleue lancée vers le fond, quel que soit l'élément ; l'arme
    n'est pas tenue pendant le lancer), dégâts affichés à l'image 11 (la boule, relâchée à l'image 9,
    s'éloigne) ; aussi pour les sorts sur soi (Soin). Le coup de poing n'a pas d'animation.
  - **Gobelins combattant, archer et sorcier animés** (jeux d'images guerrier, archer, sorcier ;
    `CombatAnime.TYPES`) : attente en boucle (le guerrier à 250 ms par image comme l'archer, cycle
    de 3 s, au lieu des 110 ms des images sources : `MS_ATTENTE` de `outils/importer_animations.py`), une de leurs attaques quand ils agissent, touché,
    mort (puis fondu). Le chaman (images de `ennemis/gobelin/gobelin chaman`, réduites de moitié) a deux attaques : boule de feu
    et cercle de feu au sol, dégâts à l'image 10. Le féticheur (`ennemis/gobelin/gobelin feticheur`, réduit à 0,7, affiché à 65 % car il est
    accroupi) aussi : orbe vaudou (dégâts à l'image 10) et fumée de malédiction avec coup au sol (image 11) ; sa mort est
    la version relevée `mort/death_lift`. Lancier et défenseur gardent leur image fixe qui respire.
    Un boss ou mini-boss animé est simplement plus grand (cadre `taille_affichage`).
  - **Calage sur les coups** : `Combat.infliger_degats` donne le lanceur de chaque coup
    (`EffetsCombat.debut_coup(lanceur)`, `Impact.source`). Au premier coup d'une attaque d'un
    combattant animé, `EffetsCombat.planifier` le retarde du temps qui sépare le début de son
    animation d'attaque de son image d'impact (`CombatAnime.avance`), et l'animation démarre
    d'autant plus tôt (`CombatAnime.demarrer`) : les dégâts s'affichent quand l'arme touche. Les
    autres coups de la même action suivent l'écart habituel. Un coup mortel sur un gobelin animé
    reste à l'écran le temps de sa mort (`EffetsCombat.durees_mort`).
  - **Barre d'actions compacte** (`menu_combat.gd`, `rect_menu_actions`, `LARGEUR_BOUTON`,
    `HAUTEUR_BOUTON`) : 600 × 58 px collée au bas de l'écran, boutons de 112 × 32, texte plus petit.
  - **Cible automatique** : une compétence ou une magie à ciblage « choix » d'une seule cible, quand il
    ne reste qu'un ennemi, le vise tout de suite, sans clic sur l'ennemi (`_attendre_cibles`).
  - **Pause avant la riposte** : l'attaque d'un ennemi qui suit celle du héros démarre
    `EffetsCombat.PAUSE_RIPOSTE` (1,5 s) après le dernier coup du héros, le temps que la cible
    réagisse (touché) ; sans attaque du héros (objet, tour passé), pas de pause.
  - Images préchargées au début de chaque combat (`CombatAnime.precharger`), sinon la première
    attaque saccade.

## Organisation

| Dossier | Contenu |
|---|---|
| `scenes/principal.tscn` + `scripts/principal.gd` | Point d'entrée (`lancer_jeu` de `menu_navigation.py`). |
| `scripts/logique/caracteristiques.gd` | `Caracteristiques` : effets de chaque caractéristique (héros et ennemis), textes de l'écran des caractéristiques. |
| `scripts/noyau/` | `Dyn` (objets à attributs dynamiques, comme en Python) et `U` (équivalents de `getattr`, `random.choices`, format `%g`...). |
| `scripts/logique/` | Règles du jeu, sans affichage : personnage, ennemis, combat, donjon, objets, compétences, sorts, altérations, talents, équilibrage, marchand, sauvegarde. |
| `scripts/interface/` | Socle de l'affichage : `Ecran` (couches de dessin, entrées), `Ecrans` (ouverture des écrans), `Ui` (style commun), `Manette`, animations, effets de combat, cartes, info-bulles. |
| `scripts/ecrans/` | Un script par menu pygame (`menu_combat.gd` ↔ `menu_combat.py`, etc.). |
| `donnees/` | Données du jeu en JSON (libellés des talents, sorts, compétences, améliorations, foyers des fonds). Exportées autrefois du jeu Python, elles sont maintenant la seule source : les modifier directement. |
| `images/` | Copie des images du jeu ; `images/combat_anime/` : animations du combat (héros de dos, gobelins), copiées par `outils/importer_animations.py` ; `images/salles_peintes/` : salles peintes (image, vidéo du décor `decor.ogv`, masque) et héros en 8 directions, copiés par `outils/importer_salles.py` (≈ 84 Mo, `.gdignore` : lus à l'exécution, pas importés). |
| `outils/` | Scripts Python de préparation des images et des données ; `importer_objets.py` copie et nettoie les objets à poser dans les salles ; `affiner_premier_plan.py` détoure au pixel le premier plan des salles de test_salle ; `importer_animations.py` copie les animations de `C:\ia image` et écrit `donnees/combat_anime.json` ; `importer_salles.py` copie les salles peintes de `test_salle` et écrit `donnees/salles_peintes/<id>.json` ; `importer_grandes_salles.py` fait de même pour les grandes salles (zones relevées à la main, image agrandie par IA) ; `importer_animations_diablotin.py` copie les animations du diablotin faites par Grok. |
| `scripts/interface/salle_peinte.gd` | `SallePeinte` : moteur de salle peinte (port de `test_salle.gd` sans l'éditeur ; décor animé = vidéo Theora lue par un `VideoStreamPlayer` caché dont la texture remplace l'image fixe, `nouveau_lecteur`, `video_prete` ; `sortie_atteinte`). |
| `scripts/logique/aventure.gd`, `rencontres.gd` | Donjon d'aventure : population des étages, combats des présences, fuite, capture, objets, clés (`Aventure`) ; personnages et choix moraux (`Rencontres`). |
| `scripts/logique/dialogues.gd`, `donnees/dialogues.json` | Textes des personnages (`Dialogues.texte("diablotin/accueil/neutre", {mots})`), modifiables dans l'éditeur de zones (menu Dialogues, `scripts/outils/editeur_dialogues.gd`). |
| `scripts/interface/presences_salle.gd` | `PresencesSalle` : ennemis qui rôdent, personnages et objets dans la salle peinte (formes, vue, ouïe, poursuite, contact). |
| `scripts/ecrans/ecran_dialogue.gd` | Dialogue à choix (`Ecrans.dialogue`). |
| `scripts/logique/plan_salles.gd` | `PlanSalles` : attribution des salles peintes au plan du donjon (chaque apparence une fois par étage, quartier des prisons, quartier des cryptes) et sortie qui mène à chaque voisine. |
| `scripts/logique/zones.gd`, `donnees/zones.json` | `Zones` : ennemis de chaque zone de l'étage (cryptes : squelettes et un féticheur élite ; « defaut » ailleurs), modifiables dans le .json. |
| `scripts/ecrans/menu_options.gd` | Options (volume de la musique), depuis le menu principal et le menu pause (`Ecrans.options`). |
| `scripts/logique/generation_objets.gd` | `GenerationObjets` : objets à une seule option (caractéristique, défense, dégâts, pénétration), type dans le nom, arme de départ nue, armure anti-boss. |
| `scripts/logique/degats.gd` | `Degats` : pourcentages (vulnérabilités, résistances en %) puis blocage en points (2 points = 1 dégât, sans cumul défense générale / résistance spécifique). |
| `audio/musique/` + `scripts/noyau/musique.gd` | Musique de fond : autoload `Musique` (déclaré dans `project.godot`) qui joue `elf_song_tavern.mp3` en boucle pendant tout le jeu, même en pause (volume `VOLUME_DB` = −8 dB à 100 % ; réglage du joueur `Musique.volume`, 0 à 1, menu Options, enregistré dans `user://options.cfg` par `regler_volume` ; `Musique.jouer(chemin)`). |
| `scripts/noyau/compte.gd` | `Compte` : ce que le joueur garde d'une partie à l'autre (glossaire des ennemis), `user://compte.json`. |
| `scripts/logique/blocs_salles.gd` + `outils/importer_blocs.py` | `BlocsSalles` : blocs de salles (plan, liens porte à porte, entrées) ; import de leurs images et de leurs zones. |
| `scripts/logique/karma.gd` | `Karma` : karma du héros, vitesse des Chevaliers de la mort, effets sur les prix, l'or et les diablotins. |
| `scripts/logique/objets_divers.gd` | `ObjetsDivers` : catalogue des objets divers, nourriture et ingrédients (`donnees/objets_divers.json`), manger, affichage des clés. |
| `tests/` | Tests et outils de contrôle (voir plus bas). |

### Correspondance pygame → Godot

- Une boucle `afficher_menu_xxx()` devient un écran (`extends Ecran`) : `preparer(...)`
  reçoit les arguments, `_dessiner(ci)` dessine chaque image, `_evenement(ev)` reçoit
  les entrées simplifiées (`clic`, `touche`, `molette`), `fermer(resultat)` rend la main.
  L'appelant fait `await Ecrans.menu_xxx(...)`.
- Couches d'un écran : fond (image), particules des foyers, contenu, lumière
  (mélange additif, équivalent de `BLEND_RGB_ADD`), dessus (info-bulles, cadre de la manette).
  `couche_decoupee(zone, fonction)` remplace `set_clip` (listes défilantes).
- Les fonctions bloquantes de la logique (`mener_combat`, `avancer`, menus du
  marchand, coffres...) sont des coroutines (`await`).
- `MortDuHeros` (exception Python) devient `Statistiques.mort` / `Statistiques.cause_mort`.

## Données du jeu

Les fichiers de `donnees/` (talents, sorts, compétences, améliorations, foyers des fonds) venaient de
`outils/exporter_donnees.py`, qui lisait le jeu Python. Cet outil a été supprimé avec la version Python
(2026-10-31) : les JSON sont maintenant la source, à modifier directement.

## Testeur d'étage (durée de l'étage 1)

`testeur_etage.bat [parties] [graine]` (ou `Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path .
-s tests/testeur_etage.gd -- [parties] [graine] [options]`) : un testeur automatique joue l'étage 1 **dans le vrai
jeu** et mesure combien de temps il faut pour trouver et vaincre le boss (objectif de l'utilisateur : environ une
heure pour un joueur moyen). Rapport : `tests/rapports/testeur_etage.txt`.

- **Déplacements réels** : il donne une direction au héros comme un stick (`SallePeinte.pilote`), en courant, sur un
  chemin calculé entre les obstacles (grille de 6 px, raccourcis en ligne droite, autres sorties évitées), puis pousse
  vers la sortie (les portes s'ouvrent comme pour un joueur).
- **Sans connaître la carte** : il ne sait que ce que montre la mini-carte (salles visitées, sorties vues) et va vers la
  salle inconnue la plus proche ; quand il a vu le boss, il y retourne jusqu'à le vaincre. Salles verrouillées
  ignorées (il ne cherche pas les clés).
- **Ennemis réels** : ils rôdent et le poursuivent ; un contact lance le combat, joué par le joueur automatique
  (`Auto`, qui fuit le Chevalier de la mort) ; les geôliers peuvent le capturer. Quand un geôlier ou le Chevalier le
  poursuit (ou est à moins de 2,5 hauteurs de héros), il sort par la sortie la plus loin de lui (« fuites devant un
  chasseur »). Il ne parle à personne, ne fouille pas, ne ramasse rien.
- **Temps** : `--fixed-fps 60` fait compter chaque image pour 1/60 s de jeu, calculée aussi vite que possible (≈ 6
  fois plus vite que le temps réel) : déplacements et fondus sont **mesurés**. Les combats du joueur automatique sont
  instantanés : leur durée est **estimée** (`TEMPS_ACTION_COMBAT` = 6 s par action du héros), comme la lecture des
  personnages croisés (`TEMPS_PERSONNAGE` = 20 s) et la découverte de chaque nouvelle salle (`TEMPS_DECOUVERTE` = 8 s).
- **Morts** : le joueur automatique joue mal (il frappe et se soigne au hasard) ; pour mesurer quand même la durée, le
  héros qui meurt se relève au cachot, soigné (Pacte de mort offert à chaque fois) ; chaque mort est comptée.
  Option `sans-relever` : la première mort termine la partie. Après `DEFAITES_GARDIEN` (3) défaites contre le boss,
  la partie s'arrête (« le joueur automatique ne bat pas le boss ») : le rapport donne alors le **temps pour
  trouver le boss** (estimé au moment où il le voit pour la première fois).
- **Ce que dit le rapport** (écrit après chaque partie) : temps pour trouver le boss, temps mesuré, estimé et total, salles visitées, passages, chaque combat (ennemis,
  actions, issue), captures, morts, **sorties abandonnées** (impossibles à prendre : zones à revoir) et salles jamais
  visitées (verrouillées, entrée jamais vue).
- Options : `trace` (où il en est toutes les 30 s de jeu), `limite=N` (N minutes de jeu au plus par partie ; 60 par
  défaut).

## Fiches techniques des ennemis

`python outils/fiches_ennemis.py` (depuis ce dossier) écrit dans le dossier de chaque ennemi (`C:\ia image\ennemis\...`)
une « fiche technique - <nom>.odt » : caractéristiques (bornes sur 300 tirages au premier étage), défenses,
compétences jouées par l'IA (coût, dés, dégâts moyens contre le héros de départ, altérations, cible), façon de se
battre, comportement dans les salles, règles communes, images et animations, et une section « Ta fiche et le jeu »
qui cite la fiche de l'utilisateur et signale les écarts. Les chiffres viennent du jeu : le script lance
`tests/exporter_fiches_ennemis.gd` (export dans `user://fiches_ennemis.json`). **À relancer après toute
modification d'un ennemi** (les fiches sont réécrites ; les notes de l'utilisateur restent dans ses propres fiches).
Les textes de comportement (IA, chasseurs, pactes) sont écrits dans le script : à mettre à jour avec le code.

## Animations du combat

Après une modification des animations sources (dans `C:\ia image`), depuis ce dossier :

```powershell
python outils/importer_animations.py   # images/combat_anime/ + donnees/combat_anime.json
& "C:\jeux\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --import
```

`donnees/combat_anime.json` donne, pour chaque animation, le nombre d'images, leurs durées (ms),
l'image d'impact, la boucle, et le point des pieds dans l'image. Les images du héros sont réduites
à 75 % ; celles des gobelins sont copiées telles quelles depuis le banc d'essai `test_salle`.

**Chevalier de la mort** (`outils/importer_combat_chevalier.py`, appelé aussi par `importer_animations.py`) : images
de Grok dans `C:\ia image\ennemis\chevalier de la mort` (`attaque/` : deux coups d'épée de haut en bas ;
`recevoir dégats/` : il lève l'épée à l'horizontale, une **parade**). Jeu « chevalier » de `combat_anime.json`
(`Aventure.creer_imbattable` lui donne `anim_combat = "chevalier"` et `centre_combat` : seul, il se tient **au milieu**,
face au héros, et son épée s'abat sur lui). `attente` : première image de l'attaque, qui respire. `attaque1` /
`attaque2` : **toutes** les images, 34 ms (original 41,5) ; chaque attaque finit par son **retour en garde** fait par
Grok (`retour/retour_A`, `retour_B`) et l'attaque B commence par `retour/bonus_debut_B` (pose de repos → début de
l'attaque) : elles partent et reviennent exactement sur la pose de repos (A : 132 images, coup à l'image 76 ; B : 128,
coup à 64). Le fondu `fondu_fin` de `CombatAnime` reste disponible mais n'est plus utilisé. `touche1` / `touche2` : la garde monte (images 0 à 36 et 0 à 42, 28 ms), tient 300 ms,
puis redescend par les mêmes images à l'envers (liste `ordre`, sans fichiers en double). Au lieu d'accuser les
coups, il **pare** : quand le héros attaque, `CombatAnime.avance` retarde son coup jusqu'à ce que la garde soit
levée (environ 1 s) et `demarrer` lance la parade ; un coup raté n'est pas paré. Pas d'animation de mort : s'il
tombe, il garde son image fixe. Images recadrées sur une même boîte, réduites de moitié (285 fichiers, 480 × 476),
ancrées au milieu du casque, compressées pour la carte graphique (BPTC, sans mipmaps, ≈ 230 Ko chacune).
Essai à jouer : `voir_combat_chevalier.bat` (`tests/voir_combat_chevalier.tscn`, héros à l'épée et 999 PV).

**Marches des gobelins** (dans le jeu depuis le 2026-10-28) : Grok a fait la marche en 4 vues (face, trois quarts,
profil, dos) du guerrier, de l'archer, du chaman et du féticheur (`C:\ia image\ennemis\gobelin\gobelin <sorte>\marche\`,
même format que le geôlier ; pas encore le sorcier). Import : `python outils/importer_animations_marche.py
gobelin_guerrier gobelin_archer gobelin_chaman gobelin_feticheur` → `images/pnj/gobelin_<sorte>_anim/` (256 px de haut,
`animations.json` avec `foulee` et `visible`, part de l'image occupée par la silhouette). Dans les salles
(`PresencesSalle`) : un gobelin **qui se déplace** joue sa marche (vue selon la direction, comme le geôlier, image selon
la distance parcourue), à la taille de son image de repos du combat (`rapport_marche_gobelin`) ; arrêté, il reprend sa
respiration de combat. Le sorcier, le lancier, le défenseur, les squelettes et les loups gardent leur image de repos.
**Vitesse** (décisions de l'utilisateur) : un groupe, un porteur ou le boss qui a au moins un gobelin avec une
marche avance en ronde à la vitesse naturelle du plus lent de ceux-là (`vitesse_gobelins`, environ 0,13 à 0,19
hauteur de héros par seconde ; le héros marche à 0,81, court à 1,8) et **poursuit à 0,85** (`COURSE_GOBELINS`) : sa
marche défile alors environ 5 fois plus vite (≈ 60 images/s pour le guerrier), l'image suivant toujours la distance.
Avant ce jour : ronde 0,40 et poursuite 1,04 ; au pas en poursuite, jugé « trop facile ». Les groupes sans marche (squelettes seuls) gardent leurs vitesses.
Aperçu hors du jeu : `voir_marches_gobelins.bat` lance
`outils/apercu_marches_gobelins.py` (même traitement que `importer_animations_marche.py` : boîte commune, foulée
mesurée sur le profil) qui écrit `C:\IA\pont-blender\apercu_gobelins\` **hors du jeu**, puis ouvre
`tests/voir_marches_gobelins.tscn` : Tab = planche des 4 vues / traversée de la salle porte 2 de profil à la vitesse
de la foulée ; Espace = pause ; + / - = vitesse ; Échap. `-- capture=<dossier>` enregistre les deux vues et quitte.

## Tests

Toujours lancer d'abord un import (enregistre les classes) :

```powershell
$godot = "C:\jeux\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --import
& $godot --headless --path . -s tests/compiler_tout.gd    # compile tous les scripts
& $godot --headless --path . -s tests/test_logique.gd     # partie complète jouée sans interface
& $godot --headless --path . -s tests/test_descente.gd    # monter puis redescendre : pas de boss rejoué
& $godot --headless --path . -s tests/test_des_armes.gd   # dés par type, caractéristiques, dés bonus (attaques de l'arme), défense (2 points = 1, sans cumul, pourcentages), options des armes, brûlure, % d'élément
& $godot --headless --path . -s tests/test_magie_ecran.gd # écran de combat : un sort sur soi = une action
& $godot --headless --path . -s tests/test_butin.gd       # gobelins sans équipement
& $godot --headless --path . -s tests/test_soins.gd       # un soin par ennemi et par combat, héros à 1 PA
& $godot --headless --path . -s tests/test_pv.gd          # PV = 70 (héros) + endurance × 2, caractéristiques du héros, ennemis par étage
& $godot --path . -s tests/robot.gd -- 2 36000            # partie jouée par l'interface (graine, images)
& $godot --path . -s tests/capture_salles_peintes.gd      # salles peintes : attribution, marche, portes, grandes salles (arrivées, sorties atteignables, captures 57_grandeN) (hors écran)
& $godot --headless --path . -s tests/test_blocs.gd               # blocs de salles : un bloc cuisine par étage, liens porte à porte, deux entrées, images réservées
& $godot --path . -s tests/capture_bloc_cuisine.gd                 # captures 120-129 : chaque salle du bloc, arrivée par chaque porte (hors écran)
& $godot --headless --path . -s tests/test_cachettes.gd           # cachettes : héros invisible, ennemis qui n'y entrent pas, sauf celui qui l'a vu entrer
& $godot --headless --path . -s tests/test_cri_de_guerre.gd       # gobelin combattant : Cri de guerre s'il est accompagné, sinon Coup d'épée
& $godot --headless --path . -s tests/test_boss_cle.gd            # boss à 35-40 salles sans raccourci, salle fermée, clé portée par une élite, ennemis isolés
& $godot --headless --path . -s tests/test_karma.gd               # karma (vitesse du chevalier, prix, or, mensonges), capture dans la prison la plus proche, pacifiques, corps et âmes
& $godot --path . -s tests/capture_karma.gd                        # captures 130-132 : corps dans une salle, dialogue du corps, points à répartir (hors écran)
& $godot --headless --path . -s tests/test_grands_etages.gd        # grands étages : ~80 salles (TAILLE_ETAGE), tout accessible, carrefours, boucles, plan dessiné en texte
& $godot --path . -s tests/capture_portes.gd               # portes : fermées tant qu'on ne marche pas vers elles, ouverture, passage, miroir, porte condamnée (hors écran)
& $godot --headless --path . -s tests/sonde_prisons.gd      # sonde : prisons hors quartier, passages sans porte, carrefours par quartier (100 étages)
& $godot --headless --path . -s tests/test_zones.gd        # zones : quartier des cryptes d'un seul tenant (toutes les images, une fois), squelettes + un seul féticheur élite, zones.json, 1d2 tous les 2 points (150 étages)
& $godot --headless --path . -s tests/test_creatures.gd     # loups et squelettes : caractéristiques, dés, faiblesses, groupes (3000 tirages)
& $godot --headless --path . -s tests/test_aventure.gd      # donjon d'aventure : peuplement, pas de récompense, Chevalier de la mort, fuite, capture, clés, personnages, sauvegarde, coffre du boss, objets à une option, 5 étages au départ, quartier des prisons
& $godot --path . -s tests/capture_aventure.gd            # rôdeurs à l'écran : ombre, vue coupée, repérage, combat au contact, diablotin, capture (captures 92-100, hors écran)
& $godot --path . -s tests/sonde_cachettes.gd             # outil : part du sol caché (ombre, premier plan) de chaque salle (hors écran)
& $godot --headless --path . -s tests/test_fouille.gd       # fouille : 0 à 2 objets par salle, résultats et leurs effets (milliers de tirages)
& $godot --headless --path . -s tests/test_emplacements.gd  # emplacements : aucune sortie bloquée, chaque objet accessible (toutes les salles, miroir)
& $godot --path . -s tests/capture_fouille.gd             # fouille à l'écran : « Fouiller (E) », E, objet assombri ; objets de chaque salle (captures 74-91, hors écran)
& $godot --headless --path . -s tests/test_arrivees.gd           # arrivée par l'ouverture qui mène à la salle quittée (porte plutôt que passage, retour par l'ouverture prise)
& $godot --headless --path . -s tests/test_retour_salle.gd       # retour dans la salle précédente : là où le héros avait franchi la sortie
& $godot --headless --path . -s tests/test_quetes_prisonniers.gd # les trois quêtes des prisonniers jouées de bout en bout (logique)
& $godot --headless --path . -s tests/test_cartographie_salles.gd   # directions de chaque salle de la carte ↔ portes de son image ; chaque apparence une seule fois par étage
& $godot --path . -s tests/voir_directions.gd             # captures 58 par combinaison + passages haut/bas/gauche/droite (hors écran)
& $godot --headless --path . -s tests/test_editeur_zones.gd   # éditeur de zones : tracer, annuler, enregistrer (porte2 remise en état)
& $godot --headless --path . -s tests/test_cuisine.gd         # cuisine : le jeu = la liste complète (14 949 mélanges), feu, eau, bouillon, recettes, intoxication (mortelle, cumulée)
& $godot --path . -s tests/capture_cuisine.gd             # captures 170-176 : onglets Feux et Eau, écran de cuisine, feu de camp et intoxication, indications dans une zone de feu et d'eau (hors écran)
& $godot --path . -s tests/capture_escaliers_carte.gd     # captures 180-182 : escaliers des passages prison / cryptes sur la mini-carte et la carte (hors écran)
& $godot --headless --path . -s tests/test_commis_dialogues.gd # commis (place, anciennes parties, animations), viande des loups, textes de dialogues.json, menu Dialogues de l'éditeur
& $godot --path . -s tests/capture_commis.gd                # captures 183-186 : commis de la cuisine et du cellier, dialogue d'un commis, menu Dialogues (hors écran)
& $godot --headless --path . -s tests/test_butin_pose.gd      # catalogue, onglets Nourriture/Ingrédients, manger, marchand, butin posé dans l'éditeur → ramassé dans le jeu (porte2 remise en état)
& $godot --path . -s tests/capture_butin.gd               # captures 160-165 : onglet Butin, butin dans la salle, « Ramasser (E) », inventaire et marchand (hors écran)
& $godot --path . -s tests/test_collisions_salles.gd      # le héros court dans 8 directions : pieds toujours sur le sol (cul-de-sac ; « -- toutes » : toutes les salles)
```

`capture_combat_anime.gd` (avec l'`override.cfg` ci-dessous) joue un combat contre un combattant,
un archer et un sorcier avec chaque arme, puis avec une magie (Étincelle ardente). Il vérifie que le héros et les gobelins bougent dès
l'ouverture du combat, que le guerrier respire à 250 ms par image, que l'image d'impact de l'attaque du héros tombe
sur son premier coup, que la cible réagit, que les gobelins attendent 1,5 s puis jouent leur attaque calée sur leurs
coups, puis que le héros réagit. Il vérifie aussi qu'un sort à cible unique vise seul le dernier ennemi. Un chaman seul puis un féticheur seul ripostent avec un de leurs lancers, puis meurent. Il enregistre les captures 31 à 42 et affiche
« BILAN combat animé : 0 échec(s) » si tout est correct.

`capture_salles_peintes.gd` vérifie l'attribution des salles peintes sur 4 étages (chaque passage du
plan mène à une sortie peinte ou à une flèche, chaque sortie mène à la salle qui est dans sa direction sur la carte, miroirs compris), fait marcher le
héros, franchit 4 portes (combats joués seuls, `Ecrans.auto`) et vérifie l'arrivée devant la porte
de la salle quittée ; captures 50 à 55 ; « BILAN salles peintes : 0 échec(s) ». Le robot (`robot.gd`)
franchit des sorties peintes au hasard (`_sortie_atteinte`) au lieu d'envoyer des flèches.

`capture_navigation.gd` vérifie quels boutons de droite s'affichent (départ de l'étage 1,
salle du boss, départ de l'étage 2, salle ordinaire, salle avec un lit) et enregistre les
captures 25 à 28 ; il affiche « BILAN navigation : 0 échec(s) » si tout est correct.

`capture.gd`, `capture_menus.gd` et `capture_combat_seul.gd` (ennemi seul centré, boss) enregistrent des captures
de contrôle dans `tests/captures/` (rendu interne de la fenêtre : rien n'est capturé
du bureau). Pour ne pas gêner l'utilisateur, les placer dans une fenêtre hors écran et
sans focus avec un `override.cfg` temporaire :

```ini
[display]
window/size/no_focus=true
window/size/initial_position_type=0
window/size/initial_position=Vector2i(-4000, -4000)
```

Les tests ne déplacent jamais la vraie souris : ils passent par le curseur virtuel
(`Manette.mode_manette`, `Manette.pos`) ou envoient les événements à l'écran (`_traiter`).

## Assets 3D (Blender)

Le jeu reste en 2D ; des assets 3D faits dans Blender sont prêts pour plus tard (décors, rendus de salles) :
- `assets_3d/entree_ruine/` : 48 assets `ER_*` (.gltf + .bin, textures partagées dans `textures/`) tirés de la banque
  d'images « entrée en ruine » : piles, colonnes, arcs, arcades, murs ruinés, dallage herbeux, fougères, lierre, arbres.
  Sources et régénération : `C:\IA\pont-blender\entree_ruine\LISEZMOI.md` ; liste de tous les assets 3D :
  `version 3d/Documentation/11_Catalogue_assets.md`.
- `scenes/3d/entree_ruine.tscn` : la reproduction 3D de l'image `mvpaev34yv4my7.jpeg` (99 instances, caméra, soleil, ciel,
  brouillard). Capture : `tests/capture_entree_ruine.gd` (fenêtre hors écran, voir Tests) → `tests/captures/70_entree_ruine_3d.png`.
- **Couleurs de sommet** : la teinte et la mousse des assets sont dans les couleurs de sommet ; la racine de la scène porte
  `scripts/3d/scene_assets_blender.gd`, qui les active sur les matériaux au chargement. Poser ces assets sous un nœud qui
  porte ce script, sinon ils sortent gris ou blancs.

## Décors 2D en calques

- `assets_2d/entree_ruine/` : l'image `mvpaev34yv4my7.jpeg` découpée en 16 sprites détourés (`sprites/*.png`, positions
  dans `sprites/sprites.json`) et 5 calques plein cadre 1536×1024 (`calques/`) : fond (ciel, forêt), plan moyen (murs et
  arcade vus à travers les arcs), sol, arcade (4 piles, 3 arcs), fougères. Les parties cachées derrière chaque calque
  sont reconstituées. Sources et régénération : `C:\IA\pont-blender\entree_ruine\assets_2d\LISEZMOI.md`.
- `scenes/2d/entree_ruine_2d.tscn` (générée) : redonne l'image au pixel près. Racine `scripts/2d/decor_2d.gd` :
  `image_entiere` (toute l'image avec bandes noires, ou écran rempli), `anime` (vent dans les fougères par
  `scripts/2d/vent_vegetation.gdshader`, pollen). Un personnage sur le dallage se place entre les nœuds `Sol` et `Arcade`.
- `assets_2d/salle_porte_2/` + `scenes/2d/salle_porte_2_2d.tscn` : la salle porte 2 (`mvb5lccj46iys4.jpeg`) en 18 sprites
  et 7 calques (fond, rotonde, murs, portes, sol, tapis, premier_plan) ; les 3 portes sont des sprites séparés avec un
  passage sombre derrière ; bougie animée, poussière. Chaîne générique : `C:\IA\pont-blender\decors_2d\LISEZMOI.md`.
- `scenes/2d/assemblage_salle_porte_2.tscn` : nouvelle salle symétrique en 16/9 composée avec ces sprites (miroirs,
  `region_rect`, `modulate`) : exemple de réutilisation.
- `decor_2d.gd` : `sprites_vent`, `sprites_flamme` (shader `scripts/2d/flamme.gdshader` + halo), `particules`
  (`"pollen"`, `"poussiere"` ou `""`).
- Test : `tests/capture_entree_ruine_2d.gd` (fenêtre hors écran) → captures 71 et 73 (taille de l'image, sans animation,
  identiques aux images) et 72, 74, 75 (960×540, animés).

## Règles de maintenance

- **Attribut qui peut valoir `null` :** sur un objet `Dyn`, `obj.attribut` provoque une
  erreur si la valeur est `null` (limite de `_get` dans Godot). Lire avec
  `U.ga(obj, "attribut", null)` (ou `obj.lire(...)`).
- Classes dérivées de `Dyn` : aucune variable membre, construction par `nouveau(...)`
  (la sauvegarde ne copie que le dictionnaire `_d`).
- Tout nouvel écran : `extends Ecran`, style `Ui`, zones de la manette déclarées à chaque
  image (`definir_zones`), Échap pour fermer, ouverture via une fonction de `Ecrans`.
- **Publication (décision de l'utilisateur, 2026-10-31) : à chaque commit**, (1) ne publier que ce dossier, sur
  [LE-Jeu-Godot](https://github.com/kanna91/LE-Jeu-Godot) : `git subtree split --prefix=godot -b version-godot-seule`
  puis `git push godot version-godot-seule:main` (le dépôt complet LE-Jeu-Ultime n'est plus mis à jour) ;
  (2) refaire le .exe avec `exporter_windows.bat` ; (3) publier une **nouvelle release** sur LE-Jeu-Godot (v0.2, v0.3…)
  avec `..\export\LE_Jeu_Ultime_Windows.zip`. Le lien de téléchargement en tête de ce README pointe toujours vers
  la dernière release.

## Journal des modifications

### 2026-11-04 — La cuisinière

- Demande de l'utilisateur : la **cuisinière** (`C:\ia image\ennemis\cuisinière et commits\cuisinière.jpeg`, vue de
  face détourée par rembg, `outils/importer_cuisiniere.py` → `images/pnj/cuisiniere.png`) est dans la cuisine, devant
  la table de droite près des fours. Image fixe qui respire ; on lui parle avec E (textes « cuisiniere » de
  `donnees/dialogues.json`, modifiables dans le menu Dialogues ; proposés par Claude).
- `Aventure.COMMIS` : une liste de personnages par image (la cuisine en a deux) ; une ancienne partie reçoit celui
  qui manque à la lecture de la salle.
- Tests : `test_commis_dialogues.gd`, capture 183 (commis et cuisinière).

### 2026-11-04 — Commis, viande des loups, menu Dialogues

- **Commis** (animations de l'utilisateur, `C:\ia image\ennemis\cuisinière et commits`) : le commis 02 (louche)
  dans la cuisine explique comment cuisiner ; le commis 01, dans le cellier droit, dit où trouver des ingrédients.
  Images importées par `outils/importer_commis.py` (repos de face, 145 images à 24 i/s, 320 px de haut). Ils sont
  posés à la création de l'étage et, dans une ancienne partie, à la lecture de leur salle.
- **Loups** : un loup fouillé donne 1 viande crue.
- **Menu Dialogues** dans l'éditeur de zones (F3 ou bouton « Dialogues ») : tous les textes des personnages,
  modifiables. Pour cela, les textes de `rencontres.gd` sont passés dans `donnees/dialogues.json` (nouveau module
  `Dialogues`) : `INFOS_CHEVALIER`, `ASTUCES`, `LORE`, `EFFETS_PACTES` deviennent `infos_chevalier()`, `astuces()`,
  `lore()` (une ligne = une histoire), `effet_pacte()`.
- Fichiers : nouveaux `scripts/logique/dialogues.gd`, `scripts/outils/editeur_dialogues.gd`, `donnees/dialogues.json`,
  `outils/importer_commis.py`, `images/pnj/commis_cuisine_anim`, `images/pnj/commis_cellier_anim` ; modifiés
  `rencontres.gd`, `aventure.gd` (`COMMIS`, `poser_commis`), `presences_salle.gd`, `fouille.gd`, `editeur_zones.gd`.
- Tests : nouveau `test_commis_dialogues.gd`, captures 183-186 (`capture_commis.gd`) ; `test_aventure.gd` et
  `capture_aventure.gd` adaptés.

### 2026-11-04 — Eau : des zones au lieu de points

- Demande de l'utilisateur : l'onglet « Eau » (touche 9) trace des **zones** comme l'onglet « Feux » (couche
  « eaux », bleue, « eau N »). Dans le jeu, le héros dans une zone d'eau peut remplir son seau
  (`SallePeinte.eau_proche`) et voit « Point d'eau : remplir le seau (K) » (« Point d'eau » s'il n'a pas de seau).
- L'éditeur n'a plus de points du tout : la mécanique des points (`POINTS`, `mode_points`, `_bouton_points`) est
  retirée ; les onglets Feux et Eau sont décrits par `ONGLETS_ZONES`. Les anciens points d'eau deviennent de petites
  zones (`SallePeinte.zones_depuis_points`, ex-`zones_feux`).
- Tests : `test_editeur_zones.gd` (zone d'eau tracée, héros dans / hors de la zone), capture 176.

### 2026-11-03 — Feux : des zones au lieu de points

- Demande de l'utilisateur : dans l'éditeur, l'onglet « Feux » (touche 8) trace des **zones** (couche « feux »,
  orange, « feu N »), avec les mêmes gestes que les autres zones ; on déplace une zone en glissant son intérieur.
- Dans le jeu, le héros **dans** une zone de feu peut allumer du bois à la torche (`SallePeinte.torche_proche`) et
  voit l'indication « Torche : allumer du bois (K) » au-dessus de lui.
- Les anciens points (un seul : `bloc_cuisine_manger`) deviennent une petite zone de la taille de l'ancienne portée
  (`SallePeinte.zones_feux`), enregistrée comme zone au prochain Ctrl+S. L'onglet « Eau » reste en points.
- Tests : `test_editeur_zones.gd` (tracé, annulation, ancien point, héros dans / hors de la zone), capture 175.

### 2026-11-03 — Les geôliers ne vont jamais dans les cryptes

- Règle de l'utilisateur. Les cryptes étant un niveau à part, aucun geôlier n'y allait déjà ; la règle est
  maintenant écrite et gardée partout : pose (`ajouter_menace`), marche (`prochaine_salle`, via `fermee_a`),
  déplacements directs (`_deplacer` refuse une crypte), capture, et ménage des anciennes parties (`presences`).
- Test : `test_prisons_cryptes.gd` (aucun geôlier dans les cryptes sur 20 donjons, les 2 geôliers sur l'étage,
  pose, déplacement, marche et ménage refusés/faits).

### 2026-11-03 — Escaliers des passages prison / cryptes sur la carte

- **Signalement de l'utilisateur** : « une seule sortie vers les prisons » dans les cryptes. Vérifié sur sa
  sauvegarde et sur des donjons générés : les 4 passages existent, sont ouverts et se franchissent à pied (les
  14 cryptes, avec ou sans miroir, ont toutes leurs sorties accessibles). Rien ne les distinguait des autres
  sorties.
- **Petit escalier** sur la mini-carte et la carte complète (`Carte.dessiner_escalier`, `_escalier_passage`) :
  collé au côté du passage, pour chaque salle à passage déjà découverte (visitée ou actuelle), sur l'étage
  (fond des couloirs de prison) comme dans les cryptes. Légende « Passage » de la carte complète.
- Titres : « Les cryptes » (mini-carte), « Carte des cryptes » (au lieu de « Carte de les cryptes »),
  « Cryptes — Salle … » dans le bandeau (au lieu de « Étage 101 »). Légende de la carte resserrée (elle passait
  sous « Fermer »).
- Captures 180-182 : `tests/capture_escaliers_carte.gd`.

### 2026-11-03 — Pas de cuisson à la torche ; points d'eau

- **Torche** (règle de l'utilisateur) : on ne grille plus à même une torche ; elle sert seulement à allumer du bois
  pour faire un feu de camp. Griller demande un feu de camp ou la cuisine (et compte comme un des 3 plats du feu).
- **Éditeur** : onglet « **Eau** » (touche 9) pour marquer les points d'eau des salles, comme les torches. Dans le jeu,
  près d'un point d'eau, l'écran de cuisine propose « Remplir le seau » (10 L).
- Fichiers : `cuisine.gd`, `salle_peinte.gd` (`eau_proche`), `menu_navigation.gd`, `menu_cuisine.gd`,
  `editeur_zones.gd` (onglets de points « feux » / « eaux ») ; tests `test_cuisine.gd`, `test_editeur_zones.gd`,
  capture 174 (`capture_cuisine.gd`).

### 2026-11-03 — La cuisine

- **Cuisine** (touche **K**) : on met 1 à 4 ingrédients dans la marmite, on choisit sans feu, grillé, bouilli ou
  mijoté, et on obtient une recette, une mixture ou un plat immonde. Griller : près d'une torche, d'un feu de camp ou
  dans la cuisine. Bouillir : feu de camp (marmite + eau du seau) ou cuisine. Mijoter et le four : seulement dans la
  cuisine. Feu de camp : bois allumé à une torche ou amadou + silex, 3 plats ou 10 minutes. Bouillon, recettes connues
  et à découvrir, pages de livre de cuisine.
- **Intoxication alimentaire** (viande périmée, viande crue) : PV qui baissent toutes les 15 s, régénération
  coupée, mortelle ; une seule mécanique, qui servira à la maladie.
- **Éditeur** : onglet « Feux » pour marquer les torches de chaque salle (à faire par l'utilisateur : sans torche
  marquée, on ne grille qu'au feu de camp ou dans la cuisine).
- **Objets** : pierres en 3 tailles, nouveaux PV (soupe et viande grillée 35, bouillie 30, séchée 25, fruits 15),
  nourriture avec du mana, nouveaux ingrédients et le matériel de cuisine ; le marchand en vend.
- Choix faits par Claude en codant : `CUISINE.md` §8 (brandon 3 min, seau trouvé vide, valeur des plats, marchand…).
- Fichiers : nouveaux `scripts/logique/cuisine.gd`, `maux.gd`, `scripts/ecrans/menu_cuisine.gd`,
  `donnees/cuisine.json`, `outils/cuisine_combinaisons.py`, tests `test_cuisine.gd`, `capture_cuisine.gd` ; modifiés
  `objets_divers.gd`, `objets_divers.json`, `personnage.gd` (régénération), `menu_navigation.gd`, `menu_combat.gd`,
  `menu_inventaire.gd`, `menu_partie.gd` (cause de mort), `salle_peinte.gd` (torches, feu de camp),
  `description_objet.gd`, `marchand.gd`, `editeur_zones.gd`, `CUISINE.md`.

### 2026-11-03 — Conception de la cuisine (document, rien de codé)

- `CUISINE.md` : règles décidées avec l'utilisateur (plats hors combat, pierres en 3 tailles, nouveaux PV, recettes
  connues ou à découvrir, mixtures ×0,5, plats immondes ×0,25, mal persistant réutilisable pour l'intoxication et
  la maladie), puis les propositions à valider : feu, eau, marmite, valeurs cachées des ingrédients et toutes les
  recettes classées.
- Suite (réponses de l'utilisateur) : feu de camp allumé à une torche ou avec amadou + silex (pas de sort de feu),
  3 plats et 10 minutes au plus ; eau infinie dans la cuisine ; mal persistant mortel, durées qui s'ajoutent, compté
  en exploration et en combat mais pas dans les menus. Règles et valeurs dans `donnees/cuisine.json` (que le jeu
  lira) ; **liste complète des 14 949 mélanges** × 4 préparations (recette, mixture ou immonde, PV, mana, raison) :
  `python outils/cuisine_combinaisons.py` → `outils/cuisine/combinaisons.csv` et `resume.md` (dossier avec
  `.gdignore`).

### 2026-11-03 — Butin posé dans l'éditeur, nourriture et ingrédients, catalogue des objets

- **Éditeur de zones, onglet « Butin »** (touche 7 ou onglet en haut à droite) : on pose du butin à un endroit précis
  de la salle (clic), on le déplace (glisser), on le retire (clic droit) ; un **module** à droite définit ce que
  c'est : or (montant ou au hasard), potion (soin, mana, régénération ou au hasard), arme, équipement (armure, bijou
  ou au hasard), objet divers, nourriture ou ingrédient (objet précis du catalogue ou au hasard), nombre, rang.
  Ctrl+Z et Ctrl+S comme pour les zones.
- **Dans le jeu** : le butin est posé au sol (tas d'or, fiole, sac), « Ramasser (E) », une fois par salle du plan.
  Le butin ajouté après une sauvegarde apparaît aussi dans les parties en cours.
- **Inventaire et marchand** : onglets **Nourriture** et **Ingrédients**. La nourriture se mange (double-clic) et
  rend des PV ; les ingrédients serviront à cuisiner. Le marchand en vend.
- **Catalogue** : la liste de l'utilisateur (41 objets) dans `donnees/objets_divers.json`. Prix, PV et classement
  nourriture/ingrédient proposés par Claude, à valider.
- Mentions corrigées : « le catalogue est vide » (règles du README, `objets_divers.gd`).
- Fichiers : `objets_divers.gd`, `objet.gd` (`est_nourriture`, `est_ingredient`), `fouille.gd` (`butins`,
  `_ajouter_butins`, `ramasser`), `salle_peinte.gd`, `menu_navigation.gd`, `menu_inventaire.gd`, `menu_marchand.gd`,
  `marchand.gd`, `description_objet.gd`, `editeur_zones.gd` ; nouveaux : `donnees/objets_divers.json`,
  `outils/dessiner_butin.py`, `images/objets_salles/butin_*.png`, tests `test_butin_pose.gd`, `capture_butin.gd`.

### 2026-11-03 — Karma : Chevalier plus rapide ; capture dans la prison la plus proche

- **Karma négatif** (règle de l'utilisateur) : plus de Chevalier de la mort supplémentaire tous les 5 points ; à la
  place, **chaque point négatif rend le Chevalier de la mort 5 % plus rapide** (dans la salle et d'une salle à
  l'autre). Message « le Chevalier de la mort presse le pas (+x % de vitesse) » quand le karma baisse sous 0,
  « il ralentit » quand il remonte. Anciennes parties : les chevaliers venus du karma repartent.
- **Capture par le geôlier** (règle de l'utilisateur) : le héros se réveille dans la **prison la plus proche** de la
  salle où il a été pris (2e grande salle de la prison, au fond), le coffre des confiscations près d'elle.
- Code : `Karma` (`EFFETS["vitesse_chevalier"]`, `facteur_vitesse_chevalier`, `synchroniser` ; plus de
  `chevaliers`), `Aventure.duree_salle`, `Aventure.cellule_la_plus_proche`, `PresencesSalle._avancer`. Test :
  `test_karma` (vitesse, pas de chevalier de plus, capture sur 12 salles au hasard).

### 2026-11-03 — Prisons aux 4 coins, niveau des cryptes, sorties potentielles

- **Pour le joueur** : un seul étage pour l'instant (les autres sont désactivés). Aux 4 coins de l'étage, une
  **prison** : 2 grandes salles de prison puis un couloir ; au fond du couloir, on descend dans **les cryptes**, un
  niveau à part de 14 salles (squelettes et un seul féticheur élite), avec 4 entrées qui ramènent chacune à sa prison.
  Les cryptes ne sont plus sur l'étage. Le cachot est une grande salle de prison.
- **Éditeur de zones** : touche **O** sur une sortie = sortie **potentielle** (orange). Plusieurs sorties possibles
  d'un même côté : une seule est ouverte à la génération s'il faut une salle de ce côté, les autres sont des murs
  invisibles. Un point d'arrivée resté loin d'une sortie déplacée n'est plus utilisé (le héros arrive devant elle).
- **Images** : 4 couloirs de prison importés (`outils/importer_couloirs_prison.py`, sol détouré, zones à affiner) ;
  prison6 (doublon) et prison8 retirées (`donnees/salles_retirees/`). Retouches de zones de l'utilisateur (cryptes,
  grandes salles, prisons, porte2, porte4, salle1, salle2, cellier).
- **Mesures** (20 à 60 étages) : prisons à 4 cases au plus de leur coin ; étage de 79 à 99 salles (chemins d'accès
  aux prisons compris) ; 0,9 passage sans porte peinte par étage (3,6 avant : les cryptes prenaient les images à
  sorties de côté) ; cryptes : aucun passage sans porte.
- **Code** : `PlanSalles` (groupes réservés, `attribuer_salles`, sorties potentielles, `PASSAGE`, plus de quartier
  des prisons ni des cryptes), `GenerateurEtage` (`_poser_prisons`, `_chemin_acces`, `generer_cryptes`, `coins`),
  `Donjon` (`NOMBRE_ETAGES` = 1, `NIVEAU_CRYPTES`, `est_niveau_unique`, `nom_niveau`, `generer_cryptes`),
  `Aventure._preparer_niveau_unique`, `menu_navigation._changer_de_niveau`, `SallePeinte.ECART_ARRIVEE_MAX`,
  éditeur de zones (touche O). Tests : nouveaux `test_prisons_cryptes`, `test_passage_cryptes` ; adaptés
  `test_aventure`, `test_zones`, `test_boss_cle`, `test_blocs`, `test_grands_etages` (taille, boucles ≥ 3,5),
  `test_cartographie_salles` (une apparence peut resservir), `test_retour_salle` (80 px), `test_quetes_prisonniers`
  (élite+ comparée à la même élite) ; `test_editeur_zones` remet aussi les zones retouchées de porte2 (il les
  écrasait) ; `sonde_prisons` supprimée, `sonde_plan_prisons` ajoutée.

### 2026-11-03 — Amélioration des compétences supprimée ; endurance et mana tous les 2 points

- **Pour le joueur** : l'amélioration des compétences n'existe plus (l'utilisateur va la reforger entièrement) :
  plus de points d'amélioration à la montée de niveau d'une compétence, plus de triangle rouge ni de « Clic :
  améliorer » dans le grimoire, plus d'écran des améliorations ; un grimoire apprend un sort sans l'améliorer (et
  n'apprend rien si le héros connaît déjà tout) ; la pastille de la tuile Magie ne compte plus que les magies à
  apprendre ; l'index des altérations ne cite plus les sources « par amélioration » ; la fiche d'un ennemi ne liste
  plus ses améliorations. Les ennemis n'améliorent plus leurs compétences (avant : de plus en plus à chaque étage, à
  60 % de la force du héros).
- **Endurance** : +5 PV max et +2 PV régénérés par minute **tous les 2 points** (+10 PV et +2 PV/min par point
  avant). **Mana** : +5 mana max et +2 mana régénérés par minute **tous les 2 points** (par point avant). Écran des
  caractéristiques mis à jour (textes, « endurance +x » et « mana +x » des ressources).
- **Ennemis inchangés** (choix de Claude, comme pour le mana le 2026-11-02) : leur endurance est multipliée par 4 à
  la création (mêmes PV : loup 10-20, squelette 20...) et leur Mana passe à 8-12 points (mêmes 20 à 30 mana).
- **Anciennes parties** : les compétences déjà améliorées reprennent leurs valeurs de base au chargement (nom,
  niveau et expérience gardés, `Sauvegarde._oublier_ameliorations`) ; le bonus de PV par endurance du héros passe de
  10 à 5 (les talents acquis restent).
- **Code** : supprimés `scripts/logique/ameliorations.gd` (`Ameliorations`), `scripts/ecrans/menu_ameliorer_competence.gd`,
  `donnees/ameliorations.json`, le champ `points_amélioration` (competences.json, sorts) et dans `Competence` :
  `améliorer_compétence`, `ameliorations_possibles`, les coûts et points d'amélioration ; `Aventure.POINTS_LIVRE`,
  `ameliorer_au_hasard`. Gardés dans `BasesCompetences` (nouveau) : les corrections de base des compétences
  (`BASES`, `preparer`) et les plafonds d'altérations lus par `ValeurCompetences`. `Caracteristiques` :
  `PAR_PALIER`, `POINTS_PAR_PALIER`, `paliers()`. Tests adaptés (test_aventure, test_des_armes, capture_menus).

### 2026-11-02 — La cuisine, refuge sans ennemis

- **Pour le joueur** : aucun ennemi dans le bloc cuisine (salle à manger, cuisine, petite porte, celliers) ; aucun
  gobelin, geôlier ni Chevalier de la mort n'y entre, même en poursuite : la cuisine est un abri. Seuls les PNJ
  neutres y vont (ceux de la cuisine sont en préparation par l'utilisateur).
- Modulable : zone « cuisine » (images `bloc_cuisine*`) avec `"sans_ennemis": true` dans `donnees/zones.json` ; toute
  zone peut devenir un refuge. Code : `Zones.refuge`, `Aventure.salles_pour_ennemis`, `ENNEMIS`, `PNJ_HORS_REFUGE`,
  `prochaine_salle`, `vacarme`, `ecarter_des_salles_paisibles`, `ajouter_menace`, `capturer`, `repousser_geolier`,
  `QuetesPrisonniers.confier_a_elite`, `menu_navigation` (suiveurs). Test : `test_zones` (cuisine vide, 2000 pas
  d'errance des chasseurs attirés vers la cuisine, intrus chassé).

### 2026-11-02 — Quartier des cryptes, zones d'ennemis, 1d2 tous les 2 points

- **Pour le joueur** : les 14 salles « crypte » forment désormais **un seul quartier** de salles voisines sur chaque
  étage (toutes utilisées, une fois chacune), au lieu d'être dispersées. On n'y croise **que des squelettes**, et
  **un seul élite : un féticheur**.
- **Zones modulables** : nouveau fichier `donnees/zones.json` (lu par `scripts/logique/zones.gd`, `Zones`) : pour
  chaque zone (préfixe d'image), sortes d'ennemis, élites, nombre d'élites, chances (pacifique, loup, féticheur).
  « defaut » reprend les anciennes valeurs (`Aventure.CHANCE_ELITE`, `CHANCE_PACIFIQUE`, `CHANCE_GROUPE_SQUELETTES`,
  `CHANCE_FETICHEUR_SQUELETTES`, `CHANCE_LOUP`, supprimées) ; « suite_elite » : escorte d'une élite (gobelins hors
  zone, comme avant ; squelettes dans les cryptes).
- **Caractéristiques** : force, intelligence et sagesse donnent **+1d2 de dégâts tous les 2 points** (et plus à
  chaque point) : `Caracteristiques.POINTS_PAR_DE`, `Formules.des_caracteristique`, textes de l'écran des
  caractéristiques. Les critiques par point (intelligence, sagesse) ne changent pas.
- Fichiers : `plan_salles.gd` (`quartier_cryptes`, `_attribuer_cryptes`, `images_cryptes`, `est_crypte`),
  `aventure.gd` (`nouveau_groupe` avec zone, `_fixer_elites`, `membres`, `ecarter_des_salles_paisibles`,
  `_poser_cle_boss`, départ des chasseurs hors zones), `quetes_prisonniers.gd` (`confier_a_elite`), `creatures.gd`
  (commentaire), `caracteristiques.gd`, `formules.gd`, `menu_caracteristique.gd`, `tests/test_des_armes.gd`,
  `tests/exporter_fiches_ennemis.gd` ; nouveau test `tests/test_zones.gd`.
- Choix de l'utilisateur (questionnaire) : 14 cryptes sans miroir plutôt que 28 avec miroirs, en acceptant ~3,6
  passages sans porte peinte par étage (mesure : `tests/sonde_prisons.gd`, nouvelle sonde). `test_cartographie_salles`
  tolère désormais 5 passages sans porte par étage en moyenne (0 exigé avant) et signale seulement les salles sans
  image exacte ; `test_aventure` tolère 2 prisons hors quartier par étage.
- L'escorte d'une élite suit « suite_elite » (gobelins hors zone, comme avant ; squelettes dans les cryptes).
- Les parties déjà commencées gardent leurs étages (cryptes dispersées, anciens ennemis) : `PlanSalles.VERSION`
  n'est pas augmentée, sinon les salles des blocs seraient ré-habillées au hasard.

### 2026-11-02 — Inventaire des règles des objets ; anneau de Mariane rare

- Nouveau document **`OBJETS_REGLES.md`** : toutes les règles liées aux objets (sortes, emplacements, rangs, options,
  armes et dés bonus, effets uniques, objets spéciaux, défenses, potions, sources, prix, confiscation), numérotées
  O1 à O24, avec les points à trancher ensemble (dégâts des objets en dés plutôt qu'en plats, demandé par
  l'utilisateur).
- Mariane donne un anneau **rare** à l'étage 1 (« +2 » = meilleur rang de l'étage + 2 ; c'était précieux).

### 2026-11-02 — Quêtes des prisonniers, suite ; Récupe

- Prisonnier malade : il **était l'élite** (idée de l'utilisateur). Une fois la cellule ouverte, « Ahahah ! » : un
  élite+ « Faux prisonnier+ » surgit à sa place (action `elite_attaque` avec `depuis_prisonnier` et `nom`).
- Choix validés par l'utilisateur : élite+ aux PV × 1,5, anneau du rang de l'étage + 2, catacombes = salles crypte.
- Récupe : la ligne « + 5 % des PV max de la cible » est retirée (`Ameliorations.BASES`) ; ce bonus n'était jamais
  appliqué. Les sorts de lumière (Lumière apaisante, Égide sacrée, Aube réparatrice, Purification, Miracle) ont le
  même « + % des PV max » affiché sans être appliqué : signalé à l'utilisateur, pas changé.

### 2026-11-02 — Quêtes des prisonniers

- **Pour le joueur** : trois prisonniers à quête dans les cellules de l'étage 1 (pour les essayer) : le vieux
  magicien (bol de soupe), le prisonnier malade (potion, nourriture, clé sur un élite) et Mariane (son amulette,
  sur un élite des catacombes). Textes de l'utilisateur (fautes de frappe corrigées). Voir « Quêtes des
  prisonniers » plus haut.
- **Modulable** : tout est dans `donnees/prisonniers.json` (étapes, répliques, objets, actions, étages) ; le moteur
  `QuetesPrisonniers` le joue. Nouveaux objets : Bol de soupe (nourriture), Clé de la cellule (objet de quête),
  Amulette de Mariane (amulette équipable).
- Branchements : `Aventure._poser_prisonniers` (pose des quêtes), `ennemis_de` (élite+), `laisser_cadavre` /
  `cadavre` (objets de quête sur les corps), `apres_victoire` (événement), `utiliser_objet` (ramasser) ;
  `Rencontres.prisonnier_a_quete` (dialogues, bouton Donner) ; `menu_navigation._suites_quete` (ennemi qui entre,
  combat direct) ; `SallePeinte.point_interieur` ; dessin de l'objet au sol (`presences_salle.gd`).
- Tests : `test_quetes_prisonniers` (0 échec), `capture_quetes_prisonniers` (soupe en cuisine, élite qui entre puis
  combat : 0 échec), `capture_quetes_chevalier` (combat direct contre le chevalier : 0 échec) ; `test_aventure` :
  0 échec.

### 2026-11-02 — Tableau des dégâts de l'écran des stats

- **Pour le joueur** : l'onglet « Dégâts » des caractéristiques n'affichait plus les bons dés (anciens dés par type,
  2d6, 1d12...). Chaque ligne liste maintenant **vos attaques** de ce type (les deux de l'arme équipée, les magies
  apprises) avec leurs dés et leur moyenne par coup, par exemple « Coup de lance 6d2 (9.0) · Balayage 3d2 (4.5) » ;
  le dé bonus d'une arme d'un autre type y apparaît aussi (« dé de l'arme »). Colonnes : + carac. (Nd2), + objets,
  × %, critique.
- La description des armes ne donne plus de dés de base (ils ne servent plus) : « Dégâts perforants + 1d6 de feu ».
- `menu_caracteristique.attaques_du_heros` / `texte_attaques` ; `DescriptionObjet.ligne_des`.

### 2026-11-02 — Mana, coût des sorts et dés de caractéristique

- **Pour le joueur** : un point de Mana donne +5 mana max (au lieu de +10) ; Estafilade, Dard empoisonné et Bourrade
  coûtent 2 mana (au lieu de 1) ; chaque point de force, d'intelligence ou de sagesse ajoute **1d2** de dégâts par
  coup (1,5 en moyenne) au lieu de +2.
- Ennemis : 4 à 6 points de Mana au lieu de 2 ou 3, pour garder leurs 20 à 30 mana (validé par l'utilisateur).
- Les compétences physiques restent à 1 mana (décision de l'utilisateur).
- Écran des caractéristiques, onglet Dégâts : la colonne de la caractéristique affiche « +Nd2 ».
- `Caracteristiques.MANA_PAR_POINT` = 5, `FACES_PAR_POINT` = 2 (remplace `DEGATS_PAR_POINT`) ;
  `Formules.des_caracteristique` ; `test_des_armes` adapté. Tests : dés, aventure, karma, magie écran, soins,
  créatures, cri de guerre : 0 échec.

### 2026-11-02 — Retour dans la salle précédente

- **Pour le joueur** : en revenant dans une salle, le héros réapparaît là où il avait franchi la sortie pour en
  partir, et plus au milieu du bas de l'image (sortie par le bas) ou à un point d'arrivée fixe loin de la porte.
- `menu_navigation._franchir` retient la position du héros par salle voisine (`lieu_sortie`, sauvegardé avec le
  plan) ; `SallePeinte.placer_au_retour` l'y replace, avancé vers l'intérieur hors de la sortie. Première arrivée
  dans une salle : inchangée.
- Nouveau test `tests/test_retour_salle.gd` (12 allers-retours, sorties bas, gauche, droite et du fond : 0 échec) ;
  `test_arrivees` : 0 échec.

### 2026-11-01 — Revue des dégâts, suite

- Enchaînement 3d2 par coup ; Botte secrète 3d2 ; Souffle du chaos 4d2 chaos + 4d2 feu (l'ombre redevient du feu).
- Plus d'étourdissement pour Coup de poing et Enchaînement, ni de base ni dans leurs améliorations (devenu trauma).
- Le gobelin combattant pousse son Cri de guerre quand il est accompagné, et utilise Botte secrète une fois sur trois.

### 2026-11-01 — Revue des dégâts du niveau 1

- Valeurs de l'utilisateur pour toutes les compétences et sorts du héros et des ennemis : **dés propres à chaque
  compétence** (`Formules.DES_HEROS`, `DES_ENNEMIS`, voir « Dégâts aux dés »), nouveau bonus en part des PV max de
  la cible (`Formules.PV_CIBLE_ENNEMIS`, `pourcentage_pv_cible` d'un lanceur) : Soin mineur des gobelins, Lame de la mort.
- Chevalier de la mort : 13d2 tranchant + 15 % des PV max ; mana retiré 6d2 + 15 % du mana max ; la moitié du mana
  retiré en dégâts d'ombre.
- Tempête de feu retirée ; Murmure des ombres renommé Trait de l'ombre ; Souffle du chaos chaos + ombre ; Coup de poing
  sans étourdissement ; soins et sorts retirés au chaman, au féticheur et au sorcier ; élites × 1,4, boss × 1,6.
- `soin_pourcentage_pv` retiré de Soin, Soin mineur et Soin majeur (jamais lu par le combat, seulement affiché).
- Nouvel outil `tests/exporter_revue_heros.gd` (compétences et sorts du héros au niveau 1, avec dégâts moyens).

### 2026-11-01 — Zones de cachette, nouvelles salles retouchées
- **Cachettes** : couche 6 de l'éditeur de zones ; dans une cachette, le héros n'est ni vu ni entendu et les ennemis
  ne l'y poursuivent pas, sauf celui qui le poursuivait tout près quand il y est entré.
- **Salles retouchées par l'utilisateur** : bloc cuisine (salle à manger, cuisine, réserve, cellier droit), crypte8,
  crypte10, crypte11, grande2, grande4, grande5, grande7, porte1, porte3, porte5, prison2 à prison7, prison9.
- Fichiers : `editeur_zones.gd`, `salle_peinte.gd` (`dans_cachette`, `heros_en_cachette`), `presences_salle.gd`
  (`PROCHE_CACHETTE`, `_suivre_cachette`) ; test `test_cachettes.gd`.

### 2026-11-01 — Éditeur de zones plus souple, zones de dialogue des prisonniers, premières salles retouchées
- **Éditeur** : prisonniers en **zones de dialogue** (et non plus en points) ; sorties déplaçables d'un bloc,
  supprimables, ajoutables, direction changeable (D), étiquetées ; changement de salle sans quitter (◀ ▶, liste) ;
  aide affichée (F1 pour la replier) ; héros jamais bloqué hors du sol (P le pose sur le sol, R le ramène au départ).
- **Jeu** : on parle au prisonnier quand le héros est dans sa zone ; une salle dont le nombre de sorties change est
  réattribuée dans les parties en cours.
- **Salles retouchées par l'utilisateur** (en cours, d'autres sessions suivront) : prison1, prison2 (2 prisonniers),
  prison5, grande1, grande5, porte2 (petite porte de gauche retirée), porte6, salle2, et le bloc cuisine (cuisine,
  réserve, cellier droit).
- Fichiers : `editeur_zones.gd`, `aventure.gd`, `presences_salle.gd`, `rencontres.gd`, `plan_salles.gd`,
  `donnees/salles_peintes/*.json`, `outils/zones_manuelles/*.json` ; test `test_editeur_zones.gd`.

### 2026-11-01 — Prisonniers des cellules (ébauche) et leur placement dans l'éditeur
- **Éditeur de zones** : couche **5 « Prisonniers »** (points) pour décider où seront les prisonniers de chaque salle.
- **Jeu** : un prisonnier sur chaque point ; parler (informations de `donnees/prisonniers.json`, vide pour l'instant),
  le tuer (karma −1, corps et âme) ou partir. Quêtes : pas encore.
- Fichiers : `editeur_zones.gd`, `aventure.gd` (`_poser_prisonniers`), `rencontres.gd` (`prisonnier_cellule`),
  `karma.gd`, `presences_salle.gd`, `statistiques.gd`, `donnees/prisonniers.json` ; test `test_editeur_zones.gd`.

### 2026-11-01 — Boss plus loin et fermé à clé, ennemis isolés, « gardien » devient « boss »
- **Boss** à 35-40 salles du départ (15-24 avant), sans raccourci ; sa salle ne s'ouvre qu'avec la **clé du boss**,
  portée par une élite (les diablotins aident à la trouver).
- **Ennemis isolés** en plus des groupes (une salle sans groupe sur six) : ≈ 30 ennemis hostiles par étage.
- Le « gardien » s'appelle **boss** partout (textes du jeu, commentaires, README ; les clés internes ne changent pas).
- Fichiers : `generateur_etage.gd` (`DISTANCE_BOSS`, `_raccourcit`), `aventure.gd` (`CHANCE_ISOLE`,
  `_poser_cle_boss`, `ouvrir_verrou`, clé sur le corps), `rencontres.gd` (indice des diablotins), `objets_divers.gd`,
  `menu_inventaire.gd` ; test `test_boss_cle.gd`.

### 2026-10-31 — « Chef » renommé « élite »
- Le gobelin plus fort qui mène parfois un groupe s'appelle maintenant **élite** partout (nom affiché « Élite … »,
  clé `elite`, `Aventure.CHANCE_ELITE`, `AMES_ELITE`) ; les anciennes sauvegardes sont converties au chargement.
  Origine du « chef » : interprétation de Claude du 2026-10-26 (anciens mini-boss du jeu Python + « équipement sur
  certains ennemis rares » de la liste de l'utilisateur), gardée telle quelle pour l'instant (décision de l'utilisateur).
- Mesures : un étage fait **77 à 83 salles** (80 visées : les salles bonus, le bloc et les cercles font varier le total) ;
  **2,6 groupes hostiles** en moyenne sur le chemin le plus court jusqu'au gardien, **aucun sur 6 % des étages**
  (`GROUPES_PAR_SALLE` : un groupe dans 20 % des salles, décision de l'utilisateur du 2026-10-30).
- Fichiers : `aventure.gd`, `presences_salle.gd`, `gobelin.gd`, `ennemis.gd`, `sauvegarde.gd`, `outils/fiches_ennemis.py`, tests.

### 2026-10-31 — Retours sur le karma
- Le marchand **rachète toujours au même prix** (le karma ne change que ce qu'il vend).
- Karma réglé par des tables faciles à nuancer (`Karma.ACTES`, `EFFETS`, `PALIERS`, `palier`, `acte`), en vue des
  quêtes spéciales du karma négatif.
- Corps : animation de mort jusqu'au bout pour le gobelin blessé achevé ; sortes sans animation de mort couchées sur
  le dos.
- Fichiers : `karma.gd`, `marchand.gd`, `rencontres.gd`, `aventure.gd`, `presences_salle.gd` ; tests `test_karma.gd`,
  `capture_karma.gd` (133 : gobelin achevé).

### 2026-10-31 — Karma, corps à fouiller, âmes
- **Karma** : clémence +1, cruauté −1 ; effets sur les mensonges des diablotins, les prix, l'or gagné, l'accueil des
  diablotins ; un Chevalier de la mort de plus sur chaque étage tous les 5 points négatifs (par paliers, il repart en
  remontant de 5). Remplace l'ancienne règle (« tuer un pacifique = un chevalier de plus » aussitôt).
- **Pacifiques** : les épargner rapporte un peu d'or et parfois un objet ; les tuer donne une âme.
- **Corps** : les ennemis vaincus laissent un corps à fouiller (comme un squelette) ; siphonner son âme le fait
  disparaître. **Âmes** : 1 par ennemi, 3 par chef, 5 par gardien ; 3 âmes = 1 point de caractéristique (les
  triangles rouges de l'écran des caractéristiques reviennent).
- Pas encore fait : quêtes (aucun système de quêtes pour l'instant).
- Fichiers : `scripts/logique/karma.gd` (nouveau), `aventure.gd` (`laisser_cadavre`, `cadavre`, `ames_de`),
  `rencontres.gd` (`epargner_pacifiques`, `accueil_diablotin`, `_noter_moralite`), `fouille.gd` (`fouiller_corps`),
  `personnage.gd` (`gagner_ames`, `distribuer_points`), `marchand.gd` (`prix_rachat`), `presences_salle.gd` (corps),
  `menu_navigation.gd`, `menu_caracteristique.gd`, `menu_marchand.gd`, `salles_bonus.gd`, `statistiques.gd` ;
  tests `test_karma.gd`, `capture_karma.gd`.

### 2026-10-31 — Premier bloc de salles : la cuisine
- **Blocs de salles** (`BlocsSalles`) : des lots d'images reliés porte à porte, posés tels quels dans l'étage ; le
  reste de l'étage reste aléatoire pour l'instant. Premier bloc : **cuisine** (salle à manger, cuisine, réserve,
  deux celliers), un par étage, deux entrées (bas de la salle à manger, arche du fond de la réserve).
- Images importées par `outils/importer_blocs.py` (zones relevées à la main, fond agrandi par IA).
- Fichiers : `scripts/logique/blocs_salles.gd`, `outils/importer_blocs.py` (nouveaux), `generateur_etage.gd`
  (`_poser_bloc`), `donjon.gd` (`_habiller_blocs`), `plan_salles.gd` (images de bloc réservées) ; tests
  `test_blocs.gd`, `capture_bloc_cuisine.gd`, `test_cartographie_salles.gd` (salles de bloc à part).
- À faire : pas encore d'emplacements de squelettes à fouiller dans les salles du bloc (`test_emplacements` : 41
  échecs, 36 avant, comme les prisons et les cryptes).

### 2026-10-31 — Retours sur la v0.3
- Les diablotins ne parlent plus de la **limite de dégâts subis** du Chevalier (elle reste secrète) : 14 informations.
  Si un compte l'avait apprise en v0.3, le glossaire ne la montre plus (`Rencontres.info_ennemi_valide`).
- **Objets divers** : catalogue vidé (l'utilisateur fera la liste) ; `ObjetsDivers.creer(nom, sorte, valeur,
  description)` et `depuis_catalogue(nom)` sont prêts. **Fouille** remise comme avant (50 rien, 35 or, 15 objet).
- Potions des ennemis en pourcentage : validé par l'utilisateur.

### 2026-10-31 — Chevalier caché, glossaire du compte, objets divers, potions, coffre près du cachot
- **Chevalier de la mort** : fiche et info-bulle en « ??? » (aucun chiffre).
- **Diablotins** : le Chevalier est expliqué un élément à la fois (15 informations au lieu de 5, la première ne liste
  plus toutes ses résistances) ; conseil « courir l'attire » corrigé (seul le bruit, chaînes brisées, l'attire).
- **Glossaire** (onglet du journal), lié au compte et gardé après une mort ; un diablotin ne redit jamais une
  information sur un ennemi, même dans une autre partie.
- **Salles pièges** désactivées ; **potions de niveau 1** : 40 PV / 40 mana ; **coffre des confiscations** à 3 salles
  au plus du cachot.
- **Catégorie « Divers »** (inventaire et marchand), clés affichées dans l'inventaire, objets divers trouvés sur les
  squelettes.
- Fichiers : `scripts/noyau/compte.gd`, `scripts/logique/objets_divers.gd` (nouveaux), `rencontres.gd`,
  `journal.gd`, `fiche_ennemi.gd` (interface et écran), `aventure.gd`, `donjon.gd`, `consommable.gd`, `ennemis.gd`,
  `fouille.gd`, `objet.gd`, `description_objet.gd`, `menu_inventaire.gd`, `menu_marchand.gd`,
  `choix_objet_combat.gd` ; tests : `test_aventure.gd` (glossaire, nouveautés), `capture_divers_glossaire.gd`
  (captures 110 à 115).

### 2026-10-31 — Nouvelle version Windows et règle de publication
- Release **v0.2** (version nettoyée) sur LE-Jeu-Godot.
- Règle de publication ajoutée (« Règles de maintenance ») : à chaque commit, seulement LE-Jeu-Godot, .exe refait
  et nouvelle release.

### 2026-10-31 — Grand nettoyage du code
- **Version Python supprimée** (décision de l'utilisateur) : les 188 fichiers de la racine (jeu pygame, `class/`,
  `images/`, `donnees/`, `outils/`, `REFERENCE_JEU.md`, `DOC_*.md`), avec `outils/exporter_donnees.py`,
  `outils/exporter_controle.py` et le test `test_controle` (≈ 290 écarts, la version Godot s'étant écartée).
  Récupérable dans l'historique git. Les commentaires qui renvoyaient aux fichiers .py ont été retirés.
- **Niveaux du héros supprimés** (et plus seulement désactivés) : expérience du héros, montée de niveau, points
  de caractéristique (triangles rouges de l'écran des caractéristiques), points passifs, compteur « Expérience
  reçue ». L'expérience des **compétences** (progression à l'usage) est conservée.
- **Récompenses des ennemis supprimées** : expérience, or et butin à leur mort (`Ennemis.loot`, paliers de
  butin, `Combat.recompence`, ligne « Récompenses » de la fiche d'un ennemi). Le chef d'un groupe lâche toujours
  son objet ; « Boss vaincus » est toujours compté.
- **Code mort retiré** : 21 fonctions jamais appelées (dont `Ui.texte_ombre`, `U.max_par`, `Musique.arreter`,
  `Talents.immunise`, doublon d'une vérification d'`Alterations`), 9 constantes, 13 valeurs de départ du donjon
  jamais lues (`nb_salle_par_etage = 15`, `nb_etages_donjon = 100`, compteurs d'ennemis...), 3 fichiers `.uid`
  orphelins, 9 anciennes images (`pnj/chevalier_1`, `geolier_1` à `4`, `diablotin_1` et `2`, deux images de
  `gobelins/`) et 8 images égarées (`salles_peintes/heros/course/*/idle_*.png`).
- Les anciennes sauvegardes se chargent toujours (les clés disparues sont simplement ignorées).
- Tests : `compiler_tout` et tous les `test_*` à 0 échec, sauf `test_emplacements` (36 échecs, déjà présents
  avant le nettoyage).
- **Deuxième passe** (demande de l'utilisateur) : **sphérier supprimé** (données, écran, tuile « Talents » et
  touche T, test `capture_talents` ; les fonctions sont gardées, voir « Règles du jeu ») ; **ancien mode du
  donjon supprimé** (`Aventure.ACTIF`, `Donjon.menace`, `menace_serieuse`, `compteur_menace` ; `test_descente`
  vérifie maintenant que le gardien reste vaincu) ; lignes « Niveau atteint » et « Talents appris » retirées du
  bilan de fin de partie ; dernières sauvegardes de la version Python effacées (`..\sauvegardes\`).

### 2026-10-31 — Lien de téléchargement
- Lien vers la dernière release Windows en tête de ce README (et du README racine de LE-Jeu-Ultime).

### 2026-10-31 — Version exécutable Windows
- **Le jeu s'exporte en .exe** (demande de l'utilisateur, pour faire jouer d'autres personnes) :
  `exporter_windows.bat` + `export_presets.cfg` ; résultat dans `..\export\` (zip d'environ 650 Mo).
- Correctif : `images/salles_peintes` et `images/objets_salles` ont un `.gdignore`, donc Godot ne les met pas
  dans le .exe. `SallePeinte.chemin` les lit maintenant à côté du .exe dans le jeu exporté (inchangé dans
  l'éditeur) ; le script d'export les y copie. Vérifié : salle du geôlier affichée dans une version exportée.
- Fichiers : `scripts/interface/salle_peinte.gd`, `export_presets.cfg`, `exporter_windows.bat`.

### 2026-10-30 — Donjon complet de 5 étages, quartier des prisons, écran de victoire
- **Donjon généré en entier au lancement** (demande de l'utilisateur) : `Donjon.nouveau` crée les 5 étages
  (`Donjon.NOMBRE_ETAGES`, choisi par l'utilisateur) : plan, images, population ; ≈ 400 salles en 0,6 s.
  Régénérer un étage efface d'abord ses anciens réglages (sinon il restait vide).
- **Victoire** : gardien du 5e étage vaincu puis « Monter » → écran de fin titré « VICTOIRE » (`ecran_mort.gd`,
  cause « victoire » ; `menu_navigation.faire_action`, `principal.gd`).
- **Quartier des prisons** (décision de l'utilisateur) : les images « prison » vont dans le quart de l'étage le plus
  loin du gardien (`PlanSalles.quartier_prisons`), et le cachot est la cellule la plus loin du gardien. Mesuré : toutes
  les prisons dans le quartier, cachot toujours une cellule (vérifié par `test_aventure`).
- Correctifs : « Étage le plus haut » et « Salles explorées » du bilan comptaient les salles de départ de tous les
  étages (marquées visitées dès leur création, donc maintenant les 5 étages) ; la liste du bilan débordait sous les
  boutons de l'écran de fin.
- Fichiers : `donjon.gd`, `plan_salles.gd`, `aventure.gd` (cachot), `menu_navigation.gd`, `principal.gd`,
  `ecran_mort.gd`, `statistiques.gd` ; test `test_aventure.gd` (5 étages, prisons, cachot). Capture 23 (victoire).
- **Fiches techniques des ennemis régénérées** (`python outils/fiches_ennemis.py`) après les changements du jour :
  résistances et faiblesses en pourcentage, groupes de 2 au plus, 80 % de salles vides ; textes du script adaptés.

### 2026-10-30 — Étages de 80 salles
- Demande de l'utilisateur : `GenerateurEtage.TAILLE_ETAGE` 50 → **80** (76 à 83 mesurées), `SALLES_CERCLES` 16 → 26
  (même part de l'étage). La voie départ → gardien garde sa longueur : les salles en plus vont aux branches et aux
  cercles. Carte jusqu'à 22 cases de large (17 avant) : la carte complète s'adapte (capture 22).
- Chaque apparence de salle reste unique par étage (98 apparences, `test_cartographie_salles` : 0 doublon, même
  qualité des portes).
- Correctif révélé par les grands étages : le cachot pouvait tomber pile à la limite de la moitié « loin du gardien »
  (salles à égalité de distance comptées avec la médiane) ; on compte maintenant les salles strictement plus près.
- Restent fixes par étage : 7 diablotins, 2 à 3 cachettes, 2 geôliers, 1 Chevalier, 2 rencontres, 6 salles bonus ;
  les groupes d'ennemis suivent le nombre de salles (20 % des salles ordinaires, ≈ 13 par étage).
- Fichiers : `generateur_etage.gd`, `aventure.gd` (cachot), `test_grands_etages.gd`.

### 2026-10-30 — Chaque apparence de salle une seule fois par étage
- Demande de l'utilisateur : sur les 98 apparences (49 images × miroir), aucune ne revient deux fois dans un étage.
  `PlanSalles.attribuer` répartit désormais les apparences sur tout l'étage d'un coup (affectation au meilleur total
  des scores, méthode hongroise `_affectation`) au lieu de choisir salle par salle ; `VERSION` 7 (les étages déjà
  attribués sont refaits). Environ 56 salles par étage pour 98 apparences.
- Mesuré sur 60 étages (`test_cartographie_salles`, qui vérifie aussi l'unicité) : aucun doublon, aucun passage sans
  porte, toutes les formes qui ont une image exacte la reçoivent toujours, pas de porte condamnée en plus. Les
  cryptes, prisons et grandes salles servent maintenant aussi aux salles à deux passages.
- Fichiers : `plan_salles.gd` (`attribuer`, `_affectation`, `_evaluer`), `test_cartographie_salles.gd`.

### 2026-10-30 — Menu Options, moins d'ennemis, diablotins précis, info-bulles lisibles
- **Menu Options** (`ecrans/menu_options.gd`, `Ecrans.options`) depuis le menu principal et le menu pause : volume de la
  musique de 0 à 100 % (barre, − / +, flèches), enregistré dans `user://options.cfg` (`Musique.regler_volume`).
- **Moins d'ennemis** (décision de l'utilisateur : « très peu ») : 80 % des salles ordinaires sans groupe, 20 % avec un
  seul ; 2 ennemis au plus par groupe, loup compris (`Aventure.GROUPES_PAR_SALLE`, `MAX_PAR_GROUPE`). Environ 8 groupes
  par étage au lieu de 33.
- **Diablotins** : au lieu de « à l'est », ils donnent le chemin depuis leur salle : « à 3 salles d'ici, en partant par
  la sortie de gauche (ouest) » (plus court chemin, `Rencontres.direction`) ; leurs mensonges ont la même forme.
- **Arme de départ sans bonus** (« Épée physique médiocre », `GenerationObjets.generer_arme_nue`) et **coffres des
  salles bonus** à rang étage + 1 (étage + 2 avant), décisions de l'utilisateur.
- **Info-bulles d'objets** : les lignes trop longues passent à la ligne (elles étaient coupées) ; la bulle s'élargit
  puis rapetisse si elle dépasse l'écran.
- Fichiers : `musique.gd`, `menu_options.gd` (nouveau), `ecrans.gd`, `menu_demarrage.gd`, `menu_pause.gd`, `aventure.gd`,
  `rencontres.gd`, `generation_objets.gd`, `personnage.gd`, `salles_bonus.gd`, `description_objet.gd`, `menu_inventaire.gd`.

### 2026-10-30 — Objets : type dans le nom, caractéristique possible sur les armes
- Choix validés par l'utilisateur (salles bonus à +4, pourcentages avant le blocage, pourcentages additionnés,
  options par emplacement). Les armes peuvent aussi donner une caractéristique (poids dégâts 2, caractéristique 2,
  pénétration 1). Chaque objet porte son type dans son nom : physique, magique ou élémentaire (accordé :
  « Bottes magiques communes »), à la place de « runique » et « enchantée ».
- Fichiers : `generation_objets.gd` (`OPTIONS_ARMES`, `ADJECTIFS_ORIENTATION`, `nom_avec_type`), `test_des_armes.gd`.

### 2026-10-30 — Refonte des objets et des résistances
- Règles de l'utilisateur (voir « Défense », « Objets » et « Armure anti-boss » plus haut) : 2 points de défense
  = 1 dégât bloqué, défense générale et résistance spécifique sans cumul, vulnérabilités et résistances en
  pourcentage à part ; résistance au poison supprimée ; objets à une seule option (caractéristique, défense,
  dégâts d'un des 3 grands types, pénétration) ; armes à une famille ; armure anti-boss dans un coffre ancien.
- Ennemis : loup +40 % feu, squelette +40 % contondant et −20 % perforant, chaman −15 % feu/froid/foudre et +40 %
  ombre, boss +50 % / −60 % (mêmes chiffres, en pourcentage) ; objets lâchés par un chaman : élémentaires.
- Écrans : onglet Défense refait (défenses en points, dégâts bloqués et pourcentages pour les 9 types),
  description des objets (nouvelles lignes, « −20 % » pour une résistance en %), inventaire (rés. magique et
  élémentaire), fiche ennemi (vulnérabilités, résistances en points et en %).
- Correctif : le diablotin disait « il se moque de des lames ».
- Sauvegardes de test effacées (accord de l'utilisateur).
- Choix de Claude validés ensuite par l'utilisateur : salles bonus à +4, ordre et addition des pourcentages,
  répartition des options par emplacement.
- Fichiers : `degats.gd`, `generation_objets.gd` (réécrit), `alterations.gd`, `ameliorations.gd`, `formules.gd`,
  `objet.gd`, `objets.gd`, `personnage.gd`, `ennemis.gd`, `gobelin.gd`, `creatures.gd`, `aventure.gd`,
  `rencontres.gd`, `salles_bonus.gd`, `presences_salle.gd`, `description_objet.gd`, `fiche_ennemi.gd`,
  `menu_caracteristique.gd`, `menu_inventaire.gd` ; tests `test_des_armes`, `test_creatures`, `test_aventure`
  (coffre du gardien, une seule option), `exporter_fiches_ennemis`, `capture_menus`. Tous les tests à 0 échec ;
  `test_controle` : 294 écarts avec la version Python (attendu).

### 2026-10-29 — Nouvelles règles des caractéristiques
- Règles de l'utilisateur (voir « Caractéristiques » plus haut) : endurance +10 PV et +2 PV/min, force +2 dégâts
  physiques, dextérité +2 % critique physique, +1 % toucher, +1 % esquive, intelligence +2 dégâts arcane/ombre/chaos
  et +1 % critique magique, sagesse +2 dégâts feu/froid/foudre et +1 % critique élémentaire (nouvelle statistique
  `chance_de_coup_critique_elementaire`), nouvelle caractéristique **Mana** (+10 mana max, +2 mana/min).
  Lumière : la plus forte d'intelligence et sagesse ; poison : pas de critique. Les anciens effets (armure, résistances,
  dégâts critiques, puissance magique, mana de la sagesse) sont retirés.
- Héros : toutes les caractéristiques à 0 (70 PV, 10 mana) ; valeurs de base gardées (toucher, esquive, critique,
  parade). Ennemis : mêmes règles, force/dextérité/intelligence/sagesse à 0, endurance divisée par 5 pour garder leurs
  PV (choix de l'utilisateur), 2 ou 3 de Mana.
- Régénération en minutes réelles pendant l'exploration (`Personnage.regenerer`), arrêtée en combat et dans les menus ;
  plus de régénération en fin de combat.
- Autel de sang : Mana fait partie des caractéristiques possibles (+1, inchangé). Altérations qui changent une
  caractéristique (Vigueur, Sérénité, Sape de force...) : leurs effets suivent les nouvelles règles (`Alterations.CONVERSIONS`).
- Lance de test : jamais confisquée par le geôlier (`Arme.est_lance_de_test`, marque `lance_de_test` ; reconnue aussi
  dans les anciennes parties : rang 0, 100 dégâts perforants).
- Prérequis des sorts corrigés : feu, froid, foudre demandent la sagesse (l'intelligence avant), perforant la force (la
  dextérité avant), lumière l'intelligence ou la sagesse (`Sorts.ATTRIBUT_ELEMENT`).
- Écran des caractéristiques refait : six caractéristiques avec leur effet par point ; ressources et régénérations par
  minute, précision, les trois critiques ; onglet « Dégâts » avec **tous** les types (arcane et chaos compris) : dés,
  bonus de caractéristique, d'objets, pourcentages, moyenne et critique. Plus de niveau ni d'expérience, ni de
  « bonus passifs » (ces points ne se gagnent plus).
- Anciennes parties : la caractéristique Mana est ajoutée à 0 et l'endurance passe à 10 PV par point
  (`Personnage._migrer_caracteristiques`) ; les caractéristiques déjà acquises sont gardées.
- Tests : `test_pv`, `test_des_armes`, `test_creatures`, `test_aventure` (la lance reste au héros) mis à jour : 0 échec,
  sauf la vérification « un chasseur erre de salle en salle » de `test_aventure`, qui dépend de l'étage tiré (elle
  échoue aussi avec la graine 2 ; le tirage a changé avec le Mana des ennemis) ; `test_controle` : 304 écarts avec le
  jeu Python (297 avant) ; `compiler_tout`, `test_descente` 0 échec.

### 2026-10-29 — Musique de fond en boucle
- Demande de l'utilisateur : jouer en boucle la musique de son dossier Musique (« Baldur's Gate Dark Alliance — Elf Song
  Tavern », 2 min 01). Copiée dans `audio/musique/elf_song_tavern.mp3` ; nouvel autoload `Musique`
  (`scripts/noyau/musique.gd`) qui la lance au démarrage, en boucle, à −8 dB, et continue pendant la pause.
- Vérifié : autoload chargé, boucle active, lecture en cours ; `compiler_tout` 0 échec.

### 2026-10-28 — Gobelins : poursuite à 0,85
- Retour de l'utilisateur après essai : poursuivre au pas (≈ 0,15) est trop facile ; poursuite montée à 0,85 hauteur
  de héros par seconde, animation adaptée (`PresencesSalle.COURSE_GOBELINS`, paramètre `course` de `_avancer`, passé
  par l'état « poursuite »). La ronde, la recherche et la fuite des pacifiques restent au pas.
- Test `capture_marches_gobelins.gd` complété (0,85 mesuré) : 0 échec ; `capture_marches`, `capture_aventure`,
  `test_aventure` 0 échec.

### 2026-10-28 — Marches des gobelins branchées dans le jeu
- Demande de l'utilisateur : brancher les marches vues dans l'aperçu. Les gobelins qui se déplacent marchent
  (guerrier, archer, chaman, féticheur), au rythme de leur animation en ronde comme en poursuite (choix de l'utilisateur
  parmi trois : les poursuites deviennent bien plus lentes, environ 0,13 à 0,19 hauteur de héros par seconde au lieu
  de 1,04). Section « Animations du combat ».
- `outils/importer_animations_marche.py` : 4 gobelins (`HAUTEURS` 256 px), clé `visible` dans `animations.json`
  (geôlier réimporté, mêmes images). `scripts/interface/presences_salle.gd` : `marche_gobelin`, `haut_tete` (sortie de
  `_gobelin`), `rapport_marche_gobelin`, `taille_membre`, `vitesse_gobelins`, `_gobelin_en_marche` ; `_avancer` (vitesse
  gardée dans `e["v_marche"]`). Images : `images/pnj/gobelin_<sorte>_anim/` (≈ 31 Mo).
- Test : `tests/capture_marches_gobelins.gd` (capture 110) 0 échec ; `capture_marches`, `capture_aventure`,
  `test_aventure`, `test_creatures` 0 échec.

### 2026-10-28 — Aperçu des marches des gobelins (avant branchement)
- Demande de l'utilisateur : voir les marches faites par Grok pour 4 gobelins avant de les brancher. Nouveaux :
  `outils/apercu_marches_gobelins.py`, `tests/voir_marches_gobelins.gd/.tscn`, `voir_marches_gobelins.bat` (section
  « Animations du combat »). Rien n'est changé dans le jeu. Mesures : 12 img/s ; foulée (hauteur de corps par image)
  archer 0,0235, féticheur 0,0190, guerrier 0,0151, chaman 0,0138.

### 2026-10-28 — Testeur d'étage ; deux bugs trouvés par lui
- Demande de l'utilisateur : savoir en combien de temps on finit l'étage 1. `tests/testeur_etage.gd` +
  `testeur_etage.bat` (section « Testeur d'étage ») : il joue l'étage dans le vrai jeu et écrit un rapport. Ajouts au
  jeu pour lui : `SallePeinte.pilote_actif` / `pilote` (direction donnée comme un stick, ignorée en jeu normal),
  `Auto.actions_combat` et `Auto.journal_combats` (compteurs).
- **Bug corrigé — ennemis inoffensifs après un contact pendant un fondu** : un ennemi qui touchait le héros pendant
  une transition (fondu d'entrée, passage) émettait un contact ignoré par l'écran (passage en cours), mais marqué comme
  émis : plus aucun ennemi de la salle ne lançait de combat jusqu'à la sortie. Le gardien qui touchait le héros à son
  entrée devenait impossible à combattre. Le contact n'est plus émis tant que le héros n'a pas la main
  (`PresencesSalle`, `salle.actif`), et un contact ignoré peut se redéclencher (`menu_navigation._contact`).
- **Bug corrigé — deuxième capture** : `Aventure.capturer` lisait `joueur.arme_equipee` sans protection ; après une
  première capture (arme confisquée, valeur vide), la seconde plantait. Lecture par `U.ga`. Même correction dans
  `tests/test_logique.gd`, qui échouait pour la même raison (il va de nouveau jusqu'au bout).
- **Premiers résultats** (6 parties, graines 2000 à 2003, 28/10) : le testeur **trouve le gardien en 5 à 14 minutes
  estimées** (environ 10 en moyenne), après avoir vu une vingtaine à une quarantaine de salles ; il ne l'a vaincu
  qu'une fois (**15 min 43 s** estimées, 25 salles visitées) : le joueur automatique joue trop mal pour le battre
  (14 fois les PV d'un gobelin, héros sans équipement trouvé) et meurt aussi souvent contre des gobelins seuls. Les
  geôliers l'ont capturé souvent (jusqu'à 7 fois en 10 minutes avant qu'il apprenne à fuir). Sortie abandonnée à
  revoir : **porte6, passage de gauche** (salle et miroir). Ces temps sont des minimums : un joueur réel hésite,
  consulte la carte, fouille, parle aux diablotins et cherche ses affaires après une capture.
- Testeur rendu robuste en chemin : chemin qui évite les autres sorties, retour vers le gardien une fois vu (et
  exploration si le chemin est inconnu), fuite devant les chasseurs, arrêt après 3 défaites contre le gardien, une
  image de jeu au moins par décision (une boucle sans image figeait le temps), rapport écrit après chaque partie.
- `tests/capture_aventure.gd` adapté aux salles paisibles (le diablotin arrive après les gobelins ; il vérifie que
  les gobelins quittent sa salle et que le geôlier reste) : 0 échec ; `test_aventure.gd` 0 échec.

### 2026-10-28 — Salle porte 3 : sol redessiné à la main
- Retour de l'utilisateur (bloqué en jeu dans cette salle) : le détourage automatique ne reliait la porte de gauche
  au sol que par un couloir en biais de quelques pixels derrière le gros pilier, la sortie du fond était sur une
  bosse de sol dans le vide, bords très dentelés. Sol redessiné (`outils/zones.py remplacer porte3 marche 0 ...`) :
  on contourne le pilier par devant pour atteindre la porte de gauche, bord lisse ; un reste d'obstacle retiré.
  `zones.py verifier porte3` : 0 échec (le héros atteint le bord gauche, salle et miroir).

### 2026-10-28 — Grandes salles refaites, lueur sur les sorties praticables
- Retour de l'utilisateur : les grandes salles étaient « un cauchemar » à naviguer. Constat : leurs sorties (posées
  par Claude à l'import) ne correspondaient à aucune ouverture visible (rectangle au milieu du sol, petits carrés
  dans les coins) et le bord du sol (redessiné par Grok le 27/10 avec `outils/zones.py`) avait jusqu'à 147 points.
- `outils/sorties_grandes_salles.py` (nouveau) : pour les 10 grandes salles, relevé à l'œil sur l'image
  (`C:\IA\pont-blender\zones\vues`) : sortie du fond au pied de l'arche, de la porte, de l'escalier ou de l'allée
  visible ; sorties de côté sur une ouverture visible de ce côté (escalier, arche, porte), sinon sur le bord de
  l'image ; sol lisse d'une quinzaine de points qui contient les sorties ; points d'arrivée devant chaque sortie.
  Obstacles et premier plan gardés (piliers des salles 5 et 9), un brasero ajouté en obstacle (salle 4). Écrit dans
  les données et dans `outils/zones_manuelles/` (historique : `python outils/zones.py annuler <id>`).
- **Lueur des sorties** (`SallePeinte._creer_lueurs`, toutes les salles) : calque additif posé sur le décor, sous les
  personnages et le premier plan. Chaque sortie praticable (ni murée ni condamnée : `sortie_praticable`, la liste
  `sorties_condamnees` vient de `definir_portes`) a un rideau de lumière dorée qui monte de son seuil (arche, porte,
  escalier) et une flaque au sol ; une sortie sur le bord de l'image luit le long du bord ; le bas (retour), plus
  discrètement. Pulsation lente (2,6 s). Réglages : `COULEUR_LUEUR`, `INTENSITE_LUEUR` (0,75), `HAUTEUR_LUEUR`.
- Les salles de prison (importées par Grok dans la nuit, mêmes 4 sorties que les grandes salles) ne sont pas
  touchées : l'utilisateur les fera reprendre après Grok, qui travaille dessus.
- Tests : `tests/capture_lueurs.gd` (nouveau, captures 109) 0 échec ; `capture_salles_peintes.gd` 0 échec (un premier
  passage, lancé pendant la modification de `salle_peinte.gd`, avait échoué sur un passage ; son message d'échec dit
  maintenant pourquoi) ; `test_collisions_salles.gd -- grande` : 0 échec (20 salles avec les miroirs : le héros
  court partout sans quitter le sol ni traverser d'obstacle).

### 2026-10-28 — Salles paisibles : diablotin et succube sans autres ennemis
- Demande de l'utilisateur : dans une salle où se trouve un diablotin et/ou une succube, **aucun autre ennemi**, sauf
  les geôliers et le Chevalier de la mort. `Aventure.salle_paisible`, `ecarter_des_salles_paisibles` : à la création
  de l'étage, les groupes de gobelins tombés dans ces salles sont déplacés dans d'autres salles ordinaires (aucun
  perdu, même densité) ; aussi appliqué à la lecture d'une salle (anciennes parties). Les porteurs créés par une
  capture n'y vont pas ; un groupe ou un porteur qui poursuit le héros ne l'y suit pas (`menu_navigation`). Les
  chasseurs vont toujours partout.
- Cachot : repli si tous les culs-de-sac sont plus près du gardien que la moitié des salles (la salle ordinaire la
  plus loin du gardien). Constat : sur les grands étages, 99 fois sur 100 les culs-de-sac sont des salles bonus ou
  celle du gardien, et le cachot était déjà la salle ordinaire la plus loin du gardien (pas un cul-de-sac).
- Tests : `test_aventure.gd` (nouveau `_salles_paisibles` : 20 étages, 160 salles paisibles, aucun intrus même après
  une capture, aucun groupe perdu) 0 échec ; le cachot respecte « loin du gardien » sur 199 étages sur 200 (le dernier
  est un cas limite). Fiches techniques régénérées.

### 2026-10-28 — Chevalier : Usure une fois sur deux, 6d2 de mana retirés
- Demande de l'utilisateur : chaque coup du Chevalier qui touche a **une chance sur deux de poser Usure** (altération
  de la lame, `type_alteration`) et **retire 6d2 de mana** au héros (`Aventure.CHEVALIER` : `usure`, `vol_mana` ;
  `vol_mana_des` sur l'ennemi, lu par `Combat._infliger_degats` pour tout lanceur qui l'a ; pas sur un coup raté ni
  partiel ; jamais plus que le mana restant).
- Affichage : « −N mana » en bleu au-dessus de l'**orbe de mana** (`EffetsCombat.signaler_texte(..., pres_mana)`,
  `EffetsDessin.post_traitement`) ; les autres chiffres du héros restent au-dessus de l'orbe de vie.
- Tests : `test_aventure.gd` mesure 400 coups (Usure ≈ 47 % des coups qui touchent, en comptant celle du tranchant ;
  6 à 12 de mana) ; son test des mensonges des diablotins a maintenant sa propre graine (il échouait ≈ 3 % du temps
  selon le hasard des tests précédents). `capture_combat_chevalier.gd` 0 échec. Fiche technique régénérée.

### 2026-10-27 — Chevalier : retours en garde de Grok, 12d2 tranchant + 6d2 ombre
- Animations de Grok branchées (`C:\ia image\ennemis\chevalier de la mort\retour`) : après chaque attaque il se relève
  jusqu'à sa pose de repos (`retour_A`, `retour_B`), et l'attaque B commence par une courte transition depuis la pose
  de repos (`bonus_debut_B`). Plus de fondu ni de saut : début et fin des attaques identiques au pixel près à la pose
  de repos. `outils/importer_combat_chevalier.py` (341 fichiers).
- **Dégâts : 12d2 tranchant + 6d2 ombre** (demande de l'utilisateur ; 2d12 + 1d2 avant) : 18 à 36 avant armure,
  27 en moyenne, très réguliers.
- Tests : `capture_combat_chevalier.gd` (garde levée à l'impact, épée au coup, il se relève, retour en garde sans
  fondu) 0 échec ; `test_aventure` 0 échec. Fiches techniques régénérées.

### 2026-10-27 — Geôlier et Chevalier au rythme de leur marche (plus de glissade)
- Retour de l'utilisateur : le geôlier glissait sur le sol. Sa marche de Grok est lente (≈ 0,19 hauteur de héros/s à
  12 images/s) alors qu'il avançait ≈ 2 fois plus vite en ronde et 6 fois en poursuite (chevalier : ≈ 3 fois).
  **Choix de l'utilisateur** : tous deux avancent toujours au rythme de leur animation, en ronde comme en poursuite
  (geôlier ≈ 0,19, chevalier ≈ 0,18 hauteur de héros/s ; le héros marche à 0,81) ; et l'image suit la distance
  parcourue (`parcouru`), une foulée par image.
- Foulée mesurée sur les images : Grok a stabilisé la marche sur place, donc dans la vue de profil le pied posé recule
  à la vitesse où le personnage devrait avancer (`outils/importer_animations_marche.py`, `foulee` dans
  `animations.json` : geôlier 0,0137, chevalier 0,0117 hauteur d'image par image).
- Code : `PresencesSalle.vitesse_marche`, `_avancer` (vitesse des marcheurs, distance au sol), `_marche_animee`.
  Le temps de traversée d'une salle hors de vue (chevalier ≈ 9 s, geôlier 6 s) ne change pas.
- Tests : `capture_marches.gd` (2 s de marche = 24 images, pour les deux) 0 échec ; `test_aventure`,
  `capture_aventure`, `compiler_tout` 0 échec ; fiches techniques régénérées.

### 2026-10-27 — Le geôlier marche (animations de Grok)
- Marche du geôlier faite par Grok (`C:\ia image\ennemis\geollier\marche`, 4 vues : dos 46, face 53, profil 52,
  trois quarts 29 images, 12 images/s) branchée dans les salles, comme celle du Chevalier : la vue suit sa direction,
  miroir pour la gauche (profil, trois-quarts), première image quand il s'arrête.
- Code commun aux deux chasseurs : `outils/importer_animations_marche.py` (nouveau ; `importer_animations_chevalier.py`
  l'appelle pour le chevalier) → `images/pnj/<nom>_anim/` + `animations.json` (nombre d'images et cadence, lus par
  le jeu au lieu d'être écrits dans le code) ; `PresencesSalle.MARCHES`, `images_marche`, `vue_marche`,
  `_marche_animee` (remplacent `images_chevalier`, `vue_chevalier`, `_chevalier_anime`). Images fixes gardées.
- Essai à jouer : `voir_geolier.bat` (`tests/voir_geolier.tscn`) : un geôlier fait sa ronde dans la salle de la
  porte 2 ; sa première capture échoue (pacte « baiser »), la suivante mène au cachot.
- Test `tests/capture_marches.gd` (capture 108 : 4 geôliers dans les 4 directions et le chevalier) 0 échec ;
  `test_aventure`, `capture_aventure`, `compiler_tout` 0 échec. Fiche technique du geôlier régénérée.

### 2026-10-27 — Résistances du chaman (fiche de l'utilisateur)
- « particularité des chamans.odt » appliquée : 15 % de résistance au feu, au froid et à la foudre, 40 % de faiblesse
  à l'ombre (`Gobelin.RESISTANCES_PAR_SOUS_CLASSE`, posées par `definir_attribut_gobelin` : chamans ordinaires, chefs,
  porteurs et gardiens chamans ; la faiblesse/force tirée du gardien remplace la valeur de son type).
- L'utilisateur valide les valeurs proposées pour les loups et les squelettes (entrée suivante).
- `test_creatures.gd` vérifie aussi le chaman (20 dégâts bruts → 17 en feu/froid/foudre, 28 en ombre) : 0 échec ;
  `test_aventure` et `compiler_tout` 0 échec ; fiches techniques régénérées (plus d'écart pour le chaman).

### 2026-10-27 — Loups et squelettes, Chevalier à 2d12 + 1d2
- **Loups et squelettes** (`scripts/logique/creatures.gd`, classe `Creatures`), dès le premier étage. Décidé par
  l'utilisateur (fiches dans `C:\ia image\ennemis\loup` et `...\squelette`) : loup faible au feu (−40 %), frappe
  perforant, toujours avec un archer ou un chaman gobelin ; squelette résiste au perforant (20 %), faible au
  contondant (−40 %), frappe 1d10 tranchant, peut être seul, accompagné seulement de squelettes (et d'un féticheur).
  **Proposé par Claude, validé par l'utilisateur** : loup 14–18 PV, morsure 1d8 ; squelette 18–22 PV ; un loup suit 50 % des groupes
  qui ont un archer ou un chaman (`Aventure.CHANCE_LOUP`), 25 % des groupes sans chef ni pacifiques sont des
  squelettes (`CHANCE_GROUPE_SQUELETTES`), un féticheur en mène 20 % à partir de 2 (`CHANCE_FETICHEUR_SQUELETTES`),
  groupe de squelettes plus lent (0,45 au lieu de 0,58, `VITESSE_SQUELETTES`, clé `vitesse_poursuite` de la présence).
- Leurs dés comptent tels quels (`des_fixes`) : précision de l'utilisateur, le « dé un cran plus bas » est un réglage
  fait à la main pour les gobelins, pas une règle pour tous les ennemis. IA : leur seule attaque (`classe` « creature »
  dans `Ennemis.mecanique_ennemis`). Composition des groupes : `Aventure.membres`.
- Images : une image de Grok par créature détourée (BiRefNet, module `rembg`) et cadrée comme les gobelins
  (`outils/importer_loup_squelette.py` → `images/gobelins/loup01.png`, `squelette01.png`) ; image fixe qui respire.
- **Chevalier de la mort : 2d12 tranchant + 1d2 ombre** (2d6 + 1d6 avant), demande de l'utilisateur : « que le joueur
  réalise que c'est un combat ingagnable » (3 à 26 dégâts, 14,5 en moyenne, contre 100 PV).
- Objectif de l'utilisateur : se concentrer sur le premier étage, qu'un joueur moyen termine en environ une heure.
- Incident : `outils/importer_creatures.py` (images fixes du Chevalier et des geôliers) a été écrasé par erreur, puis
  restauré depuis l'historique de la session qui l'avait écrit (avec sa modification « lanternes »).
- Tests : `test_creatures.gd` (nouveau) 0 échec ; `test_aventure`, `test_grands_etages`, `test_pv`, `test_des_armes`,
  `compiler_tout` 0 échec ; captures `tests/capture_creatures.gd` (105 salle, 106-107 combat). Fiches techniques
  régénérées (loup et squelette complètes).

### 2026-10-27 — Fiches techniques des ennemis
- Demande de l'utilisateur : un document par ennemi, dans son dossier, qui décrit tout ce qui le compose.
  `outils/fiches_ennemis.py` + `tests/exporter_fiches_ennemis.gd` (section « Fiches techniques des ennemis ») :
  12 fiches .odt (gobelins : règles communes, guerriers (combattant, lancier, défenseur), archer, sorcier, féticheur,
  chaman ; Chevalier de la mort, geôlier, diablotin, succube ; loup et squelette, pas encore dans le jeu).
- Écart relevé : la fiche du chaman (« particularité des chamans.odt » : 15 % de résistance au feu, au froid et à
  la foudre, 40 % de faiblesse à l'ombre) n'est **pas encore dans le jeu**.
- Relevé aussi en lisant le code : les gobelins possèdent des compétences que leur IA n'utilise jamais (un archer
  a Coup d'épée, Botte secrète et Cri de guerre) ; les fiches les listent à part.

### 2026-10-27 — Héros à 100 PV, ennemis à pleins dégâts
- Décision de l'utilisateur : le héros démarre à **100 PV** (`Personnage.PV_BASE_HEROS` = 70, plus 2 PV par point
  d'endurance comme avant : 30 au départ) ; la réduction commune des dégâts des ennemis est **retirée**
  (`Ennemis.MULTIPLICATEUR_DEGATS_ENNEMIS` 0,68 → 1, constante gardée pour pouvoir la remettre). Gardés, au choix de
  l'utilisateur : les dés des ennemis un cran plus bas que ceux du héros et le plafond des coups subis par le Chevalier.
- Les anciennes sauvegardes gardent leurs PV.
- Tests mis à jour : `test_pv.gd` (100 PV), `test_aventure.gd` (le Chevalier a ses propres animations de combat).
  0 échec : compiler_tout, test_pv, test_aventure, test_descente, test_des_armes, test_butin, test_soins, test_fouille.
  Deux tests échouent pour une raison sans rapport avec ces changements (non vérifié sur la version d'avant) :
  `test_logique.gd` lit `joueur.arme_equipee` sur un héros sans arme ; `test_controle.gd` relève 297 écarts avec le
  jeu Python, dont la version Godot s'est écartée.

### 2026-10-27 — Chevalier de la mort en combat : centré, toutes les images, fin d'attaque en fondu
- Retours de l'utilisateur : mal centré (impression étrange quand il frappe), coupure à la fin de l'attaque, images
  manquantes dans la parade.
- **Centrage** : ancré au milieu du casque (le bas de l'image mêle cape et pointe d'épée) et placé au milieu de
  l'écran, face au héros (`centre_combat`, `MenuCombat.placer_ennemis`) : son épée s'abat sur le héros.
- **Toutes les images** (une sur deux avant), compressées BPTC pour la mémoire ; la garde redescend par toutes
  les images de la montée (une sur trois avant).
- **Parade sans saut** : le coup du héros attend que la garde soit levée (avant, quand le coup arrivait vite, la
  parade démarrait à moitié levée).
- **Fin d'attaque** : les sources s'arrêtent accroupi, épée au sol, sans retour à la pose debout : fondu de 0,35 s
  vers la pose de repos. Une vraie animation de retour (faite par Grok) le remplacerait.
- Tests : `capture_combat_chevalier.gd` 0 échec (garde levée à l'impact, épée au coup, fondu), `capture_combat_anime.gd`
  (gobelins) 0 échec.

### 2026-10-27 — Le Chevalier de la mort animé en combat (attaques et parades)
- Animations de Grok branchées : deux attaques (épée qui s'abat au moment du coup) et deux parades (au lieu
  d'accuser les coups, il lève l'épée à l'horizontale juste avant que le coup du héros arrive). Détails :
  section « Animations du combat ». Les animations du dossier « recevoir dégats » s'appellent « attaque_2_horizontal »
  dans leur notice : elles servent de parade (c'est ce qu'elles montrent).
- Fichiers : `outils/importer_combat_chevalier.py` (nouveau), `outils/importer_animations.py` (l'appelle),
  `scripts/interface/combat_anime.gd` (jeu d'images propre `anim_combat`, parades anticipées, pas de mort
  obligatoire), `scripts/logique/aventure.gd`, `images/combat_anime/gobelins/chevalier/`, `donnees/combat_anime.json`.
- Test `tests/capture_combat_chevalier.gd` (captures 43_chevalier_*) : 0 échec (garde levée à l'image d'impact
  quand le coup du héros arrive, épée qui s'abat au coup du chevalier, deux échanges ; un coup raté ne déclenche
  pas de parade). Godot plante parfois en quittant ce test, après le BILAN (sans effet sur le résultat).
  `tests/capture_combat_anime.gd` (gobelins) : toujours 0 échec. Essai jouable `voir_combat_chevalier.bat`.

### 2026-10-27 — Le Chevalier de la mort frappe vraiment 2d6 tranchant + 1d6 ombre
- Vérification demandée par l'utilisateur. Les dés étaient bons, mais la réduction commune des ennemis
  (`Ennemis.MULTIPLICATEUR_DEGATS_ENNEMIS`, ×0,68) s'appliquait aussi à lui : 1 à 8 tranchant + 1 à 4 ombre
  (moyenne 7,1 au lieu de 10,5). **Correctif** : `Aventure.creer_imbattable` remet ses pourcentages de dégâts
  physiques et magiques à 1.
- Mesuré sur 400 vrais coups (`Combat.infliger_degats`, héros de départ neuf à chaque coup) : 3 à 18 subis,
  moyenne 10,3 ; environ 18 % de coups ratés ; parade du héros (2 %) : moitié des dégâts tranchants. Restent,
  comme pour toute attaque : les altérations du type tranchant (Saignement, Usure) parfois posées sur le héros,
  et un rare critique magique (×1,25 sur l'ombre, 2 coups sur 400).
- `tests/test_aventure.gd` : 0 échec.

### 2026-10-27 — Zones en ligne de commande pour Grok Bot
- L'utilisateur trouve l'éditeur pénible et veut confier les retouches à Grok Bot, qui lance des commandes sur le
  PC : `outils/zones.py` (voir, lister, ajouter, remplacer, deplacer, retirer, couche, annuler, verifier) et sa
  notice `GROK_ZONES.md` (rôle de chaque couleur, règles, méthode). Section « Zones en ligne de commande ».
- Essayé sur grande5 (ajout, refus de retirer une sortie, refus d'un point hors image, annulations : salle revenue à
  l'identique) ; `verifier grande5` : BILAN collisions 0 échec.

### 2026-10-27 — Éditeur de zones : rouvre la dernière salle
- Sans salle demandée, l'éditeur rouvre la dernière salle affichée (`user://editeur_zones_derniere_salle.txt`).
- Pour essayer puis corriger : rester dans l'éditeur (Tab marche / édition), le banc `essai_grande5` ne sert qu'à voir.

### 2026-10-27 — Éditeur de zones : héros caché pendant l'édition
- Le héros masquait la salle : il est caché en édition et revient en marchant (Tab) ; **H** le montre ou le
  cache, **P** le pose sous la souris et le montre.

### 2026-10-27 — Éditeur de zones des salles
- Demande de l'utilisateur : un petit outil pour définir soi-même les zones. `editeur_zones.bat` ouvre
  `scenes/outils/editeur_zones.tscn` (`scripts/outils/editeur_zones.gd`) : tracer, déplacer, retirer les zones de
  sol, d'obstacles, de premier plan et les points des sorties, zoom, annuler, essayer la salle en marchant (Tab),
  enregistrer (Ctrl+S). Commandes : section « Éditeur de zones ».
- Les zones enregistrées vont aussi dans `outils/zones_manuelles/<id>.json`, que `detourer_sols.py` (`detourage`,
  `appliquer`) et `carte3d.py` (`appliquer`) font passer devant leurs propres calculs : plus rien ne les écrase.
- Test `tests/test_editeur_zones.gd` (tracer, Ctrl+Z, déplacer un point, enregistrer puis relire ; remet porte2 comme
  avant) : 0 échec. Vérifié aussi : le fichier réécrit garde toutes les autres données de la salle à l'identique.
  Capture hors écran `tests/captures/62_editeur_zones.png` (`-- <salle> --capture`).

### 2026-10-27 — Banc d'essai jouable de la grande salle 5
- Pour essayer la maquette 3D invisible avant de l'étendre aux autres salles : `essai_grande5.bat` lance
  `tests/essai_grande5.tscn` (script `tests/essai_grande5.gd`) : héros seul dans la grande salle 5, sans ennemis,
  sorties murées, commandes du jeu. **F1** affiche la maquette par-dessus l'image (sol, obstacles, premier plan,
  sorties, emprise des pieds).
- `-- --capture` : capture `tests/captures/61_essai_grande5.png` (maquette visible) puis quitte (vérifié hors écran).
- Correctif : F1 ne faisait rien (l'écran d'exploration garde toutes les touches dans `Ecran._input`) ; elle est
  maintenant lue à chaque image (`Input.is_physical_key_pressed`).
- Aucun changement du jeu lui-même.

### 2026-10-27 — Vue coupée par ce qui n'est pas du sol, sols corrigés à la main dans 3 salles
- **Correctif** : depuis le nouveau détourage, les piliers sont des creux du sol et plus des « obstacles » ; ils ne
  coupaient donc plus la vue des ennemis (on ne pouvait plus se cacher derrière). `SallePeinte.vue_bouchee` : tout
  ce qui n'est pas du sol (pilier, rocher, mur) coupe maintenant la vue. Test `capture_aventure.gd` adapté (il
  cherche lui-même deux points du sol séparés par un pilier).
- **Sols ajoutés à la main** (`REGLAGES[...]["ajouts"]` de `outils/detourer_sols.py`) là où la profondeur se
  trompait : dalles du fond du cul-de-sac 1, allée dallée du fond de la grande salle 10, chemin vers la brume de la
  grande salle 3 (le héros n'atteignait pas le fond).

### 2026-10-27 — Essai : maquette 3D invisible sous la grande salle 5
- Idée de l'utilisateur : reproduire grossièrement l'image en 3D avec des formes simples, posées directement sur
  l'image ; le joueur voit l'image, mais marche sur la maquette. Essai sur **grande5** (`outils/carte3d.py`).
- **Caméra** retrouvée : horizon à la ligne 302 (profondeur de l'image), champ de vision 65°, œil à 2,05 m,
  inclinée de 4,4° vers le haut ; un héros de 1,80 m mesure 184 px au bas de l'image (comme avant).
- **Maquette** : sol, 2 piliers (cylindres de 14 m), socle de mousse, rebord gauche, gravats, rocher, masse du
  bord droit (blocs), chacun posé par des points de l'image au sol. Contrôle :
  `C:\IA\pont-blender\carte3d\grande5_maquette.png` (arêtes de la maquette, quadrillage d'un mètre, héros témoins).
- **Dans le jeu** : la maquette projetée remplace le détourage de la salle : sol praticable, obstacles (emprise au
  sol), premier plan (silhouette des piliers et de la masse : le héros passe derrière et est « Caché »), taille
  du héros à chaque ligne (table de perspective calculée par la caméra). Rien à changer dans le moteur.
  Écrit dans `outils/detourage/grande5.json` (clé `carte3d` : caméra et formes en mètres).
- Test `tests/capture_carte3d.gd` (captures 60_carte3d_N) : devant, derrière les piliers, au fond ; le pied du
  pilier et le rocher arrêtent le héros ; « BILAN carte 3D : 0 échec(s) ».

### 2026-10-27 — Le Chevalier de la mort marche (animations de Grok)
- Dans les salles, le chevalier n'est plus une image fixe : il marche avec les animations de Grok
  (`C:\ia image\ennemis\chevalier de la mort\marche`, 4 vues). La vue suit sa direction : **de dos** s'il
  s'éloigne, **de face** s'il vient vers le spectateur, **profil** ou **trois-quarts** sur les côtés (miroir pour la
  gauche) ; immobile, il garde la première image de sa vue. En combat, son image fixe reste.
- Images recadrées sur une même boîte (les pieds ne sautent pas d'une vue à l'autre), 360 px de haut :
  `python outils/importer_animations_chevalier.py` → `images/pnj/chevalier_anim/` (55 + 31 + 37 + 36 images).
- Fichiers : `outils/importer_animations_chevalier.py` (nouveau), `scripts/interface/presences_salle.gd`
  (`VUES_CHEVALIER`, `vue_chevalier`, `_chevalier_anime`, `t_bouge`). Test des collisions : on peut choisir les
  salles par le début de leur nom (`-- grande`, `-- porte`...), `-- toutes` dépassant 10 minutes. Détourage : réglage
  propre au cul-de-sac 1 (`REGLAGES` : tolérance 9 px) pour inclure le fond du couloir.

### 2026-10-27 — Sols de toutes les salles détourés à nouveau, 7 diablotins, cachot loin du gardien
- **Sols** : les 25 salles (salle 1 et 2, portes 1 à 6, culs-de-sac 1 à 7, grandes salles 1 à 10) ont une nouvelle
  zone de marche calculée sur l'image (profondeur + SAM, voir « Sol détouré automatiquement ») à la place des
  polygones tracés à la main : on marche sur ce qui est du sol dans l'image, les bases de piliers, marches,
  braseros, murs et gravats arrêtent le héros. Points d'arrivée ramenés sur le sol, 13 emplacements de squelettes
  déplacés de quelques pixels.
- **7 diablotins par étage** (décision de l'utilisateur ; 1 à 2 avant).
- **Cachot** : le cul-de-sac le plus loin de la salle du gardien (à au moins 3 salles du départ) ; avant, le plus
  loin du départ, donc souvent à côté du gardien (« les geôliers ne devraient pas me rapprocher autant de la salle
  du boss »).
- Fichiers : `outils/detourer_sols.py` (nouveau), `outils/detourage/` (nouveau), `outils/importer_salles.py`,
  `outils/importer_grandes_salles.py`, `donnees/salles_peintes/*.json`, `donnees/objets_salles.json`,
  `scripts/interface/salle_peinte.gd` (`sur_le_sol`), `scripts/logique/aventure.gd` (`DIABLOTINS_PAR_ETAGE`,
  `CACHOT_DEPART`, choix du cachot) ; test `test_aventure.gd` (7 diablotins, cachot loin du gardien).

### 2026-10-27 — Geôliers : 6 s par salle
- Un geôlier met **6 s** à traverser une salle quand il parcourt l'étage (décision de l'utilisateur ; ≈ 5 s avant,
  tiré de sa vitesse). Le chevalier garde ≈ 9 s. Les autres choix de l'entrée précédente sont validés par
  l'utilisateur. Fichiers : `scripts/logique/aventure.gd` (`DUREE_SALLE`, `duree_salle`), test `test_aventure.gd`.

### 2026-10-27 — Le chevalier et les geôliers parcourent l'étage
- **1 Chevalier de la mort et 2 geôliers par étage** (décision de l'utilisateur ; avant : 0 chevalier à l'étage 1,
  1 ensuite, et 1 geôlier). La colère ajoute toujours des chevaliers.
- **L'étage vit** : le chevalier part du milieu de l'étage, puis le chevalier et les geôliers vont de salle en salle
  au hasard à la recherche du héros, à leur vitesse, dans tout l'étage (seul l'affichage est limité à la salle du
  héros). Ils entrent par la porte de la salle d'où ils viennent et repartent par une porte.
- **Combat** : il attire tous les chasseurs de l'étage vers la salle du héros. **Action bruyante** (chaînes
  brisées) : le chevalier à plus de 3 salles se téléporte à 3 salles et va vers le héros ; les geôliers vont vers la
  salle du bruit sans se téléporter. **Courir** n'alerte plus que les ennemis de la salle (avant : 3 s de course
  faisaient venir le chevalier 5 s plus tard ; supprimé, comme `Aventure.bruit`, `BRUIT_COURSE`, `DELAI_BRUIT` et le
  signal `PresencesSalle.bruit`).
- Choix de Claude, à valider : temps pour traverser une salle (6 hauteurs de héros à la vitesse de poursuite :
  chevalier ≈ 9 s, geôlier ≈ 5 s) ; ils ne vont jamais dans la salle du gardien ; la ronde dans la salle du héros
  dure aussi une traversée avant de repartir ; les chasseurs sont figés pendant les écrans de combat, de dialogue
  et de pause.
- Correctif : à l'ouverture du coffre des confiscations, c'est bien l'arme qu'on portait qui est rééquipée (elle
  est rendue en premier ; avant, une autre arme du coffre pouvait prendre sa place).
- Fichiers : `scripts/logique/aventure.gd` (`CHEVALIERS_PAR_ETAGE`, `GEOLIERS_PAR_ETAGE`, `centre_etage`,
  `chasseurs`, `duree_salle`, `prochaine_salle`, `changer_de_salle`, `avancer_chasseurs`, `attirer`, `vacarme`),
  `scripts/interface/presences_salle.gd` (`faire_venir` par une porte, `chasseurs_en_ronde`, `quitter`, état
  « depart », signal `parti`), `scripts/interface/salle_peinte.gd` (`point_entree`), `scripts/ecrans/menu_navigation.gd`
  (`_faire_vivre_l_etage`, `_chasseur_parti`, `_bruit`, combat qui attire) ; test `test_aventure.gd` (milieu de
  l'étage, errance sur 10 minutes, combat, vacarme, 9 s par salle).

### 2026-10-27 — Grands étages (≈ 50 salles, carrefours, cercles) et grandes salles
- **Étages deux fois plus grands** (décision de l'utilisateur : environ 50 salles, 29 avant ;
  `GenerateurEtage.TAILLE_ETAGE`). Voie principale plus longue (16 salles + étage − 1, au plus 24 ; 12 avant).
  Des **branches** partent surtout des salles à 1 ou 2 passages, qui deviennent des **carrefours** (12 en moyenne
  par étage). Des **cercles** : des tours de salles en rectangle qui partent d'une salle et y reviennent, plus des
  boucles entre deux salles voisines éloignées par le chemin (au moins 6 salles) et quelques petites boucles
  (5 à 6 boucles en moyenne, au moins 2). Salles bonus et marchand comme avant. Mesuré sur 200 étages :
  49 à 51 salles en moyenne, de 47 à 53.
- **Grandes salles** (10 images de l'utilisateur) : tous les carrefours (3 ou 4 passages) reçoivent une grande
  salle, avec une sortie au fond, des passages sur les bords gauche et droit du sol et le retour par le bas. Voir
  « Grandes salles = carrefours » plus haut.
- Choix de Claude, à valider : longueurs des branches (2 à 6), tailles des cercles (1 à 3 cases sur 1 ou 2),
  4 boucles entre salles éloignées, 12 % de petites boucles ; emplacement des sorties de chaque grande salle
  (planche de contrôle) ; hauteur du héros dans chaque grande salle. **Inchangé, à décider** : le nombre de
  Chevaliers de la mort, de geôliers et de diablotins par étage reste le même alors que l'étage a deux fois plus
  de salles (les groupes de gobelins, eux, sont tirés salle par salle et suivent la taille).
- `PlanSalles.VERSION` 6 : les salles des parties enregistrées reçoivent leur image à nouveau (les anciens étages
  gardent leur plan de 29 salles ; seuls les nouveaux étages sont grands).
- Fichiers : `scripts/logique/generateur_etage.gd`, `plan_salles.gd` (`grande_salle`, `BONUS_CARREFOUR`,
  `formes_couvertes` avec les bords), `scripts/interface/salle_peinte.gd` (`fond_hd`),
  `scripts/ecrans/menu_navigation.gd` (bords murés), `outils/importer_grandes_salles.py` (nouveau),
  `donnees/salles_peintes/grande1..10.json`, `images/salles_peintes/grande1..10/` (nouveaux) ; tests
  `test_grands_etages.gd` (nouveau), `test_cartographie_salles.gd` (bords non condamnés), `capture_salles_peintes.gd`
  (grandes salles).

### 2026-10-27 — Diablotins menteurs sur le donjon, diablotin animé
- **Mensonges** (fiche de l'utilisateur `diablotin 1.odt`, fréquence décidée par l'utilisateur) : une réponse à
  « Cet étage ? » sur trois est un mensonge sur le **donjon**, jamais sur les ennemis ni sur les affaires confisquées :
  fausse direction de la cachette ou du pupitre, salle secrète ou coffre plein d'or qui n'existent pas, lame bénie
  « qui blesse le Chevalier de la mort ». Le mensonge va dans le journal comme une vraie information (il y est marqué
  `mensonge` pour les tests, sans que le joueur le voie) ; après une fausse direction, la vraie n'est plus jamais donnée.
  Remplace « ils ne mentent plus » de l'entrée précédente.
- **Diablotin animé** (animations de Grok, `C:\ia image\ennemis\diablotin\diablotin 01`) : il respire en boucle
  dans la salle et **rit** quand le héros s'approche (1,5 hauteur de héros), puis toutes les 8 à 16 s (choix de Claude).
  Il ne flotte plus. Toutes les images sont recadrées sur une même boîte (les pieds ne bougent pas), réduites à
  320 px de haut : `python outils/importer_animations_diablotin.py` → `images/pnj/diablotin_anim/` (48 + 73 images).
  Les anciennes images fixes `diablotin_1/2.png` ne servent plus.
- Fichiers : `scripts/logique/rencontres.gd` (`CHANCE_MENSONGE`, `mensonges_diablotin`, `repondre`, `noter_journal`),
  `scripts/interface/presences_salle.gd` (`ANIMS_DIABLOTIN`, `_rire_diablotin`, `image_diablotin`),
  `outils/importer_animations_diablotin.py` (nouveau) ; test `test_aventure.gd` (mensonges rangés avec l'étage,
  environ 1 sur 3, pas de vérité après un mensonge).

### 2026-10-27 — Chevalier de la mort, diablotins messagers, journal, geôlier et succube en images
- **Le Sans-Visage devient le Chevalier de la mort** (fiche de l'utilisateur) : 300 PV ; chaque coup qu'il subit
  est ramené à 1 ou 2 dégâts (3 sur un critique : `Degats._encaisser`, `plafond_degats`) ; il frappe 2d6 tranchant
  + 1d6 ombre (dés imposés `des_fixes`, pas réduits d'un palier : `Formules.des_type`) ; plus lent que le héros qui
  marche (0,36) ; il traque le héros sur au moins 2 salles (« traque ») ; le **bruit** (3 s de course dans une
  salle, chaînes du prisonnier brisées) fait venir le chevalier le plus proche dans la salle 5 s plus tard
  (`Aventure.bruit`, signal `PresencesSalle.bruit`, `faire_venir`). Image détourée (salle et combat).
- **Diablotins** (fiche de l'utilisateur) : ils ne mentent plus ; ils transmettent au compte-gouttes, sans jamais
  se répéter dans la partie, des informations sur le Chevalier de la mort (ses 5 points, dans l'ordre), l'étage,
  les affaires confisquées après une capture, et des conseils ; 2 réponses par diablotin, puis il disparaît.
- **Journal du joueur** : nouvel écran (`scripts/ecrans/journal.gd`), touche **J** ou menu Pause ; il garde tout ce
  que les diablotins ont appris, par rubrique.
- **Geôlier** en images (4 variantes, provisoires : l'utilisateur les retravaillera) ; **succube** plus grande
  (1,3 hauteur de héros au lieu de 1).
- Images : `python outils/importer_creatures.py [chevalier|geolier]` (nouvel importeur commun : boîte, points et
  objets tenus par image) → `images/pnj/chevalier_1.png`, `geolier_1..4.png`, `images/gobelins/chevalier_de_la_mort.png`.
- Choix de Claude, à valider : vitesse 0,36 ; bruit = 3 s de course cumulées dans une salle ou chaînes brisées,
  arrivée 5 s plus tard ; 2 réponses par diablotin ; textes des conseils ; diablotins qui ne mentent plus (annulé
  le jour même : voir l'entrée « Diablotins menteurs sur le donjon »).
- Fichiers : `scripts/logique/aventure.gd`, `rencontres.gd`, `degats.gd`, `formules.gd`,
  `scripts/interface/presences_salle.gd`, `combat_anime.gd`, `auto.gd`, `ecrans.gd`, `scripts/ecrans/menu_navigation.gd`,
  `menu_pause.gd`, `journal.gd` ; tests `test_aventure.gd` (chevalier, bruit, diablotins), `capture_aventure.gd`
  (capture 104 : journal).

### 2026-10-27 — La succube et ses pactes
- Nouvelle créature, la **succube** (un étage sur deux, à partir du premier) : pas de combat ; elle échange un pacte
  contre des PV max, perdus pour toujours. Petits pactes (25 %) : Voile, Carte de chair, Baiser du geôlier ; grands
  pactes (50 %) : Apaisement, Pacte de mort (détail dans « Ce que contient un étage »). Dialogue en deux temps
  (petits / grands pactes) puis confirmation ; elle disparaît une fois le pacte scellé. Nouvelle statistique
  « Pactes scellés ».
- Images : trois variantes détourées (`python outils/importer_succube.py`, SAM ; une boîte et des points par
  image dans `CORPS`, la queue dans `QUEUES`, miettes retirées) → `images/pnj/succube_N.png`.
- Pacte de mort : la mort se déroule normalement (le combat s'arrête), puis `menu_navigation._apres_action` la
  rattrape (`Aventure.relever_par_pacte`) au lieu d'ouvrir l'écran de fin, et réaffiche la salle du cachot.
- Choix de Claude, à valider : la succube est sur les étages impairs (1, 3, 5...) ; Voile : caché en marchant dans
  l'ombre, pas en courant ; le PV max cédé est pris sur les PV max du moment et les PV actuels sont ramenés au
  nouveau maximum.
- Fichiers : `scripts/logique/aventure.gd` (`PACTES`, `ETAGES_SUCCUBE`, pactes, `_deplacer`), `rencontres.gd`
  (`succube`), `statistiques.gd`, `scripts/interface/presences_salle.gd` (image, vue réduite par le Voile,
  `retirer_parties`), `salle_peinte.gd` (`pacte_voile`), `carte.gd` (`carte_de_chair`, marques),
  `scripts/ecrans/menu_navigation.gd` (Baiser, Pacte de mort, Voile), `outils/importer_succube.py`,
  `images/pnj/succube_1..3.png` ; tests `test_aventure.gd` (`_pactes`), `capture_aventure.gd` (captures 101 à 103).

### 2026-10-27 — Gobelins plus grands et fidèles au combat, portes franchissables tout de suite
- **Taille** : dans les salles, un gobelin mesure 0,8 hauteur de héros (0,55 avant) ; chef et porteur × 1,35, gardien
  × 1,7, comme en combat (`PresencesSalle.TAILLE_GOBELIN`, `Ennemis.MINI_BOSS` / `BOSS["taille"]`).
- **L'image est l'ennemi affronté** : les gobelins d'un groupe, d'un porteur et du gardien sont tirés une fois
  (sorte et image, `Aventure.membres`, gardés dans la présence et donc dans la sauvegarde), dessinés tels quels dans
  la salle, puis recréés à l'identique au combat (`generer_gobelin` / `generer_mini_boss_gobelin` /
  `generer_boss_gobelin` acceptent une [classe, sous-classe] imposée). Lancier et défenseur, sans animation,
  apparaissent avec leur image fixe du combat, qui respire. Les anciennes sauvegardes tirent leurs membres à la
  première lecture.
- **Portes** : on franchit une porte dès qu'elle commence à s'ouvrir, sans attendre la fin de l'animation
  (`SallePeinte.libre` / `porte_fermee` : seule une porte « fermee » arrête le héros).
- Tests : `test_aventure.gd` (le combat oppose les gobelins dessinés), `capture_portes.gd` (passage pendant
  l'ouverture ; la sortie est écoutée dès le premier pas).
- Fichiers : `scripts/interface/presences_salle.gd`, `scripts/interface/salle_peinte.gd`, `scripts/logique/aventure.gd`,
  `scripts/logique/gobelin.gd`, `tests/test_aventure.gd`, `tests/capture_portes.gd`.

### 2026-10-27 — Les gobelins ont leurs images dans les salles
- Dans le donjon d'aventure, les gobelins qui rôdent (groupes, chefs, porteurs, gardien de l'étage) ne sont plus des
  capsules vertes : ils sont dessinés avec les animations de repos du combat (guerrier, archer, sorcier, chaman,
  féticheur), qui respirent, et se tournent dans le sens où ils marchent. Chaque gobelin prend une sorte tirée de son
  numéro ; le chef et le gardien gardent leur couronne (posée sur la tête), le porteur son sac, les pacifiques sont
  plus pâles. Le gobelin blessé est la dernière image de l'animation de mort, dans une flaque de sang.
- L'apparence ne disait pas encore la sorte de gobelin qu'on affronte (corrigé le même jour, entrée ci-dessus).
- Fichiers : `scripts/interface/presences_salle.gd` (`SORTES_GOBELINS`, `TEINTE_PACIFIQUE`, `_gobelin`).

### 2026-10-27 — Le diablotin a son image
- Dans les salles du donjon d'aventure, le diablotin n'est plus un triangle violet : il est dessiné avec les images
  générées (`C:\ia image\ennemis\diablotin`), détourées. Chaque diablotin prend une des deux variantes (selon son
  numéro), se tourne vers le héros et flotte légèrement ; même taille qu'avant (0,5 hauteur de héros). Le texte de
  la conversation dit désormais « diablotin rouge » (et non plus violet).
- Nouvelle image = la déposer dans le dossier source puis `python outils/importer_diablotin.py` (détourage SAM, GPU ;
  une boîte par image dans `BOITES`, la fourche fine dans `FOURCHES`) ; ajouter le fichier à `IMAGES_DIABLOTIN`.
- Fichiers : `outils/importer_diablotin.py`, `images/pnj/diablotin_1.png`, `diablotin_2.png` (nouveaux) ;
  `scripts/interface/presences_salle.gd` (`IMAGES_DIABLOTIN`, dessin du diablotin), `scripts/logique/rencontres.gd`.

### 2026-10-26 — Décor 2D « salle porte 2 » et assemblage
- La salle porte 2 devient un décor 2D en calques identique à l'image (portes séparées, bougie qui vacille,
  poussière), et une nouvelle salle symétrique 16/9 est composée avec ses sprites. Pas encore utilisées par le jeu.
- Fichiers : `assets_2d/salle_porte_2/*`, `scenes/2d/salle_porte_2_2d.tscn`, `scenes/2d/assemblage_salle_porte_2.tscn`,
  `scripts/2d/flamme.gdshader` (nouveaux) ; `scripts/2d/decor_2d.gd` (vent, flammes, particules réglables),
  `tests/capture_entree_ruine_2d.gd` (5 captures).

### 2026-10-26 — Décor 2D « entrée en ruine »
- L'image de référence de l'entrée en ruine devient un décor 2D en calques : 16 sprites (piles, arcs, murs du fond,
  sol, fougères, fond de forêt) et une scène `scenes/2d/entree_ruine_2d.tscn` identique à l'image, avec vent dans les
  fougères et pollen en option. Pas encore utilisée par le jeu.
- Fichiers : `assets_2d/entree_ruine/*`, `scenes/2d/entree_ruine_2d.tscn`, `scripts/2d/decor_2d.gd`,
  `scripts/2d/vent_vegetation.gdshader`, `tests/capture_entree_ruine_2d.gd` (nouveaux).

### 2026-10-26 — Assets 3D « entrée en ruine »
- Nouveaux assets 3D générés dans Blender (41 `.gltf` dans `assets_3d/entree_ruine/`) et scène 3D
  `scenes/3d/entree_ruine.tscn`, reproduction de l'image `mvpaev34yv4my7.jpeg` de la banque « entrée en ruine ».
  Pas encore utilisés par le jeu. Version 2 : scène refaite pour coller à l'image (48 assets, 99 instances),
  brouillard allégé ; les textures découpées dans l'image ont été abandonnées.
- Fichiers : `assets_3d/entree_ruine/*`, `scenes/3d/entree_ruine.tscn`, `scripts/3d/scene_assets_blender.gd`,
  `tests/capture_entree_ruine.gd` (nouveaux).

### 2026-10-26 — Moins de grimoires, sorts tirés au hasard, arme gardée après une capture
- **Pour le joueur** : environ 0,7 grimoire par étage au lieu de 2 à 3 (pupitre un étage sur deux, plus de
  grimoire garanti dans les cachettes, un gobelin soigné donne plutôt une clé). Un grimoire apprend un **sort au
  hasard, déjà amélioré** ; on ne choisit son sort qu'au début de la partie (le Grimoire ne propose plus d'en
  apprendre). Après une capture, **l'arme se retrouve toujours** dans le coffre des confiscations.
- `Aventure` (`CHANCE_PUPITRE`, `CONTENUS_CACHETTES`, `CHANCE_LIVRE_GOBELIN`, `POINTS_LIVRE`, `lire_livre`,
  `ameliorer_au_hasard`, `capturer`), `Rencontres`, `menu_magie` (message) ; `test_aventure.gd`.

### 2026-10-26 — Ennemis qui rôdent plus lents
- **Pour le joueur** : les ennemis des salles marchent et poursuivent environ 20 % moins vite (demande de
  l'utilisateur). Ronde 0,28 → 0,22 ; poursuite : gobelins 0,72 → 0,58, porteur 0,62 → 0,5, Sans-Visage
  0,55 → 0,45, geôlier 0,8 → 0,64, gardien 0,6 → 0,48 (× la vitesse de course du héros, qui marche à 0,45).
- `PresencesSalle.VITESSE_RONDE`, `VITESSE_POURSUITE`.

### 2026-10-26 — Le donjon d'aventure (exploration à la Fear & Hunger)
- **Pour le joueur** : on n'est plus attaqué en entrant dans une salle. Les ennemis y **rôdent, visibles** (formes
  simples en attendant leurs animations) : on peut les contourner, se cacher (immobile dans l'ombre, piliers entre
  eux et soi), fuir, ou foncer sur eux pour combattre. Repéré, on est poursuivi, parfois jusque dans la salle
  suivante. Nouveau bouton **« Fuir »** en combat. Les ennemis **ne donnent plus rien** et il n'y a **plus de
  niveaux** ; sorts (grimoires) et équipement se trouvent en explorant : pupitre, râtelier, cachettes secrètes,
  coffres, chefs de groupe. **Sans-Visage** invulnérables et **geôliers** (capture : réveil au cachot, affaires
  dispersées dans l'étage, certaines sur des porteurs). **Diablotins** menteurs une fois sur deux, **choix moraux**
  (gobelin blessé, prisonnier, autel de sang), **gobelins pacifiques** à ne pas tuer, **clés** et salles bonus
  verrouillées (cadenas sur la carte). Le boss garde sa salle ; « Monter » une fois le gardien vaincu.
  Les messages longs passent à la ligne. Valeurs choisies par Claude, à valider (tableau plus haut).
- Nouveaux : `Aventure`, `Rencontres`, `PresencesSalle`, `ecran_dialogue.gd`, `FEUILLE_DE_ROUTE_AVENTURE.md` ;
  modifiés : `Donjon` (plus de combat d'office, `boss_vaincu`), `Combat` (`issue`, `tenter_fuite`, `chance_fuite`),
  `Degats` (invulnérable), `Ennemis.mort_au_combat` (récompenses désactivées), `Personnage.verifier_montee_niveau`,
  `SallePeinte` (ombre, vue coupée, présences), `menu_navigation` (contacts, E, verrous, poursuivants), `menu_combat`
  (« Fuir », silhouette sombre), `SallesBonus` (coffre verrouillé meilleur), `Carte` (cadenas), `Ui.message`
  (retour à la ligne), `Statistiques` (fuites, captures, pacifiques tués, cachettes, grimoires), `Auto` (fuit le
  Sans-Visage) ; tests `test_aventure.gd`, `capture_aventure.gd`, `sonde_cachettes.gd`, `test_logique.gd` et
  `test_descente.gd` adaptés.

### 2026-10-20 — Coffres et étagères retirés de la fouille
- **Pour le joueur** : il ne reste que les squelettes à fouiller dans les salles ; les coffres et les
  étagères, qui juraient avec le décor peint, n'apparaissent plus (même dans une partie déjà commencée).
  Les potions, l'aiguille piégée et le vieux plan qu'ils donnaient disparaissent avec eux. Les coffres des
  salles bonus (« Coffre découvert ! ») ne changent pas.
- `Fouille` (règles du squelette seules, nettoyage des anciens tirages), `SallePeinte` (plus d'objet
  accroché au mur), `donnees/objets_salles.json` (30 emplacements de squelette), `outils/importer_objets.py`,
  images `coffre_*` et `etagere_*` supprimées ; tests `test_fouille.gd`, `capture_fouille.gd`.

### 2026-10-20 — Boss à 1 PA, dés des ennemis d'un palier plus bas
- **Pour le joueur** : le boss n'agit plus qu'une fois par tour ; tous les ennemis font moins mal, chaque
  dé de dégâts descendant d'un palier (1d12 → 1d10, 1d10 → 1d6, 1d6 → 1d4, 1d4 → 1d2).
- Choix proposés par Claude, validés par l'utilisateur le 2026-10-20 : 1d2 reste 1d2 (pas de palier plus bas) ; 1d8 (dé bonus d'arme
  de rang 4, absent de la liste) devient 1d6 ; les soins des ennemis (lumière) ne sont pas réduits.
- Fichiers : `scripts/logique/formules.gd`, `scripts/logique/ennemis.gd`, `tests/test_des_armes.gd`.

### 2026-10-20 — Fouille des salles
- **Pour le joueur** : des coffres, des squelettes et des étagères apparaissent dans les salles (0 à 2 par
  salle, au hasard, 4 variantes de chaque). En s'approchant, « Fouiller (E) » : or, potions, un équipement
  sur un squelette, un vieux plan qui dévoile la carte de l'étage... ou une aiguille piégée dans un coffre.
  Chaque objet ne se fouille qu'une fois. Les 3 anciennes images d'essai sont remplacées par les 12 nouvelles.
- `scripts/logique/fouille.gd` (règles, tirage), `SallePeinte` (objets posés sur leurs emplacements, portée
  de fouille), `menu_navigation.gd` (invite, touche E / bouton X), `Carte.etats_salles` (salles dévoilées),
  `Statistiques` (« Objets fouillés »), `donnees/objets_salles.json` (34 emplacements), `outils/importer_objets.py`
  (détourage des fonds unis), tests `test_fouille.gd`, `test_emplacements.gd`, `capture_fouille.gd`
  (`capture_objets.gd` retiré).

### 2026-10-20 — Premiers objets posés dans les salles (essai)
- **Pour le joueur** : un squelette assis contre un pilier et une niche murale (livres, poteries) dans la
  salle porte 5, un coffre dans la salle porte 1. On passe devant ou derrière eux, on ne les traverse
  pas. Pas encore d'interaction (la fouille reste à définir).
- `outils/importer_objets.py` (images nettoyées dans `images/objets_salles/`), `donnees/objets_salles.json`,
  `SallePeinte` (objets, ombres, emprise), test `tests/capture_objets.gd`.

### 2026-10-20 — Arrivées cohérentes dans la salle porte 6
- **Pour le joueur** : en entrant dans la salle porte 6 par le côté gauche (ou droit en miroir), on
  arrive devant la porte, plus devant le passage sans porte (on repartait ensuite par la porte, ce qui
  cassait l'immersion). En revenant dans une salle déjà quittée, on réapparaît devant l'ouverture par
  laquelle on en était sorti.
- `PlanSalles.sortie_vers` : ouverture prise (`sortie_prise`), sinon porte plutôt que passage
  (`types_sorties`, nouveau champ des .json de salle écrit par `outils/importer_salles.py`), sinon la
  première. `menu_navigation._franchir` retient la sortie prise.
- Nouveau test `tests/test_arrivees.gd` : 8 713 passages sur 40 donjons × 3 étages, 1 529 avec deux
  ouvertures vers la même salle (567 en salle porte 6) ; 0 échec ; aucun passage sans porte peinte.
- Fichiers : `scripts/logique/plan_salles.gd`, `scripts/ecrans/menu_navigation.gd`,
  `outils/importer_salles.py`, `donnees/salles_peintes/*.json`, `tests/test_arrivees.gd`.

### 2026-10-20 — Zones des salles revues, premier plan détouré au pixel
- **Pour le joueur** : le héros n'est plus coupé par des rectangles quand il passe derrière un pilier,
  un mur ou des éboulis : les 13 salles « porte » et « cul-de-sac » ont maintenant un premier plan
  détouré au pixel (comme les salles 1 et 2). Plus de mur invisible entre les deux portes de gauche
  de la salle porte 2 ; la porte de gauche de la salle porte 3 n'est plus cachée derrière le décor
  (on l'atteint par l'avant) ; le passage de gauche de la salle porte 6 s'atteint facilement.
- Corrections faites dans `test_salle` (voir son README), puis réimport (`outils/importer_salles.py`).
  Toutes les sorties ont au moins 40 points franchissables (sonde sur chaque salle et son miroir).
- Nouvel outil `outils/affiner_premier_plan.py` : affine les polygones de premier plan d'une salle de
  test_salle en masque au pixel (GrabCut d'OpenCV, `pip install opencv-python-headless`), l'installe
  avec ses miroirs ; aperçus `tests/captures/premier_plan_<id>.png`.
- Fichiers : `donnees/salles_peintes/*.json`, `images/salles_peintes/*/masque.png` et `piliers.json`,
  `outils/affiner_premier_plan.py`.

### 2026-10-20 — Course du héros refaite dans toutes les directions
- **Pour le joueur** : nouvelle animation de course de dos, de face et en diagonale (refaite par Grok
  dans `C:\ia image\personnage pour donjon\animation de course\` ; anciennes versions rangées dans
  `ancien_dos\` et `ancien_bras\`), en plus du profil refait plus tôt. Même format (8 images de
  448 × 448 par direction, pieds sur la même ligne) : rien à régler dans le moteur. Marche,
  respiration et animations de combat inchangées.
- Fichiers : `images/salles_peintes/heros/course/` (copiés par `outils/importer_salles.py`,
  `importer_heros`).

### 2026-10-20 — Les portes ne s'ouvrent plus toutes seules
- **Pour le joueur** : une porte s'ouvre seulement quand on marche vers elle pour la franchir. Avant,
  elle s'ouvrait dès que le héros passait près d'elle, ou dès l'arrivée dans certaines salles (porte
  voisine de celle par où l'on entre).
- `SallePeinte._pousser_porte` (appelée à chaque pas) remplace le déclenchement par la distance
  (`PORTEE_PORTES` supprimée) ; `PORTEE_POUSSEE` = 0,15 hauteur du héros, car le bord du sol arrête
  souvent ses pieds 4 à 8 px avant la zone de la porte.
- `tests/capture_portes.gd` : héros immobile devant une porte → elle reste fermée ; il marche vers elle
  → elle s'ouvre, puis il la franchit ; arrivée par la porte de gauche de la salle porte 2 → la porte du
  fond reste fermée.
- Fichiers : `scripts/interface/salle_peinte.gd`, `tests/capture_portes.gd`.

### 2026-10-20 — Nouvelle course de profil
- **Pour le joueur** : le héros court vers la gauche et la droite avec la nouvelle animation de profil
  (refaite dans `C:\ia image\personnage pour donjon\animation de course\`, l'ancienne est rangée dans
  `ancien_profil\`). Mêmes dimensions (8 images de 448 × 448, pieds sur la même ligne) : rien à régler
  dans le moteur. Les 6 autres directions sont inchangées.
- Fichiers : `images/salles_peintes/heros/course/left/`, `.../right/` (copiés par
  `outils/importer_salles.py`, fonction `importer_heros`).

### 2026-10-20 — Idées pour varier la boucle de jeu
- `IDEES_GAMEPLAY.md` : 8 propositions (fouille des salles, choix avant le combat, événements à
  choix, portes et clés, pièges à éviter, objectif par étage, ennemis variés, progression entre
  parties), avec un tableau de suivi. Rien n'est codé : les règles restent à décider.

### 2026-10-20 — Portes qui s'ouvrent dans les salles peintes
- **Pour le joueur** : en s'approchant d'une porte peinte qui a son animation (8 portes des salles
  porte 1 à 5), on la voit s'ouvrir avant de la franchir ; elle reste ouverte ensuite, et la porte par
  laquelle on arrive est déjà ouverte. Les portes condamnées restent fermées.
- Correctif : la « porte du mur » de la salle porte 4 était impossible à franchir (sa zone de sortie
  s'arrêtait 1 px au-dessus du sol praticable). Zone corrigée dans `test_salle/porte4.json` (et son
  miroir), puis réimportée.
- `outils/importer_salles.py` : copie les animations des portes (réduites à 0,75, ≈ 36 Mo) et écrit
  `portes_animees` ; cherche par son nom un fichier source déplacé (l'image de la salle 1 a été rangée
  dans `salle 1\`, `test_salle/salle.json` pointe encore vers l'ancien emplacement).
- Nouveau test `tests/capture_portes.gd` (captures 60 à 68).
- Valeurs choisies par moi, à ajuster si besoin : `VITESSE_PORTES` = 1,5 (et `PORTEE_POUSSEE` = 0,15,
  voir l'entrée suivante).
- Fichiers : `scripts/interface/salle_peinte.gd`, `scripts/ecrans/menu_navigation.gd`,
  `outils/importer_salles.py`, `donnees/salles_peintes/porte1..5.json`,
  `images/salles_peintes/porte1..5/portes/`, `tests/capture_portes.gd`.

### 2026-10-20 — Dé bonus réservé aux attaques de l'arme, « +x % d'un élément » corrigé
- **Pour le joueur** : le dé bonus d'une arme ne s'ajoute plus qu'à ses attaques (Coup d'épée,
  Frénésie, Coup de lance, Balayage, Coup de marteau, Fracasser) ; les sorts gardent leurs propres
  dés (Marteau de givre lancé avec un marteau n'en profite plus). L'amélioration « +x % de dégâts de
  foudre » (ou d'un autre élément) ne joue que si la compétence inflige déjà cet élément : elle ne
  lui ajoute plus les dés complets de l'élément (un point doublait les dégâts de Transpercer).
- Correctif : l'estimation des dégâts (fiche ennemi, équilibrage) ne compte plus deux fois un
  élément présent à la fois dans la compétence et dans le dé bonus.
- Noté en tête des « Différences voulues » : sphérier et améliorations de compétences obsolètes,
  à reforger entièrement.
- Limite : une compétence d'une ancienne sauvegarde qui avait déjà reçu un « second élément »
  garde ce type de dégâts en plus.
- Tests : `test_des_armes.gd` vérifie le dé bonus (attaque de l'arme / sort) et le pourcentage
  d'élément (Transpercer inchangé, Éclair × 1,05).
- Fichiers : `scripts/logique/formules.gd`, `combat.gd`, `ameliorations.gd`, `competence.gd`,
  `equilibrage.gd`, `tests/test_des_armes.gd`.

### 2026-10-19 — Cul-de-sac animés, sol et collisions retracés
- **Pour le joueur** : les 7 cul-de-sac (et leurs miroirs) sont animés avec leurs vidéos
  (`salle cul de sac N/couloirN_boucle.mp4`, 15,75 s en boucle, 1088×720 ; cadrage identique à l'image
  fixe, vérifié). Le sol praticable a été retracé sur la vidéo : le héros marche sur les dalles et le tapis
  jusqu'au bord du précipice, et bute sur les marches au pied des piliers et sur les massifs de
  végétation.
- Nouveau test `tests/test_collisions_salles.gd` : dans chaque cul-de-sac et son miroir, le héros court
  dans les 8 directions et en zigzag ; ses pieds restent sur le sol à chaque image (0 échec) et il atteint
  le bord du fond (3 à 5 px près). Captures 59.
- Fichiers : `outils/importer_salles.py` (vidéos des cul-de-sac dans `VIDEOS`),
  `donnees/salles_peintes/culdesac*.json`, `images/salles_peintes/culdesac*/decor.ogv`,
  `tests/test_collisions_salles.gd`.

### 2026-10-19 — Décor animé : la vidéo en pleine résolution
- **Pour le joueur** : les salles sont nettement plus belles. Le décor animé est maintenant la vidéo de
  la salle lue directement, en 1088×720 (720×480 pour la salle 1), au lieu de 145 à 666 images réduites
  à 768×512 et compressées en DXT1 (trame visible, couleurs ternes, détails brouillés). Mesure sur la
  salle porte 5 : 38,8 dB de fidélité à la vidéo d'origine contre 32,4 dB avant (PSNR).
- Plus de préparation des décors à l'entrée des salles ni de salles voisines gardées en mémoire : une
  vidéo démarre tout de suite (l'image fixe reste affichée jusqu'à sa première image). Mémoire : quelques
  Mo au lieu de 130 Mo par salle (650 Mo au plus avant).
- Le premier plan (piliers, braseros et flammes de la salle 2) est découpé dans la vidéo comme il
  l'était dans les images ; miroir et fond du combat aussi animés par la vidéo.
- `outils/importer_salles.py` : convertit la vidéo d'origine de chaque salle (table `VIDEOS`) en Theora
  (`decor.ogv`, qualité 9, sans son ; seulement si la source a changé) et supprime les anciens dossiers
  `decor/` ; `images/salles_peintes/` passe d'environ 300 Mo à 84 Mo. Cadrage vérifié : les vidéos et les
  anciennes images se superposent exactement (écart moyen 2 à 3 sur 255, bruit JPEG).
- Les cul-de-sac n'avaient pas encore de vidéo (ajoutée le même jour, voir l'entrée suivante).
- La démo de comparaison (`tests/demo_qualite.gd`, images BC7) a été retirée : choix fait (option A).
  Option B (BC7) écartée : 33,4 dB seulement (la perte venait surtout de la réduction à 768×512),
  253 Mo sur le disque par salle.
- `test_salle` (banc d'essai) garde ses images de décor : rien n'y change.
- Fichiers : `scripts/interface/salle_peinte.gd` (`lecteur_video`, `decor_pret`, `nouveau_lecteur`,
  `video_prete` ; supprimés : `decors`, `Preparation`, `garder`, compression DXT),
  `scripts/ecrans/menu_navigation.gd`, `scripts/ecrans/menu_combat.gd` (`video_fond_peint`),
  `outils/importer_salles.py`, `donnees/salles_peintes/*.json` (`decor_video` au lieu de
  `decor_anime`), `tests/capture_salles_peintes.gd` (la vidéo s'affiche et avance).

### 2026-10-19 — Démo : qualité du décor animé
- Rien ne change dans le jeu. Démo pour choisir comment afficher le décor animé (salle porte 5) :
  `tests/demo_qualite.gd` (ou double-clic sur `tests/demo_qualite/lancer_demo.bat`), touches 1 à 4 :
  actuel (666 images 768×512 en DXT1), A (vidéo lue directement, `.ogv` Theora 1088×720), B (images en
  BC7), référence (image fixe).
- Mesure à l'instant 10 s, comparé à la vidéo d'origine (PSNR, plus c'est haut mieux c'est) : actuel
  32,4 dB, A 38,8 dB, B 33,4 dB. B gagne peu : la perte vient surtout de la réduction à 768×512.
- Coûts : A = 9 Mo de fichier, quelques Mo de mémoire, décodage par le processeur ; B = 253 Mo sur le
  disque par salle (préparés à l'avance, 0,2 à 0,35 s par image), 260 Mo de mémoire graphique par salle.
- Fichiers : `tests/demo_qualite.gd`, `tests/preparer_demo_qualite.gd`, `tests/demo_qualite/`
  (`porte5.ogv`, `bc7/`, captures et planches `comparaison_zoom.png`, `comparaison_entiere.png`).

### 2026-10-18 — Salles orientées comme la mini-carte, cul-de-sac
- **Pour le joueur** : le haut de l'image est maintenant toujours le haut de la mini-carte. Reculer (bas
  de l'image) mène à la salle du dessous, la porte de gauche à la salle de gauche, etc. Avant, une salle
  pouvait être « tournée » : reculer menait par exemple à la salle de gauche sur la mini-carte.
- 7 nouvelles salles **cul-de-sac** (passage qui finit sur un précipice, seule sortie le bas de
  l'image), et leurs miroirs, découpées dans `test_salle` (`culdesac1.json` à `culdesac7.json`).
- Sans salle en dessous, le bas de l'image est un mur invisible (plus de « porte condamnée » en
  reculant).
- Les images symétriques (salle 1, cul-de-sac…) sont aussi tirées en miroir.
- Reste en attendant les virages : gauche, droite, gauche + bas, droite + bas, gauche + droite (+ bas)
  n'ont pas d'image exacte ; la porte du fond y est condamnée (38 % des salles).
- Les salles des parties en cours sont réattribuées au chargement (`PlanSalles.VERSION` 5).
- Fichiers : `scripts/logique/plan_salles.gd` (orientation fixe, `voisines_carte`, `formes_couvertes`,
  `NOMS_DIRECTIONS`), `scripts/interface/salle_peinte.gd` (`murer`, `sorties_murees`),
  `scripts/ecrans/menu_navigation.gd`, `outils/importer_salles.py` (cul-de-sac),
  `donnees/salles_peintes/culdesac*.json`, `images/salles_peintes/culdesac*/`,
  `tests/test_cartographie_salles.gd` (15 combinaisons de directions, cohérence porte ↔ carte),
  `tests/voir_directions.gd` (remplace `tests/voir_virages.gd`, captures 57 supprimées).

### 2026-10-18 — Virages : plus d'image de couloir
- Pour le joueur : dans un virage ou un T, la porte à prendre se voit toujours. Avant, la salle porte 1
  pouvait être choisie : sa porte de gauche est cachée dans l'ombre et sa grande porte du fond était
  condamnée, la salle ressemblait à un couloir fermé (signalé par l'utilisateur).
- `outils/importer_salles.py` : `SORTIES_CACHEES` (porte de gauche de la salle porte 1 retirée du jeu ;
  elle reste une sortie dans test_salle) ; la salle porte 1 redevient un couloir. `PlanSalles.VERSION` 4.
- `tests/voir_virages.gd` : captures de contrôle (57). Tests : `test_cartographie_salles`,
  `capture_salles_peintes`, `capture_navigation` (0 échec).

### 2026-10-18 — Cartographie des salles, plus de son
- Cartographie : `tests/test_cartographie_salles.gd` classe chaque salle de la carte (cul-de-sac,
  couloir, virage, T, carrefour) et vérifie que son image a exactement les portes voulues : couloirs, T
  et carrefours 100 % exacts ; virages et culs-de-sac sans image exacte (une porte condamnée, images à
  créer). Tableau dans « Exploration dans des salles peintes ». Aucun changement du choix des images.
- Plus de son dans les salles : le feu de la salle 2 n'est plus joué (`outils/importer_salles.py` ne
  copie plus le son et retire `son.wav` ; importer relancé).
- Fichiers : `tests/test_cartographie_salles.gd`, `outils/importer_salles.py`, `donnees/salles_peintes/`.

### 2026-10-18 — « (miroir) » dans le titre de la salle
- Pour le joueur : quand la salle peinte est affichée retournée (gauche et droite échangées), le titre en
  haut à gauche se termine par « (miroir) », ex. « Étage 1 — Salle 13 : … (miroir) ».
- Fichier : `scripts/ecrans/menu_navigation.gd` (`_dessiner`).
- Tests : `compiler_tout`, `capture_salles_peintes`, `capture_navigation` (0 échec) ; capture 56.

### 2026-10-18 — Ennemis plus cachés par le héros en combat
- Pour le joueur : en combat, le héros (de dos, au centre) ne cache plus l'ennemi placé juste derrière
  lui. Un espace de 110 px (`ECART_HEROS` de `menu_combat.gd`) reste libre au milieu ; la première moitié du
  groupe se place à gauche du héros, le reste à droite (un ennemi seul ou un boss : juste à gauche).
- Fichier : `scripts/ecrans/menu_combat.gd` (`placer_ennemis`).
- Tests : `compiler_tout`, `capture_combat_seul`, `capture_combat_anime` (0 échec) ; captures 29 à 35.

### 2026-10-18 — Portes de côté des salles peintes
- Pour le joueur : les portes peintes qui n'étaient que du décor s'ouvrent maintenant quand une salle est
  derrière (porte de gauche des salles porte 1, 3 et 6, deux portes de gauche de la salle porte 2,
  embrasure sombre de la salle porte 4) ; sinon elles restent condamnées. Plus de combinaisons possibles,
  donc des salles plus variées sur la carte.
- `PlanSalles` : deux portes du même côté mènent à la même voisine (avant : la seconde était condamnée) ;
  `VERSION` 3 (sorties renumérotées : l'attribution des salles des parties en cours est refaite).
- `SallePeinte._placer` : arrivée au point `arrivees[nom]` du .json (préparé dans test_salle),
  `_appliquer_miroir` le retourne.
- `outils/importer_salles.py` : directions des nouvelles sorties ; importer relancé.
- `tests/capture_salles_peintes.gd` : une voisine atteinte par deux portes n'est comptée qu'une fois.
- Tests : `compiler_tout`, `test_logique`, `capture_salles_peintes`, `capture_navigation` (0 échec).
- Fichiers : `scripts/logique/plan_salles.gd`, `scripts/interface/salle_peinte.gd`,
  `outils/importer_salles.py`, `tests/capture_salles_peintes.gd`, `donnees/salles_peintes/`.

### 2026-10-18 — Salles orientées comme la carte, miroirs
- Les portes des salles peintes correspondent maintenant à la carte : une porte à gauche mène à la
  salle qui est à gauche sur la carte (vue dans le sens de la salle), une porte du fond à celle qui est
  devant, le bas de l'image à celle de derrière. Chaque salle est tournée vers une direction de la carte
  et peut être affichée en miroir ; l'attribution essaie toutes les combinaisons et garde celle où
  toutes les portes tombent juste (voir « Différences voulues »). Les anciennes attributions des
  sauvegardes sont refaites (`"v": 2`).
- Le héros qui arrive par une porte latérale est tourné vers l'intérieur de la salle.
- La salle attend ses lectures de décors en quittant l'écran (`_exit_tree`) : un test qui se fermait
  pendant une lecture restait bloqué.
- Fichiers : `scripts/logique/plan_salles.gd` (réécrit), `scripts/interface/salle_peinte.gd`
  (`charger(..., avec_miroir)`, `_appliquer_miroir`), `scripts/ecrans/menu_navigation.gd`,
  `scripts/ecrans/menu_combat.gd` (fond en miroir), `tests/capture_salles_peintes.gd` (chaque sortie
  mène à la salle dans sa direction sur la carte ; captures 56 en miroir).
- Tests : `compiler_tout`, `capture_salles_peintes`, `capture_navigation` (0 échec), `robot.gd`.

### 2026-10-18 — Fond du combat : la salle peinte
- Le combat se déroule devant la salle peinte de la salle où il a lieu, au lieu de l'image fixe
  `salle_combat.png` (ou `image_boss.png` pour le boss) : recadrée en 16:9, animée si le décor a été
  préparé par l'exploration (sinon image fixe). `scripts/ecrans/menu_combat.gd`
  (`_preparer_salle_peinte`, `_dessiner_fond`, `RECADRAGE_HAUT`).
- Tests : `compiler_tout` (0 échec), captures `capture_combat_seul.gd` (29, 30), `robot.gd`.

### 2026-10-18 — Exploration dans les salles peintes de test_salle
- L'écran d'exploration montre une salle peinte où l'on marche (salle 1, salle 2, salles porte 1 à 6
  du banc d'essai `test_salle`), avec le chargement rapide des décors et les portes reliées : chaque
  salle du donjon reçoit une de ces salles selon ses passages ; marcher dans une porte mène à la salle
  voisine du plan (fondu, puis combat, coffre, piège...) et l'on arrive devant la porte d'où l'on vient.
  Le bas de l'image ramène en arrière ; une porte sans salle derrière est condamnée ; un passage sans
  porte peinte (salle à 4 passages) garde une flèche. Détails : « Différences voulues ».
- Commandes de l'exploration : flèches / ZQSD (stick gauche, croix) pour marcher, Maj pour courir,
  H pour le soin hors combat (S sert à marcher), stick droit pour les boutons de l'interface.
- Nouveaux fichiers : `scripts/interface/salle_peinte.gd`, `scripts/logique/plan_salles.gd`,
  `outils/importer_salles.py`, `donnees/salles_peintes/`, `images/salles_peintes/`,
  `tests/capture_salles_peintes.gd`. Modifiés : `scripts/ecrans/menu_navigation.gd` (salle peinte,
  flèches de secours, touches ; `fond_salle` et `_avancer` retirés), `scripts/interface/manette.gd`
  (stick droit quand l'écran fait marcher le héros), `scripts/principal.gd` (lectures en arrière-plan
  attendues avant de quitter), `tests/robot.gd`.
- Correction au passage (aussi présente dans `test_salle.gd`, non modifié) : une tâche de lecture des
  décors déjà attendue était réinterrogée (« Invalid Group ID » dans la console).
- Tests : `compiler_tout`, `test_logique`, `test_descente`, `capture_navigation`, `capture_salles_peintes`
  (0 échec) et `robot.gd` (graine 2, 9 000 images, aucune erreur).

### 2026-10-17 — Archer plus petit
- L'archer gobelin passe de ×0,9 à ×0,8 (table `TAILLES` de `outils/importer_animations.py`).

### 2026-10-17 — Tailles des gobelins animés
- Réglage à l'œil de la taille de chaque gobelin animé : guerrier ×1,1, archer ×0,9, sorcier ×1,
  chaman ×0,92, féticheur ×0,65 (table `TAILLES` de `outils/importer_animations.py`, qui remplace
  `TAILLE_FETICHEUR` ; la hauteur de corps de référence de `donnees/combat_anime.json` est divisée d'autant).
- `tests/voir_combat_chaman.tscn` alterne combattant + archer + chaman et sorcier + combattant + féticheur.
- `tests/voir_combat_chevalier.tscn` (`voir_combat_chevalier.bat`) : combat contre le Chevalier de la mort.

### 2026-10-17 — Féticheur encore plus petit
- Le féticheur passe de 80 % à 65 % de la taille des autres gobelins (`TAILLE_FETICHEUR = 0.65`).

### 2026-10-17 — Féticheur plus petit
- Le féticheur paraissait aussi grand que les autres gobelins alors qu'il est accroupi : il est
  affiché à 80 % de leur taille (`TAILLE_FETICHEUR` de `outils/importer_animations.py`, qui augmente
  la hauteur de corps de référence dans `donnees/combat_anime.json`).

### 2026-10-17 — Féticheur animé
- Le gobelin féticheur est animé en combat : attente, touché, mort (version `mort/death_lift`, qui ne
  passe pas sous la ligne des pieds), et deux lancers tirés au hasard : orbe vaudou (dégâts à
  l'image 10, juste après le lâcher) et fumée de malédiction suivie d'un coup au sol (dégâts à
  l'image 11, quand le nuage s'étend).
- `outils/importer_animations.py` : table `FETICHEUR_ANIMS` (pas de json fourni : durées et pieds
  repris des README), images réduites à 0,7 (corps de 343 → 240 px, comme les autres gobelins).
- `tests/voir_combat_chaman.tscn` : combattant, chaman et féticheur.
- `tests/capture_combat_anime.gd` : un féticheur seul riposte puis meurt, comme le chaman (captures 38 à 42).
- Fichiers : `scripts/interface/combat_anime.gd`, `outils/importer_animations.py`,
  `donnees/combat_anime.json`, `images/combat_anime/gobelins/feticheur/`, `tests/voir_combat_chaman.gd`,
  `tests/capture_combat_anime.gd`.

### 2026-10-17 — Chaman animé
- Le gobelin chaman est animé en combat : attente, touché, mort, et deux lancers (boule de feu,
  cercle de feu au sol) tirés au hasard quand il agit ; dégâts à l'image 10 de chacun.
- `outils/importer_animations.py` lit `C:\ia image\ennemis\gobelin\gobelin chaman` (chaman.json,
  frames/), réduit les images de moitié (`ECHELLE_CHAMAN`), pieds = (243, 581) + décalage de la cellule.
- `tests/voir_combat_chaman.tscn` : combats à jouer soi-même contre combattant, chaman et sorcier (féticheur depuis l'entrée « Féticheur animé »)
  (`Godot_v4.7.2-stable_win64.exe --path . res://tests/voir_combat_chaman.tscn`).
- `tests/capture_combat_anime.gd` : la cible automatique se fait contre un chaman seul, qui riposte
  (capture 39).
- Note : `Gobelin.generer_chaman_gobelin` crée la classe « soutient » (sans compétences, comme le jeu
  d'origine) ; le donjon tire bien « soutien ».
- Fichiers : `scripts/interface/combat_anime.gd`, `outils/importer_animations.py`,
  `donnees/combat_anime.json`, `images/combat_anime/gobelins/chaman/`, `tests/voir_combat_chaman.*`,
  `tests/capture_combat_anime.gd`.

### 2026-10-17 — Héros plus bas, barre d'actions compacte, cible automatique
- Le héros de dos est placé plus bas (pieds à 715 px au lieu de 655) : l'ennemi du milieu reste visible.
- La barre d'actions du combat est plus petite et plus basse (600 × 58 px au lieu de 668 × 88).
- Un sort ou une compétence à cible unique vise directement le dernier ennemi en vie, sans clic.
- `tests/capture_combat_anime.gd` vérifie la cible automatique (capture 38).
- Fichiers : `scripts/interface/combat_anime.gd`, `scripts/ecrans/menu_combat.gd`,
  `tests/capture_combat_anime.gd`.

### 2026-10-17 — Héros au milieu, pause avant la riposte
- Le héros de dos est placé au milieu du bas de l'écran (il était à gauche).
- Les ennemis attendent 1,5 s après le dernier coup du héros avant de lancer leur animation
  d'attaque : leur animation « touché » n'est plus coupée par leur propre attaque
  (`EffetsCombat.PAUSE_RIPOSTE`, `dernier_coup_heros`).
- `tests/capture_combat_anime.gd` vérifie la pause.
- Fichiers : `scripts/interface/combat_anime.gd`, `scripts/interface/effets_combat.gd`,
  `tests/capture_combat_anime.gd`.

### 2026-10-17 — Lancer de sort, lance qui respire
- Le héros joue le lancer de sort (animation `avatar_sort_v2`) quand il utilise une magie, depuis
  le menu Magies ; les dégâts s'affichent quand la boule s'éloigne (image 11). Sorts sur soi compris.
- Avec une lance (pas d'idle fourni), la garde n'était qu'une image figée : elle respire maintenant
  comme les images fixes des gobelins.
- `tests/capture_combat_anime.gd` lance aussi Étincelle ardente (capture 37).
- Fichiers : `scripts/interface/combat_anime.gd`, `scripts/ecrans/menu_combat.gd`,
  `outils/importer_animations.py`, `donnees/combat_anime.json`, `images/combat_anime/heros/sort/`,
  `tests/capture_combat_anime.gd`.

### 2026-10-17 — Animations dès le début du combat, guerrier plus calme
- Correctif : le héros et parfois des gobelins restaient figés sur leur première image au début du
  combat, jusqu'à 6 s. Le décalage d'attente propre à chaque combattant (`Animations.phase_de`)
  peut être négatif : le départ de l'attente tombait dans le futur. Il est ramené entre 0 et 2π
  (`CombatAnime._etat`).
- Le gobelin guerrier respire plus lentement : 250 ms par image (cycle de 3 s, comme l'archer et la
  garde du héros) au lieu de 110 ms (1,3 s). Réglage `MS_ATTENTE` de `outils/importer_animations.py` ;
  les images sources et le banc d'essai `test_salle` ne changent pas.
- `tests/capture_combat_anime.gd` vérifie les deux points.
- Fichiers : `scripts/interface/combat_anime.gd`, `outils/importer_animations.py`,
  `donnees/combat_anime.json`, `tests/capture_combat_anime.gd`.

### 2026-10-17 — Combat animé
- L'écran de combat montre le héros de dos au premier plan, avec la garde de son arme. Il joue
  l'attaque de l'épée, de la lance ou du marteau quand il utilise une compétence d'arme, et
  « touché » quand on le frappe. Les gobelins combattant, archer et sorcier sont animés : attente,
  attaque quand ils agissent, touché, mort. Les dégâts s'affichent à l'image où l'arme touche.
- Les règles ne changent pas. Les autres sous-classes gardent leur image fixe ; les magies n'ont
  pas d'animation du héros.
- Ce que montrent les animations : l'épée balaie de droite à gauche, le marteau frappe le sol à
  gauche du héros (il se baisse et sort presque de l'écran), la lance pique en diagonale vers la droite.
- Mesure : sur une partie jouée par `robot.gd` (graine 2, 9 000 images, 1 902 images d'écran de
  combat), aucune erreur ; tous les tests passent (`test_logique` inchangé : le héros y meurt
  toujours au premier combat).
- Fichiers : `scripts/interface/combat_anime.gd` (nouveau), `scripts/interface/effets_combat.gd`,
  `scripts/logique/combat.gd`, `scripts/ecrans/menu_combat.gd`, `outils/importer_animations.py`
  (nouveau), `donnees/combat_anime.json` et `images/combat_anime/` (nouveaux),
  `tests/capture_combat_anime.gd` (nouveau).

### 2026-10-16 — Caractéristiques des gobelins refaites, butin réglé
- Les gobelins partaient de force 3, dextérité 2, intelligence 3, sagesse 2, armure 5,
  10 % de critique et 10 % de parade, plus +5 ou +6 dans la caractéristique de leur
  classe et +15 % de critique pour les guerriers : bien plus que le héros.
- Nouvelles règles (voir « Caractéristiques des gobelins » plus haut). Le choix des
  caractéristiques principale et secondaire de chaque sous-classe reste à confirmer.
- Butin : il était bien activé, mais seulement 10 % par objet porté, et un gobelin ne
  portait souvent que son arme (armure lâchée par environ 5 % des gobelins). Désormais
  les gobelins ne portent plus rien : un objet est généré à leur mort, avec une chance
  par paliers de 50 % à 25 % (voir « Objets des gobelins et butin »).
- `tests/test_pv.gd` retire l'endurance des objets portés avant de vérifier le tirage ;
  nouveau `tests/test_butin.gd`.
- Fichiers : `scripts/logique/gobelin.gd`, `scripts/logique/ennemis.gd`, `tests/test_pv.gd`,
  `tests/test_butin.gd` (nouveau).

### 2026-10-16 — Un seul sort par tour depuis le menu Magies
- Bug : un sort sans choix de cible (sur soi ou de zone, comme Soin) lancé depuis le menu
  « Magies » ne refermait pas l'écran de combat. Le tour des ennemis se jouait en
  interne, mais seuls les PA du héros étaient rendus : le héros pouvait relancer le
  sort plusieurs fois de suite, sans que les ennemis rejouent. C'est aussi la cause
  probable des « tours d'affilée ».
- L'écran se ferme désormais après ce sort, comme après une attaque. Un bouton d'action
  inutilisable (PA ou mana insuffisants) ne lance plus rien.
- Les tests automatiques ne passaient pas par l'écran de combat (mode `Ecrans.auto`) :
  `tests/test_magie_ecran.gd` clique dans le vrai écran.
- Fichiers : `scripts/ecrans/menu_combat.gd`, `tests/test_magie_ecran.gd` (nouveau).

### 2026-10-16 — « Tour perdu » affiché
- Impression de jouer plusieurs tours d'affilée : ce sont les ennemis qui perdaient leur
  tour sans que l'écran le dise. Les gobelins n'ont qu'1 PA, et Gel (−1 PA par tour),
  Lenteur (−1 PA une fois sur deux), Électrocution et Décrépitude (une fois sur quatre)
  le leur retirent en entier ; l'étourdissement, la terreur, la paralysie et le sommeil
  font aussi sauter le tour. Le héros n'a pas de PA en trop (vérifié sur 300 combats).
- « Tour perdu (cause) » s'affiche désormais au-dessus du combattant concerné.
- Fichiers : `scripts/logique/combat.gd`, `alterations.gd`,
  `scripts/interface/effets_combat.gd`, `tests/test_soins.gd`.

### 2026-10-16 — Un soin par ennemi, ennemi seul centré, héros à 1 PA
- Chaque ennemi ne peut être soigné qu'une fois par combat (compétence ou potion).
- Un ennemi seul (ou le boss) est centré dans l'écran de combat.
- Le héros n'a plus qu'un point d'action ; les sorts à 2 PA lui sont inaccessibles.
- Fichiers : `scripts/logique/ennemis.gd`, `combat.gd`, `personnage.gd`,
  `scripts/ecrans/menu_combat.gd`, `tests/test_soins.gd`, `tests/capture_combat_seul.gd` (nouveaux).

### 2026-10-16 — Héros à 30 PV, rencontres par étage, coups multiples
- Héros : 15 d'endurance (30 PV), autres caractéristiques à 3.
- Nombre d'ennemis selon l'étage (75 % d'un seul à l'étage 1, jusqu'à 35 % de trois à
  partir de l'étage 4).
- Coups multiples : 1d6 − 2 par coup.
- Mesure (1 500 rencontres de l'étage 1, héros de départ) : un tour complet des ennemis
  inflige 10 dégâts en moyenne et 30 ou plus dans 0,3 % des rencontres (15 % avant).
- Fichiers : `scripts/logique/personnage.gd`, `donjon.gd`, `formules.gd`, `combat.gd`,
  `tests/test_pv.gd`, `tests/test_des_armes.gd`.

### 2026-10-16 — Plus de mort en entrant dans une salle
- Cause : les objets gardaient les valeurs de l'ancien système (1 point = 1 dégât plat).
  Un sorcier gobelin pouvait porter +30 de dégâts d'ombre, soit jusqu'à 129 dégâts sur
  un critique contre 20 PV ; et les ennemis jouaient en premier 3 fois sur 4.
- Coûts des statistiques d'objets recalibrés (voir plus haut) ; résistance élémentaire
  ajoutée aux objets ; le héros joue toujours en premier.
- Mesure (1 500 rencontres, héros de départ) : un tour complet des ennemis inflige
  12 dégâts en moyenne et en fait 20 ou plus dans 15 % des rencontres.
- Fichiers : `scripts/logique/generation_objets.gd`, `objets.gd`, `combat.gd`,
  `scripts/interface/description_objet.gd`.

### 2026-10-16 — Toutes les compétences aux dés, armure fixe
- Chaque type de dégâts lance ses dés (feu 2d6, froid 3d4, foudre 1d12, arcane 2d6,
  chaos 3d4, ombre 2d6, lumière 3d6 de soin, tranchant 2d6, perforant 1d12, contondant
  1d10 + 1d2, poison 1d2), + 1 par 2 points de force (physique), de sagesse (élémentaire),
  d'intelligence (magique) ou de la meilleure des deux (lumière), × pourcentages.
- Brûlure : 1d2 par tour et par cumul.
- Armure, résistance élémentaire (nouvelle, sagesse) et résistance magique : 10 points
  retirent 1 dégât.
- Les attaques de base d'arme n'ont plus de règle à part (`ATTAQUES_ARME`, `reference_arme`
  retirés) : elles suivent la règle générale.
- Fichiers : `scripts/logique/formules.gd`, `combat.gd`, `degats.gd`, `alterations.gd`,
  `ameliorations.gd`, `personnage.gd`, `ennemis.gd`, `generation_objets.gd`,
  `scripts/interface/description_objet.gd`, `fiche_ennemi.gd`,
  `scripts/ecrans/menu_caracteristique.gd`, `tests/test_des_armes.gd`.

### 2026-10-16 — PV issus de l'endurance
- PV max = endurance × 2 (`Ennemis.PV_PAR_ENDURANCE`), plus les bonus des objets et
  des talents ; plus de PV de départ fixes (héros 300 → 0, gobelin 20 → 0).
- Héros : 10 d'endurance au départ (20 PV). Gobelins : endurance tirée selon la
  sous-classe (`Gobelin.ENDURANCE_PAR_SOUS_CLASSE`) : combattant et défenseur 10 à 12,
  lancier, archer, sorcier, féticheur et chaman 6 à 8, plus les bonus globaux des
  ennemis. Les anciens bonus d'endurance par classe sont retirés. Boss et mini-boss
  gardent leur multiplicateur de PV (× 14 et × 6).
- Équilibrage à revoir : les coups actuels (10 à 44 dégâts) tuent souvent en un coup ;
  `test_logique` : le héros meurt au premier combat.
- Fichiers : `scripts/logique/personnage.gd`, `scripts/logique/ennemis.gd`,
  `scripts/logique/gobelin.gd`, `scripts/logique/alterations.gd`,
  `scripts/ecrans/menu_caracteristique.gd`, `tests/test_pv.gd` (nouveau).

### 2026-10-16 — Attaques de base aux dés et dés bonus des armes
- Coup d'épée, de lance et de marteau : dés de l'arme + force ÷ 2 + bonus, × pourcentages
  de dégâts ; plus de dégâts de base du héros ni de dégâts propres de la compétence.
- Armes : dé bonus rare (1d2 au rang 1 … 1d12 au rang 6), très cher en points, du type
  de l'arme ou d'un élément (feu, ombre, foudre...). Affiché sur l'objet.
- Fichiers : `scripts/logique/formules.gd`, `scripts/logique/combat.gd`,
  `scripts/logique/ameliorations.gd`, `scripts/logique/generation_objets.gd`,
  `scripts/interface/description_objet.gd`, `tests/test_des_armes.gd`.

### 2026-10-16 — Dégâts des armes aux dés
- Début de la refonte du combat : lance 1d12, épée 2d6, marteau 1d10 + 1d2, fixes pour
  toutes les armes, à la place de l'ancien bonus de dégâts physiques tiré selon le rang.
  Les autres attributs des armes restent (ils récupèrent le budget des dégâts).
- Fichiers : `scripts/logique/formules.gd`, `scripts/logique/combat.gd`,
  `scripts/logique/generation_objets.gd`, `scripts/interface/description_objet.gd`,
  `scripts/ecrans/menu_caracteristique.gd`, `tests/test_des_armes.gd` (nouveau).

### 2026-10-16 — Plus de boss rejoué en redescendant
- Correctif : redescendre d'un étage ne relance plus le combat contre le boss de l'étage
  inférieur. Monter ou descendre marque désormais la salle quittée comme visitée, et la
  salle du boss où l'on arrive en descendant l'est aussi (anciennes sauvegardes comprises).
  Remonter ne relance pas non plus de rencontre dans la salle de départ déjà visitée.
- Fichiers : `scripts/logique/donjon.gd`, `tests/test_descente.gd` (nouveau).

### 2026-10-14 — Mini-carte et boutons d'action
- Mini-carte réduite (210×165) en haut à droite, sous les tuiles des menus.
- « Monter » n'apparaît que dans la salle du boss, « Descendre » que dans la salle de
  départ d'un étage (sauf au premier), « Se reposer » que dans une salle avec un lit
  (aucun lit pour l'instant). Les boutons absents ne prennent pas de place.
- Fichiers : `scripts/ecrans/menu_navigation.gd`, `scripts/interface/carte.gd`,
  `scripts/logique/donjon.gd`, `tests/capture_navigation.gd` (nouveau).

### 2026-10-14 — Portage initial
- Jeu complet porté de pygame vers Godot 4.7 (GDScript), voir plus haut.
