class_name FicheEnnemi
extends RefCounted
## Contenu de la fiche détaillée d'un ennemi et de son info-bulle en combat.

const TYPES_PHYSIQUES := ["tranchant", "perforant", "contondant"]
const TYPES_MAGIQUES := ["feu", "froid", "foudre", "arcane", "chaos", "ombre", "lumière"]
const TOUS_LES_TYPES := ["tranchant", "perforant", "contondant", "feu", "froid", "foudre", "arcane", "chaos", "ombre", "lumière", "poison", "spirituel"]
const CIBLAGES_OFFENSIFS := {"choix": "vous", "aléatoire": "vous", "toute": "vous", "all": "vous et ses alliés",
	"self": "lui-même", "personnage": "vous"}
const COULEURS := {
	"titre": Color8(255, 215, 0), "section": Color8(255, 170, 60), "normal": Color8(235, 235, 235),
	"detail": Color8(175, 175, 190), "valeur": Color8(140, 220, 255), "danger": Color8(255, 110, 90), "soin": Color8(120, 230, 140),
}


static func _pourcent(valeur) -> String:
	return "%s %%" % U.f(valeur * 100)


static func chance_de_toucher(ennemi, joueur, competence = null) -> float:
	return Formules.chance_toucher(ennemi, competence, joueur)


static func estimer_degats(ennemi, competence, joueur) -> Array:
	return Formules.estimer_degats(ennemi, competence, joueur)


