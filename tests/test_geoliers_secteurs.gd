extends SceneTree
## Geôliers par secteur (2026-11-04, décision de l'utilisateur) : sur 8 donjons, 5 geôliers par étage (4 coins et le
## centre) ; territoire d'un geôlier de coin d'au moins Aventure.TERRITOIRE_MIN salles, dont au moins
## Aventure.MORSURE_CENTRE du centre ; chacun part dans son territoire. 10 minutes de ronde (au moins 10 salles vues) puis 5 minutes de poursuite
## vers une salle d'un coin : aucun geôlier ne sort de son territoire, jamais plus de 2 geôliers dans une salle, le
## geôlier du coin rejoint le héros. Capture par un geôlier de coin : réveil dans sa prison.
## godot --headless --path . -s tests/test_geoliers_secteurs.gd

var echecs := 0


func verifier(condition: bool, cas: String) -> void:
	if not condition:
		echecs += 1
		print("ÉCHEC ", cas)


func geoliers(donjon) -> Array:
	return Aventure.chasseurs(donjon, 1).filter(func(c): return c[0]["genre"] == "geolier")


## Vérifie territoires et nombre par salle ; renvoie le nombre de fautes.
func controler(donjon, n: int, moment: String) -> int:
	var fautes := 0
	var par_salle := {}
	for c in geoliers(donjon):
		par_salle[c[1]] = int(par_salle.get(c[1], 0)) + 1
		if c[0].has("territoire") and not (c[1] in c[0]["territoire"]):
			fautes += 1
			verifier(false, "%d %s : geôlier %d hors de son territoire (salle %s)" % [n, moment, c[0]["secteur"], c[1]])
	for i in par_salle:
		if par_salle[i] > Aventure.MAX_GEOLIERS_PAR_SALLE:
			fautes += 1
			verifier(false, "%d %s : %d geôliers dans la salle %s" % [n, moment, par_salle[i], i])
	return fautes


func _initialize() -> void:
	seed(404)
	Ecrans.auto = true
	var tailles := []
	var morsures := []
	var visites := []
	for n in 8:
		Sauvegarde.reinitialiser_monde()
		var donjon := Donjon.nouveau(Personnage.nouveau())
		var salles: Dictionary = donjon.plan_donjon[1]
		var depart := ""
		for i in salles:
			if salles[i].get("depart", false):
				depart = i
		var liste := geoliers(donjon)
		verifier(liste.size() == Aventure.GEOLIERS_PAR_ETAGE, "%d : %d geôliers (voulu %d)" % [n, liste.size(), Aventure.GEOLIERS_PAR_ETAGE])
		var secteurs := {}
		for c in liste:
			var p: Dictionary = c[0]
			secteurs[int(p.get("secteur", -1))] = true
			verifier(c[1] in p.get("territoire", []), "%d : geôlier %d part dans son territoire" % [n, p.get("secteur", -1)])
			if int(p.get("secteur", -1)) != GenerateurEtage.CENTRE:
				var terr: Array = p["territoire"]
				var morsure := terr.filter(func(i): return int(salles[i].get("secteur", -1)) == GenerateurEtage.CENTRE).size()
				tailles.append(terr.size())
				morsures.append(morsure)
				verifier(terr.size() >= Aventure.TERRITOIRE_MIN, "%d : coin %d, %d salles" % [n, p["secteur"], terr.size()])
				verifier(morsure >= Aventure.MORSURE_CENTRE, "%d : coin %d mord %d salles du centre" % [n, p["secteur"], morsure])
			else:
				tailles.append(-p["territoire"].size())
		verifier(secteurs.size() == 5, "%d : un geôlier par secteur" % n)
		# Ronde : 10 minutes, le héros dans la bibliothèque (aucun geôlier n'y entre)
		var refuge := depart
		for i in salles:
			if salles[i].get("bloc", "") == "bibliotheque":
				refuge = i
		donjon.salle_actuelle = [1, int(refuge)]
		var vues := {}
		for _t in 600:
			Aventure.avancer_chasseurs(donjon, 1.0)
			for c in geoliers(donjon):
				var k := int(c[0]["secteur"])
				if not vues.has(k):
					vues[k] = {}
				vues[k][c[1]] = true
			if controler(donjon, n, "ronde") > 0:
				break
		for k in vues:
			visites.append(vues[k].size())
			verifier(vues[k].size() >= 10, "%d : le geôlier %d parcourt au moins 10 salles en 10 min (%d)" % [n, k, vues[k].size()])
		# Poursuite : le héros dans une salle du coin 0 ; tous les geôliers sont attirés
		var cible := ""
		for c in geoliers(donjon):
			if int(c[0]["secteur"]) == 0:
				for i in c[0]["territoire"]:
					if int(salles[i].get("secteur", -1)) == 0 and not salles[i].has("prison"):
						cible = i
		if cible == "":
			verifier(false, "%d : pas de salle dans le coin 0" % n)
			continue
		donjon.salle_actuelle = [1, int(cible)]
		Aventure.attirer(donjon)
		var arrive := false
		for _t in 300:
			for e in Aventure.avancer_chasseurs(donjon, 1.0):
				if e[0]["genre"] == "geolier" and int(e[0]["secteur"]) == 0:
					arrive = true
			if controler(donjon, n, "poursuite") > 0:
				break
		verifier(arrive, "%d : le geôlier du coin 0 rejoint le héros dans son coin" % n)
		# Capture par le geôlier du coin 2 : réveil dans la prison 2
		for c in geoliers(donjon):
			if int(c[0]["secteur"]) == 2:
				Aventure.capturer(donjon, c[0])
				var ou: Dictionary = salles[str(donjon.salle_actuelle[1])]
				verifier(int(ou.get("prison", -1)) == 2, "%d : capturé par le geôlier du coin 2, réveil dans sa prison (%s)" % [n, ou.get("prison", -1)])
		controler(donjon, n, "après capture")
	print("Territoires (coins ; centre en négatif) : %s" % [tailles])
	print("Morsures sur le centre : %s ; salles parcourues en 10 min : %s" % [morsures, visites])
	print("BILAN geôliers par secteur : %d échec(s)" % echecs)
	quit()
