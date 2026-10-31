extends Ecran
## Grimoire (menu_magie.py). Onglet « Magies » : magies connues (clic : améliorer)
## et disponibles par élément et palier (double-clic : apprendre), filtres par
## élément et « Apprenables ». Onglet « Compétences » : compétences de l'arme et
## toutes les compétences de base. Onglet « Altérations » : index des altérations.

const HAUTEUR_LIGNE := 52
const HAUTEUR_TITRE := 24
const HAUT_LISTE := 44
const COMPETENCES_PAR_ARME := [
	["Epée", ["Coup d'épée", "Frénésie"]],
	["Lance", ["Coup de lance", "Balayage"]],
	["Marteau", ["Coup de marteau", "Fracasser"]],
	[null, ["Coup de poing", "Enchainement"]],
]
const NOMS_ARMES := {"Epée": "Épée", "Lance": "Lance", "Marteau": "Marteau"}
const ONGLETS := {"Magies": Rect2(20, 20, 130, 34), "Compétences": Rect2(158, 20, 150, 34), "Altérations": Rect2(316, 20, 140, 34)}
const PANNEAU_GAUCHE := Rect2(20, 70, 450, 400)
const PANNEAU_DROIT := Rect2(490, 70, 450, 400)
const MAGIE_GAUCHE := Rect2(20, 100, 450, 370)
const MAGIE_DROIT := Rect2(490, 100, 450, 370)
const BOUTON_QUITTER := Rect2(Ui.LARGEUR - 140, Ui.HAUTEUR - 50, 120, 34)
const DELAI_DOUBLE_CLIC := 0.4

var joueur
var onglet := "Magies"
var index: IndexAlterations
var boutons_elements := []
var filtre_element = null
var derniere_magie_cliquee = null
var dernier_temps_clic := 0.0
var message := ""
var message_fin := 0.0
var zones_listes := {}
var defilement := {"connue": 0.0, "disponible": 0.0}
var bouton_filtre := Rect2(MAGIE_DROIT.end.x - 136, MAGIE_DROIT.position.y + 9, 124, 26)
var seulement_apprenables := false
var elements := []
var titres := []
var contenus := {"connue": 0.0, "disponible": 0.0}
var _survole = null


func preparer(j) -> Ecran:
	fond_ecran = "fond_magie.png"
	joueur = j
	index = IndexAlterations.new(Rect2(20, 70, 920, 400))
	var filtres: Array = [null] + Sorts.ORDRE_ELEMENTS
	var largeur_filtre := (920 - 4 * (filtres.size() - 1)) / filtres.size()
	for i in filtres.size():
		boutons_elements.append([filtres[i], Rect2(20 + i * (largeur_filtre + 4), 64, largeur_filtre, 28)])
	Sorts.completer_catalogue(j)
	zones_listes["connue"] = Rect2(MAGIE_GAUCHE.position.x + 10, MAGIE_GAUCHE.position.y + HAUT_LISTE, MAGIE_GAUCHE.size.x - 20, MAGIE_GAUCHE.size.y - HAUT_LISTE - 8)
	zones_listes["disponible"] = Rect2(MAGIE_DROIT.position.x + 10, MAGIE_DROIT.position.y + HAUT_LISTE, MAGIE_DROIT.size.x - 20, MAGIE_DROIT.size.y - HAUT_LISTE - 8)
	for liste in zones_listes:
		couche_decoupee(zones_listes[liste], _dessiner_liste.bind(liste))
	couche_decoupee(index.liste, func(ci): if onglet == "Altérations": index.dessiner_cartes(ci, souris()))
	return self


## Compétences de base utilisables avec l'arme équipée.
static func competences_utiles(j) -> Array:
	var type_arme = j.get_type_arme()
	var noms: Array = COMPETENCES_PAR_ARME[3][1]
	for e in COMPETENCES_PAR_ARME:
		if e[0] == type_arme:
			noms = e[1]
	var resultat := []
	for c in j.competence_de_base.values():
		if c.nom in noms:
			resultat.append(c)
	return resultat