static func _decrire_competence(ennemi, competence, joueur) -> Array:
	var lignes := [["• %s — niveau %d" % [competence.nom, competence.niveau], "section"]]
	if U.vrai(competence.description):
		lignes.append([competence.description, "detail"])
	var choisies := Ameliorations.ameliorations_choisies(competence)
	if not choisies.is_empty():
		var morceaux := []
		for c in choisies:
			var opt: Dictionary = c[1]
			morceaux.append("%s %d/%d (%s)" % [opt["nom"], Competence.points_investis(opt), Competence.POINTS_PAR_OPTION, opt["description"]])
		lignes.append(["Améliorations : " + ", ".join(morceaux), "valeur"])
	var bonus := []
	if U.ga(competence, "multiplicateur_degats", 1) != 1:
		bonus.append("dégâts ×%s" % U.f(competence.multiplicateur_degats, 2))
	if U.num(competence, "bonus_toucher"):
		bonus.append("toucher +%s %%" % U.f(competence.bonus_toucher * 100))
	if U.num(competence, "bonus_critique"):
		bonus.append("critique +%s %%" % U.f(competence.bonus_critique * 100))
	if U.num(competence, "vol_de_vie"):
		bonus.append("vol de vie %s %%" % U.f(competence.vol_de_vie * 100))
	if not bonus.is_empty():
		lignes.append(["Bonus de la compétence : " + ", ".join(bonus), "normal"])
	var type_comp = competence.type_competence
	var nature = {"offensif": "Attaque", "heal": "Soin", "renforcement defensif": "Renfort défensif (alliés)",
		"renforcement offensif physique": "Renfort offensif physique (alliés)",
		"renforcement offensif magique": "Renfort offensif magique (alliés)"}.get(type_comp, type_comp)
	lignes.append(["Nature : %s %s — coût : %s mana, %s PA" % [nature, competence.type_attaque, str(competence.cout_mana), str(competence.cout_action)], "normal"])
	var cibles: String
	if type_comp == "offensif":
		cibles = CIBLAGES_OFFENSIFS.get(competence.type_ciblage, competence.type_ciblage)
	elif type_comp == "heal":
		cibles = "l'allié le plus blessé" if competence.type_ciblage == "choix" else "un allié (ou lui-même)"
	else:
		cibles = "un allié (ou lui-même)"
	var coups: int = competence.nombre_attaque
	lignes.append(["Cible : %s — %d coup%s par utilisation" % [cibles, coups, "s" if coups > 1 else ""], "normal"])
	var types := []
	for t in U.ga(competence, "type_degats", null) if U.ga(competence, "type_degats", null) != null else []:
		if U.vrai(t):
			types.append(t)
	if not types.is_empty():
		var valeurs := []
		for t in types:
			valeurs.append("%s %s" % [t, U.g(U.ga(competence, "degats_" + t, 0))])
		lignes.append(["Types de dégâts : %s (bonus propres à la compétence : %s)" % [", ".join(types), ", ".join(valeurs)], "normal"])
	if U.vrai(competence.penetration_armure) or U.vrai(competence.penetration_resistance):
		lignes.append(["Pénétration : armure %s, résistance %s" % [U.g(competence.penetration_armure), U.g(competence.penetration_resistance)], "normal"])
	for nom in competence.type_alteration:
		var chance = competence.type_alteration[nom]
		if not U.vrai(chance):
			continue
		var effet := Alterations.description(nom, competence.puissance_alterations.get(nom))
		var duree = Alterations.definition(Alterations.nom_canonique(nom)).get("duree", 0) + competence.duree_bonus
		lignes.append(["%s %s — %s %% de chance, %d tour(s) : %s" % ["Accorde" if Alterations.est_bonus(nom) else "Inflige",
			Alterations.libelle(nom), U.g(chance), duree, effet], "soin" if Alterations.est_bonus(nom) else "danger"])
	var al = U.ga(competence, "alterations_lanceur", {})
	for nom in al:
		lignes.append(["Se donne %s (%s %% de chance) : %s" % [Alterations.libelle(nom), U.g(al[nom]), Alterations.description(nom)], "soin"])
	if type_comp == "offensif":
		var blessures := []
		for e in estimer_degats(ennemi, competence, joueur):
			if e[2] >= 0:
				blessures.append(e)
		if not blessures.is_empty():
			var detail := []
			var total := 0
			for e in blessures:
				detail.append("%d %s" % [e[2], e[0]])
				total += int(e[2])
			total *= coups
			var touche := chance_de_toucher(ennemi, joueur, competence)
			lignes.append(["Sur vous : ≈ %d dégâts par utilisation (%s%s), %s de chance de toucher" % [total, " + ".join(detail),
				(", × %d coups" % coups) if coups > 1 else "", _pourcent(touche)], "danger"])
		elif types.is_empty():
			lignes.append(["Aucun dégât direct.", "detail"])
	elif type_comp == "heal":
		for e in estimer_degats(ennemi, competence, joueur):
			if e[2] < 0:
				lignes.append(["Soigne sa cible d'environ %d PV (dégâts de %s qui soignent)." % [-e[2], e[0]], "soin"])
	lignes.append(["", "normal"])
	return lignes


