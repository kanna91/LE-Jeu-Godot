extends Ecran
## Emplacements de sauvegarde, pour sauvegarder ou charger (menu_partie.choisir_emplacement).
## En mode « sauvegarder », un emplacement occupé demande un second clic ; en mode
## « charger », la sauvegarde automatique est proposée et les emplacements vides sont grisés.
## Résultat : nom de l'emplacement, ou null.

var mode := "charger"
var noms := []
var libelles := {}
var rects := {}
var bouton_retour := Rect2(Ui.LARGEUR / 2 - 90, Ui.HAUTEUR - 70, 180, 40)
var a_confirmer = null
var resumes := {}
var fond_capture: Texture2D = null


func preparer(mode_choisi: String, fond = null) -> Ecran:
	mode = mode_choisi
	if fond is Texture2D:
		fond_capture = fond
		particules_fond = false
	else:
		fond_ecran = fond if fond != null else "salles/menu_navigation.png"
	noms = ([Sauvegarde.TEMPORAIRE] if mode == "charger" else []) + Sauvegarde.EMPLACEMENTS
	libelles[Sauvegarde.TEMPORAIRE] = "Partie en cours (sauvegarde automatique)"
	for i in Sauvegarde.EMPLACEMENTS.size():
		libelles[Sauvegarde.EMPLACEMENTS[i]] = "Emplacement %d" % (i + 1)
	for i in noms.size():
		rects[noms[i]] = Rect2(Ui.LARGEUR / 2 - 330, 150 + i * 78, 660, 66)
	return self


func _mise_a_jour(_delta: float) -> void:
	for nom in noms:
		resumes[nom] = Sauvegarde.resume(nom)


func _dessiner_fond(ci: Control) -> void:
	if fond_capture != null:
		ci.draw_texture_rect(fond_capture, Rect2(0, 0, Ui.LARGEUR, Ui.HAUTEUR), false)
	else:
		super(ci)


func _dessiner(ci: Control) -> void:
	Ui.voile(ci, 160)
	var titre := "Sauvegarder la partie" if mode == "sauvegarder" else "Charger une partie"
	Ui.texte(ci, titre, Vector2(Ui.LARGEUR / 2, 90), Ui.OR, 30, true, null, "center")
	var s := souris()
	for nom in noms:
		var r: Rect2 = rects[nom]
		var resume = resumes.get(nom)
		var actif: bool = mode == "sauvegarder" or resume != null
		var survol := r.has_point(s) and actif
		Ui.rect(ci, r, Ui.LIGNE_SURVOL if survol else Ui.LIGNE, 0, 8)
		Ui.rect(ci, r, Ui.OR if a_confirmer == nom else Ui.BRONZE, 2 if a_confirmer == nom else 1, 8)
		Ui.texte(ci, libelles[nom], r.position + Vector2(16, 10), Ui.TEXTE if actif else Ui.GRISE, 17, true)
		var detail := "Cliquez encore pour écraser cette sauvegarde" if a_confirmer == nom else MenuPartie.texte_resume(resume)
		Ui.texte(ci, detail, r.position + Vector2(16, 38), Ui.OR if a_confirmer == nom else Ui.DETAIL, 13, false, r.size.x - 32)
	Ui.bouton(ci, bouton_retour, "Retour", Ui.BOUTON_ROUGE, bouton_retour.has_point(s))
	var z := []
	for nom in noms:
		if mode == "sauvegarder" or resumes.get(nom) != null:
			z.append([["emplacement", nom], rects[nom]])
	z.append([["retour"], bouton_retour])
	definir_zones(z, z[0][0])


func _evenement(ev: Dictionary) -> void:
	if ev["type"] == "touche" and ev["touche"] == KEY_ESCAPE:
		fermer(null)
	elif ev["type"] == "clic" and ev["bouton"] == 1:
		if bouton_retour.has_point(ev["pos"]):
			fermer(null)
			return
		for nom in noms:
			if not rects[nom].has_point(ev["pos"]):
				continue
			if mode == "charger":
				if resumes.get(nom) != null:
					fermer(nom)
			elif resumes.get(nom) == null or a_confirmer == nom:
				fermer(nom)
			else:
				a_confirmer = nom
