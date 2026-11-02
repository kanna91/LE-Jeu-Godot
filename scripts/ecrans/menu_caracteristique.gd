extends Ecran
## Fiche de caractéristiques, refaite le 2026-10-29 avec les nouvelles règles (Caracteristiques) : en-tête (PV, mana,
## régénérations par minute, PA) et trois onglets — « Général » (les six caractéristiques et ce qu'elles donnent :
## ressources, précision, critiques), « Dégâts » (tous les types : dés, caractéristique, bonus, critique) et
## « Défense ». Les triangles rouges n'apparaissent que s'il reste des points à répartir : depuis le 2026-10-31,
## ils viennent des âmes siphonnées sur les corps des ennemis (3 âmes = 1 point, Personnage.gagner_ames).

## [touche de Personnage.distribuer_points, clé]
const CARACTERISTIQUES := [["1", "endurance"], ["2", "force"], ["3", "dextérité"], ["4", "intelligence"],
	["5", "sagesse"], ["6", Caracteristiques.MANA]]
## Types de dégâts de l'onglet « Dégâts », dans l'ordre : [type, libellé, caractéristique].
const TYPES := [
	["tranchant", "Tranchant", "Force"], ["perforant", "Perforant", "Force"], ["contondant", "Contondant", "Force"],
	["feu", "Feu", "Sagesse"], ["froid", "Froid", "Sagesse"], ["foudre", "Foudre", "Sagesse"],
	["arcane", "Arcane", "Intelligence"], ["ombre", "Ombre", "Intelligence"], ["chaos", "Chaos", "Intelligence"],
	["lumière", "Lumière (soins)", "Int. ou Sag."], ["poison", "Poison", "aucune"],
]
## Colonnes de l'onglet « Dégâts » : [titre, x relatif au panneau, ancre].
const COLONNES := [["Type", 14, "topleft"], ["Caractéristique", 150, "topleft"], ["Dés", 340, "topright"],
	["+ carac.", 430, "topright"], ["+ objets", 520, "topright"], ["× %", 610, "topright"],
	["Moyenne", 710, "topright"], ["Critique", 900, "topright"]]
const ONGLETS := ["Général", "Dégâts", "Défense"]
const ENTETE := Rect2(20, 14, Ui.LARGEUR - 40, 70)
const PANNEAU_GAUCHE := Rect2(20, 132, 450, 352)
const PANNEAU_DROIT := Rect2(490, 132, 450, 352)
const PANNEAU_LARGE := Rect2(20, 132, 920, 352)
const BOUTON_FERMER := Rect2(Ui.LARGEUR - 140, Ui.HAUTEUR - 46, 120, 34)

var joueur
var onglet := "Général"
var onglet_rects := {}
var fleches := []
var message := ""
var message_fin := 0.0


func preparer(j) -> Ecran:
	fond_ecran = "menu_caractéristique.png"
	joueur = j
	for i in ONGLETS.size():
		onglet_rects[ONGLETS[i]] = Rect2(20 + i * 128, 92, 120, 32)
	return self


static func pourcent(valeur: float) -> String:
	return "%s %%" % U.f(valeur * 100)


static func plafonne(valeur: float, plafond: float) -> String:
	return pourcent(valeur) + ((" (max %s)" % pourcent(plafond)) if valeur > plafond else "")


## « 12 % ×1,65 » : chance (plafonnée) et multiplicateur d'un critique.
static func critique(s: Array) -> String:
	if float(s[0]) <= 0 and float(s[1]) <= 1:
		return "jamais"
	return "%s ×%s" % [plafonne(s[0], Formules.PLAFOND_CRITIQUE), U.f(s[1], 2)]


