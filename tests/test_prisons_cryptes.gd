extends SceneTree
## Prisons, niveau des cryptes et sorties potentielles (2026-11-03, demandes de l'utilisateur) :
## - un seul étage ; 4 prisons, une près de chaque coin de l'étage, faites de 2 grandes salles de prison puis d'un
##   couloir posé au-dessus de la 2e (on y entre par le bas) ; les 8 images « prison » servent une fois chacune, dans
##   les grandes salles des prisons seulement, les 4 couloirs une fois chacun ; le cachot est une grande salle de prison ;
## - aucune image « crypte » sur l'étage ; le niveau des cryptes (Donjon.NIVEAU_CRYPTES) : 14 salles d'un seul
##   tenant, les 14 images « crypte » une fois chacune, 4 entrées ; chaque couloir mène à une entrée et l'entrée
##   ramène au couloir (passages réciproques, sortie « passage » de l'image valide) ; seulement des squelettes,
##   une seule élite (le féticheur), ni boss ni cachot ;
## - sorties potentielles : une seule des sorties potentielles d'un côté est ouverte s'il y a une salle de ce côté,
##   aucune sinon, sans malus ; une sortie ordinaire du même côté passe avant elles ;
## - les geôliers ne vont jamais dans les cryptes (ni posés, ni entrés, ni déplacés ; ménage des anciennes parties).
## godot --headless --path . -s tests/test_prisons_cryptes.gd

var echecs := 0


func verifier(condition: bool, cas: String) -> void:
	if not condition:
		echecs += 1
		print("ÉCHEC ", cas)


func _initialize() -> void:
	seed(1103)
	_sorties_potentielles()
	var sans_porte := 0
	for k in 20:
		Sauvegarde.reinitialiser_monde()
		var donjon := Donjon.nouveau(Personnage.nouveau())
		verifier(donjon.plan_donjon.keys().filter(func(e): return not Donjon.est_niveau_unique(e)) == [1], "%d : un seul étage" % k)
		_etage(donjon, k)
		sans_porte += _cryptes(donjon, k)
		_geoliers(donjon, k)
		_chevalier_cryptes(donjon, k)
	print("Passages sans porte peinte dans les cryptes : %d sur 20 donjons" % sans_porte)
	print("BILAN prisons et cryptes : %d échec(s)" % echecs)
	quit(1 if echecs else 0)


## Le Chevalier de la mort commence chaque partie au milieu des cryptes (2026-11-10), plus sur l'étage.
func _chevalier_cryptes(donjon, k: int) -> void:
	var cryptes: Dictionary = donjon.plan_donjon[Donjon.NIVEAU_CRYPTES]
	var ou := []
	for c in Aventure.chasseurs(donjon, Donjon.NIVEAU_CRYPTES):
		if c[0]["genre"] == "imbattable":
			ou.append(c[1])
	verifier(ou.size() == Aventure.CHEVALIERS_PAR_ETAGE, "%d : un Chevalier de la mort dans les cryptes" % k)
	if not ou.is_empty():
		var ecart: int = Aventure.distances_depuis(cryptes, ou[0]).values().max()
		var ecart_min := 1 << 20
		for i in Aventure.salles_pour_ennemis(donjon, Donjon.NIVEAU_CRYPTES):
			if not Aventure.fermee_a(cryptes[i], "imbattable"):
				ecart_min = mini(ecart_min, Aventure.distances_depuis(cryptes, i).values().max())
		verifier(ecart == ecart_min, "%d : il part du milieu des cryptes (%d/%d)" % [k, ecart, ecart_min])
	Aventure.preparer_etage(donjon, 1)
	var sur_etage := Aventure.chasseurs(donjon, 1).filter(func(c): return c[0]["genre"] == "imbattable").size()
	verifier(sur_etage == int(Aventure.meta(donjon, 1).get("colere", 0)), "%d : pas de chevalier de départ sur l'étage" % k)