## Tout le texte de la fiche : [[texte, style], ...].
static func contenu_fiche(ennemi, joueur) -> Array:
	var l := []
	var morceaux := []
	for x in [U.ga(ennemi, "classe", null), U.ga(ennemi, "sous_classe", null)]:
		if U.vrai(x):
			morceaux.append(x)
	var classe := " ".join(morceaux)
	l.append(["Classe : %s — type : %s — niveau %d" % [classe if classe != "" else "inconnue", ennemi.type_ennemi if U.vrai(ennemi.type_ennemi) else "inconnu", ennemi.niveau], "normal"])
	l.append(["Points de vie : %s / %s    Mana : %s / %s    PA : %s / %s" % [str(ennemi.points_de_vie), str(ennemi.points_de_vie_max),
		str(ennemi.mana), str(ennemi.mana_max), str(ennemi.points_d_action), str(ennemi.points_d_action_max)], "valeur"])
	if not U.ga(ennemi, "magie", true):
		l.append(["Réduit au silence : ne peut pas lancer de magie.", "danger"])
	l.append(["", "normal"])
	l.append(["CARACTÉRISTIQUES", "titre"])
	var carac := []
	for c in [["Force", "force"], ["Dextérité", "dextérité"], ["Endurance", "endurance"], ["Intelligence", "intelligence"],
			["Sagesse", "sagesse"], ["Puissance magique", "puissance_magique"]]:
		if U.ha(ennemi, c[1]):
			carac.append("%s %s" % [c[0], U.g(U.ga(ennemi, c[1], 0))])
	l.append(["    ".join(carac), "normal"])
	l.append(["", "normal"])
	l.append(["ATTAQUE", "titre"])
	l.append(["Dégâts de base %s (+ force × 0,5 = %s pour les coups physiques)    Dégâts physiques %s" % [U.g(ennemi.degats_base),
		U.g(ennemi.force * 0.5), U.g(ennemi.degats_physique)], "normal"])
	var plats := []
	for t in TOUS_LES_TYPES:
		if U.vrai(U.ga(ennemi, "degats_" + t, 0)):
			plats.append("%s %s" % [t, U.g(U.ga(ennemi, "degats_" + t, 0))])
	if not plats.is_empty():
		l.append(["Dégâts supplémentaires : " + ", ".join(plats), "normal"])
	var bonus := []
	for t in ["physique", "magique", "elementaire"] + TOUS_LES_TYPES:
		var v = U.ga(ennemi, "pourcentage_degats_" + t, 1)
		if v != 1:
			bonus.append("%s %s" % [t, _pourcent(v)])
	if not bonus.is_empty():
		l.append(["Multiplicateurs de dégâts : " + ", ".join(bonus), "normal"])
	l.append(["Chance de toucher %s (sur vous : %s)    Critique %s, dégâts × %s" % [_pourcent(ennemi.chance_de_toucher),
		_pourcent(chance_de_toucher(ennemi, joueur)), _pourcent(ennemi.chance_de_coup_critique), U.f(ennemi.degats_critique, 2)], "normal"])
	l.append(["Critique magique %s, dégâts × %s" % [_pourcent(U.ga(ennemi, "chance_de_coup_critique_magique", 0)),
		U.f(U.ga(ennemi, "degats_critique_magiques", 0), 2)], "normal"])
	if ennemi.chance_de_coup_critique > 0 and ennemi.degats_critique < 1:
		l.append(["Attention : son multiplicateur de coup critique est inférieur à 1 ; un coup critique de cet ennemi inflige donc MOINS de dégâts qu'un coup normal (anomalie connue du jeu).", "detail"])
	l.append(["Pénétration d'armure %s    Pénétration de résistance %s" % [U.g(ennemi.penetration_armure), U.g(ennemi.penetration_resistance)], "normal"])
	l.append(["", "normal"])
	l.append(["DÉFENSE", "titre"])
	l.append(["Armure %s    Résistance magique %s    Résistance élémentaire %s    Esquive %s    Parade %s" % [U.g(ennemi.armure),
		U.g(ennemi.resistance_magique), U.g(U.num(ennemi, "resistance_elementaire")), _pourcent(ennemi.chance_esquive),
		_pourcent(ennemi.chance_de_parer)], "normal"])
	var specifiques := []
	for t in Degats.TYPES:
		if U.num(ennemi, "resistance_" + t) != 0:
			specifiques.append("%s %s" % [t, U.g(U.num(ennemi, "resistance_" + t))])
	if not specifiques.is_empty():
		l.append(["Résistances spécifiques (points) : " + ", ".join(specifiques), "normal"])
	var p := Degats.pourcentages(ennemi)
	var faiblesses := []
	for t in p["vulnerabilites"]:
		faiblesses.append("%s +%s %%" % [t, U.f(p["vulnerabilites"][t] * 100)])
	var resistances := []
	for t in p["resistances"]:
		resistances.append("%s −%s %%" % [t, U.f(p["resistances"][t] * 100)])
	if not faiblesses.is_empty():
		l.append(["Vulnérabilités : " + ", ".join(faiblesses), "soin"])
	if not resistances.is_empty():
		l.append(["Résistances en pourcentage : " + ", ".join(resistances), "normal"])
	l.append(["Dégâts bloqués par coup : −%d physiques, −%d magiques (arcane, ombre, chaos), −%d élémentaires (feu, froid, foudre). 2 points de défense bloquent 1 dégât ; une résistance spécifique ne s'ajoute pas à la défense générale (la meilleure compte). Les pourcentages s'appliquent avant." % [
		Degats.reduction_fixe(ennemi, "tranchant"), Degats.reduction_fixe(ennemi, "arcane"), Degats.reduction_fixe(ennemi, "feu")], "detail"])
	l.append(["", "normal"])
	l.append(["ALTÉRATIONS EN COURS", "titre"])
	if U.vrai(ennemi.alteration):
		for nom in ennemi.alteration:
			var info = ennemi.alteration[nom]
			var duree = info.get("duree", "?") if info is Dictionary else "?"
			l.append(["%s — encore %s tour(s) : %s" % [Alterations.libelle(nom), str(duree), Alterations.description(nom, info.get("puissance") if info is Dictionary else null)],
				"soin" if Alterations.est_bonus(nom) else "danger"])
	else:
		l.append(["Aucune.", "detail"])
	l.append(["", "normal"])
	l.append(["COMPÉTENCES (%d)" % ennemi.competences.size(), "titre"])
	if ennemi.competences.is_empty():
		l.append(["Aucune compétence connue.", "detail"])
	for competence in ennemi.competences:
		l.append_array(_decrire_competence(ennemi, competence, joueur))
	return l


