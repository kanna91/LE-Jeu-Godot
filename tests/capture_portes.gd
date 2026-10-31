extends SceneTree
## Portes qui s'ouvrent dans les salles peintes (SallePeinte, ``portes_animees``).
##
## Pour chaque porte animée (salles porte 1 à 5, et la salle porte 2 en miroir) :
## - fermée, sa sortie arrête le héros (``libre`` faux) ;
## - le héros posé devant elle sans bouger : elle reste fermée (elle ne s'ouvre pas toute seule) ;
## - le héros marche vers elle (touche simulée) : elle s'ouvre, puis sa sortie laisse passer ;
## - captures 60 à 6x dans tests/captures/ : porte fermée, à mi-course, ouverte.
## Vérifie aussi qu'une porte condamnée ne s'ouvre pas et que la porte d'arrivée est ouverte d'emblée.
## Affiche « BILAN portes : 0 échec(s) » si tout est correct.
## À lancer dans une fenêtre hors écran (override.cfg, voir README).

var racine: Control
var echecs := 0
var numero := 60


func _initialize() -> void:
	racine = Control.new()
	racine.size = Vector2(960, 540)
	root.add_child(racine)
	lancer()


func attendre(images: int) -> void:
	for _i in images:
		await process_frame


func attendre_secondes(s: float) -> void:
	var fin := Time.get_ticks_msec() + int(s * 1000)
	while Time.get_ticks_msec() < fin:
		await process_frame


func capturer(nom: String) -> void:
	await attendre(2)
	root.get_viewport().get_texture().get_image().save_png("res://tests/captures/%d_%s.png" % [numero, nom])
	print("capture %d_%s" % [numero, nom])


func touche(code: int, appui: bool) -> void:
	var t := InputEventKey.new()
	t.keycode = code
	t.physical_keycode = code
	t.pressed = appui
	Input.parse_input_event(t)


func verifier(condition: bool, cas: String) -> void:
	if condition:
		print("ok ", cas)
	else:
		echecs += 1
		print("ÉCHEC ", cas)


## Le héros se pose juste devant la sortie de la porte, du côté de la salle.
func devant(salle: SallePeinte, i: int) -> Vector2:
	var c := salle.centre_sortie(i)
	for k in 120:
		var p := c + Vector2(0, 3 + k * 2)
		if salle.libre(p) and salle._sortie_sous(p) < 0:
			return p
	return c + Vector2(0, 20)


## Vrai si un point de la sortie ``i`` est franchissable (le centre peut être hors du sol praticable).
func franchissable(salle: SallePeinte, i: int) -> bool:
	var poly: PackedVector2Array = salle.donnees["sorties"][i]
	var r := Rect2(poly[0], Vector2.ZERO)
	for q in poly:
		r = r.expand(q)
	for x in range(int(r.position.x), int(r.end.x) + 1, 3):
		for y in range(int(r.position.y), int(r.end.y) + 1, 2):
			var q := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(q, poly) and salle.libre(q):
				return true
	return false


