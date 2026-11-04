extends SceneTree
## PV issus des caractéristiques : 5 PV tous les 2 points d'endurance (2026-11-03 ; 10 par point le 2026-10-29) ;
## héros : 70 de base, toutes les caractéristiques à 0 ; gobelins selon la sous-classe (Gobelin.ENDURANCE_PAR_SOUS_CLASSE,
## × Ennemis.ENDURANCE_PAR_POINT_ENNEMI : mêmes PV qu'avant), hors endurance des objets portés.
## godot --headless --path godot -s tests/test_pv.gd


func _initialize() -> void:
	seed(11)
	var echecs := 0
	var heros := Personnage.nouveau()
	var bonus_objets := 0
	for o in heros.equipements.values():
		if o != null:
			bonus_objets += int(U.num(o, "points_de_vie_max"))
	print("Héros : endurance %d, PV %s/%s (dont %d des objets équipés)" % [heros.endurance, heros.points_de_vie, heros.points_de_vie_max, bonus_objets])
	var a_zero := true
	for c in Caracteristiques.LISTE:
		a_zero = a_zero and U.num(heros, c) == 0
	if not a_zero or heros.points_de_vie_max != Personnage.PV_BASE_HEROS + bonus_objets:
		print("ÉCHEC : PV du héros.")
		echecs += 1
	var fabriques := {"combattant": "generer_combattant_gobelin", "defenseur": "generer_defenseur_gobelin",
		"lancier": "generer_lancier_gobelin", "archer": "generer_archer_gobelin", "sorcier": "generer_sorcier_gobelin",
		"feticheur": "generer_feticheur_gobelin", "chaman": "generer_chaman_gobelin"}
	for sous_classe in fabriques:
		var bornes: Array = Gobelin.bornes_endurance(sous_classe)
		var vus := {}
		for i in 60:
			var g = Gobelin.nouveau(null).call(fabriques[sous_classe])
			var objets := 0
			var endurance_objets := 0
			for o in g.emplacements_portes.values():
				if o != null:
					objets += int(U.num(o, "points_de_vie_max"))
					endurance_objets += int(U.num(o, "endurance"))
			var tiree: int = g.endurance - endurance_objets
			vus[tiree] = true
			var k := Ennemis.ENDURANCE_PAR_POINT_ENNEMI
			var pv_attendus: int = Caracteristiques.paliers(g.endurance) * Ennemis.PV_PAR_ENDURANCE + objets
			if tiree % k != 0 or tiree < bornes[0] * k or tiree > bornes[1] * k or g.points_de_vie_max != pv_attendus 					or (endurance_objets == 0 and g.points_de_vie_max != tiree / k * 10):
				print("ÉCHEC : %s endurance %d, PV %d (objets %d)." % [sous_classe, g.endurance, g.points_de_vie_max, objets])
				echecs += 1
				break
		var e := vus.keys()
		e.sort()
		print("%s : endurances %s" % [sous_classe, e])
	echecs += _rencontres()
	print("BILAN PV : %d échec(s)" % echecs)
	quit(1 if echecs else 0)


## Nombre d'ennemis par rencontre selon l'étage (Donjon.ENNEMIS_PAR_ETAGE ; l'étage 4 vaut pour la suite).
func _rencontres() -> int:
	var echecs := 0
	var donjon := Donjon.nouveau(Personnage.nouveau())
	var attendu := {1: [75, 25, 0], 2: [50, 40, 10], 3: [25, 50, 25], 4: [20, 45, 35], 7: [20, 45, 35]}
	for etage in attendu:
		var compte := [0, 0, 0]
		for i in 6000:
			compte[donjon.tirer_nombre_ennemis(etage) - 1] += 1
		var parts := []
		for k in 3:
			parts.append(100.0 * compte[k] / 6000)
			if absf(parts[k] - attendu[etage][k]) > 2.0:
				echecs += 1
				print("ÉCHEC : étage %d, %d ennemi(s) : %.1f %% au lieu de %d %%." % [etage, k + 1, parts[k], attendu[etage][k]])
		print("Étage %d : 1 ennemi %.1f %%, 2 ennemis %.1f %%, 3 ennemis %.1f %%" % [etage, parts[0], parts[1], parts[2]])
	return echecs
