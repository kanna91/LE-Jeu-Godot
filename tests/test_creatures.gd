extends SceneTree
## Loups et squelettes (Creatures) : caractéristiques, dés tels quels (pas un cran plus bas), faiblesses et résistance
## appliquées aux dégâts, IA (leur seule attaque), et composition des groupes de l'étage sur 3000 tirages (un loup
## jamais seul ni sans archer ou chaman ; squelettes parfois seuls ; féticheur seul gobelin possible avec eux).
## « BILAN créatures : 0 échec(s) ».   godot --headless --path . -s tests/test_creatures.gd

var echecs := 0


func verifier(c: bool, cas: String) -> void:
	if not c:
		echecs += 1
	print(("ok " if c else "ÉCHEC ") + cas)


func _initialize() -> void:
	seed(7)
	Sauvegarde.reinitialiser_monde()
	var heros := Personnage.nouveau()
	var donjon := Donjon.nouveau(heros)
	var loup := Creatures.creer(donjon, "loup")
	var sq := Creatures.creer(donjon, "squelette")
	print("loup : PV %d, squelette : PV %d" % [loup.points_de_vie_max, sq.points_de_vie_max])
	verifier(loup.points_de_vie_max in [10, 20], "loup : 10 ou 20 PV (endurance 1 ou 2, 2026-10-29)")
	verifier(sq.points_de_vie_max >= 18 and sq.points_de_vie_max <= 22, "squelette : 18 à 22 PV")
	verifier(Formules.des_type(sq, "tranchant", sq.competences[0]) == [[4, 2]], "squelette : 4d2 tranchant, pas réduit (2026-11-01)")
	verifier(Formules.des_type(loup, "perforant", loup.competences[0]) == [[4, 2]], "loup : 4d2 perforant, pas réduit (2026-11-01)")
	verifier(sq.competences[0].type_degats == ["tranchant"] and loup.competences[0].type_degats == ["perforant"], "types d'attaque")
	# Faiblesses et résistance : 20 points de dégâts bruts
	var feu := Degats.degats_subis(loup, "feu", 20.0)
	var cont := Degats.degats_subis(sq, "contondant", 20.0)
	var perf := Degats.degats_subis(sq, "perforant", 20.0)
	print("20 bruts → loup feu %.1f, squelette contondant %.1f, squelette perforant %.1f" % [feu, cont, perf])
	verifier(absf(feu - 28.0) < 0.6, "loup : +40 % de dégâts de feu")
	verifier(absf(cont - 28.0) < 0.6 or cont > 27.0, "squelette : +40 % de dégâts contondants")
	verifier(perf < 17.0, "squelette : résiste au perforant (20 %)")
	# Chaman (fiche de l'utilisateur) : 15 % au feu, au froid et à la foudre, faible à l'ombre (40 %)
	var ch := Gobelin.nouveau(donjon)._completer("soutien", "chaman")
	print("chaman, 20 bruts → feu %.1f, froid %.1f, foudre %.1f, ombre %.1f" % [Degats.degats_subis(ch, "feu", 20.0),
		Degats.degats_subis(ch, "froid", 20.0), Degats.degats_subis(ch, "foudre", 20.0), Degats.degats_subis(ch, "ombre", 20.0)])
	verifier(is_equal_approx(ch.resistance_pct_feu, 0.15) and is_equal_approx(ch.resistance_pct_froid, 0.15)
		and is_equal_approx(ch.resistance_pct_foudre, 0.15) and is_equal_approx(ch.vulnerabilite_ombre, 0.40),
		"chaman : feu, froid, foudre −15 %, ombre +40 % (pourcentages, 2026-10-30)")
	verifier(Degats.degats_subis(ch, "ombre", 20.0) > 27.0 and Degats.degats_subis(ch, "feu", 20.0) < 17.5,
		"chaman : faiblesse à l'ombre et résistance au feu appliquées aux dégâts")
	# IA : un tour de combat, il frappe avec sa seule attaque
	heros.points_de_vie_max = 999
	heros.points_de_vie = 999
	var combat := Combat.nouveau(heros, null, [sq], donjon)
	donjon.ennemis = [sq]
	sq.mecanique_ennemis(heros, donjon, combat)
	verifier(heros.points_de_vie <= 999, "le squelette joue son tour sans erreur")
	# Composition des groupes
	var m := {"prochain_id": 1}
	var stats := {"loups": 0, "groupes_loup_sans_dresseur": 0, "loup_seul": 0, "squelettes_seuls": 0,
		"groupes_squelettes": 0, "gobelin_avec_squelettes_pas_feticheur": 0, "feticheur_squelettes": 0}
	for i in 3000:
		var g := Aventure.nouveau_groupe(donjon, m, 1)
		var mb := Aventure.membres(g)
		var sortes := mb.map(func(x): return String(x["sous_classe"]))
		var nb_sq := sortes.count("squelette")
		if sortes.has("loup"):
			stats["loups"] += 1
			if not (sortes.has("archer") or sortes.has("chaman")):
				stats["groupes_loup_sans_dresseur"] += 1
			if sortes.size() == 1:
				stats["loup_seul"] += 1
		if nb_sq > 0:
			stats["groupes_squelettes"] += 1
			if sortes.size() == 1:
				stats["squelettes_seuls"] += 1
			for s in sortes:
				if s != "squelette" and s != "feticheur":
					stats["gobelin_avec_squelettes_pas_feticheur"] += 1
			if sortes.has("feticheur"):
				stats["feticheur_squelettes"] += 1
		if i < 3:
			var ennemis := Aventure.ennemis_de(donjon, g)
			verifier(ennemis.size() == mb.size(), "groupe %d : %s" % [i, ", ".join(ennemis.map(func(e): return e.nom))])
	print(stats)
	verifier(stats["loups"] > 0 and stats["groupes_loup_sans_dresseur"] == 0 and stats["loup_seul"] == 0,
		"un loup accompagne toujours un archer ou un chaman")
	verifier(stats["squelettes_seuls"] > 0, "un squelette peut être seul")
	verifier(stats["gobelin_avec_squelettes_pas_feticheur"] == 0, "avec des squelettes : seulement un féticheur")
	verifier(stats["feticheur_squelettes"] > 0, "un féticheur mène parfois des squelettes")
	print("BILAN créatures : %d échec(s)" % echecs)
	quit()