static func resume(comp) -> String:
	var types := []
	for t in U.ga(comp, "type_degats", null) if U.ga(comp, "type_degats", null) != null else []:
		if U.vrai(t):
			types.append(t)
	var morceaux := ["Niv. %s" % str(comp.niveau), ("%s mana" % str(comp.cout_mana)) if U.vrai(comp.cout_mana) else "",
		"%s PA" % str(comp.cout_action), ", ".join(types)]
	return " · ".join(morceaux.filter(func(m): return m != ""))


## Magies disponibles par élément (titres compris) : [genre, objet, y].
static func disposer_disponibles(j, seulement := false, element = null) -> Array:
	var groupes := {}
	for magie in j.magies_disponibles:
		if seulement and not Sorts.peut_apprendre(j, magie):
			continue
		if element != null and Sorts.element_de(magie) != element:
			continue
		var e = Sorts.element_de(magie)
		if not groupes.has(e):
			groupes[e] = []
		groupes[e].append(magie)
	var ordre: Array = Sorts.ORDRE_ELEMENTS.duplicate()
	for e in groupes:
		if not e in ordre:
			ordre.append(e)
	var lignes := []
	var y := 0
	for e in ordre:
		if not groupes.has(e):
			continue
		lignes.append(["titre", e, y])
		y += HAUTEUR_TITRE
		for magie in U.trie_par(groupes[e], func(m): return U.ga(m, "PALIER", 0)):
			lignes.append(["magie", magie, y])
			y += HAUTEUR_LIGNE
	return lignes


static func resume_prerequis(j, magie) -> Array:
	var manquants := []
	for p in Sorts.etat_prerequis(j, magie):
		if not p[1]:
			manquants.append(p[0])
	if not manquants.is_empty():
		return ["Requiert : " + ", ".join(manquants), Ui.ROUGE]
	var palier := ("Palier %s · " % str(magie.PALIER)) if U.vrai(U.ga(magie, "PALIER", null)) else ""
	return [palier + resume(magie), Ui.VERT]


static func ligne(ci: CanvasItem, r: Rect2, comp, survol: bool, selection := false, grise := false, detail = null) -> void:
	Ui.rect(ci, r, Ui.LIGNE_SURVOL if survol else Ui.LIGNE, 0, 5)
	Ui.rect(ci, Rect2(r.position, Vector2(5, r.size.y)), DescriptionObjet.couleur_competence(comp), 0, 2)
	if selection:
		Ui.rect(ci, r, Ui.OR, 2, 5)
	Ui.texte(ci, comp.nom, r.position + Vector2(14, 4), Ui.GRISE if grise else Ui.BLANC, 16, true, r.size.x - 60)
	var d: Array = detail if detail != null else [resume(comp), Ui.DETAIL]
	Ui.texte(ci, d[0], r.position + Vector2(14, 24), d[1], 13, false, r.size.x - 24)
	if U.ga(comp, "points_amélioration", 0) > 0:
		ci.draw_texture_rect(Ui.texture("triangle_rouge.png"), Rect2(r.end.x - 32, r.get_center().y - 11, 22, 22), false)


