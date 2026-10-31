extends Ecran
## Boutique du marchand : onglets Acheter / Vendre / Rachat,
## six catégories (dont « Divers », 2026-10-31), tri, vente en lot (onglet « Vendre », second clic pour
## confirmer), bouton « Inventaire ». Un clic (A) sur un article l'achète, le
## vend ou le rachète.

const ZONE_LISTE := Rect2(20, 106, 470, 372)
const HAUTEUR_LIGNE := 46
const AIDES := {"Acheter": "Clic / A : acheter", "Vendre": "Clic / A : vendre", "Rachat": "Clic / A : racheter"}
const PANNEAU_LOT := Rect2(720, 70, 220, 262)
const DELAI_CONFIRMATION := 3.0
const TROP_CHER := Color8(230, 90, 80)
const LIGNE := Color8(40, 36, 52)
const LIGNE_SURVOL := Color8(70, 62, 92)
const BORDURE := Color8(150, 110, 60)
const JAUNE := Color8(255, 255, 0)
const ONGLETS := {"Acheter": Rect2(20, 20, 110, 34), "Vendre": Rect2(138, 20, 110, 34), "Rachat": Rect2(256, 20, 110, 34)}
const SOUS_ONGLETS := {"Général": Rect2(20, 62, 86, 30), "Armes": Rect2(112, 62, 80, 30), "Armures": Rect2(198, 62, 88, 30),
	"Bijoux": Rect2(292, 62, 76, 30), "Consommables": Rect2(374, 62, 116, 30), "Divers": Rect2(496, 62, 76, 30)}
const BOUTON_INVENTAIRE := Rect2(Ui.LARGEUR - 380, Ui.HAUTEUR - 50, 170, 34)
const BOUTON_QUITTER := Rect2(Ui.LARGEUR - 195, Ui.HAUTEUR - 50, 170, 34)
const BOURSE := Rect2(Ui.LARGEUR - 200, 20, 180, 34)

const MenuInventaire := preload("res://scripts/ecrans/menu_inventaire.gd")

static var tri_actif := "arrivee"

var marchand
var joueur
var onglet := "Acheter"
var categories := {"Acheter": "Général", "Vendre": "Général", "Rachat": "Général"}
var defilement := 0.0
var message := ""
var couleur_message := Ui.OR
var message_fin := 0.0
var boutons_tri := {}
var boutons_lot := {}
var confirmation = null
var confirmation_fin := 0.0
var objets := []
var _survol = null


func preparer(m, j) -> Ecran:
	fond_ecran = "salles/menu_marchand.png"
	marchand = m
	joueur = j
	var modes := DescriptionObjet.MODES_TRI.keys()
	for i in modes.size():
		boutons_tri[modes[i]] = Rect2(436 + i * 86, 20, 80, 34)
	for rang in range(1, Marchand.RANG_MAX_LOT + 1):
		boutons_lot[rang] = Rect2(PANNEAU_LOT.position.x + 10, PANNEAU_LOT.position.y + 52 + (rang - 1) * 41, PANNEAU_LOT.size.x - 20, 35)
	couche_decoupee(ZONE_LISTE, _dessiner_articles)
	return self


static func filtrer_objets(liste: Array, categorie: String) -> Array:
	if categorie == "Général":
		return liste.duplicate()
	return MenuInventaire.de_categorie(liste, categorie)


func prix_affiche(objet) -> int:
	match onglet:
		"Acheter":
			return Marchand.prix_achat(objet, joueur)
		"Rachat":
			return Marchand.prix_rachat(objet, joueur)
	return Marchand.prix_vente(objet, joueur)


func source_onglet() -> Array:
	var source: Array
	if onglet == "Acheter":
		source = U.ga(marchand, "inventaire", null) if U.ga(marchand, "inventaire", null) != null else []
	elif onglet == "Vendre":
		source = joueur.inventaire
	else:
		source = U.ga(marchand, "objets_a_racheter", [])
	return filtrer_objets(source, categories[onglet])


func articles() -> Array:
	return DescriptionObjet.trier(DescriptionObjet.regrouper(source_onglet()), tri_actif)


