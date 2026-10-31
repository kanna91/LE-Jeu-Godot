extends Ecran
## Sphérier des talents (menu_talents.py) : trois secteurs colorés, chemins,
## talents clés couronnés (or : purs, rouge : à double tranchant). Double-clic
## (A A) sur un talent relié à un talent appris : l'apprendre. Molette, +/- ou
## LB/RB : zoom ; glisser ou flèches : déplacer ; Tab ou boutons : vues rapides ;
## « Bilan » : total des bonus appris.
##
## Rendu lumineux : gemmes avec dégradé et reflet, halos additifs, nébuleuses
## des secteurs, étoiles scintillantes en parallaxe, énergie qui parcourt les
## liens appris, soleil central à rayons tournants, gerbe d'un talent appris.

const COULEURS_BRANCHES := {"Dégâts": Color8(225, 95, 70), "Défense": Color8(85, 145, 235), "Utilitaire": Color8(95, 200, 120)}
const COULEUR_PONT := Color8(230, 190, 90)
const RAYONS := {"racine": 15, "chemin": 6, "mineur": 8, "notable": 12, "cle": 16}
const GENRES := {"racine": "Centre du sphérier", "chemin": "Chemin", "mineur": "Talent mineur", "notable": "Talent notable", "cle": "Talent clé"}
const COULEUR_MALUS := Color8(235, 70, 60)
const COULEUR_PUR := Color8(240, 200, 80)
const ZOOM_MIN := 0.1
const ZOOM_MAX := 1.8
const DOUBLE_CLIC := 0.4
const NIVEAUX_LUEUR := 8
const NOMBRE_ETOILES := 150
const DUREE_ECLAT := 0.9
const CONTRAINTES := ["talent_sans_critique_physique", "talent_magie_du_sang", "talent_sans_potion_pv"]
const VUE := Rect2(0, 82, Ui.LARGEUR, Ui.HAUTEUR - 82 - 46)
const BOUTON_FERMER := Rect2(Ui.LARGEUR - 136, Ui.HAUTEUR - 40, 120, 32)
const BOUTON_BILAN := Rect2(Ui.LARGEUR - 264, Ui.HAUTEUR - 40, 120, 32)
const PANNEAU_BILAN := Rect2(Ui.LARGEUR - 350, 82 + 6, 340, Ui.HAUTEUR - 82 - 46 - 12)

static var _texture_lueur: Texture2D

## Les événements « mouvement » et « relache » de la souris sont transmis (vue déplaçable).
var glisse_souris := true
var joueur
var noeuds := []
var vues := {"Ensemble": [0.0, 0.0, null], "Centre": [0.0, 0.0, 0.55], "Dégâts": [0.0, -800.0, 0.34], "Défense": [0.0, 800.0, 0.34]}
var boutons_vues := {}
var zoom_ensemble := 0.3
var premieres_parties := {}
var titres_branches := {}
var cible := {"x": 0.0, "y": 0.0, "zoom": 0.6}
var camera := {"x": 0.0, "y": 0.0, "zoom": 0.6}
var vue_active = null
var bilan_ouvert := false
var glisse := false
var depart_glisse := Vector2.ZERO
var a_glisse := false
var dernier_clic := 0.0
var dernier_noeud = null
var message := ""
var message_fin := 0.0
var etoiles := []
var nebuleuses := []
var sens_liens := []
var eclats := []
var etats := {}
var positions := {}
var survole = null
var info = null


