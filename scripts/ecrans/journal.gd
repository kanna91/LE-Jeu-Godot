extends Ecran
## Journal du joueur (donjon d'aventure) : ce que les diablotins lui ont appris, classé par sujet, le plus récent
## en haut de chaque sujet (``Rencontres.noter_journal``). Touche J (exploration) ou menu Pause. Molette, flèches :
## défiler ; Échap, J ou « Fermer » : fermer.

var joueur
var fond_capture: Texture2D
var cadre := Rect2(70, 50, Ui.LARGEUR - 140, Ui.HAUTEUR - 110)
var bouton := Rect2(Ui.LARGEUR - 200, Ui.HAUTEUR - 52, 130, 36)
## Lignes à afficher : [texte, couleur, taille, gras].
var lignes: Array = []
var defilement := 0
var visibles := 1


func preparer(j, capture: Texture2D) -> Ecran:
	joueur = j
	fond_capture = capture
	particules_fond = false
	var entrees: Array = U.ga(j, "journal", [])
	var sujets := []
	for e in entrees:
		if not (e["sujet"] in sujets):
			sujets.append(e["sujet"])
	var largeur := cadre.size.x - 50
	for sujet in sujets:
		lignes.append([sujet, Ui.OR, 18, true])
		var du_sujet := entrees.filter(func(e): return e["sujet"] == sujet)
		du_sujet.reverse()
		for e in du_sujet:
			var texte: String = e["texte"] if String(sujet).begins_with("Étage") else "Étage %d — %s" % [int(e.get("etage", 1)), e["texte"]]
			var morceaux := Ui.decouper(texte, 15, false, largeur)
			for k in morceaux.size():
				lignes.append([("• " if k == 0 else "   ") + String(morceaux[k]), Ui.TEXTE, 15, false])
		lignes.append(["", Ui.TEXTE, 8, false])
	if lignes.is_empty():
		lignes.append(["Rien pour l'instant. Les diablotins savent beaucoup de choses...", Ui.DETAIL, 15, false])
	visibles = int((cadre.size.y - 70) / Ui.hauteur_ligne(15))
	return self


func _dessiner_fond(ci: Control) -> void:
	if fond_capture != null:
		ci.draw_texture_rect(fond_capture, Rect2(0, 0, Ui.LARGEUR, Ui.HAUTEUR), false)


func _dessiner(ci: Control) -> void:
	Ui.voile(ci, 200)
	Ui.panneau(ci, cadre, 235)
	Ui.texte(ci, "Journal", Vector2(Ui.LARGEUR / 2, cadre.position.y + 22), Ui.OR, 24, true, null, "center")
	var y := cadre.position.y + 52
	for i in range(defilement, mini(lignes.size(), defilement + visibles)):
		var l: Array = lignes[i]
		Ui.texte(ci, l[0], Vector2(cadre.position.x + 24, y), l[1], l[2], l[3])
		y += Ui.hauteur_ligne(15)
	if lignes.size() > visibles:
		Ui.texte(ci, "Molette ou flèches : défiler (%d/%d)" % [mini(lignes.size(), defilement + visibles), lignes.size()],
			Vector2(cadre.position.x + 24, cadre.end.y + 18), Ui.DETAIL, 12, false, null, "midleft")
	Ui.bouton(ci, bouton, "Fermer", Ui.BOUTON_ROUGE, bouton.has_point(souris()))
	definir_zones([[["fermer"], bouton]], ["fermer"])


func _defiler(pas: int) -> void:
	defilement = clampi(defilement + pas, 0, maxi(0, lignes.size() - visibles))


func _evenement(ev: Dictionary) -> void:
	if ev["type"] == "touche":
		if ev["touche"] in [KEY_ESCAPE, KEY_J]:
			fermer()
		elif ev["touche"] in [KEY_DOWN, KEY_S]:
			_defiler(1)
		elif ev["touche"] in [KEY_UP, KEY_Z, KEY_W]:
			_defiler(-1)
	elif ev["type"] == "molette":
		_defiler(-3 if int(ev["sens"]) > 0 else 3)
	elif ev["type"] == "clic" and ev["bouton"] == 1 and bouton.has_point(ev["pos"]):
		fermer()