func transaction(obj) -> Array:
	var prix := prix_affiche(obj)
	if onglet == "Vendre":
		if marchand.vendre(obj, joueur):
			return ["Vendu : %s (+%d PO)" % [obj.nom, prix], Ui.OR]
		return ["%s n'est plus dans votre inventaire." % obj.nom, TROP_CHER]
	if joueur.piece_or < prix:
		return ["Pas assez d'or pour %s : il manque %d PO." % [obj.nom, int(prix - joueur.piece_or)], TROP_CHER]
	var reussi: bool = marchand.acheter(obj, joueur) if onglet == "Acheter" else marchand.racheter(obj, joueur)
	if reussi:
		var equipe: bool = obj in joueur.equipements.values()
		return ["%s : %s (−%d PO)%s" % ["Acheté" if onglet == "Acheter" else "Racheté", obj.nom, prix, " — équipé" if equipe else ""], Ui.OR]
	return ["%s n'est plus disponible." % obj.nom, TROP_CHER]


func _mise_a_jour(_delta: float) -> void:
	var liste := articles()
	var defilement_max := maxf(0, liste.size() * HAUTEUR_LIGNE - ZONE_LISTE.size.y + 8)
	var cle = Manette.cle_selectionnee(self)
	for i in liste.size():
		var r := Rect2(ZONE_LISTE.position.x + 4, ZONE_LISTE.position.y + 4 + i * HAUTEUR_LIGNE - defilement, ZONE_LISTE.size.x - 18, HAUTEUR_LIGNE - 6)
		if cle == ["article", liste[i][2]]:
			if r.end.y > ZONE_LISTE.end.y:
				defilement += r.end.y - ZONE_LISTE.end.y
			elif r.position.y < ZONE_LISTE.position.y + 4:
				defilement -= ZONE_LISTE.position.y + 4 - r.position.y
	defilement = clampf(defilement, 0, defilement_max)
	objets = []
	for i in liste.size():
		var r := Rect2(ZONE_LISTE.position.x + 4, ZONE_LISTE.position.y + 4 + i * HAUTEUR_LIGNE - defilement, ZONE_LISTE.size.x - 18, HAUTEUR_LIGNE - 6)
		objets.append([liste[i][0], r, liste[i][2], liste[i][1]])
	if confirmation != null and Animations.temps() >= confirmation_fin:
		confirmation = null


func _dessiner_articles(ci: Control) -> void:
	var s := souris()
	for o in objets:
		var obj = o[0]
		var r: Rect2 = o[1]
		if r.end.y < ZONE_LISTE.position.y or r.position.y > ZONE_LISTE.end.y:
			continue
		var survol := r.has_point(s) and ZONE_LISTE.has_point(s)
		var prix := prix_affiche(obj)
		var abordable: bool = onglet == "Vendre" or joueur.piece_or >= prix
		var couleur_rang: Color = DescriptionObjet.rang(obj)[1]
		Ui.rect(ci, r, LIGNE_SURVOL if survol else LIGNE, 0, 5)
		Ui.rect(ci, Rect2(r.position, Vector2(5, r.size.y)), couleur_rang, 0, 2)
		Ui.texte(ci, obj.nom, r.position + Vector2(14, 4), couleur_rang, 16, true, r.size.x - 120)
		Ui.texte(ci, MenuInventaire.resume_objet(obj), r.position + Vector2(14, 23), DescriptionObjet.COULEUR_DETAIL, 13, false, r.size.x - 120)
		if o[3] > 1:
			Ui.texte(ci, "%d PO" % prix, Vector2(r.end.x - 10, r.position.y + 4), Ui.OR if abordable else TROP_CHER, 16, true, null, "topright")
			Ui.texte(ci, "×%d" % o[3], Vector2(r.end.x - 10, r.position.y + 23), JAUNE, 14, true, null, "topright")
		else:
			Ui.texte(ci, "%d PO" % prix, Vector2(r.end.x - 10, r.position.y + 12), Ui.OR if abordable else TROP_CHER, 16, true, null, "topright")


