extends Control
## Éditeur des zones des salles peintes, dans le moteur du jeu (même salle, même héros, mêmes règles).
##
## Demande de l'utilisateur (2026-10-27) : pouvoir définir soi-même les zones de chaque salle. Lancer
## ``editeur_zones.bat`` (ou ``Godot --path . res://scenes/outils/editeur_zones.tscn [-- <salle>]``).
##
## Couches : 1 sol où l'on marche (vert), 2 obstacles (rouge), 3 premier plan qui passe devant le héros (bleu),
## 4 sorties (jaune : on peut seulement déplacer leurs points, leur nombre et leur ordre comptent pour le plan).
## Enregistrer (Ctrl+S) écrit ``donnees/salles_peintes/<id>.json`` et ``outils/zones_manuelles/<id>.json`` ;
## ce second fichier est relu par les importeurs et le détourage automatique, qui ne l'écrasent plus.

const COUCHES := ["marche", "obstacles", "premier_plan", "sorties"]
const NOMS := {"marche": "Sol (marche)", "obstacles": "Obstacles", "premier_plan": "Premier plan", "sorties": "Sorties"}
const COULEURS := {"marche": Color(0.25, 1, 0.35), "obstacles": Color(1, 0.25, 0.2),
	"premier_plan": Color(0.3, 0.6, 1), "sorties": Color(1, 0.9, 0.15)}
## Distance (pixels de l'écran) pour attraper un point ou une arête.
const PRISE := 9.0
const ZOOM_MAX := 6.0

var salle: SallePeinte
var calque: Calque
var texte: Label
var aide: Label
var salles: Array = []
var numero := 0
var couche := "marche"
var edition := true
var voir_zones := true
## Héros visible pendant l'édition (H) ; caché par défaut pour ne pas masquer la salle.
var heros_en_edition := false
var trace := PackedVector2Array()
## Point déplacé : [couche, polygone, point] (vide sinon).
var glisse: Array = []
var deplacement := false  # vue déplacée au clic du milieu
var annulations: Array = []
var modifie := false
var message := ""
var confirmer_changement := 0
var echelle_base := Vector2.ONE
var position_base := Vector2.ZERO
var zoom := 1.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color8(20, 18, 26))
	salles = SallePeinte.salles_disponibles()
	var demande := OS.get_cmdline_user_args()
	var derniere := FileAccess.get_file_as_string("user://editeur_zones_derniere_salle.txt").strip_edges()
	if derniere in salles:  # rouvre la dernière salle travaillée
		numero = salles.find(derniere)
	for a in demande:
		if a in salles:
			numero = salles.find(a)
	salle = SallePeinte.new()
	add_child(salle)
	calque = Calque.new()
	calque.editeur = self
	texte = _etiquette(Vector2(12, 8), 15)
	aide = _etiquette(Vector2(12, 484), 12)
	aide.text = "Tab : éditer / marcher   1-4 : couche   clic : ajouter un point (Entrée ou clic sur le 1er point : fermer)\n" \
		+ "glisser un point : le déplacer   Maj+clic sur un bord : nouveau point   clic droit : retirer point / zone\n" \
		+ "molette : zoom   clic milieu : déplacer la vue   0 : vue entière   Ctrl+Z : annuler   Ctrl+S : enregistrer   " \
		+ "Page préc./suiv. : salle   H : héros visible   F2 : zones visibles en marchant"
	_charger()
	if "--capture" in demande:  # vérification hors écran
		for _i in 20:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://tests/captures/62_editeur_zones.png")
		get_tree().quit()


func _etiquette(p: Vector2, taille: int) -> Label:
	var l := Label.new()
	l.position = p
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.z_index = 100
	add_child(l)
	return l


