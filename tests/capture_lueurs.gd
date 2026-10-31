extends SceneTree
## Lueur des sorties praticables (SallePeinte._creer_lueurs) : grandes salles et salles à portes, toutes sorties
## ouvertes, puis une sortie condamnée (sans lueur). Captures 109_lueurs_<salle>. Fenêtre hors écran (override.cfg).
## « BILAN lueurs : 0 échec(s) ».

var racine: Control
var echecs := 0


func _initialize() -> void:
	racine = Control.new()
	racine.size = Vector2(960, 540)
	root.add_child(racine)
	Ecrans.racine = racine
	lancer()


func attendre(n: int) -> void:
	for _i in n:
		await process_frame


func verifier(c: bool, cas: String) -> void:
	if not c:
		echecs += 1
	print(("ok " if c else "ÉCHEC ") + cas)


func lancer() -> void:
	Sauvegarde.reinitialiser_monde()
	Statistiques.mort = false
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	PlanSalles.attribuer(donjon, 1)
	var salle: Dictionary = donjon.salle_courante()
	salle["presences"] = []
	salle["objets"] = []
	Aventure.meta(donjon, 1)["prepare"] = true
	var ids := ["grande1", "grande4", "grande7", "grande8", "grande10", "porte2"]
	if OS.get_cmdline_user_args().size() > 0:
		ids = OS.get_cmdline_user_args()
	var nav = null
	for id in ids:
		var n: int = SallePeinte.lire_salle(id)["sorties"].size()
		salle["salle_peinte"]["image"] = id
		salle["salle_peinte"]["miroir"] = false
		var sorties := []
		for k in n:
			sorties.append(str(100 + k))
		salle["salle_peinte"]["sorties"] = sorties
		salle["objets_image"] = id
		if nav == null:
			nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
			Ecrans.pile.append(nav)
			racine.add_child(nav)
		else:
			nav._afficher_salle(-1)
		await attendre(30)
		var sp: SallePeinte = nav.salle_peinte
		var praticables := range(n).filter(func(i): return sp.sortie_praticable(i))
		verifier(praticables.size() == n, "%s : %d sorties praticables sur %d" % [id, praticables.size(), n])
		root.get_viewport().get_texture().get_image().save_png("res://tests/captures/109_lueurs_%s.png" % id)
		print("capture 109_lueurs_%s" % id)
	# Une sortie condamnée n'a pas de lueur
	nav.salle_peinte.definir_portes([], [0])
	verifier(not nav.salle_peinte.sortie_praticable(0), "sortie condamnée : pas de lueur")
	print("BILAN lueurs : %d échec(s)" % echecs)
	quit()
