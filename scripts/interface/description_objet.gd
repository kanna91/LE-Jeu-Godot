class_name DescriptionObjet
extends RefCounted
## Description lisible des objets et des compétences, partagée par les écrans.

# [attribut, libellé, format] — format : « plat » (+5), « pourcent » (0.12 → +12 %)
## Ordre d'affichage. Les objets générés depuis la refonte du 2026-10-30 n'ont qu'une option (caractéristique, défense,
## dégâts d'un groupe ou pénétration) ; les autres lignes servent aux objets spéciaux (lance de test, anti-boss).
const STATISTIQUES := [
	["force", "Force", "plat"],
	["dextérité", "Dextérité", "plat"],
	["endurance", "Endurance", "plat"],
	["intelligence", "Intelligence", "plat"],
	["sagesse", "Sagesse", "plat"],
	["caracteristique_mana", "Mana (caractéristique)", "plat"],
	["degats_physique", "Dégâts physiques", "plat"],
	["degats_magique", "Dégâts magiques (arcane, ombre, chaos)", "plat"],
	["degats_elementaire", "Dégâts élémentaires (feu, froid, foudre)", "plat"],
	["armure", "Armure", "plat"],
	["resistance_magique", "Résistance magique", "plat"],
	["resistance_elementaire", "Résistance élémentaire", "plat"],
	["penetration_armure", "Pénétration d'armure", "plat"],
	["penetration_resistance", "Pénétration de résistance", "plat"],
	["resistance_tranchant", "Résistance tranchante", "plat"],
	["resistance_perforant", "Résistance perforante", "plat"],
	["resistance_contondant", "Résistance contondante", "plat"],
	["resistance_feu", "Résistance au feu", "plat"],
	["resistance_froid", "Résistance au froid", "plat"],
	["resistance_foudre", "Résistance à la foudre", "plat"],
	["resistance_arcane", "Résistance à l'arcane", "plat"],
	["resistance_chaos", "Résistance au chaos", "plat"],
	["resistance_ombre", "Résistance à l'ombre", "plat"],
	["resistance_pct_tranchant", "Dégâts tranchants reçus", "moins"],
	["resistance_pct_perforant", "Dégâts perforants reçus", "moins"],
	["resistance_pct_contondant", "Dégâts contondants reçus", "moins"],
	["resistance_pct_feu", "Dégâts de feu reçus", "moins"],
	["resistance_pct_froid", "Dégâts de froid reçus", "moins"],
	["resistance_pct_foudre", "Dégâts de foudre reçus", "moins"],
	["resistance_pct_arcane", "Dégâts d'arcane reçus", "moins"],
	["resistance_pct_chaos", "Dégâts de chaos reçus", "moins"],
	["resistance_pct_ombre", "Dégâts d'ombre reçus", "moins"],
	["degats_base", "Dégâts de base", "plat"],
	["degats_tranchant", "Dégâts tranchants", "plat"],
	["degats_perforant", "Dégâts perforants", "plat"],
	["degats_contondant", "Dégâts contondants", "plat"],
	["degats_feu", "Dégâts de feu", "plat"],
	["degats_froid", "Dégâts de froid", "plat"],
	["degats_foudre", "Dégâts de foudre", "plat"],
	["degats_arcane", "Dégâts d'arcane", "plat"],
	["degats_chaos", "Dégâts de chaos", "plat"],
	["degats_ombre", "Dégâts d'ombre", "plat"],
	["degats_lumière", "Dégâts de lumière", "plat"],
	["pourcentage_degats_physique", "Dégâts physiques", "pourcent"],
	["pourcentage_degats_magique", "Dégâts magiques", "pourcent"],
	["pourcentage_degats_elementaire", "Dégâts élémentaires", "pourcent"],
	["pourcentage_degats_tranchant", "Dégâts tranchants", "pourcent"],
	["pourcentage_degats_perforant", "Dégâts perforants", "pourcent"],
	["pourcentage_degats_contondant", "Dégâts contondants", "pourcent"],
	["pourcentage_degats_feu", "Dégâts de feu", "pourcent"],
	["pourcentage_degats_froid", "Dégâts de froid", "pourcent"],
	["pourcentage_degats_foudre", "Dégâts de foudre", "pourcent"],
	["pourcentage_degats_arcane", "Dégâts d'arcane", "pourcent"],
	["pourcentage_degats_chaos", "Dégâts de chaos", "pourcent"],
	["pourcentage_degats_ombre", "Dégâts d'ombre", "pourcent"],
	["pourcentage_degats_lumière", "Dégâts de lumière", "pourcent"],
	["chance_de_toucher", "Chance de toucher", "pourcent"],
	["chance_de_coup_critique", "Chance de coup critique", "pourcent"],
	["degats_critique", "Dégâts critiques", "pourcent"],
	["chance_de_coup_critique_magique", "Chance de critique magique", "pourcent"],
	["degats_critique_magiques", "Dégâts critiques magiques", "pourcent"],
	["puissance_magique", "Puissance magique", "plat"],
	["points_de_vie_max", "PV max", "plat"],
	["regen_de_points_de_vie", "Régénération de PV", "plat"],
	["mana_max", "Mana max", "plat"],
	["regen_de_mana", "Régénération de mana", "plat"],
	["points_d_action_max", "PA max", "plat"],
	["chance_esquive", "Esquive", "pourcent"],
	["chance_de_parer", "Parade", "pourcent"],
]

