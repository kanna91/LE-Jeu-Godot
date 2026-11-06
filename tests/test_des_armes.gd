extends SceneTree
## Dégâts aux dés : dés par type de dégâts (Formules.DES_TYPES), + 2 par point de la caractéristique (2026-10-29)
## du type, × pourcentages ; dés bonus des armes ; armure et résistances (2 points = −1 dégât, 2026-10-30) ; brûlure 1d2.
## godot --headless --path godot -s tests/test_des_armes.gd


## type -> [minimum, maximum, moyenne]
const ATTENDU := {
	"tranchant": [2, 12, 7.0], "perforant": [1, 12, 6.5], "contondant": [2, 12, 7.0],
	"feu": [2, 12, 7.0], "froid": [3, 12, 7.5], "foudre": [1, 12, 6.5],
	"arcane": [2, 12, 7.0], "chaos": [3, 12, 7.5], "ombre": [2, 12, 7.0],
	"lumière": [3, 18, 10.5], "poison": [1, 2, 1.5],
}
## type -> caractéristique qui donne +2 par point
const CARACTERISTIQUE := {
	"tranchant": "force", "perforant": "force", "contondant": "force",
	"feu": "sagesse", "froid": "sagesse", "foudre": "sagesse",
	"arcane": "intelligence", "chaos": "intelligence", "ombre": "intelligence",
}


func _initialize() -> void:
	seed(3)
	var echecs := 0
	echecs += _des()
	echecs += _caracteristiques()
	echecs += _armes_generees()
	echecs += _des_bonus()
	echecs += _defenses()
	echecs += _brulure()
	echecs += _coups_multiples()
	echecs += _attaques_arme()
	echecs += _pourcentage_element()
	echecs += _des_ennemis()
	echecs += _anciennes_parties()
	print("BILAN dés : %d échec(s)" % echecs)
	quit(1 if echecs else 0)


## Parties enregistrées avant le 2026-11-03 : sort amélioré remis à sa base (niveau gardé), PV par endurance 10 → 5.
func _anciennes_parties() -> int:
	var echecs := 0
	var sort := Competences.creer(Competences.classes_de_sorts()[0])
	var base: Dictionary = sort._d.duplicate(true)
	sort._d["ameliorations_possibles"] = [[{"investi": 10}]]
	sort._d["cout_mana"] += 7
	sort._d["multiplicateur_degats"] = 3.0
	sort._d["niveau"] = 4
	Sauvegarde._oublier_ameliorations(sort)
	if sort._d.has("ameliorations_possibles") or sort.cout_mana != base["cout_mana"] or sort.multiplicateur_degats != base["multiplicateur_degats"] \
			or sort.niveau != 4 or not sort is Sort or sort.PALIER != base["PALIER"]:
		print("ÉCHEC : ancien sort amélioré mal remis à zéro (%s mana, ×%s, niveau %s)." % [sort.cout_mana, sort.multiplicateur_degats, sort.niveau])
		echecs += 1
	var heros := Personnage.nouveau()
	heros._d.erase("pv_par_tranche_endurance")
	heros._d["bonus_pv_par_endurance"] = 11  # 10 + 1 de talent
	heros.endurance = 4
	heros.calculer_stats()
	if heros.bonus_pv_par_endurance != 6 or heros.points_de_vie_max != Personnage.PV_BASE_HEROS + 12:
		print("ÉCHEC : ancienne partie : %s PV par tranche, %s PV max." % [heros.bonus_pv_par_endurance, heros.points_de_vie_max])
		echecs += 1
	return echecs


func _des() -> int:
	var echecs := 0
	for t in ATTENDU:
		var a: Array = ATTENDU[t]
		var des: Array = Formules.DES_TYPES[t]
		var mini := 999
		var maxi := 0
		var somme := 0
		for i in 20000:
			var j := Formules.jet(des)
			mini = mini if mini < j else j
			maxi = maxi if maxi > j else j
			somme += j
		var moyenne := somme / 20000.0
		print("%s : %s, jets %d à %d, moyenne %.2f" % [t, Formules.texte(des), mini, maxi, moyenne])
		if mini != a[0] or maxi != a[1] or absf(moyenne - a[2]) > 0.15 or Formules.moyenne(des) != a[2]:
			print("ÉCHEC : dés de %s." % t)
			echecs += 1
	return echecs


