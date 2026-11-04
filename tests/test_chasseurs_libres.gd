extends SceneTree
## Chasseurs jamais enfermés (2026-11-04) : sur 15 donjons, chaque geôlier et chaque Chevalier de la mort peut aller
## dans toutes les salles qui lui sont ouvertes sans passer par une salle fermée (refuges : cuisine, bibliothèque,
## laboratoire ; jardin ; cryptes pour le geôlier). Garde-fou de GenerateurEtage._relier_sans_blocs.
## godot --headless --path . -s tests/test_chasseurs_libres.gd
func _initialize() -> void:
	seed(11)
	var bloques := 0
	var total := 0
	for n in 15:
		Sauvegarde.reinitialiser_monde()
		var d := Donjon.nouveau(Personnage.nouveau())
		for e in d.plan_donjon.keys().filter(func(x): return not Donjon.est_niveau_unique(x)):
			d.salle_actuelle = [e, 1]
			Aventure.preparer_etage(d, e)
			var salles: Dictionary = d.plan_donjon[e]
			for c in Aventure.chasseurs(d, e):
				var genre := String(c[0]["genre"])
				var vus := {str(c[1]): true}
				var f := [str(c[1])]
				while not f.is_empty():
					var x: String = f.pop_back()
					for v in salles[x].get("connections", []):
						var vs := str(v)
						if not vus.has(vs) and not Aventure.fermee_a(salles[vs], genre) and not salles[vs].get("boss", false):
							vus[vs] = true
							f.append(vs)
				var ouvertes := 0
				for i in salles:
					if not Aventure.fermee_a(salles[i], genre) and not salles[i].get("boss", false):
						ouvertes += 1
				total += 1
				if vus.size() < ouvertes:
					bloques += 1
					print("BLOQUÉ donjon %d étage %d %s : %d / %d" % [n, e, genre, vus.size(), ouvertes])
	print("chasseurs bloqués : %d sur %d" % [bloques, total])
	print("BILAN chasseurs libres : %d échec(s)" % bloques)
	quit()
