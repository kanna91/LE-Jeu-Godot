extends SceneTree
## Captures (2026-11-03) : escaliers des passages prison <-> cryptes sur la mini-carte (180 : cryptes, 181 : couloir
## de prison sur l'étage) et sur la carte complète (182). Fenêtre hors écran (override.cfg, voir README) :
## godot --path . -s tests/capture_escaliers_carte.gd

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
	seed(11)
	Sauvegarde.reinitialiser_monde()
	Ecrans.auto = true
	var joueur = Personnage.nouveau()
	var donjon = Donjon.nouveau(joueur)
	var entree := ""
	var couloir := ""
	for niveau in [1, Donjon.NIVEAU_CRYPTES]:
		for id in donjon.plan_donjon[niveau]:
			var s: Dictionary = donjon.plan_donjon[niveau][id]
			s.erase("evenement")
			s["presences"] = []
			if niveau == Donjon.NIVEAU_CRYPTES:
				s["visitee"] = true
				if s.has("passage_niveau") and entree == "":
					entree = id
			elif s.has("passage_niveau") and couloir == "":
				couloir = id
	donjon.salle_actuelle = [Donjon.NIVEAU_CRYPTES, int(entree)]
	var nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
	Ecrans.ouvrir(nav)
	await capturer("180_escaliers_mini_carte_cryptes")
	var carte = Ecrans._ecran("carte_complete").preparer(donjon, null)
	Ecrans.ouvrir(carte)
	await capturer("182_escaliers_carte_cryptes")
	carte.fermer()
	await attendre(2)
	donjon.plan_donjon[1][couloir]["visitee"] = true
	donjon.salle_actuelle = [1, int(couloir)]
	nav._afficher_salle(-1)
	await capturer("181_escalier_mini_carte_couloir")
	quit()
