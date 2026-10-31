class_name EffetsDessin
extends RefCounted
## Dessin des animations de dégâts : un effet par
## type de dégâts, éclair sur le sprite touché, dissolution des ennemis vaincus,
## chiffres qui s'envolent, et effets de premier plan des coups reçus par le joueur
## (bord teinté, éclair de foudre, secousse de l'écran).
##
## Les formes sont calculées une fois par image (calculer) puis rejouées dans les
## couches de l'écran de combat : formes semi-transparentes, lueurs additives,
## silhouettes, chiffres.

const DEGRADE_FLAMMES := [[0.0, Color8(255, 250, 215)], [0.25, Color8(255, 205, 90)], [0.55, Color8(255, 115, 25)], [1.0, Color8(150, 30, 10)]]
const TYPES_PHYSIQUES := ["tranchant", "perforant", "contondant", "saignement"]

static var _vignette: Texture2D = null


static func _borne(x: float, mini := 0.0, maxi := 1.0) -> float:
	return clampf(x, mini, maxi)


static func _sortie(x: float) -> float:
	x = _borne(x)
	return 1 - pow(1 - x, 3)


static func _degrade(points: Array, u: float) -> Color:
	u = _borne(u)
	for i in points.size() - 1:
		var p0: float = points[i][0]
		var p1: float = points[i + 1][0]
		if u <= p1:
			var k := (u - p0) / (p1 - p0) if p1 > p0 else 0.0
			return points[i][1].lerp(points[i + 1][1], k)
	return points[-1][1]


## Pinceau : enregistre les formes (semi-transparentes) et les lueurs (additives) d'une image.
class Pinceau:
	var formes: Array = []
	var lueurs: Array = []

	func disque(x: float, y: float, rayon: float, couleur: Color, alpha: float) -> void:
		if alpha <= 2 or rayon < 0.5:
			return
		formes.append(["disque", Vector2(x, y), maxf(1, rayon), Color(couleur, minf(255, alpha) / 255.0)])

	func cercle(x: float, y: float, rayon: float, couleur: Color, alpha: float, largeur: float) -> void:
		if alpha <= 2 or rayon < 1:
			return
		formes.append(["cercle", Vector2(x, y), rayon, Color(couleur, minf(255, alpha) / 255.0), maxf(1, minf(rayon, largeur))])

	func lignes(points: Array, couleur: Color, alpha: float, largeur: float, fermee := false) -> void:
		if alpha <= 2 or points.size() < 2:
			return
		var p := PackedVector2Array()
		for q in points:
			p.append(q)
		if fermee:
			p.append(points[0])
		formes.append(["lignes", p, Color(couleur, minf(255, alpha) / 255.0), maxf(1, largeur)])

	func polygone(points: Array, couleur: Color, alpha: float) -> void:
		if alpha <= 2 or points.size() < 3:
			return
		var p := PackedVector2Array()
		for q in points:
			p.append(q)
		formes.append(["polygone", p, Color(couleur, minf(255, alpha) / 255.0)])

	func lueur(x: float, y: float, taille: float, couleur: Color, intensite: float) -> void:
		if intensite > 0.03 and taille >= 0.5:
			lueurs.append([x, y, taille, couleur, intensite])


# ---------------------------------------------------------------------------
# Préparation des coups
# ---------------------------------------------------------------------------

static func _p(x0, y0, vx, vy, gravite, t0, vie, taille, couleur, mode: String) -> Array:
	return [float(x0), float(y0), float(vx), float(vy), float(gravite), float(t0), float(vie), float(taille), couleur, mode]


static func _choix(a: RandomNumberGenerator, liste: Array):
	return liste[a.randi_range(0, liste.size() - 1)]


