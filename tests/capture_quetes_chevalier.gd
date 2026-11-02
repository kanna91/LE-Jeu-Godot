extends SceneTree
## Quête du vieux magicien, « AHAHAHAHA ! » (2026-11-02) : le combat contre le Chevalier de la mort commence tout
## de suite (menu_navigation._suites_quete). « BILAN chevalier quête : 0 échec(s) ».
## Fenêtre hors écran (override.cfg, voir README) :   Godot --path . -s tests/capture_quetes_chevalier.gd

var racine: Control


func _initialize() -> void:
	racine = Control.new()
	racine.size = Vector2(960, 540)
	root.add_child(racine)
	Ecrans.racine = racine
	lancer()


func lancer() -> void:
	seed(3)
	Sauvegarde.reinitialiser_monde()
	Statistiques.mort = false
	Ecrans.auto = true
	var joueur = Personnage.nouveau()
	var donjon = Donjon.nouveau(joueur)
	Aventure.preparer_etage(donjon, 1)
	var magicien := {}
	for i in donjon.plan_donjon[1]:
		for p in donjon.plan_donjon[1][i].get("presences", []):
			if p.get("quete") == "magicien":
				magicien = p
				donjon.salle_actuelle = [1, int(i)]
	var nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
	racine.add_child(nav)
	for _k in 10:
		await process_frame
	magicien["etape"] = "rire"
	var r := QuetesPrisonniers.ecouter(donjon, magicien)
	joueur.points_de_vie_max = 100000
	joueur.points_de_vie = 100000  # le héros tient le temps du combat automatique (Ecrans.auto)
	var message: String = await nav._suites_quete(r["suites"])
	print("combat contre le chevalier : ", message, " | mort : ", Statistiques.mort, " | PV ", joueur.points_de_vie, "/", joueur.points_de_vie_max)
	# Victoire, fuite, ou mort du héros (la Lame de la mort retire 15 % des PV max par coup) : le combat a eu lieu
	print("BILAN chevalier quête : %d échec(s)" % (0 if ("fuir" in message or "Victoire" in message or Statistiques.mort) else 1))
	quit()
