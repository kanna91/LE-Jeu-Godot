class_name OutilPerspective
extends RefCounted
## Couche « Perspective » de l'éditeur des salles (EditeurZones, touche V), 2026-11-15. Demande de l'utilisateur :
## « un outil pour mieux gérer les perspectives des ennemis et du personnage dans les salles. Dans certaines salles, le
## personnage marche très longtemps pour faire quelques mètres et les distances ou la taille du personnage et des
## ennemis ne sont pas raccord avec la salle. »
##
## Règle la clé « perspective » de la salle (SallePeinte) :
## - « table_hauteur » : [[y, hauteur du héros en pixels de l'image], ...], interpolée entre les points. Chaque point
##   est une règle verticale à gauche de l'image : glisser son pied change la profondeur (y), glisser sa tête change la
##   taille du héros à cette profondeur. Clic ailleurs : nouveau point ; clic droit sur un point : le retirer.
## - « vitesse » : vitesse du héros (en hauteurs de héros par seconde, en courant ; × SallePeinte.VITESSE_MARCHE en
##   marchant) ;
## - « compression_profondeur » : part de la vitesse gardée en profondeur, de près ;
## - « compression_min » : plancher de cette part au fond (SallePeinte.COMPRESSION_MIN par défaut). Plus elle est
##   haute, plus le héros avance vite vers le fond : c'est le réglage du « marche très longtemps pour quelques mètres ».
## Silhouettes : le héros et l'ennemi choisi à la souris (avec sa taille de l'éditeur des ennemis), et une rangée de
## héros du bas au haut du sol. Le panneau affiche la profondeur et la largeur du sol en mètres (héros = 1,75 m) et le
## temps pour le traverser. En mode Marche (Tab), on essaie tout de suite.
## Enregistré avec la salle (Ctrl+S), et dans ``outils/zones_manuelles/<id>.json`` pour que les importeurs et la mesure
## automatique (outils/mesurer_perspective.py) ne l'écrasent pas.

const COULEUR := Color(0.55, 0.85, 1.0)
const TAILLE_HEROS_M := 1.75
const X_REGLES := 26.0
const ECART_MIN := 6.0
const AIDE := "Couche Perspective — règles à gauche : glisser le pied (●) = profondeur, glisser la tête (▲) = taille du héros à cette profondeur\n" \
	+ "clic ailleurs : nouveau point   clic droit sur une règle : la retirer   la souris montre le héros et l'ennemi choisi à cet endroit\n" \
	+ "panneau à droite : vitesse, écrasement en profondeur, profondeur du sol en mètres   Tab : marcher pour essayer   Ctrl+Z / Ctrl+S"

var ed  # EditeurZones
var panneau: PanelContainer
var champ_vitesse: SpinBox
var champ_compression: SpinBox
var champ_minimum: SpinBox
var choix_ennemi: OptionButton
var infos: Label
var sortes: Array = []
## Point glissé : ["pied" | "tete", index] ou [].
var glisse: Array = []
var _maj := false
static var _cadres := {}


func _init(editeur) -> void:
	ed = editeur
	sortes = DonneesEnnemis.SORTES.duplicate()
	panneau = ed._panneau(COULEUR)
	panneau.custom_minimum_size = Vector2(232, 0)
	panneau.position.x = 960 - 232 - 8
	var boite := VBoxContainer.new()
	panneau.add_child(boite)
	var titre := Label.new()
	titre.text = "Perspective de la salle"
	titre.add_theme_color_override("font_color", COULEUR)
	boite.add_child(titre)
	champ_vitesse = _champ(boite, "Vitesse du héros", 0.3, 5.0, 0.05, "vitesse",
		"Hauteurs de héros par seconde en courant (× %s en marchant), de près." % U.g(SallePeinte.VITESSE_MARCHE))
	champ_compression = _champ(boite, "Vitesse en profondeur, de près", 0.1, 2.0, 0.05, "compression_profondeur",
		"Part de la vitesse gardée quand le héros va vers le fond ou revient, au premier plan (1 = aussi vite qu'en largeur).")
	champ_minimum = _champ(boite, "Vitesse en profondeur, au fond (min.)", 0.05, 1.0, 0.05, "compression_min",
		"Plancher de la vitesse en profondeur au fond, en part de celle de près. Plus haut : le héros traverse plus vite le fond de la salle.")
	boite.add_child(ed._petite_etiquette("Silhouette d'ennemi à la souris :"))
	choix_ennemi = OptionButton.new()
	choix_ennemi.focus_mode = Control.FOCUS_NONE
	choix_ennemi.add_theme_font_size_override("font_size", 12)
	for s in sortes:
		choix_ennemi.add_item(DonneesEnnemis.NOMS[s])
	boite.add_child(choix_ennemi)
	infos = ed._petite_etiquette("")
	infos.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	infos.custom_minimum_size = Vector2(214, 0)
	boite.add_child(infos)
	var bouton := Button.new()
	bouton.text = "Revenir à la perspective enregistrée"
	bouton.focus_mode = Control.FOCUS_NONE
	bouton.add_theme_font_size_override("font_size", 12)
	bouton.pressed.connect(revenir)
	boite.add_child(bouton)


