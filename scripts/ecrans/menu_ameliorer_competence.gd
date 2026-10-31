extends Ecran
## Arbre d'amélioration d'une compétence : 10
## niveaux × 3 options (une par voie). Clic : +1 point ; clic droit (X) : remplir
## l'option. Un niveau s'ouvre à 10 points investis dans le précédent.

const COULEURS_VOIES := {"puissance": Color8(220, 90, 70), "technique": Color8(90, 150, 240), "affliction": Color8(170, 100, 230)}
const NOMS_VOIES := {"puissance": "Puissance", "technique": "Technique", "affliction": "Affliction"}
const NOMS_VOIES_SOUTIEN := {"puissance": "Puissance", "technique": "Technique", "affliction": "Soutien"}
const HAUTEUR_RANGEE := 118
const BOUTON_RETOUR := Rect2(Ui.LARGEUR - 150, Ui.HAUTEUR - 46, 130, 34)
const ENTETE := Rect2(20, 10, Ui.LARGEUR - 40, 62)
const ZONE := Rect2(20, 80, Ui.LARGEUR - 40, Ui.HAUTEUR - 136)

var joueur
var competence
var message := ""
var couleur_message := Ui.OR
var message_fin := 0.0
var noms_voies: Dictionary
var defilement := 0.0
var defilement_max := 0.0
var valeur = null
var gains := {}
var cartes := []
var amelioration_rects := []
var _survolee = null


func preparer(j, comp) -> Ecran:
	fond_ecran = "menu_améliorer_compétence.png"
	joueur = j
	competence = comp
	noms_voies = NOMS_VOIES_SOUTIEN if comp.type_competence != "offensif" else NOMS_VOIES
	defilement_max = maxf(0, comp.ameliorations_possibles.size() * HAUTEUR_RANGEE - ZONE.size.y + 6)
	defilement = clampf(comp.dernier_niveau_ouvert() * HAUTEUR_RANGEE - HAUTEUR_RANGEE / 2, 0, defilement_max)
	Ameliorations.recalibrer_niveau(comp, comp.dernier_niveau_ouvert())
	valeur = texte_valeur(comp)
	couche_decoupee(ZONE.grow(-1), _dessiner_cartes)
	return self


static func valeur_de(comp):
	return ValeurCompetences.points(comp)


static func texte_valeur(comp):
	var v = valeur_de(comp)
	return null if v == null else "Valeur : %s pts" % U.f(v)


## Points de valeur qu'une option ajouterait à la compétence telle qu'elle est.
static func gain_reel(comp, amel: Dictionary):
	var spec = amel.get("spec")
	if not spec is Dictionary or spec.is_empty():
		return amel.get("points")
	var copie = Equilibrage.copie_competence(comp)
	Ameliorations.appliquer_spec(copie, spec)
	return ValeurCompetences.points(copie) - ValeurCompetences.points(comp)


## Lignes « Actuel », « Suivant » et « Max » d'une option.
static func lignes_bonus(comp, amel: Dictionary) -> Array:
	var spec = amel.get("spec")
	if not spec is Dictionary or spec.is_empty():
		return [["Max", amel["description"]]]
	var soin := Ameliorations.profil(comp) == "soin"
	var n := Competence.POINTS_PAR_OPTION
	var investi := Competence.points_investis(amel)
	var actuel := Ameliorations.decrire_part(spec, float(investi) / n, soin) if investi else "—"
	var suivant := Ameliorations.decrire_part(spec, float(investi + 1) / n, soin) if investi < n else "—"
	return [["Actuel %d/%d" % [investi, n], actuel],
		[("Suivant %d/%d" % [investi + 1, n]) if investi < n else "Suivant", suivant],
		["Max %d/%d" % [n, n], Ameliorations.decrire_part(spec, 1.0, soin)]]


func _mise_a_jour(_delta: float) -> void:
	var ouvert: int = competence.dernier_niveau_ouvert()
	var largeur_carte := int((ZONE.size.x - 104 - 2 * 10) / 3)
	cartes = []
	amelioration_rects = []
	for i in competence.ameliorations_possibles.size():
		var options: Array = competence.ameliorations_possibles[i]
		for k in options.size():
			var r := Rect2(ZONE.position.x + 100 + k * (largeur_carte + 10), ZONE.position.y + 4 + i * HAUTEUR_RANGEE - defilement, largeur_carte, HAUTEUR_RANGEE - 10)
			var etat := "verrouillée"
			if options[k].get("debloquee", false):
				etat = "choisie"
			elif i <= ouvert:
				etat = "disponible"
			cartes.append([r, i, k, etat])
			if etat == "disponible":
				amelioration_rects.append([r, i, k])
	var cle = Manette.cle_selectionnee(self)
	for a in amelioration_rects:
		if cle == ["amelioration", a[1], a[2]]:
			if a[0].end.y > ZONE.end.y - 4:
				defilement = minf(defilement_max, defilement + a[0].end.y - ZONE.end.y + 4)
			elif a[0].position.y < ZONE.position.y + 4:
				defilement = maxf(0, defilement - (ZONE.position.y + 4 - a[0].position.y))
			break


