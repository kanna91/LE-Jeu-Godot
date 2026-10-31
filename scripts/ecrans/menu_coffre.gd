extends Ecran
## Coffre d'une salle bonus : or, objet (comparé à l'équipement) et potion éventuelle.
## « Prendre » vide le coffre ; « Laisser » (ou Échap) le garde pour plus tard.

var joueur
var salle: Dictionary
var contenu: Dictionary
var cadre := Rect2(Ui.LARGEUR / 2 - 230, 40, 460, 300)
var btn_prendre: Rect2
var btn_laisser: Rect2


func preparer(j, _donjon, s: Dictionary) -> Ecran:
	fond_ecran = "salles/image_coffre_plein01.png"
	joueur = j
	salle = s
	contenu = SallesBonus.contenu_coffre(s)
	btn_prendre = Rect2(cadre.get_center().x - 170, cadre.end.y - 52, 160, 38)
	btn_laisser = Rect2(cadre.get_center().x + 10, cadre.end.y - 52, 160, 38)
	return self


func _dessiner(ci: Control) -> void:
	var s := souris()
	var objet = contenu["objet"]
	Ui.panneau(ci, cadre)
	Ui.texte(ci, "Coffre découvert !", Vector2(cadre.get_center().x, cadre.position.y + 14), Ui.OR, 22, true, null, "midtop")
	var potion = contenu.get("potion")
	Ui.texte(ci, "Or : %d PO" % contenu["or"] + (("  ·  " + potion.nom) if potion != null else ""), Vector2(cadre.get_center().x, cadre.position.y + 48),
		Ui.OR, 18, true, null, "midtop")
	var rg := DescriptionObjet.rang(objet)
	Ui.texte(ci, objet.nom, cadre.position + Vector2(24, 82), rg[1], 18, true, cadre.size.x - 48)
	Ui.texte(ci, DescriptionObjet.categorie(objet) + ((" · " + rg[0]) if rg[0] != "" else ""), cadre.position + Vector2(24, 104), Ui.DETAIL, 13)
	var stats := DescriptionObjet.statistiques(objet)
	var equipe = DescriptionObjet.objet_equipe(joueur, objet)
	for i in mini(6, stats.size()):
		Ui.texte(ci, stats[i][3], cadre.position + Vector2(24, 126 + i * 18), Ui.TEXTE, 14, false, 200)
	var x_comp := cadre.position.x + 240
	if equipe != null:
		Ui.texte(ci, "Comparé à %s :" % equipe.nom, Vector2(x_comp, cadre.position.y + 126), Ui.DETAIL, 13, true, 200)
		var comparaison := DescriptionObjet.comparaison(objet, equipe)
		for i in mini(5, comparaison.size()):
			Ui.texte(ci, comparaison[i][0], Vector2(x_comp, cadre.position.y + 144 + i * 18), comparaison[i][1], 14, false, 200)
	elif DescriptionObjet.emplacement_cible(joueur, objet) != null:
		Ui.texte(ci, "Emplacement %s libre" % DescriptionObjet.NOMS_EMPLACEMENTS.get(DescriptionObjet.emplacement_cible(joueur, objet), ""),
			Vector2(x_comp, cadre.position.y + 126), Ui.VERT, 13, false, 200)
	Ui.bouton(ci, btn_prendre, "Prendre", Ui.BOUTON_VERT, btn_prendre.has_point(s))
	Ui.bouton(ci, btn_laisser, "Laisser", Ui.BOUTON_ROUGE, btn_laisser.has_point(s))
	definir_zones([[["prendre"], btn_prendre], [["laisser"], btn_laisser]], ["prendre"])


func _evenement(ev: Dictionary) -> void:
	if ev["type"] == "touche" and ev["touche"] == KEY_ESCAPE:
		fermer()
	elif ev["type"] == "clic" and ev["bouton"] == 1:
		if btn_prendre.has_point(ev["pos"]):
			SallesBonus.prendre_coffre(joueur, salle)
			fermer()
		elif btn_laisser.has_point(ev["pos"]):
			fermer()
