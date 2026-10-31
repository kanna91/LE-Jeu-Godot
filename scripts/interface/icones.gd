class_name Icones
extends RefCounted
## Pictogrammes vectoriels des menus : talents, grimoire, caractéristiques, inventaire.
## Dessinés sur une grille de 120 unités, mise à l'échelle de la taille demandée.

const _BASE := 120.0


static func _pentagone(cx: float, cy: float, rayon: float, facteurs = null) -> PackedVector2Array:
	var f: Array = facteurs if facteurs != null else [1, 1, 1, 1, 1]
	var points := PackedVector2Array()
	for i in 5:
		var a := deg_to_rad(-90 + 72 * i)
		points.append(Vector2(cx + rayon * f[i] * cos(a), cy + rayon * f[i] * sin(a)))
	return points


## Dessine un pictogramme carré de côté ``taille`` dont le coin haut gauche est ``origine``.
static func dessiner(ci: CanvasItem, cle: String, origine: Vector2, taille: float, couleur: Color) -> void:
	var k := taille / _BASE
	var fonce := Color8(int(couleur.r8 * 0.25), int(couleur.g8 * 0.25), int(couleur.b8 * 0.25), 170)
	var p := func(v: Vector2) -> Vector2: return origine + v * k
	var pts := func(liste: PackedVector2Array) -> PackedVector2Array:
		var sortie := PackedVector2Array()
		for v in liste:
			sortie.append(origine + v * k)
		return sortie
	var e := func(epaisseur: float) -> float: return maxf(1.0, epaisseur * k)
	match cle:
		"talents":
			var centre := Vector2(60, 60)
			var autour := PackedVector2Array()
			for i in 6:
				var a := deg_to_rad(-90 + 60 * i)
				autour.append(Vector2(60 + 40 * cos(a), 60 + 40 * sin(a)))
			Ui.polygone(ci, pts.call(autour), fonce)
			Ui.polygone(ci, pts.call(autour), couleur, e.call(5))
			for point in autour:
				Ui.ligne(ci, p.call(centre), p.call(point), couleur, e.call(4))
			for point in autour:
				Ui.cercle(ci, p.call(point), 10 * k, couleur)
			Ui.cercle(ci, p.call(centre), 16 * k, couleur)
			Ui.cercle(ci, p.call(centre), 7 * k, Color8(14, 12, 20, 255))
		"magie":
			var gauche := PackedVector2Array([Vector2(10, 30), Vector2(58, 38), Vector2(58, 100), Vector2(10, 92)])
			var droite := PackedVector2Array([Vector2(110, 30), Vector2(62, 38), Vector2(62, 100), Vector2(110, 92)])
			for page in [gauche, droite]:
				Ui.polygone(ci, pts.call(page), fonce)
				Ui.polygone(ci, pts.call(page), couleur, e.call(6))
			for i in 3:
				var y := 52 + i * 13
				Ui.ligne(ci, p.call(Vector2(20, y - 1)), p.call(Vector2(48, y + 4)), couleur, e.call(4))
				Ui.ligne(ci, p.call(Vector2(72, y + 4)), p.call(Vector2(100, y - 1)), couleur, e.call(4))
			Ui.polygone(ci, pts.call(PackedVector2Array([Vector2(80, 33), Vector2(92, 31), Vector2(92, 52), Vector2(86, 46), Vector2(80, 52)])), couleur)
		"caracteristiques":
			var exterieur := _pentagone(60, 64, 50)
			Ui.polygone(ci, pts.call(exterieur), fonce)
			Ui.polygone(ci, pts.call(exterieur), couleur, e.call(5))
			for point in exterieur:
				Ui.ligne(ci, p.call(Vector2(60, 64)), p.call(point), couleur, e.call(2))
			Ui.polygone(ci, pts.call(_pentagone(60, 64, 50, [0.5, 0.5, 0.5, 0.5, 0.5])), couleur, e.call(2))
			var profil := _pentagone(60, 64, 50, [0.9, 0.6, 0.8, 0.45, 0.75])
			Ui.polygone(ci, pts.call(profil), Color8(couleur.r8, couleur.g8, couleur.b8, 150))
			Ui.polygone(ci, pts.call(profil), couleur, e.call(5))
			for point in profil:
				Ui.cercle(ci, p.call(point), 6 * k, couleur)
		"inventaire":
			ci.draw_arc(p.call(Vector2(60, 26)), 18 * k, PI, TAU, 24, couleur, e.call(6), true)
			var corps := Rect2(p.call(Vector2(22, 26)), Vector2(76, 86) * k)
			Ui.rect(ci, corps, fonce, 0, int(20 * k))
			Ui.rect(ci, corps, couleur, int(e.call(6)), int(20 * k))
			Ui.rect(ci, Rect2(p.call(Vector2(22, 26)), Vector2(76, 40) * k), couleur, int(e.call(6)), int(14 * k))
			Ui.rect(ci, Rect2(p.call(Vector2(51, 56)), Vector2(18, 18) * k), couleur, 0, int(4 * k))
			Ui.rect(ci, Rect2(p.call(Vector2(36, 82)), Vector2(48, 20) * k), couleur, int(e.call(5)), int(6 * k))
