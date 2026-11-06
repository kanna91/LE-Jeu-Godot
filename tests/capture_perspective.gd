extends SceneTree
## Perspective des salles peintes (outils/mesurer_perspective.py, 2026-11-05) : le héros au haut du sol, au milieu
## et en bas de quelques salles ; captures perspective_<salle>_N. Vérifie aussi que, partout, le héros garde au
## moins 20 % de sa taille de près (30 % sauf réglage à la main) au haut du sol et que l'écrasement des pas en profondeur diminue vers le fond.
## « BILAN perspective : 0 échec(s) ». À lancer dans une fenêtre hors écran (override.cfg, voir README).

var racine: Control
var echecs := 0
const SALLES := ["grande5", "crypte7", "couloir_livre25", "culdesac1", "prison9", "salle2"]


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


func lancer() -> void:
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	var nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
	Ecrans.pile.append(nav)
	racine.add_child(nav)
	await attendre(10)
	var salle: SallePeinte = nav.salle_peinte
	# Toutes les salles : taille au haut du sol et écrasement de la profondeur
	var dossier := DirAccess.open("res://donnees/salles_peintes")
	var nombre := 0
	for f in dossier.get_files():
		if not f.ends_with(".json"):
			continue
		salle.donnees = SallePeinte.lire_salle(f.get_basename())
		var table: Array = salle.donnees["perspective"]["table_hauteur"]
		var haut := float(table[0][0])
		var pres := salle.hauteur(511.0)
		verifier(salle.hauteur(haut) >= 0.2 * pres, "%s : héros trop petit au fond (%.0f / %.0f)" % [f, salle.hauteur(haut), pres])
		verifier(salle.compression(haut) < salle.compression(500.0), "%s : la profondeur n'est pas plus écrasée au fond" % f)
		nombre += 1
	print("%d salles vérifiées" % nombre)
	for ident in SALLES:
		salle.charger(ident, -1, false)
		salle.murer([])
		if salle.presences != null:
			salle.presences.placer([])
		await attendre(6)
		var table: Array = salle.donnees["perspective"]["table_hauteur"]
		var haut := float(table[0][0])
		var k := 0
		for y in [haut + 4.0, lerpf(haut, 505.0, 0.4), 490.0]:
			var p := salle.sur_le_sol(Vector2(384, y))
			salle.heros.position = p
			await attendre(4)
			print("  %s : pieds y=%.0f, taille %.0f px" % [ident, p.y, salle.hauteur(p.y)])
			root.get_viewport().get_texture().get_image().save_png("res://tests/captures/perspective_%s_%d.png" % [ident, k])
			k += 1
	print("BILAN perspective : %d échec(s)" % echecs)
	quit()