const RANGS := {1: ["Médiocre", Color8(175, 175, 175)], 2: ["Commun", Color8(240, 240, 240)], 3: ["Précieux", Color8(110, 220, 110)],
	4: ["Rare", Color8(100, 160, 255)], 5: ["Unique", Color8(200, 120, 255)], 6: ["Légendaire", Color8(255, 165, 40)]}
const NOMS_EMPLACEMENTS := {"arme": "Arme", "casque": "Casque", "plastron": "Plastron", "gants": "Gants",
	"ceinture": "Ceinture", "jambières": "Jambières", "bottes": "Bottes",
	"anneau": "Anneau", "anneau_1": "Anneau 1", "anneau_2": "Anneau 2", "amulette": "Amulette"}
const NOMS_ARMES := {"Epée": "Épée", "Lance": "Lance", "Marteau": "Marteau"}
const FAMILLES := {"arme": "offensif", "anneau": "offensif", "amulette": "offensif", "casque": "defensif",
	"plastron": "defensif", "jambières": "defensif", "bottes": "hybride", "ceinture": "hybride", "gants": "hybride"}
const NOMS_FAMILLES := {"offensif": "Offensif", "defensif": "Défensif", "hybride": "Hybride"}
const NOMS_ORIENTATIONS := {"physique": "Physique", "magique": "Magique", "elementaire": "Élémentaire", "mixte": "Mixte"}
const COULEURS_FAMILLES := {"offensif": Color8(235, 110, 90), "defensif": Color8(110, 160, 235), "hybride": Color8(190, 150, 230)}
const COULEUR_TITRE := Color8(255, 215, 0)
const COULEUR_UNIQUE := Color8(255, 190, 90)
const COULEUR_TEXTE := Color8(235, 235, 235)
const COULEUR_DETAIL := Color8(170, 170, 185)
const COULEUR_PLUS := Color8(110, 230, 120)
const COULEUR_MOINS := Color8(255, 110, 90)
const MODES_TRI := {"arrivee": "Arrivée", "rarete": "Rareté", "type": "Type"}
const ORDRE_TYPES := ["arme", "casque", "plastron", "gants", "ceinture", "jambières", "bottes", "anneau", "amulette"]
const ORDRE_POTIONS := ["pv", "mana", "mixte"]
const CIBLAGES := {"choix": "un ennemi au choix", "aléatoire": "ennemi(s) au hasard", "toute": "tous les ennemis",
	"all": "tous les combattants", "self": "vous-même"}
const COULEURS_ELEMENTS := {"feu": Color8(255, 140, 40), "froid": Color8(150, 215, 255), "foudre": Color8(255, 235, 110),
	"arcane": Color8(195, 120, 255), "chaos": Color8(235, 45, 95), "ombre": Color8(150, 80, 200),
	"lumière": Color8(255, 230, 120), "tranchant": Color8(235, 235, 245), "perforant": Color8(255, 225, 160),
	"contondant": Color8(225, 175, 115)}


