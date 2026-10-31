extends Control
## Banc d'essai à jouer soi-même : la grande salle 5 et sa maquette 3D invisible (outils/carte3d.py).
## Le héros arrive seul dans la salle (pas d'ennemis, sorties murées) ; se déplacer comme en jeu.
## F1 : montre ou cache la maquette (vert = sol où l'on marche, rouge = obstacles, bleu = ce qui passe
## devant le héros, jaune = sorties). Fermer la fenêtre pour quitter. Lancer :
##   Godot_v4.7.2-stable_win64.exe --path . res://tests/essai_grande5.tscn   (ou essai_grande5.bat)

var salle: SallePeinte
var calque: Node2D
var aide: Label


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color8(20, 18, 26))
	Ecrans.racine = self
	lancer()


func lancer() -> void:
	await get_tree().process_frame
	Sauvegarde.reinitialiser_monde()
	Statistiques.mort = false
	var joueur := Personnage.nouveau()
	var donjon := Donjon.nouveau(joueur)
	var nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
	Ecrans.pile.append(nav)
	add_child(nav)
	for _i in 10:
		await get_tree().process_frame
	salle = nav.salle_peinte
	salle.charger("grande5", -1, false)
	salle.murer(range(salle.donnees["sorties"].size()))
	if salle.presences != null:
		salle.presences.placer([])
	salle.heros.position = salle.sur_le_sol(Vector2(384, 450))
	calque = Calque.new()
	calque.salle = salle
	calque.visible = false
	calque.z_index = 50
	salle.monde.add_child(calque)
	aide = Label.new()
	aide.text = "Grande salle 5 — F1 : montrer la maquette cachée"
	aide.position = Vector2(16, 96)
	aide.add_theme_color_override("font_outline_color", Color.BLACK)
	aide.add_theme_constant_override("outline_size", 6)
	add_child(aide)
	if "--capture" in OS.get_cmdline_user_args():  # vérification : capture avec la maquette, puis quitte
		calque.visible = true
		for _i in 10:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://tests/captures/61_essai_grande5.png")
		get_tree().quit()


## F1 lue à chaque image : l'écran d'exploration garde pour lui toutes les touches (Ecran._input).
var _f1_avant := false


func _process(_delta: float) -> void:
	var f1 := Input.is_physical_key_pressed(KEY_F1)
	if f1 and not _f1_avant and calque != null:
		calque.visible = not calque.visible
		calque.queue_redraw()
	_f1_avant = f1


class Calque extends Node2D:
	var salle: SallePeinte

	func _process(_delta: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		var couleurs := {"marche": Color(0.2, 1, 0.3, 0.28), "obstacles": Color(1, 0.15, 0.1, 0.45),
			"premier_plan": Color(0.2, 0.5, 1, 0.35), "sorties": Color(1, 0.9, 0.1, 0.35)}
		for couche in couleurs:
			for poly in salle.donnees[couche]:
				if poly.size() < 3:
					continue
				var c: Color = couleurs[couche]
				draw_colored_polygon(poly, c)
				var bord := PackedVector2Array(poly)
				bord.append(poly[0])
				draw_polyline(bord, Color(c, 0.9), 1.5)
		var pied: Vector2 = salle.heros.position
		draw_circle(pied, salle.hauteur(pied.y) * 0.1, Color(1, 1, 1, 0.8), false, 1.5)