## Ce que donnent les caractéristiques (panneau droit de « Général ») : [[libellé, valeur ou null (titre)], ...].
static func lignes_effets(j) -> Array:
	return [["Ressources", null],
		["PV max", "%d  (endurance +%d)" % [int(j.points_de_vie_max), int(U.num(j, "endurance") * U.num(j, "bonus_pv_par_endurance")
			* U.num(j, "multiplicateur_pv_max"))]],
		["PV régénérés par minute", "+%s" % U.f(U.num(j, "regen_de_points_de_vie"))],
		["Mana max", "%d  (mana +%d)" % [int(j.mana_max), int(U.num(j, Caracteristiques.MANA) * Caracteristiques.MANA_PAR_POINT)]],
		["Mana régénéré par minute", "+%s" % U.f(U.num(j, "regen_de_mana"))],
		["Précision", null],
		["Chance de toucher", pourcent(j.chance_de_toucher)],
		["Esquive", plafonne(j.chance_esquive, Formules.PLAFOND_ESQUIVE)],
		["Parade", plafonne(j.chance_de_parer, Formules.PLAFOND_PARADE)],
		["Critiques", null],
		["Physique (dextérité)", critique(Formules.stats_critique(j, "tranchant"))],
		["Magique : arcane, ombre, chaos", critique(Formules.stats_critique(j, "arcane"))],
		["Élémentaire : feu, froid, foudre", critique(Formules.stats_critique(j, "feu"))],
		["Lumière (la plus forte des deux)", critique(Formules.stats_critique(j, "lumière"))],
		["Poison", "jamais"]]


## Une ligne de l'onglet « Dégâts » pour le type ``t`` : textes des colonnes (sans le type ni la caractéristique).
static func ligne_degats(j, t: String) -> Array:
	var des := Formules.des_type(j, t)
	var plats := Formules.degats_plats(j, t)
	var carac := Formules.des_caracteristique(j, t)
	var moyenne := Formules.base_degats(j, t, Formules.moyenne(des + carac))
	return [Formules.texte(des), ("+" + Formules.texte(carac)) if not carac.is_empty() else "+0", "+" + U.g(plats),
		pourcent(Formules.pourcentage(j, t)), U.f(moyenne, 1), critique(Formules.stats_critique(j, t))]


## Onglet « Défense » (2026-10-30) : à gauche les défenses en points (2 points = 1 dégât bloqué) et l'évitement ;
## à droite, pour chacun des 9 types, les dégâts bloqués par coup (la meilleure entre la défense du groupe et la
## résistance spécifique, qui ne se cumulent pas) et le pourcentage des vulnérabilités et résistances en %.
static func lignes_defense(j) -> Array:
	var gauche := [["Défenses (2 points = 1 dégât)", null]]
	for g in ["physique", "magique", "elementaire"]:
		var attribut: String = Degats.DEFENSES[g]
		var nom: String = {"armure": "Armure", "resistance_magique": "Résistance magique",
			"resistance_elementaire": "Résistance élémentaire"}[attribut]
		gauche.append([nom, "%s (−%d / coup)" % [U.g(U.num(j, attribut)), floori(U.num(j, attribut) / Degats.POINTS_PAR_DEGAT)]])
	gauche += [["Évitement", null],
		["Esquive", plafonne(j.chance_esquive, Formules.PLAFOND_ESQUIVE)],
		["Parade", plafonne(j.chance_de_parer, Formules.PLAFOND_PARADE)],
		["Non réduits", null], ["Poison, saignement, brut", "jamais"]]
	var droite := [["Dégâts reçus par type", null]]
	for t in Degats.TYPES:
		var texte := "−%d / coup" % Degats.reduction_fixe(j, t)
		var specifique := U.num(j, "resistance_" + t)
		if specifique > 0:
			texte += " (rés. %s)" % U.g(specifique)
		var m := Degats.multiplicateur(j, t)
		if absf(m - 1.0) > 0.001:
			texte += " · %s%s %%" % ["+" if m > 1 else "−", U.f(absf(m - 1.0) * 100)]
		droite.append([t.capitalize(), texte])
	return [gauche, droite]


static func colonne(ci: Control, r: Rect2, lignes: Array) -> void:
	var y := r.position.y
	for l in lignes:
		if l[1] == null:
			y += 4 if y > r.position.y else 0
			Ui.texte(ci, l[0], Vector2(r.position.x, y), Ui.OR, 15, true)
			y += 21
		else:
			Ui.texte(ci, l[0], Vector2(r.position.x + 8, y), Ui.DETAIL, 14)
			Ui.texte(ci, l[1], Vector2(r.end.x, y), Ui.BLANC, 14, true, r.size.x - 200, "topright")
			y += 19


