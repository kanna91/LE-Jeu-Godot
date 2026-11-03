extends Ecran
## Carte complète de l'étage, avec légende (carte.afficher_carte_complete). Échap, Tab ou « Fermer ».

var donjon
var fond_capture: Texture2D
var zone := Rect2(30, 60, Ui.LARGEUR - 60, Ui.HAUTEUR - 150)
var pas := 24.0
var centre := Vector2.ZERO
var bouton := Rect2(Ui.LARGEUR - 150, Ui.HAUTEUR - 50, 130, 36)


func preparer(d, capture: Texture2D) -> Ecran:
	donjon = d
	fond_capture = capture
	particules_fond = false
	var salles: Dictionary = d.plan_donjon.get(d.salle_actuelle[0], {})
	var positions := []
	for i in Carte.etats_salles(d):
		positions.append(salles[i]["position"])
	var min_x: int = positions[0].x
	var max_x: int = positions[0].x
	var min_y: int = positions[0].y
	var max_y: int = positions[0].y
	for p in positions:
		min_x = mini(min_x, p.x)
		max_x = maxi(max_x, p.x)
		min_y = mini(min_y, p.y)
		max_y = maxi(max_y, p.y)
	pas = maxf(12, minf(40, minf((zone.size.x - 40) / (max_x - min_x + 1), (zone.size.y - 30) / (max_y - min_y + 1))))
	centre = Vector2((min_x + max_x) / 2.0, (min_y + max_y) / 2.0)
	return self


func _dessiner_fond(ci: Control) -> void:
	if fond_capture != null:
		ci.draw_texture_rect(fond_capture, Rect2(0, 0, Ui.LARGEUR, Ui.HAUTEUR), false)


func _dessiner(ci: Control) -> void:
	var etage = donjon.salle_actuelle[0]
	var salles: Dictionary = donjon.plan_donjon.get(etage, {})
	Ui.voile(ci, 225)
	Ui.panneau(ci, zone.grow(8), 225)
	Carte.dessiner_etage(ci, donjon, zone, pas, centre, int(pas * 0.62))
	var explorees := 0
	for s in salles.values():
		if s.get("visitee", false):
			explorees += 1
	Ui.texte(ci, "Carte de " + Donjon.nom_niveau(etage), Vector2(Ui.LARGEUR / 2, 26), Ui.OR, 22, true, null, "center")
	Ui.texte(ci, "%d salles explorées sur %d" % [explorees, salles.size()], zone.position + Vector2(6, 4), Ui.DETAIL, 13)
	var x := 30.0
	for l in Carte.LEGENDE:
		var genre: String = l[0]
		var centre_icone := Vector2(x + 9, Ui.HAUTEUR - 32)
		if Carte.COULEURS.has(genre):
			var r := Rect2(centre_icone - Vector2(8, 8), Vector2(16, 16))
			Ui.rect(ci, r, Carte.COULEURS[genre], 0, 3)
			Ui.rect(ci, r, Color8(230, 225, 210), 1, 3)
			if genre == "boss":
				Carte.dessiner_pictogramme(ci, "boss", centre_icone, 16)
			elif genre == "connue":
				Ui.texte(ci, "?", centre_icone, Color8(150, 145, 160), 12, true, null, "center")
		else:
			Carte.dessiner_pictogramme(ci, genre, centre_icone, 16)
		x = Ui.texte(ci, l[1], Vector2(x + 22, Ui.HAUTEUR - 32), Ui.TEXTE, 13, false, null, "midleft").end.x + 14
	Ui.bouton(ci, bouton, "Fermer", Ui.BOUTON_ROUGE, bouton.has_point(souris()))
	definir_zones([[["fermer"], bouton]], ["fermer"])


func _evenement(ev: Dictionary) -> void:
	if ev["type"] == "touche" and ev["touche"] in [KEY_ESCAPE, KEY_TAB]:
		fermer()
	elif ev["type"] == "clic" and ev["bouton"] == 1 and bouton.has_point(ev["pos"]):
		fermer()
