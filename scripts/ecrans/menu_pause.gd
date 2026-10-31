extends Ecran
## Menu de pause de l'exploration (menu_partie.afficher_menu_pause).
## Résultat : « reprendre », « menu », « quitter » ou ["charger", nom].

var joueur
var donjon
var fond_capture: Texture2D
var boutons := MenuPartie.boutons_colonne(["Reprendre", "Journal", "Sauvegarder", "Charger une partie", "Options", "Menu principal",
	"Quitter le jeu"], Ui.LARGEUR / 2, 145, 300, 40, 9)
var cadre := Rect2(Ui.LARGEUR / 2 - 190, 80, 380, 444)
var message := ""
var message_fin := 0.0


func preparer(j, d, capture: Texture2D) -> Ecran:
	joueur = j
	donjon = d
	fond_capture = capture
	particules_fond = false
	return self


func _dessiner_fond(ci: Control) -> void:
	if fond_capture != null:
		ci.draw_texture_rect(fond_capture, Rect2(0, 0, Ui.LARGEUR, Ui.HAUTEUR), false)


func _dessiner(ci: Control) -> void:
	Ui.voile(ci, 150)
	Ui.panneau(ci, cadre, 230)
	Ui.texte(ci, "Pause", Vector2(Ui.LARGEUR / 2, 112), Ui.OR, 26, true, null, "center")
	var s := souris()
	for nom in boutons:
		var couleur := Ui.BOUTON_ROUGE if nom == "Quitter le jeu" else (Ui.BOUTON_VERT if nom == "Reprendre" else Ui.BOUTON_NEUTRE)
		Ui.bouton(ci, boutons[nom], nom, couleur, boutons[nom].has_point(s), true, 17)
	Ui.texte(ci, "Quitter ou revenir au menu enregistre la partie (« Continuer »).",
		Vector2(Ui.LARGEUR / 2, cadre.end.y - 22), Ui.DETAIL, 12, false, cadre.size.x - 20, "center")
	if message != "" and Animations.temps() < message_fin:
		Ui.message(ci, message, Vector2(Ui.LARGEUR / 2, Ui.HAUTEUR - 40))
	var z := []
	for nom in boutons:
		z.append([["bouton", nom], boutons[nom]])
	definir_zones(z, ["bouton", "Reprendre"])


func _evenement(ev: Dictionary) -> void:
	if ev["type"] == "touche" and ev["touche"] == KEY_ESCAPE:
		fermer("reprendre")
		return
	if ev["type"] != "clic" or ev["bouton"] != 1:
		return
	var choix = MenuPartie.bouton_sous(boutons, ev["pos"])
	if choix == "Reprendre":
		fermer("reprendre")
	elif choix == "Journal":
		await Ecrans.journal(joueur)
	elif choix == "Sauvegarder":
		var nom = await Ecrans.choisir_emplacement("sauvegarder", fond_capture)
		if nom != null:
			Sauvegarde.sauvegarder(nom, joueur, donjon)
			message = "Partie sauvegardée (%s)." % String(nom).replace("_", " ")
			message_fin = Animations.temps() + 3
	elif choix == "Charger une partie":
		var nom = await Ecrans.choisir_emplacement("charger", fond_capture)
		if nom != null:
			fermer(["charger", nom])
	elif choix == "Options":
		await Ecrans.options(fond_capture)
	elif choix == "Menu principal":
		fermer("menu")
	elif choix == "Quitter le jeu":
		fermer("quitter")