## Précalcule les formes et les particules d'un coup (à sa planification).
static func preparer(imp) -> void:
	if imp.prepare:
		return
	imp.prepare = true
	var a := RandomNumberGenerator.new()
	a.seed = imp.graine
	match imp.type:
		"tranchant":
			var sens := 1 if a.randf() < 0.5 else -1
			var entailles := []
			for i in (3 if imp.critique else 2):
				entailles.append([sens * a.randf_range(0.35, 0.8) * (1 if i % 2 == 0 else -1) + (PI if i % 2 else 0.0),
					a.randf_range(-14, 14), i * 0.08, a.randf_range(-0.35, 0.35)])
			imp.forme["entailles"] = entailles
			for _i in 16:
				var angle := a.randf_range(0, TAU)
				var vitesse := a.randf_range(80, 230)
				imp.particules.append(_p(0, 0, cos(angle) * vitesse, sin(angle) * vitesse - 60, 700, a.randf_range(0.05, 0.2),
					a.randf_range(0.35, 0.55), a.randf_range(2, 3.5), Color8(175, 10, 25), "goutte"))
			for _i in 8:
				var angle := a.randf_range(0, TAU)
				imp.particules.append(_p(0, 0, cos(angle) * 300, sin(angle) * 300, 0, 0.05, 0.15, 1.5, Color8(255, 255, 255), "eclat"))
		"perforant":
			var angle := a.randf_range(-0.45, 0.45) + (0.0 if a.randf() < 0.5 else PI)
			imp.forme["angle"] = angle
			for _i in 16:
				var direction := angle + a.randf_range(-0.55, 0.55)
				var vitesse := a.randf_range(250, 520)
				imp.particules.append(_p(0, 0, cos(direction) * vitesse, sin(direction) * vitesse, 300, 0.1,
					a.randf_range(0.18, 0.3), a.randf_range(1.5, 2.5), Color8(255, 235, 185), "eclat"))
			for _i in 6:
				var direction := angle + a.randf_range(-1.2, 1.2)
				imp.particules.append(_p(0, 0, cos(direction) * 140, sin(direction) * 140, 900, 0.1, 0.4,
					a.randf_range(2, 3), Color8(170, 10, 25), "goutte"))
		"contondant":
			for _i in 16:
				imp.particules.append(_p(a.randf_range(-10, 10), a.randf_range(-10, 10), a.randf_range(-260, 260), a.randf_range(-380, -90),
					950, 0.02, a.randf_range(0.45, 0.65), a.randf_range(2, 4),
					_choix(a, [Color8(120, 95, 70), Color8(150, 125, 95), Color8(95, 80, 65)]), "debris"))
			for _i in 9:
				var angle := a.randf_range(0, TAU)
				imp.particules.append(_p(cos(angle) * 15, sin(angle) * 15, cos(angle) * 70, sin(angle) * 40 - 20,
					0, 0.05, a.randf_range(0.5, 0.7), a.randf_range(8, 13), Color8(140, 128, 115), "fumee"))
			imp.forme["rotation"] = a.randf_range(0, PI)
		"feu":
			for _i in (54 if imp.critique else 44):
				var rayon := a.randf_range(0, 24)
				var angle := a.randf_range(0, TAU)
				imp.particules.append(_p(cos(angle) * rayon, sin(angle) * rayon, a.randf_range(-90, 90), a.randf_range(-170, -40),
					-120, a.randf_range(0, 0.35), a.randf_range(0.35, 0.6), a.randf_range(4, 9), null, "flamme"))
			for _i in 8:
				imp.particules.append(_p(a.randf_range(-20, 20), a.randf_range(-30, 0), a.randf_range(-20, 20), a.randf_range(-70, -40), 0,
					a.randf_range(0.25, 0.45), 0.55, a.randf_range(7, 11), Color8(60, 52, 48), "fumee"))
		"froid":
			var nombre := 11 if imp.critique else 8
			var pics := []
			for i in nombre:
				var angle := i * TAU / nombre + a.randf_range(-0.25, 0.25)
				pics.append([angle, a.randf_range(45, 82), a.randf_range(8, 13), a.randf_range(0, 0.08)])
				for _k in 3:
					var direction := angle + a.randf_range(-0.4, 0.4)
					var vitesse := a.randf_range(90, 220)
					imp.particules.append(_p(cos(angle) * 40, sin(angle) * 40, cos(direction) * vitesse,
						sin(direction) * vitesse, 500, 0.5, a.randf_range(0.3, 0.45), 1.5, Color8(210, 240, 255), "eclat"))
			imp.forme["pics"] = pics
			for _i in 14:
				imp.particules.append(_p(a.randf_range(-60, 60), a.randf_range(-70, 10), a.randf_range(-15, 15), a.randf_range(10, 40), 0,
					a.randf_range(0, 0.35), a.randf_range(0.5, 0.7), a.randf_range(1.5, 2.5), Color8(225, 245, 255), "lueur"))
		"foudre":
			var frappes := [0.0, 0.16] + ([0.3] if imp.critique else [])
			var formes := []
			for tf in frappes:
				formes.append([tf, a.randf_range(-70, 70), a.randi_range(0, 999999)])
			imp.forme["frappes"] = formes
			for tf in frappes:
				for _k in 12:
					var angle := a.randf_range(PI, TAU)
					var vitesse := a.randf_range(180, 420)
					imp.particules.append(_p(0, 0, cos(angle) * vitesse, sin(angle) * vitesse, 700, tf, a.randf_range(0.15, 0.3),
						1.5, Color8(255, 250, 170), "eclat"))
		"arcane":
			imp.forme["sens"] = 1 if a.randf() < 0.5 else -1
			for _i in (26 if imp.critique else 20):
				var angle := a.randf_range(0, TAU)
				var vitesse := a.randf_range(140, 320)
				imp.particules.append(_p(0, 0, cos(angle) * vitesse, sin(angle) * vitesse, 0, 0.55, a.randf_range(0.25, 0.4),
					a.randf_range(2, 3.5), _choix(a, [Color8(200, 130, 255), Color8(150, 110, 255), Color8(240, 200, 255)]), "lueur"))
		"chaos":
			var couleurs := [Color8(235, 40, 80), Color8(255, 50, 200), Color8(130, 255, 70)]
			for _i in 26:
				var angle := a.randf_range(0, TAU)
				var rayon := a.randf_range(70, 100)
				var x0 := cos(angle) * rayon
				var y0 := sin(angle) * rayon
				imp.particules.append(_p(x0, y0, -x0 / 0.42, -y0 / 0.42, 0, a.randf_range(0, 0.12), 0.4, a.randf_range(2, 3.5),
					_choix(a, couleurs), "lueur"))
			for _i in 18:
				var angle := a.randf_range(0, TAU)
				var vitesse := a.randf_range(260, 480)
				imp.particules.append(_p(0, 0, cos(angle) * vitesse, sin(angle) * vitesse, 0, 0.5, a.randf_range(0.2, 0.32),
					2.5, _choix(a, [Color8(235, 40, 80), Color8(60, 0, 25)]), "eclat"))
		"ombre":
			var tentacules := []
			for k in 6:
				tentacules.append([k * TAU / 6 + a.randf_range(-0.3, 0.3), a.randf_range(0, 6)])
			imp.forme["tentacules"] = tentacules
			var nappes := []
			for _i in 7:
				nappes.append([a.randf_range(-35, 35), a.randf_range(-45, 45), a.randf_range(30, 50)])
			imp.forme["nappes"] = nappes
			for _i in 12:
				imp.particules.append(_p(a.randf_range(-40, 40), a.randf_range(-30, 30), a.randf_range(-15, 15), a.randf_range(-60, -30), 0,
					a.randf_range(0.3, 0.6), 0.5, a.randf_range(7, 11), Color8(35, 8, 55), "fumee"))
		"lumière":
			for _i in 26:
				var angle := a.randf_range(0, TAU)
				var rayon := a.randf_range(0, 42)
				imp.particules.append(_p(cos(angle) * rayon, sin(angle) * rayon + 20, a.randf_range(-10, 10), a.randf_range(-140, -60),
					0, a.randf_range(0, 0.5), a.randf_range(0.45, 0.65), a.randf_range(1.8, 3.5), Color8(255, 230, 140), "lueur"))
		"saignement":
			for _i in 24:
				imp.particules.append(_p(a.randf_range(-30, 30), a.randf_range(-25, 20), a.randf_range(-50, 50), a.randf_range(-110, 10), 650,
					a.randf_range(0, 0.3), a.randf_range(0.45, 0.6), a.randf_range(2.5, 4.5), Color8(185, 10, 25), "goutte"))
		"poison":
			for _i in 22:
				imp.particules.append(_p(a.randf_range(-40, 40), a.randf_range(0, 30), a.randf_range(-15, 15), a.randf_range(-110, -50), 0,
					a.randf_range(0, 0.45), a.randf_range(0.45, 0.65), a.randf_range(5, 9), Color8(125, 230, 75), "bulle"))
			for _i in 6:
				imp.particules.append(_p(a.randf_range(-30, 30), a.randf_range(-10, 30), a.randf_range(-20, 20), a.randf_range(-30, -10), 0,
					a.randf_range(0, 0.3), 0.6, a.randf_range(9, 13), Color8(70, 140, 35), "fumee"))
		"rate":
			imp.forme["cote"] = 1 if a.randf() < 0.5 else -1
	if imp.mortel:
		var couleur: Color = EffetsCombat.COULEURS.get(imp.type, Color8(255, 255, 255))
		for _i in 28:
			imp.particules.append(_p(a.randf_range(-55, 55), a.randf_range(-95, 90), a.randf_range(-15, 15), a.randf_range(-130, -40), -20,
				EffetsCombat.DEBUT_MORT + a.randf_range(0, EffetsCombat.DUREE_MORT * 0.8), a.randf_range(0.4, 0.7),
				a.randf_range(1.5, 3), couleur, "lueur"))