func _champ(boite: VBoxContainer, titre: String, mini: float, maxi: float, pas: float, cle: String, aide: String) -> SpinBox:
	var h := HBoxContainer.new()
	var l: Label = ed._petite_etiquette(titre)
	l.custom_minimum_size = Vector2(132, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.tooltip_text = aide
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(l)
	var s := SpinBox.new()
	s.min_value = mini
	s.max_value = maxi
	s.step = pas
	s.focus_mode = Control.FOCUS_NONE
	s.get_line_edit().focus_mode = Control.FOCUS_CLICK
	s.custom_minimum_size = Vector2(70, 0)
	s.tooltip_text = aide
	s.value_changed.connect(func(v): regler(cle, v))
	h.add_child(s)
	boite.add_child(h)
	return s


func persp() -> Dictionary:
	return ed.salle.donnees["perspective"]


func table() -> Array:
	var p := persp()
	if not (p.get("table_hauteur") is Array) or p["table_hauteur"].size() < 2:
		# Sans table : deux points d'après l'horizon (même hauteur qu'avant)
		p["table_hauteur"] = [[300, int(ed.salle.hauteur(300.0))], [511, int(ed.salle.hauteur(511.0))]]
	return p["table_hauteur"]


## Réglage d'un champ du panneau.
func regler(cle: String, v: float) -> void:
	if _maj:
		return
	ed._memoriser()
	persp()[cle] = snappedf(v, 0.01)
	ed.perspective_modifiee = true
	ed._change()


## Remet le panneau d'après la perspective de la salle.
func maj_panneau() -> void:
	_maj = true
	var p := persp()
	champ_vitesse.value = float(p.get("vitesse", 1.8))
	champ_compression.value = float(p.get("compression_profondeur", 0.6))
	champ_minimum.value = float(p.get("compression_min", SallePeinte.COMPRESSION_MIN))
	_maj = false


func revenir() -> void:
	ed._memoriser()
	ed.salle.donnees["perspective"] = ed.perspective_enregistree.duplicate(true)
	ed.perspective_modifiee = false
	glisse = []
	maj_panneau()
	ed._change()
	ed.message = "Perspective remise comme à l'enregistrement"


# ---------------------------------------------------------------------------
# Souris
# ---------------------------------------------------------------------------

## Règle sous la souris : ["pied" | "tete", index] ou [].
func prise(m: Vector2) -> Array:
	var t := table()
	var meilleur: Array = []
	var d_min: float = ed.PRISE / ed.echelle()
	for i in t.size():
		var pied := Vector2(X_REGLES, float(t[i][0]))
		var tete := pied - Vector2(0, float(t[i][1]))
		for paire in [["tete", tete], ["pied", pied]]:
			var d: float = m.distance_to(paire[1])
			if d < d_min:
				d_min = d
				meilleur = [paire[0], i]
	return meilleur


func bouton(ev: InputEventMouseButton, m: Vector2) -> void:
	if ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		var p := prise(m)
		ed._memoriser()
		if p.is_empty():
			p = ajouter_point(m.y)
		glisse = p
	elif ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		if not glisse.is_empty():
			glisse = []
			ed.perspective_modifiee = true
			ed._change()
	elif ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
		var p := prise(m)
		if p.is_empty():
			return
		if table().size() <= 2:
			ed.message = "Il faut au moins deux règles"
			return
		ed._memoriser()
		table().remove_at(int(p[1]))
		ed.perspective_modifiee = true
		ed._change()
		ed.message = "Règle retirée"


## Ajoute une règle à la profondeur ``y`` (taille actuelle du héros à cet endroit) : ["tete", index].
func ajouter_point(y: float) -> Array:
	var t := table()
	y = clampf(roundf(y), 0.0, 511.0)
	for i in t.size():
		if absf(float(t[i][0]) - y) < ECART_MIN:
			return ["tete", i]
	t.append([int(y), int(round(ed.salle.hauteur(y)))])
	t.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	ed.perspective_modifiee = true
	ed.message = "Règle ajoutée à y = %d : glissez sa tête pour la taille du héros" % int(y)
	for i in t.size():
		if int(t[i][0]) == int(y):
			return ["tete", i]
	return []


func mouvement(m: Vector2) -> void:
	if glisse.is_empty():
		return
	var t := table()
	var i := int(glisse[1])
	if i >= t.size():
		glisse = []
		return
	if glisse[0] == "pied":
		var bas := float(t[i - 1][0]) + ECART_MIN if i > 0 else 0.0
		var haut := float(t[i + 1][0]) - ECART_MIN if i < t.size() - 1 else 511.0
		t[i][0] = int(clampf(roundf(m.y), bas, haut))
	else:
		t[i][1] = int(clampf(roundf(float(t[i][0]) - m.y), 4.0, 900.0))


# ---------------------------------------------------------------------------
# Mesures
# ---------------------------------------------------------------------------

## Bornes du sol (polygones « marche ») : Rect2 en pixels de l'image.
func bornes_sol() -> Rect2:
	var r := Rect2()
	var premier := true
	for poly in ed.salle.donnees.get("marche", []):
		for p in poly:
			if premier:
				r = Rect2(p, Vector2.ZERO)
				premier = false
			else:
				r = r.expand(p)
	return r if not premier else Rect2(0, 300, 960, 211)


## Profondeur du sol (en hauteurs de héros) et temps pour la parcourir en marchant, du bas au haut du sol :
## [profondeur, secondes en marchant, secondes en courant].
func traversee() -> Array:
	var r := bornes_sol()
	var salle: SallePeinte = ed.salle
	var v := float(persp().get("vitesse", 1.8))
	var profondeur := 0.0
	var temps := 0.0
	var y := r.position.y
	while y < r.end.y:
		var h := maxf(1.0, salle.hauteur(y))
		var c := maxf(0.01, salle.compression(y))
		profondeur += 1.0 / (h * c)  # 1 pixel d'écran vers le fond = 1 / (h × c) hauteurs de héros
		temps += 1.0 / (v * h * c)
		y += 1.0
	return [profondeur, temps / SallePeinte.VITESSE_MARCHE, temps]


func maj_infos() -> void:
	var r := bornes_sol()
	var salle: SallePeinte = ed.salle
	var pres := salle.hauteur(r.end.y)
	var fond := salle.hauteur(r.position.y)
	var tr := traversee()
	var largeur_m := r.size.x / maxf(1.0, pres) * TAILLE_HEROS_M
	infos.text = "Héros : %d px au premier plan, %d px au fond du sol (%d %%).\n" % [int(pres), int(fond), int(round(100.0 * fond / maxf(1.0, pres)))] \
		+ "Sol : %s m de large devant, %s m de profondeur (héros = %s m).\n" % [_m(largeur_m), _m(tr[0] * TAILLE_HEROS_M), U.g(TAILLE_HEROS_M).replace(".", ",")] \
		+ "Du bas au fond du sol : %s s en marchant, %s s en courant." % [_m(tr[1]), _m(tr[2])]


static func _m(x: float) -> String:
	return U.g(snappedf(x, 0.1)).replace(".", ",")


# ---------------------------------------------------------------------------
# Dessin (dans le calque de l'éditeur, en pixels de l'image)
# ---------------------------------------------------------------------------

func dessiner(ci: Node2D, e: float) -> void:
	var salle: SallePeinte = ed.salle
	var police := ThemeDB.fallback_font
	var t := table()
	var r := bornes_sol()
	var pres := maxf(1.0, salle.hauteur(511.0))
	# Rangée de héros du bas au haut du sol, au milieu
	var tex: Texture2D = salle.heros.texture
	var n := 6
	for k in n:
		var y := lerpf(r.end.y, r.position.y, float(k) / float(n - 1))
		var x := r.position.x + r.size.x * (0.12 + 0.76 * float(k) / float(n - 1))
		_silhouette_heros(ci, tex, Vector2(x, y), Color(1, 1, 1, 0.28))
	# Règles de la table
	for i in t.size():
		var y := float(t[i][0])
		var h := float(t[i][1])
		var actif: bool = not glisse.is_empty() and int(glisse[1]) == i
		var col := Color(1, 0.75, 0.3) if actif else COULEUR
		ci.draw_line(Vector2(0, y), Vector2(960, y), Color(col, 0.35), 1.0 * e)
		ci.draw_line(Vector2(X_REGLES, y), Vector2(X_REGLES, y - h), col, 3.0 * e)
		ci.draw_circle(Vector2(X_REGLES, y), 5.0 * e, Color.WHITE)
		ci.draw_circle(Vector2(X_REGLES, y), 3.5 * e, col)
		var tete := PackedVector2Array([Vector2(X_REGLES, y - h - 7 * e), Vector2(X_REGLES - 6 * e, y - h + 3 * e),
			Vector2(X_REGLES + 6 * e, y - h + 3 * e)])
		ci.draw_colored_polygon(tete, Color(1, 0.6, 0.2))
		var texte := "y %d · %d px (%d %%)" % [int(y), int(h), int(round(100.0 * h / pres))]
		ci.draw_set_transform(Vector2(X_REGLES + 10 * e, y - 3 * e), 0, Vector2(e, e))
		ci.draw_string_outline(police, Vector2.ZERO, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color.BLACK)
		ci.draw_string(police, Vector2.ZERO, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
		ci.draw_set_transform(Vector2.ZERO)
	# À la souris : le héros et l'ennemi choisi, à leur taille
	var m: Vector2 = ed._borne(ed.souris())
	if glisse.is_empty() and m.x > X_REGLES + 40:
		_silhouette_heros(ci, tex, m, Color(1, 1, 1, 0.65))
		var sorte := String(sortes[maxi(0, choix_ennemi.selected)])
		var hh := salle.hauteur(m.y)
		_silhouette_ennemi(ci, sorte, m + Vector2(hh * 0.45, 0), hh * PresencesSalle.TAILLE_GOBELIN * DonneesEnnemis.taille_de(sorte))
		var texte := "héros %d px · %s" % [int(hh), DonneesEnnemis.NOMS[sorte]]
		ci.draw_set_transform(m + Vector2(-80 * e, 14 * e), 0, Vector2(e, e))
		ci.draw_string_outline(police, Vector2.ZERO, texte, HORIZONTAL_ALIGNMENT_CENTER, 160, 12, 4, Color.BLACK)
		ci.draw_string(police, Vector2.ZERO, texte, HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color.WHITE)
		ci.draw_set_transform(Vector2.ZERO)


## Héros (son image actuelle) aux pieds en ``pieds``, à la taille de la perspective.
func _silhouette_heros(ci: Node2D, tex: Texture2D, pieds: Vector2, teinte: Color) -> void:
	if tex == null:
		return
	var salle: SallePeinte = ed.salle
	var s: float = salle.hauteur(pieds.y) / SallePeinte.HAUTEUR_PERSO
	var rect: Rect2 = salle.heros.get_rect()
	ci.draw_texture_rect(tex, Rect2(pieds + rect.position * s, rect.size * s), false, teinte)


## Ennemi (son image fixe) aux pieds en ``pieds``, de ``hauteur`` pixels visibles.
func _silhouette_ennemi(ci: Node2D, sorte: String, pieds: Vector2, hauteur: float) -> void:
	var nom := ""
	if Creatures.est_creature(sorte):
		nom = String(Creatures.SORTES[sorte]["image"])
	else:
		nom = String(Ennemis.IMAGES_GOBELINS_PAR_SOUS_CLASSE.get(sorte, ["gobelin_defaut.png"])[0])
	var chemin := "res://images/gobelins/" + nom
	if not ResourceLoader.exists(chemin):
		ci.draw_rect(Rect2(pieds - Vector2(hauteur * 0.2, hauteur), Vector2(hauteur * 0.4, hauteur)), Color(1, 0.4, 0.45, 0.5))
		return
	var tex: Texture2D = load(chemin)
	if not _cadres.has(chemin):
		_cadres[chemin] = tex.get_image().get_used_rect()
	var cadre: Rect2 = _cadres[chemin]
	var s := hauteur / maxf(1.0, cadre.size.y)
	var haut_gauche := pieds - Vector2(cadre.size.x * s / 2.0, cadre.size.y * s)
	ci.draw_texture_rect_region(tex, Rect2(haut_gauche, cadre.size * s), cadre, Color(1, 1, 1, 0.7))
