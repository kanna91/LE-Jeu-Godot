extends Ecran
## Inventaire : objets par catégorie (liste défilante, potions
## empilées), dix emplacements d'équipement, résumé des statistiques. Double-clic
## (A A) : équiper / utiliser ; sur un emplacement : retirer.

const ZONE_LISTE := Rect2(20, 102, 430, 376)
const HAUTEUR_LIGNE := 46
const PANNEAU_EQUIPEMENT := Rect2(480, 20, 460, 458)
## Catégories (« Divers » ajoutée le 2026-10-31 : objets neutres et clés du héros ; « Nourriture » et « Ingrédients »
## le 2026-11-03), sur deux rangées.
const BOUTONS_CATEGORIES := {"Armes": Rect2(20, 6, 100, 30), "Armures": Rect2(124, 6, 100, 30),
	"Bijoux": Rect2(228, 6, 100, 30), "Consommables": Rect2(332, 6, 118, 30),
	"Nourriture": Rect2(20, 38, 138, 30), "Ingrédients": Rect2(162, 38, 138, 30), "Divers": Rect2(304, 38, 146, 30)}
const BOUTON_QUITTER := Rect2(Ui.LARGEUR - 140, Ui.HAUTEUR - 50, 120, 34)
const DELAI_DOUBLE_CLIC := 0.4
const LIGNE := Color8(40, 36, 52)
const LIGNE_SURVOL := Color8(70, 62, 92)
const BORDURE := Color8(150, 110, 60)
const JAUNE := Color8(255, 255, 0)

static var categorie_active := "Armes"
static var tri_actif := "arrivee"

var joueur
var emplacements := {}
var boutons_tri := {}
var objets_visuels := []
var clics := {}
var defilement := 0.0
var message := ""
var message_fin := 0.0
var _survol_objet = null
var _survol_porte = null


func preparer(j) -> Ecran:
	fond_ecran = "menu_inventaire.png"
	joueur = j
	for i in Objets.EMPLACEMENTS_EQUIPEMENT.size():
		emplacements[Objets.EMPLACEMENTS_EQUIPEMENT[i]] = Rect2(PANNEAU_EQUIPEMENT.position.x + 16 + (i / 5) * 220,
			PANNEAU_EQUIPEMENT.position.y + 44 + (i % 5) * 52, 208, 46)
	var modes := DescriptionObjet.MODES_TRI.keys()
	for i in modes.size():
		boutons_tri[modes[i]] = Rect2(76 + i * 96, 72, 90, 26)
	couche_decoupee(ZONE_LISTE, _dessiner_liste)
	return self


static func objets_de_categorie(j, categorie: String) -> Array:
	return de_categorie(j.inventaire, categorie)


## Objets d'une liste qui appartiennent à une catégorie (filtrer_objets du marchand).
static func de_categorie(objets: Array, categorie: String) -> Array:
	var liste := []
	for o in objets:
		var ok := true
		match categorie:
			"Armes":
				ok = o.est_arme()
			"Armures":
				ok = o.est_armure()
			"Bijoux":
				ok = o.est_bijou()
			"Consommables":
				ok = o.est_consommable()
			"Nourriture":
				ok = o.est_nourriture()
			"Ingrédients":
				ok = o.est_ingredient()
			"Divers":
				ok = o.est_divers() and not o.est_nourriture() and not o.est_ingredient()
		if ok:
			liste.append(o)
	return liste


## Courte ligne : type (famille, orientation) et principales statistiques.
static func resume_objet(objet) -> String:
	if objet.est_consommable():
		return DescriptionObjet.effet_consommable(objet)
	if objet.est_nourriture():
		return "%s · %s" % [DescriptionObjet.effet_nourriture(objet), String(U.ga(objet, "description", ""))]
	if String(objet.nom) == "Seau en bois":
		return "Eau : %d / 10 litres" % int(U.num(objet, "eau"))
	if String(objet.nom) == "Brandon allumé":
		return "Bois allumé : à poser en feu de camp (touche K) avant qu'il s'éteigne"
	if objet.est_divers():
		return String(U.ga(objet, "description", ""))
	var stats := DescriptionObjet.statistiques(objet)
	var debut: String
	if objet.est_arme():
		var t = U.ga(objet, "type_arme", "")
		debut = DescriptionObjet.NOMS_ARMES.get(t, t)
	else:
		debut = DescriptionObjet.NOMS_EMPLACEMENTS.get(U.ga(objet, "type_armure", ""), "")
	var precisions := []
	for x in [DescriptionObjet.NOMS_FAMILLES.get(DescriptionObjet.famille(objet)), DescriptionObjet.NOMS_ORIENTATIONS.get(U.ga(objet, "orientation", null))]:
		if x != null:
			precisions.append(String(x).to_lower())
	if not precisions.is_empty():
		debut = "%s (%s)" % [debut, ", ".join(precisions)]
	var textes := []
	for s in stats.slice(0, 2):
		textes.append(s[3])
	var morceaux := []
	for x in [debut, ", ".join(textes)]:
		if x != "":
			morceaux.append(x)
	return " · ".join(morceaux)