# ---------------------------------------------------------------------------
# Dessin des effets par type
# ---------------------------------------------------------------------------

static func _particules(p: Pinceau, imp, t: float, c: Vector2, s: float) -> void:
	for q in imp.particules:
		var tau: float = t - q[5]
		var vie: float = q[6]
		if tau < 0 or tau > vie:
			continue
		var u := tau / vie
		var x: float = c.x + (q[0] + q[2] * tau) * s
		var y: float = c.y + (q[1] + q[3] * tau + 0.5 * q[4] * tau * tau) * s
		var taille: float = q[7]
		var couleur = q[8]
		match q[9]:
			"lueur":
				p.lueur(x, y, taille * s * (1 - 0.4 * u), couleur, 1 - u)
			"flamme":
				if u < 0.65:
					p.lueur(x, y, taille * s * (1 - 0.3 * u), _degrade(DEGRADE_FLAMMES, u / 0.65), 1 - u * 0.8)
				else:
					p.disque(x, y, taille * s * (0.7 + u), Color8(55, 48, 44), 120 * (1 - u) / 0.35)
			"fumee":
				p.disque(x, y, taille * s * (0.6 + u), couleur, 130 * (1 - u))
			"debris":
				p.disque(x, y, taille * s, couleur, 255 * (1 - pow(u, 3)))
			"goutte":
				var vy: float = q[3] + q[4] * tau
				p.lignes([Vector2(x, y), Vector2(x - q[2] * 0.025 * s, y - vy * 0.025 * s)], couleur, 230 * (1 - u * u), taille * s * 0.8)
				p.disque(x, y, taille * s * 0.6, couleur, 240 * (1 - u * u))
			"bulle":
				p.cercle(x, y, taille * s * (0.6 + 0.6 * u), couleur, 220 * (1 - u * u), 2)
				p.lueur(x - taille * s * 0.3, y - taille * s * 0.3, 1.2 * s, Color8(230, 255, 210), 0.6 * (1 - u))
			"eclat":
				var vy: float = q[3] + q[4] * tau
				p.lignes([Vector2(x, y), Vector2(x - q[2] * 0.035 * s, y - vy * 0.035 * s)], couleur, 255 * (1 - u), maxf(1, taille * s))


