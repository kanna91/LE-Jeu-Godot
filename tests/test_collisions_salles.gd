extends SceneTree
## Collisions des salles peintes : le héros court longtemps dans les 8 directions (vraies touches simulées)
## depuis son point de départ, puis en zigzag ; à chaque image, ses pieds doivent rester sur le sol
## praticable (« marche ») et hors des obstacles. Pour chaque salle : point le plus haut atteint (le bord
## du précipice pour un cul-de-sac) et largeur parcourue.
## Capture tests/captures/59_<salle>.png : le héros poussé au bord du fond.
## Fenêtre hors écran (override.cfg, voir README) :
##   Godot --path . -s tests/test_collisions_salles.gd            (cul-de-sac 1 à 7 et miroirs)
##   Godot --path . -s tests/test_collisions_salles.gd -- toutes  (toutes les salles ; long : plus de 10 min)
##   Godot --path . -s tests/test_collisions_salles.gd -- grande   (les salles dont le nom commence ainsi)

const DIRECTIONS := [[KEY_UP], [KEY_UP, KEY_LEFT], [KEY_LEFT], [KEY_DOWN, KEY_LEFT], [KEY_DOWN],
	[KEY_DOWN, KEY_RIGHT], [KEY_RIGHT], [KEY_UP, KEY_RIGHT]]
const IMAGES_PAR_DIRECTION := 150

var racine: Control
var echecs := 0


func _initialize() -> void:
	racine = Control.new()
	racine.size = Vector2(960, 540)
	root.add_child(racine)
	Engine.time_scale = 2.0
	lancer()


func attendre(n: int) -> void:
	for _i in n:
		await process_frame


func touches(liste: Array, appui: bool) -> void:
	for k in liste:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		ev.pressed = appui
		Input.parse_input_event(ev)


func lancer() -> void:
	var ids := []
	for id in SallePeinte.salles_disponibles():
		var args := OS.get_cmdline_user_args()
		var prefixe := "culdesac" if args.is_empty() else String(args[0])
		if prefixe == "toutes" or String(id).begins_with(prefixe):
			ids.append(id)
	for id in ids:
		for miroir in [false, true]:
			await tester(id, miroir)
	print("BILAN collisions : %d échec(s)" % echecs)
	quit()


func sur_le_sol(s: SallePeinte, p: Vector2) -> bool:
	var dedans := false
	for poly in s.donnees["marche"]:
		if Geometry2D.is_point_in_polygon(p, poly):
			dedans = true
	for poly in s.donnees["obstacles"]:
		if Geometry2D.is_point_in_polygon(p, poly):
			return false
	return dedans


func tester(id: String, miroir: bool) -> void:
	var s := SallePeinte.new()
	racine.add_child(s)
	s.charger(id, -1, miroir)
	await attendre(5)
	s.course = true
	var depart: Vector2 = s.heros.position
	var haut := 9999.0
	var gauche := 9999.0
	var droite := -9999.0
	var hors := 0
	var nom := id + (" miroir" if miroir else "")
	var parcours := DIRECTIONS.duplicate()
	# Zigzag le long du fond : gauche puis droite en appuyant vers le haut
	parcours += [[KEY_UP], [KEY_UP, KEY_LEFT], [KEY_LEFT], [KEY_UP, KEY_RIGHT], [KEY_RIGHT], [KEY_RIGHT], [KEY_UP]]
	for i in parcours.size():
		if i < DIRECTIONS.size():
			s.heros.position = depart  # chaque direction part du point de départ
		touches(parcours[i], true)
		for _f in IMAGES_PAR_DIRECTION:
			await process_frame
			var p: Vector2 = s.heros.position
			if not sur_le_sol(s, p):
				hors += 1
				if hors <= 3:
					print("  ÉCHEC %s : pieds hors du sol en %s" % [nom, p])
			haut = minf(haut, p.y)
			gauche = minf(gauche, p.x)
			droite = maxf(droite, p.x)
		touches(parcours[i], false)
		await attendre(2)
	var bord: float = s.donnees["perspective"]["table_hauteur"][0][0]
	print("%s %-18s plus haut y=%d (bord du sol %d), x de %d à %d" % ["ok" if hors == 0 else "ÉCHEC", nom, haut, bord,
		gauche, droite])
	if hors > 0:
		echecs += 1
	if haut > bord + 30:
		echecs += 1
		print("  ÉCHEC %s : le héros n'atteint pas le fond (bloqué avant)" % nom)
	await attendre(3)
	root.get_viewport().get_texture().get_image().save_png("res://tests/captures/59_%s.png" % nom.replace(" ", "_"))
	s.queue_free()
	await attendre(2)
