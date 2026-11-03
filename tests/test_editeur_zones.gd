extends SceneTree
## Éditeur de zones : tracer une zone, annuler, déplacer un point, poser des prisonniers, enregistrer (porte2).
## « BILAN éditeur de zones : 0 échec(s) ». Le test écrit donnees/salles_peintes/porte2.json et
## outils/zones_manuelles/porte2.json, puis les remet tous deux comme avant (le second est effacé s'il n'existait pas).

var echecs := 0


func verifier(c: bool, cas: String) -> void:
	if not c:
		echecs += 1
	print(("ok " if c else "ÉCHEC ") + cas)


func _initialize() -> void:
	var original := FileAccess.get_file_as_string("res://donnees/salles_peintes/porte2.json")
	if true:  # Points de feu et d'eau (onglets Feux et Eau, 2026-11-03) : vérifiés sans rien enregistrer
		var ed0 = load("res://scenes/outils/editeur_zones.tscn").instantiate()
		root.add_child(ed0)
		await process_frame
		ed0.numero = ed0.salles.find("porte2")
		ed0._charger()
		ed0.choisir_eau()
		verifier(ed0.couche == "eaux" and ed0.onglets.current_tab == 3, "onglet Eau : couche des zones d'eau")
		ed0.trace = PackedVector2Array([Vector2(300, 430), Vector2(380, 430), Vector2(380, 470), Vector2(300, 470)])
		ed0._fermer_trace()
		verifier(ed0.salle.donnees["eaux"].size() == 1 and ed0.salle.donnees["eaux"][0].size() == 4, "onglet Eau : zone d'eau tracée")
		# Feux : des zones tracées comme les autres (2026-11-03)
		ed0.choisir_feux()
		verifier(ed0.couche == "feux" and ed0.onglets.current_tab == 2, "onglet Feux : couche des zones de feu")
		ed0.trace = PackedVector2Array([Vector2(180, 430), Vector2(260, 430), Vector2(260, 470), Vector2(180, 470)])
		ed0._fermer_trace()
		verifier(ed0.salle.donnees["feux"].size() == 1 and ed0.salle.donnees["feux"][0].size() == 4 and ed0.salle.donnees["eaux"].size() == 1,
			"onglet Feux : zone de feu tracée, l'eau reste")
		ed0._annuler()
		verifier(ed0.salle.donnees["feux"].is_empty(), "Ctrl+Z retire la zone de feu")
		ed0.choisir_onglet(false)
		verifier(ed0.couche != "feux" and ed0.onglets.current_tab == 0, "retour à l'onglet Zones")
		ed0.queue_free()
		await process_frame
		# Ancien point de torche : devient une petite zone autour de lui
		var z := SallePeinte.zones_depuis_points([[675, 321]], func(_y): return 100.0)
		var poly := PackedVector2Array()
		for q in z[0]:
			poly.append(Vector2(q[0], q[1]))
		verifier(z.size() == 1 and poly.size() == 4 and Geometry2D.is_point_in_polygon(Vector2(675, 321), poly)
			and not Geometry2D.is_point_in_polygon(Vector2(675, 421), poly), "ancien point de torche → zone autour de lui")
		# Dans le jeu : le héros dans la zone peut se servir de la torche
		var sp := SallePeinte.new()
		root.add_child(sp)
		sp.charger("porte2", -1, false)
		sp.donnees["feux"] = [PackedVector2Array([Vector2(180, 430), Vector2(260, 430), Vector2(260, 470), Vector2(180, 470)])]
		sp.heros.position = Vector2(220, 450)
		verifier(sp.torche_proche(), "héros dans la zone de feu : torche à portée")
		sp.heros.position = Vector2(400, 450)
		verifier(not sp.torche_proche(), "héros hors de la zone : pas de torche")
		sp.donnees["eaux"] = [PackedVector2Array([Vector2(300, 430), Vector2(380, 430), Vector2(380, 470), Vector2(300, 470)])]
		verifier(not sp.eau_proche(), "héros hors de la zone d'eau : pas d'eau")
		sp.heros.position = Vector2(340, 450)
		verifier(sp.eau_proche() and not sp.torche_proche(), "héros dans la zone d'eau : eau à portée")
		sp.queue_free()
		await process_frame
	var manuel_avant := FileAccess.file_exists("res://outils/zones_manuelles/porte2.json")
	# Zones retouchées par l'utilisateur : remises telles quelles à la fin (2026-11-03 ; avant, elles étaient écrasées)
	var manuel_original := FileAccess.get_file_as_string("res://outils/zones_manuelles/porte2.json") if manuel_avant else ""
	var ed = load("res://scenes/outils/editeur_zones.tscn").instantiate()
	root.add_child(ed)
	await process_frame
	ed.numero = ed.salles.find("porte2")
	ed._charger()
	var avant: int = ed.salle.donnees["obstacles"].size()
	ed.couche = "obstacles"
	ed.trace = PackedVector2Array([Vector2(300, 400), Vector2(340, 400), Vector2(320, 430)])
	ed._fermer_trace()
	verifier(ed.salle.donnees["obstacles"].size() == avant + 1, "zone ajoutée")
	verifier(not ed.salle.libre(Vector2(320, 410)), "la nouvelle zone arrête le héros")
	ed._annuler()
	verifier(ed.salle.donnees["obstacles"].size() == avant, "Ctrl+Z la retire")
	var p0: Vector2 = ed.salle.donnees["marche"][0][0]
	var poly: PackedVector2Array = ed.salle.donnees["marche"][0]
	poly[0] = p0 + Vector2(-1, 0)
	ed.salle.donnees["marche"][0] = poly
	ed._enregistrer()
	verifier(ed.message.begins_with("Enregistré"), "enregistré : " + ed.message)
	var relu := SallePeinte.lire_salle("porte2")
	verifier(relu["marche"][0][0] == [p0.x - 1, p0.y], "point déplacé relu")
	verifier(FileAccess.file_exists("res://outils/zones_manuelles/porte2.json"), "copie dans zones_manuelles")
	# Prisonniers (couche 5, 2026-11-01) : des zones de dialogue tracées, enregistrées, puis posées par le jeu
	ed.couche = "prisonniers"
	ed.trace = PackedVector2Array([Vector2(180, 430), Vector2(240, 430), Vector2(240, 470), Vector2(180, 470)])
	ed._fermer_trace()
	verifier(ed.salle.donnees["prisonniers"].size() == 1, "zone de prisonnier tracée")
	# Sorties : en ajouter une, la déplacer d'un bloc, la retirer, annuler
	ed.couche = "sorties"
	var n_sorties: int = ed.salle.donnees["sorties"].size()
	ed.trace = PackedVector2Array([Vector2(20, 380), Vector2(50, 380), Vector2(50, 420), Vector2(20, 420)])
	ed._fermer_trace()
	verifier(ed.salle.donnees["sorties"].size() == n_sorties + 1 and ed.salle.donnees["directions_sorties"][-1] == "gauche",
		"sortie ajoutée sur le bord gauche : direction « gauche »")
	verifier(ed.salle.donnees["noms_sorties"].size() == n_sorties + 1 and ed.salle.donnees["types_sorties"].size() == n_sorties + 1,
		"noms et types des sorties suivent")
	ed._memoriser()
	ed._retirer_sortie(n_sorties)
	verifier(ed.salle.donnees["sorties"].size() == n_sorties, "sortie retirée")
	ed._annuler()
	verifier(ed.salle.donnees["sorties"].size() == n_sorties + 1, "Ctrl+Z remet la sortie")
	ed._memoriser()
	ed._retirer_sortie(n_sorties)
	ed._enregistrer()
	relu = SallePeinte.lire_salle("porte2")
	verifier(relu.get("prisonniers", []).size() == 1, "zone de prisonnier enregistrée")
	verifier(relu["directions_sorties"].size() == relu["sorties"].size(), "autant de directions que de sorties")
	var poses := 0
	var dans_zone := 0
	for k in 5:
		var donjon := Donjon.nouveau(Personnage.nouveau())
		for e in donjon.plan_donjon:
			for i in donjon.plan_donjon[e]:
				for p in donjon.plan_donjon[e][i].get("presences", []):
					if p.get("sous") == "prisonnier_cellule":
						poses += 1
						var zone := PackedVector2Array()
						for q in p["zone"]:
							zone.append(Vector2(q[0], q[1]))
						if Geometry2D.is_point_in_polygon(Vector2(p["pos"][0], p["pos"][1]), zone):
							dans_zone += 1
	verifier(poses > 0 and poses == dans_zone, "le jeu pose un prisonnier par zone (%d / %d)" % [dans_zone, poses])
	var f := FileAccess.open("res://donnees/salles_peintes/porte2.json", FileAccess.WRITE)
	f.store_string(original)
	f.close()
	if not manuel_avant:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("res://outils/zones_manuelles/porte2.json"))
	else:
		var m := FileAccess.open("res://outils/zones_manuelles/porte2.json", FileAccess.WRITE)
		m.store_string(manuel_original)
		m.close()
	print("BILAN éditeur de zones : %d échec(s)" % echecs)
	quit()
