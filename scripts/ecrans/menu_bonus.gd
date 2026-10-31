extends Ecran
## Trois bonus mystiques permanents au choix (menu_bonus.py). « Laisser » garde le choix pour plus tard.

var personnage
var salle: Dictionary
var choix := []
var boutons := []
var btn_laisser: Rect2


func preparer(p, s: Dictionary) -> Ecran:
	personnage = p
	salle = s
	choix = SallesBonus.choix_bonus(s)
	for i in choix.size():
		boutons.append(Rect2(Ui.LARGEUR / 2 - 260, 112 + i * 92, 520, 80))
	btn_laisser = Rect2(Ui.LARGEUR / 2 - 80, boutons[-1].end.y + 18, 160, 38)
	return self


func _mise_a_jour(_delta: float) -> void:
	fond_ecran = "salles/image_bonus_vide.png" if salle.get("effet_utilise", false) else "salles/image_bonus.png"


func _dessiner(ci: Control) -> void:
	var s := souris()
	Ui.panneau(ci, Rect2(Ui.LARGEUR / 2 - 280, 40, 560, btn_laisser.end.y - 40 + 16))
	Ui.texte(ci, "Choisissez un bonus mystique", Vector2(Ui.LARGEUR / 2, 56), Ui.OR, 22, true, null, "midtop")
	Ui.texte(ci, "Il est permanent. Un seul choix possible.", Vector2(Ui.LARGEUR / 2, 86), Ui.DETAIL, 14, false, null, "midtop")
	for i in choix.size():
		var r: Rect2 = boutons[i]
		var o: Array = choix[i]
		var survol := r.has_point(s)
		Ui.rect(ci, r, Ui.LIGNE_SURVOL if survol else Ui.LIGNE, 0, 8)
		Ui.rect(ci, r, Ui.OR if survol else Ui.BRONZE, 2 if survol else 1, 8)
		Ui.texte(ci, o[0], r.position + Vector2(16, 10), Ui.BLANC, 19, true)
		Ui.texte(ci, o[4], r.position + Vector2(16, 36), Ui.DETAIL, 14, false, r.size.x - 32)
		var avant := SallesBonus.valeur_bonus(personnage, o[1], o[3])
		personnage.set(o[1], personnage.get(o[1]) + o[2])
		var apres := SallesBonus.valeur_bonus(personnage, o[1], o[3])
		personnage.set(o[1], personnage.get(o[1]) - o[2])
		Ui.texte(ci, "Actuellement %s → %s" % [avant, apres], r.position + Vector2(16, 56), Ui.VERT, 14)
	Ui.bouton(ci, btn_laisser, "Laisser", Ui.BOUTON_ROUGE, btn_laisser.has_point(s))
	var z := []
	for i in boutons.size():
		z.append([["bonus", i], boutons[i]])
	z.append([["laisser"], btn_laisser])
	definir_zones(z, ["bonus", 0])


func _evenement(ev: Dictionary) -> void:
	if ev["type"] == "touche" and ev["touche"] == KEY_ESCAPE:
		fermer()
	elif ev["type"] == "clic" and ev["bouton"] == 1:
		if btn_laisser.has_point(ev["pos"]):
			fermer()
			return
		for i in boutons.size():
			if boutons[i].has_point(ev["pos"]):
				SallesBonus.appliquer_bonus(personnage, salle, choix[i])
				fermer()
				return
