extends Control
## Point d'entrée (menu_navigation.lancer_jeu) : menu de démarrage, puis parties successives.
##
## « Nouvelle partie » efface la sauvegarde temporaire ; « Continuer » la recharge ;
## quitter le jeu ou revenir au menu principal écrit la sauvegarde temporaire
## (y compris si la fenêtre est fermée pendant une partie) ; à la mort du héros,
## la sauvegarde temporaire est effacée et l'écran de fin propose de recommencer.

var joueur = null
var donjon = null
var partie_en_cours := false


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	RenderingServer.set_default_clear_color(Color8(20, 18, 26))
	Ecrans.racine = self
	lancer_jeu()


func _notification(quoi: int) -> void:
	if quoi == NOTIFICATION_WM_CLOSE_REQUEST:
		if partie_en_cours and joueur != null and not Statistiques.mort:
			Sauvegarde.sauvegarder(Sauvegarde.TEMPORAIRE, joueur, donjon)
		SallePeinte.liberer()
		get_tree().quit()


## Nouveau héros et nouveau donjon, puis choix du sort de départ.
func nouvelle_partie() -> void:
	Sauvegarde.reinitialiser_monde()
	Statistiques.mort = false
	joueur = Personnage.nouveau()
	donjon = Donjon.nouveau(joueur)
	await Ecrans.menu_sort_depart(joueur)


func charger_partie(nom: String) -> bool:
	if not Sauvegarde.existe(nom):
		return false
	var resultat := Sauvegarde.charger(nom)
	if resultat.is_empty() or resultat[0] == null:
		print("Sauvegarde « %s » illisible" % nom)
		return false
	joueur = resultat[0]
	donjon = resultat[1]
	Statistiques.mort = false
	return true


func lancer_jeu() -> void:
	var action = await Ecrans.menu_demarrage()
	while action != "quitter":
		if action == "nouvelle":
			Sauvegarde.supprimer(Sauvegarde.TEMPORAIRE)
			await nouvelle_partie()
		elif action == "continuer" or (action is Array and action[0] == "charger"):
			var nom: String = Sauvegarde.TEMPORAIRE if action is String else action[1]
			if not charger_partie(nom):
				action = await Ecrans.menu_demarrage("Cette sauvegarde est illisible.")
				continue
		partie_en_cours = true
		var resultat = await Ecrans.menu_navigation(joueur, donjon)
		partie_en_cours = false
		if resultat is Array and resultat[0] in ["mort", "victoire"]:
			Sauvegarde.supprimer(Sauvegarde.TEMPORAIRE)
			var choix = await Ecrans.ecran_mort(joueur, donjon, resultat[1] if resultat[0] == "mort" else "victoire")
			if choix == "recommencer":
				action = "nouvelle"
			elif choix == "quitter":
				action = "quitter"
			else:
				action = await Ecrans.menu_demarrage()
		elif resultat is Array:
			action = resultat
		else:
			Sauvegarde.sauvegarder(Sauvegarde.TEMPORAIRE, joueur, donjon)
			action = "quitter" if resultat == "quitter" else await Ecrans.menu_demarrage()
	SallePeinte.liberer()
	get_tree().quit()