func _dessiner(ci: Control) -> void:
	var s := souris()
	Ui.panneau(ci, ENTETE)
	Ui.texte(ci, "Améliorations — %s" % competence.nom, ENTETE.position + Vector2(16, 8), DescriptionObjet.couleur_competence(competence), 20, true)
	var seuil: int = 20 + 100 * competence.niveau
	Ameliorations.actualiser(competence)
	var facteur := Ameliorations.facteur_etage()
	var hausse: int = competence.hausse_cout_amelioration()
	var cout := ("coût %s mana (+%d par option remplie)" % [str(competence.cout_mana), hausse]) if hausse else "compétence gratuite"
	cout += "  ·  bonus plats ×%s à cet étage" % U.f(facteur, 1)
	Ui.texte(ci, "Niveau %s / %d  ·  EXP %s / %d  ·  %s" % [str(competence.niveau), Competence.NIVEAU_MAX_COMPETENCE,
		str(U.ga(competence, "experience", 0)), seuil, cout], ENTETE.position + Vector2(16, 36), Ui.DETAIL, 14)
	if valeur != null:
		Ui.texte(ci, valeur, Vector2(ENTETE.end.x - 150, ENTETE.position.y + 10), Ui.OR, 15, true, null, "topright")
	var points = competence.points_amélioration
	Ui.texte(ci, "Points : %s" % str(points), Vector2(ENTETE.end.x - 16, ENTETE.get_center().y), Ui.VERT if points > 0 else Ui.ROUGE, 18, true, null, "midright")
	Ui.panneau(ci, ZONE, 170)
	Ui.ascenseur(ci, ZONE.grow_individual(0, -4, 0, -4), defilement, defilement_max, ZONE.end.x - 8)
	Ui.texte(ci, "Molette : défiler · clic : +1 point · clic droit (X) : remplir l'option", Vector2(24, Ui.HAUTEUR - 40), Ui.DETAIL, 13)
	Ui.bouton(ci, BOUTON_RETOUR, "Retour", Ui.BOUTON_ROUGE, BOUTON_RETOUR.has_point(s))
	var z := []
	for a in amelioration_rects:
		z.append([["amelioration", a[1], a[2]], a[0]])
	z.append([["retour"], BOUTON_RETOUR])
	definir_zones(z, z[0][0])


func _dessiner_cartes(ci: Control) -> void:
	var s := souris()
	var ouvert: int = competence.dernier_niveau_ouvert()
	if not gains.has("valeur"):
		gains["valeur"] = valeur_de(competence)
	var valeur_actuelle = gains["valeur"]
	_survolee = null
	for c in cartes:
		var r: Rect2 = c[0]
		var i: int = c[1]
		var k: int = c[2]
		var etat: String = c[3]
		if r.end.y < ZONE.position.y or r.position.y > ZONE.end.y:
			continue
		var amel: Dictionary = competence.ameliorations_possibles[i][k]
		var voie: String = amel.get("voie", "puissance")
		if k == 0:
			var couleur_niveau := Ui.OR if i == ouvert else (Ui.VERT if i < ouvert else Ui.DETAIL)
			Ui.texte(ci, "Niveau %d" % (i + 1), Vector2(ZONE.position.x + 14, r.get_center().y - 18), couleur_niveau, 16, true)
			if i <= ouvert:
				var investis: int = competence.points_niveau(i)
				Ui.texte(ci, "%d pts investis" % investis, Vector2(ZONE.position.x + 14, r.get_center().y + 2),
					Ui.VERT if investis >= Competence.POINTS_DEBLOCAGE_NIVEAU else Ui.DETAIL, 11)
		var survol := r.has_point(s) and ZONE.has_point(s)
		var fond: Color = {"choisie": Color8(24, 60, 34), "disponible": Ui.LIGNE_SURVOL if survol else Ui.LIGNE}.get(etat, Color8(28, 26, 34))
		var bord: Color = {"choisie": Ui.VERT, "disponible": Ui.OR}.get(etat, Color8(70, 66, 78))
		Ui.rect(ci, r, Color(fond, 230 / 255.0), 0, 8)
		var couleur_voie: Color = COULEURS_VOIES.get(voie, Ui.BRONZE)
		var actif := etat in ["choisie", "disponible"]
		if not actif:
			couleur_voie = Color8(int(couleur_voie.r8 / 2), int(couleur_voie.g8 / 2), int(couleur_voie.b8 / 2))
		Ui.rect(ci, Rect2(r.position, Vector2(5, r.size.y)), couleur_voie, 0, 2)
		Ui.rect(ci, r, bord, 2 if actif else 1, 8)
		var encre := Ui.BLANC if actif else Ui.GRISE
		Ui.texte(ci, amel["nom"], r.position + Vector2(14, 7), encre, 15, true, r.size.x - 100)
		var investi := Competence.points_investis(amel)
		var libelle: String = {"choisie": "Complète", "disponible": "%d / %d" % [investi, Competence.POINTS_PAR_OPTION], "verrouillée": "Verrouillée"}[etat]
		Ui.texte(ci, libelle, Vector2(r.end.x - 10, r.position.y + 9), bord, 12, true, null, "topright")
		if etat == "disponible":
			var jauge := Rect2(r.position.x + 10, r.end.y - 6, r.size.x - 20, 3)
			Ui.rect(ci, jauge, Color8(60, 56, 66))
			Ui.rect(ci, Rect2(jauge.position, Vector2(int(jauge.size.x * investi / Competence.POINTS_PAR_OPTION), jauge.size.y)), Ui.OR)
		Ui.texte(ci, noms_voies.get(voie, ""), r.position + Vector2(14, 27), couleur_voie, 11, true)
		var points_option = amel.get("points")
		if etat == "disponible":
			if not gains.has([i, k]):
				gains[[i, k]] = gain_reel(competence, amel)
			points_option = gains[[i, k]]
		if U.vrai(points_option):
			var texte_points := "+%s points" % U.f(points_option)
			if etat == "disponible" and U.vrai(valeur_actuelle):
				texte_points += " (+%s %%)" % U.f(points_option / valeur_actuelle * 100)
			Ui.texte(ci, texte_points, Vector2(r.end.x - 10, r.position.y + 27), encre, 11, true, null, "topright")
		var cle_lignes := ["lignes", i, k, investi]
		if not gains.has(cle_lignes):
			gains[cle_lignes] = lignes_bonus(competence, amel)
		var lignes: Array = gains[cle_lignes]
		if survol:
			_survolee = [r, amel, lignes]
		for n in lignes.size():
			var y := r.position.y + 44 + n * 19
			var actif_ligne: bool = encre == Ui.BLANC and lignes[n][1] != "—"
			var rt := Ui.texte(ci, lignes[n][0] + " :", Vector2(r.position.x + 14, y), Ui.OR if actif_ligne and n < 2 else Ui.DETAIL, 12, true)
			Ui.texte(ci, lignes[n][1], Vector2(rt.end.x + 6, y), Ui.TEXTE if actif_ligne else Ui.GRISE, 12, false, r.end.x - 10 - rt.end.x - 6)


