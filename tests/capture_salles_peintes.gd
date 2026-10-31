extends SceneTree
## Contrôle des salles peintes de l'écran d'exploration (SallePeinte, PlanSalles).
##
## - Attribution sur plusieurs étages : chaque salle a une image ; chaque passage du plan mène à une
##   sortie peinte (ou, faute de porte, à une flèche) ; chaque sortie mène à la salle voisine qui est
##   dans sa direction sur la carte (face de la salle, miroir compris).
## - En jeu : le héros marche (touche flèche haut simulée), franchit des portes (combats joués seuls),
##   arrive devant la porte de la salle quittée ; captures 50 à 55 dans tests/captures/.
## Affiche « BILAN salles peintes : 0 échec(s) » si tout est correct.
## À lancer dans une fenêtre hors écran (override.cfg, voir README).

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
		await process_frame


func capturer(nom: String) -> void:
	await attendre(3)
	root.get_viewport().get_texture().get_image().save_png("res://tests/captures/%s.png" % nom)
	print("capture ", nom)


func verifier(condition: bool, cas: String) -> void:
	if condition:
		print("ok ", cas)
	else:
		echecs += 1
		print("ÉCHEC ", cas)


## Sorties qu'on atteint en marchant depuis la position du héros (parcours sur une grille de 6 px des points libres).
func _sorties_atteignables(salle: SallePeinte) -> Array:
	var pas := 6.0
	var depart: Vector2 = salle.heros.position
	var vus := {Vector2i(depart / pas): true}
	var file := [depart]
	var atteintes := []
	while not file.is_empty():
		var p: Vector2 = file.pop_front()
		var s := salle._sortie_sous(p)
		if s >= 0 and not s in atteintes:
			atteintes.append(s)
		for d in [Vector2(pas, 0), Vector2(-pas, 0), Vector2(0, pas), Vector2(0, -pas)]:
			var q: Vector2 = p + d
			var c := Vector2i(q / pas)
			if vus.has(c) or not (salle.libre(q) or salle._sortie_sous(q) >= 0):
				continue
			vus[c] = true
			if salle.libre(q):
				file.append(q)
			elif not salle._sortie_sous(q) in atteintes:
				atteintes.append(salle._sortie_sous(q))
	atteintes.sort()
	return atteintes


func controler_plan(donjon, etage: int) -> void:
	PlanSalles.attribuer(donjon, etage)
	var salles: Dictionary = donjon.plan_donjon[etage]
	var sans_porte := 0
	var condamnees := 0
	var miroirs := 0
	for id in salles:
		var s: Dictionary = salles[id]
		var info: Dictionary = s.get("salle_peinte", {})
		if not PlanSalles.images().has(String(info.get("image", ""))):
			verifier(false, "étage %d salle %s : image" % [etage, id])
			continue
		var directions: Array = PlanSalles.directions_carte(info)
		var menees := []
		for i in info["sorties"].size():
			var d = info["sorties"][i]
			if d == null:
				condamnees += 1
				continue
			if not str(d) in menees:  # deux portes du même côté mènent à la même salle
				menees.append(str(d))
			var ecart: Vector2i = PlanSalles._position(salles[str(d)]) - PlanSalles._position(s)
			if ecart != directions[i]:
				verifier(false, "étage %d salle %s : la sortie %d (%s) mène à %s, qui est en %s sur la carte" % [etage, id, i,
					directions[i], d, ecart])
		if info.get("miroir", false):
			miroirs += 1
		for d in info["sans_porte"]:
			menees.append(str(d))
		sans_porte += info["sans_porte"].size()
		var attendues := []
		for c in s["connections"]:
			attendues.append(str(c))
		menees.sort()
		attendues.sort()
		if menees != attendues:
			verifier(false, "étage %d salle %s : passages %s au lieu de %s" % [etage, id, menees, attendues])
	print("étage %d : %d salles, %d en miroir, %d sortie(s) condamnée(s), %d passage(s) sans porte peinte" % [etage,
		salles.size(), miroirs, condamnees, sans_porte])


