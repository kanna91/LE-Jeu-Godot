extends Ecran
## Liste des potions en combat (menu_combat.choisir_objet_combat) : objet choisi, ou null.

const NOMS_EFFETS := {"pv": "PV", "mana": "mana", "mixte": "PV et mana"}

var joueur
var fond_capture: Texture2D
var boutons := []
var rect_retour := Rect2()


func preparer(j, capture: Texture2D) -> Ecran:
	joueur = j
	fond_capture = capture
	particules_fond = false
	Manette.focus = null
	return self


func _calculer() -> void:
	var consommables := []
	for o in joueur.inventaire:
		if U.ga(o, "type_objet", null) == "consommable" and U.vrai(U.ga(o, "effet", null)):
			consommables.append(o)
	var piles := DescriptionObjet.regrouper(consommables)
	boutons = []
	for i in piles.size():
		boutons.append([piles[i][2], Rect2(Ui.LARGEUR / 2 - 240, 110 + i * 50, 480, 40), piles[i][0], piles[i][1]])
	rect_retour = Rect2(Ui.LARGEUR / 2 - 100, 110 + piles.size() * 50 + 20, 200, 40)


func _dessiner_fond(ci: Control) -> void:
	if fond_capture != null:
		ci.draw_texture_rect(fond_capture, Rect2(0, 0, Ui.LARGEUR, Ui.HAUTEUR), false)


func _dessiner(ci: Control) -> void:
	_calculer()
	var s := souris()
	Ui.voile(ci, 170)
	Ui.texte(ci, "Utiliser un objet (coûte 1 PA — PA restants : %d)" % joueur.points_d_action, Vector2(Ui.LARGEUR / 2, 60), Ui.BLANC, 18, false, null, "midtop")
	if boutons.is_empty():
		Ui.texte(ci, "Aucun objet utilisable.", Vector2(Ui.LARGEUR / 2, 120), Color8(200, 200, 200), 18, false, null, "midtop")
	for b in boutons:
		var r: Rect2 = b[1]
		var objet = b[2]
		Ui.rect(ci, r, Color8(90, 90, 150) if r.has_point(s) else Color8(60, 60, 110), 0, 6)
		var effet: Dictionary = objet.effet
		var detail := ("+%d %s" % [int(effet.get("valeur", 0)), NOMS_EFFETS.get(effet.get("type"), "")]) if U.vrai(effet.get("fixe", false)) \
			else "+%d %% %s" % [int(effet.get("valeur", 0) * 100), NOMS_EFFETS.get(effet.get("type"), "")]
		var r_nom := Ui.texte(ci, objet.nom, r.position + Vector2(12, 10), Ui.BLANC, 18)
		if b[3] > 1:
			Ui.texte(ci, "×%d" % b[3], Vector2(r_nom.end.x + 8, r.position.y + 10), Ui.OR, 18)
		Ui.texte(ci, detail, Vector2(r.end.x - 12, r.position.y + 10), Ui.OR, 18, false, null, "topright")
	Ui.rect(ci, rect_retour, Color8(170, 60, 60) if rect_retour.has_point(s) else Color8(130, 40, 40), 0, 6)
	Ui.texte(ci, "Retour", rect_retour.get_center(), Ui.BLANC, 18, false, null, "center")
	var z := []
	for b in boutons:
		z.append([b[0], b[1]])
	z.append([["retour"], rect_retour])
	definir_zones(z, boutons[0][0] if not boutons.is_empty() else ["retour"])


func _evenement(ev: Dictionary) -> void:
	if ev["type"] == "touche" and ev["touche"] == KEY_ESCAPE:
		fermer(null)
	elif ev["type"] == "clic" and ev["bouton"] == 1:
		_calculer()
		if rect_retour.has_point(ev["pos"]):
			fermer(null)
			return
		for b in boutons:
			if b[1].has_point(ev["pos"]):
				fermer(b[2])
				return
