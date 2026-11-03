extends SceneTree
## Retour dans la salle précédente : le héros réapparaît là où il avait franchi la sortie (2026-11-02).
## Pour des sorties de chaque côté (bas, gauche, droite, fond), le héros entre dans la sortie à un endroit précis,
## passe dans la salle voisine, revient aussitôt : il doit être à moins de 80 px de cet endroit (60 avant le 2026-11-03 : sorties plus hautes retracées dans l'éditeur), hors de la sortie.
## « BILAN retour : 0 échec(s) ».  godot --headless --path . -s tests/test_retour_salle.gd

var racine: Control
var echecs := 0
var essais := 0


func _initialize() -> void:
	racine = Control.new()
	racine.size = Vector2(960, 540)
	root.add_child(racine)
	Ecrans.racine = racine
	lancer()


func attendre(images: int) -> void:
	for _i in images:
		await process_frame


func calmer(salle: Dictionary) -> void:
	salle["visitee"] = true
	salle.erase("evenement")
	salle["ennemis"] = []
	salle["presences"] = []


func lancer() -> void:
	seed(7)
	Sauvegarde.reinitialiser_monde()
	Statistiques.mort = false
	Ecrans.auto = true
	var joueur = Personnage.nouveau()
	var donjon = Donjon.nouveau(joueur)
	var etage := 1
	PlanSalles.attribuer(donjon, etage)
	var salles: Dictionary = donjon.plan_donjon[etage]
	for id in salles:
		calmer(salles[id])
	var vus := {}
	for id in salles:
		if essais >= 12:
			break
		donjon.salle_actuelle = [etage, int(id)]
		var nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
		racine.add_child(nav)
		await attendre(3)
		var sp = nav.salle_peinte
		var sorties: Array = salles[id]["salle_peinte"]["sorties"]
		var dirs: Array = sp.directions_sorties()
		for i in sorties.size():
			var cote: String = dirs[i] if i < dirs.size() else "?"
			if sorties[i] == null or vus.get(cote, 0) >= 3 or i in sp.sorties_murees:
				continue
			# Un point de la sortie décalé du centre (vers un coin), sur le sol si possible
			var poly: PackedVector2Array = sp.donnees["sorties"][i]
			var c: Vector2 = sp.centre_sortie(i)
			var point := c
			for p in poly:
				var q: Vector2 = c.lerp(p, 0.6)
				if Geometry2D.is_point_in_polygon(q, poly) and sp.libre(q):
					point = q
					break
			vus[cote] = vus.get(cote, 0) + 1
			essais += 1
			var dest := str(sorties[i])
			sp.heros.position = point
			await nav._franchir(dest, i)
			await attendre(2)
			var j := PlanSalles.sortie_vers(donjon.salle_courante(), id)
			await nav._franchir(id, j)
			await attendre(2)
			sp = nav.salle_peinte
			var d: float = sp.heros.position.distance_to(point)
			var dans: bool = sp._sortie_sous(sp.heros.position) >= 0
			var ok: bool = str(donjon.salle_actuelle[1]) == id and d < 80.0 and not dans
			print("%s salle %s (%s) sortie %d « %s » : franchie en %s, revenu en %s (écart %d px)%s" % [
				"ok" if ok else "ÉCHEC", id, salles[id]["salle_peinte"]["image"], i, cote, point.round(),
				sp.heros.position.round(), d, " DANS la sortie" if dans else ""])
			if not ok:
				echecs += 1
		nav.queue_free()
		await attendre(2)
	print("BILAN retour : %d échec(s) sur %d essais" % [echecs, essais])
	quit()