func _charger() -> void:
	var id: String = salles[numero]
	var f := FileAccess.open("user://editeur_zones_derniere_salle.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(id)
		f.close()
	salle.charger(id, -1, false)
	salle.murer(range(salle.donnees["sorties"].size()))
	echelle_base = salle.monde.scale
	position_base = salle.monde.position
	zoom = 1.0
	if calque.get_parent() != null:
		calque.get_parent().remove_child(calque)
	calque.z_index = 50
	salle.monde.add_child(calque)
	trace.clear()
	glisse = []
	annulations.clear()
	modifie = false
	confirmer_changement = 0
	message = "Salle %s chargée" % id
	if salle.masque_piliers != null:
		message += " — premier plan au pixel (masque) : les zones bleues ne changent pas l'affichage, seulement la vue des ennemis"
	_appliquer_mode()


func _appliquer_mode() -> void:
	salle.actif = not edition
	salle.heros.visible = heros_en_edition or not edition
	if not edition:
		trace.clear()
		glisse = []
		_vue(1.0, Vector2.ZERO)


func souris() -> Vector2:
	return salle.monde.get_local_mouse_position()


func echelle() -> float:
	return salle.monde.scale.x


# ---------------------------------------------------------------------------
# Entrées
# ---------------------------------------------------------------------------

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		_touche(ev)
		return
	if not edition:
		return
	if ev is InputEventMouseButton:
		_bouton(ev)
	elif ev is InputEventMouseMotion:
		if not glisse.is_empty():
			var poly: PackedVector2Array = salle.donnees[glisse[0]][glisse[1]]
			poly[glisse[2]] = _borne(souris())
			salle.donnees[glisse[0]][glisse[1]] = poly
		elif deplacement:
			salle.monde.position += ev.relative


func _touche(ev: InputEventKey) -> void:
	message = ""
	if ev.keycode != KEY_PAGEDOWN and ev.keycode != KEY_PAGEUP:
		confirmer_changement = 0
	if ev.ctrl_pressed and ev.keycode == KEY_S:
		_enregistrer()
		return
	if ev.ctrl_pressed and ev.keycode == KEY_Z:
		_annuler()
		return
	match ev.keycode:
		KEY_TAB:
			edition = not edition
			_appliquer_mode()
		KEY_F2:
			voir_zones = not voir_zones
		KEY_PAGEDOWN, KEY_PAGEUP:
			if modifie and confirmer_changement == 0:
				confirmer_changement = 1
				message = "Modifications non enregistrées : appuyer encore pour changer de salle sans enregistrer"
				return
			numero = posmod(numero + (1 if ev.keycode == KEY_PAGEDOWN else -1), salles.size())
			_charger()
		KEY_ESCAPE:
			trace.clear()
	if not edition:
		return
	match ev.keycode:
		KEY_1, KEY_KP_1, KEY_2, KEY_KP_2, KEY_3, KEY_KP_3, KEY_4, KEY_KP_4:
			var n := {KEY_1: 0, KEY_KP_1: 0, KEY_2: 1, KEY_KP_2: 1, KEY_3: 2, KEY_KP_3: 2, KEY_4: 3, KEY_KP_4: 3}
			couche = COUCHES[n[ev.keycode]]
			trace.clear()
		KEY_ENTER, KEY_KP_ENTER:
			_fermer_trace()
		KEY_0, KEY_KP_0:
			_vue(1.0, Vector2.ZERO)
		KEY_H:  # montrer ou cacher le héros pendant l'édition
			heros_en_edition = not heros_en_edition
			salle.heros.visible = heros_en_edition
		KEY_P:  # poser le héros sous la souris (et le montrer)
			heros_en_edition = true
			salle.heros.visible = true
			salle.heros.position = souris()


func _bouton(ev: InputEventMouseButton) -> void:
	var m := _borne(souris())
	if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
		_vue(zoom * 1.2, ev.position)
	elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
		_vue(zoom / 1.2, ev.position)
	elif ev.button_index == MOUSE_BUTTON_MIDDLE:
		deplacement = ev.pressed
	elif ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		if not trace.is_empty():
			if trace.size() >= 3 and m.distance_to(trace[0]) * echelle() < PRISE:
				_fermer_trace()
			else:
				trace.append(m)
			return
		var s := _point_proche(m)
		if not s.is_empty():
			_memoriser()
			glisse = s
			return
		if ev.shift_pressed:
			var a := _arete_proche(m)
			if not a.is_empty():
				_memoriser()
				var poly: PackedVector2Array = salle.donnees[couche][a[0]]
				poly.insert(a[1] + 1, m)
				salle.donnees[couche][a[0]] = poly
				glisse = [couche, a[0], a[1] + 1]
				return
		if couche == "sorties":
			message = "Sorties : on déplace seulement leurs points (Maj+clic sur un bord pour en ajouter un)"
			return
		trace.append(m)
	elif ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		if not glisse.is_empty():
			glisse = []
			_change()
	elif ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
		_clic_droit(m)


func _clic_droit(m: Vector2) -> void:
	if not trace.is_empty():
		trace.remove_at(trace.size() - 1)
		return
	var s := _point_proche(m)
	if not s.is_empty():
		var poly: PackedVector2Array = salle.donnees[s[0]][s[1]]
		if poly.size() > 3:
			_memoriser()
			poly.remove_at(s[2])
			salle.donnees[s[0]][s[1]] = poly
			_change()
		else:
			message = "Une zone garde au moins 3 points (clic droit dans la zone pour la retirer)"
		return
	if couche == "sorties":
		message = "Les sorties ne se retirent pas (leur nombre compte pour le plan du donjon)"
		return
	var polys: Array = salle.donnees[couche]
	for i in range(polys.size() - 1, -1, -1):
		if Geometry2D.is_point_in_polygon(m, polys[i]):
			_memoriser()
			polys.remove_at(i)
			_change()
			message = "Zone retirée (Ctrl+Z pour annuler)"
			return


func _fermer_trace() -> void:
	if trace.size() < 3:
		message = "Il faut au moins 3 points"
		return
	_memoriser()
	salle.donnees[couche].append(PackedVector2Array(trace))
	trace.clear()
	_change()


## Point de la couche active (ou des autres si rien dans la couche active) le plus proche de ``m``.
func _point_proche(m: Vector2) -> Array:
	var meilleur: Array = []
	var d_min := PRISE / echelle()
	var polys: Array = salle.donnees[couche]
	for i in polys.size():
		var poly: PackedVector2Array = polys[i]
		for j in poly.size():
			var d := poly[j].distance_to(m)
			if d < d_min:
				d_min = d
				meilleur = [couche, i, j]
	return meilleur


func _arete_proche(m: Vector2) -> Array:
	var meilleur: Array = []
	var d_min := PRISE / echelle()
	var polys: Array = salle.donnees[couche]
	for i in polys.size():
		var poly: PackedVector2Array = polys[i]
		for j in poly.size():
			var q := Geometry2D.get_closest_point_to_segment(m, poly[j], poly[(j + 1) % poly.size()])
			var d := q.distance_to(m)
			if d < d_min:
				d_min = d
				meilleur = [i, j]
	return meilleur


func _borne(p: Vector2) -> Vector2:
	var t := Vector2(salle.fond.get_size())
	return Vector2(clampf(roundf(p.x), 0, t.x), clampf(roundf(p.y), 0, t.y))


func _vue(z: float, centre_ecran: Vector2) -> void:
	var avant := zoom
	zoom = clampf(z, 1.0, ZOOM_MAX)
	if zoom == 1.0:
		salle.monde.scale = echelle_base
		salle.monde.position = position_base
		return
	# Le point sous la souris reste sous la souris
	var image := (centre_ecran - salle.monde.position) / salle.monde.scale
	salle.monde.scale = echelle_base * zoom
	salle.monde.position = centre_ecran - image * salle.monde.scale
	if avant == zoom:
		return


# ---------------------------------------------------------------------------
# Annuler, enregistrer
# ---------------------------------------------------------------------------

func _memoriser() -> void:
	var copie := {}
	for c in COUCHES:
		var polys := []
		for poly in salle.donnees[c]:
			polys.append(PackedVector2Array(poly))
		copie[c] = polys
	annulations.append(copie)
	if annulations.size() > 100:
		annulations.pop_front()


func _annuler() -> void:
	if annulations.is_empty():
		message = "Rien à annuler"
		return
	var copie: Dictionary = annulations.pop_back()
	for c in COUCHES:
		salle.donnees[c] = copie[c]
	glisse = []
	_change()


func _change() -> void:
	modifie = true
	salle._reconstruire_avant_plans()


static func _en_liste(polys: Array) -> Array:
	var res := []
	for poly in polys:
		var pts := []
		for p in poly:
			pts.append([int(roundf(p.x)), int(roundf(p.y))])
		res.append(pts)
	return res


## Nombres entiers écrits sans « .0 » (JSON de Godot lit tout en flottants ; les outils Python s'en servent d'indices).
static func _entiers(v):
	if v is float and v == floorf(v) and absf(v) < 1e15:
		return int(v)
	if v is Array:
		var a := []
		for x in v:
			a.append(_entiers(x))
		return a
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _entiers(v[k])
		return d
	return v


func _enregistrer() -> void:
	var id: String = salles[numero]
	var zones := {}
	for c in COUCHES:
		zones[c] = _en_liste(salle.donnees[c])
	var donnees := SallePeinte.lire_salle(id)
	for c in COUCHES:
		donnees[c] = zones[c]
	var f := FileAccess.open("res://donnees/salles_peintes/%s.json" % id, FileAccess.WRITE)
	if f == null:
		message = "ÉCHEC : impossible d'écrire donnees/salles_peintes/%s.json" % id
		return
	f.store_string(JSON.stringify(_entiers(donnees), " ", false, true))
	f.close()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://outils/zones_manuelles"))
	f = FileAccess.open("res://outils/zones_manuelles/%s.json" % id, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(zones, "", false))
		f.close()
	modifie = false
	message = "Enregistré : %s (le jeu et les importeurs utiliseront ces zones)" % id


# ---------------------------------------------------------------------------
# Affichage
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	var id: String = salles[numero] if not salles.is_empty() else "?"
	var lignes := ["%s%s  (%d/%d)   —   %s" % [id, " *" if modifie else "", numero + 1, salles.size(),
		("ÉDITION : couche %s" % NOMS[couche]) if edition else "MARCHE : on essaie la salle (Tab pour éditer)"]]
	if edition:
		var m := _borne(souris())
		lignes.append("souris : %d, %d   zoom ×%.1f" % [m.x, m.y, zoom])
	if message != "":
		lignes.append(message)
	texte.text = "\n".join(lignes)
	aide.visible = edition
	calque.visible = edition or voir_zones
	calque.queue_redraw()


class Calque extends Node2D:
	var editeur

	func _draw() -> void:
		var ed = editeur
		var e: float = 1.0 / ed.echelle()
		for c in COUCHES:
			var col: Color = COULEURS[c]
			var actif: bool = ed.edition and c == ed.couche
			for poly in ed.salle.donnees[c]:
				if poly.size() < 3:
					continue
				draw_colored_polygon(poly, Color(col, 0.30 if actif else 0.12))
				var ferme := PackedVector2Array(poly)
				ferme.append(poly[0])
				draw_polyline(ferme, col if actif else Color(col.darkened(0.3), 0.7), (2.0 if actif else 1.0) * e)
				if actif:
					for p in poly:
						draw_circle(p, 3.5 * e, Color.WHITE)
						draw_circle(p, 2.2 * e, col)
		if not ed.trace.is_empty():
			var col: Color = COULEURS[ed.couche]
			var pts := PackedVector2Array(ed.trace)
			if ed.edition:
				pts.append(ed._borne(ed.souris()))
			draw_polyline(pts, Color.WHITE, 2.0 * e)
			for p in ed.trace:
				draw_circle(p, 3.5 * e, col)
			draw_circle(ed.trace[0], 6.0 * e, Color.WHITE, false, 1.5 * e)
		if not ed.salle.heros.visible:
			return
		var pied: Vector2 = ed.salle.heros.position
		draw_circle(pied, ed.salle.hauteur(pied.y) * 0.1, Color(1, 1, 1, 0.8), false, 1.5 * e)
