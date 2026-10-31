extends SceneTree
## Captures des menus du héros (inventaire, caractéristiques, grimoire, améliorations).

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


func clic(pos: Vector2, bouton := 1) -> void:
	Ecrans.pile[-1]._traiter([{"type": "clic", "pos": pos, "bouton": bouton, "double": false}])
	await attendre(2)


func lancer() -> void:
	seed(77)
	Sauvegarde.reinitialiser_monde()
	var joueur := Personnage.nouveau()
	var _donjon := Donjon.nouveau(joueur)
	for i in 6:
		joueur.recevoir_objet(Arme.generer_arme() if i % 2 == 0 else Armure.generer_armure())
	joueur.recevoir_objet(GenerationObjets.generer_anti_boss("foudre", 2))  # armure anti-boss (2026-10-30)
	joueur.points_a_distribuer = 3
	joueur.points_competence_passive_a_distribuer = 2
	joueur.nouvelle_magie_a_apprendre = 1
	Ecrans.menu_inventaire(joueur)
	await capturer("10_inventaire")
	var ecran = Ecrans.pile[-1]
	if not ecran.objets_visuels.is_empty():
		Manette.mode_manette = true  # curseur virtuel : la vraie souris n'est jamais déplacée
		Manette.pos = ecran.objets_visuels[0][1].get_center()
	await capturer("11_inventaire_survol")
	Manette.mode_manette = false
	ecran.fermer()
	await attendre(2)
	Ecrans.menu_caracteristique(joueur)
	await capturer("12_caracteristiques")
	await clic(Vector2(20 + 128 + 60, 108))
	await capturer("13_degats")
	await clic(Vector2(20 + 256 + 60, 108))
	await capturer("14_defense")
	Ecrans.pile[-1].fermer()
	await attendre(2)
	Ecrans.menu_magie(joueur)
	await capturer("15_magies")
	await clic(Vector2(220, 37))
	await capturer("16_competences")
	await clic(Vector2(380, 37))
	await attendre(5)
	await capturer("17_alterations")
	await clic(Vector2(80, 37))
	joueur.magies_apprises[0].points_amélioration = 3
	Ecrans.menu_ameliorer_competence(joueur, joueur.magies_apprises[0])
	await capturer("18_ameliorations")
	print("fin")
	quit()
