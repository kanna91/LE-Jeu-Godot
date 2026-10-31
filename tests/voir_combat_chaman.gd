extends Control
## Banc d'essai à jouer soi-même : combats à la suite, en alternant combattant + archer + chaman et
## sorcier + combattant + féticheur (animations de combat, CombatAnime). Le héros a une épée, 999 PV et 999 mana et connaît
## Étincelle ardente. Un nouveau combat commence quand le précédent est gagné ; fermer la fenêtre
## pour quitter. Lancer :
##   Godot_v4.7.2-stable_win64.exe --path . res://tests/voir_combat_chaman.tscn


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
	joueur.magies_apprises.append(Competences.creer("Etincelle_ardente"))
	Ecrans.menu_navigation(joueur, donjon)
	await get_tree().process_frame
	var groupes := [[["guerrier", "combattant"], ["guerrier", "archer"], ["soutien", "chaman"]],
		[["mage", "sorcier"], ["guerrier", "combattant"], ["mage", "feticheur"]]]
	var numero := 0
	while not Statistiques.mort:
		joueur.points_de_vie_max = 999
		joueur.points_de_vie = 999
		joueur.mana_max = 999
		joueur.mana = 999
		var ennemis := []
		for cs in groupes[numero % groupes.size()]:
			ennemis.append(Gobelin.nouveau(donjon)._completer(cs[0], cs[1]))
		numero += 1
		await Combat.nouveau(joueur, null, ennemis, donjon).mener_combat()
		for i in 30:
			await get_tree().process_frame
