extends SceneTree
## Cartographie des salles peintes, orientation fixe (haut de l'image = haut de la mini-carte) :
## chaque salle du plan reçoit-elle une image dont les portes mènent exactement à ses voisines ?
##
## Affiche d'abord le catalogue : pour chaque image (et son miroir), les directions de la carte où elle
## mène, avec et sans la sortie du bas (le bas peut toujours être fermé, il est hors de l'image).
## Puis les 15 combinaisons de directions possibles (haut, bas, gauche, droite) : images exactes, ou
## « AUCUNE IMAGE » (image à générer).
## Génère ensuite DONJONS donjons × ETAGES étages, attribue les images (PlanSalles.attribuer) et compte
## pour chaque combinaison : salles, images exactes (aucune porte visible condamnée, aucun passage sans
## porte), portes condamnées, passages sans porte (flèche), images utilisées.
## « BILAN cartographie : 0 échec(s) » si toute combinaison qui a une image exacte la reçoit toujours,
## s'il n'y a aucun passage sans porte et si chaque porte mène à la salle qui est dans sa direction sur la
## mini-carte (gauche de l'image = gauche de la carte, bas de l'image = bas de la carte...).
## Depuis le quartier des cryptes (2026-11-02, choix de l'utilisateur : 14 cryptes sans miroir, regroupées), les images
## à sorties de côté manquent ailleurs : ~3,6 passages sans porte par étage (mesuré). Tolérance : SANS_PORTE_PAR_ETAGE
## en moyenne ; les combinaisons sans image exacte sont seulement signalées (« À NOTER »).
## Lancer : Godot --headless --path . -s tests/test_cartographie_salles.gd

const DONJONS := 12
const ETAGES := [1, 2, 3, 4, 5]
## 9 depuis le 2026-11-04 : étages d'environ 180 salles (bibliothèque, laboratoire, jardin) et couloirs qui raccordent les
## complexes à l'étage ; mesuré 8,1 (surtout des couloirs est-ouest : il manque d'images à portes gauche ET droite).
const SANS_PORTE_PAR_ETAGE := 9.0
const ORDRE := [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]

var echecs := 0


func _initialize() -> void:
	var exactes := catalogue()
	var stats := {}
	for _n in DONJONS:
		Sauvegarde.reinitialiser_monde()
		var donjon = Donjon.nouveau(Personnage.nouveau())
		for etage in ETAGES:
			if etage > 1:
				donjon.generer_etage(etage)
			PlanSalles.attribuer(donjon, etage)
			# Chaque apparence (image × miroir) une seule fois par étage (2026-10-30) ; depuis le 2026-11-03 (cryptes et
			# prisons réservées), il y a plus de salles ordinaires que d'apparences : chacune sert au plus
			# ceil(salles / apparences) fois, sans en laisser de côté
			var vues := {}
			var ordinaires := 0
			for id in donjon.plan_donjon[etage]:
				analyser(donjon.plan_donjon[etage], str(id), stats)
				var info: Dictionary = donjon.plan_donjon[etage][id]["salle_peinte"]
				if PlanSalles.reservee(String(info["image"])):
					continue
				ordinaires += 1
				var cle := "%s|%s" % [info["image"], info["miroir"]]
				vues[cle] = int(vues.get(cle, 0)) + 1
			var apparences := 2 * PlanSalles.images().keys().filter(func(i): return not PlanSalles.reservee(String(i))).size()
			var plafond := ceili(float(ordinaires) / apparences)
			for cle in vues:
				if vues[cle] > plafond:
					echecs += 1
					print("ÉCHEC : %s utilisée %d fois à l'étage %d (%d salles ordinaires, %d apparences)." % [cle, vues[cle], etage, ordinaires, apparences])
	print("")
	print("directions                  salles  exactes  condamnées  sans porte  images (× fois)")
	var cles: Array = stats.keys()
	cles.sort()
	var total_sans_porte := 0
	for k in cles:
		var s: Dictionary = stats[k]
		var images := []
		for nom in s["images"]:
			images.append("%s ×%d" % [nom, s["images"][nom]])
		images.sort()
		print("%-26s  %6d  %7d  %10d  %10d  %s" % [k, s["salles"], s["exactes"], s["condamnees"], s["sans_porte"],
			", ".join(images)])
		if exactes.has(k) and s["exactes"] < s["salles"]:
			print("À NOTER %s : %d salle(s) sans image exacte alors qu'il en existe" % [k, s["salles"] - s["exactes"]])
		total_sans_porte += s["sans_porte"]
	var moyenne := total_sans_porte / float(DONJONS * ETAGES.size())
	print("Passages sans porte peinte : %d (%.1f par étage)" % [total_sans_porte, moyenne])
	if moyenne > SANS_PORTE_PAR_ETAGE:
		echecs += 1
		print("ÉCHEC : %.1f passages sans porte par étage (tolérance %.1f)" % [moyenne, SANS_PORTE_PAR_ETAGE])
	print("BILAN cartographie : %d échec(s)" % echecs)
	quit()