static func _chemin_eclair(depart: Vector2, arrivee: Vector2, graine: int, deviation := 0.22, niveaux := 5) -> Array:
	var a := RandomNumberGenerator.new()
	a.seed = graine
	var points := [depart, arrivee]
	var ecart := depart.distance_to(arrivee) * deviation
	for _n in niveaux:
		var nouveaux := [points[0]]
		for i in points.size() - 1:
			var p0: Vector2 = points[i]
			var p1: Vector2 = points[i + 1]
			var m := (p0 + p1) / 2
			var d := p1 - p0
			var norme := d.length()
			if norme == 0:
				norme = 1
			var lateral := a.randf_range(-ecart, ecart)
			nouveaux.append(Vector2(m.x - d.y / norme * lateral, m.y + d.x / norme * lateral))
			nouveaux.append(p1)
		points = nouveaux
		ecart *= 0.5
	return points


static func _dessiner_type(p: Pinceau, imp, t: float, c: Vector2, s: float) -> void:
	match imp.type:
		"tranchant":
			var longueur := 175 * s
			for e in imp.forme["entailles"]:
				var angle: float = e[0]
				var decal: float = e[1]
				var t0: float = e[2]
				var courbure: float = e[3]
				var avance := _borne((t - t0) / 0.09)
				if avance <= 0:
					continue
				var fondu := 1 - _borne((t - t0 - 0.09) / 0.25)
				if fondu <= 0:
					continue
				var d := Vector2(cos(angle), sin(angle))
				var n := Vector2(-d.y, d.x)
				var depart := c - d * longueur / 2 + n * decal * s
				var arrivee := c + d * longueur / 2 + n * decal * s
				var controle := c + n * (decal + courbure * longueur * 0.5) * s
				var debut_trace := maxf(0.0, avance - 0.75) if fondu >= 1 else (1 - fondu) * avance
				var gauche := []
				var droite := []
				var centre := []
				for k in 17:
					var u := debut_trace + (avance - debut_trace) * k / 16.0
					var q := (1 - u) * (1 - u) * depart + 2 * (1 - u) * u * controle + u * u * arrivee
					var largeur := sin(PI * k / 16.0) * 6.5 * s * (0.4 + 0.6 * fondu)
					gauche.append(q + n * largeur)
					droite.append(q - n * largeur)
					centre.append(q)
				var halo := []
				for k in 17:
					halo.append(centre[k] + (gauche[k] - centre[k]) * 2.2)
				for k in range(16, -1, -1):
					halo.append(centre[k] + (droite[k] - centre[k]) * 2.2)
				p.polygone(halo, Color8(170, 195, 255), 80 * fondu)
				var lame := gauche.duplicate()
				for k in range(16, -1, -1):
					lame.append(droite[k])
				p.polygone(lame, Color8(255, 255, 255), 240 * fondu)
				for k in range(0, 17, 3):
					p.lueur(centre[k].x, centre[k].y, 3.5 * s, Color8(190, 210, 255), 0.55 * fondu)
		"perforant":
			var angle: float = imp.forme["angle"]
			var d := Vector2(cos(angle), sin(angle))
			var n := Vector2(-d.y, d.x)
			var distance := -220 * (1 - t / 0.1) if t < 0.1 else 30 * _sortie((t - 0.1) / 0.08)
			var fondu := 1 - _borne((t - 0.16) / 0.14)
			if fondu > 0:
				var pointe := c + d * distance * s
				var queue := pointe - d * 120 * s
				var epaisseur := 5 * s
				p.polygone([pointe, queue + n * epaisseur, queue - n * epaisseur], Color8(255, 235, 170), 220 * fondu)
				p.lignes([pointe, queue], Color8(255, 255, 240), 255 * fondu, 2)
				p.lueur(pointe.x, pointe.y, 6 * s, Color8(255, 230, 160), fondu)
			if t >= 0.1:
				var u := _borne((t - 0.1) / 0.3)
				p.cercle(c.x, c.y, (6 + 48 * _sortie(u)) * s, Color8(255, 235, 180), 230 * (1 - u), 3 * s * (1 - u) + 1)
				p.lueur(c.x, c.y, 14 * s, Color8(255, 220, 150), 1 - u * 2.5)
		"contondant":
			var rayon := 58 * s * _sortie(t / 0.06) * (1.25 if imp.critique else 1.0)
			var fondu := 1 - _borne((t - 0.06) / 0.2)
			if fondu > 0:
				var rotation: float = imp.forme["rotation"]
				var points := []
				for k in 16:
					var r := rayon if k % 2 == 0 else rayon * 0.38
					var angle := rotation + k * PI / 8
					points.append(c + Vector2(cos(angle), sin(angle)) * r)
				p.polygone(points, Color8(255, 225, 160), 230 * fondu)
				p.lueur(c.x, c.y, 20 * s, Color8(255, 210, 140), fondu)
			for ra in [[0.0, 100.0], [0.08, 65.0]]:
				var u := _borne((t - ra[0]) / 0.45)
				if 0 < u and u < 1:
					p.cercle(c.x, c.y, (14 + ra[1] * _sortie(u)) * s, Color8(235, 195, 135), 210 * (1 - u), 7 * s * (1 - u) + 1)
		"feu":
			var u := _borne(t / 0.32)
			if u < 1:
				p.lueur(c.x, c.y, (14 + 22 * _sortie(u)) * s, Color8(255, 150, 45), 1 - u)
				p.lueur(c.x, c.y, 9 * s, Color8(255, 240, 200), 1 - u * 1.4)
				p.cercle(c.x, c.y, (12 + 55 * _sortie(u)) * s, Color8(255, 175, 70), 190 * (1 - u), 4 * s * (1 - u) + 1)
		"froid":
			p.disque(c.x, c.y, 48 * s * _sortie(t / 0.15), Color8(170, 220, 255), 70 * (1 - _borne((t - 0.3) / 0.5)))
			var fondu := 1 - _borne((t - 0.5) / 0.22)
			if fondu > 0:
				var eloignement := 14 * _borne((t - 0.5) / 0.22)
				for pic in imp.forme["pics"]:
					var g := _sortie((t - pic[3]) / 0.12)
					if g <= 0:
						continue
					var d := Vector2(cos(pic[0]), sin(pic[0]))
					var n := Vector2(-d.y, d.x)
					var base := 8 + eloignement
					var pointe: Vector2 = c + d * (base + pic[1] * g) * s
					var milieu: float = base + pic[1] * g * 0.35
					var cote1: Vector2 = c + (d * milieu + n * pic[2] / 2) * s
					var cote2: Vector2 = c + (d * milieu - n * pic[2] / 2) * s
					var racine := c + d * base * s
					var forme := [racine, cote1, pointe, cote2]
					p.polygone(forme, Color8(165, 220, 255), 215 * fondu)
					p.lignes(forme, Color8(245, 252, 255), 255 * fondu, 1, true)
					p.lignes([racine, pointe], Color8(255, 255, 255), 200 * fondu, 1)
			p.lueur(c.x, c.y, 16 * s, Color8(150, 220, 255), 1 - t / 0.35)
		"foudre":
			for f in imp.forme["frappes"]:
				var age: float = t - f[0]
				if not (0 <= age and age < 0.13):
					continue
				var scintille := 1.0 if int(age * 60) % 2 == 0 else 0.55
				var depart := Vector2(c.x + f[1] * s, -10)
				var image := int(age * 22)
				var chemin := _chemin_eclair(depart, c, f[2] + image)
				for l in [[16 * s, Color8(255, 230, 110), 55], [7 * s, Color8(255, 245, 170), 120], [3 * s, Color8(255, 255, 255), 255]]:
					p.lignes(chemin, l[1], l[2] * scintille, l[0])
				var branches := RandomNumberGenerator.new()
				branches.seed = f[2] + 7 + image
				for _b in 2:
					var origine: Vector2 = chemin[branches.randi_range(chemin.size() / 4, chemin.size() * 3 / 4 - 1)]
					var fin := origine + Vector2(branches.randf_range(-90, 90) * s, branches.randf_range(30, 90) * s)
					var branche := _chemin_eclair(origine, fin, branches.randi_range(0, 999999), 0.22, 3)
					p.lignes(branche, Color8(255, 245, 180), 90 * scintille, 5 * s)
					p.lignes(branche, Color8(255, 255, 230), 200 * scintille, 2)
				p.lueur(c.x, c.y, 18 * s, Color8(255, 245, 150), scintille)
		"arcane":
			if t < 0.55:
				var u := t / 0.55
				var apparition := _borne(t / 0.1)
				var rayon := (72 - 52 * pow(_sortie(u), 1.5)) * s
				var theta: float = t * 4 * imp.forme["sens"]
				var violet := Color8(200, 140, 255)
				p.cercle(c.x, c.y, rayon, violet, 220 * apparition, 2)
				p.cercle(c.x, c.y, rayon * 0.78, violet, 150 * apparition, 1)
				for decal in [0.0, PI / 3]:
					var triangle := []
					for k in 3:
						var an: float = theta + decal + k * TAU / 3
						triangle.append(c + Vector2(cos(an), sin(an)) * rayon * 0.78)
					p.lignes(triangle, Color8(225, 180, 255), 200 * apparition, 1, true)
				for k in 12:
					var an := -theta * 1.3 + k * PI / 6
					p.lignes([c + Vector2(cos(an), sin(an)) * rayon, c + Vector2(cos(an), sin(an)) * (rayon + 7 * s)], violet, 200 * apparition, 2)
				for k in 6:
					var an := -theta * 1.6 + k * PI / 3
					p.lueur(c.x + cos(an) * rayon * 1.12, c.y + sin(an) * rayon * 1.12, 3 * s, Color8(210, 160, 255), apparition)
				p.lueur(c.x, c.y, 8 * s, Color8(190, 120, 255), 0.4 + 0.6 * u)
			else:
				var u := _borne((t - 0.55) / 0.3)
				p.lueur(c.x, c.y, (12 + 14 * u) * s, Color8(230, 185, 255), 1 - u)
				p.cercle(c.x, c.y, (15 + 60 * _sortie(u)) * s, Color8(215, 160, 255), 220 * (1 - u), 3)
		"chaos":
			if t < 0.5:
				var u := t / 0.5
				var apparition := _borne(t / 0.1)
				p.disque(c.x, c.y, (12 + 22 * u) * s, Color8(30, 0, 15), 210 * apparition)
				for bras in 3:
					var points := []
					for k in 22:
						var v := k / 21.0
						var rayon := (85 * (1 - v) + 6) * s * (1 - 0.45 * _sortie(u))
						var an := bras * TAU / 3 + v * 4.5 + t * 10
						points.append(c + Vector2(cos(an), sin(an)) * rayon)
					var rouge := (int(t * 30) + bras) % 2 == 0
					p.lignes(points, Color8(230, 30, 75) if rouge else Color8(90, 0, 40), 220 * apparition, 3 * s)
				p.lueur(c.x, c.y, 7 * s, Color8(255, 40, 110), 0.5 + 0.5 * u)
			else:
				var u := _borne((t - 0.5) / 0.3)
				p.lueur(c.x, c.y, (14 + 12 * u) * s, Color8(255, 50, 110), 1 - u)
				p.cercle(c.x, c.y, (10 + 70 * _sortie(u)) * s, Color8(120, 0, 45), 220 * (1 - u), 6 * s * (1 - u) + 1)
		"ombre":
			var fondu := 1 - _borne((t - 0.5) / 0.4)
			var croissance := _sortie(t / 0.35)
			for nappe in imp.forme["nappes"]:
				p.disque(c.x + nappe[0] * s * croissance, c.y + nappe[1] * s * croissance, nappe[2] * s * croissance, Color8(14, 0, 24), 165 * fondu)
			var avance := _sortie(t / 0.45)
			if fondu > 0:
				for tentacule in imp.forme["tentacules"]:
					var points := []
					for k in 15:
						var v := avance * k / 14.0
						var rayon := (125 * (1 - v) + 8) * s
						var an: float = tentacule[0] + sin(v * 6 + t * 8 + tentacule[1]) * 0.35
						points.append(c + Vector2(cos(an), sin(an)) * rayon)
					p.lignes(points, Color8(30, 5, 48), 230 * fondu, 8 * s)
					p.lignes(points, Color8(165, 95, 225), 190 * fondu, 2)
			if t >= 0.45:
				var u := _borne((t - 0.45) / 0.35)
				p.lueur(c.x, c.y, 18 * s, Color8(150, 70, 220), 1 - u)
		"lumière":
			var enveloppe := sin(PI * _borne(t / 0.85))
			var haut := c.y - 300 * s
			for k in 4:
				var largeur := (64 - 14 * k) * s
				p.polygone([Vector2(c.x - largeur * 0.6, haut), Vector2(c.x + largeur * 0.6, haut),
					Vector2(c.x + largeur / 2, c.y + 30 * s), Vector2(c.x - largeur / 2, c.y + 30 * s)],
					Color8(255, 238, 160), (35 + 30 * k) * enveloppe)
			p.cercle(c.x, c.y + 20 * s, (30 + 25 * _sortie(t / 0.5)) * s, Color8(255, 235, 150), 200 * enveloppe, 2)
			p.lueur(c.x, c.y, 16 * s, Color8(255, 235, 150), enveloppe)
		"saignement":
			p.lueur(c.x, c.y, 14 * s, Color8(210, 20, 30), 0.7 * (1 - t / 0.35))
		"poison":
			p.lueur(c.x, c.y, 14 * s, Color8(110, 220, 60), 0.6 * (1 - t / 0.4))
		"rate":
			var avance := _sortie(t / 0.2)
			var fondu := 1 - _borne((t - 0.15) / 0.25)
			if fondu <= 0:
				return
			var cote: int = imp.forme["cote"]
			var points := []
			for k in 12:
				var v := maxf(0.0, avance - 0.6) + (avance - maxf(0.0, avance - 0.6)) * k / 11.0
				var an := -2.4 + 1.8 * v
				points.append(Vector2(c.x + cote * (40 + cos(an) * 75) * s, c.y + sin(an) * 75 * s + 40 * s))
			p.lignes(points, Color8(225, 225, 235), 170 * fondu, 3 * s)
			return
	_particules(p, imp, t, c, s)


