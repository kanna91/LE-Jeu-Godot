class_name Carte
extends RefCounted
## Carte de l'étage : brouillard de guerre, pictogrammes des salles,
## mini-carte de l'écran d'exploration et carte complète (EcranCarte).

const COULEURS := {
	"actuelle": Color8(235, 190, 70),
	"visitee": Color8(120, 112, 100),
	"connue": Color8(52, 50, 60),
	"depart": Color8(70, 120, 190),
	"boss": Color8(130, 50, 170),
	"bonus": Color8(60, 120, 70),
	"couloir": Color8(150, 140, 120),
	"couloir_connu": Color8(80, 76, 86),
}
const LEGENDE := [["actuelle", "Vous"], ["visitee", "Visitée"], ["connue", "Inexplorée"], ["boss", "Boss"],
	["coffre", "Coffre"], ["soin", "Source de soin"], ["choix_bonus", "Bonus"], ["marchand", "Marchand"],
	["piege", "Piège"], ["escalier", "Passage"]]


## État de connaissance de chaque salle d'un étage : {id: « actuelle » / « visitee » / « connue »}.
static func etats_salles(donjon, etage = null) -> Dictionary:
	var etage_actuel = donjon.salle_actuelle[0]
	var salle_actuelle = donjon.salle_actuelle[1]
	if etage == null:
		etage = etage_actuel
	var salles: Dictionary = donjon.plan_donjon.get(etage, {})
	var etats := {}
	for ident in salles:
		if salles[ident].get("visitee", false):
			etats[ident] = "visitee"
	if etage == etage_actuel:
		etats[str(salle_actuelle)] = "actuelle"
	for ident in etats.keys():
		for voisine in salles[ident].get("connections", []):
			if not etats.has(str(voisine)):
				etats[str(voisine)] = "connue"
	# Vieux plan trouvé en fouillant une étagère (ancienne sauvegarde ; étagères retirées le 2026-10-20) : salles connues
	for ident in salles:
		if salles[ident].get("revelee", false) and not etats.has(ident):
			etats[ident] = "connue"
	var boss := str(donjon.salle_boss(etage))
	if salles.has(boss) and not etats.has(boss):
		etats[boss] = "connue"
	# Carte de chair (pacte de la succube) : tout l'étage est connu
	if carte_de_chair(donjon, etage):
		for ident in salles:
			if not etats.has(ident):
				etats[ident] = "connue"
	return etats


## Le pacte « Carte de chair » de la succube révèle l'étage ``etage`` (contenu des salles, cachettes, geôliers et
## Sans-Visage).
static func carte_de_chair(donjon, etage) -> bool:
	if etage == null:
		return false
	var tout = U.ga(donjon, "aventure", null)
	return tout is Dictionary and tout.get(int(etage), {}).get("carte", false)


## Marques de la Carte de chair dans une salle : cachette (losange doré), geôlier (point bleu-gris), Sans-Visage
## (point blanc).
static func _marques_chair(ci: CanvasItem, salle: Dictionary, r: Rect2) -> void:
	var t := maxf(2.5, r.size.x * 0.16)
	var x := r.position.x + t * 1.1
	for p in salle.get("presences", []):
		if p.get("etat", "actif") != "actif":
			continue
		var c := Vector2(x, r.end.y - t * 1.1)
		match [p.get("genre", ""), p.get("sous", "")]:
			["objet", "cachette"]:
				Ui.polygone(ci, PackedVector2Array([c + Vector2(0, -t), c + Vector2(t, 0), c + Vector2(0, t), c + Vector2(-t, 0)]), Color8(250, 215, 90))
			["geolier", _]:
				Ui.cercle(ci, c, t, Color8(120, 135, 170))
				Ui.cercle(ci, c, t, Color8(20, 20, 30), 1)
			["imbattable", _]:
				Ui.cercle(ci, c, t, Color8(240, 238, 230))
				Ui.cercle(ci, c, t, Color8(20, 20, 30), 1)
			_:
				continue
		x += t * 2.3