func lancer() -> void:
	Sauvegarde.reinitialiser_monde()
	Statistiques.mort = false
	Ecrans.auto = true
	var joueur = Personnage.nouveau()
	var donjon = Donjon.nouveau(joueur)
	for etage in [2, 3, 4]:
		donjon.generer_etage(etage)
	for etage in [1, 2, 3, 4]:
		controler_plan(donjon, etage)
	verifier(echecs == 0, "attribution des salles peintes sur 4 étages")
	# Le héros est invincible pour le test (les combats se jouent seuls)
	joueur.points_de_vie_max = 100000
	joueur.points_de_vie = 100000
	var nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
	Ecrans.pile.append(nav)
	racine.add_child(nav)
	await attendre(30)  # première image de la vidéo du décor
	await capturer("50_salle_depart")
	var salle: SallePeinte = nav.salle_peinte
	verifier(salle.decor_pret, "décor animé (vidéo) de la salle de départ affiché")
	# La vidéo avance : deux images différentes à une demi-seconde d'intervalle
	var image_a := salle.sprite_fond.texture.get_image()
	await attendre(30)
	var image_b := salle.sprite_fond.texture.get_image()
	verifier(image_a != null and image_b != null and image_a.get_data() != image_b.get_data(), "la vidéo du décor avance")
	# Marche : flèche haut maintenue
	var avant: Vector2 = salle.heros.position
	var touche := InputEventKey.new()
	touche.keycode = KEY_UP
	touche.physical_keycode = KEY_UP
	touche.pressed = true
	Input.parse_input_event(touche)
	await attendre(40)
	await capturer("51_marche")
	touche.pressed = false
	Input.parse_input_event(touche)
	await attendre(2)
	verifier(salle.heros.position != avant, "le héros marche (%s → %s)" % [avant, salle.heros.position])
	# Franchir des portes : chaque sortie menant à une salle, jusqu'à 4 passages
	var franchies := 0
	for etape in 4:
		var ici := str(donjon.salle_actuelle[1])
		var info: Dictionary = donjon.salle_courante()["salle_peinte"]
		var sortie := -1
		for i in info["sorties"].size():
			if info["sorties"][i] != null and PlanSalles.images()[info["image"]][i] != "bas":
				sortie = i
				break
		if sortie < 0:
			for i in info["sorties"].size():
				if info["sorties"][i] != null:
					sortie = i
					break
		if sortie < 0:
			break
		var dest := str(info["sorties"][sortie])
		await nav._sortie_atteinte(sortie)
		await attendre(30)
		if str(donjon.salle_actuelle[1]) != dest:
			verifier(false, "passage %s → %s (message : « %s », verrouillée : %s, salle actuelle : %s)" % [ici, dest,
				nav.message_nav, Aventure.verrouillee(donjon, dest), donjon.salle_actuelle[1]])
			break
		franchies += 1
		var arrivee := PlanSalles.sortie_vers(donjon.salle_courante(), ici)
		var nouvelle: Dictionary = donjon.salle_courante()["salle_peinte"]
		verifier(salle.ident == nouvelle["image"], "salle %s affichée avec l'image %s" % [dest, nouvelle["image"]])
		if arrivee >= 0:
			var centre := salle.centre_sortie(arrivee)
			verifier(salle.heros.position.distance_to(centre) < 140, "arrivée devant la porte de la salle %s (%.0f px)" % [ici,
				salle.heros.position.distance_to(centre)])
		verifier(salle.libre(salle.heros.position), "héros sur le sol à l'arrivée en salle %s" % dest)
		await attendre(60)
		await capturer("%d_salle_%s_%s" % [52 + etape, dest, nouvelle["image"]])
	verifier(franchies >= 2, "au moins deux portes franchies (%d)" % franchies)
	# Une salle à 3 sorties affichée en miroir : zones retournées avec l'image
	for image in ["porte5", "porte3"]:
		salle.charger(image, -1, true)
		await attendre(60)
		verifier(salle.libre(salle.heros.position), "%s en miroir : héros sur le sol" % image)
		var gauche := salle.directions_sorties().find("gauche")
		var droite := salle.directions_sorties().find("droite")
		var cote := gauche if gauche >= 0 else droite
		var c := salle.centre_sortie(cote)
		verifier((c.x < 384) == (gauche >= 0), "%s en miroir : porte de %s du bon côté (x = %.0f)" % [image,
			"gauche" if gauche >= 0 else "droite", c.x])
		await capturer("56_miroir_" + image)
	# Grandes salles (carrefours) : arrivée sur le sol par chaque sortie, chaque sortie atteignable à pied depuis
	# le départ, image agrandie affichée ; captures 57_grande_N
	for image in SallePeinte.salles_disponibles():
		if not PlanSalles.grande_salle(image):
			continue
		salle.charger(image, -1, false)
		await attendre(5)
		verifier(salle.sprite_fond.texture.get_width() > salle.fond.get_width(), "%s : image agrandie affichée" % image)
		for i in salle.directions_sorties().size():
			salle.charger(image, i, false)
			verifier(salle.libre(salle.heros.position), "%s : arrivée par « %s » sur le sol" % [image, salle.nom_sortie(i)])
		salle.charger(image, -1, false)
		salle.murer([])
		var atteintes := _sorties_atteignables(salle)
		verifier(atteintes.size() == salle.directions_sorties().size(), "%s : sorties atteignables à pied %s" % [image, atteintes])
		await capturer("57_" + image)
	print("BILAN salles peintes : %d échec(s)" % echecs)
	SallePeinte.liberer()
	quit()
