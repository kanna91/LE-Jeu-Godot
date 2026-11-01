extends SceneTree
## Gobelin combattant (2026-11-01) : Cri de guerre quand il a au moins un allié vivant et que personne n'est en rage,
## sinon Coup d'épée.
var echecs := 0


func verifier(ok: bool, texte: String) -> void:
	if not ok:
		echecs += 1
		print("ÉCHEC ", texte)


func _initialize() -> void:
	seed(7)
	var h := Personnage.nouveau()
	h.points_de_vie_max = 9999
	h.points_de_vie = 9999
	var donjon := Donjon.nouveau(h)
	var a = Gobelin.nouveau(donjon).generer_gobelin(donjon, 0, ["guerrier", "combattant"])
	var b = Gobelin.nouveau(donjon).generer_gobelin(donjon, 0, ["guerrier", "combattant"])
	donjon.ennemis = [a, b]
	var combat := Combat.nouveau(h, null, donjon.ennemis, donjon)
	a.points_d_action = 1
	a.mecanique_ennemis(h, donjon, combat)
	verifier(a.a_l_alteration("rage") and b.a_l_alteration("rage"), "accompagné : Cri de guerre, les deux en rage")
	verifier(h.points_de_vie == 9999, "le cri ne blesse pas le héros")
	b.points_d_action = 1
	b._d["chance_de_toucher"] = 1.0
	b.mecanique_ennemis(h, donjon, combat)
	verifier(h.points_de_vie < 9999, "déjà en rage : il frappe (Coup d'épée)")
	var seul = Gobelin.nouveau(donjon).generer_gobelin(donjon, 0, ["guerrier", "combattant"])
	donjon.ennemis = [seul]
	var c2 := Combat.nouveau(h, null, donjon.ennemis, donjon)
	seul.points_d_action = 1
	seul.mecanique_ennemis(h, donjon, c2)
	verifier(not seul.a_l_alteration("rage"), "seul : pas de Cri de guerre")
	# Seul : Botte secrète environ une fois sur trois, Coup d'épée sinon
	var bottes := 0
	for i in 300:
		var g = Gobelin.nouveau(donjon).generer_gobelin(donjon, 0, ["guerrier", "combattant"])
		donjon.ennemis = [g]
		var c3 := Combat.nouveau(h, null, donjon.ennemis, donjon)
		g.points_d_action = 1
		h.points_de_vie = 9999
		g.mecanique_ennemis(h, donjon, c3)
		var lancee = U.ga(c3, "_competence_en_cours", null)
		if lancee != null and lancee.nom_classe == "Botte_secrete":
			bottes += 1
	print("  Botte secrète : %d / 300" % bottes)
	verifier(bottes >= 70 and bottes <= 130, "seul : Botte secrète environ une fois sur trois (%d / 300)" % bottes)
	print("BILAN cri de guerre : %d échec(s)" % echecs)
	quit()
