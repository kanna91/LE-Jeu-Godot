class_name Dessins
extends RefCounted
## Dessins propres au jeu, partagés par plusieurs écrans :
## boules de vie et de mana, pastilles d'altérations.


## Boule de vie ou de mana : liquide coloré dont le niveau suit le pourcentage (dessiner_sphere).
static func sphere(ci: CanvasItem, centre: Vector2, couleur: Color, pourcentage: float, texte = null) -> void:
	var rayon := 40
	pourcentage = clampf(pourcentage, 0.0, 1.0)
	var niveau := int(round((2 * rayon - 6) * pourcentage))
	Ui.cercle(ci, centre, rayon, Color8(12, 10, 16, 235))
	if niveau > 0:
		var taille := 2 * rayon + 4
		var haut := centre.y - taille / 2.0
		var sombre := Ui.foncer(couleur, 0.55)
		var interieur := rayon - 3
		for y in range(taille - 2 - niveau, taille):
			var t := float(y - (taille - 2 - niveau)) / maxi(1, niveau)
			var teinte := couleur.lerp(sombre, t)
			teinte.a = 1.0
			var dy := haut + y + 0.5 - centre.y
			if absf(dy) >= interieur:
				continue
			var demi := sqrt(interieur * interieur - dy * dy)
			ci.draw_line(Vector2(centre.x - demi, haut + y + 0.5), Vector2(centre.x + demi, haut + y + 0.5), teinte, 1.0)
	var reflet := PackedVector2Array()
	var rc := Vector2(centre.x - rayon - 2 + rayon * 0.45 + rayon * 0.4, centre.y - rayon - 2 + rayon * 0.3 + rayon * 0.225)
	for i in 24:
		var a := TAU * i / 24
		reflet.append(rc + Vector2(cos(a) * rayon * 0.4, sin(a) * rayon * 0.225))
	ci.draw_colored_polygon(reflet, Color8(255, 255, 255, 45))
	Ui.cercle(ci, centre, rayon, Color8(150, 110, 60), 3)
	if texte != null:
		Ui.texte(ci, texte, centre + Vector2(1, 1), Ui.NOIR, 14, true, null, "center")
		Ui.texte(ci, texte, centre, Ui.BLANC, 14, true, null, "center")


## Pastilles des altérations actives (vert : bonus, rouge : malus) : [[rect, nom, données], ...].
static func alterations(ci: CanvasItem, combattant, x: float, y: float, largeur_max: float, abrege := false) -> Array:
	var pastilles := []
	var depart := x
	for a in Alterations.resume(combattant):
		var nom: String = a[0]
		var libelle: String = a[1]
		var t := (libelle.substr(0, 4) + ".") if abrege else libelle
		if a[3] > 1:
			t += " ×%d" % a[3]
		t += " %s" % str(int(a[2]))
		var taille := 11 if abrege else 12
		var r := Rect2(x, y, Ui.taille_texte(t, taille, true).x + 10, 18)
		if r.end.x > depart + largeur_max:
			break
		var bonus: bool = a[4]
		Ui.rect(ci, r, Color8(30, 95, 45) if bonus else Color8(115, 32, 32), 0, 9)
		Ui.rect(ci, r, Color8(120, 230, 130) if bonus else Color8(255, 120, 100), 1, 9)
		Ui.texte(ci, t, Vector2(r.position.x + 5, r.position.y + 2), Ui.BLANC, taille, true)
		pastilles.append([r, nom, combattant.alteration.get(nom, {})])
		x = r.end.x + 4
	return pastilles


## Info-bulle d'une pastille d'altération survolée (renvoie true si une bulle est affichée).
static func infobulle_alterations(ci: CanvasItem, pastilles: Array, souris: Vector2) -> bool:
	for p in pastilles:
		if p[0].has_point(souris):
			var nom: String = p[1]
			var donnees: Dictionary = p[2]
			var lanceur = donnees.get("lanceur")
			var lignes := [Alterations.description(nom, donnees.get("puissance")),
				["Encore %s tour(s)%s" % [str(donnees.get("duree", "?")), (" · infligé par %s" % lanceur.nom) if lanceur != null else ""], Ui.DETAIL]]
			Ui.infobulle(ci, Alterations.libelle(nom), lignes, p[0], 260, Ui.VERT if Alterations.est_bonus(nom) else Ui.ROUGE)
			return true
	return false