## [nom du rang, couleur] d'un objet.
static func rang(objet) -> Array:
	return RANGS.get(int(U.num(objet, "rang")), ["", COULEUR_TEXTE])


static func emplacement(objet):
	return Objets.type_emplacement(objet)


static func emplacement_cible(joueur, objet):
	return Objets.emplacement_pour(joueur.equipements, objet)


static func famille(objet):
	var f = U.ga(objet, "famille", null)
	if U.vrai(f):
		return f
	return FAMILLES.get(emplacement(objet))


## Catégorie lisible (« Arme — Lance · Offensif · Physique », « Consommable »...).
static func categorie(objet) -> String:
	var suite := ""
	for x in [NOMS_FAMILLES.get(famille(objet)), NOMS_ORIENTATIONS.get(U.ga(objet, "orientation", null))]:
		if x != null:
			suite += " · " + x
	if objet.est_arme():
		var type_arme = U.ga(objet, "type_arme", "")
		var t := ("Arme — %s" % NOMS_ARMES.get(type_arme, type_arme)).rstrip(" —")
		return t + suite
	if objet.est_bijou():
		return "Bijou — %s" % NOMS_EMPLACEMENTS.get(objet.type_armure, objet.type_armure) + suite
	if objet.est_armure():
		var t = U.ga(objet, "type_armure", "")
		return "Armure — %s" % NOMS_EMPLACEMENTS.get(t, t) + suite
	if objet.est_consommable():
		return "Consommable"
	if U.ga(objet, "type_objet", null) == "cle":
		return "Divers — Clé"
	if objet.est_divers():
		return "%s — %s" % [ObjetsDivers.NOMS_CATEGORIES.get(U.ga(objet, "type_objet", ""), "Divers"), ObjetsDivers.SORTES.get(U.ga(objet, "sorte", ""), "Objet")]
	return "Objet"


## Valeur formatée (« +5 », « +12 % » ; mode « moins » : une résistance en pourcentage, 0.20 → « −20 % »).
static func formater(valeur, mode: String, signe := true) -> String:
	var t: String
	if mode == "moins":
		return ("−" if valeur > 0 else "+") + "%s %%" % U.f(absf(valeur) * 100, 0)
	if mode == "pourcent":
		t = ("%s %%" % U.f(valeur * 100, 0)) if (absf(valeur * 100) >= 1 or valeur == 0) else ("%s %%" % U.f(valeur * 100, 1))
	else:
		t = U.f(valeur, 2).rstrip("0").rstrip(".") if valeur is float else str(valeur)
	return ("+" + t) if signe and valeur > 0 else t


## Statistiques non nulles : [[attribut, libellé, valeur, texte], ...].
static func statistiques(objet) -> Array:
	var lignes := []
	var des := ligne_des(objet)
	if des != "":
		lignes.append(["des", "Dégâts", 0, des])
	# Améliorations (armurier, alchimiste, enchanteur, 2026-11-09), une ligne par PNJ
	for morceau in AmeliorationsArmes.resume(objet).split(" · ", false):
		lignes.append(["ameliorations", "Améliorations", 0, morceau])
	for s in STATISTIQUES:
		var valeur = U.ga(objet, s[0], 0)
		if (valeur is int or valeur is float) and valeur != 0:
			lignes.append([s[0], s[1], valeur, "%s %s" % [s[1], formater(valeur, s[2])]])
	return lignes


## Effet unique d'un équipement (« ★ ... ») ou chaîne vide.
static func effet_unique(objet) -> String:
	var attribut = U.ga(objet, "unique", null)
	if not U.vrai(attribut):
		return ""
	var lignes := Talents.decrire_stats({attribut: U.ga(objet, attribut, 0)})
	return "★ " + (lignes[0] if not lignes.is_empty() else attribut)