func _dessiner(ci: Control) -> void:
	var s := souris()
	for nom in ONGLETS:
		var choisi: bool = nom == onglet
		Ui.rect(ci, ONGLETS[nom], BORDURE if choisi else LIGNE, 0, 6)
		Ui.rect(ci, ONGLETS[nom], BORDURE, 1, 6)
		Ui.texte(ci, nom, ONGLETS[nom].get_center(), Ui.BLANC, 16, choisi, null, "center")
	for nom in SOUS_ONGLETS:
		var choisi: bool = nom == categories[onglet]
		Ui.rect(ci, SOUS_ONGLETS[nom], Color8(95, 75, 45) if choisi else Color8(32, 29, 40), 0, 5)
		Ui.rect(ci, SOUS_ONGLETS[nom], BORDURE if choisi else Color8(70, 62, 80), 1, 5)
		Ui.texte(ci, nom, SOUS_ONGLETS[nom].get_center(), Ui.BLANC, 14, choisi, null, "center")
	Ui.texte(ci, "Trier :", Vector2(boutons_tri["arrivee"].position.x - 6, 29), DescriptionObjet.COULEUR_DETAIL, 14, true, null, "topright")
	for mode in boutons_tri:
		Ui.onglet(ci, boutons_tri[mode], DescriptionObjet.MODES_TRI[mode], mode == tri_actif, boutons_tri[mode].has_point(s), 14)
	if onglet == "Vendre":
		Ui.rect(ci, PANNEAU_LOT, Color8(12, 10, 16, 205), 0, 8)
		Ui.rect(ci, PANNEAU_LOT, BORDURE, 1, 8)
		Ui.texte(ci, "Vente en lot", PANNEAU_LOT.position + Vector2(12, 8), DescriptionObjet.COULEUR_TITRE, 16, true)
		Ui.texte(ci, "%s · légendaires à la main" % categories[onglet], PANNEAU_LOT.position + Vector2(12, 29), DescriptionObjet.COULEUR_DETAIL, 12, false, PANNEAU_LOT.size.x - 24)
		for rang in boutons_lot:
			var r: Rect2 = boutons_lot[rang]
			var a_vendre := Marchand.objets_en_lot(source_onglet(), rang)
			var nom_rang: String = DescriptionObjet.RANGS[rang][0]
			var couleur_rang: Color = DescriptionObjet.RANGS[rang][1]
			Ui.rect(ci, r, LIGNE_SURVOL if r.has_point(s) and not a_vendre.is_empty() else LIGNE, 0, 5)
			Ui.rect(ci, Rect2(r.position, Vector2(5, r.size.y)), couleur_rang, 0, 2)
			if confirmation == rang:
				Ui.rect(ci, r, Ui.OR, 2, 5)
				Ui.texte(ci, "Confirmer ? %d objet(s)" % a_vendre.size(), r.position + Vector2(12, 9), Ui.OR, 14, true)
			else:
				Ui.texte(ci, "≤ " + nom_rang, r.position + Vector2(12, 2), couleur_rang if not a_vendre.is_empty() else Color8(110, 110, 120), 14, true)
				Ui.texte(ci, "%d objet(s)" % a_vendre.size(), r.position + Vector2(12, 18), DescriptionObjet.COULEUR_DETAIL, 12)
			var gain := 0
			for o in a_vendre:
				gain += Marchand.prix_vente(o, joueur)
			Ui.texte(ci, "+%d PO" % gain, Vector2(r.end.x - 10, r.position.y + 9), Ui.OR if not a_vendre.is_empty() else Color8(110, 110, 120), 15, true, null, "topright")
	Ui.rect(ci, ZONE_LISTE.grow(4), Color8(12, 10, 16, 205), 0, 8)
	Ui.rect(ci, ZONE_LISTE.grow(4), BORDURE, 1, 8)
	_survol = null
	for o in objets:
		if o[1].has_point(s) and ZONE_LISTE.has_point(s):
			_survol = [o[0], o[1]]
	if objets.is_empty():
		var vide: String = {"Acheter": "Le marchand n'a rien de ce genre.", "Vendre": "Vous n'avez rien de ce genre à vendre.",
			"Rachat": "Aucun objet vendu à racheter."}[onglet]
		Ui.texte(ci, vide, ZONE_LISTE.position + Vector2(14, 14), DescriptionObjet.COULEUR_DETAIL, 15)
	Ui.ascenseur(ci, ZONE_LISTE, defilement, maxf(0, objets.size() * HAUTEUR_LIGNE - ZONE_LISTE.size.y + 8), ZONE_LISTE.end.x - 8)
	Ui.rect(ci, BOURSE, Color8(12, 10, 16, 205), 0, 8)
	Ui.rect(ci, BOURSE, BORDURE, 1, 8)
	Ui.texte(ci, "Or : %d PO" % int(joueur.piece_or), BOURSE.position + Vector2(14, 8), Ui.OR, 17, true)
	Ui.texte(ci, AIDES[onglet] + " · molette : défiler", Vector2(24, Ui.HAUTEUR - 46), DescriptionObjet.COULEUR_DETAIL, 13)
	if message != "" and Animations.temps() < message_fin:
		Ui.texte(ci, message, Vector2(24, Ui.HAUTEUR - 28), couleur_message, 14, true, BOUTON_INVENTAIRE.position.x - 40)
	Ui.rect(ci, BOUTON_INVENTAIRE, Color8(60, 70, 140), 0, 6)
	Ui.texte(ci, "Inventaire", BOUTON_INVENTAIRE.get_center(), Ui.BLANC, 16, true, null, "center")
	Ui.rect(ci, BOUTON_QUITTER, Color8(200, 50, 50), 0, 6)
	Ui.texte(ci, "Quitter", BOUTON_QUITTER.get_center(), Ui.BLANC, 16, true, null, "center")
	var z := []
	for nom in ONGLETS:
		z.append([["onglet", nom], ONGLETS[nom]])
	for nom in SOUS_ONGLETS:
		z.append([["categorie", nom], SOUS_ONGLETS[nom]])
	for mode in boutons_tri:
		z.append([["tri", mode], boutons_tri[mode]])
	for o in objets:
		z.append([["article", o[2]], o[1]])
	if onglet == "Vendre":
		for rang in boutons_lot:
			z.append([["lot", rang], boutons_lot[rang]])
	z += [[["inventaire"], BOUTON_INVENTAIRE], [["quitter"], BOUTON_QUITTER]]
	definir_zones(z, ["article", objets[0][2]] if not objets.is_empty() else ["onglet", onglet])