## [pictogramme, utilisé] d'une salle.
static func contenu_salle(salle: Dictionary) -> Array:
	if salle.get("boss", false):
		return ["boss", U.vrai(salle.get("visitee"))]
	if salle.get("type") == "bonus":
		return [salle.get("effet_bonus"), U.vrai(salle.get("effet_utilise"))]
	if salle.get("type") == "marchand":
		return ["marchand", false]
	if salle.get("type") == "piege":
		return ["piege", true]
	if String(salle.get("nom", "")).begins_with("salle_debut"):
		return ["depart", false]
	return [null, false]


static func dessiner_pictogramme(ci: CanvasItem, genre, centre: Vector2, taille: int, utilise := false) -> void:
	var x := centre.x
	var y := centre.y
	var r := maxi(3, taille / 3)
	var gris := Color8(110, 110, 110)
	match genre:
		"boss":
			var c := gris if utilise else Color8(240, 235, 245)
			Ui.cercle(ci, Vector2(x, y - 1), r, c)
			Ui.rect(ci, Rect2(x - r / 2, y + r / 2, r, r / 2 + 1), c)
			for dx in [-r / 2, r / 2]:
				Ui.cercle(ci, Vector2(x + dx, y - 1), maxi(1, r / 3), Color8(40, 10, 50))
		"coffre":
			var c := gris if utilise else Color8(230, 175, 60)
			var l := 2 * r + 2
			var h := int(1.5 * r) + 1
			var rr := Rect2(x - l / 2.0, y - h / 2.0, l, h)
			Ui.rect(ci, rr, c, 0, 2)
			Ui.ligne(ci, Vector2(rr.position.x, rr.get_center().y - 1), Vector2(rr.end.x - 1, rr.get_center().y - 1), Color8(70, 45, 20), 1)
		"soin":
			var c := gris if utilise else Color8(220, 60, 60)
			var epais := maxi(2, r / 2)
			Ui.rect(ci, Rect2(x - epais / 2, y - r, epais, 2 * r), c)
			Ui.rect(ci, Rect2(x - r, y - epais / 2, 2 * r, epais), c)
		"choix_bonus":
			var c := gris if utilise else Color8(120, 230, 120)
			var points := PackedVector2Array()
			for i in 10:
				var angle := -PI / 2 + i * PI / 5
				var rayon: float = r + 1.0 if i % 2 == 0 else (r + 1) / 2.3
				points.append(Vector2(x + rayon * cos(angle), y + rayon * sin(angle)))
			Ui.polygone(ci, points, c)
		"marchand":
			Ui.cercle(ci, Vector2(x, y), r, Color8(240, 200, 70))
			Ui.cercle(ci, Vector2(x, y), r, Color8(120, 80, 20), 1)
			Ui.texte(ci, "$", Vector2(x, y), Color8(90, 60, 10), maxi(9, taille - 4), true, null, "center")
		"piege":
			var c := Color8(200, 70, 60)
			Ui.ligne(ci, Vector2(x - r, y - r), Vector2(x + r, y + r), c, 2)
			Ui.ligne(ci, Vector2(x - r, y + r), Vector2(x + r, y - r), c, 2)
		"escalier":
			dessiner_escalier(ci, centre, 2.0 * r + 2.0)
		"depart":
			Ui.polygone(ci, PackedVector2Array([Vector2(x, y - r), Vector2(x - r, y + r / 2), Vector2(x + r, y + r / 2)]), Color8(220, 230, 255))


## Petit escalier (passage vers un autre niveau : fond d'un couloir de prison, entrée des cryptes), dans un carré
## de côté ``t`` centré sur ``c`` : trois marches qui descendent vers la droite.
static func dessiner_escalier(ci: CanvasItem, c: Vector2, t: float) -> void:
	var cadre := Rect2(c - Vector2(t, t) / 2.0, Vector2(t, t))
	Ui.rect(ci, cadre, Color8(40, 34, 48), 0, 2)
	var dedans := cadre.grow(-2.0)
	var m := dedans.size.x / 3.0
	for k in 3:
		var h := m * (3 - k)
		Ui.rect(ci, Rect2(dedans.position.x + k * m, dedans.end.y - h, ceilf(m), h), Color8(235, 200, 120))
		Ui.ligne(ci, Vector2(dedans.position.x + k * m, dedans.end.y - h), Vector2(dedans.position.x + (k + 1) * m, dedans.end.y - h), Color8(255, 240, 200), 1)
	Ui.rect(ci, cadre, Color8(235, 200, 120), 1, 2)