## Clé de pile : les consommables identiques partagent la même.
static func cle_pile(objet) -> String:
	var effet = U.ga(objet, "effet", null)
	if objet.est_consommable() and effet is Dictionary:
		return "pile|%s|%s|%s" % [objet.nom, effet.get("type"), effet.get("valeur")]
	if objet.est_divers():
		# Plats cuisinés de valeurs différentes, seaux plus ou moins pleins : piles séparées
		return "divers|%s|%s|%s|%s|%s" % [U.ga(objet, "type_objet", ""), objet.nom, U.num(objet, "pv"), U.num(objet, "mana"), U.num(objet, "eau")]
	return "objet|%d" % objet.get_instance_id()


## Consommables identiques regroupés : [[objet représentant, nombre, clé], ...].
static func regrouper(liste: Array) -> Array:
	var piles := {}
	var ordre := []
	for objet in liste:
		var cle := cle_pile(objet)
		if not piles.has(cle):
			piles[cle] = [objet, 0]
			ordre.append(cle)
		piles[cle][1] += 1
	var resultat := []
	for cle in ordre:
		resultat.append([piles[cle][0], piles[cle][1], cle])
	return resultat


static func ordre_type(objet) -> Array:
	if objet.est_divers():
		return [ORDRE_TYPES.size() + 1, 0, objet.nom]
	if objet.est_consommable():
		var effet = U.ga(objet, "effet", null)
		var type_potion = effet.get("type") if effet is Dictionary else null
		return [ORDRE_TYPES.size(), ORDRE_POTIONS.find(type_potion) if type_potion in ORDRE_POTIONS else ORDRE_POTIONS.size(), objet.nom]
	var place = emplacement(objet)
	return [ORDRE_TYPES.find(place) if place in ORDRE_TYPES else ORDRE_TYPES.size() - 1, 0,
		U.ga(objet, "type_arme", "") if objet.est_arme() else ""]


static func _comparer_listes(a: Array, b: Array) -> bool:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return a[i] < b[i]
	return a.size() < b.size()


## Tri des lignes d'objets : « arrivee », « rarete », « type » (stable).
static func trier(lignes: Array, mode: String) -> Array:
	if mode == "arrivee":
		return lignes.duplicate()
	var avec_cles := []
	for i in lignes.size():
		var o = lignes[i][0]
		var r := -int(U.num(o, "rang"))
		var cle: Array = ([r] + ordre_type(o)) if mode == "rarete" else (ordre_type(o) + [r])
		avec_cles.append([cle + [i], lignes[i]])
	avec_cles.sort_custom(func(x, y): return _comparer_listes(x[0], y[0]))
	var resultat := []
	for e in avec_cles:
		resultat.append(e[1])
	return resultat


static func effet_consommable(objet) -> String:
	var effet = U.ga(objet, "effet", null)
	if not (effet is Dictionary):
		return ""
	if U.vrai(effet.get("fixe", false)):
		var n := int(effet.get("valeur", 0))
		return {"pv": "Rend %d PV" % n, "mana": "Rend %d points de mana" % n,
			"mixte": "Rend %d PV et %d points de mana" % [n, n]}.get(effet.get("type"), "")
	var part := "%s %%" % U.f(effet.get("valeur", 0) * 100, 0)
	return {"pv": "Rend %s des PV max" % part, "mana": "Rend %s du mana max" % part,
		"mixte": "Rend %s des PV max et du mana max" % part}.get(effet.get("type"), "")


## Comparaison avec l'objet équipé : [[texte, couleur], ...].
## Dégâts d'une arme (« Dégâts perforants + 1d4 de feu ») ou chaîne vide. Depuis le 2026-11-02, les dés sont ceux de
## chaque attaque (Formules.DES_HEROS) : l'arme ne donne que son type et son dé bonus.
static func ligne_des(objet) -> String:
	if not objet.est_arme():
		return ""
	var type_arme = U.ga(objet, "type_arme", "")
	if not Formules.DES_ARMES.has(type_arme):
		return ""
	var texte := "Dégâts %ss" % Formules.DES_ARMES[type_arme]
	var bonus := Formules.de_bonus(objet)
	if not bonus.is_empty():
		texte += " + 1d%d %s" % [bonus["faces"], ("%ss" % bonus["type"]) if bonus["type"] in Formules.TYPES_PHYSIQUES else "de " + bonus["type"]]
	return texte