func preparer(j) -> Ecran:
	joueur = j
	fond_ecran = "fond_talents.png" if ResourceLoader.exists("res://images/fond_talents.png") else "fond_magie.png"
	noeuds = Talents.noeuds().values()
	var x := Ui.LARGEUR - 16.0
	var noms := vues.keys()
	noms.reverse()
	for nom in noms:
		boutons_vues[nom] = Rect2(x - 98, 22, 98, 30)
		x -= 98 + 6
	var xs := []
	var ys := []
	for t in noeuds:
		xs.append(t.x)
		ys.append(t.y)
	for amas in Talents.spherier()["amas"]:
		if amas.has("cle"):
			premieres_parties[amas["cle"]] = true
	for ba in [["Dégâts", 270.0], ["Défense", 90.0]]:
		var distance := 0.0
		for t in noeuds:
			if U.ga(t, "branche", null) == ba[0]:
				distance = maxf(distance, Vector2(t.x, t.y).length())
		distance += 290
		titres_branches[ba[0]] = Vector2(distance * cos(deg_to_rad(ba[1])), distance * sin(deg_to_rad(ba[1])))
		xs.append(titres_branches[ba[0]].x)
		ys.append(titres_branches[ba[0]].y)
	vues["Ensemble"] = [(xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2, null]
	zoom_ensemble = minf((VUE.size.x - 40) / (xs.max() - xs.min() + 140), (VUE.size.y - 16) / (ys.max() - ys.min() + 60))
	var alea := RandomNumberGenerator.new()
	alea.seed = 7
	for i in NOMBRE_ETOILES:
		etoiles.append([alea.randf_range(0, VUE.size.x), alea.randf_range(0, VUE.size.y), alea.randf_range(0.02, 0.12),
			alea.randf_range(0, TAU), [1, 1, 1, 2][alea.randi_range(0, 3)]])
	for branche in ["Dégâts", "Défense"]:
		var membres := noeuds.filter(func(t): return U.ga(t, "branche", null) == branche)
		var m := Vector2.ZERO
		for t in membres:
			m += Vector2(t.x, t.y)
		m /= membres.size()
		var etendue := 0.0
		for t in membres:
			etendue = maxf(etendue, (Vector2(t.x, t.y) - m).length())
		nebuleuses.append([m, etendue * 1.1, Ui.foncer(COULEURS_BRANCHES[branche], 0.38)])
	nebuleuses.append([Vector2.ZERO, 560.0, Ui.foncer(COULEUR_PONT, 0.3)])
	var tous: Dictionary = Talents.noeuds()
	for l in Talents.spherier()["liens"]:
		var ta = tous[l[0]]
		var tb = tous[l[1]]
		var dedans: bool = Vector2(ta.x, ta.y).length() <= Vector2(tb.x, tb.y).length()
		sens_liens.append([l[0], l[1], ta if dedans else tb, tb if dedans else ta, (hash(l[0] + l[1]) % 997) / 997.0])
	var halo := couche_decoupee(VUE, _dessiner_halos)
	halo.material = _materiau_additif()
	couche_decoupee(VUE, _dessiner_spherier)
	var eclat := couche_decoupee(VUE, _dessiner_eclats)
	eclat.material = _materiau_additif()
	_calculer()
	return self


static func _materiau_additif() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


# ---------------------------------------------------------------------------
# Talents
# ---------------------------------------------------------------------------

static func couleur_talent(t) -> Color:
	var c: Color = COULEURS_BRANCHES.get(U.ga(t, "branche", null), COULEUR_PONT)
	return Ui.foncer(c, 0.8) if t.genre == "chemin" else c


static func etat_talent(j, t) -> String:
	var acquis: Dictionary = U.ga(j, "talents_picked_keys", {Talents.RACINE: true})
	if acquis.has(t.ident):
		return "acquis"
	if Talents.accessible(t.ident, acquis):
		return "dispo" if j.points_de_talent > 0 else "relie"
	return "verrouille"


static func lignes_talent(j, t) -> Array:
	var lignes := []
	if U.vrai(U.ga(t, "branche", null)):
		var lieu: String = U.ga(t, "branche", null) if U.ga(t, "sous_branche", null) == null else "%s › %s" % [U.ga(t, "branche", null), U.ga(t, "sous_branche", null)]
		var genre: String = GENRES[t.genre] + (" à double tranchant" if t.genre == "cle" and Talents.cle_a_malus(t.ident) else "")
		lignes.append(["%s · %s" % [lieu, genre], Ui.DETAIL])
		var partie = Talents.partie(t.ident)
		if partie != null and partie[1] > 1:
			lignes.append(["Partie %d sur %d : à apprendre dans l'ordre" % partie, Ui.DETAIL])
	var bonus := {}
	var malus := {}
	for a in t.stats:
		if t.stats[a] > 0 and not a in CONTRAINTES:
			bonus[a] = t.stats[a]
		else:
			malus[a] = t.stats[a]
	lignes += Talents.decrire_stats(bonus)
	for l in Talents.decrire_stats(malus):
		lignes.append([l, COULEUR_MALUS])
	if t.stats.is_empty():
		lignes.append("Point de départ : tous les chemins partent d'ici.")
	lignes.append({"acquis": ["Appris", Ui.VERT],
		"dispo": ["Disponible — double-clic (A A) pour l'apprendre (1 point)", Ui.OR],
		"relie": ["Plus de point de talent (vous en gagnez en montant de niveau)", Ui.ROUGE],
		"verrouille": ["Verrouillé : apprenez d'abord un talent relié", Ui.ROUGE]}[etat_talent(j, t)])
	return lignes


# ---------------------------------------------------------------------------
# Dessins lumineux
# ---------------------------------------------------------------------------

static func eclaircir(c: Color, f: float) -> Color:
	return Color(c.r + (1 - c.r) * f, c.g + (1 - c.g) * f, c.b + (1 - c.b) * f, c.a)


static func texture_lueur() -> Texture2D:
	if _texture_lueur == null:
		var n := 128
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() / (n / 2.0)
				var f := pow(maxf(0, 1 - d), 2.2)
				img.set_pixel(x, y, Color(f, f, f, 1))
		_texture_lueur = ImageTexture.create_from_image(img)
	return _texture_lueur


## Halo radial (à dessiner sur une couche additive) ; ``niveau`` de 0 à NIVEAUX_LUEUR.
static func lueur(ci: CanvasItem, centre: Vector2, rayon: float, couleur: Color, niveau: float = NIVEAUX_LUEUR) -> void:
	rayon = maxf(2, rayon)
	var k := clampf(niveau, 0, NIVEAUX_LUEUR) / NIVEAUX_LUEUR
	ci.draw_texture_rect(texture_lueur(), Rect2(centre - Vector2(rayon, rayon), Vector2(2 * rayon, 2 * rayon)), false,
		Color(couleur.r * k, couleur.g * k, couleur.b * k, 1))


## Gemme d'un nœud : ombre, dégradé décalé vers le haut à gauche, liseré, reflet.
static func gemme(ci: CanvasItem, c: Vector2, couleur: Color, etat: String, r: float, epais := true) -> void:
	var interieur: Color
	var exterieur: Color
	var lisere: Color
	var largeur := 2.0
	if etat == "acquis":
		interieur = eclaircir(couleur, 0.5)
		exterieur = Ui.foncer(couleur, 0.85)
		lisere = eclaircir(couleur, 0.6)
	elif etat == "dispo":
		interieur = couleur.lerp(Ui.OR, 0.35)
		exterieur = Ui.foncer(couleur, 0.3)
		lisere = eclaircir(Ui.OR, 0.2)
	elif etat == "relie":
		interieur = Ui.foncer(couleur, 0.4)
		exterieur = Ui.foncer(couleur, 0.15)
		lisere = Color8(170, 150, 90)
	else:
		interieur = Color8(34, 32, 46).lerp(couleur, 0.22)
		exterieur = Color8(16, 15, 22)
		lisere = Ui.foncer(couleur, 0.6)
		largeur = 2.0 if epais else 1.0
	ci.draw_circle(c, r + 1, Color8(8, 6, 12, 230), true, -1, true)
	var pas := maxi(2, int(r / 1.5))
	for i in range(pas, 0, -1):
		var t := float(i) / pas
		var k := r * t
		var decalage := (1 - t) * r * 0.3
		ci.draw_circle(c - Vector2(decalage, decalage), k, interieur.lerp(exterieur, pow(t, 1.4)), true, -1, true)
	ci.draw_arc(c, r - largeur / 2, 0, TAU, maxi(12, int(r * 2)), lisere, largeur, true)
	if etat in ["acquis", "dispo"] and r >= 4:
		var centre_reflet := c + Vector2(-r * 0.28, -r * 0.42)
		var points := PackedVector2Array()
		for i in 14:
			var a := TAU * i / 14
			points.append(centre_reflet + Vector2(cos(a) * r * 0.45, sin(a) * r * 0.25))
		ci.draw_colored_polygon(points, Color(1, 1, 1, (150 if etat == "acquis" else 70) / 255.0))


## Couronne d'un talent clé : cercle et quatre losanges, tournée de ``angle`` degrés.
static func couronne(ci: CanvasItem, c: Vector2, couleur: Color, r: float, angle := 0.0) -> void:
	var rayon := r + maxf(2, r * 0.4)
	var d := maxf(1.2, r * 0.22)
	ci.draw_arc(c, rayon, 0, TAU, maxi(16, int(rayon * 2)), couleur, 1.5 if r >= 8 else 1.0, true)
	var claire := eclaircir(couleur, 0.3)
	for i in 4:
		var a := PI / 2 * i - deg_to_rad(angle)
		var p := c + Vector2(cos(a), sin(a)) * rayon
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(cos(a), sin(a)) * d, p + Vector2(-sin(a), cos(a)) * d,
			p - Vector2(cos(a), sin(a)) * d, p + Vector2(sin(a), -cos(a)) * d]), claire)


