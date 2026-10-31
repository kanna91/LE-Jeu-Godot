class_name Manette
extends RefCounted
## Prise en charge de la manette dans tous les écrans (manette.py).
##
## Les entrées de la manette sont traduites en événements souris/clavier :
## A = clic gauche, B = Échap, X = clic droit, Y = I, LB/RB = molette,
## Back = Tab, Start = C. Navigation par zones : chaque écran déclare ses
## éléments (Ecran.definir_zones) ; le stick et la croix font sauter la
## sélection (cadre jaune) d'une zone à la voisine (cône de 45° prioritaire),
## A clique au centre de la zone. Sans zone, le stick déplace un curseur libre.

const ZONE_MORTE := 0.25
const VITESSE_CURSEUR := 700.0
const DELAI_RETOUR_SOURIS := 300
const SEUIL_STICK_ZONES := 0.6
const DELAI_PREMIERE_REPETITION := 350
const DELAI_REPETITION := 180
const COULEUR_FOCUS := Color8(255, 215, 0)

static var mode_manette := false
static var pos := Vector2(480, 270)
static var focus = null
static var derniere_action := 0
static var stick_direction = null
static var stick_prochain_saut := 0


static func _ms() -> int:
	return Time.get_ticks_msec()


static func _passer_en_mode_manette(ecran) -> bool:
	derniere_action = _ms()
	if mode_manette:
		return false
	mode_manette = true
	pos = ecran.get_global_mouse_position()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_synchroniser(ecran)
	return true


static func _passer_en_mode_souris() -> void:
	if mode_manette:
		mode_manette = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


static func _rect_focus(ecran):
	for z in ecran.zones:
		if z[0] == focus:
			return z[1]
	return null


## Garantit que la sélection désigne une zone existante (défaut, sinon la plus proche).
static func _synchroniser(ecran) -> void:
	if ecran.zones.is_empty():
		focus = null
		return
	var r = _rect_focus(ecran)
	if r == null and ecran.zones_defaut != null:
		focus = ecran.zones_defaut
		r = _rect_focus(ecran)
	if r == null:
		var meilleure = null
		var distance := INF
		for z in ecran.zones:
			var d: float = (z[1].get_center() - pos).length_squared()
			if d < distance:
				distance = d
				meilleure = z
		focus = meilleure[0]
		r = meilleure[1]
	if mode_manette:
		pos = r.get_center()


static func _deplacer_focus(ecran, dx: int, dy: int) -> void:
	_synchroniser(ecran)
	var depart = _rect_focus(ecran)
	if depart == null:
		return
	var c: Vector2 = depart.get_center()
	var meilleure = null
	var meilleur_score = null
	for z in ecran.zones:
		if z[0] == focus:
			continue
		var e: Vector2 = z[1].get_center() - c
		var principal := e.x * dx + e.y * dy
		var lateral := absf(e.x * dy) + absf(e.y * dx)
		if principal <= 0:
			continue
		var score := [1 if lateral > principal else 0, principal + 2 * lateral]
		if meilleur_score == null or score[0] < meilleur_score[0] or (score[0] == meilleur_score[0] and score[1] < meilleur_score[1]):
			meilleure = z[0]
			meilleur_score = score
	if meilleure != null:
		focus = meilleure
		pos = _rect_focus(ecran).get_center()


## Clé de la zone sélectionnée à la manette (pour faire suivre un défilement), ou null.
static func cle_selectionnee(ecran):
	if mode_manette and not ecran.zones.is_empty():
		return focus
	return null


## Position du pointeur : le curseur virtuel en mode manette, sinon la souris.
static func position_souris(ecran) -> Vector2:
	if mode_manette:
		return pos
	return ecran.get_global_mouse_position()


