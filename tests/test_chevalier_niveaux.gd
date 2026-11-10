extends SceneTree
## Le Chevalier de la mort sort des cryptes (2026-11-10, demande de l'utilisateur) : il part du milieu des cryptes,
## marche même quand le héros est sur l'étage, prend les passages entre les cryptes et l'étage (jamais vers la
## bibliothèque ni le laboratoire), et entre dans la salle du héros par le passage s'il arrive d'un autre niveau.
## Les geôliers ne changent pas de niveau. Un combat l'attire depuis l'autre niveau : il prend l'escalier le plus proche
## et vient jusqu'à la salle du combat (dans les deux sens).
## godot --headless --path . -s tests/test_chevalier_niveaux.gd

var echecs := 0


func verifier(condition: bool, cas: String) -> void:
	if not condition:
		echecs += 1
		print("ÉCHEC ", cas)


func _ou_est_le_chevalier(donjon) -> Array:
	for n in donjon.plan_donjon:
		for c in Aventure.chasseurs(donjon, int(n)):
			if c[0]["genre"] == "imbattable" and not c[0].get("karma", false):
				return [int(n), c[1], c[0]]
	return []


func _initialize() -> void:
	seed(1110)
	var sorties := 0
	var retours := 0
	var entrees_par_passage := 0
	for k in 6:
		Sauvegarde.reinitialiser_monde()
		var donjon := Donjon.nouveau(Personnage.nouveau())
		var o := _ou_est_le_chevalier(donjon)
		verifier(not o.is_empty() and o[0] == Donjon.NIVEAU_CRYPTES, "%d : le chevalier part des cryptes" % k)
		# Le héros attend dans un couloir de l'étage qui mène aux cryptes
		var couloir := ""
		for i in donjon.plan_donjon[1]:
			var lien = donjon.plan_donjon[1][i].get("passage_niveau", null)
			if lien is Dictionary and int(lien["niveau"]) == Donjon.NIVEAU_CRYPTES:
				couloir = i
				break
		verifier(couloir != "", "%d : un couloir mène aux cryptes" % k)
		donjon.salle_actuelle = [1, int(couloir)]
		var geoliers_avant := Aventure.chasseurs(donjon, 1).filter(func(c): return c[0]["genre"] == "geolier").size()
		var niveau := Donjon.NIVEAU_CRYPTES
		for t in 4 * 3600:
			for c in Aventure.avancer_chasseurs(donjon, 1.0):
				if c[0]["genre"] == "imbattable" and Aventure.autre_niveau(str(c[1])):
					entrees_par_passage += 1
					verifier(PlanSalles.sortie_vers(donjon.salle_courante(), str(c[1])) >= 0,
						"%d : il entre par la sortie du passage" % k)
					# Il repart (le test ne joue pas la salle du héros) : on le remet dans sa salle de départ
					Aventure.changer_de_salle(donjon, c[0], couloir, str(c[1]), 1)
			var ici := _ou_est_le_chevalier(donjon)
			verifier(not ici.is_empty() and Aventure.niveau_du_chevalier(ici[0]), "%d : jamais en bibliothèque ou laboratoire" % k)
			if ici.is_empty():
				break
			if ici[0] != niveau:
				if ici[0] == Donjon.NIVEAU_CRYPTES:
					retours += 1
				else:
					sorties += 1
				niveau = ici[0]
		var geoliers_apres := Aventure.chasseurs(donjon, 1).filter(func(c): return c[0]["genre"] == "geolier").size()
		verifier(geoliers_apres == geoliers_avant, "%d : les geôliers restent sur l'étage" % k)
		verifier(Aventure.chasseurs(donjon, Donjon.NIVEAU_CRYPTES).all(func(c): return c[0]["genre"] != "geolier"),
			"%d : aucun geôlier dans les cryptes" % k)
	_combat_entendu()
	print("Sur 6 parties de 4 h : %d sorties des cryptes, %d retours, %d entrées chez le héros par le passage" %
		[sorties, retours, entrees_par_passage])
	verifier(sorties > 0, "le chevalier sort des cryptes")
	verifier(entrees_par_passage > 0, "il arrive chez le héros par le passage")
	print("BILAN chevalier entre niveaux : %d échec(s)" % echecs)
	quit(1 if echecs else 0)


## Combat sur l'étage, chevalier au milieu des cryptes (et l'inverse) : il arrive dans la salle du combat.
func _combat_entendu() -> void:
	for k in 6:
		Sauvegarde.reinitialiser_monde()
		var donjon := Donjon.nouveau(Personnage.nouveau())
		var o := _ou_est_le_chevalier(donjon)
		if o.is_empty():
			verifier(false, "combat %d : pas de chevalier" % k)
			continue
		# Une salle de l'étage voisine d'un couloir des cryptes (pas l'escalier lui-même)
		var cible := ""
		for i in donjon.plan_donjon[1]:
			var lien = donjon.plan_donjon[1][i].get("passage_niveau", null)
			if lien is Dictionary and int(lien["niveau"]) == Donjon.NIVEAU_CRYPTES:
				for v in donjon.plan_donjon[1][i]["connections"]:
					if Aventure.ouverte_au(donjon.plan_donjon[1], o[2], str(v)) and not donjon.plan_donjon[1][str(v)].has("passage_niveau"):
						cible = str(v)
				break
		for sens in ["étage", "cryptes"]:
			var niveau := 1 if sens == "étage" else Donjon.NIVEAU_CRYPTES
			var salle := cible
			if sens == "cryptes":
				# Le chevalier est sur l'étage (il vient d'arriver) ; combat au milieu des cryptes
				salle = Aventure.centre_etage(donjon, Donjon.NIVEAU_CRYPTES)
			donjon.salle_actuelle = [niveau, int(salle)]
			Aventure.attirer(donjon)
			var arrive := -1
			for t in 1200:
				for c in Aventure.avancer_chasseurs(donjon, 1.0):
					if c[0]["genre"] == "imbattable":
						arrive = t
						verifier(bool(c[0].get("cherche", false)), "combat %d (%s) : il sait où est le héros" % [k, sens])
				if arrive >= 0:
					break
			verifier(arrive >= 0, "combat %d (%s) : le chevalier vient depuis l'autre niveau" % [k, sens])
			if k == 0:
				print("Combat dans les %s : chevalier arrivé en %d s" % [sens, arrive])
			var ici := _ou_est_le_chevalier(donjon)
			verifier(not ici.is_empty() and ici[0] == niveau and ici[1] == salle, "combat %d (%s) : il est dans la salle du combat" % [k, sens])
