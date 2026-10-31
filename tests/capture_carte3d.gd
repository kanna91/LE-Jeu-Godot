extends SceneTree
## Essai de la maquette 3D invisible (outils/carte3d.py) sur la grande salle 5 : le héros devant, à côté et
## derrière les piliers ; captures 60_carte3d_N. « BILAN carte 3D : 0 échec(s) ».
## À lancer dans une fenêtre hors écran (override.cfg, voir README).

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
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	var nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
	Ecrans.pile.append(nav)
	racine.add_child(nav)
	await attendre(10)
	var salle: SallePeinte = nav.salle_peinte
	salle.charger("grande5", -1, false)
	salle.murer([])
	if salle.presences != null:
		salle.presences.placer([])
	await attendre(10)
	var essais := {"devant_le_pilier_gauche": Vector2(130, 430), "derriere_le_pilier_gauche": Vector2(128, 372),
		"derriere_le_pilier_droit": Vector2(632, 378), "au_fond": Vector2(330, 352), "au_milieu": Vector2(384, 430)}
	var k := 0
	for nom in essais:
		var p: Vector2 = essais[nom]
		verifier(salle.libre(p), "%s : sur le sol (%s)" % [nom, p])
		salle.heros.position = p
		await attendre(8)
		var cache := salle.heros_cache() if salle.has_method("heros_cache") else false
		print("  %s : caché derrière le premier plan = %s, taille %.0f px" % [nom, cache, salle.hauteur(p.y)])
		await attendre(2)
		root.get_viewport().get_texture().get_image().save_png("res://tests/captures/60_carte3d_%d_%s.png" % [k, nom])
		k += 1
	verifier(not salle.libre(Vector2(118, 400)), "le pied du pilier gauche arrête le héros")
	verifier(not salle.libre(Vector2(515, 372)), "le rocher arrête le héros")
	print("BILAN carte 3D : %d échec(s)" % echecs)
	quit()