## (moyenne + 1d2 tous les 2 points de caractéristique, soit 1,5 par paire de points + plats) × pourcentages, sans dégâts de base ni dégâts propres de la compétence.
func _caracteristiques() -> int:
	var echecs := 0
	var lanceur := {"force": 7, "sagesse": 5, "intelligence": 9, "degats_base": 50, "degats_physique": 1,
		"degats_magique": 2, "degats_elementaire": 3,
		"pourcentage_degats_physique": 1.5, "pourcentage_degats_magique": 2.0, "pourcentage_degats_elementaire": 3.0}
	for t in ATTENDU:
		var stat_bonus := 0.0
		if CARACTERISTIQUE.has(t):
			stat_bonus = floori(int(lanceur[CARACTERISTIQUE[t]]) / 2.0) * 1.5
		elif t == "lumière":
			stat_bonus = 6.0  # intelligence 9 > sagesse 5 : 4d2
		var plats := 1 if t in Formules.TYPES_PHYSIQUES else (3 if t in Formules.ELEMENTAIRES else (2 if t in Formules.MAGIQUES_PURS else 0))
		var pct := 1.5 if t in Formules.TYPES_PHYSIQUES else (1.0 if t == "poison" else (3.0 if t in Formules.ELEMENTAIRES else 2.0))
		var attendu: float = (ATTENDU[t][2] + stat_bonus + plats) * pct
		var obtenu := Formules.degats_bruts(lanceur, null, t)
		if absf(obtenu - attendu) > 0.001:
			print("ÉCHEC : %s : %.2f au lieu de %.2f." % [t, obtenu, attendu])
			echecs += 1
	for nom in ["Coup_de_lance", "Givre", "Trait_arcanique", "Murmure_des_ombres"]:
		var comp := Competences.creer(nom)
		var est := Formules.estimer_degats(lanceur, comp, {"points_de_vie_max": 20})
		print("%s (%s) : %s" % [comp.nom, comp.type_degats, est])
	# Endurance et Mana : +5 et +2/min tous les 2 points (règle de l'utilisateur, 2026-11-03)
	for points in [[0, 0], [1, 0], [2, 1], [3, 1], [4, 2], [7, 3]]:
		var b := Caracteristiques.bonus({"endurance": points[0], Caracteristiques.MANA: points[0]})
		var n: int = points[1]
		if b["points_de_vie_max"] != 5 * n or b["regen_de_points_de_vie"] != 2.0 * n or b["mana_max"] != 5 * n \
				or b["regen_de_mana"] != 2.0 * n:
			print("ÉCHEC : %d points d'endurance et de mana : %s." % [points[0], b])
			echecs += 1
	return echecs


func _armes_generees() -> int:
	var echecs := 0
	for type_arme in Formules.DES_ARMES:
		var t: String = Formules.DES_ARMES[type_arme]
		for rang in [1, 6]:
			for orient in ["physique", "magique", "elementaire"]:
				var arme = GenerationObjets.generer_objet("arme", rang, type_arme, orient)
				if U.num(arme, "degats_" + t) != 0:
					print("ÉCHEC : %s rang %d %s a encore un bonus de dégâts %s." % [type_arme, rang, orient, t])
					echecs += 1
				# Une seule option : dégâts de son orientation ou pénétration (2026-10-30)
				var degats := U.num(arme, GenerationObjets.DEGATS_PAR_ORIENTATION[orient])
				var pen := U.num(arme, GenerationObjets.PENETRATION_PAR_ORIENTATION[orient])
				var ok: bool = (degats == GenerationObjets.DEGATS_PAR_RANG[rang] and pen == 0) or (pen == GenerationObjets.PENETRATION_PAR_RANG[rang] and degats == 0) or (arme.option == "caracteristique" and degats == 0 and pen == 0)
				if not ok:
					print("ÉCHEC : %s rang %d %s : dégâts %s, pénétration %s." % [type_arme, rang, orient, degats, pen])
					echecs += 1
	return echecs


