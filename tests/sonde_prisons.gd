extends SceneTree
## Sonde : prisons hors de leur quartier, passages sans porte peinte, carrefours (salles à 3-4 passages) par quartier,
## sur 20 donjons de 5 étages.
## godot --headless --path . -s tests/sonde_prisons.gd


func _initialize() -> void:
	seed(77)
	var hors := 0
	var sans_porte := 0
	var etages := 0
	var c := {"tous": 0, "cryptes": 0, "prisons": 0, "4": 0, "salles": 0, "sans_porte_degre": {}}
	for k in 20:
		Sauvegarde.reinitialiser_monde()
		var donjon := Donjon.nouveau(Personnage.nouveau())
		for et in donjon.plan_donjon:
			etages += 1
			var sl: Dictionary = donjon.plan_donjon[et]
			var q := PlanSalles.quartier_prisons(sl)
			var cr := PlanSalles.quartier_cryptes(sl, q)
			for i in sl:
				c["salles"] += 1
				var info: Dictionary = sl[i]["salle_peinte"]
				var d: int = PlanSalles.voisines_carte(sl, String(i)).size()
				if d >= 3:
					c["tous"] += 1
					if cr.has(String(i)):
						c["cryptes"] += 1
					if q.has(String(i)):
						c["prisons"] += 1
				if d == 4:
					c["4"] += 1
				if PlanSalles.est_prison(String(info["image"])) and not q.has(String(i)):
					hors += 1
				var n: int = info.get("sans_porte", []).size()
				sans_porte += n
				if n > 0:
					c["sans_porte_degre"][d] = c["sans_porte_degre"].get(d, 0) + 1
	print("SONDE étages %d : prisons hors quartier %d, passages sans porte %d ; %s" % [etages, hors, sans_porte, c])
	quit()
