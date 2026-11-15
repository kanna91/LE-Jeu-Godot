extends SceneTree
## Héros assombri quand il est caché (2026-11-15, demande de l'utilisateur) : à découvert il garde ses couleurs, immobile
## dans l'ombre (« Caché ») il prend SallePeinte.TEINTE_CACHE, et retrouve ses couleurs en sortant. Captures
## 74_heros_visible et 75_heros_cache. À lancer hors écran (override.cfg, voir README).
## « BILAN héros caché : 0 échec(s) ».

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


func verifier(condition: bool, cas: String) -> void:
	if not condition:
		echecs += 1
	print(("ok " if condition else "ÉCHEC ") + cas)


func lancer() -> void:
	Sauvegarde.reinitialiser_monde()
	Statistiques.mort = false
	Ecrans.auto = true
	seed(5)
	var joueur = Personnage.nouveau()
	var donjon = Donjon.nouveau(joueur)
	PlanSalles.attribuer(donjon, 1)
	var salle: Dictionary = donjon.salle_courante()
	salle["salle_peinte"]["image"] = "porte2"
	salle["salle_peinte"]["miroir"] = false
	salle["salle_peinte"]["sorties"] = [null, null, null, null]
	salle["objets"] = []
	salle["objets_image"] = "porte2"
	salle["presences"] = []
	Aventure.meta(donjon, 1)["prepare"] = true
	var nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
	Ecrans.pile.append(nav)
	racine.add_child(nav)
	await attendre(40)
	var sp: SallePeinte = nav.salle_peinte
	# À découvert : un point du sol ni dans l'ombre, ni caché
	var dehors := Vector2.ZERO
	var ombre := Vector2.ZERO
	for y in range(380, 500, 3):
		for x in range(20, 740, 3):
			var q := Vector2(x, y)
			if not sp.libre(q):
				continue
			if dehors == Vector2.ZERO and not sp.dans_ombre(q) and not sp.point_cache(q) and not sp.dans_cachette(q):
				dehors = q
			if ombre == Vector2.ZERO and sp.dans_ombre(q) and dehors != Vector2.ZERO and q.distance_to(dehors) > 120:
				ombre = q
	verifier(dehors != Vector2.ZERO and ombre != Vector2.ZERO, "un point à découvert et un point dans l'ombre")
	sp.heros.position = dehors
	await create_timer(0.6).timeout
	verifier(not sp.heros_cache() and sp.heros.self_modulate.is_equal_approx(Color.WHITE), "à découvert : couleurs normales")
	await capturer("74_heros_visible")
	sp.heros.position = ombre
	await create_timer(0.6).timeout
	verifier(sp.heros_cache(), "immobile dans l'ombre : caché")
	verifier(sp.heros.self_modulate.is_equal_approx(SallePeinte.TEINTE_CACHE), "caché : assombri (%s)" % sp.heros.self_modulate)
	await capturer("75_heros_cache")
	sp.heros.position = dehors
	await create_timer(0.6).timeout
	verifier(sp.heros.self_modulate.is_equal_approx(Color.WHITE), "sorti de l'ombre : couleurs revenues")
	print("BILAN héros caché : %d échec(s)" % echecs)
	quit(1 if echecs else 0)