## Rayons du soleil central (douze pointes), sur une couche additive.
static func rayons_soleil(ci: CanvasItem, c: Vector2, rayon: float, couleur: Color, angle: float) -> void:
	rayon = maxf(6, rayon)
	for i in 12:
		var a := TAU * i / 12 - deg_to_rad(angle)
		var longueur := rayon if i % 2 == 0 else rayon * 0.7
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(cos(a - 0.18), sin(a - 0.18)) * rayon * 0.25,
			c + Vector2(cos(a), sin(a)) * longueur, c + Vector2(cos(a + 0.18), sin(a + 0.18)) * rayon * 0.25]),
			Ui.foncer(couleur, 0.55 if i % 2 == 0 else 0.35))


# ---------------------------------------------------------------------------
# Caméra
# ---------------------------------------------------------------------------

func ecran(t) -> Vector2:
	return Vector2(int(VUE.get_center().x + (t.x - camera["x"]) * camera["zoom"]), int(VUE.get_center().y + (t.y - camera["y"]) * camera["zoom"]))


func point(p: Vector2) -> Vector2:
	return Vector2(VUE.get_center().x + (p.x - camera["x"]) * camera["zoom"], VUE.get_center().y + (p.y - camera["y"]) * camera["zoom"])


func monde(p: Vector2) -> Vector2:
	return Vector2(camera["x"] + (p.x - VUE.get_center().x) / camera["zoom"], camera["y"] + (p.y - VUE.get_center().y) / camera["zoom"])