static func _particules_mort(p: Pinceau, imp, t: float, r) -> void:
	if r == null:
		return
	var centre := Vector2(r.get_center().x, r.position.y + r.size.y * 0.55)
	var debut := maxi(0, imp.particules.size() - 28)
	for q in imp.particules.slice(debut):
		var tau: float = t - q[5]
		if 0 <= tau and tau <= q[6]:
			var u: float = tau / q[6]
			p.lueur(centre.x + q[0] + q[2] * tau, centre.y + q[1] + q[3] * tau + 0.5 * q[4] * tau * tau, q[7] * (1 - 0.4 * u), q[8], 1 - u)


# ---------------------------------------------------------------------------
# Calcul de l'image
# ---------------------------------------------------------------------------

## Calcule les formes de l'image courante. ``rect_de`` : ennemi → Rect2 (ou null).
## Renvoie {"pinceau", "mourants": [[impact, rect]], "silhouettes": [[ennemi, rect, couleur]], "chiffres": [[impact, t, position]]}.
static func calculer(rect_de: Callable) -> Dictionary:
	var maintenant := EffetsCombat.maintenant()
	EffetsCombat.planifier(maintenant)
	for imp in EffetsCombat.file:
		if imp.debut != null:
			preparer(imp)
	var restants := []
	for imp in EffetsCombat.file:
		if imp.debut == null or maintenant < imp.debut + imp.duree():
			restants.append(imp)
	EffetsCombat.file = restants
	var p := Pinceau.new()
	var centre_joueur := Vector2(Ui.LARGEUR / 2.0, Ui.HAUTEUR * 0.47)
	var mourants := []
	var silhouettes := []
	var chiffres := []
	for imp in EffetsCombat.file:
		if imp.mortel:
			var r = rect_de.call(imp.cible)
			if r != null:
				mourants.append([imp, r])
	for imp in EffetsCombat.file:
		if imp.debut == null or maintenant < imp.debut:
			continue
		var t: float = maintenant - imp.debut
		var centre: Vector2
		var echelle := 1.0
		var r = null
		if imp.est_joueur:
			centre = centre_joueur
			echelle = EffetsCombat.ECHELLE_JOUEUR
		else:
			r = rect_de.call(imp.cible)
			if r == null:
				continue
			centre = Vector2(r.get_center().x, r.position.y + r.size.y * 0.45)
			if not (imp.type in ["rate", "etat"]) and t < 0.3 and (imp.cible.est_vivant() or imp.mortel):
				var couleur: Color = EffetsCombat.COULEURS.get(imp.type, Color8(255, 255, 255))
				var intensite := 0.42 * pow(1 - t / 0.3, 1.5)
				silhouettes.append([imp.cible, r, Color(couleur.r * intensite, couleur.g * intensite, couleur.b * intensite, 1)])
			chiffres.append([imp, t, Vector2(r.get_center().x, r.position.y + 55)])
		if imp.type != "etat" and t < EffetsCombat.DUREES.get(imp.type, 0.8):
			_dessiner_type(p, imp, t, centre, echelle)
		if imp.mortel and t >= EffetsCombat.DEBUT_MORT:
			_particules_mort(p, imp, t, rect_de.call(imp.cible))
	return {"pinceau": p, "mourants": mourants, "silhouettes": silhouettes, "chiffres": chiffres}