func _dessiner(ci: Control) -> void:
	var s := souris()
	Ui.panneau(ci, ENTETE)
	Ui.texte(ci, String(joueur.nom), ENTETE.position + Vector2(16, 10), Ui.OR, 20, true)
	Ui.texte(ci, "Régénération (exploration seulement) : +%s PV et +%s mana par minute" % [
		U.f(U.num(joueur, "regen_de_points_de_vie")), U.f(U.num(joueur, "regen_de_mana"))],
		ENTETE.position + Vector2(16, 42), Ui.DETAIL, 13)
	Ui.texte(ci, "PV %d / %d   ·   Mana %d / %d   ·   PA %s" % [int(joueur.points_de_vie), int(joueur.points_de_vie_max),
		int(joueur.mana), int(joueur.mana_max), str(joueur.points_d_action_max)],
		Vector2(ENTETE.end.x - 16, ENTETE.position.y + 12), Ui.TEXTE, 15, false, null, "topright")
	var points := int(U.num(joueur, "points_a_distribuer"))
	var ames := "Âmes %d / %d  ·  %s" % [int(U.num(joueur, "ames")), Personnage.AMES_PAR_POINT, Karma.texte(joueur)]
	Ui.texte(ci, ("Points de caractéristique : %d  ·  " % points if points > 0 else "") + ames,
		Vector2(ENTETE.end.x - 16, ENTETE.position.y + 42), Ui.VERT if points > 0 else Ui.DETAIL, 14, points > 0, null, "topright")
	for nom in ONGLETS:
		Ui.onglet(ci, onglet_rects[nom], nom, nom == onglet, onglet_rects[nom].has_point(s))
	fleches.clear()
	var aide := ""
	if onglet == "Général":
		_dessiner_general(ci, s, points)
		if points:
			aide = "Cliquez sur un triangle rouge pour dépenser un point."
	elif onglet == "Dégâts":
		_dessiner_degats(ci)
		aide = "Moyenne d'un coup : (dés + caractéristique + objets) × pourcentages, avant la défense de la cible."
	else:
		Ui.panneau(ci, PANNEAU_GAUCHE)
		Ui.panneau(ci, PANNEAU_DROIT)
		var colonnes := lignes_defense(joueur)
		colonne(ci, PANNEAU_GAUCHE.grow_individual(-18, -14, -18, -14), colonnes[0])
		colonne(ci, PANNEAU_DROIT.grow_individual(-18, -14, -18, -14), colonnes[1])
		aide = "2 points de défense = −1 dégât par coup (défense générale ou résistance spécifique, la meilleure). Pourcentages appliqués avant."
	Ui.texte(ci, aide, Vector2(24, Ui.HAUTEUR - 36), Ui.DETAIL, 13)
	Ui.bouton(ci, BOUTON_FERMER, "Fermer", Ui.BOUTON_ROUGE, BOUTON_FERMER.has_point(s))
	if message != "" and Animations.temps() < message_fin:
		Ui.message(ci, message, Vector2(680, 108), Ui.VERT)
	var z := []
	for nom in ONGLETS:
		z.append([["onglet", nom], onglet_rects[nom]])
	for f in fleches:
		z.append([["fleche", f[0]], f[1]])
	z.append([["fermer"], BOUTON_FERMER])
	definir_zones(z, z[ONGLETS.size()][0] if not fleches.is_empty() else ["onglet", onglet])