func rayon(t) -> int:
	return maxi(3, int(RAYONS[t.genre] * minf(1.3, maxf(0.45, camera["zoom"]))))


func viser(nom: String) -> void:
	cible["x"] = vues[nom][0]
	cible["y"] = vues[nom][1]
	cible["zoom"] = zoom_ensemble if vues[nom][2] == null else vues[nom][2]


func zoomer(facteur: float, autour: Vector2) -> void:
	var avant := monde(autour)
	camera["zoom"] = clampf(camera["zoom"] * facteur, ZOOM_MIN, ZOOM_MAX)
	cible["zoom"] = camera["zoom"]
	var apres := monde(autour)
	camera["x"] += avant.x - apres.x
	camera["y"] += avant.y - apres.y
	cible["x"] = camera["x"]
	cible["y"] = camera["y"]
	vue_active = null


func deplacer(d: Vector2) -> void:
	camera["x"] -= d.x / camera["zoom"]
	camera["y"] -= d.y / camera["zoom"]
	cible["x"] = camera["x"]
	cible["y"] = camera["y"]
	vue_active = null


func noeud_sous(p: Vector2):
	if not VUE.has_point(p) or (bilan_ouvert and PANNEAU_BILAN.has_point(p)):
		return null
	for t in noeuds:
		if p.distance_to(positions[t.ident]) <= rayon(t) + 4:
			return t
	return null


func apprendre(t) -> void:
	var etat := etat_talent(joueur, t)
	if etat == "dispo" and joueur.debloquer_talent(t):
		message = "Talent appris : " + t.nom
		eclats.append([t, Animations.temps()])
	elif etat == "acquis":
		message = "Talent déjà appris."
	elif etat == "relie":
		message = "Plus de point de talent : vous en gagnez en montant de niveau."
	else:
		message = "Verrouillé : il doit être relié à un talent déjà appris."
	message_fin = Animations.temps() + 2.5


func _calculer() -> void:
	for t in noeuds:
		positions[t.ident] = ecran(t)
		etats[t.ident] = etat_talent(joueur, t)