## Formes semi-transparentes (couche du contenu).
static func dessiner_formes(ci: CanvasItem, p: Pinceau) -> void:
	for f in p.formes:
		match f[0]:
			"disque":
				ci.draw_circle(f[1], f[2], f[3], true, -1.0, true)
			"cercle":
				ci.draw_arc(f[1], f[2] - f[4] / 2.0, 0, TAU, maxi(16, int(f[2])), f[3], f[4], true)
			"lignes":
				ci.draw_polyline(f[1], f[2], f[3], true)
			"polygone":
				var pts: PackedVector2Array = f[1]
				if Geometry2D.triangulate_polygon(pts).size() > 0:
					ci.draw_colored_polygon(pts, f[2])


## Lueurs (couche additive).
static func dessiner_lueurs(ci: CanvasItem, p: Pinceau) -> void:
	for l in p.lueurs:
		var taille: float = l[2]
		var t := maxf(0.5, roundf(taille * 2) / 2) if taille < 12 else roundf(taille / 3) * 3
		var niveau := clampi(roundi(l[4] * 8), 1, 8)
		var c: Color = l[3]
		var teinte := Color(minf(1, c.r * niveau / 8.0), minf(1, c.g * niveau / 8.0), minf(1, c.b * niveau / 8.0), 1)
		var point := Animations.point_lumineux(t)
		ci.draw_texture(point, Vector2(l[0], l[1]) - point.get_size() / 2, teinte)


