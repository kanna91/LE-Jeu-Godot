extends Ecran
## Options (2026-10-30, demande de l'utilisateur) : volume de la musique, enregistré dans user://options.cfg
## (Musique.regler_volume). Ouvert depuis le menu principal et le menu pause. Clic sur la barre, boutons − et +,
## flèches gauche et droite ; Échap ou « Fermer » pour sortir.

const PAS := 0.1
var fond_capture: Texture2D
var cadre := Rect2(Ui.LARGEUR / 2 - 260, 140, 520, 250)
var barre := Rect2(Ui.LARGEUR / 2 - 150, 250, 300, 18)
var moins := Rect2(Ui.LARGEUR / 2 - 210, 240, 44, 38)
var plus := Rect2(Ui.LARGEUR / 2 + 166, 240, 44, 38)
var bouton_fermer := Rect2(Ui.LARGEUR / 2 - 90, 322, 180, 42)


func preparer(capture: Texture2D = null) -> Ecran:
	fond_capture = capture
	if capture == null:
		fond_ecran = "salles/menu_navigation.png"
	else:
		particules_fond = false
	return self


func _dessiner_fond(ci: Control) -> void:
	if fond_capture != null:
		ci.draw_texture_rect(fond_capture, Rect2(0, 0, Ui.LARGEUR, Ui.HAUTEUR), false)
	else:
		super(ci)


func _dessiner(ci: Control) -> void:
	Ui.voile(ci, 150)
	Ui.panneau(ci, cadre, 235)
	Ui.texte(ci, "Options", Vector2(Ui.LARGEUR / 2, cadre.position.y + 34), Ui.OR, 26, true, null, "center")
	var volume: float = Musique.volume
	Ui.texte(ci, "Volume de la musique : %d %%" % roundi(volume * 100), Vector2(Ui.LARGEUR / 2, 222), Ui.BLANC, 17, true, null, "center")
	Ui.rect(ci, barre, Color8(40, 36, 50), 0, 6)
	if volume > 0:
		Ui.rect(ci, Rect2(barre.position, Vector2(barre.size.x * volume, barre.size.y)), Ui.OR, 0, 6)
	Ui.rect(ci, barre, Ui.BRONZE, 1, 6)
	var s := souris()
	Ui.bouton(ci, moins, "−", Ui.BOUTON_NEUTRE, moins.has_point(s), volume > 0, 20)
	Ui.bouton(ci, plus, "+", Ui.BOUTON_NEUTRE, plus.has_point(s), volume < 1, 20)
	Ui.bouton(ci, bouton_fermer, "Fermer", Ui.BOUTON_VERT, bouton_fermer.has_point(s), true, 17)
	Ui.texte(ci, "Clic sur la barre, − / + ou flèches gauche et droite.", Vector2(Ui.LARGEUR / 2, 296), Ui.DETAIL, 12,
		false, null, "center")
	definir_zones([[["bouton", "moins"], moins], [["bouton", "plus"], plus], [["bouton", "fermer"], bouton_fermer]],
		["bouton", "fermer"])


func _regler(valeur: float) -> void:
	Musique.regler_volume(snappedf(clampf(valeur, 0.0, 1.0), 0.01))


func _evenement(ev: Dictionary) -> void:
	if ev["type"] == "touche":
		match ev["touche"]:
			KEY_ESCAPE:
				fermer()
			KEY_LEFT:
				_regler(Musique.volume - PAS)
			KEY_RIGHT:
				_regler(Musique.volume + PAS)
		return
	if ev["type"] != "clic" or ev["bouton"] != 1:
		return
	var pos: Vector2 = ev["pos"]
	if bouton_fermer.has_point(pos):
		fermer()
	elif moins.has_point(pos):
		_regler(Musique.volume - PAS)
	elif plus.has_point(pos):
		_regler(Musique.volume + PAS)
	elif barre.grow(8).has_point(pos):
		_regler((pos.x - barre.position.x) / barre.size.x)
