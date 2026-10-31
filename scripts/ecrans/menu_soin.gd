extends Ecran
## Source de soin d'une salle bonus : « Boire » applique le soin, « Laisser » la garde.

var personnage
var salle: Dictionary
var tirage: Array
var cadre := Rect2(Ui.LARGEUR / 2 - 220, 50, 440, 210)
var btn_prendre: Rect2
var btn_laisser: Rect2


func preparer(p, s: Dictionary) -> Ecran:
	personnage = p
	salle = s
	tirage = SallesBonus.tirer_soin(s)
	btn_prendre = Rect2(cadre.get_center().x - 170, cadre.end.y - 52, 160, 38)
	btn_laisser = Rect2(cadre.get_center().x + 10, cadre.end.y - 52, 160, 38)
	return self


func _mise_a_jour(_delta: float) -> void:
	fond_ecran = "salles/image_soin_vide.png" if salle.get("soin_utilise", false) else "salles/image_soin.png"


func _dessiner(ci: Control) -> void:
	var s := souris()
	var type_soin: String = tirage[0]
	var pourcent: float = tirage[1]
	Ui.panneau(ci, cadre)
	Ui.texte(ci, "Source de soin mystique", Vector2(cadre.get_center().x, cadre.position.y + 14), Ui.OR, 22, true, null, "midtop")
	Ui.texte(ci, "Elle rend %s %% %s." % [U.f(pourcent * 100), SallesBonus.NOMS_SOIN[type_soin]], Vector2(cadre.get_center().x, cadre.position.y + 52),
		Ui.TEXTE, 17, false, null, "midtop")
	var gains := SallesBonus.gains_soin(personnage, type_soin, pourcent)
	var morceaux := []
	if type_soin in ["pv", "tout"]:
		morceaux.append("+%d PV" % gains[0])
	if type_soin in ["mana", "tout"]:
		morceaux.append("+%d mana" % gains[1])
	Ui.texte(ci, "Pour vous : " + ", ".join(morceaux), Vector2(cadre.get_center().x, cadre.position.y + 80), Ui.VERT, 17, true, null, "midtop")
	Ui.texte(ci, "PV %d / %d  ·  Mana %d / %d" % [int(personnage.points_de_vie), int(personnage.points_de_vie_max), int(personnage.mana), int(personnage.mana_max)],
		Vector2(cadre.get_center().x, cadre.position.y + 108), Ui.DETAIL, 14, false, null, "midtop")
	Ui.bouton(ci, btn_prendre, "Boire", Ui.BOUTON_VERT, btn_prendre.has_point(s))
	Ui.bouton(ci, btn_laisser, "Laisser", Ui.BOUTON_ROUGE, btn_laisser.has_point(s))
	definir_zones([[["prendre"], btn_prendre], [["laisser"], btn_laisser]], ["prendre"])


func _evenement(ev: Dictionary) -> void:
	if ev["type"] == "touche" and ev["touche"] == KEY_ESCAPE:
		fermer()
	elif ev["type"] == "clic" and ev["bouton"] == 1:
		if btn_prendre.has_point(ev["pos"]):
			SallesBonus.boire_source(personnage, salle)
			fermer()
		elif btn_laisser.has_point(ev["pos"]):
			fermer()
