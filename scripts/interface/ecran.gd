class_name Ecran
extends Control
## Écran du jeu (équivalent d'une boucle ``afficher_menu_*`` de pygame).
##
## Trois couches dessinées à chaque image : le fond (image et particules de feu,
## animations.animer_particules), le contenu (_dessiner) puis les effets. Les
## entrées (souris, clavier, manette) arrivent sous forme d'événements simples
## à _evenement : {"type": "clic", "pos", "bouton"}, {"type": "touche", "touche"},
## {"type": "molette", "sens"}. Un gestionnaire peut attendre un sous-écran
## (``await Ecrans.xxx``) : l'écran ignore alors les autres entrées.

signal termine(resultat)

## Image de fond (chemin dans images/), vide pour aucune.
var fond_ecran := ""
## Les foyers du fond émettent des particules.
var particules_fond := true
## Zones de la navigation à la manette : [[clé, Rect2], ...] (déclarées à chaque image).
var zones: Array = []
var zones_defaut = null
var croix_libre := false

var _ferme := false
var _occupe := false
var couche_fond: Control
var couche_particules: CoucheParticules
var couche_contenu: Control
var couche_lumiere: Control
var couche_dessus: Control


func _init() -> void:
	size = Vector2(Ui.LARGEUR, Ui.HAUTEUR)
	mouse_filter = Control.MOUSE_FILTER_STOP
	couche_fond = _couche(_dessiner_fond)
	couche_particules = CoucheParticules.new()
	add_child(couche_particules)
	couche_contenu = _couche(_dessiner)
	couche_lumiere = _couche(_dessiner_lumiere)
	var materiau := CanvasItemMaterial.new()
	materiau.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	couche_lumiere.material = materiau
	couche_dessus = _couche(_dessiner_haut)


func _couche(fonction: Callable) -> Control:
	var c := Control.new()
	c.size = Vector2(Ui.LARGEUR, Ui.HAUTEUR)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func(): fonction.call(c))
	add_child(c)
	return c


## Couche découpée à un rectangle (``set_clip`` de pygame), dessinée juste au-dessus du contenu.
## ``fonction(ci)`` dessine en coordonnées de l'écran.
func couche_decoupee(zone: Rect2, fonction: Callable) -> Control:
	var c := Control.new()
	c.position = zone.position
	c.size = zone.size
	c.clip_contents = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		c.draw_set_transform(-zone.position)
		fonction.call(c))
	couche_contenu.add_child(c)
	return c


func _process(delta: float) -> void:
	Manette.stick(self, delta)
	couche_particules.fond = fond_ecran if particules_fond else ""
	couche_fond.queue_redraw()
	couche_particules.queue_redraw()
	couche_contenu.queue_redraw()
	for enfant in couche_contenu.get_children():
		enfant.queue_redraw()
	couche_lumiere.queue_redraw()
	couche_dessus.queue_redraw()
	_mise_a_jour(delta)


func _input(event: InputEvent) -> void:
	if _ferme or not is_visible_in_tree():
		return
	var evenements := Manette.traduire(self, event)
	if evenements.is_empty():
		return
	get_viewport().set_input_as_handled()
	if _occupe:
		return
	_traiter(evenements)


func _traiter(evenements: Array) -> void:
	_occupe = true
	for ev in evenements:
		if _ferme:
			break
		await _evenement(ev)
	_occupe = false


## Ferme l'écran ; ``await`` l'ouverture renvoie ``resultat``.
func fermer(resultat = null) -> void:
	if not _ferme:
		_ferme = true
		termine.emit(resultat)


## Pointeur (curseur virtuel à la manette).
func souris() -> Vector2:
	return Manette.position_souris(self)


## Déclare les zones de la navigation à la manette pour cette image.
func definir_zones(liste: Array, defaut = null, croix := false) -> void:
	zones = liste
	zones_defaut = defaut
	croix_libre = croix


func _dessiner_fond(ci: Control) -> void:
	if fond_ecran != "":
		Ui.fond(ci, fond_ecran)


func _dessiner_haut(ci: Control) -> void:
	_dessiner_dessus(ci)
	Manette.dessiner(ci, self)


# --- À redéfinir --------------------------------------------------------------

## Dessin de l'écran (au-dessus du fond et des particules).
func _dessiner(_ci: Control) -> void:
	pass


## Dessin en mélange additif (lueurs), au-dessus du contenu.
func _dessiner_lumiere(_ci: Control) -> void:
	pass


## Dernière couche (au-dessus des lueurs).
func _dessiner_dessus(_ci: Control) -> void:
	pass


## Mise à jour à chaque image.
func _mise_a_jour(_delta: float) -> void:
	pass


## Événement d'entrée (peut attendre un sous-écran).
func _evenement(_ev: Dictionary) -> void:
	pass