func _mise_a_jour(_delta: float) -> void:
	elements = []
	titres = []
	contenus = {"connue": 0.0, "disponible": 0.0}
	if onglet == "Magies":
		var zone: Rect2 = zones_listes["connue"]
		var rang := 0
		for i in joueur.magies_apprises.size():
			var magie = joueur.magies_apprises[i]
			if filtre_element != null and Sorts.element_de(magie) != filtre_element:
				continue
			elements.append([["connue", i], Rect2(zone.position.x, zone.position.y + rang * HAUTEUR_LIGNE - defilement["connue"], zone.size.x - 8, 46), magie, "ameliorer"])
			rang += 1
		contenus["connue"] = rang * HAUTEUR_LIGNE
		zone = zones_listes["disponible"]
		for l in disposer_disponibles(joueur, seulement_apprenables, filtre_element):
			var y: float = zone.position.y + l[2] - defilement["disponible"]
			if l[0] == "titre":
				titres.append([l[1], Rect2(zone.position.x, y, zone.size.x - 8, HAUTEUR_TITRE)])
			else:
				elements.append([["disponible", l[1].nom_classe], Rect2(zone.position.x, y, zone.size.x - 8, 46), l[1], "apprendre"])
			contenus["disponible"] = l[2] + (HAUTEUR_TITRE if l[0] == "titre" else HAUTEUR_LIGNE)
		for liste in zones_listes:
			var maximum := maxf(0, contenus[liste] - zones_listes[liste].size.y)
			defilement[liste] = clampf(defilement[liste], 0, maximum)
		# La liste défile pour garder la sélection de la manette visible
		var selection = Manette.cle_selectionnee(self)
		for e in elements:
			if e[0] == selection and zones_listes.has(e[0][0]):
				var z: Rect2 = zones_listes[e[0][0]]
				if e[1].end.y > z.end.y:
					defilement[e[0][0]] += e[1].end.y - z.end.y
				elif e[1].position.y < z.position.y:
					defilement[e[0][0]] -= z.position.y - e[1].position.y
				break
	elif onglet == "Compétences":
		var utiles := competences_utiles(joueur)
		for i in utiles.size():
			elements.append([["competence", utiles[i].nom], Rect2(PANNEAU_GAUCHE.position.x + 10, PANNEAU_GAUCHE.position.y + 44 + i * 52, PANNEAU_GAUCHE.size.x - 20, 46), utiles[i], "ameliorer"])
		var y := PANNEAU_DROIT.position.y + 44
		for e in COMPETENCES_PAR_ARME:
			y += 18
			for nom in e[1]:
				for c in joueur.competence_de_base.values():
					if c.nom == nom:
						elements.append([["base", c.nom], Rect2(PANNEAU_DROIT.position.x + 10, y, PANNEAU_DROIT.size.x - 20, 30), c, null])
						y += 32
						break
			y += 2
	else:
		index.mettre_a_jour(Manette.cle_selectionnee(self))


func _dessiner_liste(ci: Control, liste: String) -> void:
	if onglet != "Magies":
		return
	var s := souris()
	var zone: Rect2 = zones_listes[liste]
	if liste == "disponible":
		for t in titres:
			var couleur: Color = DescriptionObjet.COULEURS_ELEMENTS.get(t[0], Ui.DETAIL)
			Ui.texte(ci, Sorts.NOMS_ELEMENTS.get(t[0], str(t[0])), Vector2(t[1].position.x + 4, t[1].get_center().y), couleur, 14, true, null, "midleft")
			Ui.ligne(ci, Vector2(t[1].position.x + 110, t[1].get_center().y), Vector2(t[1].end.x - 4, t[1].get_center().y), couleur, 1)
	for e in elements:
		if e[0][0] != liste or not e[1].intersects(zone):
			continue
		var survol: bool = e[1].has_point(s) and zone.has_point(s)
		if e[3] == "apprendre":
			ligne(ci, e[1], e[2], survol, e[2] == derniere_magie_cliquee, not Sorts.peut_apprendre(joueur, e[2]), resume_prerequis(joueur, e[2]))
		else:
			ligne(ci, e[1], e[2], survol, e[2] == derniere_magie_cliquee)


