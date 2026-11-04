extends SceneTree
## PV des ennemis au début de la partie (2026-11-04, demande de l'utilisateur) : aucun ennemi ordinaire ne meurt en
## moins de 4 coups du héros de départ. Pour chaque sorte d'ennemi, le plus petit PV tiré doit dépasser 3 fois le plus
## gros coup de poing mesuré (600 coups) ; affiche aussi les dégâts des sorts de départ (pour information).
## « BILAN coups de départ : 0 échec(s) ».   godot --headless --path . -s tests/mesure_coups_depart.gd

var echecs := 0


func _initialize() -> void:
	seed(11)
	Sauvegarde.reinitialiser_monde()
	var heros := Personnage.nouveau()
	var donjon := Donjon.nouveau(heros)
	var combat := Combat.nouveau(heros, null, [], donjon)
	var attaques := [heros.competence_de_base["Coup_de_poing"], heros.competence_de_base["Enchainement"]]
	for s in Sorts.sorts_de_depart(heros):
		attaques.append(s)
	var sortes := []
	for cs in [["guerrier", "combattant"], ["guerrier", "lancier"], ["guerrier", "archer"], ["guerrier", "defenseur"],
			["mage", "sorcier"], ["mage", "feticheur"], ["soutien", "chaman"], ["creature", "loup"], ["creature", "squelette"]]:
		sortes.append(cs)
	var lignes := []
	for cs in sortes:
		var pv := []
		for _i in 60:
			pv.append(_creer(donjon, cs).points_de_vie_max)
		var ligne := "%-11s PV %d-%d :" % [cs[1], pv.min(), pv.max()]
		for k in attaques.size():
			var a = attaques[k]
			var coups := []
			for _i in (600 if k == 0 else 150):
				var e = _creer(donjon, cs)
				e.points_de_vie_max = 100000
				e.points_de_vie = 100000
				e.chance_esquive = 0
				e.chance_de_parer = 0
				heros.mana = 999
				heros.points_d_action = 9
				combat._d["ennemis"] = [e]
				combat.infliger_degats(heros, a, e, heros)
				if 100000 - e.points_de_vie > 0:
					coups.append(100000 - e.points_de_vie)
			coups.sort()
			if coups.is_empty():
				continue
			ligne += "  %s %d-%d (moy %.1f)" % [a.nom, coups[0], coups[-1], coups.reduce(func(x, y): return x + y) / coups.size()]
			if k == 0 and pv.min() <= 3 * coups[-1]:
				echecs += 1
				ligne += " ÉCHEC : 3 coups de poing (%d) tuent un ennemi de %d PV" % [3 * coups[-1], pv.min()]
		lignes.append(ligne)
	for l in lignes:
		print(l)
	print("BILAN coups de départ : %d échec(s)" % echecs)
	quit()


func _creer(donjon, cs: Array):
	if cs[0] == "creature":
		return Creatures.creer(donjon, cs[1])
	return Gobelin.nouveau(donjon)._completer(cs[0], cs[1])
