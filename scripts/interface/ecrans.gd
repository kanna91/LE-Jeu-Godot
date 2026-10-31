class_name Ecrans
extends RefCounted
## Ouverture des écrans du jeu (équivalent des fonctions ``afficher_menu_*`` de pygame,
## qui faisaient leur propre boucle puis rendaient la main).
##
## Chaque écran est un Ecran ajouté à la racine ; ``await Ecrans.xxx(...)`` attend
## sa fermeture et renvoie son résultat. L'écran appelant est masqué pendant ce
## temps, et sa sélection à la manette est restaurée au retour (manette.sous_menu).
## En mode ``auto`` (tests sans affichage), les écrans du combat et des salles jouent seuls.

static var racine: Node = null
static var pile: Array = []
## Tests sans affichage : les écrans choisissent eux-mêmes.
static var auto := false


static func _ecran(nom: String) -> Ecran:
	return load("res://scripts/ecrans/%s.gd" % nom).new()


## Ouvre un écran et attend sa fermeture ; renvoie son résultat.
static func ouvrir(ecran: Ecran):
	var selection := Manette.memoriser_selection()
	if not pile.is_empty():
		var dessous: Ecran = pile[-1]
		dessous.visible = false
		dessous.process_mode = Node.PROCESS_MODE_DISABLED
	pile.append(ecran)
	racine.add_child(ecran)
	var resultat = await ecran.termine
	pile.erase(ecran)
	ecran.queue_free()
	if not pile.is_empty():
		var dessous: Ecran = pile[-1]
		dessous.visible = true
		dessous.process_mode = Node.PROCESS_MODE_INHERIT
		if dessous.has_method("au_retour"):
			dessous.au_retour()
	Manette.restaurer_selection(selection)
	return resultat


## Copie de l'image affichée (``fenetre.copy()``), pour servir de fond à un écran superposé.
static func capture() -> Texture2D:
	if racine == null or not racine.is_inside_tree():
		return null
	var image := racine.get_viewport().get_texture().get_image()
	return ImageTexture.create_from_image(image)


# ---------------------------------------------------------------------------
# Écrans de la partie
# ---------------------------------------------------------------------------

static func menu_demarrage(message := ""):
	return await ouvrir(_ecran("menu_demarrage").preparer(message))


static func choisir_emplacement(mode: String, fond = null):
	return await ouvrir(_ecran("choix_emplacement").preparer(mode, fond))


static func menu_pause(joueur, donjon):
	return await ouvrir(_ecran("menu_pause").preparer(joueur, donjon, capture()))


static func ecran_mort(joueur, donjon, cause: String):
	return await ouvrir(_ecran("ecran_mort").preparer(joueur, donjon, cause))


static func menu_navigation(joueur, donjon):
	return await ouvrir(_ecran("menu_navigation").preparer(joueur, donjon))


static func menu_sort_depart(joueur):
	if Sorts.sorts_de_depart(joueur).is_empty() or joueur.nouvelle_magie_a_apprendre <= 0:
		return null
	return await ouvrir(_ecran("menu_sort_depart").preparer(joueur))


## Options (volume de la musique) ; ``capture`` : fond figé du jeu (menu pause), sinon le fond du menu principal.
static func options(fond: Texture2D = null) -> void:
	await ouvrir(_ecran("menu_options").preparer(fond))


static func journal(joueur) -> void:
	await ouvrir(_ecran("journal").preparer(joueur, capture()))


static func carte_complete(donjon) -> void:
	await ouvrir(_ecran("carte_complete").preparer(donjon, capture()))


# ---------------------------------------------------------------------------
# Menus du héros
# ---------------------------------------------------------------------------

static func menu_inventaire(joueur) -> void:
	await ouvrir(_ecran("menu_inventaire").preparer(joueur))


static func menu_caracteristique(joueur) -> void:
	await ouvrir(_ecran("menu_caracteristique").preparer(joueur))


static func menu_magie(joueur) -> void:
	await ouvrir(_ecran("menu_magie").preparer(joueur))


static func menu_ameliorer_competence(joueur, competence) -> void:
	await ouvrir(_ecran("menu_ameliorer_competence").preparer(joueur, competence))


# ---------------------------------------------------------------------------
# Écrans ouverts par la logique du jeu
# ---------------------------------------------------------------------------

## Écran de combat : une action du joueur (menu_combat.afficher_menu_combat).
static func menu_combat(_fenetre, personnage, combat) -> void:
	if auto:
		Auto.action_combat(personnage, combat)
		return
	await ouvrir(_ecran("menu_combat").preparer(personnage, combat))


## Dialogue du donjon d'aventure (personnage, événement, capture) : indice du choix fait.
## En mode ``auto`` : un choix au hasard.
static func dialogue(titre: String, texte: String, choix: Array = [], teinte := Ui.OR) -> int:
	if auto:
		return randi_range(0, maxi(0, choix.size() - 1))
	var resultat = await ouvrir(_ecran("ecran_dialogue").preparer(titre, texte, choix, capture(), teinte))
	return int(resultat) if resultat != null else 0


## Liste des potions en combat : objet choisi, ou null.
static func choisir_objet_combat(joueur):
	return await ouvrir(_ecran("choix_objet_combat").preparer(joueur, capture()))


static func fiche_ennemi(ennemis: Array, index: int, joueur) -> void:
	await ouvrir(_ecran("fiche_ennemi").preparer(ennemis, index, joueur, capture()))


static func menu_coffre(_fenetre, personnage, donjon, salle) -> void:
	if auto:
		Auto.coffre(personnage, donjon, salle)
		return
	await ouvrir(_ecran("menu_coffre").preparer(personnage, donjon, salle))


static func menu_bonus(_fenetre, personnage, salle) -> void:
	if auto:
		Auto.bonus(personnage, salle)
		return
	await ouvrir(_ecran("menu_bonus").preparer(personnage, salle))


static func menu_soin(_fenetre, personnage, salle) -> void:
	if auto:
		Auto.soin(personnage, salle)
		return
	await ouvrir(_ecran("menu_soin").preparer(personnage, salle))


static func menu_marchand(_fenetre, marchand, personnage) -> void:
	if auto:
		return
	await ouvrir(_ecran("menu_marchand").preparer(marchand, personnage))
