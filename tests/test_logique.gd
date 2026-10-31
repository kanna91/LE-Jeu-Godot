extends SceneTree
## Test de la logique sans affichage : partie jouée par le joueur automatique.
## godot --headless --path godot -s tests/test_logique.gd


func _initialize() -> void:
	lancer()


func lancer() -> void:
	Ecrans.auto = true
	seed(12345)
	var t0 := Time.get_ticks_msec()
	var joueur := Personnage.nouveau()
	print("Création du héros : %d ms" % (Time.get_ticks_msec() - t0))
	print("PV %s/%s mana %s arme %s" % [joueur.points_de_vie, joueur.points_de_vie_max, joueur.mana, (U.ga(joueur, "arme_equipee", null).nom if U.ga(joueur, "arme_equipee", null) != null else "aucune")])
	var donjon := Donjon.nouveau(joueur)
	var pas := 0
	while pas < 120 and not Statistiques.mort:
		pas += 1
		if donjon.est_salle_boss() and donjon.salle_courante().get("visitee", false) == false and pas > 1:
			pass
		var salle := donjon.salle_courante()
		if donjon.est_salle_boss() and donjon.boss_vaincu() and pas > 2:
			print("== Étage %d terminé, on monte" % donjon.salle_actuelle[0])
			await donjon.monter_etage()
			continue
		var directions := []
		for d in ["t", "g", "d", "r"]:
			directions.append(d)
		directions.shuffle()
		var avant = donjon.salle_actuelle.duplicate()
		for d in directions:
			await donjon.avancer(d)
			if donjon.salle_actuelle != avant:
				break
		# Donjon d'aventure : le joueur automatique va au contact de chaque ennemi de la salle (geôlier : capture)
		for p in Aventure.presences(donjon, donjon.salle_courante()).duplicate():
			if Statistiques.mort:
				break
			if p["genre"] == "geolier":
				print("== Capturé par le geôlier")
				Aventure.capturer(donjon, p)
				break
			if Aventure.est_rodeur(p) or p["genre"] == "boss":
				var combat := Combat.nouveau(joueur, null, Aventure.ennemis_de(donjon, p), donjon)
				await combat.mener_combat()
				if combat.issue == "victoire":
					Aventure.apres_victoire(donjon, p)
				print("== Combat contre %s : %s" % [p["genre"], combat.issue])
			elif p["genre"] == "objet":
				Aventure.utiliser_objet(donjon, p)
	print("Fin : pas %d, mort %s, niveau %d, étage %d, or %d" % [pas, Statistiques.mort, joueur.niveau, donjon.salle_actuelle[0], joueur.piece_or])
	print(Statistiques.bilan(joueur, donjon))
	var t1 := Time.get_ticks_msec()
	Sauvegarde.sauvegarder("test", joueur, donjon)
	var charge := Sauvegarde.charger("test")
	print("Sauvegarde + chargement : %d ms ; héros rechargé niveau %d, PV %s, talents %d" % [Time.get_ticks_msec() - t1,
		charge[0].niveau, charge[0].points_de_vie, charge[0].arbre_de_talents.talents.size()])
	quit()
