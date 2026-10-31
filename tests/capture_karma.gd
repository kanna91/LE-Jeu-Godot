extends SceneTree
## Captures du karma et des âmes (2026-10-31) : corps d'un groupe vaincu dans une salle (bandeau : âmes et karma),
## dialogue du corps, écran des caractéristiques avec des points à répartir. Fenêtre hors écran (override.cfg) :
## godot --path . -s tests/capture_karma.gd  → tests/captures/130_* à 133_*

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
	await attendre(8)
	root.get_viewport().get_texture().get_image().save_png("res://tests/captures/%s.png" % nom)
	print("capture ", nom)


func lancer() -> void:
	seed(77)
	await attendre(2)
	Sauvegarde.reinitialiser_monde()
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	joueur._d["karma"] = -2
	joueur.gagner_ames(5)
	donjon.salle_courante()["presences"] = []
	Ecrans.menu_navigation(joueur, donjon)
	var ecran = Ecrans.pile[-1]
	await attendre(6)
	var heros: Vector2 = ecran.salle_peinte.heros.position
	var corps := Aventure.laisser_cadavre(donjon, {"genre": "groupe", "nombre": 2, "elite": true, "etat": "vaincu",
		"membres": [{"classe": "guerrier", "sous_classe": "combattant"}, {"classe": "tireur", "sous_classe": "archer"}]},
		heros + Vector2(70, -25), "%s%s" % [ecran.salle_peinte.ident, "_m" if ecran.salle_peinte.miroir else ""])
	ecran.salle_peinte.presences.ajouter_immobile(corps)
	# Sortes sans animation de mort : squelette et loup, couchés sur le dos
	var os := Aventure.laisser_cadavre(donjon, {"genre": "groupe", "nombre": 2, "etat": "vaincu",
		"membres": [Creatures.membre("squelette"), Creatures.membre("loup")]},
		heros + Vector2(-110, -40), "%s%s" % [ecran.salle_peinte.ident, "_m" if ecran.salle_peinte.miroir else ""])
	ecran.salle_peinte.presences.ajouter_immobile(os)
	# Gobelin blessé (il s'effondre), puis achevé : son animation de mort va jusqu'au bout
	var blesse := {"id": 7, "genre": "pnj", "sous": "gobelin_blesse", "etat": "actif", "pos": [heros.x - 60, heros.y - 45],
		"pos_image": "%s%s" % [ecran.salle_peinte.ident, "_m" if ecran.salle_peinte.miroir else ""]}
	ecran.salle_peinte.presences.ajouter_immobile(blesse)
	await capturer("130_corps_dans_la_salle")
	blesse["sous"] = "cadavre"
	blesse["genre"] = "objet"
	blesse["membres"] = [{"sous_classe": CombatAnime.TYPES.find_key(PresencesSalle.SORTES_GOBELINS[7 * 7 % PresencesSalle.SORTES_GOBELINS.size()])}]
	blesse["t_mort"] = Animations.temps()
	await attendre(90)
	await capturer("133_gobelin_acheve")
	var dlg = Ecrans._ecran("ecran_dialogue").preparer("Cadavre", "Le corps gît sur les dalles.",
		["Fouiller les corps", "Siphonner leurs âmes (4)", "Partir"], Ecrans.capture(), Color8(150, 120, 170))
	Ecrans.ouvrir(dlg)
	await capturer("131_dialogue_corps")
	dlg.fermer()
	await attendre(2)
	Ecrans.menu_caracteristique(joueur)
	await capturer("132_caracteristiques_points")
	print("fin")
	quit()
