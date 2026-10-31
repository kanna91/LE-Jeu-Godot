extends SceneTree
## Éditeur de zones : tracer une zone, annuler, déplacer un point, enregistrer (porte2).
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
	var f := FileAccess.open("res://donnees/salles_peintes/porte2.json", FileAccess.WRITE)
	f.store_string(original)
	f.close()
	if not manuel_avant:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("res://outils/zones_manuelles/porte2.json"))
	print("BILAN éditeur de zones : %d échec(s)" % echecs)
	quit()
