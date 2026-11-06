extends SceneTree
## Combat contre les squelettes refaits (2026-11-06) : guerrier, mage et élémentaliste, puis le mage invoque deux
## squelettes ; vérifie que chaque ennemi a une place à l'écran. Captures squelettes_combat_0 et _1.
## « BILAN capture squelettes : 0 échec(s) ». À lancer dans une fenêtre hors écran (override.cfg, voir README).

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
		print("ÉCHEC " + cas)


func capturer(nom: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("res://tests/captures/%s.png" % nom)


func lancer() -> void:
	seed(3)
	await attendre(2)
	Sauvegarde.reinitialiser_monde()
	var joueur := Personnage.nouveau()
	joueur.points_de_vie_max = 999
	joueur.points_de_vie = 999
	var donjon := Donjon.nouveau(joueur)
	Ecrans.menu_navigation(joueur, donjon)
	await attendre(5)
	var ennemis := []
	for s in ["guerrier_squelette", "mage_squelette", "elementaliste_squelette"]:
		ennemis.append(Creatures.creer(donjon, s))
	var mage = ennemis[1]
	mage.mana = 99
	var combat := Combat.nouveau(joueur, null, ennemis, donjon)
	combat.mener_combat()
	await attendre(30)
	var ecran = Ecrans.pile[-1]
	verifier(ecran.has_method("rect_ennemi"), "écran de combat ouvert")
	capturer("squelettes_combat_0")
	var invocation = mage.competences.filter(func(c): return c.nom_classe == "Invocation_squelette")[0]
	for k in 2:
		mage.points_d_action = 1
		combat.lancer(invocation, mage, donjon, joueur)
	await attendre(20)
	verifier(combat.ennemis.size() == 5, "5 ennemis après deux invocations (%d)" % combat.ennemis.size())
	for e in combat.ennemis:
		var r = ecran.rect_ennemi(e)
		verifier(r != null and r.position.x >= -1 and r.end.x <= 961, "%s a une place à l'écran (%s)" % [e.nom, r])
	capturer("squelettes_combat_1")
	print("BILAN capture squelettes : %d échec(s)" % echecs)
	quit()