## Traduit un événement en événements du jeu : {"type": "clic"/"touche"/"molette", ...}.
static func traduire(ecran, event: InputEvent) -> Array:
	var sortie := []
	if event is InputEventMouseMotion:
		if mode_manette and _ms() - derniere_action > DELAI_RETOUR_SOURIS:
			if event.relative.length() > 2:
				_passer_en_mode_souris()
		if not mode_manette and ecran.get("glisse_souris") == true:  # vue déplaçable (sphérier)
			sortie.append({"type": "mouvement", "pos": ecran.get_global_mouse_position(), "rel": event.relative})
		return sortie
	if event is InputEventMouseButton and not event.pressed:
		if ecran.get("glisse_souris") == true and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			sortie.append({"type": "relache"})
		return sortie
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
		if ecran.get("glisse_souris") == true:
			sortie.append({"type": "clic", "pos": ecran.get_global_mouse_position(), "bouton": 2, "double": false})
		return sortie
	if event is InputEventMouseButton and event.pressed:
		if mode_manette and _ms() - derniere_action > DELAI_RETOUR_SOURIS:
			_passer_en_mode_souris()
		var p: Vector2 = ecran.get_global_mouse_position()
		if event.button_index == MOUSE_BUTTON_LEFT:
			sortie.append({"type": "clic", "pos": p, "bouton": 1, "double": event.double_click})
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			sortie.append({"type": "clic", "pos": p, "bouton": 3, "double": false})
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			sortie.append({"type": "molette", "sens": 1})
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			sortie.append({"type": "molette", "sens": -1})
		return sortie
	if event is InputEventKey and event.pressed:
		sortie.append({"type": "touche", "touche": event.keycode, "repete": event.echo})
		return sortie
	if event is InputEventJoypadButton and event.pressed:
		var vient_d_activer := _passer_en_mode_manette(ecran)
		var b: int = event.button_index
		if b in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
			var touche: int = {JOY_BUTTON_DPAD_UP: KEY_UP, JOY_BUTTON_DPAD_DOWN: KEY_DOWN,
				JOY_BUTTON_DPAD_LEFT: KEY_LEFT, JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT}[b]
			var direction: Vector2i = {JOY_BUTTON_DPAD_UP: Vector2i(0, -1), JOY_BUTTON_DPAD_DOWN: Vector2i(0, 1),
				JOY_BUTTON_DPAD_LEFT: Vector2i(-1, 0), JOY_BUTTON_DPAD_RIGHT: Vector2i(1, 0)}[b]
			if not ecran.zones.is_empty() and not ecran.croix_libre:
				if not vient_d_activer:
					_deplacer_focus(ecran, direction.x, direction.y)
			else:
				sortie.append({"type": "touche", "touche": touche, "repete": false})
			return sortie
		if b in [JOY_BUTTON_A, JOY_BUTTON_X] and vient_d_activer and not ecran.zones.is_empty():
			return sortie
		if b == JOY_BUTTON_A:
			sortie.append({"type": "clic", "pos": pos, "bouton": 1, "double": false})
		elif b == JOY_BUTTON_X:
			sortie.append({"type": "clic", "pos": pos, "bouton": 3, "double": false})
		elif b == JOY_BUTTON_LEFT_SHOULDER:
			sortie.append({"type": "molette", "sens": 1})
		elif b == JOY_BUTTON_RIGHT_SHOULDER:
			sortie.append({"type": "molette", "sens": -1})
		elif b == JOY_BUTTON_B:
			sortie.append({"type": "touche", "touche": KEY_ESCAPE, "repete": false})
		elif b == JOY_BUTTON_Y:
			sortie.append({"type": "touche", "touche": KEY_I, "repete": false})
		elif b == JOY_BUTTON_BACK:
			sortie.append({"type": "touche", "touche": KEY_TAB, "repete": false})
		elif b == JOY_BUTTON_START:
			sortie.append({"type": "touche", "touche": KEY_C, "repete": false})
	return sortie


## Stick gauche : curseur libre, ou sauts de zone en zone (à appeler à chaque image).
static func stick(ecran, delta: float) -> void:
	var d := Vector2.ZERO
	# Écran où le stick gauche fait marcher le héros (exploration) : le stick droit choisit les zones
	var droit: bool = ecran.get("stick_heros") == true
	for appareil in Input.get_connected_joypads():
		var ax := Input.get_joy_axis(appareil, JOY_AXIS_RIGHT_X if droit else JOY_AXIS_LEFT_X)
		var ay := Input.get_joy_axis(appareil, JOY_AXIS_RIGHT_Y if droit else JOY_AXIS_LEFT_Y)
		if absf(ax) > ZONE_MORTE:
			d.x += ax
		if absf(ay) > ZONE_MORTE:
			d.y += ay
	var maintenant := _ms()
	if not ecran.zones.is_empty():
		if maxf(absf(d.x), absf(d.y)) < SEUIL_STICK_ZONES:
			stick_direction = null
			return
		var direction := Vector2i(1 if d.x > 0 else -1, 0) if absf(d.x) >= absf(d.y) else Vector2i(0, 1 if d.y > 0 else -1)
		if _passer_en_mode_manette(ecran):
			stick_direction = direction
			stick_prochain_saut = maintenant + DELAI_PREMIERE_REPETITION
			return
		if direction != stick_direction:
			stick_direction = direction
			stick_prochain_saut = maintenant + DELAI_PREMIERE_REPETITION
			_deplacer_focus(ecran, direction.x, direction.y)
		elif maintenant >= stick_prochain_saut:
			stick_prochain_saut = maintenant + DELAI_REPETITION
			_deplacer_focus(ecran, direction.x, direction.y)
		return
	if d == Vector2.ZERO:
		return
	_passer_en_mode_manette(ecran)
	delta = minf(delta, 0.1)
	pos = Vector2(clampf(pos.x + d.x * VITESSE_CURSEUR * delta, 0, Ui.LARGEUR - 1),
		clampf(pos.y + d.y * VITESSE_CURSEUR * delta, 0, Ui.HAUTEUR - 1))


## Cadre de la zone sélectionnée, ou curseur virtuel (à la fin du dessin de l'écran).
static func dessiner(ci: CanvasItem, ecran) -> void:
	if not mode_manette:
		return
	if not ecran.zones.is_empty():
		_synchroniser(ecran)
		var r = _rect_focus(ecran)
		if r != null:
			Ui.rect(ci, r.grow(4), COULEUR_FOCUS, 3, 6)
	else:
		var x := pos.x
		var y := pos.y
		var pointe := PackedVector2Array([Vector2(x, y), Vector2(x, y + 18), Vector2(x + 5, y + 14), Vector2(x + 9, y + 21),
			Vector2(x + 12, y + 20), Vector2(x + 8, y + 13), Vector2(x + 14, y + 13)])
		Ui.polygone(ci, pointe, Color.WHITE)
		Ui.polygone(ci, pointe, Color.BLACK, 1)


static func memoriser_selection() -> Array:
	return [focus, pos]


static func restaurer_selection(selection: Array) -> void:
	focus = selection[0]
	if mode_manette:
		pos = selection[1]