func _mise_a_jour(delta: float) -> void:
	var k := 1.0 - pow(0.8, delta * 60)
	for c in ["x", "y", "zoom"]:
		camera[c] += (cible[c] - camera[c]) * k
	_calculer()
	survole = noeud_sous(souris())
	var cle = Manette.cle_selectionnee(self)
	info = survole
	if info == null and cle is Array and cle.size() == 2 and cle[0] == "noeud":
		info = Talents.noeuds().get(cle[1])
		var p: Vector2 = positions.get(cle[1], VUE.get_center())
		if not VUE.grow_individual(-80, -55, -80, -55).has_point(p):
			cible["x"] = camera["x"] + (p.x - VUE.get_center().x) / camera["zoom"] * 0.6
			cible["y"] = camera["y"] + (p.y - VUE.get_center().y) / camera["zoom"] * 0.6
	var maintenant := Animations.temps()
	eclats = eclats.filter(func(e): return maintenant - e[1] < DUREE_ECLAT)


# ---------------------------------------------------------------------------
# Couches
# ---------------------------------------------------------------------------

func _dessiner(ci: Control) -> void:
	Ui.voile(ci, 150)


## Couche additive : nébuleuses, étoiles, lueur des liens, halos des nœuds, énergie.
func _dessiner_halos(ci: Control) -> void:
	var maintenant := Animations.temps()
	var zoom: float = camera["zoom"]
	for n in nebuleuses:
		lueur(ci, point(n[0]), maxf(8, n[1] * zoom), n[2])
	for e in etoiles:
		var px: float = VUE.position.x + fposmod(e[0] - camera["x"] * zoom * e[2], VUE.size.x)
		var py: float = VUE.position.y + fposmod(e[1] - camera["y"] * zoom * e[2], VUE.size.y)
		var eclat := (70 + 60 * sin(maintenant * (1.2 + e[2] * 8) + e[3])) / 255.0
		if e[4] == 1:
			ci.draw_rect(Rect2(int(px), int(py), 1, 1), Color(eclat, eclat, minf(1, eclat * 1.1)))
		else:
			lueur(ci, Vector2(px, py), 3, Color(minf(1, eclat + 0.16), minf(1, eclat + 0.16), minf(1, eclat + 0.27)))
	var epaisseur := maxf(2, int(4 * zoom))
	var pulsation := 0.5 + 0.5 * sin(maintenant * 4)
	var tous: Dictionary = Talents.noeuds()
	for l in sens_liens:
		var ea: String = etats[l[0]]
		var eb: String = etats[l[1]]
		var a: Vector2 = positions[l[0]]
		var b: Vector2 = positions[l[1]]
		if ea == "acquis" and eb == "acquis":
			var tb = tous[l[1]]
			var ta = tous[l[0]]
			ci.draw_line(a, b, Ui.foncer(couleur_talent(tb if U.vrai(U.ga(tb, "branche", null)) else ta), 0.45), epaisseur * 4, true)
		elif (ea == "acquis" or eb == "acquis") and (ea == "dispo" or eb == "dispo"):
			ci.draw_line(a, b, Ui.foncer(Ui.OR, 0.08 + 0.12 * pulsation), epaisseur * 2, true)
	# Énergie le long des liens appris, du centre vers l'extérieur
	var rayon_energie := maxf(3, int(9 * zoom))
	for l in sens_liens:
		if etats[l[0]] != "acquis" or etats[l[1]] != "acquis":
			continue
		var p1: Vector2 = positions[l[2].ident]
		var p2: Vector2 = positions[l[3].ident]
		var longueur := p1.distance_to(p2)
		if longueur < 8 or not _segment_visible(p1, p2):
			continue
		var avance := fposmod(maintenant * 140 / maxf(longueur, 60) + l[4], 1.0)
		lueur(ci, p1.lerp(p2, avance), rayon_energie, eclaircir(couleur_talent(l[3] if U.vrai(U.ga(l[3], "branche", null)) else l[2]), 0.5), 6)
	# Halos des nœuds et soleil central
	var angle := fmod(maintenant * 25, 360)
	for t in noeuds:
		var p: Vector2 = positions[t.ident]
		var r := rayon(t)
		if not VUE.grow_individual(r + 30, r + 15, r + 30, r + 15).has_point(p):
			continue
		var etat: String = etats[t.ident]
		if t.genre == "racine":
			lueur(ci, p, r * 4, COULEUR_PONT, 5 + int(2 * pulsation))
			rayons_soleil(ci, p, r * 2.6, COULEUR_PONT, angle * 0.4)
		elif etat == "acquis":
			lueur(ci, p, r * 2.6, couleur_talent(t), 5)
		elif etat == "dispo":
			lueur(ci, p, r * (2.4 + 0.5 * pulsation), Ui.OR, 2 + int(3 * pulsation))


