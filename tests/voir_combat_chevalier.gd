extends Control
## Banc d'essai à jouer soi-même : combat contre le Chevalier de la mort (attaques et parades animées, images de
## Grok). Le héros a une épée et 999 PV ; le chevalier garde ses règles (300 PV, coups subis ramenés à 1-2).
## Un nouveau combat commence quand le précédent finit (fuite) ; fermer la fenêtre pour quitter. Lancer :
##   Godot_v4.7.2-stable_win64.exe --path . res://tests/voir_combat_chevalier.tscn   (ou voir_combat_chevalier.bat)


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
	joueur.equiper_item(Arme.nouvelle("Epée", "arme", "Epée"))
	Ecrans.menu_navigation(joueur, donjon)
	await get_tree().process_frame
	while not Statistiques.mort:
		joueur.points_de_vie_max = 999
		joueur.points_de_vie = 999
		await Combat.nouveau(joueur, null, [Aventure.creer_imbattable(donjon)], donjon).mener_combat()
		for i in 30:
			await get_tree().process_frame
