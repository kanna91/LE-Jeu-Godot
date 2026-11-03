extends SceneTree
## Passage entre une prison et les cryptes, dans l'écran d'exploration (2026-11-03) : pour chaque couloir de prison,
## le héros entre dans la sortie du fond → il arrive dans l'entrée des cryptes reliée, devant sa sortie de passage
## (qui n'est ni murée ni condamnée) ; il y entre → il revient dans le couloir, devant le fond.
## « BILAN passage cryptes : 0 échec(s) ».  godot --headless --path . -s tests/test_passage_cryptes.gd

var racine: Control
var echecs := 0


func _initialize() -> void:
	racine = Control.new()
	racine.size = Vector2(960, 540)
	root.add_child(racine)
	Ecrans.racine = racine
	lancer()


func verifier(condition: bool, cas: String) -> void:
	if not condition:
		echecs += 1
		print("ÉCHEC ", cas)


func attendre(images: int) -> void:
	for _i in images:
		await process_frame


func calmer(salle: Dictionary) -> void:
	salle["visitee"] = true
	salle.erase("evenement")
	salle["presences"] = []


func lancer() -> void:
	seed(11)
	Sauvegarde.reinitialiser_monde()
	Statistiques.mort = false
	Ecrans.auto = true
	var joueur = Personnage.nouveau()
	var donjon = Donjon.nouveau(joueur)
	for niveau in [1, Donjon.NIVEAU_CRYPTES]:
		for id in donjon.plan_donjon[niveau]:
			calmer(donjon.plan_donjon[niveau][id])
	var couloirs := []
	for id in donjon.plan_donjon[1]:
		if donjon.plan_donjon[1][id].get("prison_salle", "") == "couloir":
			couloirs.append(id)
	verifier(couloirs.size() == 4, "4 couloirs")
	for id in couloirs:
		donjon.salle_actuelle = [1, int(id)]
		var nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
		racine.add_child(nav)
		await attendre(3)
		var info: Dictionary = donjon.salle_courante()["salle_peinte"]
		var passage := int(info.get("passage", -1))
		var sp = nav.salle_peinte
		verifier(passage >= 0 and not passage in sp.sorties_murees, "couloir %s : fond ouvert" % id)
		var lien: Dictionary = donjon.salle_courante()["passage_niveau"]
		sp.heros.position = sp.centre_sortie(passage)
		await nav._sortie_atteinte(passage)
		await attendre(3)
		verifier(donjon.salle_actuelle == [Donjon.NIVEAU_CRYPTES, int(lien["salle"])],
			"couloir %s : arrivée dans l'entrée des cryptes %s (%s)" % [id, lien["salle"], donjon.salle_actuelle])
		sp = nav.salle_peinte
		var entree: Dictionary = donjon.salle_courante().get("salle_peinte", {})
		var retour := int(entree.get("passage", -1))
		verifier(retour >= 0 and not retour in sp.sorties_murees, "entrée %s : passage ouvert" % lien["salle"])
		if retour >= 0:
			verifier(sp.heros.position.distance_to(sp.centre_sortie(retour)) < 160.0,
				"entrée %s : le héros arrive devant le passage (%s, sortie %d %s de %s, centre %s)" % [lien["salle"], sp.heros.position, retour, sp.directions_sorties()[retour], entree["image"], sp.centre_sortie(retour)])
			sp.heros.position = sp.centre_sortie(retour)
			await nav._sortie_atteinte(retour)
			await attendre(3)
			verifier(donjon.salle_actuelle == [1, int(id)], "retour dans le couloir %s (%s)" % [id, donjon.salle_actuelle])
			sp = nav.salle_peinte
			verifier(sp.heros.position.distance_to(sp.centre_sortie(passage)) < 160.0, "couloir %s : retour devant le fond" % id)
		nav.queue_free()
		await attendre(2)
	print("BILAN passage cryptes : %d échec(s)" % echecs)
	quit(1 if echecs else 0)
