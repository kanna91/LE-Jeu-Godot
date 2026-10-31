extends SceneTree
## Butin : les gobelins ne portent aucun équipement ; à leur mort, un objet est généré avec une chance qui
## baisse par paliers avec le nombre d'objets équipés par le héros (50 % → 25 %).
## godot --headless --path godot -s tests/test_butin.gd


func _initialize() -> void:
	seed(7)
	var echecs := 0
	Sauvegarde.reinitialiser_monde()
	var heros := Personnage.nouveau()
	var donjon := Donjon.nouveau(heros)
	for i in 50:
		var g = Gobelin.nouveau(donjon).generer_gobelin(donjon)
		var portes := 0
		for o in g.emplacements_portes.values():
			if o != null:
				portes += 1
		if portes or U.ga(g, "arme_equipee", null) != null or not g.inventaire.is_empty():
			print("ÉCHEC : %s porte %d objet(s)." % [g.nom, portes])
			echecs += 1
			break
	# Butin réel au début (héros avec son arme seule) : environ 50 % d'objets lâchés.
	var lacher := 0
	for i in 2000:
		var g = Gobelin.nouveau(donjon).generer_gobelin(donjon)
		for o in g.loot():
			if o is Arme or o is Armure:
				lacher += 1
	print("Objets lâchés au début : %.1f %%" % (lacher / 20.0))
	if absf(lacher / 20.0 - 50.0) > 4.0:
		echecs += 1
		print("ÉCHEC : environ 50 % attendu.")
	# Paliers : objets équipés par le héros → chance attendue.
	var attendus := {1: 0.50, 2: 0.50, 3: 0.40, 5: 0.40, 6: 0.35, 7: 0.35, 8: 0.30, 9: 0.30, 10: 0.25}
	for n in attendus:
		var portes := {}
		for k in Objets.EMPLACEMENTS_EQUIPEMENT.size():
			portes[Objets.EMPLACEMENTS_EQUIPEMENT[k]] = "objet" if k < n else null
		heros.equipements = portes
		var c := Ennemis.chance_butin_objet(donjon)
		print("%d objet(s) équipé(s) : %d %%" % [n, roundi(c * 100)])
		if not is_equal_approx(c, attendus[n]):
			echecs += 1
			print("ÉCHEC : %s attendu." % attendus[n])
	print("BILAN butin : %d échec(s)" % echecs)
	quit(1 if echecs else 0)
