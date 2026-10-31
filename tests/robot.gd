extends SceneTree
## Joueur automatique *par l'interface* : lance la vraie scène principale et clique
## au hasard dans les zones déclarées par chaque écran (comme la manette), ouvre
## les menus, se bat, explore. Sert à débusquer les erreurs d'exécution des écrans.
## Aucune vraie entrée n'est simulée : les événements sont donnés à l'écran.
##
##   godot --path . -s tests/robot.gd -- <graine> <images>

var graine := 1
var images_max := 20000
var image := 0
var visites := {}
var actions_ecran := 0
var dernier_ecran = null
var alea := RandomNumberGenerator.new()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		graine = int(args[0])
	if args.size() > 1:
		images_max = int(args[1])
	alea.seed = graine
	seed(graine)
	Engine.max_fps = 60
	root.add_child(load("res://scenes/principal.tscn").instantiate())
	process_frame.connect(_image)


func _nom(ecran) -> String:
	return String(ecran.get_script().resource_path).get_file().get_basename()


func _cle_texte(cle) -> String:
	return str(cle).to_lower()


func _zones(ecran, interdits := ["quitter", "menu", "fermer", "retour", "laisser"]) -> Array:
	var z := []
	for zone in ecran.zones:
		var t := _cle_texte(zone[0])
		var ok := true
		for mot in interdits:
			if mot in t:
				ok = false
		if ok:
			z.append(zone)
	return z


func _clic(ecran, pos: Vector2, bouton := 1) -> void:
	ecran._traiter([{"type": "clic", "pos": pos, "bouton": bouton, "double": false}])


func _touche(ecran, t: int) -> void:
	ecran._traiter([{"type": "touche", "touche": t, "repete": false}])


func _clic_zone(ecran, zones: Array) -> void:
	if zones.is_empty():
		_touche(ecran, KEY_ESCAPE)
		return
	var zone: Array = zones[alea.randi_range(0, zones.size() - 1)]
	var r: Rect2 = zone[1]
	_clic(ecran, r.get_center())
	if alea.randf() < 0.3:  # double-clic (équiper, apprendre)
		_clic(ecran, r.get_center())


func _image() -> void:
	image += 1
	if image >= images_max:
		_bilan()
		quit()
		return
	if image % 4 != 0 or Ecrans.pile.is_empty():
		return
	var ecran = Ecrans.pile[-1]
	if ecran._occupe or ecran._ferme:
		return
	var nom := _nom(ecran)
	visites[nom] = visites.get(nom, 0) + 1
	if ecran != dernier_ecran:
		dernier_ecran = ecran
		actions_ecran = 0
	actions_ecran += 1
	match nom:
		"menu_demarrage":
			_clic(ecran, ecran.boutons["Nouvelle partie"].get_center())
		"menu_navigation":
			var x := alea.randf()
			if x < 0.75:
				# Franchir une des sorties de la salle peinte (porte condamnée comprise)
				var nombre: int = ecran.salle_peinte.directions_sorties().size()
				if nombre > 0 and not ecran.passage_en_cours:
					ecran._sortie_atteinte(alea.randi_range(0, nombre - 1))
			elif x < 0.9:
				_clic_zone(ecran, _zones(ecran))
			else:
				_touche(ecran, [KEY_I, KEY_C, KEY_M, KEY_TAB][alea.randi_range(0, 3)])
		"menu_combat":
			var z := _zones(ecran)
			if alea.randf() < 0.6 and not ecran.boutons_actions.is_empty():
				_clic(ecran, ecran.boutons_actions[alea.randi_range(0, 1)][0].get_center())
				if not ecran.ennemis_rects_images.is_empty():
					_clic(ecran, ecran.ennemis_rects_images[0][0].get_center())
			elif alea.randf() < 0.15:
				_clic(ecran, ecran.boutons_actions[4][0].get_center())
			else:
				_clic_zone(ecran, z)
		"menu_pause", "fiche_ennemi", "carte_complete":
			_touche(ecran, KEY_ESCAPE)
		"ecran_mort":
			_clic_zone(ecran, _zones(ecran, ["quitter", "menu"]))
		"menu_sort_depart", "menu_coffre", "menu_bonus", "menu_soin", "choix_objet_combat", "choix_emplacement":
			if actions_ecran > 6:
				_touche(ecran, KEY_ESCAPE)
			else:
				_clic_zone(ecran, _zones(ecran, ["quitter", "menu", "retour"]))
		_:  # menus du héros, marchand, talents, améliorations
			if actions_ecran > 12:
				_touche(ecran, KEY_ESCAPE)
			elif alea.randf() < 0.15:
				ecran._traiter([{"type": "molette", "sens": [-1, 1][alea.randi_range(0, 1)]}])
			else:
				_clic_zone(ecran, _zones(ecran))


func _bilan() -> void:
	print("ROBOT graine %d : %d images, écrans visités : %s" % [graine, image, visites])
	print("Statistiques : mort=%s" % Statistiques.mort)