## Équipe un objet, ou utilise un consommable (sans PA hors combat) ; renvoie le message.
static func utiliser_ou_equiper(j, objet) -> String:
	if objet.est_consommable():
		var pv = j.points_de_vie
		var mana = j.mana
		objet.utiliser(j)
		if objet in j.inventaire:
			j.inventaire.erase(objet)
		var gains := []
		if j.points_de_vie > pv:
			gains.append("+%d PV" % int(j.points_de_vie - pv))
		if j.mana > mana:
			gains.append("+%d mana" % int(j.mana - mana))
		return "%s utilisée : %s" % [objet.nom, ", ".join(gains) if not gains.is_empty() else "aucun effet (déjà au maximum)"]
	if objet.est_nourriture():
		return ObjetsDivers.manger(j, objet)
	if String(U.ga(objet, "sorte", "")) == "page":
		return Cuisine.lire_page(j, objet)
	if objet.est_ingredient():
		return "%s ne se mange pas tel quel (il servira à cuisiner)." % objet.nom
	if objet.est_divers():
		return "%s ne s'utilise pas." % objet.nom
	if DescriptionObjet.emplacement_cible(j, objet) != null:
		var cle = j.equiper_item(objet)
		return "%s équipé (%s)." % [objet.nom, DescriptionObjet.NOMS_EMPLACEMENTS.get(cle, "")]
	return "%s ne peut pas être équipé." % objet.nom


func _double_clic(cle) -> bool:
	var maintenant := Animations.temps()
	var k := str(cle)
	if clics.has(k) and maintenant - clics[k] < DELAI_DOUBLE_CLIC:
		clics.erase(k)
		return true
	clics[k] = maintenant
	return false


func _liste() -> Array:
	var liste := DescriptionObjet.trier(DescriptionObjet.regrouper(objets_de_categorie(joueur, categorie_active)), tri_actif)
	if categorie_active == "Divers" and nombre_cles(joueur) > 0:
		liste.push_front([ObjetsDivers.objet_cles(), nombre_cles(joueur), "cles"])  # les clés en tête
	if categorie_active == "Divers":
		for e in U.ga(joueur, "cles_boss", []):
			liste.push_front([ObjetsDivers.objet_cle_boss(int(e)), 1, "cle_boss_%d" % int(e)])
	return liste


## Clés du héros (compteur ``cles``), montrées en tête de la catégorie « Divers ».
static func nombre_cles(j) -> int:
	return int(U.ga(j, "cles", 0))


## Nombre affiché sur le bouton d'une catégorie (« Divers » compte aussi les clés).
static func compte_categorie(j, categorie: String) -> int:
	return objets_de_categorie(j, categorie).size() + ((nombre_cles(j) + U.ga(j, "cles_boss", []).size()) if categorie == "Divers" else 0)


func _mise_a_jour(_delta: float) -> void:
	var liste := _liste()
	var defilement_max := maxf(0, liste.size() * HAUTEUR_LIGNE - ZONE_LISTE.size.y + 8)
	objets_visuels.clear()
	for i in liste.size():
		var r := Rect2(ZONE_LISTE.position.x + 4, ZONE_LISTE.position.y + 4 + i * HAUTEUR_LIGNE - defilement, ZONE_LISTE.size.x - 18, HAUTEUR_LIGNE - 6)
		objets_visuels.append([liste[i][0], r, liste[i][2], liste[i][1]])
	# Manette : la liste défile pour montrer l'objet sélectionné
	var cle = Manette.cle_selectionnee(self)
	for ov in objets_visuels:
		if cle == ["objet", ov[2]]:
			if ov[1].end.y > ZONE_LISTE.end.y:
				defilement += ov[1].end.y - ZONE_LISTE.end.y
			elif ov[1].position.y < ZONE_LISTE.position.y + 4:
				defilement -= ZONE_LISTE.position.y + 4 - ov[1].position.y
			break
	defilement = clampf(defilement, 0, defilement_max)


