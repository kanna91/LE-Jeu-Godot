extends SceneTree
## Boss plus loin et fermé à clé, ennemis isolés (décisions de l'utilisateur, 2026-11-01) : sur 20 donjons de 5 étages,
## le boss (au centre de l'étage carré depuis le 2026-11-04 ; avant : à 35 à 40 salles du départ) n'a qu'un passage ; sa salle est
## fermée et ne s'ouvre qu'avec la clé du boss de l'étage, portée par une élite loin du départ ; vaincue, son corps
## donne la clé (fouillé ou siphonné) ; les ennemis isolés sont seuls, sans loup.
## godot --headless --path . -s tests/test_boss_cle.gd

var echecs := 0


func verifier(condition: bool, cas: String) -> void:
	if not condition:
		echecs += 1
		print("ÉCHEC ", cas)


func _initialize() -> void:
	seed(1101)
	Ecrans.auto = true
	var distances := []
	var isoles := 0
	var ennemis := 0
	var etages := 0
	for k in 20:
		Sauvegarde.reinitialiser_monde()
		var donjon := Donjon.nouveau(Personnage.nouveau())
		for e in donjon.plan_donjon:
			if Donjon.est_niveau_unique(e):
				continue  # cryptes : ni départ ni boss (2026-11-03)
			etages += 1
			var salles: Dictionary = donjon.plan_donjon[e]
			var depart := ""
			for i in salles:
				if salles[i].get("depart", false):
					depart = i
			var boss := str(donjon.salle_boss(e))
			var d := Aventure.distances_depuis(salles, depart)
			distances.append(int(d[boss]))
			# Étage carré (2026-11-04) : le boss au centre, une seule porte ; la clé suffit à l'éloigner (plus de distance imposée)
			verifier(d.has(boss) and salles[boss]["connections"].size() == 1, "%d/%d : boss au bout d'un seul passage" % [k, e])
			verifier(salles[boss].get("verrouillee", false) and salles[boss].get("cle_boss", false), "%d/%d : salle du boss fermée" % [k, e])
			var porteurs := []
			for i in salles:
				for p in salles[i].get("presences", []):
					if p.has("cle_boss"):
						porteurs.append([i, p])
					if p["genre"] == "groupe" and not p.get("pacifique", false):
						ennemis += Aventure.membres(p).size()
						if p.get("seul", false):
							isoles += 1
							verifier(Aventure.membres(p).size() == 1, "ennemi isolé : seul")
			verifier(porteurs.size() == 1, "%d/%d : une seule clé du boss (%d)" % [k, e, porteurs.size()])
			if porteurs.size() == 1:
				var p: Dictionary = porteurs[0][1]
				verifier(p["genre"] == "groupe" and p.get("elite", false), "%d/%d : la clé est portée par une élite" % [k, e])
				verifier(int(d[porteurs[0][0]]) >= Aventure.DISTANCE_CLE_BOSS, "%d/%d : élite à la clé loin du départ" % [k, e])
				verifier(porteurs[0][0] != boss, "%d/%d : la clé n'est pas dans la salle du boss" % [k, e])
	distances.sort()
	print("Distance du boss : %d à %d salles ; ennemis isolés : %.1f par étage ; ennemis hostiles : %.1f par étage" % [
		distances[0], distances[-1], float(isoles) / etages, float(ennemis) / etages])
	await _serrure()
	print("BILAN boss et clé : %d échec(s)" % echecs)
	quit(1 if echecs else 0)


## La serrure ne s'ouvre qu'avec la clé de l'étage ; le corps de l'élite la donne (fouillé ou siphonné).
func _serrure() -> void:
	Sauvegarde.reinitialiser_monde()
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	var boss := str(donjon.salle_boss(1))
	joueur._d["cles"] = 5
	var r := Aventure.ouvrir_verrou(donjon, boss)
	verifier(not r[0] and donjon.plan_donjon[1][boss]["verrouillee"], "sans clé du boss : fermée (les clés rouillées n'y font rien)")
	verifier(int(joueur.cles) == 5, "les clés rouillées ne sont pas gaspillées")
	# Corps de l'élite : la clé à la fouille
	donjon.salle_courante()["presences"] = []
	var corps := Aventure.laisser_cadavre(donjon, {"genre": "groupe", "nombre": 1, "elite": true, "cle_boss": 1, "membres": [{}], "etat": "vaincu"})
	verifier(corps.get("cle_boss") == 1, "le corps de l'élite garde la clé")
	for k in 30:
		if corps["etat"] != "actif":
			break
		await Aventure.cadavre(donjon, corps)
	verifier(Aventure.a_cle_boss(joueur, 1), "la clé du boss est prise sur le corps (fouillé ou siphonné)")
	r = Aventure.ouvrir_verrou(donjon, boss)
	verifier(r[0] and not donjon.plan_donjon[1][boss]["verrouillee"], "avec la clé : la salle du boss s'ouvre")
	verifier(not Aventure.a_cle_boss(joueur, 1), "la clé reste dans la serrure")
