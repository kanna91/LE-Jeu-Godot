extends SceneTree
## Blocs de salles (BlocsSalles, 2026-10-31) : sur 30 donjons de 5 étages, chaque étage a son bloc cuisine, posé sur
## des cases libres, avec ses liens porte à porte (salle à manger → cuisine → petite porte → celliers) et ses deux
## entrées raccordées au reste de l'étage ; ses images ne servent nulle part ailleurs ; chaque sortie mène là où il
## faut, et revenir par la même porte ramène dans la salle d'où l'on vient ; tout l'étage reste accessible.
## godot --headless --path . -s tests/test_blocs.gd

var echecs := 0


func verifier(condition: bool, cas: String) -> void:
	if not condition:
		echecs += 1
		print("ÉCHEC ", cas)


func _initialize() -> void:
	seed(1031)
	var etages := 0
	var deux_entrees := 0
	for k in 30:
		Sauvegarde.reinitialiser_monde()
		var donjon := Donjon.nouveau(Personnage.nouveau())
		for etage in donjon.plan_donjon:
			if Donjon.est_niveau_unique(etage):
				continue  # cryptes : pas de bloc cuisine (2026-11-03)
			etages += 1
			if _etage(donjon.plan_donjon[etage], "%d/%d" % [k, etage]):
				deux_entrees += 1
	print("Étages : %d, bloc cuisine à deux entrées : %d" % [etages, deux_entrees])
	verifier(deux_entrees == etages, "toujours deux entrées raccordées (%d / %d)" % [deux_entrees, etages])
	print("BILAN blocs : %d échec(s)" % echecs)
	quit(1 if echecs else 0)


## Vérifie un étage ; vrai si ses deux entrées mènent au reste de l'étage.
func _etage(salles: Dictionary, nom: String) -> bool:
	var b: Dictionary = BlocsSalles.BLOCS["cuisine"]
	var ids := {}
	for id in salles:
		var s: Dictionary = salles[id]
		if s.get("bloc") == "cuisine":
			ids[s["bloc_salle"]] = id
		elif s.has("salle_peinte"):
			verifier(not BlocsSalles.image_de_bloc(String(s["salle_peinte"].get("image", ""))), "%s : image de bloc hors bloc" % nom)
	verifier(ids.size() == b["salles"].size(), "%s : bloc cuisine complet (%d salles)" % [nom, ids.size()])
	if ids.size() != b["salles"].size():
		return false
	# Positions et images
	var origine: Vector2i = salles[ids["manger"]]["position"]
	for cle in ids:
		var s: Dictionary = salles[ids[cle]]
		verifier(s["position"] == origine + b["salles"][cle]["position"], "%s : position de %s" % [nom, cle])
		verifier(s["salle_peinte"]["image"] == b["salles"][cle]["image"], "%s : image de %s" % [nom, cle])
		verifier(not s["salle_peinte"]["miroir"], "%s : %s jamais en miroir" % [nom, cle])
		for autre in salles:
			if autre != ids[cle]:
				verifier(salles[autre]["position"] != s["position"], "%s : case de %s partagée" % [nom, cle])
	# Liens porte à porte, dans les deux sens
	for l in b["liens"]:
		var a: Dictionary = salles[ids[l[0]]]
		var c: Dictionary = salles[ids[l[2]]]
		verifier(str(a["salle_peinte"]["sorties"][l[1]]) == ids[l[2]], "%s : %s mène à %s" % [nom, l[0], l[2]])
		verifier(str(c["salle_peinte"]["sorties"][l[3]]) == ids[l[0]], "%s : %s ramène à %s" % [nom, l[2], l[0]])
		verifier(PlanSalles.sortie_vers(c, ids[l[0]]) == l[3], "%s : retour de %s par la bonne porte" % [nom, l[2]])
		verifier(ids[l[2]] in a["connections"] and ids[l[0]] in c["connections"], "%s : %s et %s reliés au plan" % [nom, l[0], l[2]])
	# Chaque connexion d'une salle du bloc a sa porte (aucun passage sans porte peinte)
	for cle in ids:
		var s: Dictionary = salles[ids[cle]]
		for conn in s["connections"]:
			verifier(PlanSalles.sortie_vers(s, str(conn)) >= 0, "%s : %s → %s sans porte" % [nom, cle, conn])
	# Entrées : une salle extérieure (hors bloc) derrière chacune, du bon côté
	var raccordees := 0
	for e in b["entrees"]:
		var s: Dictionary = salles[ids[e[0]]]
		var dehors = s["salle_peinte"]["sorties"][e[1]]
		if dehors != null and salles.has(str(dehors)) and not salles[str(dehors)].has("bloc"):
			raccordees += 1
			verifier(salles[str(dehors)]["position"] == s["position"] + e[2], "%s : entrée %s du bon côté" % [nom, e[0]])
			verifier(PlanSalles.sortie_vers(salles[str(dehors)], ids[e[0]]) >= 0, "%s : la salle extérieure a une porte vers %s" % [nom, e[0]])
	# Tout l'étage accessible depuis le départ
	var vus := {"1": true}
	var file := ["1"]
	while not file.is_empty():
		var c: String = file.pop_front()
		for v in salles[c]["connections"]:
			if not vus.has(str(v)):
				vus[str(v)] = true
				file.append(str(v))
	verifier(vus.size() == salles.size(), "%s : tout l'étage accessible (%d / %d)" % [nom, vus.size(), salles.size()])
	return raccordees == b["entrees"].size()