static func comparaison(objet, equipe) -> Array:
	var lignes := []
	var des_objet := ligne_des(objet)
	if des_objet != ligne_des(equipe) and des_objet != "":
		lignes.append([des_objet, COULEUR_DETAIL])
	for s in STATISTIQUES:
		var a = U.ga(objet, s[0], 0)
		var b = U.ga(equipe, s[0], 0)
		if a == null:
			a = 0
		if b == null:
			b = 0
		if not (a is int or a is float) or not (b is int or b is float):
			continue
		var ecart = a - b
		if absf(ecart) >= 0.005:
			lignes.append(["%s %s" % [s[1], formater(ecart, s[2])], COULEUR_PLUS if ecart > 0 else COULEUR_MOINS])
	return lignes


static func objet_equipe(joueur, objet):
	var cle = emplacement_cible(joueur, objet)
	if cle == null:
		return null
	return joueur.equipements.get(cle)


static func couleur_competence(comp) -> Color:
	var types = U.ga(comp, "type_degats", null)
	if types != null:
		for t in types:
			if U.vrai(t):
				return COULEURS_ELEMENTS.get(t, COULEUR_DETAIL)
	return COULEUR_DETAIL


## Lignes d'une info-bulle de compétence : textes ou [texte, couleur].
static func lignes_competence(comp, lanceur = null) -> Array:
	var lignes := []
	if U.vrai(U.ga(comp, "description", "")):
		lignes.append([comp.description, COULEUR_DETAIL])
	if U.vrai(U.ga(comp, "PALIER", null)) and U.vrai(U.ga(comp, "ELEMENT", null)):
		var nature := "technique physique" if comp.type_attaque == "physique" else "sort"
		lignes.append(["%s · %s de palier %d" % [U.majuscule(comp.ELEMENT), nature, comp.PALIER], couleur_competence(comp)])
	var cout := Talents.libelle_cout(lanceur, comp) if lanceur != null else "%s mana" % str(comp.cout_mana)
	lignes.append("Niveau %d · coût : %s PA, %s" % [comp.niveau, str(comp.cout_action), cout])
	var cible = CIBLAGES.get(comp.type_ciblage, comp.type_ciblage)
	var coups := " · %d coups" % comp.nombre_attaque if comp.nombre_attaque > 1 else ""
	var nombre := "%d " % comp.nombre_cible if comp.type_ciblage in ["choix", "aléatoire"] and comp.nombre_cible > 1 else ""
	lignes.append("Cible : %s%s%s" % [nombre, cible, coups])
	var types := []
	if U.ga(comp, "type_degats", null) != null:
		for t in comp.type_degats:
			if U.vrai(t):
				types.append(t)
	if not types.is_empty():
		lignes.append("Dégâts : " + ", ".join(types))
	if lanceur != null and not types.is_empty():
		var neutre := CibleNeutre.new()
		var degats := 0.0
		var soin := 0.0
		for e in Formules.estimer_degats(lanceur, comp, neutre):
			if e[2] >= 0:
				degats += e[1]
			else:
				soin -= e[2]
		if degats:
			lignes.append(["≈ %s dégâts par utilisation, avant résistances" % U.f(degats * comp.nombre_attaque), COULEUR_PLUS])
		if soin:
			var part := U.num(comp, "soin_pourcentage_pv") + Formules.part_pv_cible(lanceur, comp, "lumière")
			lignes.append(["≈ %s PV rendus (lumière)%s" % [U.f(soin), (" + %s %% des PV max de la cible" % U.f(part * 100)) if part else ""], COULEUR_PLUS])
	var bonus := []
	if Formules.facteur_degats(comp) != 1:  # le multiplicateur qui agit (éditeur, 2026-11-06), pas l'ancien multiplicateur_degats
		bonus.append("%s ×%s" % ["soins" if comp.type_competence == "heal" else "dégâts", U.f(Formules.facteur_degats(comp), 2)])
	if U.num(comp, "bonus_toucher"):
		bonus.append("toucher +%s %%" % U.f(comp.bonus_toucher * 100))
	if U.num(comp, "bonus_critique"):
		bonus.append("critique +%s %%" % U.f(comp.bonus_critique * 100))
	if U.num(comp, "bonus_degats_critique"):
		bonus.append("dégâts critiques +%s %%" % U.f(comp.bonus_degats_critique * 100))
	if U.num(comp, "vol_de_vie"):
		bonus.append("vol de vie %s %%" % U.f(comp.vol_de_vie * 100))
	if U.num(comp, "bonus_execution"):
		bonus.append("+%s %% sur une cible sous 50 %% de ses PV" % U.f(comp.bonus_execution * 100))
	if U.num(comp, "penetration_armure"):
		bonus.append("pénétration d'armure %s" % U.g(comp.penetration_armure))
	if U.num(comp, "penetration_resistance"):
		bonus.append("pénétration de résistance %s" % U.g(comp.penetration_resistance))
	var purification := U.num(comp, "purification")
	if purification:
		bonus.append("dissipe tous vos malus" if purification >= 99 else "dissipe %d malus" % purification)
	if not bonus.is_empty():
		lignes.append("Bonus : " + ", ".join(bonus))
	var ta = U.ga(comp, "type_alteration", {})
	for nom in ta:
		var chance = ta[nom]
		if U.vrai(chance):
			var couleur := COULEUR_PLUS if Alterations.est_bonus(nom) else COULEUR_MOINS
			lignes.append(["%s %s %% : %s" % [Alterations.libelle(nom), U.g(chance), Alterations.description(nom, comp.puissance_alterations.get(nom))], couleur])
	var al = U.ga(comp, "alterations_lanceur", {})
	for nom in al:
		lignes.append(["Vous donne %s (%s %%) : %s" % [Alterations.libelle(nom), U.g(al[nom]), Alterations.description(nom)], COULEUR_PLUS])
	lignes.append_array(lignes_valeur_competence(comp))
	return lignes


