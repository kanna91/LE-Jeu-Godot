extends SceneTree
## Butin : les gobelins ne portent aucun équipement (et ne lâchent rien à leur mort depuis le 2026-10-26).
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
	print("BILAN butin : %d échec(s)" % echecs)
	quit(1 if echecs else 0)