func _segment_visible(a: Vector2, b: Vector2) -> bool:
	return Rect2(a, Vector2.ZERO).expand(b).grow(1).intersects(VUE)


## Couche normale : titres, liens, couronnes, gemmes et noms.
func _dessiner_spherier(ci: Control) -> void:
	var maintenant := Animations.temps()
	var zoom: float = camera["zoom"]
	for branche in titres_branches:
		Ui.texte(ci, branche.to_upper(), point(titres_branches[branche]), COULEURS_BRANCHES[branche], maxi(14, int(30 * zoom)), true, null, "center")
	var noms_amas := zoom < 0.7
	if noms_amas and zoom >= 0.16:
		for amas in Talents.spherier()["amas"]:
			var p := point(Vector2(amas["x"], amas["y"]))
			Ui.texte(ci, amas["nom"], p - Vector2(0, RAYONS["notable"] + 14), COULEURS_BRANCHES.get(amas["branche"], COULEUR_PONT),
				12 if zoom < 0.35 else 14, true, null, "center")
	var epaisseur := maxf(2, int(4 * zoom))
	var tous: Dictionary = Talents.noeuds()
	for l in sens_liens:
		var ea: String = etats[l[0]]
		var eb: String = etats[l[1]]
		var a: Vector2 = positions[l[0]]
		var b: Vector2 = positions[l[1]]
		if not _segment_visible(a, b):
			continue
		if ea == "acquis" and eb == "acquis":
			continue
		if ea == "acquis" or eb == "acquis":
			var ouvert := ea == "dispo" or eb == "dispo"
			ci.draw_line(a, b, Color8(175, 145, 70) if ouvert else Color8(120, 105, 70), maxf(1, epaisseur - 2), true)
		else:
			ci.draw_line(a, b, Color8(66, 62, 84), 1, true)
	for l in sens_liens:
		if etats[l[0]] != "acquis" or etats[l[1]] != "acquis":
			continue
		var ta = tous[l[0]]
		var tb = tous[l[1]]
		var couleur := couleur_talent(tb if U.vrai(U.ga(tb, "branche", null)) else ta)
		ci.draw_line(positions[l[0]], positions[l[1]], eclaircir(couleur, 0.25), epaisseur, true)
		ci.draw_line(positions[l[0]], positions[l[1]], eclaircir(couleur, 0.75), 1, true)
	var cle = Manette.cle_selectionnee(self)
	var angle := fmod(maintenant * 25, 360)
	for t in noeuds:
		var p: Vector2 = positions[t.ident]
		var r := rayon(t)
		if not VUE.grow_individual(r + 30, r + 15, r + 30, r + 15).has_point(p):
			continue
		var couleur := couleur_talent(t)
		var etat: String = etats[t.ident]
		if t.genre == "cle":
			var anneau := COULEUR_MALUS if Talents.cle_a_malus(t.ident) else COULEUR_PUR
			var vive := etat in ["acquis", "dispo"]
			couronne(ci, p, anneau if vive else Ui.foncer(anneau, 0.55), r, (angle if etat == "acquis" else -angle) if vive else 0.0)
		gemme(ci, p, couleur, etat, r, t.genre != "mineur")
		if t == survole or cle == ["noeud", t.ident]:
			Ui.cercle(ci, p, r + 3, Ui.BLANC, 1)
		var premiere: bool = premieres_parties.has(t.ident)
		if (t.genre in ["notable", "cle", "racine"] and not noms_amas) or (premiere and zoom >= 0.26) or zoom >= 1.15:
			var nom: String = t.nom
			if noms_amas and nom.ends_with(" I"):
				nom = nom.substr(0, nom.length() - 2)
			var gras: bool = t.genre != "mineur"
			var dim := Ui.taille_texte(nom, 12, gras)
			var pos := Vector2(int(p.x - dim.x / 2), p.y + r + 4 + Ui.police(gras).get_ascent(12))
			ci.draw_string_outline(Ui.police(gras), pos, nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Ui.NOIR)
			ci.draw_string(Ui.police(gras), pos, nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Ui.TEXTE if etat != "verrouille" else Ui.DETAIL)


