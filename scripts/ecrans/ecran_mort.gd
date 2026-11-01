extends Ecran
## Écran de fin de partie (menu_partie.afficher_ecran_mort) : statistiques et « Recommencer ». Cause « victoire »
## (boss du dernier étage vaincu, puis « Monter », 2026-10-30) : même écran, titre « VICTOIRE ».
## Résultat : « recommencer », « menu » ou « quitter ».

var joueur
var lignes := []
var sous_titre := ""
var victoire := false
var cadre := Rect2(60, 112, Ui.LARGEUR - 120, 330)
var boutons := {}


func preparer(j, donjon, cause := "combat") -> Ecran:
	fond_ecran = "salles/image_boss.png"
	joueur = j
	lignes = Statistiques.bilan(j, donjon)
	victoire = cause == "victoire"
	if victoire:
		sous_titre = "Le boss du dernier étage est vaincu : vous sortez du donjon"
	else:
		sous_titre = "%s à l'étage %d, salle %d" % [MenuPartie.CAUSES.get(cause, "Mort"), donjon.salle_actuelle[0], donjon.salle_actuelle[1]]
	var noms := ["Recommencer", "Menu principal", "Quitter"]
	for i in noms.size():
		boutons[noms[i]] = Rect2(Ui.LARGEUR / 2 - 330 + i * 230, Ui.HAUTEUR - 82, 200, 44)
	return self


func _dessiner(ci: Control) -> void:
	Ui.voile(ci, 170)
	Ui.texte(ci, "VICTOIRE" if victoire else "VOUS ÊTES MORT", Vector2(Ui.LARGEUR / 2, 55), Ui.OR if victoire else Ui.ROUGE,
		40, true, null, "center")
	Ui.texte(ci, "%s · %s" % [joueur.nom, sous_titre], Vector2(Ui.LARGEUR / 2, 95), Ui.DETAIL, 16, false, null, "center")
	Ui.panneau(ci, cadre, 225)
	Ui.texte(ci, "Statistiques de la partie", cadre.position + Vector2(18, 12), Ui.OR, 18, true)
	var par_colonne := (lignes.size() + 1) / 2
	for i in lignes.size():
		var colonne := i / par_colonne
		var rang := i % par_colonne
		var x := cadre.position.x + 22 + colonne * int(cadre.size.x / 2)
		# Pas des lignes ajusté pour que toute la liste tienne dans le cadre (elle débordait sous les boutons)
		var pas := minf(25.0, (cadre.size.y - 56) / maxf(1, par_colonne))
		var y := cadre.position.y + 44 + rang * pas
		Ui.texte(ci, lignes[i][0], Vector2(x, y), Ui.TEXTE, 14)
		Ui.texte(ci, lignes[i][1], Vector2(x + int(cadre.size.x / 2) - 50, y), Ui.OR, 14, true, null, "topright")
	var s := souris()
	for nom in boutons:
		var couleur := Ui.BOUTON_VERT if nom == "Recommencer" else (Ui.BOUTON_ROUGE if nom == "Quitter" else Ui.BOUTON_NEUTRE)
		Ui.bouton(ci, boutons[nom], nom, couleur, boutons[nom].has_point(s), true, 17)
	var z := []
	for nom in boutons:
		z.append([["bouton", nom], boutons[nom]])
	definir_zones(z, ["bouton", "Recommencer"])


func _evenement(ev: Dictionary) -> void:
	if ev["type"] != "clic" or ev["bouton"] != 1:
		return
	var choix = MenuPartie.bouton_sous(boutons, ev["pos"])
	if choix != null:
		fermer({"Recommencer": "recommencer", "Menu principal": "menu", "Quitter": "quitter"}[choix])