## Valeur en points d'une compétence et ses principaux attributs.
static func lignes_valeur_competence(comp, nombre := 4) -> Array:
	var detail := ValeurCompetences.detail(comp)
	var total := 0.0
	for d in detail:
		total += d[1]
	var base = U.ga(comp, "valeur_base", null)
	var texte := "Valeur : %s points" % U.f(total)
	if base != null:
		texte += " (base %s, palier %d)" % [U.f(base), ValeurCompetences.palier(comp)]
	var parties := []
	for d in detail.slice(0, nombre):
		if round(d[1]) > 0:
			parties.append("%s %s" % [d[0], U.f(d[1])])
	var lignes := [[texte, COULEUR_TITRE]]
	if not parties.is_empty():
		lignes.append([", ".join(parties) + (" …" if detail.size() > nombre else ""), COULEUR_DETAIL])
	return lignes


## Carte d'information d'un objet, à côté d'un rectangle (prix et aide : [texte, couleur] / texte).
static func dessiner_infobulle(ci: CanvasItem, objet, ancre: Rect2, joueur = null, prix = null, aide = null) -> void:
	var largeur := 300
	var marge := 12
	var r := rang(objet)
	var nom_rang: String = r[0]
	var couleur_rang: Color = r[1]
	var lignes := [[objet.nom, couleur_rang, 17, true],
		[categorie(objet) + (" · %s" % nom_rang if nom_rang != "" else ""), COULEUR_DETAIL, 13, false]]
	if objet.est_consommable():
		var effet := effet_consommable(objet)
		if effet != "":
			lignes.append([effet, COULEUR_PLUS, 14, false])
	elif objet.est_divers():
		lignes.append([String(U.ga(objet, "description", "")), COULEUR_TEXTE, 14, false])
		if objet.est_nourriture():
			lignes.append(["Se mange (hors combat) : %s" % effet_nourriture(objet), COULEUR_PLUS, 14, false])
		if String(objet.nom) == "Seau en bois":
			lignes.append(["Eau : %d / 10 litres" % int(U.num(objet, "eau")), COULEUR_PLUS, 14, false])
		if int(U.num(objet, "valeur")) > 0:
			lignes.append(["Se revend %d or chez le marchand" % int(U.num(objet, "valeur")), COULEUR_DETAIL, 13, false])
	else:
		var stats := statistiques(objet)
		if stats.is_empty():
			lignes.append(["Aucun bonus", COULEUR_DETAIL, 14, false])
		for s in stats:
			lignes.append([s[3], COULEUR_TEXTE, 14, false])
		if effet_unique(objet) != "":
			lignes.append([effet_unique(objet), COULEUR_UNIQUE, 14, true])
		if U.vrai(U.ga(objet, "points", null)):
			lignes.append(["Valeur de l'objet : %s points" % U.g(objet.points), COULEURS_FAMILLES.get(famille(objet), COULEUR_DETAIL), 13, false])
	if joueur != null and not objet.est_consommable() and not objet.est_divers():
		var equipe = objet_equipe(joueur, objet)
		if equipe != null and equipe != objet:
			lignes.append(["Comparé à %s :" % equipe.nom, COULEUR_DETAIL, 13, true])
			var differences := comparaison(objet, equipe)
			if differences.is_empty():
				lignes.append(["Identique", COULEUR_DETAIL, 14, false])
			for d in differences:
				lignes.append([d[0], d[1], 14, false])
		elif equipe == null and emplacement_cible(joueur, objet) != null:
			var cle = emplacement_cible(joueur, objet)
			lignes.append(["Emplacement %s libre" % NOMS_EMPLACEMENTS.get(cle, cle), COULEUR_PLUS, 13, false])
	if prix != null:
		lignes.append([prix[0], prix[1], 14, true])
	if aide != null:
		lignes.append([aide, COULEUR_TITRE, 13, false])
	# Les lignes trop longues passent à la ligne (elles étaient coupées) ; si la bulle dépasse la hauteur de l'écran,
	# elle s'élargit, puis le texte rapetisse.
	var rendu := []
	var hauteur := 0.0
	var reduction := 0
	for essai in 4:
		largeur = [350, 400, 460, 460][essai]
		reduction = 2 if essai == 3 else 0
		rendu = []
		hauteur = marge * 2.0
		for l in lignes:
			var taille: int = l[2] - reduction
			for morceau in Ui.decouper(str(l[0]), taille, l[3], largeur - 2 * marge):
				rendu.append([morceau, l[1], taille, l[3]])
				hauteur += Ui.hauteur_ligne(taille, l[3]) + 2
		if hauteur <= Ui.HAUTEUR - 8:
			break
	var x := ancre.end.x + 10 if ancre.end.x + 10 + largeur <= Ui.LARGEUR - 4 else ancre.position.x - 10 - largeur
	x = maxf(4, minf(x, Ui.LARGEUR - largeur - 4))
	var y := maxf(4, minf(ancre.position.y, Ui.HAUTEUR - hauteur - 4))
	var carte := Rect2(x, y, largeur, hauteur)
	Ui.rect(ci, carte, Color8(15, 13, 22, 235), 0, 8)
	Ui.rect(ci, carte, couleur_rang, 1, 8)
	var cy := y + marge
	for l in rendu:
		Ui.texte(ci, l[0], Vector2(x + marge, cy), l[1], l[2], l[3])
		cy += Ui.hauteur_ligne(l[2], l[3]) + 2


## Cible fictive sans armure ni résistance (estimation des dégâts « bruts »).
class CibleNeutre:
	extends Reference

	func _init() -> void:
		_d = {"alteration": {}}

	func lire(_nom: String, _defaut = null):
		return 0

	func _get(_propriete):
		return 0


## Effet d'une nourriture : « rend 35 PV », « rend 10 PV et 29 mana »…
static func effet_nourriture(objet) -> String:
	var morceaux := []
	if int(U.num(objet, "pv")) > 0:
		morceaux.append("%d PV" % int(U.num(objet, "pv")))
	if int(U.num(objet, "mana")) > 0:
		morceaux.append("%d mana" % int(U.num(objet, "mana")))
	return ("rend " + " et ".join(morceaux)) if not morceaux.is_empty() else "ne nourrit presque pas"
