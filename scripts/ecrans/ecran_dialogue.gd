extends Ecran
## Dialogue avec un personnage ou un événement du donjon d'aventure (Aventure, Rencontres) : un titre, un texte,
## et 1 à 4 choix (boutons, touches 1 à 4). Résultat : l'indice du choix (Échap : le dernier choix, s'il y en a
## plusieurs ; sinon 0). Affiché par-dessus l'image de l'exploration, en bas de l'écran.

var titre := ""
var texte := ""
var choix: Array = []
var couleur := Ui.OR
var fond: Texture2D
var cadre := Rect2(60, Ui.HAUTEUR - 250, Ui.LARGEUR - 120, 236)
var boutons: Array = []
var lignes: Array = []


func preparer(t: String, contenu: String, options: Array, image_fond: Texture2D = null, teinte := Ui.OR) -> Ecran:
	titre = t
	texte = contenu
	choix = options if not options.is_empty() else ["Continuer"]
	fond = image_fond
	couleur = teinte
	particules_fond = false
	lignes = Ui.decouper(texte, 16, false, cadre.size.x - 40)
	var hauteur_texte := 46 + lignes.size() * Ui.hauteur_ligne(16)
	var largeur := minf(260.0, (cadre.size.x - 40 - 12 * (choix.size() - 1)) / choix.size())
	if choix.size() > 2:
		largeur = (cadre.size.x - 40 - 12 * (choix.size() - 1)) / choix.size()
	cadre.size.y = maxf(150.0, hauteur_texte + 70)
	cadre.position.y = Ui.HAUTEUR - 14 - cadre.size.y
	var total := largeur * choix.size() + 12 * (choix.size() - 1)
	for i in choix.size():
		boutons.append(Rect2(cadre.get_center().x - total / 2 + i * (largeur + 12), cadre.end.y - 50, largeur, 36))
	return self


func _dessiner(ci: Control) -> void:
	var s := souris()
	if fond != null:
		ci.draw_texture_rect(fond, Rect2(0, 0, Ui.LARGEUR, Ui.HAUTEUR), false)
		Ui.voile(ci, 90)
	Ui.panneau(ci, cadre, 230)
	Ui.rect(ci, cadre, couleur, 2, 8)
	Ui.texte(ci, titre, Vector2(cadre.position.x + 20, cadre.position.y + 12), couleur, 20, true)
	var y := cadre.position.y + 46
	for ligne in lignes:
		Ui.texte(ci, ligne, Vector2(cadre.position.x + 20, y), Ui.TEXTE, 16)
		y += Ui.hauteur_ligne(16)
	var z := []
	for i in boutons.size():
		var r: Rect2 = boutons[i]
		var libelle := ("%d. " % (i + 1) if choix.size() > 1 else "") + String(choix[i])
		Ui.bouton(ci, r, libelle, Color8(150, 110, 40) if i == 0 else Ui.BOUTON_NEUTRE, r.has_point(s), true, 15)
		z.append([["choix", i], r])
	definir_zones(z, ["choix", 0])


func _evenement(ev: Dictionary) -> void:
	if ev["type"] == "touche":
		var t: int = ev["touche"]
		if t >= KEY_1 and t < KEY_1 + choix.size():
			fermer(t - KEY_1)
		elif t == KEY_ESCAPE:
			fermer(choix.size() - 1 if choix.size() > 1 else 0)
		elif t in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and choix.size() == 1:
			fermer(0)
	elif ev["type"] == "clic" and ev["bouton"] == 1:
		for i in boutons.size():
			if boutons[i].has_point(ev["pos"]):
				fermer(i)
				return
