class_name Ui
extends RefCounted
## Éléments d'interface communs aux écrans et outils de dessin.
##
## Toutes les fonctions dessinent dans un CanvasItem ``ci`` (pendant son _draw),
## avec les coordonnées de la fenêtre pygame d'origine (960 × 540) : panneaux
## sombres bordés de bronze, boutons arrondis, onglets dorés, textes tronqués,
## info-bulles qui restent dans l'écran. La police est Arial, comme pygame.SysFont("arial").

const LARGEUR := 960
const HAUTEUR := 540

const BLANC := Color8(255, 255, 255)
const NOIR := Color8(0, 0, 0)
const OR := Color8(255, 215, 0)
const TEXTE := Color8(235, 235, 235)
const DETAIL := Color8(170, 170, 185)
const GRISE := Color8(110, 110, 120)
const VERT := Color8(110, 230, 120)
const ROUGE := Color8(230, 90, 80)
const BRONZE := Color8(150, 110, 60)
const FOND_PANNEAU := Color8(12, 10, 16, 205)
const LIGNE := Color8(40, 36, 52)
const LIGNE_SURVOL := Color8(70, 62, 92)
const BOUTON_ROUGE := Color8(170, 45, 45)
const BOUTON_VERT := Color8(40, 130, 60)
const BOUTON_BLEU := Color8(60, 70, 140)
const BOUTON_NEUTRE := Color8(60, 54, 74)

static var _polices := {}
static var _styles := {}
static var _textures := {}
static var _tailles_texte := {}


# ---------------------------------------------------------------------------
# Polices et textes
# ---------------------------------------------------------------------------

## Police Arial (grasse ou non) : la taille est donnée au moment du dessin.
static func police(gras := false) -> Font:
	if not _polices.has(gras):
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Arial", "Liberation Sans", "DejaVu Sans", "sans-serif"])
		f.font_weight = 700 if gras else 400
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_polices[gras] = f
	return _polices[gras]


