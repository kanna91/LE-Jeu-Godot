extends SceneTree
## Décors animés des grandes salles (2026-11-15) : grande1, 6, 8, 9 et 10 gardent leur image nette (fond_hd) et y
## ajoutent le mouvement de leur vidéo (decor_video). Captures 76_grande<N>_animee. À lancer hors écran (override.cfg, voir README).
## « BILAN grandes salles animées : 0 échec(s) ».

const SALLES := [1, 6, 8, 9, 10]

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
	print(("ok " if condition else "ÉCHEC ") + cas)


func lancer() -> void:
	for n in SALLES:
		Sauvegarde.reinitialiser_monde()
		Statistiques.mort = false
		Ecrans.auto = true
		seed(5)
		var joueur = Personnage.nouveau()
		var donjon = Donjon.nouveau(joueur)
		PlanSalles.attribuer(donjon, 1)
		var salle: Dictionary = donjon.salle_courante()
		salle["salle_peinte"]["image"] = "grande%d" % n
		salle["salle_peinte"]["miroir"] = false
		salle["salle_peinte"]["sorties"] = [null, null, null, null]
		salle["objets"] = []
		salle["objets_image"] = "grande%d" % n
		salle["presences"] = []
		Aventure.meta(donjon, 1)["prepare"] = true
		var nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
		Ecrans.pile.append(nav)
		racine.add_child(nav)
		await create_timer(2.5).timeout
		var sp: SallePeinte = nav.salle_peinte
		verifier(sp.lecteur_video != null and sp.decor_pret, "grande%d : la vidéo est lancée" % n)
		# Image nette (fond_hd, 1152 x 768) gardée, le mouvement de la vidéo s'y ajoute (SallePeinte.materiau_mouvement)
		var tex: Texture2D = sp.sprite_fond.texture
		verifier(tex.get_size() == Vector2(1152, 768), "grande%d : image nette gardée (%s)" % [n, tex.get_size()])
		verifier(sp.sprite_fond.material != null and sp.sprite_fond.material == sp.materiau_decor,
			"grande%d : mouvement de la vidéo ajouté" % n)
		root.get_viewport().get_texture().get_image().save_png("res://tests/captures/76_grande%d_animee.png" % n)
		Ecrans.pile.erase(nav)
		nav.queue_free()
		await process_frame
	await _combat()
	print("BILAN grandes salles animées : %d échec(s)" % echecs)
	quit(1 if echecs else 0)


## Combat dans grande9 : l'image nette avec le mouvement de la vidéo (matériau de la couche du fond).
func _combat() -> void:
	Ecrans.auto = false  # sans quoi l'écran de combat ne s'ouvre pas
	Sauvegarde.reinitialiser_monde()
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	PlanSalles.attribuer(donjon, 1)
	Ecrans.menu_navigation(joueur, donjon)
	for _i in 5:
		await process_frame
	donjon.salle_courante()["salle_peinte"]["image"] = "grande9"
	donjon.salle_courante()["salle_peinte"]["miroir"] = false
	donjon.salle_courante()["salle_peinte"]["sorties"] = [null, null, null, null]  # 4 sorties, sinon réattribuée
	var combat := Combat.nouveau(joueur, null, [Gobelin.nouveau(donjon).generer_gobelin(donjon)], donjon)
	combat.mener_combat()
	await create_timer(2.5).timeout
	var ecran = null
	for e in Ecrans.pile:
		if "fond_peint_hd" in e:
			ecran = e
	if ecran == null:
		verifier(false, "combat : écran de combat ouvert")
		return
	verifier(ecran.fond_peint_hd != null and ecran.fond_peint_hd.get_size() == Vector2(1152, 768), "combat : image nette")
	verifier(ecran.couche_fond.material != null, "combat : mouvement de la vidéo ajouté")
	root.get_viewport().get_texture().get_image().save_png("res://tests/captures/77_combat_grande9_anime.png")
	ecran.fermer()
