extends SceneTree
## Captures des nouveautés du 2026-10-31 : catégorie « Divers » (inventaire, avec les clés, et marchand), onglet
## « Glossaire » du journal, fiche et info-bulle du Chevalier de la mort (« ??? »). Fenêtre hors écran (override.cfg,
## voir README) : godot --path . -s tests/capture_divers_glossaire.gd

var racine: Control


func _initialize() -> void:
	racine = Control.new()
	racine.size = Vector2(960, 540)
	root.add_child(racine)
	Ecrans.racine = racine
	lancer()


func attendre(images: int) -> void:
	for _i in images:
		await process_frame


func capturer(nom: String) -> void:
	await attendre(4)
	root.get_viewport().get_texture().get_image().save_png("res://tests/captures/%s.png" % nom)
	print("capture ", nom)


func lancer() -> void:
	seed(31)
	Sauvegarde.reinitialiser_monde()
	Compte.vider()
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	joueur._d["cles"] = 2
	# Objets d'essai : le catalogue des objets divers est vide en attendant la liste de l'utilisateur
	for l in [["Objet d'essai A", "argenterie", 25], ["Objet d'essai A", "argenterie", 25], ["Objet d'essai B", "nourriture", 2]]:
		joueur.recevoir_objet(ObjetsDivers.creer(l[0], l[1], l[2], "Objet d'essai (capture)."))
	joueur.recevoir_objet(Consommable.creer_potion("pv", 1))
	# Inventaire, catégorie Divers
	var MI := load("res://scripts/ecrans/menu_inventaire.gd")
	MI.categorie_active = "Divers"
	Ecrans.menu_inventaire(joueur)
	await capturer("110_inventaire_divers")
	var ecran = Ecrans.pile[-1]
	Manette.mode_manette = true  # curseur virtuel : la vraie souris n'est jamais déplacée
	Manette.pos = ecran.objets_visuels[1][1].get_center()
	await capturer("111_inventaire_divers_survol")
	Manette.mode_manette = false
	ecran.fermer()
	await attendre(2)
	# Marchand, onglet Vendre, catégorie Divers
	var marchand := Marchand.nouveau("marchand", donjon)
	var ecran_m = load("res://scripts/ecrans/menu_marchand.gd").new().preparer(marchand, joueur)
	ecran_m.onglet = "Vendre"
	ecran_m.categories["Vendre"] = "Divers"
	Ecrans.ouvrir(ecran_m)
	await capturer("112_marchand_divers")
	ecran_m.fermer()
	await attendre(2)
	# Glossaire : quelques informations apprises
	for k in 4:
		Rencontres.repondre(donjon, "chevalier")
	for k in 6:
		Rencontres.repondre(donjon, "autre")
	var jnl = Ecrans._ecran("journal").preparer(joueur, null)
	Ecrans.ouvrir(jnl)
	await capturer("113_journal")
	jnl._changer_onglet("Glossaire")
	await capturer("114_glossaire")
	jnl.fermer()
	await attendre(2)
	# Fiche du Chevalier de la mort
	var chevalier := Aventure.creer_imbattable(donjon)
	Ecrans.ouvrir(load("res://scripts/ecrans/fiche_ennemi.gd").new().preparer([chevalier], 0, joueur, null))
	await capturer("115_fiche_chevalier")
	Ecrans.pile[-1].fermer()
	await attendre(2)
	print("fin")
	Compte.vider()
	quit()
