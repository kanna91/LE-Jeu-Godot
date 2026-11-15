extends SceneTree
## Couche « Perspective » de l'éditeur des salles (OutilPerspective, 2026-11-15), taille des ennemis et butin du jeu
## affiché dans l'éditeur des ennemis. Rien n'est enregistré. « BILAN outil perspective : 0 échec(s) ».

const MC := preload("res://scripts/ecrans/menu_combat.gd")

var echecs := 0


func verifier(c: bool, cas: String) -> void:
	if not c:
		echecs += 1
	print(("ok " if c else "ÉCHEC ") + cas)


func _clic(ed, m: Vector2, bouton := MOUSE_BUTTON_LEFT, appui := true) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = bouton
	ev.pressed = appui
	ed.perspective.bouton(ev, m)


func _initialize() -> void:
	var ed = load("res://scenes/outils/editeur_zones.tscn").instantiate()
	root.add_child(ed)
	await process_frame
	ed.numero = ed.salles.find("porte2")
	ed._charger()
	ed.choisir_couche("perspective")
	verifier(ed.couche_active() == "perspective" and ed.mode_perspective, "couche Perspective choisie")
	await process_frame
	verifier(ed.perspective.panneau.visible, "panneau de la perspective visible")
	var outil: OutilPerspective = ed.perspective
	var t: Array = outil.table()
	var n := t.size()
	print("table : ", t)
	# Nouvelle règle au milieu, puis sa tête glissée : le héros y est plus grand
	var y := int((float(t[0][0]) + float(t[-1][0])) / 2.0)
	var avant: float = ed.salle.hauteur(y)
	_clic(ed, Vector2(300, y))
	verifier(outil.table().size() == n + 1 and outil.glisse.size() == 2 and outil.glisse[0] == "tete"
		and int(outil.table()[int(outil.glisse[1])][0]) == y, "clic : nouvelle règle à y = %d, tête prise" % y)
	outil.mouvement(Vector2(outil.X_REGLES, y - avant - 30))
	_clic(ed, Vector2(300, y), MOUSE_BUTTON_LEFT, false)
	verifier(absf(ed.salle.hauteur(y) - (avant + 30)) < 1.5, "tête glissée : héros de %d → %d px à y = %d" % [int(avant), int(ed.salle.hauteur(y)), y])
	verifier(ed.perspective_modifiee and ed.modifie, "perspective marquée modifiée")
	# Clic droit sur la règle : retirée ; Ctrl+Z : revient
	_clic(ed, Vector2(outil.X_REGLES, y), MOUSE_BUTTON_RIGHT)
	verifier(outil.table().size() == n, "clic droit : règle retirée")
	ed._annuler()
	verifier(ed.salle.donnees["perspective"]["table_hauteur"].size() == n + 1, "Ctrl+Z : règle revenue")
	# Vitesse en profondeur au fond : plancher réglable, la traversée devient plus courte
	var lent: Array = outil.traversee()
	outil.regler("compression_min", 0.6)
	var vite: Array = outil.traversee()
	print("traversée : %.1f s → %.1f s en marchant ; profondeur %.1f → %.1f hauteurs de héros" % [lent[1], vite[1], lent[0], vite[0]])
	verifier(vite[1] < lent[1] and ed.salle.compression(float(t[0][0])) >= 0.6 * float(ed.salle.donnees["perspective"]["compression_profondeur"]) - 0.001,
		"vitesse en profondeur au fond relevée : traversée plus courte")
	outil.maj_infos()
	verifier("m de profondeur" in outil.infos.text and "en marchant" in outil.infos.text, "panneau : " + outil.infos.text.replace("\n", " | "))
	# Revenir à la perspective enregistrée
	outil.revenir()
	verifier(ed.salle.donnees["perspective"] == ed.perspective_enregistree and not ed.perspective_modifiee, "revenir : perspective enregistrée")
	# Capture de la couche (hors écran)
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		# Souris au milieu du sol pour les silhouettes (vue sans clavier ni souris réelle : position simulée)
		for _i in 10:
			await process_frame
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/captures"))
		root.get_viewport().get_texture().get_image().save_png("res://tests/captures/73_couche_perspective.png")
	ed.queue_free()
	# Taille des ennemis (éditeur des ennemis) et butin du jeu affiché
	var g := Gobelin.nouveau(null)._completer("guerrier", "combattant")
	var avant_taille: float = MC.echelle_ennemi(g)
	DonneesEnnemis.donnees()["sortes"]["combattant"]["taille"] = 1.5
	verifier(is_equal_approx(MC.echelle_ennemi(g), avant_taille * 1.5) and is_equal_approx(DonneesEnnemis.taille_de("combattant"), 1.5),
		"taille 150 % : image de combat × 1,5")
	DonneesEnnemis.recharger()
	verifier(is_equal_approx(DonneesEnnemis.taille_de("combattant"), 1.0), "taille par défaut : 1")
	# Butin du jeu réglable (2026-11-15) : valeurs par défaut = celles d'avant, puis réglages de l'éditeur suivis en jeu
	var f: Dictionary = DonneesEnnemis.butin_du_jeu("squelette", "fouille")
	verifier(int(f["rien"]) == 50 and int(f["or"]) == 35 and int(f["objet"]) == 15 and int(f["or_min"]) == 10 and int(f["or_max"]) == 30,
		"fouille par défaut : 50 / 35 / 15, 10 à 30 pièces")
	verifier(DonneesEnnemis.butin_du_jeu("loup", "fouille_par_membre").size() >= 1 and DonneesEnnemis.butin_de("loup").is_empty() and int(DonneesEnnemis.butin_du_jeu("combattant", "elite_objet")) == 100,
		"par défaut : viande des loups, objet d'élite à 100 %")
	var heros := Personnage.nouveau()
	var donjon := Donjon.nouveau(heros)
	donjon.salle_actuelle = [1, 1]
	DonneesEnnemis.donnees()["sortes"]["squelette"]["fouille"] = {"rien": 0, "or": 1, "objet": 0, "or_min": 500, "or_max": 500}
	heros.piece_or = 0
	var msg := Fouille.fouiller_corps(heros, donjon, false, [Creatures.membre("squelette")])
	verifier(heros.piece_or == roundi(500 * Karma.facteur_or(heros)), "fouille réglée à 500 pièces : %s" % msg)
	DonneesEnnemis.donnees()["sortes"]["squelette"]["fouille_par_membre"] = [{"categorie": "potion", "objet": "", "potion": "mana",
		"quantite": 1, "rang": 0, "chance": 100}]
	var potions: int = heros.inventaire.size()
	Fouille.fouiller_corps(heros, donjon, false, [Creatures.membre("squelette"), Creatures.membre("squelette")])
	verifier(heros.inventaire.size() == potions + 2, "par membre : une potion par squelette")
	DonneesEnnemis.donnees()["sortes"]["archer"]["pacifique_epargne"] = {"or_min": 7, "or_max": 7, "potion": 0, "equipement": 0}
	heros.piece_or = 0
	var groupe := {"genre": "groupe", "etat": "actif", "nombre": 1, "membres": [{"classe": "guerrier", "sous_classe": "archer", "image": ""}]}
	Rencontres.epargner_pacifiques(donjon, groupe)
	verifier(heros.piece_or == roundi(7 * Karma.facteur_or(heros)), "pacifiques épargnés : 7 pièces réglées")
	DonneesEnnemis.recharger()
	print("BILAN outil perspective : %d échec(s)" % echecs)
	quit()
