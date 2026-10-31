extends SceneTree
## Orientation fixe des salles peintes (haut de l'image = haut de la mini-carte) : captures et passages.
##
## 1. Une capture de l'écran d'exploration (salle + mini-carte) par combinaison de passages trouvée
##    (haut, gauche, droite, bas) : tests/captures/58_<directions>_<image>.png.
## 2. Passages réels : dans des salles qui ont une voisine en bas, à gauche, à droite et en haut, le héros
##    franchit la sortie de l'image qui va dans cette direction ; on vérifie que la salle atteinte est
##    bien dans la même direction sur la carte, et qu'il arrive devant la porte d'où il vient.
## « BILAN directions : 0 échec(s) ».
## Fenêtre hors écran (override.cfg, voir README) :
##   Godot --path . -s tests/voir_directions.gd

var racine: Control
var echecs := 0


func _initialize() -> void:
	racine = Control.new()
	racine.size = Vector2(960, 540)
	root.add_child(racine)
	Ecrans.racine = racine
	lancer()


func attendre(images: int) -> void:
	for _i in images:
		# Windows réduit parfois la fenêtre hors écran : on la remet à sa taille pour les captures
		if DisplayServer.window_get_size() != Vector2i(1280, 720):
			DisplayServer.window_set_size(Vector2i(1280, 720))
		await process_frame


func lancer() -> void:
	Sauvegarde.reinitialiser_monde()
	Statistiques.mort = false
	Ecrans.auto = true
	var joueur = Personnage.nouveau()
	var donjon = Donjon.nouveau(joueur)
	var vues := {}
	var essais := {}  # direction de la carte → déjà essayée
	for etage in [1, 2, 3]:
		if etage > 1:
			donjon.generer_etage(etage)
		PlanSalles.attribuer(donjon, etage)
		var salles: Dictionary = donjon.plan_donjon[etage]
		for id in salles:
			var voisines := PlanSalles.voisines_carte(salles, str(id))
			var k := _nom(voisines.keys())
			var info: Dictionary = salles[id]["salle_peinte"]
			if not vues.has(k):
				vues[k] = true
				await capturer(joueur, donjon, etage, str(id), "58_%s_%s%s" % [k.replace(" + ", "_"), info["image"],
					"_miroir" if info["miroir"] else ""])
			for d in voisines:
				if essais.size() < 4 and not essais.has(d):
					essais[d] = true
					await passer(joueur, donjon, etage, str(id), d)
	print("BILAN directions : %d échec(s)" % echecs)
	quit()


static func _nom(directions: Array) -> String:
	var noms := []
	for d in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
		if d in directions:
			noms.append(PlanSalles.NOMS_DIRECTIONS[d])
	return " + ".join(noms)


func capturer(joueur, donjon, etage: int, id: String, nom: String) -> void:
	donjon.plan_donjon[etage][id]["visitee"] = true
	donjon.salle_actuelle = [etage, int(id)]
	var nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
	racine.add_child(nav)
	await attendre(40)
	root.get_viewport().get_texture().get_image().save_png("res://tests/captures/%s.png" % nom)
	print("capture ", nom)
	nav.queue_free()
	await attendre(2)


## Depuis la salle ``id``, franchit la sortie de l'image qui mène dans la direction ``d`` de la carte.
func passer(joueur, donjon, etage: int, id: String, d: Vector2i) -> void:
	var salles: Dictionary = donjon.plan_donjon[etage]
	donjon.salle_actuelle = [etage, int(id)]
	var nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
	racine.add_child(nav)
	await attendre(5)
	var info: Dictionary = salles[id]["salle_peinte"]
	var dirs: Array = nav.salle_peinte.directions_sorties()
	var i := -1
	for k in dirs.size():
		if PlanSalles.absolue(dirs[k], PlanSalles.FACE) == d and info["sorties"][k] != null:
			i = k
			break
	var nom_dir: String = PlanSalles.NOMS_DIRECTIONS[d]
	if i < 0:
		echecs += 1
		print("ÉCHEC salle %s : aucune sortie vers %s" % [id, nom_dir])
	else:
		# Pas d'événement de salle (combat, piège) pendant ce contrôle
		var dest := str(info["sorties"][i])
		salles[dest]["visitee"] = true
		salles[dest].erase("evenement")
		salles[dest]["ennemis"] = []
		await nav._franchir(dest)
		await attendre(5)
		var ici: Dictionary = salles[str(donjon.salle_actuelle[1])]
		var ok: bool = PlanSalles._position(ici) - PlanSalles._position(salles[id]) == d
		# Porte d'arrivée : celle qui ramène à la salle de départ, donc du côté opposé de l'image
		var j := PlanSalles.sortie_vers(ici, id)
		var dirs2: Array = nav.salle_peinte.directions_sorties()
		var cote: String = dirs2[j] if j >= 0 and j < dirs2.size() else "?"
		ok = ok and PlanSalles.absolue(cote, PlanSalles.FACE) == -d
		print("%s salle %s (%s) → sortie « %s » → salle %s (%s), arrivée par sa sortie « %s »" % [
			"ok" if ok else "ÉCHEC", id, info["image"], dirs[i], donjon.salle_actuelle[1], ici["salle_peinte"]["image"],
			cote])
		if not ok:
			echecs += 1
		root.get_viewport().get_texture().get_image().save_png("res://tests/captures/58_passage_%s.png" % nom_dir)
	nav.queue_free()
	await attendre(2)
