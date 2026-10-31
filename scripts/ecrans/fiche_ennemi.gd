extends Ecran
## Fiche détaillée d'un ennemi, par-dessus le combat (fiche_ennemi.afficher_fiche_ennemi).
## Molette / ↑ ↓ / LB-RB : défiler ; ← → : ennemi voisin ; Échap / B / « Fermer » : revenir.

const HAUTEUR_LIGNE := 21

var ennemis := []
var index := 0
var joueur
var fond_capture: Texture2D
var cadre := Rect2(20, 20, Ui.LARGEUR - 40, Ui.HAUTEUR - 40)
var zone_texte: Rect2
var bouton_fermer: Rect2
var defilement := 0.0
var lignes := []


func preparer(liste: Array, i: int, j, capture: Texture2D) -> Ecran:
	ennemis = liste
	index = posmod(i, liste.size())
	joueur = j
	fond_capture = capture
	particules_fond = false
	zone_texte = Rect2(cadre.position.x + 200, cadre.position.y + 55, cadre.size.x - 220, cadre.size.y - 110)
	bouton_fermer = Rect2(cadre.end.x - 130, cadre.end.y - 45, 110, 32)
	lignes = _preparer(ennemis[index])
	return self


func _preparer(ennemi) -> Array:
	var resultat := []
	for l in FicheEnnemi.contenu_fiche(ennemi, joueur):
		var texte := String(l[0]).replace("    ", " · ")
		var gras: bool = l[1] in ["titre", "section"]
		for morceau in FicheEnnemi.decouper(texte, 17 if gras else 16, gras, zone_texte.size.x - 10):
			resultat.append([morceau, l[1]])
	return resultat


func _defilement_max() -> float:
	return maxf(0, lignes.size() * HAUTEUR_LIGNE - zone_texte.size.y)


func _dessiner_fond(ci: Control) -> void:
	if fond_capture != null:
		ci.draw_texture_rect(fond_capture, Rect2(0, 0, Ui.LARGEUR, Ui.HAUTEUR), false)


func _dessiner(ci: Control) -> void:
	defilement = clampf(defilement, 0, _defilement_max())
	var ennemi = ennemis[index]
	Ui.voile(ci, 190)
	Ui.rect(ci, cadre, Color8(25, 22, 30), 0, 10)
	Ui.rect(ci, cadre, Color8(150, 110, 60), 2, 10)
	Ui.texte(ci, ennemi.nom, cadre.position + Vector2(20, 12), FicheEnnemi.COULEURS["titre"], 26, true)
	if ennemis.size() > 1:
		Ui.texte(ci, "Ennemi %d / %d  ·  ← → : ennemi voisin" % [index + 1, ennemis.size()], Vector2(cadre.end.x - 20, cadre.position.y + 20),
			FicheEnnemi.COULEURS["detail"], 16, false, null, "topright")
	var portrait := Rect2(cadre.position.x + 20, cadre.position.y + 60, 150, 225)
	Animations.dessiner_respirant(ci, Ui.texture("gobelins/" + str(ennemi.image)), portrait, Animations.phase_de(ennemi))
	var ratio := maxf(0, ennemi.points_de_vie) / maxf(1, ennemi.points_de_vie_max)
	Ui.rect(ci, Rect2(portrait.position.x, portrait.end.y + 12, 150, 10), Color8(90, 0, 0))
	Ui.rect(ci, Rect2(portrait.position.x, portrait.end.y + 12, int(150 * ratio), 10), Color8(0, 200, 60))
	Ui.texte(ci, "%s / %s PV" % [str(ennemi.points_de_vie), str(ennemi.points_de_vie_max)], Vector2(portrait.position.x, portrait.end.y + 26),
		FicheEnnemi.COULEURS["normal"], 16)
	var y := zone_texte.position.y - defilement
	for l in lignes:
		if zone_texte.position.y - 2 <= y and y + HAUTEUR_LIGNE <= zone_texte.end.y + 2:
			var gras: bool = l[1] in ["titre", "section"]
			Ui.texte(ci, l[0], Vector2(zone_texte.position.x, y), FicheEnnemi.COULEURS[l[1]], 17 if gras else 16, gras)
		y += HAUTEUR_LIGNE
	Ui.ascenseur(ci, zone_texte, defilement, _defilement_max(), zone_texte.end.x + 6)
	Ui.texte(ci, "Défiler : molette, ↑ ↓, LB/RB  ·  Ennemi voisin : ← →  ·  Fermer : Échap, B", Vector2(cadre.position.x + 20, cadre.end.y - 38),
		FicheEnnemi.COULEURS["detail"], 16)
	Ui.rect(ci, bouton_fermer, Color8(130, 40, 40), 0, 6)
	Ui.texte(ci, "Fermer", bouton_fermer.get_center(), Ui.BLANC, 17, true, null, "center")
	definir_zones([[["fermer"], bouton_fermer]], ["fermer"], true)


func _evenement(ev: Dictionary) -> void:
	if ev["type"] == "touche":
		var t: int = ev["touche"]
		if t in [KEY_ESCAPE, KEY_I]:
			fermer()
		elif t in [KEY_DOWN, KEY_S]:
			defilement += HAUTEUR_LIGNE * 3
		elif t in [KEY_UP, KEY_Z, KEY_W]:
			defilement -= HAUTEUR_LIGNE * 3
		elif t in [KEY_LEFT, KEY_RIGHT] and ennemis.size() > 1:
			index = posmod(index + (1 if t == KEY_RIGHT else -1), ennemis.size())
			lignes = _preparer(ennemis[index])
			defilement = 0
	elif ev["type"] == "molette":
		defilement -= ev["sens"] * HAUTEUR_LIGNE * 3
	elif ev["type"] == "clic" and ev["bouton"] == 1 and bouton_fermer.has_point(ev["pos"]):
		fermer()