func _etage(donjon, k: int) -> void:
	var salles: Dictionary = donjon.plan_donjon[1]
	var positions := []
	for id in salles:
		if not salles[id].has("bloc"):  # coins de l'étage sans les blocs (2026-11-04)
			positions.append(salles[id]["position"])
	var coins := GenerateurEtage.coins(positions)
	var prisons := {}
	var images_prison := {}
	var couloirs := {}
	for id in salles:
		var s: Dictionary = salles[id]
		var image := String(s.get("salle_peinte", {}).get("image", ""))
		verifier(not PlanSalles.est_crypte(image), "%d : pas de crypte sur l'étage (%s)" % [k, image])
		if PlanSalles.est_prison(image):
			verifier(String(s.get("prison_salle", "")) in ["grande_a", "grande_b"], "%d : image de prison hors des prisons" % k)
			verifier(not images_prison.has(image), "%d : %s deux fois" % [k, image])
			images_prison[image] = true
		if PlanSalles.est_couloir_prison(image):
			verifier(s.get("prison_salle", "") == "couloir", "%d : couloir de prison hors des prisons" % k)
			couloirs[image] = true
		if s.has("prison"):
			if not prisons.has(int(s["prison"])):
				prisons[int(s["prison"])] = {}
			prisons[int(s["prison"])][s["prison_salle"]] = id
	var ecarts := []
	verifier(prisons.size() == 4, "%d : 4 prisons (%d)" % [k, prisons.size()])
	verifier(images_prison.size() == 8, "%d : les 8 grandes salles de prison (%d)" % [k, images_prison.size()])
	verifier(couloirs.size() == 4, "%d : les 4 couloirs (%d)" % [k, couloirs.size()])
	for p in prisons:
		var a: Dictionary = salles[prisons[p]["grande_a"]]
		var b: Dictionary = salles[prisons[p]["grande_b"]]
		var c: Dictionary = salles[prisons[p]["couloir"]]
		verifier(c["position"] - b["position"] == Vector2i(0, 1), "%d : couloir au-dessus de la 2e grande salle" % k)
		verifier(prisons[p]["grande_b"] in a["connections"] and prisons[p]["couloir"] in b["connections"], "%d : prison reliée" % k)
		verifier(c["connections"].size() == 1 and b["connections"].size() == 2, "%d : prison en impasse" % k)
		# Près de son coin (celui visé à la génération, avant les prisons)
		var ecart := GenerateurEtage._manhattan(c["position"], c["coin"])
		ecarts.append(ecart)
		# 4 cases au plus : en bas, le couloir est au-dessus de sa grande salle, elle-même au-dessus de la ligne du départ
		verifier(ecart <= GenerateurEtage.PROCHE_COIN + 2, "%d : prison %d près de son coin (%s, coin %s)" % [k, p, c["position"], c["coin"]])
		var info: Dictionary = c["salle_peinte"]
		var passage := int(info.get("passage", -1))
		verifier(passage >= 0 and PlanSalles.directions_carte(info)[passage] == Vector2i(0, 1), "%d : fond du couloir = passage" % k)
	print("%d : distance des couloirs à leur coin : %s" % [k, ecarts])
	var cachot := String(Aventure.meta(donjon, 1).get("cachot", ""))
	verifier(salles.has(cachot) and String(salles[cachot].get("prison_salle", "")) in ["grande_a", "grande_b"],
		"%d : cachot dans une grande salle de prison" % k)


## Renvoie le nombre de passages sans porte peinte dans les cryptes.
func _cryptes(donjon, k: int) -> int:
	var n := Donjon.NIVEAU_CRYPTES
	verifier(donjon.plan_donjon.has(n), "%d : niveau des cryptes" % k)
	var salles: Dictionary = donjon.plan_donjon.get(n, {})
	verifier(salles.size() == 14, "%d : 14 salles de crypte (%d)" % [k, salles.size()])
	verifier(Aventure.distances(salles).size() == salles.size(), "%d : cryptes d'un seul tenant" % k)
	var vues := {}
	var entrees := 0
	var sans_porte := 0
	var elites := 0
	for id in salles:
		var s: Dictionary = salles[id]
		var info: Dictionary = s.get("salle_peinte", {})
		verifier(PlanSalles.est_crypte(String(info.get("image", ""))), "%d : salle des cryptes sans image de crypte" % k)
		vues[info.get("image", "")] = true
		sans_porte += info.get("sans_porte", []).size()
		verifier(not s.get("boss", false) and not s.get("cachot", false) and not s.get("depart", false), "%d : ni boss ni cachot" % k)
		for p in s.get("presences", []):
			if p.get("genre") == "groupe":
				verifier(String(p.get("zone_ennemis", "")) == "crypte", "%d : groupe hors zone crypte" % k)
				for m in Aventure.membres(p):
					verifier(String(m.get("sous_classe")).ends_with("squelette") or m.get("sous_classe") == "feticheur", "%d : %s dans les cryptes" % [k, m.get("sous_classe")])
				if p.get("elite", false):
					elites += 1
			verifier(p.get("genre") in ["groupe", "pnj", "imbattable"], "%d : %s dans les cryptes" % [k, p.get("genre")])
		if s.has("passage_niveau"):
			entrees += 1
			var lien: Dictionary = s["passage_niveau"]
			var couloir: Dictionary = donjon.plan_donjon[int(lien["niveau"])].get(String(lien["salle"]), {})
			verifier(couloir.get("prison_salle", "") == "couloir", "%d : l'entrée ramène à un couloir" % k)
			verifier(String(couloir.get("passage_niveau", {}).get("salle", "")) == id, "%d : le couloir mène à cette entrée" % k)
			var passage := int(info.get("passage", -1))
			verifier(passage >= 0 and info["sorties"][passage] == null, "%d : entrée sans sortie de passage" % k)
			if passage >= 0:
				var d: Array = lien["direction"]
				verifier(PlanSalles.directions_carte(info)[passage] == Vector2i(int(d[0]), int(d[1])), "%d : passage du bon côté" % k)
	verifier(vues.size() == 14, "%d : les 14 images de crypte (%d)" % [k, vues.size()])
	verifier(entrees == 4, "%d : 4 entrées (%d)" % [k, entrees])
	verifier(elites == 1, "%d : une seule élite dans les cryptes (%d)" % [k, elites])
	return sans_porte