func _dessiner(ci: Control) -> void:
	var s := souris()
	for nom in ONGLETS:
		Ui.onglet(ci, ONGLETS[nom], nom, nom == onglet, ONGLETS[nom].has_point(s))
	var zones_index := []
	if onglet == "Altérations":
		zones_index = index.dessiner(ci, s)
	elif onglet == "Magies":
		Ui.panneau(ci, MAGIE_GAUCHE)
		Ui.panneau(ci, MAGIE_DROIT)
	else:
		Ui.panneau(ci, PANNEAU_GAUCHE)
		Ui.panneau(ci, PANNEAU_DROIT)
	if onglet == "Magies":
		for be in boutons_elements:
			var r: Rect2 = be[1]
			Ui.onglet(ci, r, "Tous" if be[0] == null else Sorts.NOMS_ELEMENTS[be[0]], be[0] == filtre_element, r.has_point(s), 12)
			if be[0] != null:
				Ui.rect(ci, Rect2(r.position.x + 6, r.end.y - 4, r.size.x - 12, 2), DescriptionObjet.COULEURS_ELEMENTS.get(be[0], Ui.DETAIL))
		var points = U.ga(joueur, "nouvelle_magie_a_apprendre", 0)
		Ui.texte(ci, "Points de magie : %s" % str(points), Vector2(PANNEAU_DROIT.end.x, 37), Ui.OR if U.vrai(points) else Ui.DETAIL, 17, true, null, "midright")
		Ui.texte(ci, "Magies connues", MAGIE_GAUCHE.position + Vector2(14, 12), Ui.OR, 18, true)
		Ui.texte(ci, "Clic : améliorer", Vector2(MAGIE_GAUCHE.end.x - 14, MAGIE_GAUCHE.position.y + 15), Ui.DETAIL, 13, false, null, "topright")
		Ui.texte(ci, "Magies disponibles", MAGIE_DROIT.position + Vector2(14, 12), Ui.OR, 18, true)
		Ui.onglet(ci, bouton_filtre, "Apprenables", seulement_apprenables, bouton_filtre.has_point(s), 13)
		var a_connue := false
		var a_disponible := false
		for e in elements:
			a_connue = a_connue or e[0][0] == "connue"
			a_disponible = a_disponible or e[0][0] == "disponible"
		if not a_connue:
			Ui.texte(ci, "Aucune magie apprise" + ("" if filtre_element == null else " de ce type") + " pour l'instant.",
				MAGIE_GAUCHE.position + Vector2(14, 50), Ui.DETAIL, 15)
		if joueur.magies_disponibles.is_empty():
			Ui.texte(ci, "Vous connaissez toutes les magies.", MAGIE_DROIT.position + Vector2(14, 50), Ui.DETAIL, 15)
		elif not a_disponible:
			Ui.texte(ci, "Aucune magie de ce type à apprendre." if not seulement_apprenables else "Aucune magie dont vous remplissez les prérequis.",
				MAGIE_DROIT.position + Vector2(14, 50), Ui.DETAIL, 15)
		for liste in zones_listes:
			var zone: Rect2 = zones_listes[liste]
			Ui.ascenseur(ci, zone, defilement[liste], maxf(0, contenus[liste] - zone.size.y), zone.end.x - 5)
	elif onglet == "Compétences":
		var type_arme = joueur.get_type_arme()
		Ui.texte(ci, "Compétences de votre arme : %s" % NOMS_ARMES.get(type_arme, "Mains nues" if type_arme == null else str(type_arme)),
			PANNEAU_GAUCHE.position + Vector2(14, 12), Ui.OR, 18, true, PANNEAU_GAUCHE.size.x - 28)
		Ui.texte(ci, "Clic : améliorer", PANNEAU_GAUCHE.position + Vector2(14, 44 + 2 * 52 + 6), Ui.DETAIL, 13)
		Ui.texte(ci, "Toutes les compétences de base", PANNEAU_DROIT.position + Vector2(14, 12), Ui.OR, 18, true)
		var y := PANNEAU_DROIT.position.y + 44
		for e in COMPETENCES_PAR_ARME:
			Ui.texte(ci, NOMS_ARMES.get(e[0], "Mains nues"), Vector2(PANNEAU_DROIT.position.x + 14, y + 1), Ui.DETAIL, 13, true)
			y += 18 + 32 * e[1].size() + 2
	_survole = null
	for e in elements:
		var zone = zones_listes.get(e[0][0]) if onglet == "Magies" else null
		if zone != null and not e[1].intersects(zone):
			continue
		var survol: bool = e[1].has_point(s) and (zone == null or zone.has_point(s))
		if onglet == "Compétences":
			if e[3] == null:
				Ui.rect(ci, e[1], Ui.LIGNE_SURVOL if survol else Ui.LIGNE, 0, 5)
				Ui.texte(ci, e[2].nom, Vector2(e[1].position.x + 14, e[1].get_center().y), Ui.BLANC, 15, true, null, "midleft")
				Ui.texte(ci, resume(e[2]), Vector2(e[1].end.x - 12, e[1].get_center().y), Ui.DETAIL, 13, false, null, "midright")
			else:
				ligne(ci, e[1], e[2], survol, e[2] == derniere_magie_cliquee)
		if survol:
			_survole = [e[2], e[1], e[3]]
	Ui.bouton(ci, BOUTON_QUITTER, "Quitter", Ui.BOUTON_ROUGE, BOUTON_QUITTER.has_point(s))
	var z := []
	for nom in ONGLETS:
		z.append([["onglet", nom], ONGLETS[nom]])
	if onglet == "Magies":
		for be in boutons_elements:
			z.append([["element", be[0]], be[1]])
		z.append([["filtre"], bouton_filtre])
	for e in elements:
		z.append([e[0], e[1]])
	z += zones_index
	z.append([["quitter"], BOUTON_QUITTER])
	definir_zones(z, elements[0][0] if not elements.is_empty() else ["onglet", onglet])


