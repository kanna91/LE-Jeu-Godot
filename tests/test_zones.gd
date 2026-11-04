extends SceneTree
## Zones et quartier des cryptes (2026-11-02, demandes de l'utilisateur) :
## - sur 30 donjons, toutes les images « crypte » servent une fois dans le niveau des cryptes (d'un seul tenant), et
##   nulle part ailleurs (depuis le 2026-11-03 ; avant : un quartier des cryptes dans chaque étage) ;
## - dans les cryptes, les groupes ne sont que des squelettes, avec exactement une élite : un féticheur ;
## - zones.json est lu (réglages fusionnés avec « defaut ») ;
## - force, intelligence et sagesse : 1d2 de dégâts tous les 2 points ;
## - cuisine (refuge) : aucun ennemi posé, aucun chasseur n'y entre (2000 pas d'errance par étage), un ennemi posé
##   dedans (ancienne partie) en est chassé à la lecture de la salle.
## godot --headless --path . -s tests/test_zones.gd

var echecs := 0


func verifier(condition: bool, cas: String) -> void:
	if not condition:
		echecs += 1
		print("ÉCHEC ", cas)


func _initialize() -> void:
	seed(1102)
	_reglages()
	_des()
	var etages := 0
	var groupes := 0
	var sans_quartier := 0
	for k in 30:
		Sauvegarde.reinitialiser_monde()
		var donjon := Donjon.nouveau(Personnage.nouveau())
		for etage in donjon.plan_donjon:
			etages += 1
			var r := _etage(donjon.plan_donjon[etage], "%d/%d" % [k, etage])
			if Donjon.est_niveau_unique(etage):
				groupes += r
				if r < 0:
					sans_quartier += 1
			else:
				# Depuis le 2026-11-03, les cryptes sont un niveau à part : aucune sur l'étage
				verifier(r < 0, "%d/%d : des cryptes sur l'étage" % [k, etage])
				if k < 6:
					_cuisine(donjon, etage, "%d/%d" % [k, etage])
	print("Niveaux : %d, sans cryptes : %d, groupes dans les cryptes : %d" % [etages, sans_quartier, groupes])
	verifier(sans_quartier == 0, "des cryptes dans chaque niveau des cryptes")
	print("BILAN zones : %d échec(s)" % echecs)
	quit(1 if echecs else 0)


func _reglages() -> void:
	var c := Zones.reglages("crypte")
	verifier(c["ennemis"] == {"squelette": 1.0} or c["ennemis"] == {"squelette": 1}, "cryptes : squelettes seulement")
	verifier(Zones.elites_fixes("crypte") and int(c["nombre_elites"]) == 1, "cryptes : une seule élite")
	verifier(not Zones.elites_fixes(""), "hors zone : élites au hasard")
	verifier(float(Zones.reglages("")["chance_elite"]) > 0, "hors zone : chance d'élite lue dans « defaut »")
	verifier(Zones.zone_image("crypte7") == "crypte" and Zones.zone_image("prison3") == "", "zone d'une image")
	verifier(Zones.membre("feticheur")["classe"] == "mage" and Zones.membre("squelette")["sous_classe"] == "squelette",
		"membres par sorte")


func _des() -> void:
	var attendus := {0: [], 1: [], 2: [[1, 2]], 3: [[1, 2]], 4: [[2, 2]], 7: [[3, 2]]}
	for points in attendus:
		for c in [["force", "tranchant"], ["intelligence", "ombre"], ["sagesse", "feu"]]:
			var des := Formules.des_caracteristique({c[0]: points}, c[1])
			verifier(des == attendus[points], "%s %d : %s au lieu de %s" % [c[0], points, des, attendus[points]])