## Couche additive du dessus : surbrillance et gerbes des talents appris.
func _dessiner_eclats(ci: Control) -> void:
	var maintenant := Animations.temps()
	var zoom: float = camera["zoom"]
	var cle = Manette.cle_selectionnee(self)
	for t in noeuds:
		if t == survole or cle == ["noeud", t.ident]:
			lueur(ci, positions[t.ident], rayon(t) * 2.2, Color8(120, 120, 130), 6)
	for e in eclats:
		var t = e[0]
		var age: float = (maintenant - e[1]) / DUREE_ECLAT
		var p: Vector2 = positions[t.ident]
		var r := rayon(t)
		var couleur := eclaircir(couleur_talent(t), 0.4)
		var vif := 1 - age
		lueur(ci, p, r * (2.5 + 5 * age), couleur, NIVEAUX_LUEUR * vif)
		lueur(ci, p, r * 2, Color(1, 1, 1), NIVEAUX_LUEUR * pow(vif, 3))
		Ui.cercle(ci, p, int(r + 70 * age * maxf(0.5, zoom)), Ui.foncer(couleur, vif), 3)
		for i in 16:
			var a := TAU * i / 16 + (hash(t.ident) % 100) / 30.0
			var distance := r + (35 + 15 * (i % 3)) * age * maxf(0.6, zoom) * 1.6
			lueur(ci, p + Vector2(cos(a), sin(a)) * distance, maxf(3, int(8 * vif)), couleur, int(NIVEAUX_LUEUR * vif) + 1)


func _dessiner_dessus(ci: Control) -> void:
	var s := souris()
	Ui.panneau(ci, Rect2(10, 10, Ui.LARGEUR - 20, 64), 215)
	var appris: int = joueur.talents_picked_keys.size() - 1
	Ui.texte(ci, "Sphérier des talents", Vector2(24, 16), Ui.OR, 20, true)
	var points: int = joueur.points_de_talent
	Ui.texte(ci, "Points : %d" % points, Vector2(250, 19), Ui.VERT if points else Ui.ROUGE, 17, true)
	Ui.texte(ci, "Appris : %d / %d" % [appris, noeuds.size() - 1], Vector2(360, 20), Ui.TEXTE, 15)
	Ui.texte(ci, "Double-clic : apprendre · molette ou +/- : zoom · glisser ou flèches : déplacer · Tab : vue suivante",
		Vector2(24, 48), Ui.DETAIL, 12, boutons_vues["Ensemble"].position.x - 36)
	for nom in boutons_vues:
		Ui.onglet(ci, boutons_vues[nom], nom, nom == vue_active, boutons_vues[nom].has_point(s), 14)
	var legende := [[COULEURS_BRANCHES["Dégâts"], "Dégâts"], [COULEURS_BRANCHES["Défense"], "Défense"],
		[COULEURS_BRANCHES["Utilitaire"], "Utilitaire"], [COULEUR_PUR, "Clé pure"], [COULEUR_MALUS, "Clé à malus"]]
	var x := 24.0
	var y := Ui.HAUTEUR - 24.0
	for l in legende:
		if String(l[1]).begins_with("Clé"):
			couronne(ci, Vector2(x, y), l[0], 4)
		else:
			gemme(ci, Vector2(x, y), l[0], "acquis", 6)
		x = Ui.texte(ci, l[1], Vector2(x + 11, y), Ui.TEXTE, 13, false, null, "midleft").end.x + 18
	var x_legende := x + 4
	var etats_legende := [["acquis", "Appris"], ["dispo", "Disponible"], ["verrouille", "Verrouillé"]]
	for i in etats_legende.size():
		var cx := x_legende + i * 84
		gemme(ci, Vector2(cx, y), Color8(200, 200, 210), etats_legende[i][0], 6)
		Ui.texte(ci, etats_legende[i][1], Vector2(cx + 12, y), Ui.DETAIL, 13, false, null, "midleft")
	Ui.bouton(ci, BOUTON_BILAN, "Fermer le bilan" if bilan_ouvert else "Bilan", Ui.BOUTON_BLEU, BOUTON_BILAN.has_point(s), true, 14)
	Ui.bouton(ci, BOUTON_FERMER, "Fermer", Ui.BOUTON_ROUGE, BOUTON_FERMER.has_point(s))
	if bilan_ouvert:
		Ui.panneau(ci, PANNEAU_BILAN, 235)
		Ui.texte(ci, "Bilan des talents (%d appris)" % appris, PANNEAU_BILAN.position + Vector2(14, 10), Ui.OR, 16, true)
		var lignes: Array = Talents.decrire_stats(joueur.arbre_de_talents.bilan())
		if lignes.is_empty():
			lignes = ["Aucun talent appris pour l'instant."]
		var taille := 13 if lignes.size() <= 20 else 12
		var yb := PANNEAU_BILAN.position.y + 38
		for l in lignes:
			for morceau in Ui.decouper("• " + l, taille, false, PANNEAU_BILAN.size.x - 28):
				if yb > PANNEAU_BILAN.end.y - 18:
					break
				Ui.texte(ci, morceau, Vector2(PANNEAU_BILAN.position.x + 14, yb), Ui.TEXTE, taille)
				yb += Ui.hauteur_ligne(taille) + 1
	if message != "" and Animations.temps() < message_fin:
		Ui.message(ci, message, Vector2(Ui.LARGEUR / 2, VUE.end.y - 18))
	if info != null:
		var p: Vector2 = positions[info.ident]
		var r := rayon(info)
		Ui.infobulle(ci, info.nom, lignes_talent(joueur, info), Rect2(p.x - r, p.y - r, 2 * r, 2 * r), 290, couleur_talent(info))
	var z := []
	for nom in boutons_vues:
		z.append([["vue", nom], boutons_vues[nom]])
	for t in noeuds:
		var r := rayon(t) + 3
		z.append([["noeud", t.ident], Rect2(positions[t.ident] - Vector2(r, r), Vector2(2 * r, 2 * r))])
	z += [[["bilan"], BOUTON_BILAN], [["fermer"], BOUTON_FERMER]]
	definir_zones(z, ["noeud", Talents.RACINE])


