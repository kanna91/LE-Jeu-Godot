extends Ecran
## Choix du sort offensif de départ, au début d'une nouvelle partie (menu_sort_depart.py).
## Résultat : sort appris, ou null (« Choisir plus tard » / Échap : le point de magie reste).

const LARGEUR_CARTE := 280
const HAUTEUR_CARTE := 112
const ECART := 12
const HAUT_GRILLE := 96

var joueur
var choix := []
var cartes := []
var btn_apprendre: Rect2
var btn_plus_tard: Rect2
var selection = null


func preparer(j) -> Ecran:
	fond_ecran = "salles/menu_navigation.png"
	joueur = j
	choix = Sorts.sorts_de_depart(j)
	var x0 := (Ui.LARGEUR - (3 * LARGEUR_CARTE + 2 * ECART)) / 2
	for i in choix.size():
		cartes.append(Rect2(x0 + (i % 3) * (LARGEUR_CARTE + ECART), HAUT_GRILLE + (i / 3) * (HAUTEUR_CARTE + ECART),
			LARGEUR_CARTE, HAUTEUR_CARTE))
	var bas: float = cartes[-1].end.y if not cartes.is_empty() else 300.0
	btn_apprendre = Rect2(Ui.LARGEUR / 2 - 230, bas + 16, 220, 40)
	btn_plus_tard = Rect2(Ui.LARGEUR / 2 + 10, bas + 16, 220, 40)
	return self


static func _sous_titre(sort) -> String:
	var element = Sorts.element_de(sort)
	var attribut: String = Sorts.NOMS_ATTRIBUTS.get(Sorts.ATTRIBUT_ELEMENT.get(element), "")
	var morceaux := []
	for m in [Sorts.NOMS_ELEMENTS.get(element, str(element)), attribut, "%d mana" % sort.cout_mana, "%d PA" % sort.cout_action]:
		if m != "":
			morceaux.append(m)
	return " · ".join(morceaux)


func _dessiner(ci: Control) -> void:
	Ui.voile(ci, 110)
	var s := souris()
	var x0: float = cartes[0].position.x
	Ui.panneau(ci, Rect2(x0 - 16, 20, Ui.LARGEUR - 2 * (x0 - 16), btn_apprendre.end.y - 4 - 20))
	Ui.texte(ci, "Choisissez votre sort de départ", Vector2(Ui.LARGEUR / 2, 32), Ui.OR, 22, true, null, "midtop")
	Ui.texte(ci, "Vous connaissez déjà Soin. Ce sort offensif s'ajoute à vos magies ; l'attribut indiqué servira aux sorts plus puissants du même élément.",
		Vector2(Ui.LARGEUR / 2, 64), Ui.DETAIL, 13, false, Ui.LARGEUR - 120, "midtop")
	for i in choix.size():
		var r: Rect2 = cartes[i]
		var sort = choix[i]
		var choisi: bool = selection == i
		var survol := r.has_point(s)
		Ui.rect(ci, r, Ui.LIGNE_SURVOL if (survol or choisi) else Ui.LIGNE, 0, 8)
		Ui.rect(ci, r, Ui.OR if (survol or choisi) else Ui.BRONZE, 3 if choisi else 1, 8)
		Ui.texte(ci, sort.nom, r.position + Vector2(12, 8), Ui.OR if choisi else Ui.BLANC, 18, true, r.size.x - 24)
		Ui.texte(ci, _sous_titre(sort), r.position + Vector2(12, 32), Ui.DETAIL, 13, false, r.size.x - 24)
		var lignes := Ui.decouper(sort.description, 13, false, r.size.x - 24)
		for k in mini(3, lignes.size()):
			Ui.texte(ci, lignes[k], r.position + Vector2(12, 54 + k * 17), Ui.TEXTE, 13, false, r.size.x - 24)
	Ui.bouton(ci, btn_apprendre, "Apprendre", Ui.BOUTON_VERT, btn_apprendre.has_point(s), selection != null)
	Ui.bouton(ci, btn_plus_tard, "Choisir plus tard", Ui.BOUTON_NEUTRE, btn_plus_tard.has_point(s))
	var z := []
	for i in cartes.size():
		z.append([["sort", i], cartes[i]])
	z.append([["apprendre"], btn_apprendre])
	z.append([["plus_tard"], btn_plus_tard])
	definir_zones(z, ["sort", 0])


func _evenement(ev: Dictionary) -> void:
	if ev["type"] == "touche":
		if ev["touche"] == KEY_ESCAPE:
			fermer(null)
		elif ev["touche"] in [KEY_ENTER, KEY_KP_ENTER] and selection != null:
			if joueur.apprendre_magie(choix[selection]):
				fermer(choix[selection])
	elif ev["type"] == "clic" and ev["bouton"] == 1:
		if btn_plus_tard.has_point(ev["pos"]):
			fermer(null)
			return
		if btn_apprendre.has_point(ev["pos"]) and selection != null:
			if joueur.apprendre_magie(choix[selection]):
				fermer(choix[selection])
				return
		for i in cartes.size():
			if cartes[i].has_point(ev["pos"]):
				selection = i