## Texte gras cerné de noir (chiffres de dégâts).
static func texte_contour(ci: CanvasItem, contenu: String, centre: Vector2, taille: int, couleur: Color, alpha: float) -> float:
	var f := Ui.police(true)
	var dim := Ui.taille_texte(contenu, taille, true)
	var pos := Vector2(int(centre.x - dim.x / 2), int(centre.y - dim.y / 2) + f.get_ascent(taille))
	ci.draw_string_outline(f, pos, contenu, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, 4, Color(0, 0, 0, alpha))
	ci.draw_string(f, pos, contenu, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color(couleur, alpha))
	return dim.y


static func _libelle(imp) -> Array:
	if imp.type == "etat" and imp.texte != null:
		return imp.texte
	if imp.type == "rate":
		return ["Esquivé !", Color8(150, 210, 255)] if imp.est_joueur else ["Raté", Color8(200, 200, 200)]
	var montant := int(round(absf(imp.montant)))
	if imp.montant < 0:
		return ["+%d" % montant, Color8(110, 235, 120)]
	if montant == 0:
		return ["0", Color8(170, 170, 170)]
	return [("-%d" % montant) if imp.est_joueur else str(montant), EffetsCombat.COULEURS.get(imp.type, Color8(255, 255, 255))]


## Chiffre d'un coup qui s'envole et s'efface (avec « CRITIQUE ! »).
static func dessiner_chiffre(ci: CanvasItem, imp, t: float, position: Vector2) -> void:
	if t >= EffetsCombat.DUREE_CHIFFRE:
		return
	var u := t / EffetsCombat.DUREE_CHIFFRE
	var l := _libelle(imp)
	var taille := 34 if imp.critique else (20 if imp.type == "etat" else 26)
	if t < 0.1:
		taille = int(taille * (1.45 - 0.45 * t / 0.1))
	var x: float = position.x + (imp.rang % 2 * 2 - 1) * 14 * (1 if imp.rang > 0 else 0)
	var y: float = position.y - imp.rang * 26 - 48 * _sortie(u)
	var alpha := 1 - _borne((u - 0.65) / 0.35)
	var hauteur := texte_contour(ci, l[0], Vector2(x, y), taille, l[1], alpha)
	if imp.critique:
		texte_contour(ci, "CRITIQUE !", Vector2(x, y - hauteur / 2 - 8), 15, Color8(255, 210, 60), alpha)


