extends SceneTree
## Captures d'écran de contrôle (rendu interne de la fenêtre, pas de capture du bureau).
## Lancer avec un override.cfg qui place la fenêtre hors écran et sans focus.

var racine: Control
var n := 0


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
	await attendre(3)
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("res://tests/captures/%s.png" % nom)
	print("capture ", nom)


func clic(pos: Vector2) -> void:
	var ecran = Ecrans.pile[-1]
	ecran._traiter([{"type": "clic", "pos": pos, "bouton": 1, "double": false}])
	await attendre(2)


func touche(t: int) -> void:
	var ecran = Ecrans.pile[-1]
	ecran._traiter([{"type": "touche", "touche": t, "repete": false}])
	await attendre(2)


func lancer() -> void:
	seed(4242)
	await attendre(2)
	Ecrans.menu_demarrage()
	await capturer("01_demarrage")
	await clic(Vector2(480, 220 + 56 + 22))  # Nouvelle partie
	Sauvegarde.reinitialiser_monde()
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	Ecrans.menu_sort_depart(joueur)
	await capturer("02_sort_depart")
	await clic(Vector2(200, 140))
	await capturer("03_sort_choisi")
	Ecrans.pile[-1].fermer(null)
	Ecrans.menu_navigation(joueur, donjon)
	await capturer("04_navigation")
	await touche(KEY_TAB)
	await capturer("05_carte")
	await touche(KEY_ESCAPE)
	var combat := Combat.nouveau(joueur, null, donjon.generer_nombre_ennemis() + donjon.creer_boss_gobelin(), donjon)
	combat.mener_combat()
	await attendre(30)
	await capturer("06_combat")
	var ecran = Ecrans.pile[-1]
	if ecran.ennemis_rects_images.size() > 0:
		var r: Rect2 = ecran.ennemis_rects_images[0][0]
		await clic(Vector2(380, 495))  # Frénésie / attaque puissante
		await clic(r.get_center())
		await attendre(12)
		await capturer("07_combat_coup")
		await attendre(25)
		await capturer("08_combat_apres")
	print("fin")
	quit()