## Dés bonus : rares, taille selon le rang, type de l'arme ou élément.
func _des_bonus() -> int:
	var echecs := 0
	for rang in [1, 6]:
		var avec := 0
		var autres_types := 0
		for i in 3000:
			var arme = GenerationObjets.generer_objet("arme", rang, "Lance", "physique")
			var bonus := Formules.de_bonus(arme)
			if bonus.is_empty():
				continue
			avec += 1
			if bonus["faces"] != GenerationObjets.FACES_DE_BONUS[rang]:
				print("ÉCHEC : dé bonus 1d%d au rang %d." % [bonus["faces"], rang])
				echecs += 1
			if bonus["type"] != "perforant":
				autres_types += 1
		print("Rang %d : %d armes sur 3000 avec un dé bonus (1d%d), dont %d d'un autre type" % [rang, avec, GenerationObjets.FACES_DE_BONUS[rang], autres_types])
		if absf(avec / 3000.0 - GenerationObjets.CHANCES_DE_BONUS[rang]) > 0.03 or autres_types != 0:
			echecs += 1
			print("ÉCHEC : fréquence ou type des dés bonus (une arme physique a un dé de son type).")
	# Arme magique : dé d'arcane, d'ombre ou de chaos ; son type est écrit dans son nom
	var runique = GenerationObjets.generer_objet("arme", 3, "Epée", "magique")
	GenerationObjets.ajouter_de_bonus(runique, 3)
	if not Formules.de_bonus(runique)["type"] in ["arcane", "ombre", "chaos"]:
		print("ÉCHEC : dé bonus d'une arme magique.")
		echecs += 1
	if not String(runique.nom).begins_with("Épée magique"):
		print("ÉCHEC : nom de l'arme magique (%s)." % runique.nom)
		echecs += 1
	var lance := Arme.nouvelle("Lance", "arme", "Lance")
	lance.set("de_bonus", {"faces": 6, "type": "feu"})
	var porteur := {"arme_equipee": lance}
	if Formules.de_bonus_autre_type(porteur, ["perforant"]) != ["feu", 6] or not Formules.de_bonus_autre_type(porteur, ["feu"]).is_empty():
		print("ÉCHEC : déclenchement du dé bonus de feu.")
		echecs += 1
	print(DescriptionObjet.ligne_des(lance))
	lance.set("de_bonus", {"faces": 6, "type": "perforant"})
	if Formules.moyenne(Formules.des_type(porteur, "perforant")) != 10.0 or Formules.moyenne(Formules.des_type(porteur, "tranchant")) != 7.0:
		print("ÉCHEC : dé bonus du type de l'arme.")
		echecs += 1
	return echecs


## 2 points de défense = −1 dégât (2026-10-30) : armure (physique), résistance élémentaire (feu, froid, foudre),
## résistance magique (arcane, ombre, chaos) ou résistance spécifique, sans cumul (la meilleure) ; pénétration
## retirée avant ; lumière et poison non concernés ; vulnérabilités et résistances en % appliquées d'abord.
func _defenses() -> int:
	var echecs := 0
	var cible := {"armure": 5, "resistance_elementaire": 3, "resistance_magique": 6, "resistance_feu": 6}
	var cas := [["tranchant", 0, 0, 2], ["tranchant", 2, 0, 1], ["feu", 0, 0, 3], ["foudre", 0, 0, 1], ["ombre", 0, 0, 3],
		["ombre", 0, 4, 1], ["lumière", 0, 0, 0], ["poison", 0, 0, 0]]
	for c in cas:
		var r := Degats.reduction_fixe(cible, c[0], c[1], c[2])
		if r != c[3]:
			print("ÉCHEC : réduction %s (pén. %d/%d) = %d au lieu de %d." % [c[0], c[1], c[2], r, c[3]])
			echecs += 1
	if Degats.degats_subis(cible, "tranchant", 1.0) != 0.0 or Degats.degats_subis(cible, "tranchant", 7.0) != 5.0:
		print("ÉCHEC : dégâts subis après armure.")
		echecs += 1
	# Pas de cumul : 3 d'armure et 1 de résistance tranchant = −1 (exemple de l'utilisateur)
	if Degats.reduction_fixe({"armure": 3, "resistance_tranchant": 1}, "tranchant") != 1:
		print("ÉCHEC : armure et résistance spécifique ne doivent pas se cumuler.")
		echecs += 1
	# Faiblesse de 40 % au feu : 10 → 14, puis −1 (résistance élémentaire 3)
	var faible := {"resistance_elementaire": 3, "vulnerabilite_feu": 0.40}
	if absf(Degats.degats_subis(faible, "feu", 10.0) - 13.0) > 0.001:
		print("ÉCHEC : faiblesse au feu (%s au lieu de 13)." % Degats.degats_subis(faible, "feu", 10.0))
		echecs += 1
	# Protection (−40 % physique) et vulnérabilité (+10 %) s'additionnent : ×0,70
	var protege := {"resistance_pct_physique": 0.40, "vulnerabilite_tranchant": 0.10}
	if absf(Degats.multiplicateur(protege, "tranchant") - 0.70) > 0.001 or Degats.multiplicateur(protege, "feu") != 1.0:
		print("ÉCHEC : pourcentages de dégâts reçus.")
		echecs += 1
	var heros := Personnage.nouveau()
	print("Héros : armure %s, résistance élémentaire %s (sagesse %s), résistance magique %s (intelligence %s)" % [
		heros.armure, heros.resistance_elementaire, heros.sagesse, heros.resistance_magique, heros.intelligence])
	if heros.resistance_elementaire != 0 or heros.armure != 0 or heros.resistance_magique != 0:
		print("ÉCHEC : défenses de départ du héros (0 partout).")
		echecs += 1
	return echecs