## Vérifie un étage ; renvoie le nombre de groupes vus dans les cryptes (-1 : pas de quartier).
func _etage(salles: Dictionary, nom: String) -> int:
	var cryptes := []
	var vues := {}
	for id in salles:
		var image := String(salles[id].get("salle_peinte", {}).get("image", ""))
		if PlanSalles.est_crypte(image):
			cryptes.append(String(id))
			verifier(not vues.has(image), "%s : %s deux fois" % [nom, image])
			vues[image] = true
	if cryptes.is_empty():
		return -1
	verifier(vues.size() == PlanSalles.images_cryptes().size(),
		"%s : %d images de crypte sur %d" % [nom, vues.size(), PlanSalles.images_cryptes().size()])
	# D'un seul tenant : depuis une crypte, on atteint toutes les autres sans sortir des cryptes
	var atteintes := {cryptes[0]: true}
	var file := [cryptes[0]]
	while not file.is_empty():
		var c: String = file.pop_front()
		for v in salles[c].get("connections", []):
			var vs := str(v)
			if vs in cryptes and not atteintes.has(vs):
				atteintes[vs] = true
				file.append(vs)
	verifier(atteintes.size() == cryptes.size(), "%s : cryptes séparées (%d reliées sur %d)" % [nom, atteintes.size(), cryptes.size()])
	# Ennemis des cryptes
	var elites := 0
	var groupes := 0
	for id in cryptes:
		for p in salles[id].get("presences", []):
			if p.get("genre") != "groupe":
				continue
			groupes += 1
			verifier(String(p.get("zone_ennemis", "")) == "crypte", "%s : groupe sans zone dans une crypte" % nom)
			var mb := Aventure.membres(p)
			for k in mb.size():
				if k == 0 and p.get("elite", false):
					elites += 1
					verifier(mb[0]["sous_classe"] == "feticheur", "%s : élite des cryptes = %s" % [nom, mb[0]["sous_classe"]])
				else:
					verifier(mb[k]["sous_classe"] == "squelette", "%s : %s dans les cryptes" % [nom, mb[k]["sous_classe"]])
	# Les groupes de la zone restent dans la zone
	for id in salles:
		if not id in cryptes:
			for p in salles[id].get("presences", []):
				verifier(String(p.get("zone_ennemis", "")) != "crypte", "%s : groupe des cryptes hors des cryptes" % nom)
	verifier(elites == 1, "%s : %d élite(s) dans les cryptes" % [nom, elites])
	return groupes


## Cuisine : aucun ennemi, les chasseurs n'y entrent jamais, un ennemi glissé dedans en est chassé.
func _cuisine(donjon, etage: int, nom: String) -> void:
	var salles: Dictionary = donjon.plan_donjon[etage]
	var refuges := []
	for id in salles:
		if Zones.refuge(salles[id]):
			refuges.append(String(id))
			for p in salles[id].get("presences", []):
				verifier(not p.get("genre", "") in Aventure.ENNEMIS, "%s : %s dans la cuisine" % [nom, p.get("genre")])
				verifier(p.get("sous", "") != "gobelin_blesse", "%s : gobelin blessé dans la cuisine" % nom)
	# Refuges : le bloc cuisine et le bloc bibliothèque (2026-11-04)
	verifier(refuges.size() == BlocsSalles.BLOCS["cuisine"]["salles"].size() + BlocsSalles.BLOCS["bibliotheque"]["salles"].size(),
		"%s : %d salles refuges" % [nom, refuges.size()])
	if refuges.is_empty():
		return
	donjon.salle_actuelle = [etage, int(refuges[0])]
	# Errance, même attirés vers la cuisine (le héros y est)
	Aventure.attirer(donjon)
	for _k in 2000:
		for c in Aventure.chasseurs(donjon, etage):
			var vers := Aventure.prochaine_salle(donjon, c[0], c[1])
			verifier(not vers in refuges, "%s : un %s entre dans la cuisine" % [nom, c[0]["genre"]])
			Aventure.changer_de_salle(donjon, c[0], c[1], vers)
	# Ancienne partie : un groupe dans la cuisine en est chassé
	var intrus := {"id": 99999, "genre": "groupe", "etat": "actif", "nombre": 1, "elite": false, "pacifique": false}
	salles[refuges[0]]["presences"].append(intrus)
	Aventure.presences(donjon, salles[refuges[0]])
	verifier(not intrus in salles[refuges[0]]["presences"], "%s : intrus resté dans la cuisine" % nom)
