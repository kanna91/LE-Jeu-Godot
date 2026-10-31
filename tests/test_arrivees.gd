extends SceneTree
## Arrivées cohérentes d'une salle peinte à l'autre (PlanSalles.sortie_vers).
##
## Sur de nombreux étages générés, pour chaque passage d'une salle A vers sa voisine B :
## - le héros arrive en B devant une ouverture peinte qui mène à A (sinon : passage sans porte, compté) ;
## - quand deux ouvertures de B mènent à A, il arrive par une vraie porte plutôt que par un passage
##   (salle porte 6 : porte de gauche, pas le passage de gauche) ;
## - s'il était sorti de B vers A par une ouverture précise, il revient devant elle (« sortie_prise »).
## godot --headless --path godot -s tests/test_arrivees.gd

var echecs := 0


func verifier(condition: bool, cas: String) -> void:
	if not condition:
		echecs += 1
		print("ÉCHEC ", cas)


func _initialize() -> void:
	var passages := 0
	var sans_porte := 0
	var choix := 0
	var porte6 := 0
	for graine in 40:
		seed(graine)
		Sauvegarde.reinitialiser_monde()
		var donjon = Donjon.nouveau(Personnage.nouveau())
		for etage in range(1, 4):
			if not donjon.plan_donjon.has(etage):
				donjon.generer_etage(etage)
			PlanSalles.attribuer(donjon, etage)
			var salles: Dictionary = donjon.plan_donjon[etage]
			for a in salles:
				var info_a: Dictionary = salles[a]["salle_peinte"]
				sans_porte += info_a.get("sans_porte", []).size()
				for dest in info_a["sorties"]:
					if dest == null:
						continue
					var b: Dictionary = salles[str(dest)]
					var info_b: Dictionary = b["salle_peinte"]
					passages += 1
					var arrivee := PlanSalles.sortie_vers(b, str(a))
					var candidates := []
					for i in info_b["sorties"].size():
						if info_b["sorties"][i] != null and str(info_b["sorties"][i]) == str(a):
							candidates.append(i)
					if candidates.is_empty():
						continue  # A est reliée à B par un passage sans porte peinte (flèche)
					verifier(arrivee in candidates, "étage %d : %s → %s, arrivée %d hors des ouvertures %s" % [etage, a, dest, arrivee, candidates])
					var types := PlanSalles.types_sorties(String(info_b["image"]))
					if candidates.size() > 1:
						choix += 1
						var une_porte := false
						for i in candidates:
							une_porte = une_porte or types[i] == "porte"
						verifier(not une_porte or types[arrivee] == "porte",
							"étage %d : %s → %s (%s) : arrivée par un passage alors qu'une porte y mène" % [etage, a, dest, info_b["image"]])
						if info_b["image"] == "porte6":
							porte6 += 1
						# Sorti de B vers A par la dernière ouverture : on revient devant elle
						var prise: int = candidates[-1]
						info_b["sortie_prise"] = {str(a): prise}
						verifier(PlanSalles.sortie_vers(b, str(a)) == prise, "retour par l'ouverture prise (%s)" % info_b["image"])
						info_b.erase("sortie_prise")
	print("%d passages, %d avec deux ouvertures vers la même salle (dont %d en salle porte 6), %d passages sans porte peinte" % [
		passages, choix, porte6, sans_porte])
	print("BILAN arrivées : %d échec(s)" % echecs)
	quit(1 if echecs else 0)