func _dessiner_liste(ci: Control) -> void:
	var s := souris()
	for ov in objets_visuels:
		var objet = ov[0]
		var r: Rect2 = ov[1]
		if r.end.y < ZONE_LISTE.position.y or r.position.y > ZONE_LISTE.end.y:
			continue
		var survol := r.has_point(s) and ZONE_LISTE.has_point(s)
		var rg := DescriptionObjet.rang(objet)
		Ui.rect(ci, r, LIGNE_SURVOL if survol else LIGNE, 0, 5)
		Ui.rect(ci, Rect2(r.position, Vector2(5, r.size.y)), rg[1], 0, 2)
		Ui.texte(ci, objet.nom, r.position + Vector2(14, 4), rg[1], 16, true, r.size.x - 80)
		if ov[3] > 1:
			Ui.texte(ci, "×%d" % ov[3], Vector2(r.end.x - 12, r.position.y + 4), JAUNE, 16, true, null, "topright")
		Ui.texte(ci, resume_objet(objet), r.position + Vector2(14, 23), DescriptionObjet.COULEUR_DETAIL, 13, false, r.size.x - 24)


func _dessiner(ci: Control) -> void:
	var s := souris()
	for nom in BOUTONS_CATEGORIES:
		var r: Rect2 = BOUTONS_CATEGORIES[nom]
		var actif: bool = nom == categorie_active
		Ui.rect(ci, r, BORDURE if actif else LIGNE, 0, 6)
		Ui.rect(ci, r, BORDURE, 1, 6)
		Ui.texte(ci, "%s (%d)" % [nom, compte_categorie(joueur, nom)], r.get_center(), Ui.BLANC, 14, actif, null, "center")
	Ui.texte(ci, "Trier :", Vector2(22, 76), DescriptionObjet.COULEUR_DETAIL, 14, true)
	for mode in boutons_tri:
		Ui.onglet(ci, boutons_tri[mode], DescriptionObjet.MODES_TRI[mode], mode == tri_actif, boutons_tri[mode].has_point(s), 14)
	Ui.rect(ci, ZONE_LISTE.grow(4), Color8(12, 10, 16, 200), 0, 8)
	Ui.rect(ci, ZONE_LISTE.grow(4), BORDURE, 1, 8)
	_survol_objet = null
	for ov in objets_visuels:
		if ov[1].has_point(s) and ZONE_LISTE.has_point(s):
			_survol_objet = [ov[0], ov[1]]
	if objets_visuels.is_empty():
		Ui.texte(ci, "Aucun objet dans cette catégorie.", ZONE_LISTE.position + Vector2(14, 14), DescriptionObjet.COULEUR_DETAIL, 15)
	var defilement_max := maxf(0, objets_visuels.size() * HAUTEUR_LIGNE - ZONE_LISTE.size.y + 8)
	Ui.ascenseur(ci, ZONE_LISTE, defilement, defilement_max, ZONE_LISTE.end.x - 8)
	Ui.rect(ci, PANNEAU_EQUIPEMENT, Color8(12, 10, 16, 200), 0, 8)
	Ui.rect(ci, PANNEAU_EQUIPEMENT, BORDURE, 1, 8)
	Ui.texte(ci, "Équipement", PANNEAU_EQUIPEMENT.position + Vector2(16, 12), DescriptionObjet.COULEUR_TITRE, 18, true)
	var cible = DescriptionObjet.emplacement_cible(joueur, _survol_objet[0]) if _survol_objet != null else null
	_survol_porte = null
	for nom in emplacements:
		var r: Rect2 = emplacements[nom]
		var porte = joueur.equipements.get(nom)
		var survol := r.has_point(s)
		Ui.rect(ci, r, LIGNE_SURVOL if survol else LIGNE, 0, 5)
		var type_emplacement: String = "anneau" if String(nom).begins_with("anneau") else nom
		var couleur_famille: Color = DescriptionObjet.COULEURS_FAMILLES.get(DescriptionObjet.FAMILLES.get(type_emplacement), DescriptionObjet.COULEUR_DETAIL)
		Ui.texte(ci, DescriptionObjet.NOMS_EMPLACEMENTS[nom], r.position + Vector2(12, 4), couleur_famille, 12, true)
		if porte != null:
			var couleur_rang: Color = DescriptionObjet.rang(porte)[1]
			Ui.rect(ci, Rect2(r.position, Vector2(5, r.size.y)), couleur_rang, 0, 2)
			Ui.texte(ci, porte.nom, r.position + Vector2(12, 21), couleur_rang, 15, true, r.size.x - 20)
			if survol:
				_survol_porte = [porte, r]
		else:
			Ui.texte(ci, "— vide —", r.position + Vector2(12, 22), Color8(110, 110, 120), 14)
		if nom == cible:
			Ui.rect(ci, r, JAUNE, 2, 5)
	var dernier: Rect2 = emplacements[Objets.EMPLACEMENTS_EQUIPEMENT[-1]]
	var zone := Rect2(PANNEAU_EQUIPEMENT.position.x + 16, dernier.end.y + 14, PANNEAU_EQUIPEMENT.size.x - 32, 70)
	var valeurs := [["PV", "%d / %d" % [int(joueur.points_de_vie), int(joueur.points_de_vie_max)]],
		["Mana", "%d / %d" % [int(joueur.mana), int(joueur.mana_max)]],
		["Armure", U.g(joueur.armure)],
		["Rés. m/é", "%s / %s" % [U.g(joueur.resistance_magique), U.g(U.num(joueur, "resistance_elementaire"))]],
		["Toucher", "%s %%" % U.f(joueur.chance_de_toucher * 100)],
		["Critique", "%s %% ×%s" % [U.f(joueur.chance_de_coup_critique * 100), U.f(joueur.degats_critique, 2)]],
		["Force", U.g(joueur.force)], ["Puiss. magique", U.g(joueur.puissance_magique)], ["Or", str(int(joueur.piece_or))]]
	for i in valeurs.size():
		var x := zone.position.x + (i % 3) * int(zone.size.x / 3)
		var y := zone.position.y + (i / 3) * 22
		Ui.texte(ci, "%s : %s" % valeurs[i], Vector2(x, y), Ui.BLANC, 13, false, int(zone.size.x / 3) - 6)
	Ui.texte(ci, "Double-clic (A A) : équiper / utiliser · sur un emplacement : retirer", Vector2(24, Ui.HAUTEUR - 44), DescriptionObjet.COULEUR_DETAIL, 13)
	if message != "" and Animations.temps() < message_fin:
		Ui.texte(ci, message, Vector2(24, Ui.HAUTEUR - 26), DescriptionObjet.COULEUR_TITRE, 14, true, Ui.LARGEUR - 200)
	Ui.rect(ci, BOUTON_QUITTER, Color8(200, 50, 50), 0, 6)
	Ui.texte(ci, "Quitter", BOUTON_QUITTER.get_center(), Ui.BLANC, 16, true, null, "center")
	var z := []
	for nom in BOUTONS_CATEGORIES:
		z.append([["categorie", nom], BOUTONS_CATEGORIES[nom]])
	for mode in boutons_tri:
		z.append([["tri", mode], boutons_tri[mode]])
	for ov in objets_visuels:
		z.append([["objet", ov[2]], ov[1]])
	for nom in emplacements:
		z.append([["emplacement", nom], emplacements[nom]])
	z.append([["quitter"], BOUTON_QUITTER])
	definir_zones(z, ["objet", objets_visuels[0][2]] if not objets_visuels.is_empty() else ["categorie", categorie_active])


