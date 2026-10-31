extends Control
## Banc d'essai à jouer soi-même : un geôlier fait sa ronde dans la salle de la porte 2 (marche animée de Grok).
## S'il touche le héros, la première capture échoue (baiser de la succube, pour pouvoir continuer à le regarder) ;
## la suivante emmène le héros au cachot. Fermer la fenêtre pour quitter. Lancer :
##   Godot_v4.7.2-stable_win64.exe --path . res://tests/voir_geolier.tscn   (ou voir_geolier.bat)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color8(20, 18, 26))
	Ecrans.racine = self
	lancer()


func lancer() -> void:
	await get_tree().process_frame
	Sauvegarde.reinitialiser_monde()
	Statistiques.mort = false
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	PlanSalles.attribuer(donjon, 1)
	var salle: Dictionary = donjon.salle_courante()
	salle["salle_peinte"]["image"] = "porte2"
	salle["salle_peinte"]["miroir"] = false
	salle["salle_peinte"]["sorties"] = [null, null, null, null]
	salle["objets"] = []
	salle["objets_image"] = "porte2"
	salle["presences"] = [{"id": 501, "genre": "geolier", "etat": "actif"}]
	Aventure.meta(donjon, 1)["prepare"] = true
	Aventure.sceller_pacte(donjon, "baiser")
	var nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
	Ecrans.pile.append(nav)
	add_child(nav)
