extends SceneTree
## Captures du combat contre un ennemi seul (centré) et contre le boss seul : 29_combat_seul, 30_combat_boss.
## Lancer avec un override.cfg qui place la fenêtre hors écran et sans focus (voir README).

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
	await attendre(3)
	root.get_viewport().get_texture().get_image().save_png("res://tests/captures/%s.png" % nom)
	print("capture ", nom)


func lancer() -> void:
	seed(77)
	await attendre(2)
	Sauvegarde.reinitialiser_monde()
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	Ecrans.menu_navigation(joueur, donjon)
	await attendre(5)
	for cas in [["29_combat_seul", [Gobelin.nouveau(donjon).generer_gobelin(donjon)]], ["30_combat_boss", donjon.creer_boss_gobelin()]]:
		var combat := Combat.nouveau(joueur, null, cas[1], donjon)
		combat.mener_combat()
		await attendre(30)
		var ecran = Ecrans.pile[-1]
		var r: Rect2 = ecran.rect_ennemi(cas[1][0])
		print("%s : sprite de x = %d à %d (centre %d ; écran %d)" % [cas[0], r.position.x, r.end.x, r.get_center().x, Ui.LARGEUR])
		await capturer(cas[0])
		ecran.fermer()
		await attendre(5)
	print("fin")
	quit()