func _brulure() -> int:
	var echecs := 0
	for cumul in [1, 3]:
		var mini := 99
		var maxi := 0
		for i in 2000:
			var r: Array = Alterations._dot_brulure(null, {"cumul": cumul}, 1)
			mini = mini if mini < r[1] else r[1]
			maxi = maxi if maxi > r[1] else r[1]
			if r[0] != "feu":
				echecs += 1
		print("Brûlure × %d : %d à %d" % [cumul, mini, maxi])
		if mini != cumul or maxi != 2 * cumul:
			print("ÉCHEC : brûlure × %d." % cumul)
			echecs += 1
	return echecs


## Coups multiples (Rafale de lance...) : 1d6 − 2 par coup, + 1d2 tous les 2 points de caractéristique, × pourcentages, jamais négatif.
func _coups_multiples() -> int:
	var echecs := 0
	var rafale := Competences.creer("Rafale_de_lance")
	var simple := Competences.creer("Coup_de_lance")
	var lanceur := {"force": 4, "pourcentage_degats_physique": 1.0}
	if not Formules.est_coup_multiple(rafale) or Formules.est_coup_multiple(simple):
		print("ÉCHEC : détection des coups multiples.")
		echecs += 1
	var attendu := (3.5 - 2 + 3) * 1.0  # force 4 : 2d2 = 3 en moyenne
	if absf(Formules.degats_bruts(lanceur, rafale, "perforant") - attendu) > 0.001:
		print("ÉCHEC : Rafale de lance %.2f au lieu de %.2f par coup." % [Formules.degats_bruts(lanceur, rafale, "perforant"), attendu])
		echecs += 1
	var mini := 99.0
	var maxi := -99.0
	for i in 3000:
		var v := Formules.base_degats({"force": 0}, "perforant", Formules.valeur_jet({"force": 0}, rafale, "perforant"))
		mini = minf(mini, v)
		maxi = maxf(maxi, v)
	print("Rafale de lance (%d coups), force 0 : %.0f à %.0f par coup" % [rafale.nombre_attaque, mini, maxi])
	if mini != 0 or maxi != 4:
		print("ÉCHEC : bornes d'un coup multiple.")
		echecs += 1
	return echecs


## Le dé bonus de l'arme ne sert qu'aux attaques de l'arme (Coup de marteau, Fracasser...) :
## un sort qui fait le même type (Givre : froid) garde ses propres dés.
func _attaques_arme() -> int:
	var echecs := 0
	var marteau := Arme.nouvelle("Marteau", "arme", "Marteau")
	var porteur := {"arme_equipee": marteau, "force": 0, "sagesse": 0}
	var coup := Competences.creer("Coup_de_marteau")
	var sort := Competences.creer("Givre")
	var des_sort := Formules.moyenne(Formules.des_type(porteur, "froid", sort))
	marteau.set("de_bonus", {"faces": 6, "type": "contondant"})
	if Formules.moyenne(Formules.des_type(porteur, "contondant", coup)) != 12.5:  # 6d2 (2026-11-01) + 1d6
		print("ÉCHEC : Coup de marteau sans le dé bonus contondant.")
		echecs += 1
	marteau.set("de_bonus", {"faces": 6, "type": "froid"})
	if Formules.moyenne(Formules.des_type(porteur, "froid", sort)) != des_sort:
		print("ÉCHEC : Givre profite du dé bonus de froid de l'arme.")
		echecs += 1
	if Formules.de_bonus_autre_type(porteur, coup.type_degats, coup) != ["froid", 6]:
		print("ÉCHEC : Coup de marteau sans le dé bonus de froid.")
		echecs += 1
	if not Formules.de_bonus_autre_type(porteur, sort.type_degats, sort).is_empty():
		print("ÉCHEC : Givre déclenche le dé bonus de froid.")
		echecs += 1
	var froid := 0
	for r in Formules.estimer_degats(porteur, sort, {}, false):
		if r[0] == "froid":
			froid += 1
	if froid != 1:
		print("ÉCHEC : estimation de Givre : froid compté %d fois." % froid)
		echecs += 1
	return echecs


