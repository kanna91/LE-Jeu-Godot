extends SceneTree
## Blocs de salles (BlocsSalles, 2026-10-31) : sur 30 donjons de 5 étages, chaque étage a son bloc cuisine, posé sur
## des cases libres, avec ses liens porte à porte (salle à manger → cuisine → petite porte → celliers) et ses deux
## entrées raccordées au reste de l'étage ; ses images ne servent nulle part ailleurs ; chaque sortie mène là où il
## faut, et revenir par la même porte ramène dans la salle d'où l'on vient ; tout l'étage reste accessible.
## Bloc bibliothèque (2026-11-04) : mêmes vérifications, plus : complexe fermé (aucun passage vers l'étage hors de ses
## deux entrées) et refuge (Zones.refuge : ni ennemis, ni geôlier, ni Chevalier de la mort).
## godot --headless --path . -s tests/test_blocs.gd

var echecs := 0


func verifier(condition: bool, cas: String) -> void:
	if not condition:
		echecs += 1
		print("ÉCHEC ", cas)


func _initialize() -> void:
	seed(1031)
	var etages := 0
	var deux_entrees := {}
	for k in 30:
		Sauvegarde.reinitialiser_monde()
		var donjon := Donjon.nouveau(Personnage.nouveau())
		for etage in donjon.plan_donjon:
			if Donjon.est_niveau_unique(etage):
				continue  # cryptes : pas de bloc cuisine (2026-11-03)
			etages += 1
			for bloc in BlocsSalles.BLOCS:
				if _etage(donjon.plan_donjon[etage], "%d/%d %s" % [k, etage, bloc], bloc):
					deux_entrees[bloc] = deux_entrees.get(bloc, 0) + 1
	for bloc in BlocsSalles.BLOCS:
		print("Étages : %d, bloc %s : toutes ses entrées raccordées sur %d étages" % [etages, bloc, deux_entrees.get(bloc, 0)])
		verifier(deux_entrees.get(bloc, 0) == etages, "bloc %s : toujours toutes ses entrées raccordées (%d / %d)" % [bloc, deux_entrees.get(bloc, 0), etages])
	print("BILAN blocs : %d échec(s)" % echecs)
	quit(1 if echecs else 0)


## Vérifie un étage ; vrai si ses deux entrées mènent au reste de l'étage.
func _etage(salles: Dictionary, nom: String, bloc: String) -> bool:
	var b: Dictionary = BlocsSalles.BLOCS[bloc]
	var ids := {}
	for id in salles:
		var s: Dictionary = salles[id]
		if s.get("bloc") == bloc:
			ids[s["bloc_salle"]] = id
		elif not s.has("bloc") and s.has("salle_peinte"):
			verifier(not BlocsSalles.image_de_bloc(String(s["salle_peinte"].get("image", ""))), "%s : image de bloc hors bloc" % nom)
	verifier(ids.size() == b["salles"].size(), "%s : bloc complet (%d salles)" % [nom, ids.size()])
	if ids.size() != b["salles"].size():
		return false
	# Positions et images
	var premiere: String = b["salles"].keys()[0]
	var origine: Vector2i = salles[ids[premiere]]["position"] - b["salles"][premiere]["position"]
	for cle in ids:
		var s: Dictionary = salles[ids[cle]]
		verifier(s["position"] == origine + b["salles"][cle]["position"], "%s : position de %s" % [nom, cle])
		verifier(s["salle_peinte"]["image"] == b["salles"][cle]["image"], "%s : image de %s" % [nom, cle])
		verifier(bool(s["salle_peinte"]["miroir"]) == bool(b["salles"][cle].get("miroir", false)), "%s : %s en miroir comme prévu" % [nom, cle])
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
	# Laboratoire (2026-11-04, structure cohérente) : chaque porte mène du côté où elle est (miroir compris) et arrive
	# par la porte d'en face (fond → bas, gauche → droite)
	# Depuis le 2026-11-04 : tous les blocs (bibliothèque refaite, jardin), sauf les liens vers les celliers de la cuisine
	# (on y entre par le bas de leur image : exception acceptée par l'utilisateur le 2026-10-31)
	if true:
		for l in b["liens"]:
			if String(l[2]).begins_with("cellier"):
				continue
			var sa: Dictionary = salles[ids[l[0]]]
			var sb: Dictionary = salles[ids[l[2]]]
			var da := PlanSalles.absolue(PlanSalles.directions(sa["salle_peinte"]["image"], sa["salle_peinte"]["miroir"])[l[1]], PlanSalles.FACE)
			var db := PlanSalles.absolue(PlanSalles.directions(sb["salle_peinte"]["image"], sb["salle_peinte"]["miroir"])[l[3]], PlanSalles.FACE)
			verifier(da == sb["position"] - sa["position"] and db == sa["position"] - sb["position"],
				"%s : porte de %s vers %s du bon côté" % [nom, l[0], l[2]])
	# Chaque connexion d'une salle du bloc a sa porte (aucun passage sans porte peinte)
	for cle in ids:
		var s: Dictionary = salles[ids[cle]]
		for conn in s["connections"]:
			verifier(PlanSalles.sortie_vers(s, str(conn)) >= 0, "%s : %s → %s sans porte" % [nom, cle, conn])
	# Complexe fermé : hors des entrées, aucune salle du bloc ne mène hors du bloc
	var entrees_cles: Array = b["entrees"].map(func(e): return e[0])
	var vers_dehors := 0
	for cle in ids:
		for conn in salles[ids[cle]]["connections"]:
			if salles[str(conn)].get("bloc", "") != bloc:
				vers_dehors += 1
				verifier(cle in entrees_cles, "%s : %s mène hors du bloc sans être une entrée" % [nom, cle])
	verifier(vers_dehors <= b["entrees"].size(), "%s : %d passages vers l'étage (au plus %d)" % [nom, vers_dehors, b["entrees"].size()])
	if bloc == "cuisine":
		# Jardin (2026-11-04) : ni geôlier ni Chevalier de la mort ; pas un refuge (les autres ennemis peuvent y être)
		for cle in ids:
			var s: Dictionary = salles[ids[cle]]
			if String(s["salle_peinte"]["image"]).begins_with("bloc_jardin"):
				verifier(Zones.sans_chasseurs(s) and not Zones.refuge(s), "%s : %s sans chasseurs, pas un refuge" % [nom, cle])
				verifier(Aventure.fermee_a(s, "geolier") and Aventure.fermee_a(s, "imbattable") and not Aventure.fermee_a(s, "groupe"),
					"%s : %s fermé au geôlier et au chevalier, ouvert aux autres" % [nom, cle])
				for p in s.get("presences", []):
					verifier(not (p.get("genre", "") in Aventure.CHASSEURS), "%s : chasseur dans %s" % [nom, cle])
	if bloc in ["bibliotheque", "laboratoire"]:
		for cle in ids:
			verifier(Zones.refuge(salles[ids[cle]]), "%s : %s est un refuge" % [nom, cle])
			for p in salles[ids[cle]].get("presences", []):
				verifier(not (p.get("genre", "") in Aventure.ENNEMIS), "%s : ennemi %s dans %s" % [nom, p.get("genre"), cle])
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