func _dessiner_dessus(ci: Control) -> void:
	if _survol_objet != null:
		var aide = "Double-clic : manger" if _survol_objet[0].est_nourriture() else "Double-clic : lire" if String(U.ga(_survol_objet[0], "sorte", "")) == "page" else null if _survol_objet[0].est_divers() else ("Double-clic : utiliser" if _survol_objet[0].est_consommable() else "Double-clic : équiper")
		DescriptionObjet.dessiner_infobulle(ci, _survol_objet[0], _survol_objet[1], joueur, null, aide)
	elif _survol_porte != null:
		DescriptionObjet.dessiner_infobulle(ci, _survol_porte[0], _survol_porte[1], null, null, "Double-clic : retirer")


func _evenement(ev: Dictionary) -> void:
	if ev["type"] == "touche" and ev["touche"] == KEY_ESCAPE:
		fermer()
	elif ev["type"] == "molette":
		defilement -= ev["sens"] * 30
	elif ev["type"] == "clic" and ev["bouton"] == 1:
		var pos: Vector2 = ev["pos"]
		for nom in BOUTONS_CATEGORIES:
			if BOUTONS_CATEGORIES[nom].has_point(pos) and nom != categorie_active:
				categorie_active = nom
				defilement = 0
		for mode in boutons_tri:
			if boutons_tri[mode].has_point(pos):
				tri_actif = mode
		if BOUTON_QUITTER.has_point(pos):
			fermer()
			return
		if ZONE_LISTE.has_point(pos):
			for ov in objets_visuels:
				if ov[1].has_point(pos) and _double_clic(["objet", ov[2]]):
					message = utiliser_ou_equiper(joueur, ov[0])
					message_fin = Animations.temps() + 2.5
					break
		for nom in emplacements:
			if emplacements[nom].has_point(pos) and _double_clic(["emplacement", nom]):
				var porte = joueur.equipements.get(nom)
				if porte != null:
					joueur.desequiper_item(nom)
					message = "%s retiré et rangé dans l'inventaire." % porte.nom
					message_fin = Animations.temps() + 2.5
