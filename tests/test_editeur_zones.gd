extends SceneTree
## Éditeur de zones : tracer une zone, annuler, déplacer un point, poser des prisonniers, enregistrer (porte2).
## « BILAN éditeur de zones : 0 échec(s) ». Le test écrit donnees/salles_peintes/porte2.json et
## outils/zones_manuelles/porte2.json, puis remet le premier comme avant et efface le second.

var echecs := 0


func verifier(c: bool, cas: String) -> void:
	if not c:
		echecs += 1
	print(("ok " if c else "ÉCHEC ") + cas)


func _initialize() -> void:
	var original := FileAccess.get_file_as_string("res://donnees/salles_peintes/porte2.json")
	var manuel_avant := FileAccess.file_exists("res://outils/zones_manuelles/porte2.json")
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
	# Prisonniers (couche 5, 2026-11-01) : des points posés, annulés, enregistrés, puis placés par le jeu
	ed.couche = ed.PRISONNIERS
	ed._memoriser()
	ed.salle.donnees[ed.PRISONNIERS].append(Vector2(200, 450))
	ed.salle.donnees[ed.PRISONNIERS].append(Vector2(560, 440))
	verifier(ed._prisonnier_proche(Vector2(201, 451)) == 0, "prisonnier attrapé au clic")
	ed._memoriser()
	ed.salle.donnees[ed.PRISONNIERS].remove_at(1)
	ed._annuler()
	verifier(ed.salle.donnees[ed.PRISONNIERS].size() == 2, "Ctrl+Z remet le prisonnier retiré")
	ed._enregistrer()
	relu = SallePeinte.lire_salle("porte2")
	verifier(str(relu.get("prisonniers", [])) == str([[200.0, 450.0], [560.0, 440.0]]), "prisonniers enregistrés : %s" % str(relu.get("prisonniers")))
	var poses := 0
	var bien_places := 0
	for k in 5:
		var donjon := Donjon.nouveau(Personnage.nouveau())
		for e in donjon.plan_donjon:
			for i in donjon.plan_donjon[e]:
				var info: Dictionary = donjon.plan_donjon[e][i].get("salle_peinte", {})
				for p in donjon.plan_donjon[e][i].get("presences", []):
					if p.get("sous") == "prisonnier_cellule":
						poses += 1
						var x: float = 768.0 - 200 if info.get("miroir", false) else 200.0
						var x2: float = 768.0 - 560 if info.get("miroir", false) else 560.0
						if info.get("image") == "porte2" and (is_equal_approx(p["pos"][0], x) or is_equal_approx(p["pos"][0], x2)):
							bien_places += 1
	verifier(poses > 0 and poses == bien_places, "le jeu pose un prisonnier sur chaque point (%d / %d)" % [bien_places, poses])
	var f := FileAccess.open("res://donnees/salles_peintes/porte2.json", FileAccess.WRITE)
	f.store_string(original)
	f.close()
	if not manuel_avant:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("res://outils/zones_manuelles/porte2.json"))
	print("BILAN éditeur de zones : %d échec(s)" % echecs)
	quit()
