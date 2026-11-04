extends SceneTree
## Captures (2026-11-04) : étage carré en 5 secteurs (GenerateurEtage), toutes les salles vues, sur la carte complète
## du jeu (270 à 272 : trois étages tirés au hasard). Fenêtre hors écran (override.cfg, voir README) :
## godot --path . -s tests/capture_etage_carre.gd

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
	Ecrans.auto = true
	for n in 3:
		seed(40 + n)
		Sauvegarde.reinitialiser_monde()
		var joueur = Personnage.nouveau()
		var donjon = Donjon.nouveau(joueur)
		for id in donjon.plan_donjon[1]:
			donjon.plan_donjon[1][id]["visitee"] = true
		donjon.salle_actuelle = [1, 1]
		var carte = Ecrans._ecran("carte_complete").preparer(donjon, null)
		Ecrans.ouvrir(carte)
		await capturer("%d_etage_carre_%d" % [270 + n, n + 1])
		carte.fermer()
		await attendre(2)
	quit()