## [compétence, dégâts] : l'attaque de l'ennemi qui vous ferait le plus mal.
static func meilleure_attaque(ennemi, joueur) -> Array:
	var meilleure = null
	var maximum := 0
	for competence in ennemi.competences:
		if competence.type_competence != "offensif":
			continue
		var total := 0
		for e in estimer_degats(ennemi, competence, joueur):
			if e[2] >= 0:
				total += int(e[2])
		total *= competence.nombre_attaque
		if total > maximum:
			meilleure = competence
			maximum = total
	return [meilleure, maximum]


## Découpe un texte à une largeur (suite des lignes indentée).
static func decouper(texte: String, taille: int, gras: bool, largeur: float) -> Array:
	if texte == "":
		return [""]
	var lignes := []
	var courante := ""
	for mot in texte.split(" "):
		var essai := ("%s %s" % [courante, mot]).strip_edges()
		if Ui.taille_texte(essai, taille, gras).x <= largeur or courante == "":
			courante = essai
		else:
			lignes.append(courante)
			courante = "    " + mot
	lignes.append(courante)
	return lignes


## Carte résumé d'un ennemi survolé en combat, à côté de son image.
static func dessiner_infobulle(ci: CanvasItem, ennemi, joueur, rect_ennemi: Rect2) -> void:
	var largeur := 310
	var marge := 12
	var lignes := []
	var morceaux := []
	for x in [U.ga(ennemi, "classe", null), U.ga(ennemi, "sous_classe", null)]:
		if U.vrai(x):
			morceaux.append(x)
	var classe := " ".join(morceaux)
	lignes.append(["%s · niveau %d" % [U.majuscule(classe) if classe != "" else "Ennemi", ennemi.niveau], COULEURS["detail"], 13])
	lignes.append(null)
	var attaque := meilleure_attaque(ennemi, joueur)
	if attaque[0] != null:
		lignes.append(["Danger : %s ≈ %d dégâts" % [attaque[0].nom, attaque[1]], COULEURS["danger"], 14])
	var critique := (" · critique %s ×%s" % [_pourcent(ennemi.chance_de_coup_critique), U.f(ennemi.degats_critique, 1)]) if ennemi.chance_de_coup_critique > 0 else ""
	lignes.append(["Vous touche à %s%s" % [_pourcent(chance_de_toucher(ennemi, joueur)), critique], COULEURS["normal"], 14])
	lignes.append(["Armure %s · rés. magique %s · rés. élém. %s · esquive %s" % [U.g(ennemi.armure), U.g(ennemi.resistance_magique),
		U.g(U.num(ennemi, "resistance_elementaire")), _pourcent(ennemi.chance_esquive)], COULEURS["normal"], 14])
	var p := Degats.pourcentages(ennemi)
	var faiblesses := []
	var resistances := []
	for t in p["vulnerabilites"]:
		faiblesses.append("%s (+%s %%)" % [t, U.f(p["vulnerabilites"][t] * 100)])
	for t in p["resistances"]:
		resistances.append("%s (−%s %%)" % [t, U.f(p["resistances"][t] * 100)])
	for t in Degats.TYPES:
		if U.num(ennemi, "resistance_" + t) > 0:
			resistances.append("%s (%s pts)" % [t, U.g(U.num(ennemi, "resistance_" + t))])
	if not faiblesses.is_empty():
		lignes.append(["Faible contre : " + ", ".join(faiblesses), COULEURS["soin"], 14])
	if not resistances.is_empty():
		lignes.append(["Résiste à : " + ", ".join(resistances), COULEURS["valeur"], 14])
	if U.vrai(ennemi.alteration):
		var etats := []
		for n in ennemi.alteration:
			var i = ennemi.alteration[n]
			etats.append("%s (%s t.)" % [Alterations.libelle(n), str(i.get("duree", "?"))] if i is Dictionary else Alterations.libelle(n))
		lignes.append(["État : " + ", ".join(etats), COULEURS["danger"], 14])
	if not U.ga(ennemi, "magie", true):
		lignes.append(["Réduit au silence", COULEURS["danger"], 14])
	lignes.append(["Clic / A / Y : fiche détaillée", COULEURS["titre"], 13])
	var rendu := []
	for ligne in lignes:
		if ligne == null:
			rendu.append(null)
			continue
		for morceau in decouper(ligne[0], ligne[2], false, largeur - 2 * marge):
			rendu.append([morceau.strip_edges(), ligne[1], ligne[2]])
	var hauteur := marge + Ui.hauteur_ligne(18, true) + 4
	for ligne in rendu:
		hauteur += 30 if ligne == null else Ui.hauteur_ligne(ligne[2]) + 3
	hauteur += marge - 3
	var x := rect_ennemi.end.x + 8 if rect_ennemi.end.x + 8 + largeur <= Ui.LARGEUR - 4 else rect_ennemi.position.x - 8 - largeur
	x = maxf(4, minf(x, Ui.LARGEUR - largeur - 4))
	var y := maxf(4, minf(rect_ennemi.position.y + 10, Ui.HAUTEUR - hauteur - 4))
	var carte := Rect2(x, y, largeur, hauteur)
	Ui.rect(ci, carte, Color8(15, 13, 22, 225), 0, 8)
	Ui.rect(ci, carte, Color8(150, 110, 60), 1, 8)
	Ui.texte(ci, ennemi.nom, Vector2(x + marge, y + marge), COULEURS["titre"], 18, true)
	var cy := y + marge + Ui.hauteur_ligne(18, true) + 4
	for ligne in rendu:
		if ligne == null:
			var jauges := [[ennemi.points_de_vie, ennemi.points_de_vie_max, Color8(40, 200, 70), "PV"],
				[ennemi.mana, ennemi.mana_max, Color8(60, 120, 255), "mana"]]
			for rang in 2:
				var j: Array = jauges[rang]
				if j[1] <= 0:
					continue
				var bx := x + marge
				var by := cy + rang * 14
				Ui.rect(ci, Rect2(bx, by + 2, 150, 8), Color8(60, 20, 20), 0, 3)
				Ui.rect(ci, Rect2(bx, by + 2, int(150 * maxf(0, j[0]) / j[1]), 8), j[2], 0, 3)
				Ui.texte(ci, "%s / %s %s" % [str(int(maxf(0, j[0]))), str(int(j[1])), j[3]], Vector2(bx + 158, by - 2), COULEURS["normal"], 13)
			cy += 30
			continue
		Ui.texte(ci, ligne[0], Vector2(x + marge, cy), ligne[1], ligne[2])
		cy += Ui.hauteur_ligne(ligne[2]) + 3
