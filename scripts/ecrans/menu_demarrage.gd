extends Ecran
## Menu de démarrage (menu_partie.afficher_menu_demarrage) : « Continuer », « Nouvelle partie »,
## « Charger une partie », « Options », « Quitter ». Résultat : « continuer », « nouvelle », ["charger", nom] ou « quitter ».

var boutons := MenuPartie.boutons_colonne(["Continuer", "Nouvelle partie", "Charger une partie", "Options", "Quitter"],
	Ui.LARGEUR / 2, 210, 300, 42, 10)
var message := ""
var message_fin := 0.0
var resume_temp = null


func preparer(texte := "") -> Ecran:
	fond_ecran = "salles/menu_navigation.png"
	message = texte
	message_fin = Animations.temps() + 4 if texte != "" else 0.0
	return self


func _mise_a_jour(_delta: float) -> void:
	resume_temp = Sauvegarde.resume(Sauvegarde.TEMPORAIRE)


func _dessiner(ci: Control) -> void:
	Ui.voile(ci, 140)
	Ui.texte(ci, "LE DONJON", Vector2(Ui.LARGEUR / 2, 110), Ui.OR, 54, true, null, "center")
	Ui.texte(ci, "Menu principal", Vector2(Ui.LARGEUR / 2, 160), Ui.DETAIL, 18, false, null, "center")
	var s := souris()
	for nom in boutons:
		var r: Rect2 = boutons[nom]
		var actif: bool = nom != "Continuer" or resume_temp != null
		var couleur := Ui.BOUTON_VERT if nom == "Continuer" else (Ui.BOUTON_ROUGE if nom == "Quitter" else Ui.BOUTON_NEUTRE)
		Ui.bouton(ci, r, nom, couleur, r.has_point(s), actif, 18)
	Ui.texte(ci, MenuPartie.texte_resume(resume_temp) if resume_temp != null else "Aucune partie en cours",
		Vector2(Ui.LARGEUR / 2, boutons["Continuer"].position.y - 12), Ui.DETAIL, 13, false, Ui.LARGEUR - 40, "center")
	if message != "" and Animations.temps() < message_fin:
		Ui.message(ci, message, Vector2(Ui.LARGEUR / 2, Ui.HAUTEUR - 40), Ui.ROUGE)
	var z := []
	for nom in boutons:
		if nom != "Continuer" or resume_temp != null:
			z.append([["bouton", nom], boutons[nom]])
	definir_zones(z, ["bouton", "Continuer" if resume_temp != null else "Nouvelle partie"])


func _evenement(ev: Dictionary) -> void:
	if ev["type"] != "clic" or ev["bouton"] != 1:
		return
	var choix = MenuPartie.bouton_sous(boutons, ev["pos"])
	if choix == "Continuer" and resume_temp != null:
		fermer("continuer")
	elif choix == "Nouvelle partie":
		fermer("nouvelle")
	elif choix == "Charger une partie":
		var nom = await Ecrans.choisir_emplacement("charger", fond_ecran)
		if nom != null:
			fermer(["charger", nom])
	elif choix == "Options":
		await Ecrans.options()
	elif choix == "Quitter":
		fermer("quitter")