## Escaliers des passages découverts (salle visitée ou actuelle avec « passage_niveau »), collés au bord de la salle
## du côté du passage.
static func _escalier_passage(ci: CanvasItem, salle: Dictionary, etat: String, c: Vector2, taille_salle: int, zone: Rect2) -> void:
	var lien = salle.get("passage_niveau", null)
	if not (lien is Dictionary) or etat == "connue":
		return
	var d: Array = lien.get("direction", [0, 1])
	var t := maxf(10.0, taille_salle * 0.8)
	var centre := c + Vector2(float(d[0]), -float(d[1])) * (taille_salle / 2.0 + t / 2.0 + 1.0)
	if zone.encloses(Rect2(centre - Vector2(t, t) / 2.0, Vector2(t, t))):
		dessiner_escalier(ci, centre, t)


static func _couleur_salle(salle: Dictionary, etat: String) -> Color:
	if etat == "actuelle":
		return COULEURS["actuelle"]
	if salle.get("boss", false):
		return COULEURS["boss"] if etat == "visitee" else Color8(90, 40, 115)
	if etat == "connue":
		return COULEURS["connue"]
	if String(salle.get("nom", "")).begins_with("salle_debut"):
		return COULEURS["depart"]
	if salle.get("type") == "bonus":
		return COULEURS["bonus"]
	return COULEURS["visitee"]


## Salles connues d'un étage dans une zone (couloirs, salles, pictogrammes), découpées à la zone.
static func dessiner_etage(ci: CanvasItem, donjon, zone: Rect2, pas: float, centre_monde: Vector2, taille_salle: int) -> void:
	var etage = donjon.salle_actuelle[0]
	var salles: Dictionary = donjon.plan_donjon.get(etage, {})
	var etats := etats_salles(donjon, etage)
	var chair := carte_de_chair(donjon, etage)
	var ecran := func(p: Vector2i) -> Vector2:
		return Vector2(int(zone.get_center().x + (p.x - centre_monde.x) * pas), int(zone.get_center().y - (p.y - centre_monde.y) * pas))
	var visible := zone.grow(taille_salle / 2.0)
	var traces := {}
	for ident in etats:
		if etats[ident] == "connue" and not chair:
			continue
		for voisine in salles[ident].get("connections", []):
			voisine = str(voisine)
			if not etats.has(voisine) or traces.has(ident + "|" + voisine):
				continue
			traces[voisine + "|" + ident] = true
			var couleur: Color = COULEURS["couloir"] if etats[voisine] != "connue" and etats[ident] != "connue" else COULEURS["couloir_connu"]
			var a: Vector2 = ecran.call(salles[ident]["position"])
			var b: Vector2 = ecran.call(salles[voisine]["position"])
			var segment := _decouper_segment(a, b, zone)
			if not segment.is_empty():
				Ui.ligne(ci, segment[0], segment[1], couleur, maxi(2, taille_salle / 5))
	var pulsation := 0.5 + 0.5 * sin(Animations.temps() * 4)
	for ident in etats:
		var etat: String = etats[ident]
		var salle: Dictionary = salles[ident]
		var c: Vector2 = ecran.call(salle["position"])
		if not visible.has_point(c):
			continue
		var r := Rect2(c.x - taille_salle / 2.0, c.y - taille_salle / 2.0, taille_salle, taille_salle)
		if not zone.encloses(r):
			if zone.intersects(r):  # salle coupée par le bord de la zone (découpage pygame)
				Ui.rect(ci, r.intersection(zone), _couleur_salle(salle, etat))
			continue
		var arrondi := maxi(2, taille_salle / 5)
		Ui.rect(ci, r, _couleur_salle(salle, etat), 0, arrondi)
		Ui.rect(ci, r, Color8(230, 225, 210) if etat != "connue" else Color8(95, 92, 105), 1, arrondi)
		var contenu := contenu_salle(salle)
		var genre = contenu[0]
		if etat == "connue" and not chair and not salle.get("boss", false) and salle.get("type") != "bonus":
			Ui.texte(ci, "?", c, Color8(150, 145, 160), maxi(10, taille_salle - 4), true, null, "center")
		elif genre != null and (etat != "actuelle" or genre != "depart"):
			dessiner_pictogramme(ci, genre, c, taille_salle, contenu[1])
		if salle.get("verrouillee", false):
			# Cadenas : salle verrouillée (donjon d'aventure), il faut une clé
			var t := maxf(4.0, taille_salle * 0.32)
			var coin := Vector2(r.end.x - t * 0.6, r.position.y + t * 0.4)
			Ui.cercle(ci, coin + Vector2(0, -t * 0.15), t * 0.35, Ui.OR, maxf(1.0, t * 0.15))
			Ui.rect(ci, Rect2(coin + Vector2(-t * 0.5, -t * 0.1), Vector2(t, t * 0.8)), Ui.OR, 0, 1)
		if chair:
			_marques_chair(ci, salle, r)
		_escalier_passage(ci, salle, etat, c, taille_salle, zone)
		if etat == "actuelle":
			var g := 2 + int(2 * pulsation)
			Ui.rect(ci, r.grow(g), Ui.BLANC, 2, maxi(3, taille_salle / 4))


