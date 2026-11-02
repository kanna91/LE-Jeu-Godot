extends SceneTree
## Quêtes des prisonniers à l'écran (2026-11-02) : bol de soupe posé dans la cuisine, élite qui entre par une porte
## (« GARDE ! »), combat immédiat contre le Chevalier de la mort (« AHAHAHAHA ! »). Captures :
## tests/captures/70_soupe_cuisine.png, 71_garde_elite.png ; le combat lui-même est mené par Ecrans.auto. « BILAN capture quêtes : 0 échec(s) ».
## Fenêtre hors écran (override.cfg, voir README) :   Godot --path . -s tests/capture_quetes_prisonniers.gd

var racine: Control
var echecs := 0


func _initialize() -> void:
	racine = Control.new()
	racine.size = Vector2(960, 540)
	root.add_child(racine)
	Ecrans.racine = racine
	lancer()


func attendre(images: int) -> void:
	for _i in images:
		if DisplayServer.window_get_size() != Vector2i(1280, 720):
			DisplayServer.window_set_size(Vector2i(1280, 720))
		await process_frame


func verifier(condition: bool, cas: String) -> void:
	if not condition:
		echecs += 1
		print("ÉCHEC ", cas)


func lancer() -> void:
	seed(3)
	Sauvegarde.reinitialiser_monde()
	Statistiques.mort = false
	Ecrans.auto = true
	var joueur = Personnage.nouveau()
	var donjon = Donjon.nouveau(joueur)
	Aventure.preparer_etage(donjon, 1)
	var salles: Dictionary = donjon.plan_donjon[1]
	var magicien := {}
	var ici := ""
	for i in salles:
		for p in salles[i].get("presences", []):
			if p.get("quete") == "magicien":
				magicien = p
				ici = str(i)
	donjon.salle_actuelle = [1, int(ici)]
	QuetesPrisonniers.ecouter(donjon, magicien)  # demande la soupe : elle est posée en cuisine
	var cuisine := ""
	for i in salles:
		for p in salles[i].get("presences", []):
			if p.get("sous") == "objet_quete":
				cuisine = str(i)
	# 1. La cuisine, avec le bol de soupe
	donjon.salle_actuelle = [1, int(cuisine)]
	salles[cuisine]["visitee"] = true
	var nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
	racine.add_child(nav)
	await attendre(30)
	var vu := false
	for e in nav.salle_peinte.presences.entites:
		if e["p"].get("sous") == "objet_quete":
			vu = true
			nav.salle_peinte.heros.position = e["pos"] + Vector2(30, 0)
	verifier(vu, "soupe affichée dans la cuisine")
	await attendre(10)
	verifier(Aventure.action(nav._presence_proche()) == "Ramasser : Bol de soupe", "action « Ramasser » près de la soupe")
	root.get_viewport().get_texture().get_image().save_png("res://tests/captures/70_soupe_cuisine.png")
	nav.queue_free()
	await attendre(2)
	# 2. Retour au magicien, étape « GARDE ! » : un élite entre par une porte, rejoint le héros, le combat commence
	donjon.salle_actuelle = [1, int(ici)]
	magicien["etape"] = "garde"
	magicien["vu"] = false
	nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
	racine.add_child(nav)
	await attendre(10)
	var r := QuetesPrisonniers.ecouter(donjon, magicien)
	var elite: Dictionary = r["suites"][0]["faire_entrer"]
	joueur.points_de_vie_max = 100000
	joueur.points_de_vie = 100000  # le héros tient le temps du combat automatique (Ecrans.auto)
	await nav._suites_quete(r["suites"])
	var capture := false
	var combat := false
	for k in 6000:
		await attendre(1)
		for e in nav.salle_peinte.presences.entites:
			if e["p"] == elite and not capture and e["noeud"].visible and e["pos"].x < 650:
				capture = true
				print("élite entré : pos %s, état %s, héros %s" % [e["pos"], e["etat"], nav.salle_peinte.heros.position])
				root.get_viewport().get_texture().get_image().save_png("res://tests/captures/71_garde_elite.png")
		# Ecrans.auto mène le combat sans écran : il se termine par une victoire ou une fuite (message de l'écran)
		if "Victoire" in nav.message_nav or "fuir" in nav.message_nav:
			combat = true
			print("après le contact : ", nav.message_nav)
			break
	verifier(capture, "élite entré, qui marche vers le héros")
	verifier(combat, "combat au contact de l'élite (mort : %s)" % Statistiques.mort)
	print("BILAN capture quêtes : %d échec(s)" % echecs)
	quit()
