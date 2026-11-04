extends SceneTree
## Ennemis interdits dans une salle (éditeur de zones, couche « Ennemis », 2026-11-04). Sur 4 donjons, on interdit
## (sans rien écrire : cache d'Aventure) tous les ennemis dans un tiers des images de salles, et les squelettes dans un
## autre tiers. Après la préparation de l'étage puis 10 minutes de ronde des chasseurs et une poursuite : aucun
## ennemi interdit dans ces salles.   « BILAN ennemis interdits : 0 échec(s) »
## godot --headless --path . -s tests/test_ennemis_interdits.gd

var echecs := 0


func verifier(condition: bool, cas: String) -> void:
	if not condition:
		echecs += 1
		print("ÉCHEC ", cas)


func controler(donjon, n: int, moment: String) -> int:
	var fautes := 0
	var salles: Dictionary = donjon.plan_donjon[1]
	for i in salles:
		for p in salles[i].get("presences", []):
			if p.get("genre", "") in Aventure.ENNEMIS and p.get("etat", "actif") == "actif" and Aventure.interdite_a(salles[i], p):
				fautes += 1
				verifier(false, "%d %s : %s (%s) dans la salle %s qui l'interdit" % [n, moment, p["genre"], Aventure.sortes_presence(p), i])
	return fautes


func _initialize() -> void:
	seed(808)
	Ecrans.auto = true
	var vides := 0
	var bloques := 0
	for n in 4:
		Sauvegarde.reinitialiser_monde()
		Aventure.vider_interdits()
		var donjon := Donjon.nouveau(Personnage.nouveau())
		# Donjon.nouveau a déjà préparé l'étage : on interdit puis on refait la préparation
		var salles: Dictionary = donjon.plan_donjon[1]
		var images := {}
		for i in salles:
			var im := String(salles[i].get("salle_peinte", {}).get("image", ""))
			if im != "" and not salles[i].get("boss", false) and not salles[i].get("depart", false):
				images[im] = true
		var k := 0
		var interdites := []
		for im in images:
			if k % 3 == 0:
				Aventure._interdits[im] = Aventure.SORTES_SALLE.duplicate()
				interdites.append(im)
			elif k % 3 == 1:
				Aventure._interdits[im] = ["squelette", "loup"]
			else:
				Aventure._interdits[im] = []
			k += 1
		for i in salles:
			salles[i]["presences"] = []
		Aventure.meta(donjon, 1)["prepare"] = false
		Aventure.preparer_etage(donjon, 1)
		controler(donjon, n, "préparation")
		for i in salles:
			if String(salles[i].get("salle_peinte", {}).get("image", "")) in interdites:
				vides += 1
				if salles[i].get("presences", []).any(func(p): return p.get("genre", "") in Aventure.ENNEMIS):
					bloques += 1
		# Ronde de 10 minutes, héros au départ
		for _t in 600:
			Aventure.avancer_chasseurs(donjon, 1.0)
			if controler(donjon, n, "ronde") > 0:
				break
		# Poursuite vers une salle interdite à tous : personne n'y entre
		var cible := ""
		for i in salles:
			if String(salles[i].get("salle_peinte", {}).get("image", "")) in interdites and not salles[i].has("bloc"):
				cible = i
		if cible != "":
			donjon.salle_actuelle = [1, int(cible)]
			Aventure.attirer(donjon)
			for _t in 300:
				for e in Aventure.avancer_chasseurs(donjon, 1.0):
					verifier(false, "%d : %s entre dans la salle %s qui lui est interdite" % [n, e[0]["genre"], cible])
				if controler(donjon, n, "poursuite") > 0:
					break
	print("Salles où tout est interdit : %d, dont %d avec un ennemi" % [vides, bloques])
	verifier(bloques == 0, "aucun ennemi dans les salles où tout est interdit")
	Aventure.vider_interdits()
	print("BILAN ennemis interdits : %d échec(s)" % echecs)
	quit()