## Largeur et hauteur d'un texte (``police.size(texte)``).
static func taille_texte(contenu: String, taille := 16, gras := false) -> Vector2:
	var cle := "%d|%s|%s" % [taille, gras, contenu]
	if _tailles_texte.has(cle):
		return _tailles_texte[cle]
	var f := police(gras)
	var t := Vector2(f.get_string_size(contenu, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x, f.get_height(taille))
	if _tailles_texte.size() > 4000:
		_tailles_texte.clear()
	_tailles_texte[cle] = t
	return t


static func hauteur_ligne(taille := 16, gras := false) -> float:
	return police(gras).get_height(taille)


## Raccourcit un texte avec « … » pour qu'il tienne dans une largeur.
static func tronquer(contenu: String, taille: int, gras: bool, largeur_max: float) -> String:
	if taille_texte(contenu, taille, gras).x <= largeur_max:
		return contenu
	while contenu != "" and taille_texte(contenu + "…", taille, gras).x > largeur_max:
		contenu = contenu.substr(0, contenu.length() - 1)
	return contenu + "…"


## Rectangle d'un texte placé par une ancre pygame (« topleft », « center », « midbottom »...).
static func rect_ancre(taille: Vector2, position: Vector2, ancre: String) -> Rect2:
	var x := position.x
	var y := position.y
	match ancre:
		"topleft":
			pass
		"center":
			x -= taille.x / 2
			y -= taille.y / 2
		"topright":
			x -= taille.x
		"midleft":
			y -= taille.y / 2
		"midright":
			x -= taille.x
			y -= taille.y / 2
		"midtop":
			x -= taille.x / 2
		"midbottom":
			x -= taille.x / 2
			y -= taille.y
		"bottomleft":
			y -= taille.y
		"bottomright":
			x -= taille.x
			y -= taille.y
	return Rect2(floorf(x), floorf(y), taille.x, taille.y)


## Écrit un texte (tronqué si besoin) et renvoie son rectangle.
static func texte(ci: CanvasItem, contenu: String, position: Vector2, couleur := TEXTE, taille := 16, gras := false,
		largeur_max = null, ancre := "topleft") -> Rect2:
	if largeur_max != null:
		contenu = tronquer(contenu, taille, gras, largeur_max)
	var t := taille_texte(contenu, taille, gras)
	var r := rect_ancre(t, position, ancre)
	var f := police(gras)
	ci.draw_string(f, Vector2(r.position.x, r.position.y + f.get_ascent(taille)), contenu, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, couleur)
	return r


## Découpe un texte en lignes qui tiennent dans une largeur (sauts de ligne respectés).
static func decouper(contenu: String, taille: int, gras: bool, largeur: float) -> Array:
	var lignes := []
	for paragraphe in str(contenu).split("\n"):
		var courante := ""
		for mot in paragraphe.split(" "):
			var essai := ("%s %s" % [courante, mot]).strip_edges()
			if taille_texte(essai, taille, gras).x <= largeur or courante == "":
				courante = essai
			else:
				lignes.append(courante)
				courante = mot
		lignes.append(courante)
	return lignes


# ---------------------------------------------------------------------------
# Formes
# ---------------------------------------------------------------------------

static func _style(fond: Color, bordure: Color, epaisseur: int, rayon: int) -> StyleBoxFlat:
	var cle := "%s|%s|%d|%d" % [fond.to_html(), bordure.to_html(), epaisseur, rayon]
	if not _styles.has(cle):
		var s := StyleBoxFlat.new()
		s.bg_color = fond
		s.border_color = bordure
		s.set_border_width_all(epaisseur)
		s.set_corner_radius_all(rayon)
		s.anti_aliasing = true
		s.anti_aliasing_size = 0.8
		s.corner_detail = 6
		if _styles.size() > 2000:
			_styles.clear()
		_styles[cle] = s
	return _styles[cle]


## ``pygame.draw.rect`` : plein (épaisseur 0) ou contour, coins arrondis.
static func rect(ci: CanvasItem, r: Rect2, couleur: Color, epaisseur_f: float = 0, rayon_f: float = 0) -> void:
	if r.size.x <= 0 or r.size.y <= 0:
		return
	var epaisseur := int(epaisseur_f)
	var rayon := mini(int(rayon_f), int(minf(r.size.x, r.size.y) / 2))
	if epaisseur == 0:
		if rayon == 0:
			ci.draw_rect(r, couleur)
		else:
			ci.draw_style_box(_style(couleur, couleur, 0, rayon), r)
	else:
		if rayon == 0:
			ci.draw_rect(r.grow(-epaisseur / 2.0), couleur, false, epaisseur)
		else:
			ci.draw_style_box(_style(Color(0, 0, 0, 0), couleur, epaisseur, rayon), r)


## ``pygame.draw.circle`` : disque (épaisseur 0) ou cercle.
static func cercle(ci: CanvasItem, centre: Vector2, rayon: float, couleur: Color, epaisseur: float = 0) -> void:
	if epaisseur == 0:
		ci.draw_circle(centre, rayon, couleur, true, -1.0, true)
	else:
		ci.draw_arc(centre, rayon - epaisseur / 2.0, 0, TAU, maxi(16, int(rayon * 2)), couleur, epaisseur, true)


static func ligne(ci: CanvasItem, a: Vector2, b: Vector2, couleur: Color, epaisseur: float = 1) -> void:
	ci.draw_line(a, b, couleur, epaisseur, true)


static func polygone(ci: CanvasItem, points: PackedVector2Array, couleur: Color, epaisseur: float = 0) -> void:
	if epaisseur == 0:
		if points.size() >= 3:
			ci.draw_colored_polygon(points, couleur)
	else:
		var ferme := points.duplicate()
		ferme.append(points[0])
		ci.draw_polyline(ferme, couleur, epaisseur, true)


## Assombrit tout l'écran.
static func voile(ci: CanvasItem, alpha := 120) -> void:
	ci.draw_rect(Rect2(0, 0, LARGEUR, HAUTEUR), Color8(0, 0, 0, alpha))


static func eclaircir(couleur: Color, ajout: int) -> Color:
	return Color8(mini(255, couleur.r8 + ajout), mini(255, couleur.g8 + ajout), mini(255, couleur.b8 + ajout), couleur.a8)


static func foncer(couleur: Color, facteur: float) -> Color:
	return Color8(int(couleur.r8 * facteur), int(couleur.g8 * facteur), int(couleur.b8 * facteur), couleur.a8)


# ---------------------------------------------------------------------------
# Images
# ---------------------------------------------------------------------------

## Texture d'une image du dossier images (chemin relatif : « salles/image_boss.png »).
static func texture(chemin: String) -> Texture2D:
	if not _textures.has(chemin):
		var t = load("res://images/" + chemin)
		_textures[chemin] = t
	return _textures[chemin]


## Dessine une image étirée dans un rectangle (``smoothscale`` puis ``blit``).
static func image(ci: CanvasItem, chemin: String, r: Rect2, teinte := Color(1, 1, 1, 1)) -> void:
	var t := texture(chemin)
	if t != null:
		ci.draw_texture_rect(t, r, false, teinte)


## Fond d'écran (image étirée sur toute la fenêtre).
static func fond(ci: CanvasItem, chemin: String) -> void:
	image(ci, chemin, Rect2(0, 0, LARGEUR, HAUTEUR))


# ---------------------------------------------------------------------------
# Composants
# ---------------------------------------------------------------------------

## Panneau sombre semi-transparent aux coins arrondis.
static func panneau(ci: CanvasItem, r: Rect2, alpha := 205, bordure := true) -> void:
	rect(ci, r, Color8(FOND_PANNEAU.r8, FOND_PANNEAU.g8, FOND_PANNEAU.b8, alpha), 0, 8)
	if bordure:
		rect(ci, r, BRONZE, 1, 8)


## Bouton arrondi avec son libellé centré.
static func bouton(ci: CanvasItem, r: Rect2, libelle: String, couleur := BOUTON_NEUTRE, survol := false, actif := true,
		taille := 16) -> void:
	var fond_bouton: Color
	var encre: Color
	if not actif:
		fond_bouton = Color8(45, 42, 52)
		encre = GRISE
	else:
		fond_bouton = eclaircir(couleur, 30) if survol else couleur
		encre = BLANC
	rect(ci, r, fond_bouton, 0, 6)
	rect(ci, r, BRONZE if actif else Color8(70, 66, 78), 1, 6)
	while taille > 12 and taille_texte(libelle, taille, true).x > r.size.x - 10:
		taille -= 1
	texte(ci, libelle, r.get_center(), encre, taille, true, r.size.x - 10, "center")


## Onglet (doré lorsqu'il est choisi).
static func onglet(ci: CanvasItem, r: Rect2, libelle: String, choisi: bool, survol := false, taille := 15) -> void:
	var fond_onglet := BRONZE if choisi else (LIGNE_SURVOL if survol else LIGNE)
	rect(ci, r, fond_onglet, 0, 6)
	rect(ci, r, BRONZE, 1, 6)
	texte(ci, libelle, r.get_center(), BLANC, taille, choisi, r.size.x - 8, "center")


## Info-bulle à côté d'un rectangle, sans sortir de l'écran. ``lignes`` : textes ou [texte, couleur].
static func infobulle(ci: CanvasItem, titre: String, lignes: Array, ancre: Rect2, largeur := 300, couleur_titre := OR) -> void:
	var marge := 10
	var rendu := []
	if titre != "":
		for morceau in decouper(titre, 16, true, largeur - 2 * marge):
			rendu.append([morceau, couleur_titre, 16, true])
	for l in lignes:
		var contenu: String
		var couleur := TEXTE
		if l is Array:
			contenu = str(l[0])
			couleur = l[1]
		else:
			contenu = str(l)
		for morceau in decouper(contenu, 14, false, largeur - 2 * marge):
			rendu.append([morceau, couleur, 14, false])
	var hauteur := 2.0 * marge
	for r in rendu:
		hauteur += hauteur_ligne(r[2], r[3]) + 2
	var x := ancre.end.x + 10 if ancre.end.x + 10 + largeur <= LARGEUR - 4 else ancre.position.x - 10 - largeur
	x = maxf(4, minf(x, LARGEUR - largeur - 4))
	var y := maxf(4, minf(ancre.position.y, HAUTEUR - hauteur - 4))
	var carte := Rect2(x, y, largeur, hauteur)
	rect(ci, carte, Color8(15, 13, 22, 238), 0, 8)
	rect(ci, carte, BRONZE, 1, 8)
	var cy := y + marge
	for r in rendu:
		texte(ci, r[0], Vector2(x + marge, cy), r[1], r[2], r[3])
		cy += hauteur_ligne(r[2], r[3]) + 2


## Message de confirmation (texte gras ombré sur fond sombre).
## Message centré sur ``position`` ; au-delà de MESSAGE_LARGEUR_MAX pixels, il passe à la ligne.
const MESSAGE_LARGEUR_MAX := 820.0


static func message(ci: CanvasItem, contenu: String, position: Vector2, couleur := OR, taille := 15) -> void:
	var lignes := decouper(contenu, taille, true, MESSAGE_LARGEUR_MAX)
	var hl := hauteur_ligne(taille, true)
	var largeur := 0.0
	for l in lignes:
		largeur = maxf(largeur, taille_texte(l, taille, true).x)
	var r := rect_ancre(Vector2(largeur, hl * lignes.size()), position, "center")
	rect(ci, Rect2(r.position.x - 12, r.position.y - 5, r.size.x + 24, r.size.y + 10), Color8(0, 0, 0, 170), 0, 6)
	for i in lignes.size():
		var pl := Vector2(position.x - taille_texte(lignes[i], taille, true).x / 2.0, r.position.y + i * hl)
		texte(ci, lignes[i], pl + Vector2(1, 1), NOIR, taille, true)
		texte(ci, lignes[i], pl, couleur, taille, true)


## Barre de défilement verticale (ascenseur).
static func ascenseur(ci: CanvasItem, zone: Rect2, defilement: float, defilement_max: float, x: float) -> void:
	if defilement_max <= 0:
		return
	var haut := zone.size.y * zone.size.y / (zone.size.y + defilement_max)
	var pos := zone.position.y + (zone.size.y - haut) * defilement / defilement_max
	rect(ci, Rect2(x, zone.position.y, 5, zone.size.y), Color8(70, 70, 80), 0, 2)
	rect(ci, Rect2(x, pos, 5, haut), Color8(200, 160, 90), 0, 2)