## Segment [a, b] découpé à un rectangle (vide s'il est dehors) : remplace le découpage de pygame.
static func _decouper_segment(a: Vector2, b: Vector2, zone: Rect2) -> Array:
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	var bords := [[-d.x, a.x - zone.position.x], [d.x, zone.end.x - a.x], [-d.y, a.y - zone.position.y], [d.y, zone.end.y - a.y]]
	for bord in bords:
		var p: float = bord[0]
		var q: float = bord[1]
		if p == 0:
			if q < 0:
				return []
		else:
			var t := q / p
			if p < 0:
				t0 = maxf(t0, t)
			else:
				t1 = minf(t1, t)
	if t0 > t1:
		return []
	return [a + d * t0, a + d * t1]


## Mini-carte de l'écran d'exploration : panneau centré sur la salle du héros.
static func dessiner_mini_carte(ci: CanvasItem, donjon, zone: Rect2) -> void:
	Ui.panneau(ci, zone, 200)
	var etage = donjon.salle_actuelle[0]
	var salles: Dictionary = donjon.plan_donjon.get(etage, {})
	var position: Vector2i = salles.get(str(donjon.salle_actuelle[1]), {}).get("position", Vector2i(0, 0))
	var interieur := Rect2(zone.position.x + 4, zone.position.y + 22, zone.size.x - 8, zone.size.y - 40)
	var echelle := zone.size.x / 300.0  # 24 px par case et salles de 16 px pour une carte de 300 px de large
	dessiner_etage(ci, donjon, interieur, 24 * echelle, Vector2(position), maxi(8, int(16 * echelle)))
	var titre := Donjon.nom_niveau(etage)
	Ui.texte(ci, titre.left(1).to_upper() + titre.substr(1), zone.position + Vector2(10, 4), Ui.OR, 14, true)
	var explorees := 0
	for s in salles.values():
		if s.get("visitee", false):
			explorees += 1
	Ui.texte(ci, "%d/%d salles" % [explorees, salles.size()], Vector2(zone.end.x - 10, zone.position.y + 5), Ui.DETAIL, 12, false, null, "topright")
	Ui.texte(ci, "Clic ou Tab : carte", Vector2(zone.get_center().x, zone.end.y - 9), Ui.DETAIL, 11, false, null, "center")