# ---------------------------------------------------------------------------
# Entrées
# ---------------------------------------------------------------------------

func _evenement(ev: Dictionary) -> void:
	match ev["type"]:
		"touche":
			var t: int = ev["touche"]
			if t == KEY_ESCAPE:
				fermer()
			elif t in [KEY_MINUS, KEY_KP_SUBTRACT]:
				zoomer(1 / 1.15, VUE.get_center())
			elif t in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]:
				zoomer(1.15, VUE.get_center())
			elif t == KEY_LEFT:
				deplacer(Vector2(40, 0))
			elif t == KEY_RIGHT:
				deplacer(Vector2(-40, 0))
			elif t == KEY_UP:
				deplacer(Vector2(0, 40))
			elif t == KEY_DOWN:
				deplacer(Vector2(0, -40))
			elif t == KEY_TAB:
				var noms := vues.keys()
				vue_active = noms[(noms.find(vue_active) + 1) % noms.size()] if vue_active in noms else noms[0]
				viser(vue_active)
		"molette":
			var s := souris()
			zoomer(1.15 if ev["sens"] > 0 else 1 / 1.15, s if VUE.has_point(s) else VUE.get_center())
		"relache":
			glisse = false
		"mouvement":
			if glisse:
				if a_glisse or ev["pos"].distance_to(depart_glisse) > 4:
					a_glisse = true
					deplacer(ev["rel"])
		"clic":
			var pos: Vector2 = ev["pos"]
			if ev["bouton"] in [2, 3]:
				glisse = true
				depart_glisse = pos
				a_glisse = false
				return
			if BOUTON_FERMER.has_point(pos):
				fermer()
				return
			if BOUTON_BILAN.has_point(pos):
				bilan_ouvert = not bilan_ouvert
				return
			for nom in boutons_vues:
				if boutons_vues[nom].has_point(pos):
					vue_active = nom
					viser(nom)
					return
			var t = noeud_sous(pos)
			if t != null:
				var maintenant := Animations.temps()
				if dernier_noeud == t and maintenant - dernier_clic < DOUBLE_CLIC:
					apprendre(t)
					dernier_noeud = null
				else:
					dernier_noeud = t
					dernier_clic = maintenant
			elif VUE.has_point(pos) and not (bilan_ouvert and PANNEAU_BILAN.has_point(pos)):
				glisse = true
				depart_glisse = pos
				a_glisse = false