## Bonus « +x % de dégâts d'un élément » (table pourcentage_types) : n'ajoute pas de type, ne joue que si la
## compétence en inflige.
func _pourcentage_element() -> int:
	var echecs := 0
	var lanceur := {"force": 0, "sagesse": 0}
	var givre := Competences.creer("Givre")
	var avant := Formules.degats_bruts(lanceur, givre, "froid")
	givre.pourcentage_types["foudre"] = 0.05
	if "foudre" in givre.type_degats or Formules.degats_bruts(lanceur, givre, "froid") != avant:
		print("ÉCHEC : +5 %% de foudre change Givre (%s)." % [givre.type_degats])
		echecs += 1
	var eclair := Competences.creer("Eclair")
	var avant_eclair := Formules.degats_bruts(lanceur, eclair, "foudre")
	eclair.pourcentage_types["foudre"] = 0.05
	var apres_eclair := Formules.degats_bruts(lanceur, eclair, "foudre")
	print("Éclair : %.2f -> %.2f avec +5 %% de foudre" % [avant_eclair, apres_eclair])
	if absf(apres_eclair - avant_eclair * 1.05) > 0.001:
		print("ÉCHEC : +5 %% de foudre sur Éclair.")
		echecs += 1
	return echecs


## Les ennemis lancent chaque dé un palier plus bas (1d2, 1d4, 1d6, 1d10, 1d12 ; 1d2 reste 1d2),
## sauf les soins (lumière) ; le héros garde ses dés.
func _des_ennemis() -> int:
	var echecs := 0
	var donjon := Donjon.nouveau(Personnage.nouveau())
	var gobelin = Gobelin.nouveau(donjon).generer_combattant_gobelin(donjon)
	var attendus := {"tranchant": [[2, 4]], "perforant": [[1, 10]], "contondant": [[1, 6], [1, 2]], "froid": [[3, 2]],
		"foudre": [[1, 10]], "poison": [[1, 2]], "lumière": [[3, 6]]}
	for t in attendus:
		var obtenu := Formules.des_type(gobelin, t)
		if obtenu != attendus[t]:
			print("ÉCHEC : dés ennemis %s = %s au lieu de %s" % [t, obtenu, attendus[t]])
			echecs += 1
	if Formules.des_type({"force": 0}, "tranchant") != [[2, 6]]:
		print("ÉCHEC : le héros garde 2d6 tranchants.")
		echecs += 1
	var rafale := Competences.creer("Rafale_de_lance")
	if Formules.des_type(gobelin, "perforant", rafale) != [[2, 2]] or Formules.valeur_jet(gobelin, rafale, "perforant", true) != 3.0:
		print("ÉCHEC : Rafale de lance d'un ennemi en 2d2 par coup, sans malus (2026-11-01).")
		echecs += 1
	# Dés propres des compétences (2026-11-01) : héros et ennemis ont les leurs pour une même compétence
	if Formules.des_type({"force": 0}, "feu", Competences.creer("Boule_de_feu")) != [[8, 2]] 			or Formules.des_type(gobelin, "feu", Competences.creer("Boule_de_feu")) != [[5, 2]]:
		print("ÉCHEC : Boule de feu 8d2 pour le héros, 5d2 pour un gobelin.")
		echecs += 1
	# Soin mineur d'un gobelin : 7d2 + 15 % des PV max de la cible
	var soin := Competences.creer("Soin_mineur")
	if absf(Formules.bonus_pv_cible(gobelin, soin, gobelin, "lumière") - 0.15 * gobelin.points_de_vie_max) > 0.001:
		print("ÉCHEC : Soin mineur + 15 % des PV max de la cible.")
		echecs += 1
	if Ennemis.MINI_BOSS["degats"] != 1.4 or Ennemis.BOSS["degats"] != 1.6:
		print("ÉCHEC : élites × 1,4 et boss × 1,6.")
		echecs += 1
	print("Dés ennemis : tranchant %s, perforant %s, contondant %s" % [Formules.texte(Formules.des_type(gobelin, "tranchant")),
		Formules.texte(Formules.des_type(gobelin, "perforant")), Formules.texte(Formules.des_type(gobelin, "contondant"))])
	if Ennemis.BOSS["pa"] != 1:
		print("ÉCHEC : boss à 1 PA.")
		echecs += 1
	return echecs