func essayer_porte(id: String, miroir: bool, index_porte: int) -> void:
	var salle := SallePeinte.new()
	racine.add_child(salle)
	salle.charger(id, -1, miroir)
	salle.definir_portes([], [])
	await attendre_secondes(1.0)  # vidéo et images de la porte chargées
	var porte: Dictionary = salle.portes[index_porte]
	var i := int(porte["spec"]["sortie"])
	var nom := "%s%s_%s" % [id, "_miroir" if miroir else "", porte["spec"]["nom"]]
	verifier(not franchissable(salle, i) and salle.porte_fermee(i), nom + " : fermée, la sortie arrête le héros")
	verifier(porte["pretes"], nom + " : images chargées en arrière-plan")
	salle.heros.position = devant(salle, i)
	salle.direction = "up"
	await attendre_secondes(1.5)
	verifier(porte["etat"] == "fermee", nom + " : héros immobile devant, elle reste fermée")
	await capturer(nom + "_fermee")
	# Le joueur marche vers la porte : elle s'ouvre (il peut la franchir dès ce moment)
	var franchie := [false]
	salle.sortie_atteinte.connect(func(j): franchie[0] = franchie[0] or j == i)
	touche(KEY_UP, true)
	var fin := Time.get_ticks_msec() + 3000
	while porte["etat"] == "fermee" and Time.get_ticks_msec() < fin:
		await process_frame
	touche(KEY_UP, false)
	verifier(porte["etat"] == "ouverture", nom + " : s'ouvre quand le héros marche vers elle")
	verifier(franchissable(salle, i) and not salle.porte_fermee(i), nom + " : on passe sans attendre la fin de l'ouverture")
	await attendre_secondes(1.2)
	await capturer(nom + "_mi_course")
	await attendre_secondes(2.0)
	verifier(porte["etat"] == "ouverte" and franchissable(salle, i) and not salle.porte_fermee(i), nom + " : ouverte, la sortie laisse passer")
	verifier(porte["images"].is_empty(), nom + " : images libérées une fois ouverte")
	await capturer(nom + "_ouverte")
	# En continuant de marcher vers elle, le héros la franchit (la sortie se déclenche), s'il ne l'a pas déjà fait
	for code in [KEY_UP, KEY_LEFT if salle.centre_sortie(i).x < salle.heros.position.x else KEY_RIGHT]:
		touche(code, true)
		fin = Time.get_ticks_msec() + 2000
		while not franchie[0] and Time.get_ticks_msec() < fin:
			await process_frame
		touche(code, false)
		if franchie[0]:
			break
	verifier(franchie[0], nom + " : le héros passe par la porte ouverte")
	numero += 1
	salle.queue_free()
	await attendre(2)


func lancer() -> void:
	var cas := [["porte1", false, 0], ["porte2", false, 0], ["porte2", false, 1], ["porte2", true, 0],
		["porte3", false, 0], ["porte4", false, 0], ["porte5", false, 0], ["porte5", false, 1]]
	for c in cas:
		await essayer_porte(c[0], c[1], c[2])
	# Porte condamnée : ne s'ouvre pas, sa sortie reste franchissable (message « porte condamnée »)
	var salle := SallePeinte.new()
	racine.add_child(salle)
	salle.charger("porte2", -1, false)
	salle.definir_portes([], [0])
	await attendre_secondes(0.5)
	salle.heros.position = devant(salle, 0)
	salle.actif = true
	touche(KEY_UP, true)
	await attendre_secondes(0.6)
	touche(KEY_UP, false)
	verifier(salle.portes[0]["etat"] == "fermee" and franchissable(salle, 0), "porte condamnée : reste fermée, pas de mur")
	salle.queue_free()
	await attendre(2)
	# Arrivée par la porte de gauche de la salle porte 2 : la porte du fond, voisine, ne s'ouvre pas
	salle = SallePeinte.new()
	racine.add_child(salle)
	salle.charger("porte2", 2, false)
	salle.definir_portes([2], [])
	await attendre_secondes(2.0)
	verifier(salle.portes[0]["etat"] == "fermee" and salle.portes[1]["etat"] == "ouverte",
		"arrivée par la porte de gauche : seule elle est ouverte, la porte du fond reste fermée")
	salle.queue_free()
	await attendre(2)
	# Arrivée par une porte : elle est déjà ouverte
	salle = SallePeinte.new()
	racine.add_child(salle)
	salle.charger("porte5", 0, false)
	salle.definir_portes([0], [])
	verifier(salle.portes[0]["etat"] == "ouverte" and salle.portes[0]["sprite"].visible, "porte d'arrivée ouverte d'emblée")
	verifier(salle.portes_ouvertes() == [0], "portes_ouvertes() = [0]")
	await capturer("porte5_arrivee")
	salle.queue_free()
	await attendre(2)
	print("BILAN portes : %d échec(s)" % echecs)
	quit(1 if echecs else 0)