func _dessiner_dessus(ci: Control) -> void:
	if message != "" and Animations.temps() < message_fin:
		Ui.message(ci, message, Vector2(Ui.LARGEUR / 2, Ui.HAUTEUR - 32))
	if _survole == null:
		return
	var comp = _survole[0]
	var lignes: Array = DescriptionObjet.lignes_competence(comp, joueur)
	if _survole[2] == "apprendre":
		for p in Sorts.etat_prerequis(joueur, comp):
			lignes.append(["Prérequis : %s (%s)" % [p[0], "rempli" if p[1] else "manquant"], Ui.VERT if p[1] else Ui.ROUGE])
	if U.ga(comp, "points_amélioration", 0) > 0:
		lignes.append(["%s point(s) d'amélioration à dépenser" % str(comp.points_amélioration), Ui.ROUGE])
	var aide = {"ameliorer": "Clic : voir les améliorations", "apprendre": "Double-clic : apprendre"}.get(_survole[2])
	if aide != null:
		lignes.append([aide, Ui.OR])
	Ui.infobulle(ci, comp.nom, lignes, _survole[1], 300, DescriptionObjet.couleur_competence(comp))


func _evenement(ev: Dictionary) -> void:
	if onglet == "Altérations":
		index.evenement(ev)
	if ev["type"] == "touche" and ev["touche"] == KEY_ESCAPE:
		fermer()
		return
	if ev["type"] == "molette" and onglet == "Magies":
		for liste in zones_listes:
			if zones_listes[liste].has_point(souris()):
				defilement[liste] -= ev["sens"] * 40
		return
	if ev["type"] != "clic" or ev["bouton"] != 1:
		return
	var pos: Vector2 = ev["pos"]
	if BOUTON_QUITTER.has_point(pos):
		fermer()
		return
	if onglet == "Magies":
		for be in boutons_elements:
			if be[1].has_point(pos):
				filtre_element = be[0]
				defilement = {"connue": 0.0, "disponible": 0.0}
		if bouton_filtre.has_point(pos):
			seulement_apprenables = not seulement_apprenables
			defilement["disponible"] = 0.0
	for nom in ONGLETS:
		if ONGLETS[nom].has_point(pos):
			onglet = nom
	for e in elements:
		if not e[1].has_point(pos):
			continue
		if zones_listes.has(e[0][0]) and not zones_listes[e[0][0]].has_point(pos):
			continue
		var comp = e[2]
		if e[3] == "ameliorer":
			await Ecrans.menu_ameliorer_competence(joueur, comp)
		elif e[3] == "apprendre":
			var maintenant := Animations.temps()
			if derniere_magie_cliquee == comp and maintenant - dernier_temps_clic < DELAI_DOUBLE_CLIC:
				var manquants := []
				for p in Sorts.etat_prerequis(joueur, comp):
					if not p[1]:
						manquants.append(p[0])
				if not manquants.is_empty():
					message = "Prérequis manquants : " + ", ".join(manquants) + "."
				elif joueur.nouvelle_magie_a_apprendre > 0:
					joueur.apprendre_magie(comp)
					message = "Vous avez appris %s !" % comp.nom
				else:
					message = "Les nouveaux sorts s'apprennent dans les grimoires trouvés en explorant."
				message_fin = maintenant + 3
				derniere_magie_cliquee = null
			else:
				derniere_magie_cliquee = comp
				dernier_temps_clic = maintenant
		break