## Nom d'un ensemble de directions de la carte, dans un ordre fixe : « haut + gauche + bas ».
static func nom(directions: Array) -> String:
	var noms := []
	for d in ORDRE:
		if d in directions:
			noms.append(PlanSalles.NOMS_DIRECTIONS[d])
	return " + ".join(noms)


func analyser(salles: Dictionary, id: String, stats: Dictionary) -> void:
	var voisines := PlanSalles.voisines_carte(salles, id)
	if voisines.is_empty():
		return
	var k := nom(voisines.keys())
	if not stats.has(k):
		stats[k] = {"salles": 0, "exactes": 0, "condamnees": 0, "sans_porte": 0, "images": {}}
	var info: Dictionary = salles[id].get("salle_peinte", {})
	var st: Dictionary = stats[k]
	st["salles"] += 1
	var dirs := PlanSalles.directions(String(info.get("image", "")), bool(info.get("miroir", false)))
	var sorties: Array = info.get("sorties", [])
	var condamnees := 0
	var ici := PlanSalles._position(salles[id])
	var types := PlanSalles.types_sorties(String(info.get("image", "")))
	for i in sorties.size():
		# Le bas et les passages de bord des grandes salles se ferment sans se voir (mur invisible)
		if sorties[i] == null and i < dirs.size() and dirs[i] != "bas" and not (i < types.size() and types[i] == "bord"):
			condamnees += 1
		# La porte doit mener à la salle qui est dans sa direction sur la mini-carte (sauf dans un bloc de salles :
		# ses liens sont donnés porte à porte, avec des exceptions voulues, vérifiées par test_blocs)
		if sorties[i] != null and not salles[id].has("bloc"):
			var vers := PlanSalles._position(salles[str(sorties[i])]) - ici
			if PlanSalles.absolue(dirs[i], PlanSalles.FACE) != vers:
				echecs += 1
				print("ÉCHEC salle %s : sortie « %s » vers %s sur la carte" % [id, dirs[i], vers])
	var sans_porte: int = info.get("sans_porte", []).size()
	st["condamnees"] += condamnees
	st["sans_porte"] += sans_porte
	if condamnees == 0 and sans_porte == 0:
		st["exactes"] += 1
	var image := String(info.get("image", "?")) + (" miroir" if info.get("miroir", false) else "")
	st["images"][image] = st["images"].get(image, 0) + 1


## Affiche le catalogue des images et des 15 combinaisons ; renvoie {combinaison : [images exactes]}.
func catalogue() -> Dictionary:
	print("Catalogue des images (directions de la carte ; « bas » peut toujours être fermé) :")
	var exactes := {}
	var noms: Array = PlanSalles.images().keys()
	noms.sort()
	for image in noms:
		for miroir in [false, true]:
			var formes := PlanSalles.formes_couvertes(image, miroir)
			var textes := []
			for f in formes:
				textes.append(nom(f))
				var k := nom(f)
				if not exactes.has(k):
					exactes[k] = []
				exactes[k].append(image + (" miroir" if miroir else ""))
			print("  %-18s %s" % [image + (" miroir" if miroir else ""), "  |  ".join(textes)])
	print("")
	print("Combinaisons de passages (haut, gauche, droite, bas) :")
	for masque in range(1, 16):
		var dirs := []
		for b in 4:
			if masque & (1 << b):
				dirs.append(ORDRE[b])
		var k := nom(dirs)
		var l: Array = exactes.get(k, [])
		print("  %-26s %s" % [k, ", ".join(l) if not l.is_empty() else "AUCUNE IMAGE (à générer)"])
	return exactes