func _dessiner_general(ci: Control, s: Vector2, points: int) -> void:
	Ui.panneau(ci, PANNEAU_GAUCHE)
	Ui.panneau(ci, PANNEAU_DROIT)
	Ui.texte(ci, "Caractéristiques", PANNEAU_GAUCHE.position + Vector2(14, 8), Ui.OR, 17, true)
	var triangle := Ui.texture("triangle_rouge.png")
	for i in CARACTERISTIQUES.size():
		var cle: String = CARACTERISTIQUES[i][1]
		var l := Rect2(PANNEAU_GAUCHE.position.x + 10, PANNEAU_GAUCHE.position.y + 36 + i * 52, PANNEAU_GAUCHE.size.x - 20, 48)
		Ui.rect(ci, l, Ui.LIGNE_SURVOL if l.has_point(s) else Ui.LIGNE, 0, 5)
		Ui.texte(ci, Caracteristiques.NOMS[cle], l.position + Vector2(40, 5), Ui.BLANC, 16, true)
		Ui.texte(ci, U.g(U.ga(joueur, cle, 0)), Vector2(l.end.x - 12, l.position.y + 5), Ui.OR, 18, true, null, "topright")
		Ui.texte(ci, "Par point : " + Caracteristiques.TEXTES[cle], l.position + Vector2(40, 28), Ui.DETAIL, 12, false, l.size.x - 52)
		if points > 0:
			var f := Rect2(l.position.x + 10, l.get_center().y - 11, 22, 22)
			ci.draw_texture_rect(triangle, f, false)
			fleches.append([CARACTERISTIQUES[i][0], f])
	colonne(ci, PANNEAU_DROIT.grow_individual(-18, -12, -18, -12), lignes_effets(joueur))


func _dessiner_degats(ci: Control) -> void:
	var r := PANNEAU_LARGE
	Ui.panneau(ci, r)
	var y := r.position.y + 12
	for c in COLONNES:
		Ui.texte(ci, c[0], Vector2(r.position.x + c[1], y), Ui.OR, 14, true, null, c[2])
	y += 24
	for i in TYPES.size():
		var t: Array = TYPES[i]
		if i in [3, 6, 9]:
			Ui.rect(ci, Rect2(r.position.x + 12, y - 3, r.size.x - 24, 1), Ui.BRONZE)
		var valeurs := ligne_degats(joueur, t[0])
		Ui.texte(ci, t[1], Vector2(r.position.x + COLONNES[0][1], y), Ui.BLANC, 14, true)
		Ui.texte(ci, t[2], Vector2(r.position.x + COLONNES[1][1], y), Ui.DETAIL, 14)
		for k in valeurs.size():
			var c: Array = COLONNES[k + 2]
			Ui.texte(ci, valeurs[k], Vector2(r.position.x + c[1], y), Ui.BLANC if k == 4 else Ui.TEXTE, 14, k == 4, null, c[2])
		y += 22
	y += 8
	var arme = U.ga(joueur, "arme_equipee", null)
	Ui.texte(ci, "Arme : %s   ·   Pénétration d'armure %s   ·   Pénétration de résistance %s" % [
		DescriptionObjet.ligne_des(arme).trim_prefix("Dégâts ") if arme != null else "aucune",
		U.g(U.num(joueur, "penetration_armure")), U.g(U.num(joueur, "penetration_resistance"))],
		Vector2(r.position.x + 14, y), Ui.DETAIL, 13, false, r.size.x - 28)
	Ui.texte(ci, "Coups multiples : 1d6 − 2 par coup au lieu des dés du type. Le dé bonus d'une arme ne sert qu'à ses attaques.",
		Vector2(r.position.x + 14, y + 20), Ui.DETAIL, 13, false, r.size.x - 28)


func _evenement(ev: Dictionary) -> void:
	if ev["type"] == "touche" and ev["touche"] == KEY_ESCAPE:
		fermer()
	elif ev["type"] == "clic":
		var pos: Vector2 = ev["pos"]
		if BOUTON_FERMER.has_point(pos):
			fermer()
			return
		for nom in ONGLETS:
			if onglet_rects[nom].has_point(pos):
				onglet = nom
		for f in fleches:
			if f[1].has_point(pos) and int(U.num(joueur, "points_a_distribuer")) > 0:
				joueur.distribuer_points(f[0])
				for c in CARACTERISTIQUES:
					if c[0] == f[0]:
						message = "+1 " + Caracteristiques.NOMS[c[1]]
				message_fin = Animations.temps() + 2
				break