## Une image d'essai : 3 sorties potentielles à gauche, 1 ordinaire et 1 potentielle au fond, le retour.
func _sorties_potentielles() -> void:
	var image := "essai_potentielles"
	PlanSalles.images()[image] = ["gauche", "gauche", "gauche", "devant", "devant", "bas"]
	PlanSalles._types[image] = ["passage", "passage", "passage", "passage", "passage", "passage"]
	PlanSalles._grandes[image] = false
	PlanSalles._potentielles[image] = [true, true, true, false, true, false]
	var salles := {
		"1": {"position": Vector2i(0, 0), "connections": ["2", "3"]},
		"2": {"position": Vector2i(-1, 0), "connections": ["1"]},
		"3": {"position": Vector2i(0, 1), "connections": ["1"]},
		"4": {"position": Vector2i(5, 5), "connections": []},
	}
	var e := PlanSalles._evaluer(salles, "1", 1, image, false)
	var s: Array = e[1]["sorties"]
	var a_gauche := [s[0], s[1], s[2]].filter(func(x): return x != null)
	verifier(a_gauche == ["2"], "une seule sortie potentielle de gauche ouverte (%s)" % [s])
	verifier(s[3] == "3" and s[4] == null, "la sortie ordinaire du fond passe avant la potentielle (%s)" % [s])
	verifier(e[1]["sans_porte"].is_empty(), "aucun passage sans porte")
	# Sans salle à gauche : les sorties potentielles restent fermées, sans malus
	salles["1"]["connections"] = ["3"]
	var sans := PlanSalles._evaluer(salles, "1", 1, image, false)
	verifier(sans[1]["sorties"].slice(0, 3) == [null, null, null], "sorties potentielles fermées sans salle de ce côté")
	var malus: int = int(e[0]) - absi(hash([1, "1", image, false])) % 10 - (int(sans[0]) - absi(hash([1, "1", image, false])) % 10)
	verifier(malus == 0, "aucun malus pour des sorties potentielles fermées (%d)" % malus)
	verifier(PlanSalles.fermee_sans_se_voir(image, 1, "gauche") and not PlanSalles.fermee_sans_se_voir(image, 3, "devant"),
		"sortie potentielle fermée = mur invisible")
	# Même tirage pour la même salle (stable)
	salles["1"]["connections"] = ["2", "3"]
	verifier(PlanSalles._evaluer(salles, "1", 1, image, false)[1]["sorties"] == s, "tirage stable")
	PlanSalles.images().erase(image)


## Les geôliers ne vont jamais dans les cryptes (règle de l'utilisateur, 2026-11-03).
func _geoliers(donjon, k: int) -> void:
	var cryptes: Dictionary = donjon.plan_donjon[Donjon.NIVEAU_CRYPTES]
	var dans_cryptes := 0
	for id in cryptes:
		for p in cryptes[id].get("presences", []):
			if p.get("genre") == "geolier":
				dans_cryptes += 1
	verifier(dans_cryptes == 0, "%d : aucun geôlier dans les cryptes (%d)" % [k, dans_cryptes])
	verifier(Aventure.chasseurs(donjon, 1).filter(func(c): return c[0]["genre"] == "geolier").size() == Aventure.GEOLIERS_PAR_ETAGE, "%d : les %d geôliers sont sur l'étage" % [k, Aventure.GEOLIERS_PAR_ETAGE])
	if k > 0:
		return
	verifier(Aventure.ajouter_menace(donjon, Donjon.NIVEAU_CRYPTES, "geolier").is_empty(), "pas de geôlier posé dans les cryptes")
	var une: String = cryptes.keys()[0]
	verifier(Aventure.fermee_a(cryptes[une], "geolier") and not Aventure.fermee_a(cryptes[une], "imbattable"), "une crypte est fermée au geôlier seulement")
	# Déplacement direct refusé : le geôlier reste où il est
	var g := {"id": 999001, "genre": "geolier", "etat": "actif"}
	var autre: String = cryptes.keys()[1]
	cryptes[autre]["presences"] = cryptes[autre].get("presences", []) + [g]
	cryptes[une]["presences"] = cryptes[une].get("presences", [])
	Aventure._deplacer(cryptes, g, une)
	verifier(not g in cryptes[une]["presences"] and g in cryptes[autre]["presences"], "un geôlier n'est pas déplacé dans une crypte")
	# Marche : jamais une crypte comme salle suivante (geôlier glissé dans les cryptes, cas d'une ancienne partie)
	donjon.salle_actuelle = [Donjon.NIVEAU_CRYPTES, int(une)]
	var suivante := Aventure.prochaine_salle(donjon, g, autre)
	verifier(suivante == autre, "un geôlier ne marche pas vers une crypte (%s)" % suivante)
	# Ménage : un geôlier trouvé dans une crypte disparaît
	var vues := Aventure.presences(donjon, cryptes[autre])
	verifier(not g in vues and not g in cryptes[autre]["presences"], "ancienne partie : le geôlier des cryptes est retiré")
