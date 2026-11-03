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
