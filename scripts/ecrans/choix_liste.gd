extends Ecran
## Liste de choix d'un PNJ (armurier, alchimiste, enchanteur : choisir une arme, puis une recette ; 2026-11-09).
## Chaque ligne : {texte, detail, actif} ; une ligne inactive est grisée (son détail dit pourquoi) et ne se choisit
## pas. Résultat : l'indice de la ligne choisie, ou -1 (Retour, Échap). Par pages de PAR_PAGE lignes.

const PAR_PAGE := 8

var titre := ""
var sous_titre := ""
var lignes: Array = []
var couleur := Ui.OR
var fond: Texture2D
var page := 0
var cadre := Rect2(90, 40, Ui.LARGEUR - 180, Ui.HAUTEUR - 80)
var rect_retour := Rect2()
var rect_avant := Rect2()
var rect_apres := Rect2()


func preparer(t: String, st: String, options: Array, image_fond: Texture2D = null, teinte := Ui.OR) -> Ecran:
	titre = t
	sous_titre = st
	lignes = options
	fond = image_fond
	couleur = teinte
	particules_fond = false
	var bas := cadre.end.y - 50
	rect_retour = Rect2(cadre.get_center().x - 80, bas, 160, 36)
	rect_avant = Rect2(cadre.position.x + 20, bas, 150, 36)
	rect_apres = Rect2(cadre.end.x - 170, bas, 150, 36)
	return self


func _pages() -> int:
	return maxi(1, ceili(lignes.size() / float(PAR_PAGE)))


func _rect_ligne(k: int) -> Rect2:
	return Rect2(cadre.position.x + 20, cadre.position.y + 84 + k * 46, cadre.size.x - 40, 40)


func _dessiner_fond(ci: Control) -> void:
	if fond != null:
		ci.draw_texture_rect(fond, Rect2(0, 0, Ui.LARGEUR, Ui.HAUTEUR), false)


func _dessiner(ci: Control) -> void:
	var s := souris()
	Ui.voile(ci, 120)
	Ui.panneau(ci, cadre, 235)
	Ui.rect(ci, cadre, couleur, 2, 8)
	Ui.texte(ci, titre, Vector2(cadre.position.x + 20, cadre.position.y + 12), couleur, 20, true)
	Ui.texte(ci, sous_titre, Vector2(cadre.position.x + 20, cadre.position.y + 44), Ui.DETAIL, 14, false, cadre.size.x - 40)
	var z := []
	var debut := page * PAR_PAGE
	for k in range(debut, mini(lignes.size(), debut + PAR_PAGE)):
		var l: Dictionary = lignes[k]
		var r := _rect_ligne(k - debut)
		var actif := bool(l.get("actif", true))
		Ui.rect(ci, r, Ui.LIGNE_SURVOL if (actif and r.has_point(s)) else Ui.LIGNE, 0, 6)
		Ui.texte(ci, String(l.get("texte", "")), r.position + Vector2(12, 3), Ui.BLANC if actif else Ui.GRISE, 16, actif,
			r.size.x - 24)
		Ui.texte(ci, String(l.get("detail", "")), r.position + Vector2(12, 22), Ui.OR if actif else Ui.ROUGE.darkened(0.15), 13,
			false, r.size.x - 24)
		if actif:
			z.append([["ligne", k], r])
	if lignes.is_empty():
		Ui.texte(ci, "Rien à choisir.", Vector2(cadre.get_center().x, cadre.position.y + 110), Ui.DETAIL, 16, false, null, "midtop")
	Ui.bouton(ci, rect_retour, "Retour", Ui.BOUTON_ROUGE, rect_retour.has_point(s))
	z.append([["retour"], rect_retour])
	if _pages() > 1:
		Ui.bouton(ci, rect_avant, "◀ Précédents", Ui.BOUTON_NEUTRE, rect_avant.has_point(s), page > 0)
		Ui.bouton(ci, rect_apres, "Suivants ▶", Ui.BOUTON_NEUTRE, rect_apres.has_point(s), page < _pages() - 1)
		Ui.texte(ci, "Page %d / %d" % [page + 1, _pages()], Vector2(cadre.get_center().x, rect_retour.position.y - 22),
			Ui.DETAIL, 13, false, null, "midtop")
		if page > 0:
			z.append([["avant"], rect_avant])
		if page < _pages() - 1:
			z.append([["apres"], rect_apres])
	definir_zones(z, z[0][0])


func _evenement(ev: Dictionary) -> void:
	if ev["type"] == "touche" and ev["touche"] == KEY_ESCAPE:
		fermer(-1)
	elif ev["type"] == "molette":
		page = clampi(page + (1 if int(ev["sens"]) < 0 else -1), 0, _pages() - 1)
	elif ev["type"] == "clic" and ev["bouton"] == 1:
		var pos: Vector2 = ev["pos"]
		if rect_retour.has_point(pos):
			fermer(-1)
			return
		if _pages() > 1 and rect_avant.has_point(pos) and page > 0:
			page -= 1
			return
		if _pages() > 1 and rect_apres.has_point(pos) and page < _pages() - 1:
			page += 1
			return
		var debut := page * PAR_PAGE
		for k in range(debut, mini(lignes.size(), debut + PAR_PAGE)):
			if _rect_ligne(k - debut).has_point(pos) and bool(lignes[k].get("actif", true)):
				fermer(k)
				return