func _dessiner_dessus(ci: Control) -> void:
	if _survolee != null:
		var l := []
		for n in _survolee[2].size():
			var ligne_bonus: Array = _survolee[2][n]
			l.append(["%s : %s" % ligne_bonus, Ui.OR if n < 2 and ligne_bonus[1] != "—" else Ui.TEXTE])
		Ui.infobulle(ci, _survolee[1]["nom"], l, _survolee[0], 320, COULEURS_VOIES.get(_survolee[1].get("voie"), Ui.OR))
	if message != "" and Animations.temps() < message_fin:
		Ui.message(ci, message, Vector2(Ui.LARGEUR / 2 - 60, Ui.HAUTEUR - 22), couleur_message)


func _evenement(ev: Dictionary) -> void:
	if ev["type"] == "touche" and ev["touche"] == KEY_ESCAPE:
		fermer()
	elif ev["type"] == "molette":
		defilement = clampf(defilement - ev["sens"] * 40, 0, defilement_max)
	elif ev["type"] == "clic" and ev["bouton"] in [1, 3]:
		var pos: Vector2 = ev["pos"]
		if ev["bouton"] == 1 and BOUTON_RETOUR.has_point(pos):
			fermer()
		elif ZONE.has_point(pos):
			for a in amelioration_rects:
				if not a[0].has_point(pos):
					continue
				var niveau: int = a[1]
				var choix: int = a[2]
				var nom: String = competence.ameliorations_possibles[niveau][choix]["nom"]
				if competence.points_amélioration <= 0:
					message = "Aucun point d'amélioration : la compétence doit gagner un niveau."
					couleur_message = Ui.ROUGE
				else:
					var cout_avant = competence.cout_mana
					var a_investir := 1 if ev["bouton"] == 1 else Competence.POINTS_PAR_OPTION
					if competence.améliorer_compétence(choix, niveau, a_investir):
						Ameliorations.recalibrer_niveau(competence, competence.dernier_niveau_ouvert())
						valeur = texte_valeur(competence)
						gains = {}
						var amel: Dictionary = competence.ameliorations_possibles[niveau][choix]
						var investi := Competence.points_investis(amel)
						var hausse = competence.cout_mana - cout_avant
						message = "%s : %d / %d (%d %% du bonus)" % [nom, investi, Competence.POINTS_PAR_OPTION, investi * 100 / Competence.POINTS_PAR_OPTION]
						if U.vrai(hausse):
							message += ", coût +%s mana" % str(hausse)
						couleur_message = Ui.VERT if amel.get("debloquee", false) else Ui.OR
				message_fin = Animations.temps() + 3