## Bord d'écran transparent au centre (blanc : à teinter).
static func vignette() -> Texture2D:
	if _vignette == null:
		var l := 240
		var h := 135
		var img := Image.create(l, h, false, Image.FORMAT_RGBA8)
		for i in l:
			for j in h:
				var x := (i - l / 2.0 + 0.5) / (l / 2.0)
				var y := (j - h / 2.0 + 0.5) / (h / 2.0)
				var d := sqrt(x * x + y * y)
				img.set_pixel(i, j, Color(1, 1, 1, pow(clampf((d - 0.55) / 0.75, 0, 1), 1.4)))
		_vignette = ImageTexture.create_from_image(img)
	return _vignette


## Effets de premier plan des coups reçus par le joueur ; renvoie la secousse de l'écran.
static func post_traitement(ci: CanvasItem, centre_sphere: Vector2) -> Vector2:
	var maintenant := EffetsCombat.maintenant()
	var secousse := Vector2.ZERO
	for imp in EffetsCombat.file:
		if imp.debut == null or maintenant < imp.debut:
			continue
		var t: float = maintenant - imp.debut
		if imp.type == "foudre":
			for f in imp.forme.get("frappes", []):
				if 0 <= t - f[0] and t - f[0] < 0.06:
					ci.draw_rect(Rect2(0, 0, Ui.LARGEUR, Ui.HAUTEUR), Color8(255, 255, 235, 70 if imp.est_joueur else 22))
					break
		if not imp.est_joueur:
			continue
		if not (imp.type in ["rate", "etat"]) and t < 0.6:
			var couleur: Color = Color8(200, 0, 0) if imp.type in TYPES_PHYSIQUES else EffetsCombat.COULEURS.get(imp.type, Color8(200, 0, 0))
			var force := (0.4 if imp.montant < 0 else 0.85) * (1 - t / 0.6)
			ci.draw_texture_rect(vignette(), Rect2(0, 0, Ui.LARGEUR, Ui.HAUTEUR), false, Color(couleur, force))
		if t < 0.35:
			var amplitude: float = EffetsCombat.SECOUSSES.get(imp.type, 4) * (1.6 if imp.critique else 1.0) * (1 - t / 0.35)
			secousse.x += sin(t * 80 + imp.groupe) * amplitude
			secousse.y += cos(t * 65 + imp.groupe) * amplitude * 0.6
		var x_chiffre := Ui.LARGEUR - centre_sphere.x - 20 if imp.forme.get("pres_mana", false) else centre_sphere.x + 10
		dessiner_chiffre(ci, imp, t, Vector2(x_chiffre, centre_sphere.y - 62))
	if absf(secousse.x) >= 1 or absf(secousse.y) >= 1:
		return Vector2(int(secousse.x), int(secousse.y))
	return Vector2.ZERO
