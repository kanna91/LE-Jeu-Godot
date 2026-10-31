extends SceneTree
## Contrôle de l'écran d'exploration : mini-carte réduite et boutons de droite affichés
## seulement quand ils sont utilisables (Monter : salle du boss ; Descendre : salle de
## départ hors premier étage ; Se reposer : salle avec un lit).
## Vérifie les règles et enregistre des captures dans tests/captures/ (fenêtre hors écran).

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
		await process_frame


func capturer(nom: String) -> void:
	await attendre(3)
	root.get_viewport().get_texture().get_image().save_png("res://tests/captures/%s.png" % nom)
	print("capture ", nom)


func verifier(ecran, attendu: Array, cas: String) -> void:
	var obtenu: Array = ecran.actions_visibles()
	if obtenu != attendu:
		echecs += 1
		print("ÉCHEC %s : %s au lieu de %s" % [cas, obtenu, attendu])
	else:
		print("ok %s : %s" % [cas, obtenu])


func aller(donjon, etage: int, salle: int) -> void:
	donjon.salle_actuelle = [etage, salle]


func lancer() -> void:
	seed(4242)
	await attendre(2)
	Sauvegarde.reinitialiser_monde()
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	Ecrans.menu_navigation(joueur, donjon)
	var ecran = Ecrans.pile[-1]
	var depart_1: int = donjon.salle_actuelle[1]
	await capturer("25_navigation_depart_etage1")
	verifier(ecran, [], "départ étage 1")
	aller(donjon, 1, donjon.salle_boss(1))
	await capturer("26_navigation_boss")
	verifier(ecran, ["Monter"], "salle du boss")
	donjon.generer_etage(2)
	var depart_2 := -1
	for ident in donjon.plan_donjon[2]:
		if donjon.est_salle_depart(2, ident):
			depart_2 = int(ident)
	aller(donjon, 2, depart_2)
	await capturer("27_navigation_depart_etage2")
	verifier(ecran, ["Descendre"], "départ étage 2")
	var autre := -1
	for ident in donjon.plan_donjon[2]:
		if int(ident) != depart_2 and not donjon.est_salle_boss(2, ident):
			autre = int(ident)
			break
	aller(donjon, 2, autre)
	verifier(ecran, [], "salle ordinaire étage 2")
	donjon.salle_courante()["lit"] = true
	await capturer("28_navigation_lit")
	verifier(ecran, ["Se reposer"], "salle avec un lit")
	aller(donjon, 1, depart_1)
	verifier(ecran, [], "retour départ étage 1")
	print("BILAN navigation : %d échec(s)" % echecs)
	quit()