func _dessiner_dessus(ci: Control) -> void:
	if _survol == null:
		return
	var prix := prix_affiche(_survol[0])
	var abordable: bool = onglet == "Vendre" or joueur.piece_or >= prix
	var libelle: String = {"Acheter": "Prix", "Vendre": "Vous en obtenez", "Rachat": "Prix de rachat"}[onglet]
	DescriptionObjet.dessiner_infobulle(ci, _survol[0], _survol[1], joueur, ["%s : %d PO" % [libelle, prix], Ui.OR if abordable else TROP_CHER],
		AIDES[onglet] if abordable else "Pas assez d'or")


func _evenement(ev: Dictionary) -> void:
	if ev["type"] == "touche" and ev["touche"] == KEY_ESCAPE:
		fermer()
	elif ev["type"] == "molette":
		defilement -= ev["sens"] * 30
	elif ev["type"] == "clic" and ev["bouton"] == 1:
		var pos: Vector2 = ev["pos"]
		for nom in ONGLETS:
			if ONGLETS[nom].has_point(pos) and nom != onglet:
				onglet = nom
				defilement = 0
		for nom in SOUS_ONGLETS:
			if SOUS_ONGLETS[nom].has_point(pos) and nom != categories[onglet]:
				categories[onglet] = nom
				defilement = 0
				confirmation = null
		for mode in boutons_tri:
			if boutons_tri[mode].has_point(pos):
				tri_actif = mode
		if onglet == "Vendre":
			for rang in boutons_lot:
				if not boutons_lot[rang].has_point(pos):
					continue
				var a_vendre := Marchand.objets_en_lot(source_onglet(), rang)
				if a_vendre.is_empty():
					message = "Aucun objet à vendre jusqu'à ce rang."
					couleur_message = TROP_CHER
				elif confirmation == rang and Animations.temps() < confirmation_fin:
					var resultat: Array = marchand.vendre_lot(a_vendre, joueur)
					confirmation = null
					message = "Vente en lot : %d objet(s) vendu(s) (+%d PO)." % [resultat[0], resultat[1]]
					couleur_message = Ui.OR
				else:
					confirmation = rang
					confirmation_fin = Animations.temps() + DELAI_CONFIRMATION
					message = "Cliquez à nouveau pour confirmer la vente en lot."
					couleur_message = Ui.OR
				message_fin = Animations.temps() + 2.5
		if ZONE_LISTE.has_point(pos):
			for o in objets:
				if o[1].has_point(pos):
					var t := transaction(o[0])
					message = t[0]
					couleur_message = t[1]
					message_fin = Animations.temps() + 2.5
					break
		if BOUTON_INVENTAIRE.has_point(pos):
			await Ecrans.menu_inventaire(joueur)
		elif BOUTON_QUITTER.has_point(pos):
			fermer()
