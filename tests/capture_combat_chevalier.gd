extends SceneTree
## Combat animé du Chevalier de la mort (CombatAnime, jeu « chevalier ») : le héros (épée) le frappe → le
## chevalier pare (garde levée à l'impact), puis il riposte (une de ses deux attaques, épée qui s'abat au coup).
## Captures 43_chevalier_* dans tests/captures/. « BILAN combat chevalier : 0 échec(s) ».
## Fenêtre hors écran (override.cfg, voir README).

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


func attendre_jusqu_a(instant: float) -> void:
	while EffetsCombat.maintenant() < instant:
		await process_frame
	await attendre(2)


func capturer(nom: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("res://tests/captures/%s.png" % nom)
	print("capture ", nom)


func verifier(c: bool, cas: String) -> void:
	if not c:
		echecs += 1
	print(("ok " if c else "ÉCHEC ") + cas)


func coup_de(source):
	for imp in EffetsCombat.file:
		if imp.source == source and imp.debut != null:
			return imp
	return null


func lancer() -> void:
	seed(3)
	await attendre(2)
	Sauvegarde.reinitialiser_monde()
	var joueur := Personnage.nouveau()
	joueur.points_de_vie_max = 999
	joueur.points_de_vie = 999
	var donjon := Donjon.nouveau(joueur)
	joueur.equiper_item(Arme.nouvelle("Epée", "arme", "Epée"))
	Ecrans.menu_navigation(joueur, donjon)
	await attendre(5)
	var k := Aventure.creer_imbattable(donjon)
	verifier(CombatAnime.type_gobelin(k) == "chevalier", "le chevalier a ses images de combat")
	verifier(CombatAnime.parades(k).size() == 2, "deux parades")
	var combat := Combat.nouveau(joueur, null, [k], donjon)
	combat.mener_combat()
	await attendre(30)
	capturer("43_chevalier_0_attente")
	for tour in 2:
		var ecran = Ecrans.pile[-1]  # l'écran de combat est recréé à chaque tour
		ecran._traiter([{"type": "clic", "pos": ecran.boutons_actions[0][0].get_center(), "bouton": 1}])
		await attendre(2)
		if ecran.competence_en_cours != null:
			ecran._traiter([{"type": "clic", "pos": ecran.rect_ennemi(k).get_center(), "bouton": 1}])
		await attendre(2)
		var imp = coup_de(joueur)
		verifier(imp != null, "tour %d : le héros frappe" % tour)
		if imp == null:
			break
		await attendre_jusqu_a(imp.debut)
		var c := CombatAnime.image_courante(k)
		print("  à l'impact du héros : chevalier « %s » image %d (garde levée à %d), coup %s" % [c[0], c[1], int(c[2].get("impact", -1)), imp.type])
		if imp.type != "rate":
			verifier(String(c[0]).begins_with("touche") and absi(c[1] - int(c[2]["impact"])) <= 1,
				"tour %d : le chevalier a la garde levée quand le coup arrive" % tour)
		capturer("43_chevalier_%d_parade" % (tour * 3 + 1))
		if tour == 0:
			await create_timer(0.55).timeout
			var c3 := CombatAnime.image_courante(k)
			print("  0,55 s après : « %s » image %d / %d" % [c3[0], c3[1], int(c3[2]["images"])])
			capturer("43_chevalier_1b_garde_redescend")
		# Riposte du chevalier
		var riposte = null
		var limite := EffetsCombat.maintenant() + 15.0
		while riposte == null and EffetsCombat.maintenant() < limite:
			await process_frame
			riposte = coup_de(k)
		verifier(riposte != null, "tour %d : le chevalier riposte" % tour)
		if riposte == null:
			break
		var anim: String = riposte.anim_source
		var defn: Dictionary = CombatAnime.donnees()["gobelins"]["chevalier"]["anims"].get(anim, {})
		verifier(anim.begins_with("attaque"), "tour %d : il joue une attaque (%s)" % [tour, anim])
		await attendre_jusqu_a(riposte.debut - 0.9)
		capturer("43_chevalier_%d_armement" % (tour * 3 + 2))
		await attendre_jusqu_a(riposte.debut)
		var c2 := CombatAnime.image_courante(k)
		verifier(c2[0] == anim and absi(c2[1] - int(defn.get("impact", -99))) <= 1,
			"tour %d : l'épée s'abat au moment du coup (%s image %d, impact %d)" % [tour, c2[0], c2[1], int(defn.get("impact", -1))])
		capturer("43_chevalier_%d_coup" % (tour * 3 + 3))
		# Retour en garde (Grok) : il se relève par ses propres images, puis l'attente, sans fondu
		var fin: float = riposte.debut + (int(defn["images"]) - int(defn["impact"])) * 0.034
		await attendre_jusqu_a(fin - 0.45)
		var c3 := CombatAnime.image_courante(k)
		verifier(c3[0] == anim and c3[1] > int(defn["images"]) - 20, "tour %d : il se relève (%s image %d / %d)" % [tour, c3[0], c3[1], int(defn["images"])])
		capturer("43_chevalier_%db_retour" % (tour * 3 + 3))
		await attendre_jusqu_a(fin + 0.15)
		var c4 := CombatAnime.image_courante(k)
		verifier(c4[0] == "attente" and not CombatAnime._etat(k).has("fondu"), "tour %d : de retour en garde, sans fondu" % tour)
		while EffetsCombat.en_cours() or not is_instance_valid(Ecrans.pile[-1]) or Ecrans.pile[-1] == ecran 				or not Ecrans.pile[-1].has_method("rect_ennemi") or Ecrans.pile[-1].boutons_actions.is_empty():
			await process_frame
		await attendre(20)
	print("BILAN combat chevalier : %d échec(s)" % echecs)
	quit()
